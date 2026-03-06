import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:ble_peripheral/ble_peripheral.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:share_app_latest/app/models/file_meta.dart';

class BluetoothPeripheralService {
  // Define UUIDs
  static const String SERVICE_UUID = "bf27730d-860a-4e09-889c-2d8b6a9e0fe7";
  static const String CHARACTERISTIC_UUID =
      "bf27730d-860a-4e09-889c-2d8b6a9e0fe8";

  final _dataStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get dataStream => _dataStreamController.stream;

  final _connectionStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get connectionStream =>
      _connectionStreamController.stream;

  /// Emits when sendResponse cannot send (no connected device or updateCharacteristic failed).
  /// Receiver UI can listen and show error / clear offer state.
  final _sendResponseErrorController =
      StreamController<String>.broadcast();
  Stream<String> get sendResponseError => _sendResponseErrorController.stream;

  /// BLE file receive: progress 0.0..1.0 during chunked transfer.
  final _bleReceiveProgressController = StreamController<double>.broadcast();
  Stream<double> get bleReceiveProgress => _bleReceiveProgressController.stream;

  /// BLE file receive: emits when transfer complete with savePath and meta.
  final _bleReceiveCompleteController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get bleReceiveComplete =>
      _bleReceiveCompleteController.stream;

  /// BLE file receive: emits error message on failure.
  final _bleReceiveErrorController = StreamController<String>.broadcast();
  Stream<String> get bleReceiveError => _bleReceiveErrorController.stream;

  bool _isAdvertising = false;
  String? _lastConnectedDeviceId;
  bool _restartScheduled = false;

  // BLE file receive state (receiver side)
  bool _receivingFile = false;
  bool _expectingFileMeta = false;
  FileMeta? _receiveFileMeta;
  IOSink? _receiveSink;
  String? _receiveTmpPath;
  String? _receiveSavePath;
  int _receiveTotal = 0;
  int _receiveReceived = 0;
  final List<Uint8List> _pendingChunks = [];

  /// Returns current local name for advertising (device-dependent).
  Future<String> _getLocalName() async {
    String localName = "ShareMe Receiver";
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        localName = androidInfo.model;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        localName = iosInfo.name;
      }
    } catch (_) {}
    return localName;
  }

  /// Adds the app BLE service and starts advertising. Used by start() and by
  /// restart-after-disconnect (iOS/Android) so the receiver is connectable again.
  Future<void> _addServiceAndStartAdvertising() async {
    final localName = await _getLocalName();
    final characteristic = BleCharacteristic(
      uuid: CHARACTERISTIC_UUID,
      properties: [
        CharacteristicProperties.read.index,
        CharacteristicProperties.write.index,
        CharacteristicProperties.notify.index,
      ],
      permissions: [
        AttributePermissions.readable.index,
        AttributePermissions.writeable.index,
      ],
      value: null,
    );
    final service = BleService(
      uuid: SERVICE_UUID,
      primary: true,
      characteristics: [characteristic],
    );
    await BlePeripheral.addService(service);
    await BlePeripheral.startAdvertising(
      services: [SERVICE_UUID],
      localName: localName,
    );
    _isAdvertising = true;
    print("📡 Receiver Mode: Advertising started as '$localName'...");
  }

  /// Called when central unsubscribes (disconnect). On iOS, re-advertising after
  /// disconnect is required for the next connection to succeed reliably.
  /// Uses platform-specific delay (slightly longer on iOS) before re-advertising.
  void _onCentralDisconnected() {
    if (!_isAdvertising || _restartScheduled) return;
    _restartScheduled = true;
    _lastConnectedDeviceId = null;
    final delay = Platform.isIOS
        ? const Duration(milliseconds: 600)
        : const Duration(milliseconds: 300);
    Future.delayed(delay, () async {
      if (!_isAdvertising) {
        _restartScheduled = false;
        return;
      }
      try {
        await BlePeripheral.stopAdvertising();
        _isAdvertising = false;
        await BlePeripheral.clearServices();
        if (Platform.isIOS) {
          await Future.delayed(const Duration(milliseconds: 300));
        }
        await _addServiceAndStartAdvertising();
        print("📡 Receiver Mode: Re-advertising after disconnect (ready for next sender).");
      } catch (e) {
        print("⚠️ [BT Peripheral] Re-advertise after disconnect failed: $e");
      }
      _restartScheduled = false;
    });
  }

  Future<void> start() async {
    // If already advertising (e.g. user re-opened receiver screen), restart so native
    // state is fresh and iOS characteristic lookup works on retry.
    if (_isAdvertising) {
      try {
        await BlePeripheral.stopAdvertising();
        await BlePeripheral.clearServices();
        if (Platform.isIOS) {
          await Future.delayed(const Duration(milliseconds: 300));
        }
      } catch (_) {}
      _isAdvertising = false;
      _lastConnectedDeviceId = null;
      _restartScheduled = false;
    }

    try {
      await BlePeripheral.initialize();
    } catch (e) {
      print(
        "⚠️ BlePeripheral initialize error (might be already initialized): $e",
      );
    }

    await _addServiceAndStartAdvertising();

    // Notify when a central (sender) connects so receiver UI can update immediately.
    // On Android, track deviceId so we have a fallback if write callback hasn't run yet.
    if (Platform.isAndroid) {
      BlePeripheral.setConnectionStateChangeCallback(
        (String deviceId, bool connected) {
          if (connected) {
            _lastConnectedDeviceId = deviceId;
          } else {
            if (_lastConnectedDeviceId == deviceId) {
              _lastConnectedDeviceId = null;
            }
            _onCentralDisconnected();
          }
          _connectionStreamController.add({
            'connected': connected,
            'deviceId': deviceId,
            'name': null,
          });
        },
      );
    }
    BlePeripheral.setCharacteristicSubscriptionChangeCallback(
      (String deviceId, String characteristicId, bool isSubscribed, String? name) {
        if (isSubscribed) {
          _lastConnectedDeviceId = deviceId;
          _connectionStreamController.add({
            'connected': true,
            'deviceId': deviceId,
            'name': name,
          });
        } else {
          if (_lastConnectedDeviceId == deviceId) {
            _lastConnectedDeviceId = null;
          }
          _connectionStreamController.add({
            'connected': false,
            'deviceId': deviceId,
            'name': null,
          });
          _onCentralDisconnected();
        }
      },
    );

    BlePeripheral.setWriteRequestCallback(
      ((
            String deviceId,
            String characteristicId,
            int offset,
            Uint8List? value,
          ) {
            print("📩 Received Write Request from $deviceId: $value");

            if (value != null && value.isNotEmpty) {
              // BLE file receive: expecting file_meta then chunked data
              if (_receivingFile) {
                if (_expectingFileMeta) {
                  try {
                    final msg = utf8.decode(value);
                    final data = jsonDecode(msg) as Map<String, dynamic>;
                    if (data['type'] == 'file_meta' && data['meta'] != null) {
                      _receiveFileMeta = FileMeta.fromJson(
                          data['meta'] as Map<String, dynamic>);
                      _receiveTotal = _receiveFileMeta!.size;
                      _receiveReceived = 0;
                      _expectingFileMeta = false;
                      print(
                        '📄 [BT Peripheral] File meta: ${_receiveFileMeta!.name} (${_receiveTotal} bytes)',
                      );
                      _startReceivingFileToDisk();
                    }
                  } catch (e) {
                    print('❌ [BT Peripheral] Parse file_meta: $e');
                    if (!_bleReceiveErrorController.isClosed) {
                      _bleReceiveErrorController.add('Invalid metadata: $e');
                    }
                    resetReceivingFileState();
                  }
                  return null;
                }
                if (_receiveSink != null) {
                  _receiveSink!.add(value);
                  _receiveReceived += value.length;
                  final progress = _receiveTotal > 0
                      ? (_receiveReceived / _receiveTotal).clamp(0.0, 1.0)
                      : 1.0;
                  if (!_bleReceiveProgressController.isClosed) {
                    _bleReceiveProgressController.add(progress);
                  }
                  if (_receiveReceived >= _receiveTotal) {
                    _finishReceivingFile();
                  }
                } else {
                  _pendingChunks.add(Uint8List.fromList(value));
                }
                return null;
              }
              try {
                final msg = utf8.decode(value);
                final Map<String, dynamic> data = jsonDecode(msg);
                _dataStreamController.add(data);
                _lastConnectedDeviceId = deviceId;
              } catch (e) {
                print("❌ Error decoding message: $e");
              }
            }

            return null;
          })
          as dynamic,
    );
  }

  /// Call when receiver accepts with bleTransfer: true. Next write = file_meta.
  void startReceivingFile() {
    resetReceivingFileState();
    _receivingFile = true;
    _expectingFileMeta = true;
    print('📥 [BT Peripheral] Ready to receive file over BLE');
  }

  void resetReceivingFileState() {
    _receivingFile = false;
    _expectingFileMeta = false;
    _receiveFileMeta = null;
    _receiveTotal = 0;
    _receiveReceived = 0;
    _pendingChunks.clear();
    try {
      _receiveSink?.close();
    } catch (_) {}
    _receiveSink = null;
    _receiveTmpPath = null;
    _receiveSavePath = null;
  }

  Future<void> _startReceivingFileToDisk() async {
    if (_receiveFileMeta == null) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final fileName = _receiveFileMeta!.name.isNotEmpty
          ? _receiveFileMeta!.name
          : 'received_file';
      _receiveSavePath = p.join(dir.path, p.basename(fileName));
      _receiveTmpPath = '$_receiveSavePath.part';
      final file = File(_receiveTmpPath!);
      _receiveSink = file.openWrite();
      print('💾 [BT Peripheral] Saving to: $_receiveSavePath');
      for (final chunk in _pendingChunks) {
        _receiveSink!.add(chunk);
        _receiveReceived += chunk.length;
      }
      _pendingChunks.clear();
      final progress = _receiveTotal > 0
          ? (_receiveReceived / _receiveTotal).clamp(0.0, 1.0)
          : 1.0;
      if (!_bleReceiveProgressController.isClosed) {
        _bleReceiveProgressController.add(progress);
      }
      if (_receiveReceived >= _receiveTotal) {
        _finishReceivingFile();
      }
    } catch (e) {
      print('❌ [BT Peripheral] Failed to open file: $e');
      if (!_bleReceiveErrorController.isClosed) {
        _bleReceiveErrorController.add('Failed to save file: $e');
      }
      resetReceivingFileState();
    }
  }

  void _finishReceivingFile() {
    try {
      _receiveSink?.close();
      _receiveSink = null;
    } catch (_) {}
    if (_receiveTmpPath != null && _receiveSavePath != null) {
      final tmp = File(_receiveTmpPath!);
      if (tmp.existsSync()) {
        tmp.renameSync(_receiveSavePath!);
      }
      if (!_bleReceiveCompleteController.isClosed) {
        _bleReceiveCompleteController.add({
          'savePath': _receiveSavePath!,
          'meta': _receiveFileMeta?.toJson(),
        });
      }
      print('✅ [BT Peripheral] File received: $_receiveSavePath');
    }
    resetReceivingFileState();
  }

  Future<void> stop() async {
    _restartScheduled = true;
    if (_isAdvertising) {
      try {
        await BlePeripheral.stopAdvertising();
        await BlePeripheral.clearServices();
      } catch (e) {
        print("⚠️ [BT Peripheral] stop error: $e");
      }
      _isAdvertising = false;
      _lastConnectedDeviceId = null;
      print("🛑 Receiver Mode: Advertising stopped.");
    }
  }

  Future<void> sendResponse(String message) async {
    final bytes = utf8.encode(message);

    // On Android we need deviceId; on iOS we can try broadcast (updateCharacteristic without deviceId)
    // when _lastConnectedDeviceId is null, so only bail out on Android when null.
    if (_lastConnectedDeviceId == null && !Platform.isIOS) {
      print(
        "⚠️ [BT Peripheral] No connected device to send response; "
        "sender will not receive accept/reject.",
      );
      if (!_sendResponseErrorController.isClosed) {
        _sendResponseErrorController.add(
          'No connected device to send response to sender.',
        );
      }
      return;
    }

    try {
      if (Platform.isAndroid && _lastConnectedDeviceId != null) {
        await BlePeripheral.updateCharacteristic(
          characteristicId: CHARACTERISTIC_UUID,
          value: Uint8List.fromList(bytes),
          deviceId: _lastConnectedDeviceId!,
        );
        print("📤 Sent Response (Notification): $message");
        return;
      }
      // iOS (or Android with deviceId): try both UUID formats so we always find the characteristic.
      // On iOS when _lastConnectedDeviceId is null we still attempt broadcast (no deviceId) for cross-platform.
      final idsToTry = Platform.isIOS
          ? [CHARACTERISTIC_UUID.toUpperCase(), CHARACTERISTIC_UUID]
          : [CHARACTERISTIC_UUID];
      Object? lastError;
      for (var i = 0; i < idsToTry.length; i++) {
        try {
          await BlePeripheral.updateCharacteristic(
            characteristicId: idsToTry[i],
            value: Uint8List.fromList(bytes),
          );
          print("📤 Sent Response (Notification): $message");
          return;
        } catch (e) {
          lastError = e;
          final msg = e.toString();
          final isNotFound = msg.contains('not found') || msg.contains('notFound');
          if (!isNotFound || i == idsToTry.length - 1) break;
        }
      }
      if (lastError != null) throw lastError;
    } catch (e) {
      print("❌ [BT Peripheral] updateCharacteristic failed: $e");
      if (!_sendResponseErrorController.isClosed) {
        _sendResponseErrorController.add(
          'Could not send response to sender: $e',
        );
      }
      rethrow;
    }
  }
}

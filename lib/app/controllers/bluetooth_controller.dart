import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:path/path.dart' as p;
import 'package:share_app_latest/services/bluetooth_peripheral_service.dart';
import 'package:share_app_latest/utils/permissions.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'package:device_info_plus/device_info_plus.dart';

import 'package:share_app_latest/app/models/device_info.dart';
import 'package:share_app_latest/app/models/file_meta.dart';

class BluetoothController extends GetxController {
  final isScanning = false.obs;
  final devices = <BluetoothDevice>[].obs;

  final pairedDevices = <DeviceInfo>[].obs;
  final error = ''.obs;
  final connectedDevice = Rxn<BluetoothDevice>();
  final incomingOffer = Rxn<Map<String, dynamic>>();
  final offerAccepted = false.obs;

  /// Receiver only: set when a sender has connected and we know its name (from offer or connection).
  final connectedSenderName = Rxn<String>();
  String? selectedFilePath;
  String? receiverIp;
  int? receiverPort;
  final incomingConnection = Rxn<BluetoothDevice>();
  Timer? _pollTimer;
  BluetoothCharacteristic? _chatChar;
  StreamSubscription<List<int>>? notifySub;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSub;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription? _connectionStreamSub;
  StreamSubscription? _dataStreamSub;
  /// RSSI threshold: devices with signal weaker than this are filtered out. -80 allows receivers at edge of range.
  final int distanceThreshold = -80;

  // New Peripheral Service
  final _peripheralService = BluetoothPeripheralService();
  bool isReceiver = false;

  static const String SERVICE_UUID = "bf27730d-860a-4e09-889c-2d8b6a9e0fe7";
  static const String CHARACTERISTIC_UUID =
      "bf27730d-860a-4e09-889c-2d8b6a9e0fe8";

  Future<void> sendMessage(String message) async {
    try {
      if (isReceiver) {
        // Receiver sending response (Accept/Reject) via Notification
        await _peripheralService.sendResponse(message);
      } else {
        // Sender sending offer via Write
        if (_chatChar == null) {
          Get.snackbar("Error", "Bluetooth channel not ready");
          return;
        }

        final bytes = utf8.encode(message);
        await _chatChar!.write(bytes, withoutResponse: false);
        print("📤 Sent BLE message: $message");
      }
    } catch (e) {
      print("❌ sendMessage failed: $e");
    }
  }

  /// Builds FileMeta from path, sets selectedFilePath, and sends BLE offer.
  /// Receiver will reply with accept (including ip/port) or reject.
  Future<void> sendOffer(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        Get.snackbar("Error", "File not found");
        return;
      }
      offerAccepted.value = false;
      receiverIp = null;
      receiverPort = null;

      final name = p.basename(filePath);
      final size = await file.length();
      final type = _fileTypeFromPath(filePath);
      final meta = FileMeta(name: name, size: size, type: type);
      selectedFilePath = filePath;

      final deviceName = await _getSenderDeviceName();
      final offer = {
        "type": "offer",
        "meta": meta.toJson(),
        "deviceName": deviceName,
      };
      await sendMessage(jsonEncode(offer));
      print("📤 BLE offer sent: $name (${size} bytes)");
    } catch (e) {
      print("❌ sendOffer failed: $e");
      Get.snackbar("Error", "Failed to send offer: $e");
    }
  }

  static String _fileTypeFromPath(String path) {
    final ext = p.extension(path).toLowerCase();
    if (ext == '.apk') return 'apk';
    if (ext == '.mp4' || ext == '.mov') return 'video';
    if (ext == '.jpg' || ext == '.jpeg' || ext == '.png') return 'image';
    return 'file';
  }

  static Future<String> _getSenderDeviceName() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        final brand = androidInfo.brand;
        final model = androidInfo.model;
        if (brand.isNotEmpty && model.isNotEmpty) return '$brand $model'.trim();
        return model.isNotEmpty ? model : 'Android device';
      }
      if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.name.isNotEmpty ? iosInfo.name : 'iPhone';
      }
    } catch (_) {}
    return 'Sender device';
  }

  /// Single source of truth: true iff [device] is the currently connected device.
  bool isDeviceConnected(BluetoothDevice device) {
    final current = connectedDevice.value;
    return current != null && current.remoteId.str == device.remoteId.str;
  }

  /// DeviceInfo for the currently connected BLE device, if any (from pairedDevices).
  DeviceInfo? get connectedDeviceInfo {
    final current = connectedDevice.value;
    if (current == null) return null;
    final id = current.remoteId.str;
    try {
      return pairedDevices.firstWhere((e) => e.bluetoothDeviceId == id);
    } catch (_) {
      return null;
    }
  }

  /// Disconnect a device and clear channel state. No-op if [device] is not the connected one.
  Future<void> disconnect(BluetoothDevice device) async {
    if (!isDeviceConnected(device)) return;
    await _tearDownConnection(device);
    connectedDevice.value = null;
    Get.snackbar('Disconnected', 'Disconnected from device');
  }

  /// Cancel notify subscription, connection-state listener, and disconnect the device.
  Future<void> _tearDownConnection(BluetoothDevice device) async {
    await notifySub?.cancel();
    notifySub = null;
    await _connectionStateSub?.cancel();
    _connectionStateSub = null;
    _chatChar = null;
    try {
      await device.disconnect();
    } catch (e) {
      print("⚠️ disconnect error (ignoring): $e");
    }
  }

  void _listenToConnectionState(BluetoothDevice device) {
    _connectionStateSub?.cancel();
    _connectionStateSub = device.connectionState.listen((state) {
      if (state != BluetoothConnectionState.connected) {
        if (isDeviceConnected(device)) {
          _tearDownConnection(device).then((_) {
            connectedDevice.value = null;
            Get.snackbar('Disconnected', 'Device disconnected');
          });
        }
      }
    });
  }

  Future<void> connect(BluetoothDevice device) async {
    // if (await Vibration.hasVibrator()) {
    //   Vibration.vibrate(duration: 300); // 500 ms
    // }

    try {
      error.value = '';

      // Already connected to this device → no-op
      if (isDeviceConnected(device)) return;

      // One connection at a time: disconnect current device if different
      final current = connectedDevice.value;
      if (current != null) {
        await _tearDownConnection(current);
        connectedDevice.value = null;
      }

      await FlutterBluePlus.stopScan();
      isScanning.value = false;

      await device.connect(
        timeout: const Duration(seconds: 12),
        autoConnect: false,
      );

      // 🕒 Wait for connection to stabilize (Critical for Android)
      if (Platform.isAndroid) {
        await Future.delayed(const Duration(milliseconds: 1000));
      }

      final connected =
          await device.connectionState
              .where((s) => s == BluetoothConnectionState.connected)
              .timeout(const Duration(seconds: 12))
              .first;

      if (connected == BluetoothConnectionState.connected) {
        // 🚀 Request higher MTU for faster file transfer (Android only)
        // Wrapped in try-catch to avoid "device is disconnected" crash
        if (Platform.isAndroid) {
          try {
            await device.requestMtu(512);
            print("✅ MTU requested: 512");
            await Future.delayed(const Duration(milliseconds: 500));
          } catch (e) {
            print("⚠️ MTU request failed (ignoring): $e");
          }
        }

        // ✅ Discover services AFTER connection
        final services = await device.discoverServices();

        bool found = false;

        for (final s in services) {
          // Check for our specific service if possible, or fall back to finding any suitable characteristic
          if (s.uuid.str.toLowerCase() == SERVICE_UUID.toLowerCase()) {
            for (final c in s.characteristics) {
              if (c.uuid.str.toLowerCase() ==
                  CHARACTERISTIC_UUID.toLowerCase()) {
                _chatChar = c;
                found = true;
                break;
              }
            }
          }
          if (found) break;

          // Fallback logic: find any write+notify characteristic
          for (final c in s.characteristics) {
            if (c.properties.write && c.properties.notify) {
              _chatChar = c;
              found = true;
              break;
            }
          }
          if (found) break;
        }

        if (found && _chatChar != null) {
          await _chatChar!.setNotifyValue(true);

          notifySub = _chatChar!.lastValueStream.listen((data) {
            if (data.isEmpty) return;

            final msg = utf8.decode(data);
            print("📩 Received BLE notification: $msg");

            try {
              final decoded = jsonDecode(msg);

              if (decoded["type"] == "offer") {
                incomingOffer.value = decoded;
              } else if (decoded["type"] == "accept") {
                receiverIp = decoded["ip"]?.toString();
                receiverPort =
                    decoded["port"] != null
                        ? (decoded["port"] is int
                            ? decoded["port"] as int
                            : int.tryParse(decoded["port"].toString()))
                        : null;
                if (receiverIp != null &&
                    receiverIp!.isNotEmpty &&
                    receiverPort != null) {
                  offerAccepted.value = true;
                } else {
                  Get.snackbar(
                    "Error",
                    "Receiver did not send address (connect to same Wi‑Fi)",
                  );
                }
              } else if (decoded["type"] == "reject") {
                offerAccepted.value = false;
                Get.snackbar("Rejected", "Receiver rejected file");
              }
            } catch (e) {
              print("Invalid BLE message: $msg");
            }
          });
        }

        // Add to pairedDevices BEFORE setting connectedDevice so that
        // SelectDeviceScreen's ever(connectedDevice) callback sees connectedDeviceInfo.
        final deviceName = _getBluetoothDeviceDisplayName(device);
        final remoteIdStr = device.remoteId.str;
        final deviceInfo = DeviceInfo(
          name: deviceName,
          ip: '',
          transferPort: 0,
          isBluetooth: true,
          bluetoothDeviceId: remoteIdStr,
        );
        final existingIndex = pairedDevices.indexWhere(
          (e) => e.bluetoothDeviceId == remoteIdStr,
        );
        if (existingIndex >= 0) {
          pairedDevices[existingIndex] = deviceInfo;
        } else {
          pairedDevices.add(deviceInfo);
        }

        connectedDevice.value = device;
        _listenToConnectionState(device);

        Get.snackbar(
          'Connected',
          'Connected to ${device.platformName.isNotEmpty ? device.platformName : device.remoteId.str}',
        );
        // Navigation to transfer is handled by SelectDeviceScreen's ever(connectedDevice).
      }
    } on TimeoutException {
      await _tearDownConnection(device);
      connectedDevice.value = null;
      error.value = 'Connection timeout';
    } catch (e) {
      await _tearDownConnection(device);
      connectedDevice.value = null;
      error.value = 'Failed to connect: $e';
    }
  }

  Future<void> startReceiverMode() async {
    error.value = '';
    isScanning.value = false;
    isReceiver = true;
    devices.clear();

    final isOn = await FlutterBluePlus.isOn;
    if (!isOn) await FlutterBluePlus.turnOn();

    try {
      await _peripheralService.start();

      _connectionStreamSub?.cancel();
      _dataStreamSub?.cancel();

      _connectionStreamSub = _peripheralService.connectionStream.listen((event) {
        final connected = event["connected"] == true;
        if (connected) {
          final name = event["name"]?.toString().trim();
          connectedSenderName.value =
              (name != null && name.isNotEmpty) ? name : "Sender device";
          assert(() {
            // ignore: avoid_print
            debugPrint('[BT] Receiver: connection event, name=${connectedSenderName.value}');
            return true;
          }());
        } else {
          connectedSenderName.value = null;
        }
      });

      // Listen for incoming offers and any BLE writes so receiver UI shows "Connected with X" reliably.
      _dataStreamSub = _peripheralService.dataStream.listen((data) {
        if (data["type"] == "offer") {
          incomingOffer.value = data;
          final offerName = data["deviceName"]?.toString().trim();
          connectedSenderName.value =
              (offerName != null && offerName.isNotEmpty)
                  ? offerName
                  : (connectedSenderName.value ?? "Sender");
          assert(() {
            // ignore: avoid_print
            debugPrint('[BT] Receiver: offer received, connectedSenderName=${connectedSenderName.value}');
            return true;
          }());
        } else {
          // Fallback: on any write, if we still don't have a name, set generic so UI shows "Connected"
          final current = connectedSenderName.value;
          if (current == null || current.isEmpty) {
            final name = data["deviceName"]?.toString().trim();
            connectedSenderName.value =
                (name != null && name.isNotEmpty) ? name : "Sender device";
          }
        }
      });
    } catch (e) {
      error.value = "Failed to start receiver mode: $e";
    }
  }

  void stopReceiverMode() {
    _connectionStreamSub?.cancel();
    _connectionStreamSub = null;
    _dataStreamSub?.cancel();
    _dataStreamSub = null;
    _peripheralService.stop();
    isReceiver = false;
    connectedSenderName.value = null;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void onClose() {
    stopScan();
    stopReceiverMode();
    super.onClose();
  }

  Future<void> startScan() async {
    stopReceiverMode();
    devices.clear();
    pairedDevices.clear();
    error.value = '';
    isScanning.value = true;

    if (!await askPermissions()) {
      error.value = 'Bluetooth permission denied';
      isScanning.value = false;
      return;
    }

    if (Platform.isAndroid) {
      final locationStatus = await Permission.location.status;
      if (!locationStatus.isGranted) {
        error.value =
            'Allow location access so we can find nearby Bluetooth devices.';
        isScanning.value = false;
        return;
      }
    }

    final isOn = await FlutterBluePlus.isOn;
    if (!isOn) {
      try {
        await FlutterBluePlus.turnOn();
      } catch (e) {
        error.value = 'Please turn on Bluetooth in settings';
        isScanning.value = false;
        return;
      }
    }

    try {
      final supported = await FlutterBluePlus.isSupported;
      if (!supported) {
        error.value = 'Bluetooth not supported on this device';
        isScanning.value = false;
        return;
      }

      // ✅ Subscribe to scan results FIRST so we don't miss early results, then start scan.
      final serviceGuid = Guid(SERVICE_UUID);

      await _scanSubscription?.cancel();
      _scanSubscription = null;

      _scanSubscription = FlutterBluePlus.scanResults.listen(
        (results) {
          for (final r in results) {
            final d = r.device;
            if (r.rssi < distanceThreshold) continue;
            final index = devices.indexWhere(
              (e) => e.remoteId.str == d.remoteId.str,
            );
            if (index == -1) {
              devices.add(d);
            } else {
              devices[index] = d;
            }
          }
        },
        onDone: () {
          isScanning.value = false;
        },
        onError: (e) {
          error.value = 'Bluetooth scan error: $e';
          isScanning.value = false;
        },
      );

      await FlutterBluePlus.startScan(
        withServices: [serviceGuid],
        timeout: null,
      );
      assert(() {
        // ignore: avoid_print
        debugPrint('[BT] Scan started; waiting for receivers advertising service.');
        return true;
      }());
    } catch (e) {
      error.value = 'Bluetooth unavailable. Please try again.';
      isScanning.value = false;
      assert(() {
        // ignore: avoid_print
        debugPrint('[BT] startScan error: $e');
        return true;
      }());
    }
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    isScanning.value = false;
    assert(() {
      // ignore: avoid_print
      debugPrint('[BT] Scan stopped.');
      return true;
    }());
  }

  /// Only devices with valid, identifiable names. Filters out Unknown/dummy placeholders.
  List<BluetoothDevice> get displayableDevices =>
      devices.where(_hasValidDisplayName).toList();

  static String _getBluetoothDeviceDisplayName(BluetoothDevice d) {
    final name = d.name.trim();
    final platformName = d.platformName.trim();
    if (name.isNotEmpty) return name;
    if (platformName.isNotEmpty) return platformName;
    return d.remoteId.str;
  }

  static bool _hasValidDisplayName(BluetoothDevice d) {
    final name = d.name.trim();
    final platformName = d.platformName.trim();
    final effective = name.isNotEmpty ? name : platformName;
    if (effective.isEmpty) return false;
    return !_isGenericPlaceholder(effective);
  }

  static bool _isGenericPlaceholder(String name) {
    final lower = name.toLowerCase();
    const placeholders = [
      'unknown',
      'unknown device',
      'unnamed',
      'unnamed device',
      'null',
      'n/a',
      'ble device',
      'bluetooth device',
    ];
    return placeholders.any((p) => lower == p || lower.startsWith('$p '));
  }
}

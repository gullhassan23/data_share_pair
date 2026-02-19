import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:ble_peripheral/ble_peripheral.dart';
import 'package:device_info_plus/device_info_plus.dart';

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

  bool _isAdvertising = false;
  String? _lastConnectedDeviceId;

  Future<void> start() async {
    if (_isAdvertising) return;

    // Initialize BLE Peripheral
    try {
      await BlePeripheral.initialize();
    } catch (e) {
      print(
        "⚠️ BlePeripheral initialize error (might be already initialized): $e",
      );
    }

    // Get device name
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

    // Define the characteristic
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

    // Define the service
    final service = BleService(
      uuid: SERVICE_UUID,
      primary: true,
      characteristics: [characteristic],
    );

    // Add service
    await BlePeripheral.addService(service);

    // Start advertising
    await BlePeripheral.startAdvertising(
      services: [SERVICE_UUID],
      localName: localName,
    );

    _isAdvertising = true;
    print("📡 Receiver Mode: Advertising started as '$localName'...");

    // Notify when a central (sender) connects so receiver UI can update immediately
    if (Platform.isAndroid) {
      BlePeripheral.setConnectionStateChangeCallback(
        (String deviceId, bool connected) {
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
          _connectionStreamController.add({
            'connected': true,
            'deviceId': deviceId,
            'name': name,
          });
        } else {
          _connectionStreamController.add({
            'connected': false,
            'deviceId': deviceId,
            'name': null,
          });
        }
      },
    );

    // Set typed write callback
    // Signature: (String deviceId, String characteristicId, int offset, Uint8List? value)
    BlePeripheral.setWriteRequestCallback(
      ((
            String deviceId,
            String characteristicId,
            int offset,
            Uint8List? value,
          ) {
            print("📩 Received Write Request from $deviceId: $value");

            if (value != null && value.isNotEmpty) {
              try {
                final msg = utf8.decode(value);
                final Map<String, dynamic> data = jsonDecode(msg);
                _dataStreamController.add(data);
                _lastConnectedDeviceId = deviceId;
              } catch (e) {
                print("❌ Error decoding message: $e");
              }
            }

            // Return null (no explicit result)
            return null;
          })
          as dynamic,
    );
  }

  Future<void> stop() async {
    if (_isAdvertising) {
      await BlePeripheral.stopAdvertising();
      _isAdvertising = false;
      print("🛑 Receiver Mode: Advertising stopped.");
    }
  }

  Future<void> sendResponse(String message) async {
    if (_lastConnectedDeviceId == null) {
      print("⚠️ No connected device to send response.");
      return;
    }

    final bytes = utf8.encode(message);

    await BlePeripheral.updateCharacteristic(
      characteristicId: CHARACTERISTIC_UUID,
      value: Uint8List.fromList(bytes),
      deviceId: _lastConnectedDeviceId!,
    );

    print("📤 Sent Response (Notification): $message");
  }
}

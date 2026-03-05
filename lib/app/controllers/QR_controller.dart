import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_app_latest/services/receiver_readiness_service.dart';
import '../models/device_info.dart';
import '../models/file_meta.dart';

/// QR transfer flow states. Pairing and file sending are separate phases.
enum TransferFlowState {
  idle,
  paired,
  fileSelected,
  offerSent,
  transferring,
  completed,
}

class QrController extends GetxController {
  final devices = <DeviceInfo>[].obs;
  final isServer = false.obs;
  final deviceName = ''.obs;
  final wsPort = 7070;
  final transferPort = 9090;
  StreamSubscription? _p2pSub;
  HttpServer? _wsHttpServer;
  ReceivePort? _scanReceivePort;
  final wsRunning = false.obs;
  final wsDisplayIp = ''.obs;

  /// The IP the pairing WebSocket server is bound to (for QR display when on same Wi-Fi)
  final serverBindIp = ''.obs;
  // P2P channels
  final MethodChannel _p2pMethod = const MethodChannel(
    'com.share.transfer.file.all.data.app/p2p',
  );
  final EventChannel _p2pEvents = const EventChannel(
    'com.share.transfer.file.all.data.app/p2p_events',
  );
  final incomingOffer = Rxn<Map<String, dynamic>>();

  /// Pairing request from a sender that scanned our QR (receiver shows "Device X wants to pair").
  final incomingPairingRequest = Rxn<Map<String, dynamic>>();
  final Map<String, WebSocket> _pendingSockets = {};
  final isScanning = false.obs;

  /// QR sender flow state: idle → paired → fileSelected → offerSent → transferring → completed.
  final flowState = TransferFlowState.idle.obs;
  @override
  void onInit() {
    super.onInit();
    // Listen to native P2P events if available
    try {
      _p2pSub = _p2pEvents.receiveBroadcastStream().listen((dynamic event) {
        try {
          final Map<dynamic, dynamic> map = event as Map<dynamic, dynamic>;
          final type = map['type'] as String? ?? '';
          if (type == 'peerFound') {
            final name = map['name'] as String? ?? 'Unknown';
            final addr = map['deviceAddress'] as String? ?? '';
            final exists =
                devices.where((d) => d.ip == addr || d.name == name).isNotEmpty;
            if (!exists) {
              devices.add(
                DeviceInfo(
                  name: name,
                  ip: addr,
                  wsPort: wsPort,
                  transferPort: transferPort,
                ),
              );
              print('🔍 P2P peerFound: $name at $addr');
            }
          } else if (type == 'peerLost') {
            final addr = map['deviceAddress'] as String? ?? '';
            devices.removeWhere((d) => d.ip == addr);
            print('🔍 P2P peerLost: $addr');
          } else if (type == 'connectionInfo') {
            final groupIp = map['groupOwnerIp'] as String? ?? '';
            final isOwner = map['isGroupOwner'] as bool? ?? false;
            print('🔗 P2P connectionInfo: $groupIp owner:$isOwner');
            // Update wsDisplayIp so UI/QR can use it
            if (groupIp.isNotEmpty) {
              wsDisplayIp.value = groupIp;
            }
            // Update device list entry if present
            final existing = devices.where((d) => d.ip == groupIp).isNotEmpty;
            if (!existing && groupIp.isNotEmpty) {
              devices.add(
                DeviceInfo(
                  name: deviceName.value,
                  ip: groupIp,
                  wsPort: wsPort,
                  transferPort: transferPort,
                ),
              );
            } else if (existing) {
              // ensure entry has correct ip
              for (var i = 0; i < devices.length; i++) {
                if (devices[i].ip.isEmpty) {
                  devices[i] = DeviceInfo(
                    name: devices[i].name,
                    ip: groupIp,
                    wsPort: wsPort,
                    transferPort: transferPort,
                  );
                }
              }
            }
          } else if (type == 'p2pError') {
            final msg = map['message'] as String? ?? '';
            print('❌ P2P error: $msg');
          }
        } catch (e) {
          print('❌ Error handling P2P event: $e');
        }
      });
    } catch (e) {
      print('⚠️ P2P EventChannel not available: $e');
    }
  }

  Future<bool> connectToPeer(String deviceAddress) async {
    try {
      final res = await _p2pMethod.invokeMethod<bool>('connectToPeer', {
        'deviceAddress': deviceAddress,
      });
      return res == true;
    } catch (e) {
      print('❌ connectToPeer failed: $e');
      return false;
    }
  }

  @override
  void onClose() {
    _p2pSub?.cancel();
    super.onClose();
  }

  Future<String> _getDeviceName() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        final brand = androidInfo.brand.toUpperCase();
        final model = androidInfo.model;
        return '$brand $model'.trim();
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        final name = iosInfo.name;
        final model = iosInfo.model;
        return name.isNotEmpty ? name : 'iPhone $model'.trim();
      }
    } catch (e) {
      print('Error getting device info: $e');
    }
    return 'Unknown Device';
  }

  Future<void> startServer([String? customName]) async {
    const maxBindAttempts = 3;
    for (var attempt = 1; attempt <= maxBindAttempts; attempt++) {
      try {
        final ok = await _startServerAttempt(customName);
        if (ok) return;
      } catch (e) {
        print("❌ startServer attempt $attempt failed: $e");
      }
      if (attempt < maxBindAttempts) {
        await Future.delayed(Duration(milliseconds: 300 * attempt));
      }
    }
    print("❌ Failed to start server after $maxBindAttempts attempts");
    isServer.value = false;
  }

  Future<bool> _startServerAttempt(String? customName) async {
    try {
      final actualDeviceName = customName ?? await _getDeviceName();
      deviceName.value = actualDeviceName;
      isServer.value = true;

      String? wifiIp = await ReceiverReadinessService.discoverLocalIp();
      if (wifiIp == null || wifiIp.isEmpty) {
        wifiIp = await ReceiverReadinessService.waitForNetworkReady(
          timeout: const Duration(seconds: 5),
        );
      }
      if (wifiIp == null || wifiIp.isEmpty) {
        print(
          "❌ No routable WiFi IP found; refusing to bind to 0.0.0.0 for QR flow",
        );
        isServer.value = false;
        throw Exception(
          'Could not detect network IP. Ensure Wi-Fi is on and try again.',
        );
      }

      print("📡 Binding WebSocket Server to IP: $wifiIp (display: $wifiIp)");

      final server = await HttpServer.bind(
        InternetAddress(wifiIp),
        wsPort,
        shared: true,
      );

      _wsHttpServer = server;
      serverBindIp.value = wifiIp;
      wsRunning.value = true;

      print("✅ WebSocket Server running at ws://$wifiIp:$wsPort");
      print("[QR] server started bind=$wifiIp port=$wsPort");

      server.listen((HttpRequest request) async {
        final remoteIp = request.connectionInfo?.remoteAddress.address;
        print("🌐 Incoming request from $remoteIp");

        if (!WebSocketTransformer.isUpgradeRequest(request)) {
          request.response.statusCode = HttpStatus.badRequest;
          await request.response.close();
          return;
        }

        try {
          final socket = await WebSocketTransformer.upgrade(request);
          print("🔗 WebSocket upgraded: $remoteIp");
          print("[QR] websocket upgraded remoteIp=$remoteIp");

          // Send tagged device info (use serverBindIp for routable address)
          final deviceInfoJson = jsonEncode({
            'type': 'device_info',
            'name': deviceName.value.trim(),
            'ip': serverBindIp.value.isNotEmpty ? serverBindIp.value : wifiIp,
            'wsPort': wsPort,
            'transferPort': transferPort,
          });

          socket.add(deviceInfoJson);
          print("📤 Sent device info: $deviceInfoJson");

          socket.listen(
            (dynamic data) async {
              try {
                final map = jsonDecode(data as String) as Map<String, dynamic>;
                print("📥 Received WS data: $map");

                final fromIp = remoteIp ?? '';
                if (map['type'] == 'pairing_request') {
                  final senderName = map['senderName'] as String? ?? 'Unknown';
                  print(
                    "[QR] Pairing request received from $fromIp (senderName: $senderName)",
                  );
                  // If same IP reconnected (e.g. sender retried), replace socket so response goes to live connection
                  if (_pendingSockets.containsKey(fromIp)) {
                    final oldSocket = _pendingSockets[fromIp];
                    try {
                      await oldSocket?.close();
                    } catch (_) {}
                    print(
                      "[QR] Replaced pending socket for $fromIp (sender reconnected)",
                    );
                    // Do not set incomingPairingRequest again — dialog already shown
                  } else {
                    incomingPairingRequest.value = {
                      'fromIp': fromIp,
                      'senderName': senderName,
                    };
                    print(
                      "✅ incomingPairingRequest set for UI: ${incomingPairingRequest.value}",
                    );
                  }
                  _pendingSockets[fromIp] = socket;
                } else if (map['type'] == 'offer') {
                  print("📥 File offer received from $fromIp");
                  print("[QR] offer received raw");

                  final metaJson = map['meta'];
                  if (metaJson == null || metaJson is! Map<String, dynamic>) {
                    print(
                      "❌ Error parsing socket data: offer meta missing or invalid",
                    );
                    return;
                  }

                  incomingOffer.value = null;
                  _pendingSockets[fromIp] = socket;

                  incomingOffer.value = {
                    'fromIp': fromIp,
                    'meta': FileMeta.fromJson(metaJson).toJson(),
                  };

                  print("✅ incomingOffer set for UI: ${incomingOffer.value}");
                  print("[QR] incomingOffer set");
                }
              } catch (e) {
                print("❌ Error parsing socket data: $e");
              }
            },
            onDone: () {
              print("🔌 Socket closed: $remoteIp");
            },
            onError: (e) {
              print("❌ Socket error: $e");
            },
          );
        } catch (e) {
          print("❌ WebSocket upgrade failed: $e");
        }
      });
      return true;
    } catch (e) {
      print("❌ Failed to start server: $e");
      isServer.value = false;
      rethrow;
    }
  }

  Future<void> stopServer() async {
    await _wsHttpServer?.close(force: true);
    _wsHttpServer = null;
    isServer.value = false;
    wsRunning.value = false;
    serverBindIp.value = '';
  }

  Future<void> discover() async {
    final info = NetworkInfo();
    String? localIp = await info.getWifiIP();

    if (localIp == null || localIp.isEmpty) {
      print(
        "⚠️ Local IP not found via NetworkInfo, trying alternative methods...",
      );
      try {
        final interfaces = await NetworkInterface.list();
        for (final interface in interfaces) {
          for (final addr in interface.addresses) {
            if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
              localIp = addr.address;
              print("📡 Found local IP via NetworkInterface: $localIp");
              break;
            }
          }
          if (localIp != null) break;
        }
      } catch (e) {
        print("❌ Error getting local IP: $e");
        return;
      }
    }

    if (localIp == null || localIp.isEmpty) {
      print("❌ Cannot determine local IP for network scanning");
      return;
    }

    final base = localIp.split('.');
    if (base.length != 4) {
      print("❌ Invalid IP format: $localIp");
      return;
    }

    final prefix = '${base[0]}.${base[1]}.${base[2]}';
    print("🔍 Scanning network: $prefix.1-254");
    _scanReceivePort?.close();
    _scanReceivePort = ReceivePort();
    isScanning.value = true;
    _scanReceivePort!.listen((dynamic msg) {
      if (msg is Map<String, dynamic>) {
        try {
          final d = DeviceInfo.fromJson(msg);

          // Validate device info
          if (d.name.isEmpty) {
            print('⚠️ Skipping device with empty name');
            return;
          }
          if (d.ip.isEmpty) {
            print('⚠️ Skipping device with empty IP');
            return;
          }

          print('🔍 Found device: ${d.name} at ${d.ip}:${d.transferPort}');
          // Don't add our own device to the list
          if (d.ip != localIp) {
            final existing = devices.where((e) => e.ip == d.ip).isNotEmpty;
            if (!existing) {
              devices.add(d);
              print(
                '✅ Added device to list: ${d.name} (${devices.length} total devices)',
              );
            } else {
              print('⚠️ Device already in list: ${d.name}');
            }
          } else {
            print('🚫 Skipping own device: ${d.ip} (local IP: $localIp)');
          }
        } catch (e) {
          print('❌ Error parsing device info: $e');
        }
      } else if (msg is String && msg == 'done') {
        print('🔍 Device discovery completed. Found ${devices.length} devices');
        isScanning.value = false;
      }
    });
    await Isolate.spawn(_scanIsolate, {
      'prefix': prefix,
      'sendPort': _scanReceivePort!.sendPort,
    });
  }

  Future<void> pairWith(DeviceInfo device) async {
    if (device.ip.isEmpty) {
      print('❌ pairWith: device IP is empty');
      return;
    }
    final port = device.wsPort ?? wsPort;
    final uri = Uri.parse('ws://${device.ip}:$port');
    try {
      final ws = await WebSocket.connect(
        uri.toString(),
      ).timeout(const Duration(seconds: 5));
      final first = await ws.first;
      final jsonMap = jsonDecode(first as String) as Map<String, dynamic>;
      final peer = DeviceInfo.fromJson(jsonMap);
      ws.close();
      final info = NetworkInfo();
      final localIp = await info.getWifiIP();
      // Don't add our own device to the list
      if (peer.ip != localIp) {
        final existing = devices.where((e) => e.ip == peer.ip).isNotEmpty;
        if (!existing) devices.add(peer);
      }
    } catch (_) {}
  }

  Future<bool> sendOffer(DeviceInfo device, FileMeta meta) async {
    print('📤 Sending offer to ${device.ip}:${device.wsPort}');
    print('[QR] sendOffer called ip=${device.ip} wsPort=${device.wsPort}');
    final uri = Uri.parse('ws://${device.ip}:${device.wsPort}');
    WebSocket? ws;
    try {
      ws = await WebSocket.connect(
        uri.toString(),
      ).timeout(const Duration(seconds: 5)); // Increased timeout for connection
      print('✅ Connected to receiver WS. Sending offer data...');

      final offerJson = jsonEncode({'type': 'offer', 'meta': meta.toJson()});
      ws.add(offerJson);
      print('📤 Offer sent: $offerJson');
      print('[QR] offer sent');
      print('⏳ Waiting for receiver response (10 second timeout)...');

      final response = await ws
          .timeout(
            const Duration(seconds: 15), // Increased timeout to 15 seconds
          )
          .map((e) {
            try {
              final decoded = jsonDecode(e as String) as Map<String, dynamic>;
              print('📥 Received message: $decoded');
              return decoded;
            } catch (e) {
              print('⚠️ Error decoding message: $e');
              return <String, dynamic>{};
            }
          })
          .firstWhere(
            (m) => m['type'] == 'offer_response',
            orElse: () => <String, dynamic>{'type': 'timeout'},
          );

      if (response['type'] == 'timeout') {
        print('⏱️ Timeout waiting for receiver response');
        await ws.close();
        return false;
      }

      print('📨 Received offer response: $response');
      final accepted = response['accept'] == true;
      print('[QR] response received accept=$accepted');
      await ws.close();

      print(
        accepted
            ? '✅ Offer accepted by receiver'
            : '❌ Offer rejected by receiver',
      );
      return accepted;
    } catch (e) {
      print('❌ SendOffer failed: $e');
      print('📋 Error details: ${e.toString()}');
      try {
        await ws?.close();
      } catch (_) {}
      return false;
    }
  }

  Future<bool> startP2P() async {
    // Request location permission required for Wi‑Fi P2P discovery
    if (Platform.isAndroid) {
      final status = await Permission.location.request();
      if (!status.isGranted) {
        print('⚠️ Location permission denied; cannot start P2P');
        return false;
      }
    }

    // Retry/backoff for transient failures (BUSY/ERROR)
    const maxAttempts = 3;
    var attempt = 0;
    var delayMs = 500;
    while (attempt < maxAttempts) {
      attempt++;
      try {
        final res = await _p2pMethod.invokeMethod<bool>('startP2P');
        if (res == true) return true;
        print('❌ startP2P returned false on attempt $attempt');
      } on PlatformException catch (pe) {
        final msg = pe.message?.toString() ?? '';
        print('❌ startP2P failed (attempt $attempt): $msg');
        // If transient BUSY or generic ERROR, retry; otherwise break and surface error
        final lowered = msg.toLowerCase();
        final isTransient =
            lowered.contains('busy') ||
            lowered.contains('error') ||
            lowered.contains('discovery failed: error');
        if (!isTransient) {
          break;
        }
      } catch (e) {
        print('❌ startP2P unexpected error (attempt $attempt): $e');
      }

      // Backoff before retrying
      await Future.delayed(Duration(milliseconds: delayMs));
      delayMs *= 2;
    }

    print('❌ startP2P failed after $attempt attempts');
    return false;
  }

  Future<void> respondToOffer(String fromIp, bool accept) async {
    print('📤 Sending ${accept ? 'ACCEPT' : 'REJECT'} response to $fromIp');

    final ws = _pendingSockets.remove(fromIp);
    if (ws != null) {
      try {
        final responseJson = jsonEncode({
          'type': 'offer_response',
          'accept': accept,
        });
        ws.add(responseJson);
        print('📤 Response sent: $responseJson');
        print('[QR] response sent accept=$accept');
        // Give the message time to be sent before closing
        await Future.delayed(const Duration(milliseconds: 100));
        await ws.close();
        print('📤 WebSocket closed after sending response');
      } catch (e) {
        print('❌ Error sending response: $e');
        try {
          await ws.close();
        } catch (_) {}
      }
    } else {
      print('❌ No pending socket found for $fromIp');
      print('📋 Available sockets: ${_pendingSockets.keys.toList()}');
    }
    incomingOffer.value = null;
  }

  /// Requests pairing with a receiver (QR flow). Sends pairing_request and waits for
  /// pairing_response. Returns true only if receiver accepted; otherwise false.
  Future<bool> requestPairing(DeviceInfo receiver) async {
    if (receiver.ip.isEmpty) {
      print('[QR] requestPairing: receiver IP is empty');
      return false;
    }
    final port = receiver.wsPort ?? wsPort;
    final uri = Uri.parse('ws://${receiver.ip}:$port');
    WebSocket? ws;
    StreamSubscription? sub;
    try {
      print(
        '[QR] Sender[requestPairing]: Connecting to receiver at '
        '${receiver.ip}:$port (transferPort=${receiver.transferPort})',
      );
      ws = await WebSocket.connect(
        uri.toString(),
      ).timeout(const Duration(seconds: 5));

      final responseCompleter = Completer<Map<String, dynamic>>();
      var messageCount = 0;
      DeviceInfo? peer;

      sub = ws.listen(
        (dynamic data) {
          messageCount++;
          try {
            final map = jsonDecode(data as String) as Map<String, dynamic>;
            print('[QR] Sender[requestPairing]: message#$messageCount = $map');
            if (messageCount == 1) {
              peer = DeviceInfo.fromJson(map);
              _getDeviceName().then((senderName) {
                if (ws == null) return;
                final pairingRequestJson = jsonEncode({
                  'type': 'pairing_request',
                  'senderName': senderName,
                });
                ws.add(pairingRequestJson);
                print(
                  '[QR] Sender[requestPairing]: pairing_request sent to '
                  '${receiver.ip} (senderName: $senderName)',
                );
              });
            } else if (messageCount >= 2 && map['type'] == 'pairing_response') {
              if (!responseCompleter.isCompleted) {
                print(
                  '[QR] Sender[requestPairing]: pairing_response received '
                  'accept=${map['accept']} full=$map',
                );
                responseCompleter.complete(map);
              }
            }
          } catch (_) {}
        },
        onError: (e) {
          print('[QR] Sender[requestPairing]: WebSocket onError: $e');
          if (!responseCompleter.isCompleted) {
            responseCompleter.complete(<String, dynamic>{'type': 'error'});
          }
        },
        onDone: () {
          print(
            '[QR] Sender[requestPairing]: WebSocket onDone (closed by peer)',
          );
          if (!responseCompleter.isCompleted) {
            responseCompleter.complete(<String, dynamic>{'type': 'timeout'});
          }
        },
      );

      Timer(const Duration(seconds: 20), () {
        if (!responseCompleter.isCompleted) {
          print('[QR] Sender[requestPairing]: global 20s timeout fired');
          responseCompleter.complete(<String, dynamic>{'type': 'timeout'});
        }
      });

      final response = await responseCompleter.future;
      print('[QR] Sender[requestPairing]: final response map = $response');
      await sub.cancel();
      await ws.close();
      ws = null;
      sub = null;

      if (response['type'] == 'timeout' || response['type'] == 'error') {
        print(
          '[QR] Sender[requestPairing]: pairing failed due to ${response['type']}',
        );
        return false;
      }
      final accepted = response['accept'] == true;
      if (!accepted) {
        print(
          '[QR] Sender[requestPairing]: pairing_response.accept is false/absent',
        );
        return false;
      }
      final acceptedPeer = peer;
      if (acceptedPeer != null) {
        final info = NetworkInfo();
        final localIp = await info.getWifiIP();
        if (acceptedPeer.ip != localIp) {
          final exists =
              devices.where((e) => e.ip == acceptedPeer.ip).isNotEmpty;
          if (!exists) {
            devices.add(acceptedPeer);
            print(
              '[QR] Sender[requestPairing]: added acceptedPeer '
              '${acceptedPeer.name}@${acceptedPeer.ip}:${acceptedPeer.wsPort}',
            );
          } else {
            print(
              '[QR] Sender[requestPairing]: acceptedPeer already in devices '
              'list, skipping add (${acceptedPeer.ip})',
            );
          }
        }
      }
      print('[QR] Sender[requestPairing]: Pairing accepted by receiver');
      return true;
    } catch (e) {
      print('[QR] Sender[requestPairing]: exception during pairing: $e');
      await sub?.cancel();
      try {
        await ws?.close();
      } catch (_) {}
      return false;
    }
  }

  /// Sends pairing_response (accept/reject) to the sender that sent pairing_request.
  Future<void> respondToPairing(String fromIp, bool accept) async {
    print('[QR] Pairing response sent: accept=$accept to $fromIp');
    final ws = _pendingSockets.remove(fromIp);
    if (ws != null) {
      try {
        final responseJson = jsonEncode({
          'type': 'pairing_response',
          'accept': accept,
        });
        ws.add(responseJson);
        await Future.delayed(const Duration(milliseconds: 100));
        await ws.close();
      } catch (e) {
        print('❌ Error sending pairing response: $e');
        try {
          await ws.close();
        } catch (_) {}
      }
    } else {
      print('❌ No pending socket found for pairing response: $fromIp');
    }
    incomingPairingRequest.value = null;
  }

  Future<bool> stopP2P() async {
    try {
      final res = await _p2pMethod.invokeMethod<bool>('stopP2P');
      return res == true;
    } catch (e) {
      print('❌ stopP2P failed: $e');
      return false;
    }
  }

  static void _scanIsolate(Map<String, dynamic> params) async {
    final prefix = params['prefix'] as String;
    final sendPort = params['sendPort'] as SendPort;
    for (int i = 1; i < 255; i++) {
      final ip = '$prefix.$i';
      try {
        final uri = Uri.parse('ws://$ip:7070');
        final ws = await WebSocket.connect(
          uri.toString(),
        ).timeout(const Duration(milliseconds: 300));
        final data = await ws.first;
        ws.close();
        final jsonMap = jsonDecode(data as String) as Map<String, dynamic>;
        // Override IP with the one we actually connected to
        jsonMap['ip'] = ip;
        sendPort.send(jsonMap);
      } catch (_) {}
    }
    sendPort.send('done');
  }

  String localIp() {
    final addr = _wsHttpServer?.address.address;
    return addr ?? '';
  }
}

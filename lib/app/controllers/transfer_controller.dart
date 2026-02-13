import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:file_picker/file_picker.dart';
import '../models/file_meta.dart';
import '../models/device_info.dart';
import 'progress_controller.dart';
import 'pairing_controller.dart';

class TransferController extends GetxController {
  final progress = Get.put(ProgressController());
  final receivedFiles = <Map<String, dynamic>>[].obs;
  ServerSocket? _server;
  final serverPort = 9090;
  ReceivePort? _receivePort;
  StreamController<double>? _sendStream;
  StreamController<double>? _recvStream;

  /// Starts the TCP server for receiving file transfers
  ///
  /// **Purpose:** Creates a TCP server on port 9090 that listens for incoming file transfers.
  ///             When a sender connects, it receives the file data and saves it to the device.
  /// **Why:** This is the actual file transfer server that handles the binary file data transmission
  /// **When called:** Called automatically by PairingController.respondToOffer() when receiver accepts
  ///                 a file transfer offer, OR can be called manually to prepare for receiving files
  /// **Side:** RECEIVER side - receives files from senders
  /// **Port:** 9090 (TCP for file transfer)
  /// **Note:** This is DIFFERENT from PairingController.startServer() which uses WebSocket port 7070
  ///          for device discovery/pairing. This TCP server handles the actual file data transfer.
  Future<void> startServer() async {
    try {
      print('🔄 Starting TCP server on port $serverPort...');
      _server = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        serverPort,
        shared: true,
      );
      print(
        '✅ TCP Server started successfully on ${_server!.address.address}:$serverPort',
      );
      print('🔅 Server is listening for incoming file transfers...');

      // Load existing received files
      await _loadReceivedFiles();
    } catch (e) {
      print('❌ Failed to start TCP server: $e');
      progress.error.value = 'Failed to start server: $e';
      return; // Do not continue if bind failed - avoid _server! null crash
    }
    // Only reach here if bind succeeded - _server is non-null
    _recvStream = StreamController<double>.broadcast();
    _recvStream!.stream.listen((v) {
      progress.receiveProgress.value = v;
    });
    _server!.listen((Socket client) async {
      print(
        '📨 Incoming TCP connection from ${client.remoteAddress.address}:${client.remotePort}',
      );
      client.setOption(SocketOption.tcpNoDelay, true);

      File? file;
      IOSink? sink;
      String? savePath;
      FileMeta? meta;
      int received = 0;

      // Receiver-side progress tracking
      DateTime? receiveStartTime;
      DateTime lastReceiveProgressUpdate = DateTime.now();
      double lastReceivedMB = 0.0;

      try {
        print('⏳ Starting file reception process...');

        // Reset receiver progress for new transfer
        progress.receiveProgress.value = 0.0;
        progress.receivedMB.value = 0.0;
        progress.receiveTotalMB.value = 0.0;
        progress.receiveSpeedMBps.value = 0.0;
        progress.status.value = '';
        progress.error.value = '';

        // Step 1: Read metadata first, then continue to file data in the same loop
        print('📄 Step 1: Reading metadata...');
        final List<int> metaBuffer = [];
        bool metadataReceived = false;
        bool transferComplete = false;
        int chunkCount = 0;

        // Use a single await for loop - socket streams are single-subscription
        await for (final chunk in client) {
          try {
            if (!metadataReceived) {
              // Scan for newline byte (10)
              int newlineIndex = -1;
              for (int i = 0; i < chunk.length; i++) {
                if (chunk[i] == 10) {
                  newlineIndex = i;
                  break;
                }
              }

              if (newlineIndex != -1) {
                // Found newline - extract metadata
                metaBuffer.addAll(chunk.sublist(0, newlineIndex));
                final metaJson = utf8.decode(metaBuffer);
                print('📄 Metadata received: $metaJson');

                // Parse metadata
                meta = FileMeta.fromJson(
                  jsonDecode(metaJson) as Map<String, dynamic>,
                );
                print('📄 File info: ${meta.name} (${meta.size} bytes)');

                // Initialize receiver progress tracking
                receiveStartTime = DateTime.now();
                lastReceiveProgressUpdate = receiveStartTime;
                final totalMB = meta.size / (1024 * 1024);
                progress.receiveTotalMB.value = totalMB;
                progress.status.value = 'Receiving...';

                // Initialize file saving
                final dir = await getApplicationDocumentsDirectory();
                savePath = p.join(dir.path, meta.name);
                final tmpPath = '$savePath.part';

                file = File(tmpPath);
                sink = file.openWrite();

                print('💾 Saving to: $savePath');
                print('🔄 Step 2: Reading file data...');
                metadataReceived = true;

                // Process remaining data in this chunk if any
                if (newlineIndex + 1 < chunk.length) {
                  final remainingData = chunk.sublist(newlineIndex + 1);
                  sink.add(remainingData);
                  received += remainingData.length;
                  print('📊 Initial file data: ${remainingData.length} bytes');

                  // Check if we've received all data
                  if (received >= meta.size) {
                    transferComplete = true;
                    print(
                      '📤 All bytes received in initial chunk, transfer complete',
                    );
                    break;
                  }
                }
              } else {
                // No newline yet, accumulate
                metaBuffer.addAll(chunk);
              }
            } else {
              // Reading file data - use byte counting instead of EOF markers
              chunkCount++;

              if (sink == null || meta == null) {
                print('❌ Error: sink or meta is null during file data reception');
                break;
              }
              sink.add(chunk);
              received += chunk.length;

              // Log progress every 50 chunks or when near completion
              if (chunkCount % 50 == 0 || received >= meta.size) {
                print(
                  '💾 Chunk $chunkCount: total $received / ${meta.size} bytes (${(received / meta.size * 100).toStringAsFixed(1)}%)',
                );
              }

              // Update progress with real-time tracking
              final progressValue = received / meta.size;
              _recvStream?.add(progressValue);
              progress.receiveProgress.value = progressValue;

              // Calculate and update MB received
              final receivedMB = received / (1024 * 1024);
              progress.receivedMB.value = receivedMB;

              // Calculate receive speed (update every 100ms for smooth UI)
              final now = DateTime.now();
              final timeSinceLastUpdate =
                  now.difference(lastReceiveProgressUpdate).inMilliseconds;
              if (timeSinceLastUpdate >= 100 && receiveStartTime != null) {
                final mbDelta = receivedMB - lastReceivedMB;
                final timeDelta = timeSinceLastUpdate / 1000.0;

                if (timeDelta > 0) {
                  progress.receiveSpeedMBps.value = mbDelta / timeDelta;
                }

                lastReceiveProgressUpdate = now;
                lastReceivedMB = receivedMB;
              }

              // Check if we've received all expected bytes
              if (received >= meta.size) {
                print('📤 All ${meta.size} bytes received, transfer complete');
                transferComplete = true;
                // Final progress update
                progress.receiveProgress.value = 1.0;
                progress.receivedMB.value = meta.size / (1024 * 1024);
                progress.receiveSpeedMBps.value = 0.0;
                break;
              }
            }
          } catch (e) {
            print('❌ Error processing chunk: $e');
            // Continue with next chunk
          }
        }

        if (!transferComplete) {
          throw Exception(
            'File transfer incomplete - received $received of ${meta?.size ?? 0} bytes',
          );
        }
        // Ensure all data is flushed to disk
        if (sink != null) {
          await sink.flush();
          await sink.close();
        }

        print('🔄 Renaming temp file to final location...');
        if (file != null && savePath != null) {
          await file.rename(savePath);
        }

        // Send acknowledgment to sender before closing socket
        print('📤 Sending ACK to sender...');
        client.write('__ACK__\n');
        await client.flush();

        // Small delay to ensure ACK is sent
        await Future.delayed(const Duration(milliseconds: 100));

        client.destroy();
        progress.status.value = 'received';

        if (savePath != null && meta != null) {
          print('✅ File received successfully: $savePath (${meta.size} bytes)');

          // Verify file exists and has correct size
          final savedFile = File(savePath);
          if (await savedFile.exists()) {
            final actualSize = await savedFile.length();
            print(
              '🔍 Verification: File exists at $savePath with size $actualSize bytes',
            );
            if (actualSize == meta.size) {
              print('✅ File size matches expected size');

              // Add to received files list
              receivedFiles.add({
                'name': meta.name,
                'path': savePath,
                'size': actualSize,
                'type': meta.type,
                'timestamp': DateTime.now(),
              });
              print('📁 Added to received files list: ${meta.name}');

              // Auto-save images and videos to gallery
              await _autoSaveToGalleryIfMedia(savePath, meta.name);
            } else {
              print(
                '⚠️ File size mismatch! Expected: ${meta.size}, Actual: $actualSize',
              );
            }
          } else {
            print('❌ File not found after saving!');
          }
        }
      } catch (e) {
        print('❌ Error receiving file: $e');
        if (sink != null) {
          await sink.close();
        }
        if (file != null && await file.exists()) {
          await file.delete();
        }
        client.destroy();
        progress.error.value = 'receive_failed';
      }
    });
  }

  /// Automatically saves images and videos to gallery after successful reception
  ///
  /// **Purpose:** Automatically saves media files (images/videos) to the device gallery
  ///             immediately after they are successfully received, without requiring user action
  /// **Why:** Provides seamless experience - media files appear in gallery automatically
  /// **When called:** Called automatically after file reception is complete and verified
  /// **Side:** RECEIVER side - auto-saves media files
  /// **Behavior:** Only saves images/videos, silently skips other file types
  Future<void> _autoSaveToGalleryIfMedia(
    String sourcePath,
    String fileName,
  ) async {
    try {
      // Check if it's an image or video
      final ext = p.extension(fileName).toLowerCase();
      final isImage = ['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(ext);
      final isVideo = ['.mp4', '.mov', '.avi', '.mkv'].contains(ext);

      if (!isImage && !isVideo) {
        // Not a media file, skip auto-save
        return;
      }

      print('🖼️ Auto-saving media file to gallery: $fileName');

      // Request gallery access if needed
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        await Gal.requestAccess();
      }

      // Save to Gallery
      if (isImage) {
        await Gal.putImage(sourcePath);
        print('✅ Image auto-saved to Gallery: $fileName');
      } else {
        await Gal.putVideo(sourcePath);
        print('✅ Video auto-saved to Gallery: $fileName');
      }
    } catch (e) {
      // Silently handle errors - don't interrupt the file reception flow
      print('⚠️ Auto-save to gallery failed (non-critical): $e');
    }
  }

  /// Saves a received file to the device's Downloads folder or Gallery
  ///
  /// **Purpose:** Moves a file from the app's internal storage to a user-accessible location
  ///             (Downloads folder for general files, Gallery for images/videos)
  /// **Why:** Files are initially saved to app documents directory, but users need them in
  ///          accessible locations like Downloads or Gallery
  /// **When called:** Called when user taps "Save" or "Download" on a received file
  /// **Side:** RECEIVER side - saves files after receiving them
  /// **Behavior:** Images/videos → Gallery, Other files → Downloads folder
  Future<void> saveToDownloads(String sourcePath, String fileName) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        Get.snackbar('Error', 'Source file not found');
        return;
      }

      // Check if it's an image or video for Gallery saving
      final ext = p.extension(fileName).toLowerCase();
      final isImage = ['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(ext);
      final isVideo = ['.mp4', '.mov', '.avi', '.mkv'].contains(ext);

      if (isImage || isVideo) {
        // Request access first
        final hasAccess = await Gal.hasAccess();
        if (!hasAccess) {
          await Gal.requestAccess();
        }

        // Save to Gallery
        if (isImage) {
          await Gal.putImage(sourcePath);
        } else {
          await Gal.putVideo(sourcePath);
        }

        Get.snackbar(
          'Saved',
          'Saved to Gallery',
          snackPosition: SnackPosition.BOTTOM,
        );
        print('✅ File saved to Gallery: $fileName');
        return; // Done
      }

      // ✅ Android Downloads directory (Legacy/Documents approach for non-media or if gallery fails preferred)
      Directory? downloadsDir;

      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
      } else if (Platform.isIOS) {
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      if (downloadsDir == null) {
        Get.snackbar('Error', 'Downloads folder not found');
        return;
      }

      final targetPath = p.join(downloadsDir.path, fileName);

      // ✅ Copy file
      await sourceFile.copy(targetPath);

      Get.snackbar(
        'Download complete',
        'Saved to Downloads',
        snackPosition: SnackPosition.BOTTOM,
      );

      print('✅ File saved to: $targetPath');
    } catch (e) {
      print('❌ Download failed: $e');
      Get.snackbar('Error', 'Failed to save file: $e');
    }
  }

  /// Stops the TCP file transfer server
  ///
  /// **Purpose:** Closes the TCP server (port 9090) that was receiving file transfers
  /// **Why:** Frees up network resources and stops listening for incoming file transfers
  /// **When called:** Called when user wants to stop receiving files or when app closes
  /// **Side:** RECEIVER side - stops the file transfer server
  /// **Note:** This stops the FILE TRANSFER server, not the pairing server (see PairingController.stopServer())
  Future<void> stopServer() async {
    await _server?.close();
    _server = null;
    await _recvStream?.close();
  }

  /// Loads the list of previously received files from app storage
  ///
  /// **Purpose:** Scans the app's documents directory and builds a list of all files that
  ///             were previously received, including their metadata (name, size, type, timestamp)
  /// **Why:** Allows the app to display a history of received files even after app restart
  /// **When called:** Called automatically when startServer() is called, and can be called
  ///                 manually to refresh the received files list
  /// **Side:** RECEIVER side - manages received files list
  Future<void> _loadReceivedFiles() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      if (await dir.exists()) {
        final files = dir.listSync().whereType<File>();
        receivedFiles.clear();

        for (final file in files) {
          final stat = await file.stat();
          final fileName = p.basename(file.path);
          final fileSize = stat.size;

          // Determine file type
          String fileType = 'file';
          final ext = p.extension(fileName).toLowerCase();
          if (['.jpg', '.jpeg', '.png', '.gif'].contains(ext)) {
            fileType = 'image';
          } else if (['.mp4', '.avi', '.mov'].contains(ext)) {
            fileType = 'video';
          } else if (['.pdf', '.doc', '.docx'].contains(ext)) {
            fileType = 'document';
          }

          receivedFiles.add({
            'name': fileName,
            'path': file.path,
            'size': fileSize,
            'type': fileType,
            'timestamp': stat.modified,
          });
        }
        print('📁 Loaded ${receivedFiles.length} received files');
      }
    } catch (e) {
      print('❌ Error loading received files: $e');
    }
  }

  /// Sends a file to a receiver device over TCP
  ///
  /// **Purpose:** Connects to a receiver's TCP server (port 9090) and transmits file data.
  ///             First sends file metadata, then streams the file bytes, and waits for ACK.
  /// **Why:** This is the actual file transfer function that sends binary file data after
  ///          pairing/offer negotiation is complete
  /// **When called:** Called after PairingController.sendOffer() returns true (offer accepted)
  /// **Side:** SENDER side - sends files to receivers
  /// **Flow:** 1. Spawns isolate → 2. Connects to receiver TCP (port 9090) → 3. Sends metadata →
  ///          4. Streams file data in chunks → 5. Waits for ACK → 6. Closes connection
  /// **Note:** Runs in a background isolate to avoid blocking UI during large file transfers
  // Future<void> sendFile(String path, String ip, int port) async {
  //   print('📤 Starting file transfer: $path -> $ip:$port');
  //   _sendStream = StreamController<double>.broadcast();
  //   _sendStream!.stream.listen((v) => progress.sendProgress.value = v);
  //   _receivePort?.close();
  //   _receivePort = ReceivePort();
  //   _receivePort!.listen((dynamic msg) {
  //     if (msg is double) {
  //       _sendStream?.add(msg);
  //     } else if (msg is String) {
  //       if (msg == 'done') progress.status.value = 'sent';
  //       if (msg.startsWith('error')) progress.error.value = msg;
  //     }
  //   });
  //   await Isolate.spawn(_sendIsolate, {
  //     'path': path,
  //     'ip': ip,
  //     'port': port,
  //     'sendPort': _receivePort!.sendPort,
  //   });
  // }

  Future<void> sendFile(String path, String ip, int port) async {
    // ========== VALIDATION: Ensure all args are valid before proceeding ==========
    if (path.isEmpty) {
      final err = 'File path is empty. Cannot start transfer.';
      print('❌ sendFile validation failed: $err');
      progress.error.value = err;
      throw Exception(err);
    }
    if (ip.isEmpty) {
      final err = 'Target IP address is empty. Cannot connect to receiver.';
      print('❌ sendFile validation failed: $err');
      progress.error.value = err;
      throw Exception(err);
    }
    if (port <= 0 || port > 65535) {
      final err = 'Target port is invalid ($port). Must be 1-65535.';
      print('❌ sendFile validation failed: $err');
      progress.error.value = err;
      throw Exception(err);
    }

    print('📤 Starting file transfer: $path -> $ip:$port');
    print('🔍 DEBUG: sendFile params validated - path=$path, ip=$ip, port=$port');

    // Reset progress before starting
    progress.sendProgress.value = 0.0;
    progress.sentMB.value = 0.0;
    progress.speedMBps.value = 0.0;

    final file = File(path);
    if (!await file.exists()) {
      final err = 'File does not exist at path: $path';
      print('❌ sendFile validation failed: $err');
      progress.error.value = err;
      throw Exception(err);
    }
    final fileSize = await file.length(); // bytes
    final totalMB = fileSize / (1024 * 1024);
    progress.totalMB.value = totalMB;

    final startTime = DateTime.now(); // ⏱ start time
    DateTime lastUpdateTime = startTime;
    double lastSentMB = 0.0;

    final sendStream = StreamController<double>.broadcast();
    _sendStream = sendStream;
    sendStream.stream.listen((v) {
      /// v = progress (0.0 - 1.0)
      final now = DateTime.now();
      final elapsed = now.difference(startTime).inMilliseconds / 1000;

      // Update progress immediately
      progress.sendProgress.value = v;

      /// Convert to MB
      final sentBytes = fileSize * v;
      final sentMB = sentBytes / (1024 * 1024);
      progress.sentMB.value = sentMB;

      /// Calculate speed (throttle updates to every 100ms for smoother UI)
      final timeSinceLastUpdate = now.difference(lastUpdateTime).inMilliseconds;
      if (timeSinceLastUpdate >= 100 && elapsed > 0) {
        // Calculate speed based on recent progress
        final mbDelta = sentMB - lastSentMB;
        final timeDelta = timeSinceLastUpdate / 1000.0;

        if (timeDelta > 0) {
          progress.speedMBps.value = mbDelta / timeDelta;
        }

        lastUpdateTime = now;
        lastSentMB = sentMB;
      }

      progress.status.value = "Uploading...";
    });

    _receivePort?.close();
    final receivePort = ReceivePort();
    _receivePort = receivePort;

    receivePort.listen((dynamic msg) {
      if (msg is double) {
        // Progress update from isolate (0.0 - 1.0)
        _sendStream?.add(msg);
      } else if (msg is String) {
        if (msg == 'done') {
          progress.status.value = 'sent';
          progress.sendProgress.value = 1.0;
          progress.sentMB.value = totalMB;
          progress.speedMBps.value = 0;
        }
        if (msg.startsWith('error')) progress.error.value = msg;
      }
    });

    final isolateSendPort = receivePort.sendPort;
    print('🔍 DEBUG: About to spawn isolate - path=$path, ip=$ip, port=$port, hasSendPort=${isolateSendPort != null}');
    await Isolate.spawn(_sendIsolate, {
      'path': path,
      'ip': ip,
      'port': port,
      'sendPort': isolateSendPort,
    });
  }

  /// Opens file picker and returns selected file path
  ///
  /// **Purpose:** Handles file selection logic in the controller layer
  /// **Why:** Keeps file selection business logic out of UI
  /// **When called:** Called by initiateFileTransfer or directly for custom file selection
  /// **Side:** SENDER side - file selection
  /// **Returns:** File path if selected, null if cancelled
  Future<String?> selectFile({
    FileType type = FileType.any,
    List<String>? allowedExtensions,
  }) async {
    print(
      '📁 Opening file picker with type: $type, extensions: $allowedExtensions',
    );

    FilePickerResult? result;
    try {
      if (type == FileType.custom && allowedExtensions != null) {
        result = await FilePicker.platform.pickFiles(
          type: type,
          allowedExtensions: allowedExtensions,
          withReadStream: true,
        );
      } else {
        result = await FilePicker.platform.pickFiles(
          type: type,
          allowedExtensions: allowedExtensions,
          withReadStream: true,
        );
      }

      print(
        '📁 File picker result: ${result != null ? 'Success' : 'Cancelled'}',
      );
      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path;
        if (path == null || path.isEmpty) {
          print('⚠️ File picker returned null or empty path (e.g. web/streaming mode)');
          return null;
        }
        print('📁 Selected file path: $path');
        return path;
      }
    } catch (e) {
      print('❌ File picker error: $e');
      throw Exception('Failed to open file picker: $e');
    }

    return null;
  }

  /// Initiates a complete file transfer to a paired device
  ///
  /// **Purpose:** Handles the complete flow of selecting a file, sending offer, and transferring
  /// **Why:** Centralizes transfer coordination logic in the controller layer
  /// **When called:** Called from TransferScreen when user wants to send a file
  /// **Side:** SENDER side - coordinates file selection and transfer
  /// **Flow:** 1. Select file → 2. Send offer → 3. If accepted, transfer file
  Future<void> initiateFileTransfer(DeviceInfo targetDevice) async {
    try {
      if (!targetDevice.isValidForTransfer) {
        final err =
            'Target device has invalid connection info (IP or port missing/invalid)';
        print('❌ initiateFileTransfer: $err');
        progress.error.value = err;
        throw Exception(err);
      }

      // Step 1: Select file
      final filePath = await selectFile();
      if (filePath == null) {
        print('📁 File selection cancelled');
        return;
      }

      // Step 2: Create file metadata
      final file = File(filePath);
      final meta = FileMeta(
        name: p.basename(filePath),
        size: await file.length(),
        type: _extType(filePath),
      );

      // Step 3: Send offer and wait for response
      final pairing = Get.find<PairingController>();
      final accepted = await pairing.sendOffer(targetDevice, meta);

      if (accepted) {
        print('✅ Offer accepted! Starting file transfer...');
        // Step 4: Transfer the file
        await sendFile(filePath, targetDevice.ip, targetDevice.transferPort);
      } else {
        print('❌ Offer was rejected or timed out');
        throw Exception(
          'The receiving device did not accept the transfer or timed out',
        );
      }
    } catch (e) {
      print('❌ Error initiating transfer: $e');
      rethrow; // Let UI handle the error display
    }
  }

  /// Background isolate that handles the actual file transmission
  ///
  /// **Purpose:** Runs in a separate isolate to send file data over TCP without blocking the UI.
  ///             Reads file in chunks, sends to receiver, tracks progress, and waits for ACK.
  /// **Why:** Large file transfers can take time and would freeze the UI if done on main thread
  /// **When called:** Spawned by `sendFile()` function when sender initiates file transfer
  /// **Side:** SENDER side - handles file transmission in background
  /// **How:** Opens file, connects to receiver TCP socket, sends metadata + file data in 64KB chunks,
  ///         updates progress, waits for receiver ACK, then closes connection
  static void _sendIsolate(Map<String, dynamic> params) async {
    // Defensive logging: log param presence before any access
    print('🔍 DEBUG: _sendIsolate received params - hasSendPort=${params['sendPort'] != null}, hasPath=${params['path'] != null}, hasIp=${params['ip'] != null}, hasPort=${params['port'] != null}');

    final rawSendPort = params['sendPort'];
    final rawPath = params['path'];
    final rawIp = params['ip'];
    final rawPort = params['port'];

    if (rawSendPort == null || rawSendPort is! SendPort) {
      print('❌ CRITICAL: Isolate sendPort is null or invalid');
      return; // Cannot report error - no way to reach main isolate
    }
    final sendPort = rawSendPort;

    if (rawPath == null || rawPath is! String) {
      final error = 'Isolate: path is null or invalid type';
      print('❌ CRITICAL: $error');
      sendPort.send('error:$error');
      return;
    }
    final path = rawPath;

    if (rawIp == null || rawIp is! String) {
      final error = 'Isolate: ip is null or invalid type';
      print('❌ CRITICAL: $error');
      sendPort.send('error:$error');
      return;
    }
    final ip = rawIp;

    if (rawPort == null || (rawPort is! int && rawPort is! double)) {
      final error = 'Isolate: port is null or invalid type';
      print('❌ CRITICAL: $error');
      sendPort.send('error:$error');
      return;
    }
    final port = (rawPort is int) ? rawPort : (rawPort as double).toInt();

    print('🔍 DEBUG: _sendIsolate started with: path=$path, ip=$ip, port=$port');

    // ========== CRITICAL VALIDATION IN ISOLATE ==========
    // Validate parameters in isolate
    if (path.isEmpty) {
      final error = 'Isolate: File path is empty';
      print('❌ CRITICAL: $error');
      sendPort.send('error:$error');
      return;
    }

    if (ip.isEmpty) {
      final error = 'Isolate: IP address is empty';
      print('❌ CRITICAL: $error');
      sendPort.send('error:$error');
      return;
    }

    if (port <= 0 || port > 65535) {
      final error = 'Isolate: Invalid port number: $port';
      print('❌ CRITICAL: $error');
      sendPort.send('error:$error');
      return;
    }

    final file = File(path);
    if (!await file.exists()) {
      final error = 'Isolate: File does not exist at path: $path';
      print('❌ CRITICAL: $error');
      sendPort.send('error:$error');
      return;
    }

    final size = await file.length();
    if (size <= 0) {
      final error = 'Isolate: File is empty or size cannot be determined';
      print('❌ CRITICAL: $error');
      sendPort.send('error:$error');
      return;
    }

    print('✅ Isolate: All validations passed');
    print('✅ Isolate: File size: $size bytes');
    print('🔌 Connecting to receiver: $ip:$port');

    try {
      final socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(
          seconds: 10,
        ), // Increased timeout for Wi-Fi latency
      );
      print('✅ Connected to receiver TCP socket');
      socket.setOption(SocketOption.tcpNoDelay, true);

      // Send file metadata
      final meta = FileMeta(
        name: p.basename(path),
        size: size,
        type: _extType(path),
      );
      print('📤 Sending file metadata: ${meta.name} (${meta.size} bytes)');
      final metaJson = jsonEncode(meta.toJson());
      socket.write(metaJson);
      socket.write('\n');
      print('📤 Metadata sent: $metaJson');
      print('🔄 Starting file data transmission...');
      int sent = 0;
      final raf = await file.open();
      const chunkSize = 65536;
      int offset = 0;
      int flushCounter = 0;
      int progressUpdateCounter = 0;
      final startTime = DateTime.now();
      DateTime lastProgressUpdate = startTime;

      while (offset < size) {
        final n = (offset + chunkSize) > size ? (size - offset) : chunkSize;
        final data = await raf.read(n);
        if (data.isEmpty) break;
        socket.add(data);
        offset += data.length;
        sent += data.length;
        flushCounter++;
        progressUpdateCounter++;

        // Send progress updates more frequently for smooth UI (every chunk for small files,
        // every 2-4 chunks for larger files to avoid overwhelming the UI)
        final shouldUpdate =
            size <
                    10 *
                        1024 *
                        1024 // For files < 10MB, update every chunk
                ? true
                : progressUpdateCounter >=
                    2; // For larger files, update every 2 chunks

        if (shouldUpdate) {
          final progressValue = sent / size;
          sendPort.send(progressValue);
          progressUpdateCounter = 0;

          // Throttle progress updates to max 10 per second for very large files
          final now = DateTime.now();
          final timeSinceLastUpdate =
              now.difference(lastProgressUpdate).inMilliseconds;
          if (timeSinceLastUpdate < 100 && size > 50 * 1024 * 1024) {
            // For very large files (>50MB), add small delay to throttle updates
            await Future.delayed(const Duration(milliseconds: 50));
          }
          lastProgressUpdate = now;
        }

        // Flush every 4 chunks (256KB) to prevent buffer overflow
        if (flushCounter >= 4) {
          await socket.flush();
          flushCounter = 0;
        }

        // Log progress every 100KB
        if (sent % 102400 == 0 || sent == size) {
          print(
            '📤 Sent: $sent / $size bytes (${(sent / size * 100).toStringAsFixed(1)}%)',
          );
        }
      }

      // Ensure final progress update is sent
      sendPort.send(1.0);
      await raf.close();
      print('✅ File data transmission complete (${size} bytes sent)');

      // Final flush to ensure all data is sent
      await socket.flush();
      print('📤 All data flushed, waiting for receiver acknowledgment...');

      // Wait for acknowledgment from receiver (with timeout)
      final ackCompleter = Completer<void>();

      // Set up a timeout for acknowledgment
      final timeout = Timer(const Duration(seconds: 5), () {
        if (!ackCompleter.isCompleted) {
          print('⚠️ ACK timeout, closing socket anyway');
          ackCompleter.complete();
        }
      });

      // Listen for ACK response
      final ackSubscription = socket.listen(
        (data) {
          final response = utf8.decode(data).trim();
          if (response == '__ACK__') {
            print('✅ Received ACK from receiver');
            timeout.cancel();
            if (!ackCompleter.isCompleted) {
              ackCompleter.complete();
            }
          }
        },
        onError: (error) {
          print('❌ Socket error while waiting for ACK: $error');
          timeout.cancel();
          if (!ackCompleter.isCompleted) {
            ackCompleter.complete();
          }
        },
        onDone: () {
          print('📤 Socket closed while waiting for ACK');
          timeout.cancel();
          if (!ackCompleter.isCompleted) {
            ackCompleter.complete();
          }
        },
      );

      // Wait for acknowledgment or timeout
      await ackCompleter.future;
      await ackSubscription.cancel();

      // Now safely close the socket
      socket.destroy();
      print('✅ File sent successfully (${size} bytes)');
      sendPort.send('done');
    } catch (e) {
      print('❌ Error sending file: $e');
      sendPort.send('error:$e');
    }
  }

  /// Determines file type from file extension
  ///
  /// **Purpose:** Maps file extensions to file type categories (apk, video, image, file)
  /// **Why:** Used to categorize files for display and determine how to handle them
  /// **When called:** Called internally when creating FileMeta objects for file transfers
  /// **Side:** Used by both sender and receiver
  static String _extType(String path) {
    final ext = p.extension(path).toLowerCase();
    if (ext == '.apk') return 'apk';
    if (ext == '.mp4' || ext == '.mov') return 'video';
    if (ext == '.jpg' || ext == '.jpeg' || ext == '.png') return 'image';
    return 'file';
  }
}

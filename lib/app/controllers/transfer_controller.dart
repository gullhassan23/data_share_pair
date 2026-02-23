import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_app_latest/app/controllers/pairing_controller.dart';
import 'package:share_app_latest/services/transfer_foreground_service.dart';
import 'package:share_app_latest/services/transfer_state_persistence.dart';
import 'package:share_app_latest/services/transfer_temp_manager.dart';
import 'package:share_app_latest/routes/app_navigator.dart';
import 'package:share_app_latest/utils/constants.dart';

import '../models/file_meta.dart';
import '../models/device_info.dart';
import 'progress_controller.dart';

class TransferController extends GetxController {
  final sessionState = TransferSessionState.waiting.obs;
  final progress = Get.put(ProgressController());
  final isCancelled = false.obs;
  SendPort? _cancelSendPort;
  final receivedFiles = <Map<String, dynamic>>[].obs;
  ServerSocket? _server;
  final serverPort = 9090;
  ReceivePort? _receivePort;
  StreamController<double>? _sendStream;
  StreamController<double>? _recvStream;
  final _tempManager = TransferTempManager();

  Worker? _completionWorker;

  @override
  void onInit() {
    super.onInit();
    _completionWorker = ever<String>(progress.status, _onTransferStatusChanged);
  }

  @override
  void onClose() {
    _completionWorker?.dispose();
    super.onClose();
  }

  /// Handles transfer completion (sent/received) from a long-lived controller so completion
  /// runs even when TransferProgressScreen is disposed (e.g. app backgrounded).
  void _onTransferStatusChanged(String status) {
    final isSuccess = status == 'sent' || status == 'received';
    final hasError = progress.error.value.isNotEmpty;
    if (!isSuccess || hasError) return;

    if (status == 'sent') {
      print('✅ File successfully sent to receiver!');
      Get.snackbar(
        'Transfer Completed',
        'Your file transferred successfully 🎉',
        backgroundColor: Colors.green.withOpacity(0.8),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
      Future.delayed(const Duration(seconds: 2), () {
        AppNavigator.toHome();
      });
    } else if (status == 'received') {
      print('✅ File successfully received from sender!');
      Get.snackbar(
        'Transfer Completed',
        'File received successfully 🎉',
        backgroundColor: Colors.green.withOpacity(0.8),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
      Future.delayed(const Duration(seconds: 2), () {
        AppNavigator.toReceivedFiles(device: null);
      });
    }
  }

  Future<void> startServer() async {
    if (_server != null) {
      print('✅ TCP server already running on port $serverPort');
      return;
    }
    try {
      sessionState.value = TransferSessionState.waiting;
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
    }
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

        // Reset progress for new receiver connection (single source of truth; do not reset in UI dispose)
        progress.reset();
        progress.status.value = 'Receiving...';
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

                // Keep transfer alive when app is backgrounded
                await TransferForegroundService.startTransferNotification(
                  isSender: false,
                  fileName: meta.name,
                );
                await TransferStatePersistence.saveTransferStarted(
                  isSender: false,
                  fileName: meta.name,
                  totalBytes: meta.size,
                );

                // Initialize receiver progress tracking
                receiveStartTime = DateTime.now();
                lastReceiveProgressUpdate = receiveStartTime;
                final totalMB = meta.size / (1024 * 1024);
                progress.receiveTotalMB.value = totalMB;
                progress.status.value = 'Receiving...';

                // Initialize file saving (always use original filename from metadata)
                final dir = await getApplicationDocumentsDirectory();
                final fileName =
                    meta.name.isNotEmpty ? meta.name : 'received_file';
                savePath = p.join(dir.path, p.basename(fileName));
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

              // Write chunk to file
              sink!.add(chunk);
              received += chunk.length;

              // Log progress every 50 chunks or when near completion
              if (chunkCount % 50 == 0 || received >= meta!.size) {
                print(
                  '💾 Chunk $chunkCount: total $received / ${meta!.size} bytes (${(received / meta.size * 100).toStringAsFixed(1)}%)',
                );
              }

              // Update progress with real-time tracking
              final progressValue = received / meta.size;
              _recvStream?.add(progressValue);
              progress.receiveProgress.value = progressValue;
              TransferStatePersistence.updateProgress(progressValue);

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

              TransferForegroundService.updateProgress(
                fileName: meta.name,
                progress: progressValue,
                sentMB: receivedMB,
                totalMB: meta.size / (1024 * 1024),
                speedMBps: progress.receiveSpeedMBps.value,
                isSender: false,
              );

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

              // Add to received files list (use path basename if meta.name empty)
              receivedFiles.add({
                'name': meta.name.isNotEmpty ? meta.name : p.basename(savePath),
                'path': savePath,
                'size': actualSize,
                'type': meta.type,
                'timestamp': DateTime.now(),
              });
              print('📁 Added to received files list: ${meta.name}');

              // Auto-save images and videos to gallery
              await _autoSaveToGalleryIfMedia(savePath, meta.name);

              sessionState.value = TransferSessionState.completed;
              await TransferForegroundService.stopTransferNotification();
              await TransferStatePersistence.clearTransferState();
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
        sessionState.value = TransferSessionState.error;
        await TransferForegroundService.stopTransferNotification();
        await TransferStatePersistence.clearTransferState();
        if (sink != null) {
          await sink.close();
        }
        if (file != null && await file.exists()) {
          await file.delete();
        }
        client.destroy();
        progress.error.value =
            'Connection lost. The sender may have closed the app or turned off. Try again.';
      }
    });
  }

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

  Future<void> stopServer() async {
    await _server?.close();
    _server = null;
    sessionState.value = TransferSessionState.waiting;
    await _recvStream?.close();
  }

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
          if (['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(ext)) {
            fileType = 'image';
          } else if (['.mp4', '.avi', '.mov', '.mkv', '.webm'].contains(ext)) {
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

  /// [senderTempPath] If provided, deleted on success/error/cancel (no garbage)
  /// [originalFileName] Use when [path] is staging/temp; preserves real name in metadata
  Future<void> sendFile(
    String path,
    String ip,
    int port, {
    String? senderTempPath,
    String? originalFileName,
  }) async {
    print('📤 Starting file transfer: $path -> $ip:$port');

    if (senderTempPath != null) _tempManager.registerTemp(senderTempPath);

    // Reset progress when starting a new transfer (single source of truth; do not reset in UI dispose)
    progress.reset();
    isCancelled.value = false;
    sessionState.value = TransferSessionState.transferring;
    progress.sendProgress.value = 0.0;
    progress.sentMB.value = 0.0;
    progress.speedMBps.value = 0.0;

    final fileSize = await File(path).length(); // bytes
    final totalMB = fileSize / (1024 * 1024);
    progress.totalMB.value = totalMB;
    final fileName = originalFileName ?? p.basename(path);

    await TransferForegroundService.startTransferNotification(
      isSender: true,
      fileName: fileName,
    );
    await TransferStatePersistence.saveTransferStarted(
      isSender: true,
      fileName: fileName,
      totalBytes: fileSize,
    );

    final startTime = DateTime.now(); // ⏱ start time
    DateTime lastUpdateTime = startTime;
    double lastSentMB = 0.0;

    _sendStream = StreamController<double>.broadcast();
    _sendStream!.stream.listen((v) {
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
      TransferStatePersistence.updateProgress(v);
      TransferForegroundService.updateProgress(
        fileName: fileName,
        progress: v,
        sentMB: sentMB,
        totalMB: totalMB,
        speedMBps: progress.speedMBps.value,
        isSender: true,
      );
    });

    _receivePort?.close();
    _receivePort = ReceivePort();

    final completer = Completer<void>();
    _receivePort!.listen((dynamic msg) {
      if (msg is double) {
        // Progress update from isolate (0.0 - 1.0)
        _sendStream?.add(msg);
      } else if (msg is String) {
        if (msg == 'done') {
          progress.status.value = 'sent';
          progress.sendProgress.value = 1.0;
          progress.sentMB.value = totalMB;
          progress.speedMBps.value = 0;
          sessionState.value = TransferSessionState.completed;
          _tempManager.cleanupCurrentSession();
          TransferForegroundService.stopTransferNotification();
          TransferStatePersistence.clearTransferState();
          if (!completer.isCompleted) completer.complete();
        }
        if (msg.startsWith('error')) {
          progress.error.value = msg.length > 6 ? msg.substring(6) : msg;
          sessionState.value = TransferSessionState.error;
          _tempManager.cleanupCurrentSession();
          TransferForegroundService.stopTransferNotification();
          TransferStatePersistence.clearTransferState();
          if (!completer.isCompleted) completer.complete();
        }
      }
    });

    await Isolate.spawn(_sendIsolate, {
      'path': path,
      'ip': ip,
      'port': port,
      'sendPort': _receivePort!.sendPort,
      'originalFileName': originalFileName ?? p.basename(path),
    });

    await completer.future;
  }

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
          withReadStream: true,
        );
      }

      print(
        '📁 File picker result: ${result != null ? 'Success' : 'Cancelled'}',
      );
      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path;
        print('📁 Selected file path: $path');
        return path;
      }
    } catch (e) {
      print('❌ File picker error: $e');
      throw Exception('Failed to open file picker: $e');
    }

    return null;
  }

  Future<void> initiateFileTransfer(DeviceInfo targetDevice) async {
    try {
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
        print('✅ Offer accepted! Navigating to transfer progress...');
        sessionState.value = TransferSessionState.transferring;
        await AppNavigator.toTransferProgress(
          device: targetDevice,
          filePath: filePath,
          fileName: p.basename(filePath),
        );
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

  /// Max connection attempts (initial + retries)
  static const int _senderMaxAttempts = 3;
  /// Backoff delays in ms between attempts: after 1st failure wait 2s, after 2nd wait 5s
  static const List<int> _senderBackoffMs = [2000, 5000];

  static void _sendIsolate(Map<String, dynamic> params) async {
    final sendPort = params['sendPort'] as SendPort;
    final path = params['path'] as String;
    final ip = params['ip'] as String;
    final port = params['port'] as int;
    final originalFileName = params['originalFileName'] as String?;
    final file = File(path);
    final size = await file.length();
    Socket? socket;
    Exception? lastError;
    for (int attempt = 1; attempt <= _senderMaxAttempts; attempt++) {
      print('🔌 Connecting to receiver: $ip:$port (attempt $attempt/$_senderMaxAttempts)');
      try {
        socket = await Socket.connect(
          ip,
          port,
          timeout: const Duration(seconds: 10),
        );
        print('✅ Connected to receiver TCP socket');
        lastError = null;
        break;
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        print('❌ Connection attempt $attempt failed: $e');
        if (attempt < _senderMaxAttempts) {
          final delayMs = _senderBackoffMs[attempt - 1];
          print('⏳ Retrying in ${delayMs}ms...');
          await Future.delayed(Duration(milliseconds: delayMs));
        }
      }
    }
    if (socket == null) {
      final msg = lastError != null
          ? 'Connection lost. The other device may be off or the app closed. Try again.'
          : 'Could not connect to receiver. Try again.';
      print('❌ Error sending file after $_senderMaxAttempts attempts: $lastError');
      sendPort.send('error:$msg');
      return;
    }
    try {
      socket.setOption(SocketOption.tcpNoDelay, true);

      // Send file metadata (always use original filename, never staging path basename)
      final meta = FileMeta(
        name: originalFileName ?? p.basename(path),
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
      final msg = e is SocketException
          ? 'Connection lost. The other device may be off or the app closed. Try again.'
          : (e is Exception ? e.toString() : 'Transfer failed. Try again.');
      sendPort.send('error:$msg');
    } finally {
      socket.destroy();
    }
  }

  static String _extType(String path) {
    final ext = p.extension(path).toLowerCase();
    if (ext == '.apk') return 'apk';
    if (ext == '.mp4' || ext == '.mov') return 'video';
    if (ext == '.jpg' || ext == '.jpeg' || ext == '.png') return 'image';
    return 'file';
  }

  void cancelTransfer() {
    print('🛑 User requested transfer cancel');

    isCancelled.value = true;
    sessionState.value = TransferSessionState.error;
    progress.status.value = 'cancelled';

    _tempManager.cleanupCurrentSession();
    _cancelSendPort?.send('cancel');

    _sendStream?.close();
    _recvStream?.close();

    progress.sendProgress.value = 0;
    progress.receiveProgress.value = 0;

    TransferForegroundService.stopTransferNotification();
    TransferStatePersistence.clearTransferState();
  }
}

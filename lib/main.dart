import 'dart:async';
import 'dart:collection';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:image/image.dart' as img;
import 'dart:math';

// --- Data Structures for Isolate Communication ---

/// Data sent TO the isolate for processing.
class ProcessingRequest {
  final Uint8List imageBytes;
  final Rect boundingBox;
  final SendPort sendPort; // Port to send the result back

  ProcessingRequest(this.imageBytes, this.boundingBox, this.sendPort);
}

/// Data received FROM the isolate after processing.
class ProcessingResult {
  final Uint8List? thumbnailBytes;
  final String? apiResponse;
  final String? errorMessage;

  ProcessingResult({this.thumbnailBytes, this.apiResponse, this.errorMessage});
}

// --- Isolate Function ---

/// This is the function that will run in the background isolate.
/// It performs all heavy CPU-bound work.
void processImageInIsolate(ProcessingRequest request) async {
  try {
    // 1. Decode the image
    final originalImage = img.decodeImage(request.imageBytes);
    if (originalImage == null) {
      throw Exception('Failed to decode image');
    }

    // 2. Crop the image using the bounding box
    final box = request.boundingBox;
    final croppedImage = img.copyCrop(
      originalImage,
      x: box.left.toInt(),
      y: box.top.toInt(),
      width: box.width.toInt(),
      height: box.height.toInt(),
    );

    // 3. Add padding (letterboxing) to make it a square
    final int size = max(croppedImage.width, croppedImage.height);
    final paddedImage =
        img.Image(width: size, height: size); // Black background
    final int offsetX = (size - croppedImage.width) ~/ 2;
    final int offsetY = (size - croppedImage.height) ~/ 2;
    img.compositeImage(paddedImage, croppedImage, dstX: offsetX, dstY: offsetY);

    // 4. Encode the final thumbnail to PNG bytes
    final thumbnailBytes = Uint8List.fromList(img.encodePng(paddedImage));

    // 5. --- YOUR API CALL GOES HERE ---
    // This is a placeholder for your actual API call.
    await Future.delayed(
        const Duration(milliseconds: 500)); // Simulate network latency
    final apiResponse = "PLATE-XYZ-123"; // Simulated API result

    // 6. Send the successful result back to the main thread
    request.sendPort.send(ProcessingResult(
      thumbnailBytes: thumbnailBytes,
      apiResponse: apiResponse,
    ));
  } catch (e) {
    // If anything goes wrong, send an error result back
    request.sendPort.send(ProcessingResult(errorMessage: e.toString()));
  }
}

// --- Main App ---

void main() => runApp(MaterialApp(home: MyWidget()));

class MyWidget extends StatefulWidget {
  const MyWidget({super.key});

  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  // Using a Map to store thumbnails with a unique key (timestamp) to avoid duplicates
  final LinkedHashMap<int, Uint8List> _detectionThumbnails = LinkedHashMap();
  final int _maxThumbnails = 10;

  DateTime _lastProcessingTime = DateTime.now();
  final Duration _processingCooldown =
      const Duration(seconds: 1); // Process one detection per second

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('YOLO Detection & Cropping')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          YOLOView(
            modelPath: 'yolo11n',
            task: YOLOTask.detect,
            showNativeUI: false,
            streamingConfig: const YOLOStreamingConfig(
              includeOriginalImage: true,
              includeDetections: true,
            ),
            onStreamingData: _processFrameAndDetections,
          ),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: _buildDetectionCarousel(),
          ),
        ],
      ),
    );
  }

  void _processFrameAndDetections(Map<String, dynamic> streamData) {
    final originalImageBytes = streamData['originalImage'] as Uint8List?;
    final detections = (streamData['detections'] as List? ?? [])
        .map((d) => YOLOResult.fromMap(d))
        .toList();

    if (originalImageBytes == null || detections.isEmpty) {
      return;
    }

    // Throttle the processing to avoid overwhelming the system
    if (DateTime.now().difference(_lastProcessingTime) < _processingCooldown) {
      return;
    }
    _lastProcessingTime = DateTime.now();

    // For this example, we process the first detected object
    final firstDetection = detections.first;
    _spawnIsolateForProcessing(firstDetection, originalImageBytes);
  }

  Future<void> _spawnIsolateForProcessing(
      YOLOResult detection, Uint8List imageBytes) async {
    final receivePort = ReceivePort();

    await Isolate.spawn(
      processImageInIsolate,
      ProcessingRequest(
          imageBytes, detection.boundingBox, receivePort.sendPort),
    );

    receivePort.listen((message) {
      if (message is ProcessingResult) {
        if (message.thumbnailBytes != null) {
          // We have our cropped image bytes, now update the UI
          if (mounted) {
            setState(() {
              final key = DateTime.now().millisecondsSinceEpoch;
              _detectionThumbnails[key] = message.thumbnailBytes!;
              if (_detectionThumbnails.length > _maxThumbnails) {
                _detectionThumbnails.remove(_detectionThumbnails.keys.first);
              }
            });
            // You can now use the API response
            print("Received API Response: ${message.apiResponse}");
          }
        } else {
          print("Isolate processing failed: ${message.errorMessage}");
        }
      }
      receivePort.close();
    });
  }

  Widget _buildDetectionCarousel() {
    final thumbnails = _detectionThumbnails.values.toList().reversed.toList();

    return Container(
      height: 120,
      color: Colors.black.withOpacity(0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 16, top: 8, bottom: 4),
            child: Text(
              'Recent Detections',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: thumbnails.isEmpty
                ? const Center(
                    child: Text(
                      'No objects detected yet.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: thumbnails.length,
                    itemBuilder: (context, index) {
                      final thumbnailBytes = thumbnails[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 8),
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.memory(
                              thumbnailBytes,
                              fit: BoxFit
                                  .contain, // Use contain to see the padding
                              gaplessPlayback: true,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

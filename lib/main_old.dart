import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'tracker.dart';
import 'widgets.dart';
import 'dart:ui' as ui;

void main() => runApp(YOLODemo());

class YOLODemo extends StatefulWidget {
  @override
  _YOLODemoState createState() => _YOLODemoState();
}

class _YOLODemoState extends State<YOLODemo> {
  bool isCameraReady = true;
  final _tracker = IoUTracker(
    iouThreshold: 0.5, // Increased for more stable tracking
    maxMisses: 10,
  );

  int _totalDetections = 0;
  String _lastDetected = "Ninguno";
  double _currentFPS = 0.0;
  double _processingTimeMs = 0.0;
  String _performanceRating = "Iniciando...";

  List<TrackedObject> _activeTracks = [];
  List<TrackedObject> _lostTracks = [];

  Timer? _uiUpdateTimer;

  @override
  void initState() {
    super.initState();
    _uiUpdateTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (mounted) {
        setState(() {
          _activeTracks = List.from(_tracker.tracks);
          _lostTracks = List.from(_tracker.lostTracks);
        });
      }
    });
  }

  @override
  void dispose() {
    _uiUpdateTimer?.cancel();
    super.dispose();
  }

  void _processFrameData(Map<String, dynamic> data) {
    final rawDetections = data['detections'] as List? ?? [];
    _currentFPS = (data['fps'] as num?)?.toDouble() ?? _currentFPS;
    _processingTimeMs =
        (data['processingTimeMs'] as num?)?.toDouble() ?? _processingTimeMs;
    _performanceRating = _getPerformanceRating(_currentFPS, _processingTimeMs);

    final yoloDetections =
        rawDetections.map((d) => YOLOResult.fromMap(d)).toList();

    final activeTracks = _tracker.update(yoloDetections);

    _totalDetections = yoloDetections.length;
    if (yoloDetections.isNotEmpty) {
      _lastDetected = yoloDetections.first.className;
    }

    // MODIFIED: Re-enabled image processing
    final originalImage = data['originalImage'] as Uint8List?;
    if (originalImage != null && activeTracks.isNotEmpty) {
      _generateRealThumbnails(activeTracks, originalImage);
    }
  }

  void _generateRealThumbnails(
      List<TrackedObject> tracks, Uint8List originalImage) {
    for (final track in tracks) {
      if (!track.thumbnailCaptured) {
        _createRealThumbnail(track, originalImage);
      }
    }
  }

  Future<void> _createRealThumbnail(
      TrackedObject track, Uint8List originalImage) async {
    try {
      final codec = await ui.instantiateImageCodec(originalImage);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      // Use absolute pixel coordinates for cropping
      final box = track.box;
      final cropRect = Rect.fromLTRB(
        box.left.clamp(0, image.width.toDouble()),
        box.top.clamp(0, image.height.toDouble()),
        box.right.clamp(0, image.width.toDouble()),
        box.bottom.clamp(0, image.height.toDouble()),
      );

      if (cropRect.width <= 0 || cropRect.height <= 0) return;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const thumbnailSize = 80.0;
      final srcRect = cropRect;
      final dstRect = Rect.fromLTWH(0, 0, thumbnailSize, thumbnailSize);
      canvas.drawImageRect(image, srcRect, dstRect, Paint());

      final picture = recorder.endRecording();
      final thumbnailImage =
          await picture.toImage(thumbnailSize.toInt(), thumbnailSize.toInt());
      final byteData =
          await thumbnailImage.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        track.setThumbnail(byteData.buffer.asUint8List());
      }
    } catch (e) {
      print('❌ Error generating thumbnail for track ${track.id}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('YOLO Demo con Tracking')),
        body: Column(
          children: [
            _buildPerformanceBar(),
            _buildTrackingStatus(),
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      YOLOView(
                        modelPath: 'yolo11n',
                        task: YOLOTask.detect,
                        showNativeUI: false,
                        confidenceThreshold: 0.5,
                        iouThreshold: 0.45,
                        streamingConfig: const YOLOStreamingConfig(
                          includeOriginalImage: true, // RE-ENABLED
                          includeDetections: true,
                        ),
                        onStreamingData: _processFrameData,
                      ),
                      if (_activeTracks.isNotEmpty)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: DebugTrackingPainter(_activeTracks),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            DetectionCarousel(lostTracks: _lostTracks),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // Helper methods to build UI parts
  Widget _buildPerformanceBar() {
    return Container(
      // ... (your existing performance bar code) ...
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.blue.shade50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('FPS: ${_currentFPS.toStringAsFixed(1)}'),
          Text('${_processingTimeMs.toStringAsFixed(0)}ms'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _getPerformanceColor(),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_performanceRating,
                style: const TextStyle(color: Colors.white, fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingStatus() {
    return Container(
      // ... (your existing tracking status code) ...
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Estado del Tracking',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Detectados: $_totalDetections objetos'),
          Text('Activos: ${_activeTracks.length}'),
          Text('Último: $_lastDetected'),
          Text('Histórico: ${_lostTracks.length} objetos'),
        ],
      ),
    );
  }

  Color _getPerformanceColor() {
    if (_currentFPS >= 20) return Colors.green;
    if (_currentFPS >= 15) return Colors.orange;
    return Colors.red;
  }

  String _getPerformanceRating(double fps, double timeMs) {
    if (fps >= 20 && timeMs <= 50) return "Excelente";
    if (fps >= 15 && timeMs <= 100) return "Bueno";
    if (fps >= 10 && timeMs <= 150) return "Regular";
    return "Bajo";
  }
}

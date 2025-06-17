// lib/tracker.dart
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart'; // For Rect and Offset
import 'package:ultralytics_yolo/yolo.dart'; // For YOLOResult
import 'package:simple_kalman/simple_kalman.dart'; // for smoothing

class TrackedObject {
  int id;
  int classIndex;
  String className;
  Rect box;
  Rect? normalizedBox;
  double confidence;
  int misses; // how many frames it has not been matched

  // Kalman filters for smooth tracking
  final SimpleKalman _kfCenterX;
  final SimpleKalman _kfCenterY;
  final SimpleKalman _kfWidth;
  final SimpleKalman _kfHeight;

  // For storing cropped thumbnail
  Uint8List? thumbnail;
  DateTime lastSeen;
  DateTime firstSeen;
  bool thumbnailCaptured = false;

  // Track frame count for this object
  int frameCount = 0;

  TrackedObject(
      this.id, this.classIndex, this.className, this.box, this.confidence,
      {this.normalizedBox})
      : misses = 0,
        lastSeen = DateTime.now(),
        firstSeen = DateTime.now(),
        // Configure Kalman filters with appropriate parameters for object tracking
        _kfCenterX =
            SimpleKalman(errorMeasure: 0.1, errorEstimate: 0.5, q: 0.008),
        _kfCenterY =
            SimpleKalman(errorMeasure: 0.1, errorEstimate: 0.5, q: 0.008),
        _kfWidth = SimpleKalman(errorMeasure: 0.2, errorEstimate: 1.0, q: 0.01),
        _kfHeight =
            SimpleKalman(errorMeasure: 0.2, errorEstimate: 1.0, q: 0.01);

  void update(Rect newBox, double newConf, {Rect? newNormalizedBox}) {
    frameCount++;

    // Apply Kalman filtering to smooth the bounding box
    final centerX = (newBox.left + newBox.right) / 2;
    final centerY = (newBox.top + newBox.bottom) / 2;
    final width = newBox.width;
    final height = newBox.height;

    // Filter the values
    final smoothedCenterX = _kfCenterX.filtered(centerX);
    final smoothedCenterY = _kfCenterY.filtered(centerY);
    final smoothedWidth = _kfWidth.filtered(width);
    final smoothedHeight = _kfHeight.filtered(height);

    // Reconstruct the smoothed bounding box
    final smoothedLeft = smoothedCenterX - smoothedWidth / 2;
    final smoothedTop = smoothedCenterY - smoothedHeight / 2;
    final smoothedRight = smoothedCenterX + smoothedWidth / 2;
    final smoothedBottom = smoothedCenterY + smoothedHeight / 2;

    box =
        Rect.fromLTRB(smoothedLeft, smoothedTop, smoothedRight, smoothedBottom);

    // También actualizar las coordenadas normalizadas si están disponibles
    if (newNormalizedBox != null) {
      normalizedBox = newNormalizedBox;
    }

    confidence = newConf;
    misses = 0;
    lastSeen = DateTime.now();
  }

  // Get display color for this track
  Color get displayColor {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.amber,
    ];
    return colors[id % colors.length];
  }

  // Get duration being tracked
  Duration get trackingDuration => lastSeen.difference(firstSeen);

  // Set thumbnail from captured image
  void setThumbnail(Uint8List imageData) {
    thumbnail = imageData;
    thumbnailCaptured = true;
  }

  // Create a synthetic thumbnail as placeholder
  Future<Uint8List> createSyntheticThumbnail() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Create a 60x60 thumbnail
    const size = 60.0;

    // Background with object color
    final bgPaint = Paint()..color = displayColor.withOpacity(0.3);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, size, size),
        const Radius.circular(8),
      ),
      bgPaint,
    );

    // Border
    final borderPaint = Paint()
      ..color = displayColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(1, 1, size - 2, size - 2),
        const Radius.circular(7),
      ),
      borderPaint,
    );

    // ID text (large)
    final idTextPainter = TextPainter(
      text: TextSpan(
        text: '$id',
        style: TextStyle(
          color: displayColor,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    idTextPainter.layout();
    idTextPainter.paint(canvas, Offset((size - idTextPainter.width) / 2, 8));

    // Class name (smaller)
    final classTextPainter = TextPainter(
      text: TextSpan(
        text: className,
        style: TextStyle(
          color: displayColor,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    classTextPainter.layout();
    classTextPainter.paint(
        canvas, Offset((size - classTextPainter.width) / 2, size - 20));

    // Confidence indicator (small dots)
    final dotPaint = Paint()..color = displayColor;
    final confLevel = (confidence * 5).round(); // 0-5 dots
    for (int i = 0; i < confLevel; i++) {
      canvas.drawCircle(Offset(10 + i * 8, size - 6), 2, dotPaint);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  // Ensure thumbnail is generated when object is first created or updated
  Future<void> ensureThumbnail() async {
    if (!thumbnailCaptured && thumbnail == null) {
      thumbnail = await createSyntheticThumbnail();
      thumbnailCaptured = true;
    }
  }
}

class IoUTracker {
  final _tracks = <TrackedObject>[];
  final _lostTracks = <TrackedObject>[]; // For carousel
  int _nextId = 0;

  // thresholds
  final double iouThreshold;
  final int maxMisses;
  final int maxLostTracks;

  IoUTracker(
      {this.iouThreshold = 0.3,
      this.maxMisses = 8, // Reduced for quicker removal
      this.maxLostTracks = 15 // Reduced for automatic cleanup
      });

  // Public getters
  List<TrackedObject> get tracks => _tracks;
  List<TrackedObject> get lostTracks => _lostTracks;

  /// Call this on every onResult() from YOLOView
  List<TrackedObject> update(List<YOLOResult> detections) {
    print('🔍 Tracker input: ${detections.length} detecciones del modelo');

    // Las detecciones ya vienen filtradas por el modelo nativo
    // NO aplicamos filtro adicional aquí

    if (detections.isNotEmpty) {
      print('📝 Detecciones para tracking:');
      for (final det in detections) {
        print(
            '  - ${det.className}: ${(det.confidence * 100).toStringAsFixed(1)}% en ${det.boundingBox}');
      }
    }

    // 1. Match each detection to the best track (greedy IoU)
    final unmatchedDet = <YOLOResult>{...detections};
    final unmatchedTrk = <TrackedObject>{..._tracks};

    for (final det in detections) {
      TrackedObject? best;
      double bestIoU = 0;
      for (final trk in unmatchedTrk) {
        final iou = _iou(det.boundingBox, trk.box);
        if (iou > bestIoU) {
          bestIoU = iou;
          best = trk;
        }
      }
      if (bestIoU > iouThreshold && best != null) {
        best.update(det.boundingBox, det.confidence,
            newNormalizedBox: det.normalizedBox);
        unmatchedDet.remove(det);
        unmatchedTrk.remove(best);
        print(
            '🔄 Match: ${det.className} → Track ID ${best.id} (IoU: ${bestIoU.toStringAsFixed(2)})');
      }
    }

    // 2. Create new tracks for unmatched detections
    for (final det in unmatchedDet) {
      final newTrack = TrackedObject(_nextId++, det.classIndex, det.className,
          det.boundingBox, det.confidence,
          normalizedBox: det.normalizedBox);
      newTrack.ensureThumbnail(); // Generate thumbnail
      _tracks.add(newTrack);
      print(
          '✨ New track: ID ${newTrack.id} (${newTrack.className}) conf=${(newTrack.confidence * 100).toStringAsFixed(1)}%');
    }

    // 3. Age & remove unmatched tracks
    for (final t in unmatchedTrk) {
      t.misses++;
      if (t.misses <= maxMisses) {
        print('⏳ Track ID ${t.id} missed (${t.misses}/$maxMisses)');
      }
    }

    // Move lost tracks to carousel before removing
    final lostTracks = _tracks.where((t) => t.misses > maxMisses).toList();
    for (final lost in lostTracks) {
      lost.ensureThumbnail(); // Ensure thumbnail before moving to carousel
      _lostTracks.insert(0, lost); // Add to beginning
      print(
          '📦 Track lost: ID ${lost.id} (${lost.className}) - tracked for ${lost.frameCount} frames');
    }

    // Automatic cleanup: Keep only the most recent lost tracks
    _autoCleanupLostTracks();

    _tracks.removeWhere((t) => t.misses > maxMisses);

    if (_tracks.isNotEmpty) {
      print(
          '🎯 Active tracks: ${_tracks.map((t) => 'ID${t.id}:${t.className}').join(', ')}');
    } else {
      print('🎯 No active tracks');
    }

    return _tracks;
  }

  /// Automatic cleanup of lost tracks - removes oldest when limit exceeded
  void _autoCleanupLostTracks() {
    if (_lostTracks.length > maxLostTracks) {
      final removedCount = _lostTracks.length - maxLostTracks;
      _lostTracks.removeRange(maxLostTracks, _lostTracks.length);
      print('🧹 Auto cleanup: Removed $removedCount old track(s) from history');
    }
  }

  double _iou(Rect a, Rect b) {
    final inter = Rect.fromLTRB(
      max(a.left, b.left),
      max(a.top, b.top),
      min(a.right, b.right),
      min(a.bottom, b.bottom),
    );
    if (inter.width <= 0 || inter.height <= 0) return 0;
    final i = inter.width * inter.height;
    final u = a.width * a.height + b.width * b.height - i;
    return i / u;
  }

  // Manual clear for reset functionality
  void clearHistory() {
    final count = _lostTracks.length;
    _lostTracks.clear();
    print('🗑️ Manual cleanup: Cleared $count track(s) from history');
  }

  // Clear all tracks (reset tracker)
  void reset() {
    final activeCount = _tracks.length;
    final historyCount = _lostTracks.length;
    _tracks.clear();
    _lostTracks.clear();
    _nextId = 0;
    print(
        '🔄 Tracker reset: Cleared $activeCount active + $historyCount history tracks');
  }

  // Get tracker statistics
  Map<String, dynamic> getStats() {
    return {
      'active_tracks': _tracks.length,
      'lost_tracks': _lostTracks.length,
      'next_id': _nextId,
      'iou_threshold': iouThreshold,
      'max_misses': maxMisses,
      'max_lost_tracks': maxLostTracks,
    };
  }
}

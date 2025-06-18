// lib/tracker.dart
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/yolo.dart';
import 'package:simple_kalman/simple_kalman.dart';

class TrackedObject {
  int id;
  int classIndex;
  String className;
  Rect box;
  Rect normalizedBox; // Made non-nullable
  double confidence;
  int misses;

  final SimpleKalman _kfCenterX;
  final SimpleKalman _kfCenterY;
  final SimpleKalman _kfWidth;
  final SimpleKalman _kfHeight;

  Uint8List? thumbnail;
  DateTime lastSeen;
  DateTime firstSeen;
  bool thumbnailCaptured = false;
  int frameCount = 0;

  TrackedObject(
      this.id, this.classIndex, this.className, this.box, this.confidence,
      {required this.normalizedBox})
      : misses = 0,
        lastSeen = DateTime.now(),
        firstSeen = DateTime.now(),
        _kfCenterX = SimpleKalman(errorMeasure: 2, errorEstimate: 4, q: 0.15),
        _kfCenterY = SimpleKalman(errorMeasure: 2, errorEstimate: 4, q: 0.15),
        _kfWidth = SimpleKalman(errorMeasure: 4, errorEstimate: 8, q: 0.2),
        _kfHeight = SimpleKalman(errorMeasure: 4, errorEstimate: 8, q: 0.2);

  void update(Rect newBox, double newConf, {required Rect newNormalizedBox}) {
    frameCount++;

    // Kalman filter should operate on consistent coordinates. Let's use normalized.
    final centerX = newNormalizedBox.center.dx;
    final centerY = newNormalizedBox.center.dy;
    final width = newNormalizedBox.width;
    final height = newNormalizedBox.height;

    final smoothedCenterX = _kfCenterX.filtered(centerX);
    final smoothedCenterY = _kfCenterY.filtered(centerY);
    final smoothedWidth = _kfWidth.filtered(width);
    final smoothedHeight = _kfHeight.filtered(height);

    normalizedBox = Rect.fromCenter(
        center: Offset(smoothedCenterX, smoothedCenterY),
        width: smoothedWidth,
        height: smoothedHeight);

    // Update pixel box based on new normalized box
    box = newBox; // We can just use the latest pixel box for display

    confidence = newConf;
    misses = 0;
    lastSeen = DateTime.now();
  }

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

  Duration get trackingDuration => lastSeen.difference(firstSeen);

  void setThumbnail(Uint8List imageData) {
    thumbnail = imageData;
    thumbnailCaptured = true;
  }
}

class IoUTracker {
  final _tracks = <TrackedObject>[];
  final _lostTracks = <TrackedObject>[];
  int _nextId = 0;

  final double iouThreshold;
  final int maxMisses;
  final int maxLostTracks;
  final double nmsThreshold;

  IoUTracker({
    this.iouThreshold = 0.4,
    this.maxMisses = 10,
    this.maxLostTracks = 15,
    this.nmsThreshold = 0.45,
  });

  List<TrackedObject> get tracks => _tracks;
  List<TrackedObject> get lostTracks => _lostTracks;

  List<YOLOResult> _nonMaxSuppression(List<YOLOResult> detections) {
    if (detections.isEmpty) return [];
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));
    final List<YOLOResult> nmsDetections = [];
    final List<bool> isSuppressed = List.filled(detections.length, false);
    for (int i = 0; i < detections.length; i++) {
      if (isSuppressed[i]) continue;
      nmsDetections.add(detections[i]);
      for (int j = i + 1; j < detections.length; j++) {
        if (isSuppressed[j]) continue;
        // CORRECTED: Use normalizedBox for IoU calculation
        final iou =
            _iou(detections[i].normalizedBox, detections[j].normalizedBox);
        if (iou > nmsThreshold) {
          isSuppressed[j] = true;
        }
      }
    }
    return nmsDetections;
  }

  List<TrackedObject> update(List<YOLOResult> detections) {
    final cleanDetections = _nonMaxSuppression(detections);

    final unmatchedDet = <YOLOResult>{...cleanDetections};
    final unmatchedTrk = <TrackedObject>{..._tracks};

    for (final det in cleanDetections) {
      TrackedObject? best;
      double bestIoU = 0;
      for (final trk in unmatchedTrk) {
        if (det.className != trk.className) continue;
        // CORRECTED: Use normalizedBox for IoU calculation
        final iou = _iou(det.normalizedBox, trk.normalizedBox);
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
      }
    }

    for (final det in unmatchedDet) {
      final newTrack = TrackedObject(
        _nextId++,
        det.classIndex,
        det.className,
        det.boundingBox,
        det.confidence,
        normalizedBox: det.normalizedBox,
      );
      _tracks.add(newTrack);
    }

    for (final t in unmatchedTrk) {
      t.misses++;
    }

    final lost = _tracks.where((t) => t.misses > maxMisses).toList();
    for (final l in lost) {
      _lostTracks.insert(0, l);
    }
    _autoCleanupLostTracks();
    _tracks.removeWhere((t) => t.misses > maxMisses);

    return _tracks;
  }

  void _autoCleanupLostTracks() {
    if (_lostTracks.length > maxLostTracks) {
      _lostTracks.removeRange(maxLostTracks, _lostTracks.length);
    }
  }

  double _iou(Rect a, Rect b) {
    final inter = a.intersect(b);
    if (inter.width <= 0 || inter.height <= 0) return 0;
    final i = inter.width * inter.height;
    final u = a.width * a.height + b.width * b.height - i;
    return i / u;
  }

  void reset() {
    _tracks.clear();
    _lostTracks.clear();
    _nextId = 0;
  }
}

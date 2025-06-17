// lib/tracker.dart
import 'dart:math';
import 'package:flutter/material.dart'; // For Rect and Offset
import 'package:ultralytics_yolo/yolo.dart'; // For YOLOResult
import 'package:simple_kalman/simple_kalman.dart'; // optional smoothing

class TrackedObject {
  int id;
  int classIndex;
  String className;
  Rect box;
  double confidence;
  int misses; // how many frames it has not been matched
  final _kf = SimpleKalman(
      errorMeasure: 0.008,
      errorEstimate: 3,
      q: 0.1); // 1-D KF for smoothing centre-x

  TrackedObject(
      this.id, this.classIndex, this.className, this.box, this.confidence)
      : misses = 0;

  void update(Rect newBox, double newConf) {
    // simple smoothing on centre-x
    final cx = (newBox.left + newBox.right) / 2;
    final smoothedCx = _kf.filtered(cx);
    final dx = smoothedCx - cx;
    box = newBox.shift(Offset(dx, 0));
    confidence = newConf;
    misses = 0;
  }
}

class IoUTracker {
  final _tracks = <TrackedObject>[];
  int _nextId = 0;

  // thresholds
  final double iouThreshold;
  final int maxMisses;
  IoUTracker({this.iouThreshold = .3, this.maxMisses = 10});

  // Public getter for tracks
  List<TrackedObject> get tracks => _tracks;

  /// Call this on every onResult() from YOLOView
  List<TrackedObject> update(List<YOLOResult> detections) {
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
        best.update(det.boundingBox, det.confidence);
        unmatchedDet.remove(det);
        unmatchedTrk.remove(best);
      }
    }

    // 2. Create new tracks for unmatched detections
    for (final det in unmatchedDet) {
      _tracks.add(TrackedObject(_nextId++, det.classIndex, det.className,
          det.boundingBox, det.confidence));
    }

    // 3. Age & remove unmatched tracks
    for (final t in _tracks) {
      t.misses++;
    }
    _tracks.removeWhere((t) => t.misses > maxMisses);

    return _tracks;
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
}

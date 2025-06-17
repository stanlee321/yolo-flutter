import 'package:flutter/material.dart';
import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:async';
import 'tracker.dart';

// Import for CapturedDetection class
class CapturedDetection {
  final dynamic detection; // Can be YOLOResult or TrackedObject
  final Uint8List frameData;
  final DateTime timestamp;

  CapturedDetection({
    required this.detection,
    required this.frameData,
    required this.timestamp,
  });
}

// DEBUG: Simplified painter for debugging tracking overlay
class DebugTrackingPainter extends CustomPainter {
  final List<TrackedObject> tracks;

  DebugTrackingPainter(this.tracks);

  @override
  void paint(Canvas canvas, Size size) {
    print(
        '🎨 DebugTrackingPainter: Drawing ${tracks.length} tracks on canvas ${size}');

    // En lugar de asumir una resolución específica, usar coordenadas normalizadas
    // si están disponibles, sino fallback a coordenadas absolutas con auto-detección de escala

    for (final track in tracks) {
      print('  🎯 Drawing track ID ${track.id} at ${track.box}');

      Rect drawBox;

      // Si tenemos coordenadas normalizadas válidas, usarlas
      if (track.normalizedBox != null &&
          track.normalizedBox!.left >= 0 &&
          track.normalizedBox!.left <= 1 &&
          track.normalizedBox!.top >= 0 &&
          track.normalizedBox!.top <= 1) {
        // Usar coordenadas normalizadas (0.0 - 1.0) escaladas al canvas
        final normBox = track.normalizedBox!;
        drawBox = Rect.fromLTRB(
          normBox.left * size.width,
          normBox.top * size.height,
          normBox.right * size.width,
          normBox.bottom * size.height,
        );

        print(
            '    📏 Using NORMALIZED coordinates: ${normBox} → Canvas: ${drawBox}');
      } else {
        // Fallback: auto-detectar escala basada en las coordenadas máximas
        double maxCoord = 0;
        for (final t in tracks) {
          maxCoord = [maxCoord, t.box.right, t.box.bottom]
              .reduce((a, b) => a > b ? a : b);
        }

        // Si las coordenadas son muy grandes, probablemente son de alta resolución
        double scaleX = 1.0;
        double scaleY = 1.0;

        if (maxCoord > size.width * 2) {
          // Coordenadas parecen ser de alta resolución, auto-escalar
          scaleX = size.width / maxCoord;
          scaleY = size.height / maxCoord;
        }

        drawBox = Rect.fromLTRB(
          track.box.left * scaleX,
          track.box.top * scaleY,
          track.box.right * scaleX,
          track.box.bottom * scaleY,
        );

        print(
            '    📦 Using ABSOLUTE coordinates with auto-scale (${scaleX.toStringAsFixed(3)}, ${scaleY.toStringAsFixed(3)}): ${track.box} → Canvas: ${drawBox}');
      }

      // Clamp to canvas bounds
      final clampedBox = Rect.fromLTRB(
        drawBox.left.clamp(0, size.width),
        drawBox.top.clamp(0, size.height),
        drawBox.right.clamp(0, size.width),
        drawBox.bottom.clamp(0, size.height),
      );

      print('    🔧 Final clamped box: ${clampedBox}');

      // Solo dibujar si la caja tiene tamaño válido
      if (clampedBox.width > 5 && clampedBox.height > 5) {
        // Use direct coordinates (assume they're already in screen space)
        final paint = Paint()
          ..color = track.displayColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0;

        final fillPaint = Paint()
          ..color = track.displayColor.withOpacity(0.2)
          ..style = PaintingStyle.fill;

        // Draw filled rectangle
        canvas.drawRect(clampedBox, fillPaint);

        // Draw border
        canvas.drawRect(clampedBox, paint);

        // Draw ID text SOLO si hay espacio suficiente
        if (clampedBox.width > 40 && clampedBox.height > 20) {
          final textPainter = TextPainter(
            text: TextSpan(
              text: 'ID:${track.id}',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    offset: Offset(1.0, 1.0),
                    blurRadius: 2.0,
                    color: Colors.black,
                  ),
                ],
              ),
            ),
            textDirection: TextDirection.ltr,
          );

          textPainter.layout();

          // Position text in top-left of box
          final textOffset = Offset(
            clampedBox.left + 2,
            clampedBox.top + 2,
          );

          // Draw text background
          final textBackground = Paint()
            ..color = track.displayColor.withOpacity(0.8);

          canvas.drawRect(
            Rect.fromLTWH(
              textOffset.dx - 2,
              textOffset.dy - 2,
              textPainter.width + 4,
              textPainter.height + 4,
            ),
            textBackground,
          );

          textPainter.paint(canvas, textOffset);
        }
      } else {
        print('    ❌ Caja muy pequeña para dibujar: ${clampedBox}');
      }
    }
  }

  @override
  bool shouldRepaint(DebugTrackingPainter oldDelegate) {
    return true; // Always repaint for debugging
  }
}

// CustomPainter for drawing bounding boxes and IDs
class TrackingOverlayPainter extends CustomPainter {
  final List<TrackedObject> tracks;
  final Size viewSize;

  TrackingOverlayPainter(this.tracks, this.viewSize);

  @override
  void paint(Canvas canvas, Size size) {
    for (final track in tracks) {
      final paint = Paint()
        ..color = track.displayColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;

      final fillPaint = Paint()
        ..color = track.displayColor.withOpacity(0.1)
        ..style = PaintingStyle.fill;

      // Scale box coordinates to canvas size
      final scaledBox = Rect.fromLTRB(
        track.box.left * (size.width / viewSize.width),
        track.box.top * (size.height / viewSize.height),
        track.box.right * (size.width / viewSize.width),
        track.box.bottom * (size.height / viewSize.height),
      );

      // Draw filled rectangle
      canvas.drawRect(scaledBox, fillPaint);

      // Draw border
      canvas.drawRect(scaledBox, paint);

      // Draw ID and class name
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'ID:${track.id} ${track.className}',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                offset: Offset(1.0, 1.0),
                blurRadius: 3.0,
                color: Colors.black,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      // Position text above the box
      final textOffset = Offset(
        scaledBox.left,
        scaledBox.top - textPainter.height - 5,
      );

      // Draw background for text
      final textBackground = Paint()
        ..color = track.displayColor.withOpacity(0.8);

      canvas.drawRect(
        Rect.fromLTWH(
          textOffset.dx - 2,
          textOffset.dy - 2,
          textPainter.width + 4,
          textPainter.height + 4,
        ),
        textBackground,
      );

      textPainter.paint(canvas, textOffset);

      // Draw confidence
      final confText = TextPainter(
        text: TextSpan(
          text: '${(track.confidence * 100).toStringAsFixed(1)}%',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      confText.layout();
      final confOffset = Offset(
        scaledBox.right - confText.width,
        scaledBox.bottom + 2,
      );

      canvas.drawRect(
        Rect.fromLTWH(
          confOffset.dx - 2,
          confOffset.dy - 2,
          confText.width + 4,
          confText.height + 4,
        ),
        textBackground,
      );

      confText.paint(canvas, confOffset);
    }
  }

  @override
  bool shouldRepaint(TrackingOverlayPainter oldDelegate) {
    // Always repaint to ensure fresh drawing
    return true;
  }
}

// Widget for the tracking overlay
class TrackingOverlay extends StatelessWidget {
  final List<TrackedObject> tracks;
  final Size viewSize;

  const TrackingOverlay({
    Key? key,
    required this.tracks,
    required this.viewSize,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: TrackingOverlayPainter(tracks, viewSize),
      child: Container(),
    );
  }
}

// Carousel widget for showing detected objects
class DetectionCarousel extends StatelessWidget {
  final List<TrackedObject> lostTracks;

  const DetectionCarousel({
    Key? key,
    required this.lostTracks,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (lostTracks.isEmpty) {
      return Container(
        height: 100,
        child: Center(
          child: Text(
            'No hay objetos detectados aún',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return Container(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 8),
        itemCount: lostTracks.length,
        itemBuilder: (context, index) {
          final track = lostTracks[index];
          return Container(
            width: 80,
            margin: EdgeInsets.symmetric(horizontal: 4),
            child: Card(
              elevation: 3,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: track.displayColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: track.displayColor,
                        width: 2,
                      ),
                    ),
                    child: track.thumbnail != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.memory(
                              track.thumbnail!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildFallbackThumbnail(track);
                              },
                            ),
                          )
                        : _buildFallbackThumbnail(track),
                  ),
                  SizedBox(height: 4),
                  Text(
                    track.className,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${track.trackingDuration.inSeconds}s',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFallbackThumbnail(TrackedObject track) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: track.displayColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${track.id}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: track.displayColor,
            ),
          ),
          Text(
            track.className.length > 6
                ? track.className.substring(0, 6)
                : track.className,
            style: TextStyle(
              fontSize: 8,
              color: track.displayColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Settings widget for adjusting thresholds
class TrackingSettings extends StatelessWidget {
  final double confidenceThreshold;
  final double iouThreshold;
  final Function(double) onConfidenceChanged;
  final Function(double) onIouChanged;

  const TrackingSettings({
    Key? key,
    required this.confidenceThreshold,
    required this.iouThreshold,
    required this.onConfidenceChanged,
    required this.onIouChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'Configuración de Tracking',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),

          // Confidence threshold slider
          Row(
            children: [
              Text('Confianza: '),
              Expanded(
                child: Slider(
                  value: confidenceThreshold,
                  min: 0.1,
                  max: 0.9,
                  divisions: 8,
                  label: '${(confidenceThreshold * 100).toStringAsFixed(0)}%',
                  onChanged: onConfidenceChanged,
                ),
              ),
              Text('${(confidenceThreshold * 100).toStringAsFixed(0)}%'),
            ],
          ),

          // IoU threshold slider
          Row(
            children: [
              Text('IoU: '),
              Expanded(
                child: Slider(
                  value: iouThreshold,
                  min: 0.1,
                  max: 0.9,
                  divisions: 8,
                  label: '${(iouThreshold * 100).toStringAsFixed(0)}%',
                  onChanged: onIouChanged,
                ),
              ),
              Text('${(iouThreshold * 100).toStringAsFixed(0)}%'),
            ],
          ),
        ],
      ),
    );
  }
}

// Advanced settings widget with additional configuration options
class AdvancedTrackingSettings extends StatelessWidget {
  final double confidenceThreshold;
  final double iouThreshold;
  final int maxDetections;
  final bool showNativeUI;
  final Function(double) onConfidenceChanged;
  final Function(double) onIouChanged;
  final Function(double) onMaxDetectionsChanged;
  final Function(bool) onShowNativeUIChanged;

  const AdvancedTrackingSettings({
    Key? key,
    required this.confidenceThreshold,
    required this.iouThreshold,
    required this.maxDetections,
    required this.showNativeUI,
    required this.onConfidenceChanged,
    required this.onIouChanged,
    required this.onMaxDetectionsChanged,
    required this.onShowNativeUIChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.tune, color: Colors.blue.shade600),
              SizedBox(width: 8),
              Text(
                'Configuración Avanzada de Tracking',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          // Confidence threshold slider
          Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  'Confianza:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
              Expanded(
                child: Slider(
                  value: confidenceThreshold,
                  min: 0.1,
                  max: 0.9,
                  divisions: 8,
                  label: '${(confidenceThreshold * 100).toStringAsFixed(0)}%',
                  onChanged: onConfidenceChanged,
                  activeColor: Colors.blue.shade600,
                ),
              ),
              Container(
                width: 45,
                child: Text(
                  '${(confidenceThreshold * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          // IoU threshold slider
          Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  'IoU:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
              Expanded(
                child: Slider(
                  value: iouThreshold,
                  min: 0.1,
                  max: 0.9,
                  divisions: 8,
                  label: '${(iouThreshold * 100).toStringAsFixed(0)}%',
                  onChanged: onIouChanged,
                  activeColor: Colors.green.shade600,
                ),
              ),
              Container(
                width: 45,
                child: Text(
                  '${(iouThreshold * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          // Max detections slider
          Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  'Máx objetos:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
              Expanded(
                child: Slider(
                  value: maxDetections.toDouble(),
                  min: 5,
                  max: 100,
                  divisions: 19,
                  label: '$maxDetections',
                  onChanged: onMaxDetectionsChanged,
                  activeColor: Colors.orange.shade600,
                ),
              ),
              Container(
                width: 45,
                child: Text(
                  '$maxDetections',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          // Native UI toggle
          Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  'UI Nativa:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Switch(
                      value: showNativeUI,
                      onChanged: onShowNativeUIChanged,
                      activeColor: Colors.blue.shade600,
                    ),
                    SizedBox(width: 8),
                    Text(
                      showNativeUI
                          ? 'Mostrar controles de cámara'
                          : 'Ocultar controles de cámara',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 8),

          // Help text
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Confianza: umbral mínimo para detectar objetos\n'
              'IoU: umbral para unir detecciones similares\n'
              'Máx objetos: límite de objetos por frame',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _getIconForClass(String className) {
  switch (className.toLowerCase()) {
    case 'person':
      return Icons.person;
    case 'car':
      return Icons.directions_car;
    case 'chair':
      return Icons.chair;
    case 'laptop':
      return Icons.laptop;
    case 'cup':
      return Icons.local_cafe;
    case 'cat':
    case 'dog':
      return Icons.pets;
    default:
      return Icons.category;
  }
}

// Enhanced carousel with real thumbnail generation
class EnhancedDetectionCarousel extends StatefulWidget {
  final List<TrackedObject> lostTracks;
  final Queue<CapturedDetection> detectionQueue;

  const EnhancedDetectionCarousel({
    Key? key,
    required this.lostTracks,
    required this.detectionQueue,
  }) : super(key: key);

  @override
  _EnhancedDetectionCarouselState createState() =>
      _EnhancedDetectionCarouselState();
}

class _EnhancedDetectionCarouselState extends State<EnhancedDetectionCarousel> {
  final Map<String, Uint8List> _thumbnailCache = {};

  @override
  Widget build(BuildContext context) {
    // Combine lost tracks with recent captures
    final allDetections = <DetectionItem>[];

    // Add lost tracks (with synthetic thumbnails)
    for (final track in widget.lostTracks) {
      allDetections.add(DetectionItem(
        id: track.id.toString(),
        className: track.className,
        confidence: track.confidence,
        color: track.displayColor,
        duration: track.trackingDuration,
        thumbnail: track.thumbnail,
        isSynthetic: true,
      ));
    }

    // Add recent captures from queue (with real thumbnails)
    final recentCaptures = widget.detectionQueue.toList();
    final uniqueClasses = <String, CapturedDetection>{};

    // Get latest capture for each class
    for (final capture in recentCaptures.reversed) {
      final className = _getClassName(capture.detection);
      if (!uniqueClasses.containsKey(className)) {
        uniqueClasses[className] = capture;
      }
    }

    // Add recent captures to display
    for (final capture in uniqueClasses.values) {
      final className = _getClassName(capture.detection);
      final confidence = _getConfidence(capture.detection);

      allDetections.add(DetectionItem(
        id: 'cap_${capture.timestamp.millisecondsSinceEpoch}',
        className: className,
        confidence: confidence,
        color: _getColorForClass(className),
        duration: DateTime.now().difference(capture.timestamp),
        thumbnail: null, // Will be generated
        isSynthetic: false,
        capturedDetection: capture,
      ));
    }

    if (allDetections.isEmpty) {
      return Container(
        height: 100,
        child: Center(
          child: Text(
            'No hay objetos detectados aún',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return Container(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 8),
        itemCount: allDetections.length,
        itemBuilder: (context, index) {
          final item = allDetections[index];
          return Container(
            width: 90,
            margin: EdgeInsets.symmetric(horizontal: 4),
            child: Card(
              elevation: 3,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: item.color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: item.color,
                        width: 2,
                      ),
                    ),
                    child: _buildThumbnail(item),
                  ),
                  SizedBox(height: 4),
                  Text(
                    item.className,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item.isSynthetic
                            ? Icons.auto_awesome
                            : Icons.camera_alt,
                        size: 10,
                        color: Colors.grey.shade600,
                      ),
                      SizedBox(width: 2),
                      Text(
                        '${item.duration.inSeconds}s',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildThumbnail(DetectionItem item) {
    if (item.thumbnail != null) {
      // Use existing thumbnail
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.memory(
          item.thumbnail!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildFallbackIcon(item);
          },
        ),
      );
    } else if (item.capturedDetection != null) {
      // Generate real thumbnail from captured frame
      return FutureBuilder<Uint8List?>(
        future: _generateRealThumbnail(item.capturedDetection!),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.memory(
                snapshot.data!,
                fit: BoxFit.cover,
              ),
            );
          } else if (snapshot.hasError) {
            return _buildFallbackIcon(item);
          } else {
            return Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(item.color),
                ),
              ),
            );
          }
        },
      );
    } else {
      return _buildFallbackIcon(item);
    }
  }

  Widget _buildFallbackIcon(DetectionItem item) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: item.color.withOpacity(0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getIconForClass(item.className),
            size: 20,
            color: item.color,
          ),
          SizedBox(height: 2),
          Text(
            '${(item.confidence * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: item.color,
            ),
          ),
        ],
      ),
    );
  }

  Future<Uint8List?> _generateRealThumbnail(CapturedDetection capture) async {
    try {
      final cacheKey =
          '${_getClassName(capture.detection)}_${capture.timestamp.millisecondsSinceEpoch}';

      // Check cache first
      if (_thumbnailCache.containsKey(cacheKey)) {
        return _thumbnailCache[cacheKey];
      }

      // Decode original image
      final codec = await ui.instantiateImageCodec(capture.frameData);
      final frame = await codec.getNextFrame();
      final originalImage = frame.image;

      // Get bounding box for cropping
      final boundingBox = _getBoundingBox(capture.detection);
      if (boundingBox == null) return null;

      // Calculate crop area with padding
      final padding = 20.0;
      final cropLeft = (boundingBox.left - padding)
          .clamp(0.0, originalImage.width.toDouble());
      final cropTop = (boundingBox.top - padding)
          .clamp(0.0, originalImage.height.toDouble());
      final cropRight = (boundingBox.right + padding)
          .clamp(0.0, originalImage.width.toDouble());
      final cropBottom = (boundingBox.bottom + padding)
          .clamp(0.0, originalImage.height.toDouble());

      final cropWidth = cropRight - cropLeft;
      final cropHeight = cropBottom - cropTop;

      if (cropWidth <= 0 || cropHeight <= 0) return null;

      // Create cropped thumbnail
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      const thumbnailSize = 60.0;

      // Draw cropped and scaled image
      final srcRect = Rect.fromLTWH(cropLeft, cropTop, cropWidth, cropHeight);
      final dstRect = Rect.fromLTWH(0, 0, thumbnailSize, thumbnailSize);

      canvas.drawImageRect(originalImage, srcRect, dstRect, Paint());

      // Add border
      final borderPaint = Paint()
        ..color = _getColorForClass(_getClassName(capture.detection))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRect(
        Rect.fromLTWH(1, 1, thumbnailSize - 2, thumbnailSize - 2),
        borderPaint,
      );

      // Convert to image
      final picture = recorder.endRecording();
      final thumbnailImage = await picture.toImage(
        thumbnailSize.toInt(),
        thumbnailSize.toInt(),
      );

      final byteData =
          await thumbnailImage.toByteData(format: ui.ImageByteFormat.png);
      final thumbnail = byteData!.buffer.asUint8List();

      // Cache the result
      _thumbnailCache[cacheKey] = thumbnail;

      // Clean old cache entries
      if (_thumbnailCache.length > 50) {
        final keys = _thumbnailCache.keys.toList();
        _thumbnailCache.remove(keys.first);
      }

      return thumbnail;
    } catch (e) {
      print('❌ Error generando thumbnail: $e');
      return null;
    }
  }

  String _getClassName(dynamic detection) {
    if (detection is TrackedObject) return detection.className;
    if (detection.toString().contains('className')) {
      // Handle YOLOResult or similar objects
      try {
        return detection.className ?? 'unknown';
      } catch (e) {
        return 'unknown';
      }
    }
    return 'unknown';
  }

  double _getConfidence(dynamic detection) {
    if (detection is TrackedObject) return detection.confidence;
    try {
      return detection.confidence ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  Rect? _getBoundingBox(dynamic detection) {
    if (detection is TrackedObject) return detection.box;
    try {
      return detection.boundingBox;
    } catch (e) {
      return null;
    }
  }

  Color _getColorForClass(String className) {
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
    return colors[className.hashCode % colors.length];
  }
}

// Helper class for detection items
class DetectionItem {
  final String id;
  final String className;
  final double confidence;
  final Color color;
  final Duration duration;
  final Uint8List? thumbnail;
  final bool isSynthetic;
  final CapturedDetection? capturedDetection;

  DetectionItem({
    required this.id,
    required this.className,
    required this.confidence,
    required this.color,
    required this.duration,
    this.thumbnail,
    this.isSynthetic = false,
    this.capturedDetection,
  });
}

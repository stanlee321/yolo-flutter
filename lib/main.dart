import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'tracker.dart';
import 'widgets.dart';

void main() => runApp(YOLODemo());

class YOLODemo extends StatefulWidget {
  @override
  _YOLODemoState createState() => _YOLODemoState();
}

class _YOLODemoState extends State<YOLODemo> {
  YOLO? yolo;
  YOLOViewController? controller;
  bool isLoading = false;
  bool showSettings = false;
  bool isCameraReady = false;

  final _tracker = IoUTracker();
  int _totalDetections = 0;
  String _lastDetected = "Ningún objeto detectado";

  // Performance metrics
  double _currentFPS = 0.0;
  double _processingTimeMs = 0.0;
  String _performanceRating = "Iniciando...";

  // Configurable thresholds - HARDCODEADO PARA TESTING
  double _confidenceThreshold = 0.8;
  double _iouThreshold = 0.5;
  int _maxDetections = 10; // Reducido para menos ruido

  // Camera settings - FORZAR NATIVE UI DISABLED
  String _currentCamera = "Trasera";
  bool _showNativeUI = false; // HARDCODEADO - NO native drawing

  // Camera view size for overlay scaling
  final Size _cameraViewSize = Size(640, 480);

  @override
  void initState() {
    super.initState();
    _initializeYOLO();
  }

  Future<void> _initializeYOLO() async {
    setState(() => isLoading = true);

    try {
      // Initialize controller WITH THRESHOLDS ALTOS
      // controller = YOLOViewController();
      // await _applyStrictThresholds();

      setState(() {
        isLoading = false;
        isCameraReady = true;
      });

      print('✅ YOLO inicializado con thresholds estrictos');
    } catch (e) {
      setState(() => isLoading = false);
      print('❌ Error inicializando YOLO: $e');
      _showError('Error al cargar el modelo YOLO: $e');
    }
  }

  Future<void> _applyStrictThresholds() async {
    if (controller == null) return;

    try {
      await controller!.setThresholds(
        confidenceThreshold: _confidenceThreshold, // 0.8
        iouThreshold: _iouThreshold, // 0.5
        numItemsThreshold: _maxDetections, // 10
      );
      print(
          '✅ THRESHOLDS ESTRICTOS aplicados: conf=${(_confidenceThreshold * 100).toStringAsFixed(0)}%, iou=${(_iouThreshold * 100).toStringAsFixed(0)}%, max=$_maxDetections');
    } catch (e) {
      print('⚠️ Error aplicando thresholds estrictos: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 5),
      ),
    );
  }

  Future<void> _switchCamera() async {
    if (controller == null) return;

    try {
      await controller!.switchCamera();
      setState(() {
        _currentCamera = _currentCamera == "Trasera" ? "Frontal" : "Trasera";
      });
      print('📷 Cámara cambiada a: $_currentCamera');
    } catch (e) {
      print('❌ Error cambiando cámara: $e');
      _showError('Error al cambiar cámara');
    }
  }

  @override
  void dispose() {
    yolo?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Text('YOLO Demo con Tracking Avanzado'),
          backgroundColor: Colors.blue.shade700,
          actions: [
            IconButton(
              icon: Icon(Icons.cameraswitch),
              onPressed: isCameraReady ? _switchCamera : null,
              tooltip: 'Cambiar cámara ($_currentCamera)',
            ),
            IconButton(
              icon: Icon(showSettings ? Icons.close : Icons.settings),
              onPressed: () {
                setState(() {
                  showSettings = !showSettings;
                });
              },
              tooltip: 'Configuración',
            ),
          ],
        ),
        body: Column(
          children: [
            // Performance metrics bar
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.speed, size: 16, color: Colors.blue.shade600),
                      SizedBox(width: 4),
                      Text(
                        'FPS: ${_currentFPS.toStringAsFixed(1)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.timer, size: 16, color: Colors.green.shade600),
                      SizedBox(width: 4),
                      Text(
                        '${_processingTimeMs.toStringAsFixed(0)}ms',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getPerformanceColor(),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _performanceRating,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Status and settings section - SIMPLIFICADO
            if (showSettings)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border:
                      Border(bottom: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Column(
                  children: [
                    Text(
                      'Configuración Hardcodeada',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                        'Confianza: ${(_confidenceThreshold * 100).toStringAsFixed(0)}% (hardcodeado)'),
                    Text(
                        'IoU: ${(_iouThreshold * 100).toStringAsFixed(0)}% (hardcodeado)'),
                    Text('Max objetos: $_maxDetections (hardcodeado)'),
                    Text('Native UI: DESHABILITADO (hardcodeado)'),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Estado del Tracking',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isCameraReady
                                    ? Colors.green
                                    : Colors.orange,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isCameraReady ? 'LISTO' : 'CARGANDO',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _tracker.tracks.isNotEmpty
                                    ? Colors.green
                                    : Colors.grey,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _tracker.tracks.isNotEmpty
                                    ? 'ACTIVO'
                                    : 'INACTIVO',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                            child:
                                Text('Detectados: $_totalDetections objetos')),
                        Expanded(
                            child: Text('Activos: ${_tracker.tracks.length}')),
                      ],
                    ),
                    Text('Último: $_lastDetected'),
                    Text('Histórico: ${_tracker.lostTracks.length} objetos'),
                    Text('Cámara: $_currentCamera'),
                  ],
                ),
              ),

            // Camera view with overlay
            Expanded(
              child: Container(
                margin: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    children: [
                      // Enhanced camera view
                      if (isCameraReady)
                        YOLOView(
                          modelPath: 'yolo11n',
                          task: YOLOTask.detect,
                          // controller: controller,
                          showNativeUI: _showNativeUI,
                          cameraResolution: "720p",
                          confidenceThreshold: 0.8,
                          iouThreshold: 0.5,
                          streamingConfig: const YOLOStreamingConfig(
                            includeOriginalImage:
                                true, // Enable original image capture
                            includeDetections:
                                true, // Keep detections if needed
                          ),

                          // CALLBACK PRINCIPAL - TODA LA LÓGICA AQUÍ
                          onStreamingData: (data) {
                            try {
                              _processFrameData(data);
                            } catch (e) {
                              print('❌ Error en onStreamingData: $e');
                            }
                          },

                          // CALLBACK SECUNDARIO - Solo para métricas adicionales si las necesitamos
                          onPerformanceMetrics: (metrics) {
                            // Este ya maneja las métricas desde _processFrameData
                            // pero lo mantenemos como backup
                          },
                        )
                      else
                        // Loading indicator
                        Container(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text(
                                  'Inicializando cámara y modelo YOLO...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // OVERLAY DE TRACKING SIMPLIFICADO PARA DEBUGGING
                      if (isCameraReady && _tracker.tracks.isNotEmpty)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: DebugTrackingPainter(_tracker.tracks),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // CARRUSEL SIMPLIFICADO
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.history,
                            size: 20, color: Colors.grey.shade600),
                        SizedBox(width: 8),
                        Text(
                          'Objetos Detectados (${_tracker.lostTracks.length})',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Spacer(),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Auto-limpieza',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  DetectionCarousel(lostTracks: _tracker.lostTracks),
                ],
              ),
            ),

            // Instructions and quick actions - SIMPLIFICADO
            Container(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  // SOLO botón de UI (aunque esté hardcodeado)
                  ElevatedButton.icon(
                    icon: Icon(Icons
                        .visibility_off), // Siempre "off" porque está hardcodeado
                    label: Text('UI Nativa DESHABILITADA'),
                    onPressed: null, // Disabled porque está hardcodeado
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade400,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: Colors.grey.shade600),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tracking con IDs únicos y thumbnails reales. Configuración hardcodeada para testing: Confianza 80%, Max 10 objetos.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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

  void _processFrameData(dynamic data) {
    print('🎯 _processFrameData llamado con keys: ${data.keys}');

    // 1. EXTRAER DATOS DEL STREAMING
    final rawDetections = data['detections'] as List? ?? [];
    final fps = (data['fps'] as num?)?.toDouble() ?? 0.0;
    final processingTime =
        (data['processingTimeMs'] as num?)?.toDouble() ?? 0.0;

    // MEJORAR VERIFICACIÓN DE ORIGINAL IMAGE siguiendo GitHub issue
    Uint8List? originalImage;
    if (data.containsKey('originalImage') && data['originalImage'] != null) {
      originalImage = data['originalImage'] as Uint8List;
    }

    print(
        '📊 Frame data: ${rawDetections.length} detections, ${fps.toStringAsFixed(1)} FPS, ${processingTime.toStringAsFixed(1)}ms');

    // DEBUG IMAGEN ORIGINAL
    if (originalImage != null) {
      print('📸 ✅ Original image disponible: ${originalImage.length} bytes');
    } else {
      print('📸 ❌ Original image es NULL - NO se pueden generar thumbnails');
    }

    // 2. ACTUALIZAR MÉTRICAS DE PERFORMANCE
    setState(() {
      _currentFPS = fps;
      _processingTimeMs = processingTime;
      _performanceRating = _getPerformanceRating(fps, processingTime);
    });

    // 3. CONVERTIR DETECCIONES RAW A YOLOResult - USAR COORDENADAS NORMALIZADAS
    final yoloDetections = <YOLOResult>[];

    for (final rawDet in rawDetections) {
      if (rawDet is Map) {
        try {
          final className = rawDet['className']?.toString() ?? 'unknown';
          final confidence = (rawDet['confidence'] as num?)?.toDouble() ?? 0.0;
          final classIndex = (rawDet['classIndex'] as num?)?.toInt() ?? 0;

          // Usar coordenadas NORMALIZADAS para evitar problemas de escala
          final normalizedBoxData = rawDet['normalizedBox'];
          final boundingBoxData = rawDet['boundingBox'];

          if (normalizedBoxData is Map && boundingBoxData is Map) {
            final left = (boundingBoxData['left'] as num?)?.toDouble() ?? 0.0;
            final top = (boundingBoxData['top'] as num?)?.toDouble() ?? 0.0;
            final right = (boundingBoxData['right'] as num?)?.toDouble() ?? 0.0;
            final bottom =
                (boundingBoxData['bottom'] as num?)?.toDouble() ?? 0.0;

            // También extraer las coordenadas normalizadas
            final normLeft =
                (normalizedBoxData['left'] as num?)?.toDouble() ?? 0.0;
            final normTop =
                (normalizedBoxData['top'] as num?)?.toDouble() ?? 0.0;
            final normRight =
                (normalizedBoxData['right'] as num?)?.toDouble() ?? 0.0;
            final normBottom =
                (normalizedBoxData['bottom'] as num?)?.toDouble() ?? 0.0;

            final result = YOLOResult(
              classIndex: classIndex,
              className: className,
              confidence: confidence,
              boundingBox: Rect.fromLTRB(left, top, right, bottom),
              normalizedBox: Rect.fromLTRB(normLeft, normTop, normRight,
                  normBottom), // Usar las coordenadas reales
            );

            yoloDetections.add(result);
            print(
                '  ✅ ${className}: ${(confidence * 100).toStringAsFixed(1)}% en [${left.toStringAsFixed(0)}, ${top.toStringAsFixed(0)}, ${right.toStringAsFixed(0)}, ${bottom.toStringAsFixed(0)}]');
            print(
                '     📏 Normalized: [${normLeft.toStringAsFixed(3)}, ${normTop.toStringAsFixed(3)}, ${normRight.toStringAsFixed(3)}, ${normBottom.toStringAsFixed(3)}]');
          }
        } catch (e) {
          print('⚠️ Error procesando detección: $e');
        }
      }
    }

    // 4. TRACKING
    final tracks = _tracker.update(yoloDetections);

    // 5. ACTUALIZAR UI STATE
    setState(() {
      _totalDetections = yoloDetections.length;
      if (yoloDetections.isNotEmpty) {
        _lastDetected = yoloDetections.first.className;
      }
    });

    // 6. DEBUG THUMBNAILS - Verificar condiciones
    print(
        '🖼️ Thumbnail check: originalImage=${originalImage != null}, tracks=${tracks.length}');

    if (originalImage != null && tracks.isNotEmpty) {
      print('🖼️ ✅ Condiciones cumplidas - Llamando _generateRealThumbnails');
      _generateRealThumbnails(tracks, originalImage);
    } else {
      if (originalImage == null) {
        print('🖼️ ❌ NO thumbnails: originalImage es null');
      }
      if (tracks.isEmpty) {
        print('🖼️ ❌ NO thumbnails: no hay tracks activos');
      }
    }

    // 7. LOGGING DE PERFORMANCE
    if (fps < 15) {
      print('⚠️ Performance: FPS bajo ${fps.toStringAsFixed(1)}');
    }
    if (processingTime > 100) {
      print(
          '⚠️ Performance: Procesamiento lento ${processingTime.toStringAsFixed(1)}ms');
    }
  }

  void _generateRealThumbnails(
      List<TrackedObject> tracks, Uint8List originalImage) {
    print('🖼️ Generando thumbnails para ${tracks.length} tracks activos');

    // Generar thumbnails reales de forma asíncrona
    for (final track in tracks) {
      if (!track.thumbnailCaptured) {
        print(
            '  📷 Track ID ${track.id} (${track.className}): Generando thumbnail real...');
        _createRealThumbnail(track, originalImage);
      }
    }
  }

  Future<void> _createRealThumbnail(
      TrackedObject track, Uint8List originalImage) async {
    try {
      // 1. Decodificar la imagen original
      final codec = await ui.instantiateImageCodec(originalImage);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      // 2. Calcular área de recorte con padding
      const padding = 10.0;
      final box = track.box;

      final cropLeft = (box.left - padding).clamp(0.0, image.width.toDouble());
      final cropTop = (box.top - padding).clamp(0.0, image.height.toDouble());
      final cropRight =
          (box.right + padding).clamp(0.0, image.width.toDouble());
      final cropBottom =
          (box.bottom + padding).clamp(0.0, image.height.toDouble());

      final cropWidth = cropRight - cropLeft;
      final cropHeight = cropBottom - cropTop;

      if (cropWidth <= 0 || cropHeight <= 0) {
        print('  ❌ Área de recorte inválida para track ${track.id}');
        return;
      }

      // 3. Crear thumbnail recortado y redimensionado
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      const thumbnailSize = 80.0; // Tamaño del thumbnail

      // Dibujar imagen recortada y escalada
      final srcRect = Rect.fromLTWH(cropLeft, cropTop, cropWidth, cropHeight);
      final dstRect = Rect.fromLTWH(0, 0, thumbnailSize, thumbnailSize);

      canvas.drawImageRect(image, srcRect, dstRect, Paint());

      // Añadir borde con color del track
      final borderPaint = Paint()
        ..color = track.displayColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawRect(
        Rect.fromLTWH(1, 1, thumbnailSize - 2, thumbnailSize - 2),
        borderPaint,
      );

      // 4. Convertir a imagen y luego a bytes
      final picture = recorder.endRecording();
      final thumbnailImage = await picture.toImage(
        thumbnailSize.toInt(),
        thumbnailSize.toInt(),
      );

      final byteData =
          await thumbnailImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final thumbnailBytes = byteData.buffer.asUint8List();

        // 5. Guardar thumbnail en el track
        track.setThumbnail(thumbnailBytes);

        print(
            '  ✅ Thumbnail real generado para track ${track.id} (${track.className})');
      }
    } catch (e) {
      print('  ❌ Error generando thumbnail para track ${track.id}: $e');
    }
  }
}

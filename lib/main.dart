import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/yolo.dart';
import 'package:ultralytics_yolo/yolo_view.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'tracker.dart';

void main() => runApp(YOLODemo());

class YOLODemo extends StatefulWidget {
  @override
  _YOLODemoState createState() => _YOLODemoState();
}

class _YOLODemoState extends State<YOLODemo> {
  YOLO? yolo;
  File? selectedImage;
  List<dynamic> results = [];
  bool isLoading = false;

  final _tracker = IoUTracker();
  int _totalDetections = 0;
  String _lastDetected = "Ningún objeto detectado";

  @override
  void initState() {
    super.initState();
    loadYOLO();
  }

  Future<void> loadYOLO() async {
    setState(() => isLoading = true);

    yolo = YOLO(
      modelPath: 'yolo11n',
      task: YOLOTask.detect,
    );

    await yolo!.loadModel();
    setState(() => isLoading = false);
  }

  Future<void> pickAndDetect() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        selectedImage = File(image.path);
        isLoading = true;
      });

      final imageBytes = await selectedImage!.readAsBytes();
      final detectionResults = await yolo!.predict(imageBytes);

      setState(() {
        results = detectionResults['boxes'] ?? [];
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('YOLO Demo con Tracking'),
          backgroundColor: Colors.blue.shade700,
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              margin: EdgeInsets.all(16),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estado del Tracking',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('Total detectado: $_totalDetections objetos'),
                  Text('Último: $_lastDetected'),
                  Text(
                      'Tracker activo: ${_tracker.tracks.length} objetos rastreados'),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: YOLOView(
                    modelPath: 'yolo11n',
                    task: YOLOTask.detect,
                    confidenceThreshold: 0.9,
                    iouThreshold: 0.5,
                    onResult: (detections) {
                      try {
                        final tracks =
                            _tracker.update(detections.cast<YOLOResult>());

                        setState(() {
                          _totalDetections = detections.length;
                          if (detections.isNotEmpty) {
                            _lastDetected = detections.first.className;
                          }
                        });

                        if (detections.isNotEmpty) {
                          print('🎯 Detectados: ${detections.length} objetos');
                          for (int i = 0; i < tracks.length; i++) {
                            final track = tracks[i];
                            print(
                                '  ID ${track.id} → ${track.className} (conf: ${(track.confidence * 100).toStringAsFixed(1)}%)');
                          }
                        }
                      } catch (e) {
                        print('❌ Error en tracking: $e');
                      }
                    },
                  ),
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Instrucciones:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Apunta la cámara a objetos (personas, autos, teléfonos, etc.)',
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    '• Los objetos detectados aparecerán con IDs únicos',
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    '• Revisa la consola para logs detallados',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

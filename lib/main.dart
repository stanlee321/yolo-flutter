import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/yolo.dart';
import 'package:ultralytics_yolo/yolo_view.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:async';

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
  int currentPage = 0; // Use page index instead of boolean

  @override
  void initState() {
    super.initState();
    loadYOLO();
  }

  Future<void> loadYOLO() async {
    setState(() => isLoading = true);

    // Check if model exists first
    try {
      final modelCheck = await YOLO.checkModelExists('yolo11n');
      print('🔍 Model check result: $modelCheck');
    } catch (e) {
      print('❌ Model check failed: $e');
    }

    yolo = YOLO(
      modelPath: 'yolo11n',  // Just the base name, no extension (as per docs)
      task: YOLOTask.detect,
    );

    try {
      final success = await yolo!.loadModel();
      print('✅ Model loaded successfully: $success');
    } catch (e) {
      print('❌ Model loading failed: $e');
    }
    
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
      print('📷 Image loaded: ${imageBytes.length} bytes');
      
      print('🚀 Starting prediction...');
      final stopwatch = Stopwatch()..start();
      
      final detectionResults = await yolo!.predict(
        imageBytes,
        confidenceThreshold: 0.15,  // Lower threshold for better detection
        iouThreshold: 0.3,          // Lower IoU threshold
      );
      
      stopwatch.stop();
      print('⏱️ Prediction took: ${stopwatch.elapsedMilliseconds}ms');

      // Print the Keys
      print('🔑 Available keys: ${detectionResults.keys}');

      print('📦 Boxes: ${detectionResults['boxes']}');
      print('⚡ Speed: ${detectionResults['speed']}');
      print('📐 Image size: ${detectionResults['imageSize']}');
      print('🎯 Detections: ${detectionResults['detections']}');

      setState(() {
        // Safety check for valid detection results
        final rawResults = detectionResults['boxes'] ?? [];
        final validResults = rawResults.where((detection) {
          // Filter out any detections with invalid coordinates
          if (detection == null) return false;
          if (detection['confidence'] == null || detection['confidence'].isNaN) return false;
          if (detection['x'] != null && detection['x'].isNaN) return false;
          if (detection['y'] != null && detection['y'].isNaN) return false;
          return true;
        }).toList();
        
        results = validResults;
        isLoading = false;
        
        print('🔍 Filtered results: ${results.length} valid detections out of ${rawResults.length} total');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('YOLO Quick Demo'),
        ),
        body: IndexedStack(
          index: currentPage,
          children: [
            _buildImageView(),
            StableCameraPage(), // Completely independent page
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: currentPage,
          onTap: (index) {
            setState(() {
              currentPage = index;
              if (currentPage == 0) {
                // Clear camera results when switching to image mode
                selectedImage = null;
                results = [];
              }
            });
          },
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.photo),
              label: 'Image',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.camera),
              label: 'Live Camera',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (selectedImage != null)
            Container(
              height: 300,
              child: Image.file(selectedImage!),
            ),

          SizedBox(height: 20),

          if (isLoading)
            CircularProgressIndicator()
          else
            Text('Detected ${results.length} objects'),

          SizedBox(height: 20),

          ElevatedButton(
            onPressed: yolo != null ? pickAndDetect : null,
            child: Text('Pick Image & Detect'),
          ),

          SizedBox(height: 20),

          Expanded(
            child: ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, index) {
                final detection = results[index];
                return ListTile(
                  title: Text(detection['class'] ?? 'Unknown'),
                  subtitle: Text(
                    'Confidence: ${(detection['confidence'] * 100).toStringAsFixed(1)}%'
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

// Completely independent camera page that NEVER rebuilds
class StableCameraPage extends StatefulWidget {
  @override
  _StableCameraPageState createState() => _StableCameraPageState();
}

class _StableCameraPageState extends State<StableCameraPage> {
  // Static variables to avoid rebuilds
  static int _detectionCount = 0;
  static String _lastDetection = "None";

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Camera view that NEVER rebuilds
        Expanded(
          child: YOLOView(
            modelPath: 'yolo11n',  // Try with explicit extension
            task: YOLOTask.detect,
            onResult: (results) {
              // NO setState() calls - just print and update static variables
              print('✅ DETECTION SUCCESS: ${results.length} objects found');
              _detectionCount = results.length;
              
              if (results.isNotEmpty) {
                _lastDetection = results[0].className ?? 'Unknown';
                print('📍 First object: $_lastDetection (${(results[0].confidence * 100).toStringAsFixed(1)}%)');
                
                // Print all detections
                for (int i = 0; i < results.length; i++) {
                  final detection = results[i];
                  print('  ${i + 1}. ${detection.className} - ${(detection.confidence * 100).toStringAsFixed(1)}%');
                }
              } else {
                _lastDetection = "None";
              }
            },
          ),
        ),
        
        // Static info display - no rebuilds
        Container(
          padding: EdgeInsets.all(20),
          color: Colors.black87,
          child: Column(
            children: [
              Text(
                'YOLO Live Detection',
                style: TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.bold, 
                  color: Colors.white
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Point camera at objects (people, cars, phones, etc.)',
                style: TextStyle(color: Colors.white70),
              ),
              SizedBox(height: 10),
              Text(
                'Check console for detection logs',
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
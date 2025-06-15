---
title: Quick Start
description: Get YOLO running in your Flutter app in under 2 minutes - minimal setup guide
path: /integrations/flutter/quickstart/
---

# Quick Start Guide

Get YOLO object detection running in your Flutter app in under 2 minutes! ⚡

## 🎯 Goal

By the end of this guide, you'll have a working Flutter app that can detect objects in images using YOLO.

## 📋 Prerequisites

- ✅ Flutter SDK installed
- ✅ Android/iOS device or emulator
- ✅ 5 minutes of your time

## 🚀 Step 1: Create New Flutter App

```bash
flutter create yolo_demo
cd yolo_demo
```

## 📦 Step 2: Add YOLO Plugin

Add to `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  ultralytics_yolo: ^0.1.25
  image_picker: ^0.8.7 # For image selection
```

Install dependencies:

```bash
flutter pub get
```

## 🎯 Step 3: Add a model

You can get the model in one of the following ways:

1. Download from the [release assets](https://github.com/ultralytics/yolo-flutter-app/releases/tag/v0.0.0) of this repository

2. Get it from [Ultralytics Hub](https://www.ultralytics.com/hub)

3. Export it from [Ultralytics/ultralytics](https://github.com/ultralytics/ultralytics) ([CoreML](https://docs.ultralytics.com/ja/integrations/coreml/)/[TFLite](https://docs.ultralytics.com/integrations/tflite/))

**[📥 Download Models](./install.md#models)** |

Bundle the model with your app using the following method.

For iOS: Drag and drop mlpackage/mlmodel directly into **ios/Runner.xcworkspace** and set target to Runner.

For Android: Place the tflite file in app/src/main/assets.

## ⚡ Step 4: Minimal Detection Code

Replace `lib/main.dart` with this complete working example:

```dart
import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/yolo.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

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
        appBar: AppBar(title: Text('YOLO Quick Demo')),
        body: Center(
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

              // Show detection results
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
        ),
      ),
    );
  }
}
```

## 🏃‍♂️ Step 5: Run Your App

```bash
flutter run
```

## 🎉 That's It!

You now have a working YOLO object detection app! The app will:

1. **Load the YOLO model** when it starts
2. **Let you pick an image** from your gallery
3. **Detect objects** in the selected image
4. **Show results** with class names and confidence scores

## 🚀 Next Steps

### Add Real-time Camera

Want real-time detection? Add the YOLOView widget:

```dart
import 'package:ultralytics_yolo/yolo_view.dart';

// Replace the Column with:
YOLOView(
  modelPath: 'yolo11n',
  task: YOLOTask.detect,
  onResult: (results) {
    print('Detected ${results.length} objects');
  },
)
```

### Dynamic Model Switching

Switch models without restarting the camera:

```dart
final controller = YOLOViewController();

YOLOView(
  modelPath: 'yolo11n',  // Initial model
  task: YOLOTask.detect,
  controller: controller,
  onResult: (results) {
    print('Detected ${results.length} objects');
  },
)

// Later, switch to a different model
await controller.switchModel('yolo11s', YOLOTask.detect);
```

## 🎯 Multi-Instance Quick Example

Want to run multiple models? Try this:

```dart
// Create two YOLO instances
final detector = YOLO(
  modelPath: 'assets/models/yolo11n.tflite',
  task: YOLOTask.detect,
  useMultiInstance: true, // Enable multi-instance
);

final classifier = YOLO(
  modelPath: 'assets/models/yolo11n-cls.tflite',
  task: YOLOTask.classify,
  useMultiInstance: true,
);

// Load both models
await detector.loadModel();
await classifier.loadModel();

// Run both on the same image
final detections = await detector.predict(imageBytes);
final classifications = await classifier.predict(imageBytes);
```

## 🛠️ Troubleshooting

**App crashes on startup?**

- Make sure the model file exists in the right place

**No detections found?**

- Try a different image with clear objects
- Check model file is not corrupted
- Verify model matches the task type

**Build errors?**

- Run `flutter clean && flutter pub get`
- Check minimum SDK versions in installation guide

## 📚 Learn More

Now that you have YOLO working, explore more features:

- **[📖 Usage Guide](usage.md)** - Advanced patterns and examples
- **[🔧 API Reference](api.md)** - Complete API documentation
- **[🚀 Performance](performance.md)** - Optimization tips
- **[🛠️ Troubleshooting](troubleshooting.md)** - Common issues and solutions

## 💡 Pro Tips

- **Start small**: Use yolo11n model for development, upgrade for production
- **Test on device**: Emulators don't show real performance
- **Monitor memory**: Watch usage when running multiple instances
- **Cache models**: Keep loaded models in memory for better performance

---

**🎉 Congratulations!** You've successfully integrated YOLO into your Flutter app. Ready to build something amazing? 🚀




---
title: API Reference
description: Complete API documentation for Ultralytics YOLO Flutter plugin - classes, methods, and parameters
path: /integrations/flutter/api/
---

# API Reference

Complete reference documentation for all classes, methods, and parameters in the Ultralytics YOLO Flutter plugin.

## 📚 Core Classes

### YOLO Class

The main class for YOLO model operations.

```dart
class YOLO {
  YOLO({
    required String modelPath,
    required YOLOTask task,
    bool useMultiInstance = false,
  });
}
```

#### Constructor Parameters

| Parameter          | Type       | Required | Default | Description                           |
| ------------------ | ---------- | -------- | ------- | ------------------------------------- |
| `modelPath`        | `String`   | ✅       | -       | Path to the YOLO model file (.tflite) |
| `task`             | `YOLOTask` | ✅       | -       | Type of YOLO task to perform          |
| `useMultiInstance` | `bool`     | ❌       | `false` | Enable multi-instance support         |

#### Properties

| Property     | Type       | Description                              |
| ------------ | ---------- | ---------------------------------------- |
| `instanceId` | `String`   | Unique identifier for this YOLO instance |
| `modelPath`  | `String`   | Path to the loaded model file            |
| `task`       | `YOLOTask` | Current task type                        |

#### Methods

##### `loadModel()`

Load the YOLO model for inference.

```dart
Future<bool> loadModel()
```

**Returns**: `Future<bool>` - `true` if model loaded successfully

**Throws**:

- `ModelLoadingException` - If model file cannot be found or loaded
- `PlatformException` - If platform-specific error occurs

**Example**:

```dart
final yolo = YOLO(modelPath: 'yolo11n', task: YOLOTask.detect);
final success = await yolo.loadModel();
if (success) {
  print('Model loaded successfully');
}
```

##### `predict()`

Run inference on an image.

```dart
Future<Map<String, dynamic>> predict(
  Uint8List imageBytes, {
  double? confidenceThreshold,
  double? iouThreshold,
})
```

**Parameters**:

| Parameter             | Type        | Required | Default | Description                     |
| --------------------- | ----------- | -------- | ------- | ------------------------------- |
| `imageBytes`          | `Uint8List` | ✅       | -       | Raw image data                  |
| `confidenceThreshold` | `double?`   | ❌       | `0.25`  | Confidence threshold (0.0-1.0)  |
| `iouThreshold`        | `double?`   | ❌       | `0.4`   | IoU threshold for NMS (0.0-1.0) |

**Returns**: `Future<Map<String, dynamic>>` - Prediction results

**Throws**:

- `ModelNotLoadedException` - If model not loaded
- `InvalidInputException` - If input parameters invalid
- `InferenceException` - If inference fails

**Example**:

```dart
final imageBytes = await File('image.jpg').readAsBytes();
final results = await yolo.predict(
  imageBytes,
  confidenceThreshold: 0.6,
  iouThreshold: 0.5,
);
```

##### `switchModel()`

Switch to a different model (requires viewId to be set).

```dart
Future<void> switchModel(String newModelPath, YOLOTask newTask)
```

**Parameters**:

| Parameter      | Type       | Description                 |
| -------------- | ---------- | --------------------------- |
| `newModelPath` | `String`   | Path to the new model file  |
| `newTask`      | `YOLOTask` | Task type for the new model |

**Throws**:

- `StateError` - If view not initialized
- `ModelLoadingException` - If model switch fails

##### `dispose()`

Release all resources and clean up the instance.

```dart
Future<void> dispose()
```

**Example**:

```dart
await yolo.dispose();
```

##### Static Methods

###### `checkModelExists()`

Check if a model file exists at the specified path.

```dart
static Future<Map<String, dynamic>> checkModelExists(String modelPath)
```

**Returns**: Map containing existence info and location details

###### `getStoragePaths()`

Get available storage paths for the app.

```dart
static Future<Map<String, String?>> getStoragePaths()
```

**Returns**: Map of storage location names to paths

---

### YOLOTask Enum

Defines the type of YOLO task to perform.

```dart
enum YOLOTask {
  detect,      // Object detection
  segment,     // Instance segmentation
  classify,    // Image classification
  pose,        // Pose estimation
  obb,         // Oriented bounding boxes
}
```

#### Usage

```dart
final task = YOLOTask.detect;
print(task.name); // "detect"
```

---

### YOLOView Widget

Real-time camera view with YOLO processing.

```dart
class YOLOView extends StatefulWidget {
  const YOLOView({
    Key? key,
    required this.modelPath,
    required this.task,
    this.controller,
    this.onResult,
    this.onPerformanceMetrics,
    this.onStreamingData,
    this.onZoomChanged,
    this.cameraResolution = "720p",
    this.showNativeUI = true,
    this.streamingConfig,
  }) : super(key: key);
}
```

#### Constructor Parameters

| Parameter              | Type                                | Required | Default  | Description                                             |
| ---------------------- | ----------------------------------- | -------- | -------- | ------------------------------------------------------- |
| `modelPath`            | `String`                            | ✅       | -        | Path to YOLO model file (camera starts even if invalid) |
| `task`                 | `YOLOTask`                          | ✅       | -        | YOLO task type                                          |
| `controller`           | `YOLOViewController?`               | ❌       | `null`   | Custom view controller                                  |
| `onResult`             | `Function(List<YOLOResult>)?`       | ❌       | `null`   | Detection results callback                              |
| `onPerformanceMetrics` | `Function(YOLOPerformanceMetrics)?` | ❌       | `null`   | Performance metrics callback                            |
| `onStreamingData`      | `Function(Map<String, dynamic>)?`   | ❌       | `null`   | Comprehensive streaming callback                        |
| `onZoomChanged`        | `Function(double)?`                 | ❌       | `null`   | Zoom level change callback                              |
| `cameraResolution`     | `String`                            | ❌       | `"720p"` | Camera resolution                                       |
| `showNativeUI`         | `bool`                              | ❌       | `true`   | Show native camera UI                                   |
| `streamingConfig`      | `YOLOStreamingConfig?`              | ❌       | `null`   | Streaming configuration                                 |

#### Example

```dart
// Basic usage with valid model
YOLOView(
  modelPath: 'assets/models/yolo11n.tflite',
  task: YOLOTask.detect,
  onResult: (results) {
    print('Detected ${results.length} objects');
  },
  onPerformanceMetrics: (metrics) {
    print('FPS: ${metrics.fps}');
  },
)

// Camera-only mode (v0.1.25+): starts even with invalid model path
YOLOView(
  modelPath: 'model_not_yet_downloaded.tflite',  // Model doesn't exist yet
  task: YOLOTask.detect,
  controller: controller,
  onResult: (results) {
    // Will receive empty results until model is loaded
    print('Detections: ${results.length}');
  },
)

// Later, load the model dynamically
await controller.switchModel('downloaded_model.tflite', YOLOTask.detect);
```

---

### YOLOViewController Class

Controller for managing YOLOView behavior and settings.

```dart
class YOLOViewController {
  YOLOViewController();
}
```

#### Properties

| Property              | Type     | Description                            |
| --------------------- | -------- | -------------------------------------- |
| `confidenceThreshold` | `double` | Current confidence threshold (0.0-1.0) |
| `iouThreshold`        | `double` | Current IoU threshold (0.0-1.0)        |
| `numItemsThreshold`   | `int`    | Maximum number of detections (1-100)   |
| `isInitialized`       | `bool`   | Whether controller is initialized      |

#### Methods

##### `setConfidenceThreshold()`

Set the confidence threshold for detections.

```dart
Future<void> setConfidenceThreshold(double threshold)
```

**Parameters**: `threshold` - Value between 0.0 and 1.0

##### `setIoUThreshold()`

Set the IoU threshold for non-maximum suppression.

```dart
Future<void> setIoUThreshold(double threshold)
```

**Parameters**: `threshold` - Value between 0.0 and 1.0

##### `setNumItemsThreshold()`

Set the maximum number of detections to return.

```dart
Future<void> setNumItemsThreshold(int threshold)
```

**Parameters**: `threshold` - Value between 1 and 100

##### `setThresholds()`

Set multiple thresholds at once.

```dart
Future<void> setThresholds({
  double? confidenceThreshold,
  double? iouThreshold,
  int? numItemsThreshold,
})
```

##### `switchCamera()`

Switch between front and back camera.

```dart
Future<void> switchCamera()
```

##### `switchModel()`

Dynamically switch to a different model without restarting the camera.

```dart
Future<void> switchModel(String modelPath, YOLOTask task)
```

Parameters:

- `modelPath`: Path to the new model file
- `task`: The YOLO task type for the new model

**Throws**:

- `PlatformException` - If model file cannot be found or loaded

**Note**: As of v0.1.25, YOLOView can start with an invalid model path (camera-only mode). Use this method to load a valid model later.

Example:

```dart
// Switch to a different model
await controller.switchModel('yolo11s', YOLOTask.detect);

// Platform-specific paths
await controller.switchModel(
  Platform.isIOS ? 'yolo11s' : 'yolo11s.tflite',
  YOLOTask.detect,
);

// Handle errors
try {
  await controller.switchModel('new_model.tflite', YOLOTask.detect);
} catch (e) {
  print('Failed to load model: $e');
}
```

##### `setStreamingConfig()`

Configure streaming behavior.

```dart
Future<void> setStreamingConfig(YOLOStreamingConfig config)
```

---

### YOLOResult Class

Represents a single detection result.

```dart
class YOLOResult {
  final int classIndex;
  final String className;
  final double confidence;
  final Rect boundingBox;
  final Rect normalizedBox;
  final List<Offset>? keypoints;
  final Uint8List? mask;
}
```

#### Properties

| Property        | Type            | Description                           |
| --------------- | --------------- | ------------------------------------- |
| `classIndex`    | `int`           | Class index in the model              |
| `className`     | `String`        | Human-readable class name             |
| `confidence`    | `double`        | Detection confidence (0.0-1.0)        |
| `boundingBox`   | `Rect`          | Bounding box in pixel coordinates     |
| `normalizedBox` | `Rect`          | Normalized bounding box (0.0-1.0)     |
| `keypoints`     | `List<Offset>?` | Pose keypoints (pose task only)       |
| `mask`          | `Uint8List?`    | Segmentation mask (segment task only) |

---

### YOLOPerformanceMetrics Class

Performance metrics for YOLO inference.

```dart
class YOLOPerformanceMetrics {
  final double fps;
  final double processingTimeMs;
  final int frameNumber;
  final DateTime timestamp;
}
```

#### Properties

| Property           | Type       | Description                     |
| ------------------ | ---------- | ------------------------------- |
| `fps`              | `double`   | Frames per second               |
| `processingTimeMs` | `double`   | Processing time in milliseconds |
| `frameNumber`      | `int`      | Current frame number            |
| `timestamp`        | `DateTime` | Timestamp of the measurement    |

#### Methods

##### `isGoodPerformance`

Check if performance meets good thresholds.

```dart
bool get isGoodPerformance
```

**Returns**: `true` if FPS ≥ 15 and processing time ≤ 100ms

##### `hasPerformanceIssues`

Check if there are performance issues.

```dart
bool get hasPerformanceIssues
```

**Returns**: `true` if FPS < 10 or processing time > 200ms

##### `performanceRating`

Get a performance rating string.

```dart
String get performanceRating
```

**Returns**: "Excellent", "Good", "Fair", or "Poor"

##### Factory Constructors

###### `fromMap()`

Create metrics from a map.

```dart
factory YOLOPerformanceMetrics.fromMap(Map<String, dynamic> map)
```

#### Example

```dart
onPerformanceMetrics: (metrics) {
  print('Performance: ${metrics.performanceRating}');
  print('FPS: ${metrics.fps.toStringAsFixed(1)}');
  print('Processing: ${metrics.processingTimeMs.toStringAsFixed(1)}ms');

  if (metrics.hasPerformanceIssues) {
    print('⚠️ Performance issues detected');
  }
}
```

---

### YOLOStreamingConfig Class

Configuration for real-time streaming behavior.

```dart
class YOLOStreamingConfig {
  const YOLOStreamingConfig({
    this.includeDetections = true,
    this.includeClassifications = true,
    this.includeProcessingTimeMs = true,
    this.includeFps = true,
    this.includeMasks = false,
    this.includePoses = false,
    this.includeOBB = false,
    this.includeOriginalImage = false,
    this.maxFPS,
    this.throttleInterval,
    this.inferenceFrequency,
    this.skipFrames,
  });
}
```

#### Properties

| Property                  | Type        | Default | Description                      |
| ------------------------- | ----------- | ------- | -------------------------------- |
| `includeDetections`       | `bool`      | `true`  | Include detection results        |
| `includeClassifications`  | `bool`      | `true`  | Include classification results   |
| `includeProcessingTimeMs` | `bool`      | `true`  | Include processing time          |
| `includeFps`              | `bool`      | `true`  | Include FPS metrics              |
| `includeMasks`            | `bool`      | `false` | Include segmentation masks       |
| `includePoses`            | `bool`      | `false` | Include pose keypoints           |
| `includeOBB`              | `bool`      | `false` | Include oriented bounding boxes  |
| `includeOriginalImage`    | `bool`      | `false` | Include original frame data      |
| `maxFPS`                  | `int?`      | `null`  | Maximum FPS limit                |
| `throttleInterval`        | `Duration?` | `null`  | Throttling interval              |
| `inferenceFrequency`      | `int?`      | `null`  | Inference frequency (per second) |
| `skipFrames`              | `int?`      | `null`  | Number of frames to skip         |

#### Factory Constructors

##### `minimal()`

Minimal streaming configuration for best performance.

```dart
factory YOLOStreamingConfig.minimal()
```

##### `withMasks()`

Configuration including segmentation masks.

```dart
factory YOLOStreamingConfig.withMasks()
```

##### `full()`

Full configuration with all features except original image.

```dart
factory YOLOStreamingConfig.full()
```

##### `debug()`

Debug configuration including original image data.

```dart
factory YOLOStreamingConfig.debug()
```

##### `throttled()`

Throttled configuration with FPS limiting.

```dart
factory YOLOStreamingConfig.throttled({
  required int maxFPS,
  bool includeMasks = false,
  bool includePoses = false,
  int? inferenceFrequency,
  int? skipFrames,
})
```

##### `powerSaving()`

Power-saving configuration with reduced frequency.

```dart
factory YOLOStreamingConfig.powerSaving({
  int inferenceFrequency = 10,
  int maxFPS = 15,
})
```

##### `highPerformance()`

High-performance configuration for maximum throughput.

```dart
factory YOLOStreamingConfig.highPerformance({
  int inferenceFrequency = 30,
})
```

#### Example

```dart
// Power-saving configuration
final config = YOLOStreamingConfig.powerSaving(
  inferenceFrequency: 10,
  maxFPS: 15,
);

// Custom configuration
final customConfig = YOLOStreamingConfig(
  includeDetections: true,
  includeMasks: true,
  maxFPS: 20,
  skipFrames: 2,
);
```

---

### YOLOInstanceManager Class

Static class for managing multiple YOLO instances.

```dart
class YOLOInstanceManager {
  // Static methods only
}
```

#### Static Methods

##### `registerInstance()`

Register a YOLO instance.

```dart
static void registerInstance(String instanceId, YOLO instance)
```

##### `unregisterInstance()`

Unregister a YOLO instance.

```dart
static void unregisterInstance(String instanceId)
```

##### `getInstance()`

Get a registered YOLO instance.

```dart
static YOLO? getInstance(String instanceId)
```

##### `hasInstance()`

Check if an instance is registered.

```dart
static bool hasInstance(String instanceId)
```

##### `getActiveInstanceIds()`

Get list of all active instance IDs.

```dart
static List<String> getActiveInstanceIds()
```

#### Example

```dart
// Create multi-instance YOLO
final yolo = YOLO(
  modelPath: 'model.tflite',
  task: YOLOTask.detect,
  useMultiInstance: true,
);

// Check instance registration
print('Instance registered: ${YOLOInstanceManager.hasInstance(yolo.instanceId)}');
print('Active instances: ${YOLOInstanceManager.getActiveInstanceIds().length}');
```

---

## 🚨 Exception Classes

### YOLOException

Base exception class for all YOLO-related errors.

```dart
class YOLOException implements Exception {
  final String message;
  const YOLOException(this.message);
}
```

### ModelLoadingException

Thrown when model loading fails.

```dart
class ModelLoadingException extends YOLOException {
  const ModelLoadingException(String message) : super(message);
}
```

### ModelNotLoadedException

Thrown when attempting to use an unloaded model.

```dart
class ModelNotLoadedException extends YOLOException {
  const ModelNotLoadedException(String message) : super(message);
}
```

### InferenceException

Thrown when inference fails.

```dart
class InferenceException extends YOLOException {
  const InferenceException(String message) : super(message);
}
```

### InvalidInputException

Thrown when invalid input is provided.

```dart
class InvalidInputException extends YOLOException {
  const InvalidInputException(String message) : super(message);
}
```

---

## 📊 Type Definitions

### Common Types

```dart
// Callback function types
typedef YOLOResultCallback = void Function(List<YOLOResult> results);
typedef YOLOPerformanceCallback = void Function(YOLOPerformanceMetrics metrics);
typedef YOLOStreamingCallback = void Function(Map<String, dynamic> data);
typedef YOLOZoomCallback = void Function(double zoomLevel);

// Result data types
typedef DetectionBox = Map<String, dynamic>;
typedef ClassificationResult = Map<String, dynamic>;
typedef PoseKeypoints = List<Map<String, dynamic>>;
```

---

## 🔧 Constants

### Default Values

```dart
// Default thresholds
const double DEFAULT_CONFIDENCE_THRESHOLD = 0.25;
const double DEFAULT_IOU_THRESHOLD = 0.4;
const int DEFAULT_NUM_ITEMS_THRESHOLD = 30;

// Performance thresholds
const double GOOD_PERFORMANCE_FPS = 15.0;
const double GOOD_PERFORMANCE_TIME_MS = 100.0;
const double PERFORMANCE_ISSUE_FPS = 10.0;
const double PERFORMANCE_ISSUE_TIME_MS = 200.0;

// Camera resolutions
const List<String> SUPPORTED_RESOLUTIONS = [
  "480p", "720p", "1080p", "4K"
];
```

---

## 🎯 Migration Guide

### From v0.1.15 to v0.1.18+

#### Multi-Instance Support

**Old (Single Instance)**:

```dart
final yolo = YOLO(modelPath: 'model.tflite', task: YOLOTask.detect);
```

**New (Multi-Instance)**:

```dart
final yolo = YOLO(
  modelPath: 'model.tflite',
  task: YOLOTask.detect,
  useMultiInstance: true, // Add this line
);
```

#### Streaming Configuration

**New Feature**:

```dart
YOLOView(
  modelPath: 'model.tflite',
  task: YOLOTask.detect,
  streamingConfig: YOLOStreamingConfig.throttled(maxFPS: 15), // New
  onStreamingData: (data) { /* New comprehensive callback */ },
)
```

---

This API reference covers all public interfaces in the YOLO Flutter plugin. For usage examples, see the [Usage Guide](usage.md), and for performance optimization, check the [Performance Guide](performance.md).


---
title: Usage Guide
description: Comprehensive examples and patterns for using YOLO in Flutter - from basic detection to advanced multi-instance workflows
path: /integrations/flutter/usage/
---

# Usage Guide

Master the Ultralytics YOLO Flutter plugin with comprehensive examples and real-world patterns.

## 📖 Table of Contents

- [Basic Usage Patterns](#basic-usage-patterns)
- [All YOLO Tasks](#all-yolo-tasks)
- [Multi-Instance Support](#multi-instance-support)
- [Real-time Camera Processing](#real-time-camera-processing)
- [Advanced Configurations](#advanced-configurations)
- [Error Handling](#error-handling)
- [Best Practices](#best-practices)

## 🎯 Basic Usage Patterns

### Single Image Detection

```dart
import 'package:ultralytics_yolo/yolo.dart';
import 'dart:io';

class ObjectDetector {
  late YOLO yolo;

  Future<void> initializeYOLO() async {
    yolo = YOLO(
      modelPath: 'yolo11n',
      task: YOLOTask.detect,
    );

    await yolo.loadModel();
    print('YOLO model loaded successfully!');
  }

  Future<List<Map<String, dynamic>>> detectObjects(File imageFile) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      final results = await yolo.predict(imageBytes);

      return List<Map<String, dynamic>>.from(results['boxes'] ?? []);
    } catch (e) {
      print('Detection error: $e');
      return [];
    }
  }
}
```

### Batch Processing

```dart
class BatchProcessor {
  final YOLO yolo;

  BatchProcessor(this.yolo);

  Future<Map<String, List<dynamic>>> processImageBatch(
    List<File> images,
  ) async {
    final results = <String, List<dynamic>>{};

    for (final image in images) {
      final imageBytes = await image.readAsBytes();
      final detection = await yolo.predict(imageBytes);
      results[image.path] = detection['boxes'] ?? [];
    }

    return results;
  }
}
```

## 🎨 All YOLO Tasks

### 🔍 Object Detection

```dart
class DetectionExample {
  Future<void> runDetection() async {
    final yolo = YOLO(
      modelPath: 'yolo11n',
      task: YOLOTask.detect,
    );

    await yolo.loadModel();

    final imageBytes = await loadImageBytes();
    final results = await yolo.predict(imageBytes);

    // Process bounding boxes
    final boxes = results['boxes'] as List<dynamic>;
    for (final box in boxes) {
      print('Object: ${box['class']}');
      print('Confidence: ${box['confidence']}');
      print('Box: x=${box['x']}, y=${box['y']}, w=${box['width']}, h=${box['height']}');
    }
  }
}
```

### 🎭 Instance Segmentation

```dart
class SegmentationExample {
  Future<void> runSegmentation() async {
    final yolo = YOLO(
      modelPath: 'yolo11n-seg',
      task: YOLOTask.segment,
    );

    await yolo.loadModel();

    final imageBytes = await loadImageBytes();
    final results = await yolo.predict(imageBytes);

    // Process segmentation masks
    final boxes = results['boxes'] as List<dynamic>;
    for (final box in boxes) {
      print('Object: ${box['class']}');
      print('Mask available: ${box.containsKey('mask')}');

      // Access mask data if available
      if (box.containsKey('mask')) {
        final mask = box['mask'];
        // Process mask data for overlay rendering
      }
    }
  }
}
```

### 🏷️ Image Classification

```dart
class ClassificationExample {
  Future<void> runClassification() async {
    final yolo = YOLO(
      modelPath: 'yolo11n-cls',
      task: YOLOTask.classify,
    );

    await yolo.loadModel();

    final imageBytes = await loadImageBytes();
    final results = await yolo.predict(imageBytes);

    // Process classification results
    final classifications = results['classifications'] as List<dynamic>? ?? [];
    for (final classification in classifications) {
      print('Class: ${classification['class']}');
      print('Confidence: ${classification['confidence']}');
    }
  }
}
```

### 🤸 Pose Estimation

```dart
class PoseEstimationExample {
  Future<void> runPoseEstimation() async {
    final yolo = YOLO(
      modelPath: 'yolo11n-pose',
      task: YOLOTask.pose,
    );

    await yolo.loadModel();

    final imageBytes = await loadImageBytes();
    final results = await yolo.predict(imageBytes);

    // Process pose keypoints
    final poses = results['poses'] as List<dynamic>? ?? [];
    for (final pose in poses) {
      print('Person detected with ${pose['keypoints']?.length ?? 0} keypoints');

      // Access individual keypoints
      final keypoints = pose['keypoints'] as List<dynamic>? ?? [];
      for (int i = 0; i < keypoints.length; i++) {
        final keypoint = keypoints[i];
        print('Keypoint $i: x=${keypoint['x']}, y=${keypoint['y']}, confidence=${keypoint['confidence']}');
      }
    }
  }
}
```

### 📦 Oriented Bounding Box (OBB)

```dart
class OBBExample {
  Future<void> runOBBDetection() async {
    final yolo = YOLO(
      modelPath: 'yolo11n-obb',
      task: YOLOTask.obb,
    );

    await yolo.loadModel();

    final imageBytes = await loadImageBytes();
    final results = await yolo.predict(imageBytes);

    // Process oriented bounding boxes
    final boxes = results['boxes'] as List<dynamic>;
    for (final box in boxes) {
      print('Object: ${box['class']}');
      print('Confidence: ${box['confidence']}');
      print('Rotation: ${box['angle']} degrees');

      // Access rotated box coordinates
      final points = box['points'] as List<dynamic>? ?? [];
      print('Box corners: $points');
    }
  }
}
```

## 🔀 Multi-Instance Support

### Parallel Model Execution

```dart
class MultiInstanceExample {
  late YOLO detector;
  late YOLO segmenter;
  late YOLO classifier;

  Future<void> initializeMultipleModels() async {
    // Create multiple instances with unique IDs
    detector = YOLO(
      modelPath: 'yolo11n',
      task: YOLOTask.detect,
      useMultiInstance: true, // Enable multi-instance mode
    );

    segmenter = YOLO(
      modelPath: 'yolo11n-seg',
      task: YOLOTask.segment,
      useMultiInstance: true,
    );

    classifier = YOLO(
      modelPath: 'yolo11n-cls',
      task: YOLOTask.classify,
      useMultiInstance: true,
    );

    // Load all models in parallel
    await Future.wait([
      detector.loadModel(),
      segmenter.loadModel(),
      classifier.loadModel(),
    ]);

    print('All models loaded successfully!');
  }

  Future<Map<String, dynamic>> runComprehensiveAnalysis(
    Uint8List imageBytes,
  ) async {
    // Run all models on the same image simultaneously
    final results = await Future.wait([
      detector.predict(imageBytes),
      segmenter.predict(imageBytes),
      classifier.predict(imageBytes),
    ]);

    return {
      'detection': results[0],
      'segmentation': results[1],
      'classification': results[2],
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<void> dispose() async {
    // Clean up all instances
    await Future.wait([
      detector.dispose(),
      segmenter.dispose(),
      classifier.dispose(),
    ]);
  }
}
```

### Model Comparison Workflow

```dart
class ModelComparison {
  late YOLO modelA;
  late YOLO modelB;

  Future<void> initializeComparison() async {
    modelA = YOLO(
      modelPath: 'yolo11n',
      task: YOLOTask.detect,
      useMultiInstance: true,
    );

    modelB = YOLO(
      modelPath: 'yolo11s', // Different model size
      task: YOLOTask.detect,
      useMultiInstance: true,
    );

    await Future.wait([
      modelA.loadModel(),
      modelB.loadModel(),
    ]);
  }

  Future<Map<String, dynamic>> compareModels(Uint8List imageBytes) async {
    final stopwatchA = Stopwatch()..start();
    final resultA = await modelA.predict(imageBytes);
    stopwatchA.stop();

    final stopwatchB = Stopwatch()..start();
    final resultB = await modelB.predict(imageBytes);
    stopwatchB.stop();

    return {
      'model_a': {
        'results': resultA,
        'inference_time': stopwatchA.elapsedMilliseconds,
        'detections_count': (resultA['boxes'] as List).length,
      },
      'model_b': {
        'results': resultB,
        'inference_time': stopwatchB.elapsedMilliseconds,
        'detections_count': (resultB['boxes'] as List).length,
      },
    };
  }
}
```

## 📹 Real-time Camera Processing

### Basic Camera Integration

```dart
import 'package:ultralytics_yolo/yolo_view.dart';

class CameraDetectionScreen extends StatefulWidget {
  @override
  _CameraDetectionScreenState createState() => _CameraDetectionScreenState();
}

class _CameraDetectionScreenState extends State<CameraDetectionScreen> {
  late YOLOViewController controller;
  List<YOLOResult> currentResults = [];

  @override
  void initState() {
    super.initState();
    controller = YOLOViewController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Camera view with YOLO processing
          YOLOView(
            modelPath: 'yolo11n',
            task: YOLOTask.detect,
            controller: controller,
            onResult: (results) {
              setState(() {
                currentResults = results;
              });
            },
            onPerformanceMetrics: (metrics) {
              print('FPS: ${metrics.fps.toStringAsFixed(1)}');
              print('Processing time: ${metrics.processingTimeMs.toStringAsFixed(1)}ms');
            },
          ),

          // Overlay UI
          Positioned(
            top: 50,
            left: 20,
            child: Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Objects: ${currentResults.length}',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

### Advanced Streaming Configuration

```dart
import 'package:ultralytics_yolo/yolo_streaming_config.dart';

class AdvancedCameraScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: YOLOView(
        modelPath: 'yolo11n',
        task: YOLOTask.detect,

        // Configure streaming behavior
        streamingConfig: YOLOStreamingConfig.throttled(
          maxFPS: 15, // Limit to 15 FPS for battery saving
          includeMasks: false, // Disable masks for performance
          includeOriginalImage: false, // Save bandwidth
        ),

        // Comprehensive callback
        onStreamingData: (data) {
          final detections = data['detections'] as List? ?? [];
          final fps = data['fps'] as double? ?? 0.0;
          final originalImage = data['originalImage'] as Uint8List?;

          print('Streaming: ${detections.length} detections at ${fps.toStringAsFixed(1)} FPS');

          // Process complete frame data
          processFrameData(detections, originalImage);
        },
      ),
    );
  }

  void processFrameData(List detections, Uint8List? imageData) {
    // Custom processing logic
    for (final detection in detections) {
      final className = detection['className'] as String?;
      final confidence = detection['confidence'] as double?;

      if (confidence != null && confidence > 0.8) {
        print('High confidence detection: $className (${(confidence * 100).toStringAsFixed(1)}%)');
      }
    }
  }
}
```

## 🔄 Dynamic Model Management

### Dynamic Model Switching

Switch models on-the-fly without restarting the camera view:

```dart
class DynamicModelExample extends StatefulWidget {
  @override
  _DynamicModelExampleState createState() => _DynamicModelExampleState();
}

class _DynamicModelExampleState extends State<DynamicModelExample> {
  final controller = YOLOViewController();
  String currentModel = 'yolo11n';
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Camera starts even with invalid model path
          YOLOView(
            modelPath: 'invalid_model.tflite', // Can be invalid initially
            task: YOLOTask.detect,
            controller: controller,
            onResult: (results) {
              print('Detected ${results.length} objects');
            },
          ),

          // Model switching UI
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: isLoading ? null : () => switchToModel('yolo11n'),
                  child: Text('YOLO11n'),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : () => switchToModel('yolo11s'),
                  child: Text('YOLO11s'),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : () => switchToModel('yolo11m'),
                  child: Text('YOLO11m'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> switchToModel(String modelName) async {
    setState(() => isLoading = true);

    try {
      // Switch model without restarting camera
      await controller.switchModel(
        Platform.isIOS ? modelName : '$modelName.tflite',
        YOLOTask.detect,
      );

      setState(() {
        currentModel = modelName;
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Switched to $modelName')),
      );
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load model: $e')),
      );
    }
  }
}
```

### Camera-Only Mode (Deferred Model Loading)

Start camera preview immediately while models download in background:

```dart
class DeferredModelLoadingExample extends StatefulWidget {
  @override
  _DeferredModelLoadingExampleState createState() => _DeferredModelLoadingExampleState();
}

class _DeferredModelLoadingExampleState extends State<DeferredModelLoadingExample> {
  final controller = YOLOViewController();
  bool isModelReady = false;

  @override
  void initState() {
    super.initState();
    downloadAndLoadModel();
  }

  Future<void> downloadAndLoadModel() async {
    // Simulate model download
    await Future.delayed(Duration(seconds: 3));

    // Load model after download completes
    await controller.switchModel(
      'downloaded_model.tflite',
      YOLOTask.detect,
    );

    setState(() => isModelReady = true);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Camera starts immediately with placeholder model
        YOLOView(
          modelPath: 'placeholder.tflite', // Non-existent file
          task: YOLOTask.detect,
          controller: controller,
          onResult: (results) {
            // Will only receive results after model is loaded
            print('Detection active: ${results.length} objects');
          },
        ),

        if (!isModelReady)
          Center(
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Downloading model...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
```

## ⚙️ Advanced Configurations

### Custom Thresholds and Performance Tuning

```dart
class AdvancedConfiguration {
  late YOLO yolo;
  late YOLOViewController controller;

  Future<void> setupOptimizedYOLO() async {
    yolo = YOLO(
      modelPath: 'yolo11n',
      task: YOLOTask.detect,
    );

    await yolo.loadModel();

    controller = YOLOViewController();

    // Optimize for your use case
    await controller.setThresholds(
      confidenceThreshold: 0.6,  // Higher for fewer false positives
      iouThreshold: 0.4,         // Lower for more distinct objects
      numItemsThreshold: 20,     // Limit max detections
    );
  }

  Future<List<dynamic>> optimizedPrediction(Uint8List imageBytes) async {
    // Use custom thresholds during prediction
    final results = await yolo.predict(
      imageBytes,
      confidenceThreshold: 0.7,  // Override global setting
      iouThreshold: 0.3,
    );

    return results['boxes'] ?? [];
  }
}
```

### Model Switching

```dart
class ModelSwitcher {
  late YOLO yolo;
  String currentModel = '';

  Future<void> initializeWithModel(String modelPath) async {
    yolo = YOLO(
      modelPath: modelPath,
      task: YOLOTask.detect,
    );

    await yolo.loadModel();
    currentModel = modelPath;
  }

  Future<void> switchToModel(String newModelPath, YOLOTask newTask) async {
    try {
      // Switch model dynamically (requires view to be set)
      await yolo.switchModel(newModelPath, newTask);
      currentModel = newModelPath;
      print('Switched to model: $newModelPath');
    } catch (e) {
      print('Model switch failed: $e');
      // Fallback: create new instance
      await initializeWithModel(newModelPath);
    }
  }
}
```

## 🛡️ Error Handling

### Robust Error Management

```dart
class RobustYOLOService {
  YOLO? yolo;
  bool isModelLoaded = false;

  Future<bool> safeInitialize(String modelPath) async {
    try {
      yolo = YOLO(
        modelPath: modelPath,
        task: YOLOTask.detect,
      );

      await yolo!.loadModel();
      isModelLoaded = true;
      return true;

    } on ModelLoadingException catch (e) {
      print('Model loading failed: ${e.message}');
      return false;
    } on PlatformException catch (e) {
      print('Platform error: ${e.message}');
      return false;
    } catch (e) {
      print('Unexpected error: $e');
      return false;
    }
  }

  Future<List<dynamic>?> safePrediction(Uint8List imageBytes) async {
    if (!isModelLoaded || yolo == null) {
      print('Model not loaded');
      return null;
    }

    try {
      final results = await yolo!.predict(imageBytes);
      return results['boxes'];

    } on ModelNotLoadedException catch (e) {
      print('Model not loaded: ${e.message}');
      // Attempt to reload
      await safeInitialize(yolo!.modelPath);
      return null;

    } on InferenceException catch (e) {
      print('Inference failed: ${e.message}');
      return null;

    } on InvalidInputException catch (e) {
      print('Invalid input: ${e.message}');
      return null;

    } catch (e) {
      print('Prediction error: $e');
      return null;
    }
  }

  Future<void> safeDispose() async {
    try {
      await yolo?.dispose();
      isModelLoaded = false;
    } catch (e) {
      print('Dispose error: $e');
    }
  }
}
```

## 🎯 Best Practices

### Memory Management

```dart
class MemoryEfficientYOLO {
  static const int MAX_CONCURRENT_INSTANCES = 3;
  final List<YOLO> activeInstances = [];

  Future<YOLO> createManagedInstance(String modelPath, YOLOTask task) async {
    // Limit concurrent instances
    if (activeInstances.length >= MAX_CONCURRENT_INSTANCES) {
      // Dispose oldest instance
      final oldest = activeInstances.removeAt(0);
      await oldest.dispose();
    }

    final yolo = YOLO(
      modelPath: modelPath,
      task: task,
      useMultiInstance: true,
    );

    await yolo.loadModel();
    activeInstances.add(yolo);

    return yolo;
  }

  Future<void> disposeAll() async {
    await Future.wait(
      activeInstances.map((yolo) => yolo.dispose()),
    );
    activeInstances.clear();
  }
}
```

### Performance Monitoring

```dart
class PerformanceMonitor {
  final List<double> inferenceTimes = [];
  final List<double> fpsValues = [];

  void onPerformanceUpdate(YOLOPerformanceMetrics metrics) {
    inferenceTimes.add(metrics.processingTimeMs);
    fpsValues.add(metrics.fps);

    // Keep only last 100 measurements
    if (inferenceTimes.length > 100) {
      inferenceTimes.removeAt(0);
      fpsValues.removeAt(0);
    }

    // Log performance warnings
    if (metrics.processingTimeMs > 200) {
      print('⚠️ Slow inference: ${metrics.processingTimeMs.toStringAsFixed(1)}ms');
    }

    if (metrics.fps < 10) {
      print('⚠️ Low FPS: ${metrics.fps.toStringAsFixed(1)}');
    }
  }

  Map<String, double> getPerformanceStats() {
    if (inferenceTimes.isEmpty) return {};

    final avgInferenceTime = inferenceTimes.reduce((a, b) => a + b) / inferenceTimes.length;
    final avgFps = fpsValues.reduce((a, b) => a + b) / fpsValues.length;

    return {
      'average_inference_time_ms': avgInferenceTime,
      'average_fps': avgFps,
      'performance_rating': avgFps > 20 ? 5.0 : avgFps > 15 ? 4.0 : avgFps > 10 ? 3.0 : 2.0,
    };
  }
}
```

## 🎓 Example Applications

### Security Camera System

```dart
class SecuritySystem {
  late YOLO detector;
  final List<String> alertClasses = ['person', 'car', 'truck'];

  Future<void> initialize() async {
    detector = YOLO(
      modelPath: 'yolo11n',
      task: YOLOTask.detect,
    );
    await detector.loadModel();
  }

  Future<bool> analyzeFrame(Uint8List frameBytes) async {
    final results = await detector.predict(frameBytes);
    final boxes = results['boxes'] as List;

    // Check for security-relevant objects
    for (final box in boxes) {
      final className = box['class'] as String;
      final confidence = box['confidence'] as double;

      if (alertClasses.contains(className) && confidence > 0.8) {
        await triggerAlert(className, confidence);
        return true;
      }
    }

    return false;
  }

  Future<void> triggerAlert(String objectClass, double confidence) async {
    print('🚨 Security Alert: $objectClass detected (${(confidence * 100).toStringAsFixed(1)}% confidence)');
    // Implement notification logic
  }
}
```

This comprehensive usage guide covers all major patterns and use cases for the YOLO Flutter plugin. For specific API details, check the [API Reference](api.md), and for performance optimization, see the [Performance Guide](performance.md).
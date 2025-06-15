# yolo_demo

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


```bash
python3 -c "from ultralytics import YOLO; print('Re-exporting with coordinate fix...'); model = YOLO('yolo11n.pt'); model.export(format='mlmodel', imgsz=640, nms=True, half=False, int8=False, optimize=True); print('✅ Model re-exported with proper coordinate handling')"

```


```python
from ultralytics import YOLO; 
print('Re-exporting with coordinate fix...'); 
model = YOLO('yolo11n.pt'); 
model.export(format='coreml', imgsz=640, nms=True, half=False, int8=False, optimize=True, device='mps'); 
print('✅ Model re-exported with proper coordinate handling')"
```
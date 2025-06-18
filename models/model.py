from ultralytics import YOLO; 
print('Re-exporting with coordinate fix...'); 
model = YOLO('yolo11n.pt'); 
#model.export(format='coreml', imgsz=320, nms=False, half=False, int8=True, optimize=False, device='mps'); 
model.export(format="coreml", imgsz=320, nms=True)

print('✅ Model re-exported with proper coordinate handling')
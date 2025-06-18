from ultralytics import YOLO
from ultralytics.utils.downloads import zip_directory


def export_and_zip_yolo_models(
    model_types=("", "-seg", "-cls", "-pose", "-obb"),
    model_sizes=("n", "s", "m", "l", "x"),
):
    """Exports YOLO11 models to CoreML format and optionally zips the output packages."""
    for model_type in model_types:
        imgsz = [224, 224] if "cls" in model_type else [640, 384]  # default input image sizes
        nms = True if model_type == "" else False  # only apply NMS to Detect models
        for size in model_sizes:
            model_name = f"yolo11{size}{model_type}"
            print(f"Exporting {model_name}...")
            model = YOLO(f"{model_name}.pt")
            model.export(format="coreml", int8=True, imgsz=imgsz, nms=nms)
            zip_directory(f"{model_name}.mlpackage").rename(f"{model_name}.mlpackage.zip")


# Execute with default parameters
export_and_zip_yolo_models()
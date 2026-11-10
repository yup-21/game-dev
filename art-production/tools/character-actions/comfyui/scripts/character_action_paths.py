"""Local paths for the native ComfyUI authoring workflow."""
import json
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
BUNDLE = SCRIPTS.parent

CONFIG = json.loads((BUNDLE / "settings.example.json").read_text("utf-8"))
local = BUNDLE / "settings.local.json"
if local.is_file():
    override = json.loads(local.read_text("utf-8-sig"))
    CONFIG.update({key: value for key, value in override.items() if key != "models"})
    CONFIG["models"].update(override.get("models", {}))


def configured_path(key):
    value = CONFIG.get(key)
    return (BUNDLE / value).resolve() if value else None


DEFAULT_COMFY = configured_path("comfy_root")
TEMPLATE_ROOT = configured_path("pose_templates_root")
POSE_MODEL = configured_path("pose_model")
ALPHA_MODEL = configured_path("alpha_model")
POSE_DEPS = configured_path("pose_dependencies")
AI_POSE_PLANS = BUNDLE / "outputs" / "planner-cache"
MODELS = CONFIG["models"]

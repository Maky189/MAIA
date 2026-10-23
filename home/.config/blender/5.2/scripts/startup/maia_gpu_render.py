# Render Cycles on the NVIDIA GPU: pick OptiX (or CUDA) when no device is set,
# and switch every scene to GPU Compute, in new and old files.
import bpy
from bpy.app.handlers import persistent


def pick_device():
    addon = bpy.context.preferences.addons.get("cycles")
    if not addon or addon.preferences.compute_device_type != "NONE":
        return
    cp = addon.preferences
    for kind in ("OPTIX", "CUDA"):
        try:
            cp.compute_device_type = kind
        except TypeError:
            continue
        cp.refresh_devices()
        if any(d.type == kind for d in cp.devices):
            for d in cp.devices:
                d.use = d.type == kind
            bpy.context.preferences.is_dirty = True
            return
    cp.compute_device_type = "NONE"


@persistent
def use_gpu(*_):
    pick_device()
    for scene in bpy.data.scenes:
        if scene.cycles.device != "GPU":
            scene.cycles.device = "GPU"


def register():
    bpy.app.handlers.load_post.append(use_gpu)


def unregister():
    bpy.app.handlers.load_post.remove(use_gpu)

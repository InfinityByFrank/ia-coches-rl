"""
train_godot.py  -  FASE 2: entrena el coche DENTRO de Godot (ciudad en 3D)

Python (PPO de Stable-Baselines3) y Godot hablan por un socket TCP:
    Godot  --(observaciones + recompensa)-->  Python
    Godot  <--(accion: direccion, aceleracion)--  Python
Godot se lanza solo, en modo headless (sin ventana), con 16 coches a la vez.

Uso:   python train_godot.py            (300k pasos)
       python train_godot.py 5000       (prueba rapida)
Al terminar guarda:
       models/godot_ppo.zip             (modelo de Stable-Baselines3)
       godot/models/car.onnx            (el mismo modelo en ONNX, para Godot)
"""
import atexit
import os
import subprocess
import sys
import threading
from pathlib import Path

from stable_baselines3 import PPO
from stable_baselines3.common.vec_env import VecMonitor
from godot_rl.wrappers.onnx.stable_baselines_export import export_model_as_onnx
from godot_rl.wrappers.stable_baselines_wrapper import StableBaselinesGodotEnv

TIMESTEPS = int(sys.argv[1]) if len(sys.argv) > 1 else 300_000
PORT = 11008
SPEEDUP = 20  # la simulacion va 20 veces mas rapida que el tiempo real (el delta de fisica no cambia)
ROOT = Path(__file__).resolve().parent
GODOT = os.environ.get("GODOT_PATH", "/Volumes/ack - ssd/Applications/Godot.app/Contents/MacOS/Godot")

(ROOT / "models").mkdir(exist_ok=True)
(ROOT / "godot" / "models").mkdir(exist_ok=True)

godot_proc = None


def launch_godot():
    """Lanza Godot cuando el servidor de Python ya esta escuchando."""
    global godot_proc
    godot_proc = subprocess.Popen(
        [GODOT, "--headless", "--path", str(ROOT / "godot"), "res://scenes/train.tscn",
         f"--port={PORT}", f"--speedup={SPEEDUP}"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )


atexit.register(lambda: godot_proc and godot_proc.poll() is None and godot_proc.terminate())

# GodotEnv abre el servidor y se queda esperando: lanzamos Godot 3 s despues, en otro hilo.
threading.Timer(3.0, launch_godot).start()
env = VecMonitor(StableBaselinesGodotEnv(env_path=None, port=PORT, show_window=False, seed=0))
print(f"Conectado. Coches en paralelo: {env.num_envs}")

model = PPO(
    "MultiInputPolicy",   # la observacion llega como diccionario {"obs": [...]}
    env,
    learning_rate=3e-4,
    n_steps=256,          # pasos por coche antes de cada actualizacion (x16 coches = 4096)
    batch_size=512,
    gamma=0.99,
    verbose=1,
)
model.learn(TIMESTEPS)

model.save(ROOT / "models" / "godot_ppo")
export_model_as_onnx(model, str(ROOT / "godot" / "models" / "car.onnx"))
print("Guardado models/godot_ppo.zip y godot/models/car.onnx")
env.close()

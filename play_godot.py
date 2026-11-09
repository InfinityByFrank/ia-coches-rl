"""
play_godot.py  -  Mira al coche entrenado conduciendo en Godot (con ventana)

Carga models/godot_ppo.zip, abre Godot con la escena `watch` (3 coches con rayos)
y cada decision la toma el modelo. Cierra la ventana de Godot para terminar.

Uso:   python play_godot.py
"""
import os
import subprocess
import threading
from pathlib import Path

from stable_baselines3 import PPO
from godot_rl.wrappers.stable_baselines_wrapper import StableBaselinesGodotEnv

ROOT = Path(__file__).resolve().parent
GODOT = os.environ.get("GODOT_PATH", "/Volumes/ack - ssd/Applications/Godot.app/Contents/MacOS/Godot")
PORT = 11009
EXTRA = os.environ.get("GODOT_EXTRA_ARGS", "").split()   # p.ej. --write-movie ruta.png (para pruebas)
STEPS = int(os.environ.get("PLAY_STEPS", "0"))            # 0 = hasta cerrar la ventana

proc = None


def launch():
    global proc
    proc = subprocess.Popen([GODOT, "--path", str(ROOT / "godot"), "res://scenes/watch.tscn",
                             f"--port={PORT}", "--speedup=1", *EXTRA])


threading.Timer(2.0, launch).start()
env = StableBaselinesGodotEnv(env_path=None, port=PORT, show_window=True)
model = PPO.load(ROOT / "models" / "godot_ppo")
obs = env.reset()
n = 0
try:
    while STEPS == 0 or n < STEPS:
        action, _ = model.predict(obs, deterministic=True)
        obs, reward, done, info = env.step(action)
        n += 1
except (ConnectionError, BrokenPipeError, OSError):
    print("Godot se cerro.")
finally:
    if proc and proc.poll() is None:
        proc.terminate()

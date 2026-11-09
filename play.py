"""
play.py  -  VER AL COCHE YA ENTRENADO

Carga el modelo y lo ejecuta en una ventana. Si no has entrenado, usa --random
para ver como conduce un coche "sin cerebro" (acciones al azar) y compararlo.

Uso:  python play.py
      python play.py --random
"""
import sys
from stable_baselines3 import PPO
from car_env import CarEnv

random_mode = "--random" in sys.argv
env = CarEnv(render_mode="human")
model = None if random_mode else PPO.load("models/car_ppo")

obs, _ = env.reset()
episode, best = 1, 0.0
while True:
    if model is None:
        action = env.action_space.sample()
    else:
        action, _ = model.predict(obs, deterministic=True)
    obs, reward, terminated, truncated, info = env.step(action)
    best = max(best, info["laps"])
    if terminated or truncated:
        print(f"Episodio {episode}: vueltas={info['laps']:.2f}  ({'choque' if terminated else 'tiempo agotado'})")
        episode += 1
        obs, _ = env.reset()

"""
evaluate.py  -  MEDIR (sin ventana) cuanto mejor es el modelo que el azar.
Asi sabes con numeros, no a ojo, si el entrenamiento funciono.
"""
import numpy as np
from stable_baselines3 import PPO
from car_env import CarEnv


def run(policy, n=20):
    env = CarEnv()
    laps = []
    for _ in range(n):
        obs, _ = env.reset()
        done = False
        while not done:
            obs, r, term, trunc, info = env.step(policy(obs, env))
            done = term or trunc
        laps.append(info["laps"])
    return np.mean(laps)


model = PPO.load("models/car_ppo")
print(f"Azar    : {run(lambda o, e: e.action_space.sample()):.2f} vueltas de media")
print(f"Entrenado: {run(lambda o, e: model.predict(o, deterministic=True)[0]):.2f} vueltas de media")

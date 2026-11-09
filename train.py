"""
train.py  -  EL ENTRENAMIENTO

Usa PPO (Proximal Policy Optimization) de Stable-Baselines3.
PPO crea una red neuronal que:
   observacion  ->  [red]  ->  accion
y la va ajustando para que la recompensa acumulada suba.

Uso:   python train.py            (200k pasos, unos minutos en CPU)
       python train.py 500000     (mas pasos = mejor conductor)
"""
import sys
from pathlib import Path
from stable_baselines3 import PPO
from stable_baselines3.common.callbacks import BaseCallback
from stable_baselines3.common.env_util import make_vec_env
from stable_baselines3.common.monitor import Monitor
from car_env import CarEnv

TIMESTEPS = int(sys.argv[1]) if len(sys.argv) > 1 else 200_000
Path("models").mkdir(exist_ok=True)
Path("logs").mkdir(exist_ok=True)

# 8 coches entrenando en paralelo = mas experiencia por segundo
env = make_vec_env(lambda: Monitor(CarEnv()), n_envs=8)

model = PPO(
    "MlpPolicy",          # red neuronal totalmente conectada (Multi-Layer Perceptron)
    env,
    learning_rate=3e-4,   # que tan grandes son los ajustes de la red
    n_steps=1024,         # pasos que recolecta cada coche antes de cada actualizacion
    batch_size=256,
    gamma=0.99,           # cuanto le importa el futuro vs. el presente
    verbose=1,
    tensorboard_log=None,
)

class LogEpisodes(BaseCallback):
    """Guarda (pasos, recompensa, duracion) de cada episodio terminado en logs/episodes.csv.
    Monitor mete la clave 'episode' en `info` cuando un coche termina un episodio."""

    def __init__(self):
        super().__init__()
        self.rows = []

    def _on_step(self):
        for info in self.locals["infos"]:
            if "episode" in info:
                self.rows.append((self.num_timesteps, info["episode"]["r"], info["episode"]["l"]))
        return True

    def _on_training_end(self):
        with open("logs/episodes.csv", "w") as f:
            f.write("timesteps,reward,length\n")
            f.writelines(f"{t},{r:.3f},{l}\n" for t, r, l in self.rows)


model.learn(total_timesteps=TIMESTEPS, callback=LogEpisodes())
model.save("models/car_ppo")
print("\nModelo guardado en models/car_ppo.zip  ->  ahora ejecuta: python play.py")

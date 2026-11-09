"""
plot.py  -  GRAFICA DE APRENDIZAJE

Lee logs/episodes.csv (lo genera train.py) y dibuja:
  - Recompensa por episodio vs. pasos de entrenamiento
  - Duracion del episodio vs. pasos (si sube hacia 1500, el coche ya no choca)
Los puntos sueltos son episodios individuales; la linea gruesa es la media movil.

Uso:  python plot.py          (guarda training_curve.png y abre la ventana)
      python plot.py --nogui  (solo guarda el PNG)
"""
import sys
import numpy as np
import matplotlib

if "--nogui" in sys.argv:
    matplotlib.use("Agg")
import matplotlib.pyplot as plt

data = np.genfromtxt("logs/episodes.csv", delimiter=",", names=True)
steps, reward, length = data["timesteps"], data["reward"], data["length"]


def moving_avg(y, w=50):
    w = min(w, len(y))
    return np.convolve(y, np.ones(w) / w, mode="valid")


fig, axes = plt.subplots(2, 1, figsize=(9, 7), sharex=True)
for ax, y, title in [(axes[0], reward, "Recompensa por episodio"),
                     (axes[1], length, "Duración del episodio (máx 1500)")]:
    ax.scatter(steps, y, s=4, alpha=0.25)
    ma = moving_avg(y)
    ax.plot(steps[len(steps) - len(ma):], ma, linewidth=2.5, color="C3", label="media móvil (50)")
    ax.set_title(title)
    ax.grid(alpha=0.3)
    ax.legend()
axes[1].set_xlabel("Pasos de entrenamiento")
plt.tight_layout()
plt.savefig("training_curve.png", dpi=120)
print("Guardado: training_curve.png")
if "--nogui" not in sys.argv:
    plt.show()

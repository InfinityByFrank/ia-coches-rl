# IA-Coches-RL

Proyecto de estudio: aprender Reinforcement Learning (RL) haciendo que un coche 2D aprenda a conducir solo.
Fase 2 prevista: llevarlo a Godot 4 con los coches del pack KayKit City Builder Bits (Godot RL Agents).

## Instalación

```bash
python3.11 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Uso

```bash
python play.py --random   # coche sin entrenar (acciones al azar)
python train.py           # entrena (200k pasos, unos minutos en CPU)
python evaluate.py        # compara numéricamente azar vs. entrenado
python play.py            # ver al coche entrenado
```

## Archivos (en el orden recomendado para leerlos)

| Archivo | Qué es |
|---|---|
| `car_env.py` | El entorno v2: pistas con curvas **distintas en cada episodio**, sensores, **recompensa**. Lo más importante. |
| `car_env_ring.py` | Entorno v1 (anillo fijo), conservado para comparar. Gráfica: `training_curve_ring.png`. |
| `train.py` | Entrenamiento con PPO (Stable-Baselines3). |
| `evaluate.py` | Mide vueltas medias: azar vs. modelo. |
| `play.py` | Visualiza con pygame. |
| `plot.py` | Gráfica de aprendizaje (`training_curve.png`) a partir de `logs/episodes.csv`. |

## Conceptos clave

- **Observación:** 7 rayos de distancia a la pared + velocidad (todo normalizado 0..1).
- **Acción:** [dirección, aceleración] continuas en -1..1.
- **Recompensa:** + por avanzar alrededor del circuito, −10 por chocar, −0.01 por paso.
- **PPO:** algoritmo que ajusta una red neuronal para maximizar la recompensa acumulada.

## Ideas para experimentar

1. Cambia la recompensa (p. ej. quita el −0.01) y observa cómo cambia el comportamiento.
2. Prueba `python train.py 50000` vs `1000000` y compara con `evaluate.py`.
3. Cambia `N_RAYS` o el ancho de la pista.
4. Añade obstáculos u otros coches.

"""
car_env.py  -  EL ENTORNO (el "mundo" donde vive el coche)

Un entorno de RL siempre tiene 4 piezas (interfaz de Gymnasium):
  - observation_space : que "ve" el agente
  - action_space      : que puede hacer
  - reset()           : empieza un episodio nuevo
  - step(action)      : avanza 1 instante y devuelve (observacion, recompensa, terminado, truncado, info)

Aqui: un coche 2D visto desde arriba en un circuito cerrado. Debe dar vueltas sin chocar.
"""
import math
import numpy as np
import gymnasium as gym
from gymnasium import spaces

# ---- Geometria del circuito: dos circulos concentricos (un anillo) ----
CENTER = np.array([400.0, 300.0])
R_INNER = 150.0          # pared interior
R_OUTER = 260.0          # pared exterior
R_MID = (R_INNER + R_OUTER) / 2

# ---- Sensores: rayos que miden distancia a la pared ----
N_RAYS = 7
RAY_ANGLES = np.linspace(-math.pi / 2, math.pi / 2, N_RAYS)  # de -90 a +90 grados
RAY_MAX = 150.0

# ---- Fisica sencilla ----
MAX_SPEED = 6.0
ACCEL = 0.25
MAX_STEER = 0.08         # radianes por paso
MAX_STEPS = 1500         # limite de pasos por episodio


class CarEnv(gym.Env):
    metadata = {"render_modes": ["human"], "render_fps": 60}

    def __init__(self, render_mode=None):
        super().__init__()
        self.render_mode = render_mode

        # ACCION: 2 numeros continuos entre -1 y 1  ->  [direccion, aceleracion]
        self.action_space = spaces.Box(low=-1.0, high=1.0, shape=(2,), dtype=np.float32)

        # OBSERVACION: N_RAYS distancias (0..1) + velocidad (0..1)
        # Normalizar a 0..1 ayuda MUCHO a que la red neuronal aprenda.
        self.observation_space = spaces.Box(low=0.0, high=1.0, shape=(N_RAYS + 1,), dtype=np.float32)

        self._screen = None
        self._clock = None

    # ------------------------------------------------------------------
    def _ray_distance(self, angle):
        """Distancia desde el coche hasta la pared en la direccion 'angle' (avanzando a pasos)."""
        for d in range(0, int(RAY_MAX), 3):
            p = self.pos + d * np.array([math.cos(angle), math.sin(angle)])
            r = np.linalg.norm(p - CENTER)
            if r < R_INNER or r > R_OUTER:
                return d / RAY_MAX
        return 1.0

    def _get_obs(self):
        rays = [self._ray_distance(self.heading + a) for a in RAY_ANGLES]
        speed = self.speed / MAX_SPEED
        return np.array(rays + [speed], dtype=np.float32)

    def _angle_around_center(self):
        v = self.pos - CENTER
        return math.atan2(v[1], v[0])

    # ------------------------------------------------------------------
    def reset(self, seed=None, options=None):
        super().reset(seed=seed)
        # Arranca en la parte derecha del anillo, mirando hacia abajo (sentido horario en pantalla)
        start_angle = self.np_random.uniform(0, 2 * math.pi)
        self.pos = CENTER + R_MID * np.array([math.cos(start_angle), math.sin(start_angle)])
        self.heading = start_angle + math.pi / 2   # tangente al anillo
        self.speed = 0.0
        self.steps = 0
        self.prev_angle = self._angle_around_center()
        self.total_progress = 0.0
        return self._get_obs(), {}

    def step(self, action):
        steer, throttle = float(action[0]), float(action[1])

        # --- fisica ---
        self.speed = float(np.clip(self.speed + throttle * ACCEL, 0.0, MAX_SPEED))
        self.heading += steer * MAX_STEER * (0.4 + self.speed / MAX_SPEED)
        self.pos = self.pos + self.speed * np.array([math.cos(self.heading), math.sin(self.heading)])
        self.steps += 1

        # --- progreso: cuanto avanzamos ALREDEDOR del anillo en este paso ---
        ang = self._angle_around_center()
        delta = (ang - self.prev_angle + math.pi) % (2 * math.pi) - math.pi  # normaliza a -pi..pi
        self.prev_angle = ang
        self.total_progress += delta

        # --- recompensa (EL CORAZON del RL: le dices que es "bueno") ---
        reward = delta * R_MID * 0.1        # + por avanzar en el sentido del circuito
        reward -= 0.01                      # pequeno castigo por paso (evita quedarse quieto)

        # --- fin de episodio ---
        r = np.linalg.norm(self.pos - CENTER)
        crashed = r < R_INNER or r > R_OUTER
        if crashed:
            reward = -10.0                  # choque: castigo fuerte
        terminated = bool(crashed)
        truncated = self.steps >= MAX_STEPS

        if self.render_mode == "human":
            self.render()
        return self._get_obs(), reward, terminated, truncated, {"laps": self.total_progress / (2 * math.pi)}

    # ------------------------------------------------------------------
    def render(self):
        import pygame
        if self._screen is None:
            pygame.init()
            self._screen = pygame.display.set_mode((800, 600))
            pygame.display.set_caption("IA Coche RL")
            self._clock = pygame.time.Clock()
        pygame.event.pump()
        s = self._screen
        s.fill((40, 120, 50))
        pygame.draw.circle(s, (70, 70, 75), CENTER, R_OUTER)
        pygame.draw.circle(s, (40, 120, 50), CENTER, R_INNER)
        # rayos
        for a in RAY_ANGLES:
            d = self._ray_distance(self.heading + a) * RAY_MAX
            end = self.pos + d * np.array([math.cos(self.heading + a), math.sin(self.heading + a)])
            pygame.draw.line(s, (255, 220, 0), self.pos, end, 1)
        # coche
        pygame.draw.circle(s, (220, 40, 40), self.pos, 8)
        nose = self.pos + 14 * np.array([math.cos(self.heading), math.sin(self.heading)])
        pygame.draw.line(s, (255, 255, 255), self.pos, nose, 3)
        pygame.display.flip()
        self._clock.tick(60)

    def close(self):
        if self._screen is not None:
            import pygame
            pygame.quit()
            self._screen = None

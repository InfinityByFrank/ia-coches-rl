"""
car_env.py  -  ENTORNO v2: circuitos con curvas, DISTINTO en cada episodio

Diferencia clave con car_env_ring.py (el anillo original):
  - Antes: siempre la misma pista circular  -> el coche podia "memorizar".
  - Ahora: en cada reset() se genera una pista nueva con curvas aleatorias.
           Para puntuar bien tiene que aprender A CONDUCIR, no a recorrer un circuito concreto.
           Eso es generalizar.

Como se define la pista: una "linea central" (lista de puntos) + un ancho.
  - Fuera de pista  = distancia a la linea central > mitad del ancho
  - Progreso        = cuanto avanza el indice del punto central mas cercano
La observacion, la accion y la recompensa son IGUALES que en la version del anillo,
asi el unico cambio es el mundo. Si el modelo sigue funcionando, es que generaliza.
"""
import math
import numpy as np
import gymnasium as gym
from gymnasium import spaces

CENTER = np.array([400.0, 300.0])
N_POINTS = 360            # resolucion de la linea central
BASE_RADIUS = 180.0       # radio medio del circuito
HALF_WIDTH = 38.0         # mitad del ancho de la carretera
MIN_TURN_RADIUS = 60.0    # curva mas cerrada permitida (mayor que HALF_WIDTH: si no, imposible)

# ---- Sensores ----
N_RAYS = 7
RAY_ANGLES = np.linspace(-math.pi / 2, math.pi / 2, N_RAYS)
RAY_MAX = 150.0
RAY_STEP = 3.0
RAY_DISTS = np.arange(0.0, RAY_MAX, RAY_STEP)   # puntos a comprobar a lo largo de cada rayo

# ---- Fisica ----
MAX_SPEED = 6.0
ACCEL = 0.25
MAX_STEER = 0.08
MAX_STEPS = 1500


class CarEnv(gym.Env):
    metadata = {"render_modes": ["human"], "render_fps": 60}

    def __init__(self, render_mode=None, fixed_track=False):
        """fixed_track=True -> siempre la misma pista (para comparar memorizar vs generalizar)."""
        super().__init__()
        self.render_mode = render_mode
        self.fixed_track = fixed_track
        self.action_space = spaces.Box(low=-1.0, high=1.0, shape=(2,), dtype=np.float32)
        self.observation_space = spaces.Box(low=0.0, high=1.0, shape=(N_RAYS + 1,), dtype=np.float32)
        self._screen = None
        self._clock = None
        self._track_surface = None

    # ------------------------------------------------------------------
    # GENERACION DE PISTAS
    # ------------------------------------------------------------------
    def _make_track(self, rng):
        """Radio en funcion del angulo: r(t) = R + suma de ondas (armonicos 2, 3, 4).
        Al ser r(t) una funcion del angulo, la pista nunca se cruza consigo misma.
        Si alguna curva sale demasiado cerrada, se descarta y se prueba otra."""
        t = np.linspace(0, 2 * math.pi, N_POINTS, endpoint=False)
        while True:
            r = BASE_RADIUS + sum(
                rng.uniform(0, amp) * np.cos(k * t + rng.uniform(0, 2 * math.pi))
                for k, amp in ((2, 45), (3, 30), (4, 18))
            )
            pts = CENTER + r[:, None] * np.stack([np.cos(t), np.sin(t)], axis=1)
            # curvatura = 1 / radio de giro (formula con derivadas periodicas)
            x, y = pts[:, 0], pts[:, 1]
            dx, dy = (np.roll(x, -1) - np.roll(x, 1)) / 2, (np.roll(y, -1) - np.roll(y, 1)) / 2
            ddx, ddy = np.roll(x, -1) - 2 * x + np.roll(x, 1), np.roll(y, -1) - 2 * y + np.roll(y, 1)
            curvature = np.abs(dx * ddy - dy * ddx) / (dx**2 + dy**2) ** 1.5
            if curvature.max() < 1.0 / MIN_TURN_RADIUS:
                seg = np.linalg.norm(np.roll(pts, -1, axis=0) - pts, axis=1)
                return pts, seg.sum()

    # ------------------------------------------------------------------
    # SENSORES
    # ------------------------------------------------------------------
    def _dist2_to_track(self, points):
        """Distancia^2 de cada punto a la linea central (el punto central mas cercano)."""
        d2 = ((points[..., None, :] - self.track) ** 2).sum(-1)
        return d2.min(-1)

    def _ray_dists(self):
        """Las 7 distancias a la pared, calculadas de golpe (vectorizado con numpy)."""
        angles = self.heading + RAY_ANGLES
        dirs = np.stack([np.cos(angles), np.sin(angles)], axis=1)               # (7, 2)
        pts = self.pos + dirs[:, None, :] * RAY_DISTS[None, :, None]            # (7, K, 2)
        off = self._dist2_to_track(pts) > HALF_WIDTH**2                         # (7, K)
        first = off.argmax(axis=1)                                              # primer punto fuera
        return np.where(off.any(axis=1), RAY_DISTS[first] / RAY_MAX, 1.0)

    def _get_obs(self):
        return np.append(self._ray_dists(), self.speed / MAX_SPEED).astype(np.float32)

    # ------------------------------------------------------------------
    def reset(self, seed=None, options=None):
        super().reset(seed=seed)
        # fixed_track: generador con semilla fija -> sale siempre la misma pista
        rng = np.random.default_rng(0) if self.fixed_track else self.np_random
        self.track, self.track_len = self._make_track(rng)
        self._track_surface = None

        # El coche aparece en un punto de la linea central, mirando en el sentido del circuito
        self.idx = int(self.np_random.integers(N_POINTS))
        self.prev_idx = self.idx
        self.pos = self.track[self.idx].copy()
        tangent = self.track[(self.idx + 1) % N_POINTS] - self.track[self.idx - 1]
        self.heading = math.atan2(tangent[1], tangent[0]) + self.np_random.uniform(-0.1, 0.1)
        self.speed = 0.0
        self.steps = 0
        self.total_progress = 0.0
        return self._get_obs(), {}

    def step(self, action):
        steer, throttle = float(action[0]), float(action[1])

        self.speed = float(np.clip(self.speed + throttle * ACCEL, 0.0, MAX_SPEED))
        self.heading += steer * MAX_STEER * (0.4 + self.speed / MAX_SPEED)
        self.pos = self.pos + self.speed * np.array([math.cos(self.heading), math.sin(self.heading)])
        self.steps += 1

        # --- progreso: cuantos puntos de la linea central hemos avanzado ---
        d2 = ((self.pos - self.track) ** 2).sum(-1)
        self.idx = int(d2.argmin())
        delta_idx = (self.idx - self.prev_idx + N_POINTS // 2) % N_POINTS - N_POINTS // 2
        self.prev_idx = self.idx
        progress = delta_idx * self.track_len / N_POINTS          # en pixeles
        self.total_progress += progress

        # --- recompensa (misma formula que en el anillo) ---
        reward = progress * 0.1 - 0.01
        crashed = d2.min() > HALF_WIDTH**2
        if crashed:
            reward = -10.0
        terminated = bool(crashed)
        truncated = self.steps >= MAX_STEPS

        if self.render_mode == "human":
            self.render()
        return self._get_obs(), reward, terminated, truncated, {"laps": self.total_progress / self.track_len}

    # ------------------------------------------------------------------
    def _build_track_surface(self, pygame):
        surf = pygame.Surface((800, 600))
        surf.fill((40, 120, 50))
        for p in self.track:                                   # carretera = circulos solapados
            pygame.draw.circle(surf, (70, 70, 75), p, HALF_WIDTH)
        for p in self.track[::6]:                              # linea central discontinua
            pygame.draw.circle(surf, (200, 200, 200), p, 1.5)
        return surf

    def render(self):
        import pygame
        if self._screen is None:
            pygame.init()
            self._screen = pygame.display.set_mode((800, 600))
            pygame.display.set_caption("IA Coche RL - circuitos aleatorios")
            self._clock = pygame.time.Clock()
        pygame.event.pump()
        if self._track_surface is None:
            self._track_surface = self._build_track_surface(pygame)
        s = self._screen
        s.blit(self._track_surface, (0, 0))
        for a, d in zip(RAY_ANGLES, self._ray_dists()):
            end = self.pos + d * RAY_MAX * np.array([math.cos(self.heading + a), math.sin(self.heading + a)])
            pygame.draw.line(s, (255, 220, 0), self.pos, end, 1)
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

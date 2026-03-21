extends Node
## Constants — valores de gameplay, game feel y tuning visual.
## Versión comercial indie con todos los parámetros de feel ajustados.

# ── Jugador ──────────────────────────────────────────────
const PLAYER_SPEED_WALK    := 5.2
const PLAYER_SPEED_SPRINT  := 12.0
const PLAYER_JUMP_FORCE    := 7.5
const PLAYER_GRAVITY       := 22.0
const PLAYER_MAX_HEALTH    := 100.0
const PLAYER_HEALTH_REGEN_PER_ABSORB := 30.0

# ── Absorción ────────────────────────────────────────────
const ABSORB_RANGE   := 2.8
const ABSORB_TIME    := 1.6   # ligeramente más rápido = más satisfactorio

# ── Game Feel ────────────────────────────────────────────
const ABSORB_SLOWMO_SCALE    := 0.18   # time_scale al completar absorción
const ABSORB_SLOWMO_DURATION := 0.22   # segundos de slow-mo
const ABSORB_CAM_SHAKE       := 0.85   # trauma al absorber
const DAMAGE_CAM_SHAKE       := 0.60
const JUMP_LAND_SQUASH       := 0.12   # escala Y de squash al aterrizar
const JUMP_SQUASH_SPEED      := 14.0
const CAM_FOV_NORMAL         := 75.0
const CAM_FOV_SPRINT         := 82.0
const CAM_FOV_ABSORB         := 65.0   # zoom in durante absorción
const CAM_FOV_SPEED          := 6.0    # velocidad de transición FOV
const VIGNETTE_DANGER_HP     := 35.0   # hp por debajo del cual aparece viñeta
const HEARTBEAT_BPM_LOW      := 72.0
const HEARTBEAT_BPM_HIGH     := 140.0

# ── Habilidades pasivas ───────────────────────────────────
const ABILITY_SPEED_MULT   := 2.0
const ABILITY_JUMP_MULT    := 2.8
const ABILITY_SPEED_DUR    := 15.0
const ABILITY_JUMP_DUR     := 20.0
const ABILITY_STEALTH_DUR  := 12.0
const ABILITY_SENSE_DUR    := 25.0
const ABILITY_FUERZA_DR    := 0.30

# ── Habilidades activas ───────────────────────────────────
const SKILL_DASH_COOLDOWN  := 5.0
const SKILL_DASH_DISTANCE  := 10.0
const SKILL_DASH_UNLOCK    := 2
const SKILL_PULSE_COOLDOWN := 15.0
const SKILL_PULSE_RADIUS   := 8.0
const SKILL_PULSE_STUN_TIME:= 4.0
const SKILL_PULSE_UNLOCK   := 4
const SKILL_CAMO_COOLDOWN  := 22.0
const SKILL_CAMO_DURATION  := 9.0
const SKILL_CAMO_UNLOCK    := 6

# ── Progresión ────────────────────────────────────────────
const XP_PER_WORKER   := 50
const XP_PER_SECURITY := 120
const MAX_LEVEL       := 10
const LEVEL_XP        := [0, 100, 250, 450, 700, 1000, 1350, 1750, 2200, 2700]
const HEALTH_PER_LEVEL:= 15.0
const POWER_DR_PER_ABSORB := 0.015
const POWER_DR_MAX        := 0.50

# ── Trabajadores ──────────────────────────────────────────
const WORKER_SPEED_PATROL      := 1.8
const WORKER_SPEED_ALERT       := 3.2   # más rápido en alerta
const WORKER_SPEED_FLEE        := 6.0   # huyen más rápido
const WORKER_DETECT_RANGE      := 5.5
const WORKER_DETECT_RANGE_FOV  := 11.0
const WORKER_FOV_ANGLE         := 1.05
const WORKER_PATROL_MAX_DIST   := 12.0
const WORKER_HIDE_DIST         := 14.0
const WORKER_PANIC_DURATION    := 0.6   # segundos de animación de pánico inicial
const WORKER_CALL_RADIUS       := 12.0  # radio para alertar a otros workers

# ── Guardias ─────────────────────────────────────────────
const GUARD_SPEED_PATROL        := 2.5
const GUARD_SPEED_INVESTIGATE   := 3.8
const GUARD_SPEED_CHASE         := 7.0
const GUARD_SPEED_LOCKDOWN      := 9.0
const GUARD_FOV_DISTANCE        := 14.0
const GUARD_FOV_DISTANCE_ALARM  := 20.0
const GUARD_FOV_ANGLE           := 0.70
const GUARD_FOV_ANGLE_ALARM     := 1.10
const GUARD_ATTACK_RANGE        := 1.8
const GUARD_ATTACK_DAMAGE       := 12.0
const GUARD_ATTACK_COOLDOWN     := 1.4
const GUARD_SUSPICIOUS_TIME     := 1.8
const GUARD_INVESTIGATE_TIME    := 9.0
const GUARD_MEMORY_TIME         := 14.0
const GUARD_RADIO_RANGE         := 22.0  # distancia para compartir last_known
const GUARD_FLANK_OFFSET        := 3.5   # distancia de flanqueo

# ── Alarma ────────────────────────────────────────────────
const ALARM_ALERTA_TIMEOUT    := 12.0
const ALARM_ALARMA_TIMEOUT    := 20.0
const ALARM_LOCKDOWN_DURATION := 30.0
const ALARM_SUSPICIOUS_TIMEOUT:= 8.0

# ── Nivel ─────────────────────────────────────────────────
const LEVEL_WALL_HEIGHT := 4.0
const LEVEL_WALL_THICK  := 0.4
const VENT_HEIGHT       := 2.2
const VENT_WIDTH        := 1.5
const DOOR_REQ_ARCHIVO  := 2
const DOOR_REQ_CAMARA_FRIA := 3
const XP_ORB_SMALL     := 75
const XP_ORB_LARGE     := 150
const DOOR_OPEN_TIME   := 0.55

# ── Efectos de entorno dinámicos ──────────────────────────
const FLICKER_INTERVAL_MIN := 3.0   # segundos mínimos entre parpadeos de luz
const FLICKER_INTERVAL_MAX := 12.0
const DRIP_INTERVAL_MIN    := 8.0
const DRIP_INTERVAL_MAX    := 25.0

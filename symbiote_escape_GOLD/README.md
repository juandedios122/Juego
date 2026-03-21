# Symbiote Escape — v4 (Godot 4.6)

## Controles
| Acción | Tecla |
|---|---|
| Mover | WASD |
| Absorber | E |
| Sprint | Shift |
| Saltar | Espacio |
| Pausa | ESC |
| Saltar cinemática | Enter |

## Cómo abrir
1. Abrir Godot 4.6
2. Import → seleccionar `project.godot`
3. La escena principal es `scenes/main_menu.tscn`

## Autoloads
- `GM` — GameManager (estado global, transiciones)
- `Alarm` — AlarmSystem (niveles de alerta 0-3)
- `SaveMgr` — SaveManager (opciones y puntuación)

## Estructura
```
scripts/
  core/          — singletons globales
  systems/       — cinemática, generador de nivel, level manager
  entities/
    player/      — symbiote_controller, ability_system
    enemies/     — worker_ai, security_ai
  ui/            — hud, main_menu, pause_menu, game_over, victory, options
scenes/
  player/, enemies/, ui/
shaders/
```

## Sistemas implementados
- Nivel procedural completo (7 salas + corredores + reactor)
- Personaje con animación orgánica via _process
- Partículas CPUParticles3D en absorción
- Sistema de 5 habilidades con temporizadores
- IA trabajadores (patrulla/huida) y guardias (FOV/alerta/ataque)
- Sistema de alerta 4 niveles con luces pulsantes
- HUD: salud, absorciones, alerta, habilidad activa
- Menú principal + pausa + opciones + game over + victoria
- Guardado de puntuación máxima y opciones (ConfigFile)

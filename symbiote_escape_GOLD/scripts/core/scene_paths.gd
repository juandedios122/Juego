extends Node
## ScenePaths — constantes de rutas de escena.
## Centralizar aquí evita magic strings dispersos en el código.
## Usar: ScenePaths.MAIN_MENU, ScenePaths.GAME_LEVEL, etc.

const MAIN_MENU      := "res://scenes/main_menu.tscn"
const INTRO          := "res://scenes/intro_cinematic.tscn"
const GAME_LEVEL     := "res://scenes/game_level.tscn"
const GAME_OVER      := "res://scenes/game_over.tscn"
const VICTORY        := "res://scenes/victory.tscn"

const PLAYER         := "res://scenes/player/symbiote.tscn"
const WORKER         := "res://scenes/enemies/worker.tscn"
const SECURITY       := "res://scenes/enemies/security.tscn"

const HUD            := "res://scenes/ui/hud.tscn"
const PAUSE_MENU     := "res://scenes/ui/pause_menu.tscn"

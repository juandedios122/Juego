# Sprites — Instrucciones

Coloca aquí los spritesheets PNG para cada personaje.
El juego los carga automáticamente. Si no existen, usa el visual por código.

## Estructura esperada

```
assets/sprites/
  symbiote/
	idle.png        — 4 frames, 128x128 px cada uno (fila horizontal)
	walk.png        — 6 frames, 128x128 px
	absorb.png      — 6 frames, 128x128 px
	dash.png        — 4 frames, 128x128 px

  guard/
	idle.png        — 4 frames, 64x128 px
	walk.png        — 6 frames, 64x128 px
	chase.png       — 6 frames, 64x128 px
	attack.png      — 4 frames, 64x128 px
	absorb.png      — 4 frames, 64x128 px (siendo absorbido)

  worker/
	idle.png        — 4 frames, 64x128 px
	walk.png        — 6 frames, 64x128 px
	panic.png       — 4 frames, 64x128 px
	flee.png        — 6 frames, 64x128 px
	hide.png        — 2 frames, 64x128 px
	absorb.png      — 4 frames, 64x128 px
```

## Fuentes gratuitas recomendadas

- https://itch.io/game-assets/free/tag-sprites  (busca "character sprite sheet")
- https://opengameart.org/content/lpc-character-sprites
- https://craftpix.net/freebies/  (personajes 2D gratis)

## Venom / Simbionte
Busca en itch.io: "slime character sprite" o "monster character sprite sheet"
Ejemplo gratuito: https://itch.io/game-assets/free/tag-slime

## Guardias
Busca: "soldier sprite sheet" o "guard character 2d"
Ejemplo: https://opengameart.org/content/lpc-medieval-fantasy-character-sprites

## Tamaño recomendado
- Frames de 64x128 px para enemigos
- Frames de 128x128 px para el simbionte (más grande)
- Fondo transparente (PNG con alpha)

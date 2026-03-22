# 🕷️ SYMBIOTE ESCAPE - UPGRADE VISUAL COMPLETO
## Guía de instalación para Godot 4.6.1

---

## 📁 ESTRUCTURA DE ARCHIVOS

```
res://
├── shaders/
│   ├── symbiote_body.gdshader     ← Shader del personaje (estilo Venom)
│   ├── symbiote_eyes.gdshader     ← Ojos brillantes amenazantes
│   ├── floor_wet.gdshader         ← Suelo mojado con líneas de energía
│   ├── wall_symbiote.gdshader     ← Paredes de concreto infectadas
│   └── pillar_infected.gdshader   ← Pilares metálicos con simbionte
├── particles/
│   ├── symbiote_aura.gd           ← Aura del personaje
│   ├── symbiote_tendrils.gd       ← Tentáculos en el suelo
│   └── absorb_effect.gd           ← Efecto de absorción de enemigos
├── scripts/
│   ├── symbiote_lighting_manager.gd ← Sistema de iluminación completo
│   └── vfx_controller.gd          ← Efectos de cámara y pantalla
└── ui/
    └── symbiote_hud.gd            ← HUD mejorado estilo Venom
```

---

## 🚀 INSTALACIÓN PASO A PASO

### PASO 1: CONFIGURAR EL PERSONAJE SIMBIONTE

1. Selecciona el MeshInstance3D de tu simbionte (la esfera oscura)
2. En Inspector > Surface Material Override > [0]
3. Crea un **ShaderMaterial** nuevo
4. Asigna `shaders/symbiote_body.gdshader`
5. Ajusta los parámetros:
   - `color_base`: negro azulado oscuro (0.04, 0.01, 0.08)
   - `color_venas`: púrpura (0.35, 0.0, 0.6)
   - `color_glow`: violeta brillante (0.6, 0.0, 1.0)
   - `vein_intensity`: 1.8
   - `rim_strength`: 1.4

### PASO 2: OJOS DEL SIMBIONTE

Si tienes las esferas de los ojos como MeshInstance3D separadas:
1. Crea ShaderMaterial con `symbiote_eyes.gdshader`
2. Ajusta `glow_intensity` a 3.0+
3. Activa **transparency = Alpha** en el material

Si los ojos están en el mismo mesh, crea un MeshInstance3D encima
con SphereShape más pequeña solapada.

### PASO 3: MATERIALES DEL ESCENARIO

**Suelo:**
1. Selecciona el MeshInstance3D del piso
2. Crea ShaderMaterial con `floor_wet.gdshader`
3. Ajusta `tile_scale` a 3.0-5.0 según el tamaño del nivel

**Paredes:**
1. Cada pared: ShaderMaterial con `wall_symbiote.gdshader`
2. Sube `vein_coverage` a 0.3-0.6 para más invasión symbiote
3. `crack_glow_intensity`: 1.5 para grietas brillantes

**Pilares (cilindros):**
1. ShaderMaterial con `pillar_infected.gdshader`
2. `infection_amount`: 0.4-0.7 (qué tanto está infectado)

### PASO 4: ILUMINACIÓN

1. Agrega un nodo **Node** vacío en la raíz de la escena
2. Asígnale `scripts/symbiote_lighting_manager.gd`
3. Elimina todas tus luces actuales (el script las crea automático)
4. En `_ready()`, llama: `attach_to_player(tu_nodo_jugador)`

**IMPORTANTE**: En Project Settings → Rendering → Lights and Shadows:
- `use_physical_light_units`: ON
- `directional_shadow_size`: 4096
- En Rendering → Global Illumination:
  - `gi_probes_quality`: HIGH

### PASO 5: POST-PROCESADO (WorldEnvironment)

1. Crea un nodo **WorldEnvironment**
2. Crea Environment nuevo
3. Configura estos valores CRÍTICOS:

```
Background Mode: Color
Background Color: (0.01, 0.005, 0.02)

Ambient:
  Source: Color  
  Color: (0.06, 0.0, 0.12)
  Energy: 0.5

Tonemap:
  Mode: ACES
  Exposure: 1.1
  White: 6.0

Glow: ✅ ACTIVADO
  Intensity: 0.85
  Strength: 1.1  
  Bloom: 0.12
  Blend Mode: Softlight
  HDR Threshold: 0.8

SSAO: ✅ ACTIVADO
  Radius: 1.0
  Intensity: 2.5

SSR: ✅ ACTIVADO
  Max Steps: 64

Volumetric Fog: ✅ ACTIVADO
  Density: 0.012
  Albedo: (0.04, 0.0, 0.08)
  Emission: (0.05, 0.0, 0.15)

Adjustment: ✅ ACTIVADO
  Contrast: 1.12
  Saturation: 1.2
```

### PASO 6: PARTÍCULAS DE AURA

1. Añade nodo hijo **GPUParticles3D** al simbionte
2. Asigna script `particles/symbiote_aura.gd`
3. Añade otro GPUParticles3D hijo llamado "Tendrils"
4. Asigna script `particles/symbiote_tendrils.gd`

### PASO 7: EFECTOS DE CÁMARA

1. Selecciona tu nodo **Camera3D**
2. Asigna script `scripts/vfx_controller.gd`
3. En tu script de juego, llama:
   ```gdscript
   @onready var vfx = $Camera3D  # ajusta la ruta
   
   # Al absorber:
   vfx.absorb_pulse()
   
   # Al recibir daño:
   vfx.damage_flash()
   
   # Al subir de nivel:
   vfx.level_up_flash()
   ```

### PASO 8: HUD MEJORADO

1. Elimina tu CanvasLayer/HUD actual (o renómbralo como backup)
2. Crea nuevo CanvasLayer → Control
3. Asigna `ui/symbiote_hud.gd` al Control
4. Conecta las funciones a tu sistema de juego:
   ```gdscript
   # Obtener referencia
   @onready var hud = $CanvasLayer/Control
   
   # Actualizar valores
   hud.update_energy(current_energy, max_energy)
   hud.update_vitality(current_vitality, max_vitality)
   hud.update_absorptions(absorbidos, archivo, archivo_max, camara, camara_max)
   hud.update_objetivo("Absorbe 1 enemigo más para abrir CÁMARA FRÍA")
   ```

---

## ⚙️ AJUSTES DE RENDIMIENTO

### Para PC media/baja:
```
Volumetric Fog: ❌ DESACTIVADO (mayor impacto)
SSR: ❌ DESACTIVADO
SSAO Radius: 0.5
Glow Intensity: 0.6
```

### Para PC alta/recomendada:
```
Todo activado como se indica
SSIL: ✅ ACTIVADO
Shadow Atlas Size: 4096
```

### En Project Settings → Rendering:
- `renderer/rendering_method`: Forward+  (necesario para SSR, SSIL)
- `textures/default_filters/use_nearest_mipmap_filter`: OFF
- `anti_aliasing/quality/msaa_3d`: 4x

---

## 🎨 PALETA DE COLORES

```
Negro Simbionte:  #0A0215  (0.04, 0.01, 0.08)
Púrpura Venas:   #590099  (0.35, 0.0,  0.60)
Violeta Glow:    #9900FF  (0.60, 0.0,  1.00)
Blanco Ojos:     #F0F0FF  (0.94, 0.94, 1.00)
Verde Energía:   #00E84A  (0.0,  0.91, 0.29)
```

---

## 💡 CONSEJOS EXTRA

### Mover pilares para que parezcan más amenazantes:
- Varía las alturas (algunos más altos, otros tumbados)
- Añade pilares rotos o inclinados
- Cluster de 2-3 pilares juntos

### Iluminación dramática:
- Coloca OmniLight3D de color púrpura (energy=2.0, range=3.0) DENTRO de las grietas de las paredes
- Un SpotLight3D rojo tenue desde arriba crea tensión

### Para el efecto "infected lab":
- Añade slime/liquid mesh plano encima del suelo con `floor_wet.gdshader` a escala 0.3
- Usa `wet_amount = 1.0` para zonas encharcadas

---

## 🐛 ERRORES COMUNES

**"El shader no compila":**
→ Godot 4.6 requiere `render_mode` en la primera línea del shader

**"El glow no se ve":**
→ Activa `glow_enabled = true` en WorldEnvironment
→ El Forward+ renderer es NECESARIO para glow (no Compatibility)

**"SSAO muy agresivo":**  
→ Baja `ssao_intensity` a 1.5 y `ssao_radius` a 0.6

**"FPS muy bajo:"**
→ Desactiva Volumetric Fog primero (cuesta ~5-15fps)
→ Reduce shadow atlas size

---

¡Listo! Tu simbionte ahora se verá como Venom en un juego comercial 🕷️

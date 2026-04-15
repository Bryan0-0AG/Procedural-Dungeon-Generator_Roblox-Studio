# 🗺️ Generación Procedural de Mapas — Roblox Studio

> Un generador procedural de mazmorras modular y orientado a datos para Roblox, construido íntegramente en Lua. Genera redes de corredores ramificados con detección de colisiones, selección de salas ponderada, gestión de spawns y sellado automático de callejones sin salida — todo en tiempo de ejecución.

---

## 📋 Tabla de contenidos

- [Descripción general](#descripción-general)
- [Características](#características)
- [Estructura del proyecto](#estructura-del-proyecto)
- [Tipos de habitación](#tipos-de-habitación)
- [Inicio rápido](#inicio-rápido)
- [Configuración](#configuración)
- [Cómo funciona](#cómo-funciona)
- [Assets](#assets)

---

## Descripción general

Este sistema genera un mapa completo de mazmorra en tiempo de ejecución encadenando plantillas de habitaciones modulares. Partiendo desde una sala de spawn, se expande hacia afuera a través de corredores que desembocan en salas raíz ramificadas, respeta los límites de colisión y sella los callejones con piezas de pared o salas finales. El número de ramas, la longitud de los corredores y las probabilidades de cada habitación son completamente configurables.

---

## ✨ Características

- **100% procedural** — cada ejecución genera un mapa único.
- **Selección ponderada de habitaciones** — las salas tienen un atributo `Probability` configurable (`NumberRange`) que controla la frecuencia con la que aparecen.
- **Placement con detección de colisiones** — las habitaciones superpuestas se detectan y se reemplazan por paredes o tipos alternativos, evitando geometría inválida.
- **Arquitectura ramificada** — las salas raíz (en T y en cruz) se expanden en múltiples corredores simultáneamente, creando diseños orgánicos.
- **Restricción de repetición** — las habitaciones pueden marcarse con `RepRestriction` para evitar que el mismo tipo aparezca dos veces seguidas.
- **Soporte multijugador** — las salas de spawn adicionales se distribuyen automáticamente entre los jugadores conectados.
- **Sellado automático de callejones** — los puntos de conexión sobrantes se cierran con salas finales o paredes.
- **Modo debug** — generación paso a paso con delays configurables para inspección visual.
- **Plug-and-play** — inserta `Map_generation_folder.rbxm` en cualquier place y funciona de inmediato.

---

## 📁 Estructura del proyecto

```
Workspace/
└── Folder (raíz del sistema — ponle el nombre que quieras)
    ├── Main.lua              ← ServerScript — punto de entrada y bucle de generación
    │   ├── Configuration.lua ← ModuleScript — parámetros globales
    │   ├── Functions.lua     ← ModuleScript — toda la lógica de generación
    │   └── Rooms.lua         ← ModuleScript — definición de tipos de habitación
    ├── Templates/            ← Modelos de plantillas organizados por tipo
    └── Generation/           ← Creada automáticamente en tiempo de ejecución
```

### Archivos en este repositorio

| Archivo | Descripción |
|---|---|
| `Main.lua` | Script servidor. Orquesta todo el pipeline de generación. |
| `Configuration.lua` | Configuración global: rango de longitud de corredor, máximo de ramas, posición de spawn, etc. |
| `Functions.lua` | Lógica central: selección de plantillas, conexión de salas, detección de solapamientos, etc. |
| `Rooms.lua` | Declara todas las familias y tipos de habitación con sus arrays de plantillas. |
| `Map_generation_folder.rbxm` | 📦 Modelo de Roblox listo para insertar con el sistema completo. |
| `Templates.rbxm` | 📦 Todas las plantillas de habitación ya configuradas con sus attachments. |
| `Procedural_map_gen.rbxl` | 🎮 Place completa de Roblox — ábrela y dale a Play para verlo en acción. |
| `assets/Showcase_Video.mp4` | 🎬 Video de demostración del sistema funcionando. |

---

## 🚪 Tipos de habitación

Las habitaciones se agrupan en **familias** que controlan dónde y cómo se colocan en el pipeline de generación.

| Familia | Tipo(s) | Rol |
|---|---|---|
| `Root` | `T`, `+` | Salas hub con múltiples salidas que ramifican el mapa. |
| `Corridor` | `I`, `I2` | Segmentos de pasillo recto que conectan salas raíz. |
| `Corner` | `L` | Piezas de giro usadas dentro de los corredores. |
| `Habitation` | `H` | Salas especiales opcionales colocadas en línea con los corredores. |
| `Spawn` | `S` | Sala inicial; también usada para spawns adicionales de jugadores. |
| `End` | `E` | Cierra las conexiones abiertas al final de la generación. |
| `Walls` | `W` | Sellado de emergencia cuando una sala final solaparía geometría existente. |

Cada plantilla de habitación es un `Model` de Roblox con:
- Una parte **`In`** — punto de entrada (con un hijo `Attachment`).
- Una o más partes **`Out`** — puntos de salida (cada una con un hijo `Attachment`).
- Un atributo **`Type`** — debe coincidir con uno de los tipos definidos en `Rooms.lua`.
- Un atributo opcional **`Probability`** (`NumberRange`) — controla la selección ponderada.
- Un atributo opcional **`RepRestriction`** (`bool`) — evita la repetición consecutiva.

---

## 🚀 Inicio rápido

### Opción A — Place completa (más rápido)
1. Abre `Procedural_map_gen.rbxl` en Roblox Studio.
2. Pulsa **Play** o **Run**. El mapa se genera de inmediato.

### Opción B — Insertar en tu propia place
1. Inserta `Map_generation_folder.rbxm` en tu `Workspace`.
2. Inserta `Templates.rbxm` como hijo de esa carpeta (debe llamarse `Templates`).
3. Asegúrate de que `Main.lua` es un **ServerScript** dentro de la carpeta.
4. Pulsa **Play**.

### Opción C — Configuración manual
1. Crea una `Folder` en `Workspace`.
2. Añade un `ServerScript` llamado `Main` con el contenido de `Main.lua`.
3. Añade `ModuleScript`s llamados `Configuration`, `Functions` y `Rooms` como hijos de `Main`, con sus respectivos contenidos.
4. Añade una carpeta `Templates` con tus modelos de habitación organizados en subcarpetas por tipo.
5. Pulsa **Play**.

---

## ⚙️ Configuración

Edita `Configuration.lua` para ajustar el generador:

```lua
module = {
    CORRIDOR_LENGHT   = NumberRange.new(1, 8),  -- Mínimo/máximo de salas por segmento de corredor
    MAX_BRANCHES      = 15,                      -- Total de salas raíz a generar
    SPAWNPOS          = CFrame.new(0, 30, 0),   -- Posición mundial de la primera sala
    roomGenerationTag = "Rooms",                -- Tag de CollectionService aplicado a todas las salas generadas
}
```

Activa `debug_mode = true` en `Main.lua` para ralentizar la generación y observar cada paso visualmente.

---

## ⚙️ Cómo funciona

La generación sigue un pipeline basado en cola en cuatro etapas:

**1. Sala de spawn** — Se coloca una sala de familia `Spawn` en `SPAWNPOS`. Su attachment `Out` se añade a la cola de conexiones.

**2. Bucle principal** — Mientras `rootsGenerated < MAX_BRANCHES` y la cola no esté vacía:
- Por cada conexión en cola, se genera un **corredor** (una cadena de longitud aleatoria con salas `Corridor`, `Corner` y `Habitation`).
- Al final de cada corredor se coloca una **sala raíz**. Sus attachments `Out` vuelven a la cola para el siguiente ciclo.
- Si una sala solapa geometría existente, se destruye y se reemplaza por una pared o una sala `T` forzada para redirigir el flujo.

**3. Fase de cierre** — Una vez alcanzado el límite de ramas:
- Las conexiones sobrantes que correspondan a jugadores activos reciben salas de spawn adicionales.
- El resto de conexiones abiertas se sellan con salas `End` o `Wall`.

**4. Finalización** — La carpeta del mapa recibe el atributo `Generated = true`, indicando al resto de sistemas que el mapa está listo.

La colocación de salas usa matemáticas de `CFrame`: el attachment `In` de cada sala nueva se alinea al attachment `Out` de la sala anterior con una rotación de 180° en el eje Y, de modo que queden correctamente enfrentadas.

---

## 🎬 Assets

| Archivo | Descripción |
|---|---|
| `assets/Showcase_Video.mp4` | Video completo del sistema generando y funcionando dentro del juego. |

---

## 📄 Licencia

MIT — libre para usar y modificar en tus propios proyectos de Roblox.

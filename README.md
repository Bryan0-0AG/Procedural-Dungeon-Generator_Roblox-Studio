# 🗺️ Procedural Dungeon Generation — Roblox Studio

> A modular, data-driven procedural dungeon generator for Roblox, built entirely in Lua. Generates branching corridor networks with collision detection, weighted room selection, spawn management, and automatic dead-end sealing — all at runtime.

---

## 📋 Table of contents

- [Overview](#overview)
- [Features](#features)
- [Project structure](#project-structure)
- [Room types](#room-types)
- [Quick start](#quick-start)
- [Configuration](#configuration)
- [How it works](#how-it-works)
- [Assets](#assets)

---

## Overview

This system generates a complete dungeon map at runtime by chaining modular room templates. Starting from a spawn room, it expands outward through corridors that lead into branching root rooms, respects collision boundaries, and seals dead ends with wall pieces or end rooms. The number of branches, corridor length, and room probabilities are fully configurable.

---

## ✨ Features

- **100% procedural** — every run generates a unique map.
- **Weighted room selection** — rooms have a configurable `Probability` attribute (`NumberRange`) that controls how often they appear.
- **Collision-aware placement** — overlapping rooms are detected and replaced with walls or alternative types, preventing invalid geometry.
- **Branching architecture** — root rooms (T-shaped and cross-shaped) expand into multiple corridors simultaneously, creating organic layouts.
- **Repetition restriction** — rooms can be flagged with `RepRestriction` to prevent the same type from appearing twice in a row.
- **Multiplayer support** — additional spawn rooms are automatically distributed among connected players.
- **Automatic dead-end sealing** — leftover connection points are closed with end rooms or walls.
- **Debug mode** — step-by-step generation with configurable delays for visual inspection.
- **Plug-and-play** — insert `Map_generation_folder.rbxm` into any place and it works immediately.

---

## 📁 Project structure

Workspace/
└── Folder (system root — name it whatever you want)
    ├── Main.lua              ← ServerScript — entry point and generation loop
    │   ├── Configuration.lua ← ModuleScript — global parameters
    │   ├── Functions.lua     ← ModuleScript — all generation logic
    │   └── Rooms.lua         ← ModuleScript — room type definitions
    ├── Templates/            ← Template models organized by type
    └── Generation/           ← Created automatically at runtime

### Files in this repository

| File | Description |
|---|---|
| `Main.lua` | Server script. Orchestrates the entire generation pipeline. |
| `Configuration.lua` | Global settings: corridor length range, max branches, spawn position, etc. |
| `Functions.lua` | Core logic: template selection, room connection, overlap detection, etc. |
| `Rooms.lua` | Declares all room families and types with their template arrays. |
| `Map_generation_folder.rbxm` | 📦 Ready-to-insert Roblox model with the complete system. |
| `Templates.rbxm` | 📦 All room templates pre-configured with their attachments. |
| `Procedural_map_gen.rbxl` | 🎮 Full Roblox place — open it and hit Play to see it in action. |
| `assets/Showcase_Video.mp4` | 🎬 Demo video of the system in action. |

---

## 🚪 Room types

Rooms are grouped into **families** that control where and how they are placed in the generation pipeline.

| Family | Type(s) | Role |
|---|---|---|
| `Root` | `T`, `+` | Hub rooms with multiple exits that branch the map. |
| `Corridor` | `I`, `I2` | Straight hallway segments connecting root rooms. |
| `Corner` | `L` | Turn pieces used inside corridors. |
| `Habitation` | `H` | Optional special rooms placed inline within corridors. |
| `Spawn` | `S` | Starting room; also used for additional player spawns. |
| `End` | `E` | Closes open connections at the end of generation. |
| `Walls` | `W` | Emergency sealing when an end room would overlap existing geometry. |

Each room template is a Roblox `Model` with:
- An **`In`** part — entry point (with an `Attachment` child).
- One or more **`Out`** parts — exit points (each with an `Attachment` child).
- A **`Type`** attribute — must match one of the types defined in `Rooms.lua`.
- An optional **`Probability`** attribute (`NumberRange`) — controls weighted selection.
- An optional **`RepRestriction`** attribute (`bool`) — prevents consecutive repetition.

---

## 🚀 Quick start

### Option A — Full place (fastest)
1. Open `Procedural_map_gen.rbxl` in Roblox Studio.
2. Press **Play** or **Run**. The map generates immediately.

### Option B — Insert into your own place
1. Insert `Map_generation_folder.rbxm` into your `Workspace`.
2. Insert `Templates.rbxm` as a child of that folder (it must be named `Templates`).
3. Make sure `Main.lua` is a **ServerScript** inside the folder.
4. Press **Play**.

### Option C — Manual setup
1. Create a `Folder` in `Workspace`.
2. Add a `ServerScript` named `Main` with the contents of `Main.lua`.
3. Add `ModuleScript`s named `Configuration`, `Functions`, and `Rooms` as children of `Main`, with their respective contents.
4. Add a `Templates` folder with your room models organized in subfolders by type.
5. Press **Play**.

---

## ⚙️ Configuration

Edit `Configuration.lua` to tune the generator:

```lua
module = {
    CORRIDOR_LENGHT   = NumberRange.new(1, 8),  -- Min/max rooms per corridor segment
    MAX_BRANCHES      = 15,                      -- Total root rooms to generate
    SPAWNPOS          = CFrame.new(0, 30, 0),   -- World position of the first room
    roomGenerationTag = "Rooms",                -- CollectionService tag applied to all generated rooms
}
```

Enable `debug_mode = true` in `Main.lua` to slow down generation and observe each step visually.

---

## ⚙️ How it works

Generation follows a four-stage queue-based pipeline:

**1. Spawn room** — A `Spawn` family room is placed at `SPAWNPOS`. Its `Out` attachment is added to the connection queue.

**2. Main loop** — While `rootsGenerated < MAX_BRANCHES` and the queue is not empty:
- For each connection in the queue, a **corridor** is generated (a randomly-lengthed chain of `Corridor`, `Corner`, and `Habitation` rooms).
- At the end of each corridor, a **root room** is placed. Its `Out` attachments are pushed back into the queue for the next cycle.
- If a room overlaps existing geometry, it is destroyed and replaced with a wall or a forced `T` room to redirect the flow.

**3. Closing phase** — Once the branch limit is reached:
- Leftover connections matching active players receive additional spawn rooms.
- All remaining open connections are sealed with `End` or `Wall` rooms.

**4. Finalization** — The map folder receives a `Generated = true` attribute, signaling to other systems that the map is ready.

Room placement uses `CFrame` math: each new room's `In` attachment is aligned to the previous room's `Out` attachment with a 180° Y-axis rotation, so they face each other correctly.

---

## 🎬 Assets

| File | Description |
|---|---|
| `assets/Showcase_Video.mp4` | Full video of the system generating and running inside the game. |

---

## 📄 License

MIT — free to use and modify in your own Roblox projects.

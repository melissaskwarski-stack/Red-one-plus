# Red One Plus

A 3-player local network co-op flying shooter built in **Godot 4**.

Three aircraft (red, blue, green) fly together across a side-scrolling level,
surviving 3 waves of enemy aircraft that patrol and shoot back.
Players connect over LAN — one device hosts, the others join by IP.

---

## How to Run

1. Clone or pull this repo
2. Open **Godot 4** and import `project.godot`
3. Press **F5** to run

Minimum Godot version: **4.3**

---

## Multiplayer — Host & Join

All players must be on the same local network.

### Host (one device only)
```gdscript
NetworkManager.host_game()
```
The host is automatically assigned **Player 1 (red)**.

### Join (all other devices)
```gdscript
NetworkManager.join_game("192.168.x.x")   # replace with host's LAN IP
```
Joining players are assigned **Player 2 (blue)** and **Player 3 (green)** in connection order.

Port used: **7777** (UDP via ENet). Make sure it is open on the host machine.

---

## Controls

| Action   | Keys               |
|----------|--------------------|
| Move     | WASD or Arrow Keys |
| Shoot    | Spacebar           |

---

## File Map

```
Red-one-plus/
│
├── project.godot                  Godot 4 project config + autoload registry
│
├── autoloads/
│   └── signal_bus.gd              Global event bus (SignalBus singleton)
│                                  All game systems communicate through signals here
│
├── scenes/
│   ├── Level1.tscn                Main level — parallax bg, camera, wave spawner
│   ├── Player.tscn                Aircraft CharacterBody2D with MultiplayerSynchronizer
│   ├── Enemy.tscn                 Enemy aircraft — patrols and shoots at players
│   ├── Bullet.tscn                Projectile fired by players and enemies
│   └── HUD.tscn                   Health bars (P1/P2/P3) + shared score label
│
└── scripts/
    ├── network_manager.gd         ENet host/join, peer→player_id assignment
    ├── player.gd                  Movement (WASD), shooting (Space), take_damage RPC
    ├── enemy.gd                   Entry, patrol ±200px, shoot toward nearest player
    ├── bullet.gd                  Flies along rotation axis, hits layer-2 enemies only
    ├── hud.gd                     Listens to SignalBus, updates bars + score + DEAD labels
    └── level1.gd                  Spawns players, runs 3 waves, dynamic camera zoom
```

---

## Collision Layers

| Layer | Who uses it       | Purpose                          |
|-------|-------------------|----------------------------------|
| 2     | Enemies           | Player bullets detect this layer |
| 3     | Bullets           | Bullets live here                |
| —     | Players           | Not on layer 2 — no friendly fire|

---

## Signal Bus — Key Signals

| Signal                                    | Fired by         | Heard by          |
|-------------------------------------------|------------------|-------------------|
| `player_health_updated(player_id, health)`| player.gd        | hud.gd            |
| `player_died(player_id)`                  | player.gd        | hud.gd, level1.gd |
| `enemy_destroyed(position)`               | enemy.gd         | level1.gd         |
| `score_changed(new_score)`                | enemy.gd         | hud.gd            |
| `wave_started(wave_number)`               | level1.gd        | hud / debug       |
| `level_complete()`                        | level1.gd        | game flow         |
| `player_connected(player_id)`             | network_manager  | hud / lobby       |
| `player_disconnected(player_id)`          | network_manager  | hud / lobby       |

---

## For Collaborators

### First time setup
```bash
git clone https://github.com/melissaskwarski-stack/Red-one-plus.git
cd Red-one-plus
```

### Pull latest main into your branch
```bash
git checkout your-branch-name
git fetch origin
git merge origin/main
```

### movement-and-control-of-player branch
This branch is responsible for player input refinement and movement polish.
Pull from `main` first to get the full project base, then build on top of:
- `scripts/player.gd` — movement and shooting logic lives here
- `scenes/Player.tscn` — node tree and MultiplayerSynchronizer config
- `autoloads/signal_bus.gd` — emit `bullet_fired` and `player_health_updated` from here

### Branch workflow
- **Never commit directly to `main`**
- Work on a named branch, open a PR when ready
- One commit per file — keep history readable

---

## Game Rules

- 3 enemy waves, one every 10 seconds
- 3 enemies per wave — each has 3 health points
- Each enemy kill = +100 score (shared)
- Players have 3 health points — no respawn
- All players dead → Game Over
- All 3 waves cleared → Level Complete

---

## Characters

Each player slot has a fixed character with unique stats and a skill activated with **Shift**.

### P1 — Crimson Ace *(red plane)*
| Stat    | Value |
|---------|-------|
| Speed   | 475 px/s |
| Health  | 3 hits |
| Attack  | 60 |

**Skill: Afterburner** — Doubles movement speed for 3 seconds. Cooldown: 10s.
> Best for flanking enemies and dodging incoming fire.

---

### P2 — Azure Guardian *(blue plane)*
| Stat    | Value |
|---------|-------|
| Speed   | 325 px/s |
| Health  | 5 hits |
| Attack  | 50 |

**Skill: Plasma Shield** — Absorbs the next incoming hit, or expires after 3 seconds. Cooldown: 15s.
> Tankiest character. Use the shield to hold the front line.

---

### P3 — Gilded Striker *(gold plane)*
| Stat    | Value |
|---------|-------|
| Speed   | 250 px/s |
| Health  | 4 hits |
| Attack  | 95 |

**Skill: Multi-Barrage** — Fires 3 bullets in a spread pattern (-15°, 0°, +15°) for 5 seconds. Cooldown: 8s.
> Highest damage output. Activate before entering a wave for maximum effect.

---

### Skill Cooldown Display
The HUD shows the cooldown timer per player beneath their health bar.
- `SHIFT: Afterburner` → `SHIFT: 9.4s` → `SHIFT: Afterburner` (ready again)

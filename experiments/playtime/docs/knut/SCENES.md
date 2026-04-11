# Knut Scenes — Interactive Physics Toys

One-screen physics scenes based on the Kapitein Knut books by Victor Engbers (Boycott Books).
Each scene is a self-contained interactive toy — tap, drag, fling, balance.

## Characters

- **Kapitein Knut** — boy with yellow cat mask, white underwear, gray dotted socks
- **Django** — brown/orange dog with curly tail
- **Pandora** — pink cat mask, blue overalls with heart, yellow boots
- **The Shadow** — black silhouette of Knut (Stomme Schaduw book)

## Scenes

### 1. Cliff / Level Select (gevaarland-22)
Knut, Pandora, and Django standing on a cliff with the "GEVAARLAND" sign.
Mountains and sea in the background.

**Gameplay:** Level select hub. Characters stand on cliff edge. Tap a sign/door to enter a scene. Maybe jump off the cliff to start.

**Physics:** Minimal — just character ragdolls on a platform. Focus on UI/navigation.

**Priority:** Build first — ties everything together.

---

### 2. Stone Balancing (gevaarland-02)
Knut standing on a tower of stacked stones by a river. Django at the base. Mountains behind.

**Gameplay:** Stack colorful stones into a tower. Balance Knut on top. How high can you go before it topples?

**Physics:** Stacking, friction, balance. Bodies with irregular shapes (rounded stones). Gravity + topple detection.

**Playtime has:** Basic stacking physics, custom shapes.

---

### 3. Crocodile River (schaduw-03, gevaarland-03)
Knut and friends riding/jumping across crocodile heads in water. Four-panel comic layout showing diving, surfacing, riding, and standing on croc heads.

**Gameplay:** Crocodiles float in water. Jump across their heads to cross the river. Crocs bob and sink when you land on them.

**Physics:** Buoyancy (water script exists!), platforms on floating bodies, timing jumps.

**Playtime has:** Water/buoyancy script, platforms.

---

### 4. Zombie Soccer (gevaarland-04, gevaarland-05)
Zombies from a crashed plane dancing with Knut and friends. "Before I tell you, let's play football first!"

**Gameplay:** Kick a ball around with zombie ragdolls. Score goals. Zombies flop and tumble.

**Physics:** Ball physics, ragdoll characters, goal detection. Maybe wind-up kick mechanic (drag back + release).

**Playtime has:** Ragdolls, projectile launching (catapult script).

---

### 5. Juggling Monster (gevaarland-20)
Giant orange monster of Gevaarland — bigger than mountains, juggles fireballs. Knut, Pandora, Django at its feet.

**Gameplay:** Catch/throw fireballs. Keep them in the air. Or: the monster throws things, you dodge.

**Physics:** Projectiles with arc, catch mechanic (weld joint on contact?), timer/score.

**Playtime has:** Projectile launching, weld joints.

---

### 6. Moon & Robots (schaduw-18)
Knut and Django in space with rocket boots. Racing against robots around the moon. City skyline below.

**Gameplay:** Low-gravity jetpack flying. Race through obstacles. Tap to boost.

**Physics:** Reduced gravity, impulse-on-tap (like flappy bird but with ragdoll), obstacles.

**Playtime has:** Gravity settings, impulse forces via script.

---

### 7. Shadow Island (schaduw-14)
Purple shadow monster standing in water next to a pirate ship in a palm tree. Beach with animals. Knut and friends being thrown in the air.

**Gameplay:** Fling characters at the shadow monster. Or: escape from shadow by climbing the ship/tree.

**Physics:** Catapult/slingshot (already have this!), ragdoll trajectory, target collision.

**Playtime has:** Catapult script, ragdolls.

---

## Scene Reference (page → file)

| Scene | Book | Page file |
|---|---|---|
| Cliff / level select | Gevaarland | gevaarland-22.png |
| Stone balancing | Schaduw (Gevaarland intro) | gevaarland-02.png |
| Crocodile river | Schaduw / Gevaarland | schaduw-03.png, gevaarland-03.png |
| Zombie soccer | Gevaarland | gevaarland-04.png, gevaarland-05.png |
| Juggling monster | Gevaarland | gevaarland-20.png |
| Moon & robots | Schaduw | schaduw-18.png |
| Shadow island | Schaduw | schaduw-14.png |

## Build Order

1. **Cliff / level select** — simplest, needed for navigation
2. **Stone balancing** — impressive, simple physics, good demo
3. **Crocodile river** — buoyancy already works, visually fun
4. **Zombie soccer** — crowd favorite, ragdoll chaos
5-7. Rest as time allows

## Tech Notes

- Block out with placeholder shapes first (rectangles, circles)
- Get gameplay feeling right before adding book art
- Each scene = one .playtime.json + one .playtime.lua script
- Web export proven and working (see `docs/WEB-EXPORT-LOVEJS.md`)
- Character deformation via layered meshes (see `experiments/deform-textured`)
- Scans extracted at 300dpi in `textures/knut-scans/` (not in git — 628MB)

## Web Export Workflow

```bash
# Build scene for browser:
./webtest/build-web.sh knut

# Serve locally:
./webtest/serve.sh 8080 knut

# Open http://localhost:8080
```

- Build auto-detects texture references from scene JSON — only bundles what's needed
- ~2MB per scene (plus ~5MB love.js engine, shared across all scenes)
- Knut scene with 5 textures: works, tested 2026-04-11

## Character Art Pipeline

1. Scan book pages (done — `knut-scans/`)
2. Cut characters manually (GIMP/Photoshop) into layered body parts
3. Each layer = separate PNG on transparent background, same canvas size
4. Layers drawn back-to-front: torso → legs → arms (overlap at shoulders/hips)
5. Deform system attaches layers to shared physics skeleton
6. See `experiments/deform-textured/` for multi-layer proof-of-concept

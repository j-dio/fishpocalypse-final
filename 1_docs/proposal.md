# FISHPOCALYPSE

_Just your typical (but not so) cutesy fishing game._

## ARTS 1 · Critical Perspectives in the Arts
**Midterm Capstone Proposal**  
University of the Philippines Cebu · AY 2025–2026

- **Medium:** Digital Interactive Game
- **Tool:** Godot 4.6.1

## Concept / Idea
Fishpocalypse is a 2.5D wave-survival game with a PSX low-poly aesthetic: a 3D world populated with 2D sprites inspired by _DOOM (1993)_ and early PlayStation visuals.

The game loop centers on:
- **Daytime:** Scavenge and prepare by fishing, gathering resources, setting traps, and managing inventory.
- **Nighttime:** Survive demonic assaults in a high-contrast retro horror palette.

The setting is a small island with docks, a hut, and a neighbor. As nights progress, difficulty increases, enemies become stronger, and environmental combat effects (including blood decals and overkill effects) intensify. Surviving a set number of days triggers boss encounters and unlocks new zones, culminating in a final battle against a hell-representing demon.

### Core Gameplay Notes
- Peaceful island by day; gritty retro horror shift by night.
- Sea turns red at night; demons inspired by Philippine mythology attack.
- Fish function as both weapons and food.
- Overkilled enemies explode and drop ammo/resources.
- Limited inventory: fish weapons plus buffs.
- No passive regeneration; health is restored by eating fish.

## Connection to Course Topics
### Module 1: Art as an Experience
The game frames lived struggle through interactive systems: labor, survival, and adaptation. Through dynamic interactions between player, NPCs, and enemies, gameplay expresses fisherfolk life and its pressures in a Philippine context.

### Module 2: Image and Context
The visual contrast between calm daylight labor and violent night survival contextualizes ongoing human struggle across shifting social and symbolic conditions.

## Proposed Medium or Format
Submitted output: a playable first-person 3D digital game under digital and interactive media, built in Godot 4.6.1 with:
- 3D environments
- 2D sprites for characters and enemies
- Standalone executable distribution

## Materials and Techniques
### Engine & Rendering
- Godot 4.6.1
- 3D environment with 2D sprites

### Visual Style
- PSX low-poly aesthetic
- Dual palette:
  - Warm, cutesy daytime
  - Gritty, high-contrast nighttime

### Game Systems
- First-person combat
- Brutal execution triggers

### Audio & Writing
- Lo-fi ambient morning audio
- Heavier retro horror nighttime audio

## Initial Plan of Execution

### Week 0 · Concept Finalization
- Finalize core mechanics, visual direction, and gameplay

### Week 1 · Core Prototype
- Day/night cycle
- Enemy wave system and basic optimization (targeting 100+ enemies)
- Basic player movement
- Basic enemy behavior
- Basic player/enemy health systems

### Week 1 · Core Systems (Combat)
- Basic melee attacks
- Basic weapon hot-swapping
- Enemy execution at low health
- Ammo drops on execution kill

### Week 2 · Core Systems (Weapon Pool)
- Create fish-related weapon list
- Add weapon audio

### Week 2 · Core Systems (Enemy Pool)
- Random enemy spawning system
- Add more challenging enemies
- Unique enemy movesets and behaviors

### Week 3 · Fishing System
- Fishing mini-game
- Integrate fishing with combat weapon pool

### Week 3 · Item Use System
- Integrate fish weapons with health recovery system

### Week 4–5 · Visuals (Major Entity Sprites and Animation)
- Create unique sprites for current enemies
- Create animated sprites

### Week 6 · Content Creation (Levels)
- Build required zones

### Week 6 · Visuals (Particles)
- Create decals (explosion marks, bullet holes, blood particles)

### Week 6 · Audio (Music and Ambience)
- Add player footsteps, hurt, jump sounds
- Add day/night background music

### Week 7–8 · Gore System
- Expand combat reaction systems
- Damage-type-specific enemy reactions (dismemberment, chunking, explosions)
- Blood splatter affecting environmental look

### Week 8 · Additional Audio
- Add gore-related sounds (enemy screams, meat chunk impacts, etc.)

### Week 9 · UI / HUD System
- UI texture creation
- Show health
- Show current equipped weapon and inventory
- Screen effects (hurt, low HP, bloody camera, etc.)

### Week 9 · Further Optimization
- Polish game structure
- Implement additional optimization

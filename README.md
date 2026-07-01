# RaidTools

> A full-featured raid management addon for WoW 1.12 (OctoWow / TurtleWoW)

Covers everything needed to recruit, organise, and run a PUG raid — from LFM posting and spec detection to boss assignments and group optimisation.

---

## Features

### Roster
- Scan the current raid or import from SoftRes.it CSV
- Auto-detect each player's spec via addon comms (silent for RaidTools users) or whisper fallback
- One-click **Auto-roles** — sets Tank / Heal / Melee / Ranged from specs, requests missing specs automatically
- Filter roster by role, search by name

### WhisperBot (PUG hub)
- Automated whisper replies: `?join`, `?role`, `?spec`, `?group`, `?mt`, `?strat`, `?comp`
- Multi-channel **LFM posting** (Say / Yell / Guild / World / LFG) with slot tracking
- **Comp announce** — broadcasts current group composition to raid
- Spec request flow: RaidTools users reply silently via addon; everyone else gets a class-specific whisper  
  *(e.g. Warrior → "What's your spec? (Arms / Fury / Prot)")*

### Groups
- Automatic group optimisation (Windfury groups, caster groups, heal groups)
- Buff summary per group (Windfury, Devotion, LoTP, Trueshot Aura, Shadow Weaving…)
- Manual drag-and-drop assignment, save/load presets

### Boss Assignments
- Per-boss tank / heal assignments with one-click raid announce
- 100+ English boss strategies (Molten Core, BWL, ZG, AQ20/40, Naxxramas, World Bosses, OctoWow custom content)
  — imported from [tactica](https://github.com/Player-Doite/tactica)
- Inline strategy lookup via WhisperBot (`?strat`)

### Other tabs
| Tab | Description |
|-----|-------------|
| **Assign** | Auto-compute tank/heal/buff/curse assignments, whisper everyone |
| **Consumes** | Track who brought consumes before the pull |
| **Attendance** | Record kill history per boss |
| **Loot** | SoftRes loot tracking |
| **Dashboard** | Quick status overview + pull timer |

---

## Installation

1. Copy the `rt` folder into `WoW/Interface/AddOns/`
2. Launch World of Warcraft
3. Enable **RT - Raid Tool** in the addon list
4. Type `/rt` to open the panel

---

## File structure

```
rt/
├── rt.toc              # Addon manifest (loads v2 base + rt.lua)
├── rt.xml              # Minimal frame definition
├── rt.lua              # Built v3 UI (generated — do not edit directly)
│
│── v3Compat.lua        # Spec detection, role mapping, shared helpers
│── v3Store.lua         # SavedVariables wrapper
│── v3UIKit.lua         # Shared widget factory (Button, EditBox…)
│── v3Registry.lua      # Module tab system + Settings panel
│── v3Roster.lua        # Roster tab
│── v3WhisperBot.lua    # WhisperBot + LFM + comp announce
│── v3Groups.lua        # Groups tab
│── v3GroupOpt.lua      # Group optimiser algorithm
│── v3Boss.lua          # Boss assignments tab
│── v3Assign.lua        # Auto-assignment engine
│── v3Strats.lua        # Boss strategy browser
│── v3Consumes.lua      # Consumes tracker
│── v3ModDash.lua       # Dashboard tab
│── v3Minimap.lua       # Minimap button
│
│   (v2 base files — loaded before rt.lua)
├── Tactics.lua         # Boss strategy database (English, 100+ bosses)
├── Sync.lua            # Addon-to-addon messaging (RTSYNC prefix)
├── AutoAssign.lua      # v2 assignment logic
├── Dashboard.lua       # v2 dashboard
├── Attendance.lua      # v2 attendance
├── BossPresets.lua     # v2 boss presets
├── SoftResJSON.lua     # SoftRes CSV parser
├── AutoInvite.lua      # Auto-invite by class/role
├── CooldownTracker.lua # Cooldown tracker
├── Overlay.lua         # Raid overlay
├── PullTimer.lua       # Pull countdown
├── Colors.lua          # Class/role colour helpers
└── Config.lua          # Shared constants
```

> `rt.lua` is the compiled output of all `v3*.lua` source files concatenated by `rebuild_rt.py`.  
> Edit the `v3*.lua` files, then run the script to rebuild.

---

## Slash commands

```
/rt          Open / close the main panel
/rt help     List available commands
```

---

## SavedVariables

All data is stored in `RT_DB` (see `v3Store.lua`):

```lua
RT_DB = {
    v3 = {
        roster  = { ["PlayerName"] = { class, spec, role, sr } },
        groups  = { [1..8] = { "Name", ... } },
        bosses  = { ["BossName"] = { tanks, heals, note } },
        loot    = { ... },
        v3bot   = { enabled, templates, lfm, ... },
    }
}
```

---

## Credits

- Boss strategies: [tactica](https://github.com/Player-Doite/tactica) by Player-Doite
- Built for [OctoWow](https://octowow.com) / [TurtleWoW](https://turtle-wow.org) (WoW 1.12.1)

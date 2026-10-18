-- RT - Raid Tool | Boss Presets
-- Presets de configuration pour les boss vanilla TurtleWoW.
-- Noms de boss = exactement ceux de RT_VANILLA_RAIDS dans rt.lua.
-- ============================================================

-- Format d'un preset:
--   tank_count  : nombre de tanks actifs (1-4)
--   tank_marks  : marqueurs Skull/Cross/Square/Moon/Triangle/Diamond/Circle/Star (ou "")
--   h_counts    : { h_tank1, h_tank2, h_tank3, h_tank4, h_raid, h_melee, h_caster }
--   note        : conseil affiché dans la zone note
RT_BOSS_PRESETS = {

    -- ========== MOLTEN CORE ==========
    ["Lucifron"] = {
        tank_count = 2,
        tank_marks  = { "Skull", "Cross", "", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=2, h_melee=1, h_caster=1 },
        note = "2 tanks. Interrupt Impending Doom. Dispel Lucifron's Curse.",
    },
    ["Magmadar"] = {
        tank_count = 2,
        tank_marks  = { "Skull", "Cross", "", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=2, h_melee=1, h_caster=1 },
        note = "2 tanks. Tranquilizing Shot to remove Frenzy. Fear on whole raid.",
    },
    ["Gehennas"] = {
        tank_count = 2,
        tank_marks  = { "Skull", "Cross", "", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=3, h_melee=1, h_caster=1 },
        note = "2 tanks. Heavy raid damage from Rain of Fire. Dispel Gehennas Curse.",
    },
    ["Garr"] = {
        tank_count = 2,
        tank_marks  = { "Skull", "Cross", "", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=2, h_melee=1, h_caster=1 },
        note = "Tank adds with Warlocks (Banish). Kill spawns when Garr Antimagic Pulse.",
    },
    ["Baron Geddon"] = {
        tank_count = 2,
        tank_marks  = { "Skull", "Cross", "", "" },
        h_counts    = { h_tank1=2, h_tank2=1, h_tank3=1, h_tank4=1, h_raid=3, h_melee=1, h_caster=1 },
        note = "Living Bomb: isolate player! Inferno AoE. Spread raid.",
    },
    ["Shazzrah"] = {
        tank_count = 2,
        tank_marks  = { "Skull", "Cross", "", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=2, h_melee=1, h_caster=1 },
        note = "Teleports randomly. Counterspell. Dispel curses. Keep spread.",
    },
    ["Sulfuron Harbinger"] = {
        tank_count = 3,
        tank_marks  = { "Skull", "Cross", "Square", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=3, h_melee=1, h_caster=1 },
        note = "MT on Sulfuron. OT1+OT2 on Flamewakers. Priests interrupt Heal. Banish/Sheep adds.",
    },
    ["Golemagg"] = {
        tank_count = 3,
        tank_marks  = { "Skull", "Cross", "Square", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=2, h_melee=1, h_caster=1 },
        note = "OT1+OT2 on Core Ragers. MT on Golemagg. Lava Blanket stacks.",
    },
    ["Majordomo Executus"] = {
        tank_count = 3,
        tank_marks  = { "Skull", "Cross", "Square", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=2, h_melee=1, h_caster=1 },
        note = "8 adds. CC: Sheep fire casters, Shackle/Banish others. Burn casters first.",
    },
    ["Ragnaros"] = {
        tank_count = 3,
        tank_marks  = { "Skull", "Cross", "Square", "" },
        h_counts    = { h_tank1=3, h_tank2=3, h_tank3=2, h_tank4=2, h_raid=3, h_melee=1, h_caster=1 },
        note = "MT. P2 at 50% (submerge + Sons). Kill Sons fast. Wrath of Ragnaros knockback.",
    },

    -- ========== ONYXIA'S LAIR ==========
    ["Onyxia"] = {
        tank_count = 2,
        tank_marks  = { "Skull", "Cross", "", "" },
        h_counts    = { h_tank1=3, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=3, h_melee=1, h_caster=1 },
        note = "MT drags Onyxia. OT handles whelps. P1 ground, P2 air (ranged), P3 whelps + MT. Never stand in fire!",
    },

    -- ========== BLACKWING LAIR ==========
    ["Razorgore"] = {
        tank_count = 2,
        tank_marks  = { "Skull", "Cross", "", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=3, h_melee=1, h_caster=1 },
        note = "MC Razorgore. 4 warriors in corners. Kill all eggs. Phase 2 burn.",
    },
    ["Vaelastrasz"] = {
        tank_count = 2,
        tank_marks  = { "Skull", "Cross", "", "" },
        h_counts    = { h_tank1=3, h_tank2=3, h_tank3=2, h_tank4=2, h_raid=3, h_melee=1, h_caster=1 },
        note = "Heavy tank damage. Burning Adrenaline: move away! Enrage at 20%.",
    },
    ["Broodlord Lashlayer"] = {
        tank_count = 2,
        tank_marks  = { "Skull", "Cross", "", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=2, h_melee=1, h_caster=1 },
        note = "Mortal Strike. Decimate at 30%. Dispel Suppression. Kill whelps.",
    },
    ["Firemaw"] = {
        tank_count = 2,
        tank_marks  = { "Skull", "Cross", "", "" },
        h_counts    = { h_tank1=3, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=2, h_melee=1, h_caster=1 },
        note = "Wing Buffet knockback. Heavy tank damage. Stand in arc. Enrage fear resist.",
    },
    ["Ebonroc"] = {
        tank_count = 2,
        tank_marks  = { "Skull", "Cross", "", "" },
        h_counts    = { h_tank1=3, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=2, h_melee=1, h_caster=1 },
        note = "Shadow of Ebonroc: tank swap needed when debuffed tank is healed.",
    },
    ["Flamegor"] = {
        tank_count = 2,
        tank_marks  = { "Skull", "Cross", "", "" },
        h_counts    = { h_tank1=3, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=2, h_melee=1, h_caster=1 },
        note = "Frenzy stacks: Tranquilizing Shot. Wing Buffet. Fire vulnerability.",
    },
    ["Chromaggus"] = {
        tank_count = 2,
        tank_marks  = { "Skull", "Cross", "", "" },
        h_counts    = { h_tank1=3, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=2, h_melee=1, h_caster=1 },
        note = "5 Chromatically Tempered Brood debuffs. Dispel when possible. Time Stop = 3 sec stun.",
    },
    ["Nefarian"] = {
        tank_count = 3,
        tank_marks  = { "Skull", "Cross", "Square", "" },
        h_counts    = { h_tank1=3, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=3, h_melee=1, h_caster=1 },
        note = "P1: OTs on drakonids. P2: Class calls. MT tanks Nef. P3: raise all skeletons at 20%.",
    },

    -- ========== ZUL'GURUB ==========
    ["Jeklik"] = {
        tank_count = 1,
        tank_marks  = { "Skull", "", "", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=2, h_melee=1, h_caster=1 },
        note = "Bat phase: AoE the bats. Ground phase: kill bats on MT. Silence priestess.",
    },
    ["Venoxis"] = {
        tank_count = 1,
        tank_marks  = { "Skull", "", "", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=2, h_melee=1, h_caster=1 },
        note = "Snake phase at 50%: poison spit. Antidotes. Kill quickly.",
    },
    ["Marli"] = {
        tank_count = 1,
        tank_marks  = { "Skull", "", "", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=2, h_melee=1, h_caster=1 },
        note = "Spider adds: AoE them. Drain Life. Don't spread for web spray.",
    },
    ["Mandokir"] = {
        tank_count = 2,
        tank_marks  = { "Skull", "Cross", "", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=2, h_melee=1, h_caster=1 },
        note = "Mandokir watches one player: stop action! OT on Ohgan (raptor). Decimate at 25%.",
    },
    ["Gahzranka"] = {
        tank_count = 1,
        tank_marks  = { "Skull", "", "", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=2, h_melee=1, h_caster=1 },
        note = "Summon Gahzranka with 5x Mudskunk Lure. Tank near pool edge.",
    },
    ["Thekal"] = {
        tank_count = 3,
        tank_marks  = { "Skull", "Cross", "Square", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=2, h_melee=1, h_caster=1 },
        note = "3 targets: Thekal + Zealot Lor'Khan + Zealot Zath. Kill all 3 together or they rez.",
    },
    ["Arlokk"] = {
        tank_count = 1,
        tank_marks  = { "Skull", "", "", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=2, h_melee=1, h_caster=1 },
        note = "Panther phase: she vanishes. Kill panthers. MT picks up when she reappears.",
    },
    ["Jindo"] = {
        tank_count = 1,
        tank_marks  = { "Skull", "", "", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=2, h_melee=1, h_caster=1 },
        note = "Destroy Soul Urns around the room to kill spirit adds. Interrupt Shadow Bolt Volley.",
    },
    ["Hakkar"] = {
        tank_count = 2,
        tank_marks  = { "Skull", "Cross", "", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=3, h_melee=1, h_caster=1 },
        note = "Son of Hakkar infected players sacrifice near Hakkar for Corrupted Blood stacks. Mind control to give corrupted blood.",
    },

    -- ========== RUINS OF AHN'QIRAJ (AQ20) ==========
    ["Kurinnaxx"] = {
        tank_count = 1,
        tank_marks  = { "Skull", "", "", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=2, h_melee=1, h_caster=1 },
        note = "Mortal Wound stacks: OT ready for swap. Resists nature.",
    },
    ["Rajaxx"] = {
        tank_count = 2,
        tank_marks  = { "Skull", "Cross", "", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=2, h_melee=1, h_caster=1 },
        note = "7 waves of adds before Rajaxx. Interrupt War Command. Kill generals fast.",
    },
    ["Moam"] = {
        tank_count = 1,
        tank_marks  = { "Skull", "", "", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=2, h_melee=1, h_caster=1 },
        note = "Mana drain phase: interrupt mana users. Petrifies at 0 mana. Burn adds.",
    },
    ["Buru"] = {
        tank_count = 1,
        tank_marks  = { "Skull", "", "", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=2, h_melee=1, h_caster=1 },
        note = "Kite to eggs, explode eggs on Buru to stack. At 20% kill him on a corpse for chain explosion.",
    },
    ["Ayamiss"] = {
        tank_count = 1,
        tank_marks  = { "Skull", "", "", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=2, h_melee=1, h_caster=1 },
        note = "P1: air phase. Hive Ashi Drones swarm the altar sacrifice. Free them. P2 ground at 70%.",
    },
    ["Ossirian"] = {
        tank_count = 1,
        tank_marks  = { "Skull", "", "", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=3, h_melee=1, h_caster=1 },
        note = "Kite between Crystal Pylons to change weakness. All resist is 75% until crystal.",
    },

    -- ========== TEMPLE OF AHN'QIRAJ (AQ40) ==========
    ["Skeram"] = {
        tank_count = 3,
        tank_marks  = { "Skull", "Cross", "Square", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=2, h_melee=1, h_caster=1 },
        note = "Splits into 3 images at 75%/50%/25%. Kill real one. Each split resets.",
    },
    ["Bug Trio"] = {
        tank_count = 3,
        tank_marks  = { "Skull", "Cross", "Square", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=2, h_melee=1, h_caster=1 },
        note = "Vem, Kri, Yauj. Kill Yauj last (Heal). Kill Kri first (cleave). All 3 must die close together.",
    },
    ["Sartura"] = {
        tank_count = 3,
        tank_marks  = { "Skull", "Cross", "Square", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=3, h_melee=1, h_caster=1 },
        note = "Whirlwinds everywhere. Spread out tanks. Kill adds fast. Heavy AoE phase.",
    },
    ["Fankriss"] = {
        tank_count = 2,
        tank_marks  = { "Skull", "Cross", "", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=2, h_melee=1, h_caster=1 },
        note = "Spits players to corner with Spawn of Fankriss. Kill snakes fast. Nature resistance.",
    },
    ["Viscidus"] = {
        tank_count = 1,
        tank_marks  = { "Skull", "", "", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=2, h_melee=1, h_caster=1 },
        note = "Frost spells to freeze → melee burst to shatter. Globs reform. Nature poison debuff.",
    },
    ["Huhuran"] = {
        tank_count = 2,
        tank_marks  = { "Skull", "Cross", "", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=3, h_melee=1, h_caster=1 },
        note = "Nature Resist gear. Frenzy at 30% (Tranq Shot). Wyvern Sting random target.",
    },
    ["Twin Emperors"] = {
        tank_count = 2,
        tank_marks  = { "Skull", "Cross", "", "" },
        h_counts    = { h_tank1=3, h_tank2=3, h_tank3=2, h_tank4=2, h_raid=2, h_melee=1, h_caster=1 },
        note = "Vek'lor (magic) + Vek'nilash (physical). Tanks swap on Teleport. Melee on physical only.",
    },
    ["Ouro"] = {
        tank_count = 2,
        tank_marks  = { "Skull", "Cross", "", "" },
        h_counts    = { h_tank1=3, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=2, h_melee=1, h_caster=1 },
        note = "Submerges → Scarabs. P2: burn on surface. P3: berserk at 20% with Boulder.",
    },
    ["C'Thun"] = {
        tank_count = 2,
        tank_marks  = { "Skull", "Cross", "", "" },
        h_counts    = { h_tank1=3, h_tank2=3, h_tank3=2, h_tank4=2, h_raid=3, h_melee=1, h_caster=1 },
        note = "P1: kill tentacles. P2: tentacles in stomach, kill flesh tentacles. MT the tentacles.",
    },

    -- ========== NAXXRAMAS ==========
    ["Anub'Rekhan"] = {
        tank_count = 2,
        tank_marks  = { "Skull", "Cross", "", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=2, h_melee=1, h_caster=1 },
        note = "Kite Anub during Locust Swarm. OT on Crypt Guards. Impale random target: run from group.",
    },
    ["Faerlina"] = {
        tank_count = 2,
        tank_marks  = { "Skull", "Cross", "", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=2, h_melee=1, h_caster=1 },
        note = "Sacrifice a Worshipper during Frenzy to remove it. Keep 2 Worshippers alive.",
    },
    ["Maexxna"] = {
        tank_count = 1,
        tank_marks  = { "Skull", "", "", "" },
        h_counts    = { h_tank1=3, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=2, h_melee=1, h_caster=1 },
        note = "Web Wrap: free players. Venom on MT. Frenzies at 30%. Burn hard.",
    },
    ["Noth"] = {
        tank_count = 2,
        tank_marks  = { "Skull", "Cross", "", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=2, h_melee=1, h_caster=1 },
        note = "Teleports. Kill skeletons during ground phase. Plague: dispel.",
    },
    ["Heigan"] = {
        tank_count = 1,
        tank_marks  = { "Skull", "", "", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=2, h_melee=1, h_caster=1 },
        note = "Heigan Dance: 4 lanes. Zone 1 safe while boss is there. Move constantly. Must know the dance!",
    },
    ["Loatheb"] = {
        tank_count = 1,
        tank_marks  = { "Skull", "", "", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=3, h_melee=1, h_caster=1 },
        note = "Healing window every 20s: heal only then. Corrupted Mind debuff = random player silenced.",
    },
    ["Razuvious"] = {
        tank_count = 2,
        tank_marks  = { "Skull", "Cross", "", "" },
        h_counts    = { h_tank1=3, h_tank2=3, h_tank3=2, h_tank4=2, h_raid=2, h_melee=1, h_caster=1 },
        note = "Priests MC two Understudy and tank-swap. MT cannot survive without Shield.",
    },
    ["Gothik"] = {
        tank_count = 3,
        tank_marks  = { "Skull", "Cross", "Square", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=2, h_melee=1, h_caster=1 },
        note = "Split raid Live/Dead sides. Kill adds. At 30% gate opens: burn Gothik.",
    },
    ["Four Horsemen"] = {
        tank_count = 4,
        tank_marks  = { "Skull", "Cross", "Square", "Moon" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=2, h_melee=1, h_caster=1 },
        note = "4 tanks in corners. Debuff stacks: swap at 3-4 stacks. Back tanks: Blaumeux + Zeliek.",
    },
    ["Patchwerk"] = {
        tank_count = 2,
        tank_marks  = { "Skull", "Cross", "", "" },
        h_counts    = { h_tank1=4, h_tank2=4, h_tank3=2, h_tank4=2, h_raid=1, h_melee=1, h_caster=1 },
        note = "Tank swap on Hateful Strike (OT must be highest HP non-MT). Heal spam tanks.",
    },
    ["Grobbulus"] = {
        tank_count = 1,
        tank_marks  = { "Skull", "", "", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=2, h_melee=1, h_caster=1 },
        note = "Kite in circle. Injected Poison: move away and drop cloud. No one in clouds.",
    },
    ["Gluth"] = {
        tank_count = 2,
        tank_marks  = { "Skull", "Cross", "", "" },
        h_counts    = { h_tank1=3, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=2, h_melee=1, h_caster=1 },
        note = "OT kites Zombie Chow. Decimate at 5s intervals. Free players. Mortal Wound stacks.",
    },
    ["Thaddius"] = {
        tank_count = 2,
        tank_marks  = { "Skull", "Cross", "", "" },
        h_counts    = { h_tank1=3, h_tank2=3, h_tank3=2, h_tank4=2, h_raid=2, h_melee=1, h_caster=1 },
        note = "Kill Stalagg + Feugen. P2: positive side right, negative side left of Thaddius. Never touch opposite polarity.",
    },
    ["Sapphiron"] = {
        tank_count = 2,
        tank_marks  = { "Skull", "Cross", "", "" },
        h_counts    = { h_tank1=3, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=3, h_melee=1, h_caster=1 },
        note = "Frost resist gear. Air phase: hide behind ice block. Frost bomb: spread out.",
    },
    ["Kel'Thuzad"] = {
        tank_count = 3,
        tank_marks  = { "Skull", "Cross", "Square", "" },
        h_counts    = { h_tank1=3, h_tank2=3, h_tank3=2, h_tank4=2, h_raid=3, h_melee=1, h_caster=1 },
        note = "P1: kill abominations+skeletons 3min. P2: MT Kel'Thuzad. P3: OTs on Lich Kings portals.",
    },

    -- ========== WORLD BOSSES ==========
    ["Azuregos"] = {
        tank_count = 2,
        tank_marks  = { "Skull", "Cross", "", "" },
        h_counts    = { h_tank1=3, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=2, h_melee=1, h_caster=1 },
        note = "Mark of Frost = stun + freeze. Teleport: reset aggro. Frost resist tank.",
    },
    ["Lord Kazzak"] = {
        tank_count = 2,
        tank_marks  = { "Skull", "Cross", "", "" },
        h_counts    = { h_tank1=3, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=3, h_melee=1, h_caster=1 },
        note = "No deaths! Each death heals Kazzak. Void Bolt: Shadow resist.",
    },
    ["Taerar"] = {
        tank_count = 3,
        tank_marks  = { "Skull", "Cross", "Square", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=2, h_melee=1, h_caster=1 },
        note = "3 shades when submerged. Kill all 3 at same time. Noxious Breath AoE.",
    },
    ["Emeriss"] = {
        tank_count = 2,
        tank_marks  = { "Skull", "Cross", "", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=3, h_melee=1, h_caster=1 },
        note = "Volatile Infection: AoE damage on death. 25% mobs: don't kill near group.",
    },
    ["Lethon"] = {
        tank_count = 2,
        tank_marks  = { "Skull", "Cross", "", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=2, h_melee=1, h_caster=1 },
        note = "Shadow Bolt Whirl. Draw Spirit: void zones from shadows, step on them to kill.",
    },
    ["Ysondre"] = {
        tank_count = 2,
        tank_marks  = { "Skull", "Cross", "", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=2, h_tank4=2, h_raid=2, h_melee=1, h_caster=1 },
        note = "Summons Druids of the Nightmare at 75%/50%/25%. CC them, burn dragon.",
    },

    -- ========== KARAZHAN (KZ10) ==========
    ["Attumen"] = {
        tank_count = 1,
        tank_marks  = { "Skull", "", "", "" },
        h_counts    = { h_tank1=2, h_tank2=1, h_tank3=1, h_tank4=1, h_raid=2, h_melee=1, h_caster=1 },
        note = "Kite Midnight until 95%, Attumen joins. Charge = spread. Curse of Unbinding: dispel.",
    },
    ["Moroes"] = {
        tank_count = 2,
        tank_marks  = { "Skull", "Cross", "Square", "Moon" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=1, h_tank4=1, h_raid=2, h_melee=1, h_caster=1 },
        note = "CC 3 adds. Kill priority: healer > caster > Moroes. Garrote (bleed) stays all fight.",
    },
    ["Maiden of Virtue"] = {
        tank_count = 1,
        tank_marks  = { "Skull", "", "", "" },
        h_counts    = { h_tank1=2, h_tank2=1, h_tank3=1, h_tank4=1, h_raid=3, h_melee=1, h_caster=1 },
        note = "Holy Ground stuns melee near her. Repentance = raid stun. MT must be Consecrated.",
    },
    ["Opera"] = {
        tank_count = 1,
        tank_marks  = { "Skull", "", "", "" },
        h_counts    = { h_tank1=2, h_tank2=1, h_tank3=1, h_tank4=1, h_raid=2, h_melee=1, h_caster=1 },
        note = "3 possible events: Wizard of Oz / BBW / Romulo & Julianne. Prep for all.",
    },
    ["The Curator"] = {
        tank_count = 1,
        tank_marks  = { "Skull", "", "", "" },
        h_counts    = { h_tank1=2, h_tank2=1, h_tank3=1, h_tank4=1, h_raid=2, h_melee=1, h_caster=1 },
        note = "Kill Astral Flares fast (ranged DPS priority). DPS Curator only during Evocation.",
    },
    ["Illhoof"] = {
        tank_count = 2,
        tank_marks  = { "Skull", "Cross", "", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=1, h_tank4=1, h_raid=2, h_melee=1, h_caster=1 },
        note = "Kill Imps. Free Sacrificed player (burn chains). Tank Kil'rek away from boss.",
    },
    ["Shade of Aran"] = {
        tank_count = 0,
        tank_marks  = { "", "", "", "" },
        h_counts    = { h_tank1=1, h_tank2=1, h_tank3=1, h_tank4=1, h_raid=3, h_melee=1, h_caster=1 },
        note = "No threat. Interrupt Frostbolt/Fireball/Arcane Missiles. Blizzard = move. Flame Wreath = STOP.",
    },
    ["Netherspite"] = {
        tank_count = 3,
        tank_marks  = { "Skull", "Cross", "Square", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=2, h_tank4=1, h_raid=2, h_melee=1, h_caster=1 },
        note = "3 beams (Red/Green/Blue). Red = tank, Green = healer, Blue = mage/lock. Banish phase = hide.",
    },
    ["Chess Event"] = {
        tank_count = 0,
        tank_marks  = { "", "", "", "" },
        h_counts    = { h_tank1=1, h_tank2=1, h_tank3=1, h_tank4=1, h_raid=1, h_melee=1, h_caster=1 },
        note = "Chess puzzle. Control pieces. King Llane = always control. Cheat mechanic.",
    },
    ["Prince Malchezaar"] = {
        tank_count = 1,
        tank_marks  = { "Skull", "", "", "" },
        h_counts    = { h_tank1=3, h_tank2=1, h_tank3=1, h_tank4=1, h_raid=3, h_melee=1, h_caster=1 },
        note = "Infernal axes spawn = spread. P2 (60-30%): highest shadow damage. P3: Enfeeble = stop DPS.",
    },
    ["Nightbane"] = {
        tank_count = 1,
        tank_marks  = { "Skull", "", "", "" },
        h_counts    = { h_tank1=3, h_tank2=1, h_tank3=1, h_tank4=1, h_raid=3, h_melee=1, h_caster=1 },
        note = "Ground phase: Charred Earth (move tank). Air phase: ranged spread, kill skeletons.",
    },

    -- ========== KZ10 OctoWow ==========
    ["Master Blacksmith Rolfen"] = {
        tank_count = 2,
        tank_marks  = { "Skull", "Cross", "", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=1, h_tank4=1, h_raid=2, h_melee=1, h_caster=1 },
        note = "Tanks swap on Hamstring stacks. Interrupts on casts. DPS priority: adds then boss.",
    },
    ["Brood Queen Araxxna"] = {
        tank_count = 1,
        tank_marks  = { "Skull", "", "", "" },
        h_counts    = { h_tank1=2, h_tank2=1, h_tank3=1, h_tank4=1, h_raid=3, h_melee=1, h_caster=1 },
        note = "Kill spiderlings fast. Spread for web wrap. Poison cleanse when possible.",
    },
    ["Grizikil"] = {
        tank_count = 2,
        tank_marks  = { "Skull", "Cross", "", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=1, h_tank4=1, h_raid=2, h_melee=1, h_caster=1 },
        note = "Tank swap on bleed stacks. Ranged spread. Kill adds priority.",
    },
    ["Clawlord Howlfang"] = {
        tank_count = 1,
        tank_marks  = { "Skull", "", "", "" },
        h_counts    = { h_tank1=3, h_tank2=1, h_tank3=1, h_tank4=1, h_raid=2, h_melee=1, h_caster=1 },
        note = "Heavy tank damage. Interrupt howl if possible. Move out of cleave zone.",
    },
    ["Lord Blackwald II"] = {
        tank_count = 2,
        tank_marks  = { "Skull", "Cross", "", "" },
        h_counts    = { h_tank1=2, h_tank2=2, h_tank3=1, h_tank4=1, h_raid=3, h_melee=1, h_caster=1 },
        note = "Shadow resist gear recommended. Tank swap on debuff. Dispel curses on raid.",
    },
}

-- Applique le preset d'un boss sur RT_BOSS_STATE.
-- Appelé depuis RT_BossSelectBoss quand aucune sauvegarde n'existe.
function RT_BossApplyPreset(bossName)
    if not RT_BOSS_PRESETS then return false end
    local preset = RT_BOSS_PRESETS[bossName]
    if not preset then return false end

    local s = RT_BOSS_STATE
    if not s then return false end

    -- Nombre de tanks
    local tc = preset.tank_count or 3
    if tc < 1 then tc = 1 end
    if tc > 4 then tc = 4 end
    s.tank_count = tc

    -- Marqueurs (copie défensive)
    local marks = preset.tank_marks or {}
    s.tank_marks = {
        marks[1] or "",
        marks[2] or "",
        marks[3] or "",
        marks[4] or "",
    }

    -- Comptes de healers
    local pc = preset.h_counts or {}
    local defaults = RT_BOSS_HEAL_DEFAULTS or {}
    local limits   = RT_BOSS_HEAL_LIMITS   or {}
    local function clamp(v, def, key)
        local lim = limits[key] or def
        v = tonumber(v) or def
        if v < 1 then v = 1 end
        if v > lim then v = lim end
        return v
    end
    s.h_counts = {
        h_tank1 = clamp(pc.h_tank1, defaults.h_tank1 or 2, "h_tank1"),
        h_tank2 = clamp(pc.h_tank2, defaults.h_tank2 or 2, "h_tank2"),
        h_tank3 = clamp(pc.h_tank3, defaults.h_tank3 or 2, "h_tank3"),
        h_tank4 = clamp(pc.h_tank4, defaults.h_tank4 or 2, "h_tank4"),
        h_raid   = clamp(pc.h_raid,  defaults.h_raid  or 3, "h_raid"),
        h_melee  = clamp(pc.h_melee, defaults.h_melee or 1, "h_melee"),
        h_caster = clamp(pc.h_caster,defaults.h_caster or 1,"h_caster"),
    }

    -- Note stratégique
    s.note = preset.note or ""

    RT_BossRefreshSlots()
    return true
end

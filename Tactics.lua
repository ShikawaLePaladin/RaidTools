-- ============================================================
-- RT v2 — Tactics.lua
-- Boss tactics database (English). Strategies imported from
-- Tactica by Player-Doite (https://github.com/Player-Doite/tactica).
-- Recherche, affichage, annonce raid, tactiques customs
-- Compatible WoW 1.12 / TurtleWoW
-- ============================================================

RT_Tactics = RT_Tactics or {}

-- ── Base de données tactiques ──────────────────────────────
-- Format : { boss=string, raid=string, lines={string,...} }
-- Garder <255 chars/ligne pour SendChatMessage

RT_TACTICS_DB = {

  -- == MOLTEN CORE ==
  { boss="Incindis", raid="Molten Core", lines={
    "Tanks: MT on boss, OT pick up adds from hatched eggs and move them aside. Face boss away. Move out of pull-in AoE.",
    "DPS: Kill spawned adds quickly. Focus boss-eggs can't all be nuked before hatch. Run away when pulled in.",
    "Healers: Heal through pull-in AoE + add dmg. Watch MT.",
    "Class Specific: AoE classes handle adds fast. MDPS back off on pull-in.",
    "Boss Ability: Pull-in + AoE burst. Eggs hatch adds. Small AoE around boss.",
  }},
  { boss="Lucifron", raid="Molten Core", lines={
    "Tanks: MT on boss, OT on adds. Face away. Adds respawn at 50%-tank and burn again.",
    "DPS: Kill adds every time they spawn, then boss. Avoid cleave.",
    "Healers: Focus tanks. Dispel Impending Doom and Decurse Curse of Lucifron.",
    "Class Specific: Mages/Druids/Priests/Paladins cleanse Curse + Doom fast.",
    "Boss Ability: Periodic add spawns. Curse of Lucifron + Impending Doom.",
  }},
  { boss="Magmadar", raid="Molten Core", lines={
    "Tanks: MT face away. Watch position of healers.",
    "DPS: Stay behind boss. Move out during Frenzy/Panic. Avoid fire patches. Max range.",
    "Healers: Heal spikes, prio MT. Cover Panic. Fearward tank.",
    "Class Specific: Hunters Tranq Frenzy. Priests Fear Ward tank. Shamans Tremor Totem.",
    "Boss Ability: Frenzy (tranq), Panic fear, fire patches.",
  }},
  { boss="Smoldaris & Basalthar", raid="Molten Core", lines={
    "Tanks: 1 tank each. Smoldaris: FR gear, tank on spot face away (will do a fire-cone). Basalthar: watch knockback, tank against wall (entrence - towards same side as Smoldaris).",
    "DPS: Attack Smoldaris or Basalthar depending on Molten Bulwark buff on boss (start Basalthar). Avoid cone + AoE knockback. Swap between when called buff is up on bosses. Range stand where Basalthar is before pull.",
    "Healers: Heavy tank heals on Smoldaris. Heal repositioning after knockbacks. Smoldaris will do AoE - heal through. Stand with range where Smoldaris is before pull.",
    "Class Specific: FR pots useful. MDPS max melee range. Track Bulwark.",
    "Boss Ability: Smoldaris cone + AoE fire blasts. Basalthar knockback. Both will get buff Molten Bulwark (swap to other boss).",
  }},
  { boss="Garr", raid="Molten Core", lines={
    "Tanks: MT on Garr. OTs split adds, face to walls. Kill some adds first-each killed increases Garr dmg taken but also his dmg dealt.",
    "DPS: Kill 3-4 adds, then boss. After boss dies, kill rest adds. Avoid add deaths near you. MDPS can be on boss, and RDPS on adds until 4 are dead (easier). Focus one at a time.",
    "Healers: Assign 1 per add tank. Cover Garr dmg scaling.",
    "Class Specific: Warlocks banish adds.",
    "Boss Ability: Fire Sworn Fortification stacks based on adds killed.",
  }},
  { boss="Baron Geddon", raid="Molten Core", lines={
    "Tanks: MT position boss, keep ranged 40y out. FR gear recommended. Don't outrange healers. Max range MDPS if tank gets bomb. Move out from AoE.",
    "DPS: Melee run out on Inferno. Ranged stack max range. Run out when you get Living Bomb away from group (towards wall). Living Bomb leaves ground AoE-use 5 preset explosion spots.",
    "Healers: Heal bomb targets + AoE. Watch ground AoEs.",
    "Class Specific: Priests/Paladins dispel Ignite Mana. Shield bomb targets.",
    "Boss Ability: Living Bomb + leaves ground AoE, Inferno around boss. Preselect 5 spots for bombs and alternate between.",
  }},
  { boss="Shazzrah", raid="Molten Core", lines={
    "Tanks: MT boss away from ranged. OTs taunt after Blinks.",
    "DPS: Ranged max spread. Melee reposition fast after Blinks. Burn quickly.",
    "Healers: Cover tank + AoE bursts. Stay spread.",
    "Class Specific: Priests/Shamans dispel Deaden Magic on boss. Mages/Druids decurse(!).",
    "Boss Ability: Blink + Arcane Explosion, Deaden Magic, curse.",
  }},
  { boss="Sulfuron Harbinger", raid="Molten Core", lines={
    "Tanks: MT on boss, 1-2 OTs on Adds and Sons. Stack all adds onto boss.",
    "DPS: Kill Sons first (prio) when spawned > then adds of Sulfuron > then boss. Interrupt Dark Mending. All stack on boss.",
    "Healers: Assign 1 per tank. Cover add dmg. All stack on boss.",
    "Class Specific: Rogues/Warriors kick heals.",
    "Boss Ability: Summons Sons (all stack on boss - kill Sons first). Dark Mending heals (interrupt).",
  }},
  { boss="Golemagg the Incinerator", raid="Molten Core", lines={
    "Tanks: MT on boss. 2-3 OTs on Core Hounds. Dogs will auto-switch to random target adding 10k threat-OT taunt quickly away from boss. Must kill all other MC bosses first.",
    "DPS: Full focus boss. Ignore dogs. Stay behind. Move out if to many stacks.",
    "Healers: Heavy tank heals and MDPS. Watch OTs.",
    "Boss Ability: Core Hounds swap threat. High fire dmg. Pre-req: clear all bosses.",
  }},
  { boss="Majordomo Executus", raid="Molten Core", lines={
    "Tanks: MT on Domo, who will get teleported and needs to pickup and reposition boss. MT tank on far edge of circle with back against the raid. OTs split adds in 2 camps. 1-2 tank assigned dispeller for stun/TP debuff.",
    "DPS: Do not DPS boss. Kill healers first (un-sheeped), then elites. Stop DPS on reflect. Sheep as many healers as possible.",
    "Healers: Cover tanks. Heal and dispel stunned/TP victims in middle.",
    "Class Specific: Mages sheep healers. Hunters kite elites if assigned. Assign Paladin or Priest to dispel Hammer of Justice (stun).",
    "Boss Ability: Teleport & stun MT +  random group (3-5) with Hammer of Justice (dispellable). Magic reflect. Adds heal.",
  }},
  { boss="Sorcerer-thane Thaurissan", raid="Molten Core", lines={
    "Tanks: MT back towards wall/pillar vs knockback. OT pick mirror at 50%. Both tanks - Center boss on ground marked Rune of Power. Move out of rune (spread) on Rune of Detonation, stay on rune on Rune of Combustion.",
    "DPS: Focus boss - ignore clone. Back facing wall (knockback). Spread for Detonation out of marking (dont stand on Rune of Power), while during Rune on Combustion move in (stand on Rune of Power).",
    "Healers: Follow MT and DPS. Move out on Detonation (spread) and move in on marking during Combustion. Care knockback and have back facing wall.",
    "Class Specific: Quick movement. All classes - not a DPS race. Move out & spread from Rune of Power (marking on ground) when Rune of Detonation. Else stay on and in.",
    "Boss Ability: Rune of Power on ground - Mark of Detonation (spread and move out), Mark of Combustion (stack and move in), if none (stay in). Mirror add at 50%, knockbacks.",
  }},
  { boss="Ragnaros", raid="Molten Core", lines={
    "Tanks: 2 tanks. MT in front, OT ready. Swap after/if current tanks get Wrath of Ragnaros knockbacked. FR gear high. At 50% submerge, tanks stack (entire raid) grab adds in FR gear.",
    "DPS: Melee stack behind. Ranged spread >=8y. Kill adds at 50% quickly (stack), then boss. MDPS move out during Wrath of Ragnaros (avoid knockback).",
    "Healers: Spread >=8y. Heal Wrath + Lava Burst dmg. Focus tanks.",
    "Class Specific: Ret/Survival Hunters/Enh Shamans form mana melee grp.",
    "Boss Ability: Wrath of Ragnaros knockback (move out MDPS, not MT), Lava Burst, submerge + adds at 50%.",
  }},

  -- == BLACKWING LAIR ==
  { boss="Razorgore the Untamed", raid="Blackwing Lair", lines={
    "Tanks: Tanks stay to left and right side of orb-altar and pickup adds. Before Razorgore has destroyed all eggs, the MT takes over control of the orb and destroys the last egg (furthest). Position Razorgore during kill beneath and hugging",
    "the orb-altar.",
    "DPS: Melee DPS spread between left and right side of orb-altar. Range DPS stay on altar. Kill adds and protect orb controller. After add phase, ranged and melee rotate to safe LoS corner of the orb altar (jumping in and out to avoid",
    "fireball).",
    "Healers: Stay on altar during Phase 1; in Phase 2, use LoS corner to avoid Fireball Volley. Prioritize healing the orb-controller immediately after control breaks.",
    "Boss Ability: Razorgore is mind-controlled to destroy eggs via the orb. Select one or two to operate Razorgore and killing the eggs. After control breaks, he casts a Fireball Volley that hits everyone in LoS-raid must hide behind corner of",
    "orb-altar.",
    "Optional: Raidleader can also choose to position Razorgore during P2 in the center of the room, abit towards the entrance and use the pilars to LoS.",
  }},
  { boss="Vaelastrasz the Corrupt", raid="Blackwing Lair", lines={
    "Tanks: Only two tanks needed (max three). Main tank pulls facing one direction; off-tank(s) stand of opposite side of DPS ready to pick up aggro immediately when main tank dies, as boss is taunt-immune.",
    "DPS: Unlimited Mana/Rage/Energy from Essence of the Red. Stay focused on max DPS, but do NOT take agro (watch threat). If afflicted by Burning Adrenaline (deal damage), run to a corner to die safely without exploding near others.",
    "Healers: Mana is infinite-optimize healing output. Prioritize keeping tanks alive through the burn phase and use max ranked heals.",
    "Boss Ability: Vaelastrasz applies Essence of the Red (unlimited resources) and Burning Adrenaline periodically. When Burning Adrenaline expires, the affected player explodes-must run away to avoid wiping raid.",
  }},
  { boss="Broodlord Lashlayer", raid="Blackwing Lair", lines={
    "Tanks: Two tanks required. Pull Broodlord into a corner and hold there-tank's back should be against the wall to avoid his knockback ability. Second tank should be to the side against the other wall (not behind or infront) and be ready to",
    "taunt.",
    "DPS: Melee DPS should position themselves behind, but preferably abit towards the wall to mitigate the knockback. Two Rogues stay stealthed out of combat to disarm traps in the Suppression Room before the pull.",
    "Healers: Keep both tanks topped despite their healing reduction from Mortal Strike debuff. Keep ranged to avoid knockback.",
  }},
  { boss="Firemaw", raid="Blackwing Lair", lines={
    "Tanks: Two tanks (max 3) - MT with 315 Fire Resistance. Position Firemaw in a LoS corner with other tanks using taunt just before Wingbuffet and hiding during downtime. Use Onyxia Scale Cloak (highly recommended) to mitigate Shadow Flame",
    "fire damage.",
    "DPS: Monitor Flame Buffet debuff stacks (5-6), using LoS to drop them. It's a marathon-max damage, but don't die to the stacking burn. Care threat.",
    "Healers: Keep tanks topped as their damage taken stacks rise. Rotate LoS usage so not all healers drop stacks simultaneously.",
    "Optional: Raidleader can choose to position Firemaw just at the entrence of the Firemaw room, with the back towards Suppression Room. If so, 3 healers should be assigned the MT on the Firemaw side and LoS will be done by hugging the wall",
    "on both sides.",
  }},
  { boss="Ebonroc", raid="Blackwing Lair", lines={
    "Tanks: Three tanks required. Position Ebonroc in the corner near the ramp; tanks form a spaced triangle with backs against the wall. Swap taunts immediately in order when current tank is cursed preventing boss healing. Onyxia Scale Cloak",
    "recommended.",
    "DPS: Melee stack tightly behind Ebonroc and remain stationary. Ranged stay positioned to maintain line of sight without moving.",
    "Healers: Focus solely on keeping tanks alive during taunt swaps and curse damage-no extra mechanics to manage.",
    "Optional: Raidleader can choose to position Ebonroc in the left corner just above the ramp instead. Tanks can also swap just before Wingbuffert.",
  }},
  { boss="Flamegor", raid="Blackwing Lair", lines={
    "Tanks: Two tanks required. Pull Flamegor into a corner next to the ramp with each tank spaced and backs against the wall. Taunt-swap on Wing Buffet knockbacks. Onyxia Scale Cloak is strongly recommended to mitigate Fire damage.",
    "DPS: Melee stack closely behind the boss with minimal movement. Ranged maintain steady DPS from further back. Ensure at least two Hunters stand by to use Tranquilizing Shot on Enrage to prevent raid-wide Fire Nova.",
    "Healers: Focus on keeping tanks alive-no special mechanics beyond healing requirements. Hunters must be ready to dispel Enrage quickly.",
    "Class Specific: Hunters use Tranquilizing Shot to remove Enrage immediately when Flamegor gains it, avoiding repeated Fire Nova.",
  }},
  { boss="Chromaggus", raid="Blackwing Lair", lines={
    "Tanks: Two tanks required. Swap only if Time Lapse is cast-off-tank LoS to avoid Time Lapse, then immediately taunt to re-establish aggro. If not cast, MT tanks throughout. Position to allow for all to LoS before abilities, while MT stays",
    "stationary.",
    "DPS: Everyone must line-of-sight each breath to avoid raid-wide damage. ONLY stay in for Time Lapse.",
    "Healers: Dispels and curse removals are critical-always remove debuffs from raid. When Time Lapse is cast, two healers and off-tank must LoS each cast to keep raid alive through stun duration.",
    "Class Specific: Mages/Druids decurse Brood Afflictions (prio tanks > casters > melee); Hunters use Tranquilizing Shot on Frenzy; everyone LoS breath casts.",
  }},
  { boss="Nefarian", raid="Blackwing Lair", lines={
    "Tanks: 2-3 tanks needed. During P1, keep one tank each on each add entrence. When Nefarian lands MT picks up boss on the spot and faces boss towards balcony (tanks back). If \\\"Rogue call\\\", MT runs directly through and turns the boss until",
    "the call is over.",
    "DPS: Split DPS at the add doors to handle adds; never stand in front of the boss. Ranged stay ~40 yards away. Prioritize killing adds quickly when they spawn. Tanks AOE taunt / Limited Vulnerability Potion adds during phase 2 when they",
    "spawn.",
    "Healers: Stay distant (~40 yd) with ranged, out of Bellowing Roar range. Split up during inital add phase.",
    "Class Specific: All players (except MT) stay to right side of Neferian's facing direction. Mages/Druids decurse MT during P2. Priests/Shamans Fear Ward/Tremor Totems for MT.",
    "Boss Ability: If \\\"Mage Call\\\" - Mages needs to quickly LoS rest of raid, else all will get Polymorphed. If \\\"Priest Call\\\" stop casting direct heals, only HoT's. Rest of calls can be ignored/handled on spot.",
  }},
  { boss="Ezzel Darkbrewer", raid="Blackwing Lair", lines={
    "Tanks: Tank Ezzel in the center between pillars. Keep him faced away and centered so charge lanes are predictable.",
    "DPS: When targeted by charge, hide behind a pillar. Boss stuns on pillar hit and becomes vulnerable-burst then. Avoid standing in charge path.",
    "Healers: Pre-hot charge targets and path players. Top Acid Bomb targets, then move out from pools/DoT areas quickly.",
    "Class Specific: Mobility/sprint classes bait and break charge safely. Ranged call safe lanes so melee can step out fast.",
    "Boss Ability: Charges a player every ~10-20s; pillar stops it, stuns boss, and opens vuln window. Acid Bomb deals ~1200 hit plus ticking damage.",
  }},

  -- == ZUL'GURUB ==
  { boss="High Priestess Jeklik", raid="Zul'Gurub", lines={
    "Tanks: Tank Jeklik at spawn, facing her away from melee; off-tank picks up bat adds and holds them separately for AoE clear.",
    "DPS: Melee remain behind Jeklik and interrupt Great Heal and Mind Flay. Ranged stay max range to avoid silences and AoE fire circles. Prioritize killing bats quickly.",
    "Healers: Prioritize keeping melee alive-they take more damage. Dispel Shadow Word: Pain from affected raid members. Stay at max range with ranged DPS to avoid silence.",
    "Class Specific: Priests/Paladins dispel Shadow Word: Pain quickly (prio tanks > casters > melee). Rogues/Warriors must be ready to interrupt Great Heal and Mind Flay.",
    "Boss Ability: Jeklik periodically charges the closest ranged target and casts Sonic Burst (AoE silence). Avoid stacking and use LoS or Tremor Totem to mitigate silence/fear.",
  }},
  { boss="High Priest Venoxis", raid="Zul'Gurub", lines={
    "Tanks: At least two tanks needed. Main tank pulls Venoxis away from snake adds (she can heal them). Other tank takes adds. In Phase 2, kite Venoxis slowly around the room/outside-avoid poison clouds.",
    "DPS: Ranged focus Venoxis to reach Phase 2 quickly. Melee stay far from boss in Phase 1 and burn adds held by off-tank. In Phase 2, everyone burns the boss while avoiding poison clouds.",
    "Healers: Keep at least one healer in range of the boss tank. Watch melee near Venoxis-they can be instantly targeted and heavily damaged.",
    "Boss Ability: Venoxis transforms at 50% health and leaves periodic poison clouds. Position boss away from clouds and kite accordingly to avoid raid-wide damage.",
  }},
  { boss="High Priestess Mar'li", raid="Zul'Gurub", lines={
    "Tanks: Two tanks recommended. One holds Mar'li while off-tank stays with ranged group. When she casts Enveloping Webs and roots melee, off-tank picks her up and brings her back to melee.",
    "DPS: Melee must interrupt Drain Life consistently. Ranged stay 30+ yards away with healers, killing spider adds immediately as they spawn.",
    "Healers: Dispel Poison Bolt Volley when possible. Shamans should use Poison Cleansing Totem. Stay at least 30 yards away to avoid boss poison and webs.",
    "Class Specific: Shamans place Poison Cleansing Totem to help with Poison Bolt Volley. Priests/Paladins need to dispel Poison Bolt Volley quickly (prio tanks > casters > melee).",
    "Boss Ability: Enveloping Webs roots all melee and drops threat-off-tank must pick up Mar'li immediately. Periodic spider adds must be killed ASAP.",
  }},
  { boss="High Priest Thekal", raid="Zul'Gurub", lines={
    "Tanks: 2-3 tanks recommended-one for Thekal and one each for Lor'Khan and Zath. Swap taunts on Gouge/Blind gaps. Synchronize pulls so all three bosses drop within ~10 seconds to prevent resurrections.",
    "DPS: Kill Zulian Tigers immediately. Bring Thekal, Lor'Khan, and Zath to ~10-15% health, then AoE them down simultaneously to avoid resurrection. Interrupt Great Heal and silence when needed.",
    "Healers: Use cooldowns to keep all tanks alive through synchronized burn. Dispel Silence and watch for healer interrupts on Lor'Khan. Manage mana across phases for extended burn.",
    "Boss Ability: Phase 1: Thekal's Council-Thekal, Lor'Khan, and Zath alongside spawn tigers. All three must die together or they resurrect. Phase 2: Thekal enrages and gains Force Punch-tank should be ready to taunt to mitigate if pulled",
    "into melee.",
  }},
  { boss="High Priestess Arlokk", raid="Zul'Gurub", lines={
    "Tanks: Two tanks recommended. Main tank picks up Arlokk and faces her away from melee. Off-tank holds panthers-grab them when they lose stealth and strip aggro off the marked player before they overwhelm the raid.",
    "DPS: Focus DPS on Arlokk while she is visible. When Arlokk vanishes, kill only the panthers attacking raid-avoid those on off-tanks. Resume DPS on Arlokk immediately upon reappearance.",
    "Healers: Watch the marked player-they draw panthers and take high damage. Ranged & healers can back to fences during vanish phases to force Arlokk's reappear behind the fence and dodge her Whirlwind.",
    "Class Specific: Warlocks/Priests mass-fear panthers once Arlokk vanishes (raid control). Mages use AoE to thin panther groups swiftly before boss reappears.",
    "Boss Ability: Arlokk periodically vanishes into stealth, marking a player that draws panthers, then reappears with a deadly Whirlwind cleave-be ready to dodge and regain control quickly.",
  }},
  { boss="Hakkar", raid="Zul'Gurub", lines={
    "Tanks: Two tanks needed. Tanks must maintain threat continuously since Hakkar is taunt-immune. Expect occasional mind control on the one with agro - when under control the other tank takes position.",
    "DPS: Ranged and melee must spread to avoid chaining Corrupted Blood, but stack briefly to soak Blood Siphon via the Son of Hakkar's Poisonous Blood debuff.",
    "Healers: Stay spread to reduce Corrupted Blood chaining. Prepare raid for high healing demands during Blood Siphon-early warning allows cooldown usage.",
    "Class Specific: Hunter or Mage assigned to pull Son of Hakkar to raid for Poisonous Blood soak before Blood Siphon. Can be pre-pulled and crowd controlled (CC) if the raid has room for it. Atleast 1 Mage or Warlock keep mind controlled",
    "tank Polymorphed.",
    "Boss Ability: Hakkar periodically casts Blood Siphon. When its 20-30 seconds remaining before the ability, kill the Son of Hakkar (should already be on the platform) and make sure everyone soaks it (do not cure posion).",
  }},
  { boss="Bloodlord Mandokir", raid="Zul'Gurub", lines={
    "Tanks: Two tanks needed. One holds Mandokir, one hold the raptor away from raid. Taunt quickly if the boss charges and drops threat. Face boss away from melee to avoid cleave.",
    "DPS: Kill the boss first, then raptor. One Hunter can stay at max range to bait charges.",
    "Healers: Stay in range of both tanks and melee. Use cooldowns if raptor is killed early-tanks take heavy damage then. Monitor Threatening Gaze; avoid actions if targeted.",
    "Boss Ability: Mandokir uses Threatening Gaze-target must freeze (no actions) or die. Deaths trigger chained spirits that resurrect players; every three deaths empower Mandokir.",
  }},
  { boss="Jin'do the Hexxer", raid="Zul'Gurub", lines={
    "One or two tanks needed (Druid tank can go solo). If not a Druid, swap on Hex (should be dispelled immediately).",
    "DPS: Prioritize adds in this order: Shades (kill immediately, invisible unless cursed) > Brainwash Totem > Healing Totem > then Jin'do. Potentially assigned Mage/Warlock should AoE skeletons when someone is teleported into the pit.",
    "Healers: Dispel Hex on tank instantly. Do not remove Delusions. Be ready to heal raid through Shade attacks and pit DPS.",
    "Class Specific: Mages or Warlocks assigned to AoE cleanup of skeletons from teleport phase. Priests/Paladins dispel Hex-all others avoid dispelling Delusions.",
    "Boss Ability: Jin'do casts Hex on the tank (must be dispelled), periodically summons Shades that must be killed by cursed players, Healing Totems that buff Jin'do, Brainwash Totems that control players, and may teleport a player into the",
    "skeleton pit.",
  }},
  { boss="Gahz'ranka", raid="Zul'Gurub", lines={
    "Tanks: Only one tank needed. Tank Gahz'ranka in the shallow river to negate knockbacks and slam effects, minimizing positioning issues. Recover aggro immediately if knocked back.",
    "DPS: Fight him underwater to avoid geyser knockbacks and fall damage. Melee should stand close; ranged phased in to avoid being tossed. DPS until dead.",
    "Healers: No major raid-wide mechanics-keep main tank healed through any knockback/reposition recovery.",
    "Boss Ability: Gahz'ranka has three mechanics-Frost Breath (cone that slows/mana drains), Slam (knockback), and Massive Geyser (random knockback and fall damage). All are nullified by fighting in water.",
  }},

  -- == RUINS OF AHN'QIRAJ ==
  { boss="Kurinnaxx", raid="Ruins of Ahn'Qiraj", lines={
    "Tanks: Face Kurinnaxx away from the raid. Use two tanks and swap at ~5 Mortal Wound stacks. Move boss slowly to avoid Sand Traps. Save defensive cooldowns for his enrage at 30%.",
    "DPS: Stay behind the boss. Keep eyes on the ground to avoid Sand Traps. Save DPS cooldowns for the final burn after enrage triggers.",
    "Healers: Watch tanks' Mortal Wounds, heal through the add phase while managing threat. Avoid standing in Sand Traps. Expect and prepare for heavier healing demands post-30% enrage.",
  }},
  { boss="General Rajaxx", raid="Ruins of Ahn'Qiraj", lines={
    "Tanks: First tank holds wave adds while second grabs Captains if needed and pull it to the side (waves will likely come of themselves, so wait at entrence to room). During Rajaxx himself, face him away from the raid-use defensives.",
    "DPS: Focus down small adds in each wave before engaging Captains. Save all cooldowns for Rajaxx; burn him quickly after the wave. Expect knocks from Thundercrash-keep movement tight.",
    "Healers: Keep tanks topped through the waves and especially through Thundercrash damage. Don't let burst knockbacks overwhelm your healing capacity.",
  }},
  { boss="Moam", raid="Ruins of Ahn'Qiraj", lines={
    "Tanks: Only one tank needed. Keep Moam facing away from the raid. Moam does not do much damage, so focus holding threat.",
    "DPS: Maximize damage output without taking agro. Use cooldowns and kill the boss as quickly as possible.",
    "Healers: Moam does not do alot of damage, so any Priest healers should cast mana burn instead of healing. Only MT will take damage (minimal) and can easily be healed by one or two healer (depending on raid size).",
    "Class Specific: Priests, Warlocks, Hunters-must continuously use Mana Burn, Mana Drain, or Viper Sting to prevent Moam from reaching full mana and wiping the raid.",
    "Boss Ability: Moam constantly drains the raid's mana and gains it himself-if Moam fills up before being killed (approximately 90 seconds), he casts a fatal raid-wiping explosion. Avoid triggering Phase 2 by killing him promptly.",
  }},
  { boss="Buru the Gorger", raid="Ruins of Ahn'Qiraj", lines={
    "Tanks: No boss tanking required until Buru reaches 20%. One tank picks up adds spawned from eggs as they explode near Buru. Adds are easy to handle and should be grabbed immediately. Tank boss when less than 20% remaining.",
    "DPS: Focus on getting eggs to 20% health and killing eggs near Buru to damage him-do not attack Buru directly before boss has 20%. At 20% health, burn him hard-save all cooldowns for this final phase.",
    "Healers: Prioritize raid survival during the final burn phase, else incoming damage to the one getting focused and tanks picking up adds. Use cooldowns and consumables effectively.",
    "Boss Ability: Buru fixates a player that will likely be marked with a Skull. This player must kite Buru and stand behind an egg that has 20% remaining. Once the Buru is ontop of an egg kill the egg. Follow the procedure until Buru has 20%",
    "health.",
  }},
  { boss="Ayamiss the Hunter", raid="Ruins of Ahn'Qiraj", lines={
    "Tanks: Only one tank needed. Pick up the small adds when they spawn. Try to get inital threat before airphase. Taunt in Phase 2, when Ayamiss lands. Tank in at top of altar in any corner (facing the boss away).",
    "DPS: Ranged DPS stand on the altar and focus the boss in Phase 1 while she's airborne. Melee DPS stay beneath the altar stairs and focuses on the Larva adds when present. Phase 2 is ground combat-kill boss quickly while avoiding raid-wide",
    "nature damage.",
    "Healers: Focus healing on ranged DPS during Phase 1-they take stacking nature damage from Stinger Spray. Stock consumables and use efficiency-this fight is healing-intensive.",
    "Boss Ability: Ayamiss the Hunter will select one player to be sacrificed. During this phase Melee DPS needs to kill the spawned Larva before it reaches the altar.",
  }},
  { boss="Ossirian the Unscarred", raid="Ruins of Ahn'Qiraj", lines={
    "Tanks: Two tanks needed. Build max threat (boss is taunt-immune). Keep Ossirian consistently on and towards crystals to remove his Strength buff or he becomes enraged. Careful at pull as he needs to be kited to the first crystal.",
    "DPS: Careful to not overtake threat from tanks. Assign a dedicated DPS to scout and activate next crystals when it's 10 seconds left on the timer. Avoid tornadoes and move out of War Stomp.",
    "Healers: Watch tank during crystal transitions, stay out of melee range to avoid War Stomp, but try and stay ahead of the tanks (towards the next crystal) to make sure you always can reach.",
    "Class Specific: Druids/Mages can decurse Curse of Tongues on raid.",
    "Boss Ability: Ossirian starts with Strength of Ossirian buff-must be kited and placed on an activated crystal to become vulnerable for 45 s (repeat). Avoid tornadoes and manage movement between crystals to prevent enraged burst.",
  }},

  -- == TEMPLE OF AHN'QIRAJ ==
  { boss="The Prophet Skeram", raid="Temple of Ahn'Qiraj", lines={
    "Tanks: Three tanks are needed-one on Skeram, and two on clones positioned atop the stairs first set of stairs (will appear). This ensures each is held separately and avoids overlapping Arcane Explosion damage.",
    "DPS: Ranged and melee spread their damage evenly across Skeram and clones to identify the real boss by slower health drop. Interrupt Arcane Explosion, and use Curse of Tongues to slow cast times.",
    "Healers: Stay on the top platform to avoid Arcane Explosion. Area-of-effect healing is essential when it hits, and keep healing tanks regardless of Mind Control targets.",
    "Boss Ability: Prophet Skeram teleports at 75%, 50%, and 25% health, spawning two clones. Perform Arcane Explosion interrupts, manage Mind Controls, and burst the real boss while managing clone aggro.",
  }},
  { boss="Silithid Royalty (Bug Trio)", raid="Temple of Ahn'Qiraj", lines={
    "Tanks: Assign one tank per boss (recommend 2 for Yauj) in separate corners. Rotate taunts and Berserker Rage on Yauj to avoid threat reset. Move Kri away from raid before death to avoid poison cloud. Save cooldowns for final boss if not",
    "killing Vem last.",
    "DPS: Nuke one boss at a time. Interrupt Yauj's heals. Kill her adds fast after death. Stay away from Kri at low HP to avoid poison cloud. Save DPS cooldowns for enraged final boss if Vem is not last.",
    "Healers: Assign extra healers to Kri tank. Use Poison Cleansing Totem or Abolish Poison on Kri group. Use Tremor Totem or Fear Ward on Yauj tank group. Prepare big heals for final boss if not Vem.",
    "Class Specific: Warriors rotate Berserker Rage on Yauj. Priests use Fear Ward. Shaman use Tremor Totem and Poison Cleansing Totem. Paladin/Druid use Cleanse/Cure on poison. Rogues/Warriors should interrupt heals.",
    "Boss Ability: Vem charges and knocks back. Kri deals heavy poison AoE. Yauj fears and heals, and spawns adds on death. Killing a boss enrages the others-Vem last is safest, Kri last is hard mode.",
  }},
  { boss="Battleguard Sartura", raid="Temple of Ahn'Qiraj", lines={
    "Tanks: Assign four tanks-one each for Sartura and her three royal guards. Tank them apart at spread positions to avoid overlapping Whirlwinds, and rotate taunts if threat is lost. Save cooldowns for enrage at 20%.",
    "DPS: Spread out across the room, focus down the guards first using stuns to control their movement, then burst Sartura once adds are down. Melee move away from Whirlwind.",
    "Healers: Spread evenly across the room away from Whirlwind zones. Assign dedicated healers per tank group and prioritize healing downed tank fast during enrage.",
    "Class Specific: Warriors, Rogues, and Paladins should use stuns (e.g., Concussion Blow, Kidney Shot, Hammer of Justice) to control Sartura when Whirlwind ends. Try not to overlap each stun, instead create a smooth rotation to keep the",
    "targets stunned.",
    "Boss Ability: Sartura and guards use Whirlwind, dropping aggro periodically and dealing AoE damage; Cleave/Sunder increase tank damage; at 20% Sartura enrages, increasing attack speed and physical damage.",
  }},
  { boss="Fankriss the Unyielding", raid="Temple of Ahn'Qiraj", lines={
    "Tanks: Use at least three tanks-two on Fankriss, one on adds (preferably a Paladin or Druid). Turn Fankriss away from raid. Rotate when Mortal Wound stacks hit 50% healing reduction. Tank adds as needed.",
    "DPS: Focus down Spawn of Fankriss immediately before they enrage. Handle Vekniss Hatchlings on sight to prevent lethal webs; off-tank leftovers as numbers grow.",
    "Healers: Stack behind Fankriss to quickly aid webbed players. Use defensive cooldowns when swarm of adds hits.",
    "Boss Ability: Fankriss spawns adds that enrage if untreated; he also stacks Mortal Wound, significantly reducing healing-mitigate via rotation.",
  }},
  { boss="Viscidus", raid="Temple of Ahn'Qiraj", lines={
    "Tanks: One dedicated tank is enough-other tanks focus on DPS, freezing and shattering the boss once he's brittle.",
    "DPS: Use frost attacks (procs, frost weapons, wands) to gradually freeze Viscidus, then immediately shatter with burst damage to prevent reversion. When Viscidus splits, use Sapper Charges and AOE to kill onces close to gathered.",
    "Healers: Prepare area healing and anti-poison effects during freezing phases, especially when Viscidus spawns blobs that run inward and reform the boss.",
    "Class Specific: Mages excel with fast Rank 1 Frostbolts to freeze. Others should use Frost procs or apply frost oils when possible. Non-contributing players should hang back safely until blobs appear. All - Nature Resistance gear",
    "recommended.",
    "Boss Ability: Viscidus must be frozen in stages and shattered-each successful shatter spawns blobs that reduce his health when killed. Time frost damage and burst carefully to manage the 15-second timer per freeze stage.",
  }},
  { boss="Princess Huhuran", raid="Temple of Ahn'Qiraj", lines={
    "Tanks: Use 1-2 tanks and rotate when Acid Spit stacks (5+) begin to exceed healing capacity. Keep her facing away from melee. Equip Nature Resistance is recommended (depending on group).",
    "DPS: Damage boss as hard as possible, without breaking threat. Interrupt Frenzy with Tranquilizing Shot. Nature Resistance gear is recommended (depending on group).",
    "Healers: Spread to avoid multiple silences from Noxious Poison. Do not dispel Wyvern Sting unless called-doing so causes massive damage. Save at least 50% mana for her enrage phase.",
    "Class Specific: Hunters handle Tranquilizing Shot to remove Frenzy.  Barov Peasant Caller (trinket from quest) is highly recommended to be used and equiped by ALL players at ~40% health. This forces up towards 120 minions to soak the",
    "poison instead.",
    "Boss Ability: Huhuran applies Acid Spit stacking on tanks, Noxious Poison AoE on melee, and Berserker Enrage at 30%-use nature resistance and cooldowns to survive. Barov Peasant Caller quest trinket is highly recommended at ~40%.",
  }},
  { boss="Twin Emperors", raid="Temple of Ahn'Qiraj", lines={
    "Tanks: Assign one melee tank and one shadow-caster tank per emperor. Pull each to opposite sides (against wall) to avoid shared healing and split threat. Be ready to swap from melee to range tanking quickly after teleport, which grants",
    "threat to closest.",
    "DPS: Focus adds from Vek'nilash (bugs he spawns), then burn the emperor. Melee on Vek'nilash (and bugs during switch), casters handle bugs and shift to Vek'lor when adds are clear. Therefore DPS will run between the sides for their",
    "respective target.",
    "Healers: Position centrally for coverage; avoid Blizzard rays and exploding bugs from Vek'lor. Keep tanks topped through swaps and area transitions. Assign healers to tanks.",
    "Boss Ability: Two emperors share health; Vek'nilash auto-summons bugs and reduces tank defense, while Vek'lor casts Blizzard and Arcane Explosion zones-positioning is critical.",
  }},
  { boss="Ouro", raid="Temple of Ahn'Qiraj", lines={
    "Tanks: Keep two or more tanks ready-main tank on Ouro and off-tanks to handle burrow threat resets. Always face Ouro away from the raid (and the focused tank on his own) and be ready to Intercept immediately after Sweep to prevent",
    "burrow-triggered reset.",
    "DPS: Stand in mid-range to maintain boss agro and prevent instant burrowing. DPS Ouro until he burrows-be prepared to dodge Earthquake effects and kill adds quickly. \\\"Regular\\\" and shadow based DPS stand seperately, due to threat.",
    "Healers: Spread out to minimize Sand Blast coverage and avoid standing behind tanks. Stay mobile during earthquakes and reserve at least 20% mana for the frantic final phase. Use fast, instant heals while moving.",
    "Boss Ability: Ouro burrows periodically, creating Earthquake zones while underground. He uses Sand Blast, a wide frontal AoE. At 20%, he becomes enraged-uses both burrow mechanics simultaneously and summons adds-burn phase must be fast.",
  }},
  { boss="C'Thun", raid="Temple of Ahn'Qiraj", lines={
    "Tanks: Phase 1-The initial pull must be made by a dedicated tank through a door peek to absorb 3x Eye Beam-others enter and spread. Phase 2-Tanks must quickly pick up Giant Claw Tentacles as they spawn; stay mobile to avoid being killed by",
    "chained beams.",
    "DPS: Phase 1-spread in concentric circles to avoid the eye beam and red Death Glare. Focus small Eye Tentacles first, then Giant Claw, then Giant Eye Tentacles. Phase 2-damage tentacles inside stomach as quickly as possible during",
    "vulnerability windows.",
    "Healers: Spread out to avoid chained Eye Beam and Death Glare. If inside stomach, tanks should exit quickly-healers need to top melee up before rejoining; heal players under attack by tentacles or beams immediately.",
    "Healers: Raid-wide damage. Position for coverage",
    "Boss Ability: Phase 1-Conal Green Eye Beam (chains) and rotating Death Glare. Phase 2-Spawns Giant Claw Tentacles (tank then kill), Giant Eye Tentacles (beam attacks), and eats raid members into stomach where 2 tentacles must be killed to",
    "weaken the boss.",
  }},

  -- == NAXXRAMAS ==
  { boss="Anub'Rekhan", raid="Naxxramas", lines={
    "Tanks: Main tank should position Anub'Rekhan deep in the room, facing his Crypt Guards away from raid. Assign off-tanks to hold add threat. Use Free Action Potions to avoid Web roots. If Locust Swarm (after 90s), MT needs to kite the boss",
    "away from raid.",
    "DPS: Focus adds first-Crypt Guards then unlocked Corpse Scarabs. Cleave when paired is ideal. Melee use quick gap closers against Scarabs; Hunters help kite during Locust Swarm with Aspect of the Pack.",
    "Healers: Watch for fall damage and Impale victims-spot-heals in mid-air can save lives. Pre-HoT tanks before Web Spray and Swarm.",
    "Class Specific: Hunters boost Main Tank speed during Locust Swarm.",
    "Boss Ability: Impale targets a straight line, launching and damaging players. Locust Swarm silences and deals heavy Nature DoT-raid must spread and flee opposite side of the room.",
  }},
  { boss="Grand Widow Faerlina", raid="Naxxramas", lines={
    "Tanks: Assign one tank to Faerlina and others to hold Worshippers (to be mind-controlled) and Followers separately. Kite the boss out of Rain of Fire quickly when it targets melee.",
    "DPS: Prioritize killing Followers immediately to eliminate their AoE Silence and Charge. Do not damage Worshippers-save them for post-Enrage.",
    "Healers: Dispel Poison Bolt Volley quickly (Nature DoT) using Druids/Shamans/Paladins. Use healing cooldowns during Frenzy bursts.",
    "Class Specific: Priests must Mind Control Worshippers at Enrage to use Widow's Embrace, which removes Frenzy and silences her Nature spells for 30 seconds.",
    "Boss Ability: Poison Bolt Volley hits multiple players and applies a Nature DoT; Rain of Fire creates damaging fire zones; Frenzy sharply increases her damage-must be mitigated via Widow's Embrace.",
  }},
  { boss="Maexxna", raid="Naxxramas", lines={
    "Tanks: Position Maexxna in the room's center, facing away from the raid. Pre-buff tank with high mitigation like Greater Stoneshield Potion, Lifegiving Gem, or cooldowns such as Shield Wall before Web Spray.",
    "DPS: Ranged destroy Web Wrap cocoons on the room's edge. AoE spiderlings right after spawn, using Frost Nova or AoE spells. Save DPS cooldowns for after Web Spray.",
    "Healers: Heal tank prio, keeping MT full health at all times. Heal players that get Web Wrap in coccoons. Layer HoTs, shields, and Abolish Poison on the tank just before Web Spray.",
    "Class Specific: Druids, Shamans, and Paladins are essential for quickly cleansing Necrotic Poison. Hunters, Mages, and Warlocks must handle cocoon destruction and spiderling control.",
    "Boss Ability: Web Wrap sends players to the wall and deals DOT in cocoon. Spiderling Summon spawns adds to AoE. Web Spray stuns and damages raid every 40s. At ~30%, Frenzy increases damage output.",
  }},
  { boss="Noth the Plaguebringer", raid="Naxxramas", lines={
    "Tanks: Keep Noth central and facing away from the raid. After each Blink (which results in a full threat-reset every ~30 sec), the off-tank must pick up spawning warrior adds. Use Free Action Potions to avoid Blink's Cripple effect for",
    "melee.",
    "DPS: Prioritize adds after Blink - don't kill Noth during brief threat reset. Resume boss DPS once aggro is stabilized. Keep DPS tight and clear adds quickly.",
    "Healers: Focus on tank healing. Be ready to top off off-tank taking damage from adds post-Blink.",
    "Class Specific: Mages/Druids should decurse without delay, starting with tanks. Warriors and Paladins should taunt or use defensive cooldowns proactively post-Blink.",
    "Boss Ability: Noth applies Curse of the Plaguebringer every ~60 seconds (deadly DoT if not removed). He Blinks regularly, resetting aggro and briefly incapacitating melee. Adds spawn only if boss is ignored during aggression transitions.",
  }},
  { boss="Heigan the Unclean", raid="Naxxramas", lines={
    "Tanks: Main tank should keep Heigan away from the platform to protect mana-users from Mana Burn. Move boss between safe zones in rhythm with the dance pattern starting from entrence to the other side of the room and back.",
    "DPS: Melee DPS focus damage while avoiding erupting slimes. Ranged stay on the platform for mana and range protection, stepping down only during \\\"the dance\\\".",
    "Healers: Stand on the platform to avoid Mana Burn, stepping down only during \\\"the dance\\\".",
    "Class Specific: Priests, Paladins, and Shamans are critical-they must cleanse Decrepit Fever promptly (prio MT) to prevent raid health reduction.",
    "Boss Ability: The fight features a \\\"dance\\\" mechanic-slimes erupt in waves, requiring movement between safe zones. Decrepit Fever and Mana Burn pressure add urgency to positioning and healing.",
  }},
  { boss="Loatheb", raid="Naxxramas", lines={
    "Tanks: Keep Loatheb centered and stable throughout the fight in full mitigation gear. Tanks avoid getting the zero-threat Fungal Creep debuff. Aim for off-center placement to manage spore spawn points.",
    "DPS: Groups of 5 raid members should grab the Fungal Bloom buff from spores as soon as they spawn in a pre-defined order. This adds massive crit (~+50-60%) and no threat for 90 s. Rotate roles or raid groups accordingly to maximize raid",
    "DPS.",
    "Healers: Due to Corrupted Mind (1-minute shared healing cooldown), each healer may only cast one healing or utility spell per minute-plan a strict heal rotation. Use Shield and HoTs at all times-to mitigate damage effectively (doesnt",
    "trigger debuff).",
    "Class Specific: Following does not trigger debuff - Druids and Priests use HoTs like Rejuvenation/Renew. Paladins/Priests apply shields and blessings. Shamans drop Poison Cleansing Totem. All classes with poison cures should cleanse melee",
    "regularly.",
    "Boss Ability: Loatheb triggers Fungal Spores (spawns every ~13 seconds), Corrupted Mind (1-minute healing spell cooldown), Inevitable Doom (massive raid damage after ~10 seconds, every 30s), and Poison Aura (AoE nature damage to melee).",
  }},
  { boss="Instructor Razuvious", raid="Naxxramas", lines={
    "Tanks: Regular tanks do not handle the boss; instead, tank the three unused Understudies and avoid sunder/taunt to keep them clean for Priests (mind control). Position in LoS position to avoid Disrupting Shout.",
    "DPS: Avoid pulling threat from the MCed Understudy tanks. DPS boss only when a taunt is active and Shield Wall is up. Prioritize clean transitions between tank swaps. Avoid Disrupting Shout.",
    "Healers: Prepare to heal the MCed Understudy between taunts-especially after Unbalancing Strike. Use LoS to avoid Disrupting Shout, and coordinate with Priests to heal the new tank target.",
    "Class Specific: for Priests Mind Control rotation is critical. Use Shield Wall + Taunt on each Understudy before they break. Alternate and allow time for healing.",
    "Boss Ability: Disrupting Shout is a 5k Mana burn and deals double the damage to health - use LoS to survive (this is especially for healers and ranged DPS that \\\"peak\\\" when the Shout is not cast, while Melee should be behind boss and",
    "tanks LoS all time).",
  }},
  { boss="Gothik the Harvester", raid="Naxxramas", lines={
    "Tanks: Preferable up towards 5 tanks (depending on group) - 3 on living side and 2 on undead side. Handle incoming waves per side via platforms and piles. Horses and Raiders needs to be tanked and facing away from raid and are the main",
    "focus.",
    "DPS: Split raid into \\\"living\\\" (left) and \\\"undead\\\" (right) groups. Kill riders first on living side, then death knights, then trainees. On undead side: trainees -> riders -> death knights -> horses. Avoid mass kills to prevent",
    "overwhelming the opposite side.",
    "Healers: Assign healers per side. On living side, prioritize shackle undead cast by Priests. On undead side, manage mana and use cooldowns during heavy wave transitions-beware Shadow Bolts.",
    "Class Specific: Priests must Shackle Undead Deathknights to stall incoming waves.",
    "Boss Ability: Gothik summons dual waves for 4 min 30s, spawning on each side. At that point, he engages directly, using instant Shadow Bolt, Harvest Soul (-10% stats each stack), and must be tanked carefully through transitions.",
  }},
  { boss="The Four Horsemen", raid="Naxxramas", lines={
    "Tanks: Assign 6-8 dedicated tanks (1-2xThane, 1-2xMograine, 2xLadyB, 2xZeliek, depending on strategy), selecting one tank each to position their boss in one corner of the room immediately on pull. Rotate using Off-Tanks for 3-4 stacks.",
    "Middle is safezone.",
    "DPS: Spread DPS across Thane, Mograine, Blaumeux, and Zeliek (all starting Thane to kill at start). Monitor personal marks - avoid stacking over 3 - 4. Melee stack behind Thane for Meteor. Dodge LadyB Void Zone, and stay away from Zeliek",
    "for Holy Wrath.",
    "Healers: Always track marks; healers must stay under 3 - 4 stacks, rotating between bosses equally. Move with the raid rotation and be prepared to heal the active tank during swaps. Healers begin divided and move in intervals of gained",
    "marks (1,2 or 3).",
    "Rotation: Tanks - the two upper bosses should be tanked by the 4 assigned tanks, rotating based on stacks and using middle safezone to await. DPS prio - Thane>Mograine>LadyB>Zeliek. Healers - move on your mark repeatedly, either on each 1,",
    "2 or 3.",
    "Boss Ability: Each Horseman casts Mark every ~13 seconds, stacking, unremovable, and dealing increasing damage. Upon death, each summons a Spirit that continues to cast Mark and must be avoided. All players should use middle safezone.",
  }},
  { boss="Patchwerk", raid="Naxxramas", lines={
    "Tanks: Use three to four tanks to soak Hateful Strike in full mitigation gear, the boss's primary mechanic. The main tank should maintain threat; off-tanks need high health (~9k+ health) and armor to minimize damage. Tanks must be top 3-4",
    "on threat.",
    "DPS: Avoid overtaking tanks on threat to reduce the chance of being hit by Hateful Strike. Melee and ranged need to maintain steady DPS while monitoring threat. Non-mana users can dip in the green acid for less health, to avoid accidential",
    "strikes.",
    "Healers: Assign dedicated healers to the tanks only-top them off continuously. Do not heal DPS at all or other healers to ensure tank survival through savage strikes.",
    "Boss Ability: Hateful Strike hits the highest-health melee player (other than the tank), dealing significant damage. At ~5% health, Patchwerk Enrages, gaining 40% attack speed and increased damage output.",
  }},
  { boss="Grobbulus", raid="Naxxramas", lines={
    "Tanks: Keep Grobbulus facing away from the raid-only the tank should ever be in front to avoid Slime Spray add spawns. Slowly kite the boss around the outer grate of the room, moving after each Poison Cloud is dropped (every ~15s). Pop",
    "cooldowns at 30%.",
    "DPS: Kill Slime adds quickly; cleave them down when they spawn in melee. Stay behind the boss at all times. Avoid being in front to prevent add spawns from Slime Spray.",
    "Healers: Prepare for burst healing when players receive Mutating Injection-they will run to the side away before being dispelled (do not dispel before). Expect doubled frequency after 30%.",
    "Class Specific: Dedicate 1x Priest/Paladin to dispel Mutating Injection only after the infected player has moved away out of the raid.",
    "Boss Ability: Poison Cloud- dropped at boss location every 15s, expands over time, persists indefinitely. Slime Spray - Frontal cone, spawns 1 Slime per player hit. Mutating Injection - Disease explodes after 10s, deals AoE damage-run out",
    "of raid.",
  }},
  { boss="Gluth", raid="Naxxramas", lines={
    "Tanks: Use 1-2 tanks and potentially rotate at 3-4 Mortal Wound stacks (can be done solo). Position boss near door to increase distance from zombies. Another tank can spam Blessing of Kings or shout/howl to get aggro of Zombies and kite",
    "them.",
    "DPS: Focus boss. Assign a kite team for zombies using Frost Trap, Nova, and slows. Do not let zombies reach Gluth post-Decimate or he will heal massively.",
    "Healers: Maintain tank healing through Mortal Wound debuff. After Decimate, be ready for quick AoE and tank burst heals. HoTs pre-Decimate help survivability.",
    "Class Specific: Hunters, Paladin, Warrior or/and Mages kite zombies with Frost Trap, Nova, Blessing of Kings, Howl and slows. Priests and Druids pre-cast HoTs before Decimate. Use Fear Ward to avoid zombie fears if applicable.",
    "Boss Ability: Mortal Wound stacks reduce tank healing. Decimate drops all units to 5% HP. Enrage is removed with Tranquilizing Shot.",
  }},
  { boss="Thaddius", raid="Naxxramas", lines={
    "Tanks: 2-4 tanks recommended. Each tank handles one mini-boss on their starting platform. Have an off-tank ready to taunt whenever the main tank is knocked back. Rotate as needed to maintain control. On the boss, tank the boss center, but",
    "move to +/-side.",
    "DPS: Divide DPS between the platforms - as to die at same time. On the boss split into positive (+right side) and negative (-left side) charge groups and stack accordingly. Stay with your assigned side to maintain polarity and avoid",
    "excessive damage.",
    "Healers: Spread across the two platforms to cover each tank. Keep healing flows smooth during polarity shifts-mark changes cause stacking damage if mixed up.",
    "Boss Ability: Polarity Shift assigns raid-wide +/- charges periodically-standing with opposite-charge players deals massive damage. All players should stack in respective group and run directly through boss if the individual stack changes",
    "(+ right/- left)",
  }},
  { boss="Sapphiron", raid="Naxxramas", lines={
    "Tanks: MT tank Sapphiron in middle of the room facing the opposite side of the entrence. Follow mechanics during air phase, then reposition during ground phase.",
    "DPS: Transition between melee and ranged depending on phase. Use Frost Resistance Potions. Move to avoid Blizzard. Spread during air phase to get even spread of Ice Blocks.",
    "Healers: Pre-shield and pre-heal tanks before breath phases. Spread HoTs to mitigate Frost Aura damage during landing. Use powerful AoE heals when Blizzard hits. Try to keep everyone full health.",
    "Class Specific: Using Frost Resistance gear recommended (~100, depending on group). Druids / Mages decurse immediately Life Drain on all players (high prio).",
    "Boss Ability: Alternates ground and air phases; casts Frost Breath, Blizzard zones, Ice Block targeting, and a constant Frost Aura.",
  }},
  { boss="Kel'Thuzad", raid="Naxxramas", lines={
    "Tanks: Phase 1 - tank Unstoppable Abominations at edge of center circle. Phase 2/3 - Main tank (MT) holds boss, Off-tanks (OT) during phase 2 ready to take agro if MT is Mind Controlled and pick up Guardians in Phase 3 and kite them if",
    "needed.",
    "DPS: Phase 1 - kill Abominations then clear portal adds from Soldiers/Soul Weavers as they come. Soldiers/Soul Weavers should be prioritized by ranged DPS and not to reach melee. Phase 2/3 - Melee stack on boss and DPS while respecting",
    "spacing.",
    "Healers: Phase 2 - spread to avoid Detonate Mana and Frost Blast chains. Heal Frost Blast victims immediately. Phase 3 - Priests maintain Shackles on Guardians.",
    "Class Specific: Rogues/Warriors must interrupt Frostbolt. Mages/Warlocks CC Mind-controlled raid members. Priests Shackle Guardians in Phase 3.",
    "Boss Ability: Phase 2 - Frostbolt interruptible, Frostbolt Volley, Chains of Kel'Thuzad (MC), Detonate Mana, Shadow Fissure, Frost Blast. Phase 3 - spawn Guardians needing Shackle/Kite. MT, OT and DPS needs to group respecitvely in a",
    "triangle around boss.",
  }},

  -- == WORLD BOSSES ==
  { boss="Lord Kazzak", raid="World Bosses", lines={
    "Tanks: One tank is sufficient. Face Kazzak away from the raid to avoid Cleave. Manage threat carefully-player deaths heal Kazzak via Capture Soul. Maintain cooldowns to survive during enrage.",
    "DPS: Manage threat tightly; avoid stacking. Dying causes Kazzak to heal. Dispel Twisted Reflection to stop boss healing and Mark of Kazzak to prevent explosive deaths.",
    "Healers: Dispel Twisted Reflection fast (Priests/Paladins). Cleanse Mark of Kazzak or have target run away before mana burnout explosion. Watch for Capture Soul, heal quick to avoid healing Kazzak.",
    "Class Specific: Priests/Paladins must dispel Twisted Reflection. Druids/Mages should cleanse Mark of Kazzak if possible or the target should disengage raid safely. Other classes support with LoS for Shadowbolt Volley.",
    "Boss Ability: Heals when players die (Capture Soul), casts Twisted Reflection to steal life-must be dispelled, Mark of Kazzak drains mana then explodes, Shadowbolt Volley hits raid, Enrages after 3 mins-burn fast or wipe.",
  }},
  { boss="Azuregos", raid="World Bosses", lines={
    "Tanks: Solo tank works. Face Azuregos away from raid. Save Rage for teleport aggro resets. Pull to open area so raid can dodge Manastorm easily.",
    "DPS: Spread out and avoid Manastorm. After teleport, run away from Azuregos to avoid breath/cleave. Stop DPS until tank regains threat.",
    "Healers: Watch for teleport resets. Stay spread, avoid Manastorm, and don't heal near front. Be ready to heal tank after aggro reset.",
    "Class Specific: Warlocks/Priests should avoid Mark of Frost death. Mages can help kite if needed post-teleport. Rogues vanish post-teleport if threat is high.",
    "Boss Ability: Manastorm drains health/mana. Teleport pulls all players in 30y to boss and resets aggro. Mark of Frost prevents rejoining if you die.",
  }},
  { boss="Lethon", raid="World Bosses", lines={
    "Tanks: Use 2 tanks and swap to avoid Noxious Breath stacks. Face boss away from raid. Rotate Lethon 180deg when feet glow 4x in a row to prevent Shadow Bolt Whirl from hitting raid. Failing rotation leads to deadly AoE damage.",
    "DPS: Stack on one side and move with the tank's rotation to avoid Shadow Bolt Whirl. At 75/50/25% HP, either run 100 yards away to skip Draw Spirit or target kill spawned spirits before they reach boss. Avoid green sleep clouds.",
    "Healers: Pre-position to avoid green sleep clouds. Be ready for large raid damage if Shadow Bolt Whirl hits. Stack with raid to stay in range and rotate with tank. Heal tanks through Noxious Breath dot and Shadow Bolt Whirl spikes.",
    "Class Specific: Rogues, Hunters, and ranged must single-target spirits-immune to AoE. Priests keep Fear Ward on tanks. Warlocks watch threat on boss healing phases. All avoid tail and frontal cleave while stacked to side.",
    "Boss Ability: Shadow Bolt Whirl deals high raid damage unless boss is rotated. Draw Spirit stuns and spawns healable adds at 75/50/25%. Noxious Breath forces tank swaps. Mark of Nature prevents re-entry if you die.",
  }},
  { boss="Emeriss", raid="World Bosses", lines={
    "Tanks: Use 2 tanks and swap on each Noxious Breath, which increases ability cooldowns and lowers threat gen. Face boss away from raid. Move away from mushrooms. Prepare CDs for 75/50/25% HP when Corruption of the Earth hits the whole raid.",
    "DPS: Avoid green clouds (sleep) and stay spread. Move 100 yards out at 75/50/25% HP to avoid Corruption damage. Help dispel Volatile Infection if you can. Focus survival over DPS if mushrooms or AoE get out of control.",
    "Healers: Prep CDs and AoE heals at 75/50/25% HP for Corruption of the Earth. Dispel Volatile Infection immediately. Avoid green clouds. Assign spot-heals for tanks and AoE for the group. Stay clear of mushroom spawns after deaths.",
    "Class Specific: Priests and Paladins should dispel Volatile Infection fast. Druids help cleanse and support with Rejuv/Hots during Corruption. Avoid green clouds to prevent sleep. No one should re-engage boss after death due to 15min sleep",
    "debuff.",
    "Boss Ability: At 75/50/25% HP Emeriss casts Corruption of the Earth, dealing 20% HP every 2s for 10s. Also uses Noxious Breath (threat loss), Volatile Infection (spread disease), Spore Clouds (on death), and Mark of Nature (15m sleep on",
    "rez).",
  }},
  { boss="Taerar", raid="World Bosses", lines={
    "Tanks: Use 3 tanks. Turn boss sideways to avoid breath/tail. Use Fear Ward/Tremor/Berserker Rage before Bellowing Roar. On each 25% HP, pick up 3 Shades fast, spread them to avoid cleave overlap. Rotate tanks for Noxious Breath stacks.",
    "DPS: Stop DPS at 76%, 51%, and 26% so Shade tanks recover from Breath debuff. Kill Shades one by one-focus those not tanked by debuffed tanks. Avoid green clouds and tail swipe.",
    "Healers: Pre-place Tremor Totems and Fear Wards before fears. Avoid sleep clouds. Be ready for spike damage after 75/50/25% Shade phases. Heal tanks hard during Noxious Breath stacks.",
    "Class Specific: Priests use Fear Ward on tanks before Bellowing Roar. Shamans drop Tremor Totems. Warriors use Berserker Rage. All classes must avoid green clouds and spread when Shades spawn.",
    "Boss Ability: At 75/50/25% Taerar vanishes and summons 3 Shades. Each uses Noxious Breath, requiring separate tanks. Bellowing Roar fears, and Mark of Nature prevents re-entry if you die.",
  }},
  { boss="Ysondre", raid="World Bosses", lines={
    "Tanks: Use 2 tanks to rotate for Noxious Breath. Face boss away from raid to avoid breath and tail. Swap before stacks get too high. Position sideways with raid spread loosely around to avoid chain lightning.",
    "DPS: Spread out to avoid Lightning Wave chaining. At 75/50/25% HP, AoE down Demented Druid Spirits quickly before they spread. Avoid green sleep clouds. Melee stay to boss sides, not front or back.",
    "Healers: Stay spread to avoid Lightning Wave. Watch for spike damage during add phases. Avoid green sleep clouds. Heal tank swaps early to keep up with threat. Be ready for bursts after breath stacks.",
    "Class Specific: Classes with AoE should prep for 75/50/25% add waves. Mages, Warlocks, Hunters ideal for Spirit cleanup. Everyone must avoid sleep clouds and keep spread to minimize Lightning Wave bounces.",
    "Boss Ability: At 75/50/25%, Ysondre spawns one Demented Spirit per player. Lightning Wave chains up to 10 players if too close. Noxious Breath reduces threat and increases ability cooldowns, requires tank swap.",
  }},
  { boss="Nerubian Overseer", raid="World Bosses", lines={
    "Tanks: MT tanks boss away from water to avoid reset. Periodically move out of poison cloud. Keep boss pathing in quarter-circle toward Tirion. DPS warriors can off-tank spawned adds.",
    "DPS: Melee stack behind boss, ranged at min range and stay still. Kill adds from web-sprayed players if they spawn. Use frost mages/paladins for web spray immune rotation.",
    "Healers: Heal through poison nova damage and add spikes. Stand in range group. Cleanse poison quickly with spells, Cleansing Totem, or poison removal items.",
    "Class Specific: Frost mages rotate Ice Block to immune web spray (2 uses each). Paladins use Divine Shield after mage rotation ends. Warriors can pick up spawned adds. Shamans drop Cleansing Totem.",
    "Boss Ability: Drops poison clouds (move boss), poison nova, web sprays farthest player every 24s (spawns 4 weak adds), water proximity resets fight.",
  }},
  { boss="Dark Reaver of Karazhan", raid="World Bosses", lines={
    "Tanks: MT keeps boss in place. Position so regular adds can be cleaved/AoE'd. Stay aware of class-specific adds spawning on random players-help control them until the correct class can kill.",
    "DPS: Bring 1+ DPS of each class to handle class-specific adds. Focus your own class add ASAP. Regular adds die to cleave/AoE near boss. Hunters split into 2+ groups to avoid deadzone.",
    "Healers: Heal through add damage spikes, especially on players targeted by class-specific adds. Stay mobile to avoid getting locked down by adds while keeping tank and raid stable.",
    "Class Specific: Only your class can damage its class-specific add. All classes may apply CC/debuffs to them. Hunters split to avoid deadzone.",
    "Boss Ability: Spawns regular adds (AoE down) and class-specific adds (only that class can damage). Class adds spawn on random players. More players = easier fight.",
  }},
  { boss="Ostarius", raid="World Bosses", lines={
    "Tanks: 1 MT on boss, face away. In P1, keep position while ranged handle portals. In P2, position boss so melee can stand in safe spots behind left/right sides at max range. Move boss if Rain of Fire/Blizzard lands in safe spot.",
    "DPS: P1-Ranged burn boss, close portals, kill adds fast. Melee only 1 grp on boss, rest on adds. P2-All melee on boss in safe spots. Avoid Rain of Fire, Blizzard, and traps. Help with adds if ranged overwhelmed.",
    "Healers: 6+ healers. In P1, heal portal clickers, tanks, and conflag targets. In P2, focus MT and melee in safe spots. Avoid Rain of Fire and Blizzard. Watch for portal/add damage spikes.",
    "Class Specific: Stun add beam channel. Avoid standing near conflagged players. Melee use safe spot max range behind boss in P2. Hunters/Warlocks help interrupt and control adds if overwhelmed.",
    "Boss Ability: Portals spawn adds with stun beams + conflag AoE. P2-Rain of Fire, Blizzard, frost AoE from statues/traps. Safe spots behind boss prevent cleave. Portals increase in number over time until closed.",
  }},
  { boss="Concavius", raid="World Bosses", lines={
    "Tanks: 1 Tank is enough. Face boss away from raid. Pull Concavius to a position so AoE cast can be LoS around pillar for the rest of raid. Does shadow damage so pre-pot Greater Shadow Protection Potion.",
    "DPS: Nuke, max range and LoS during AoE cast.",
    "Healers: Care and top up tank, LoS around pillar during AoE.",
    "Boss Abilities: Shadow damage and AoE that needs to be LoS around pillar - similar to SM Library (Arcanist Doan).",
  }},
  { boss="Moo", raid="World Bosses", lines={
    "Tactic: Tank and spank. Does an AOE during the kill and needs to be killed before it does a lethal ability. 5-10 people can easily take it.",
  }},
  { boss="Cla'ckora", raid="World Bosses", lines={
    "Tanks: 1 tank is enough. Face boss away from raid and pick up adds on spawn. Bring a second tank if struggling to control adds.",
    "DPS: Kill adds before boss. Move out of void zones. Frost Volley can be interrupted, including with stuns-do so if possible.",
    "Healers: Watch for spike damage from tank losing aggro, players standing in void zones, or Frost Volley not being interrupted.",
    "Class Specific: Any class with stun or interrupt should attempt to stop Frost Volley. Keep an eye out for add spawns.",
    "Boss Ability: Frost Volley deals AoE damage and can be interrupted. Void zones deal damage-move out. Boss hits hard. Adds spawn regularly.",
  }},

  -- == EMERALD SANCTUM ==
  { boss="Erennius", raid="Emerald Sanctum", lines={
    "Tanks: 2 tank. Position far from ranged/healers. Face away from raid to avoid frontal breath. Second tank keep high on threat, if first gets slept.",
    "DPS: Stay at range from boss. Avoid standing in front.",
    "Healers: Stay far; watch for AOE silence and sleep DoT (~500/tick). Heal tank through silence downtime.",
    "Class Specific: Poison Volley must be cleansed/cured (Paladins, Druids, Shamans).",
    "Boss Ability: AoE silence, sleep with DoT, Poison Volley (cure), frontal breath.",
  }},
  { boss="Solnius the Awakener", raid="Emerald Sanctum", lines={
    "Tanks: 2 tanks on Solnius, taunt at 91% as he is untauntable after 90%. Face so DPS can hit from the side. During add phase, tanks pick up all adds (prio large).",
    "DPS: Watch threat below 90% as boss is untauntable. In add phase, kill large adds before whelps (whelps keep spawning until large are dead).",
    "Healers: Care for spike damage during add phase or from debuffs. No decurse, dispel, or cleanse (!).",
    "Class Specific: No decursing, dispelling, or cleansing at any time. Very important!",
    "Boss Ability: Does debuffs of all types (do not dispell, decurse or cleanse). At 50% Solnius sleeps; adds spawn-kill large adds first, then whelps. Untauntable after 90%.",
  }},

  -- == LOWER KARAZHAN HALLS ==
  { boss="Master Blacksmith Rolfen", raid="Lower Karazhan Halls", lines={
    "Tanks, DPS and Healers: Tank and spank.",
  }},
  { boss="Brood Queen Araxxna", raid="Lower Karazhan Halls", lines={
    "Tanks: 1 tank. Face away.",
    "DPS: Focus and kill eggs as they spawn, stay max range.",
    "Healers: Keep poison cleansed/cured quickly.",
    "Class Specific: Druids, Paladins, Shamans cleanse/cure poison.",
    "Boss Ability: Frequent poison application.",
  }},
  { boss="Grizikil", raid="Lower Karazhan Halls", lines={
    "Tanks: 1 tank, move out of Rain of Fire or Blast Wave AoE.",
    "DPS: Focus boss, avoid ground/boss AoE.",
    "Healers: Avoid Rain of Fire, AoE, spread to cover all. Care for damage surge from abilties.",
    "Class Specific: Rogues / Warriors can interrupt the blast wave AoE.",
    "Boss Ability: Rain of Fire, blast wave AoE (interruptable).",
  }},
  { boss="Clawlord Howlfang", raid="Lower Karazhan Halls", lines={
    "Tanks: 2 tanks. MT engages and tanks Howlfang where he stands. OT hides behind corner until MT gets 15 stacks, then run in and taunts. Swap back and forth until stacks drop.",
    "DPS: Threat control. Melee can stay in; avoid getting hit. Ranged stay max range.",
    "Healers: Max range. Watch for heavy tank damage during swaps or enrage.",
    "Class Specific: Mages/Druids decurse tanks instantly.",
    "Boss Ability: Armor -5% & damage -5% reduction stack, 75% heal reduction curse, periodic enrage.",
  }},
  { boss="Lord Blackwald II", raid="Lower Karazhan Halls", lines={
    "Tanks: 1-2 tanks. MT on boss; OT can pick up add (if not MT can pick it up as well).",
    "DPS: Burn boss; kill add when it spawns.",
    "Healers: Watch tank during add phase, decurse and outheal life drain.",
    "Class Specific: Mages/Druids decurse -20% stats.",
    "Boss Ability: Curses, spawns add, life drain.",
  }},
  { boss="Moroes", raid="Lower Karazhan Halls", lines={
    "Tanks: 2 tanks, stay high on threat. Boss sleeps/kicks causing full threat loss-OT taunts immediately. Swap back and forth when abilties happen.",
    "DPS: Spread out to avoid AoE silence and overlap effects, during threat drop.",
    "Healers: Spread to avoid AoE silence during threat drop, maintain heals during swaps.",
    "Class Specific: Mages/Druids decurse 60% cast speed curse.",
    "Boss Ability: AoE silence, Sleep, Kick, 60% slower casting speed curse.",
  }},

  -- == UPPER KARAZHAN HALLS ==
  { boss="Keeper Gnarlmoon", raid="Upper Karazhan Halls", lines={
    "Tanks: Max 3 tanks. MT on boss and keep in position facing away. 1 Raven add tank right side (blue). If MT avoids Lunar Shift, no OT (left side) needed.",
    "DPS: Split DPS evenly. Casters/AoE classes to right (blue debuff), melee to left (red debuff). Nuke boss until 4 owls (all) or Ravens (blue right side) spawn. Bring all owls to ~10% and kill all owls at once. Move out of Lunar Shift",
    "AoE-only MT stays in.",
    "Healers: Evenly split between left and right. Be ready to heal through Lunar Shift and owl spawn damage. Focus on MT healing during shift and when threat resets. Watch for side-switching during debuff swap.",
    "Class Specific: Casters/range right side (Blue), melee left side (Red). Healers split evenly - needs to be equally many on both. During Lunar Shift, your debuff may switch-adjust sides immediately or risk being silenced or damaged heavily.",
    "Boss Ability: Lunar Shift deals AoE and may switch debuff color-move out unless you're MT. Owls must die simultaneously. Ravens spawn during fight-aggro reset also occurs, requiring OT to pick up boss fast and reposition.",
  }},
  { boss="Lay-Watcher Incantagos", raid="Upper Karazhan Halls", lines={
    "Tanks: Use 2-5 tanks. MT keeps boss near entrance, facing away. Reposition if AoE drops on MT. Other tanks pick up adds as they spawn. At start 1 tank/per or one by one using Rogue/Hunter kite-vanish/FD tactic from opposite side of the",
    "room).",
    "DPS: Priority: kill Incantagos Affinity (class-specific), then adds, then boss. Avoid Blizzard and AoEs. Stay max range and spread to minimize group damage. Melee must move fast-AoEs tick for 2.5k+ and is likely to be placed due to",
    "stacking.",
    "Healers: Watch for burst during AoEs-especially in melee. Prioritize MT and OT heals otherwise. Be ready for raid-wide spot healing if mechanics overlap.",
    "Class Specific: Kill Incantagos Affinity immediately when your spell school matches (e.g., Fire, Nature, Physical, etc.). It only takes damage from one school at a time. This is the fight's most critical mechanic.",
    "Boss Ability: Incantagos spawns damaging AoEs-Missles and Blizzard-often targeting melee. Adds will spawn frequently. Affinity adds must be killed fast, first and only take damage from one specific school per spawn.",
  }},
  { boss="Anomalus", raid="Upper Karazhan Halls", lines={
    "Tanks: Use 3-4 tanks. Current tank keeps boss near books corner opposite entrance, facing away. Reposition if pool drops on tank. Swap at ~10-12 stacks (Arcane Resistance [AR] leather) or ~20-25 (AR plate). The tank who swaps out always",
    "gets the bomb.",
    "DPS: Melee behind boss, ranged further back forming it's own stacked group. Do not overtake threat-2nd threat always gets bomb. Move from pools and manage positioning carefully to avoid sudden aggro shifts.",
    "Healers: Stand on stairs opposite entrance-central to all roles. Watch for increasing tank damage as stacks rise. Instantly heal and dispel Arcane Prison, cast randomly.",
    "Class Specific: 2nd on threat, gets bomb (including prior tanks after switch). DPS normally until 7s left on debuff, then run to a corner (entrance side) to explode. Use resulting debuff to soak pools. A Paladin soaks first pool. DIspell",
    "Arcane Prison.",
    "Boss Ability: All players must have 200+ Arcane Resistance (else wipe). Bomb targets 2nd threat (includes swapped tanks). Pools spawn on randomly-must be soaked by someone with debuff from explotion, else wiping raid.",
  }},
  { boss="Echo of Medivh", raid="Upper Karazhan Halls", lines={
    "Tanks: MT tanks boss facing away. 3 tanks pick up Infernal at every ~25%, move left, don't stack. Infernal reset threat, charge players-taunt back. Full Fire Resistance gear required for add tanking. If you get a Corruption of Medivh",
    "debuff, move away.",
    "DPS: Only DPS Medivh and Lingering Doom adds. Ignore Infernals. Assigned interrupts only-Shadebolt must be kicked. Overkicking/interruption causes instant casts. Move right if debuffed by Corruption of Medivh. Dodge Flamestrike. Range",
    "Spread behind boss.",
    "Healers: Assign 1 Priest + 1 Paladin to MT. Dispel Arcane Focus ASAP-causes +200% magic dmg. Shadebolt and Flamestrike deal heavy magic burst. Heal through Corruption of Medivh-never dispel it.",
    "Class Specific: Assign interrupters-Shadebolt is priority. Rogue/Warlock CoT/mind-numbing to increase cast. Priests/Paladins dispel MT's Arcane Focus. Move right if debuffed with Corruption of Medivh and use Restorative Pot at 4 stacks of",
    "Doom of Medivh!",
    "Boss Ability: Shadebolt = lethal, must be kicked. Overkicking = instant casts. Flamestrike targets group-move. Frost Nova roots melee. Corruption of Medivh is fatal if dispelled- Restorative Pot at 4 stacks Doom of Medivh.",
  }},
  { boss="King (Chess)", raid="Upper Karazhan Halls", lines={
    "Tanks: 4-5 tanks. 1 tank picks up Rook (far left), 1 on Bishop (far right), 1 on Knight (close right), and 1-2 tanks also pick up Broken Rook, Decaying Bishop, Mechanical Knight and Pawns. Drag pawns to bosses for cleave. Swap",
    "Knight/Bishop tank at end.",
    "DPS: Kill order: Rook -> Bishop -> Knight -> King. Swap to Pawns as they spawn and cleave them on bosses. LOS King's Holy Nova behind pillars after each boss dies or you will wipe. /bow on Queen's Dark Subservience if you get debuff. Avoid",
    "void zones.",
    "Healers: LOS King's Holy Nova behind pillars when any boss dies. Dispel silence from Bishop. Watch tank on Knight for armor debuff spikes. Prepare for AoE damage from Queen and Bishop. Keep range if not needed in melee.",
    "Class Specific: Mages/Druids decurse King's curse. All players must /bow in melee on Queen's Subservience or die. Stand behind Knight. LOS Holy Nova (King) when a boss dies. Interrupt/silence as needed. Dispel Bishop silence.",
    "Boss Ability: King- Holy Nova on each death, void zones, deadly curse. Queen- AoE Shadowbolts, Dark Subservience. Bishop- ST/cleave shadowbolt, silence. Knight- Frontal cleave, armor debuff. Pawns- constant spawn, cleave on boss.",
  }},
  { boss="Sanv Tas'dal", raid="Upper Karazhan Halls", lines={
    "Tanks: 3-4 tanks. MT holds boss at top of stairs facing away from raid. OT tanks adds from left/right portals when spawned, optional tank for mid portal at melee. During add phase boss untanked; all tanks help kill/tank adds during this",
    "phase, prio large.",
    "DPS: No dispelling to see shades. If you see shades, kill them. All range stand lower level center and DPS prio adds from portals as they spawn, big first. Melee behind boss, but during add phase all on adds at lower center. Move when boss",
    "does AoE melee.",
    "Healers: Stand center lower ground (with range DPS). Heal MT at stairs and OTs at portals. Watch for heavy AoE melee dmg or from add. Do not dispel magic debuff called phase shifted (it reveals shades).",
    "Class Specific: 2 Hunters rotate Tranq Shot on boss when needed. No one dispel Phase Shifted to keep shades visible. Melee can cleave mid-portal adds at boss.",
    "Boss Ability: AoE melee dmg-melee move out. Spawns shades only visible with debuff. Add waves from 3 portals, large adds most dangerous. During add phase boss inactive.",
  }},
  { boss="Kruul", raid="Upper Karazhan Halls", lines={
    "Tanks: 4-6 tanks. 1-2 front(facing boss at start), 1-2 back(behind boss at start), 1 infernal tank(full FR), 1 add helper if needed. Taunt swap between front/back at 6 stacks (no more). Infernal tank left, DPS right. Boss ignore armor; so",
    "stack HP/threat.",
    "DPS: Ranged on boss only. Melee in front/back groups to soak cleave (~8+tanks in each group). Melee have good health. At 30% after knockback all melee chain LIP shouts/taunts, then die; ranged continues. Ignore infernals. Run out of raid",
    "if decurse.",
    "Healers: Heal tanks/front/back groups. At 30% phase, let melee die after LIP taunt, focus ranged + tanks. 3 assigned decurser that removes decruse only after target moves from raid (left, right, middle).",
    "Class Specific: Assign 3 decurser for Kruul's curse. Melee tanks use LIP in 30% phase after knockback. Infernal tank uses full FR. Fury prot viable-boss ignores armor.",
    "Boss Ability: Cleave on front/back groups, stacking debuff (swap at 6). Summons infernals. At 30% gains 4x dmg. Casts decursable curse-must be decursed outside raid (assign 3 decursers - have player move out when getting decursed).",
  }},
  { boss="Rupturan the Broken", raid="Upper Karazhan Halls", lines={
    "Tanks: 5 heavy + 2-3 OT. During P1-2 tanks on boss, 1 per add in corners. Always have a tank 2nd boss threat and 15y away to soak (run in and taunt swap to ensure). During P2-2 tanks per fragment (1+2 threat). 1-2 on Tanks Exiles.",
    "DPS: During P1 kill adds first. Avoid add death explosions (think Garr adds). Dont overtake 1-2 tank threat. During P2 nuke heart/crystal before full mana+small adds, then fragments to same % - kill at same time. Move away from Flamestrike",
    "when announced.",
    "Healers: Stack center P1-P2 with Range. Watch tank burst + add explosions + Ouro tail damage + Flamestrike. Dispel tank debuffs instantly in P2. Keep OT/soak tanks alive. Heal during kiting trails.",
    "Class Specific: Moonkin/Warlock to initally get 2nd of threat, away from raid and soak before first adds are dead. Threat control-keep assigned tanks 1+2 on boss/frags. Dispel tanks fast. Avoid trail on ground. Hunters - Vipersting crystal.",
    "Boss Ability: Adds explode on death, soak mechanic for 2nd threat tank, trail to kite, crystal/heart to mana drain, fragments require dual-threat tanks, Exile spawns. Also Flamestrikes zone to move out from (move during cast to avoid all",
    "damage).",
  }},
  { boss="Mephistroth", raid="Upper Karazhan Halls", lines={
    "Tanks: 2-3 tanks. MT on boss & doomguard when boss teleports. OT on other doomguard + adds. 3rd or just DPS Paladin helps pick Imps. Drag Nightmare Crawlers & Doomguards away from ranged/healers as they soak mana/AOE. MT usually",
    "stationary-face boss away.",
    "DPS: Prio shards > adds > boss. Kill nightmare crawlers fast, drag from ranged. During shard phase, assigned 4-5 kill each Hellfury Shard in time limit. They spawn in the outter circle, with equal distance. Think of it like a clock.",
    "Healers: Stack with ranged. Heal shard teams. Watch for fear + burst on tank swap. Assign 2-3 dispellers, to cover shard groups on far side during this ability. Dispel immediately.",
    "Class Specific: No movement during Shackles-any movement wipes raid. Assigned groups kill Hellfury Shards fast. Drag nightmare crawlers out. Assign a few dispellers to also spread out during shards.",
    "Boss Ability: Shackles-no one moves or wipe. Hellfury Shards-kill fast. Spawns nightmare crawlers (mana drain) + doomguards. Fears raid. Dispel prio - not dispelling will cause a kills from center.",
  }},

  -- == ONYXIA'S LAIR ==
  { boss="Broodcommander Axelus", raid="Onyxia's Lair", lines={
    "Tanks: MT keeps Axelus to the side (frontal push). Off tank/DPS tank big adds outside raid due to explosion.",
    "DPS: Break Chains by crossing boss line (or split left/right around boss). Swap hard to big adds; 2 alive is dangerous raid AoE.",
    "Healers: Expect burst on tank and add explosions. Keep tanks stable during add pickups and chain movement.",
    "Class Specific: Fast movers break chain lines quickly on one side each of boss. Assign stuns on big adds while they are moved out.",
    "Boss Ability: Chain cast (Searing Pain-like icon) links 2 players; line through boss breaks it. At 5% he resets to 100% (half Onyxia HP), then repeat cleanly.",
  }},
  { boss="Onyxia", raid="Onyxia's Lair", lines={
    "Tanks: Tank near back wall during inital phase (P1) and when Onyxia lands again (P3). Turn away from raid (side of boss towards raid). During airphase (P2), grab all adds.",
    "DPS: Never stand behind or infront of Onyxia. Focus adds when up. CARE THREAT! Stable DPS and let tank get agro when Onyxia lands (P3).",
    "Healers: Focus on tank, and during airphase (P2) and landing phase (P3) on damage on raid.",
    "Class Specific: Fear Ward (Priests) and Tremor Totem (Shaman) prio for MT during landing phase (P3).",
    "Boss Ability: During airphase (P2) Onyxia will occasionally Fire Breath, with will likely kill anyone in it's path. To avoid it ALL must NEVER stand beneath or diagonally (in straight line) from where Onyxia currently is facing. Note the",
    "boss will move.",
  }},

  -- == TIMBERMAW HOLD ==
  { boss="Karrsh the Sentinel", raid="Timbermaw Hold", lines={
    "Tanks: Face Karrsh away (cleave). 2nd tank ready for aggro reset. In P1, at ~70% Slam cast, MT can LoS behind pillar to skip reset. Pick adds instantly.",
    "DPS: Kill spawned adds instantly. Stay out of frontal. During P1 Slam timing, help execute LoS skip cleanly.",
    "Healers: Never dispel Seed in raid (explodes). Track spikes after resets and during add pressure.",
    "Class Specific: Assigned dispeller handles Seed only outside stack/raid if needed.",
    "Boss Ability: Seed explodes on dispel, cleave, and threat resets. P1 Slam reset can be LoS-skipped; later phases are direct resets.",
  }},
  { boss="Rotgrowl", raid="Timbermaw Hold", lines={
    "Tanks: Keep Rotgrowl faced away and stable while Kodiak is controlled/killed.",
    "DPS: Kill Kodiak (bear add) fast; boss becomes vulnerable after bear dies. Move out of arrow AoE.",
    "Healers: Prepare for damage on fixate target, Flaming Bolt and fear moments; keep movement-safe healing.",
    "Class Specific: Hunters can quickly fire Tranquilizing Shot after Kodiak (bear) resurrection. Kite if chased by Kodiak.",
    "Boss Ability: Kodiak fixates/chases (move), fear, arrow AoE requires to move. Most important -> When Flaming Bolt (Fire-Soaked Arrow) is cast, all (except tanks) should stack on that random player.",
  }},
  { boss="Loktanag the Vile", raid="Timbermaw Hold", lines={
    "Tanks: MT moves boss with raid in a hexagon path while keeping boss out of cloud drops.",
    "DPS: Everyone stacks so clouds drop in one controlled spot; no player outside stack. Kill spawned adds fast while moving with tank.",
    "Healers: Heavy dispel/decurse/cure priority while raid stays stacked and moving.",
    "Class Specific: Shamans keep Poison Cleansing Totem coverage.",
    "Boss Ability: Poison clouds target random players; controlled stacking keeps room usable. Add spawns overlap cloud movement.",
  }},
  { boss="Trioch the Devourer", raid="Timbermaw Hold", lines={
    "Tanks: Keep Trioch faced away; tank stacks are expected while holding frontal (fire/poison/frost).",
    "DPS: Never stand in front and avoid frontal stack debuffs. Move out of poison clouds and kill adds.",
    "Healers: Each stack increases tank vulnerability; prepare escalating tank damage and boss abilities.",
    "Class Specific: Cleanse support where class toolkit allows.",
    "Boss Ability: Three heads (frost/fire/poison) apply stacking frontals. All stack when fire at melee, spread during poison and into melee/range during frost.",
  }},
  { boss="Selenaxx Foulheart", raid="Timbermaw Hold", lines={
    "Tanks: Gain threat by standing in line between boss and crystal. Swap tanks at 85/65/45/25% for heavy post-threshold mechanics.",
    "DPS: Kill adds on spawn and interrupt immediately.",
    "Healers: Track shadow-vulnerability tank debuff and swap spikes.",
    "Class Specific: Assign one player to stay furthest for Rain of Destruction bait.",
    "Boss Ability: If boss is closest to crystal he gains stacks (12 = wipe). Rain of Destruction hits the furthest target; move out of fire.",
  }},
  { boss="Ormanos the Cracked", raid="Timbermaw Hold", lines={
    "Tanks: Keep boss away from clones. Hold boss steady while Tremor of Ormanos spawns are handled.",
    "DPS: Kill Tremor clones fast or they spawn extra adds and AoE pressure. Avoid when their cone-based AOE (you get debuff if you are in it).",
    "Healers: Be ready for heavy spike healing during clone AoE around melee.",
    "Class Specific: Curse of Tongues on boss to slow charge casts.",
    "Boss Ability: During charge, EVERYONE stacks on the assigned marker to split damage correctly. Boss gains rotating spell-school vulnerability windows.",
  }},
  { boss="Chieftain Partath", raid="Timbermaw Hold", lines={
    "Tanks: Keep boss and illuminators on separate sides. During boss immunity, move illuminators above boss.",
    "DPS: Kill spawned adds (not illuminators). Interrupt illuminator Regrowth; otherwise nuke boss.",
    "Healers: Prepare burst healing during movement windows and Leeching Strike cast.",
    "Class Specific: Assign strict interrupt rotation on illuminators.",
    "Boss Ability: Leeching Strike turns boss toward raid path and starts casting; melee must sidestep then return.",
  }},
  { boss="Archdruid Kronn", raid="Timbermaw Hold", lines={
    "Tanks: Outside group handles hostile boss. Two groups swap every ~30s by Phasebound timer.",
    "DPS: Outside: kill boss + Xavian Image only. Inside: kill image/adds before they reach portal.",
    "Healers: Inside heal friendly boss to ~90%, then sync 100% inside with 0% outside within ~10s.",
    "Class Specific: Druids are preferred inside healers (no inside damage taken).",
    "Boss Ability: Dual-world sync fight: dispel/decurse/cure everything, rotate in/out on debuff timing, and finish both realms simultaneously.",
  }},
  { boss="Ursol", raid="Timbermaw Hold", lines={
    "Tanks: Armor is ignored, so prioritize high-HP setup and stable positioning.",
    "DPS: If chased by fiends, kite. Assign fiend-killers while rest stay boss. At 30% all kill adds, then boss (optional LIP nuking adds after banish phase).",
    "Healers: If chased by fiends, kite and call path. Cover fear phases, add pressure, and post-30% add burst.",
    "Class Specific: Decurse Mind-Shattering Rumble.",
    "Boss Ability: Fear and root zones occur. Fiends spawn; if fixated, run. Immune/banish phase transitions into add cleanup, then boss kill window.",
  }},
  { boss="Peroth'arn", raid="Timbermaw Hold", lines={
    "No tactic added yet.",
  }},

}

-- ── Index de recherche ──────────────────────────────────────
local RT_TACTICS_INDEX = nil

local function Tactics_BuildIndex()
    if RT_TACTICS_INDEX then return end
    RT_TACTICS_INDEX = {}
    for i = 1, table.getn(RT_TACTICS_DB) do
        local t = RT_TACTICS_DB[i]
        local key = string.lower(t.boss)
        RT_TACTICS_INDEX[key] = i
        -- Alias courts
        local short = string.lower(string.gsub(t.boss, " ", ""))
        RT_TACTICS_INDEX[short] = i
    end
end

-- ── Recherche ──────────────────────────────────────────────
function RT_Tactics.Find(query)
    Tactics_BuildIndex()
    if not query or query == "" then return nil end
    local q = string.lower(RT_BTrim and RT_BTrim(query) or query)
    -- Match exact
    if RT_TACTICS_INDEX[q] then
        return RT_TACTICS_DB[RT_TACTICS_INDEX[q]]
    end
    -- Match partiel
    for i = 1, table.getn(RT_TACTICS_DB) do
        if string.find(string.lower(RT_TACTICS_DB[i].boss), q, 1, true)
        or string.find(string.lower(RT_TACTICS_DB[i].raid or ""), q, 1, true) then
            return RT_TACTICS_DB[i]
        end
    end
    -- Customs
    if RT_DB and RT_DB.customTactics then
        for j = 1, table.getn(RT_DB.customTactics) do
            local ct = RT_DB.customTactics[j]
            if string.find(string.lower(ct.boss or ""), q, 1, true) then
                return ct
            end
        end
    end
    return nil
end

function RT_Tactics.FindAll(query)
    local results = {}
    local q = query and string.lower(RT_BTrim and RT_BTrim(query) or query) or ""
    for i = 1, table.getn(RT_TACTICS_DB) do
        local t = RT_TACTICS_DB[i]
        if q == "" or string.find(string.lower(t.boss), q, 1, true)
                   or string.find(string.lower(t.raid or ""), q, 1, true) then
            table.insert(results, t)
        end
    end
    if RT_DB and RT_DB.customTactics then
        for j = 1, table.getn(RT_DB.customTactics) do
            local ct = RT_DB.customTactics[j]
            if q == "" or string.find(string.lower(ct.boss or ""), q, 1, true) then
                table.insert(results, ct)
            end
        end
    end
    return results
end

-- ── Poster une tactique ────────────────────────────────────
function RT_Tactics.Post(bossName, channel)
    local tactic = RT_Tactics.Find(bossName)
    if not tactic then
        RT_Print("|cffFF4444[Tactics] No tactic found for: " .. (bossName or "?") .. "|r")
        return false
    end
    channel = channel or "RAID"
    local nRaid = GetNumRaidMembers and GetNumRaidMembers() or 0
    local nParty = GetNumPartyMembers and GetNumPartyMembers() or 0
    if nRaid == 0 and nParty == 0 then channel = "SAY" end
    if nRaid == 0 and nParty > 0 then channel = "PARTY" end
    local lang = GetDefaultLanguage and GetDefaultLanguage("player") or nil
    for i = 1, table.getn(tactic.lines) do
        pcall(SendChatMessage, tactic.lines[i], channel, lang, nil)
    end
    RT_Print("|cff88FF88[Tactics] Tactic for " .. tactic.boss .. " posted to " .. channel .. ".|r")
    return true
end

-- ── Ajouter une tactique custom ────────────────────────────
function RT_Tactics.AddCustom(bossName, text)
    if not bossName or bossName == "" or not text or text == "" then return false end
    RT_DB = RT_DB or {}
    RT_DB.customTactics = RT_DB.customTactics or {}
    -- Remplace si existant
    for i = 1, table.getn(RT_DB.customTactics) do
        if string.lower(RT_DB.customTactics[i].boss) == string.lower(bossName) then
            RT_DB.customTactics[i] = { boss=bossName, raid="Custom", lines={text}, custom=true }
            RT_Print("|cff88FF88[Tactics] Tactic for " .. bossName .. " updated.|r")
            RT_TACTICS_INDEX = nil
            return true
        end
    end
    table.insert(RT_DB.customTactics, { boss=bossName, raid="Custom", lines={text}, custom=true })
    RT_Print("|cff88FF88[Tactics] Tactic for " .. bossName .. " added.|r")
    RT_TACTICS_INDEX = nil
    return true
end

function RT_Tactics.DeleteCustom(bossName)
    if not RT_DB or not RT_DB.customTactics then return end
    for i = table.getn(RT_DB.customTactics), 1, -1 do
        if string.lower(RT_DB.customTactics[i].boss) == string.lower(bossName or "") then
            table.remove(RT_DB.customTactics, i)
            RT_Print("|cffFFAA00[Tactics] Tactic for " .. bossName .. " removed.|r")
            RT_TACTICS_INDEX = nil
            return
        end
    end
end

-- ── UI Panneau ─────────────────────────────────────────────
local TACT_ROWS     = {}
local TACT_SELECTED = nil

function RT_BuildUITactics(parent)
    local p = parent
    RT_DB = RT_DB or {}
    RT_DB.customTactics = RT_DB.customTactics or {}

    local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", p, "TOPLEFT", 6, -4)
    title:SetText("|cffFFD700Tactics|r  —  " .. table.getn(RT_TACTICS_DB) .. " bosses + custom tactics")
    title:SetTextColor(1.0, 0.85, 0.0)

    -- Recherche
    local searchLabel = p:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    searchLabel:SetPoint("TOPLEFT", p, "TOPLEFT", 6, -24)
    searchLabel:SetText("Search:")

    local searchBox = CreateFrame("EditBox", "RT_TacticSearchBox", p, "InputBoxTemplate")
    searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 6, 0)
    searchBox:SetWidth(200)
    searchBox:SetHeight(22)
    searchBox:SetAutoFocus(false)
    searchBox:SetText("")

    -- Bouton filtrer par raid actif
    local bossBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    bossBtn:SetPoint("LEFT", searchBox, "RIGHT", 6, 0)
    bossBtn:SetWidth(110)
    bossBtn:SetHeight(22)
    bossBtn:SetText("Current boss")
    bossBtn:SetScript("OnClick", function()
        local bossName = (RT_BOSS_STATE and RT_BOSS_STATE.bossName) or ""
        if bossName ~= "" then
            searchBox:SetText(bossName)
            RT_TacticsRefreshList(bossName)
        else
            RT_Print("|cffFFAA00[Tactics] No boss selected in the Boss tab.|r")
        end
    end)

    -- Zone gauche : liste des boss
    local listScroll = CreateFrame("ScrollFrame", "RT_TacticListScroll", p, "UIPanelScrollFrameTemplate")
    listScroll:SetPoint("TOPLEFT", p, "TOPLEFT", 6, -48)
    listScroll:SetWidth(220)
    listScroll:SetHeight(330)

    local listContent = CreateFrame("Frame", "RT_TacticListContent", listScroll)
    listContent:SetWidth(200)
    listContent:SetHeight(3000)
    listScroll:SetScrollChild(listContent)

    for i = 1, 60 do
        local row = CreateFrame("Button", "RT_TacticRow" .. i, listContent)
        row:SetWidth(198)
        row:SetHeight(16)
        row:SetPoint("TOPLEFT", listContent, "TOPLEFT", 2, -(i-1)*17)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(row)
        bg:SetTexture(0.0, 0.0, 0.0, 0.0)
        row._bg = bg

        local txt = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        txt:SetPoint("LEFT", row, "LEFT", 4, 0)
        txt:SetWidth(190)
        txt:SetJustifyH("LEFT")
        row._txt = txt
        row:Hide()
        TACT_ROWS[i] = row
    end

    -- Zone droite : contenu de la tactique sélectionnée
    local previewBg = p:CreateTexture(nil, "BACKGROUND")
    previewBg:SetPoint("TOPLEFT", p, "TOPLEFT", 234, -48)
    previewBg:SetWidth(488)
    previewBg:SetHeight(280)
    previewBg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    previewBg:SetVertexColor(0.02, 0.02, 0.04, 1.0)

    local previewScroll = CreateFrame("ScrollFrame", "RT_TacticPreviewScroll", p, "UIPanelScrollFrameTemplate")
    previewScroll:SetPoint("TOPLEFT", p, "TOPLEFT", 234, -48)
    previewScroll:SetWidth(486)
    previewScroll:SetHeight(280)

    local previewContent = CreateFrame("Frame", nil, previewScroll)
    previewContent:SetWidth(460)
    previewContent:SetHeight(2000)
    previewScroll:SetScrollChild(previewContent)

    local previewText = previewContent:CreateFontString("RT_TacticPreviewText", "OVERLAY", "GameFontNormalSmall")
    previewText:SetPoint("TOPLEFT", previewContent, "TOPLEFT", 4, -4)
    previewText:SetWidth(450)
    previewText:SetJustifyH("LEFT")
    previewText:SetText("|cff888888Select a boss on the left|r")

    -- Boutons d'action sous la preview
    local postRaidBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    postRaidBtn:SetPoint("TOPLEFT", p, "TOPLEFT", 234, -336)
    postRaidBtn:SetWidth(100)
    postRaidBtn:SetHeight(24)
    postRaidBtn:SetText("|cff88FF88Post /Raid|r")
    local prTex = postRaidBtn:GetNormalTexture()
    if prTex then prTex:SetVertexColor(0.1, 0.6, 0.2) end
    postRaidBtn:SetScript("OnClick", function()
        if TACT_SELECTED then RT_Tactics.Post(TACT_SELECTED, "RAID") end
    end)

    local postPartyBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    postPartyBtn:SetPoint("LEFT", postRaidBtn, "RIGHT", 4, 0)
    postPartyBtn:SetWidth(100)
    postPartyBtn:SetHeight(24)
    postPartyBtn:SetText("Post /Party")
    postPartyBtn:SetScript("OnClick", function()
        if TACT_SELECTED then RT_Tactics.Post(TACT_SELECTED, "PARTY") end
    end)

    local postSayBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    postSayBtn:SetPoint("LEFT", postPartyBtn, "RIGHT", 4, 0)
    postSayBtn:SetWidth(80)
    postSayBtn:SetHeight(24)
    postSayBtn:SetText("Post /Say")
    postSayBtn:SetScript("OnClick", function()
        if TACT_SELECTED then RT_Tactics.Post(TACT_SELECTED, "SAY") end
    end)

    -- Zone custom
    local customSep = p:CreateTexture(nil, "ARTWORK")
    customSep:SetPoint("TOPLEFT", p, "TOPLEFT", 6, -386)
    customSep:SetWidth(718)
    customSep:SetHeight(1)
    customSep:SetTexture(0.5, 0.5, 0.2, 0.5)

    local customTitle = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    customTitle:SetPoint("TOPLEFT", p, "TOPLEFT", 6, -394)
    customTitle:SetText("|cffFFD700Custom Tactic|r")

    local customNameLabel = p:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    customNameLabel:SetPoint("TOPLEFT", p, "TOPLEFT", 6, -410)
    customNameLabel:SetText("Boss:")

    local customNameEdit = CreateFrame("EditBox", "RT_TacticCustomName", p, "InputBoxTemplate")
    customNameEdit:SetPoint("LEFT", customNameLabel, "RIGHT", 6, 0)
    customNameEdit:SetWidth(160)
    customNameEdit:SetHeight(20)
    customNameEdit:SetAutoFocus(false)
    customNameEdit:SetText("")
    customNameEdit:SetScript("OnEscapePressed", function() customNameEdit:ClearFocus() end)

    local customTextEdit = CreateFrame("EditBox", "RT_TacticCustomText", p, "InputBoxTemplate")
    customTextEdit:SetPoint("LEFT", customNameEdit, "RIGHT", 8, 0)
    customTextEdit:SetWidth(400)
    customTextEdit:SetHeight(20)
    customTextEdit:SetAutoFocus(false)
    customTextEdit:SetText("")
    customTextEdit:SetScript("OnEscapePressed", function() customTextEdit:ClearFocus() end)

    local customSaveBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    customSaveBtn:SetPoint("TOPLEFT", customNameLabel, "BOTTOMLEFT", 0, -6)
    customSaveBtn:SetWidth(90)
    customSaveBtn:SetHeight(22)
    customSaveBtn:SetText("Save")
    customSaveBtn:SetScript("OnClick", function()
        local boss = RT_BTrim and RT_BTrim(customNameEdit:GetText()) or customNameEdit:GetText()
        local text = customTextEdit:GetText()
        if boss ~= "" and text ~= "" then
            RT_Tactics.AddCustom(boss, text)
            RT_TacticsRefreshList("")
            customNameEdit:SetText("")
            customTextEdit:SetText("")
        end
    end)

    local customDelBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    customDelBtn:SetPoint("LEFT", customSaveBtn, "RIGHT", 4, 0)
    customDelBtn:SetWidth(80)
    customDelBtn:SetHeight(22)
    customDelBtn:SetText("Delete")
    customDelBtn:SetScript("OnClick", function()
        if TACT_SELECTED then
            RT_Tactics.DeleteCustom(TACT_SELECTED)
            TACT_SELECTED = nil
            if RT_TacticPreviewText then
                RT_TacticPreviewText:SetText("|cff888888Select a boss|r")
            end
            RT_TacticsRefreshList("")
        end
    end)

    -- Refresh liste initial
    local function onSearch()
        local q = searchBox:GetText()
        RT_TacticsRefreshList(q)
    end
    searchBox:SetScript("OnTextChanged", onSearch)
    searchBox:SetScript("OnEnterPressed", function()
        onSearch()
        searchBox:ClearFocus()
    end)

    RT_TacticsRefreshList("")
end

-- ── Refresh la liste ────────────────────────────────────────
function RT_TacticsRefreshList(query)
    local results = RT_Tactics.FindAll(query or "")
    local raidColors = {
        ["Molten Core"]           = "FF8800",
        ["Blackwing Lair"]        = "CC4444",
        ["Zul'Gurub"]             = "44FFAA",
        ["Ruins of Ahn'Qiraj"]   = "FFDD44",
        ["Temple of Ahn'Qiraj"]  = "FF6600",
        ["Naxxramas"]             = "AA66FF",
        ["Onyxia's Lair"]        = "66CCFF",
        ["World Boss"]            = "FF4488",
        ["Custom"]                = "FFFFFF",
    }
    local maxR = math.min(table.getn(results), 60)
    for i = 1, 60 do
        local row = getglobal("RT_TacticRow" .. i)
        if not row then break end
        if i <= maxR then
            local t = results[i]
            local color = raidColors[t.raid] or "CCCCCC"
            row._txt:SetText("|cff" .. color .. t.boss .. "|r")
            local boss = t.boss
            row:SetScript("OnClick", function()
                TACT_SELECTED = boss
                -- Highlight
                for j = 1, 60 do
                    local r2 = getglobal("RT_TacticRow" .. j)
                    if r2 and r2._bg then r2._bg:SetTexture(0,0,0,0) end
                end
                if row._bg then row._bg:SetTexture(0.2, 0.1, 0.5, 0.5) end
                -- Affiche dans la preview
                local tactic = RT_Tactics.Find(boss)
                local pt = getglobal("RT_TacticPreviewText")
                if pt and tactic then
                    local txt = "|cffFFD700" .. tactic.boss .. "|r  |cff888888(" .. (tactic.raid or "") .. ")|r\n\n"
                    for li = 1, table.getn(tactic.lines) do
                        txt = txt .. tactic.lines[li] .. "\n"
                    end
                    pt:SetText(txt)
                end
            end)
            row:Show()
        else
            row:Hide()
        end
    end
end

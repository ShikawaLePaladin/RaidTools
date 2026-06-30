-- ============================================================
-- RT v2 — Tactics.lua
-- Base de données des tactiques vanilla (MC/BWL/ZG/AQ/Naxx)
-- Inspiré de Tactica (Player-Doite/tactica)
-- Recherche, affichage, annonce raid, tactiques customs
-- Compatible WoW 1.12 / TurtleWoW
-- ============================================================

RT_Tactics = RT_Tactics or {}

-- ── Base de données tactiques ──────────────────────────────
-- Format : { boss=string, raid=string, lines={string,...} }
-- Garder <255 chars/ligne pour SendChatMessage

RT_TACTICS_DB = {

  -- ══ ONYXIA ════════════════════════════════════════════════
  { boss="Onyxia", raid="Onyxia's Lair", lines={
    "[Phase 1] Tanks sur Onyxia face au mur nord. Melee DPS derrière. Healers hors du cône de feu.",
    "[Phase 2] Onyxia s'envole. Spread toute la salle. Tuez les whelps. Pas de sorts de zone.",
    "[Phase 3] Onyxia retombe. Restack tanks. DPS full. Ignorer les whelps restants.",
    "[NOTE] Ne jamais se mettre dans la hitbox ou devant la tête. Warlock : Drain Life OK.",
  }},

  -- ══ MOLTEN CORE ══════════════════════════════════════════
  { boss="Lucifron", raid="Molten Core", lines={
    "[Lucifron] 2 Flamewakers + Lucifron. CC les adds en priorité (Poly/Peur).",
    "Lucifron cast Impending Doom (debuff 8s) — Dispel immédiatement (Prêtres/Chamans).",
    "Lucifron cast Domination (MC) — Dispel. Tanks sur Lucifron en dernier.",
  }},
  { boss="Magmadar", raid="Molten Core", lines={
    "[Magmadar] Boss à tuer rapidement. Caste Panic (peur AoE) — Tremor Totem obligatoire.",
    "Magmadar caste Lava Bomb sur des joueurs aléatoires — Spread légèrement.",
    "Tanks : alterner Taunt si Frenzy actif. Pas de loot sauf si Tranq Shot (Hunter).",
    "[NOTE] Hunters : Tranquilizing Shot sur Frenzy immédiatement.",
  }},
  { boss="Gehennas", raid="Molten Core", lines={
    "[Gehennas] 2 Flamewakers + Gehennas. CC les adds.",
    "Gehennas caste Rain of Fire (AoE) — Bougez hors de la zone rouge.",
    "Gehennas caste Gehennas' Curse (réduit soins de 75%) — Dispel en priorité.",
  }},
  { boss="Garr", raid="Molten Core", lines={
    "[Garr] 8 Firesworn adds. Chaque tank prend 1-2 adds. DPS Garr seulement.",
    "Firesworn exploseront à la mort (Detonate). Spread les tanks adds.",
    "Garr caste Antimagic Pulse — sort zone qui remove buffs magiques.",
    "[NOTE] Pas de AoE. Tuer Garr en dernier ou les adds exploseront ensemble.",
  }},
  { boss="Baron Geddon", raid="Molten Core", lines={
    "[Baron Geddon] Tank seul, tous les healers et DPS en cercle autour.",
    "Living Bomb : si tu as le debuff, COURS LOIN DU GROUPE immédiatement!",
    "Inferno (AoE) = tous à distance max. Ignite Mana = Mana drain (healers cibles).",
  }},
  { boss="Shazzrah", raid="Molten Core", lines={
    "[Shazzrah] Blink aléatoire dans le groupe. Tank re-taunt après chaque blink.",
    "Shazzrah caste Arcane Explosion (AoE) — Spread légèrement.",
    "Dispel Magic sur Shazzrah retire ses buffs. Prêtres priorité.",
  }},
  { boss="Sulfuron Harbinger", raid="Molten Core", lines={
    "[Sulfuron] 4 Flamewaker Priests adds. PRIORITÉ : tuer/CC les adds Priests.",
    "Les adds healen Sulfuron — Interrupt les heals (Kick/Pummel/Earth Shock).",
    "Sulfuron caste Hand of Ragnaros (assomme) — tanks alternent Taunt.",
    "[NOTE] Pas de loot intéressant — rush les adds, puis Sulfuron.",
  }},
  { boss="Golemagg", raid="Molten Core", lines={
    "[Golemagg] 2 Core Rager adds. Tank principal : Golemagg. Tanks adds : Core Ragers.",
    "Core Ragers ne doivent PAS mourir — sinon Golemagg gagne des stacks de dégâts.",
    "Golemagg caste Pyroblast (single target) — Healers sur le tank principal.",
  }},
  { boss="Majordomo Executus", raid="Molten Core", lines={
    "[Majordomo] 8 adds : 4 Flamewaker Elite + 4 Flamewaker Healer.",
    "Priorité : CC les 4 Healers (Poly, Shackle), tuer les 4 Elites.",
    "Puis tuer les Healers un par un. Majordomo est invulnérable jusqu'à la fin.",
    "[NOTE] Shackle se resiste souvent — avoir 2+ Prêtres sur les Shackles.",
  }},
  { boss="Ragnaros", raid="Molten Core", lines={
    "[Phase 1] Tank Ragnaros face au mur. Healers + DPS derrière. Wrath of Ragnaros = tank KO.",
    "Sons of Flame : quand Ragnaros plonge (P2), tuez les adds AVANT qu'ils l'atteignent.",
    "[Phase 2] Ragnaros ressort renforcé. Même strat + Submerge toutes les 90s.",
    "[NOTE] Melee : attention Knockback aléatoire. Ranged : rester max range.",
  }},

  -- ══ BLACKWING LAIR ════════════════════════════════════════
  { boss="Razorgore", raid="Blackwing Lair", lines={
    "[Phase 1] 1 joueur contrôle Razorgore (Orb) pour détruire les oeufs. Reste défend.",
    "Tanks : récupérer tous les adds qui spawn aux portes. DPS : tuer les adds.",
    "[Phase 2] Quand tous les oeufs sont détruits — tank Razorgore et DPS full.",
    "[NOTE] L'Orb control est la clé. Si le controleur meurt = wipe.",
  }},
  { boss="Vaelastrasz", raid="Blackwing Lair", lines={
    "[Vaela] Burning Aura = vos soins alimentent Vaela aussi. Pas de Mana drain.",
    "Vaela cast Burning Adrenaline sur un joueur aléatoire = mort dans 20s.",
    "Le joueur BA doit caster tous ses sorts (Mage/Lock) ou courir loin (Healer).",
    "Tank : Vaela monte en dégâts avec le temps. Kill avant ~5 min.",
  }},
  { boss="Broodlord Lashlayer", raid="Blackwing Lair", lines={
    "[Broodlord] 8 Chromatic Whelps adds en premier. AoE + CC.",
    "Broodlord caste Blast Wave (AoE, knockback) — Melee derrière lui.",
    "Broodlord caste Mortal Strike — Healers spammer le tank.",
    "Broodlord caste Knock Away — Tank se repositionne rapidement.",
  }},
  { boss="Firemaw", raid="Blackwing Lair", lines={
    "[Firemaw] Tank contre le mur. Shadow Flame = cône arrière, NE PAS se mettre derrière.",
    "Wing Buffet (knockback) = tank revient. Flame Buffet stack = changer de tank.",
    "[NOTE] Fire Resist recommandé. Troisième dragon du trio.",
  }},
  { boss="Ebonroc", raid="Blackwing Lair", lines={
    "[Ebonroc] Shadow of Ebonroc : si cast sur le tank, re-taunt pour changer de tank.",
    "Shadow Flame cône arrière — rester sur les flancs.",
    "Wing Buffet knockback — même strat que Firemaw.",
  }},
  { boss="Flamegor", raid="Blackwing Lair", lines={
    "[Flamegor] Frenzy régulier — Tranq Shot obligatoire (Hunters).",
    "Shadow Flame cône arrière. Wing Buffet. Same strat trio.",
    "[NOTE] Plus simple que les deux autres. Rush DPS.",
  }},
  { boss="Chromaggus", raid="Blackwing Lair", lines={
    "[Chromaggus] 5 Brood Afflictions aléatoires parmi : Time Lapse, Ignite Flesh, Corrosive Acid, Feverish Catnap, Dire Charm.",
    "Dispel/Cure les afflictions selon le set du jour. Adaptez la résistance.",
    "Time Lapse = assomme un joueur. Feverish Catnap = endort. Dire Charm = MC.",
    "[NOTE] Potions de résistance très utiles. Fight long — pas de DPS rush.",
  }},
  { boss="Nefarian", raid="Blackwing Lair", lines={
    "[Phase 1] Tuer les 42 Drakonides adds avant que Nefarian arrive.",
    "[Phase 2] Nefarian atterrit. Tank sur le côté. DPS full. Class Call selon le jour.",
    "Class Calls : Warrior saignent, Rogue aveugles, Druid forme ours forcée, Priest aggro...",
    "[Phase 3] Nefarian à 20% = Bone Constructs spawn. Tank les adds. DPS Nefarian full.",
    "[NOTE] Rez possible en P3 (Paladins/Druides). Corruption les empoisonne.",
  }},

  -- ══ ZUL'GURUB ═════════════════════════════════════════════
  { boss="High Priest Venoxis", raid="Zul'Gurub", lines={
    "[Venoxis] Phase serpent à 50% HP. Poison Nova = spread toute la salle.",
    "Phase humaine : Interrupt Holy Fire. Tuer rapidement avant snake phase.",
  }},
  { boss="High Priestess Jeklik", raid="Zul'Gurub", lines={
    "[Jeklik] Phase 1 (bat) : Sonic Burst silence = Casters arrêtent de caster.",
    "Phase 2 (troll) : Heals en masse, Interrupt en priorité. Bats additionnels.",
    "Shadow Word: Pain sur les bats pour les tuer vite.",
  }},
  { boss="High Priest Mar'li", raid="Zul'Gurub", lines={
    "[Mar'li] Teche les joueurs aléatoires (spider add). Tanks prennent les adds.",
    "Mar'li se transforme en araignée à 50% HP. AoE les araignées.",
    "Drain Life Web = interrupt ou dispel.",
  }},
  { boss="Mandokir", raid="Zul'Gurub", lines={
    "[Mandokir] NE REGARDEZ PAS Mandokir (turn around). Gaze = mort.",
    "Mandokir charge un joueur aléatoire — Tanks re-taunt.",
    "Ohgan (raptor) doit mourir en dernier. Mandokir rez Ohgan.",
    "[NOTE] Levelup = Mandokir heal + dégâts augmentent. Kill vite.",
  }},
  { boss="High Priest Thekal", raid="Zul'Gurub", lines={
    "[Thekal] 3 mobs ensemble : Thekal + Zath (panther) + Lor'Khan. Tuer simultanément!",
    "Si un seul meurt, les deux autres se regen à 100% HP.",
    "Phase tigre à 0% : AoE peur. Tanks re-positionnent. DPS rapide.",
  }},
  { boss="High Priestess Arlokk", raid="Zul'Gurub", lines={
    "[Arlokk] Disparaît régulièrement (invisibilité). Panther adds spawnt.",
    "Mark target aléatoire — tank récupère la cible marquée. Spread si Arlokk revient.",
  }},
  { boss="Hakkar", raid="Zul'Gurub", lines={
    "[Hakkar] Corruption de sang = Sanguinate tue le groupe entier si non géré.",
    "Infected player se sacrifie ou est tué puis rez.",
    "Hakkar drain le Mana — Paladin Seals de Wisdom sur les healers.",
    "4 Sons of Hakkar adds qui doivent mourir — sang empoisonné = Corromptu Hakkar.",
    "[NOTE] Tuer les Sons of Hakkar AVANT d'engager Hakkar (dégâts réduits).",
  }},
  { boss="Gahz'ranka", raid="Zul'Gurub", lines={
    "[Gahz'ranka] World boss ZG optionnel. Summon avec Mudskunk Lure.",
    "Tank and spank. Tail Sweep = ne pas se mettre derrière.",
  }},

  -- ══ RUINS OF AHN'QIRAJ (AQ20) ════════════════════════════
  { boss="Kurinnaxx", raid="Ruins of Ahn'Qiraj", lines={
    "[Kurinnaxx] Tank contre un mur. Sand Trap = piège aléatoire, bougez.",
    "Mortal Wounds stacks (réduit soins) — changer de tank à 5 stacks.",
    "Enrage à 30% HP — Paladin Blessing of Protection sur un healer si besoin.",
  }},
  { boss="General Rajaxx", raid="Ruins of Ahn'Qiraj", lines={
    "[Rajaxx] 7 vagues d'adds avant Rajaxx lui-même. Défense sur l'entrée.",
    "Tuerle General Rajaxx rapidement — il buff les autres adds.",
    "Rally = Rajaxx buff tout le raid adverse. AoE les waves.",
  }},
  { boss="Moam", raid="Ruins of Ahn'Qiraj", lines={
    "[Moam] Drain Mana sur tous les casters. Warlocks/Mages ont 0 mana rapidement.",
    "Moam invulnérable si Mana non drainé — DPS physique only pendant.",
    "Phase Mana épuisé = DPS full. Serpentine Obsidian Scorpid adds spawnt.",
  }},
  { boss="Ossirian", raid="Ruins of Ahn'Qiraj", lines={
    "[Ossirian] Invulnérable sauf si Crystal actif. Cristaux rouges autour de la salle.",
    "Trouver le Crystal qui l'affaiblit (icône correspondante). Activer pour DPS window.",
    "Supreme Mode (sans crystal) = Ossirian one-shot. TOUJOURS avoir crystal actif.",
    "[NOTE] Crystal respawn toutes les 45s. Assignez des coureurs de cristaux.",
  }},

  -- ══ TEMPLE OF AHN'QIRAJ (AQ40) ═══════════════════════════
  { boss="The Prophet Skeram", raid="Temple of Ahn'Qiraj", lines={
    "[Skeram] Split en 3 images à 75%, 50%, 25% HP. Tuer les 3 images simultaneously.",
    "True Fulfillment = MC aléatoire — interrompre et kill les MC players.",
    "Mind Control les joueurs avec le plus de dégâts en priorité.",
  }},
  { boss="Sartura", raid="Temple of Ahn'Qiraj", lines={
    "[Sartura] Whirlwind fréquent = TOUT LE MONDE s'éloigne pendant le Whirlwind.",
    "4 Royal Guards adds. Tanks sur chaque add. Kill Sartura en dernier.",
    "Sartura et adds font le Whirlwind simultanément. Spread la salle.",
  }},
  { boss="Fankriss", raid="Temple of Ahn'Qiraj", lines={
    "[Fankriss] Summon Spawn of Fankriss aléatoirement (warp des joueurs).",
    "Joueurs warpés doivent courir vers le groupe. Prendre les Spawns.",
    "Encase in Amber = piège. Libérez les joueurs encapsulés.",
  }},
  { boss="Viscidus", raid="Temple of Ahn'Qiraj", lines={
    "[Viscidus] Gelé par les sorts de glace (Frost Bolt, Frost Shock, etc.).",
    "Phase 1 : Geler avec sorts Frost. Phase 2 : Briser avec attaques physiques.",
    "Phase 3 : Slime glob = AOE poison. Phase 4 (glob) : tuer rapidement.",
    "[NOTE] Nécessite beaucoup de Frost DPS. Chamans/Mages/Chasseurs Frost.",
  }},
  { boss="Princess Huhuran", raid="Temple of Ahn'Qiraj", lines={
    "[Huhuran] Enrage à 30% HP. TOUS les joueurs doivent avoir Nature Resist max.",
    "Wyvern Sting = sleep sur un joueur (dispel).",
    "Nature Resist gear obligatoire. Frenzy = Tranquilizing Shot (Hunter).",
    "[NOTE] Seuil Nature Resist : min 200 NR recommandé pour tous.",
  }},
  { boss="Twin Emperors", raid="Temple of Ahn'Qiraj", lines={
    "[Vem/Vek] Vek'lor (magie) et Vek'nilash (physique) — chacun immune à l'autre type.",
    "Vek'nilash = physique seulement. Vek'lor = sorts seulement.",
    "Téléportent entre eux régulièrement. Tanks doivent switcher rapidement.",
    "Healers sur les tanks à tout moment. Gardes adds en périphérie.",
  }},
  { boss="Ouro", raid="Temple of Ahn'Qiraj", lines={
    "[Ouro] Submerge sous le sable, réémerge aléatoirement. Run si sandblast.",
    "Scarab adds spawnt pendant Submerge. AoE les scarabs.",
    "Enrage à 20%. Tanks alternent quand Ouro re-surface.",
  }},
  { boss="C'Thun", raid="Temple of Ahn'Qiraj", lines={
    "[C'Thun Phase 1] Eye Beam = NE PAS regarder l'oeil. Spread toute la salle.",
    "Claw Tentacles : tanks les tentacules, DPS les brûle.",
    "[C'Thun Phase 2] Tentacules + Stomach. Joueurs avalés doivent DPS depuis l'intérieur.",
    "Eye of C'Thun = one-shot. Positionnement critique. Healers en permanence.",
    "[NOTE] Fight le plus difficile de l'ère vanilla. Requires très bonne coordination.",
  }},

  -- ══ NAXXRAMAS ════════════════════════════════════════════
  -- Aile Plague
  { boss="Noth the Plaguebringer", raid="Naxxramas", lines={
    "[Noth] Phase combat : Cote une malédiction (Decursive obligatoire).",
    "Phase téléportation : Noth invulnérable, Plague Champions + Guardians spawnt.",
    "Alterner phases 3 fois. Paladin/Prêtre : curse dispel constant.",
  }},
  { boss="Heigan the Unclean", raid="Naxxramas", lines={
    "[Heigan] La Danse! Salle divisée en 4 zones. Rester dans la zone 1 (safe).",
    "Eruptez les zones dans l'ordre 4-3-2-1 puis 1-2-3-4 avec la vague.",
    "[NOTE] Presque tout le raid wipe à la danse. Pratiquez le timing.",
    "Phase cast : Nécrose = 1 joueur seulement près de Heigan pour maintenir l'aggro.",
  }},
  { boss="Loatheb", raid="Naxxramas", lines={
    "[Loatheb] Debuff empêche les soins sauf pendant 3 secondes toutes les 20s.",
    "TOUS les joueurs doivent savoir quand le window de heal est actif.",
    "Spores spawnt autour de la salle — TOUS doivent toucher une Spore pour le buff.",
    "[NOTE] DPS race. Fenêtre de heal précise. Très peu de marges d'erreur.",
  }},
  -- Aile Spider
  { boss="Anub'Rekhan", raid="Naxxramas", lines={
    "[Anub] Locust Swarm = cours vers les portes, tank Anub dans le couloir.",
    "Scarab adds pendant Locust Swarm — AoE les scarabs.",
    "Impale : tank ne pas paniquer. Healers sur le tank pendant Impale.",
  }},
  { boss="Grand Widow Faerlina", raid="Naxxramas", lines={
    "[Faerlina] 4 Naxxramas Worshipper + 2 Naxxramas Follower adds.",
    "Faerlina Frenzy à bas HP — sacrifier un Worshipper (MC + kill) pour Frenzy cancel.",
    "Mortal Wound stacks sur le tank — alterner tanks.",
  }},
  { boss="Maexxna", raid="Naxxramas", lines={
    "[Maexxna] Web Wrap aléatoire = joueurs prisonniers dans le mur. Libérez-les.",
    "Stun toutes les 40s (Web Spray). Préparez-vous : tous les joueurs stunned 8s.",
    "Enrage à 30% HP — Bloodlust/Innervate tout. DPS race après Enrage.",
    "Poison = dispel constant. Spider adds spawnt avec Enrage.",
  }},
  -- Aile Military
  { boss="Instructor Razuvious", raid="Naxxramas", lines={
    "[Razuvious] 2 Understudies adds. SEULEMENT les Understudies peuvent tank.",
    "2 Prêtres : MC des Understudies pour tank Razuvious (roulement MC).",
    "Unbalancing Strike = swing de 45k. MC tank doit swap avant ce cast.",
    "[NOTE] Si les Prêtres MC échouent = wipe instantané. 2 Prêtres dédiés obligatoires.",
  }},
  { boss="Gothik the Harvester", raid="Naxxramas", lines={
    "[Gothik] Salle divisée en 2 par une grille. 50% du raid de chaque côté.",
    "Adds morts passent de l'autre côté comme morts-vivants. Tuer rapidement.",
    "Grille s'ouvre à 50% HP — tous sur Gothik.",
  }},
  { boss="Four Horsemen", raid="Naxxramas", lines={
    "[4HM] 4 boss simultanés aux 4 coins. Chacun caste Mark qui stacks.",
    "Tanks rotatent à 4-5 Marks. Zigzag entre les corners.",
    "Zeliek et Blaumeux (arrière) = distance only. Mograine et Thane (avant) = tanks physiques.",
    "[NOTE] Synchronisation parfaite requise. Fight de coordination maximum.",
  }},
  -- Aile Abomination
  { boss="Patchwerk", raid="Naxxramas", lines={
    "[Patchwerk] Tank and spank. 3 tanks obligatoires (Hateful Strike sur le 2ème plus haute aggro).",
    "Enrage à 5% HP — DPS race. Fight dure 3 minutes max ou enrage = wipe.",
    "[NOTE] Test DPS pur. Si DPS insuffisant = impossible à tuer.",
  }},
  { boss="Grobbulus", raid="Naxxramas", lines={
    "[Grobbulus] Inject Poison sur un joueur aléatoire = drop une flaque de poison.",
    "Joueur injecté court EN DEHORS du groupe et pose la flaque, puis revient.",
    "Ne jamais poser une flaque au centre. Circle kite Grobbulus.",
    "Slime Spray = cône frontal, personne devant Grobbulus sauf tank.",
  }},
  { boss="Gluth", raid="Naxxramas", lines={
    "[Gluth] Zombie Chow adds = ne pas les laisser atteindre Gluth (il se heal).",
    "Kitter : 1-2 joueurs kitent les Zombie Chow loin de Gluth.",
    "Decimate à 25% HP (répété) = tous les joueurs à 5% HP. Healers spamment.",
    "Après Decimate : Zombie Chow courent vers Gluth. Kitters les redirigent.",
  }},
  { boss="Thaddius", raid="Naxxramas", lines={
    "[Phase 1] Stalagg + Feugen doivent mourir en même temps (< 5 secondes d'écart).",
    "[Phase 2] Polarity Shift = + et - charges. CÔTÉ + avec +, CÔTÉ - avec -.",
    "Si tu touches quelqu'un de charge opposée = dégâts massifs sur tout le groupe.",
    "[NOTE] Mort = perte de la charge Polarity. Vérifiez votre buff après rez.",
  }},
  -- Frostwyrm Lair
  { boss="Sapphiron", raid="Naxxramas", lines={
    "[Sapph] Phase 1 : Tank + DPS normalement. Phase vol : Blizzard = évitez la zone.",
    "Frost Bolt Volley = Frost Resist obligatoire (min 150 FR recommandé).",
    "Ice Tomb = joueurs gelés dans la glace. Autres se cachent derrière les glaçons.",
    "Life Drain pendant la phase vol. Healers antent.",
  }},
  { boss="Kel'Thuzad", raid="Naxxramas", lines={
    "[Phase 1] Morts-vivants et Spectral adds. Tuer les Abominations rapidement.",
    "[Phase 2] KT engage. Frostbolt interruptible. Shadow Fissure = bouger immédiatement.",
    "Frost Blast = joueur gelé, healer spammer ce joueur.",
    "[Phase 3] 2 Lick Kings adds (non tankables). DPS KT full. Healers sur le tank.",
    "[NOTE] Utiliser les Rez Paladin/Druide pendant la fenêtre de Banish.",
  }},

  -- ══ WORLD BOSSES ══════════════════════════════════════════
  { boss="Azuregos", raid="World Boss", lines={
    "[Azuregos] Frost AoE massif — Frost Resist recommandé.",
    "Mark of Frost = stun. Mana Freeze = drain mana complet.",
    "Cible aléatoire pour Frost Breath — Spread le groupe.",
  }},
  { boss="Kazzak", raid="World Boss", lines={
    "[Kazzak] Supreme Mode si des joueurs meurent (Kazzak se heal). Ne jamais mourir!",
    "Void Bolt = tank prend de gros dégâts. Healers spamment le tank.",
    "Shadowbolt Volley = tous prennent des dégâts. Shadow Resist utile.",
    "[NOTE] Tuer vite avant que Enrage soit actif. Pas de rez pendant le fight.",
  }},
  { boss="Lethon", raid="World Boss", lines={
    "[Lethon] (Green Dragon) Draw Spirit = soigne Lethon de chaque spirit collecté.",
    "Spirit Shades spawnt et courent vers Lethon. DPS/Kill les Spirits.",
    "Sleep (peur) = run hors de portée. Shadowbolt = Nature Resist utile.",
  }},
  { boss="Taerar", raid="World Boss", lines={
    "[Taerar] 3 Shades copies. Tuer les Shades pour faire apparaître Taerar.",
    "Bellowing Roar = AoE peur. Tremor Totem / Fear Ward obligatoire.",
    "Arcane Blast = interruptible.",
  }},
  { boss="Ysondre", raid="World Boss", lines={
    "[Ysondre] Druids of the Nightmare adds à 75/50/25%. Tuer les adds vite.",
    "Lightning Cloud = zone de dégâts lightning, bougez.",
    "Decay of Ages = debuff soin réduit.",
  }},

  -- ══ KARAZHAN ══════════════════════════════════════════════
  { boss="Attumen", raid="Upper Karazhan Halls", lines={
    "[Attumen] Phase 1: tank Midnight (cheval). A 95% PV Attumen invoque et monte.",
    "Phase 2: Attumen + Midnight fusionnent. Curse of Unbinding = dispel immédiat.",
    "Charge aléatoire = spread le raid. Tank face au mur, dos au raid.",
  }},
  { boss="Moroes", raid="Lower Karazhan Halls", lines={
    "[Moroes] 4 adds = CC 3 en priorité (Poly/Peur/Aveugle/Banissement).",
    "Tuer l'add healer en 1er, puis add caster, puis Moroes. Garrote (saignée) dure tout le combat.",
    "Moroes disparaît et réapparaît. Tanks en alerte. Heal lourd sur Garrote.",
  }},
  { boss="Maiden of Virtue", raid="Upper Karazhan Halls", lines={
    "[Maiden] Repentance = stun raid 12s (prévisible). Healers doivent heal avant.",
    "Holy Ground stun les mêlées. Mêlées doivent rester hors de la zone sacrée.",
    "Holy Fire = gros dot sur joueur. Heal priorité. Interruption = ne pas interrompre Consecration.",
  }},
  { boss="Opera", raid="Upper Karazhan Halls", lines={
    "[Opera] 3 évènements possibles: Magicien d'Oz, Grand Méchant Loup, Romulo & Julianne.",
    "Magicien d'Oz: tuer Dorothée, puis Lion Pleutre, puis Manequin, puis Épouvantail.",
    "Grand Méchant Loup: kite le loup. R&J: tuer ensemble (ils se ressuscitent si écart > 5s).",
  }},
  { boss="The Curator", raid="Upper Karazhan Halls", lines={
    "[Curator] DPS ranged sur les Astral Flares dès qu'ils spawn. Mêlées sur le boss.",
    "Evocation (mana vide): DPS full sur le Curator. Arrêt dès qu'il reprend mana.",
    "Ne jamais waste DPS sur le boss hors Evocation. Priorité absolue: Flares.",
  }},
  { boss="Illhoof", raid="Upper Karazhan Halls", lines={
    "[Illhoof] Kill Imps en AoE constant. Libérer le joueur sacrifié (DPS les chains).",
    "Kil'rek (petit démon) = tank loin d'Illhoof. Le tuer si possible (boost illhoof sinon).",
    "Sacrifice aléatoire = focus DPS sur les chaînes immédiatement.",
  }},
  { boss="Shade of Aran", raid="Upper Karazhan Halls", lines={
    "[Aran] Pas de taunt possible. Interruptions: Frostbolt, Fireball, Arcane Missiles (3 interrupteurs).",
    "Blizzard = cercle bleu qui se déplace = bougez. FLAME WREATH = NE PAS BOUGER (explosion raid).",
    "Elementals à 40%: tuer en priorité. Secondes flammes/blizzards = burst phase.",
  }},
  { boss="Netherspite", raid="Upper Karazhan Halls", lines={
    "[Netherspite] 3 faisceaux: Rouge (tank DMG), Vert (heal+absorbe soin), Bleu (arcane).",
    "Rouge = warrior/paladin. Vert = healer ou mage. Bleu = mage/démo. Rotation toutes les 30s.",
    "Phase Banissement: courir contre les murs, ne pas toucher Netherspite.",
  }},
  { boss="Chess Event", raid="Upper Karazhan Halls", lines={
    "[Chess] Chaque joueur contrôle une pièce. King Llane = toujours contrôlé.",
    "Medivh triche: flammes aléatoires sur les cases. Anticiper et déplacer.",
    "Tuer le Roi Noir (boss) pour gagner. Pièces auto-combattent si non contrôlées.",
  }},
  { boss="Prince Malchezaar", raid="Upper Karazhan Halls", lines={
    "[Malchezaar] Axes d'Enfer (infernaux) : spread dans toute la salle dès spawn.",
    "P2 (60-30%): dégâts shadow très élevés. Resist shadow utile. DPS lent.",
    "P3 (<30%): Enfeeble random joueurs (HP à 1). STOP DPS quand votre nom apparaît.",
  }},
  { boss="Nightbane", raid="Upper Karazhan Halls", lines={
    "[Nightbane] Phase terrestre: Charred Earth sous le tank = tank se déplace.",
    "Phase aérienne: ranged DPS tuer les squelettes. Raid spread (Smoking Blast = one-shot).",
    "Alterner sol/air. Resist feu recommandé sur le tank.",
  }},

  -- ══ KZ10 OctoWow ══════════════════════════════════════════
  { boss="Master Blacksmith Rolfen", raid="Lower Karazhan Halls", lines={
    "[Rolfen] Tank swap sur les stacks de débuffs. Interruptions sur ses casts de forgeron.",
    "Les adds arrivent par vagues: AoE rapide. DPS priorité adds > boss.",
    "Sortir des zones au sol (feu/fumée). Dispel les débuffs de mêlée.",
  }},
  { boss="Brood Queen Araxxna", raid="Lower Karazhan Halls", lines={
    "[Araxxna] Toiles de toile = spread le raid. Healers priorité: dépoisonner.",
    "Petites araignées = AoE immédiate sinon elles empoisonnent tout le monde.",
    "La reine plaque des joueurs: DPS les toiles pour libérer. Ne pas rester groupé.",
  }},
  { boss="Grizikil", raid="Lower Karazhan Halls", lines={
    "[Grizikil] Tank swap dès 4-5 stacks de saignée. Le saignement continue hors taunt.",
    "Ranged spread: cleave / griffes larges sur l'arc frontal.",
    "Kill adds en priorité (ils renforcent Grizikil avec des buffs).",
  }},
  { boss="Clawlord Howlfang", raid="Lower Karazhan Halls", lines={
    "[Howlfang] Tank seul. Dégâts très lourds sur le MT: heal intensif.",
    "Interruption du Howl (peur / stun) = priorité pour les interrupteurs.",
    "Rester derrière: cleave frontal mortel. Pas de mêlée devant le boss.",
  }},
  { boss="Lord Blackwald II", raid="Lower Karazhan Halls", lines={
    "[Blackwald] Équipement shadow resist sur le tank recommandé.",
    "Tank swap sur débuff Shadow Embrace (>3 stacks). Dispel les malédictions raid.",
    "Heal lourd en phase d'ombre (amplification des dégâts). DPS constant sans interruption.",
  }},

  -- ── Upper Karazhan Halls (KZ40) ─────────────────────────────
  { boss="Keeper Gnarlmoon", raid="Upper Karazhan Halls", lines={
    "[Gnarlmoon] Boss nature. Tank face au mur, dos au raid. Évitez les zones AoE au sol.",
    "Interrompez Moonfire Surge si possible. Heal constant sur le MT.",
    "Phase d'empowerment à 50% PV : DPS burst, soigneurs en alerte maximale.",
  }},
  { boss="Ley-Watcher Incantagos", raid="Upper Karazhan Halls", lines={
    "[Incantagos] Boss arcane. Spreader les joueurs (aura arcane à proximité).",
    "Interrompez Arcane Overload — critical wipe si non-interrompu. 2 groupes d'interruption rotation.",
    "Ley Lines au sol : ne pas rester dessus. Sorts : purge les buffs arcane sur le boss.",
  }},
  { boss="Anomalus", raid="Upper Karazhan Halls", lines={
    "[Anomalus] Invoque des Rifts = tuer immédiatement (deviennent enragés sinon).",
    "Tank pivote le boss, DPS focus Rifts dès spawn. Ne pas AoE le boss pendant les Rifts.",
    "Phase chaos à 30% PV : tout le monde debout, heal raid intensif.",
  }},
  { boss="Echo of Medivh", raid="Upper Karazhan Halls", lines={
    "[Echo of Medivh] Boss spectral, réplique de Medivh. Résiste aux sorts shadow.",
    "Conjure Arcane Image = interrupt/kick immédiat. Tank maintient face au mur.",
    "Des projections de sorts couvrent le sol : deplacement constant requis.",
  }},
  { boss="King (Chess fight)", raid="Upper Karazhan Halls", lines={
    "[King - Chess] Combat d'échecs tactique. Chaque joueur contrôle une pièce.",
    "Roi = pièce priorité à ne pas laisser mourir. Reines et Tours = DPS principal.",
    "Méfiez-vous du triche IA : le boss peut bouger deux pièces. Protégez votre Roi.",
  }},
  { boss="Sanv Tas'dal", raid="Upper Karazhan Halls", lines={
    "[Sanv Tas'dal] Démon ancien. Aura de corruption progressive sur le raid.",
    "Tank swap sur 4 stacks de Fel Corruption. Purge/Dispel continus requis.",
    "À 40% PV invoque des Imps : tanks secondaires ou CC. Focus boss en priorité.",
  }},
  { boss="Kruul", raid="Upper Karazhan Halls", lines={
    "[Kruul] Pit Lord d'Outland. AoE feu massive, positionnement strict.",
    "Raid spread 8m minimum. Mêlées rotationnelles pour éviter Cleave + Flamestrike.",
    "Felfire Barrage = tout le raid s'écarte de la zone cible. Phase enragée à 20%.",
  }},
  { boss="Rupturan the Broken", raid="Upper Karazhan Halls", lines={
    "[Rupturan] Draenei brisé. Aura de désespoir (réduit soins de 50% à 60% PV).",
    "Heal throughput maximum entre 70%-60%. Tanks à max distance les uns des autres.",
    "Soulburst = stun 3s raid — positionnement serré avant le cast pour minimiser dégats.",
  }},
  { boss="Mephistroth", raid="Upper Karazhan Halls", lines={
    "[Mephistroth] Boss final KZ40. Démon majeur, 3 phases.",
    "Phase 1 : tank principal, Dispel Shadow Word: Weakness immédiat.",
    "Phase 2 (50%) : adds Shades = tanks off, tuer avant retour boss. Soins raid priorité.",
    "Phase 3 (20%) : enrage + Soul Leech sur le MT. Bloodlust/Héroisme. Burn rapide.",
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
        RT_Print("|cffFF4444[Tactics] Aucune tactique trouvée pour: " .. (bossName or "?") .. "|r")
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
    RT_Print("|cff88FF88[Tactics] Tactique de " .. tactic.boss .. " postée en " .. channel .. ".|r")
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
            RT_Print("|cff88FF88[Tactics] Tactique de " .. bossName .. " mise à jour.|r")
            RT_TACTICS_INDEX = nil
            return true
        end
    end
    table.insert(RT_DB.customTactics, { boss=bossName, raid="Custom", lines={text}, custom=true })
    RT_Print("|cff88FF88[Tactics] Tactique de " .. bossName .. " ajoutée.|r")
    RT_TACTICS_INDEX = nil
    return true
end

function RT_Tactics.DeleteCustom(bossName)
    if not RT_DB or not RT_DB.customTactics then return end
    for i = table.getn(RT_DB.customTactics), 1, -1 do
        if string.lower(RT_DB.customTactics[i].boss) == string.lower(bossName or "") then
            table.remove(RT_DB.customTactics, i)
            RT_Print("|cffFFAA00[Tactics] Tactique de " .. bossName .. " supprimée.|r")
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
    title:SetText("|cffFFD700Tactics|r  —  " .. table.getn(RT_TACTICS_DB) .. " boss vanilla + tactiques custom")
    title:SetTextColor(1.0, 0.85, 0.0)

    -- Recherche
    local searchLabel = p:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    searchLabel:SetPoint("TOPLEFT", p, "TOPLEFT", 6, -24)
    searchLabel:SetText("Recherche:")

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
    bossBtn:SetText("Boss actuel")
    bossBtn:SetScript("OnClick", function()
        local bossName = (RT_BOSS_STATE and RT_BOSS_STATE.bossName) or ""
        if bossName ~= "" then
            searchBox:SetText(bossName)
            RT_TacticsRefreshList(bossName)
        else
            RT_Print("|cffFFAA00[Tactics] Aucun boss sélectionné dans l'onglet Boss.|r")
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
    previewText:SetText("|cff888888Sélectionne un boss à gauche|r")

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
    customTitle:SetText("|cffFFD700Tactique Custom|r")

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
    customSaveBtn:SetText("Sauvegarder")
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
    customDelBtn:SetText("Supprimer")
    customDelBtn:SetScript("OnClick", function()
        if TACT_SELECTED then
            RT_Tactics.DeleteCustom(TACT_SELECTED)
            TACT_SELECTED = nil
            if RT_TacticPreviewText then
                RT_TacticPreviewText:SetText("|cff888888Sélectionne un boss|r")
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

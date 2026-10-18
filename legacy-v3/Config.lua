-- RT - Raid Tool | Configuration & Constants
-- Mapping spécialisation, buffs, raids
-- ============================================================

-- Mapping Spécialisation → Rôle
RT_SPEC_ROLE = {
    ["Warrior"]  = {
        ["Fury"]="DPS", ["Arms"]="DPS", ["Protection"]="Tank", ["Prot"]="Tank",
    },
    ["Paladin"]  = {
        ["Holy"]="Heal", ["Protection"]="Tank", ["Prot"]="Tank", ["Retribution"]="DPS", ["Ret"]="DPS",
    },
    ["Druid"]    = {
        ["Restoration"]="Heal", ["Resto"]="Heal",
        ["Balance"]="DPS", ["Boomkin"]="DPS", ["Moonkin"]="DPS", ["Boom"]="DPS",
        ["Feral"]="DPS", ["Bear"]="Tank", ["Cat"]="DPS", ["Feral Tank"]="Tank",
    },
    ["Priest"]   = {
        ["Holy"]="Heal", ["Discipline"]="Heal", ["Disc"]="Heal", ["Shadow"]="DPS",
    },
    ["Shaman"]   = {
        ["Restoration"]="Heal", ["Resto"]="Heal",
        ["Enhancement"]="DPS", ["Enh"]="DPS",
        ["Elemental"]="DPS", ["Ele"]="DPS",
    },
    ["Mage"]     = { ["Arcane"]="DPS", ["Fire"]="DPS", ["Frost"]="DPS" },
    ["Warlock"]  = { ["Affliction"]="DPS", ["Affli"]="DPS", ["Demonology"]="DPS", ["Demo"]="DPS", ["Destruction"]="DPS", ["Destro"]="DPS" },
    ["Hunter"]   = { ["Marksmanship"]="DPS", ["MM"]="DPS", ["Marks"]="DPS", ["Survival"]="DPS", ["SV"]="DPS", ["Beast Mastery"]="DPS", ["BM"]="DPS" },
    ["Rogue"]    = { ["Swords"]="DPS", ["Combat"]="DPS", ["Assassination"]="DPS", ["Assa"]="DPS", ["Subtlety"]="DPS", ["Sub"]="DPS" },
}

-- Buffs de masse par classe
RT_BUFFS_LIST = {
    ["Priest"]  = { "Power Word: Fortitude", "Divine Spirit", "Shadow Protection" },
    ["Mage"]    = { "Arcane Brilliance" },
    ["Druid"]   = { "Gift of the Wild" },
    ["Warlock"] = { "Curse of Elements", "Curse of Shadow", "Curse of Recklessness" },
}

-- Données des raids Vanilla + TurtleWoW
RT_VANILLA_RAIDS = {
    { key="MC",    name="Molten Core",
        bosses={"Lucifron","Magmadar","Gehennas","Garr","Baron Geddon","Shazzrah",
                "Sulfuron Harbinger","Golemagg","Majordomo Executus","Ragnaros"} },
    { key="ONY",   name="Onyxia's Lair",
        bosses={"Onyxia"} },
    { key="BWL",   name="Blackwing Lair",
        bosses={"Razorgore","Vaelastrasz","Broodlord Lashlayer","Firemaw",
                "Ebonroc","Flamegor","Chromaggus","Nefarian"} },
    { key="ZG",    name="Zul'Gurub",
        bosses={"Jeklik","Venoxis","Marli","Mandokir","Gahzranka",
                "Thekal","Arlokk","Jindo","Hakkar"} },
    { key="AQ20",  name="Ruins of Ahn'Qiraj",
        bosses={"Kurinnaxx","Rajaxx","Moam","Buru","Ayamiss","Ossirian"} },
    { key="AQ40",  name="Temple of Ahn'Qiraj",
        bosses={"Skeram","Bug Trio","Sartura","Fankriss","Viscidus",
                "Huhuran","Twin Emperors","Ouro","C'Thun"} },
    { key="NAXX",  name="Naxxramas",
        bosses={"Anub'Rekhan","Faerlina","Maexxna","Noth","Heigan","Loatheb",
                "Razuvious","Gothik","Four Horsemen","Patchwerk","Grobbulus",
                "Gluth","Thaddius","Sapphiron","Kel'Thuzad"} },
    { key="WORLD", name="World Bosses",
        bosses={"Azuregos","Lord Kazzak","Taerar","Emeriss","Lethon","Ysondre"} },
    { key="CUSTOM",name="Custom / Trash",
        bosses={} },
}

-- Copie de référence des boss natifs (sert à empêcher la suppression des boss de base)
RT_DEFAULT_RAID_BOSSES = {}
for raidIdx = 1, table.getn(RT_VANILLA_RAIDS) do
    local raid = RT_VANILLA_RAIDS[raidIdx]
    RT_DEFAULT_RAID_BOSSES[raid.key] = {}
    local bosses = raid.bosses or {}
    for bossIdx = 1, table.getn(bosses) do
        local bossName = bosses[bossIdx]
        RT_DEFAULT_RAID_BOSSES[raid.key][bossName] = true
    end
end

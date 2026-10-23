
local RetroUI = require("retro_ui")
local PAGES = require("data")
local PRICES = require("prices")                -- GE guide prices for the drop log's values (tools/make_dev_kit_prices.py)
local C = RetroUI.COLOURS

local function get(fn) local ok, v = pcall(fn); if ok then return v end end

local W, H = 540, 465
local MAX_SPOTS = 6
local TABS = {}
for i, p in ipairs(PAGES) do TABS[i] = p.name end
TABS[#TABS + 1] = "TELEPORT"
local TELEPORT = #TABS
TABS[#TABS + 1] = "TOOLS"
local TOOLS = #TABS
TABS[#TABS + 1] = "SEARCH"
local SEARCH = #TABS
local TAB_ROWS = #TABS > 14 and 3 or (#TABS > 8 and 2 or 1)
local TABS_PER_ROW = math.ceil(#TABS / TAB_ROWS)
H = H + (TAB_ROWS - 1) * 33

local SKILLS = {
    { "Attack", "attack" }, { "Strength", "strength" }, { "Defence", "defence" }, { "Ranged", "ranged" },
    { "Magic", "magic" }, { "Necromancy", "necromancy" }, { "Constitution", "constitution" }, { "Prayer", "prayer" },
    { "Summoning", "summoning" }, { "Slayer", "slayer" }, { "Cooking", "cooking" }, { "Woodcutting", "woodcutting" },
    { "Fletching", "fletching" }, { "Fishing", "fishing" }, { "Firemaking", "firemaking" }, { "Crafting", "crafting" },
    { "Smithing", "smithing" }, { "Mining", "mining" }, { "Herblore", "herblore" }, { "Agility", "agility" },
    { "Thieving", "thieving" }, { "Farming", "farming" }, { "Runecraft", "runecrafting" }, { "Hunter", "hunter" },
    { "Construct", "construction" }, { "Dungeon", "dungeoneering" }, { "Divination", "divination" },
    { "Invention", "invention" }, { "Archaeology", "archaeology" }, { "ALL skills", nil },
}

local saved = get(function() return PersistentDB:GetStructuredData("devKit") end)
if type(saved) ~= "table" then saved = {} end
local page = 1
if type(saved.page) == "number" and saved.page >= 1 and saved.page <= #TABS then page = math.floor(saved.page) end
local spots, spotNames = {}, {}
if type(saved.spots) == "table" then
    for i, s in ipairs(saved.spots) do
        if type(s) == "string" and s:match("^%d+,%d+,%d+") and #spots < MAX_SPOTS then
            spots[#spots + 1] = s
            local name = type(saved.spotNames) == "table" and saved.spotNames[i]
            spotNames[#spots] = type(name) == "string" and name ~= "" and name:sub(1, 24) or ("Spot " .. #spots)
        end
    end
end
local tool = { skill = #SKILLS - 1, picking = false, field = nil, junkAt = nil, confirm = nil, preset = 1 }
if type(saved.toolSkill) == "number" and SKILLS[saved.toolSkill] then tool.skill = math.floor(saved.toolSkill) end
local PRESETS = 6
local presets = {}
if type(saved.presets) == "table" then
    for n = 1, PRESETS do
        local p = saved.presets[n]
        if type(p) == "table" then
            local list = {}
            for _, line in ipairs(p) do if type(line) == "string" and line:match("^%S+ %d+$") then list[#list + 1] = line end end
            if #list > 0 then presets[n] = list end
        end
    end
end
if type(saved.preset) == "number" and saved.preset >= 1 and saved.preset <= PRESETS then tool.preset = math.floor(saved.preset) end
local clearCds = saved.clearCds == true
local flips = {}
if type(saved.flips) == "table" then for k, v in pairs(saved.flips) do if type(k) == "string" then flips[k] = v == true end end end
local function flipOn(name) if flips[name] == nil then return true end return flips[name] end

local window, logWindow                       -- made below: the kit, and the drop log
local status, statusColour = "Ready. Developer worlds only.", C.GREEN
local queue, current = {}, nil                -- commands still to send; { label, done, total, failed, problem }

local ARMED = {
    { key = "oyster", label = "Keep oyster armed", short = "oyster", var = "TUTISLAND_REWARD_STATE", value = 3 },
    { key = "solak", label = "Keep Solak armed", short = "Solak", var = "NATURE_BOSS_LOOT_OWED_GROUP", value = 1 },
    { key = "zamorak", label = "Keep Zamorak rare armed", short = "Zamorak rare", var = "EGWD_ZAMORAK_BOSS_OWED_RARE", value = 1 },
    { key = "myst", label = "Keep Mysterious 15", short = "Mysterious 15", var = "INVENT_PERK_MYSTERIOUS", value = 15 },
    { key = "rare", label = "Keep rare drops 10x", short = "rare drops 10x", var = "LEAGUE_RELIC_RARE_MULTIPLIER", value = 10 },
    { key = "barrows", label = "Keep Barrows chest armed", short = "Barrows chest", var = "BARROWS_TAKEN_ANY_LOOT", value = 0 },
    { key = "hhloot", label = "Keep Harvest Hollow 3x loot", short = "Harvest Hollow 3x loot", var = "HALLOWEEN_HUB_GAUNTLET_DAILY_TRIPLE_LOOT_USED", value = 0 },
}
local POWERS = {
    { key = "souls", short = "souls", var = "COMBATV2_BUFF_NECROMANCY_RESIDUAL_SOUL_STACKS", value = 5, quiet = true },
    { key = "necrosis", short = "Necrosis", var = "COMBATV2_BUFF_NECROMANCY_NECROSIS_STACKS", value = 12, quiet = true },
    { key = "threads", short = "Threads", var = "COMBATV2_BUFF_NECROMANCY_THREADS_OF_FATE_ACTIVE", value = 1, quiet = true },
    { key = "splitsoul", short = "Split Soul", var = "COMBATV2_BUFF_NECROMANCY_SPLIT_SOUL_ACTIVE", value = 1, quiet = true },
    { key = "soulsplit", short = "Soul Split", var = "CURSE_SOULSPLIT", value = 1, quiet = true },
    { key = "skulls", short = "Death Skulls", var = "COMBATV2_COOLDOWN_NECROMANCY_DEATH_SKULLS_END", value = 0, quiet = true },
    { key = "invoke", short = "Invoke Death", var = "COMBATV2_BUFF_NECROMANCY_INVOKE_DEATH_ACTIVE", value = 1, quiet = true },
    { key = "darkness", short = "Darkness", var = "COMBATV2_BUFF_NECROMANCY_DARKNESS_ACTIVE", value = 1, quiet = true },
    { key = "essence", short = "Death Essence", var = "COMBATV2_BUFF_NECROMANCY_DEATH_ESSENCE_ACTIVE", value = 1, quiet = true },
    { key = "bones", short = "Lord of Bones", var = "COMBATV2_BUFF_NECROMANCY_INVOKE_LORD_OF_BONES_ACTIVE", value = 1, quiet = true },
    { key = "livingdeath", short = "Living Death", var = "COMBATV2_BUFF_NECROMANCY_UNDEAD_INSTINCT_ABILITY_STRUCT", value = 48324, quiet = true },
    { key = "berserk", short = "Berserk", var = "COMBATV2_BUFF_MELEE_BERSERK_ACTIVE", value = 1, quiet = true },
    { key = "berserkend", short = "Berserk", var = "COMBATV2_BUFF_MELEE_BERSERK_END", value = 100000000, quiet = true },
    { key = "swiftness", short = "Death's Swiftness", var = "COMBATV2_BUFF_RANGED_DEATH_SWIFTNESS_ACTIVE", value = 1, quiet = true },
    { key = "shadows", short = "Imbued Shadows", var = "COMBATV2_BUFF_RANGED_IMBUED_SHADOWS_ACTIVE", value = 1, quiet = true },
    { key = "shadowsend", short = "Imbued Shadows", var = "COMBATV2_BUFF_RANGED_IMBUED_SHADOWS_END", value = 100000000, quiet = true },
    { key = "winds", short = "Searing Winds", var = "COMBATV2_BUFF_RANGED_SEARING_WINDS_ACTIVE", value = 1, quiet = true },
    { key = "windsend", short = "Searing Winds", var = "COMBATV2_BUFF_RANGED_SEARING_WINDS_END", value = 100000000, quiet = true },
    { key = "flow", short = "Greater Flow", var = "COMBATV2_BUFF_MAGIC_GREATER_FLOW_ACTIVE", value = 1, quiet = true },
    { key = "anomaly", short = "Temporal Anomaly", var = "COMBATV2_BUFF_MAGIC_TEMPORAL_ANOMALY_ACTIVE", value = 1, quiet = true },
    { key = "anomalyend", short = "Temporal Anomaly", var = "COMBATV2_BUFF_MAGIC_TEMPORAL_ANOMALY_END", value = 100000000, quiet = true },
    { key = "flowcharged", short = "charged Greater Flow", var = "COMBATV2_BUFF_MAGIC_GREATER_FLOW_CHARGED_ACTIVE", value = 1, quiet = true },
    { key = "curses", short = "every curse", var = "CURSE_BASE", value = 536870911, quiet = true },
    { key = "curses2", short = "every curse", var = "CURSE_BASE_2", value = 260096, quiet = true },
    { key = "prayers", short = "every prayer", var = "PRAYER_BASE", value = 4194303, quiet = true },
    { key = "prayers2", short = "every prayer", var = "PRAYER_BASE2", value = 63, quiet = true },
    { key = "skeleton", short = "conjures", var = "COMBATV2_BUFF_NECROMANCY_SPIRIT_SKELETON_WARRIOR_END", value = 100000000, quiet = true },
    { key = "zombie", short = "conjures", var = "COMBATV2_BUFF_NECROMANCY_SPIRIT_PUTRID_ZOMBIE_END", value = 100000000, quiet = true },
    { key = "ghost", short = "conjures", var = "COMBATV2_BUFF_NECROMANCY_SPIRIT_VENGEFUL_GHOST_END", value = 100000000, quiet = true },
    { key = "phantom", short = "conjures", var = "COMBATV2_BUFF_NECROMANCY_SPIRIT_PHANTOM_GUARDIAN_END", value = 100000000, quiet = true },
    { key = "bbf", short = "Balance by Force", var = "COMBATV2_BUFF_BALANCE_BY_FORCE_ACTIVE", value = 1, quiet = true },
    { key = "aoe", short = "every attack AoE", var = "COMBATV2_ACTIVE_ATTACK_FLAG_AOE_ACTIVE", value = 1, quiet = true },
    { key = "breath", short = "charged magic", var = "COMBATV2_ACTIVE_ATTACK_MAGIC_CHARGED_DRAGON_BREATH", value = 1, quiet = true },
    { key = "blast", short = "charged magic", var = "COMBATV2_ACTIVE_ATTACK_MAGIC_CHARGED_CONCENTRATED_BLAST", value = 1, quiet = true },
    { key = "sonic", short = "charged magic", var = "COMBATV2_ACTIVE_ATTACK_MAGIC_CHARGED_SONIC_WAVE", value = 1, quiet = true },
    { key = "dracolich", short = "Dracolich set effect", var = "COMBATV2_BUFF_DRACOLICH_SET_EFFECT", value = 3, quiet = true },
    { key = "archoff", short = "offhand effects", var = "COMBATV2_BUFF_SKILLING_OFFHAND_ARCHAEOLOGY_EFFECT", value = 1, quiet = true },
    { key = "huntoff", short = "offhand effects", var = "COMBATV2_BUFF_SKILLING_OFFHAND_HUNTER_EFFECT", value = 1, quiet = true },
    { key = "overload", short = "overload", var = "OVERLOAD_POTION_EFFECTS_LONG", value = 1000, quiet = true },
    { key = "perfectplus", short = "Perfect plus", var = "HERBLORE_PERFECT_PLUS_TIMER", value = 1000, quiet = true },
    { key = "antifire", short = "antifire", var = "DRAGONRESIST_ALL_EXTENDED", value = 500, quiet = true },
    { key = "dxp", short = "double XP", var = "DOUBLEXP_PERSONAL_BUFF_TIME_REMAINING", value = 1000000, quiet = true },
    { key = "cutcam", short = "cutscene control", var = "CUTSCENE_ALLOW_MOUSECAM", value = 1, quiet = true },
    { key = "cutui", short = "cutscene control", var = "CUTSCENE_KEEP_UI", value = 1, quiet = true },
    { key = "cuthide", short = "cutscene control", var = "CUTSCENE_HIDETOPLEVELFEATURES", value = 0, quiet = true },
    { key = "cutchat", short = "cutscene control", var = "CUTSCENE_HIDE_CHAT", value = 0, quiet = true },
    { key = "cutlock1", short = "cutscene control", var = "TOPLEVEL_V2_PARENT_LOCK", value = 0, quiet = true },
    { key = "cutlock2", short = "cutscene control", var = "TOPLEVEL_V2_PARENT_LOCK_2", value = 0, quiet = true },
    { key = "cutlock3", short = "cutscene control", var = "TOPLEVEL_V2_PARENT_LOCK_3", value = 0, quiet = true },
    { key = "famspec", short = "familiar specials", var = "LORE_SPELL_POINTS", value = 60, quiet = true },
    { key = "famtime", short = "familiar time", var = "LORE_FULL_TIMER", value = 400, quiet = true },
    { key = "channel", short = "endless channels", var = "COMBATV2_CHANNEL_ABILITY_ITERATIONS", value = 60, quiet = true },
    { key = "bloat", short = "endless Bloat", var = "COMBATV2_DEBUFF_NECROMANCY_BLOATED_ITERATION", value = 0, quiet = true },
    { key = "rasial", short = "Rasial armguard stacks", var = "COMBATV2_BUFF_NECRO_RASIAL_ARMGUARD_T95_PASSIVE_STACKS", value = 5, quiet = true },
    { key = "skelrage", short = "skeleton rage", var = "COMBATV2_BUFF_NECROMANCY_SPIRIT_SKELETON_WARRIOR_STACKS", value = 25, quiet = true },
    { key = "phantom", short = "phantom stacks", var = "COMBATV2_BUFF_NECROMANCY_SPIRIT_PHANTOM_GUARDIAN_STACKS", value = 25, quiet = true },
    { key = "bloodlust", short = "Bloodlust", var = "COMBATV2_BUFF_MELEE_BLOODLUST_STACKS", value = 4, quiet = true },
    { key = "flowon", short = "Flow", var = "COMBATV2_BUFF_MAGIC_FLOW_ACTIVE", value = 1, quiet = true },
    { key = "wrack", short = "Wrack", var = "COMBATV2_BUFF_MAGIC_WRACK_ACTIVE", value = 1, quiet = true },
    { key = "wildmagic", short = "Wild Magic", var = "COMBATV2_BUFF_MAGIC_WILD_MAGIC_INFUSED_ACTIVE", value = 1, quiet = true },
    { key = "meteor", short = "Meteor Strike adrenaline", var = "COMBATV2_BUFF_MELEE_METEOR_STRIKE_ADRENALINE_EFFECT", value = 1, quiet = true },
    { key = "meteorend", short = "Meteor Strike adrenaline", var = "COMBATV2_BUFF_MELEE_METEOR_STRIKE_ADRENALINE_EFFECT_END", value = 100000000, quiet = true },
    { key = "darkend", short = "Darkness", var = "COMBATV2_BUFF_NECROMANCY_DARKNESS_END", value = 100000000, quiet = true },
    { key = "chanend", short = "endless channels", var = "COMBATV2_CHANNEL_END", value = 100000000, quiet = true },
    { key = "eclipsed", short = "Eclipsed Soul", var = "COMBATV2_PRAYER_ECLIPSED_SOUL_EFFECT_END", value = 100000000, quiet = true },
    { key = "puncture", short = "Puncture", var = "COMBATV2_PLAYER_PUNCTURE_END_TIME", value = 100000000, quiet = true },
    { key = "qbd", short = "QBD coffer", var = "QBD2_REWARDS_AVAILABLE", value = 1, quiet = true, loot = true },
    { key = "araxdd", short = "Araxxi double drops", var = "BSLAY_MASK_DOUBLE_DROPS_GIVEN_ARAXXI", value = 0, quiet = true },
    { key = "gwd2loot", short = "Telos loot", var = "GWD2_SOLO_LOOT_STATE", value = 1, quiet = true, loot = true },
    { key = "wenloot", short = "Arch-Glacor HM loot", var = "EGWD_WEN_BOSS_LOOT_STATE", value = 1, quiet = true, loot = true },
    { key = "goldchest", short = "Pyramid gold chest", var = "NTK_GOLDEN_CHEST_STATE", value = 0, quiet = true, loot = true },
    { key = "wenidle", short = "Arch-Glacor HM loot", var = "EGWD_WEN_BOSS_HM_INPROGRESS", value = 0, quiet = true, loot = true },
    { key = "telosidle", short = "Telos loot", var = "GWD2_SOLO_BOSS_INPROGRESS", value = 0, quiet = true, loot = true },
    { key = "zamloot", short = "Zamorak loot", var = "EGWD_ZAMORAK_BOSS_LOOT_STATE", value = 1, quiet = true, loot = true },
    { key = "raidloot", short = "raid loot", var = "RAID1_LOOT_STATE", value = 1, quiet = true, loot = true },
    { key = "zamowed", short = "Zamorak loot", var = "EGWD_ZAMORAK_BOSS_LOOT_OWED", value = 1, quiet = true, loot = true },
    { key = "fortloot", short = "Zemouregal & Vorkath loot", var = "FORT_BOSS_LOOT_OWED", value = 1, quiet = true, loot = true },
    { key = "raidowed1", short = "raid loot", var = "RAID1_LOOT_OWED_BOSS1", value = 1, quiet = true, loot = true },
    { key = "raidowed2", short = "raid loot", var = "RAID1_LOOT_OWED_BOSS2", value = 1, quiet = true, loot = true },
    { key = "raidpet", short = "raid pet roll", var = "RAID1_BOSS1_PET_ROLL_OWED", value = 1, quiet = true, loot = true },
    { key = "tog", short = "Tears of Guthix", var = "TOG_TEARS_COMPLETE", value = 0, quiet = true },
    { key = "amas0", short = "Amascut loot", var = "AMASCUT_BOSS_COMMON_LOOT_AVAILABLE", value = 1, quiet = true, loot = true },
    { key = "amas1", short = "Amascut loot", var = "AMASCUT_BOSS_RARE_1_LOOT_AVAILABLE", value = 1, quiet = true, loot = true },
    { key = "amas2", short = "Amascut loot", var = "AMASCUT_BOSS_RARE_2_LOOT_AVAILABLE", value = 1, quiet = true, loot = true },
    { key = "amas3", short = "Amascut loot", var = "AMASCUT_BOSS_RARE_3_LOOT_AVAILABLE", value = 1, quiet = true, loot = true },
    { key = "sanct0", short = "Sanctum loot", var = "RAID_REBIRTH1_WYRM_BOSS_COMMON_LOOT_AVAILABLE", value = 1, quiet = true, loot = true },
    { key = "sanct1", short = "Sanctum loot", var = "RAID_REBIRTH1_WYRM_BOSS_RARE_LOOT_AVAILABLE", value = 1, quiet = true, loot = true },
    { key = "sanct2", short = "Sanctum loot", var = "RAID_REBIRTH1_BEAST_BOSS_COMMON_LOOT_AVAILABLE", value = 1, quiet = true, loot = true },
    { key = "sanct3", short = "Sanctum loot", var = "RAID_REBIRTH1_BEAST_BOSS_RARE_LOOT_AVAILABLE", value = 1, quiet = true, loot = true },
    { key = "sanct4", short = "Sanctum loot", var = "RAID_REBIRTH1_SLAYER_MASTER_BOSS_COMMON_LOOT_AVAILABLE", value = 1, quiet = true, loot = true },
    { key = "sanct5", short = "Sanctum loot", var = "RAID_REBIRTH1_SLAYER_MASTER_BOSS_RARE_LOOT_AVAILABLE", value = 1, quiet = true, loot = true },
    { key = "sanct6", short = "Sanctum loot", var = "RAID_REBIRTH1_COMPLETION_RARE_1_LOOT_AVAILABLE", value = 1, quiet = true, loot = true },
    { key = "sanct7", short = "Sanctum loot", var = "RAID_REBIRTH1_COMPLETION_RARE_2_LOOT_AVAILABLE", value = 1, quiet = true, loot = true },
}
local KEEPS = {}                              -- every keep: LOOT's switches, then the powers
for _, a in ipairs(ARMED) do KEEPS[#KEEPS + 1] = a end
for _, a in ipairs(POWERS) do KEEPS[#KEEPS + 1] = a end
local armed, arming = {}, {}                  -- key -> on (saved); key -> { tries, wait } while it doesn't read armed
if type(saved.armed) == "table" then
    for _, a in ipairs(KEEPS) do armed[a.key] = saved.armed[a.key] == true end
end
local function toggleOn(b) return armed[b.toggle:match("[^,]+")] == true end
local windows = { [364] = true, [168] = true }   -- reward windows (interface ids): the guesses, plus learned ones
local learnedWindows = {}                         -- the learned ones, saved
local logSize = { cols = 1, rows = 8 }           -- the drop log's size (0.1.7), saved
local logOff = saved.logOff == true or (type(saved.log) == "table" and saved.log.hidden == true)
local setLogGone                                  -- made with the drop log window
if type(saved.logSize) == "table" then
    logSize.cols = math.max(1, math.min(3, math.floor(tonumber(saved.logSize.cols) or 1)))
    logSize.rows = math.max(3, math.min(40, math.floor(tonumber(saved.logSize.rows) or 8)))
end
if type(saved.windows) == "table" then
    for _, id in ipairs(saved.windows) do
        if type(id) == "number" and not windows[id] then windows[id] = true; learnedWindows[#learnedWindows + 1] = id end
    end
end

local SOURCES = {
    { key = "oyster", name = "Oyster", var = "TUTISLAND_REWARD_STATE", value = 3 },
    { key = "telos", name = "Telos", var = "GWD2_SOLO_LOOT_STATE", value = 1 },
    { key = "glacor", name = "Arch-Glacor HM", var = "EGWD_WEN_BOSS_LOOT_STATE", value = 1 },
    { key = "qbd", name = "QBD coffer", var = "QBD2_REWARDS_AVAILABLE", value = 1 },
    { key = "zamorak", name = "Zamorak", var = "EGWD_ZAMORAK_BOSS_LOOT_STATE", value = 1 },
    { key = "solak", name = "Solak", var = "NATURE_BOSS_LOOT_OWED_GROUP", value = 1 },
}
local REWARD_INVS = { 141, 773, 952, 787 }
local NOT_REWARDS = { [93] = true, [94] = true, [95] = true }   -- backpack, worn, bank
local BEFORE, AFTER = 30, 50                  -- client ticks either side of a claim that count as its loot
local drops = get(function() return PersistentDB:GetStructuredData("devKitDrops") end)
if type(drops) ~= "table" then drops = {} end
for _, s in ipairs(SOURCES) do
    local d = drops[s.key]
    if type(d) ~= "table" or type(d.items) ~= "table" then drops[s.key] = { claims = 0, empty = 0, items = {} } end
end
local dl = { tick = 0, pack = nil, names = {}, adds = {}, rewards = {}, others = {}, seen = {}, claims = {}, dirty = false, told = 0,
             state = {}, errors = {}, scans = 0 }    -- state: each source's switch as last read; scans: window checks done
local function logSource()
    for _, src in ipairs(SOURCES) do if src.key == drops.current then return src end end
    return SOURCES[1]
end

local search                                  -- the SEARCH page (0.1.80): set up with its code below
local function save()
    if not window then return end
    local x, y = window:GetPos()
    local copy, on = {}, {}
    local names = {}
    for i, s in ipairs(spots) do copy[i], names[i] = s, spotNames[i] or ("Spot " .. i) end
    for _, a in ipairs(KEEPS) do on[a.key] = armed[a.key] == true end
    local logAt = saved.log
    if logWindow then
        local lx, ly = logWindow:GetPos()
        logAt = { x = lx, y = ly, hidden = false }   -- (closed is logOff; nothing is left hidden behind a gold tab)
    end
    pcall(function()
        PersistentDB:SetStructuredData("devKit", { x = x, y = y, hidden = window:IsHidden(), page = page, spots = copy, spotNames = names, armed = on, log = logAt,
            windows = learnedWindows, logSize = { cols = logSize.cols, rows = logSize.rows }, logOff = logOff, toolSkill = tool.skill,
            presets = presets, preset = tool.preset, clearCds = clearCds, flips = flips,
            searchMode = search and search.mode, searchDest = search and search.dest })
    end)
end

local function here()
    local grid = get(function() return Player.GetEntity().coordGrid end)
    if grid == nil then return nil end
    local text = get(function() return tostring(grid) end)
    if type(text) == "string" and text:match("^%d+[,_]%d+[,_]%d+") then return (text:gsub("_", ",")) end
    local x = get(function() return grid.x end)
    local z = get(function() return grid.z end) or get(function() return grid.y end)
    if type(x) ~= "number" or type(z) ~= "number" then return nil end
    local level = get(function() return grid.level end)
    if type(level) ~= "number" then level = 0 end
    x, z = math.floor(x), math.floor(z)
    return string.format("%d,%d,%d,%d,%d", level, math.floor(x / 64), math.floor(z / 64), x % 64, z % 64)
end

local L = {}
local function layout()
    local inner = window.inner
    L.x, L.w = inner.x, 474
    L.tabY = inner.y
    L.tabW = math.floor((474 - (TABS_PER_ROW - 1) * 6) / TABS_PER_ROW / 3) * 3   -- 5 a row: 90 each
    L.gridY, L.colW, L.rowH, L.step = inner.y + 36 + (TAB_ROWS - 1) * 33, 234, 27, 33
    L.lcdY = L.gridY + 7 * 33 + 3
end
local function tabAt(i)                       -- where tab i sits (one or two rows)
    local row, col = math.floor((i - 1) / TABS_PER_ROW), (i - 1) % TABS_PER_ROW
    return L.x + col * (L.tabW + 6), L.tabY + row * 33
end
local function cell(i)                        -- the i-th button of a page: two columns
    local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
    return L.x + col * (L.colW + 6), L.gridY + row * L.step, L.colW, L.rowH
end
local function spotRow(r)                     -- a saved spot's row on the TELEPORT page (under its two buttons)
    return L.gridY + r * L.step
end

local redraw
local function setStatus(text, colour)
    status, statusColour = text, colour or C.GREEN
end

local function runName()
    if not current.first or current.first == current.label then return current.label end
    return current.first .. ", then " .. current.label
end
local function run(label, cmds)
    if type(ExecuteConsoleCommand) ~= "function" then
        setStatus("Console commands aren't available here (developer worlds only).", C.RED)
        redraw()
        return
    end
    for _, c in ipairs(cmds) do queue[#queue + 1] = c end
    current = current or { done = 0, total = 0, failed = 0 }
    current.label, current.total = label, current.total + #cmds
    current.first = current.first or label
    setStatus("Running " .. runName() .. ": " .. current.done .. " of " .. current.total)
    redraw()
end

local function sendNext()
    if #queue == 0 or not current then return end
    local command = table.remove(queue, 1)
    local ok, problem = pcall(ExecuteConsoleCommand, command)
    current.done = current.done + 1
    if not ok then
        current.failed, current.problem = current.failed + 1, tostring(problem)
        if current.failed <= 3 then log("Dev Kit: " .. command .. " failed: " .. current.problem) end
    end
    if #queue == 0 then
        local n = current.total
        if current.failed > 0 then
            setStatus("Done: " .. runName() .. ". " .. current.failed .. " of " .. n .. " failed: " .. current.problem, C.RED)
        else
            setStatus("Done: " .. runName() .. " (" .. n .. " command" .. (n == 1 and "" or "s") .. ")")
        end
        current = nil
        redraw()
    elseif current.done % 10 == 0 then
        setStatus("Running " .. runName() .. ": " .. current.done .. " of " .. current.total)
        redraw()
    end
end

local function toolRow(r) return L.gridY + (r - 1) * L.step end
local function pickCell(i)
    local col, row = (i - 1) % 5, math.floor((i - 1) / 5)
    return L.x + col * 96, toolRow(2 + row), 90, L.rowH
end

local function amount(text)
    local s = tostring(text or ""):lower():gsub("[,%s_]", "")
    local digits, suffix = s:match("^(%d+%.?%d*)([km]?)$")
    local n = tonumber(digits)
    if not n then return nil end
    if suffix == "k" then n = n * 1000 elseif suffix == "m" then n = n * 1000000 end
    return math.floor(n + 0.5)
end

local function toolSkills(kind)
    local n = amount(tool.typed or (tool.field and tool.field.content))
    local pick = SKILLS[tool.skill]
    if not n then
        setStatus("Type a number in the box first: a level (99) or XP (13m).", C.RED)
    elseif kind == "level" and (n < 1 or n > 150) then
        setStatus("Levels go from 1 to 120 (150 for Invention).", C.RED)
    elseif kind ~= "level" and n > 200000000 then
        setStatus("XP goes up to 200,000,000.", C.RED)
    else
        local verb = ({ level = "skillsetlevel", xp = "skillsetxp", add = "skilladdxp" })[kind]
        local cmds = {}
        for i, s in ipairs(SKILLS) do
            if s[2] and (pick[2] == nil or i == tool.skill) then cmds[#cmds + 1] = "!" .. verb .. " " .. s[2] .. " " .. string.format("%d", n) end
        end
        local what = ({ level = "level ", xp = "XP ", add = "+XP " })[kind] .. string.format("%d", n)
        run(pick[1] .. " " .. what, cmds)
        return
    end
    redraw()
end

local SEARCH_MODES = { { key = "items", label = "ITEMS", file = "search_items" },
                       { key = "titles", label = "TITLES", file = "search_titles" },
                       { key = "vars", label = "VARS", file = "search_vars" },
                       { key = "places", label = "PLACES", file = "search_places" } }
local SEARCH_ROWS, SEARCH_CAP, SEARCH_ROW_H = 6, 500, 20      -- (0.1.86: 6 rows, the bottom row is ITEMS' pick buttons)
local VAR_KINDS = { p = "VarPlayer", b = "VarBit", c = "VarClient" }
search = { mode = 1, text = "", value = "1", dest = (saved.searchDest == "bank" or saved.searchBank == true) and "bank" or "inv",
           picks = {}, pickList = {}, results = {}, total = 0, offset = 0,
                 picked = nil, dirtyAt = nil, tick = 0, data = {}, field = nil, valueField = nil }
if type(saved.searchMode) == "number" and SEARCH_MODES[saved.searchMode] then search.mode = math.floor(saved.searchMode) end

local function searchData(mode)
    if search.data[mode] then return search.data[mode] end
    local d = { lines = {}, low = {} }
    local part = 1
    while true do
        local name = SEARCH_MODES[mode].file .. "_" .. part
        local ok, blob = pcall(require, name)
        if ok and type(blob) == "table" then blob = blob[1] end
        if not ok or type(blob) ~= "string" then
            if part == 1 then
                d.problem = name .. ": " .. (ok and ("it gave a " .. type(blob)) or tostring(blob))
                log("Dev Kit SEARCH couldn't load " .. d.problem)
            end
            break
        end
        for line in blob:gmatch("[^\n]+") do
            d.lines[#d.lines + 1] = line
            d.low[#d.low + 1] = line:lower()
        end
        part = part + 1
    end
    d.parts = part - 1
    search.data[mode] = d
    return d
end
local function searchFields(line) return line:match("^([^\t]*)\t([^\t]*)\t?([^\t]*)$") end
local function gameName(name) return (name:gsub("^_(%d)", "%1")) end

local function typedPlace(text)
    local t = text:lower()
    local n = {}
    for d in t:gmatch("%d+") do n[#n + 1] = tonumber(d) end
    if t:match("^%s*square") and #n >= 2 then
        return "Map square " .. n[1] .. "," .. n[2], string.format("%d,%d,%d,32,32", n[3] or 0, n[1], n[2])
    elseif t:match("^%s*region") and #n >= 1 then
        local mx, my = math.floor(n[1] / 256), n[1] % 256
        return "Region " .. n[1] .. " (square " .. mx .. "," .. my .. ")", string.format("%d,%d,%d,32,32", n[2] or 0, mx, my)
    elseif t:match("^[%d%s,]+$") and #n == 5 then
        return "Coordinate " .. table.concat(n, ","), table.concat(n, ",")
    elseif t:match("^[%d%s,]+$") and (#n == 2 or #n == 3) and n[1] >= 64 and n[2] >= 64 then
        local x, y, lv = n[1], n[2], n[3] or 0
        return "Tile " .. x .. ", " .. y .. (lv > 0 and (" level " .. lv) or ""),
            string.format("%d,%d,%d,%d,%d", lv, math.floor(x / 64), math.floor(y / 64), x % 64, y % 64)
    end
end

local function runSearch()
    search.dirtyAt, search.offset, search.picked = nil, 0, nil
    local words = {}
    for w in search.text:lower():gmatch("%S+") do words[#words + 1] = w end
    local out, total = {}, 0
    if #words > 0 then
        local d = searchData(search.mode)
        for i, low in ipairs(d.low) do
            local hit = true
            for _, w in ipairs(words) do
                if not low:find(w, 1, true) then hit = false; break end
            end
            if hit then
                total = total + 1
                if #out < SEARCH_CAP then out[#out + 1] = d.lines[i] end
            end
        end
        if search.mode == 4 then
            local name, coord = typedPlace(search.text)
            if coord then table.insert(out, 1, name .. "\tTYPED\t" .. coord); total = total + 1 end
        end
        local what = SEARCH_MODES[search.mode].label:lower()
        local d = searchData(search.mode)
        if #d.lines == 0 and total == 0 then
            setStatus("Couldn't load the " .. what .. " list: " .. tostring(d.problem or "it is empty"):sub(1, 90), C.RED)
        elseif total == 0 then
            setStatus("No " .. what .. " match \"" .. search.text .. "\".", C.RED)
        else
            setStatus(total .. " found" .. (total > SEARCH_CAP and (" (the first " .. SEARCH_CAP .. " listed)") or "") ..
                (search.mode == 1 and ". Click one to spawn it." or search.mode == 2 and ". Click one to unlock it." or
                 search.mode == 4 and ". Click one to teleport." or ". Click one, type a value, then Set."))
        end
    end
    search.results, search.total = out, total
end

local function varValue(name, kind)
    if kind == "c" then return get(function() return var.VarClient[name].value end) end
    local v = get(function() return var.VarPlayer[name].value end)
    if v == nil and kind == "b" then v = get(function() return var.VarBit[name].value end) end
    return v
end

local WORN_FILLER = "MACRO_DIGGER_SKULL"
local WORN_SLOTS = { [0] = "head", "cape", "neck", "weapon", "body", "off-hand", "arms", "legs", "hair", "hands", "feet",
                     "jaw", "ring", "ammo", "aura", "pocket", "extra 16", "extra 17", "extra 18" }
local function wantedSlot(text)
    local word = tostring(text or ""):lower():match("^%s*slot%s+(.-)%s*$")
    if not word then return nil end
    local n = tonumber(word)
    if n then return (n >= 0 and n <= 18 and n == math.floor(n)) and n or false end
    for i = 0, 18 do if WORN_SLOTS[i] == word then return i end end
    return false
end
local function wornUsed()                      -- worn slot (0-18) -> true when something is in it; nil if unreadable
    local inv = get(function() return Inventory.Find(94) end)
    if not inv then return nil end
    local used = {}
    for i = 0, 18 do
        local oid = get(function() return inv:GetSlot(i + 1).obj.id end)
        used[i] = type(oid) == "number" and oid >= 0
    end
    return used
end

local function itemName(a, b) return a ~= "" and a or b end
local function spawnCmd(b)
    local n = amount(search.value) or 1
    if n < 1 then n = 1 end
    return "!give " .. gameName(b) .. " " .. string.format("%d", n) .. (search.dest == "bank" and " bank" or ""), n
end
local function spawnItem(a, b)
    local cmd, n = spawnCmd(b)
    run(itemName(a, b) .. " x" .. string.format("%d", n), { cmd })
end
local function equipItem(a, b)
    local slot = wantedSlot(search.value)
    if slot == nil then                        -- worn: the first empty slot
        run(itemName(a, b) .. " (worn)", { "!give " .. gameName(b) .. " 1 worn" })
        return
    end
    local used = slot and wornUsed()           -- worn into one slot (0.1.85)
    if slot == false then
        setStatus("Slot goes from 0 to 18, or a name: head, cape, neck, weapon, body, off-hand, arms, legs, hair...", C.RED)
    elseif not used then
        setStatus("Couldn't read your worn items.", C.RED)
    elseif used[slot] then
        setStatus("Slot " .. slot .. " (" .. WORN_SLOTS[slot] .. ") is taken: take that off first.", C.RED)
    else
        local cmds = {}
        for i = 0, slot - 1 do
            if not used[i] then cmds[#cmds + 1] = "!give " .. WORN_FILLER .. " 1 worn" end
        end
        cmds[#cmds + 1] = "!give " .. gameName(b) .. " 1 worn"
        run(itemName(a, b) .. " in slot " .. slot .. " (" .. WORN_SLOTS[slot] .. ")" ..
            (#cmds > 1 and (", " .. (#cmds - 1) .. " filler" .. (#cmds == 2 and "" or "s") .. " before it") or ""), cmds)
        return
    end
    redraw()
end
local function togglePick(a, b)
    if search.picks[b] then
        search.picks[b] = nil
        for i, cfg in ipairs(search.pickList) do if cfg == b then table.remove(search.pickList, i); break end end
    else
        search.picks[b] = itemName(a, b)
        search.pickList[#search.pickList + 1] = b
    end
    local n = #search.pickList
    setStatus(n == 0 and "No items picked." or (n .. " picked. Spawn picked or Equip picked at the bottom."))
    redraw()
end
local function spawnPicked()
    if #search.pickList == 0 then setStatus("Click item rows to pick them first.", C.RED); redraw(); return end
    local cmds = {}
    for _, cfg in ipairs(search.pickList) do cmds[#cmds + 1] = (spawnCmd(cfg)) end
    run("Spawn " .. #cmds .. " picked", cmds)
end
local function equipPicked()
    if #search.pickList == 0 then setStatus("Click item rows to pick them first.", C.RED); redraw(); return end
    local cmds = {}
    for _, cfg in ipairs(search.pickList) do cmds[#cmds + 1] = "!give " .. gameName(cfg) .. " 1 worn" end
    run("Equip " .. #cmds .. " picked (worn slots in order)", cmds)
end
local function clearPicks()
    search.picks, search.pickList = {}, {}
    setStatus("Picks cleared.")
    redraw()
end

local function pressResult(r, which)
    local index = search.offset + r
    local line = search.results[index]
    if not line then return end
    local a, b, c = searchFields(line)
    if search.mode == 1 then                   -- an item: name, config name, id
        if which == "spawn" then spawnItem(a, b)
        elseif which == "equip" then equipItem(a, b)
        else togglePick(a, b) end
    elseif search.mode == 2 then               -- a title: title, switch
        run("Title: " .. (a ~= "" and a or b), { "!setvar " .. gameName(b) .. " 1" })
    elseif search.mode == 4 then               -- a place: name, map-element name, coordinate
        run("Go: " .. a, { "!tele " .. c })
    else                                       -- a var: name, kind, id
        search.picked = index
        local now = varValue(a, b)
        setStatus("Type a value, then Set. " .. a .. (now ~= nil and (" is " .. tostring(now) .. " now.") or " (value not readable here)."))
        redraw()
    end
end

local function searchAction()
    if search.mode == 1 then
        search.dest = search.dest == "bank" and "inv" or "bank"
        save()
        setStatus(search.dest == "bank" and "Spawned items go to the bank." or "Spawned items go to the backpack.")
        redraw()
    elseif search.mode == 4 then               -- My spot: where you stand, as a coordinate to type or save
        local coord = here()
        setStatus(coord and ("You're at " .. coord .. " (type that to come back).") or "Couldn't read where you're standing.", coord and C.GREEN or C.RED)
        redraw()
    elseif search.mode == 2 then
        if #search.results == 0 then setStatus("Search for titles first.", C.RED); redraw(); return end
        local cmds = {}
        for _, line in ipairs(search.results) do
            local _, sw = searchFields(line)
            cmds[#cmds + 1] = "!setvar " .. gameName(sw) .. " 1"
        end
        run("Unlock " .. #cmds .. " title" .. (#cmds == 1 and "" or "s"), cmds)
    else
        local line = search.picked and search.results[search.picked]
        if not line then setStatus("Pick a variable from the list first.", C.RED); redraw(); return end
        local name, kind = searchFields(line)
        local v = tonumber((tostring(search.value or ""):gsub("[,%s]", "")))
        if not v or v ~= math.floor(v) then setStatus("Type a whole number in the value box.", C.RED); redraw(); return end
        run(name .. " = " .. string.format("%d", v), { (kind == "c" and "!setvarc " or "!setvar ") .. gameName(name) .. " " .. string.format("%d", v) })
    end
end

local function buttons() return PAGES[page] and PAGES[page].buttons or {} end
local scroll = {}
local function pageScroll() return (PAGES[page] and scroll[page]) or 0 end   -- (0.1.73: LOOT scrolls too)
local function maxScroll() return math.max(0, math.ceil((#buttons() - 14) / 2) * 2) end
local function scrollBy(d)
    local to = math.max(0, math.min(maxScroll(), pageScroll() + d))
    if to ~= pageScroll() then scroll[page] = to; redraw() end
end

local function readVar(name)
    local v = get(function() return var.VarPlayer[name].value end)
    return type(v) == "number" and v or nil
end

local function isOpen(id) return get(function() return ui.Interfaces:GetInterface(id) end) ~= nil end
local GUESSES = { [364] = true, [168] = true }
local itemStatics = {}                          -- window id -> the statics that showed items (the drop log fills it)
local function rewardWindowOpen()
    for id in pairs(windows) do if (GUESSES[id] or itemStatics[id]) and isOpen(id) then return true end end
    return false
end
local DIALOGUES = { 1184, 1186, 1191 }
local function talking()
    for _, id in ipairs(DIALOGUES) do if isOpen(id) then return true end end
    return false
end
local function openWindows()
    local t = {}
    for id = 0, 1946 do if isOpen(id) then t[id] = true end end
    return t
end

local function keepArmed()
    if type(ExecuteConsoleCommand) ~= "function" then return end
    local open, talk
    for _, a in ipairs(KEEPS) do
        if armed[a.key] and a.quiet then          -- a FUN power: every game tick until it reads its value again
            local w = arming[a.key]
            if readVar(a.var) == a.value then
                arming[a.key] = nil
            else
                w = w or { wait = 0 }
                arming[a.key] = w
                if open == nil then open, talk = rewardWindowOpen(), talking() end
                if a.loot and talk and not open then
                    w.wait = math.min(w.wait, 15)
                end
                if a.loot and w.boxUp and not talk then w.wait = 0 end
                w.boxUp = talk
                if not (open or talk) or (a.loot and not open) then
                    w.wait = w.wait - 1
                    if w.wait <= 0 then
                        w.wait = (a.loot and talk) and 15 or 30
                        pcall(ExecuteConsoleCommand, "!setvar " .. a.var .. " " .. a.value)
                    end
                end
            end
        elseif armed[a.key] then
            local w = arming[a.key]
            if readVar(a.var) == a.value then
                if w and w.tries > 0 then
                    setStatus(a.short:sub(1, 1):upper() .. a.short:sub(2) .. " armed again.")
                    redraw()
                end
                arming[a.key] = nil
            else
                w = w or { tries = 0, wait = 0 }
                arming[a.key] = w
                if open == nil then open, talk = rewardWindowOpen(), talking() end
                w.heldFor = open and (w.heldFor or 0) + 1 or nil
                if open and w.heldFor <= 1500 then
                    if not w.held then
                        w.held = true
                        setStatus("Close the reward window (Esc) and the " .. a.short .. " arms again at once.")
                        redraw()
                    end
                else
                    if w.held then w.held, w.wait, w.tries = nil, 0, 0 end   -- it just closed: set it this tick
                    if talk then
                        w.talkFor = (w.talkFor or 0) + 1
                        if w.talkFor <= 1500 then w.tries = math.min(w.tries, 1) end   -- the quick tries, not 3 s
                        if not w.talkSaid then
                            w.talkSaid = true
                            setStatus("Close the dialogue (Space) and the " .. a.short .. " arms again at once.")
                            redraw()
                        end
                    elseif w.talkFor then
                        w.talkFor, w.talkSaid, w.wait, w.tries = nil, nil, 0, 0     -- it just closed: set it this tick
                    end
                    w.wait = w.wait - 1
                    if w.wait <= 0 then
                        w.tries = w.tries + 1
                        w.wait = (talk and w.talkFor <= 1500) and 15 or (w.tries <= 10 and 40 or 150)
                        pcall(ExecuteConsoleCommand, "!setvar " .. a.var .. " " .. a.value)
                        if w.tries == 1 and not talk then
                            setStatus("Arming " .. a.short .. " (close the reward window if one is open)")
                            redraw()
                        end
                    end
                end
            end
        end
    end
end

local function contents(invId)
    local inv = get(function() return Inventory.Find(invId) end)
    local slots = inv and get(function() return inv:GetSlots() end)
    if type(slots) ~= "table" then return nil end
    local t = {}
    for _, s in pairs(slots) do
        local obj = get(function() return s.obj end)
        local id = obj and get(function() return obj.id end)
        if type(id) == "number" and id >= 0 then
            t[id] = (t[id] or 0) + (tonumber(get(function() return s.count end)) or 1)
            if not dl.names[id] then dl.names[id] = get(function() return obj.name end) end
        end
    end
    return t
end
local function backpack() return contents(93) end

local function same(a, b)
    for k, v in pairs(a) do if b[k] ~= v then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

local function rewardSeen(invId, always)
    local now = contents(invId)
    if not now or next(now) == nil then dl.seen[invId] = nil; return end
    if not always and dl.seen[invId] and same(dl.seen[invId], now) then return end
    dl.seen[invId] = now
    dl.rewards[#dl.rewards + 1] = { at = dl.tick, inv = invId, items = now }
end

local function onInventory(event)
    local changed = event and get(function() return event.inv.id end)
    local known = false
    for _, invId in ipairs(REWARD_INVS) do
        if invId == changed then
            known = true
            rewardSeen(invId, true)               -- this list was just sent: the same items as last time still count
        else
            rewardSeen(invId, false)
        end
    end
    if type(changed) == "number" and not known and not NOT_REWARDS[changed] then
        dl.others[#dl.others + 1] = { at = dl.tick, inv = changed }   -- not used as loot; named in the console
    end
    local now = backpack()
    if not now then return end
    if dl.pack then
        local diff, any = {}, false
        for id, n in pairs(now) do
            local d = n - (dl.pack[id] or 0)
            if d > 0 then diff[id], any = d, true end
        end
        if any then dl.adds[#dl.adds + 1] = { at = dl.tick, diff = diff } end
    end
    dl.pack = now
end

local function itemName(id)
    if not dl.names[id] then dl.names[id] = get(function() return config.Obj.FromID(id).name end) end
    return dl.names[id] or ("Item " .. id)
end

local ALL_STATICS = {}
for static = 0, 80 do ALL_STATICS[#ALL_STATICS + 1] = static end
local function picturesIn(id, statics)
    local t, found = {}, {}
    for _, static in ipairs(statics) do
        local comp = get(function() return ui.Interfaces:GetComponent(id, static) end)
        if comp then
            local got = false
            local function take(c)
                local oid = get(function() return c.associatedObjectID end)
                if type(oid) == "number" and oid >= 0 then
                    local q = tonumber(get(function() return c.associatedObjectQuantity end)) or 1
                    t[oid] = (t[oid] or 0) + math.max(1, q)
                    got = true
                end
            end
            take(comp)
            pcall(function() comp:IterateDynamicComponents(take) end)
            if got then found[#found + 1] = static end
        end
    end
    if #found > 0 then return t, found end
end
local function windowLoot()
    for id in pairs(windows) do
        if isOpen(id) then
            local items = itemStatics[id] and picturesIn(id, itemStatics[id])
            if not items and dl.tick - (dl.fullAt or -1000) >= 10 then
                local found
                dl.fullAt = dl.tick
                items, found = picturesIn(id, ALL_STATICS)
                if items then itemStatics[id] = found end
            end
            if items then return items, id end
        end
    end
end

local function signature(items)
    local keys = {}
    for id, n in pairs(items) do keys[#keys + 1] = id .. "x" .. n end
    table.sort(keys)
    return table.concat(keys, ",")
end
local function holds(big, small)
    for id, n in pairs(small) do if (big[id] or 0) < n then return false end end
    return true
end
local function watchWindow()
    local items, win = windowLoot()
    if not items then
        if not rewardWindowOpen() then dl.winSig = nil end
        return
    end
    local sig = signature(items)
    if sig == dl.winSig then return end
    dl.winSig = sig
    if dl.tick <= 1 then return end                  -- a window already open when the kit starts isn't a new claim
    local last = dl.lastShown
    if last and not last.done and dl.tick - last.shownAt <= 15 and holds(items, last.direct) then
        last.direct = items                          -- the same claim, more of it shown
        return
    end
    local claim
    for _, c in ipairs(dl.claims) do
        if c.state and not c.shown and dl.tick - c.at <= 30 then claim = c; break end
    end
    if not claim then
        claim = { key = logSource().key, at = dl.tick }
        dl.claims[#dl.claims + 1] = claim
    end
    claim.shown, claim.direct, claim.window, claim.shownAt = true, items, win, dl.tick
    dl.lastShown = claim
end

local function watchSwitches()
    for _, s in ipairs(SOURCES) do
        local v = readVar(s.var)
        if v ~= nil then
            if dl.state[s.key] == s.value and v ~= s.value then
                local seen = false
                for _, c in ipairs(dl.claims) do
                    if c.shown and not c.state and dl.tick - c.at <= 30 then c.state, seen = true, true; break end
                end
                if not seen then dl.claims[#dl.claims + 1] = { key = s.key, at = dl.tick, state = true } end
                drops.current = s.key                     -- 0.1.71: the drop log follows the loot
                if dl.baseline and dl.scans < 3 then dl.scanAt = dl.tick + 5 end
            elseif v == s.value and dl.state[s.key] ~= s.value and dl.scans < 3 then
                dl.baseline = openWindows()
            end
            dl.state[s.key] = v
        end
    end
    if dl.scanAt and dl.tick >= dl.scanAt then
        local now, new = openWindows(), {}
        for id in pairs(now) do if not dl.baseline[id] then new[#new + 1] = id end end
        table.sort(new)
        dl.scanAt, dl.scans = nil, dl.scans + 1
        local learned = false
        for _, id in ipairs(new) do
            if not windows[id] and picturesIn(id, ALL_STATICS) then    -- (0.1.8: only a window that shows loot)
                windows[id] = true; learnedWindows[#learnedWindows + 1] = id; learned = true
            end
        end
        if learned then save() end
        if #new > 0 then
            log("Dev Kit: the oyster claim opened window " .. table.concat(new, ", ") ..
                (learned and " - Keep armed now arms the moment it closes" or ""))
        end
    end
end

local function guarded(what, fn, ...)
    local ok, problem = pcall(fn, ...)
    if not ok and not dl.errors[what] then
        dl.errors[what] = true
        log("Dev Kit drop log (" .. what .. "): " .. tostring(problem))
    end
end

local function price(id) return PRICES.gp[id] or 0 end

local function record(key, loot)
    local d = drops[key]
    d.claims = d.claims + 1
    local any, worth = false, 0
    for id, n in pairs(loot) do
        any = true
        local k = tostring(id)
        local e = d.items[k] or { id = id, name = itemName(id), qty = 0, hits = 0 }
        e.qty, e.hits = e.qty + n, e.hits + 1
        d.items[k] = e
        worth = worth + n * price(id)
    end
    if not any then d.empty = d.empty + 1 end
    d.best = math.max(tonumber(d.best) or 0, worth)
    dl.dirty = true
    return worth
end
local onClaim                                   -- the drop log window's reaction to a claim (made with the window)

local function near(e, c) return not e.used and e.at >= c.at - BEFORE and e.at <= c.at + AFTER end

local function logTick()
    dl.tick = dl.tick + 1
    watchSwitches()
    watchWindow()
    while dl.claims[1] and dl.tick >= dl.claims[1].at + AFTER do
        local c = table.remove(dl.claims, 1)
        c.done = true
        local loot, best, from = {}, nil, nil
        for _, r in ipairs(dl.rewards) do
            if near(r, c) and (not best or math.abs(r.at - c.at) < math.abs(best.at - c.at)) then best = r end
        end
        if c.direct then                            -- what the REWARDS window pictured comes first
            for id, n in pairs(c.direct) do loot[id] = n; itemName(id) end
            if best then
                for _, r in ipairs(dl.rewards) do if near(r, c) and same(r.items, best.items) then r.used = true end end
            end
            from = "loot from the reward window's pictures (window " .. tostring(c.window) .. ")"
        elseif best then
            for _, r in ipairs(dl.rewards) do       -- that list, and the game sending it again, belong to this claim
                if near(r, c) and r.inv == best.inv and same(r.items, best.items) then r.used = true end
            end
            for id, n in pairs(best.items) do loot[id] = n end
            from = "loot from the reward window (inventory " .. best.inv .. ")"
        else
            for _, a in ipairs(dl.adds) do
                if near(a, c) then
                    a.used = true
                    for id, n in pairs(a.diff) do loot[id] = (loot[id] or 0) + n end
                end
            end
            from = next(loot) and "loot from the backpack" or "no loot seen"
            local ids = {}
            for _, o in ipairs(dl.others) do
                if o.at >= c.at - BEFORE and o.at <= c.at + AFTER then ids[#ids + 1] = tostring(o.inv) end
            end
            if #ids > 0 then from = from .. "; other inventories changed: " .. table.concat(ids, ", ") end
        end
        local worth = record(c.key, loot)
        if onClaim then onClaim(c.key, loot, worth) end
        if dl.told < 3 then                         -- the first few claims a session say where their loot was read
            dl.told = dl.told + 1
            log("Dev Kit: " .. c.key .. " claim logged, " .. from)
        end
    end
    while dl.adds[1] and dl.adds[1].at < dl.tick - 200 do table.remove(dl.adds, 1) end
    while dl.rewards[1] and dl.rewards[1].at < dl.tick - 200 do table.remove(dl.rewards, 1) end
    while dl.others[1] and dl.others[1].at < dl.tick - 200 do table.remove(dl.others, 1) end
    if dl.dirty and dl.tick % 250 == 0 then
        dl.dirty = false
        pcall(function() PersistentDB:SetStructuredData("devKitDrops", drops) end)
    end
end

local function dropRows(key)
    local list = {}
    for k, e in pairs(drops[key].items) do
        e.id = tonumber(e.id) or tonumber(k)
        e.value = e.qty * price(e.id)
        list[#list + 1] = e
    end
    table.sort(list, function(a, b)
        if a.value ~= b.value then return a.value > b.value end
        if a.hits ~= b.hits then return a.hits < b.hits end
        return tostring(a.name) < tostring(b.name)
    end)
    return list
end

local function rate(hits, claims)
    if hits <= 0 or claims <= 0 then return "" end
    local every, pct = claims / hits, hits * 100 / claims
    local one = (every >= 10 or every == math.floor(every)) and string.format("%d", math.floor(every + 0.5)) or string.format("%.1f", every)
    return "1/" .. one .. " (" .. (pct >= 10 and string.format("%d", math.floor(pct + 0.5)) or string.format("%.1f", pct)) .. "%)"
end

local function wipeCheck(what)
    local pack = contents(93)
    if not pack then
        setStatus("Couldn't read your backpack.", C.RED)
        return nil
    end
    local items, aug = 0, 0
    for itemId in pairs(pack) do
        items = items + 1
        if tostring(itemName(itemId)):find("^Augmented") then aug = aug + 1 end
    end
    if aug > 0 and tool.confirm ~= what then
        tool.confirm, tool.junkAt = what, dl.tick
        setStatus(aug .. " augmented item" .. (aug == 1 and "" or "s") .. " would be wiped too! Press again within 3 s.", C.RED)
        return nil
    end
    tool.confirm, tool.junkAt = nil, nil
    return items
end

local function clearJunk()
    local items = wipeCheck("junk")
    if items == 0 then
        setStatus("Your backpack is already empty.")
    elseif items then
        run("Clear junk", { "!clearinv" })
        return
    end
    redraw()
end

local function savePreset()
    local inv = get(function() return Inventory.Find(93) end)
    local slots = inv and get(function() return inv:GetSlots() end)
    if type(slots) ~= "table" then
        setStatus("Couldn't read your backpack.", C.RED)
        redraw()
        return
    end
    local list, skipped = {}, 0
    for _, s in ipairs(slots) do
        local oid = get(function() return s.obj.id end)
        if type(oid) == "number" and oid >= 0 then
            local cfg = get(function() return config.Obj.FromID(oid).configName end)
            local n = math.max(1, math.floor(tonumber(get(function() return s.count end)) or 1))
            if type(cfg) == "string" and cfg:match("^%S+$") then list[#list + 1] = cfg .. " " .. n else skipped = skipped + 1 end
        end
    end
    if #list == 0 then
        setStatus("Your backpack is empty: nothing to save.", C.RED)
    else
        presets[tool.preset] = list
        save()
        setStatus("Preset " .. tool.preset .. " saved: " .. #list .. " item" .. (#list == 1 and "" or "s") ..
            (skipped > 0 and (" (" .. skipped .. " without a name skipped)") or "") .. ".")
    end
    redraw()
end

local EGG_GEAR = {
    { "NEX2_MAGIC_WAND_AUGMENTED", 1 }, { "NEX2_MAGIC_OFFHAND_AUGMENTED", 1 },
    { "GANODERMIC_PONCHO_AUGMENTED", 2 }, { "GANODERMIC_LEGGINGS_AUGMENTED", 2 },   -- (gizmos each)
}
local function freeSlots(n)
    local inv = get(function() return Inventory.Find(93) end)
    local free = {}
    for i = 1, 28 do
        local s = inv and get(function() return inv:GetSlot(i) end)
        local oid = s and get(function() return s.obj.id end)
        if not s or type(oid) ~= "number" or oid < 0 then free[#free + 1] = i - 1 end
        if #free == n then break end
    end
    if not inv or #free < n then return nil, #free end
    return free
end
local function eggHunt()
    local free, have = freeSlots(#EGG_GEAR)
    if not free then
        setStatus("Egg Hunt needs " .. #EGG_GEAR .. " free backpack slots (" .. have .. " now).", C.RED)
        redraw()
        return
    end
    local cmds = {}
    for _, g in ipairs(EGG_GEAR) do cmds[#cmds + 1] = "!give " .. g[1] end
    for k, g in ipairs(EGG_GEAR) do
        for gizmo = 1, g[2] do cmds[#cmds + 1] = "!inventsetperks " .. free[k] .. " 51 6 51 6 " .. gizmo end
    end
    for _, c in ipairs({ "!setvar TEST_GODMODE_HP 1", "!setvar TEST_GODMODE_PRAY 1", "!setvar TEST_GODMODE_SPEC 1",
                         "!setvar TEST_GODMODE_COMBAT 1", "!setvar EASTER2019_PET_EGG_UNLOCKED 0",
                         "!setvar EASTER2019_PET_EGG_2_UNLOCKED 0", "!give DUNGEON_DRAGONFORT_TELETAB 10",
                         "!give DUNGEON_DRAGONFORT_DROP_ENHANCER 100" }) do
        cmds[#cmds + 1] = c
    end
    run("Egg Hunt (wear the 4, break a lab tab)", cmds)
end

local function pressButton(b)
    if b.special == "egg" then eggHunt(); return end
    if b.special == "hp" then                     -- 0.1.21: a share of your real max life points (god mode's refill off first)
        local max = readVar("MAXLIFEPOINTS")
        if not max or max <= 0 then
            setStatus("Couldn't read your max life points.", C.RED)
            redraw()
            return
        end
        run(b.label, { "!setvar TEST_GODMODE_HP 0", "!setvar LIFEPOINTS " .. math.max(1, math.floor(max * (b.frac or 0.5))) })
        return
    end
    if b.special == "cds_on" or b.special == "cds_off" then
        clearCds = b.special == "cds_on"
        save()
        run(b.label, b.cmds)
        return
    end
    local free, have = {}, 0
    if b.gear then
        free, have = freeSlots(#b.gear)
        if not free then
            setStatus(b.label .. " needs " .. #b.gear .. " free backpack slots (" .. have .. " now).", C.RED)
            redraw()
            return
        end
    end
    if b.flip then                                -- 0.1.54: the game switch to its other state
        local on = flipOn(b.flip)
        flips[b.flip] = not on
        save()
        run(b.label .. (on and ": off" or ": on"), { "!setvar " .. b.flip .. " " .. (on and 0 or 1) })
        return
    end
    if b.special == "droplog" then                -- 0.1.73 (LOOT): open or close the drop log; it keeps logging either way
        setLogGone(not logOff)
        setStatus(logOff and "Drop log closed. It keeps logging and saving." or "Drop log open.")
        redraw()
        return
    end
    if b.toggle then                              -- 0.1.38 FUN: one button flips its powers' keeps on or off
        local on = not toggleOn(b)
        for key in b.toggle:gmatch("[^,]+") do armed[key], arming[key] = on, nil end
        save()
        if #(on and b.cmds or b.offCmds) > 0 then
            run(b.label .. (on and ": on" or ": off"), on and b.cmds or b.offCmds)
        else                                      -- (0.1.73: LOOT's Keep armed switches have no commands of their own)
            setStatus(b.label .. (on and ": on. Claim, close the reward window, claim again." or ": off."))
            redraw()
        end
        return
    end
    if b.keep ~= nil then                         -- (only once the button really runs)
        local key = b.keepKey or "myst"           -- 0.1.36: FUN's powers name their own keep
        armed[key], arming[key] = b.keep == true, nil
        save()
    end
    if not b.gear then run(b.label, b.cmds); return end
    local cmds = {}
    for _, g in ipairs(b.gear) do cmds[#cmds + 1] = "!give " .. g[1] end
    for k, g in ipairs(b.gear) do
        for gizmo = 1, g[2] do cmds[#cmds + 1] = "!inventsetperks " .. free[k] .. " " .. (g[2 + gizmo] or "51 6 51 6") .. " " .. gizmo end
    end
    for _, c in ipairs(b.cmds) do cmds[#cmds + 1] = c end
    run(b.label, cmds)
end

local function loadPreset()
    local list = presets[tool.preset]
    if not list then
        setStatus("Preset " .. tool.preset .. " is empty. Save one first.", C.RED)
        redraw()
        return
    end
    if not wipeCheck("load") then redraw(); return end
    local cmds = { "!clearinv" }
    for _, line in ipairs(list) do cmds[#cmds + 1] = "!give " .. line end
    run("Load preset " .. tool.preset, cmds)
end

local tabAreas, gridAreas, goAreas, delAreas, nameFields = {}, {}, {}, {}, {}
local toolAreas = { pick = {} }
local searchAreas = { modes = {}, rows = {}, spawn = {}, equip = {}, picks = {} }   -- SEARCH's click areas (0.1.86: 26)
local scrollUp, scrollDown                     -- the scroll bar's two halves (made with the window)
local function drawTools(paint)
    local pick = SKILLS[tool.skill]
    paint:Button(L.x, toolRow(1), L.w, L.rowH, "Skill: " .. pick[1] .. (tool.picking and "   (pick one below)" or "   (press to change)"), tool.picking)
    if tool.picking then
        for i, s in ipairs(SKILLS) do
            local x, y, w, h = pickCell(i)
            paint:Button(x, y, w, h, s[1], i == tool.skill)
        end
        return
    end
    paint:Glass(L.x, toolRow(2) - 1, 150, 29)                            -- (the number box sits on this)
    paint:Button(L.x + 156, toolRow(2), 102, L.rowH, "Set level", false)
    paint:Button(L.x + 264, toolRow(2), 102, L.rowH, "Set XP", false)
    paint:Button(L.x + 372, toolRow(2), 102, L.rowH, "Add XP", false)
    paint:Button(L.x, toolRow(3), L.colW, L.rowH, tool.confirm == "junk" and "Press again to clear" or "Clear junk", tool.confirm == "junk")
    paint:Button(L.x + L.colW + 6, toolRow(3), L.colW, L.rowH, "Grace porters (26)", false)
    paint:Button(L.x, toolRow(4), 150, L.rowH, "Preset " .. tool.preset .. " of " .. PRESETS, false)
    paint:Button(L.x + 156, toolRow(4), 156, L.rowH, "Save inventory", false)
    paint:Button(L.x + 318, toolRow(4), 156, L.rowH, tool.confirm == "load" and "Press again to load" or "Load inventory", tool.confirm == "load")
    local list = presets[tool.preset]
    paint:Button(L.x, toolRow(5), L.w, L.rowH, "Egg Hunt: Dragonkin Lab, Mysterious 6 gear, god mode", false)
    paint:Text(L.x + 9, toolRow(6) + 3, L.w - 18, 24, list and ("Preset " .. tool.preset .. ": " .. #list .. " item" .. (#list == 1 and "" or "s") ..
        " (perks and charges come back fresh)") or ("Preset " .. tool.preset .. " is empty."), C.FADED)
    paint:Text(L.x + 9, toolRow(7) + 3, L.w - 18, 24, "Box: a level (1-120) or XP (13m, 250k). Clear junk/Load wipe the backpack.", C.FADED)
end
local function searchRowY(r) return toolRow(3) + (r - 1) * SEARCH_ROW_H end
local function drawSearch(paint)
    for i, m in ipairs(SEARCH_MODES) do
        paint:Button(L.x + (i - 1) * 120, toolRow(1), 114, L.rowH, m.label, i == search.mode)
    end
    paint:Glass(L.x, toolRow(2) - 1, 270, 29)                            -- (the search box sits on this)
    paint:Glass(L.x + 276, toolRow(2) - 1, 96, 29)                       -- (and the amount / value box on this)
    local action = search.mode == 1 and ("To: " .. (search.dest == "bank" and "bank" or "backpack")) or search.mode == 2 and "Unlock all"
        or search.mode == 4 and "My spot" or "Set"
    paint:Button(L.x + 378, toolRow(2), 96, L.rowH, action, search.mode == 1 and search.dest == "bank")
    if search.mode == 1 then                                              -- (0.1.86) the picks' buttons, under the rows
        local by, n = searchRowY(SEARCH_ROWS) + SEARCH_ROW_H + 6, #search.pickList
        paint:Button(L.x, by, 154, 24, "Spawn picked (" .. n .. ")", n > 0)
        paint:Button(L.x + 160, by, 154, 24, "Equip picked (" .. n .. ")", n > 0)
        paint:Button(L.x + 320, by, 154, 24, "Clear picks", false)
    end
    paint:Glass(L.x, searchRowY(1) - 3, L.w, SEARCH_ROWS * SEARCH_ROW_H + 3)
    if #search.results == 0 then
        local hint = search.mode == 1 and "Type any words of an item's name, e.g. hair only, partyhat, do not translate."
            or search.mode == 2 and "Type any words of a title, e.g. slayer, the eternal, imps."
            or search.mode == 4 and "Any place: words (vault, basement), 3200 3200, square 50 50 or region 12850."
            or "Type any words of a variable's name, e.g. godmode, debug, cooldown."
        paint:Text(L.x + 9, searchRowY(1), L.w - 18, SEARCH_ROW_H, hint, C.FADED)
    end
    for r = 1, SEARCH_ROWS do
        local index = search.offset + r
        local line = search.results[index]
        if not line then break end
        local a, b, c = searchFields(line)
        local y = searchRowY(r)
        if index == search.picked or (search.mode == 1 and search.picks[b]) then
            paint:Rect(L.x + 3, y, L.w - 6, SEARCH_ROW_H - 2, search.mode == 1 and C.GOLD_DARK or C.GLASS_LIGHT)
        end
        local left, right
        if search.mode == 1 then left, right = (a ~= "" and a or "(no name)"), b
        elseif search.mode == 2 then left, right = (a ~= "" and a or b), b
        elseif search.mode == 4 then left, right = a, c .. "  " .. b
        else left, right = a, (VAR_KINDS[b] or b) .. " " .. c end
        if search.mode == 1 then                                          -- an item row: name, config, Spawn, Equip
            paint:Text(L.x + 9, y, 168, SEARCH_ROW_H, left, C.CREAM)
            paint:Text(L.x + 183, y, L.w - 306, SEARCH_ROW_H, right, C.FADED)
            paint:Button(L.x + L.w - 117, y + 1, 54, SEARCH_ROW_H - 2, "Spawn", false)
            paint:Button(L.x + L.w - 60, y + 1, 54, SEARCH_ROW_H - 2, "Equip", false)
        else
            paint:Text(L.x + 9, y, 222, SEARCH_ROW_H, left, C.CREAM)
            paint:Text(L.x + 237, y, L.w - 246, SEARCH_ROW_H, right, C.FADED)
        end
    end
    if search.total > SEARCH_ROWS then                                    -- where in the list: a thumb in the right margin
        local trackY, trackH = searchRowY(1), SEARCH_ROWS * SEARCH_ROW_H
        local shown = math.min(search.total, SEARCH_CAP)
        paint:Glass(L.x + L.w + 1, trackY, 5, trackH)
        local thumbH = math.max(12, math.floor(trackH * SEARCH_ROWS / shown))
        local most = math.max(1, shown - SEARCH_ROWS)
        paint:Gold(L.x + L.w + 1, trackY + math.floor((trackH - thumbH) * search.offset / most), 5, thumbH)
    end
end
local function draw(paint)
    for i, name in ipairs(TABS) do
        local tx, ty = tabAt(i)
        paint:Button(tx, ty, L.tabW, 27, name, i == page)
    end
    if page == TOOLS then
        drawTools(paint)
    elseif page == SEARCH then
        drawSearch(paint)
    elseif page == TELEPORT then
        local x, y, w, h = cell(1)
        paint:Button(x, y, w, h, "Save this spot", false)
        x, y, w, h = cell(2)
        paint:Button(x, y, w, h, "Grand Exchange", false)
        paint:Glass(L.x, spotRow(1) - 3, L.w, MAX_SPOTS * L.step + 3)
        if #spots == 0 then
            paint:Text(L.x + 9, spotRow(1) + 3, L.w - 18, 24, "No spots saved yet. Stand somewhere and press Save this spot.", C.FADED)
        end
        for r, coord in ipairs(spots) do
            local ry = spotRow(r)
            paint:Text(L.x + 201, ry + 3, 108, 24, coord, C.FADED)       -- (the name is the text box to its left)
            paint:Button(L.x + 312, ry, 96, 24, "GO", false)
            paint:Button(L.x + 414, ry, 54, 24, "X", false)
        end
    else
        local first = pageScroll()
        for i = 1, 14 do
            local b = buttons()[first + i]
            if not b then break end
            local x, y, w, h = cell(i)
            if b.special == "droplog" then        -- 0.1.73: the drop log's switch is a LOOT button
                paint:Button(x, y, w, h, logOff and "Drop log: closed (still logging)" or "Drop log: open", not logOff)
            elseif b.flip then                    -- 0.1.54: a game switch, as the kit last set it (0.1.56), gold while on
                local on = flipOn(b.flip)
                paint:Button(x, y, w, h, b.label .. ": " .. (on and "on" or "off"), on)
            elseif b.toggle then                  -- a FUN power: gold while on
                paint:Button(x, y, w, h, b.label .. ": " .. (toggleOn(b) and "on" or "off"), toggleOn(b))
            else
                local lit = current ~= nil and current.label == b.label
                paint:Button(x, y, w, h, b.label .. (#b.cmds > 1 and (" (" .. #b.cmds .. ")") or ""), lit)
            end
        end
        if maxScroll() > 0 then                   -- the scroll bar: a gold thumb on a dark track, in the right margin
            local trackY, trackH = L.gridY, 7 * L.step - 6
            paint:Glass(L.x + L.w + 1, trackY, 5, trackH)
            local rows = math.ceil(#buttons() / 2)
            local thumbH = math.max(18, math.floor(trackH * 7 / rows))
            paint:Gold(L.x + L.w + 1, trackY + math.floor((trackH - thumbH) * first / maxScroll()), 5, thumbH)
        end
    end
    paint:LCD(L.x, L.lcdY, L.w, 30)
    paint:Text(L.x + 9, L.lcdY + 3, L.w - 18, 24, status, statusColour)
end

redraw = function()
    if not window then return end
    local shownCells = math.min(14, #buttons() - pageScroll())
    if scrollUp then scrollUp.hidden, scrollDown.hidden = maxScroll() == 0, maxScroll() == 0 end
    for i, a in ipairs(gridAreas) do
        a.hidden = not ((page == TELEPORT and i <= 2) or (page ~= TELEPORT and i <= shownCells))
    end
    for r = 1, MAX_SPOTS do
        local shown = page == TELEPORT and spots[r] ~= nil
        goAreas[r].hidden, delAreas[r].hidden = not shown, not shown
        if nameFields[r] then
            nameFields[r].hidden = not shown
            local want = spots[r] and (spotNames[r] or ("Spot " .. r)) or ""
            if nameFields[r].content ~= want then nameFields[r].content = want end
        end
    end
    local onTools, listOpen = page == TOOLS, page == TOOLS and tool.picking
    if toolAreas.skill then
        toolAreas.skill.hidden = not onTools
        for _, a in ipairs(toolAreas.pick) do a.hidden = not listOpen end
        for _, k in ipairs({ "level", "xp", "add", "junk", "grace", "preset", "save", "load", "egg" }) do toolAreas[k].hidden = not onTools or listOpen end
    end
    if tool.field then tool.field.hidden = not onTools or listOpen end
    local onSearch = page == SEARCH
    if searchAreas.action then
        for _, a in ipairs(searchAreas.modes) do a.hidden = not onSearch end
        searchAreas.action.hidden = not onSearch
        for r, a in ipairs(searchAreas.rows) do
            local gone = not onSearch or search.results[search.offset + r] == nil
            a.hidden, searchAreas.spawn[r].hidden, searchAreas.equip[r].hidden = gone, gone, gone
        end
        for _, a in ipairs(searchAreas.picks) do a.hidden = not onSearch or search.mode ~= 1 end
    end
    if search.field then search.field.hidden, search.valueField.hidden = not onSearch, not onSearch end
    window:Redraw(draw)
end

local function pressCell(i)
    if page == TELEPORT then
        if i == 1 then
            local coord = here()
            if not coord then
                setStatus("Couldn't read where you're standing.", C.RED)
            elseif #spots >= MAX_SPOTS then
                setStatus("All " .. MAX_SPOTS .. " spots are used. Press X on one first.", C.RED)
            else
                spots[#spots + 1] = coord
                spotNames[#spots] = "Spot " .. #spots
                save()
                setStatus("Saved spot " .. #spots .. ": " .. coord)
            end
            redraw()
        elseif i == 2 then
            run("Grand Exchange", { "!tele grandexchange" })
        end
        return
    end
    local b = buttons()[pageScroll() + i]
    if b then pressButton(b) end
end

local layer = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__PLUGIN_BUILD_LAYER_TOP)
local screenW = get(function() return layer.width end) or 1920
local startX = tonumber(saved.x) or (screenW - W - 420)
local startY = tonumber(saved.y) or 120
window = RetroUI.Window(layer, {
    width = W, height = H, title = "DEV KIT", x = startX, y = startY,
    onMove = function() save() end,
    onHide = function() save() end,
})
layout()
for i = 1, #SEARCH_MODES do
    searchAreas.modes[i] = window:Area(L.x + (i - 1) * 120, toolRow(1), 114, L.rowH, function()
        if search.mode ~= i then
            search.mode = i
            save()
            runSearch()
            if search.text:match("%S") == nil then setStatus(SEARCH_MODES[i].label .. ": type to search.") end
        end
        redraw()
    end)
end
searchAreas.action = window:Area(L.x + 378, toolRow(2), 96, L.rowH, function() searchAction() end)
local function searchScroll(delta)
    if type(delta) ~= "number" or delta == 0 then return end
    local most = math.max(0, #search.results - SEARCH_ROWS)
    search.offset = math.max(0, math.min(most, search.offset + (delta > 0 and 4 or -4)))
    redraw()
end
for r = 1, SEARCH_ROWS do
    local y = toolRow(3) + (r - 1) * SEARCH_ROW_H
    searchAreas.rows[r] = window:Area(L.x, y, L.w - 120, SEARCH_ROW_H, function() pressResult(r, "row") end, searchScroll)
    searchAreas.spawn[r] = window:Area(L.x + L.w - 117, y, 54, SEARCH_ROW_H, function() pressResult(r, search.mode == 1 and "spawn" or "row") end, searchScroll)
    searchAreas.equip[r] = window:Area(L.x + L.w - 60, y, 54, SEARCH_ROW_H, function() pressResult(r, search.mode == 1 and "equip" or "row") end, searchScroll)
end
local pickY = toolRow(3) + SEARCH_ROWS * SEARCH_ROW_H + 6
searchAreas.picks[1] = window:Area(L.x, pickY, 154, 24, function() spawnPicked() end)
searchAreas.picks[2] = window:Area(L.x + 160, pickY, 154, 24, function() equipPicked() end)
searchAreas.picks[3] = window:Area(L.x + 320, pickY, 154, 24, function() clearPicks() end)
local barH = math.floor((7 * L.step - 6) / 2)
scrollUp = window:Area(L.x + L.w, L.gridY, 6, barH, function() scrollBy(-2) end)
scrollDown = window:Area(L.x + L.w, L.gridY + barH, 6, barH, function() scrollBy(2) end)
toolAreas.skill = window:Area(L.x, toolRow(1), L.w, L.rowH, function()
    tool.picking = not tool.picking
    redraw()
end)
for i = 1, #SKILLS do
    local x, y, w, h = pickCell(i)
    toolAreas.pick[i] = window:Area(x, y, w, h, function()
        tool.skill, tool.picking = i, false
        save()
        setStatus("Skill: " .. SKILLS[i][1] .. ". Type a number, then Set level, Set XP or Add XP.")
        redraw()
    end)
end
toolAreas.level = window:Area(L.x + 156, toolRow(2), 102, L.rowH, function() toolSkills("level") end)
toolAreas.xp = window:Area(L.x + 264, toolRow(2), 102, L.rowH, function() toolSkills("xp") end)
toolAreas.add = window:Area(L.x + 372, toolRow(2), 102, L.rowH, function() toolSkills("add") end)
toolAreas.junk = window:Area(L.x, toolRow(3), L.colW, L.rowH, function() clearJunk() end)
toolAreas.grace = window:Area(L.x + L.colW + 6, toolRow(3), L.colW, L.rowH, function()
    run("Grace porters, now Charge all porters", { "!give DIV_SIGN_PORTER7 26" })
end)
toolAreas.preset = window:Area(L.x, toolRow(4), 150, L.rowH, function()
    tool.preset, tool.confirm, tool.junkAt = tool.preset % PRESETS + 1, nil, nil
    save()
    redraw()
end)
toolAreas.save = window:Area(L.x + 156, toolRow(4), 156, L.rowH, function() savePreset() end)
toolAreas.load = window:Area(L.x + 318, toolRow(4), 156, L.rowH, function() loadPreset() end)
toolAreas.egg = window:Area(L.x, toolRow(5), L.w, L.rowH, function() eggHunt() end)
for i = 1, #TABS do
    local tx, ty = tabAt(i)
    tabAreas[i] = window:Area(tx, ty, L.tabW, 27, function()
        page, tool.picking = i, false
        save()
        redraw()
    end)
end
for i = 1, 14 do
    local x, y, w, h = cell(i)
    gridAreas[i] = window:Area(x, y, w, h, function() pressCell(i) end, function(delta)
        if type(delta) == "number" and delta ~= 0 then scrollBy(delta > 0 and 2 or -2) end
    end)
end
for r = 1, MAX_SPOTS do
    local ry = spotRow(r)
    goAreas[r] = window:Area(L.x + 312, ry, 96, 24, function()
        if spots[r] then run(spotNames[r] or ("Spot " .. r), { "!tele " .. spots[r] }) end
    end)
    nameFields[r] = window:Field(L.x + 9, ry, 186, spotNames[r] or "", function(text)
        if not spots[r] then return end
        local name = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""):sub(1, 24)
        if name ~= "" and name ~= spotNames[r] then spotNames[r] = name; save() end
    end)
    delAreas[r] = window:Area(L.x + 414, ry, 54, 24, function()
        if spots[r] then
            local gone = spotNames[r] or ("Spot " .. r)
            table.remove(spots, r)
            table.remove(spotNames, r)
            save()
            setStatus(gone .. " removed.")
            redraw()
        end
    end)
end
tool.field = window:Field(L.x + 6, toolRow(2) + 1, 138, "", function(text) tool.typed = text end)
search.field = window:Field(L.x + 6, toolRow(2) + 1, 258, "", function(text)
    search.text, search.dirtyAt = tostring(text or ""), search.tick
end)
search.valueField = window:Field(L.x + 282, toolRow(2) + 1, 84, search.value, function(text) search.value = tostring(text or "") end)
if saved.hidden == true then window:SetHidden(true) end
redraw()

local BASE_W, BASE_H, COL_STEP, ROW_H = 432, 321, 384, 36   -- one column, no rows; each column adds 384, each row 36
local STRIPE, GHOST, RARE = 0x13222FFF, 0x1C2618FF, 0xC77DFFFF
local logView = { offset = 0, resetAt = nil, flash = nil, banner = nil }   -- flash: { items, at }; banner: { text, at }
local LL = {}                                   -- the log's layout, inside its cabinet
local icons, shownIds, iconAt = {}, {}, {}      -- game item pictures (made as needed), the item each shows, where each is

local DIGITS = {
    ["0"] = { "###", "#.#", "#.#", "#.#", "###" }, ["1"] = { ".#.", "##.", ".#.", ".#.", "###" },
    ["2"] = { "###", "..#", "###", "#..", "###" }, ["3"] = { "###", "..#", ".##", "..#", "###" },
    ["4"] = { "#.#", "#.#", "###", "..#", "..#" }, ["5"] = { "###", "#..", "###", "..#", "###" },
    ["6"] = { "###", "#..", "###", "#.#", "###" }, ["7"] = { "###", "..#", ".#.", ".#.", ".#." },
    ["8"] = { "###", "#.#", "###", "#.#", "###" }, ["9"] = { "###", "#.#", "###", "..#", "###" },
    [","] = { "..", "..", "..", ".#", "#." },
}
local function bigNumber(paint, x, y, text, colour)
    for ch in text:gmatch(".") do
        local rows = DIGITS[ch]
        if rows then
            if ch ~= "," then paint:Sprite(x, y, DIGITS["8"], { ["#"] = GHOST }, 6) end
            paint:Sprite(x, y, rows, { ["#"] = colour }, 6)
            x = x + (#rows[1] + 1) * 6
        end
    end
    return x
end

local function commas(n)
    local s = tostring(math.floor(n + 0.5))
    while true do
        local done
        s, done = s:gsub("^(%d+)(%d%d%d)", "%1,%2")
        if done == 0 then return s end
    end
end
local function short(n)                         -- 950, 12.3k, 450k, 1.25m, 12.5m, 1.25b
    local function cut(v, unit)                 -- (no trailing zeros: 64k, not 64.0k)
        local t
        if v >= 100 then t = string.format("%d", math.floor(v))
        elseif v >= 10 then t = string.format("%.1f", math.floor(v * 10) / 10)
        else t = string.format("%.2f", math.floor(v * 100) / 100) end
        if t:find(".", 1, true) then t = t:gsub("0+$", ""):gsub("%.$", "") end
        return t .. unit
    end
    if n >= 1e9 then return cut(n / 1e9, "b") end
    if n >= 1e6 then return cut(n / 1e6, "m") end
    if n >= 1e4 then return cut(n / 1e3, "k") end
    return commas(n)
end

local function totalValue(key)
    local t = 0
    for _, e in pairs(drops[key].items) do t = t + e.qty * price(tonumber(e.id) or 0) end
    return t
end

local BROADCASTS = { ["backstab cape"] = true, ["sack of effigies"] = true, ["golden compass"] = true }
local function broadcast(name)
    local n = tostring(name or ""):lower()
    return n:find(" dye$") ~= nil or n:find("^third[%- ]age") ~= nil or n:find("^second[%- ]age") ~= nil
        or n:find("^explosive barrel") ~= nil or BROADCASTS[n] == true
end

local function tier(e, claims)
    local each, pct = price(e.id), claims > 0 and e.hits / claims or 1
    if pct <= 0.01 or broadcast(e.name) or each >= 10000000 then return RARE, true end
    if pct <= 0.05 or each >= 1000000 then return C.GOLD_LIGHT, false end
    return C.CREAM, false
end

local function listShape()
    local cols = math.max(1, math.min(3, 1 + math.floor((LL.w - (BASE_W - 60)) / COL_STEP)))
    local rows = math.max(1, math.floor((LL.footY - 6 - LL.listY - 6) / ROW_H))
    return cols, rows, math.floor((LL.w - (cols - 1) * 12) / cols)
end

local function iconFor(i)
    if icons[i] == nil then
        local icon = get(function() return ui.Sprite.new(logWindow.layer) end)
        if icon then
            pcall(function() icon:SetSize(36, 32) end)
            pcall(function() icon.clickthrough = true end)
            pcall(function() icon.associatedObjectQuantityMode = ui.ObjectQuantityDisplayMode.NEVER end)
            icon.hidden = true
        end
        icons[i] = icon or false
    end
    return icons[i] or nil
end

local function drawLog(paint)
    local s = logSource()
    if logView.source ~= s.key then logView.source, logView.offset = s.key, 0 end   -- (a new source starts at the top)
    local d = drops[s.key]
    local x, w, y0 = LL.x, LL.w, LL.y
    paint:Button(x, y0, w, 27, s.name:upper() .. "   " .. commas(d.claims), true)      -- the source's name plate
    local total = totalValue(s.key)
    local read = d.claims - d.empty                 -- claims whose loot was seen: the rates and average use these
    paint:LCD(x, y0 + 33, w, 69)
    paint:Text(x + 9, y0 + 36, 200, 18, "TOTAL LOOT VALUE", C.FADED)
    paint:Text(x + w - 159, y0 + 36, 150, 18, "GE prices, " .. PRICES.date, C.FADED, { align = "right" })
    local after = bigNumber(paint, x + 12, y0 + 60, commas(total), C.NUMBER)
    paint:Text(after + 3, y0 + 75, 30, 18, "gp", C.NUMBER, { bold = true })
    local b = logView.banner
    if b then
        paint:Gold(x, y0 + 105, w, 24)
        paint:Text(x, y0 + 105, w, 24, b.text, C.DARK, { bold = true, align = "centre" })
    else
        local parts = { commas(d.claims) .. (d.claims == 1 and " oyster" or " oysters") }
        if read > 0 then
            parts[#parts + 1] = "avg " .. short(total / read) .. " per oyster"
            parts[#parts + 1] = "best " .. short(tonumber(d.best) or 0)
        end
        if d.empty > 0 then parts[#parts + 1] = commas(d.empty) .. " not read" end
        paint:Text(x + 3, y0 + 105, w - 6, 24, table.concat(parts, "   "), C.CREAM)
    end
    local cols, rows, colW = listShape()
    local shown = cols * rows
    local listY = LL.listY
    paint:Glass(x, listY, w, LL.footY - 6 - listY)
    local list = dropRows(s.key)
    logView.offset = math.max(0, math.min(logView.offset, math.max(0, #list - shown)))
    if #list == 0 then
        paint:Text(x + 9, listY + 9, w - 18, 24, "No claims logged yet. Claim away!", C.FADED, { align = "centre" })
    end
    local lit = logView.flash and logView.flash.items or {}
    local slots = math.max(shown, #icons)
    for i = 1, slots do
        local e = i <= shown and list[logView.offset + i] or nil
        local icon = e and iconFor(i) or icons[i]
        if e then
            local c, r = math.floor((i - 1) / rows), (i - 1) % rows
            local cx, ry = x + c * (colW + 12), listY + 3 + r * ROW_H
            local new = lit[e.id]
            if new then
                paint:Rect(cx + 3, ry, colW - 6, ROW_H - 3, C.GOLD)
            elseif r % 2 == 1 then
                paint:Rect(cx + 3, ry, colW - 6, ROW_H - 3, STRIPE)
            end
            local colour, rare = tier(e, read)
            local nameW = colW - 186
            paint:Text(cx + 51, ry + 2, nameW, 16, e.name, new and C.DARK or colour, { bold = rare or new ~= nil })
            paint:Text(cx + 51, ry + 18, nameW, 16, rate(e.hits, read), new and C.DARK or C.FADED)
            local function count(n) return n >= 10000 and short(n) or commas(n) end
            paint:Text(cx + colW - 132, ry + 2, 123, 16, (new and ("+" .. count(new) .. "   ") or "") .. "x" .. count(e.qty),
                new and C.DARK or C.NUMBER, { align = "right", bold = new ~= nil })
            paint:Text(cx + colW - 132, ry + 18, 123, 16, e.value > 0 and (short(e.value) .. " gp") or "-", new and C.DARK or C.GREEN, { align = "right" })
            if icon then
                local spot = (cx + 9) .. "," .. (ry + 2)
                if iconAt[i] ~= spot then pcall(function() icon:SetPos(cx + 9, ry + 2) end); iconAt[i] = spot end
                if shownIds[i] ~= e.id then           -- (kept in our own table: the game's components take no new fields)
                    pcall(function() icon:SetAssociatedObject(e.id) end)
                    shownIds[i] = e.id
                end
                icon.hidden = false
            end
        elseif icon then
            icon.hidden = true
        end
    end
    paint:Button(x, LL.footY, 132, 27, logView.resetAt and "Press again" or "Reset " .. s.name, logView.resetAt ~= nil)
    if #list > shown then
        paint:Text(x + 141, LL.footY, w - 180, 27, "Items " .. (logView.offset + 1) .. "-" .. math.min(#list, logView.offset + shown) ..
            " of " .. #list .. "  (scroll)", C.CREAM, { align = "right" })
    end
    local gx = x + w - 30
    paint:Button(gx, LL.footY, 30, 27, "", LL.resizing == true)
    for col = 0, 2 do                               -- the usual corner grip: a triangle of dots
        for row = 0, 2 do
            if col + row >= 2 then paint:Rect(gx + 6 + col * 6, LL.footY + 6 + row * 6, 3, 3, C.DARK) end
        end
    end
end

local function logRedraw()
    if logWindow then logWindow:Redraw(drawLog) end
end

local logAt = type(saved.log) == "table" and saved.log or {}
logWindow = RetroUI.Window(layer, {
    width = BASE_W, height = BASE_H + 8 * ROW_H, title = "DROP LOG",
    x = tonumber(logAt.x) or math.max(0, startX - BASE_W - 6), y = tonumber(logAt.y) or startY,
    onMove = function() save() end,
    onHide = function(hidden)                     -- 0.1.12: HIDE closes it (no gold tab); LOOT opens it again
        if hidden and not logOff and setLogGone then
            setLogGone(true)
            setStatus("Drop log closed (still logging). Open it: LOOT page, Drop log.")
            redraw()
        end
        save()
    end,
})

local function moveArea(area, ax, ay, aw, ah)
    pcall(function() area:SetPos(math.floor(ax), math.floor(ay)) end)
    pcall(function() area:SetSize(math.floor(aw), math.floor(ah)) end)
    for _, spot in ipairs(logWindow.spots) do
        if spot[5] == area then spot[1], spot[2], spot[3], spot[4] = math.floor(ax), math.floor(ay), math.floor(aw), math.floor(ah) end
    end
end
local listArea, resetArea, gripArea
local function relayout()
    LL.x, LL.y, LL.w = logWindow.inner.x, logWindow.inner.y, logWindow.inner.width
    LL.listY = LL.y + 132
    LL.footY = LL.y + logWindow.inner.height - 30
    if listArea then
        moveArea(listArea, LL.x, LL.listY, LL.w, LL.footY - 6 - LL.listY)
        moveArea(resetArea, LL.x, LL.footY, 132, 27)
        moveArea(gripArea, LL.x + LL.w - 30, LL.footY, 30, 27)
    end
end
relayout()

local function maxRows()
    local screenH = get(function() return layer.height end) or 1080
    local _, wy = logWindow:GetPos()
    return math.max(3, math.min(40, math.floor((screenH - wy - BASE_H - 6) / ROW_H)))
end
local function setLogSize(w, h, settle)
    local top = maxRows()
    w = math.max(BASE_W, math.min(BASE_W + 2 * COL_STEP, w))
    h = math.max(BASE_H + 3 * ROW_H, math.min(BASE_H + top * ROW_H, h))
    if settle then
        logSize.cols = math.max(1, math.min(3, 1 + math.floor((w - BASE_W) / COL_STEP + 0.5)))
        logSize.rows = math.max(3, math.min(top, math.floor((h - BASE_H) / ROW_H + 0.5)))
        w, h = BASE_W + (logSize.cols - 1) * COL_STEP, BASE_H + logSize.rows * ROW_H
    end
    if w ~= logWindow.width or h ~= logWindow.height or settle then
        logWindow:Resize(w, h)
        relayout()
        logRedraw()
    end
end

listArea = logWindow:Area(LL.x, LL.listY, LL.w, LL.footY - 6 - LL.listY, nil, function(delta)
    if type(delta) ~= "number" or delta == 0 then return end
    local cols, rows = listShape()
    local most = math.max(0, #dropRows(logSource().key) - cols * rows)
    local to = math.max(0, math.min(most, logView.offset + (delta > 0 and 3 or -3)))
    if to ~= logView.offset then logView.offset = to; logRedraw() end
end)
resetArea = logWindow:Area(LL.x, LL.footY, 132, 27, function()
    local s = logSource()
    if logView.resetAt and dl.tick - logView.resetAt <= 150 then
        drops[s.key] = { claims = 0, empty = 0, items = {} }
        logView.resetAt, logView.offset, logView.flash, logView.banner = nil, 0, nil, nil
        pcall(function() PersistentDB:SetStructuredData("devKitDrops", drops) end)
    else
        logView.resetAt = dl.tick
    end
    logRedraw()
end)
local resize = nil
local function mouseAt()
    local okX, mx = pcall(Mouse.GetX)
    local okY, my = pcall(Mouse.GetY)
    if okX and okY and type(mx) == "number" and type(my) == "number" then return mx, my end
end
local function endResize()
    if not resize then return end
    resize, LL.resizing = nil, nil
    setLogSize(logWindow.width, logWindow.height, true)
    save()
end
gripArea = logWindow:Area(LL.x + LL.w - 30, LL.footY, 30, 27, function()
    local mx, my = mouseAt()
    if mx then
        resize = { mx = mx, my = my, w = logWindow.width, h = logWindow.height, off = 0 }
        LL.resizing = true
        logRedraw()
    end
end)
pcall(function() gripArea:Subscribe(ui.Hook.ONRELEASE, function() endResize(); return false end) end)
local function followResize()
    if not resize then return end
    local mx, my = mouseAt()
    if not mx then return end
    setLogSize(resize.w + mx - resize.mx, resize.h + my - resize.my, false)
    local okOver, over = pcall(function() return gripArea.isMouseOver end)
    if okOver and over == false then
        resize.off = resize.off + 1
        if resize.off > 15 then endResize() end
    else
        resize.off = 0
    end
end
setLogSize(BASE_W + (logSize.cols - 1) * COL_STEP, BASE_H + logSize.rows * ROW_H, true)

onClaim = function(_, loot)
    logView.flash = { items = loot, at = dl.tick }
    local top, topWorth = nil, -1                   -- the most valuable broadcast drop in it, if any
    for id, n in pairs(loot) do
        if broadcast(itemName(id)) and n * price(id) > topWorth then top, topWorth = id, n * price(id) end
    end
    if top then
        local n = loot[top]
        logView.banner = { text = "BROADCAST!  " .. (n > 1 and (commas(n) .. " x ") or "") .. itemName(top) ..
            (topWorth > 0 and ("  (" .. short(topWorth) .. ")") or ""), at = dl.tick }
    end
    logRedraw()
end
local function logTimers()
    local again = false
    if logView.flash and dl.tick - logView.flash.at >= 100 then logView.flash, again = nil, true end
    if logView.banner and dl.tick - logView.banner.at >= 250 then logView.banner, again = nil, true end
    if logView.resetAt and dl.tick - logView.resetAt > 150 then logView.resetAt, again = nil, true end
    if again then logRedraw() end
end
setLogGone = function(off)
    if off == logOff then return end
    logOff = off                                  -- (first: Show below calls onHide(false), which must not close it again)
    if off then
        if logWindow:IsHidden() then logWindow:Show() end   -- (takes the gold tab away)
        logWindow.layer.hidden = true
    else
        logWindow.layer.hidden = false
    end
    save()
end
if logOff then logWindow.layer.hidden = true end
logRedraw()

Event.Logic.Subscribe("devKit", function()
    window:Animate()
    sendNext()
    if #queue == 0 then keepArmed() end         -- (a big button's commands go first)
    logWindow:Animate()
    followResize()
    guarded("tick", logTick)
    guarded("timers", logTimers)
    if tool.junkAt and dl.tick - tool.junkAt > 150 then tool.junkAt, tool.confirm = nil, nil; redraw() end   -- an unanswered warning
    search.tick = search.tick + 1
    if search.dirtyAt and search.tick - search.dirtyAt >= 8 then guarded("search", runSearch); redraw() end
end)
Event.InventoryUpdated.Subscribe("devKit", function(event) guarded("inventory", onInventory, event) end)
local function onVarCooldown(event)
    if type(ExecuteConsoleCommand) ~= "function" then return end
    local name = get(function() return event.var.configName end)
    local value = tonumber(event.newValue)
    if type(name) ~= "string" or not value or value == 0 then return end
    if not (clearCds or (armed.skulls and name:find("DEATH_SKULLS", 1, true))) then return end
    if name:match("^COMBATV2_.*COOLDOWN.*_END$") then
        pcall(ExecuteConsoleCommand, "!setvar " .. name .. " 0")
    elseif name:match("^COMBATV2_.*COOLDOWN.*_END_CLIENT$") then
        pcall(ExecuteConsoleCommand, "!setvarc " .. name .. " 0")
    end
end
Event.VarTransmit.Subscribe("devKit", function(event) guarded("cooldowns", onVarCooldown, event) end)
guarded("inventory", onInventory)               -- the backpack as it is now, so the first claim has a "before"

function PluginShutdown()
    Event.Logic.Unsubscribe("devKit")
    Event.InventoryUpdated.Unsubscribe("devKit")
    Event.VarTransmit.Unsubscribe("devKit")
    save()
    pcall(function() PersistentDB:SetStructuredData("devKitDrops", drops) end)
    window:Destroy()
    logWindow:Destroy()
end

log("Dev Kit is on: " .. #TABS .. " pages" .. (type(ExecuteConsoleCommand) == "function" and "" or " (console commands not available here)"))

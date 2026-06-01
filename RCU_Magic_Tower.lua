-- Ducky Hub | RCU Magic Tower Event 
-- Native Knit Update: Bypasses all obfuscated RE/RF folders and uses exposed API.
-- Added: Multi-Select Mobs, Flame Machine, 4-Tier RNG Wheel, RNG Minigame Egg.

local Library, InterfaceManager, SaveManager
local maxRetries, retryDelay, uiLoaded = 3, 3, false

for attempt = 1, maxRetries do
    local ok, err = pcall(function()
        Library          = loadstring(game:HttpGet("https://github.com/ActualMasterOogway/Fluent-Renewed/releases/latest/download/Fluent.luau"))()
        InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/InterfaceManager.luau"))()
        SaveManager      = loadstring(game:HttpGet("https://raw.githubusercontent.com/bigbeanscripts/Pet-Warriors/refs/heads/main/test"))()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/SenhorLDS/ProjectLDSHUB/refs/heads/main/Anti%20AFK"))()
    end)
    if ok then uiLoaded = true; break else task.wait(retryDelay) end
end
if not uiLoaded then error("[DuckyHub] Failed to load UI") end

local RS      = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CS      = game:GetService("CollectionService")
local lp      = Players.LocalPlayer

local Knit = require(RS.Packages.Knit)
Knit.OnStart():await()

-- Native Controllers
local DataController     = Knit.GetController("DataController")
local EggController      = Knit.GetController("EggController")
local MagicTowerCtrl     = Knit.GetController("MagicTowerController")
local HatchingController = require(lp.PlayerScripts.Client.Controllers.HatchingController)

-- Native Services (Direct API Access)
local EggService         = Knit.GetService("EggService")
local SkillTreeService   = Knit.GetService("SkillTreeService")
local InventoryService   = Knit.GetService("InventoryService")
local MagicTowerService  = Knit.GetService("MagicTowerService")

local Floors     = require(RS.Shared.List.MagicTower.Floors)
local SkillTree  = require(RS.Shared.List.SkillTree)
local EggsModule = require(RS.Shared.List.Pets.Eggs)
local EggUtils   = require(RS.Shared.Util.EggUtils)

local TM = {threads={}}
function TM:Add(k, fn) self:Stop(k); self.threads[k] = task.spawn(fn) end
function TM:Stop(k) if self.threads[k] then pcall(task.cancel, self.threads[k]); self.threads[k] = nil end end

local function safeGetData()
    if not DataController then return nil end
    local ok, res = pcall(function() return DataController:getData() end)
    return ok and res or nil
end

local function runSafeUpdater(para, fn)
    task.spawn(function()
        while true do
            local ok, content = pcall(fn)
            if ok and content then pcall(function() para:SetValue(content) end) end
            task.wait(2)
        end
    end)
end

local function suffix(n)
    n = tonumber(n) or 0
    if n >= 1e12 then return ("%.2fT"):format(n/1e12)
    elseif n >= 1e9 then return ("%.2fB"):format(n/1e9)
    elseif n >= 1e6 then return ("%.2fM"):format(n/1e6)
    elseif n >= 1e3 then return ("%.2fK"):format(n/1e3)
    end
    return tostring(math.floor(n))
end

local function getCurrencyAmount(pd, upg)
    if not upg.currency then return tonumber(pd.gems) or 0 end
    local c = upg.currency
    local cName = ""
    if type(c) == "string" then cName = c
    elseif type(c) == "table" then cName = c.nm or c.id or c.name or "" end
    cName = tostring(cName):lower():gsub(" ", "")
    if cName == "skulls" then return tonumber(pd.skulls) or 0 end
    if cName == "dungeoncoins" then return tonumber(pd.dungeonCoins) or 0 end
    if cName == "gems" then return tonumber(pd.gems) or 0 end
    return 0
end

local WandOrder = {"basicWand","shadowWand","frostWand","crystalWand","stormWand","mysticWand","phoenixWand","galaxyWand","celestialWand","moneyWand"}
local WandData = {
    basicWand={name="Basic Wand",dmg=20,index=1}, shadowWand={name="Shadow Wand",dmg=50,index=2},
    frostWand={name="Frost Wand",dmg=100,index=3}, crystalWand={name="Crystal Wand",dmg=200,index=4},
    stormWand={name="Storm Wand",dmg=750,index=5}, mysticWand={name="Mystic Wand",dmg=1500,index=6},
    phoenixWand={name="Phoenix Wand",dmg=3500,index=7}, galaxyWand={name="Galaxy Wand",dmg=10000,index=8},
    celestialWand={name="Celestial Wand",dmg=25000,index=9}, moneyWand={name="Money Wand",dmg=30000,index=99}
}
local WandCraftCosts = {
    shadowWand={skulls=5000,magicDust=3}, frostWand={skulls=100000,magicDust=15,greenFlame=3},
    crystalWand={skulls=2000000,magicDust=75,greenFlame=15,redFlame=3}, stormWand={skulls=15000000,magicDust=250,greenFlame=75,redFlame=25,magicFlame=3},
    mysticWand={skulls=100000000,magicDust=600,redFlame=100,magicFlame=30,ultraFlame=5,insaneFlame=1},
    phoenixWand={skulls=700000000,magicDust=1500,redFlame=300,magicFlame=75,ultraFlame=20,insaneFlame=4},
    galaxyWand={skulls=5000000000,magicDust=3000,magicFlame=150,ultraFlame=75,insaneFlame=15,celestialFlame=1},
    celestialWand={skulls=100000000000,magicDust=7500,magicFlame=400,ultraFlame=200,insaneFlame=30,celestialFlame=5}
}

local function getCurrentWandKey()
    local data = safeGetData()
    if not data then return "basicWand" end
    if data.boughtMoneyWand then return "moneyWand" end
    local idx = data.magicWand or data.magicWandIndex or data.wandIndex
    if type(idx) == "number" then for k, w in pairs(WandData) do if w.index == idx then return k end end end
    if type(idx) == "string" and WandData[idx] then return idx end
    if data.inventory and type(data.inventory.magicTowerEvent) == "table" then
        for i = #WandOrder, 1, -1 do
            local key = WandOrder[i]
            for _, item in pairs(data.inventory.magicTowerEvent) do
                if type(item) == "table" and item.nm == key then return key end
            end
        end
    end
    return "basicWand"
end

local function getNextWandKey(currentKey)
    if not currentKey then return WandOrder[1] end
    for i, k in ipairs(WandOrder) do if k == currentKey then return WandOrder[i+1] end end
    return nil
end

local function buildWandProgress(currentKey)
    local idx = 0
    for i, k in ipairs(WandOrder) do if k == currentKey then idx = i; break end end
    local lines = {}
    for i, k in ipairs(WandOrder) do
        local wd = WandData[k]
        local mark = i < idx and "✓" or (i == idx and "▶" or " ")
        local costStr = ""
        if WandCraftCosts[k] and i > idx then
            local c = WandCraftCosts[k]
            costStr = " [Cost: "..suffix(c.skulls).." Skulls"
            if c.magicDust then costStr = costStr..", "..c.magicDust.." Dust" end
            if c.greenFlame then costStr = costStr..", "..c.greenFlame.." GF" end
            if c.redFlame then costStr = costStr..", "..c.redFlame.." RF" end
            if c.magicFlame then costStr = costStr..", "..c.magicFlame.." MF" end
            if c.ultraFlame then costStr = costStr..", "..c.ultraFlame.." UF" end
            if c.insaneFlame then costStr = costStr..", "..c.insaneFlame.." IF" end
            if c.celestialFlame then costStr = costStr..", "..c.celestialFlame.." CF" end
            costStr = costStr.."]"
        end
        table.insert(lines, ("[%s] %s (%s dmg)%s"):format(mark, wd.name, suffix(wd.dmg), costStr))
    end
    return table.concat(lines, "\n")
end

local Values = require(RS.Shared.Values)
local _originalWandAttackSpeed = nil
local function patchWandSpeed(multiplier)
    if not _originalWandAttackSpeed then _originalWandAttackSpeed = Values.wandAttackSpeed end
    if multiplier and multiplier > 0 then Values.wandAttackSpeed = function(...) return multiplier end
    else Values.wandAttackSpeed = _originalWandAttackSpeed end
end

local function isBoostActive(data, itemKey)
    if not data or type(data.activeBoosts) ~= "table" then return false end
    return tonumber(data.activeBoosts[itemKey]) and tonumber(data.activeBoosts[itemKey]) > 0
end

local function getItemAmount(data, itemKey)
    if not data or type(data.inventory) ~= "table" then return 0 end
    for _, cat in ipairs({"magicTowerEvent", "potion"}) do
        if type(data.inventory[cat]) == "table" then
            for _, item in pairs(data.inventory[cat]) do
                if type(item) == "table" and item.nm == itemKey then return tonumber(item.am) or 0 end
            end
        end
    end
    return 0
end

local function getBestFloor()
    local data = safeGetData()
    local rebirths = data and tonumber(data.magicRebirths) or 0
    local best = nil
    for id, floor in pairs(Floors) do
        if (floor.requiredRebirth or 0) <= rebirths then if not best or id > best then best = id end end
    end
    return best
end

local function getMagicTowerSkillCategories()
    local cats = {}
    for catId, catData in pairs(SkillTree) do
        local name = (catData.name or tostring(catId)):lower()
        if name:find("magic") or name:find("tower") or name:find("wand") or name:find("skull") or catId == "magicTowerEvent" then
            table.insert(cats, {id=catId, data=catData})
        end
    end
    return cats
end

local selectedEgg, currentHatchKey = "Basic", "Max"
local hatchAmountMap = {["1x"]=1, ["3x"]=3, ["Max"]=99}
local useLuckyEggs, isHatchHidden, isAutoHatchEnabled = false, false, false

if not HatchingController._realPlayEggAnimation then HatchingController._realPlayEggAnimation = HatchingController.playEggAnimation end
HatchingController.playEggAnimation = function(self, ...) if isHatchHidden then return nil end return HatchingController._realPlayEggAnimation(self, ...) end

task.spawn(function()
    while true do
        if isAutoHatchEnabled and not HatchingController._isHatching then
            pcall(function()
                local amount = hatchAmountMap[currentHatchKey] or 99
                local args = {selectedEgg, amount}
                if useLuckyEggs then
                    local bestId, bestMult = nil, 0
                    for id in pairs(EggController._luckyEggs or {}) do
                        local m = (EggController._globalLuckEventAmount or 0) * 1000
                        if m > bestMult then bestMult, bestId = m, id end
                    end
                    if bestId then table.insert(args, {luckyEggId = bestId}) end
                end
                EggService.openEgg._re:FireServer(unpack(args))
            end)
        end
        task.wait(0.1)
    end
end)

local eggsTable, displayToEggName, eggOptions = {}, {}, {}
for eggName, eggData in pairs(EggsModule) do
    if type(eggData) == "table" and eggData.cost then
        table.insert(eggsTable, {name=eggName, cost=eggData.cost, currency=EggUtils.getCurrency(eggName) or "clicks"})
    end
end
table.sort(eggsTable, function(a,b) return a.cost < b.cost end)
for _, e in ipairs(eggsTable) do
    local disp = e.name.." - "..suffix(e.cost).." "..e.currency
    table.insert(eggOptions, disp)
    displayToEggName[disp] = e.name
end
if #eggOptions == 0 then eggOptions = {"Basic"} end

local Window = Library:Window{
    Title = "🦆 Ducky Hub", SubTitle = "RCU Magic Tower",
    TabWidth = 160, Size = UDim2.fromOffset(580, 460), Resize = false, Theme = "Darker", MinimizeKey = Enum.KeyCode.RightShift,
}
local Tabs = {
    Farm     = Window:AddTab({ Title = "Auto Farm",     Icon = "swords" }),
    Upgrades = Window:AddTab({ Title = "Auto Upgrades", Icon = "trending-up" }),
    Rewards  = Window:AddTab({ Title = "Auto Rewards",  Icon = "gift" }),
    Settings = Window:AddTab({ Title = "Settings",      Icon = "settings" }),
}

-- =============================================
-- TAB: AUTO FARM
-- =============================================
local KillSection = Tabs.Farm:AddSection("Auto Kill (Multi-Select)")
local selectedMobs = {}
local mobNames = {
    "Spider", "Skeleton", "Magic Bat", "Witch", "Magic Golem", 
    "Haunted Wizard", "Magic Slime", "Dark Eye", "Electro Wizard", 
    "Dark Wizard", "Chaos Wizard", "Frozen Wizard"
}
local mobOptions = {}
for _, name in ipairs(mobNames) do table.insert(mobOptions, name) end

KillSection:Dropdown("MobTargetMulti", {
    Title = "Select Mobs to Kill", Values = mobOptions, Default = {}, Multi = true, Searchable = true,
    Callback = function(val)
        selectedMobs = val
    end,
})

KillSection:Toggle("AutoKill", {
    Title = "Auto Kill", Default = false,
    Callback = function(val)
        if val then
            TM:Add("kill", function()
                while not MagicTowerService.damage do task.wait(0.5) end
                while true do
                    pcall(function()
                        local mobs = CS:GetTagged("mob")
                        for _, mob in mobs do
                            if mob and mob.Parent then
                                local hit = selectedMobs[mob.Name]
                                if hit then
                                    local id = mob:GetAttribute("mobId")
                                    if id then
                                        MagicTowerService.damage:Fire(id)
                                    end
                                end
                            end
                        end
                    end)
                    task.wait(0.05)
                end
            end)
        else
            TM:Stop("kill")
        end
    end,
})

local FloorSection = Tabs.Farm:AddSection("Auto Floor")
FloorSection:Toggle("AutoFloor", {
    Title = "Auto TP Best Floor", Default = false,
    Callback = function(val)
        if val then
            TM:Add("floor", function()
                while true do
                    pcall(function()
                        local best = getBestFloor()
                        local current = nil
                        pcall(function() current = MagicTowerCtrl:getFloorId() end)
                        if best and current ~= best then
                            MagicTowerCtrl:setFloorId(best)
                            MagicTowerCtrl:teleportToFloor()
                            task.wait(3)
                            pcall(function()
                                MagicTowerService.setIsAutoFighting:Fire(best)
                            end)
                        end
                    end)
                    task.wait(5)
                end
            end)
        else TM:Stop("floor") end
    end,
})

local HatchSection = Tabs.Farm:AddSection("Auto Hatch")
HatchSection:Dropdown("SelectEgg", { Title = "Select Egg", Values = eggOptions, Default = eggOptions[1] or "Basic", Multi = false, Searchable = true, Callback = function(val) selectedEgg = displayToEggName[val] or val:match("^(.-) %-") or val end })
HatchSection:Dropdown("HatchAmount", { Title = "Hatch Amount", Values = {"1x","3x","Max"}, Default = "Max", Multi = false, Callback = function(val) currentHatchKey = val end })
HatchSection:Toggle("LuckyEggs", { Title = "Use Lucky Eggs", Default = false, Callback = function(val) useLuckyEggs = val end })
HatchSection:Toggle("AutoHatch", { Title = "Auto Hatch Normal Egg", Default = false, Callback = function(val) isAutoHatchEnabled = val end })
HatchSection:Toggle("HideAnimation", { Title = "Hide Hatch Animation", Default = false, Callback = function(val) isHatchHidden = val end })

HatchSection:Toggle("AutoRNGEgg", {
    Title = "Auto Open RNG Minigame Egg", Description = "Spams the event minigame egg while the stage is active.", Default = false,
    Callback = function(val)
        if val then
            TM:Add("rngegg", function()
                while true do
                    pcall(function()
                        local amt = hatchAmountMap[currentHatchKey] or 99
                        EggService.openEgg._re:FireServer("Magic RNG", amt)
                        EggService.openEgg._re:FireServer("Magic RNG Egg", amt)
                    end)
                    task.wait(0.2)
                end
            end)
        else TM:Stop("rngegg") end
    end
})

-- =============================================
-- TAB: AUTO UPGRADES
-- =============================================
local WandSection = Tabs.Upgrades:AddSection("Wand Upgrader")

local wandStatusPara = WandSection:Paragraph("WandStatus", { Title = "Current Wand", Content = "Detecting...", TitleAlignment = "Middle" })
runSafeUpdater(wandStatusPara, function()
    local key = getCurrentWandKey()
    return key and ("▶ %s | %s dmg"):format(WandData[key].name, suffix(WandData[key].dmg)) or "Not detected — equip a wand in game"
end)

local wandProgressPara = WandSection:Paragraph("WandProgress", { Title = "Wand Progress & Craft Costs", Content = "Loading...", TitleAlignment = "Middle" })
runSafeUpdater(wandProgressPara, function() return buildWandProgress(getCurrentWandKey()) end)

WandSection:Toggle("AutoWandUpgrade", {
    Title = "Auto Upgrade Wand", Description = "Upgrades wand until Money Wand", Default = false,
    Callback = function(val)
        if val then
            TM:Add("wand", function()
                while true do
                    pcall(function()
                        local currentKey = getCurrentWandKey()
                        local nextKey = getNextWandKey(currentKey)
                        if not nextKey then task.wait(5); return end
                        MagicTowerService:upgradeWand()
                    end)
                    task.wait(0.5)
                end
            end)
        else TM:Stop("wand") end
    end,
})

local WandSpeedSection = Tabs.Upgrades:AddSection("Attack Speed")
local speedSliderValue = 1.0
WandSpeedSection:Slider("AttackSpeedSlider", { Title = "Wand Attack Speed Multiplier", Description = "Lower = faster. 1.0 = normal, 0.01 = near instant", Default = 1.0, Min = 0.01, Max = 1.0, Rounding = 2, Callback = function(val) speedSliderValue = val end })
WandSpeedSection:Toggle("SpeedHack", { Title = "Override Attack Speed", Default = false, Callback = function(val) if val then patchWandSpeed(speedSliderValue); TM:Add("speedpatch", function() while true do patchWandSpeed(speedSliderValue); task.wait(1) end end) else TM:Stop("speedpatch"); patchWandSpeed(nil) end end })

local FlameMachineSection = Tabs.Upgrades:AddSection("Flame Machine")
local flameOptions = {
    "250x Magic Dust", "100x Green Flame", "50x Red Flame", "50x Magic Flame",
    "50x Ultra Flame", "15x Insane Flame", "1x Celestial Flame", "1x Frozen Flame"
}
local flameIndexMap = {
    ["250x Magic Dust"] = 1, ["100x Green Flame"] = 2, ["50x Red Flame"] = 3,
    ["50x Magic Flame"] = 4, ["50x Ultra Flame"] = 5, ["15x Insane Flame"] = 6,
    ["1x Celestial Flame"] = 7, ["1x Frozen Flame"] = 8
}
local selectedFlames = {}

FlameMachineSection:Dropdown("SelectFlames", {
    Title = "Select Sacrifices", Values = flameOptions, Multi = true, Default = {},
    Callback = function(val) selectedFlames = val end
})

FlameMachineSection:Toggle("AutoFlameMachine", {
    Title = "Auto Use Flame Machine", Default = false,
    Callback = function(val)
        if val then
            TM:Add("flamemachine", function()
                while true do
                    pcall(function()
                        for name, isSelected in pairs(selectedFlames) do
                            if isSelected then
                                local index = flameIndexMap[name]
                                if index then MagicTowerService:useFlameMachine(index) end
                                task.wait(0.5)
                            end
                        end
                    end)
                    task.wait(2)
                end
            end)
        else TM:Stop("flamemachine") end
    end
})

local RebirthSection = Tabs.Upgrades:AddSection("Event Rebirth")
RebirthSection:Toggle("AutoRebirth", {
    Title = "Auto Event Rebirth", Default = false,
    Callback = function(val)
        if val then
            TM:Add("rebirth", function()
                while true do
                    pcall(function() MagicTowerService:magicRebirth() end)
                    task.wait(1)
                end
            end)
        else TM:Stop("rebirth") end
    end,
})

local SkillSection = Tabs.Upgrades:AddSection("Skill Tree")
SkillSection:Toggle("AutoBuySkillTree", {
    Title = "Auto Buy Event Skill Tree", Default = false,
    Callback = function(val)
        if val then
            TM:Add("skilltree", function()
                while true do
                    pcall(function()
                        local pd = safeGetData()
                        if not pd then return end
                        for _, cat in ipairs(getMagicTowerSkillCategories()) do
                            local catStr = tostring(cat.id)
                            for subName, subData in pairs(cat.data.list or {}) do
                                for i, upg in ipairs(subData.list or {}) do
                                    local key = subName.."_"..i
                                    if not (pd.skillTree and pd.skillTree[catStr] and pd.skillTree[catStr][key]) then
                                        local price = upg.price or 0
                                        if getCurrencyAmount(pd, upg) >= price then
                                            task.spawn(function()
                                                pcall(function() SkillTreeService:buySkillTree(catStr, subName, i) end)
                                            end)
                                            task.wait(0.01)
                                        end
                                    end
                                end
                            end
                        end
                    end)
                    task.wait(0.1)
                end
            end)
        else TM:Stop("skilltree") end
    end,
})

-- =============================================
-- TAB: AUTO REWARDS
-- =============================================
local WheelSection = Tabs.Rewards:AddSection("Magic Spin Wheel")
local selectedWheelTier = 1

WheelSection:Dropdown("SelectWheelTier", {
    Title = "Select Wheel Tier", Values = {"Tier 1", "Tier 2", "Tier 3", "Tier 4"}, Default = "Tier 1", Multi = false,
    Callback = function(val)
        selectedWheelTier = tonumber(val:match("%d+")) or 1
    end
})

WheelSection:Toggle("AutoSpinWheel", {
    Title = "Auto Spin RNG Wheel", Description = "Automatically spins the selected wheel tier.", Default = false,
    Callback = function(val)
        if val then
            TM:Add("spinwheel", function()
                while true do
                    pcall(function() MagicTowerService:magicWheelSpin(selectedWheelTier) end)
                    task.wait(5)
                end
            end)
        else TM:Stop("spinwheel") end
    end
})

local GachaSection = Tabs.Rewards:AddSection("Event Gacha (Keys & Tickets)")
GachaSection:Toggle("AutoMagicChest", {
    Title = "Auto Magic Chest", Default = false,
    Callback = function(val)
        if val then
            TM:Add("magicChest", function()
                while true do
                    pcall(function()
                        local data = safeGetData()
                        if data and getItemAmount(data, "magicKey") > 0 then
                            MagicTowerService:openMagicChest(true)
                        end
                    end)
                    task.wait(2)
                end
            end)
        else TM:Stop("magicChest") end
    end,
})

GachaSection:Toggle("AutoMagicReward", {
    Title = "Auto Magic Rewards", Default = false,
    Callback = function(val)
        if val then
            TM:Add("magicReward", function()
                while true do
                    pcall(function()
                        local data = safeGetData()
                        if data and getItemAmount(data, "magicTicket") > 0 then
                            MagicTowerService:claimMagicReward()
                        end
                    end)
                    task.wait(0.05)
                end
            end)
        else TM:Stop("magicReward") end
    end,
})

local BoostSection = Tabs.Rewards:AddSection("Auto Event Boosts")
local EventBoostItems = {
    {id="magicPotion", name="Magic Potion"}, {id="megaMagicPotion", name="Mega Magic Potion"},
    {id="ultraMagicPotion", name="Ultra Magic Potion"}, {id="magicCore", name="Magic Core"},
    {id="magicOrb", name="Magic Orb"}, {id="magicShard", name="Magic Shard"}, {id="magicLuck", name="Magic Luck"},
}
local boostOptions = {}
for _, b in ipairs(EventBoostItems) do table.insert(boostOptions, b.name) end
local selectedBoosts = {}

local boostStatusPara = BoostSection:Paragraph("BoostStatus", { Title = "Active Boosts", Content = "Loading...", TitleAlignment = "Middle" })
runSafeUpdater(boostStatusPara, function()
    local data = safeGetData()
    if not data then return "Awaiting player data..." end
    local lines = {}
    for _, b in ipairs(EventBoostItems) do
        local amt = getItemAmount(data, b.id)
        local active = isBoostActive(data, b.id)
        local secs = data.activeBoosts and tonumber(data.activeBoosts[b.id]) or 0
        table.insert(lines, ("%s %s x%d%s"):format(active and "🟢" or "🔴", b.name, amt, active and (" | "..math.floor(secs).."s left") or ""))
    end
    return table.concat(lines, "\n")
end)

BoostSection:Dropdown("BoostSelect", { Title = "Select Boosts to Auto Use", Values = boostOptions, Multi = true, Default = {}, Callback = function(val) selectedBoosts = val end })
BoostSection:Toggle("AutoBoosts", {
    Title = "Auto Use Selected Boosts", Default = false,
    Callback = function(val)
        if val then
            TM:Add("boosts", function()
                while true do
                    pcall(function()
                        local data = safeGetData()
                        if not data then return end
                        for _, b in ipairs(EventBoostItems) do
                            if selectedBoosts[b.name] and not isBoostActive(data, b.id) then
                                local itemUsed = false
                                for _, folderName in ipairs({"magicTowerEvent", "potion"}) do
                                    local folder = data.inventory[folderName]
                                    if type(folder) == "table" and not itemUsed then
                                        for invId, itemData in pairs(folder) do
                                            if type(itemData) == "table" and (itemData.nm == b.id or invId == b.id) and (tonumber(itemData.am) or 0) > 0 then
                                                task.spawn(function() InventoryService:useItem(invId, "1") end)
                                                task.wait(0.1)
                                                itemUsed = true
                                                break
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end)
                    task.wait(3)
                end
            end)
        else TM:Stop("boosts") end
    end,
})

local BoxSection = Tabs.Rewards:AddSection("Auto Open Boxes")
local EventBoxItems = { {id="wizardBag", name="Wizard Bag"}, {id="wizardCrate", name="Wizard Crate"} }
local boxOptions = {}
for _, b in ipairs(EventBoxItems) do table.insert(boxOptions, b.name) end
local selectedBoxes = {}

local boxStatusPara = BoxSection:Paragraph("BoxStatus", { Title = "Box Inventory", Content = "Loading...", TitleAlignment = "Middle" })
runSafeUpdater(boxStatusPara, function()
    local data = safeGetData()
    if not data then return "Awaiting player data..." end
    local lines = {}
    for _, b in ipairs(EventBoxItems) do table.insert(lines, ("%s: x%d"):format(b.name, getItemAmount(data, b.id))) end
    return table.concat(lines, "\n")
end)

BoxSection:Dropdown("BoxSelect", { Title = "Select Boxes to Auto Open", Values = boxOptions, Multi = true, Default = {}, Callback = function(val) selectedBoxes = val end })
BoxSection:Toggle("AutoBoxes", {
    Title = "Auto Open Selected Boxes", Default = false,
    Callback = function(val)
        if val then
            TM:Add("boxes", function()
                while true do
                    pcall(function()
                        local data = safeGetData()
                        if not data then return end
                        for _, b in ipairs(EventBoxItems) do
                            if selectedBoxes[b.name] then
                                if data.inventory and type(data.inventory.magicTowerEvent) == "table" then
                                    for invId, itemData in pairs(data.inventory.magicTowerEvent) do
                                        if type(itemData) == "table" and (itemData.nm == b.id or invId == b.id) and (tonumber(itemData.am) or 0) > 0 then
                                            local owned = tonumber(itemData.am)
                                            task.spawn(function() InventoryService:useItem(invId, {use = owned}) end)
                                            task.wait(0.5)
                                        end
                                    end
                                end
                            end
                        end
                    end)
                    task.wait(2)
                end
            end)
        else TM:Stop("boxes") end
    end,
})

-- SETTINGS TAB
SaveManager:SetLibrary(Library)
InterfaceManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes{}
InterfaceManager:SetFolder("DuckyHub")
SaveManager:SetFolder("DuckyHub/MagicTower")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)
Window:SelectTab(1)
SaveManager:LoadAutoloadConfig()

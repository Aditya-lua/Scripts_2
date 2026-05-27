--=============================================================================
-- 🦆 Ducky Hub | MAIN GAME Core Engine (Phase 1)
-- Host on GitHub/Pastebin. Do not put in autoexec.
--=============================================================================

local cfg = _G.RCUMainSettings
if not cfg then error("[🦆 Ducky Hub] CRITICAL ERROR: _G.RCUMainSettings not found!") end

if cfg.Optimization.AntiAFK then
    pcall(function() loadstring(game:HttpGet("https://raw.githubusercontent.com/SenhorLDS/ProjectLDSHUB/refs/heads/main/Anti%20AFK"))() end)
end

local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local lp = Players.LocalPlayer

local Knit = require(RS.Packages.Knit)
Knit.OnStart():await()

-- Services & Controllers
local DataController = Knit.GetController("DataController")
local ClickController = require(lp.PlayerScripts.Client.Controllers.ClickController)
local HatchingController = require(lp.PlayerScripts.Client.Controllers.HatchingController)
local EggController = Knit.GetController("EggController")

local ClickService = Knit.GetService("ClickService")
local RebirthService = Knit.GetService("RebirthService")
local UpgradeService = Knit.GetService("UpgradeService")
local SkillTreeService = Knit.GetService("SkillTreeService")
local EggService = Knit.GetService("EggService")

-- Modules
local RebirthsList = require(RS.Shared.List.Rebirths)
local Variables = require(RS.Shared.Variables)
local UpgradesModule = require(RS.Shared.List.Upgrades)
local SkillTreeList = require(RS.Shared.List.SkillTree)
local EggsModule = require(RS.Shared.List.Pets.Eggs)

local TM = {threads={}}
function TM:Add(k, fn) self:Stop(k); self.threads[k] = task.spawn(fn) end
function TM:Stop(k) if self.threads[k] then pcall(task.cancel, self.threads[k]); self.threads[k] = nil end end

local function safeGetData()
    local ok, res = pcall(function() return DataController:getData() end)
    return ok and res or nil
end

--=============================================================================
-- 🚀 KAITUN MODULES (PHASE 1)
--=============================================================================

-- 1. Hatch Animation Opt
if cfg.Optimization.HideHatchAnimation then
    if not HatchingController._realPlayEggAnimation then HatchingController._realPlayEggAnimation = HatchingController.playEggAnimation end
    HatchingController.playEggAnimation = function(...) return nil end
end

-- 2. Auto Click
if cfg.AutoFarm.AutoClick then
    TM:Add("click", function()
        while true do
            pcall(function()
                ClickController:setLastClickType(2) 
                ClickController:setDebounce()
                ClickController:doClick()
            end)
            task.wait(0.02)
        end
    end)
end

-- 3. Auto Rebirth (Smart Best Calculation)
if cfg.AutoFarm.AutoRebirth.Enable then
    TM:Add("rebirth", function()
        while true do
            pcall(function()
                local pd = safeGetData()
                if not pd then return end

                local basePrice = Variables.rebirthPrice or 0
                local multiplier = Variables.rebirthPriceMultiplier or 0
                local currentRebirths = pd.rebirths or 0
                local clicks = pd.clicks or 0

                local bestIndex, bestAmount = nil, 0

                for index, amount in pairs(RebirthsList) do
                    local price = (basePrice + currentRebirths * multiplier) * amount + multiplier * (amount * (amount - 1) / 2)
                    if clicks >= price and amount > bestAmount then
                        bestAmount = amount
                        bestIndex = index
                    end
                end

                if bestIndex then
                    RebirthService:rebirth(bestIndex)
                end
            end)
            task.wait(cfg.AutoFarm.AutoRebirth.Delay or 2)
        end
    end)
end

-- 4. Auto Upgrades
if cfg.AutoFarm.AutoUpgrades then
    TM:Add("upgrades", function()
        while true do
            pcall(function()
                local pd = safeGetData()
                if not pd then return end

                for id, def in pairs(UpgradesModule) do
                    if def and not (def.requiredMap and not (pd.maps and pd.maps[def.requiredMap])) then
                        local level = (pd.upgrades and pd.upgrades[id] or 0) + 1
                        local costData = def.upgrades and def.upgrades[level]
                        if costData and costData.cost <= (pd.gems or 0) then
                            UpgradeService:upgrade(id)
                            task.wait(0.1)
                        end
                    end
                end
            end)
            task.wait(5)
        end
    end)
end

-- 5. Auto Hatch
if cfg.AutoHatch.Enable then
    local hMap = {["1x"]=1, ["3x"]=3, ["Max"]=99}
    local amt = hMap[cfg.AutoHatch.Amount] or 99
    local egg = cfg.AutoHatch.Egg
    local useLck = cfg.AutoHatch.UseLuckyEggs

    TM:Add("hatch", function()
        while true do
            if not HatchingController._isHatching then
                pcall(function()
                    local args = {egg, amt}
                    if useLck then
                        local bId, bMult = nil, 0
                        for id in pairs(EggController._luckyEggs or {}) do
                            local m = (EggController._globalLuckEventAmount or 0) * 1000
                            if m > bMult then bMult, bId = m, id end
                        end
                        if bId then table.insert(args, {luckyEggId = bId}) end
                    end
                    EggService.openEgg._re:FireServer(unpack(args))
                end)
            end
            task.wait(0.15)
        end
    end)
end

print("[🦆] Ducky Hub MAIN Kaitun (Phase 1) Loaded!")


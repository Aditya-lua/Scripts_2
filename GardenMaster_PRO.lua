local request = (syn and syn.request) or (http and http.request) or http_request

local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LightingService = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local TeleportService = game:GetService("TeleportService")
local client = Players.LocalPlayer

print("Loading Library...")
local Library = loadstring(game:HttpGet("https://versusairlines.top/scripts/NewLibrary.lua"))()
local Setup = Library:Setup({
    Location = CoreGui,
    OpenCloseLocation = "Top Center"
})

client.Idled:Connect(function()
    VirtualUser:Button2Down(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
    task.wait(1)
    VirtualUser:Button2Up(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
end)

-----------------------------------------------------------------
-- PLAYER + CHARACTER REFS
-----------------------------------------------------------------

local Char = client.Character or client.CharacterAdded:Wait()
local Hum = Char:WaitForChild("Humanoid")
local HRP = Char:WaitForChild("HumanoidRootPart")
local Backpack = client:WaitForChild("Backpack")

-----------------------------------------------------------------
-- NETWORKING
-----------------------------------------------------------------

local Net = nil
pcall(function()
    Net = require(ReplicatedStorage:WaitForChild("SharedModules", 15):WaitForChild("Networking", 15))
end)
if not Net then warn("[GAG2] Networking module not reachable") end

local function safeFire(path, ...)
    if not Net then return false end
    local n = Net
    for seg in string.gmatch(path, "[^%.]+") do
        if type(n) ~= "table" then return false end
        n = n[seg]
    end
    if type(n) == "table" and type(n.Fire) == "function" then
        local ok, err = pcall(n.Fire, n, ...)
        if not ok then warn("[GAG2] safeFire "..path.." failed:", err) end
        return ok
    end
    return false
end

local RemoteRegistry = {
    PlantSeed         = "Plant.PlantSeed",
    HarvestFruit      = "Garden.CollectFruit",
    SellAll           = "NPCS.SellAll",
    SellFruit         = "NPCS.SellFruit",
    AskBidAll         = "NPCS.AskBidAll",
    CheckDailyDeal    = "NPCS.CheckDailyDeal",
    BeginSteal        = "Steal.BeginSteal",
    CompleteSteal     = "Steal.CompleteSteal",
    BuySeed           = "SeedShop.PurchaseSeed",
    BuyGear           = "GearShop.PurchaseGear",
    BuyCrate          = "CrateShop.PurchaseCrate",
    PurchasePetSlot   = "Pets.RequestPurchasePetSlot",
    EquipPet          = "Pets.PetEquipped",
    UnequipPet        = "Pets.RequestUnequipByName",
    EquipGear         = "GearShop.EquipGear",
    UnequipGear       = "GearShop.UnequipGear",
    OpenEgg           = "Egg.OpenEgg",
    OpenCrate         = "Crate.OpenCrate",
    OpenSeedPack      = "SeedPack.OpenSeedPack",
    ConfirmSeedPack   = "SeedPack.ConfirmSeedPack",
    Water             = "WateringCan.UseWateringCan",
    Shovel            = "Shovel.UseShovel",
    Trowel            = "Trowel.MovePlant",
    PlaceSprinkler    = "Place.PlaceSprinkler",
    SubmitCode        = "Settings.SubmitCode",
    OpenMail          = "Mailbox.OpenInbox",
}
local function fireNamed(name, ...)
    local path = RemoteRegistry[name]
    if not path then return false end
    return safeFire(path, ...)
end

-----------------------------------------------------------------
-- FILE PERSISTENCE
-----------------------------------------------------------------

local function saveFile(name, data) pcall(function() if writefile then writefile("GAG2_"..name..".json", data) end end) end
local function loadFile(name)
    local ok, d = pcall(function() if readfile then return readfile("GAG2_"..name..".json") end end)
    if ok and d and d ~= "" then return d end
    return nil
end

-----------------------------------------------------------------
-- INTERVAL HELPER (from Versus template)
-- Wraps callbacks in heartbeat loops with proper cleanup on toggle off.
-----------------------------------------------------------------

function interval(tag, flag, delayTime, callback)
    Library:CleanupConnectionsByTag(tag)
    delayTime = math.max(tonumber(delayTime) or 0.1, 0.05)
    if not Library.Flags[flag] then return end

    local last = 0
    local running = false
    local conn = RunService.Heartbeat:Connect(function()
        if not Library.Flags[flag] then
            Library:CleanupConnectionsByTag(tag)
            return
        end
        local current = os.clock()
        if running or current - last < delayTime then return end
        last = current
        running = true
        task.spawn(function()
            local ok, err = pcall(callback)
            if not ok then warn("[interval:"..tostring(tag).."]", err) end
            task.wait()
            running = false
        end)
    end)
    Library:TrackConnection(conn, tag)
end

function notify(title, desc, style)
    pcall(function()
        Library:createDisplayMessage(title, desc, {{text="OK"}}, style or "info")
    end)
end

function createIntervalToggle(section, cfg)
    section:createToggle({
        Name = cfg.Name,
        Flag = cfg.Flag or false,
        flagName = cfg.flagName,
        Callback = function(enabled)
            local tag = cfg.tag or cfg.flagName
            Library:CleanupConnectionsByTag(tag)
            if not enabled then return end
            interval(tag, cfg.flagName, cfg.delay or 1, cfg.Step)
        end,
    })
end

function firstOrDefault(value, fallback)
    if value == nil then return fallback end
    if type(value) == "table" then
        if value[1] ~= nil then return value[1] end
        for k, v in pairs(value) do
            if v == true then return k end
            if type(v) == "string" then return v end
        end
        return fallback
    end
    if value == "" then return fallback end
    return value
end

-----------------------------------------------------------------
-- LOGGING SYSTEM
-----------------------------------------------------------------

local Logs = {}
local MaxLogs = 500

local function addLog(level, source, msg)
    table.insert(Logs, 1, {
        time = os.time(),
        ts = os.date("%H:%M:%S"),
        level = level,
        source = source,
        msg = tostring(msg),
    })
    if #Logs > MaxLogs then table.remove(Logs) end
end

local function logInfo(s, m) addLog("info", s, m) end
local function logWarn(s, m) addLog("warn", s, m) end
local function logError(s, m) addLog("error", s, m) end
local function logSuccess(s, m) addLog("success", s, m) end

-----------------------------------------------------------------
-- SESSION STATS
-----------------------------------------------------------------

local Session = {
    startTime = os.time(),
    plantsHarvested = 0,
    fruitsSold = 0,
    seedsPlanted = 0,
    sprinklersPlaced = 0,
    stealsCompleted = 0,
    petsBought = 0,
    codesRedeemed = 0,
    dailyDealsClaimed = 0,
    mailClaimed = 0,
    seedPacksOpened = 0,
    eggsOpened = 0,
    cratesOpened = 0,
    webhookHits = 0,
    errors = 0,
}

local function formatDuration(s)
    s = math.max(0, math.floor(s))
    local h = math.floor(s/3600)
    local m = math.floor((s%3600)/60)
    local sec = s%60
    if h > 0 then return h.."h "..m.."m "..sec.."s"
    elseif m > 0 then return m.."m "..sec.."s"
    else return sec.."s" end
end

-----------------------------------------------------------------
-- AUTO-DETECT GAME LISTS
-----------------------------------------------------------------

local Seeds, Gear, Eggs, Pets, PetRarities, Mutations, ShopItems = {}, {}, {}, {}, {}, {}, {}

local function autoDetectLists()
    pcall(function()
        local sd = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("SeedData"))
        for _, e in ipairs(sd) do
            if type(e) == "table" and e.SeedName and e.RestockShop then
                table.insert(Seeds, e.SeedName)
            end
        end
    end)
    if #Seeds == 0 then
        Seeds = {"Carrot","Strawberry","Blueberry","Tulip","Tomato","Apple","Bamboo","Corn","Cactus","Pineapple","Mushroom","Green Bean","Banana","Grape","Coconut","Mango","Dragon Fruit","Acorn","Cherry","Sunflower","Venus Fly Trap","Pomegranate","Poison Apple","Moon Bloom","Dragon's Breath","Ghost Pepper","Poison Ivy","Baby Cactus","Glow Mushroom","Romanesco","Horned Melon","Gold","Rainbow"}
    end

    pcall(function()
        local gd = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("GearShopData"))
        for _, e in ipairs(gd) do if type(e) == "table" and e.ItemName then table.insert(Gear, e.ItemName) end end
    end)
    if #Gear == 0 then
        Gear = {"Common Watering Can","Common Sprinkler","Sign","Lantern","Uncommon Sprinkler","Rare Sprinkler","Legendary Sprinkler","Super Sprinkler","Trowel","Speed Mushroom","Jump Mushroom","Gnome","Shrink Mushroom","Supersize Mushroom","Invisibility Mushroom","Wheelbarrow","Teleporter","Super Watering Can","Basic Pot","Flashbang"}
    end

    pcall(function()
        local ed = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("EggData"))
        for _, e in ipairs(ed.Data) do
            if type(e) == "table" and e.EggName and e.EggName ~= "Test Egg" then
                table.insert(Eggs, e.EggName)
            end
        end
    end)
    if #Eggs == 0 then Eggs = {"Common Egg","Epic Egg"} end

    pcall(function()
        local cd = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("CrateData"))
        for _, e in ipairs(cd:GetAllCrates()) do if type(e) == "table" and e.Name then table.insert(ShopItems, e.Name) end end
    end)
    pcall(function()
        local gc = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("GuildCrateData"))
        for _, e in ipairs(gc:GetAllCrates()) do if type(e) == "table" and e.Name then table.insert(ShopItems, e.Name) end end
    end)
    local seen = {}
    local dedup = {}
    for _, c in ipairs(ShopItems) do if not seen[c] then seen[c] = true; table.insert(dedup, c) end end
    ShopItems = dedup
    if #ShopItems == 0 then
        ShopItems = {"Common Egg","Epic Egg","Common Guild Crate","Uncommon Guild Crate","Rare Guild Crate","Legendary Guild Crate","Epic Guild Crate","Mythic Guild Crate"}
    end

    pcall(function()
        local pd = require(ReplicatedStorage:WaitForChild("SharedData"):WaitForChild("PetData"))
        local rar = {}
        for _, e in pairs(pd) do
            if type(e) == "table" and e.DisplayName then
                table.insert(Pets, e.DisplayName)
                if e.Rarity then table.insert(rar, e.Rarity) end
            end
        end
        table.sort(Pets)
        local sr = {}
        for _, r in ipairs(rar) do if not sr[r] then sr[r] = true; table.insert(PetRarities, r) end end
        table.sort(PetRarities)
    end)
    if #Pets == 0 then
        Pets = {"Raccoon","Monkey","Robin","Frog","Bunny","Deer","Owl","Bee","Unicorn","Black Dragon","Ice Serpent","Golden Dragonfly"}
        PetRarities = {"Common","Uncommon","Rare","Legendary","Mythic","Super"}
    end

    pcall(function()
        local md = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("MutationData"))
        for n, e in pairs(md) do
            if type(e) == "table" and e.PriceMultiplier then table.insert(Mutations, n) end
        end
        table.sort(Mutations)
    end)
    if #Mutations == 0 then Mutations = {"Gold","Rainbow","Electric","Frozen","Bloodlit","Chained","Starstruck"} end
end

autoDetectLists()

local Sprinklers = {"Common Sprinkler","Uncommon Sprinkler","Rare Sprinkler","Legendary Sprinkler","Super Sprinkler"}

-----------------------------------------------------------------
-- PLOT DETECTION
-----------------------------------------------------------------

local PlotData = { auth = false, model = nil, id = nil, center = Vector3.zero, grid = {} }

local function getPlotId() return client:GetAttribute("PlotId") end

local function findPlot()
    local pid = getPlotId()
    if not pid then return nil end
    local gardens = Workspace:FindFirstChild("Gardens")
    if not gardens then return nil end
    return gardens:FindFirstChild("Plot" .. pid)
end

local function authPlot(force)
    if PlotData.auth and not force then return true end
    local m = findPlot()
    if not m then PlotData.auth = false; return false end
    PlotData.model = m
    PlotData.id = getPlotId()

    local areas = {}
    for _,d in ipairs(m:GetDescendants()) do
        if d:IsA("BasePart") then
            local n = d.Name:lower()
            local tagged = CollectionService:HasTag(d,"PlantArea") or CollectionService:HasTag(d,"Soil")
            if tagged or n:find("plantarea") or n:find("soil") or n:find("dirt") or n:find("farm") then
                table.insert(areas, d)
            end
        end
    end

    local minX,maxX,minZ,maxZ,cy = math.huge,-math.huge,-math.huge,math.huge,0
    if #areas == 0 then
        local cf,sz = m:GetBoundingBox()
        minX = cf.Position.X - sz.X/2; maxX = cf.Position.X + sz.X/2
        minZ = cf.Position.Z - sz.Z/2; maxZ = cf.Position.Z + sz.Z/2
        cy = cf.Position.Y
    else
        for _,a in ipairs(areas) do
            local p = a.Position; local sx = a.Size.X/2; local sz = a.Size.Z/2
            minX = math.min(minX, p.X - sx); maxX = math.max(maxX, p.X + sx)
            minZ = math.min(minZ, p.Z - sz); maxZ = math.max(maxZ, p.Z + sz)
            cy = p.Y
        end
    end

    PlotData.center = Vector3.new((minX+maxX)/2, cy, (minZ+maxZ)/2)
    PlotData.grid = {}
    local step = 3
    for x = minX+2, maxX-2, step do
        for z = minZ+2, maxZ-2, step do
            table.insert(PlotData.grid, Vector3.new(x, cy, z))
        end
    end
    for i = #PlotData.grid, 2, -1 do
        local j = math.random(i)
        PlotData.grid[i], PlotData.grid[j] = PlotData.grid[j], PlotData.grid[i]
    end
    PlotData.auth = true
    return true
end

local function plantsFolder()
    if not PlotData.auth then authPlot() end
    return PlotData.model and PlotData.model:FindFirstChild("Plants")
end

local function sprinklersFolder()
    if not PlotData.auth then authPlot() end
    return PlotData.model and PlotData.model:FindFirstChild("Sprinklers")
end

-----------------------------------------------------------------
-- MOVEMENT
-----------------------------------------------------------------

local function moveTo(target)
    if not HRP or not target then return end
    local mode = Library.Flags["TransportMode"] or "Tween"
    local goal = target + Vector3.new(0, 3.5, 0)
    if mode == "Teleport" then
        pcall(function() hrp.CFrame = CFrame.new(goal) end)
        return
    end
    local dist = (HRP.Position - target).Magnitude
    local dur = math.clamp(dist / 80, 0.15, 2)
    local tw = TweenService:Create(HRP, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(goal) })
    tw:Play()
    tw.Completed:Wait()
end

-----------------------------------------------------------------
-- TOOL HELPERS
-----------------------------------------------------------------

local function findTool(name)
    if not name or name == "" then return nil end
    local target = name:lower()
    local best, score = nil, 0
    local function scan(c)
        if not c then return end
        for _,t in ipairs(c:GetChildren()) do
            if t:IsA("Tool") then
                local tn = t.Name:lower()
                local s = 0
                if tn == target then s = 100
                elseif tn:find(target,1,true) then s = 50
                elseif target:find(tn,1,true) then s = 30 end
                if s > score then score = s; best = t end
            end
        end
    end
    scan(Char); scan(Backpack)
    return best
end

local function equipTool(tool)
    if not tool or not Hum then return false end
    if tool.Parent == Char then return true end
    if tool.Parent == Backpack then
        pcall(function() Hum:EquipTool(tool) end)
        task.wait(0.15)
    end
    return tool.Parent == Char
end

-----------------------------------------------------------------
-- TIME HELPERS
-----------------------------------------------------------------

local function isNight()
    local wv = ReplicatedStorage:FindFirstChild("WeatherValues")
    if wv then
        for _,n in ipairs({"Bloodmoon","Goldmoon","RainbowMoon","ChainedMoon","PizzaMoon"}) do
            if wv:GetAttribute(n.."_Playing") == true then return true end
        end
    end
    local t = LightingService.ClockTime
    return t < 6 or t >= 18
end

local function getSheckles()
    local ls = client:FindFirstChild("leaderstats"); if not ls then return 0 end
    for _, v in ipairs(ls:GetChildren()) do
        if v:IsA("NumberValue") or v:IsA("IntValue") then
            local n = v.Name:lower()
            if n:find("sheckle") or n:find("coin") or n:find("money") then return tonumber(v.Value) or 0 end
        end
    end
    return 0
end

local function formatSheckles(n)
    local abs = math.abs(n)
    if abs >= 1e9 then return string.format("%.2fB", n/1e9)
    elseif abs >= 1e6 then return string.format("%.2fM", n/1e6)
    elseif abs >= 1e3 then return string.format("%.2fK", n/1e3)
    else return tostring(math.floor(n)) end
end

local function rarityRank(r)
    if not r then return 0 end
    local l = r:lower()
    if l == "common" then return 1
    elseif l == "uncommon" then return 2
    elseif l == "rare" then return 3
    elseif l == "super" then return 4
    elseif l == "epic" then return 5
    elseif l == "legendary" then return 6
    elseif l == "mythic" then return 7
    end
    return 0
end

local function rarityColor(r)
    if not r then return Color3.fromRGB(200,200,200) end
    local l = r:lower()
    if l == "mythic" then return Color3.fromRGB(255,50,50)
    elseif l == "legendary" then return Color3.fromRGB(255,150,50)
    elseif l == "epic" then return Color3.fromRGB(200,50,255)
    elseif l == "super" then return Color3.fromRGB(50,200,255)
    elseif l == "rare" then return Color3.fromRGB(50,100,255)
    elseif l == "uncommon" then return Color3.fromRGB(50,255,100)
    elseif l == "common" then return Color3.fromRGB(200,200,200) end
    return Color3.fromRGB(200,200,200)
end

-----------------------------------------------------------------
-- CORE: Auto Harvest
-----------------------------------------------------------------

local function doHarvest()
    local pf = plantsFolder(); if not pf then return 0 end
    local count = 0
    for _,plant in ipairs(pf:GetChildren()) do
        if not plant:IsA("Model") then continue end
        local pid = plant:GetAttribute("PlantId"); if not pid then continue end
        local hp = plant:FindFirstChild("HarvestPrompt", true)
        if hp and hp:IsA("ProximityPrompt") and hp.Enabled then
            pcall(function()
                local old = hp.HoldDuration; hp.HoldDuration = 0
                hp:InputHoldBegin(); task.wait(0.05); hp:InputHoldEnd()
                hp.HoldDuration = old
            end)
            count = count + 1
            task.wait(0.1)
        end
        local fruits = plant:FindFirstChild("Fruits")
        if fruits then
            for _, f in ipairs(fruits:GetChildren()) do
                local fid = f:GetAttribute("FruitId") or f.Name
                fireNamed("HarvestFruit", pid, fid)
                count = count + 1
                task.wait(0.05)
            end
        end
    end
    if count > 0 then Session.plantsHarvested = Session.plantsHarvested + count end
    return count
end

-----------------------------------------------------------------
-- CORE: Auto Plant
-----------------------------------------------------------------

local function occupiedPositions()
    local occ = {}
    local pf = plantsFolder()
    if pf then for _,p in ipairs(pf:GetChildren()) do if p:IsA("Model") and p.PrimaryPart then table.insert(occ, p.PrimaryPart.Position) end end end
    local sf = sprinklersFolder()
    if sf then for _,s in ipairs(sf:GetChildren()) do if s:IsA("Model") and s.PrimaryPart then table.insert(occ, s.PrimaryPart.Position) end end end
    return occ
end

local function pickPlantPosition()
    if not PlotData.auth then authPlot() end
    if not PlotData.auth then return nil end
    local occ = occupiedPositions()
    for _, gridPos in ipairs(PlotData.grid) do
        local ok = true
        for _, op in ipairs(occ) do
            if (Vector3.new(op.X, gridPos.Y, op.Z) - gridPos).Magnitude < 2.5 then
                ok = false; break
            end
        end
        if ok then return gridPos end
    end
    return nil
end

local function doPlant()
    local seed = firstOrDefault(Library.Flags["PlantSeed"], "Carrot")
    if seed == "" or seed == "None" then return false end
    local tool = findTool(seed)
    if not tool then return false end
    if not equipTool(tool) then return false end
    if not authPlot() then return false end
    local targetPos = pickPlantPosition()
    if not targetPos then return false end
    Session.seedsPlanted = Session.seedsPlanted + 1
    return fireNamed("PlantSeed", targetPos, seed, tool)
end

-----------------------------------------------------------------
-- CORE: Auto Sell
-----------------------------------------------------------------

local function doSell()
    Session.fruitsSold = Session.fruitsSold + 1
    return fireNamed("SellAll")
end

-----------------------------------------------------------------
-- CORE: Auto Water
-----------------------------------------------------------------

local function doWater()
    local pf = plantsFolder(); if not pf then return 0 end
    local can = findTool("Watering Can") or findTool("WateringCan") or findTool("Watering")
    if can then equipTool(can) end
    local count = 0
    for _, plant in ipairs(pf:GetChildren()) do
        if not plant:IsA("Model") then continue end
        local pos = plant.PrimaryPart and plant.PrimaryPart.Position
        if not pos then continue end
        local pid = plant:GetAttribute("PlantId")
        if pid and can then
            local attr = can:GetAttribute("WateringCan") or can.Name
            if fireNamed("Water", pos, attr, can) then
                count = count + 1
                task.wait(0.1)
            end
        end
    end
    return count
end

-----------------------------------------------------------------
-- CORE: Auto Steal
-----------------------------------------------------------------

local function doSteal()
    if Library.Flags["StealOnlyNight"] and not isNight() then return end
    if not HRP then return end
    local carry = tonumber(Library.Flags["StealCarry"]) or 20
    if carry <= 0 then return end
    local stolen = 0
    local moveToPlants = Library.Flags["StealMove"]
    if moveToPlants == nil then moveToPlants = true end

    local gardens = Workspace:FindFirstChild("Gardens"); if not gardens then return end
    for _, plot in ipairs(gardens:GetChildren()) do
        if stolen >= carry then break end
        if not (plot:IsA("Model") or plot:IsA("Folder")) then continue end
        if plot == PlotData.model then continue end
        local ownerId = plot:GetAttribute("UserId") or plot:GetAttribute("OwnerId") or plot.Name
        if not ownerId or ownerId == "" or tostring(ownerId) == tostring(client.UserId) then continue end

        local pf = plot:FindFirstChild("Plants"); if not pf then continue end
        for _, plant in ipairs(pf:GetChildren()) do
            if stolen >= carry then break end
            if not plant:IsA("Model") then continue end
            local pid = plant:GetAttribute("PlantId"); if not pid then continue end
            local pos = plant.PrimaryPart and plant.PrimaryPart.Position
            if not pos then continue end
            if moveToPlants then pcall(function() moveTo(pos) end) end
            local sp = plant:FindFirstChild("StealPrompt", true)
            if sp and sp:IsA("ProximityPrompt") and sp.Enabled then
                pcall(function()
                    local old = sp.HoldDuration; sp.HoldDuration = 0
                    sp:InputHoldBegin(); task.wait(0.05); sp:InputHoldEnd()
                    sp.HoldDuration = old
                end)
                stolen = stolen + 1
                task.wait(0.2)
            else
                local fid = ""
                local fruits = plant:FindFirstChild("Fruits")
                if fruits and #fruits:GetChildren() > 0 then
                    fid = fruits:GetChildren()[1]:GetAttribute("FruitId") or fruits:GetChildren()[1].Name
                end
                fireNamed("BeginSteal", tostring(ownerId), pid, fid)
                task.wait(0.1)
                fireNamed("CompleteSteal")
                stolen = stolen + 1
                task.wait(0.3)
            end
        end
    end
    if stolen > 0 then Session.stealsCompleted = Session.stealsCompleted + stolen end
end

-----------------------------------------------------------------
-- CORE: Auto Sprinkler
-----------------------------------------------------------------

local function findBestSprinklerSpot(radius)
    local pf = plantsFolder(); if not pf then return nil, 0 end
    local positions = {}
    for _,p in ipairs(pf:GetChildren()) do
        if p:IsA("Model") and p.PrimaryPart then table.insert(positions, p.PrimaryPart.Position) end
    end
    if #positions == 0 then return nil, 0 end
    if not authPlot() then return nil, 0 end
    local best, bestCount = nil, 0
    for x = PlotData.center.X - 25, PlotData.center.X + 25, 3 do
        for z = PlotData.center.Z - 25, PlotData.center.Z + 25, 3 do
            local pos = Vector3.new(x, PlotData.center.Y, z)
            local count = 0
            for _,pp in ipairs(positions) do
                if (Vector3.new(pp.X, pos.Y, pp.Z) - pos).Magnitude <= radius then count = count + 1 end
            end
            if count > bestCount then bestCount = count; best = pos end
        end
    end
    return best, bestCount
end

local function doPlaceSprinkler(targetPos)
    local sprinklerName = firstOrDefault(Library.Flags["SprinklerType"], "Common Sprinkler")
    local tool = findTool(sprinklerName)
    if not tool then notify("Sprinkler", "No "..sprinklerName.." in inventory", "danger"); return false end
    if not equipTool(tool) then notify("Sprinkler", "Failed to equip", "danger"); return false end
    local attrName = tool:GetAttribute("Sprinkler") or sprinklerName
    Session.sprinklersPlaced = Session.sprinklersPlaced + 1
    return fireNamed("PlaceSprinkler", targetPos, attrName, tool, PlotData.id or 1)
end

local function doAutoPlaceSprinkler()
    local r = tonumber(Library.Flags["SprinklerRadius"]) or 20
    local pos, count = findBestSprinklerSpot(r)
    if not pos then notify("Sprinkler", "Plant some seeds first", "warning"); return end
    doPlaceSprinkler(pos)
end

-----------------------------------------------------------------
-- CORE: Auto Open Seed Packs + Eggs + Crates
-----------------------------------------------------------------

local function doOpenSeedPacks()
    local bp = client:FindFirstChild("Backpack"); if not bp then return 0 end
    local count = 0
    for _, item in ipairs(bp:GetChildren()) do
        if not item:IsA("Tool") then continue end
        local isPack = item:GetAttribute("SeedPack") or item:GetAttribute("IsSeedPack")
        local nm = item.Name:lower()
        if isPack or nm:find("pack") or nm:find("seedpack") then
            if fireNamed("OpenSeedPack", item) then
                count = count + 1
                Session.seedPacksOpened = Session.seedPacksOpened + 1
                task.wait(0.3)
            end
        end
    end
    return count
end

-----------------------------------------------------------------
-- ESP ENGINE
-----------------------------------------------------------------

local ESPObjects = {}

local function makeESP(obj, text, color)
    if not obj or not obj:IsDescendantOf(Workspace) then return end
    if ESPObjects[obj] then
        if ESPObjects[obj].label then ESPObjects[obj].label.Text = text end
        return
    end
    local ad = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
    if not ad then return end
    local bb = Instance.new("BillboardGui")
    bb.Name = "GAG2_ESP"
    bb.Size = UDim2.new(0, 180, 0, 35)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.Adornee = ad
    bb.Parent = obj
    local lb = Instance.new("TextLabel", bb)
    lb.Size = UDim2.new(1,0,1,0)
    lb.BackgroundTransparency = 1
    lb.TextColor3 = color or Color3.new(1,1,1)
    lb.TextStrokeTransparency = 0.3
    lb.Text = text or obj.Name
    lb.TextSize = 13
    lb.Font = Enum.Font.GothamBold
    local hl = Instance.new("Highlight", obj)
    hl.Name = "GAG2_HL"
    hl.FillColor = color or Color3.new(1,1,1)
    hl.FillTransparency = 0.85
    hl.OutlineColor = color or Color3.new(1,1,1)
    hl.OutlineTransparency = 0
    ESPObjects[obj] = { bb = bb, hl = hl, label = lb }
end

local function clearESP()
    for obj, _ in pairs(ESPObjects) do
        pcall(function()
            if obj and obj.Parent then
                for _,c in ipairs(obj:GetChildren()) do
                    if c.Name == "GAG2_ESP" or c.Name == "GAG2_HL" then c:Destroy() end
                end
            end
        end)
    end
    ESPObjects = {}
end

-----------------------------------------------------------------
-- WEBHOOKS (4 channels)
-----------------------------------------------------------------

local Webhooks = {
    main    = { url = "", ping = "", allowPing = false },
    restock = { url = "", ping = "", allowPing = false },
    rare    = { url = "", ping = "", allowPing = false },
    profit  = { url = "", ping = "", allowPing = false },
}
pcall(function()
    local d = loadFile("Webhooks")
    if d then
        local loaded = HttpService:JSONDecode(d)
        if type(loaded) == "table" then
            for k, v in pairs(loaded) do
                if Webhooks[k] and type(v) == "table" then Webhooks[k] = v end
            end
        end
    end
end)

local function saveWebhooks()
    pcall(function() saveFile("Webhooks", HttpService:JSONEncode(Webhooks)) end)
end

local function sendWebhook(hookName, content, title)
    local h = Webhooks[hookName]
    if not h or not h.url or h.url == "" then return false end
    local ping = ""
    if h.allowPing and h.ping and h.ping ~= "" then ping = h.ping .. " " end
    local body = HttpService:JSONEncode({
        content = ping .. (title and ("**"..title.."**\n"..content) or content),
        username = "GAG_2 Hub",
    })
    task.spawn(function()
        pcall(function()
            if syn and syn.request then
                syn.request({Url=h.url, Method="POST", Headers={["Content-Type"]="application/json"}, Body=body})
            elseif request then
                request({Url=h.url, Method="POST", Headers={["Content-Type"]="application/json"}, Body=body})
            elseif HttpService.PostAsync then
                HttpService:PostAsync(h.url, body)
            end
        end)
    end)
    Session.webhookHits = Session.webhookHits + 1
    return true
end

-----------------------------------------------------------------
-- EXTERNAL PREDICTOR (Discord bot text parser)
--
-- SenZ V2 bot posts messages in Discord that look like:
--   "[Next Seed Shop]"
--   "Epic restock incoming"
--   "[emoji] Next Seed Stock • in 5 minutes"
--   "🌱 Mushroom x3"
--   "🍇 Corn x1"
--   ...
--   "[Seeds Upcoming]"
--   "• Cactus x1 • 22 seconds ago"
--   "• Pineapple x1 • 22 seconds ago"
--   ...
--
-- Three ways to get these messages into the script:
--   1. Pastebin URL containing the raw text (easiest)
--   2. JSON endpoint that wraps the text (advanced)
--   3. Discord webhook messages (advanced, uses bot token)
--
-- The script supports ALL THREE formats automatically.
-----------------------------------------------------------------

local ExternalPred = { lastFetch = 0, raw = "", parsed = nil, error = nil }

-- Convert Discord duration text to seconds
-- "22 seconds ago" -> 22, "5 minutes" -> 300, "2 hours" -> 7200
local function parseDuration(text)
    if not text or text == "" then return nil end
    text = text:lower()
    local n = tonumber(text:match("(%d+)")) or 0
    if text:find("second") then return n
    elseif text:find("minute") then return n * 60
    elseif text:find("hour") then return n * 3600
    elseif text:find("day") then return n * 86400
    elseif text:find("week") then return n * 604800
    end
    return n
end

-- Strip leading emoji from a Discord line so we can match the name
-- Clean up Discord's fancy markdown so we can parse it
-- Strips: zero-width chars, Discord emoji codes <:name:id>, **bold**, __underline__, `code`
local function cleanDiscordText(text)
    if not text then return "" end
    text = text:gsub("\u200B", ""):gsub("\u200C", ""):gsub("\u200D", ""):gsub("\uFEFF", "")
    text = text:gsub("<:[%w_]+:%d+>", "")
    text = text:gsub("%*%*", ""):gsub("__", ""):gsub("`", "")
    text = text:gsub("^%s*•%s*", ""):gsub("^%s*[-#]%s*", "")
    text = text:gsub("^%*%*", ""):gsub("%*%*$", "")
    return text
end

-- Parse "22 seconds ago" / "5 minutes" / "2 hours" / "1 day" / "in 3 minutes" etc.
local function parseDuration(text)
    if not text or text == "" then return nil end
    text = text:lower():gsub("^in%s+", ""):gsub("^%s*•%s*", "")
    local n = tonumber(text:match("(%d+)")) or 0
    if text:find("second") then return n
    elseif text:find("minute") then return n * 60
    elseif text:find("hour") then return n * 3600
    elseif text:find("day") then return n * 86400
    elseif text:find("week") then return n * 604800
    elseif n > 0 then return n
    end
    return nil
end

-- Extract name + count from a Discord item line
-- Handles: "<:bamboo:123> __Bamboo__ `x7`" or "Mushroom x3"
local function parseItemLine(line)
    -- Remove all the Discord markdown noise
    local cleaned = cleanDiscordText(line)
    cleaned = cleaned:gsub("^%s*[%p]%s*", "")
    -- Look for name + xN pattern
    local name, count = cleaned:match("^([%w%s%-%_%.%']+)%s*[xX]%s*(%d+)")
    if not name then return nil end
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    return { name = name, count = tonumber(count) or 0 }
end

-- Parse SenZ V2 (or similar) Discord bot messages into structured data
-- Detects sections by their header content (handles bold/emoji variants)
local function parseDiscordText(text)
    local result = {
        currentSeed = { nextIn = nil, items = {} },
        upcomingSeed = {},
        currentGear = { nextIn = nil, items = {} },
        upcomingGear = {},
        weather = {},
        raw = text,
    }

    if not text or text == "" then return result end

    local lines = {}
    for line in text:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end

    local section = nil

    for _, rawLine in ipairs(lines) do
        local line = rawLine
        local lower = line:lower()

        -- Detect section headers (handles markdown variants)
        -- Examples: "**🟢 Next Seed Shop**", "**Next Seed Shop**", "Next Seed Shop"
        if lower:match("next%s+seed%s+shop") and not lower:match("upcoming") then
            section = "currentSeed"
        elseif lower:match("seeds?%s*upcoming") or lower:match("upcoming%s+seeds?") then
            section = "upcomingSeed"
        elseif lower:match("next%s+gear%s+shop") and not lower:match("upcoming") then
            section = "currentGear"
        elseif lower:match("gears?%s*upcoming") or lower:match("upcoming%s+gears?") then
            section = "upcomingGear"
        elseif lower:match("weather") then
            section = "weather"
        elseif lower:match("^%s*%*%*sen") or lower:match("weather predictions") then
            section = nil
            goto continue
        end

        if not section then goto continue end

        if section == "currentSeed" or section == "currentGear" then
            -- Try to extract timing header: "Next Seed Stock • in 5 minutes" or "Next Stock • in 5m"
            local inText = line:match("Next%s+%w+%s+Stock%s*•?%s*[Ii]n%s+(.+)$")
            if inText then
                result[section].nextIn = parseDuration(inText)
                goto continue
            end
            -- Item line: "Mushroom x3" or "Bamboo x7"
            local item = parseItemLine(line)
            if item and item.name ~= "" then
                -- Skip if this looks like a header (e.g. "Epic restock incoming")
                if not lower:match("restock incoming") and not lower:match("next stock") then
                    table.insert(result[section].items, item)
                end
                goto continue
            end
        end

        if section == "upcomingSeed" or section == "upcomingGear" then
            -- Items end with " ⋅" or "•" or trailing dot
            local item = parseItemLine(line)
            if item and item.name ~= "" then
                table.insert(result[section], item)
                goto continue
            end
        end

        if section == "weather" then
            -- Weather line: "Goldmoon ⋅" or "Rainbow Moon • in 13 minutes"
            local cleaned = cleanDiscordText(line)
            -- Skip the header line
            if cleaned:lower():match("weather events") then goto continue end
            -- Look for "X in Y minutes/hours"
            local wname, whenText = cleaned:match("^([%w%s%-%_%.%']+)%s*[•⋅]?%s*[Ii]n%s+(.+)$")
            if wname then
                local when = parseDuration(whenText)
                table.insert(result.weather, { name = wname:match("^%s*(.-)%s*$"), when = when })
                goto continue
            end
            -- Just name (no timing = upcoming)
            local nameOnly = cleaned:match("^([%w%s%-%_%.%']+)%s*[•⋅]?$")
            if nameOnly and #nameOnly > 2 then
                table.insert(result.weather, { name = nameOnly:match("^%s*(.-)%s*$"), when = nil })
                goto continue
            end
        end

        ::continue::
    end

    return result
endlocal function tryParseJSON(text)
    if not text then return nil end
    local trimmed = text:match("^%s*(.-)%s*$") or text
    if trimmed:sub(1,1) == "{" or trimmed:sub(1,1) == "[" then
        local ok, data = pcall(function() return HttpService:JSONDecode(trimmed) end)
        if ok and type(data) == "table" then return data end
    end
    return nil
end

-- Convert JSON to the same structure as parseDiscordText output
local function jsonToStructure(data)
    local result = {
        currentSeed = { nextIn = nil, items = {} },
        upcomingSeed = {},
        currentGear = { nextIn = nil, items = {} },
        upcomingGear = {},
        weather = {},
        raw = data,
    }

    if data.seeds and type(data.seeds) == "table" then
        for _, s in ipairs(data.seeds) do
            if type(s) == "table" then
                if s.current and s.current == true then
                    table.insert(result.currentSeed.items, {
                        name = s.name or "?",
                        count = s.stock or s.count or 0,
                    })
                    if s.next_in or s.nextIn then
                        result.currentSeed.nextIn = s.next_in or s.nextIn
                    end
                else
                    table.insert(result.upcomingSeed, {
                        name = s.name or "?",
                        count = s.stock or s.count or 0,
                        when = s.next_in or s.nextIn or s.restock_in or s.when,
                    })
                end
            end
        end
    end

    if data.gears and type(data.gears) == "table" then
        for _, g in ipairs(data.gears) do
            if type(g) == "table" then
                if g.current and g.current == true then
                    table.insert(result.currentGear.items, {
                        name = g.name or "?",
                        count = g.stock or g.count or 0,
                    })
                    if g.next_in or g.nextIn then
                        result.currentGear.nextIn = g.next_in or g.nextIn
                    end
                else
                    table.insert(result.upcomingGear, {
                        name = g.name or "?",
                        count = g.stock or g.count or 0,
                        when = g.next_in or g.nextIn or s.restock_in or s.when,
                    })
                end
            end
        end
    end

    if data.weather and type(data.weather) == "table" then
        for _, w in ipairs(data.weather) do
            if type(w) == "table" then
                table.insert(result.weather, {
                    name = w.name or "?",
                    when = w.next_in or w.nextIn or w.when,
                })
            end
        end
    end

    return result
end

-- Main fetch function
local function fetchExternalPredictions()
    local url = Library.Flags["PredSourceURL"]
    if not url or url == "" then ExternalPred.error = "No URL"; return end

    local ok, body = pcall(function() return game:HttpGet(url, true) end)
    if not ok or not body then ExternalPred.error = "Fetch failed"; return end

    ExternalPred.lastFetch = os.time()
    ExternalPred.raw = body

    -- Try JSON first
    local asJson = tryParseJSON(body)
    if asJson then
        ExternalPred.parsed = jsonToStructure(asJson)
        ExternalPred.error = nil
        logSuccess("Predictor", "Got JSON predictions")
        return
    end

    -- Fall back to Discord text parsing
    local asText = parseDiscordText(body)
    if asText then
        ExternalPred.parsed = asText
        ExternalPred.error = nil
        logSuccess("Predictor", "Got text predictions")
        return
    end

    ExternalPred.error = "Unrecognized format"
    ExternalPred.parsed = nil
end

local function fmtFuture(s)
    if not s or s <= 0 then return "any moment" end
    s = math.floor(s)
    local h = math.floor(s/3600); local m = math.floor((s%3600)/60); local d = math.floor(h/24)
    if d > 0 then return d.."d "..h%24.."h"
    elseif h > 0 then return h.."h "..m.."m"
    elseif m > 0 then return m.."m "..s%60.."s"
    else return s.."s" end
end

local function buildPredictionsText()
    if not ExternalPred.parsed then return nil end
    local p = ExternalPred.parsed
    local lines = {"=== PREDICTIONS ==="}

    if p.currentSeed and (p.currentSeed.nextIn or #p.currentSeed.items > 0) then
        table.insert(lines, "")
        table.insert(lines, "📦 SEED SHOP")
        if p.currentSeed.nextIn then
            table.insert(lines, "Next restock: "..fmtFuture(p.currentSeed.nextIn))
        end
        for _, it in ipairs(p.currentSeed.items) do
            table.insert(lines, "  • "..it.name.." x"..it.count)
        end
    end

    if p.currentGear and (p.currentGear.nextIn or #p.currentGear.items > 0) then
        table.insert(lines, "")
        table.insert(lines, "🔧 GEAR SHOP")
        if p.currentGear.nextIn then
            table.insert(lines, "Next restock: "..fmtFuture(p.currentGear.nextIn))
        end
        for _, it in ipairs(p.currentGear.items) do
            table.insert(lines, "  • "..it.name.." x"..it.count)
        end
    end

    if p.upcomingSeed and #p.upcomingSeed > 0 then
        table.insert(lines, "")
        table.insert(lines, "🌱 SEEDS UPCOMING")
        for _, it in ipairs(p.upcomingSeed) do
            local line = "  • "..it.name.." x"..it.count
            if it.when then line = line.." - "..fmtFuture(it.when) end
            table.insert(lines, line)
        end
    end

    if p.upcomingGear and #p.upcomingGear > 0 then
        table.insert(lines, "")
        table.insert(lines, "⚙️ GEARS UPCOMING")
        for _, it in ipairs(p.upcomingGear) do
            local line = "  • "..it.name.." x"..it.count
            if it.when then line = line.." - "..fmtFuture(it.when) end
            table.insert(lines, line)
        end
    end

    if p.weather and #p.weather > 0 then
        table.insert(lines, "")
        table.insert(lines, "🌤️ WEATHER EVENTS")
        for _, w in ipairs(p.weather) do
            local line = "  • "..w.name
            if w.when == 0 then line = line.." (ACTIVE)"
            elseif w.when then line = line.." in "..fmtFuture(w.when)
            end
            table.insert(lines, line)
        end
    end

    return table.concat(lines, "\n")
end

-----------------------------------------------------------------
-- SERVER HELPERS
-----------------------------------------------------------------

local function hopServer()
    pcall(function()
        local http = game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100")
        local data = HttpService:JSONDecode(http)
        if data and data.data then
            for _,s in ipairs(data.data) do
                if s.playing < s.maxPlayers and s.id ~= game.JobId then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id)
                    return true
                end
            end
        end
    end)
    return false
end

local function rejoin() pcall(function() TeleportService:Teleport(game.PlaceId, client) end) end

-----------------------------------------------------------------
-- UI SECTIONS
-----------------------------------------------------------------

local Home = Setup:CreateSection("🏠 Home")
local Farm = Setup:CreateSection("🌱 Farm")
local Shop = Setup:CreateSection("🛒 Shop")
local WebhookSec = Setup:CreateSection("🔔 Webhooks")
local ESP = Setup:CreateSection("👁️ ESP")
local Predictors = Setup:CreateSection("🔮 Predictors")
local Gameplay = Setup:CreateSection("🎮 Gameplay")
local Logs = Setup:CreateSection("📜 Logs")
local Stats = Setup:CreateSection("📊 Stats")

-----------------------------------------------------------------
-- 🏠 HOME
-----------------------------------------------------------------

Home:createLabel({ Name = "GAG_2", Special = true })
Home:createLabel({ Name = "Grow a Garden 2 - Autofarm", Center = true })

Home:createDropdown({
    Name = "Movement Mode",
    flagName = "TransportMode",
    List = {"Tween", "Teleport"},
    Flag = "Tween",
})

Home:createLabel({ Name = "Plot", Special = true })

Home:createButton({
    Name = "Refresh Plot",
    Callback = function()
        authPlot(true)
        if PlotData.auth then
            notify("Plot", "Plot #"..tostring(PlotData.id).." - "..#PlotData.grid.." plant slots", "info")
        else
            notify("Plot", "No plot - join a server", "warning")
        end
    end,
})

Home:createButton({
    Name = "TP to Garden",
    Callback = function() if authPlot() then moveTo(PlotData.center) end end,
})

Home:createButton({
    Name = "Check Sheckles",
    Callback = function() notify("Sheckles", "Current: "..formatSheckles(getSheckles()), "info") end,
})

Home:createLabel({ Name = "Server", Special = true })
Home:createButton({ Name = "Rejoin Server", Callback = rejoin })
Home:createButton({
    Name = "Hop Server",
    Callback = function()
        if hopServer() then notify("Server", "Hopping...", "info")
        else notify("Server", "No servers found", "danger") end
    end,
})

-----------------------------------------------------------------
-- 🌱 FARM (Harvest / Plant / Sell / Water / Steal / Sprinkler / Packs)
-----------------------------------------------------------------

Farm:createLabel({ Name = "- [ Harvest ] -", Special = true })

createIntervalToggle(Farm, {
    Name = "Auto Harvest",
    flagName = "AutoHarvest",
    tag = "AutoHarvest",
    delay = 0.1,
    Step = doHarvest,
})

Farm:createLabel({ Name = "- [ Plant ] -", Special = true })

Farm:createDropdown({
    Name = "Seed To Plant",
    flagName = "PlantSeed",
    List = Seeds,
    Flag = "Carrot",
})

Farm:createButton({
    Name = "Plant Now",
    Callback = function()
        if doPlant() then notify("Plant", "Planted!", "info")
        else notify("Plant", "No empty spot or missing tool", "warning") end
    end,
})

createIntervalToggle(Farm, {
    Name = "Auto Plant Loop",
    flagName = "AutoPlantLoop",
    tag = "AutoPlantLoop",
    delay = 2,
    Step = doPlant,
})

Farm:createLabel({ Name = "- [ Sell ] -", Special = true })

Farm:createButton({
    Name = "Sell All Now",
    Callback = function() doSell(); notify("Sell", "Fired", "info") end,
})

createIntervalToggle(Farm, {
    Name = "Auto Sell Loop",
    flagName = "AutoSellLoop",
    tag = "AutoSellLoop",
    delay = 30,
    Step = doSell,
})

Farm:createLabel({ Name = "- [ Water ] -", Special = true })

createIntervalToggle(Farm, {
    Name = "Auto Water",
    flagName = "AutoWaterLoop",
    tag = "AutoWaterLoop",
    delay = 1,
    Step = doWater,
})

Farm:createLabel({ Name = "- [ Steal ] -", Special = true })

Farm:createToggle({ Name = "Only At Night", flagName = "StealOnlyNight", Flag = true })
Farm:createToggle({ Name = "Walk To Plants", flagName = "StealMove", Flag = true })
Farm:createSlider({ Name = "Carry Limit", flagName = "StealCarry", value = 20, minValue = 1, maxValue = 100 })

createIntervalToggle(Farm, {
    Name = "Auto Steal",
    flagName = "AutoSteal",
    tag = "AutoSteal",
    delay = 1,
    Step = doSteal,
})

Farm:createLabel({ Name = "- [ Sprinkler ] -", Special = true })

Farm:createDropdown({
    Name = "Sprinkler Type",
    flagName = "SprinklerType",
    List = Sprinklers,
    Flag = "Common Sprinkler",
})

Farm:createSlider({
    Name = "Coverage Radius",
    flagName = "SprinklerRadius",
    value = 20,
    minValue = 10,
    maxValue = 60,
})

Farm:createButton({
    Name = "Place Sprinkler Now",
    Callback = doAutoPlaceSprinkler,
})

createIntervalToggle(Farm, {
    Name = "Auto Place Sprinkler",
    flagName = "AutoSprinklerLoop",
    tag = "AutoSprinklerLoop",
    delay = 30,
    Step = doAutoPlaceSprinkler,
})

Farm:createLabel({ Name = "- [ Seed Packs / Eggs ] -", Special = true })

Farm:createButton({
    Name = "Open All Seed Packs",
    Callback = function()
        local n = doOpenSeedPacks()
        notify("Packs", "Opened "..n.." packs", "info")
    end,
})

createIntervalToggle(Farm, {
    Name = "Auto Open Seed Packs",
    flagName = "AutoOpenPacks",
    tag = "AutoOpenPacks",
    delay = 2,
    Step = doOpenSeedPacks,
})

Farm:createDropdown({
    Name = "Egg/Crate",
    flagName = "BuyCrate",
    List = ShopItems,
    Flag = "Common Egg",
})

Farm:createButton({
    Name = "Open Selected",
    Callback = function()
        local n = firstOrDefault(Library.Flags["BuyCrate"], "Common Egg")
        if n:find("Egg") then
            fireNamed("OpenEgg", n); notify("Egg", "Opening", "info")
        else
            fireNamed("OpenCrate", n); notify("Crate", "Opening", "info")
        end
    end,
})

-----------------------------------------------------------------
-- 🛒 SHOP
-----------------------------------------------------------------

Shop:createLabel({ Name = "- [ Shop Seeds ] -", Special = true })

Shop:createDropdown({
    Name = "Seed",
    flagName = "BuySeed",
    List = Seeds,
    Flag = "Carrot",
})

Shop:createButton({
    Name = "Buy Seed",
    Callback = function() fireNamed("BuySeed", firstOrDefault(Library.Flags["BuySeed"], "Carrot")); notify("Shop", "Bought", "info") end,
})

createIntervalToggle(Shop, {
    Name = "Auto Buy Seed",
    flagName = "AutoBuySeedLoop",
    tag = "AutoBuySeedLoop",
    delay = 3,
    Step = function() fireNamed("BuySeed", firstOrDefault(Library.Flags["BuySeed"], "Carrot")) end,
})

createIntervalToggle(Shop, {
    Name = "Auto Buy ALL Seeds",
    flagName = "AutoBuyAllSeedsLoop",
    tag = "AutoBuyAllSeedsLoop",
    delay = 15,
    Step = function() for _, s in ipairs(Seeds) do fireNamed("BuySeed", s); task.wait(0.3) end end,
})

Shop:createLabel({ Name = "- [ Shop Gear ] -", Special = true })

Shop:createDropdown({
    Name = "Gear",
    flagName = "BuyGear",
    List = Gear,
    Flag = "Common Sprinkler",
})

Shop:createButton({
    Name = "Buy Gear",
    Callback = function() fireNamed("BuyGear", firstOrDefault(Library.Flags["BuyGear"], "Common Sprinkler")); notify("Shop", "Bought", "info") end,
})

createIntervalToggle(Shop, {
    Name = "Auto Buy Gear",
    flagName = "AutoBuyGearLoop",
    tag = "AutoBuyGearLoop",
    delay = 3,
    Step = function() fireNamed("BuyGear", firstOrDefault(Library.Flags["BuyGear"], "Common Sprinkler")) end,
})

createIntervalToggle(Shop, {
    Name = "Auto Buy ALL Gear",
    flagName = "AutoBuyAllGearLoop",
    tag = "AutoBuyAllGearLoop",
    delay = 20,
    Step = function() for _, g in ipairs(Gear) do fireNamed("BuyGear", g); task.wait(0.3) end end,
})

Shop:createLabel({ Name = "- [ Shop Egg/Crate ] -", Special = true })

Shop:createDropdown({
    Name = "Egg/Crate",
    flagName = "BuyCrate",
    List = ShopItems,
    Flag = "Common Egg",
})

Shop:createButton({
    Name = "Buy Egg/Crate",
    Callback = function() fireNamed("BuyCrate", firstOrDefault(Library.Flags["BuyCrate"], "Common Egg")); notify("Shop", "Bought", "info") end,
})

createIntervalToggle(Shop, {
    Name = "Auto Buy Egg/Crate",
    flagName = "AutoBuyCrateLoop",
    tag = "AutoBuyCrateLoop",
    delay = 5,
    Step = function() fireNamed("BuyCrate", firstOrDefault(Library.Flags["BuyCrate"], "Common Egg")) end,
})

Shop:createLabel({ Name = "- [ Buy Roaming Pets ] -", Special = true })

Shop:createDropdown({
    Name = "Pet",
    flagName = "BuyPet",
    List = Pets,
    Flag = "Raccoon",
})

Shop:createButton({
    Name = "Buy Pet Slot",
    Callback = function() fireNamed("PurchasePetSlot", firstOrDefault(Library.Flags["BuyPet"], "Raccoon")); Session.petsBought = Session.petsBought + 1; notify("Shop", "Bought slot", "info") end,
})

createIntervalToggle(Shop, {
    Name = "Auto Buy Pet Slot",
    flagName = "AutoBuyPetLoop",
    tag = "AutoBuyPetLoop",
    delay = 4,
    Step = function() fireNamed("PurchasePetSlot", firstOrDefault(Library.Flags["BuyPet"], "Raccoon")); Session.petsBought = Session.petsBought + 1 end,
})

Shop:createLabel({ Name = "- [ Codes ] -", Special = true })

Shop:createInputBox({
    Name = "Redeem Code",
    flagName = "RedeemCode",
    Placeholder = "Enter code",
    Flag = "",
})

Shop:createButton({
    Name = "Redeem",
    Callback = function()
        local code = firstOrDefault(Library.Flags["RedeemCode"], "")
        if code and code ~= "" then
            fireNamed("SubmitCode", code)
            Session.codesRedeemed = Session.codesRedeemed + 1
            notify("Code", "Submitted: "..code, "info")
        end
    end,
})

-----------------------------------------------------------------
-- 🔔 WEBHOOKS
-----------------------------------------------------------------

WebhookSec:createLabel({ Name = "- [ Main ] -", Special = true })

WebhookSec:createInputBox({
    Name = "Main Webhook URL",
    flagName = "WebhookURL",
    Placeholder = "https://discord.com/api/webhooks/...",
    Flag = "",
})

WebhookSec:createInputBox({
    Name = "Ping ID (optional)",
    flagName = "PingID",
    Placeholder = "<@your_id>",
    Flag = "",
})

WebhookSec:createToggle({
    Name = "Allow Ping",
    flagName = "AllowPing",
    Flag = false,
    Callback = function(v) Webhooks.main.allowPing = v; saveWebhooks() end,
})

WebhookSec:createButton({
    Name = "Test Main Webhook",
    Callback = function() sendWebhook("main", "Test from GAG_2", "Test"); notify("Webhook", "Sent", "info") end,
})

WebhookSec:createLabel({ Name = "- [ Restock ] -", Special = true })

WebhookSec:createInputBox({
    Name = "Restock Webhook URL",
    flagName = "RestockWH",
    Placeholder = "https://discord.com/api/webhooks/...",
    Flag = "",
})

WebhookSec:createToggle({
    Name = "Notify On Restock",
    flagName = "NotifyRestock",
    Flag = false,
})

WebhookSec:createLabel({ Name = "- [ Rare Find ] -", Special = true })

WebhookSec:createInputBox({
    Name = "Rare Webhook URL",
    flagName = "RareWH",
    Placeholder = "https://discord.com/api/webhooks/...",
    Flag = "",
})

WebhookSec:createToggle({
    Name = "Notify On Rare Find",
    flagName = "NotifyRare",
    Flag = false,
})

WebhookSec:createLabel({ Name = "- [ Profit ] -", Special = true })

WebhookSec:createInputBox({
    Name = "Profit Webhook URL",
    flagName = "ProfitWH",
    Placeholder = "https://discord.com/api/webhooks/...",
    Flag = "",
})

WebhookSec:createToggle({
    Name = "Notify On Profit Change",
    flagName = "NotifyProfit",
    Flag = false,
})

-----------------------------------------------------------------
-- 👁️ ESP
-----------------------------------------------------------------

ESP:createLabel({ Name = "- [ ESP Filters ] -", Special = true })

ESP:createDropdown({
    Name = "Fruit Filter",
    flagName = "ESPFruit",
    List = {"All", unpack(Seeds)},
    Flag = "All",
})

ESP:createDropdown({
    Name = "Rarity Filter",
    flagName = "ESPRarity",
    List = {"All", "Common", "Uncommon", "Rare", "Super", "Epic", "Legendary", "Mythic"},
    Flag = "All",
})

ESP:createDropdown({
    Name = "Mutation Filter",
    flagName = "ESPMutation",
    List = {"All", unpack(Mutations)},
    Flag = "All",
})

ESP:createLabel({ Name = "- [ ESP Modes ] -", Special = true })

ESP:createToggle({
    Name = "ESP My Plants",
    flagName = "ESPPlantsOn",
    Flag = false,
    Callback = function(enabled)
        Library:CleanupConnectionsByTag("ESPPlantsOn")
        if not enabled then clearESP(); return end
        interval("ESPPlantsOn", "ESPPlantsOn", 2, function()
            local pf = plantsFolder(); if not pf then return end
            for _,plant in ipairs(pf:GetChildren()) do
                if not plant:IsA("Model") then continue end
                local sname = plant:GetAttribute("SeedName") or plant.Name
                local r = plant:GetAttribute("Rarity") or "Common"
                local mut = plant:GetAttribute("Mutation") or ""
                if (Library.Flags["ESPFruit"] or "All") ~= "All" and sname ~= Library.Flags["ESPFruit"] then continue end
                if (Library.Flags["ESPRarity"] or "All") ~= "All" and r ~= Library.Flags["ESPRarity"] then continue end
                if (Library.Flags["ESPMutation"] or "All") ~= "All" and mut ~= Library.Flags["ESPMutation"] then continue end
                local text = sname.." | "..r
                if mut ~= "" then text = text.." ["..mut.."]" end
                makeESP(plant, text, rarityColor(r))
            end
        end)
    end,
})

ESP:createToggle({
    Name = "ESP All Plots (Steal Targets)",
    flagName = "ESPAllPlotsOn",
    Flag = false,
    Callback = function(enabled)
        Library:CleanupConnectionsByTag("ESPAllPlotsOn")
        if not enabled then clearESP(); return end
        interval("ESPAllPlotsOn", "ESPAllPlotsOn", 2, function()
            local gardens = Workspace:FindFirstChild("Gardens")
            if not gardens then return end
            for _,plot in ipairs(gardens:GetChildren()) do
                if not (plot:IsA("Model") or plot:IsA("Folder")) then continue end
                local pf = plot:FindFirstChild("Plants"); if not pf then continue end
                for _,plant in ipairs(pf:GetChildren()) do
                    if not plant:IsA("Model") then continue end
                    local sname = plant:GetAttribute("SeedName") or plant.Name
                    local r = plant:GetAttribute("Rarity") or "Common"
                    local mut = plant:GetAttribute("Mutation") or ""
                    local text = sname.." | "..r
                    if mut ~= "" then text = text.." ["..mut.."]" end
                    if plot ~= PlotData.model then text = text.." [STEAL]" end
                    makeESP(plant, text, rarityColor(r))
                end
            end
        end)
    end,
})

ESP:createToggle({
    Name = "ESP Sprinklers",
    flagName = "ESPSprinklersOn",
    Flag = false,
    Callback = function(enabled)
        Library:CleanupConnectionsByTag("ESPSprinklersOn")
        if not enabled then clearESP(); return end
        interval("ESPSprinklersOn", "ESPSprinklersOn", 3, function()
            local sf = sprinklersFolder(); if not sf then return end
            for _,s in ipairs(sf:GetChildren()) do
                if s:IsA("Model") then makeESP(s, s.Name, Color3.fromRGB(100,200,255)) end
            end
        end)
    end,
})

ESP:createToggle({
    Name = "ESP NPCs",
    flagName = "ESPNPCsOn",
    Flag = false,
    Callback = function(enabled)
        Library:CleanupConnectionsByTag("ESPNPCsOn")
        if not enabled then clearESP(); return end
        interval("ESPNPCsOn", "ESPNPCsOn", 4, function()
            local npcs = Workspace:FindFirstChild("NPCS") or Workspace:FindFirstChild("NPCs")
            if npcs then
                for _,npc in ipairs(npcs:GetChildren()) do
                    if npc:IsA("Model") then makeESP(npc, npc.Name.." [NPC]", Color3.fromRGB(255,200,50)) end
                end
            end
        end)
    end,
})

ESP:createButton({
    Name = "Clear All ESP",
    Callback = function() clearESP(); notify("ESP", "Cleared", "info") end,
})

-----------------------------------------------------------------
-- 🔮 PREDICTORS (External Discord bot source)
--
-- The bot (e.g. SenZ V2) posts predictions as Discord messages.
-- To make this work, follow the setup below.
--
-- OPTION A - Pastebin (easiest):
--   1. Open Pastebin, paste the bot's message text as "Unlisted"
--   2. Copy the RAW URL (pastebin.com/raw/XXXX)
--   3. Paste it in "Prediction Source URL" below
--
-- OPTION B - JSON endpoint (cleaner):
--   Host a JSON file at any URL with this format:
--   {
--     "seeds": [{"name":"Carrot","stock":0,"next_in":300}],
--     "weather": [{"name":"Bloodmoon","next_in":1800}]
--   }
--   Script auto-detects JSON vs text format.
--
-- OPTION C - Discord channel export:
--   Use a Discord-to-webhook mirror service to pipe channel messages
--   to a public URL, then paste that URL.
--
-- The script supports ALL THREE formats. It tries JSON first,
-- falls back to Discord text parser.
-----------------------------------------------------------------

Predictors:createLabel({ Name = "- [ Setup ] -", Special = true })
Predictors:createLabel({ Name = "Paste a URL with the bot's message text or JSON", Center = true })

Predictors:createInputBox({
    Name = "Prediction Source URL",
    flagName = "PredSourceURL",
    Placeholder = "https://pastebin.com/raw/... or JSON URL",
    Flag = "",
})

Predictors:createSlider({
    Name = "Refresh Interval (sec)",
    flagName = "PredRefresh",
    value = 60,
    minValue = 15,
    maxValue = 600,
})

Predictors:createButton({
    Name = "Fetch Predictions Now",
    Callback = function()
        fetchExternalPredictions()
        if ExternalPred.error then
            notify("Predictor", "Error: "..ExternalPred.error, "danger")
        elseif ExternalPred.parsed then
            notify("Predictor", "Predictions fetched OK", "info")
        end
    end,
})

Predictors:createButton({
    Name = "Show Predictions",
    Callback = function()
        if not ExternalPred.parsed then
            notify("Predictor", "No data yet. Set URL + Fetch Now first.", "warning"); return
        end
        local text = buildPredictionsText()
        if text then notify("Predictor", text, "info") end
    end,
})

Predictors:createToggle({
    Name = "Auto Fetch Predictions Loop",
    flagName = "AutoFetchPred",
    Flag = false,
    Callback = function(enabled)
        Library:CleanupConnectionsByTag("AutoFetchPred")
        if not enabled then return end
        interval("AutoFetchPred", "AutoFetchPred", function()
            local v = tonumber(Library.Flags["PredRefresh"]) or 60
            return math.max(15, v)
        end, function() fetchExternalPredictions() end)
    end,
})

Predictors:createButton({
    Name = "Send Predictions to Webhook",
    Callback = function()
        if not ExternalPred.parsed then notify("Predictor", "No data yet", "warning"); return end
        local text = buildPredictionsText()
        if text then sendWebhook("main", text, "Predictions"); notify("Predictor", "Sent to webhook", "info") end
    end,
})

Predictors:createLabel({ Name = "- [ Current Game Stock ] -", Special = true })

Predictors:createButton({
    Name = "Show Current Game Stock",
    Callback = function()
        local stock = ReplicatedStorage:FindFirstChild("StockValues"); if not stock then notify("Stock", "No data", "warning"); return end
        local lines = {"=== GAME STOCK (LIVE) ==="}
        for _,shop in ipairs(stock:GetChildren()) do
            local items = shop:FindFirstChild("Items"); if not items then continue end
            table.insert(lines, "")
            table.insert(lines, "["..shop.Name.."]")
            for _,item in ipairs(items:GetChildren()) do
                if item:IsA("NumberValue") then
                    table.insert(lines, "  "..item.Name.." x"..item.Value)
                end
            end
        end
        notify("Stock", table.concat(lines, "\n"), "info")
    end,
})

Predictors:createButton({
    Name = "Show Current Weather",
    Callback = function()
        local wv = ReplicatedStorage:FindFirstChild("WeatherValues"); if not wv then notify("Weather", "No data", "warning"); return end
        local lines = {"=== GAME WEATHER (LIVE) ==="}
        local any = false
        for _,w in ipairs({"Bloodmoon","Goldmoon","RainbowMoon","ChainedMoon","PizzaMoon","Starfall","Snowfall","Rainbow","Rain"}) do
            local playing = wv:GetAttribute(w.."_Playing") == true
            if playing then any = true; table.insert(lines, w.." ACTIVE") end
        end
        if not any then table.insert(lines, "No weather active") end
        notify("Weather", table.concat(lines, "\n"), "info")
    end,
})

-----------------------------------------------------------------
-- 🎮 GAMEPLAY MODS
-----------------------------------------------------------------

Gameplay:createLabel({ Name = "- [ Visuals ] -", Special = true })

Gameplay:createToggle({
    Name = "Fullbright",
    flagName = "Fullbright",
    Flag = false,
    Callback = function(v)
        if v then
            LightingService.Ambient = Color3.fromRGB(255,255,255)
            LightingService.OutdoorAmbient = Color3.fromRGB(255,255,255)
            LightingService.Brightness = 4
            LightingService.FogEnd = 100000
            LightingService.GlobalShadows = false
        else
            LightingService.Brightness = 3
            LightingService.GlobalShadows = true
        end
    end,
})

Gameplay:createToggle({
    Name = "More FPS",
    flagName = "MoreFPS",
    Flag = false,
    Callback = function(v)
        if v then
            LightingService.GlobalShadows = false
            LightingService.FogEnd = 9e9
            pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
            for _,d in ipairs(Workspace:GetDescendants()) do
                if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Beam") then d.Enabled = false end
            end
        end
    end,
})

Gameplay:createLabel({ Name = "- [ Protection ] -", Special = true })

Gameplay:createToggle({
    Name = "Anti-Fling",
    flagName = "AntiFling",
    Flag = false,
    Callback = function(enabled)
        Library:CleanupConnectionsByTag("AntiFling")
        if not enabled then return end
        interval("AntiFling", "AntiFling", 0.2, function()
            if HRP and HRP.Velocity.Magnitude > 200 then
                HRP.Velocity = Vector3.zero
                HRP.AngularVelocity = Vector3.zero
            end
        end)
    end,
})

Gameplay:createToggle({
    Name = "Less Knockback",
    flagName = "LessKnockback",
    Flag = false,
    Callback = function(enabled)
        Library:CleanupConnectionsByTag("LessKnockback")
        if not enabled then return end
        interval("LessKnockback", "LessKnockback", 0.2, function()
            if HRP and HRP.Velocity.Magnitude > 60 then HRP.Velocity = HRP.Velocity * 0.5 end
        end)
    end,
})

Gameplay:createToggle({
    Name = "Instant Proximity Prompts",
    flagName = "InstantPrompt",
    Flag = false,
    Callback = function(enabled)
        Library:CleanupConnectionsByTag("InstantPrompt")
        if not enabled then return end
        interval("InstantPrompt", "InstantPrompt", 2, function()
            for _, pp in ipairs(Workspace:GetDescendants()) do
                if pp:IsA("ProximityPrompt") then pp.HoldDuration = 0 end
            end
        end)
    end,
})

Gameplay:createToggle({
    Name = "Bypass Gameplay Paused",
    flagName = "BypassPause",
    Flag = false,
    Callback = function(enabled)
        Library:CleanupConnectionsByTag("BypassPause")
        if not enabled then return end
        interval("BypassPause", "BypassPause", 0.5, function()
            local pg = client:FindFirstChild("PlayerGui")
            if pg then
                for _,g in ipairs(pg:GetChildren()) do
                    if g:IsA("ScreenGui") and g.Name:lower():find("pause") then g.Enabled = false end
                end
            end
        end)
    end,
})

Gameplay:createToggle({
    Name = "Anti-Stuck Recover",
    flagName = "AutoStuckRecover",
    Flag = false,
})

Gameplay:createLabel({ Name = "- [ Player ] -", Special = true })

Gameplay:createSlider({
    Name = "Walk Speed",
    flagName = "WalkSpeed",
    value = 16,
    minValue = 16,
    maxValue = 200,
})

Gameplay:createToggle({
    Name = "Auto Set Walk Speed",
    flagName = "AutoSpeed",
    Flag = false,
    Callback = function(enabled)
        Library:CleanupConnectionsByTag("AutoSpeed")
        if not enabled then return end
        interval("AutoSpeed", "AutoSpeed", 0.5, function()
            if Hum then Hum.WalkSpeed = tonumber(Library.Flags["WalkSpeed"]) or 16 end
        end)
    end,
})

Gameplay:createSlider({
    Name = "Jump Power",
    flagName = "JumpPower",
    value = 50,
    minValue = 50,
    maxValue = 250,
})

Gameplay:createToggle({
    Name = "Auto Set Jump Power",
    flagName = "AutoJump",
    Flag = false,
    Callback = function(enabled)
        Library:CleanupConnectionsByTag("AutoJump")
        if not enabled then return end
        interval("AutoJump", "AutoJump", 0.5, function()
            if Hum then Hum.JumpPower = tonumber(Library.Flags["JumpPower"]) or 50 end
        end)
    end,
})

Gameplay:createButton({
    Name = "Reset Walk/Jump to Default",
    Callback = function() if Hum then Hum.WalkSpeed = 16; Hum.JumpPower = 50 end; notify("Player", "Reset", "info") end,
})

Gameplay:createLabel({ Name = "- [ Inventory ] -", Special = true })

Gameplay:createButton({
    Name = "Drop All Tools",
    Callback = function()
        local bp = client:FindFirstChild("Backpack")
        if bp then for _,t in ipairs(bp:GetChildren()) do if t:IsA("Tool") then t.Parent = Workspace end end end
        notify("Tools", "Dropped all", "info")
    end,
})

Gameplay:createButton({
    Name = "Equip Current Tool",
    Callback = function()
        local c = Char
        if c then local t = c:FindFirstChildWhichIsA("Tool"); if t then pcall(function() Hum:EquipTool(t) end) end end
    end,
})

-----------------------------------------------------------------
-- 📜 LOGS VIEWER
-----------------------------------------------------------------

Logs:createLabel({ Name = "Logs Viewer", Special = true })
Logs:createLabel({ Name = "Last "..MaxLogs.." events (newest first)", Center = true })

Logs:createButton({
    Name = "Show Last 50 Logs",
    Callback = function()
        local lines = {"=== LOGS ("..#Logs..") ==="}
        for i = 1, math.min(50, #Logs) do
            local l = Logs[i]
            table.insert(lines, "["..l.ts.."] "..l.level:upper().." "..l.source..": "..l.msg)
        end
        notify("Logs", table.concat(lines, "\n"), "info")
    end,
})

Logs:createButton({
    Name = "Clear All Logs",
    Callback = function() Logs = {}; notify("Logs", "Cleared", "info") end,
})

Logs:createButton({
    Name = "Send Logs to Main Webhook",
    Callback = function()
        local lines = {"=== RECENT LOGS ==="}
        for i = 1, math.min(50, #Logs) do
            local l = Logs[i]
            table.insert(lines, "["..l.ts.."] "..l.level:upper().." "..l.source..": "..l.msg)
        end
        sendWebhook("main", table.concat(lines, "\n"), "Logs Dump")
        notify("Logs", "Sent", "info")
    end,
})

-----------------------------------------------------------------
-- 📊 STATS VIEWER
-----------------------------------------------------------------

Stats:createLabel({ Name = "Session Statistics", Special = true })

Stats:createButton({
    Name = "Show Session Stats",
    Callback = function()
        local elapsed = os.time() - Session.startTime
        local lines = {
            "=== SESSION STATS ===",
            "Duration: "..formatDuration(elapsed),
            "Plants Harvested: "..Session.plantsHarvested,
            "Fruits Sold: "..Session.fruitsSold,
            "Seeds Planted: "..Session.seedsPlanted,
            "Sprinklers Placed: "..Session.sprinklersPlaced,
            "Steals Completed: "..Session.stealsCompleted,
            "Pets Bought: "..Session.petsBought,
            "Seed Packs Opened: "..Session.seedPacksOpened,
            "Eggs/Crates Opened: "..(Session.eggsOpened + Session.cratesOpened),
            "Codes Redeemed: "..Session.codesRedeemed,
            "Daily Deals: "..Session.dailyDealsClaimed,
            "Webhook Hits: "..Session.webhookHits,
            "Current Sheckles: "..formatSheckles(getSheckles()),
        }
        notify("Stats", table.concat(lines, "\n"), "info")
    end,
})

Stats:createButton({
    Name = "Send Stats to Webhook",
    Callback = function()
        local elapsed = os.time() - Session.startTime
        local body = "Duration: "..formatDuration(elapsed)
            .."\nPlants: "..Session.plantsHarvested
            .."\nSold: "..Session.fruitsSold
            .."\nSeeds: "..Session.seedsPlanted
            .."\nSteals: "..Session.stealsCompleted
            .."\nSheckles: "..formatSheckles(getSheckles())
        sendWebhook("main", body, "Session Stats")
        notify("Stats", "Sent", "info")
    end,
})

Stats:createButton({
    Name = "Reset Stats",
    Callback = function()
        Session.plantsHarvested = 0; Session.fruitsSold = 0
        Session.seedsPlanted = 0; Session.sprinklersPlaced = 0
        Session.stealsCompleted = 0; Session.petsBought = 0
        Session.seedPacksOpened = 0; Session.eggsOpened = 0; Session.cratesOpened = 0
        Session.codesRedeemed = 0; Session.dailyDealsClaimed = 0; Session.mailClaimed = 0
        Session.webhookHits = 0; Session.errors = 0
        Session.startTime = os.time()
        notify("Stats", "Reset", "info")
    end,
})

-----------------------------------------------------------------
-- BACKGROUND TASKS
-----------------------------------------------------------------

task.spawn(function()
    local lastPos, stuck = nil, 0
    while task.wait(1) do
        pcall(function()
            if not HRP then return end
            if lastPos then
                if (HRP.Position - lastPos).Magnitude < 0.3 then stuck = stuck + 1
                else stuck = 0 end
                if stuck > 30 and Library.Flags["AutoStuckRecover"] then
                    HRP.CFrame = HRP.CFrame + Vector3.new(0,5,0)
                    stuck = 0
                end
            end
            lastPos = HRP.Position
        end)
    end
end)

-- Restock webhook: fires when item goes 0 -> >0 (LIVE game detection, no predictor needed)
task.spawn(function()
    local prev = {}
    while task.wait(10) do
        if not Library.Flags["NotifyRestock"] then continue end
        pcall(function()
            local stock = ReplicatedStorage:FindFirstChild("StockValues")
            if not stock then return end
            for _,shop in ipairs(stock:GetChildren()) do
                local items = shop:FindFirstChild("Items")
                if items then
                    if not prev[shop.Name] then prev[shop.Name] = {} end
                    for _,item in ipairs(items:GetChildren()) do
                        if item:IsA("NumberValue") then
                            local name = item.Name; local count = item.Value
                            local was = prev[shop.Name][name] or 0
                            if was == 0 and count > 0 then
                                sendWebhook("restock", shop.Name.." restocked: **"..name.."** x"..count, "Restock")
                                Session.webhookHits = Session.webhookHits + 1
                            end
                            prev[shop.Name][name] = count
                        end
                    end
                end
            end
        end)
    end
end)

-- Rare find webhook
task.spawn(function()
    while task.wait(5) do
        if not Library.Flags["NotifyRare"] then continue end
        pcall(function()
            local pf = plantsFolder(); if not pf then return end
            for _, plant in ipairs(pf:GetChildren()) do
                if not plant:IsA("Model") then continue end
                local r = plant:GetAttribute("Rarity") or "Common"
                local mut = plant:GetAttribute("Mutation") or ""
                if r == "Legendary" or r == "Mythic" or mut == "Gold" or mut == "Rainbow" then
                    local sname = plant:GetAttribute("SeedName") or plant.Name
                    sendWebhook("rare", sname.." | "..r.." | "..mut, "Rare Find")
                    Session.webhookHits = Session.webhookHits + 1
                end
            end
        end)
    end
end)

-- Profit webhook
task.spawn(function()
    local last = 0
    while task.wait(60) do
        if not Library.Flags["NotifyProfit"] then continue end
        if os.time() - last < 60 then continue end
        last = os.time()
        local s = getSheckles()
        if s > 0 then
            sendWebhook("profit", "Current sheckles: **"..formatSheckles(s).."**", "Profit")
            Session.webhookHits = Session.webhookHits + 1
        end
    end
end)

client.CharacterAdded:Connect(function(c)
    Char = c
    Hum = c:WaitForChild("Humanoid")
    HRP = c:WaitForChild("HumanoidRootPart")
    Backpack = client:WaitForChild("Backpack")
    task.wait(1)
    authPlot(true)
end)

task.spawn(function()
    task.wait(2)
    authPlot()
    if PlotData.auth then
        print("[GAG2] Ready | Plot #"..tostring(PlotData.id).." | "..#PlotData.grid.." plant slots")
    end
end)

notify("GAG_2", "Loaded - external predictor ready", "info")
print("[GAG2] Loaded")

local request = (syn and syn.request) or (http and http.request) or http_request

-- Essential services
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LightingService = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local TeleportService = game:GetService("TeleportService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local LocalizationService = game:GetService("LocalizationService")
local StarterGui = game:GetService("StarterGui")
local Camera = Workspace.CurrentCamera
local client = Players.LocalPlayer

-- Load UI
print("Loading Library...")
local Library = loadstring(game:HttpGet("https://versusairlines.top/scripts/NewLibrary.lua"))()

local Setup = Library:Setup({
    Location = CoreGui,
    OpenCloseLocation = "Bottom Right"
})

-- Prevent player from being idled out
client.Idled:Connect(function()
    VirtualUser:Button2Down(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
    task.wait(1)
    VirtualUser:Button2Up(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
end)

-----------------------------------------------------------------

local unpackArgs = table.unpack or unpack
local Shared = ReplicatedStorage:WaitForChild("Shared", 15)
local SharedList = Shared and Shared:FindFirstChild("List")

-----------------------------------------------------------------
-- Safe wrappers
-----------------------------------------------------------------

function safeRequire(module, label)
    if not module then
        warn("[GAG2] Missing module:", tostring(label or module))
        return nil
    end

    local ok, result = pcall(require, module)
    if not ok then
        warn("[GAG2] Failed to require", tostring(label or module), result)
        return nil
    end

    return result
end

function findPath(root, path)
    local node = root
    for _, name in ipairs(path) do
        if not node then return nil end
        node = node:FindFirstChild(name)
    end
    return node
end

function safeRequirePath(root, path, label)
    return safeRequire(findPath(root, path), label or table.concat(path, "."))
end

function safeServiceCall(service, methodName, ...)
    if not service then return nil, "missing_service" end
    local member = service[methodName]
    if member == nil then return nil, "missing_method:" .. tostring(methodName) end

    local args = { ... }
    local ok, result = pcall(function()
        if type(member) == "function" then
            return member(service, unpackArgs(args))
        end
        if member.Fire then
            return member:Fire(unpackArgs(args))
        end
        if member.Invoke then
            return member:Invoke(unpackArgs(args))
        end
        if member.FireServer then
            return member:FireServer(unpackArgs(args))
        end
        if member.InvokeServer then
            return member:InvokeServer(unpackArgs(args))
        end
    end)

    if not ok then
        warn("[GAG2] service call failed:", tostring(methodName), result)
        return nil, result
    end

    return result
end

function safeFire(path, ...)
    if not Net then return false end
    local n = Net
    for seg in string.gmatch(path, "[^%.]+") do
        if type(n) ~= "table" then return false end
        n = n[seg]
    end
    if type(n) == "table" and type(n.Fire) == "function" then
        return pcall(n.Fire, n, ...)
    end
    return false
end

function firstValue(v)
    if type(v) == "table" then return v[1] end
    return v
end

function addUnique(list, value)
    if value == nil then return end
    for _, existing in ipairs(list) do
        if existing == value then return end
    end
    table.insert(list, value)
end

-----------------------------------------------------------------
-- Player + character refs
-----------------------------------------------------------------

local Char = client.Character or client.CharacterAdded:Wait()
local Hum = Char:WaitForChild("Humanoid")
local HRP = Char:WaitForChild("HumanoidRootPart")
local Backpack = client:WaitForChild("Backpack")

local Net = nil
pcall(function() Net = require(ReplicatedStorage:WaitForChild("SharedModules", 15):WaitForChild("Networking", 15)) end)
if not Net then warn("[GAG2] Networking module not reachable") end

-----------------------------------------------------------------
-- Session stats
-----------------------------------------------------------------

local Session = {
    startTime = os.time(),
    plantsHarvested = 0,
    fruitsSold = 0,
    petsBought = 0,
    eggsOpened = 0,
    cratesOpened = 0,
    seedsPlanted = 0,
    sprinklersPlaced = 0,
    stealsCompleted = 0,
    bargainsCompleted = 0,
    bidsAsked = 0,
    webhookHits = 0,
    errors = 0,
    mailClaimed = 0,
    codesRedeemed = 0,
    dailyDealsClaimed = 0,
}

-----------------------------------------------------------------
-- Plot + spatial state
-----------------------------------------------------------------

local PlotData = { auth = false, model = nil, id = nil, center = Vector3.zero, grid = {}, gate = nil }
local ESPObjects = {}
local TracerObjects = {}
local BoxObjects = {}
local SavedPositions = {}
local _conns = {}
local Logs = {}
local MaxLogs = 300

-----------------------------------------------------------------
-- Auto-detect lists from game data modules
-----------------------------------------------------------------

local Seeds = {}
local Gear = {}
local Crates = {}
local Eggs = {}
local Pets = {}
local PetRarities = {}
local Mutations = {}
local FruitValues = {}
local SeedRarities = {}
local PetBasePrices = {}

local function autoDetectLists()
    pcall(function()
        local sd = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("SeedData"))
        for _, e in ipairs(sd) do
            if type(e) == "table" and e.SeedName and e.RestockShop then
                table.insert(Seeds, e.SeedName)
                if e.Rarity then SeedRarities[e.SeedName] = e.Rarity end
            end
        end
    end)
    if #Seeds == 0 then Seeds = {"Carrot","Strawberry","Blueberry","Tulip","Tomato","Apple","Bamboo","Corn","Cactus","Pineapple","Mushroom","Green Bean","Banana","Grape","Coconut","Mango","Dragon Fruit","Acorn","Cherry","Sunflower","Venus Fly Trap","Pomegranate","Poison Apple","Moon Bloom","Dragon's Breath","Ghost Pepper","Poison Ivy","Baby Cactus","Glow Mushroom","Romanesco","Horned Melon","Gold","Rainbow"} end

    pcall(function()
        local gd = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("GearShopData"))
        for _, e in ipairs(gd) do if type(e) == "table" and e.ItemName then table.insert(Gear, e.ItemName) end end
    end)
    if #Gear == 0 then Gear = {"Common Watering Can","Common Sprinkler","Sign","Lantern","Uncommon Sprinkler","Rare Sprinkler","Legendary Sprinkler","Super Sprinkler","Trowel","Speed Mushroom","Jump Mushroom","Gnome","Shrink Mushroom","Supersize Mushroom","Invisibility Mushroom","Wheelbarrow","Teleporter","Super Watering Can","Basic Pot","Flashbang"} end

    pcall(function()
        local ed = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("EggData"))
        for _, e in ipairs(ed.Data) do if type(e) == "table" and e.EggName and e.EggName ~= "Test Egg" then table.insert(Eggs, e.EggName) end end
    end)
    if #Eggs == 0 then Eggs = {"Common Egg","Epic Egg"} end

    pcall(function()
        local cd = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("CrateData"))
        for _, e in ipairs(cd:GetAllCrates()) do if type(e) == "table" and e.Name then table.insert(Crates, e.Name) end end
    end)
    pcall(function()
        local gc = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("GuildCrateData"))
        for _, e in ipairs(gc:GetAllCrates()) do if type(e) == "table" and e.Name then table.insert(Crates, e.Name) end end
    end)
    if #Crates == 0 then Crates = {"Common Guild Crate","Uncommon Guild Crate","Rare Guild Crate","Legendary Guild Crate","Epic Guild Crate","Mythic Guild Crate","Arch Crate","Bear Trap Crate","Bench Crate","Bridge Crate","Conveyor Crate","Fence Crate","Ladder Crate","Owner Door Crate","Roleplay Crate","Seesaw Crate","Sign Crate","Spring Crate","Teleporter Pad Crate","Common Bear Trap","Gold Bear Trap","Rainbow Bear Trap"} end
    local seen, dedup = {}, {}
    for _, c in ipairs(Crates) do if not seen[c] then seen[c] = true; table.insert(dedup, c) end end
    Crates = dedup

    pcall(function()
        local pd = require(ReplicatedStorage:WaitForChild("SharedData"):WaitForChild("PetData"))
        local rar = {}
        for n, e in pairs(pd) do
            if type(e) == "table" and e.DisplayName then
                table.insert(Pets, e.DisplayName)
                if e.Rarity then table.insert(rar, e.Rarity) end
                if e.BasePrice then PetBasePrices[n] = e.BasePrice end
            end
        end
        table.sort(Pets)
        local sr = {}
        for _, r in ipairs(rar) do if not sr[r] then sr[r] = true; table.insert(PetRarities, r) end end
        table.sort(PetRarities)
    end)
    if #Pets == 0 then Pets = {"Raccoon","Monkey","Robin","Frog","Bunny","Deer","Owl","Bee","Unicorn","Black Dragon","Ice Serpent","Golden Dragonfly"}; PetRarities = {"Common","Uncommon","Rare","Legendary","Mythic","Super"} end

    pcall(function()
        local md = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("MutationData"))
        for n, e in pairs(md) do
            if type(e) == "table" and e.PriceMultiplier then
                table.insert(Mutations, n)
                FruitValues[n] = e.PriceMultiplier or 1
            end
        end
        table.sort(Mutations)
    end)
    if #Mutations == 0 then Mutations = {"Gold","Rainbow","Electric","Frozen","Bloodlit","Chained","Starstruck"} end
end

autoDetectLists()

local ShopItems = {}
local _sa = {}
for _, e in ipairs(Eggs) do if not _sa[e] then _sa[e] = true; table.insert(ShopItems, e) end end
for _, c in ipairs(Crates) do if not _sa[c] then _sa[c] = true; table.insert(ShopItems, c) end end

local Sprinklers = {"Common Sprinkler","Uncommon Sprinkler","Rare Sprinkler","Legendary Sprinkler","Super Sprinkler"}

-----------------------------------------------------------------
-- Core utility
-----------------------------------------------------------------

local function getHRP() local c = client.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum() local c = client.Character; return c and c:FindFirstChildOfClass("Humanoid") end
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

    local areas, gate = {}, nil
    for _,d in ipairs(m:GetDescendants()) do
        if d:IsA("BasePart") then
            local n = d.Name:lower()
            local tagged = CollectionService:HasTag(d,"PlantArea") or CollectionService:HasTag(d,"Soil")
            if tagged or n:find("plantarea") or n:find("soil") or n:find("dirt") or n:find("farm") then
                table.insert(areas, d)
            end
            if n:find("gate") or n:find("entrance") or n:find("spawn") then gate = d end
        end
    end

    local minX,maxX,minZ,maxZ,cy = math.huge,-math.huge,math.huge,-math.huge,0
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
    PlotData.gate = gate or PlotData.center
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

local function droppedItemsFolder() return Workspace:FindFirstChild("DroppedItems") end

local function moveTo(target)
    local hrp = getHRP()
    if not hrp or not target then return false end
    local mode = Library.Flags["TransportMode"] or "Tween"
    local goal = target + Vector3.new(0, 3.5, 0)
    if mode == "Teleport" then pcall(function() hrp.CFrame = CFrame.new(goal) end); return true end
    local dist = (hrp.Position - target).Magnitude
    local dur = math.clamp(dist / 80, 0.15, 2)
    local ok, tw = pcall(function()
        return TweenService:Create(hrp, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(goal) })
    end)
    if ok and tw then tw:Play(); tw.Completed:Wait(); return true end
    return false
end

local function firePrompt(p)
    if not p or not p:IsA("ProximityPrompt") then return end
    pcall(function()
        local old = p.HoldDuration
        p.HoldDuration = 0
        p:InputHoldBegin()
        task.wait(0.05)
        p:InputHoldEnd()
        p.HoldDuration = old
    end)
end

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
                elseif target:find(tn,1,true) then s = 30
                end
                if s > score then score = s; best = t end
            end
        end
    end
    scan(client.Character); scan(Backpack)
    return best
end

local function equipTool(tool)
    if not tool or not Hum then return false end
    if tool.Parent == Backpack then
        pcall(function() Hum:EquipTool(tool) end)
        task.wait(0.1)
    end
    return tool.Parent == client.Character
end

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

local function saveFile(name, data) pcall(function() if writefile then writefile("GAG2_"..name..".json", data) end end) end

local function loadFile(name)
    local ok, d = pcall(function() if readfile then return readfile("GAG2_"..name..".json") end end)
    if ok and d and d ~= "" then return d end
    return nil
end

local function cleanup(tag)
    if not _conns[tag] then return end
    for _, c in ipairs(_conns[tag]) do
        pcall(function()
            if typeof(c) == "RBXScriptConnection" then c:Disconnect()
            elseif typeof(c) == "thread" then task.cancel(c)
            end
        end)
    end
    _conns[tag] = nil
end

local function track(tag, conn)
    if not _conns[tag] then _conns[tag] = {} end
    table.insert(_conns[tag], conn)
end

local function firstSelected(value, fallback)
    if type(value) == "table" then
        if value[1] ~= nil then return value[1] end
        for k, v in pairs(value) do
            if v == true then return k end
            if type(v) == "string" then return v end
        end
        return fallback
    end
    if value == nil or value == "" then return fallback end
    return value
end

local function asNumber(value, fallback)
    local n = tonumber(value)
    if n then return n end
    return fallback
end

-----------------------------------------------------------------
-- Versus template helpers (from Versus template)
-----------------------------------------------------------------

function interval(tag, flag, delayTime, callback)
    Library:CleanupConnectionsByTag(tag)
    delayTime = math.max(tonumber(delayTime) or 0.1, 0.05)
    if not Library.Flags[flag] then
        return
    end

    local last = 0
    local running = false
    local slowWarnAt = 0
    local conn = RunService.Heartbeat:Connect(function()
        if not Library.Flags[flag] then
            Library:CleanupConnectionsByTag(tag)
            return
        end

        local current = os.clock()
        if running or current - last < delayTime then
            return
        end

        last = current
        running = true

        local spawnFn = task and task.spawn or spawn
        spawnFn(function()
            local startedAt = os.clock()
            local ok, err = pcall(callback)
            local elapsed = os.clock() - startedAt

            if not ok then
                warn("[interval:" .. tostring(tag) .. "]", err)
            elseif elapsed > 10 and os.clock() - slowWarnAt > 5 then
                slowWarnAt = os.clock()
                warn(string.format("[GAG2] slow interval %s took %.3fs", tostring(tag), elapsed))
            end

            local waitFn = task and task.wait or wait
            waitFn()
            running = false
        end)
    end)

    Library:TrackConnection(conn, tag)
end

function notify(title, desc, style)
    pcall(function()
        Library:createDisplayMessage(title, desc, {{ text = "OK" }}, style or "info")
    end)
end

-----------------------------------------------------------------
-- RCU-style interval toggle + todo toggle helpers
-----------------------------------------------------------------

function createIntervalToggle(section, cfg)
    section:createToggle({
        Name = cfg.Name,
        Warning = cfg.Warning,
        WarnIf = cfg.WarnIf,
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

function createTodoToggle(section, name, flagName, note)
    section:createToggle({
        Name = tostring(name) .. " (TODO)",
        Flag = false,
        flagName = flagName,
        Callback = function(enabled)
            Library:CleanupConnectionsByTag(flagName)
            if not enabled then return end
            interval(flagName, flagName, 5, function()
                -- blank
            end)
        end,
    })
end

-----------------------------------------------------------------
-- Logging system
-----------------------------------------------------------------

local function addLog(level, source, msg)
    table.insert(Logs, 1, { time = os.time(), ts = os.date("%H:%M:%S"), level = level, source = source, msg = msg })
    if #Logs > MaxLogs then table.remove(Logs) end
end

local function logInfo(s, m) addLog("info", s, m) end
local function logWarn(s, m) addLog("warn", s, m) end
local function logError(s, m) addLog("error", s, m); Session.errors = Session.errors + 1 end
local function logProfit(s, m) addLog("profit", s, m) end

-----------------------------------------------------------------
-- Multiple webhooks (6 separate channels)
-----------------------------------------------------------------

local Webhooks = {
    main = { url = "", ping = "", allowPing = false },
    restock = { url = "", ping = "", allowPing = false },
    pets = { url = "", ping = "", allowPing = false },
    event = { url = "", ping = "", allowPing = false },
    rare = { url = "", ping = "", allowPing = false },
    profit = { url = "", ping = "", allowPing = false },
}
pcall(function()
    local d = loadFile("Webhooks")
    if d then
        local loaded = HttpService:JSONDecode(d)
        if type(loaded) == "table" then
            for k, v in pairs(loaded) do
                if Webhooks[k] and type(v) == "table" then
                    Webhooks[k] = v
                end
            end
        end
    end
end)

local function httpPost(url, body)
    if not url or url == "" then return end
    pcall(function()
        if syn and syn.request then syn.request({ Url = url, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
        elseif request then request({ Url = url, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
        elseif HttpService.PostAsync then HttpService:PostAsync(url, body)
        end
    end)
end

local function sendToHook(hookName, content, title)
    local h = Webhooks[hookName]
    if not h or not h.url or h.url == "" then return false end
    local ping = ""
    if h.allowPing and h.ping and h.ping ~= "" then ping = h.ping .. " " end
    local body = HttpService:JSONEncode({
        ["content"] = ping .. (title and ("**"..title.."**\n"..content) or content),
        ["username"] = "GAG_2 Hub",
    })
    task.spawn(function() httpPost(h.url, body) end)
    Session.webhookHits = Session.webhookHits + 1
    return true
end

local function sendHook(content, title) return sendToHook("main", content, title) end

-----------------------------------------------------------------
-- Profiles (multi-config save)
-----------------------------------------------------------------

local Profiles = { current = "default", list = { "default" } }
pcall(function() local d = loadFile("Profiles"); if d then local loaded = HttpService:JSONDecode(d); if type(loaded) == "table" then Profiles = loaded end end end)
local function saveProfiles() pcall(function() saveFile("Profiles", HttpService:JSONEncode(Profiles)) end) end

-----------------------------------------------------------------
-- Remote registry (all real paths from game source)
-----------------------------------------------------------------

local RemoteRegistry = {
    PlantSeed = "Plant.PlantSeed",
    PlaceSprinkler = "Place.PlaceSprinkler",
    PlaceGnome = "Place.PlaceGnome",
    PlaceProp = "Place.PlaceProp",
    PlaceLadder = "Place.PlaceLadder",
    PlaceRake = "Place.PlaceRake",
    PlaceBird = "Place.PlaceBird",
    PlacePottedPlant = "PotPlacement.PlacePottedPlant",
    RemoveGnome = "Place.RemoveGnome",
    PickupProp = "Prop.PickupProp",
    HarvestFruit = "Garden.CollectFruit",
    SellAll = "NPCS.SellAll",
    SellFruit = "NPCS.SellFruit",
    AskBidAll = "NPCS.AskBidAll",
    CheckDailyDeal = "NPCS.CheckDailyDeal",
    BeginSteal = "Steal.BeginSteal",
    CompleteSteal = "Steal.CompleteSteal",
    CancelSteal = "Steal.CancelSteal",
    BuySeed = "SeedShop.PurchaseSeed",
    BuyGear = "GearShop.PurchaseGear",
    BuyCrate = "CrateShop.PurchaseCrate",
    EquipGear = "GearShop.EquipGear",
    UnequipGear = "GearShop.UnequipGear",
    EquipPet = "Pets.PetEquipped",
    UnequipPet = "Pets.RequestUnequipByName",
    PurchasePetSlot = "Pets.RequestPurchasePetSlot",
    GetEquippedPets = "Pets.GetEquippedPets",
    OpenEgg = "Egg.OpenEgg",
    ConfirmEgg = "Egg.ConfirmEgg",
    OpenCrate = "Crate.OpenCrate",
    OpenSeedPack = "SeedPack.OpenSeedPack",
    ConfirmSeedPack = "SeedPack.ConfirmSeedPack",
    Water = "WateringCan.UseWateringCan",
    Shovel = "Shovel.UseShovel",
    ShovelHit = "Shovel.HitPlayer",
    Trowel = "Trowel.MovePlant",
    BearTrap = "BearTrap.BearTrap",
    FreezeRay = "FreezeRay.Fire",
    SpringFire = "Spring.SpringFire",
    VineActivate = "VineWrapper.Activate",
    PowerHose = "PowerHose.Activate",
    CrowbarSwing = "Crowbar.SwingCrowbar",
    SignText = "SignTool.SetSignText",
    RequestDrop = "DroppedItem.RequestDrop",
    SubmitCode = "Settings.SubmitCode",
    InstantGrant = "DevProducts.InstantGrant",
    ClaimMail = "Mailbox.Claim",
    OpenMail = "Mailbox.OpenInbox",
    SendMail = "Mailbox.SendBatch",
    JoinGuild = "Guild.Invite",
    LeaveGuild = "Guild.Leave",
    KickGuild = "Guild.Kick",
    CheckGuild = "Guild.GetMyGuild",
}
local function fireNamed(name, ...) local path = RemoteRegistry[name]; if not path then return false end; return safeFire(path, ...) end

-----------------------------------------------------------------
-- Stealth / anti-pattern
-----------------------------------------------------------------

local Stealth = { enabled = false, sessionStart = os.time(), maxSessionLength = 7200, humanJitter = 0.15 }
local BehaviorTracker = { lastAction = "", lastTime = 0, repeatCount = 0 }

-----------------------------------------------------------------
-- ESP engine (extended with tracers + boxes)
-----------------------------------------------------------------

local function makeESP(obj, text, color, dist)
    if not obj or not obj:IsDescendantOf(Workspace) then return end
    if ESPObjects[obj] then
        if ESPObjects[obj].label then ESPObjects[obj].label.Text = text end
        if ESPObjects[obj].distLabel and dist then ESPObjects[obj].distLabel.Text = "[ " .. math.floor(dist) .. " studs ]" end
        if ESPObjects[obj].hl then ESPObjects[obj].hl.OutlineColor = color; ESPObjects[obj].hl.FillColor = color end
        return
    end
    local ad = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
    if not ad then return end
    local bb = Instance.new("BillboardGui")
    bb.Name = "GAG2_ESP"
    bb.Size = UDim2.new(0, 180, 0, 50)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.Adornee = ad
    bb.Parent = obj
    local lb = Instance.new("TextLabel", bb)
    lb.Size = UDim2.new(1, 0, 0.6, 0)
    lb.Position = UDim2.new(0, 0, 0, 0)
    lb.BackgroundTransparency = 1
    lb.TextColor3 = color or Color3.new(1,1,1)
    lb.TextStrokeTransparency = 0.3
    lb.Text = text or obj.Name
    lb.TextSize = 13
    lb.Font = Enum.Font.GothamBold
    local db = Instance.new("TextLabel", bb)
    db.Size = UDim2.new(1, 0, 0.4, 0)
    db.Position = UDim2.new(0, 0, 0.6, 0)
    db.BackgroundTransparency = 1
    db.TextColor3 = color or Color3.new(1,1,1)
    db.TextStrokeTransparency = 0.5
    db.TextSize = 11
    db.Font = Enum.Font.Gotham
    db.Text = dist and ("[ "..math.floor(dist).." studs ]") or ""
    local hl = Instance.new("Highlight", obj)
    hl.Name = "GAG2_HL"
    hl.FillColor = color or Color3.new(1,1,1)
    hl.FillTransparency = 0.85
    hl.OutlineColor = color or Color3.new(1,1,1)
    hl.OutlineTransparency = 0
    ESPObjects[obj] = { bb = bb, hl = hl, label = lb, distLabel = db }
end

local function makeTracer(obj, color)
    if TracerObjects[obj] then return end
    if not obj or not obj:IsDescendantOf(Workspace) then return end
    local ad = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
    if not ad then return end
    local att0 = Instance.new("Attachment"); att0.Name = "GAG2_TraceTop"; att0.Position = Vector3.new(0, 3, 0); att0.Parent = ad
    local att1 = Instance.new("Attachment"); att1.Name = "GAG2_TraceBot"; att1.Position = Vector3.new(0, -3, 0); att1.Parent = ad
    local beam = Instance.new("Beam"); beam.Name = "GAG2_Tracer"
    beam.Attachment0 = att0; beam.Attachment1 = att1
    beam.Color = ColorSequence.new(color or Color3.new(1,0,0))
    beam.Width0 = 0.15; beam.Width1 = 0.05
    beam.FaceCamera = true; beam.Parent = ad
    TracerObjects[obj] = { beam = beam, att0 = att0, att1 = att1 }
end

local function makeBox(obj, color, size)
    if BoxObjects[obj] then return end
    if not obj or not obj:IsDescendantOf(Workspace) then return end
    local ad = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
    if not ad then return end
    local box = Instance.new("BoxHandleAdornment"); box.Name = "GAG2_Box"
    box.Adornee = ad; box.AlwaysOnTop = true; box.ZIndex = 5
    box.Size = size or Vector3.new(4, 4, 4)
    box.Color3 = color or Color3.new(1, 0, 0)
    box.Transparency = 0.5
    box.Parent = ad
    BoxObjects[obj] = { box = box }
end

local function clearESP()
    for obj, _ in pairs(ESPObjects) do
        pcall(function()
            if obj and obj.Parent then
                for _, c in ipairs(obj:GetChildren()) do
                    if c.Name == "GAG2_ESP" or c.Name == "GAG2_HL" then c:Destroy() end
                end
            end
        end)
    end
    for obj, data in pairs(TracerObjects) do
        pcall(function()
            if data.att0 then data.att0:Destroy() end
            if data.att1 then data.att1:Destroy() end
            if data.beam then data.beam:Destroy() end
        end)
    end
    for obj, data in pairs(BoxObjects) do
        pcall(function() if data.box then data.box:Destroy() end end)
    end
    ESPObjects = {}; TracerObjects = {}; BoxObjects = {}
end

-----------------------------------------------------------------
-- Color + rarity helpers
-----------------------------------------------------------------

local function rarityColor(r)
    if not r then return Color3.fromRGB(200,200,200) end
    local l = r:lower()
    if l == "mythic" then return Color3.fromRGB(255,50,50)
    elseif l == "legendary" then return Color3.fromRGB(255,150,50)
    elseif l == "epic" then return Color3.fromRGB(200,50,255)
    elseif l == "super" then return Color3.fromRGB(50,200,255)
    elseif l == "rare" then return Color3.fromRGB(50,100,255)
    elseif l == "uncommon" then return Color3.fromRGB(50,255,100)
    elseif l == "common" then return Color3.fromRGB(200,200,200)
    end
    return Color3.fromRGB(200,200,200)
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

local function getAllHarvestables(scope)
    scope = scope or "own"
    local list = {}
    local gardens = Workspace:FindFirstChild("Gardens")
    if not gardens then return list end
    for _,plot in ipairs(gardens:GetChildren()) do
        if not (plot:IsA("Model") or plot:IsA("Folder")) then continue end
        if scope == "own" and plot ~= PlotData.model then continue end
        if scope == "all" and plot == PlotData.model then continue end
        local pf = plot:FindFirstChild("Plants")
        if not pf then continue end
        for _,plant in ipairs(pf:GetChildren()) do
            if not plant:IsA("Model") then continue end
            local sname = plant:GetAttribute("SeedName") or plant.Name
            local rarity = plant:GetAttribute("Rarity") or "Common"
            local mut = plant:GetAttribute("Mutation") or ""
            local weight = plant:GetAttribute("Weight") or plant:GetAttribute("Value") or 0
            table.insert(list, {
                Model = plant, SeedName = sname, Rarity = rarity, Mutation = mut,
                Weight = tonumber(weight) or 0, PlantId = plant:GetAttribute("PlantId"),
                Plot = plot, IsFruit = false,
            })
            local fruits = plant:FindFirstChild("Fruits")
            if fruits then
                for _, f in ipairs(fruits:GetChildren()) do
                    local fid = f:GetAttribute("FruitId") or f.Name
                    local fweight = f:GetAttribute("Weight") or f:GetAttribute("Value") or 0
                    table.insert(list, {
                        Model = f, Parent = plant, SeedName = sname, Rarity = rarity, Mutation = mut,
                        Weight = tonumber(fweight) or 0, PlantId = plant:GetAttribute("PlantId"),
                        FruitId = fid, Plot = plot, IsFruit = true,
                    })
                end
            end
        end
    end
    return list
end

local function passesFilter(item, mode, filter, rarity, mutation, thresholdMode, threshold)
    if filter ~= "All" and filter ~= nil and filter ~= "" then
        if not string.find(item.SeedName:lower(), filter:lower(), 1, true) then return false end
    end
    if rarity and rarity ~= "All" and rarity ~= "" then
        if item.Rarity ~= rarity then return false end
    end
    if mutation and mutation ~= "Any" and mutation ~= "All" and mutation ~= "" then
        if item.Mutation ~= mutation then return false end
    end
    if thresholdMode == "Above Weight" and threshold and threshold > 0 then
        if item.Weight < threshold then return false end
    elseif thresholdMode == "Below Weight" and threshold and threshold > 0 then
        if item.Weight > threshold then return false end
    end
    return true
end

local function collectItem(item)
    if item.IsFruit then
        fireNamed("HarvestFruit", item.PlantId, item.FruitId)
    else
        local hp = item.Model:FindFirstChild("HarvestPrompt", true)
        if hp and hp:IsA("ProximityPrompt") and hp.Enabled then
            firePrompt(hp)
            return true
        end
    end
    return true
end

local function occupiedPositions()
    local occ = {}
    local pf = plantsFolder()
    if pf then
        for _,c in ipairs(pf:GetChildren()) do
            if c:IsA("Model") and c.PrimaryPart then table.insert(occ, c.PrimaryPart.Position) end
        end
    end
    local sf = sprinklersFolder()
    if sf then
        for _,c in ipairs(sf:GetChildren()) do
            if c:IsA("Model") and c.PrimaryPart then table.insert(occ, c.PrimaryPart.Position) end
        end
    end
    return occ
end

local function getValidPlantPositions(occupied, nearPos, mode)
    local positions = {}
    if not PlotData.auth then authPlot() end
    if mode == "Sprinkler Radius" and nearPos then
        local r = asNumber(Library.Flags["PlantRadius"], 8)
        for x = nearPos.X - r, nearPos.X + r, 2 do
            for z = nearPos.Z - r, nearPos.Z + r, 2 do
                table.insert(positions, Vector3.new(x, nearPos.Y, z))
            end
        end
    else
        positions = PlotData.grid
    end
    local valid = {}
    for _, p in ipairs(positions) do
        local taken = false
        for _, o in ipairs(occupied) do
            if (Vector3.new(o.X, p.Y, o.Z) - p).Magnitude < 2.5 then taken = true; break end
        end
        if not taken then table.insert(valid, p) end
    end
    for i = #valid, 2, -1 do local j = math.random(i); valid[i], valid[j] = valid[j], valid[i] end
    return valid
end

-----------------------------------------------------------------
-- Action handlers
-----------------------------------------------------------------

local function doPlant()
    local seed = firstSelected(Library.Flags["PlantSeed"], "Carrot")
    if seed == "" or seed == "None" then return false end
    local positionMode = firstSelected(Library.Flags["PlantPosition"], "Random")
    local tool = findTool(seed)
    if not tool then return false end
    if not equipTool(tool) then return false end
    if not authPlot() then return false end
    local occ = occupiedPositions()
    local targetPos = nil
    if positionMode == "Saved Position" and SavedPositions["Plant"] then targetPos = SavedPositions["Plant"]
    elseif positionMode == "Player Position" then local hrp = getHRP(); if hrp then targetPos = hrp.Position end
    elseif positionMode == "Sprinkler Radius" then
        local sf = sprinklersFolder()
        if sf and #sf:GetChildren() > 0 then local s = sf:GetChildren()[1]; if s.PrimaryPart then targetPos = s.PrimaryPart.Position end end
    else
        local valid = getValidPlantPositions(occ, nil, "grid")
        if #valid > 0 then targetPos = valid[1] end
    end
    if not targetPos then return false end
    Session.seedsPlanted = Session.seedsPlanted + 1
    logInfo("Plant", seed.." planted at "..tostring(targetPos))
    return safeFire("Plant.PlantSeed", targetPos, seed, tool)
end

local function doSteal()
    if Library.Flags["StealOnlyNight"] and not isNight() then return end
    local hrp = getHRP(); if not hrp then return end
    local gardens = Workspace:FindFirstChild("Gardens"); if not gardens then return end
    local carry = asNumber(Library.Flags["StealCarry"], 20)
    local stolen = 0
    local fruit = firstSelected(Library.Flags["StealFruit"], "All")
    local rarity = firstSelected(Library.Flags["StealRarity"], "All")
    local mutation = firstSelected(Library.Flags["StealMutation"], "All")
    for _,plot in ipairs(gardens:GetChildren()) do
        if stolen >= carry then break end
        if not (plot:IsA("Model") or plot:IsA("Folder")) then continue end
        if plot == PlotData.model then continue end
        local oid = plot:GetAttribute("UserId") or plot:GetAttribute("OwnerId")
        if not oid or oid == client.UserId then continue end
        local pf = plot:FindFirstChild("Plants"); if not pf then continue end
        for _,plant in ipairs(pf:GetChildren()) do
            if stolen >= carry then break end
            if not plant:IsA("Model") then continue end
            local sname = plant:GetAttribute("SeedName") or plant.Name
            local r = plant:GetAttribute("Rarity") or "Common"
            local mut = plant:GetAttribute("Mutation") or ""
            if not passesFilter({SeedName=sname, Rarity=r, Mutation=mut, Weight=0}, "steal", fruit, rarity, mutation, nil, nil) then continue end
            local pid = plant:GetAttribute("PlantId"); if not pid then continue end
            local pos = plant.PrimaryPart and plant.PrimaryPart.Position or hrp.Position
            local sp = plant:FindFirstChild("StealPrompt", true)
            if sp and sp:IsA("ProximityPrompt") and sp.Enabled then
                if Library.Flags["StealMove"] then moveTo(pos) end
                task.wait(0.2)
                safeFire("Steal.BeginSteal", oid, pid, "")
                task.wait(0.1)
                safeFire("Steal.CompleteSteal")
                stolen = stolen + 1
                Session.stealsCompleted = Session.stealsCompleted + 1
                task.wait(0.25)
            else
                local fruits = plant:FindFirstChild("Fruits")
                if fruits then
                    for _,f in ipairs(fruits:GetChildren()) do
                        local fp = f:FindFirstChild("StealPrompt", true)
                        if fp and fp:IsA("ProximityPrompt") and fp.Enabled then
                            local fid = f:GetAttribute("FruitId") or f.Name
                            if Library.Flags["StealMove"] then moveTo(pos) end
                            task.wait(0.2)
                            safeFire("Steal.BeginSteal", oid, pid, fid)
                            task.wait(0.1)
                            safeFire("Steal.CompleteSteal")
                            stolen = stolen + 1
                            Session.stealsCompleted = Session.stealsCompleted + 1
                            task.wait(0.25)
                            break
                        end
                    end
                end
            end
        end
    end
end

local function doSell() Session.fruitsSold = Session.fruitsSold + 1; return safeFire("NPCS.SellAll") end

local function doBuySeed()
    local s = firstSelected(Library.Flags["BuySeed"], "Carrot")
    if s and s ~= "" then safeFire("SeedShop.PurchaseSeed", s) end
end

local function doBuyGear()
    local g = firstSelected(Library.Flags["BuyGear"], "Common Sprinkler")
    if g and g ~= "" then safeFire("GearShop.PurchaseGear", g) end
end

local function doBuyCrate()
    local c = firstSelected(Library.Flags["BuyCrate"], "Common Egg")
    if c and c ~= "" then safeFire("CrateShop.PurchaseCrate", c) end
end

local function doBuyAllSeeds() for _, s in ipairs(Seeds) do safeFire("SeedShop.PurchaseSeed", s); task.wait(0.25) end end
local function doBuyAllGears() for _, g in ipairs(Gear) do safeFire("GearShop.PurchaseGear", g); task.wait(0.25) end end
local function doBuyAllCrates() for _, c in ipairs(Crates) do if c:find("Egg") then safeFire("CrateShop.PurchaseCrate", c) end; task.wait(0.3) end end

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
    local sprinklerName = firstSelected(Library.Flags["SprinklerType"], "Common Sprinkler")
    local tool = findTool(sprinklerName)
    if not tool then notify("Sprinkler", "No "..sprinklerName.." in inventory", "danger"); return false end
    if not equipTool(tool) then notify("Sprinkler", "Failed to equip", "danger"); return false end
    local attrName = tool:GetAttribute("Sprinkler") or sprinklerName
    Session.sprinklersPlaced = Session.sprinklersPlaced + 1
    return safeFire("Place.PlaceSprinkler", targetPos, attrName, tool, PlotData.id or 1)
end

local function doAutoPlaceSprinkler()
    local r = asNumber(Library.Flags["SprinklerRadius"], 20)
    local placement = firstSelected(Library.Flags["SprinklerPlaceMode"], "Random")
    local targetPos = nil
    if placement == "Saved Position" and SavedPositions["Sprinkler"] then targetPos = SavedPositions["Sprinkler"]
    elseif placement == "Player Position" then local hrp = getHRP(); if hrp then targetPos = hrp.Position end
    elseif placement == "Near Fruit" then
        local spacing = asNumber(Library.Flags["SprinklerSpacing"], 8)
        local pf = plantsFolder()
        if pf and #pf:GetChildren() > 0 then
            local p = pf:GetChildren()[math.random(1, math.min(#pf:GetChildren(), 5))]
            if p.PrimaryPart then targetPos = p.PrimaryPart.Position end
        end
    else
        local pos, count = findBestSprinklerSpot(r)
        targetPos = pos
    end
    if not targetPos then notify("Sprinkler", "No valid position", "warning"); return end
    doPlaceSprinkler(targetPos)
end

local function doTrowelPlant(targetPos)
    local plantName = firstSelected(Library.Flags["TrowelPlant"], "")
    if plantName == "" or plantName == "None" then return false end
    local tool = findTool("Trowel")
    if not tool then notify("Trowel", "No Trowel in inventory", "danger"); return false end
    if not equipTool(tool) then return false end
    local pf = plantsFolder()
    if not pf then return false end
    for _, plant in ipairs(pf:GetChildren()) do
        if plant:IsA("Model") then
            local sname = plant:GetAttribute("SeedName") or plant.Name
            if sname == plantName then
                local pid = plant:GetAttribute("PlantId")
                if pid then safeFire("Trowel.MovePlant", targetPos, pid); return true end
            end
        end
    end
    return false
end

local function doShovelPlant()
    local treeName = firstSelected(Library.Flags["ShovelTree"], "")
    local treeRarity = firstSelected(Library.Flags["ShovelTreeRarity"], "All")
    local treeMutation = firstSelected(Library.Flags["ShovelTreeMutation"], "Any")
    local tool = findTool("Shovel")
    if not tool then notify("Shovel", "No Shovel in inventory", "danger"); return false end
    if not equipTool(tool) then return false end
    local pf = plantsFolder()
    if not pf then return false end
    for _, plant in ipairs(pf:GetChildren()) do
        if plant:IsA("Model") then
            local sname = plant:GetAttribute("SeedName") or plant.Name
            local r = plant:GetAttribute("Rarity") or "Common"
            local mut = plant:GetAttribute("Mutation") or ""
            local matches = (treeName == "" or treeName == "All" or sname == treeName) and (treeRarity == "All" or r == treeRarity) and (treeMutation == "Any" or mut == treeMutation)
            if matches then
                local pid = plant:GetAttribute("PlantId")
                if pid then safeFire("Shovel.UseShovel", pid, "", "", tool); task.wait(0.3) end
            end
        end
    end
    return true
end

local function doCollectDropped()
    local folder = droppedItemsFolder(); if not folder then return 0 end
    local hrp = getHRP(); if not hrp then return 0 end
    local count = 0
    for _, item in ipairs(folder:GetChildren()) do
        if not item:IsDescendantOf(Workspace) then continue end
        local pos = item:IsA("Model") and item.PrimaryPart and item.PrimaryPart.Position or (item:IsA("BasePart") and item.Position)
        if not pos then continue end
        if (hrp.Position - pos).Magnitude > 60 then continue end
        local pp = item:FindFirstChildWhichIsA("ProximityPrompt", true)
        if pp and pp.Enabled then firePrompt(pp); count = count + 1; task.wait(0.1) end
    end
    return count
end

local function findPets()
    local pets = {}
    local petsFolder = Workspace:FindFirstChild("Pets")
    if petsFolder then
        for _,p in ipairs(petsFolder:GetChildren()) do
            if p:IsA("Model") then table.insert(pets, p) end
        end
    end
    local gardens = Workspace:FindFirstChild("Gardens")
    if gardens then
        for _,plot in ipairs(gardens:GetChildren()) do
            local pf = plot:FindFirstChild("Pets")
            if pf then
                for _,p in ipairs(pf:GetChildren()) do
                    if p:IsA("Model") then table.insert(pets, p) end
                end
            end
        end
    end
    return pets
end

local function petMatches(p, nameFilter, rarityFilter, sizeFilter)
    local pname = (p:GetAttribute("PetName") or p.Name or ""):lower()
    local rarity = p:GetAttribute("Rarity") or p:GetAttribute("PetRarity") or ""
    local size = p:GetAttribute("Size") or 1
    if nameFilter and nameFilter ~= "" and nameFilter ~= "All" and nameFilter ~= "None" then
        if not pname:find(nameFilter:lower(), 1, true) then return false end
    end
    if rarityFilter and rarityFilter ~= "" and rarityFilter ~= "All" and rarityFilter ~= "None" then
        if rarity ~= rarityFilter then return false end
    end
    if sizeFilter then
        local s = tonumber(sizeFilter) or 0
        if s > 0 and tonumber(size) and tonumber(size) < s then return false end
    end
    return true
end

local function hopServer()
    pcall(function()
        local http = game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100")
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
-- Stock + weather prediction
-----------------------------------------------------------------

local StockHist = {}
local WeatherHist = {}
local LastStock = {}
local LastWeather = {}
pcall(function() local d = loadFile("Stock"); if d then StockHist = HttpService:JSONDecode(d) end end)
pcall(function() local d = loadFile("Weather"); if d then WeatherHist = HttpService:JSONDecode(d) end end)

local function fmtFuture(s)
    s = math.max(0, math.floor(s))
    local h = math.floor(s/3600); local m = math.floor((s%3600)/60); local d = math.floor(h/24)
    if d > 0 then return d.." day"..(d>1 and "s" or "") end
    if h > 0 then return h.." hour"..(h>1 and "s" or "") end
    if m > 0 then return m.." minute"..(m>1 and "s" or "") end
    if s > 1 then return s.." seconds" end
    return "a moment"
end

local function trackStock()
    local stock = ReplicatedStorage:FindFirstChild("StockValues")
    if not stock then return end
    local now = os.time()
    for _,shop in ipairs(stock:GetChildren()) do
        local items = shop:FindFirstChild("Items")
        if items then
            local shopName = shop.Name
            if not StockHist[shopName] then StockHist[shopName] = {} end
            for _,item in ipairs(items:GetChildren()) do
                if item:IsA("NumberValue") then
                    local name = item.Name
                    local count = item.Value
                    if not StockHist[shopName][name] then
                        StockHist[shopName][name] = { appearances = {}, intervals = {}, lastSeen = nil, lastCount = 0 }
                    end
                    local h = StockHist[shopName][name]
                    if h.lastCount == 0 and count > 0 then
                        table.insert(h.appearances, { time = now, amount = count })
                        if h.lastSeen then
                            table.insert(h.intervals, now - h.lastSeen)
                            if #h.intervals > 30 then table.remove(h.intervals, 1) end
                        end
                        h.lastSeen = now
                    end
                    if h.lastCount > 0 and count == 0 then h.lastSeen = now end
                    h.lastCount = count
                    if #h.appearances > 100 then table.remove(h.appearances, 1) end
                end
            end
        end
    end
    pcall(function() saveFile("Stock", HttpService:JSONEncode(StockHist)) end)
end

local function predictStock(shop, item)
    local h = StockHist[shop] and StockHist[shop][item]
    if not h or not h.intervals or #h.intervals < 1 then return nil end
    local total = 0; for _,i in ipairs(h.intervals) do total = total + i end
    local avg = math.floor(total / #h.intervals)
    local last = h.appearances[#h.appearances]
    if not last then return nil end
    local remaining = last.time + avg - os.time()
    local amtTotal = 0; for _,a in ipairs(h.appearances) do amtTotal = amtTotal + (a.amount or 1) end
    return remaining, math.floor(amtTotal / #h.appearances + 0.5), avg
end

local WeatherTypes = {
    { name="Bloodmoon",     attr="Bloodmoon",     color=Color3.fromRGB(180,0,0) },
    { name="Goldmoon",      attr="Goldmoon",      color=Color3.fromRGB(255,200,50) },
    { name="Rainbow Moon",  attr="RainbowMoon",   color=Color3.fromRGB(200,100,255) },
    { name="Chained Moon",  attr="ChainedMoon",   color=Color3.fromRGB(120,80,160) },
    { name="Pizza Moon",    attr="PizzaMoon",     color=Color3.fromRGB(255,140,40) },
    { name="Starfall",      attr="Starfall",      color=Color3.fromRGB(255,255,200) },
    { name="Snowfall",      attr="Snowfall",      color=Color3.fromRGB(200,230,255) },
    { name="Rainbow",       attr="Rainbow",       color=Color3.fromRGB(150,255,150) },
    { name="Rain",          attr="Rain",          color=Color3.fromRGB(100,150,255) }
}

local function trackWeather()
    local wv = ReplicatedStorage:FindFirstChild("WeatherValues")
    if not wv then return end
    local now = os.time()
    for _,w in ipairs(WeatherTypes) do
        local playing = wv:GetAttribute(w.attr.."_Playing") == true
        if not WeatherHist[w.attr] then WeatherHist[w.attr] = { events = {}, intervals = {} } end
        local h = WeatherHist[w.attr]
        local prev = LastWeather[w.attr]
        if prev ~= nil and prev ~= playing then
            if playing then
                table.insert(h.events, { time = now })
                if h.lastEnd then
                    table.insert(h.intervals, now - h.lastEnd)
                    if #h.intervals > 20 then table.remove(h.intervals, 1) end
                end
                h.lastStart = now
            else
                h.lastEnd = now
            end
            if #h.events > 50 then table.remove(h.events, 1) end
        elseif prev == nil and playing then
            h.lastStart = now
        end
        LastWeather[w.attr] = playing
    end
    pcall(function() saveFile("Weather", HttpService:JSONEncode(WeatherHist)) end)
end

local function predictWeather(attr)
    local h = WeatherHist[attr]
    if not h or not h.intervals or #h.intervals < 1 then return nil end
    local total = 0; for _,i in ipairs(h.intervals) do total = total + i end
    local avg = math.floor(total / #h.intervals)
    local last = h.lastEnd or h.lastStart
    if not last then return nil end
    return (last + avg) - os.time(), avg
end

local function getCurrentStock()
    local stock = ReplicatedStorage:FindFirstChild("StockValues")
    if not stock then return {} end
    local res = {}
    for _,shop in ipairs(stock:GetChildren()) do
        local items = shop:FindFirstChild("Items")
        if items then
            res[shop.Name] = {}
            for _,item in ipairs(items:GetChildren()) do
                if item:IsA("NumberValue") then
                    table.insert(res[shop.Name], { name = item.Name, count = item.Value })
                end
            end
        end
    end
    return res
end

local function getCurrentWeather()
    local wv = ReplicatedStorage:FindFirstChild("WeatherValues")
    if not wv then return {} end
    local res = {}
    for _,w in ipairs(WeatherTypes) do
        local playing = wv:GetAttribute(w.attr.."_Playing") == true
        local endTime = wv:GetAttribute(w.attr.."_EndTime") or 0
        local rem = playing and math.max(0, endTime - os.time()) or 0
        res[w.attr] = { playing = playing, remaining = rem, name = w.name, color = w.color }
    end
    return res
end

local function getSheckles()
    local leaders = client:FindFirstChild("leaderstats"); if not leaders then return 0 end
    for _, v in ipairs(leaders:GetChildren()) do
        if v:IsA("NumberValue") or v:IsA("IntValue") then
            local n = v.Name:lower()
            if n:find("sheckle") or n:find("coin") or n:find("money") or n:find("cash") then
                return tonumber(v.Value) or 0
            end
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

local function formatDuration(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    if h > 0 then return h.."h "..m.."m "..s.."s"
    elseif m > 0 then return m.."m "..s.."s"
    else return s.."s" end
end

-----------------------------------------------------------------
-- SECTIONS (RCU style with emoji)
-----------------------------------------------------------------

local Home = Setup:CreateSection("🏠 Home")
local Farm = Setup:CreateSection("🌱 Farm")
local Sprinklers = Setup:CreateSection("💧 Sprinklers")
local Tools = Setup:CreateSection("🛠️ Tools")
local Shop = Setup:CreateSection("🛒 Shop")
local Pets = Setup:CreateSection("🐾 Pets")
local Webhooks = Setup:CreateSection("🔔 Webhooks")
local Visuals = Setup:CreateSection("👁️ Visuals")
local Stats = Setup:CreateSection("📊 Stats")
local Logs = Setup:CreateSection("📜 Logs")
local DevTools = Setup:CreateSection("🛠️ Developer Tools")

Home:createLabel({
    Name = "GAG_2 - Grow a Garden 2",
    Special = true,
})

Home:createLabel({
    Name = "Speed Hub X style | Versus Airlines",
    Center = true,
})

---------------------------------------------------------------------- https://versusairlines.top/developers.html
-- HOME
----------------------------------------------------------------------

Home:createDropdown({
    Name = "Movement Mode",
    flagName = "TransportMode",
    List = {"Tween", "Teleport"},
    Flag = "Tween",
})

Home:createSlider({
    Name = "Geofence Radius",
    flagName = "Geofence",
    value = 25,
    minValue = 8,
    maxValue = 100,
})

Home:createLabel({
    Name = "Plot",
    Special = true,
})

Home:createButton({
    Name = "Refresh Plot",
    Callback = function()
        authPlot(true)
        local ok = PlotData.auth
        notify("Plot", ok and ("Plot #"..tostring(PlotData.id).." | "..#PlotData.grid.." nodes") or "No plot found", ok and "info" or "warning")
    end,
})

Home:createButton({
    Name = "TP to Garden",
    Callback = function() if authPlot() then moveTo(PlotData.center) end end,
})

Home:createButton({
    Name = "TP to Gate",
    Callback = function() if authPlot() and PlotData.gate then moveTo(PlotData.gate.Position) end end,
})

Home:createButton({
    Name = "Sell All Now",
    Callback = function() doSell(); notify("Sell", "SellAll fired", "info") end,
})

Home:createButton({
    Name = "Check Daily Deal",
    Callback = function()
        safeFire("NPCS.CheckDailyDeal")
        Session.dailyDealsClaimed = Session.dailyDealsClaimed + 1
    end,
})

Home:createButton({
    Name = "Claim Mailbox",
    Callback = function()
        safeFire("Mailbox.OpenInbox")
        Session.mailClaimed = Session.mailClaimed + 1
    end,
})

Home:createLabel({
    Name = "Stats",
    Special = true,
})

Home:createButton({
    Name = "Check Stock",
    Callback = function()
        trackStock()
        local stock = getCurrentStock()
        local lines = {"=== SEED STOCK ==="}
        for shop, items in pairs(stock) do
            table.insert(lines, "["..shop.."]")
            for _,it in ipairs(items) do
                if it.count > 0 then
                    table.insert(lines, "  "..it.name.." x"..it.count)
                else
                    local rem, amt = predictStock(shop, it.name)
                    if rem and rem > 0 then table.insert(lines, "  "..it.name.." - OUT (restock "..fmtFuture(rem).." x"..(amt or 1)..")")
                    elseif rem and rem <= 0 then table.insert(lines, "  "..it.name.." - OUT (any moment x"..(amt or 1)..")")
                    else table.insert(lines, "  "..it.name.." - OUT (learning...)") end
                end
            end
        end
        notify("Stock", table.concat(lines, "\n"), "info")
    end,
})

Home:createButton({
    Name = "Check Weather",
    Callback = function()
        trackWeather()
        local w = getCurrentWeather()
        local lines = {"=== WEATHER ==="}
        local any = false
        for _,wt in ipairs(WeatherTypes) do
            local d = w[wt.attr]
            if d and d.playing then any = true; table.insert(lines, wt.name.." - ACTIVE ("..fmtFuture(d.remaining).." left)") end
        end
        if not any then table.insert(lines, "No active weather") end
        for _,wt in ipairs(WeatherTypes) do
            local rem = predictWeather(wt.attr)
            if rem and rem > 0 then table.insert(lines, wt.name.." next in "..fmtFuture(rem)) end
        end
        notify("Weather", table.concat(lines, "\n"), "info")
    end,
})

Home:createButton({
    Name = "Clear Predictions",
    Callback = function()
        StockHist = {}; WeatherHist = {}
        pcall(function() saveFile("Stock", "{}") end)
        pcall(function() saveFile("Weather", "{}") end)
        notify("Cleared", "All prediction history wiped", "info")
    end,
})

Home:createButton({
    Name = "Show Sheckles",
    Callback = function() notify("Sheckles", "Current: "..formatSheckles(getSheckles()), "info") end,
})

---------------------------------------------------------------------- https://versusairlines.top/developers.html
-- FARM (plants + collect + sell + water)
----------------------------------------------------------------------

Farm:createLabel({
    Name = "- [ Harvest ] -",
    Special = true,
})

createIntervalToggle(Farm, {
    Name = "Auto Harvest",
    flagName = "AH",
    tag = "AH",
    delay = 0.1,
    Step = function()
        local items = getAllHarvestables("own")
        for _, item in ipairs(items) do
            collectItem(item)
            Session.plantsHarvested = Session.plantsHarvested + 1
            task.wait(0.05)
        end
    end,
})

Farm:createDropdown({
    Name = "Harvest Blacklist",
    flagName = "AH_blist",
    multi = true,
    List = Seeds,
})

Farm:createDropdown({
    Name = "Min Rarity",
    flagName = "AH_minRarity",
    List = {"Common", "Uncommon", "Rare", "Super", "Epic", "Legendary", "Mythic"},
    Flag = "Common",
})

Farm:createDropdown({
    Name = "Harvest Mutation",
    flagName = "AH_mutation",
    List = {"Any", unpack(Mutations)},
    Flag = "Any",
})

Farm:createInputBox({
    Name = "Delay To Collect",
    flagName = "CollectDelay",
    Placeholder = "0",
    Flag = "0",
})

Farm:createDropdown({
    Name = "Select Threshold Mode",
    flagName = "CollectThresholdMode",
    List = {"None", "Above Weight", "Below Weight"},
    Flag = "None",
})

Farm:createInputBox({
    Name = "Weight Threshold",
    flagName = "CollectThreshold",
    Placeholder = "0",
    Flag = "0",
})

Farm:createToggle({
    Name = "Stop Collect If Backpack Is Full Max",
    flagName = "CollectStopFull",
    Flag = false,
})

createIntervalToggle(Farm, {
    Name = "Auto Collect Gold Seed",
    flagName = "AutoCollectGold",
    tag = "AutoCollectGold",
    delay = 0.2,
    Step = function()
        for _, item in ipairs(getAllHarvestables("own")) do
            if item.Mutation == "Gold" then
                collectItem(item)
                Session.plantsHarvested = Session.plantsHarvested + 1
                task.wait(0.1)
            end
        end
    end,
})

createIntervalToggle(Farm, {
    Name = "Auto Collect Rainbow Seed",
    flagName = "AutoCollectRainbow",
    tag = "AutoCollectRainbow",
    delay = 0.2,
    Step = function()
        for _, item in ipairs(getAllHarvestables("own")) do
            if item.Mutation == "Rainbow" then
                collectItem(item)
                Session.plantsHarvested = Session.plantsHarvested + 1
                task.wait(0.1)
            end
        end
    end,
})

Farm:createToggle({
    Name = "Auto Collect Best Fruit",
    flagName = "AutoCollectBest",
    Flag = false,
    Callback = function(enabled)
        Library:CleanupConnectionsByTag("AutoCollectBest")
        if not enabled then return end
        interval("AutoCollectBest", "AutoCollectBest", 0.2, function()
            local items = getAllHarvestables("own")
            if #items == 0 then return end
            table.sort(items, function(a, b)
                local ra = rarityRank(a.Rarity); local rb = rarityRank(b.Rarity)
                if ra ~= rb then return ra > rb end
                return a.Weight > b.Weight
            end)
            collectItem(items[1])
        end)
    end,
})

createIntervalToggle(Farm, {
    Name = "Auto Collect Dropped Item",
    flagName = "AutoCollectDropped",
    tag = "AutoCollectDropped",
    delay = 0.5,
    Step = doCollectDropped,
})

Farm:createLabel({
    Name = "- [ Plant ] -",
    Special = true,
})

Farm:createDropdown({
    Name = "Select Seeds",
    flagName = "PlantSeed",
    List = Seeds,
    Flag = "Carrot",
})

Farm:createDropdown({
    Name = "Select Position",
    flagName = "PlantPosition",
    List = {"Random", "Saved Position", "Player Position", "Sprinkler Radius"},
    Flag = "Random",
})

Farm:createDropdown({
    Name = "Select Sprinkler For Plants",
    flagName = "PlantSprinkler",
    List = Sprinklers,
    Flag = "Common Sprinkler",
})

Farm:createInputBox({
    Name = "Plant Radius",
    flagName = "PlantRadius",
    Placeholder = "8",
    Flag = "8",
})

Farm:createButton({
    Name = "Save Position",
    Callback = function()
        local hrp = getHRP()
        if not hrp then return end
        SavedPositions["Plant"] = hrp.Position
        notify("Plant", "Position saved", "info")
    end,
})

Farm:createInputBox({
    Name = "Delay To Plants",
    flagName = "PlantDelay",
    Placeholder = "0",
    Flag = "0",
})

Farm:createToggle({
    Name = "Disable Teleport (Plants)",
    flagName = "PlantNoTP",
    Flag = false,
})

createIntervalToggle(Farm, {
    Name = "Auto Plants Seed",
    flagName = "AutoPlantSeed",
    tag = "AutoPlantSeed",
    delay = 1.5,
    Step = doPlant,
})

createIntervalToggle(Farm, {
    Name = "Auto Plants All Seeds",
    flagName = "AutoPlantAllSeed",
    tag = "AutoPlantAllSeed",
    delay = 2,
    Step = function()
        for _, s in ipairs(Seeds) do
            if not Library.Flags["AutoPlantAllSeed"] then break end
            local tool = findTool(s); if not tool then continue end
            equipTool(tool)
            local occ = occupiedPositions()
            local valid = getValidPlantPositions(occ, nil, "grid")
            if #valid > 0 then
                safeFire("Plant.PlantSeed", valid[1], s, tool)
                Session.seedsPlanted = Session.seedsPlanted + 1
                task.wait(0.5)
            end
        end
    end,
})

Farm:createLabel({
    Name = "- [ Sell ] -",
    Special = true,
})

Farm:createDropdown({
    Name = "Sell Mode",
    flagName = "SellMode",
    List = {"Manual", "Auto Every X Sec", "When Backpack Full"},
    Flag = "Manual",
})

Farm:createToggle({
    Name = "Allow Sell If Backpack Is Max",
    flagName = "SellAllowMax",
    Flag = false,
})

Farm:createToggle({
    Name = "Allows Bargain Inventory",
    flagName = "SellBargain",
    Flag = false,
})

Farm:createToggle({
    Name = "Use Daily Deal",
    flagName = "SellDailyDeal",
    Flag = false,
})

Farm:createInputBox({
    Name = "Delay To Sell Inventory",
    flagName = "SellDelay",
    Placeholder = "0",
    Flag = "0",
})

createIntervalToggle(Farm, {
    Name = "Auto Sell All",
    flagName = "AutoSellAll",
    tag = "AutoSellAll",
    delay = 6,
    Step = function()
        safeFire("NPCS.SellAll")
        Session.fruitsSold = Session.fruitsSold + 1
        if Library.Flags["SellBargain"] then safeFire("NPCS.AskBidAll") end
        if Library.Flags["SellDailyDeal"] then
            safeFire("NPCS.CheckDailyDeal")
            Session.dailyDealsClaimed = Session.dailyDealsClaimed + 1
        end
    end,
})

Farm:createButton({
    Name = "Sell All",
    Callback = doSell,
})

Farm:createLabel({
    Name = "- [ Sell Fruits ] -",
    Special = true,
})

Farm:createDropdown({
    Name = "Select Sell Fruit",
    flagName = "SellFruit",
    List = {"All", unpack(Seeds)},
    Flag = "All",
})

Farm:createDropdown({
    Name = "Select Sell Rarity",
    flagName = "SellRarity",
    List = {"All", "Common", "Uncommon", "Rare", "Super", "Epic", "Legendary", "Mythic"},
    Flag = "All",
})

Farm:createDropdown({
    Name = "Select Sell Mutation",
    flagName = "SellMutation",
    List = {"Any", unpack(Mutations)},
    Flag = "Any",
})

Farm:createDropdown({
    Name = "Select Threshold Mode",
    flagName = "SellThresholdMode",
    List = {"None", "Above Weight", "Below Weight"},
    Flag = "None",
})

Farm:createInputBox({
    Name = "Weight Threshold",
    flagName = "SellThreshold",
    Placeholder = "0",
    Flag = "0",
})

createIntervalToggle(Farm, {
    Name = "Auto Sell Fruit",
    flagName = "AutoSellFruit",
    tag = "AutoSellFruit",
    delay = 2,
    Step = function()
        local fruit = firstSelected(Library.Flags["SellFruit"], "All")
        local rarity = firstSelected(Library.Flags["SellRarity"], "All")
        local mutation = firstSelected(Library.Flags["SellMutation"], "Any")
        local bp = client:FindFirstChild("Backpack"); if not bp then return end
        for _, item in ipairs(bp:GetChildren()) do
            if not item:IsA("Tool") then continue end
            local sname = item:GetAttribute("SeedName") or item.Name
            local r = item:GetAttribute("Rarity") or "Common"
            local mut = item:GetAttribute("Mutation") or ""
            if not passesFilter({SeedName=sname, Rarity=r, Mutation=mut, Weight=0}, "sell", fruit, rarity, mutation, nil, nil) then continue end
            safeFire("NPCS.SellFruit", sname)
            Session.fruitsSold = Session.fruitsSold + 1
            task.wait(0.3)
        end
    end,
})

Farm:createLabel({
    Name = "- [ Water ] -",
    Special = true,
})

createIntervalToggle(Farm, {
    Name = "Auto Water",
    flagName = "AW",
    tag = "AW",
    delay = 1,
    Step = function()
        local pf = plantsFolder(); if not pf then return end
        local can = findTool("Watering Can"); if can then equipTool(can) end
        for _,p in ipairs(pf:GetChildren()) do
            if not p:IsA("Model") then continue end
            local gp = p:FindFirstChild("GrowPrompt", true)
            if gp and gp:IsA("ProximityPrompt") and gp.Enabled then
                firePrompt(gp)
                task.wait(0.1)
            end
        end
    end,
})

Farm:createLabel({
    Name = "- [ Steal ] -",
    Special = true,
})

Farm:createDropdown({
    Name = "Select Filter",
    flagName = "StealFilter",
    List = {"All", "Mutated", "Gold", "Rainbow"},
    Flag = "All",
})

Farm:createDropdown({
    Name = "Select Fruit",
    flagName = "StealFruit",
    List = {"All", unpack(Seeds)},
    Flag = "All",
})

Farm:createDropdown({
    Name = "Select Rarity",
    flagName = "StealRarity",
    List = {"All", "Common", "Uncommon", "Rare", "Super", "Epic", "Legendary", "Mythic"},
    Flag = "All",
})

Farm:createDropdown({
    Name = "Select Mutation",
    flagName = "StealMutation",
    List = {"Any", unpack(Mutations)},
    Flag = "Any",
})

Farm:createSlider({
    Name = "Carry Limit",
    flagName = "StealCarry",
    value = 20,
    minValue = 1,
    maxValue = 100,
})

Farm:createToggle({
    Name = "Only At Night",
    flagName = "StealOnlyNight",
    Flag = true,
})

Farm:createToggle({
    Name = "Move To Plants",
    flagName = "StealMove",
    Flag = true,
})

Farm:createToggle({
    Name = "Disable Teleport (Steal)",
    flagName = "StealNoTP",
    Flag = false,
})

createIntervalToggle(Farm, {
    Name = "Auto Steal Fruit",
    flagName = "AutoStealFruit",
    tag = "AutoStealFruit",
    delay = 0.8,
    Step = doSteal,
})

createIntervalToggle(Farm, {
    Name = "Auto Steal Best Fruit",
    flagName = "AutoStealBest",
    tag = "AutoStealBest",
    delay = 0.8,
    Step = function()
        local hrp = getHRP(); if not hrp then return end
        local gardens = Workspace:FindFirstChild("Gardens"); if not gardens then return end
        local carry = asNumber(Library.Flags["StealCarry"], 20)
        local bestPlants = {}
        for _,plot in ipairs(gardens:GetChildren()) do
            if plot == PlotData.model then continue end
            local pf = plot:FindFirstChild("Plants"); if not pf then continue end
            for _,plant in ipairs(pf:GetChildren()) do
                if not plant:IsA("Model") then continue end
                local r = plant:GetAttribute("Rarity") or "Common"
                local mut = plant:GetAttribute("Mutation") or ""
                if rarityRank(r) >= rarityRank("Legendary") or mut ~= "" then
                    table.insert(bestPlants, plant)
                end
            end
        end
        table.sort(bestPlants, function(a, b)
            return rarityRank(a:GetAttribute("Rarity") or "Common") > rarityRank(b:GetAttribute("Rarity") or "Common")
        end)
        local stolen = 0
        for _, plant in ipairs(bestPlants) do
            if stolen >= carry then break end
            local oid = plant.Parent:GetAttribute("UserId") or plant.Parent:GetAttribute("OwnerId")
            if not oid then continue end
            local pid = plant:GetAttribute("PlantId"); if not pid then continue end
            local pos = plant.PrimaryPart and plant.PrimaryPart.Position or hrp.Position
            if Library.Flags["StealMove"] then moveTo(pos) end
            task.wait(0.2)
            safeFire("Steal.BeginSteal", oid, pid, "")
            task.wait(0.1)
            safeFire("Steal.CompleteSteal")
            stolen = stolen + 1
            Session.stealsCompleted = Session.stealsCompleted + 1
            task.wait(0.25)
        end
    end,
})

Farm:createLabel({
    Name = "- [ Locks Garden ] -",
    Special = true,
})

createIntervalToggle(Farm, {
    Name = "Auto Lock Garden At Night",
    flagName = "AutoLockNight",
    tag = "AutoLockNight",
    delay = 1,
    Step = function()
        if not isNight() then return end
        if not PlotData.auth then authPlot() end
        if not PlotData.model then return end
        local gate = PlotData.model:FindFirstChild("Gate") or PlotData.model:FindFirstChild("Lock")
        if gate and gate:IsA("BasePart") then gate.CanCollide = true end
    end,
})

Farm:createLabel({
    Name = "- [ Hit Players ] -",
    Special = true,
})

createIntervalToggle(Farm, {
    Name = "Auto Hit Player Stolen",
    flagName = "AutoHitStolen",
    tag = "AutoHitStolen",
    delay = 2,
    Step = function()
        local shovel = findTool("Shovel"); if not shovel then return end
        equipTool(shovel)
        for _, p in ipairs(Players:GetPlayers()) do
            if p == client then continue end
            local char = p.Character
            if not char or not char:FindFirstChild("HumanoidRootPart") then continue end
            local hrp = getHRP()
            if hrp and (hrp.Position - char.HumanoidRootPart.Position).Magnitude < 15 then
                safeFire("Shovel.HitPlayer", p.UserId)
            end
        end
    end,
})

---------------------------------------------------------------------- https://versusairlines.top/developers.html
-- SPRINKLERS
----------------------------------------------------------------------

Sprinklers:createLabel({
    Name = "- [ Automation Sprinkler ] -",
    Special = true,
})

Sprinklers:createDropdown({
    Name = "Select Sprinkler",
    flagName = "SprinklerType",
    List = Sprinklers,
    Flag = "Common Sprinkler",
})

Sprinklers:createDropdown({
    Name = "Select Position",
    flagName = "SprinklerPlaceMode",
    List = {"Saved Position", "Random", "Player Position", "Near Fruit"},
    Flag = "Random",
})

Sprinklers:createInputBox({
    Name = "Sprinkler Spacing",
    flagName = "SprinklerSpacing",
    Placeholder = "8",
    Flag = "8",
})

Sprinklers:createButton({
    Name = "Save Position",
    Callback = function()
        local hrp = getHRP()
        if not hrp then return end
        SavedPositions["Sprinkler"] = hrp.Position
        notify("Sprinkler", "Position saved", "info")
    end,
})

Sprinklers:createInputBox({
    Name = "Delay To Sprinkler",
    flagName = "SprinklerDelay",
    Placeholder = "0",
    Flag = "0",
})

Sprinklers:createSlider({
    Name = "Radius",
    flagName = "SprinklerRadius",
    value = 20,
    minValue = 10,
    maxValue = 60,
})

Sprinklers:createToggle({
    Name = "Disable Teleport (Sprinkler)",
    flagName = "SprinklerNoTP",
    Flag = false,
})

Sprinklers:createButton({
    Name = "Find Best Spot",
    Callback = function()
        local r = Library.Flags["SprinklerRadius"] or 20
        local pos, count = findBestSprinklerSpot(r)
        if pos then
            local ring = Instance.new("Part")
            ring.Shape = Enum.PartType.Cylinder
            ring.Size = Vector3.new(0.5, r*2, r*2)
            ring.CFrame = CFrame.new(pos) * CFrame.Angles(0,0,math.rad(90))
            ring.Anchored = true; ring.CanCollide = false
            ring.Transparency = 0.85
            ring.Color = Color3.fromRGB(0,255,100)
            ring.Material = Enum.Material.Neon
            ring.Parent = Workspace
            Debris:AddItem(ring, 6)
            local dot = Instance.new("Part")
            dot.Size = Vector3.new(1,1,1)
            dot.CFrame = CFrame.new(pos)
            dot.Anchored = true; dot.CanCollide = false
            dot.Color = Color3.fromRGB(255,255,0)
            dot.Material = Enum.Material.Neon
            dot.Parent = Workspace
            Debris:AddItem(dot, 6)
            notify("Sprinkler", "Best spot covers "..count.." plants", "info")
        else
            notify("Sprinkler", "No plants found", "warning")
        end
    end,
})

Sprinklers:createButton({
    Name = "Place Sprinkler Now",
    Callback = doAutoPlaceSprinkler,
})

createIntervalToggle(Sprinklers, {
    Name = "Auto Place Sprinkler",
    flagName = "AutoSprinkler",
    tag = "AutoSprinkler",
    delay = 30,
    Step = doAutoPlaceSprinkler,
})

createIntervalToggle(Sprinklers, {
    Name = "Auto Place All Sprinkler",
    flagName = "AutoSprinklerAll",
    tag = "AutoSprinklerAll",
    delay = 25,
    Step = function()
        for _, s in ipairs(Sprinklers) do
            if not Library.Flags["AutoSprinklerAll"] then break end
            Library.Flags["SprinklerType"] = s
            task.wait(0.5)
            doAutoPlaceSprinkler()
            task.wait(2)
        end
    end,
})

---------------------------------------------------------------------- https://versusairlines.top/developers.html
-- TOOLS (Trowel + Shovel)
----------------------------------------------------------------------

Tools:createLabel({
    Name = "- [ Automation Trowel ] -",
    Special = true,
})

Tools:createDropdown({
    Name = "Select Plant",
    flagName = "TrowelPlant",
    List = Seeds,
    Flag = "Carrot",
})

Tools:createDropdown({
    Name = "Select Position",
    flagName = "TrowelPosition",
    List = {"Random", "Saved Position", "Player Position"},
    Flag = "Random",
})

Tools:createButton({
    Name = "Save Position",
    Callback = function()
        local hrp = getHRP()
        if not hrp then return end
        SavedPositions["Trowel"] = hrp.Position
        notify("Trowel", "Position saved", "info")
    end,
})

Tools:createInputBox({
    Name = "Delay To Trowel",
    flagName = "TrowelDelay",
    Placeholder = "0",
    Flag = "0",
})

Tools:createDropdown({
    Name = "Select Mutation",
    flagName = "TrowelMutation",
    List = {"Any", unpack(Mutations)},
    Flag = "Any",
})

Tools:createDropdown({
    Name = "Select Threshold Mode",
    flagName = "TrowelThresholdMode",
    List = {"None", "Above Weight", "Below Weight"},
    Flag = "None",
})

Tools:createInputBox({
    Name = "Weight Threshold",
    flagName = "TrowelThreshold",
    Placeholder = "0",
    Flag = "0",
})

createIntervalToggle(Tools, {
    Name = "Auto Trowel Plant",
    flagName = "AutoTrowel",
    tag = "AutoTrowel",
    delay = 1.5,
    Step = function()
        local pos = nil
        local mode = firstSelected(Library.Flags["TrowelPosition"], "Random")
        if mode == "Saved Position" and SavedPositions["Trowel"] then
            pos = SavedPositions["Trowel"]
        elseif mode == "Player Position" then
            local h = getHRP(); if h then pos = h.Position end
        else
            if not PlotData.auth then authPlot() end
            if #PlotData.grid > 0 then pos = PlotData.grid[math.random(1, #PlotData.grid)] end
        end
        if pos then doTrowelPlant(pos) end
    end,
})

Tools:createLabel({
    Name = "- [ Automation Shovel ] -",
    Special = true,
})

Tools:createLabel({
    Name = "[ Tree Shovel ]",
    Special = true,
})

Tools:createDropdown({
    Name = "Select Tree",
    flagName = "ShovelTree",
    List = Seeds,
    Flag = "Bamboo",
})

Tools:createDropdown({
    Name = "Select Rarity Tree",
    flagName = "ShovelTreeRarity",
    List = {"All", "Common", "Uncommon", "Rare", "Super", "Epic", "Legendary", "Mythic"},
    Flag = "All",
})

Tools:createDropdown({
    Name = "Select Mutation Tree",
    flagName = "ShovelTreeMutation",
    List = {"Any", unpack(Mutations)},
    Flag = "Any",
})

Tools:createInputBox({
    Name = "Delay To Shovel Tree",
    flagName = "ShovelTreeDelay",
    Placeholder = "0",
    Flag = "0",
})

createIntervalToggle(Tools, {
    Name = "Auto Shovel Tree",
    flagName = "AutoShovelTree",
    tag = "AutoShovelTree",
    delay = 1.5,
    Step = doShovelPlant,
})

Tools:createLabel({
    Name = "[ Fruits Shovel ]",
    Special = true,
})

Tools:createDropdown({
    Name = "Select Fruit",
    flagName = "ShovelFruit",
    List = {"All", unpack(Seeds)},
    Flag = "All",
})

Tools:createDropdown({
    Name = "Select Rarity",
    flagName = "ShovelFruitRarity",
    List = {"All", "Common", "Uncommon", "Rare", "Super", "Epic", "Legendary", "Mythic"},
    Flag = "All",
})

Tools:createDropdown({
    Name = "Select Mutation",
    flagName = "ShovelFruitMutation",
    List = {"Any", unpack(Mutations)},
    Flag = "Any",
})

Tools:createDropdown({
    Name = "Select Threshold Mode",
    flagName = "ShovelThresholdMode",
    List = {"None", "Above Weight", "Below Weight"},
    Flag = "None",
})

Tools:createInputBox({
    Name = "Weight Threshold",
    flagName = "ShovelThreshold",
    Placeholder = "0",
    Flag = "0",
})

Tools:createInputBox({
    Name = "Delay To Shovel Fruit",
    flagName = "ShovelFruitDelay",
    Placeholder = "0",
    Flag = "0",
})

createIntervalToggle(Tools, {
    Name = "Auto Shovel Fruit",
    flagName = "AutoShovelFruit",
    tag = "AutoShovelFruit",
    delay = 1.5,
    Step = function()
        local fruit = firstSelected(Library.Flags["ShovelFruit"], "All")
        local r = firstSelected(Library.Flags["ShovelFruitRarity"], "All")
        local m = firstSelected(Library.Flags["ShovelFruitMutation"], "Any")
        local tmode = firstSelected(Library.Flags["ShovelThresholdMode"], "None")
        local threshold = asNumber(firstSelected(Library.Flags["ShovelThreshold"], "0"), 0)
        local tool = findTool("Shovel"); if not tool then return end
        equipTool(tool)
        local pf = plantsFolder(); if not pf then return end
        for _, plant in ipairs(pf:GetChildren()) do
            if not plant:IsA("Model") then continue end
            local sname = plant:GetAttribute("SeedName") or plant.Name
            local rarity = plant:GetAttribute("Rarity") or "Common"
            local mut = plant:GetAttribute("Mutation") or ""
            local weight = tonumber(plant:GetAttribute("Weight") or plant:GetAttribute("Value") or 0) or 0
            if not passesFilter({SeedName=sname, Rarity=rarity, Mutation=mut, Weight=weight}, "shovel", fruit, r, m, tmode, threshold) then continue end
            local pid = plant:GetAttribute("PlantId")
            if pid then safeFire("Shovel.UseShovel", pid, "", "", tool); task.wait(0.3) end
        end
    end,
})

Tools:createLabel({
    Name = "- [ Equipment ] -",
    Special = true,
})

Tools:createButton({
    Name = "Equip Current Tool",
    Callback = function()
        local c = client.Character
        if c then local t = c:FindFirstChildWhichIsA("Tool"); if t then pcall(function() Hum:EquipTool(t) end) end end
    end,
})

Tools:createButton({
    Name = "Drop All Tools",
    Callback = function()
        local bp = client:FindFirstChild("Backpack")
        if bp then for _,t in ipairs(bp:GetChildren()) do if t:IsA("Tool") then t.Parent = Workspace end end end
    end,
})

createIntervalToggle(Tools, {
    Name = "Keep Tool Equipped",
    flagName = "KeepTool",
    tag = "KeepTool",
    delay = 0.5,
    Step = function()
        local want = firstSelected(Library.Flags["PlantSeed"], "")
        if want and want ~= "" then
            local t = findTool(want)
            if t and t.Parent ~= client.Character then pcall(function() Hum:EquipTool(t) end) end
        end
    end,
})

---------------------------------------------------------------------- https://versusairlines.top/developers.html
-- SHOP
----------------------------------------------------------------------

Shop:createLabel({
    Name = "- [ Shop Seeds ] -",
    Special = true,
})

Shop:createDropdown({
    Name = "Select Seed",
    flagName = "BuySeed",
    List = Seeds,
    Flag = "Carrot",
})

createIntervalToggle(Shop, {
    Name = "Auto Buy Seeds",
    flagName = "AutoBuySeed",
    tag = "AutoBuySeed",
    delay = 3,
    Step = doBuySeed,
})

createIntervalToggle(Shop, {
    Name = "Auto Buy All Seeds",
    flagName = "AutoBuyAllSeed",
    tag = "AutoBuyAllSeed",
    delay = 8,
    Step = doBuyAllSeeds,
})

Shop:createButton({
    Name = "Buy Now",
    Callback = doBuySeed,
})

Shop:createLabel({
    Name = "- [ Shop Gear ] -",
    Special = true,
})

Shop:createDropdown({
    Name = "Select Gear",
    flagName = "BuyGear",
    List = Gear,
    Flag = "Common Sprinkler",
})

createIntervalToggle(Shop, {
    Name = "Auto Buy Gear",
    flagName = "AutoBuyGear",
    tag = "AutoBuyGear",
    delay = 3,
    Step = doBuyGear,
})

createIntervalToggle(Shop, {
    Name = "Auto Buy All Gear",
    flagName = "AutoBuyAllGear",
    tag = "AutoBuyAllGear",
    delay = 8,
    Step = doBuyAllGears,
})

Shop:createButton({
    Name = "Buy Now",
    Callback = doBuyGear,
})

Shop:createLabel({
    Name = "- [ Shop Crate ] -",
    Special = true,
})

Shop:createDropdown({
    Name = "Select Crate",
    flagName = "BuyCrate",
    List = ShopItems,
    Flag = "Common Egg",
})

createIntervalToggle(Shop, {
    Name = "Auto Buy Crate",
    flagName = "AutoBuyCrate",
    tag = "AutoBuyCrate",
    delay = 4,
    Step = doBuyCrate,
})

createIntervalToggle(Shop, {
    Name = "Auto Buy All Crate",
    flagName = "AutoBuyAllCrate",
    tag = "AutoBuyAllCrate",
    delay = 12,
    Step = doBuyAllCrates,
})

Shop:createButton({
    Name = "Buy Now",
    Callback = doBuyCrate,
})

Shop:createLabel({
    Name = "- [ Codes ] -",
    Special = true,
})

Shop:createInputBox({
    Name = "Redeem Code",
    flagName = "RedeemCode",
    Placeholder = "Enter code",
    Flag = "",
})

Shop:createButton({
    Name = "Redeem",
    Callback = function()
        local code = firstSelected(Library.Flags["RedeemCode"], "")
        if code and code ~= "" then
            safeFire("Settings.SubmitCode", code)
            Session.codesRedeemed = Session.codesRedeemed + 1
            notify("Code", "Submitted: "..code, "info")
        end
    end,
})

Shop:createButton({
    Name = "Claim Daily Reward",
    Callback = function()
        safeFire("NPCS.CheckDailyDeal")
        Session.dailyDealsClaimed = Session.dailyDealsClaimed + 1
    end,
})

---------------------------------------------------------------------- https://versusairlines.top/developers.html
-- PETS
----------------------------------------------------------------------

Pets:createLabel({
    Name = "- [ Pet Equipment ] -",
    Special = true,
})

Pets:createDropdown({
    Name = "Pet To Equip",
    flagName = "EquipPet",
    List = Pets,
    Flag = "Raccoon",
})

Pets:createButton({
    Name = "Equip Pet",
    Callback = function()
        local p = firstSelected(Library.Flags["EquipPet"], "Raccoon")
        if p then safeFire("Pets.PetEquipped", p, {}) end
    end,
})

Pets:createButton({
    Name = "Unequip All Pets",
    Callback = function()
        for _, n in ipairs(Pets) do
            safeFire("Pets.RequestUnequipByName", n)
            task.wait(0.1)
        end
    end,
})

Pets:createToggle({
    Name = "Pet Purchase Protection",
    flagName = "PetProtect",
    Flag = false,
})

Pets:createLabel({
    Name = "- [ Buys Pets ] -",
    Special = true,
})

Pets:createDropdown({
    Name = "Select Pets",
    flagName = "BuyPet",
    List = Pets,
    Flag = "Raccoon",
})

Pets:createDropdown({
    Name = "Select Rarity Pets",
    flagName = "BuyPetRarity",
    List = {"All", unpack(PetRarities)},
    Flag = "All",
})

Pets:createDropdown({
    Name = "Select Size Pets",
    flagName = "BuyPetSize",
    List = {"All", "1", "2", "3", "5", "10", "50", "100"},
    Flag = "All",
})

createIntervalToggle(Pets, {
    Name = "Auto Buy Pet",
    flagName = "AutoBuyPet",
    tag = "AutoBuyPet",
    delay = 4,
    Step = function()
        for _, p in ipairs(Pets) do
            safeFire("Pets.RequestPurchasePetSlot", p)
            Session.petsBought = Session.petsBought + 1
            task.wait(0.5)
        end
    end,
})

Pets:createLabel({
    Name = "- [ Sell Pets ] -",
    Special = true,
})

Pets:createDropdown({
    Name = "Select Pets",
    flagName = "SellPet",
    List = {"All", unpack(Pets)},
    Flag = "All",
})

Pets:createDropdown({
    Name = "Select Rarity Pets",
    flagName = "SellPetRarity",
    List = {"All", unpack(PetRarities)},
    Flag = "All",
})

Pets:createDropdown({
    Name = "Select Size Pets",
    flagName = "SellPetSize",
    List = {"All", "1", "2", "3", "5", "10", "50", "100"},
    Flag = "All",
})

createTodoToggle(Pets, "Auto Sell Pets", "AutoSellPet", "Use inventory UI to sell pets directly")

---------------------------------------------------------------------- https://versusairlines.top/developers.html
-- WEBHOOKS
----------------------------------------------------------------------

Webhooks:createLabel({
    Name = "- [ Config Webhook ] -",
    Special = true,
})

Webhooks:createInputBox({
    Name = "Main Webhook URL",
    flagName = "WebhookURL",
    Placeholder = "https://discord.com/api/webhooks/...",
    Flag = "",
})

Webhooks:createInputBox({
    Name = "Ping Message/ID",
    flagName = "PingID",
    Placeholder = "<@your_id>",
    Flag = "",
})

Webhooks:createToggle({
    Name = "Allow Ping On Ping Message/ID",
    flagName = "AllowPing",
    Flag = false,
    Callback = function(v)
        Webhooks.main.allowPing = v
        saveFile("Webhooks", HttpService:JSONEncode(Webhooks))
    end,
})

Webhooks:createButton({
    Name = "Test Webhook",
    Callback = function()
        sendHook("Test from GAG_2 - "..os.date("%c"), "Webhook OK")
        notify("Webhook", "Test sent", "info")
    end,
})

Webhooks:createLabel({
    Name = "- [ Restock Webhook ] -",
    Special = true,
})

Webhooks:createInputBox({
    Name = "Restock Webhook URL",
    flagName = "RestockWH",
    Placeholder = "https://discord.com/api/webhooks/...",
    Flag = "",
})

Webhooks:createToggle({
    Name = "Enable Restock Webhook",
    flagName = "NotifyRestock",
    Flag = false,
})

Webhooks:createLabel({
    Name = "- [ Pets Purchase Webhook ] -",
    Special = true,
})

Webhooks:createInputBox({
    Name = "Pets Webhook URL",
    flagName = "PetsWH",
    Placeholder = "https://discord.com/api/webhooks/...",
    Flag = "",
})

Webhooks:createDropdown({
    Name = "Select Pets",
    flagName = "WhPet",
    List = {"All", unpack(Pets)},
    Flag = "All",
})

Webhooks:createDropdown({
    Name = "Select Rarity Pets",
    flagName = "WhPetRarity",
    List = {"All", unpack(PetRarities)},
    Flag = "All",
})

Webhooks:createDropdown({
    Name = "Select Size Pets",
    flagName = "WhPetSize",
    List = {"All", "1", "2", "3", "5", "10", "50", "100"},
    Flag = "All",
})

Webhooks:createToggle({
    Name = "Pets Purchase Webhook",
    flagName = "WhPetNotify",
    Flag = false,
})

Webhooks:createLabel({
    Name = "- [ Webhook Collection Event Seed ] -",
    Special = true,
})

Webhooks:createInputBox({
    Name = "Event Webhook URL",
    flagName = "EventWH",
    Placeholder = "https://discord.com/api/webhooks/...",
    Flag = "",
})

Webhooks:createDropdown({
    Name = "Select Event Seed",
    flagName = "WhEventSeedName",
    List = {"All", unpack(Seeds)},
    Flag = "All",
})

Webhooks:createToggle({
    Name = "Webhook Collection Event Seed",
    flagName = "WhEventSeed",
    Flag = false,
})

Webhooks:createLabel({
    Name = "- [ Profit Webhook ] -",
    Special = true,
})

Webhooks:createInputBox({
    Name = "Profit Webhook URL",
    flagName = "ProfitWH",
    Placeholder = "https://discord.com/api/webhooks/...",
    Flag = "",
})

Webhooks:createToggle({
    Name = "Send Profit Reports",
    flagName = "NotifyProfit",
    Flag = false,
})

Webhooks:createLabel({
    Name = "- [ Rare Find Webhook ] -",
    Special = true,
})

Webhooks:createInputBox({
    Name = "Rare Webhook URL",
    flagName = "RareWH",
    Placeholder = "https://discord.com/api/webhooks/...",
    Flag = "",
})

Webhooks:createToggle({
    Name = "Notify On Rare Find",
    flagName = "NotifyRare",
    Flag = false,
})

---------------------------------------------------------------------- https://versusairlines.top/developers.html
-- VISUALS (ESP + Tracers)
----------------------------------------------------------------------

Visuals:createLabel({
    Name = "- [ ESP Fruit ] -",
    Special = true,
})

Visuals:createDropdown({
    Name = "Select ESP Fruit",
    flagName = "ESPFruit",
    List = {"All", unpack(Seeds)},
    Flag = "All",
})

Visuals:createDropdown({
    Name = "Select ESP Rarity",
    flagName = "ESPRarity",
    List = {"All", unpack(PetRarities)},
    Flag = "All",
})

Visuals:createDropdown({
    Name = "Select ESP Mutation",
    flagName = "ESPMutation",
    List = {"All", unpack(Mutations)},
    Flag = "All",
})

createIntervalToggle(Visuals, {
    Name = "ESP Fruit",
    flagName = "ESPFruitOn",
    tag = "ESPFruitOn",
    delay = 2,
    Step = function()
        clearESP()
        local gardens = Workspace:FindFirstChild("Gardens")
        if not gardens then return end
        local ff = firstSelected(Library.Flags["ESPFruit"], "All")
        local rf = firstSelected(Library.Flags["ESPRarity"], "All")
        local mf = firstSelected(Library.Flags["ESPMutation"], "All")
        for _,plot in ipairs(gardens:GetChildren()) do
            if not (plot:IsA("Model") or plot:IsA("Folder")) then continue end
            local pf = plot:FindFirstChild("Plants"); if not pf then continue end
            for _,plant in ipairs(pf:GetChildren()) do
                if not plant:IsA("Model") then continue end
                local sname = plant:GetAttribute("SeedName") or plant.Name
                local rarity = plant:GetAttribute("Rarity") or "Common"
                local mut = plant:GetAttribute("Mutation") or ""
                if ff ~= "All" and not sname:lower():find(ff:lower(), 1, true) then continue end
                if rf ~= "All" and rarity ~= rf then continue end
                if mf ~= "All" and mut ~= mf then continue end
                local text = sname.." | "..rarity
                if mut ~= "" then text = text.." ["..mut.."]" end
                if plot ~= PlotData.model then text = text.." [STEAL]" end
                makeESP(plant, text, rarityColor(rarity))
            end
        end
    end,
})

Visuals:createLabel({
    Name = "- [ ESP Spawned Pets ] -",
    Special = true,
})

Visuals:createDropdown({
    Name = "Select Pets",
    flagName = "ESPPet",
    List = {"All", unpack(Pets)},
    Flag = "All",
})

Visuals:createDropdown({
    Name = "Select Rarity Pets",
    flagName = "ESPPetRarity",
    List = {"All", unpack(PetRarities)},
    Flag = "All",
})

Visuals:createDropdown({
    Name = "Select Size Pets",
    flagName = "ESPPetSize",
    List = {"All", "1", "2", "3", "5", "10", "50", "100"},
    Flag = "All",
})

createIntervalToggle(Visuals, {
    Name = "ESP Spawned Pets",
    flagName = "ESPPetOn",
    tag = "ESPPetOn",
    delay = 2,
    Step = function()
        local nf = firstSelected(Library.Flags["ESPPet"], "All")
        local rf = firstSelected(Library.Flags["ESPPetRarity"], "All")
        local sf = firstSelected(Library.Flags["ESPPetSize"], "All")
        for _,pet in ipairs(findPets()) do
            if petMatches(pet, nf, rf, sf) then
                local pname = pet:GetAttribute("PetName") or pet.Name
                local rarity = pet:GetAttribute("Rarity") or "Common"
                local size = pet:GetAttribute("Size") or 1
                makeESP(pet, pname.." | "..rarity.." | x"..tostring(size), rarityColor(rarity))
            end
        end
    end,
})

Visuals:createLabel({
    Name = "- [ ESP NPCs ] -",
    Special = true,
})

createIntervalToggle(Visuals, {
    Name = "ESP NPCs",
    flagName = "ESPNPCOn",
    tag = "ESPNPCOn",
    delay = 3,
    Step = function()
        local npcs = Workspace:FindFirstChild("NPCS") or Workspace:FindFirstChild("NPCs")
        if npcs then
            for _,npc in ipairs(npcs:GetChildren()) do
                if npc:IsA("Model") then makeESP(npc, npc.Name, Color3.fromRGB(100,200,255)) end
            end
        end
    end,
})

Visuals:createToggle({
    Name = "Show Distance",
    flagName = "ShowDist",
    Flag = false,
})

Visuals:createToggle({
    Name = "Show Box ESP",
    flagName = "ESPBox",
    Flag = false,
})

Visuals:createToggle({
    Name = "Show Tracer Lines",
    flagName = "ESPTracer",
    Flag = false,
})

Visuals:createLabel({
    Name = "- [ Gameplay Mods ] -",
    Special = true,
})

Visuals:createToggle({
    Name = "Fullbright",
    flagName = "Fullbright",
    Flag = false,
    Callback = function(v)
        if v then
            LightingService.Ambient = Color3.fromRGB(255,255,255)
            LightingService.OutdoorAmbient = Color3.fromRGB(255,255,255)
            LightingService.Brightness = 4
            LightingService.ClockTime = 14
            LightingService.FogEnd = 100000
            LightingService.GlobalShadows = false
        else
            LightingService.Ambient = Color3.fromRGB(0,0,0)
            LightingService.OutdoorAmbient = Color3.fromRGB(0,0,0)
            LightingService.Brightness = 3
            LightingService.GlobalShadows = true
        end
    end,
})

Visuals:createToggle({
    Name = "Bypass Gameplay Paused",
    flagName = "BypassPause",
    Flag = false,
    Callback = function(enabled)
        Library:CleanupConnectionsByTag("BypassPause")
        if not enabled then return end
        interval("BypassPause", "BypassPause", 0.5, function()
            local pg = client:FindFirstChild("PlayerGui")
            if pg then for _,g in ipairs(pg:GetChildren()) do if g:IsA("ScreenGui") and g.Name:lower():find("pause") then g.Enabled = false end end end
        end)
    end,
})

Visuals:createToggle({
    Name = "Instant Interact Prompt",
    flagName = "InstantPrompt",
    Flag = false,
    Callback = function(enabled)
        Library:CleanupConnectionsByTag("InstantPrompt")
        if not enabled then return end
        interval("InstantPrompt", "InstantPrompt", 1, function()
            for _,pp in ipairs(Workspace:GetDescendants()) do if pp:IsA("ProximityPrompt") then pp.HoldDuration = 0 end end
        end)
    end,
})

Visuals:createToggle({
    Name = "Anti-Fling",
    flagName = "AntiFling",
    Flag = false,
    Callback = function(enabled)
        Library:CleanupConnectionsByTag("AntiFling")
        if not enabled then return end
        interval("AntiFling", "AntiFling", 0.2, function()
            local hrp = getHRP()
            if hrp and hrp.Velocity.Magnitude > 200 then
                hrp.Velocity = Vector3.zero
                hrp.AngularVelocity = Vector3.zero
            end
        end)
    end,
})

Visuals:createToggle({
    Name = "Less Knockback",
    flagName = "LessKnockback",
    Flag = false,
    Callback = function(enabled)
        Library:CleanupConnectionsByTag("LessKnockback")
        if not enabled then return end
        interval("LessKnockback", "LessKnockback", 0.2, function()
            local hrp = getHRP()
            if hrp and hrp.Velocity.Magnitude > 60 then hrp.Velocity = hrp.Velocity * 0.5 end
        end)
    end,
})

Visuals:createToggle({
    Name = "Noclip Plants",
    flagName = "NoclipPlants",
    Flag = false,
    Callback = function(enabled)
        Library:CleanupConnectionsByTag("NoclipPlants")
        if not enabled then return end
        interval("NoclipPlants", "NoclipPlants", 0, function()
            local pf = plantsFolder()
            if pf then for _,d in ipairs(pf:GetDescendants()) do if d:IsA("BasePart") then d.CanCollide = false end end end
        end)
    end,
})

Visuals:createToggle({
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

Visuals:createSlider({
    Name = "Walk Speed",
    flagName = "WalkSpeed",
    value = 16,
    minValue = 16,
    maxValue = 200,
})

Visuals:createSlider({
    Name = "Jump Power",
    flagName = "JumpPower",
    value = 50,
    minValue = 50,
    maxValue = 250,
})

Visuals:createToggle({
    Name = "Auto Speed",
    flagName = "AutoSpeed",
    Flag = false,
    Callback = function(enabled)
        Library:CleanupConnectionsByTag("AutoSpeed")
        if not enabled then return end
        interval("AutoSpeed", "AutoSpeed", 0.5, function()
            local h = getHum()
            if h then h.WalkSpeed = asNumber(Library.Flags["WalkSpeed"], 16) end
        end)
    end,
})

Visuals:createToggle({
    Name = "Auto Jump",
    flagName = "AutoJump",
    Flag = false,
    Callback = function(enabled)
        Library:CleanupConnectionsByTag("AutoJump")
        if not enabled then return end
        interval("AutoJump", "AutoJump", 0.3, function()
            local h = getHum()
            if h then h.JumpPower = asNumber(Library.Flags["JumpPower"], 50) end
            if h and h:GetState() == Enum.HumanoidStateType.Freefall then h:ChangeState(Enum.HumanoidStateType.Jumping) end
        end)
    end,
})

Visuals:createLabel({
    Name = "- [ Stealth ] -",
    Special = true,
})

Visuals:createToggle({
    Name = "Legit Mode (Random Delays)",
    flagName = "LegitMode",
    Flag = false,
    Callback = function(v) Stealth.enabled = v end,
})

Visuals:createToggle({
    Name = "Anti-Stuck Recover",
    flagName = "AntiStuckRecover",
    Flag = false,
})

Visuals:createLabel({
    Name = "- [ Server ] -",
    Special = true,
})

Visuals:createButton({
    Name = "Rejoin Server",
    Callback = rejoin,
})

Visuals:createButton({
    Name = "Hop Server",
    Callback = function()
        if hopServer() then notify("Server", "Hopping...", "info")
        else notify("Server", "Hop failed", "danger") end
    end,
})

Visuals:createButton({
    Name = "Leave Server",
    Callback = function()
        pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, "", client) end)
    end,
})

Visuals:createButton({
    Name = "Copy Place ID",
    Callback = function() pcall(function() setclipboard(tostring(game.PlaceId)) end) end,
})

---------------------------------------------------------------------- https://versusairlines.top/developers.html
-- STATS
----------------------------------------------------------------------

Stats:createLabel({
    Name = "Session Statistics",
    Special = true,
})

Stats:createLabel({
    Name = "Track your progress this session",
    Center = true,
})

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
            "Mail Claimed: "..Session.mailClaimed,
            "Codes Redeemed: "..Session.codesRedeemed,
            "Daily Deals: "..Session.dailyDealsClaimed,
            "Webhook Hits: "..Session.webhookHits,
            "Errors: "..Session.errors,
            "Current Sheckles: "..formatSheckles(getSheckles()),
        }
        notify("Stats", table.concat(lines, "\n"), "info")
    end,
})

Stats:createButton({
    Name = "Reset Stats",
    Callback = function()
        Session.plantsHarvested = 0; Session.fruitsSold = 0
        Session.seedsPlanted = 0; Session.sprinklersPlaced = 0
        Session.stealsCompleted = 0; Session.petsBought = 0
        Session.mailClaimed = 0; Session.codesRedeemed = 0
        Session.dailyDealsClaimed = 0
        Session.webhookHits = 0; Session.errors = 0
        Session.startTime = os.time()
        notify("Stats", "Reset", "info")
    end,
})

---------------------------------------------------------------------- https://versusairlines.top/developers.html
-- LOGS
----------------------------------------------------------------------

Logs:createLabel({
    Name = "Logs Viewer",
    Special = true,
})

Logs:createLabel({
    Name = "Last "..MaxLogs.." events (newest first)",
    Center = true,
})

Logs:createButton({
    Name = "Show Logs",
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
    Name = "Clear Logs",
    Callback = function() Logs = {}; notify("Logs", "Cleared", "info") end,
})

---------------------------------------------------------------------- https://versusairlines.top/developers.html
-- DEV TOOLS
----------------------------------------------------------------------

DevTools:createLabel({
    Name = "Developer Tools",
    Special = true,
})

DevTools:createLabel({
    Name = "Diagnostic + debug helpers",
    Center = true,
})

DevTools:createButton({
    Name = "Print All Flags",
    Callback = function()
        local lines = {"=== FLAGS ==="}
        for k, v in pairs(Library.Flags or {}) do
            table.insert(lines, tostring(k).." = "..tostring(v))
        end
        print(table.concat(lines, "\n"))
        notify("DevTools", "Printed flags to console", "info")
    end,
})

DevTools:createButton({
    Name = "Force Re-Auth Plot",
    Callback = function()
        PlotData.auth = false
        authPlot(true)
        notify("DevTools", "Plot re-authed: #"..tostring(PlotData.id).." | "..#PlotData.grid.." nodes", "info")
    end,
})

DevTools:createButton({
    Name = "Export Config",
    Callback = function()
        local ok, data = pcall(function()
            local cfg = { flags = {}, webhooks = Webhooks, profiles = Profiles, predictions = { stock = StockHist, weather = WeatherHist } }
            for k, v in pairs(Library.Flags or {}) do cfg.flags[k] = v end
            return HttpService:JSONEncode(cfg)
        end)
        if ok then
            pcall(function() setclipboard(data) end)
            notify("DevTools", "Config exported to clipboard", "info")
        end
    end,
})

DevTools:createButton({
    Name = "Clear All Saved Data",
    Callback = function()
        StockHist = {}; WeatherHist = {}; Logs = {}; SavedPositions = {}
        pcall(function() saveFile("Stock", "{}") end)
        pcall(function() saveFile("Weather", "{}") end)
        notify("DevTools", "All saved data cleared", "info")
    end,
})

createTodoToggle(DevTools, "Auto Collect Rare Events", "AutoRareEvents", "Auto-claim event seed drops when they spawn")
createTodoToggle(DevTools, "Guild Crate Auto-Open", "AutoGuildCrate", "Open guild crates when inventory fills")
createTodoToggle(DevTools, "Twitch Drops Auto-Claim", "AutoTwitch", "Auto-claim Twitch drop rewards")
createTodoToggle(DevTools, "Daily Login Auto", "AutoDailyLogin", "Auto-claim daily login reward")

---------------------------------------------------------------------- https://versusairlines.top/developers.html
-- TRACKING LOOPS (background)
----------------------------------------------------------------------

task.spawn(function() while task.wait(5) do pcall(trackStock) end end)
task.spawn(function() while task.wait(10) do pcall(trackWeather) end end)

task.spawn(function()
    local prev = {}
    while task.wait(15) do
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
                                sendToHook("restock", "**"..shop.Name.."** restocked: `"..name.."` x"..count, "Restock")
                                logInfo("Stock", shop.Name..": "..name.." x"..count.." restocked")
                            end
                            prev[shop.Name][name] = count
                        end
                    end
                end
            end
        end)
    end
end)

task.spawn(function()
    while task.wait(3) do
        if not Library.Flags["NotifyRare"] then continue end
        pcall(function()
            local items = getAllHarvestables("own")
            for _, item in ipairs(items) do
                if rarityRank(item.Rarity) >= rarityRank("Legendary") or item.Mutation == "Gold" or item.Mutation == "Rainbow" then
                    sendToHook("rare", item.SeedName.." | "..item.Rarity.." | "..item.Mutation.." | Weight "..item.Weight, "Rare Find")
                end
            end
        end)
    end
end)

task.spawn(function()
    local lastPos, stuck = nil, 0
    while task.wait(1) do
        pcall(function()
            local hrp = getHRP()
            if not hrp then return end
            if lastPos then
                if (hrp.Position - lastPos).Magnitude < 0.3 then stuck = stuck + 1 else stuck = 0 end
                if stuck > 30 and Library.Flags["AntiStuckRecover"] then
                    hrp.CFrame = hrp.CFrame + Vector3.new(0,5,0)
                    stuck = 0
                end
            end
            lastPos = hrp.Position
        end)
    end
end)

task.spawn(function()
    local last = 0
    while task.wait(30) do
        if not Library.Flags["NotifyProfit"] then continue end
        if os.time() - last < 60 then continue end
        last = os.time()
        local s = getSheckles()
        if s > 0 then sendToHook("profit", "Current sheckles: **"..formatSheckles(s).."**", "Profit Report") end
    end
end)

-- Pet purchase event listener
task.spawn(function()
    pcall(function()
        local bp = client:FindFirstChild("Backpack")
        if bp then
            bp.ChildAdded:Connect(function(child)
                if child:IsA("Tool") and Library.Flags["WhPetNotify"] then
                    local pname = child:GetAttribute("PetName") or child.Name
                    if petMatches(child, firstSelected(Library.Flags["WhPet"], "All"), firstSelected(Library.Flags["WhPetRarity"], "All"), firstSelected(Library.Flags["WhPetSize"], "All")) then
                        task.wait(0.5)
                        sendToHook("pets", "Got pet: **"..pname.."**", "Pet Purchased")
                        Session.petsBought = Session.petsBought + 1
                    end
                end
            end)
        end
    end)
end)

client.CharacterAdded:Connect(function(c)
    Char = c
    Hum = c:WaitForChild("Humanoid")
    HRP = c:WaitForChild("HumanoidRootPart")
    task.wait(1)
    authPlot(true)
    logInfo("Init", "Character respawned, plot re-auth")
end)

task.spawn(function()
    task.wait(2)
    authPlot()
    if PlotData.auth then
        print("[GAG2] Ready | Plot #"..tostring(PlotData.id).." | "..#PlotData.grid.." nodes")
        logInfo("Init", "Plot #"..tostring(PlotData.id).." authed with "..#PlotData.grid.." nodes")
    end
end)

notify("GAG_2", "Loaded - RCU style | Versus Airlines", "info")
print("[GAG2] Loaded")

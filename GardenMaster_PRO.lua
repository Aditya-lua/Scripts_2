--[[
    Versus Airlines | GAG 2
    Grow a Garden 2 Autofarm
    Built from decompiled GAG2 source
    Networking: ReplicatedStorage.SharedModules.Networking
]]

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local client = Players.LocalPlayer

-- Cleanup previous instance
if _G.VA_Unload then pcall(_G.VA_Unload) end
_G.VA_Unload = nil

-- ===========================================================================
-- CONNECTION & OBJECT TRACKER
-- ===========================================================================
local _alive = true
local _connections, _instances, _threads = {}, {}, {}

local function Track(v)
    if typeof(v) == "RBXScriptConnection" then
        _connections[#_connections + 1] = v
    elseif typeof(v) == "Instance" then
        _instances[#_instances + 1] = v
    elseif type(v) == "thread" then
        _threads[#_threads + 1] = v
    end
end

_G.VA_Unload = function()
    _alive = false
    for _, c in _connections do pcall(function() c:Disconnect() end) end
    for _, t in _threads do pcall(function() if coroutine.status(t) ~= "dead" then task.cancel(t) end end) end
    for _, o in _instances do pcall(function() if o and o.Parent then o:Destroy() end end) end
    _connections = {}; _instances = {}; _threads = {}
end

-- ===========================================================================
-- LIBRARY LOAD
-- ===========================================================================
local Library = loadstring(game:HttpGet("https://versusairlines.top/scripts/NewLibrary.lua"))()
if not Library then warn("[VA] Library failed to load"); return end
local UI = Library:Setup({Location = CoreGui, OpenCloseLocation = "Bottom Right"})

-- ===========================================================================
-- ANTI-AFK
-- ===========================================================================
Track(client.Idled:Connect(function()
    pcall(function()
        VirtualUser:Button2Down(Vector2.new(), Workspace.CurrentCamera.CFrame)
        task.wait(0.5)
        VirtualUser:Button2Up(Vector2.new(), Workspace.CurrentCamera.CFrame)
    end)
end))

-- ===========================================================================
-- NETWORKING MODULE
-- ===========================================================================
local Net = nil
do
    local ok, mod = pcall(function()
        return require(ReplicatedStorage:WaitForChild("SharedModules", 10):WaitForChild("Networking", 10))
    end)
    if ok and mod then
        Net = mod
    else
        warn("[VA] Networking module not found: " .. tostring(mod))
        return
    end
end

-- Optional PacketEvent for alternate planting path
local PacketEvent
pcall(function()
    PacketEvent = ReplicatedStorage:WaitForChild("SharedModules", 5):WaitForChild("Packet", 5):WaitForChild("RemoteEvent", 5)
end)

-- ===========================================================================
-- INTERVAL HELPER (Versus Airlines template pattern)
-- ===========================================================================
local function interval(tag, flag, delayTime, callback)
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
        if running or current - last < delayTime then
            return
        end
        last = current
        running = true
        task.spawn(function()
            local ok, err = pcall(callback)
            if not ok then warn("[interval:" .. tostring(tag) .. "]", err) end
            task.wait()
            running = false
        end)
    end)
    Library:TrackConnection(conn, tag)
end

-- ===========================================================================
-- NOTIFICATION HELPER
-- ===========================================================================
local function Notify(title, desc, style)
    Library:createDisplayMessage(title, desc, {
        { text = "OK" },
    }, style or "info")
end

-- ===========================================================================
-- UTILITY
-- ===========================================================================
local function trimText(v) return tostring(v or ""):gsub("^%s+", ""):gsub("%s+$", "") end

local function cleanItemName(name)
    local s = trimText(name)
    s = s:gsub("%b[]", "")
    s = s:gsub("%s*%*%s*x%d+%s*$", "")
    s = s:gsub("%s+(%d+)%s*$", "")
    s = s:gsub("_", " "):gsub(":", " ")
    s = s:gsub("^Seed%s+", ""):gsub("%s+Seed$", ""):gsub("%s+Tool$", "")
    return trimText(s:gsub("%s+", " "))
end

local function isNamedLikeSeed(name)
    local n = tostring(name or ""):lower()
    return n:find("seed", 1, true) and not n:find("seed pack", 1, true) and not n:find("seedpack", 1, true)
end

local function firstOf(value, fallback)
    if typeof(value) == "table" then
        if value[1] ~= nil then return value[1] end
        for k, v in pairs(value) do
            if v == true then return k end
            if type(v) == "string" then return v end
        end
        return fallback
    end
    return (value ~= nil and value ~= "") and value or fallback
end

local function toList(value)
    local list = {}
    if typeof(value) == "table" then
        for k, v in pairs(value) do
            if type(k) == "number" and type(v) == "string" and v ~= "" and v ~= "None" then
                list[#list + 1] = v
            elseif type(k) == "string" and v == true and k ~= "" and k ~= "None" then
                list[#list + 1] = k
            end
        end
    elseif type(value) == "string" and value ~= "" and value ~= "None" then
        list[1] = value
    end
    return list
end

local function fmtTime(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    if h > 0 then return string.format("%dh %02dm", h, m) end
    if m > 0 then return string.format("%dm %02ds", m, s) end
    return s .. "s"
end

local function selectedMode(flag, fallback)
    local v = Library.Flags[flag]
    if typeof(v) == "table" then
        if v[1] then return v[1] end
        for k, val in pairs(v) do if val == true then return k end end
        return fallback
    end
    return v or fallback
end

-- ===========================================================================
-- MOVEMENT HELPERS
-- ===========================================================================
local function TP(pos)
    local hrp = client.Character and client.Character:FindFirstChild("HumanoidRootPart")
    if hrp then pcall(function() hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3.8, 0)) end) end
end

local function smoothTP(pos)
    local hrp = client.Character and client.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local tw = TweenService:Create(hrp, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        CFrame = CFrame.new(pos + Vector3.new(0, 3.8, 0))
    })
    tw:Play(); tw.Completed:Wait()
end

local function firePrompt(prompt)
    if prompt and prompt:IsA("ProximityPrompt") then
        pcall(function() fireproximityprompt(prompt) end)
    end
end

-- ===========================================================================
-- TOOL SYSTEM
-- ===========================================================================
local function findTool(searchName)
    if not searchName or searchName == "" then return nil end
    local cs = cleanItemName(searchName):lower():gsub("%s+", "")
    if cs == "" then return nil end

    local function score(tool)
        if not tool or not tool:IsA("Tool") then return nil end
        local tn = cleanItemName(tool.Name):lower():gsub("%s+", "")
        local raw = tool.Name:lower():gsub("%s+", "")
        if tn == cs then return 5 end
        if raw == cs then return 4 end
        if tn:find(cs, 1, true) or cs:find(tn, 1, true) then return 3 end
        if isNamedLikeSeed(tool.Name) and cleanItemName(tool.Name):lower():find(cleanItemName(searchName):lower(), 1, true) then return 2 end
        return nil
    end

    local best, bestScore = nil, -1
    local function scan(container)
        if not container then return end
        for _, t in ipairs(container:GetChildren()) do
            local s = score(t)
            if s and s > bestScore then best, bestScore = t, s end
        end
    end
    scan(client.Character)
    scan(client:FindFirstChild("Backpack"))
    return best
end

local function equipTool(tool)
    if not tool or not tool.Parent then return false end
    if tool.Parent == client:FindFirstChild("Backpack") then
        local hum = client.Character and client.Character:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum:EquipTool(tool) end); task.wait(0.08) end
    end
    return tool.Parent == client.Character
end

local function unequipTools()
    local hum = client.Character and client.Character:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function() hum:UnequipTools() end); task.wait(0.05) end
end

-- ===========================================================================
-- REMOTE WRAPPERS (verified against decompiled Networking module)
-- ===========================================================================
local function harvestPlant(plantId, fruitId)
    if not plantId then return end
    Net.Garden.CollectFruit:Fire(plantId, fruitId or "")
end

local function plantSeed(seedName, pos)
    if not seedName or not pos then return false end
    local tool = findTool(seedName)
    if not tool then return false end
    local seedType = cleanItemName(tool.Name)
    if seedType == "" then seedType = cleanItemName(seedName) end
    local ok, err = pcall(function()
        if PacketEvent then
            PacketEvent:FireServer(4, pos, seedType, tool)
        else
            Net.Plant.PlantSeed:Fire(pos, seedType, tool)
        end
    end)
    return ok
end

local function placeSprinkler(name, pos)
    if not name or not pos then return false end
    local tool = findTool(name)
    if not tool or not tostring(tool.Name):lower():find("sprinkler", 1, true) then return false end
    if tool.Parent ~= client.Character then equipTool(tool); task.wait(0.03) end
    local cleanName = tool:GetAttribute("Sprinkler") or cleanItemName(tool.Name)
    local plotId = PL.plotId or (PL.model and tonumber(tostring(PL.model.Name):match("%d+"))) or client:GetAttribute("PlotId") or 1
    pcall(function() Net.Place.PlaceSprinkler:Fire(pos, cleanName, tool, plotId) end)
    return true
end

local function waterPlant(pos)
    local tool = findTool("watering") or findTool("Watering")
    if tool then equipTool(tool); task.wait(0.05) end
    local canName = tool and (tool:GetAttribute("WateringCan") or tool.Name or "")
    pcall(function() Net.WateringCan.UseWateringCan:Fire(pos - Vector3.new(0, 0.3, 0), canName, tool) end)
end

local function shovelPlant(plantId, fruitId, shovelTool)
    if not plantId then return end
    local tool = shovelTool or findTool("shovel") or findTool("Shovel")
    if not tool then return end
    if tool.Parent ~= client.Character then equipTool(tool); task.wait(0.015) end
    local attr = tool:GetAttribute("Shovel") or cleanItemName(tool.Name)
    pcall(function() Net.Shovel.UseShovel:Fire(plantId, fruitId or "", attr, tool) end)
end

local function movePlant(plantId, pos, rot)
    if not plantId or not pos then return end
    pcall(function() Net.Trowel.MovePlant:Fire(plantId, pos, rot or 0) end)
end

local function sellAll()
    pcall(function() Net.NPCS.SellAll:Fire() end)
end

local function sellFruit(fruitId)
    if not fruitId then return end
    pcall(function() Net.NPCS.SellFruit:Fire(fruitId) end)
end

local function buySeed(name)
    if not name or name == "" then return end
    pcall(function() Net.SeedShop.PurchaseSeed:Fire(name) end)
end

local function buyGear(name)
    if not name or name == "" then return end
    pcall(function() Net.GearShop.PurchaseGear:Fire(name) end)
end

local function equipGear(name)
    if not name or name == "" then return end
    pcall(function() Net.GearShop.EquipGear:Fire(name) end)
end

local function unequipGear()
    pcall(function() Net.GearShop.UnequipGear:Fire() end)
end

local function buyCrate(name)
    if not name or name == "" then return end
    pcall(function() Net.CrateShop.PurchaseCrate:Fire(name) end)
end

local function openCrate(name)
    if not name or name == "" then return end
    pcall(function() Net.Crate.OpenCrate:Fire(name) end)
end

local function openSeedPack(name)
    if not name or name == "" then return end
    pcall(function() Net.SeedPack.OpenSeedPack:Fire(name) end)
end

local function openEgg(name)
    if not name or name == "" then return end
    pcall(function() Net.Egg.OpenEgg:Fire(name) end)
end

local function beginSteal(userId, plantId, fruitId)
    pcall(function() Net.Steal.BeginSteal:Fire(userId, plantId, fruitId or "") end)
end

local function completeSteal()
    pcall(function() Net.Steal.CompleteSteal:Fire() end)
end

local function submitCode(code)
    if not code or code == "" then return end
    pcall(function() Net.Settings.SubmitCode:Fire(code) end)
end

local function equipPet(name)
    if not name or name == "" then return end
    pcall(function() Net.Pets.PetEquipped:Fire(name, {}) end)
end

local function unequipPet(name)
    if not name or name == "" then return end
    pcall(function() Net.Pets.RequestUnequipByName:Fire(name) end)
end

local function placeProp(pos, propName, tool, rot)
    if not pos or not propName then return end
    pcall(function() Net.Prop.PlaceProp:Fire(pos, propName, tool, rot or 0) end)
end

local function pickupProp(propId)
    if not propId then return end
    pcall(function() Net.Prop.PickupProp:Fire(propId) end)
end

local function checkDailyDeal()
    pcall(function() Net.NPCS.CheckDailyDeal:Fire() end)
end

local function favoriteFruit(fruitId, state)
    if not fruitId then return end
    pcall(function() Net.Backpack.SetFruitFavorite:Fire(fruitId, state) end)
end

-- ===========================================================================
-- NIGHT DETECTION
-- ===========================================================================
local function isNightTime()
    local wv = ReplicatedStorage:FindFirstChild("WeatherValues")
    if wv then
        for _, name in ipairs({"Moon", "Bloodmoon", "Goldmoon", "Rainbow", "RainbowMoon", "ChainedMoon", "PizzaMoon"}) do
            if wv:GetAttribute(name .. "_Playing") == true then return true end
        end
    end
    local nd = ReplicatedStorage:FindFirstChild("Night", true)
    if nd and nd:IsA("BoolValue") then return nd.Value end
    local t = Lighting.ClockTime
    return t < 6 or t >= 18
end

-- ===========================================================================
-- BACKPACK STATE
-- ===========================================================================
local function isBackpackFull()
    if client:GetAttribute("BackpackFull") then return true end
    local bp = client:FindFirstChild("Backpack")
    if bp and bp:GetAttribute("BackpackFull") then return true end
    local max = client:GetAttribute("BackpackMax") or client:GetAttribute("MaxBackpack") or 0
    if bp and max > 0 and #bp:GetChildren() >= max then return true end
    local pg = client:FindFirstChild("PlayerGui")
    if pg then
        for _, d in ipairs(pg:GetDescendants()) do
            if d:IsA("TextLabel") or d:IsA("TextButton") then
                local s = tostring(d.Text or ""):lower()
                if s:find("backpack") and (s:find("full") or s:find("100/100")) then return true end
            end
        end
    end
    return false
end

local function getBackpackSeeds()
    local seeds = {}
    local bp = client:FindFirstChild("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") and isNamedLikeSeed(t.Name) then seeds[#seeds + 1] = t.Name end
        end
    end
    local char = client.Character
    if char then
        for _, t in ipairs(char:GetChildren()) do
            if t:IsA("Tool") and isNamedLikeSeed(t.Name) then seeds[#seeds + 1] = t.Name end
        end
    end
    return seeds
end

local function getBackpackSprinklers()
    local list = {}
    local bp = client:FindFirstChild("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") and t.Name:lower():find("sprinkler", 1, true) then list[#list + 1] = t.Name end
        end
    end
    return list
end

-- ===========================================================================
-- PLOT SYSTEM
-- ===========================================================================
PL = {auth = false, model = nil, plotId = nil, center = Vector3.zero, gate = nil, gridNodes = {}, plantAreas = {}, occupiedHash = {}, plantsFolder = nil, sprinklersFolder = nil, rowX = nil, rowZ = nil, lastAuth = 0}

local function getPlotOwner(plot)
    if not plot then return nil end
    local uid = plot:GetAttribute("UserId") or plot:GetAttribute("OwnerId") or plot:GetAttribute("Owner")
    if type(uid) == "number" then return uid end
    local sv = plot:FindFirstChild("OwnerUserId") or plot:FindFirstChild("OwnerId")
    if sv and sv:IsA("ValueBase") then return sv.Value end
    return nil
end

local function authenticatePlot()
    if PL.auth and (os.clock() - PL.lastAuth) < 30 then return PL end
    PL.lastAuth = os.clock()

    local gardens = Workspace:FindFirstChild("Gardens") or Workspace
    local target, pid

    -- Find owned plot
    for _, plot in ipairs(gardens:GetChildren()) do
        if plot:IsA("Model") or plot:IsA("Folder") then
            if getPlotOwner(plot) == client.UserId then
                target = plot
                pid = tonumber(tostring(plot.Name):match("%d+"))
                break
            end
        end
    end

    -- Fallback: nearest plot
    if not target then
        local hrp = client.Character and client.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local closest, closestDist = nil, math.huge
            for _, plot in ipairs(gardens:GetChildren()) do
                if plot:IsA("Model") or plot:IsA("Folder") then
                    local primary = plot.PrimaryPart or plot:FindFirstChildWhichIsA("BasePart")
                    if primary then
                        local dist = (primary.Position - hrp.Position).Magnitude
                        if dist < closestDist then
                            closest = plot
                            closestDist = dist
                            pid = tonumber(tostring(plot.Name):match("%d+"))
                        end
                    end
                end
            end
            if closest and closestDist < 50 then target = closest end
        end
    end

    if not target then return PL end

    PL.model = target
    PL.plotId = pid or tonumber(tostring(target.Name):match("%d+"))
    PL.auth = true
    PL.plantAreas = {}
    PL.occupiedHash = {}
    PL.rowX = nil
    PL.rowZ = nil

    local sp = target:FindFirstChild("SpawnPoint")
    if sp and sp:IsA("BasePart") then
        PL.center = sp.Position
        PL.gate = CFrame.new(sp.Position + Vector3.new(0, 3.5, 3), sp.Position)
    else
        local pr = (target:IsA("Model") and target.PrimaryPart) or target:FindFirstChild("BottomFace", true)
        if pr and pr:IsA("BasePart") then
            PL.center = pr.Position
            PL.gate = CFrame.new(pr.Position + Vector3.new(0, 5, 15), pr.Position)
        end
    end

    PL.plantsFolder = target:FindFirstChild("Plants")
    PL.sprinklersFolder = target:FindFirstChild("Sprinklers")

    -- Find plantable floor parts
    local fallbackParts = {}
    for _, ch in ipairs(target:GetDescendants()) do
        if ch:IsA("BasePart") then
            local n = ch.Name:lower()
            local tagged = CollectionService:HasTag(ch, "PlantArea") or CollectionService:HasTag(ch, "Soil")
            local namedSoil = n:find("plantarea", 1, true) or n:find("plant area", 1, true) or n:find("soil", 1, true) or n:find("dirt", 1, true) or n:find("farm", 1, true)
            if tagged or namedSoil then
                PL.plantAreas[#PL.plantAreas + 1] = ch
            elseif n == "bottomface" or n == "base" or n == "floor" or n:find("garden", 1, true) then
                fallbackParts[#fallbackParts + 1] = ch
            end
        end
    end

    if #PL.plantAreas == 0 then
        table.sort(fallbackParts, function(a, b) return (a.Size.X * a.Size.Z) > (b.Size.X * b.Size.Z) end)
        if fallbackParts[1] then
            PL.plantAreas[#PL.plantAreas + 1] = fallbackParts[1]
        else
            local b = target:FindFirstChild("BottomFace", true) or (target:IsA("Model") and target.PrimaryPart)
            if b and b:IsA("BasePart") then PL.plantAreas[#PL.plantAreas + 1] = b end
        end
    end

    table.sort(PL.plantAreas, function(a, b) return (a.Size.X * a.Size.Z) > (b.Size.X * b.Size.Z) end)

    -- Build grid via raycast
    PL.gridNodes = {}
    for _, area in ipairs(PL.plantAreas) do
        local ap = area.Position
        local sx, sz = math.max(area.Size.X, 1) * 0.46, math.max(area.Size.Z, 1) * 0.46
        for x = -sx, sx, 2.6 do
            for z = -sz, sz, 2.6 do
                local ox = ap.X + x + math.random(-0.4, 0.4)
                local oz = ap.Z + z + math.random(-0.4, 0.4)
                local ry = Workspace:Raycast(Vector3.new(ox, ap.Y + 30, oz), Vector3.new(0, -60, 0))
                PL.gridNodes[#PL.gridNodes + 1] = ry and ry.Position or Vector3.new(ox, ap.Y + area.Size.Y / 2 + 0.15, oz)
            end
        end
    end

    -- Shuffle
    for i = #PL.gridNodes, 2, -1 do
        local j = math.random(i)
        PL.gridNodes[i], PL.gridNodes[j] = PL.gridNodes[j], PL.gridNodes[i]
    end

    return PL
end

-- ===========================================================================
-- OCCUPIED CELLS
-- ===========================================================================
local function getOccupiedCells()
    local oc, h = {}, PL.occupiedHash or {}
    if PL.plantsFolder then
        for _, p in PL.plantsFolder:GetChildren() do
            if p:IsA("Model") and p.PrimaryPart then
                local pp = p:GetPivot().Position
                oc[#oc + 1] = pp
                h[math.floor(pp.X / 2) .. "," .. math.floor(pp.Z / 2)] = true
            end
        end
    end
    if PL.sprinklersFolder then
        for _, s in PL.sprinklersFolder:GetChildren() do
            if s:IsA("Model") and s.PrimaryPart then oc[#oc + 1] = s:GetPivot().Position end
        end
    end
    PL.occupiedHash = h
    return oc
end

-- ===========================================================================
-- PLACEMENT POSITIONS
-- ===========================================================================
local function getRowPosition(spc)
    authenticatePlot()
    spc = spc or 2.9
    if not PL.auth or #PL.plantAreas == 0 then return PL.center end

    local area = PL.plantAreas[1]
    local ap = area.Position
    local sx, sz = math.max(area.Size.X, 1) * 0.44, math.max(area.Size.Z, 1) * 0.44

    if not PL.rowX then PL.rowX = ap.X - sx; PL.rowZ = ap.Z - sz end

    local x, z = PL.rowX, PL.rowZ
    getOccupiedCells()
    local key = math.floor(x / 2) .. "," .. math.floor(z / 2)
    local tries = 0
    while PL.occupiedHash[key] and tries < 600 do
        x = x + spc
        if x > ap.X + sx then x = ap.X - sx; z = z + spc end
        if z > ap.Z + sz then z = ap.Z - sz; x = ap.X - sx end
        key = math.floor(x / 2) .. "," .. math.floor(z / 2)
        tries = tries + 1
    end

    local r = Workspace:Raycast(Vector3.new(x, ap.Y + 30, z), Vector3.new(0, -60, 0))
    local pos = r and r.Position or Vector3.new(x, ap.Y + area.Size.Y / 2 + 0.15, z)

    PL.rowX = x + spc
    if PL.rowX > ap.X + sx then PL.rowX = ap.X - sx; PL.rowZ = PL.rowZ + spc end
    if PL.rowZ > ap.Z + sz then PL.rowZ = ap.Z - sz end
    PL.occupiedHash[key] = true
    return pos
end

local function getPlacementPosition(spc)
    authenticatePlot()
    spc = spc or 2.9
    local mode = Library.Flags["PlacingMode"] or "Good Position"
    local hrp = client.Character and client.Character:FindFirstChild("HumanoidRootPart")

    if mode == "Good Position" then return getRowPosition(spc) end

    if mode == "Player Position" then
        if hrp then
            local r = Workspace:Raycast(hrp.Position + Vector3.new(0, 6, 0), Vector3.new(0, -30, 0))
            return r and r.Position or hrp.Position - Vector3.new(0, 2.8, 0)
        end
        return Vector3.zero
    end

    if mode == "Random" and PL.auth then
        local h = 18
        local rx = PL.center.X + (math.random() * 2 - 1) * h
        local rz = PL.center.Z + (math.random() * 2 - 1) * h
        local r = Workspace:Raycast(Vector3.new(rx, PL.center.Y + 28, rz), Vector3.new(0, -55, 0))
        return r and r.Position or Vector3.new(rx, PL.center.Y, rz)
    end

    if mode == "Mouse" then
        local mp
        pcall(function() local m = client:GetMouse(); if m and m.Hit then mp = m.Hit.Position end end)
        if mp then return mp end
    end

    -- Fallback: grid
    if not PL.auth or #PL.gridNodes == 0 then return hrp and hrp.Position or Vector3.zero end
    local o = getOccupiedCells()
    for _, n in PL.gridNodes do
        local k = math.floor(n.X / 2) .. "," .. math.floor(n.Z / 2)
        if not PL.occupiedHash[k] then
            local ok = true
            for _, u in o do
                if (Vector3.new(u.X, n.Y, u.Z) - n).Magnitude < 2.5 then ok = false; break end
            end
            if ok then PL.occupiedHash[k] = true; return n end
        end
    end
    return hrp and hrp.Position or Vector3.zero
end

local function enforceGeofence(mode)
    if not PL.auth or not PL.gate then return end
    local hrp = client.Character and client.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local range = mode == "p" and 60 or mode == "c" and 100 or 80
    if (hrp.Position - PL.center).Magnitude > range then pcall(function() hrp.CFrame = PL.gate end) end
end

-- ===========================================================================
-- VALUE SCORING & FILTERING
-- ===========================================================================
local MutationValue = {gold=15, rainbow=42, electric=11, solarflare=13, frozen=9, bloodlit=11, chained=7, pizza=6, starstruck=22, ghost=18, poison=14}
local RarityScore = {common=1, uncommon=2, rare=3, super=4, epic=5, legendary=6, mythic=7}

local function passesFilter(model, fruitF, mutF, rarF)
    if not model then return false end
    local nm = model.Name:lower()
    local sa = (model:GetAttribute("SeedName") or ""):lower()
    local ma = (model:GetAttribute("Mutation") or ""):lower()
    local ra = (model:GetAttribute("Rarity") or ""):lower()

    if fruitF and #fruitF > 0 then
        local ok = false
        for _, f in ipairs(fruitF) do if nm:find(f:lower(), 1, true) or sa:find(f:lower(), 1, true) then ok = true; break end end
        if not ok then return false end
    end
    if mutF and #mutF > 0 then
        local ok = false
        for _, m in ipairs(mutF) do if ma == m:lower() then ok = true; break end end
        if not ok then return false end
    end
    if rarF and #rarF > 0 then
        local ok = false
        for _, r in ipairs(rarF) do if ra == r:lower() then ok = true; break end end
        if not ok then return false end
    end
    return true
end

local function calculatePlantValue(model)
    if not model then return 0 end
    local s = 0
    local rarity = (model:GetAttribute("Rarity") or ""):lower()
    s = s + (RarityScore[rarity] or 1) * 120
    local mutation = (model:GetAttribute("Mutation") or ""):lower()
    s = s * (MutationValue[mutation] or 1)
    local size = model:GetAttribute("Size") or model:GetAttribute("FruitSize") or 1
    if type(size) == "number" then s = s * math.max(size, 0.15) end
    local sv = model:GetAttribute("Value") or model:GetAttribute("SellValue") or 0
    if type(sv) == "number" then s = s + sv * 1.2 end
    if model:GetAttribute("MultiHarvest") or model.Name:lower():find("multi") or model.Name:lower():find("regrow") then s = s * 1.6 end
    local age = model:GetAttribute("Age") or model:GetAttribute("Growth") or 1
    if type(age) == "number" and age > 1 then s = s * (1 + math.min(age / 10, 0.8)) end
    return s
end

local function getCandidates(maxCount, fruitF, mutF, rarF, ownedOnly, blacklist)
    maxCount = maxCount or 12
    local candidates = {}
    local hrp = client.Character and client.Character:FindFirstChild("HumanoidRootPart")
    local gardens = Workspace:FindFirstChild("Gardens") or Workspace

    local function add(model, isOurs)
        if not model or not model:IsA("Model") then return end
        if blacklist and #blacklist > 0 then
            for _, b in ipairs(blacklist) do if model.Name:lower():find(b:lower(), 1, true) then return end end
        end
        if not passesFilter(model, fruitF, mutF, rarF) then return end
        if ownedOnly and not isOurs then return end
        local pid = model:GetAttribute("PlantId")
        local fid = model:GetAttribute("FruitId")
        local sc = calculatePlantValue(model)
        local d = hrp and (model:GetPivot().Position - hrp.Position).Magnitude or 0
        candidates[#candidates + 1] = {model = model, plantId = pid, fruitId = fid, score = sc, distance = d, isOwned = isOurs}
    end

    for _, prompt in ipairs(CollectionService:GetTagged("HarvestPrompt")) do
        add(prompt:FindFirstAncestorWhichIsA("Model"), true)
    end

    for _, plot in ipairs(gardens:GetChildren()) do
        if plot:IsA("Model") or plot:IsA("Folder") then
            local ours = getPlotOwner(plot) == client.UserId
            local pf = plot:FindFirstChild("Plants")
            if pf then for _, m in ipairs(pf:GetChildren()) do if m:IsA("Model") then add(m, ours) end end end
        end
    end

    table.sort(candidates, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.distance < b.distance
    end)

    local r = {}
    for i = 1, math.min(maxCount, #candidates) do r[#r + 1] = candidates[i] end
    return r
end

-- ===========================================================================
-- SEED SHOP RESTOCK
-- ===========================================================================
local function getSeedRestockSeconds()
    local stock = ReplicatedStorage:FindFirstChild("StockValues")
    local seedShop = stock and stock:FindFirstChild("SeedShop")
    local nextRestock = seedShop and seedShop:FindFirstChild("UnixNextRestock")
    if nextRestock and tonumber(nextRestock.Value) then
        return math.max(0, tonumber(nextRestock.Value) - os.time())
    end
    local pg = client:FindFirstChild("PlayerGui")
    local shopGui = pg and pg:FindFirstChild("SeedShop")
    if not shopGui then return nil end
    for _, d in ipairs(shopGui:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") then
            local txt = tostring(d.Text or ""):lower()
            if txt:find("restock", 1, true) then
                local h = tonumber(txt:match("(%d+)%s*h")) or 0
                local m = tonumber(txt:match("(%d+)%s*m")) or 0
                local s = tonumber(txt:match("(%d+)%s*s")) or 0
                local total = h * 3600 + m * 60 + s
                if total > 0 then return total end
            end
        end
    end
    return nil
end

-- ===========================================================================
-- INTERVAL TOGGLE BUILDER
-- ===========================================================================
local function buildToggle(parent, cfg)
    local tag, flag, delay, step = cfg.tag or cfg.flagName, cfg.flagName, cfg.delay or 0.5, cfg.step
    parent:createToggle({
        Name = cfg.Name,
        flagName = flag,
        Flag = cfg.Flag or false,
        Callback = function()
            Library:CleanupConnectionsByTag(tag)
            if not Library.Flags[flag] then return end
            local actualDelay = Library.Flags["LegitMode"]
                and (delay * (0.6 + math.random() * 0.8) + math.random(0.05, 0.25))
                or delay
            interval(tag, flag, actualDelay, step)
        end
    })
end

-- ===========================================================================
-- GAME DATA DISCOVERY
-- ===========================================================================
local GD = {seeds = {}, gears = {}, crates = {}, pets = {}}
local MTS = {"Gold", "Rainbow", "Electric", "Solarflare", "Frozen", "Bloodlit", "Chained", "Pizza", "Starstruck", "Ghost", "Poison"}
local RTS = {"Common", "Uncommon", "Rare", "Super", "Epic", "Legendary", "Mythic"}

pcall(function()
    local sm, gm, cm, pm = {}, {}, {}, {}
    for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
        if d:IsA("ModuleScript") then
            local n = d.Name:lower()
            local target = nil
            if n:find("seed", 1, true) and not n:find("pack", 1, true) then target = sm
            elseif n:find("gear", 1, true) and not n:find("shop", 1, true) then target = gm
            elseif n:find("crate", 1, true) then target = cm
            elseif n:find("pet", 1, true) then target = pm end
            if target then
                pcall(function()
                    local data = require(d)
                    if type(data) == "table" then
                        for k in pairs(data) do if type(k) == "string" then target[k] = true end end
                    end
                end)
            end
        end
    end
    for k in pairs(sm) do GD.seeds[#GD.seeds + 1] = k end
    for k in pairs(gm) do GD.gears[#GD.gears + 1] = k end
    for k in pairs(cm) do GD.crates[#GD.crates + 1] = k end
    for k in pairs(pm) do GD.pets[#GD.pets + 1] = k end
    table.sort(GD.seeds); table.sort(GD.gears); table.sort(GD.crates); table.sort(GD.pets)
end)

-- ===========================================================================
-- ESP SYSTEM
-- ===========================================================================
local ESP_Cache = {}

local function createESP(object, text, color)
    if ESP_Cache[object] then
        local holder = ESP_Cache[object]
        if holder and holder.Parent then
            local bb = holder:FindFirstChild("BB")
            if bb then local label = bb:FindFirstChild("Label"); if label then label.Text = text end end
        end
        return
    end

    local holder = Instance.new("Folder")
    holder.Name = "ESP_" .. object.Name

    local highlight = Instance.new("Highlight")
    highlight.FillColor = color or Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = 0.7
    highlight.OutlineColor = color or Color3.fromRGB(255, 255, 255)
    highlight.OutlineTransparency = 0
    highlight.Adornee = object
    highlight.Parent = holder

    local bb = Instance.new("BillboardGui")
    bb.Name = "BB"
    bb.Size = UDim2.new(0, 200, 0, 50)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.Adornee = object:IsA("Model") and (object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart")) or object
    bb.Parent = holder

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.Parent = bb

    holder.Parent = CoreGui
    ESP_Cache[object] = holder
end

local function cleanESP()
    for _, holder in pairs(ESP_Cache) do pcall(function() holder:Destroy() end) end
    ESP_Cache = {}
end

-- ===========================================================================
-- UI TABS
-- ===========================================================================
local HomeTab = UI:CreateSection("Home")
local FarmTab = UI:CreateSection("Farm")
local StealTab = UI:CreateSection("Steal")
local ShopTab = UI:CreateSection("Shop")
local PlayerTab = UI:CreateSection("Player")
local VisualsTab = UI:CreateSection("Visuals")
local MiscTab = UI:CreateSection("Misc")

-- ===========================================================================
-- HOME TAB
-- ===========================================================================
HomeTab:createLabel({Name = "Versus Airlines | GAG 2", Special = true})
HomeTab:createLabel({Name = "v1.0 — Built from decompiled source", Center = true})

HomeTab:createButton({Name = "Refresh Plot", Callback = function()
    PL.auth = false; PL.lastAuth = 0
    authenticatePlot()
    if PL.auth then
        Notify("Plot", "Plot #" .. tostring(PL.plotId or "?") .. " ready — " .. #PL.gridNodes .. " nodes", "info")
    else
        Notify("Plot", "No plot found. Stand in your garden and try again.", "warning")
    end
end})

HomeTab:createButton({Name = "Show Status", Callback = function()
    authenticatePlot()
    local restock = getSeedRestockSeconds()
    Notify("Status", string.format(
        "Plot: %s\nSeeds: %d | Gears: %d\nNight: %s\nRestock: %s",
        PL.auth and ("#" .. tostring(PL.plotId or "?")) or "none",
        #GD.seeds, #GD.gears,
        isNightTime() and "yes" or "no",
        restock and fmtTime(restock) or "syncing"
    ), "info")
end})

HomeTab:createButton({Name = "Rejoin Server", Callback = function()
    pcall(function() TeleportService:Teleport(game.PlaceId, client) end)
end})

-- ===========================================================================
-- FARM TAB
-- ===========================================================================
FarmTab:createLabel({Name = "Planting", Special = true})
FarmTab:createDropdown({Name = "Seeds", flagName = "PS_list", multi = true, List = GD.seeds})
FarmTab:createDropdown({Name = "Mode", flagName = "PS_type", List = {"None", "All", "Selected"}})
FarmTab:createDropdown({Name = "Placement", flagName = "PlacingMode", List = {"Good Position", "Player Position", "Random", "Mouse"}})
FarmTab:createDropdown({Name = "Priority", flagName = "PP", List = {"Manual Order", "Highest Value"}})

buildToggle(FarmTab, {
    Name = "Auto Plant", flagName = "AP", tag = "AP", delay = 0.35,
    step = function()
        authenticatePlot()
        local st = selectedMode("PS_type", "None")
        if st == "None" then return end
        enforceGeofence("p")

        local seeds = st == "All" and getBackpackSeeds() or toList(Library.Flags["PS_list"])
        if #seeds == 0 then return end

        if selectedMode("PP", "Manual Order") == "Highest Value" then
            local score = {}
            for _, n in ipairs(seeds) do
                local t = findTool(n)
                score[n] = t and (t:GetAttribute("Value") or t:GetAttribute("Price") or 1) or 1
            end
            table.sort(seeds, function(a, b) return (score[a] or 0) > (score[b] or 0) end)
        end

        for _, seedName in ipairs(seeds) do
            if not Library.Flags["AP"] then break end
            local pos = getPlacementPosition(2.9)
            if pos then plantSeed(seedName, pos); task.wait(0.08) end
        end
    end
})

FarmTab:createLabel({Name = "Collection", Special = true})
FarmTab:createDropdown({Name = "Filter", flagName = "AH_type", List = {"None", "All", "Selected", "Blacklist"}})
FarmTab:createDropdown({Name = "Fruits", flagName = "AH_list", multi = true, List = GD.seeds})
FarmTab:createDropdown({Name = "Blacklist", flagName = "AH_blist", multi = true, List = GD.seeds})
FarmTab:createDropdown({Name = "Priority", flagName = "HP", List = {"Highest Value", "Closest", "Oldest"}})
FarmTab:createToggle({Name = "Stop When Full", flagName = "AH_fullstop", Flag = false})

buildToggle(FarmTab, {
    Name = "Auto Collect", flagName = "AH", tag = "AH", delay = 0.05,
    step = function()
        local st = selectedMode("AH_type", "None")
        if st == "None" then return end
        authenticatePlot()
        if Library.Flags["AH_fullstop"] and isBackpackFull() then return end
        enforceGeofence("c")

        local include, blacklist
        if st == "Selected" then include = toList(Library.Flags["AH_list"])
        elseif st == "Blacklist" then blacklist = toList(Library.Flags["AH_blist"]) end

        local candidates = getCandidates(500, include, nil, nil, true, blacklist)
        local used = 0
        for _, c in ipairs(candidates) do
            if not Library.Flags["AH"] or used >= 80 then break end
            if c.plantId then
                task.spawn(harvestPlant, c.plantId, c.fruitId)
                used += 1
            end
            task.wait(0.01)
        end
    end
})

FarmTab:createLabel({Name = "Selling", Special = true})
FarmTab:createDropdown({Name = "Mode", flagName = "Sell_type", List = {"None", "Always", "When Full"}})

buildToggle(FarmTab, {
    Name = "Auto Sell", flagName = "AS", tag = "AS", delay = 0.55,
    step = function()
        local mode = selectedMode("Sell_type", "None")
        if mode == "None" then return end
        if mode == "When Full" and not isBackpackFull() then return end
        sellAll()
    end
})

FarmTab:createButton({Name = "Sell All Now", Callback = function()
    sellAll()
    Notify("Sell", "SellAll fired", "info")
end})

FarmTab:createLabel({Name = "Sprinklers", Special = true})
FarmTab:createDropdown({Name = "Sprinkler", flagName = "SP_list", multi = true, List = GD.gears})

buildToggle(FarmTab, {
    Name = "Auto Sprinkler", flagName = "SP", tag = "SP", delay = 0.35,
    step = function()
        authenticatePlot(); enforceGeofence("p")
        local selected = toList(Library.Flags["SP_list"])
        local sprinklers = #selected > 0 and selected or getBackpackSprinklers()
        for _, name in ipairs(sprinklers) do
            if not Library.Flags["SP"] then break end
            local pos = getPlacementPosition(4.0)
            if pos then placeSprinkler(name, pos); task.wait(0.08) end
        end
    end
})

FarmTab:createLabel({Name = "Shovel", Special = true})
FarmTab:createDropdown({Name = "Fruit", flagName = "RM_list", multi = true, List = GD.seeds})
FarmTab:createDropdown({Name = "Mode", flagName = "RM_type", List = {"None", "All", "Selected", "Blacklist"}})

buildToggle(FarmTab, {
    Name = "Auto Shovel", flagName = "RM", tag = "RM", delay = 0.18,
    step = function()
        local st = selectedMode("RM_type", "None")
        if st == "None" then return end
        authenticatePlot()
        if not PL.plantsFolder then return end

        local include, blacklist
        if st == "Selected" then include = toList(Library.Flags["RM_list"])
        elseif st == "Blacklist" then blacklist = toList(Library.Flags["RM_list"]) end

        local candidates = getCandidates(300, include, nil, nil, true, blacklist)
        local shovel = findTool("shovel") or findTool("Shovel")
        for _, c in ipairs(candidates) do
            if not Library.Flags["RM"] then break end
            if c.plantId then shovelPlant(c.plantId, c.fruitId, shovel); task.wait(0.012) end
        end
    end
})

-- ===========================================================================
-- STEAL TAB
-- ===========================================================================
StealTab:createLabel({Name = "Night Stealing", Special = true})
StealTab:createDropdown({Name = "Rarities", flagName = "ST_rar", multi = true, List = RTS})
StealTab:createDropdown({Name = "Fruits", flagName = "ST_names", multi = true, List = GD.seeds})
StealTab:createDropdown({Name = "Mutation Whitelist", flagName = "ST_mw", multi = true, List = MTS})
StealTab:createDropdown({Name = "Mutation Blacklist", flagName = "ST_mb", multi = true, List = MTS})
StealTab:createSlider({Name = "Min Value", flagName = "ST_minKG", value = 0, minValue = 0, maxValue = 100000})
StealTab:createSlider({Name = "Carry Limit", flagName = "ST_carry", value = 50, minValue = 1, maxValue = 200})
StealTab:createDropdown({Name = "Priority", flagName = "ST_prio", List = {"Value", "Closest", "Random"}})
StealTab:createToggle({Name = "Skip Friends", flagName = "ST_skipF", Flag = false})
StealTab:createToggle({Name = "Avoid Owners", flagName = "ST_avoidO", Flag = false})

buildToggle(StealTab, {
    Name = "Auto Steal", flagName = "ST", tag = "ST", delay = 0.65,
    step = function()
        local sr = toList(Library.Flags["ST_rar"])
        local sn = toList(Library.Flags["ST_names"])
        local mw = toList(Library.Flags["ST_mw"])
        local mb = toList(Library.Flags["ST_mb"])
        local minScore = Library.Flags["ST_minKG"] or 0
        local carry = Library.Flags["ST_carry"] or 50
        local priority = selectedMode("ST_prio", "Value")

        local candidates = getCandidates(350, sn, mw, sr, false)
        local filtered = {}
        for _, c in ipairs(candidates) do
            if c.model and not c.isOwned then
                local mut = tostring(c.model:GetAttribute("Mutation") or ""):lower()
                local blocked = false
                for _, b in ipairs(mb) do if mut == tostring(b):lower() then blocked = true; break end end
                if not blocked and (minScore <= 0 or c.score >= minScore) then filtered[#filtered + 1] = c end
            end
        end
        candidates = filtered

        if priority == "Closest" then
            table.sort(candidates, function(a, b) return a.distance < b.distance end)
        elseif priority == "Random" then
            for i = #candidates, 2, -1 do local j = math.random(i); candidates[i], candidates[j] = candidates[j], candidates[i] end
        else
            table.sort(candidates, function(a, b) return a.score > b.score end)
        end

        local stolen = 0
        for _, c in ipairs(candidates) do
            if not Library.Flags["ST"] or stolen >= carry then break end
            local plot = c.model
            while plot and plot.Parent and plot.Parent ~= Workspace and not getPlotOwner(plot) do plot = plot.Parent end
            local ownerId = plot and getPlotOwner(plot)
            if ownerId and ownerId ~= client.UserId then
                if Library.Flags["ST_skipF"] then
                    local ok, isFriend = pcall(function() return client:IsFriendsWith(ownerId) end)
                    if ok and isFriend then continue end
                end
                if Library.Flags["ST_avoidO"] then
                    local owner = Players:GetPlayerByUserId(ownerId)
                    if owner and owner.Character and owner.Character:FindFirstChild("HumanoidRootPart") then
                        if (c.model:GetPivot().Position - owner.Character.HumanoidRootPart.Position).Magnitude < 20 then continue end
                    end
                end
                TP(c.model:GetPivot().Position)
                task.wait(0.08)
                beginSteal(ownerId, c.plantId, c.fruitId)
                task.wait(0.04)
                completeSteal()
                if c.plantId then task.spawn(harvestPlant, c.plantId, c.fruitId) end
                stolen += 1
                task.wait(0.16)
            end
        end
    end
})

-- ===========================================================================
-- SHOP TAB
-- ===========================================================================
ShopTab:createLabel({Name = "Seeds", Special = true})
ShopTab:createDropdown({Name = "Select Seed", flagName = "SH_seeds", multi = true, List = GD.seeds})

buildToggle(ShopTab, {
    Name = "Auto Buy Seeds", flagName = "SH_bs", tag = "SH_bs", delay = 1.0,
    step = function()
        for _, name in ipairs(toList(Library.Flags["SH_seeds"])) do
            if not Library.Flags["SH_bs"] then break end
            buySeed(name); task.wait(0.05)
        end
    end
})

buildToggle(ShopTab, {
    Name = "Buy All Seeds", flagName = "SH_bs_all", tag = "SH_bs_all", delay = 1.0,
    step = function()
        for _, name in ipairs(GD.seeds) do
            if not Library.Flags["SH_bs_all"] then break end
            buySeed(name); task.wait(0.04)
        end
    end
})

ShopTab:createLabel({Name = "Gear", Special = true})
ShopTab:createDropdown({Name = "Select Gear", flagName = "SH_gears", multi = true, List = GD.gears})

buildToggle(ShopTab, {
    Name = "Auto Buy Gear", flagName = "SH_bg", tag = "SH_bg", delay = 1.0,
    step = function()
        for _, name in ipairs(toList(Library.Flags["SH_gears"])) do
            if not Library.Flags["SH_bg"] then break end
            buyGear(name); task.wait(0.05)
        end
    end
})

ShopTab:createLabel({Name = "Crates", Special = true})
ShopTab:createDropdown({Name = "Select Crate", flagName = "SH_crates", multi = true, List = GD.crates})

buildToggle(ShopTab, {
    Name = "Auto Buy Crate", flagName = "SH_bp", tag = "SH_bp", delay = 1.0,
    step = function()
        for _, name in ipairs(toList(Library.Flags["SH_crates"])) do
            if not Library.Flags["SH_bp"] then break end
            buyCrate(name); task.wait(0.05)
        end
    end
})

ShopTab:createLabel({Name = "Stock", Special = true})
ShopTab:createButton({Name = "Check Seed Restock", Callback = function()
    local restock = getSeedRestockSeconds()
    Notify("Seed Shop", restock and ("Next restock in " .. fmtTime(restock)) or "Restock timer not found. Open seed shop once.", "info")
end})

ShopTab:createButton({Name = "Check Stock", Callback = function()
    local stock = ReplicatedStorage:FindFirstChild("StockValues")
    if not stock then Notify("Stock", "StockValues not found", "warning"); return end
    local msg = ""
    for _, shop in ipairs(stock:GetChildren()) do
        local items = shop:FindFirstChild("Items")
        if items then
            msg = msg .. shop.Name .. ": "
            local count = 0
            for _, item in ipairs(items:GetChildren()) do
                if item:IsA("NumberValue") and item.Value > 0 then
                    msg = msg .. item.Name .. " x" .. item.Value .. ", "
                    count += 1
                end
            end
            if count == 0 then msg = msg .. "no stock" end
            msg = msg .. "\n"
        end
    end
    Notify("Stock", msg, "info")
end})

-- ===========================================================================

-- ===========================================================================
-- PREDICTORS TAB
-- ===========================================================================
local PredTab = UI:CreateSection("Predictors")

-- Weather data from ReplicatedStorage.WeatherValues
-- Each weather has: Playing (BoolValue), EndTime (NumberValue)
-- Also attributes on WeatherValues folder: {Name}_Playing, {Name}_EndTime
local WeatherTypes = {
    {id = "Starfall",  label = "Starfall",  color = Color3.fromRGB(255, 220, 100), mutations = {"Starstruck"}},
    {id = "Snowfall",  label = "Snowfall",  color = Color3.fromRGB(180, 220, 255), mutations = {"Frozen"}},
    {id = "Rainbow",   label = "Rainbow",   color = Color3.fromRGB(120, 255, 200), mutations = {"Rainbow"}},
    {id = "Rain",      label = "Rain",      color = Color3.fromRGB(100, 150, 255), mutations = {}},
    {id = "Lighting",  label = "Lighting",  color = Color3.fromRGB(255, 255, 150), mutations = {"Electric"}},
}

local function readWeatherState()
    local wv = ReplicatedStorage:FindFirstChild("WeatherValues")
    if not wv then return {} end

    local states = {}
    for _, wt in ipairs(WeatherTypes) do
        local folder = wv:FindFirstChild(wt.id)
        local playing = false
        local endTime = 0

        if folder then
            local pv = folder:FindFirstChild("Playing")
            local ev = folder:FindFirstChild("EndTime")
            if pv and pv:IsA("BoolValue") then playing = pv.Value end
            if ev and ev:IsA("NumberValue") then endTime = ev.Value end
        else
            -- Fallback: read attributes from parent folder
            playing = wv:GetAttribute(wt.id .. "_Playing") == true
            endTime = wv:GetAttribute(wt.id .. "_EndTime") or 0
        end

        local remaining = 0
        if playing then
            remaining = math.max(0, endTime - os.time())
        end

        states[wt.id] = {
            playing = playing,
            endTime = endTime,
            remaining = remaining,
            mutations = wt.mutations,
            label = wt.label,
            color = wt.color,
        }
    end
    return states
end

local function readStockData()
    local stock = ReplicatedStorage:FindFirstChild("StockValues")
    if not stock then return {} end

    local data = {}
    for _, shop in ipairs(stock:GetChildren()) do
        local items = shop:FindFirstChild("Items")
        if items then
            local shopData = {}
            for _, item in ipairs(items:GetChildren()) do
                if item:IsA("NumberValue") then
                    shopData[#shopData + 1] = {name = item.Name, count = item.Value}
                end
            end
            table.sort(shopData, function(a, b)
                if (a.count > 0) ~= (b.count > 0) then return a.count > 0 end
                return a.name < b.name
            end)
            data[shop.Name] = shopData
        end
    end
    return data
end

-- Predicted restock tracker: snapshots stock changes to estimate intervals
local StockSnapshots = {}
local RestockPredictions = {}

local function updateRestockPredictions()
    local stock = ReplicatedStorage:FindFirstChild("StockValues")
    if not stock then return end

    local now = os.time()
    for _, shop in ipairs(stock:GetChildren()) do
        local items = shop:FindFirstChild("Items")
        if not items then continue end
        for _, item in ipairs(items:GetChildren()) do
            if not item:IsA("NumberValue") then continue end
            local key = shop.Name .. "." .. item.Name
            local prev = StockSnapshots[key] or 0
            local curr = item.Value

            if prev == 0 and curr > 0 then
                -- Item just restocked
                local lastRestock = RestockPredictions[key] and RestockPredictions[key].lastSeen or now
                local interval = now - lastRestock
                if interval > 60 then
                    RestockPredictions[key] = {interval = interval, nextAt = now + interval, lastSeen = now}
                end
            end

            if curr > 0 then
                if not RestockPredictions[key] then
                    RestockPredictions[key] = {lastSeen = now}
                else
                    RestockPredictions[key].lastSeen = now
                end
            end

            StockSnapshots[key] = curr
        end
    end
end

-- Seed shop restock timer (from UnixNextRestock)
local function getSeedRestockUnix()
    local stock = ReplicatedStorage:FindFirstChild("StockValues")
    local shop = stock and stock:FindFirstChild("SeedShop")
    local nr = shop and shop:FindFirstChild("UnixNextRestock")
    if nr and tonumber(nr.Value) then return tonumber(nr.Value) end
    return nil
end

-- Gear shop restock timer
local function getGearRestockUnix()
    local stock = ReplicatedStorage:FindFirstChild("StockValues")
    local shop = stock and stock:FindFirstChild("GearShop")
    local nr = shop and shop:FindFirstChild("UnixNextRestock")
    if nr and tonumber(nr.Value) then return tonumber(nr.Value) end
    return nil
end

-- ===========================================================================
-- PREDICTORS HUD (ScreenGui overlay)
-- ===========================================================================
local PredHUD = Instance.new("ScreenGui")
PredHUD.Name = "VA_Predictors"
PredHUD.ResetOnSpawn = false
PredHUD.Parent = CoreGui
PredHUD.Enabled = false
Track(PredHUD)

-- Weather bar at bottom
local WeatherBar = Instance.new("Frame")
WeatherBar.Name = "WeatherBar"
WeatherBar.Size = UDim2.new(0, 520, 0, 40)
WeatherBar.Position = UDim2.new(0.5, -260, 1, -90)
WeatherBar.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
WeatherBar.BackgroundTransparency = 0.05
WeatherBar.BorderSizePixel = 1
WeatherBar.BorderColor3 = Color3.fromRGB(50, 50, 60)
WeatherBar.Parent = PredHUD

Instance.new("UICorner", WeatherBar).CornerRadius = UDim.new(0, 6)

local WeatherLayout = Instance.new("UIListLayout")
WeatherLayout.Parent = WeatherBar
WeatherLayout.FillDirection = Enum.FillDirection.Horizontal
WeatherLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
WeatherLayout.VerticalAlignment = Enum.VerticalAlignment.Center
WeatherLayout.Padding = UDim.new(0, 4)

local WeatherWidgets = {}

for i, wt in ipairs(WeatherTypes) do
    local box = Instance.new("Frame")
    box.Name = wt.id
    box.Size = UDim2.new(0, 96, 0, 32)
    box.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    box.BorderSizePixel = 1
    box.BorderColor3 = wt.color
    box.LayoutOrder = i
    box.Parent = WeatherBar

    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)

    local text = Instance.new("TextLabel")
    text.Name = "Text"
    text.Size = UDim2.new(1, -6, 1, -4)
    text.Position = UDim2.new(0, 3, 0, 2)
    text.BackgroundTransparency = 1
    text.Text = wt.label .. "\n--"
    text.TextColor3 = wt.color
    text.Font = Enum.Font.GothamBold
    text.TextSize = 9
    text.TextWrapped = true
    text.TextXAlignment = Enum.TextXAlignment.Center
    text.Parent = box

    WeatherWidgets[wt.id] = text
end

-- Stock ticker below weather bar
local StockBar = Instance.new("Frame")
StockBar.Name = "StockBar"
StockBar.Size = UDim2.new(0, 520, 0, 20)
StockBar.Position = UDim2.new(0.5, -260, 1, -48)
StockBar.BackgroundTransparency = 1
StockBar.Parent = PredHUD

local StockLayout = Instance.new("UIListLayout")
StockLayout.FillDirection = Enum.FillDirection.Horizontal
StockLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
StockLayout.Padding = UDim.new(0, 6)
StockLayout.Parent = StockBar

local StockLabels = {}

local function updateStockLabel(key, text, visible)
    if not visible then
        if StockLabels[key] then StockLabels[key].Visible = false end
        return
    end
    if not StockLabels[key] then
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0, 120, 0, 16)
        label.BackgroundTransparency = 0.2
        label.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
        label.BorderSizePixel = 0
        label.TextColor3 = Color3.fromRGB(160, 255, 160)
        label.Font = Enum.Font.GothamMedium
        label.TextSize = 9
        label.TextTruncate = Enum.TextTruncate.AtEnd
        label.Parent = StockBar
        Instance.new("UICorner", label).CornerRadius = UDim.new(0, 3)
        StockLabels[key] = label
    end
    StockLabels[key].Text = text
    StockLabels[key].Visible = true
end

-- Status line at very bottom
local StatusBar = Instance.new("Frame")
StatusBar.Name = "StatusBar"
StatusBar.Size = UDim2.new(0, 520, 0, 16)
StatusBar.Position = UDim2.new(0.5, -260, 1, -26)
StatusBar.BackgroundTransparency = 1
StatusBar.Parent = PredHUD

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, 0, 1, 0)
StatusLabel.BackgroundTransparency = 1
StatusLabel.TextColor3 = Color3.fromRGB(170, 170, 180)
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 9
StatusLabel.Text = "Versus Airlines | Syncing..."
StatusLabel.TextXAlignment = Enum.TextXAlignment.Center
StatusLabel.Parent = StatusBar

-- ===========================================================================
-- PREDICTOR UPDATE LOOP
-- ===========================================================================
Track(task.spawn(function()
    while _alive do
        task.wait(1.0)
        pcall(function()
            PredHUD.Enabled = Library.Flags["ShowPred"] == true

            -- Weather
            local weather = readWeatherState()
            for _, wt in ipairs(WeatherTypes) do
                local w = weather[wt.id]
                local widget = WeatherWidgets[wt.id]
                if w and widget then
                    if w.playing then
                        widget.Text = wt.label .. "\n" .. fmtTime(w.remaining)
                        widget.Parent.BackgroundTransparency = 0.3
                    else
                        widget.Text = wt.label .. "\n--"
                        widget.Parent.BackgroundTransparency = 0.7
                    end
                end
            end

            -- Stock ticker (show items with stock > 0)
            local stockData = readStockData()
            local stockCount = 0
            for shopName, items in pairs(stockData) do
                for _, item in ipairs(items) do
                    if item.count > 0 and stockCount < 8 then
                        local key = shopName .. "." .. item.name
                        local label = shopName:gsub("Shop", "") .. ": " .. item.name .. " x" .. item.count
                        updateStockLabel(key, label, true)
                        stockCount += 1
                    end
                end
            end

            -- Restock predictions
            updateRestockPredictions()

            -- Status line
            local night = isNightTime()
            local seedRestock = getSeedRestockUnix()
            local gearRestock = getGearRestockUnix()

            local seedText = seedRestock and ("Seeds: " .. fmtTime(math.max(0, seedRestock - os.time()))) or "Seeds: --"
            local gearText = gearRestock and ("Gear: " .. fmtTime(math.max(0, gearRestock - os.time()))) or "Gear: --"
            local nightText = night and "🌙 Night" or "☀ Day"

            StatusLabel.Text = string.format("%s | %s | %s | Plot: %s",
                nightText, seedText, gearText,
                PL.auth and ("#" .. tostring(PL.plotId or "?")) or "none"
            )
        end)
    end
end))

-- ===========================================================================
-- PREDICTOR UI ELEMENTS
-- ===========================================================================
PredTab:createLabel({Name = "HUD Overlay", Special = true})
PredTab:createToggle({Name = "Show Predictor HUD", flagName = "ShowPred", Flag = false})

PredTab:createLabel({Name = "Weather Status", Special = true})
PredTab:createButton({Name = "Check Weather", Callback = function()
    local weather = readWeatherState()
    local lines = {}
    for _, wt in ipairs(WeatherTypes) do
        local w = weather[wt.id]
        if w then
            if w.playing then
                lines[#lines + 1] = wt.label .. ": ACTIVE (" .. fmtTime(w.remaining) .. " left)"
                if #w.mutations > 0 then
                    lines[#lines + 1] = "  → Mutations: " .. table.concat(w.mutations, ", ")
                end
            else
                lines[#lines + 1] = wt.label .. ": inactive"
            end
        end
    end
    Notify("Weather", table.concat(lines, "\n"), "info")
end})

PredTab:createLabel({Name = "Stock Predictions", Special = true})
PredTab:createButton({Name = "Show Seed Stock", Callback = function()
    local stockData = readStockData()
    local seeds = stockData["SeedShop"]
    if not seeds then Notify("Stock", "Seed shop data not found", "warning"); return end
    local lines = {}
    local restockUnix = getSeedRestockUnix()
    local restockSec = restockUnix and math.max(0, restockUnix - os.time()) or nil
    lines[#lines + 1] = "Restock: " .. (restockSec and fmtTime(restockSec) or "unknown") .. "\n"
    for _, item in ipairs(seeds) do
        local status = item.count > 0 and ("x" .. item.count) or "SOLD OUT"
        lines[#lines + 1] = item.name .. ": " .. status
    end
    Notify("Seed Stock", table.concat(lines, "\n"), "info")
end})

PredTab:createButton({Name = "Show Gear Stock", Callback = function()
    local stockData = readStockData()
    local gears = stockData["GearShop"]
    if not gears then Notify("Stock", "Gear shop data not found", "warning"); return end
    local lines = {}
    local restockUnix = getGearRestockUnix()
    local restockSec = restockUnix and math.max(0, restockUnix - os.time()) or nil
    lines[#lines + 1] = "Restock: " .. (restockSec and fmtTime(restockSec) or "unknown") .. "\n"
    for _, item in ipairs(gears) do
        local status = item.count > 0 and ("x" .. item.count) or "SOLD OUT"
        lines[#lines + 1] = item.name .. ": " .. status
    end
    Notify("Gear Stock", table.concat(lines, "\n"), "info")
end})

PredTab:createButton({Name = "Show Crate Stock", Callback = function()
    local stockData = readStockData()
    local crates = stockData["CrateShop"]
    if not crates then Notify("Stock", "Crate shop data not found", "warning"); return end
    local lines = {}
    for _, item in ipairs(crates) do
        local status = item.count > 0 and ("x" .. item.count) or "SOLD OUT"
        lines[#lines + 1] = item.name .. ": " .. status
    end
    Notify("Crate Stock", table.concat(lines, "\n"), "info")
end})

PredTab:createLabel({Name = "Night Steal Timer", Special = true})
PredTab:createButton({Name = "Check Night Status", Callback = function()
    local night = isNightTime()
    local weather = readWeatherState()
    local moonActive = false
    for _, id in ipairs({"Starfall", "Snowfall", "Rainbow"}) do
        if weather[id] and weather[id].playing then moonActive = true end
    end
    Notify("Night", string.format(
        "Night: %s\nMoon events active: %s\n\nBest steal mutations during night:\n  Starfall → Starstruck\n  Snowfall → Frozen\n  Rainbow → Rainbow",
        night and "YES" or "NO",
        moonActive and "YES" or "NO"
    ), night and "info" or "warning")
end})

PredTab:createLabel({Name = "Mutation Tracker", Special = true})
PredTab:createButton({Name = "Show Active Mutations", Callback = function()
    local weather = readWeatherState()
    local active = {}
    for _, wt in ipairs(WeatherTypes) do
        local w = weather[wt.id]
        if w and w.playing and #w.mutations > 0 then
            for _, mut in ipairs(w.mutations) do
                active[#active + 1] = mut .. " (from " .. wt.label .. ", " .. fmtTime(w.remaining) .. " left)"
            end
        end
    end
    if #active > 0 then
        Notify("Mutations", "Active weather mutations:\n" .. table.concat(active, "\n"), "info")
    else
        Notify("Mutations", "No weather mutations active right now.", "warning")
    end
end})

-- ===========================================================================
-- SEED SHOP IN-GAME OVERLAY (injected into PlayerGui when shop is open)
-- ===========================================================================
local SeedOverlayActive = false

Track(task.spawn(function()
    while _alive do
        task.wait(2)
        pcall(function()
            if not Library.Flags["ShowPred"] then
                if SeedOverlayActive then
                    local pg = client:FindFirstChild("PlayerGui")
                    local shop = pg and pg:FindFirstChild("SeedShop")
                    local frame = shop and shop:FindFirstChild("Frame")
                    local panel = frame and frame:FindFirstChild("VA_SeedPanel")
                    if panel then panel:Destroy() end
                    SeedOverlayActive = false
                end
                return
            end

            local pg = client:FindFirstChild("PlayerGui")
            local shop = pg and pg:FindFirstChild("SeedShop")
            local frame = shop and shop:FindFirstChild("Frame")
            if not frame then SeedOverlayActive = false; return end

            local panel = frame:FindFirstChild("VA_SeedPanel")
            if not panel then
                panel = Instance.new("Frame")
                panel.Name = "VA_SeedPanel"
                panel.Size = UDim2.new(0, 220, 0, 130)
                panel.Position = UDim2.new(1, -230, 1, -140)
                panel.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
                panel.BackgroundTransparency = 0.1
                panel.BorderSizePixel = 1
                panel.BorderColor3 = Color3.fromRGB(80, 180, 120)
                panel.Parent = frame
                Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 6)

                local title = Instance.new("TextLabel")
                title.Name = "Title"
                title.Size = UDim2.new(1, -10, 0, 18)
                title.Position = UDim2.new(0, 5, 0, 4)
                title.BackgroundTransparency = 1
                title.Font = Enum.Font.GothamBold
                title.TextSize = 11
                title.TextColor3 = Color3.fromRGB(160, 255, 180)
                title.TextXAlignment = Enum.TextXAlignment.Left
                title.Parent = panel

                local body = Instance.new("TextLabel")
                body.Name = "Body"
                body.Size = UDim2.new(1, -10, 1, -28)
                body.Position = UDim2.new(0, 5, 0, 24)
                body.BackgroundTransparency = 1
                body.Font = Enum.Font.GothamMedium
                body.TextSize = 9
                body.TextWrapped = true
                body.TextYAlignment = Enum.TextYAlignment.Top
                body.TextXAlignment = Enum.TextXAlignment.Left
                body.TextColor3 = Color3.fromRGB(220, 220, 230)
                body.Parent = panel
            end

            SeedOverlayActive = true

            local title = panel:FindFirstChild("Title")
            local body = panel:FindFirstChild("Body")
            local restockUnix = getSeedRestockUnix()
            local restockSec = restockUnix and math.max(0, restockUnix - os.time()) or nil

            if title then
                title.Text = "Versus Airlines | Restock: " .. (restockSec and fmtTime(restockSec) or "...")
            end

            if body then
                local stockData = readStockData()
                local seeds = stockData["SeedShop"]
                if seeds then
                    local lines = {}
                    local shown = 0
                    for _, item in ipairs(seeds) do
                        if shown >= 8 then break end
                        if item.count > 0 then
                            lines[#lines + 1] = "✅ " .. item.name .. " x" .. item.count
                            shown += 1
                        end
                    end
                    -- Show first few sold out
                    local soldOut = 0
                    for _, item in ipairs(seeds) do
                        if item.count == 0 then soldOut += 1 end
                    end
                    if soldOut > 0 then
                        lines[#lines + 1] = "\n+" .. soldOut .. " sold out"
                    end
                    body.Text = table.concat(lines, "\n")
                end
            end
        end)
    end
end))

-- ===========================================================================
-- PREDICTOR SEED TAB AUTO-BUY (buys seeds that just restocked)
-- ===========================================================================
PredTab:createLabel({Name = "Auto-Buy Restocked Seeds", Special = true})
PredTab:createDropdown({Name = "Target Seeds", flagName = "PredBuySeeds", multi = true, List = GD.seeds})

buildToggle(PredTab, {
    Name = "Auto Buy When Restocked", flagName = "PredBuy", tag = "PredBuy", delay = 2.0,
    step = function()
        local targets = toList(Library.Flags["PredBuySeeds"])
        if #targets == 0 then return end
        local stockData = readStockData()
        local seeds = stockData["SeedShop"]
        if not seeds then return end
        local stockMap = {}
        for _, item in ipairs(seeds) do stockMap[item.name] = item.count end
        for _, name in ipairs(targets) do
            if not Library.Flags["PredBuy"] then break end
            local count = stockMap[name] or 0
            if count > 0 then
                buySeed(name)
                task.wait(0.1)
            end
        end
    end
})
-- PLAYER TAB
-- ===========================================================================
PlayerTab:createLabel({Name = "Movement", Special = true})
PlayerTab:createSlider({Name = "Walk Speed", flagName = "WalkSpeed", value = 16, minValue = 16, maxValue = 200})

buildToggle(PlayerTab, {
    Name = "Override Walk Speed", flagName = "WSOn", tag = "WSOn", delay = 0.3,
    step = function()
        local hum = client.Character and client.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = Library.Flags["WalkSpeed"] or 16 end
    end
})

PlayerTab:createSlider({Name = "Jump Power", flagName = "JumpPower", value = 50, minValue = 50, maxValue = 300})

buildToggle(PlayerTab, {
    Name = "Override Jump Power", flagName = "JPOn", tag = "JPOn", delay = 0.3,
    step = function()
        local hum = client.Character and client.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.JumpPower = Library.Flags["JumpPower"] or 50 end
    end
})

PlayerTab:createToggle({Name = "Infinite Jump", flagName = "InfJump", Flag = false, Callback = function(enabled)
    Library:CleanupConnectionsByTag("InfJump")
    if enabled then
        local conn = UserInputService.JumpRequest:Connect(function()
            if Library.Flags["InfJump"] then
                local hum = client.Character and client.Character:FindFirstChildOfClass("Humanoid")
                if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
            end
        end)
        Library:TrackConnection(conn, "InfJump")
    end
end})

PlayerTab:createToggle({Name = "Noclip", flagName = "NoClip", Flag = false, Callback = function(enabled)
    Library:CleanupConnectionsByTag("NoClip")
    if enabled then
        local conn = RunService.Stepped:Connect(function()
            if not Library.Flags["NoClip"] or not client.Character then return end
            for _, part in ipairs(client.Character:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end)
        Library:TrackConnection(conn, "NoClip")
    end
end})

-- ===========================================================================
-- VISUALS TAB
-- ===========================================================================
VisualsTab:createLabel({Name = "World", Special = true})
VisualsTab:createSlider({Name = "Clock Time", flagName = "ClockTime", value = 21, minValue = 0, maxValue = 24})

buildToggle(VisualsTab, {
    Name = "Override Clock", flagName = "ClockOn", tag = "ClockOn", delay = 0.5,
    step = function()
        Lighting.ClockTime = Library.Flags["ClockTime"] or 21
    end
})

VisualsTab:createToggle({Name = "Fullbright", flagName = "Fullbright", Flag = false, Callback = function(enabled)
    if enabled then
        Lighting.Brightness = 2
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 100000
    end
end})

VisualsTab:createLabel({Name = "ESP", Special = true})
VisualsTab:createDropdown({Name = "Fruit", flagName = "PE_names", multi = true, List = GD.seeds})
VisualsTab:createDropdown({Name = "Rarity", flagName = "PE_rar", multi = true, List = RTS})
VisualsTab:createDropdown({Name = "Mutation", flagName = "PE_mut", multi = true, List = MTS})
VisualsTab:createSlider({Name = "Max Distance", flagName = "PE_range", value = 1200, minValue = 100, maxValue = 3000})

buildToggle(VisualsTab, {
    Name = "ESP Fruit", flagName = "PlantESP", tag = "PlantESP", delay = 0.6,
    step = function()
        local range = Library.Flags["PE_range"] or 1200
        local hrp = client.Character and client.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local candidates = getCandidates(350, toList(Library.Flags["PE_names"]), toList(Library.Flags["PE_mut"]), toList(Library.Flags["PE_rar"]), false)
        local live = {}
        for _, c in ipairs(candidates) do
            if c.model and c.distance <= range then
                live[c.model] = true
                local text = string.format("%s | %.0f | %.0fm", c.model.Name, c.score or 0, c.distance or 0)
                createESP(c.model, text, c.isOwned and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(255, 220, 80))
            end
        end
        for obj, holder in pairs(ESP_Cache) do
            if obj and obj:IsDescendantOf(Workspace) and not live[obj] and obj:FindFirstAncestor("Plants") then
                holder:Destroy(); ESP_Cache[obj] = nil
            end
        end
    end
})

VisualsTab:createButton({Name = "Clear ESP", Callback = function()
    cleanESP()
end})

-- ===========================================================================
-- MISC TAB
-- ===========================================================================
MiscTab:createLabel({Name = "Protection", Special = true})
MiscTab:createToggle({Name = "Humanized Mode", flagName = "LegitMode", Flag = true})

buildToggle(MiscTab, {
    Name = "Anti Fling", flagName = "AntiFling", tag = "AntiFling", delay = 0.1, Flag = true,
    step = function()
        local root = client.Character and client.Character:FindFirstChild("HumanoidRootPart")
        if root and (root.AssemblyLinearVelocity.Magnitude > 250 or root.AssemblyAngularVelocity.Magnitude > 50) then
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
    end
})

buildToggle(MiscTab, {
    Name = "Anti Ragdoll", flagName = "AntiRagdoll", tag = "AntiRagdoll", delay = 0.5, Flag = true,
    step = function()
        local hum = client.Character and client.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        end
    end
})

buildToggle(MiscTab, {
    Name = "Instant Prompt", flagName = "InstantPrompt", tag = "InstantPrompt", delay = 1.2,
    step = function()
        for _, prompt in ipairs(Workspace:GetDescendants()) do
            if prompt:IsA("ProximityPrompt") then prompt.HoldDuration = 0 end
        end
    end
})

buildToggle(MiscTab, {
    Name = "Bypass AFK Popup", flagName = "NoPause", tag = "NoPause", delay = 1.0,
    step = function()
        local pg = client:FindFirstChild("PlayerGui")
        if not pg then return end
        for _, gui in ipairs(pg:GetDescendants()) do
            if gui:IsA("GuiObject") then
                local n = gui.Name:lower()
                if n:find("pause") or n:find("gameplaypaused") or n:find("afk") then gui.Visible = false end
            end
        end
    end
})

buildToggle(MiscTab, {
    Name = "Noclip Plants", flagName = "NoclipPlants", tag = "NoclipPlants", delay = 2.0,
    step = function()
        authenticatePlot()
        if not PL.plantsFolder then return end
        for _, part in ipairs(PL.plantsFolder:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
})

MiscTab:createLabel({Name = "Codes", Special = true})
MiscTab:createInputBox({Name = "Code", flagName = "CodeInput", Flag = ""})
MiscTab:createButton({Name = "Redeem Code", Callback = function()
    local code = Library.Flags["CodeInput"]
    if code and code ~= "" then
        submitCode(code)
        Notify("Code", "Submitted: " .. code, "info")
    end
end})

-- ===========================================================================
-- AUTO-RECONNECT & LIFECYCLE
-- ===========================================================================
Track(Players.PlayerRemoving:Connect(function(leaving)
    if leaving == client then
        if _G.VA_Unload then pcall(_G.VA_Unload) end
    end
end))

Track(client.CharacterAdded:Connect(function(char)
    local hum = char:WaitForChild("Humanoid", 5)
    if hum then
        hum.Died:Connect(function()
            task.wait(2)
        end)
    end
end))

-- Periodic ESP cleanup
Track(task.spawn(function()
    while _alive do
        task.wait(120)
        pcall(function()
            local stale = 0
            for obj in pairs(ESP_Cache) do
                if not obj or not obj.Parent then stale += 1 end
            end
            if stale > 50 then cleanESP() end
        end)
    end
end))

-- Periodic plot re-auth
Track(RunService.Heartbeat:Connect(function()
    if os.clock() - PL.lastAuth > 30 then pcall(authenticatePlot) end
end))

-- Memory cleanup
Track(task.spawn(function()
    while _alive do
        task.wait(300)
        pcall(function()
            local espCount = 0
            for _ in pairs(ESP_Cache) do espCount += 1 end
            if espCount > 100 then cleanESP() end
            collectgarbage("collect")
        end)
    end
end))

-- ===========================================================================
-- INIT
-- ===========================================================================
task.spawn(function()
    task.wait(2)
    pcall(function()
        authenticatePlot()
        if PL.auth then
            print(string.format("[VA] Plot #%s authenticated. %d grid nodes.", tostring(PL.plotId), #PL.gridNodes))
        end
    end)
end)

Notify("Versus Airlines", "GAG 2 loaded\n" .. #GD.seeds .. " seeds | " .. #GD.gears .. " gears | " .. #GD.crates .. " crates", "info")

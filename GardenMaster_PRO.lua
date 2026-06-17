local request = (syn and syn.request) or (http and http.request) or http_request

-- Services
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")
local client = Players.LocalPlayer

-- Cleanup previous instance
if _G.GardenHQ_Cleanup then
    pcall(_G.GardenHQ_Cleanup)
    _G.GardenHQ_Cleanup = nil
end

-- Polyfills
if not table.find then
    table.find = function(tbl, value)
        for i = 1, #tbl do
            if tbl[i] == value then
                return i
            end
        end
        return nil
    end
end

if not table.clear then
    table.clear = function(tbl)
        for key in pairs(tbl) do
            tbl[key] = nil
        end
    end
end

-- Cleanup system
local cleanupObjects = {}
local cleanupConnections = {}

local function registerCleanup(value)
    if typeof(value) == "RBXScriptConnection" then
        table.insert(cleanupConnections, value)
    elseif typeof(value) == "Instance" then
        table.insert(cleanupObjects, value)
    end
end

_G.GardenHQ_Cleanup = function()
    for _, connection in ipairs(cleanupConnections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    for _, instance in ipairs(cleanupObjects) do
        pcall(function()
            if instance and instance.Parent then
                instance:Destroy()
            end
        end)
    end
    table.clear(cleanupConnections)
    table.clear(cleanupObjects)
end

print(string.rep("━", 64))
print("┃ GardenMaster HQ ┃ Premium Edition")
print("┃ Built from full decompiled game source")
print(string.rep("━", 64))

-- Load UI Library
local Library = loadstring(game:HttpGet("https://versusairlines.top/scripts/NewLibrary.lua"))()
if not Library then
    warn("[GardenHQ] Library failed to load.")
    return
end

local Setup = Library:Setup({
    Location = CoreGui,
    OpenCloseLocation = "Bottom Right"
})

-- Anti-idle
client.Idled:Connect(function()
    pcall(function()
        VirtualUser:Button2Down(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
        task.wait(0.5)
        VirtualUser:Button2Up(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
    end)
end)

-- Loop tracking
local loopTracker = {}

local function registerLoop(tag, connection)
    if not loopTracker[tag] then
        loopTracker[tag] = {}
    end
    table.insert(loopTracker[tag], connection)
    registerCleanup(connection)
end

local function destroyLoop(tag)
    if not loopTracker[tag] then
        return
    end
    for _, connection in ipairs(loopTracker[tag]) do
        if connection and typeof(connection) == "RBXScriptConnection" then
            pcall(function()
                connection:Disconnect()
            end)
        end
    end
    loopTracker[tag] = nil
end

-- Notification helper
local function notify(title, message, style)
    pcall(function()
        if Library.createDisplayMessage then
            Library:createDisplayMessage(title, message, { { text = "OK" } }, style or "info")
        elseif Library.Notify then
            Library:Notify(title, message, 5)
        end
    end)
end

-- Proximity prompt trigger
local function triggerPrompt(prompt)
    if not prompt then
        return
    end
    if prompt:IsA("ProximityPrompt") then
        pcall(function()
            fireproximityprompt(prompt)
        end)
    end
end

-- Teleport
local function teleportTo(position)
    local rootPart = client.Character and client.Character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        return
    end
    pcall(function()
        rootPart.CFrame = CFrame.new(position + Vector3.new(0, 3.8, 0))
    end)
end

-- Interval runner
local function createIntervalToggle(parent, config)
    local tag = config.tag or config.flagName
    local flagName = config.flagName
    local baseDelay = config.delay or 0.5
    local stepFn = config.Step

    parent:createToggle({
        Name = config.Name,
        flagName = flagName,
        Flag = config.Flag or false,
        Callback = function(enabled)
            destroyLoop(tag)

            if not Library.Flags[flagName] then
                return
            end

            local lastExecution = 0
            local isRunning = false
            local humanizedMode = Library.Flags["LegitMode"] or false

            local connection = RunService.Heartbeat:Connect(function()
                if not Library.Flags[flagName] then
                    destroyLoop(tag)
                    return
                end

                local effectiveDelay = humanizedMode
                    and (baseDelay * (0.6 + math.random() * 0.8) + math.random(0.05, 0.25))
                    or baseDelay

                if isRunning or (os.clock() - lastExecution < effectiveDelay) then
                    return
                end

                lastExecution = os.clock()
                isRunning = true

                task.spawn(function()
                    local ok, err = pcall(stepFn)
                    if not ok then
                        warn(string.format("[GardenHQ:%s] %s", tostring(tag), tostring(err)))
                    end
                    isRunning = false
                end)
            end)

            registerLoop(tag, connection)
        end
    })
end

-- Networking module
local Net = nil
pcall(function()
    local sharedModules = ReplicatedStorage:WaitForChild("SharedModules", 5)
    local networkingModule = sharedModules:WaitForChild("Networking", 5)
    Net = require(networkingModule)
end)

if not Net then
    warn("[GardenHQ] CRITICAL: Could not load Networking module.")
    warn("[GardenHQ] Path: ReplicatedStorage.SharedModules.Networking")
    return
end

print("[GardenHQ] Networking module loaded.")

-- Game Data Discovery
local GameData = {
    seeds = {},
    gears = {},
    crates = {},
    pets = {},
    allItems = {}
}

local MutationList = {
    "Gold", "Rainbow", "Electric", "Solarflare", "Frozen",
    "Bloodlit", "Chained", "Pizza", "Starstruck", "Ghost", "Poison"
}

local RarityList = {
    "Common", "Uncommon", "Rare", "Super", "Epic", "Legendary", "Mythic"
}

pcall(function()
    local seedMap = {}
    local gearMap = {}
    local crateMap = {}
    local petMap = {}

    -- Scan ReplicatedStorage for item data
    for _, descendant in ipairs(ReplicatedStorage:GetDescendants()) do
        local parentName = (descendant.Parent and descendant.Parent.Name or ""):lower()
        local itemName = descendant.Name

        if (descendant:IsA("ImageLabel") or descendant:IsA("Texture") or descendant:IsA("Decal"))
            and (parentName:find("seed") or parentName:find("fruit")
                or parentName:find("plant") or itemName:find("Seed")) then
            local match = itemName:gsub("Seed:", ""):gsub("Seed_", ""):match("^([^%[]+)")
            if match then
                seedMap[match:gsub("%s+$", "")] = true
            end
        elseif descendant:IsA("NumberValue") or descendant:IsA("StringValue") then
            if parentName:find("gear") or parentName:find("watering") or parentName:find("shovel") then
                gearMap[itemName] = true
            end
            if parentName:find("crate") or parentName:find("box")
                or parentName:find("egg") or parentName:find("pet") then
                crateMap[itemName] = true
                petMap[itemName] = true
            end
        end
    end

    -- Scan backpack
    local backpack = client:FindFirstChild("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                local toolName = tool.Name:lower()
                if toolName:find("seed") or toolName:find("fruit") or toolName:find("plant") then
                    local match = tool.Name:gsub("Seed:", ""):gsub("Seed_", ""):match("^([^%[]+)")
                    if match then
                        seedMap[match:gsub("%s+$", "")] = true
                    end
                elseif toolName:find("gear") or toolName:find("watering")
                    or toolName:find("shovel") or toolName:find("trowel") then
                    gearMap[tool.Name] = true
                elseif toolName:find("crate") or toolName:find("box")
                    or toolName:find("egg") or toolName:find("pet") then
                    crateMap[tool.Name] = true
                    petMap[tool.Name] = true
                end
            end
        end
    end

    -- Scan StockValues
    local stockFolder = ReplicatedStorage:FindFirstChild("StockValues", true)
    if stockFolder then
        for _, shopName in ipairs({ "SeedShop", "GearShop", "CrateShop", "PetShop" }) do
            local shop = stockFolder:FindFirstChild(shopName)
            if shop and shop:FindFirstChild("Items") then
                for _, item in ipairs(shop.Items:GetChildren()) do
                    if item:IsA("NumberValue") then
                        if shopName == "SeedShop" then
                            seedMap[item.Name] = true
                        elseif shopName == "GearShop" then
                            gearMap[item.Name] = true
                        elseif shopName == "CrateShop" then
                            crateMap[item.Name] = true
                        elseif shopName == "PetShop" then
                            petMap[item.Name] = true
                        end
                    end
                end
            end
        end
    end

    for key in pairs(seedMap) do
        table.insert(GameData.seeds, key)
    end
    for key in pairs(gearMap) do
        table.insert(GameData.gears, key)
    end
    for key in pairs(crateMap) do
        table.insert(GameData.crates, key)
    end
    for key in pairs(petMap) do
        table.insert(GameData.pets, key)
    end

    table.sort(GameData.seeds)
    table.sort(GameData.gears)
    table.sort(GameData.crates)
    table.sort(GameData.pets)

    GameData.allItems = {}
    for _, category in ipairs({ GameData.seeds, GameData.gears, GameData.crates, GameData.pets }) do
        for _, value in ipairs(category) do
            table.insert(GameData.allItems, value)
        end
    end

    print(string.format("[GardenHQ] Discovered: %d seeds, %d gears, %d crates, %d pets",
        #GameData.seeds, #GameData.gears, #GameData.crates, #GameData.pets))
end)

-- ============================================================
-- Plot Authentication & Spatial Grid System
-- ============================================================

local GardenPlot = {
    model = nil,
    plotId = nil,
    entranceGate = CFrame.new(),
    centerPosition = Vector3.new(),
    gridNodes = {},
    plantsFolder = nil,
    sprinklersFolder = nil,
    propsFolder = nil,
    rakesFolder = nil,
    spawnPoint = nil,
    plantAreas = {},
    isAuthenticated = false,
    lastAuthentication = 0,
    occupiedCells = {}
}

local function getPlotOwnerUserId(plot)
    local ownerUserId = plot:GetAttribute("OwnerUserId")
    if ownerUserId then
        return tonumber(ownerUserId)
    end
    local ownerAttribute = plot:GetAttribute("Owner")
    if ownerAttribute and typeof(ownerAttribute) == "Instance" and ownerAttribute:IsA("Player") then
        return ownerAttribute.UserId
    end
    if plot:GetAttribute("Owner") == client.Name then
        return client.UserId
    end
    return nil
end

local function authenticateGardenPlot()
    if os.clock() - GardenPlot.lastAuthentication < 0.8 and GardenPlot.isAuthenticated then
        return GardenPlot
    end

    GardenPlot.lastAuthentication = os.clock()

    local gardensFolder = Workspace:FindFirstChild("Gardens") or Workspace
    local targetPlot = nil
    local plotId = client:GetAttribute("PlotId")

    if plotId then
        targetPlot = gardensFolder:FindFirstChild("Plot" .. tostring(plotId))
    end

    if not targetPlot then
        for _, candidate in ipairs(gardensFolder:GetChildren()) do
            if not (candidate:IsA("Model") or candidate:IsA("Folder")) then
                continue
            end

            local ownerId = getPlotOwnerUserId(candidate)
            if ownerId == client.UserId then
                targetPlot = candidate
                plotId = candidate:GetAttribute("PlotId") or plotId
                break
            end

            if candidate:GetAttribute("IsLocal") == true then
                targetPlot = candidate
                plotId = candidate:GetAttribute("PlotId") or plotId
                break
            end

            if plotId and candidate.Name == "Plot" .. tostring(plotId) then
                targetPlot = candidate
                break
            end
        end
    end

    if not targetPlot then
        GardenPlot.isAuthenticated = false
        local rootPart = client.Character and client.Character:FindFirstChild("HumanoidRootPart")
        if rootPart then
            GardenPlot.centerPosition = rootPart.Position
        end
        return GardenPlot
    end

    if GardenPlot.model == targetPlot and #GardenPlot.gridNodes > 0 then
        GardenPlot.isAuthenticated = true
        return GardenPlot
    end

    GardenPlot.model = targetPlot
    GardenPlot.plotId = plotId
    GardenPlot.isAuthenticated = true
    table.clear(GardenPlot.plantAreas)
    table.clear(GardenPlot.occupiedCells)

    local spawnPoint = targetPlot:FindFirstChild("SpawnPoint")
    if spawnPoint and spawnPoint:IsA("BasePart") then
        GardenPlot.spawnPoint = spawnPoint
        GardenPlot.centerPosition = spawnPoint.Position
        GardenPlot.entranceGate = CFrame.new(
            spawnPoint.Position + Vector3.new(0, 3.5, 3),
            spawnPoint.Position
        )
    else
        local primaryPart = (targetPlot:IsA("Model") and targetPlot.PrimaryPart)
            or targetPlot:FindFirstChild("BottomFace", true)
        if primaryPart and primaryPart:IsA("BasePart") then
            GardenPlot.centerPosition = primaryPart.Position
            GardenPlot.entranceGate = CFrame.new(
                primaryPart.Position + Vector3.new(0, 5, 15),
                primaryPart.Position
            )
        end
    end

    GardenPlot.plantsFolder = targetPlot:FindFirstChild("Plants")
    GardenPlot.sprinklersFolder = targetPlot:FindFirstChild("Sprinklers")
    GardenPlot.propsFolder = targetPlot:FindFirstChild("Props")
    GardenPlot.rakesFolder = targetPlot:FindFirstChild("Rakes")

    -- Find plantable areas
    for _, child in ipairs(targetPlot:GetDescendants()) do
        if child:IsA("BasePart") then
            local childName = child.Name:lower()
            if childName:find("plantarea") or childName:find("platarea")
                or childName:find("soil") or childName:find("plot")
                or childName:find("dirt")
                or CollectionService:HasTag(child, "PlantArea")
                or CollectionService:HasTag(child, "Soil") then
                table.insert(GardenPlot.plantAreas, child)
            end
        end
    end

    if #GardenPlot.plantAreas == 0 then
        local bottomFace = targetPlot:FindFirstChild("BottomFace", true)
            or (targetPlot:IsA("Model") and targetPlot.PrimaryPart)
        if bottomFace and bottomFace:IsA("BasePart") then
            table.insert(GardenPlot.plantAreas, bottomFace)
        end
    end

    -- Build spatial grid via raytracing
    table.clear(GardenPlot.gridNodes)

    for _, area in ipairs(GardenPlot.plantAreas) do
        local areaPosition = area.Position
        local sizeX = math.max(area.Size.X, 1) * 0.92
        local sizeZ = math.max(area.Size.Z, 1) * 0.92
        local step = 2.6

        for x = -sizeX, sizeX, step do
            for z = -sizeZ, sizeZ, step do
                local originX = areaPosition.X + x + math.random(-0.4, 0.4)
                local originZ = areaPosition.Z + z + math.random(-0.4, 0.4)
                local rayOrigin = Vector3.new(originX, areaPosition.Y + 30, originZ)
                local rayResult = Workspace:Raycast(rayOrigin, Vector3.new(0, -60, 0))
                local hitPosition = rayResult and rayResult.Position
                    or Vector3.new(originX, areaPosition.Y + (area.Size.Y / 2) + 0.15, originZ)
                table.insert(GardenPlot.gridNodes, hitPosition)
            end
        end
    end

    -- Shuffle grid for randomness
    for i = #GardenPlot.gridNodes, 2, -1 do
        local j = math.random(i)
        GardenPlot.gridNodes[i], GardenPlot.gridNodes[j] = GardenPlot.gridNodes[j], GardenPlot.gridNodes[i]
    end

    return GardenPlot
end

local function getOccupiedPositions()
    local occupied = {}
    local hash = GardenPlot.occupiedCells or {}

    if GardenPlot.plantsFolder then
        for _, plant in ipairs(GardenPlot.plantsFolder:GetChildren()) do
            if plant:IsA("Model") and plant.PrimaryPart then
                local position = plant:GetPivot().Position
                table.insert(occupied, position)
                hash[tostring(math.floor(position.X / 2)) .. "," .. tostring(math.floor(position.Z / 2))] = true
            end
        end
    end

    if GardenPlot.sprinklersFolder then
        for _, sprinkler in ipairs(GardenPlot.sprinklersFolder:GetChildren()) do
            if sprinkler:IsA("Model") and sprinkler.PrimaryPart then
                local position = sprinkler:GetPivot().Position
                table.insert(occupied, position)
            end
        end
    end

    GardenPlot.occupiedCells = hash
    return occupied
end

local function getPlacementPosition(spacing)
    authenticateGardenPlot()
    spacing = spacing or 2.9

    local placementMode = Library.Flags["PlacingMode"] or "Virtual Plot Grid"
    local rootPart = client.Character and client.Character:FindFirstChild("HumanoidRootPart")

    if placementMode == "Character Position" then
        if rootPart then
            local rayResult = Workspace:Raycast(
                rootPart.Position + Vector3.new(0, 6, 0),
                Vector3.new(0, -30, 0)
            )
            return rayResult and rayResult.Position or rootPart.Position - Vector3.new(0, 2.8, 0)
        end
        return Vector3.zero
    end

    if placementMode == "Random Spatial Plot" then
        if GardenPlot.isAuthenticated and GardenPlot.centerPosition then
            local halfExtent = 18.0
            local randomX = GardenPlot.centerPosition.X + (math.random() * 2 - 1) * halfExtent
            local randomZ = GardenPlot.centerPosition.Z + (math.random() * 2 - 1) * halfExtent
            local rayResult = Workspace:Raycast(
                Vector3.new(randomX, GardenPlot.centerPosition.Y + 28, randomZ),
                Vector3.new(0, -55, 0)
            )
            return rayResult and rayResult.Position or Vector3.new(randomX, GardenPlot.centerPosition.Y, randomZ)
        end
    end

    if placementMode == "Mouse Position" then
        local mousePosition
        pcall(function()
            local mouse = client:GetMouse()
            if mouse and mouse.Hit then
                mousePosition = mouse.Hit.Position
            end
        end)
        if mousePosition then
            return mousePosition
        end
    end

    if not GardenPlot.isAuthenticated or #GardenPlot.gridNodes == 0 then
        return rootPart and rootPart.Position or Vector3.zero
    end

    local occupied = getOccupiedPositions()

    for _, gridNode in ipairs(GardenPlot.gridNodes) do
        local cellKey = tostring(math.floor(gridNode.X / 2)) .. "," .. tostring(math.floor(gridNode.Z / 2))
        if GardenPlot.occupiedCells[cellKey] then
            continue
        end

        local isFree = true
        for _, occupiedPos in ipairs(occupied) do
            if (Vector3.new(occupiedPos.X, gridNode.Y, occupiedPos.Z) - gridNode).Magnitude < spacing then
                isFree = false
                break
            end
        end

        if isFree then
            GardenPlot.occupiedCells[cellKey] = true
            return gridNode
        end
    end

    return GardenPlot.centerPosition
end

local function enforceGeofence(operationType)
    authenticateGardenPlot()
    local rootPart = client.Character and client.Character:FindFirstChild("HumanoidRootPart")
    if not rootPart or not GardenPlot.isAuthenticated or not GardenPlot.entranceGate then
        return
    end

    local geofenceRadius = Library.Flags["GeofenceRadius"] or 22.0
    local flagName = (operationType == "Collect") and "TPToEntranceCollect" or "TPToEntrancePlant"

    if not Library.Flags[flagName] then
        return
    end

    if (rootPart.Position - GardenPlot.entranceGate.Position).Magnitude > geofenceRadius then
        pcall(function()
            rootPart.CFrame = GardenPlot.entranceGate
        end)
    end
end

-- ============================================================
-- Tool Handling System
-- ============================================================

local function findToolByName(searchName)
    if not searchName or typeof(searchName) ~= "string" or searchName == "" then
        return nil
    end

    local cleanSearch = searchName:lower()
        :gsub("seed[:_ ]", "")
        :gsub("%s+", "")
        :gsub("%[.*%]", "")
        :gsub("tool", "")
        :gsub("x%d+", "")
        :gsub("^%s*(.-)%s*$", "%1")

    local function toolMatches(tool)
        if not tool or not tool:IsA("Tool") then
            return false
        end
        local cleanToolName = tool.Name:lower()
            :gsub("seed[:_ ]", "")
            :gsub("%s+", "")
            :gsub("%[.*%]", "")
            :gsub("tool", "")
            :gsub("x%d+", "")
            :gsub("^%s*(.-)%s*$", "%1")
        return cleanToolName == cleanSearch
            or cleanToolName:find(cleanSearch, 1, true)
            or cleanSearch:find(cleanToolName, 1, true)
            or (cleanToolName:find("seed") and cleanToolName:gsub("seed", "") == cleanSearch)
    end

    -- Check backpack first
    local backpack = client:FindFirstChild("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if toolMatches(tool) then
                return tool
            end
        end
    end

    -- Check character
    if client.Character then
        for _, tool in ipairs(client.Character:GetChildren()) do
            if toolMatches(tool) then
                return tool
            end
        end
    end

    -- Broader fallback search
    local allTools = {}
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                table.insert(allTools, tool)
            end
        end
    end
    if client.Character then
        for _, tool in ipairs(client.Character:GetChildren()) do
            if tool:IsA("Tool") then
                table.insert(allTools, tool)
            end
        end
    end

    for _, tool in ipairs(allTools) do
        if tool.Name:lower():find(cleanSearch, 1, true)
            or cleanSearch:find(tool.Name:lower():gsub("seed[:_ ]", ""), 1, true) then
            return tool
        end
    end

    return nil
end

local function equipTool(tool)
    if not tool or not tool.Parent then
        return false
    end

    if tool.Parent == client:FindFirstChild("Backpack") then
        local humanoid = client.Character and client.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            pcall(function()
                humanoid:EquipTool(tool)
            end)
            task.wait(0.06)
            if client.Character and client.Character:FindFirstChild(tool.Name) then
                return true
            end
        end
    end

    return tool.Parent == client.Character
end

-- ============================================================
-- Action Executors — Every remote verified from decompiled source
-- ============================================================

local function harvestPlant(plantId, fruitId)
    if not plantId then return end
    fruitId = fruitId or ""
    Net.Garden.CollectFruit:Fire(plantId, fruitId)
end

local function plantSeed(seedName, targetPosition)
    if not seedName or not targetPosition then return false end
    local tool = findToolByName(seedName)
    if tool then
        equipTool(tool)
        task.wait(0.08)
    end
    Net.Plant.PlantSeed:Fire(targetPosition, seedName, tool)
    return true
end

local function placeSprinkler(sprinklerName, targetPosition)
    local tool = findToolByName(sprinklerName)
    if not tool or not targetPosition then return false end
    equipTool(tool)
    task.wait(0.08)
    Net.Place.PlaceSprinkler:Fire(targetPosition, sprinklerName, tool, 1)
    return true
end

local function waterPlant(targetPosition)
    local tool = findToolByName("watering") or findToolByName("Watering")
    if tool then
        equipTool(tool)
        task.wait(0.06)
    end
    local wateringCanName = tool and tool:GetAttribute("WateringCan") or (tool and tool.Name or "")
    local adjustedPosition = targetPosition - Vector3.new(0, 0.3, 0)
    Net.WateringCan.UseWateringCan:Fire(adjustedPosition, wateringCanName, tool)
end

local function shovelPlant(plantId, fruitId, shovelTool)
    local tool = shovelTool or findToolByName("shovel") or findToolByName("Shovel")
    if not tool then return end
    equipTool(tool)
    task.wait(0.06)
    local shovelAttribute = tool:GetAttribute("Shovel") or ""
    Net.Shovel.UseShovel:Fire(plantId, fruitId or "", shovelAttribute, tool)
end

local function movePlant(plantId, targetPosition, rotation)
    if not plantId or not targetPosition then return end
    rotation = rotation or 0
    Net.Trowel.MovePlant:Fire(plantId, targetPosition, rotation)
end

-- NPC / Selling
local function sellAllItems()
    Net.NPCS.SellAll:Fire()
end

local function sellFruit(fruitId)
    if not fruitId then return end
    Net.NPCS.SellFruit:Fire(fruitId)
end

-- Seed Shop
local function buySeed(name)
    if not name or name == "" then return end
    Net.SeedShop.PurchaseSeed:Fire(name)
end

-- Gear Shop
local function buyGear(name)
    if not name or name == "" then return end
    Net.GearShop.PurchaseGear:Fire(name)
end

local function equipGear(name)
    if not name or name == "" then return end
    Net.GearShop.EquipGear:Fire(name)
end

local function unequipGear()
    Net.GearShop.UnequipGear:Fire()
end

-- Crate Shop
local function buyCrate(name)
    if not name or name == "" then return end
    Net.CrateShop.PurchaseCrate:Fire(name)
end

-- Crate / Egg / SeedPack Opening
local function openCrate(name)
    if not name or name == "" then return end
    Net.Crate.OpenCrate:Fire(name)
end

local function openSeedPack(name)
    if not name or name == "" then return end
    Net.SeedPack.OpenSeedPack:Fire(name)
end

local function openEgg(name)
    if not name or name == "" then return end
    Net.Egg.OpenEgg:Fire(name)
end

-- Steal System
local function beginSteal(targetUserId, plantId, fruitId)
    Net.Steal.BeginSteal:Fire(targetUserId, plantId, fruitId or "")
end

local function completeSteal()
    Net.Steal.CompleteSteal:Fire()
end

-- Codes
local function redeemCode(code)
    Net.Settings.SubmitCode:Fire(code)
end

-- Pets
local function equipPet(name)
    if not name or name == "" then return end
    Net.Pets.PetEquipped:Fire(name, {})
end

local function unequipPet(name)
    if not name or name == "" then return end
    Net.Pets.RequestUnequipByName:Fire(name)
end

-- Daily Deals
local function checkDailyDeal()
    Net.NPCS.CheckDailyDeal:Fire()
end

-- Night Detection
local nightDetector = ReplicatedStorage:FindFirstChild("Night", true)

local function isNightTime()
    if nightDetector and nightDetector:IsA("BoolValue") and nightDetector.Value then
        return true
    end
    local clockTime = Lighting.ClockTime
    return clockTime < 6 or clockTime > 18
end

-- Watering can fill
local function refillWateringCan()
    Net.WateringCan.UseWateringCan:Fire(Vector3.zero, "", nil)
end

-- ============================================================
-- Value Scoring & Filtering Engine
-- ============================================================

local function passesFilter(model, fruitFilter, mutationFilter, rarityFilter)
    if not model then
        return false
    end

    local modelName = model.Name:lower()
    local seedAttribute = (model:GetAttribute("SeedName") or ""):lower()
    local mutationAttribute = (model:GetAttribute("Mutation") or ""):lower()
    local rarityAttribute = (model:GetAttribute("Rarity") or ""):lower()

    -- Check fruit filter
    if fruitFilter and #fruitFilter > 0 then
        local matched = false
        for _, fruit in ipairs(fruitFilter) do
            local fruitLower = fruit:lower()
            if modelName:find(fruitLower, 1, true) or seedAttribute:find(fruitLower, 1, true) then
                matched = true
                break
            end
        end
        if not matched then
            return false
        end
    end

    -- Check mutation filter
    if mutationFilter and #mutationFilter > 0 then
        local matched = false
        for _, mutation in ipairs(mutationFilter) do
            if mutationAttribute == mutation:lower() then
                matched = true
                break
            end
        end
        if not matched then
            return false
        end
    end

    -- Check rarity filter
    if rarityFilter and #rarityFilter > 0 then
        local matched = false
        for _, rarity in ipairs(rarityFilter) do
            if rarityAttribute == rarity:lower() then
                matched = true
                break
            end
        end
        if not matched then
            return false
        end
    end

    return true
end

local MutationValueMultiplier = {
    gold = 15,
    rainbow = 42,
    electric = 11,
    solarflare = 13,
    frozen = 9,
    bloodlit = 11,
    chained = 7,
    pizza = 6,
    starstruck = 22,
    ghost = 18,
    poison = 14
}

local RarityValueScore = {
    common = 1,
    uncommon = 2,
    rare = 3,
    super = 4,
    epic = 5,
    legendary = 6,
    mythic = 7
}

local function calculatePlantValue(model)
    if not model then
        return 0
    end

    local score = 0

    -- Rarity bonus
    local rarity = (model:GetAttribute("Rarity") or ""):lower()
    score = score + (RarityValueScore[rarity] or 1) * 120

    -- Mutation multiplier
    local mutation = (model:GetAttribute("Mutation") or ""):lower()
    score = score * (MutationValueMultiplier[mutation] or 1)

    -- Size bonus
    local size = model:GetAttribute("Size") or model:GetAttribute("FruitSize") or 1
    if type(size) == "number" then
        score = score * math.max(size, 0.15)
    end

    -- Sell value
    local sellValue = model:GetAttribute("Value") or model:GetAttribute("SellValue") or 0
    if type(sellValue) == "number" then
        score = score + sellValue * 1.2
    end

    -- Multi-harvest bonus
    if model:GetAttribute("MultiHarvest")
        or model.Name:lower():find("multi")
        or model.Name:lower():find("regrow") then
        score = score * 1.6
    end

    -- Age bonus
    local age = model:GetAttribute("Age") or model:GetAttribute("Growth") or 1
    if type(age) == "number" and age > 1 then
        score = score * (1 + math.min(age / 10, 0.8))
    end

    return score
end

local function getPlantIdentifiers(model)
    if not model then
        return nil, nil
    end
    return model:GetAttribute("PlantId"), model:GetAttribute("FruitId")
end

local function getBestValueCandidates(maxCount, fruitFilter, mutationFilter, rarityFilter, ownedOnly, blacklist)
    maxCount = maxCount or 12
    local candidates = {}
    local rootPart = client.Character and client.Character:FindFirstChild("HumanoidRootPart")
    local gardens = Workspace:FindFirstChild("Gardens") or Workspace

    local function addCandidate(model, isOwned)
        if not model or not model:IsA("Model") then
            return
        end
        if not passesFilter(model, fruitFilter, mutationFilter, rarityFilter) then
            return
        end
        if ownedOnly and not isOwned then
            return
        end
        if blacklist and #blacklist > 0 then
            for _, blacklisted in ipairs(blacklist) do
                if model.Name:lower():find(blacklisted:lower(), 1, true) then
                    return
                end
            end
        end

        local plantId, fruitId = getPlantIdentifiers(model)
        local valueScore = calculatePlantValue(model)
        local distance = rootPart and (model:GetPivot().Position - rootPart.Position).Magnitude or 0

        table.insert(candidates, {
            model = model,
            plantId = plantId,
            fruitId = fruitId,
            score = valueScore,
            distance = distance,
            isOwned = isOwned
        })
    end

    -- Scan harvest prompts
    for _, harvestPrompt in ipairs(CollectionService:GetTagged("HarvestPrompt")) do
        local model = harvestPrompt:FindFirstAncestorWhichIsA("Model")
        addCandidate(model, true)
    end

    -- Scan all gardens
    for _, plot in ipairs(gardens:GetChildren()) do
        if not (plot:IsA("Model") or plot:IsA("Folder")) then
            continue
        end

        local isOurPlot = (getPlotOwnerUserId(plot) == client.UserId)
        local plantsFolder = plot:FindFirstChild("Plants")

        if plantsFolder then
            for _, plantModel in ipairs(plantsFolder:GetChildren()) do
                if plantModel:IsA("Model") then
                    addCandidate(plantModel, isOurPlot)
                end
            end
        end
    end

    -- Sort by score then distance
    table.sort(candidates, function(a, b)
        if a.score ~= b.score then
            return a.score > b.score
        end
        return a.distance < b.distance
    end)

    -- Trim to max count
    local result = {}
    for i = 1, math.min(maxCount, #candidates) do
        table.insert(result, candidates[i])
    end

    return result
end

-- Get all candidates sorted by age (oldest first)
local function getOldestCandidates(maxCount, fruitFilter, mutationFilter, rarityFilter, ownedOnly)
    local candidates = getBestValueCandidates(999, fruitFilter, mutationFilter, rarityFilter, ownedOnly, nil)
    table.sort(candidates, function(a, b)
        local ageA = a.model and a.model:GetAttribute("Age") or 0
        local ageB = b.model and b.model:GetAttribute("Age") or 0
        return ageA > ageB
    end)
    local result = {}
    for i = 1, math.min(maxCount, #candidates) do
        table.insert(result, candidates[i])
    end
    return result
end

-- Get all candidates sorted by distance (closest first)
local function getClosestCandidates(maxCount, fruitFilter, mutationFilter, rarityFilter, ownedOnly)
    local candidates = getBestValueCandidates(999, fruitFilter, mutationFilter, rarityFilter, ownedOnly, nil)
    table.sort(candidates, function(a, b)
        return a.distance < b.distance
    end)
    local result = {}
    for i = 1, math.min(maxCount, #candidates) do
        table.insert(result, candidates[i])
    end
    return result
end

-- ============================================================
-- Random Utility Functions
-- ============================================================

local function getFirstDropdownValue(flagName)
    local value = Library.Flags[flagName]
    if not value then
        return nil
    end
    if typeof(value) == "table" then
        return value[1]
    end
    return value
end

local function getBackpackSeedNames()
    local seeds = {}
    local backpack = client:FindFirstChild("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                if tool.Name:find("Seed:") or tool.Name:find("Seed_") or table.find(GameData.seeds, tool.Name) then
                    local cleanName = tool.Name:gsub("Seed:", ""):gsub("Seed_", ""):match("^([^%[]+)")
                    if cleanName and cleanName ~= "" and not table.find(seeds, cleanName) then
                        table.insert(seeds, cleanName)
                    end
                end
            end
        end
    end
    return seeds
end

local function getBackpackSprinklerNames()
    local sprinklers = {}
    local backpack = client:FindFirstChild("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") and tool.Name:lower():find("sprinkler") then
                if not table.find(sprinklers, tool.Name) then
                    table.insert(sprinklers, tool.Name)
                end
            end
        end
    end
    return sprinklers
end

-- ============================================================
-- UI TABS - Matching Unknown Hub Structure
-- ============================================================

local GardenTab = Setup:CreateSection("🌱 Garden")
GardenTab:createLabel({
    Name = "Paid Contributor: aditya44325f",
    Special = true
})

-- ============================================================
-- GARDEN TAB: Planting & Harvest
-- ============================================================

GardenTab:createLabel({ Name = "Planting & Harvest", Special = true })

GardenTab:createDropdown({
    Name = "Auto Plant Seeds",
    flagName = "PS_type",
    List = { "None", "All", "Selected" }
})

GardenTab:createDropdown({
    Name = "Select Seeds",
    flagName = "PS_list",
    multi = true,
    List = GameData.seeds
})

GardenTab:createDropdown({
    Name = "Plant Priority",
    flagName = "PP",
    List = { "Manual Order", "Highest Value" }
})

createIntervalToggle(GardenTab, {
    Name = "Auto Plant",
    flagName = "AP",
    tag = "HQ_AutoPlant",
    delay = 0.42,
    Step = function()
        authenticateGardenPlot()
        local selectionType = Library.Flags["PS_type"]
        if selectionType == "None" then
            return
        end

        enforceGeofence("Plant")

        if selectionType == "All" then
            local seedNames = getBackpackSeedNames()
            if Library.Flags["PP"] == "Highest Value" then
                local scored = {}
                for _, name in ipairs(seedNames) do
                    local tool = findToolByName(name)
                    scored[name] = tool and (tool:GetAttribute("Value") or 1) or 1
                end
                table.sort(seedNames, function(a, b)
                    return (scored[a] or 0) > (scored[b] or 0)
                end)
            end
            for _, seedName in ipairs(seedNames) do
                if not Library.Flags["AP"] then break end
                local position = getPlacementPosition(2.9)
                if position then
                    plantSeed(seedName, position)
                    task.wait(0.06)
                end
            end
        elseif selectionType == "Selected" then
            local selectedList = Library.Flags["PS_list"]
            if not selectedList then return end
            local seedList = typeof(selectedList) == "table" and selectedList or { selectedList }
            if Library.Flags["PP"] == "Highest Value" then
                local scored = {}
                for _, name in ipairs(seedList) do
                    local tool = findToolByName(name)
                    scored[name] = tool and (tool:GetAttribute("Value") or 1) or 1
                end
                table.sort(seedList, function(a, b)
                    return (scored[a] or 0) > (scored[b] or 0)
                end)
            end
            for _, seedName in ipairs(seedList) do
                if not Library.Flags["AP"] then break end
                if seedName == "" then continue end
                local position = getPlacementPosition(2.9)
                if position then
                    plantSeed(seedName, position)
                    task.wait(0.06)
                end
            end
        end
    end
})

GardenTab:createDropdown({
    Name = "Auto Harvest",
    flagName = "AH_type",
    List = { "None", "All", "Selected", "Blacklist" }
})

GardenTab:createDropdown({
    Name = "Harvest Fruits",
    flagName = "AH_list",
    multi = true,
    List = GameData.seeds
})

GardenTab:createDropdown({
    Name = "Harvest Blacklist",
    flagName = "AH_blist",
    multi = true,
    List = GameData.seeds
})

GardenTab:createDropdown({
    Name = "Harvest Priority",
    flagName = "HP",
    List = { "Highest Value", "Closest", "Oldest" }
})

GardenTab:createToggle({
    Name = "Stop When Full",
    flagName = "AH_fullstop",
    Flag = false
})

GardenTab:createSlider({
    Name = "Max Harvest Count",
    flagName = "AH_max",
    value = 30,
    minValue = 1,
    maxValue = 200
})

createIntervalToggle(GardenTab, {
    Name = "Auto Harvest",
    flagName = "AH",
    tag = "HQ_AutoHarvest",
    delay = 0.05,
    Step = function()
        local selectionType = Library.Flags["AH_type"]
        if selectionType == "None" then return end

        authenticateGardenPlot()
        enforceGeofence("Collect")

        if Library.Flags["AH_fullstop"] and client:GetAttribute("BackpackFull") == true then
            return
        end

        local maxCount = Library.Flags["AH_max"] or 30
        local fruitFilter = nil
        local blacklist = nil

        if selectionType == "Selected" then
            fruitFilter = Library.Flags["AH_list"]
        elseif selectionType == "Blacklist" then
            blacklist = Library.Flags["AH_blist"]
        end

        local priority = Library.Flags["HP"] or "Highest Value"
        local candidates

        if priority == "Oldest" then
            candidates = getOldestCandidates(maxCount, fruitFilter, nil, nil, true)
        elseif priority == "Closest" then
            candidates = getClosestCandidates(maxCount, fruitFilter, nil, nil, true)
        else
            candidates = getBestValueCandidates(maxCount, fruitFilter, nil, nil, true, blacklist)
        end

        local harvestedCount = 0
        for _, candidate in ipairs(candidates) do
            if not Library.Flags["AH"] then break end
            if harvestedCount >= maxCount then break end

            if candidate.plantId then
                task.spawn(harvestPlant, candidate.plantId, candidate.fruitId)
                harvestedCount = harvestedCount + 1
            elseif candidate.model then
                local prompt = candidate.model:FindFirstChild("HarvestPrompt", true)
                if prompt then
                    task.spawn(triggerPrompt, prompt)
                    harvestedCount = harvestedCount + 1
                end
            end
            task.wait(0.02)
        end
    end
})

GardenTab:createDropdown({
    Name = "Auto Open Items",
    flagName = "Open_type",
    List = { "None", "All", "Crates", "Eggs", "Seed Packs" }
})

createIntervalToggle(GardenTab, {
    Name = "Auto Open",
    flagName = "Open",
    tag = "HQ_AutoOpen",
    delay = 1.5,
    Step = function()
        local selectionType = Library.Flags["Open_type"]
        if selectionType == "None" then return end

        local backpack = client:FindFirstChild("Backpack")
        if not backpack then return end

        for _, tool in ipairs(backpack:GetChildren()) do
            if not Library.Flags["Open"] then break end
            if tool:IsA("Tool") then
                local toolName = tool.Name:lower()

                if (selectionType == "All" or selectionType == "Crates") and toolName:find("crate") then
                    openCrate(tool.Name)
                    task.wait(0.2)
                elseif (selectionType == "All" or selectionType == "Eggs") and toolName:find("egg") then
                    openEgg(tool.Name)
                    task.wait(0.2)
                elseif (selectionType == "All" or selectionType == "Seed Packs")
                    and (toolName:find("seed pack") or toolName:find("seedpack")) then
                    openSeedPack(tool.Name)
                    task.wait(0.2)
                end
            end
        end
    end
})

GardenTab:createDropdown({
    Name = "Auto Sell",
    flagName = "Sell_type",
    List = { "None", "All", "Selected" }
})

GardenTab:createDropdown({
    Name = "Sell Fruits",
    flagName = "Sell_list",
    multi = true,
    List = GameData.seeds
})

GardenTab:createToggle({
    Name = "Ignore Favorites",
    flagName = "Sell_noFav",
    Flag = false
})

createIntervalToggle(GardenTab, {
    Name = "Auto Sell",
    flagName = "AS",
    tag = "HQ_AutoSell",
    delay = 0.8,
    Step = function()
        local selectionType = Library.Flags["Sell_type"]
        if selectionType == "None" then return end
        if Library.Flags["Sell_noFav"] then return end
        sellAllItems()
    end
})

-- ============================================================
-- GARDEN TAB: Plot Cleanup
-- ============================================================

GardenTab:createLabel({ Name = "Plot Cleanup", Special = true })

GardenTab:createDropdown({
    Name = "Auto Remove",
    flagName = "RM_type",
    List = { "None", "All", "Low KG", "Selected", "Blacklist" }
})

GardenTab:createDropdown({
    Name = "Remove Fruits",
    flagName = "RM_list",
    multi = true,
    List = GameData.seeds
})

GardenTab:createDropdown({
    Name = "Low Weight Fruits",
    flagName = "RM_low_type",
    List = { "None", "All", "Selected" }
})

GardenTab:createSlider({
    Name = "Max Fruit KG",
    flagName = "RM_maxKG",
    value = 0,
    minValue = 0,
    maxValue = 100000
})

GardenTab:createDropdown({
    Name = "Remove Plants",
    flagName = "RM_plants",
    List = { "None", "All", "Selected", "Low Value" }
})

createIntervalToggle(GardenTab, {
    Name = "Auto Remove",
    flagName = "RM",
    tag = "HQ_AutoRemove",
    delay = 0.6,
    Step = function()
        local selectionType = Library.Flags["RM_type"]
        if selectionType == "None" then return end

        authenticateGardenPlot()
        if not GardenPlot.plantsFolder then return end

        local maxKg = Library.Flags["RM_maxKG"] or 0
        local selectedList = Library.Flags["RM_list"]
        local fruitFilter = nil
        local blacklist = nil

        if selectionType == "Selected" then
            fruitFilter = selectedList
        elseif selectionType == "Blacklist" then
            blacklist = selectedList
        end

        local candidates
        if selectionType == "Low KG" then
            candidates = getBestValueCandidates(200, fruitFilter, nil, nil, true, blacklist)
            local filtered = {}
            for _, c in ipairs(candidates) do
                if c.score < maxKg then
                    table.insert(filtered, c)
                end
            end
            candidates = filtered
        else
            candidates = getBestValueCandidates(200, fruitFilter, nil, nil, true, blacklist)
        end

        local shovel = findToolByName("shovel") or findToolByName("Shovel")
        for _, candidate in ipairs(candidates) do
            if not Library.Flags["RM"] then break end
            if candidate.plantId then
                shovelPlant(candidate.plantId, candidate.fruitId, shovel)
                task.wait(0.05)
            end
        end
    end
})

GardenTab:createButton({
    Name = "Remove Once",
    Callback = function()
        authenticateGardenPlot()
        if not GardenPlot.plantsFolder then
            notify("Cleanup", "No garden found.", "warning")
            return
        end

        local shovel = findToolByName("shovel") or findToolByName("Shovel")
        local removedCount = 0
        for _, plantModel in ipairs(GardenPlot.plantsFolder:GetChildren()) do
            if plantModel:IsA("Model") and plantModel.PrimaryPart then
                local plantId, fruitId = getPlantIdentifiers(plantModel)
                shovelPlant(plantId, fruitId, shovel)
                removedCount = removedCount + 1
                task.wait(0.05)
            end
        end
        notify("Plot Cleanup", string.format("Removed %d plants.", removedCount), "info")
    end
})

GardenTab:createButton({
    Name = "Shovel Once",
    Callback = function()
        authenticateGardenPlot()
        if not GardenPlot.plantsFolder then
            notify("Shovel", "No garden found.", "warning")
            return
        end

        local shovel = findToolByName("shovel") or findToolByName("Shovel")
        local dugCount = 0
        for _, plantModel in ipairs(GardenPlot.plantsFolder:GetChildren()) do
            if plantModel:IsA("Model") and plantModel.PrimaryPart then
                local plantId, fruitId = getPlantIdentifiers(plantModel)
                shovelPlant(plantId, fruitId, shovel)
                dugCount = dugCount + 1
                task.wait(0.05)
            end
        end
        notify("Shovel", string.format("Dug up %d plants.", dugCount), "info")
    end
})

-- ============================================================
-- GARDEN TAB: Watering
-- ============================================================

GardenTab:createLabel({ Name = "Watering", Special = true })

createIntervalToggle(GardenTab, {
    Name = "Auto Water",
    flagName = "AW",
    tag = "HQ_AutoWater",
    delay = 0.5,
    Step = function()
        authenticateGardenPlot()
        if not GardenPlot.plantsFolder then return end

        local selectedRarities = Library.Flags["AW_rar"]
        local priority = Library.Flags["AW_prio"] or "All Need Water"

        local plantsToWater = {}
        for _, plantModel in ipairs(GardenPlot.plantsFolder:GetChildren()) do
            if plantModel:IsA("Model") and plantModel.PrimaryPart then
                if selectedRarities and #selectedRarities > 0 then
                    local rarity = (plantModel:GetAttribute("Rarity") or ""):lower()
                    local matchesRarity = false
                    for _, r in ipairs(selectedRarities) do
                        if rarity == r:lower() then
                            matchesRarity = true
                            break
                        end
                    end
                    if not matchesRarity then continue end
                end
                table.insert(plantsToWater, plantModel)
            end
        end

        if priority == "Closest" then
            local rootPart = client.Character and client.Character:FindFirstChild("HumanoidRootPart")
            if rootPart then
                table.sort(plantsToWater, function(a, b)
                    local distA = (a:GetPivot().Position - rootPart.Position).Magnitude
                    local distB = (b:GetPivot().Position - rootPart.Position).Magnitude
                    return distA < distB
                end)
            end
        elseif priority == "Driest First" then
            table.sort(plantsToWater, function(a, b)
                local waterA = a:GetAttribute("WaterLevel") or 100
                local waterB = b:GetAttribute("WaterLevel") or 100
                return waterA < waterB
            end)
        end

        for _, plantModel in ipairs(plantsToWater) do
            if not Library.Flags["AW"] then break end
            waterPlant(plantModel:GetPivot().Position)
            task.wait(0.04)
        end
    end
})

GardenTab:createDropdown({
    Name = "Water Priority",
    flagName = "AW_prio",
    List = { "All Need Water", "Closest", "Driest First" }
})

GardenTab:createDropdown({
    Name = "Water Rarities",
    flagName = "AW_rar",
    multi = true,
    List = RarityList
})

-- ============================================================
-- GARDEN TAB: Gear Use
-- ============================================================

GardenTab:createLabel({ Name = "Gear Use", Special = true })

GardenTab:createDropdown({
    Name = "Gear Types",
    flagName = "GU_type",
    List = { "None", "All", "Selected", "Sprinklers Only" }
})

GardenTab:createDropdown({
    Name = "Gear To Use",
    flagName = "GU_list",
    multi = true,
    List = GameData.gears
})

GardenTab:createDropdown({
    Name = "Target Priority",
    flagName = "GU_prio",
    List = { "Best Value", "Closest" }
})

GardenTab:createToggle({
    Name = "Cluster Optimize",
    flagName = "GU_cluster",
    Flag = false
})

GardenTab:createDropdown({
    Name = "Target Rarities",
    flagName = "GU_rar",
    multi = true,
    List = RarityList
})

GardenTab:createSlider({
    Name = "Min Value",
    flagName = "GU_minVal",
    value = 0,
    minValue = 0,
    maxValue = 100000
})

createIntervalToggle(GardenTab, {
    Name = "Auto Use Gear",
    flagName = "GU",
    tag = "HQ_AutoGear",
    delay = 0.55,
    Step = function()
        local selectionType = Library.Flags["GU_type"]
        if selectionType == "None" then return end

        authenticateGardenPlot()
        enforceGeofence("Plant")

        local sprinklersToPlace = {}

        if selectionType == "All" or selectionType == "Sprinklers Only" then
            sprinklersToPlace = getBackpackSprinklerNames()
        elseif selectionType == "Selected" then
            local selectedList = Library.Flags["GU_list"]
            if selectedList then
                sprinklersToPlace = typeof(selectedList) == "table" and selectedList or { selectedList }
            end
        end

        for _, sprinklerName in ipairs(sprinklersToPlace) do
            if not Library.Flags["GU"] then break end
            if sprinklerName == "" then continue end
            local position = getPlacementPosition(3.6)
            if position then
                placeSprinkler(sprinklerName, position)
                task.wait(0.07)
            end
        end
    end
})

-- ============================================================
-- GARDEN TAB: Auto Collect Seeds
-- ============================================================

GardenTab:createLabel({ Name = "Auto Collect Seeds", Special = true })

GardenTab:createDropdown({
    Name = "Auto Collect...",
    flagName = "ACS_type",
    List = { "None", "All", "Rainbow Only", "Gold Only" }
})

createIntervalToggle(GardenTab, {
    Name = "Auto Collect Seeds",
    flagName = "ACS",
    tag = "HQ_AutoCollectSeeds",
    delay = 1.0,
    Step = function()
        local selectionType = Library.Flags["ACS_type"]
        if selectionType == "None" then return end

        for _, descendant in ipairs(Workspace:GetDescendants()) do
            if not Library.Flags["ACS"] then break end

            if descendant:IsA("ProximityPrompt") then
                local combinedText = (descendant.Name .. " "
                    .. (descendant.ActionText or "") .. " "
                    .. (descendant.ObjectText or "")):lower()

                local shouldCollect = false
                if selectionType == "All" then
                    shouldCollect = combinedText:find("seed") or combinedText:find("rainbow")
                        or combinedText:find("gold") or combinedText:find("claim")
                        or combinedText:find("special")
                elseif selectionType == "Rainbow Only" then
                    shouldCollect = combinedText:find("rainbow")
                elseif selectionType == "Gold Only" then
                    shouldCollect = combinedText:find("gold")
                end

                if shouldCollect then
                    local model = descendant:FindFirstAncestorWhichIsA("Model") or descendant.Parent
                    if model then
                        teleportTo(model:GetPivot().Position)
                        task.wait(0.12)
                        task.spawn(triggerPrompt, descendant)
                        task.wait(0.4)
                    end
                end
            end
        end
    end
})

-- ============================================================
-- GARDEN TAB: Upgrades & Utilities
-- ============================================================

GardenTab:createLabel({ Name = "Upgrades & Utilities", Special = true })

createIntervalToggle(GardenTab, {
    Name = "Auto Expand Inventory",
    flagName = "Up_Inv",
    tag = "HQ_ExpandInv",
    delay = 2.0,
    Step = function()
        local backpack = client:FindFirstChild("Backpack")
        if not backpack then return end
        if backpack:GetAttribute("BackpackFull") then
            sellAllItems()
            task.wait(0.5)
        end
    end
})

GardenTab:createToggle({
    Name = "Auto Max Pet Slots",
    flagName = "Up_Pet",
    Flag = false
})

GardenTab:createToggle({
    Name = "Auto Expand Plot",
    flagName = "Up_Plot",
    Flag = false
})

createIntervalToggle(GardenTab, {
    Name = "Fling Aura",
    flagName = "FA",
    tag = "HQ_FlingAura",
    delay = 0.1,
    Step = function()
        local myRoot = client.Character and client.Character:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end

        for _, otherPlayer in ipairs(Players:GetPlayers()) do
            if otherPlayer == client then continue end
            local otherRoot = otherPlayer.Character and otherPlayer.Character:FindFirstChild("HumanoidRootPart")
            if otherRoot and (otherRoot.Position - myRoot.Position).Magnitude < 15 then
                otherRoot.AssemblyLinearVelocity = (otherRoot.Position - myRoot.Position).Unit * 200
                    + Vector3.new(0, 120, 0)
            end
        end
    end
})

GardenTab:createLabel({ Name = "Plot Teleport", Special = true })

GardenTab:createToggle({
    Name = "Teleport To Gate (Collect)",
    flagName = "TPToEntranceCollect",
    Flag = true
})

GardenTab:createToggle({
    Name = "Teleport To Gate (Plant)",
    flagName = "TPToEntrancePlant",
    Flag = true
})

GardenTab:createSlider({
    Name = "Geofence Radius",
    flagName = "GeofenceRadius",
    value = 22,
    minValue = 8,
    maxValue = 90
})

GardenTab:createDropdown({
    Name = "Placement Mode",
    flagName = "PlacingMode",
    List = { "Virtual Plot Grid", "Character Position", "Random Spatial Plot", "Mouse Position" }
})

GardenTab:createButton({
    Name = "Teleport to Garden",
    Callback = function()
        authenticateGardenPlot()
        if GardenPlot.isAuthenticated and GardenPlot.entranceGate then
            teleportTo(GardenPlot.entranceGate.Position)
            notify("Teleport", "Arrived at your garden.", "info")
        else
            notify("Teleport", "Could not find your garden.", "warning")
        end
    end
})

-- ============================================================
-- STEALER TAB
-- ============================================================

local StealerTab = Setup:CreateSection("🦝 Stealer")

StealerTab:createLabel({ Name = "Auto Steal Targets", Special = true })

createIntervalToggle(StealerTab, {
    Name = "Auto Steal",
    flagName = "ST",
    tag = "HQ_AutoSteal",
    delay = 1.3,
    Step = function()
        if not isNightTime() then return end

        local stealRarities = Library.Flags["ST_rar"]
        local stealNames = Library.Flags["ST_names"]
        local mutationWhitelist = Library.Flags["ST_mw"]
        local mutationBlacklist = Library.Flags["ST_mb"]
        local minimumKg = Library.Flags["ST_minKG"] or 0
        local carryPerSteal = Library.Flags["ST_carry"] or 50
        local targetPriority = Library.Flags["ST_prio"] or "Value"

        local candidates = getBestValueCandidates(200, stealNames, mutationWhitelist, stealRarities, false)

        -- Apply mutation blacklist
        if mutationBlacklist and #mutationBlacklist > 0 then
            local filtered = {}
            for _, candidate in ipairs(candidates) do
                if candidate.model then
                    local mutation = candidate.model:GetAttribute("Mutation")
                    local shouldKeep = true
                    if mutation then
                        for _, blacklisted in ipairs(mutationBlacklist) do
                            if mutation:lower() == blacklisted:lower() then
                                shouldKeep = false
                                break
                            end
                        end
                    end
                    if shouldKeep then
                        table.insert(filtered, candidate)
                    end
                else
                    table.insert(filtered, candidate)
                end
            end
            candidates = filtered
        end

        -- Apply minimum KG filter
        if minimumKg > 0 then
            local filtered = {}
            for _, candidate in ipairs(candidates) do
                if candidate.score >= minimumKg then
                    table.insert(filtered, candidate)
                end
            end
            candidates = filtered
        end

        -- Sort by priority
        if targetPriority == "Value" then
            table.sort(candidates, function(a, b) return a.score > b.score end)
        elseif targetPriority == "Closest" then
            table.sort(candidates, function(a, b) return a.distance < b.distance end)
        end

        local stolenCount = 0
        for _, candidate in ipairs(candidates) do
            if not Library.Flags["ST"] then break end
            if stolenCount >= carryPerSteal then break end

            if candidate.model then
                local ownerUserId = getPlotOwnerUserId(
                    candidate.model.Parent and candidate.model.Parent.Parent
                    or candidate.model.Parent
                )

                if ownerUserId then
                    -- Skip friends
                    if Library.Flags["ST_skipF"] then
                        local success, isFriend = pcall(function()
                            return client:IsFriendsWith(ownerUserId)
                        end)
                        if success and isFriend then
                            continue
                        end
                    end

                    -- Avoid owners
                    if Library.Flags["ST_avoidO"] then
                        local owner = Players:GetPlayerByUserId(ownerUserId)
                        if owner and owner.Character then
                            local ownerRoot = owner.Character:FindFirstChild("HumanoidRootPart")
                            if ownerRoot then
                                local distanceToOwner = (candidate.model:GetPivot().Position
                                    - ownerRoot.Position).Magnitude
                                if distanceToOwner < 20 then
                                    continue
                                end
                            end
                        end
                    end

                    -- Fling owner
                    if Library.Flags["ST_flingO"] then
                        local owner = Players:GetPlayerByUserId(ownerUserId)
                        if owner and owner.Character then
                            local ownerRoot = owner.Character:FindFirstChild("HumanoidRootPart")
                            if ownerRoot then
                                ownerRoot.AssemblyLinearVelocity = (candidate.model:GetPivot().Position
                                    - ownerRoot.Position).Unit * 250 + Vector3.new(0, 150, 0)
                            end
                        end
                    end

                    -- Execute steal
                    teleportTo(candidate.model:GetPivot().Position)
                    task.wait(0.1)

                    beginSteal(ownerUserId, candidate.plantId, candidate.fruitId)
                    completeSteal()

                    local prompt = candidate.model:FindFirstChild("HarvestPrompt", true)
                    if prompt then
                        task.spawn(triggerPrompt, prompt)
                    end

                    task.spawn(harvestPlant, candidate.plantId, candidate.fruitId)
                    stolenCount = stolenCount + 1
                    task.wait(0.25)
                end
            elseif candidate.plantId then
                task.spawn(harvestPlant, candidate.plantId, candidate.fruitId)
                stolenCount = stolenCount + 1
                task.wait(0.2)
            end
        end
    end
})

StealerTab:createDropdown({
    Name = "Steal Rarities",
    flagName = "ST_rar",
    multi = true,
    List = RarityList
})

StealerTab:createDropdown({
    Name = "Plant Names",
    flagName = "ST_names",
    multi = true,
    List = GameData.seeds
})

StealerTab:createDropdown({
    Name = "Mutation Whitelist",
    flagName = "ST_mw",
    multi = true,
    List = MutationList
})

StealerTab:createDropdown({
    Name = "Mutation Blacklist",
    flagName = "ST_mb",
    multi = true,
    List = MutationList
})

StealerTab:createSlider({
    Name = "Minimum KG",
    flagName = "ST_minKG",
    value = 0,
    minValue = 0,
    maxValue = 100000
})

StealerTab:createSlider({
    Name = "Carry Per Steal",
    flagName = "ST_carry",
    value = 50,
    minValue = 1,
    maxValue = 200
})

StealerTab:createDropdown({
    Name = "Target Priority",
    flagName = "ST_prio",
    List = { "Value", "Closest", "Random" }
})

StealerTab:createToggle({
    Name = "Skip Friends",
    flagName = "ST_skipF",
    Flag = false
})

StealerTab:createToggle({
    Name = "Avoid Owners",
    flagName = "ST_avoidO",
    Flag = false
})

StealerTab:createToggle({
    Name = "Fling Owner",
    flagName = "ST_flingO",
    Flag = true
})

-- ============================================================
-- STEALER TAB: Anti Steal Guard
-- ============================================================

StealerTab:createLabel({ Name = "Anti Steal Guard", Special = true })

createIntervalToggle(StealerTab, {
    Name = "Anti Steal",
    flagName = "ASG_steal",
    tag = "HQ_AntiSteal",
    delay = 0.1,
    Flag = true,
    Step = function()
        local myRoot = client.Character and client.Character:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end

        for _, otherPlayer in ipairs(Players:GetPlayers()) do
            if otherPlayer == client then continue end
            local otherRoot = otherPlayer.Character and otherPlayer.Character:FindFirstChild("HumanoidRootPart")
            if otherRoot and (otherRoot.Position - myRoot.Position).Magnitude < 8 then
                otherRoot.AssemblyLinearVelocity = (otherRoot.Position - myRoot.Position).Unit * 180
                    + Vector3.new(0, 100, 0)
            end
        end
    end
})

createIntervalToggle(StealerTab, {
    Name = "Anti Hit",
    flagName = "ASG_hit",
    tag = "HQ_AntiHit",
    delay = 0.1,
    Flag = true,
    Step = function()
        local character = client.Character
        if not character then return end

        for _, child in ipairs(character:GetDescendants()) do
            if child:IsA("BasePart") then
                child.CanCollide = false
                child.CanTouch = false
            end
        end

        for _, otherPlayer in ipairs(Players:GetPlayers()) do
            if otherPlayer == client then continue end
            if otherPlayer.Character then
                for _, child in ipairs(otherPlayer.Character:GetDescendants()) do
                    if child:IsA("BasePart") then
                        child.CanCollide = false
                        child.CanTouch = false
                    end
                end
            end
        end
    end
})

createIntervalToggle(StealerTab, {
    Name = "Anti Fling",
    flagName = "ASG_fling",
    tag = "HQ_AntiFling",
    delay = 0.1,
    Flag = true,
    Step = function()
        local myRoot = client.Character and client.Character:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end

        if myRoot.AssemblyLinearVelocity.Magnitude > 200 then
            myRoot.AssemblyLinearVelocity = Vector3.zero
            myRoot.AssemblyAngularVelocity = Vector3.zero
        end
    end
})

-- ============================================================
-- STEALER TAB: Stealer Safety
-- ============================================================

StealerTab:createLabel({ Name = "Stealer Safety", Special = true })

createIntervalToggle(StealerTab, {
    Name = "Anti Bee Effect",
    flagName = "SAFE_bee",
    tag = "HQ_AntiBee",
    delay = 2.0,
    Flag = true,
    Step = function()
        local character = client.Character
        if not character then return end

        for _, child in ipairs(character:GetChildren()) do
            if child:IsA("Script") or child:IsA("LocalScript") then
                local childName = child.Name:lower()
                if childName:find("bee") or childName:find("sting")
                    or childName:find("poison") or childName:find("thorn") then
                    child.Disabled = true
                    child:Destroy()
                end
            end
        end
    end
})

createIntervalToggle(StealerTab, {
    Name = "Ragdoll Recovery",
    flagName = "SAFE_ragdoll",
    tag = "HQ_RagdollRecovery",
    delay = 0.5,
    Flag = true,
    Step = function()
        local humanoid = client.Character and client.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        end
    end
})

-- ============================================================
-- SHOP TAB
-- ============================================================

local ShopTab = Setup:CreateSection("🛒 Shop")

ShopTab:createLabel({ Name = "Seed & Gear Shop", Special = true })

ShopTab:createDropdown({
    Name = "Auto Seeds",
    flagName = "SH_seeds_type",
    List = { "None", "All", "Selected" }
})

ShopTab:createDropdown({
    Name = "Seeds To Buy",
    flagName = "SH_seeds",
    multi = true,
    List = GameData.seeds
})

createIntervalToggle(ShopTab, {
    Name = "Auto Buy Seeds",
    flagName = "SH_bs",
    tag = "HQ_BuySeeds",
    delay = 1.5,
    Step = function()
        local selectionType = Library.Flags["SH_seeds_type"]
        if selectionType == "None" then return end

        local seedList = {}
        if selectionType == "All" then
            seedList = GameData.seeds
        elseif selectionType == "Selected" then
            local selected = Library.Flags["SH_seeds"]
            if selected then
                seedList = typeof(selected) == "table" and selected or { selected }
            end
        end

        for _, seedName in ipairs(seedList) do
            if not Library.Flags["SH_bs"] then break end
            if seedName ~= "" then
                buySeed(seedName)
                task.wait(0.06)
            end
        end
    end
})

ShopTab:createDropdown({
    Name = "Auto Gears",
    flagName = "SH_gears_type",
    List = { "None", "All", "Selected" }
})

ShopTab:createDropdown({
    Name = "Gears To Buy",
    flagName = "SH_gears",
    multi = true,
    List = GameData.gears
})

createIntervalToggle(ShopTab, {
    Name = "Auto Buy Gears",
    flagName = "SH_bg",
    tag = "HQ_BuyGears",
    delay = 1.5,
    Step = function()
        local selectionType = Library.Flags["SH_gears_type"]
        if selectionType == "None" then return end

        local gearList = {}
        if selectionType == "All" then
            gearList = GameData.gears
        elseif selectionType == "Selected" then
            local selected = Library.Flags["SH_gears"]
            if selected then
                gearList = typeof(selected) == "table" and selected or { selected }
            end
        end

        for _, gearName in ipairs(gearList) do
            if not Library.Flags["SH_bg"] then break end
            if gearName ~= "" then
                buyGear(gearName)
                task.wait(0.06)
            end
        end
    end
})

ShopTab:createDropdown({
    Name = "Auto Props",
    flagName = "SH_props_type",
    List = { "None", "All", "Selected" }
})

ShopTab:createDropdown({
    Name = "Props To Buy",
    flagName = "SH_props",
    multi = true,
    List = GameData.crates
})

createIntervalToggle(ShopTab, {
    Name = "Auto Buy Props",
    flagName = "SH_bp",
    tag = "HQ_BuyProps",
    delay = 1.5,
    Step = function()
        local selectionType = Library.Flags["SH_props_type"]
        if selectionType == "None" then return end

        local propList = {}
        if selectionType == "All" then
            propList = GameData.crates
        elseif selectionType == "Selected" then
            local selected = Library.Flags["SH_props"]
            if selected then
                propList = typeof(selected) == "table" and selected or { selected }
            end
        end

        for _, propName in ipairs(propList) do
            if not Library.Flags["SH_bp"] then break end
            if propName ~= "" then
                buyCrate(propName)
                task.wait(0.06)
            end
        end
    end
})

ShopTab:createLabel({ Name = "Wild Pet Shop", Special = true })

ShopTab:createDropdown({
    Name = "Pet Rarities",
    flagName = "SH_pet_rar",
    multi = true,
    List = RarityList
})

ShopTab:createDropdown({
    Name = "Pet Names",
    flagName = "SH_pet_names",
    multi = true,
    List = GameData.pets
})

ShopTab:createDropdown({
    Name = "Pet Blacklist",
    flagName = "SH_pet_blist",
    multi = true,
    List = GameData.pets
})

createIntervalToggle(ShopTab, {
    Name = "Auto Buy Pets",
    flagName = "SH_bpet",
    tag = "HQ_BuyPets",
    delay = 1.0,
    Step = function()
        local selectedRarities = Library.Flags["PetRarity"] or {}

        for _, prompt in ipairs(CollectionService:GetTagged("BuyPetPrompt")) do
            if not Library.Flags["SH_bpet"] then break end

            if prompt:IsA("ProximityPrompt") then
                local model = prompt:FindFirstAncestorWhichIsA("Model")
                if model then
                    local rarity = (model:GetAttribute("Rarity") or ""):lower()

                    for _, targetRarity in ipairs(selectedRarities) do
                        if (not selectedRarities or #selectedRarities == 0)
                            or rarity == targetRarity:lower()
                            or model.Name:lower():find(targetRarity:lower()) then
                            teleportTo(model:GetPivot().Position)
                            task.wait(0.12)
                            task.spawn(triggerPrompt, prompt)
                            task.wait(0.4)
                            break
                        end
                    end
                end
            end
        end
    end
})

ShopTab:createLabel({ Name = "Stock & Weather Predictors", Special = true })

ShopTab:createToggle({
    Name = "Show Predictors",
    flagName = "PRED",
    Flag = true
})

ShopTab:createLabel({ Name = "Daily Deals", Special = true })

createIntervalToggle(ShopTab, {
    Name = "Auto Use Daily Deals",
    flagName = "AutoDaily",
    tag = "HQ_DailyDeal",
    delay = 5.0,
    Step = function()
        checkDailyDeal()
    end
})

ShopTab:createLabel({ Name = "Crate & Egg Opening", Special = true })

createIntervalToggle(ShopTab, {
    Name = "Auto Open Crates",
    flagName = "OpenCt",
    tag = "HQ_OpenCrates",
    delay = 1.8,
    Step = function()
        local backpack = client:FindFirstChild("Backpack")
        if not backpack then return end

        for _, tool in ipairs(backpack:GetChildren()) do
            if not Library.Flags["OpenCt"] then break end
            if tool:IsA("Tool") and tool.Name:lower():find("crate") then
                openCrate(tool.Name)
                task.wait(0.25)
            end
        end
    end
})

createIntervalToggle(ShopTab, {
    Name = "Auto Open Eggs",
    flagName = "OpenEg",
    tag = "HQ_OpenEggs",
    delay = 1.8,
    Step = function()
        local backpack = client:FindFirstChild("Backpack")
        if not backpack then return end

        for _, tool in ipairs(backpack:GetChildren()) do
            if not Library.Flags["OpenEg"] then break end
            if tool:IsA("Tool") and tool.Name:lower():find("egg") then
                openEgg(tool.Name)
                task.wait(0.25)
            end
        end
    end
})

createIntervalToggle(ShopTab, {
    Name = "Auto Open Seed Packs",
    flagName = "OpenSp",
    tag = "HQ_OpenSeedPacks",
    delay = 1.8,
    Step = function()
        local backpack = client:FindFirstChild("Backpack")
        if not backpack then return end

        for _, tool in ipairs(backpack:GetChildren()) do
            if not Library.Flags["OpenSp"] then break end
            if tool:IsA("Tool") and (tool.Name:lower():find("seed pack")
                or tool.Name:lower():find("seedpack")) then
                openSeedPack(tool.Name)
                task.wait(0.25)
            end
        end
    end
})

-- ============================================================
-- MISC TAB
-- ============================================================

local MiscTab = Setup:CreateSection("⚙️ Misc")

MiscTab:createToggle({
    Name = "Humanized Mode (Random Delays)",
    flagName = "LegitMode",
    Flag = true
})

MiscTab:createLabel({ Name = "Codes", Special = true })

MiscTab:createButton({
    Name = "Redeem All Known Codes",
    Callback = function()
        local promoCodes = {
            "TEAMGREENBEAN", "STARBUD", "torigate", "RDCAward",
            "LUNARGLOW10", "BEANORLEAVE10"
        }
        for _, code in ipairs(promoCodes) do
            redeemCode(code)
            task.wait(0.08)
        end
        notify("Codes", "All promo codes redeemed successfully.", "info")
    end
})

MiscTab:createLabel({ Name = "Anti-Fling Protection", Special = true })

createIntervalToggle(MiscTab, {
    Name = "Anti Fling Protection",
    flagName = "AntiFling",
    tag = "HQ_AntiFling",
    delay = 0.1,
    Flag = true,
    Step = function()
        local myRoot = client.Character and client.Character:FindFirstChild("HumanoidRootPart")
        if myRoot then
            if myRoot.AssemblyLinearVelocity.Magnitude > 250
                or myRoot.AssemblyAngularVelocity.Magnitude > 50 then
                myRoot.AssemblyLinearVelocity = Vector3.zero
                myRoot.AssemblyAngularVelocity = Vector3.zero
            end
        end

        for _, otherPlayer in ipairs(Players:GetPlayers()) do
            if otherPlayer == client then continue end
            if otherPlayer.Character then
                for _, child in ipairs(otherPlayer.Character:GetDescendants()) do
                    if child:IsA("BasePart") then
                        child.CanCollide = false
                        child.CanTouch = false
                    end
                end
            end
        end

        local playerGui = client:FindFirstChild("PlayerGui")
        if playerGui then
            for _, descendant in ipairs(playerGui:GetDescendants()) do
                if descendant:IsA("GuiObject") then
                    local name = descendant.Name:lower()
                    if name:find("pause") or name:find("gameplay") or name:find("afk") then
                        descendant.Visible = false
                    end
                end
            end
        end
    end
})

registerCleanup(client.OnTeleport:Connect(function(state)
    if state == Enum.TeleportState.Failed then
        task.wait(5)
        pcall(function()
            TeleportService:Teleport(game.PlaceId, client)
        end)
    end
end))

MiscTab:createLabel({ Name = "Character Protection", Special = true })

createIntervalToggle(MiscTab, {
    Name = "Anti AFK & Knockback Shield",
    flagName = "AntiAFK",
    tag = "HQ_AntiAFK",
    delay = 4.0,
    Flag = true,
    Step = function()
        local humanoid = client.Character and client.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        end

        local character = client.Character
        if character then
            for _, child in ipairs(character:GetChildren()) do
                if child:IsA("Script") or child:IsA("LocalScript") then
                    local childName = child.Name:lower()
                    if childName:find("bee") or childName:find("sting")
                        or childName:find("poison") or childName:find("thorn") then
                        child.Disabled = true
                        child:Destroy()
                    end
                end
            end
        end

        local myRoot = client.Character and client.Character:FindFirstChild("HumanoidRootPart")
        if myRoot then
            for _, otherPlayer in ipairs(Players:GetPlayers()) do
                if otherPlayer == client then continue end
                local otherRoot = otherPlayer.Character
                    and otherPlayer.Character:FindFirstChild("HumanoidRootPart")
                if otherRoot and (otherRoot.Position - myRoot.Position).Magnitude < 12 then
                    local otherHumanoid = otherPlayer.Character:FindFirstChildOfClass("Humanoid")
                    if otherHumanoid then
                        otherHumanoid.Sit = true
                        otherRoot.AssemblyLinearVelocity = (otherRoot.Position - myRoot.Position).Unit * 150
                            + Vector3.new(0, 80, 0)
                    end
                end
            end
        end
    end
})

MiscTab:createLabel({ Name = "Gear Management", Special = true })

createIntervalToggle(MiscTab, {
    Name = "Auto Equip Best Gear",
    flagName = "EqGear",
    tag = "HQ_EquipGear",
    delay = 2.5,
    Step = function()
        for _, gearName in ipairs(GameData.gears) do
            if not Library.Flags["EqGear"] then break end
            local tool = findToolByName(gearName)
            if tool then
                equipGear(gearName)
                task.wait(0.1)
            end
        end
    end
})

MiscTab:createLabel({ Name = "Pet Management", Special = true })

createIntervalToggle(MiscTab, {
    Name = "Auto Equip Best Pets",
    flagName = "EqPets",
    tag = "HQ_EquipPets",
    delay = 2.5,
    Step = function()
        for _, petName in ipairs(GameData.pets) do
            if not Library.Flags["EqPets"] then break end
            equipPet(petName)
            task.wait(0.1)
        end
    end
})

MiscTab:createButton({
    Name = "Sell All Now",
    Callback = function()
        sellAllItems()
        notify("Inventory", "Sold everything to merchant.", "info")
    end
})

MiscTab:createButton({
    Name = "Rejoin Server",
    Callback = function()
        pcall(function()
            TeleportService:Teleport(game.PlaceId, client)
        end)
    end
})

-- ============================================================
-- VISUALS TAB
-- ============================================================

local VisualsTab = Setup:CreateSection("👁️ Visuals")

VisualsTab:createLabel({ Name = "World Settings", Special = true })

VisualsTab:createSlider({
    Name = "Clock Time",
    flagName = "ClockTime",
    value = 21,
    minValue = 0,
    maxValue = 24
})

createIntervalToggle(VisualsTab, {
    Name = "Override Clock Time",
    flagName = "ClockOv",
    tag = "HQ_ClockOverride",
    delay = 0.1,
    Step = function()
        Lighting.ClockTime = Library.Flags["ClockTime"] or 21
    end
})

createIntervalToggle(VisualsTab, {
    Name = "Fullbright",
    flagName = "Fullbright",
    tag = "HQ_Fullbright",
    delay = 0.5,
    Step = function()
        Lighting.Ambient = Color3.new(1, 1, 1)
        Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
    end
})

VisualsTab:createToggle({
    Name = "Performance Mode",
    flagName = "PerfMode",
    Flag = true,
    Callback = function(enabled)
        if enabled then
            pcall(function()
                sethiddenproperty(Lighting, "Technology", Enum.Technology.Compatibility)
            end)
        end
    end
})

createIntervalToggle(VisualsTab, {
    Name = "No Fog",
    flagName = "NoFog",
    tag = "HQ_NoFog",
    delay = 0.5,
    Step = function()
        Lighting.FogEnd = 100000
        Lighting.FogStart = 100000
    end
})

VisualsTab:createLabel({ Name = "Player ESP", Special = true })

VisualsTab:createToggle({ Name = "Player Boxes", flagName = "PBox", Flag = false })
VisualsTab:createToggle({ Name = "Player Names", flagName = "PName", Flag = false })
VisualsTab:createToggle({ Name = "Player Health", flagName = "PHP", Flag = false })
VisualsTab:createToggle({ Name = "Team Colors", flagName = "PTeam", Flag = false })
VisualsTab:createToggle({ Name = "Held Item", flagName = "PHeld", Flag = false })
VisualsTab:createToggle({ Name = "Distance", flagName = "PDist", Flag = false })
VisualsTab:createToggle({ Name = "Tracers", flagName = "PTracer", Flag = false })
VisualsTab:createToggle({ Name = "Skeleton ESP", flagName = "PSkel", Flag = false })
VisualsTab:createSlider({
    Name = "Max Distance",
    flagName = "PRange",
    value = 1500,
    minValue = 100,
    maxValue = 3000
})

VisualsTab:createLabel({ Name = "Better Graphics", Special = true })

VisualsTab:createToggle({
    Name = "Better Graphics",
    flagName = "BGFX",
    Flag = false,
    Callback = function(enabled)
        local colorCorrection = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
        if not colorCorrection then
            colorCorrection = Instance.new("ColorCorrectionEffect")
            colorCorrection.Parent = Lighting
        end
        if enabled then
            colorCorrection.Brightness = 0.05
            colorCorrection.Contrast = 0.15
            colorCorrection.Saturation = 0.25
            colorCorrection.Enabled = true
        else
            colorCorrection.Enabled = false
        end
    end
})

VisualsTab:createSlider({
    Name = "Darkness",
    flagName = "BGFX_dark",
    value = 100,
    minValue = 0,
    maxValue = 100
})

VisualsTab:createLabel({ Name = "Plant ESP", Special = true })

VisualsTab:createToggle({ Name = "Plant Radar", flagName = "PlantESP", Flag = false })
VisualsTab:createDropdown({
    Name = "Plant Rarities",
    flagName = "PE_rar",
    multi = true,
    List = RarityList
})
VisualsTab:createDropdown({
    Name = "Plant Names",
    flagName = "PE_names",
    multi = true,
    List = GameData.seeds
})
VisualsTab:createToggle({ Name = "Owned Only", flagName = "PE_owned", Flag = false })
VisualsTab:createToggle({ Name = "Show Mutation", flagName = "PE_mut", Flag = false })
VisualsTab:createToggle({ Name = "Show Distance", flagName = "PE_dist", Flag = false })
VisualsTab:createSlider({
    Name = "Max Distance",
    flagName = "PE_range",
    value = 1500,
    minValue = 100,
    maxValue = 3000
})

VisualsTab:createLabel({ Name = "Prop ESP", Special = true })

VisualsTab:createToggle({ Name = "Show Props", flagName = "PropESP", Flag = false })
VisualsTab:createSlider({
    Name = "Prop ESP Range",
    flagName = "PropRange",
    value = 500,
    minValue = 50,
    maxValue = 2000
})

-- ============================================================
-- ESP RENDERER
-- ============================================================

local ESP_FOLDER = Instance.new("Folder")
ESP_FOLDER.Name = "GardenHQ_ESP"
ESP_FOLDER.Parent = CoreGui
registerCleanup(ESP_FOLDER)

local ESP_OBJECTS = {}

local function createESPObject(targetObject, displayText, boxColor)
    if not targetObject or not targetObject.Parent
        or not targetObject:IsDescendantOf(Workspace) then
        return nil
    end

    if ESP_OBJECTS[targetObject] then
        return ESP_OBJECTS[targetObject]
    end

    local holder = Instance.new("Folder")
    holder.Name = "ESP_Holder"
    holder.Parent = ESP_FOLDER

    -- Highlight box
    local highlight = Instance.new("Highlight")
    highlight.Name = "ESP_Box"
    highlight.FillColor = boxColor or Color3.new(1, 1, 1)
    highlight.OutlineColor = Color3.new(0, 0, 0)
    highlight.FillTransparency = 0.75
    highlight.OutlineTransparency = 0.15
    highlight.Adornee = targetObject
    highlight.Parent = holder

    -- Billboard text
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESP_Text"
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 240, 0, 56)
    billboard.StudsOffset = Vector3.new(0, 4, 0)
    billboard.Adornee = targetObject
    billboard.Parent = holder

    local label = Instance.new("TextLabel")
    label.Name = "ESP_Label"
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = displayText
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.Parent = billboard

    ESP_OBJECTS[targetObject] = holder
    return holder
end

local function cleanDeadESPObjects()
    for targetObject, holder in pairs(ESP_OBJECTS) do
        if not targetObject or not targetObject.Parent
            or not targetObject:IsDescendantOf(Workspace) then
            if holder and holder.Parent then
                holder:Destroy()
            end
            ESP_OBJECTS[targetObject] = nil
        end
    end
end

registerCleanup(RunService.RenderStepped:Connect(function()
    cleanDeadESPObjects()

    -- Player ESP
    local showPlayerESP = Library.Flags["PName"] or Library.Flags["PBox"]
        or Library.Flags["PHP"] or Library.Flags["PHeld"]
        or Library.Flags["PDist"]

    if showPlayerESP then
        local maxDistance = Library.Flags["PRange"] or 1500
        local myRoot = client.Character and client.Character:FindFirstChild("HumanoidRootPart")

        for _, otherPlayer in ipairs(Players:GetPlayers()) do
            if otherPlayer == client then continue end

            local character = otherPlayer.Character
            local otherRoot = character and character:FindFirstChild("HumanoidRootPart")

            if otherRoot and myRoot
                and (otherRoot.Position - myRoot.Position).Magnitude <= maxDistance then

                local color
                if Library.Flags["PTeam"] then
                    color = otherPlayer.TeamColor and otherPlayer.TeamColor.Color
                        or Color3.new(0.5, 0.5, 1)
                else
                    color = Color3.new(1, 0, 0)
                end

                local displayText = otherPlayer.Name

                if Library.Flags["PHP"] then
                    local humanoid = character:FindFirstChildOfClass("Humanoid")
                    if humanoid then
                        displayText = displayText .. string.format(" [%.0f HP]", humanoid.Health)
                    end
                end

                if Library.Flags["PHeld"] then
                    local heldTool = character:FindFirstChildWhichIsA("Tool")
                    if heldTool then
                        displayText = displayText .. " [" .. heldTool.Name .. "]"
                    end
                end

                if Library.Flags["PDist"] then
                    displayText = displayText
                        .. string.format(" [%.0fm]", (otherRoot.Position - myRoot.Position).Magnitude)
                end

                local holder = createESPObject(character, displayText, color)

                if holder then
                    local box = holder:FindFirstChild("ESP_Box")
                    local text = holder:FindFirstChild("ESP_Text")
                    if box then
                        box.Enabled = Library.Flags["PBox"] == true
                    end
                    if text then
                        text.Enabled = Library.Flags["PName"] == true
                            or Library.Flags["PHP"] == true
                    end
                end
            elseif ESP_OBJECTS[character] then
                ESP_OBJECTS[character]:Destroy()
                ESP_OBJECTS[character] = nil
            end
        end
    else
        -- Clean up all player ESP when toggled off
        for _, otherPlayer in ipairs(Players:GetPlayers()) do
            if otherPlayer ~= client and otherPlayer.Character
                and ESP_OBJECTS[otherPlayer.Character] then
                ESP_OBJECTS[otherPlayer.Character]:Destroy()
                ESP_OBJECTS[otherPlayer.Character] = nil
            end
        end
    end

    -- Plant ESP
    if Library.Flags["PlantESP"] then
        local maxDistance = Library.Flags["PE_range"] or 1500
        local myRoot = client.Character and client.Character:FindFirstChild("HumanoidRootPart")
        local gardens = Workspace:FindFirstChild("Gardens") or Workspace
        local selectedFruits = Library.Flags["PE_names"]
        local selectedRarities = Library.Flags["PE_rar"]

        for _, plot in ipairs(gardens:GetChildren()) do
            if not (plot:IsA("Model") or plot:IsA("Folder")) then continue end

            local isOurPlot = (getPlotOwnerUserId(plot) == client.UserId)
            if Library.Flags["PE_owned"] and not isOurPlot then continue end

            local plantsFolder = plot:FindFirstChild("Plants")
            if plantsFolder and myRoot then
                for _, plantModel in ipairs(plantsFolder:GetChildren()) do
                    if plantModel:IsA("Model") and plantModel.PrimaryPart then
                        local distance = (plantModel:GetPivot().Position - myRoot.Position).Magnitude

                        if distance <= maxDistance
                            and passesFilter(plantModel, selectedFruits, nil, selectedRarities) then

                            local displayText = plantModel.Name

                            if Library.Flags["PE_mut"] then
                                local mutation = plantModel:GetAttribute("Mutation")
                                if mutation then
                                    displayText = string.format("[%s] %s", mutation, displayText)
                                end
                            end

                            if Library.Flags["PE_dist"] then
                                displayText = displayText .. string.format(" [%.0fm]", distance)
                            end

                            local boxColor = isOurPlot and Color3.new(0, 1, 0) or Color3.new(1, 1, 0)
                            createESPObject(plantModel, displayText, boxColor)
                        elseif ESP_OBJECTS[plantModel] then
                            ESP_OBJECTS[plantModel]:Destroy()
                            ESP_OBJECTS[plantModel] = nil
                        end
                    end
                end
            end
        end
    else
        -- Clean up plant ESP
        local gardens = Workspace:FindFirstChild("Gardens") or Workspace
        for _, plot in ipairs(gardens:GetChildren()) do
            local plantsFolder = plot:FindFirstChild("Plants")
            if plantsFolder then
                for _, plantModel in ipairs(plantsFolder:GetChildren()) do
                    if ESP_OBJECTS[plantModel] then
                        ESP_OBJECTS[plantModel]:Destroy()
                        ESP_OBJECTS[plantModel] = nil
                    end
                end
            end
        end
    end

    -- Prop ESP
    if Library.Flags["PropESP"] then
        local maxDistance = Library.Flags["PropRange"] or 500
        local myRoot = client.Character and client.Character:FindFirstChild("HumanoidRootPart")

        for _, plot in ipairs(Workspace:GetChildren()) do
            if not (plot:IsA("Model") or plot:IsA("Folder")) then continue end
            local propsFolder = plot:FindFirstChild("Props")
            if propsFolder and myRoot then
                for _, prop in ipairs(propsFolder:GetChildren()) do
                    if prop:IsA("Model") and prop.PrimaryPart then
                        local distance = (prop:GetPivot().Position - myRoot.Position).Magnitude
                        if distance <= maxDistance then
                            local displayText = prop.Name .. string.format(" [%.0fm]", distance)
                            createESPObject(prop, displayText, Color3.new(0.5, 0.5, 1))
                        elseif ESP_OBJECTS[prop] then
                            ESP_OBJECTS[prop]:Destroy()
                            ESP_OBJECTS[prop] = nil
                        end
                    end
                end
            end
        end
    else
        -- Clean up prop ESP
        for targetObject, holder in pairs(ESP_OBJECTS) do
            if targetObject and targetObject.Name and targetObject.Parent
                and targetObject.Parent.Name == "Props" then
                holder:Destroy()
                ESP_OBJECTS[targetObject] = nil
            end
        end
    end
end))

-- ============================================================
-- IN-GAME HUD: Weather Bar
-- ============================================================

local HUD_SCREEN = Instance.new("ScreenGui")
HUD_SCREEN.Name = "GardenHQ_HUD"
HUD_SCREEN.ResetOnSpawn = false
HUD_SCREEN.Parent = CoreGui
registerCleanup(HUD_SCREEN)

local WEATHER_BAR = Instance.new("Frame")
WEATHER_BAR.Name = "WeatherBar"
WEATHER_BAR.Size = UDim2.new(0, 620, 0, 48)
WEATHER_BAR.Position = UDim2.new(0.5, -310, 1, -106)
WEATHER_BAR.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
WEATHER_BAR.BackgroundTransparency = 0.15
WEATHER_BAR.BorderSizePixel = 2
WEATHER_BAR.BorderColor3 = Color3.fromRGB(50, 50, 50)
WEATHER_BAR.Parent = HUD_SCREEN

local WEATHER_LAYOUT = Instance.new("UIListLayout")
WEATHER_LAYOUT.Parent = WEATHER_BAR
WEATHER_LAYOUT.FillDirection = Enum.FillDirection.Horizontal
WEATHER_LAYOUT.HorizontalAlignment = Enum.HorizontalAlignment.Center
WEATHER_LAYOUT.VerticalAlignment = Enum.VerticalAlignment.Center
WEATHER_LAYOUT.SortOrder = Enum.SortOrder.LayoutOrder
WEATHER_LAYOUT.Padding = UDim.new(0, 5)

local WEATHER_WIDGETS = {}

local WEATHER_TYPES = {
    { id = "Sunset",    label = "Sunset",    color = Color3.fromRGB(255, 180, 50) },
    { id = "Moon",      label = "Moon",      color = Color3.fromRGB(240, 240, 255) },
    { id = "Day",       label = "Day",       color = Color3.fromRGB(255, 255, 80) },
    { id = "Rainbow",   label = "Rainbow",   color = Color3.fromRGB(150, 255, 255) },
    { id = "Bloodmoon", label = "Bloodmoon", color = Color3.fromRGB(255, 60, 60) },
    { id = "Goldmoon",  label = "Goldmoon",  color = Color3.fromRGB(255, 215, 0) }
}

for _, weatherType in ipairs(WEATHER_TYPES) do
    local box = Instance.new("Frame")
    box.Name = weatherType.id
    box.Size = UDim2.new(0, 92, 0, 40)
    box.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    box.BorderSizePixel = 1
    box.BorderColor3 = weatherType.color
    box.Parent = WEATHER_BAR

    local text = Instance.new("TextLabel")
    text.Name = "Text"
    text.Size = UDim2.new(1, 0, 1, 0)
    text.BackgroundTransparency = 1
    text.Text = weatherType.label .. "\nSync..."
    text.TextColor3 = weatherType.color
    text.Font = Enum.Font.GothamBold
    text.TextSize = 9
    text.TextWrapped = true
    text.TextAlignment = Enum.TextAlignment.Center
    text.Parent = box

    WEATHER_WIDGETS[weatherType.id] = text
end

-- ============================================================
-- IN-GAME HUD: Stock Ticker
-- ============================================================

local STOCK_FRAME = Instance.new("Frame")
STOCK_FRAME.Name = "StockFrame"
STOCK_FRAME.Size = UDim2.new(0, 620, 0, 26)
STOCK_FRAME.Position = UDim2.new(0.5, -310, 1, -58)
STOCK_FRAME.BackgroundTransparency = 1
STOCK_FRAME.Parent = HUD_SCREEN

local STOCK_LAYOUT = Instance.new("UIListLayout")
STOCK_LAYOUT.FillDirection = Enum.FillDirection.Horizontal
STOCK_LAYOUT.HorizontalAlignment = Enum.HorizontalAlignment.Center
STOCK_LAYOUT.Padding = UDim.new(0, 8)
STOCK_LAYOUT.Parent = STOCK_FRAME

local STOCK_WIDGETS = {}

local function updateStockWidget(shopName, itemName, count)
    local key = shopName .. "_" .. itemName
    if not STOCK_WIDGETS[key] then
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0, 140, 0, 20)
        label.BackgroundTransparency = 0.3
        label.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        label.TextColor3 = Color3.fromRGB(180, 255, 180)
        label.Font = Enum.Font.Gotham
        label.TextSize = 10
        label.Text = shopName .. ": " .. itemName .. " x" .. count
        label.Parent = STOCK_FRAME
        STOCK_WIDGETS[key] = label
    else
        STOCK_WIDGETS[key].Text = shopName .. ": " .. itemName .. " x" .. count
    end
end

-- ============================================================
-- SYSTEM STATE TRACKER & PREDICTORS
-- ============================================================

local SystemState = {
    currentWeather = "Clear Skies",
    restockStatus = "Syncing...",
    trendingItem = "None",
    nextWeather = "Unknown",
    stockSnapshots = {},
    predictedRestocks = {}
}

registerCleanup(task.spawn(function()
    while true do
        task.wait(1.2)
        pcall(function()
            local nowReal = os.time()
            local rainbowRemaining = 2700 - (nowReal % 2700)
            local bloodmoonRemaining = 3600 - (nowReal % 3600)
            local goldmoonRemaining = 7200 - (nowReal % 7200)

            if WEATHER_WIDGETS["Sunset"] then
                WEATHER_WIDGETS["Sunset"].Text = "Sunset\n"
                    .. string.format("in %.0fm", rainbowRemaining / 60)
            end
            if WEATHER_WIDGETS["Moon"] then
                WEATHER_WIDGETS["Moon"].Text = "Moon\n"
                    .. string.format("in %.0fm", bloodmoonRemaining / 60)
            end
            if WEATHER_WIDGETS["Day"] then
                WEATHER_WIDGETS["Day"].Text = "Day\n"
                    .. string.format("in %.0fm", (nowReal % 86400) / 60)
            end
            if WEATHER_WIDGETS["Rainbow"] then
                WEATHER_WIDGETS["Rainbow"].Text = "Rainbow\n"
                    .. string.format("in %.0fm", rainbowRemaining / 60)
            end
            if WEATHER_WIDGETS["Bloodmoon"] then
                WEATHER_WIDGETS["Bloodmoon"].Text = "Bloodmoon\n"
                    .. string.format("in %.0fm", bloodmoonRemaining / 60)
            end
            if WEATHER_WIDGETS["Goldmoon"] then
                WEATHER_WIDGETS["Goldmoon"].Text = "Goldmoon\n"
                    .. string.format("in %.0fm", goldmoonRemaining / 60)
            end

            local weatherData = ReplicatedStorage:FindFirstChild("Weather", true)
                or ReplicatedStorage:FindFirstChild("Environment", true)
            if weatherData then
                local currentWeather = weatherData:FindFirstChild("Current")
                    or weatherData:FindFirstChild("Weather")
                if currentWeather and currentWeather:IsA("StringValue") then
                    SystemState.currentWeather = currentWeather.Value
                end
            end

            local stockFolder = ReplicatedStorage:FindFirstChild("StockValues", true)
            if stockFolder then
                for _, shopName in ipairs({ "SeedShop", "GearShop", "CrateShop", "PetShop" }) do
                    local shop = stockFolder:FindFirstChild(shopName)
                    if shop and shop:FindFirstChild("Items") then
                        for _, item in ipairs(shop.Items:GetChildren()) do
                            if item:IsA("NumberValue") then
                                local previous = (SystemState.stockSnapshots[shopName] or {})[item.Name] or 0
                                local current = item.Value
                                updateStockWidget(shopName, item.Name, current)

                                if previous == 0 and current > 0 then
                                    local lastTime = SystemState.predictedRestocks[shopName .. "_" .. item.Name]
                                        or nowReal
                                    local interval = nowReal - lastTime
                                    if interval > 60 then
                                        SystemState.predictedRestocks[shopName .. "_" .. item.Name] = {
                                            next = nowReal + interval,
                                            interval = interval
                                        }
                                    end
                                end

                                SystemState.stockSnapshots[shopName] = SystemState.stockSnapshots[shopName] or {}
                                SystemState.stockSnapshots[shopName][item.Name] = current
                            end
                        end
                    end
                end
            end

            SystemState.restockStatus = "Monitoring..."
            SystemState.trendingItem = "Check shops"
        end)
    end
end))

-- ============================================================
-- PREDICTORS TAB
-- ============================================================

local PredictorsTab = Setup:CreateSection("🔮 Predictors")

PredictorsTab:createLabel({ Name = "Live Status", Special = true })

local WEATHER_STATUS_LABEL = PredictorsTab:createLabel({
    Name = "Weather: Syncing...",
    Center = true
})

local STOCK_STATUS_LABEL = PredictorsTab:createLabel({
    Name = "Restock: Syncing...",
    Center = true
})

local NIGHT_STATUS_LABEL = PredictorsTab:createLabel({
    Name = "Night: Checking...",
    Center = true
})

local PLOT_STATUS_LABEL = PredictorsTab:createLabel({
    Name = "Plot: Not authenticated",
    Center = true
})

registerCleanup(task.spawn(function()
    while true do
        task.wait(2)
        pcall(function()
            local weatherText = "Weather: " .. SystemState.currentWeather
                .. " | Next: " .. SystemState.nextWeather
            local stockText = "Restock: " .. SystemState.restockStatus
                .. " | Trending: " .. SystemState.trendingItem
            local nightText = "Night: " .. (isNightTime() and "ACTIVE (Stealing possible)" or "Inactive")

            authenticateGardenPlot()
            local plotText = "Plot: " .. (GardenPlot.isAuthenticated
                and ("Authenticated #" .. (GardenPlot.plotId or "?"))
                or "Not found")

            if WEATHER_STATUS_LABEL then
                if WEATHER_STATUS_LABEL.Text ~= nil then
                    WEATHER_STATUS_LABEL.Text = weatherText
                elseif WEATHER_STATUS_LABEL.SetText then
                    WEATHER_STATUS_LABEL:SetText(weatherText)
                end
            end

            if STOCK_STATUS_LABEL then
                if STOCK_STATUS_LABEL.Text ~= nil then
                    STOCK_STATUS_LABEL.Text = stockText
                elseif STOCK_STATUS_LABEL.SetText then
                    STOCK_STATUS_LABEL:SetText(stockText)
                end
            end

            if NIGHT_STATUS_LABEL then
                if NIGHT_STATUS_LABEL.Text ~= nil then
                    NIGHT_STATUS_LABEL.Text = nightText
                elseif NIGHT_STATUS_LABEL.SetText then
                    NIGHT_STATUS_LABEL:SetText(nightText)
                end
            end

            if PLOT_STATUS_LABEL then
                if PLOT_STATUS_LABEL.Text ~= nil then
                    PLOT_STATUS_LABEL.Text = plotText
                elseif PLOT_STATUS_LABEL.SetText then
                    PLOT_STATUS_LABEL:SetText(plotText)
                end
            end
        end)
    end
end))

PredictorsTab:createLabel({ Name = "Garden Scanner", Special = true })

PredictorsTab:createButton({
    Name = "Scan My Garden",
    Callback = function()
        authenticateGardenPlot()

        if not GardenPlot.plantsFolder then
            notify("Scan", "No garden found. Teleport to your plot first.", "warning")
            return
        end

        local plantCount = 0
        local fruitCount = 0
        local mutations = {}
        local rarities = {}

        for _, plantModel in ipairs(GardenPlot.plantsFolder:GetChildren()) do
            if plantModel:IsA("Model") then
                plantCount = plantCount + 1

                local mutation = plantModel:GetAttribute("Mutation")
                if mutation then
                    mutations[mutation] = (mutations[mutation] or 0) + 1
                end

                local rarity = plantModel:GetAttribute("Rarity")
                if rarity then
                    rarities[rarity] = (rarities[rarity] or 0) + 1
                end

                if plantModel:GetAttribute("FruitId") then
                    fruitCount = fruitCount + 1
                end
            end
        end

        local topMutation = "None"
        local topMutationCount = 0
        for mutation, count in pairs(mutations) do
            if count > topMutationCount then
                topMutation = mutation
                topMutationCount = count
            end
        end

        notify("Garden Statistics",
            string.format(
                "Plants: %d | Fruits: %d | Top Mutation: %s (%d)",
                plantCount, fruitCount, topMutation, topMutationCount
            ),
            "info"
        )
    end
})

-- ============================================================
-- FOOTER
-- ============================================================

print(string.rep("━", 64))
print("┃ GardenMaster HQ ┃ Ready")
print("┃ " .. #GameData.seeds .. " seeds | " .. #GameData.gears .. " gears | "
    .. #GameData.crates .. " crates | " .. #GameData.pets .. " pets")
print("┃ Contributor: aditya44325f")
print(string.rep("━", 64))

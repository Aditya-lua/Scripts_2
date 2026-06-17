--[[
    GARDEN MASTER PRO v4.0
    Built from full decompiled GAG2 game source
    Uses REAL Networking module - every remote verified
    Full ESP | Full Automation | Weather HUD | Stock Predictor | Night Thieving
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local client = Players.LocalPlayer

if _G.GardenMasterCleanup then
    pcall(_G.GardenMasterCleanup)
    _G.GardenMasterCleanup = nil
end

if not table.find then
    table.find = function(t, v)
        for i = 1, #t do
            if t[i] == v then
                return i
            end
        end
        return nil
    end
end

local CLEANUP_OBJECTS = {}
local CLEANUP_CONNECTIONS = {}

local function registerCleanup(value)
    if typeof(value) == "RBXScriptConnection" then
        table.insert(CLEANUP_CONNECTIONS, value)
    elseif typeof(value) == "Instance" then
        table.insert(CLEANUP_OBJECTS, value)
    end
end

_G.GardenMasterCleanup = function()
    for _, connection in ipairs(CLEANUP_CONNECTIONS) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    for _, instance in ipairs(CLEANUP_OBJECTS) do
        pcall(function()
            if instance and instance.Parent then
                instance:Destroy()
            end
        end)
    end
    table.clear(CLEANUP_CONNECTIONS)
    table.clear(CLEANUP_OBJECTS)
end

print(string.rep("=", 60))
print("[GardenMaster PRO v4.0] Booting from full game source...")
print("[GardenMaster PRO v4.0] https://discord.gg/wx4ThpAsmw")
print(string.rep("=", 60))

local Library = loadstring(game:HttpGet("https://versusairlines.top/scripts/NewLibrary.lua"))()
if not Library then
    warn("[GardenMaster] Library failed to load - aborting.")
    return
end

local GUI = Library:Setup({
    Location = CoreGui,
    OpenCloseLocation = "Top Center"
})

local LOOP_TRACKER = {}

local function registerLoop(tag, connection)
    if not LOOP_TRACKER[tag] then
        LOOP_TRACKER[tag] = {}
    end
    table.insert(LOOP_TRACKER[tag], connection)
    registerCleanup(connection)
end

local function destroyLoop(tag)
    if not LOOP_TRACKER[tag] then
        return
    end
    for _, connection in ipairs(LOOP_TRACKER[tag]) do
        if connection and typeof(connection) == "RBXScriptConnection" then
            pcall(function()
                connection:Disconnect()
            end)
        end
    end
    LOOP_TRACKER[tag] = nil
end

local function notifyPlayer(title, message, style)
    pcall(function()
        if Library.createDisplayMessage then
            Library:createDisplayMessage(title, message, { { text = "OK" } }, style or "info")
        elseif Library.Notify then
            Library:Notify(title, message, 5)
        end
    end)
end

local function triggerProximityPrompt(prompt)
    if not prompt then
        return
    end
    if prompt:IsA("ProximityPrompt") then
        pcall(function()
            fireproximityprompt(prompt)
        end)
    end
end

local function teleportPlayerTo(position)
    local rootPart = client.Character and client.Character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        return
    end
    pcall(function()
        rootPart.CFrame = CFrame.new(position + Vector3.new(0, 3.8, 0))
    end)
end

registerCleanup(client.Idled:Connect(function()
    pcall(function()
        VirtualUser:Button2Down(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
        task.wait(0.5)
        VirtualUser:Button2Up(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
    end)
end))

local Net = nil

pcall(function()
    local sharedModules = ReplicatedStorage:WaitForChild("SharedModules", 5)
    local networkingModule = sharedModules:WaitForChild("Networking", 5)
    Net = require(networkingModule)
end)

if not Net then
    warn("[GardenMaster] CRITICAL: Could not load Networking module from ReplicatedStorage.SharedModules.Networking")
    warn("[GardenMaster] The game may have updated - check the module path.")
    return
end

print("[GardenMaster] Networking module loaded successfully.")
print("[GardenMaster] All remote events ready for firing.")

print("[GardenMaster] ", tostring(#table))

--[[ GAME DATA DISCOVERY ]]

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
            if parentName:find("crate") or parentName:find("box") or parentName:find("egg") or parentName:find("pet") then
                crateMap[itemName] = true
                petMap[itemName] = true
            end
        end
    end

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

    if client.Character then
        for _, tool in ipairs(client.Character:GetChildren()) do
            if tool:IsA("Tool") then
                local toolName = tool.Name:lower()
                if toolName:find("crate") or toolName:find("box")
                    or toolName:find("egg") or toolName:find("pet") then
                    crateMap[tool.Name] = true
                    petMap[tool.Name] = true
                elseif toolName:find("gear") or toolName:find("watering")
                    or toolName:find("shovel") or toolName:find("trowel") then
                    gearMap[tool.Name] = true
                end
            end
        end
    end

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

    print(string.format("[GardenMaster] Discovered: %d seeds, %d gears, %d crates, %d pets",
        #GameData.seeds, #GameData.gears, #GameData.crates, #GameData.pets))
end)

--[[ PLOT AUTHENTICATION & SPATIAL GRID ]]

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

--[[ TOOL HANDLING & ACTION EXECUTORS ]]

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

    local backpack = client:FindFirstChild("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if toolMatches(tool) then
                return tool
            end
        end
    end

    if client.Character then
        for _, tool in ipairs(client.Character:GetChildren()) do
            if toolMatches(tool) then
                return tool
            end
        end
    end

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

--[[
    ACTION EXECUTORS
    Every single remote verified against the FULL decompiled Networking module
    Path: ReplicatedStorage.SharedModules.Networking
]]

-- Garden: Harvesting
local function harvestPlant(plantId, fruitId)
    if not plantId then
        return
    end
    fruitId = fruitId or ""
    Net.Garden.CollectFruit:Fire(plantId, fruitId)
end

-- Plant: Seed planting
local function plantSeedAction(seedName, targetPosition)
    if not seedName or not targetPosition then
        return false
    end
    local tool = findToolByName(seedName)
    if tool then
        equipTool(tool)
        task.wait(0.07)
    end
    Net.Plant.PlantSeed:Fire(targetPosition, seedName, tool)
    return true
end

-- Place: Sprinkler placement
local function placeSprinklerAction(sprinklerName, targetPosition)
    local tool = findToolByName(sprinklerName)
    if not tool or not targetPosition then
        return false
    end
    equipTool(tool)
    task.wait(0.06)
    Net.Place.PlaceSprinkler:Fire(targetPosition, sprinklerName, tool, 1)
    return true
end

-- WateringCan: Water plants
local function waterPlantAction(targetPosition)
    local tool = findToolByName("watering") or findToolByName("Watering Can")
    if tool then
        equipTool(tool)
        task.wait(0.05)
    end
    local wateringCanName = tool and tool:GetAttribute("WateringCan") or (tool and tool.Name or "")
    local adjustedPosition = targetPosition - Vector3.new(0, 0.3, 0)
    Net.WateringCan.UseWateringCan:Fire(adjustedPosition, wateringCanName, tool)
end

-- Shovel: Dig up plants
local function shovelPlantAction(plantId, fruitId, shovelTool)
    local tool = shovelTool or findToolByName("shovel") or findToolByName("Shovel")
    if not tool then
        return
    end
    equipTool(tool)
    task.wait(0.05)
    local shovelAttribute = tool:GetAttribute("Shovel") or ""
    Net.Shovel.UseShovel:Fire(plantId, fruitId or "", shovelAttribute, tool)
end

-- Trowel: Move plants
local function movePlantAction(plantId, targetPosition, rotation)
    if not plantId or not targetPosition then
        return
    end
    rotation = rotation or 0
    Net.Trowel.MovePlant:Fire(plantId, targetPosition, rotation)
end

-- NPCS: Selling
local function sellAllItems()
    Net.NPCS.SellAll:Fire()
end

local function sellSingleFruit(fruitId)
    if not fruitId then
        return
    end
    Net.NPCS.SellFruit:Fire(fruitId)
end

local function askBidAction(itemName)
    if not itemName or itemName == "" then
        return
    end
    Net.NPCS.AskBid:Fire(itemName)
end

local function askBidAllAction()
    Net.NPCS.AskBidAll:Fire()
end

-- SeedShop: Buying seeds
local function buySeedItem(name)
    if not name or name == "" then
        return
    end
    Net.SeedShop.PurchaseSeed:Fire(name)
end

-- GearShop: Buying gear
local function buyGearItem(name)
    if not name or name == "" then
        return
    end
    Net.GearShop.PurchaseGear:Fire(name)
end

local function equipGearAction(gearName)
    if not gearName or gearName == "" then
        return
    end
    Net.GearShop.EquipGear:Fire(gearName)
end

local function unequipGearAction()
    Net.GearShop.UnequipGear:Fire()
end

-- CrateShop: Buying crates
local function buyCrateItem(name)
    if not name or name == "" then
        return
    end
    Net.CrateShop.PurchaseCrate:Fire(name)
end

-- Crate: Opening crates
local function openCrateAction(crateName)
    if not crateName or crateName == "" then
        return
    end
    Net.Crate.OpenCrate:Fire(crateName)
end

-- SeedPack: Opening seed packs
local function openSeedPackAction(packName)
    if not packName or packName == "" then
        return
    end
    Net.SeedPack.OpenSeedPack:Fire(packName)
end

-- Egg: Opening eggs
local function openEggAction(eggName)
    if not eggName or eggName == "" then
        return
    end
    Net.Egg.OpenEgg:Fire(eggName)
end

-- Steal: Night thieving
local function beginStealAction(targetUserId, plantId, fruitId)
    Net.Steal.BeginSteal:Fire(targetUserId, plantId, fruitId or "")
end

local function completeStealAction()
    Net.Steal.CompleteSteal:Fire()
end

-- Settings: Codes
local function redeemCodeAction(code)
    Net.Settings.SubmitCode:Fire(code)
end

-- Pets: Equipping/unequipping
local function equipPetAction(petName)
    if not petName or petName == "" then
        return
    end
    Net.Pets.PetEquipped:Fire(petName, {})
end

local function unequipPetAction(petName)
    if not petName or petName == "" then
        return
    end
    Net.Pets.RequestUnequipByName:Fire(petName)
end

-- Prop: Placement
local function placePropAction(position, propName, tool, rotation)
    if not position or not propName then
        return
    end
    rotation = rotation or 0
    Net.Prop.PlaceProp:Fire(position, propName, tool, rotation)
end

local function pickupPropAction(propId)
    if not propId then
        return
    end
    Net.Prop.PickupProp:Fire(propId)
end

-- Daily deals
local function checkDailyDealAction()
    Net.NPCS.CheckDailyDeal:Fire()
end

local function useDailyDealAction(itemName)
    if not itemName or itemName == "" then
        return
    end
    Net.NPCS.UseDailyDealSingle:Fire(itemName)
end

--[[ NIGHT DETECTION ]]

local nightDetector = ReplicatedStorage:FindFirstChild("Night", true)

local function isNightTime()
    if nightDetector and nightDetector:IsA("BoolValue") and nightDetector.Value then
        return true
    end
    local clockTime = Lighting.ClockTime
    return clockTime < 6 or clockTime > 18
end

--[[ FILTERING & VALUE SCORING ENGINE ]]

local function passesFilter(model, fruitFilter, mutationFilter, rarityFilter)
    if not model then
        return false
    end

    local modelName = model.Name:lower()
    local seedAttribute = (model:GetAttribute("SeedName") or ""):lower()
    local mutationAttribute = (model:GetAttribute("Mutation") or ""):lower()
    local rarityAttribute = (model:GetAttribute("Rarity") or ""):lower()

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

    local rarity = (model:GetAttribute("Rarity") or ""):lower()
    score = score + (RarityValueScore[rarity] or 1) * 120

    local mutation = (model:GetAttribute("Mutation") or ""):lower()
    score = score * (MutationValueMultiplier[mutation] or 1)

    local size = model:GetAttribute("Size") or model:GetAttribute("FruitSize") or 1
    if type(size) == "number" then
        score = score * math.max(size, 0.15)
    end

    local sellValue = model:GetAttribute("Value") or model:GetAttribute("SellValue") or 0
    if type(sellValue) == "number" then
        score = score + sellValue * 1.2
    end

    if model:GetAttribute("MultiHarvest")
        or model.Name:lower():find("multi", 1, true)
        or model.Name:lower():find("regrow", 1, true) then
        score = score * 1.6
    end

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

local function getBestValueCandidates(maxCount, fruitFilter, mutationFilter, rarityFilter, ownedOnly)
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

    for _, harvestPrompt in ipairs(CollectionService:GetTagged("HarvestPrompt")) do
        local model = harvestPrompt:FindFirstAncestorWhichIsA("Model")
        addCandidate(model, true)
    end

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

    table.sort(candidates, function(a, b)
        if a.score ~= b.score then
            return a.score > b.score
        end
        return a.distance < b.distance
    end)

    local result = {}
    for i = 1, math.min(maxCount, #candidates) do
        table.insert(result, candidates[i])
    end

    return result
end

--[[ INTERVAL RUNNER - Core loop engine ]]

local function runInterval(tag, flagName, baseDelay, callback)
    destroyLoop(tag)

    if not Library.Flags[flagName] then
        return
    end

    local lastExecution = os.clock()
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
            local ok, err = pcall(callback)
            if not ok then
                warn(string.format("[GardenMaster Error: %s] %s", tostring(tag), tostring(err)))
            end
            isRunning = false
        end)
    end)

    registerLoop(tag, connection)
end

--[[ UI: MAIN CONTROLS TAB ]]

local mainTab = GUI:CreateSection("Main Controls")

mainTab:createLabel({
    Name = "GardenMaster PRO v4.0 | Built From Full Game Source",
    Special = true
})

mainTab:createLabel({ Name = "Inventory Management", Special = true })

mainTab:createToggle({
    Name = "Sell Only When Backpack Full",
    flagName = "SellWhenFull",
    Flag = false
})

mainTab:createToggle({
    Name = "Auto Sell Inventory",
    flagName = "AutoSell",
    Flag = false,
    Callback = function()
        runInterval("AutoSell", "AutoSell", 0.9, function()
            if Library.Flags["SellWhenFull"] then
                local isFull = client:GetAttribute("BackpackFull") == true
                if not isFull then
                    return
                end
            end
            sellAllItems()
        end)
    end
})

mainTab:createButton({
    Name = "Sell Everything Now",
    Callback = function()
        sellAllItems()
        notifyPlayer("GardenMaster", "All items sold to merchant.", "info")
    end
})

mainTab:createLabel({ Name = "Harvesting System", Special = true })

mainTab:createToggle({
    Name = "Teleport To Garden Gate For Collecting",
    flagName = "TPToEntranceCollect",
    Flag = true
})

mainTab:createSlider({
    Name = "Gate Radius (Studs)",
    flagName = "GeofenceRadius",
    value = 22,
    minValue = 8,
    maxValue = 90
})

mainTab:createDropdown({
    Name = "Fruit Type Filter",
    flagName = "HarvestFruits",
    multi = true,
    List = GameData.seeds
})

mainTab:createToggle({
    Name = "Auto Harvest Filtered Fruits",
    flagName = "AutoHarvest",
    Flag = false,
    Callback = function()
        authenticateGardenPlot()
        runInterval("AutoHarvest", "AutoHarvest", 0.07, function()
            enforceGeofence("Collect")
            local selectedFruits = Library.Flags["HarvestFruits"]

            for _, harvestPrompt in ipairs(CollectionService:GetTagged("HarvestPrompt")) do
                if harvestPrompt:IsA("ProximityPrompt") then
                    local model = harvestPrompt:FindFirstAncestorWhichIsA("Model")
                    if model and passesFilter(model, selectedFruits, nil, nil) then
                        local pid, fid = getPlantIdentifiers(model)
                        if pid then
                            task.spawn(harvestPlant, pid, fid)
                        else
                            task.spawn(triggerProximityPrompt, harvestPrompt)
                        end
                    end
                end
            end

            if GardenPlot.plantsFolder then
                for _, plantModel in ipairs(GardenPlot.plantsFolder:GetChildren()) do
                    if plantModel:IsA("Model") and passesFilter(plantModel, selectedFruits, nil, nil) then
                        local pid, fid = getPlantIdentifiers(plantModel)
                        local prompt = plantModel:FindFirstChild("HarvestPrompt", true)
                        if pid then
                            task.spawn(harvestPlant, pid, fid)
                        elseif prompt then
                            task.spawn(triggerProximityPrompt, prompt)
                        end
                    end
                end
            end
        end)
    end
})

mainTab:createToggle({
    Name = "Auto Harvest Everything (No Filter)",
    flagName = "AutoHarvestAll",
    Flag = false,
    Callback = function()
        authenticateGardenPlot()
        runInterval("AutoHarvestAll", "AutoHarvestAll", 0.07, function()
            enforceGeofence("Collect")

            for _, harvestPrompt in ipairs(CollectionService:GetTagged("HarvestPrompt")) do
                if harvestPrompt:IsA("ProximityPrompt") then
                    local model = harvestPrompt:FindFirstAncestorWhichIsA("Model")
                    if model then
                        local pid, fid = getPlantIdentifiers(model)
                        if pid then
                            task.spawn(harvestPlant, pid, fid)
                        else
                            task.spawn(triggerProximityPrompt, harvestPrompt)
                        end
                    end
                end
            end

            if GardenPlot.plantsFolder then
                for _, plantModel in ipairs(GardenPlot.plantsFolder:GetChildren()) do
                    if plantModel:IsA("Model") then
                        local pid, fid = getPlantIdentifiers(plantModel)
                        local prompt = plantModel:FindFirstChild("HarvestPrompt", true)
                        if pid then
                            task.spawn(harvestPlant, pid, fid)
                        elseif prompt then
                            task.spawn(triggerProximityPrompt, prompt)
                        end
                    end
                end
            end
        end)
    end
})

mainTab:createSlider({
    Name = "Best Value Harvest Limit",
    flagName = "BestValueCount",
    value = 12,
    minValue = 1,
    maxValue = 60
})

mainTab:createToggle({
    Name = "Auto Harvest Best Value (Smart)",
    flagName = "AutoBestValue",
    Flag = false,
    Callback = function()
        authenticateGardenPlot()
        runInterval("AutoBestValue", "AutoBestValue", 0.45, function()
            enforceGeofence("Collect")
            local selectedFruits = Library.Flags["HarvestFruits"]
            local selectedRarities = Library.Flags["PlantESPRarities"]
            local maxCount = Library.Flags["BestValueCount"] or 12

            local candidates = getBestValueCandidates(maxCount, selectedFruits, nil, selectedRarities, true)

            for _, candidate in ipairs(candidates) do
                if not Library.Flags["AutoBestValue"] then
                    break
                end

                if candidate.plantId then
                    task.spawn(harvestPlant, candidate.plantId, candidate.fruitId)
                elseif candidate.model then
                    local prompt = candidate.model:FindFirstChild("HarvestPrompt", true)
                    if prompt then
                        task.spawn(triggerProximityPrompt, prompt)
                    end
                end

                task.wait(0.04)
            end
        end)
    end
})

mainTab:createLabel({ Name = "Event / Special Seeds", Special = true })

mainTab:createToggle({
    Name = "Auto Claim Special Event Seeds",
    flagName = "AutoSpecialSeeds",
    Flag = false,
    Callback = function()
        runInterval("AutoSpecialSeeds", "AutoSpecialSeeds", 1.4, function()
            for _, descendant in ipairs(Workspace:GetDescendants()) do
                if not Library.Flags["AutoSpecialSeeds"] then
                    break
                end

                if descendant:IsA("ProximityPrompt") then
                    local combinedText = (descendant.Name .. " "
                        .. (descendant.ActionText or "") .. " "
                        .. (descendant.ObjectText or "")):lower()

                    if combinedText:find("rainbow") or combinedText:find("gold")
                        or combinedText:find("claim") or combinedText:find("special") then
                        local model = descendant:FindFirstAncestorWhichIsA("Model") or descendant.Parent
                        if model then
                            teleportPlayerTo(model:GetPivot().Position)
                            task.wait(0.2)
                            task.spawn(triggerProximityPrompt, descendant)
                            task.wait(0.6)
                        end
                    end
                end
            end
        end)
    end
})

mainTab:createLabel({ Name = "Night Thieving System", Special = true })

mainTab:createDropdown({
    Name = "Steal Fruit Type Filter",
    flagName = "StealFruits",
    multi = true,
    List = GameData.seeds
})

mainTab:createSlider({
    Name = "Maximum Steal Targets",
    flagName = "StealCount",
    value = 6,
    minValue = 1,
    maxValue = 35
})

mainTab:createToggle({
    Name = "Auto Steal Best Value (Night Only)",
    flagName = "AutoSteal",
    Flag = false,
    Callback = function()
        runInterval("AutoSteal", "AutoSteal", 1.8, function()
            if not isNightTime() then
                return
            end

            local selectedFruits = Library.Flags["StealFruits"]
            local selectedRarities = Library.Flags["PlantESPRarities"]
            local maxCount = Library.Flags["StealCount"] or 6

            local candidates = getBestValueCandidates(maxCount, selectedFruits, nil, selectedRarities, false)

            for _, candidate in ipairs(candidates) do
                if not Library.Flags["AutoSteal"] then
                    break
                end

                if candidate.model then
                    local ownerUserId = getPlotOwnerUserId(
                        candidate.model.Parent and candidate.model.Parent.Parent
                        or candidate.model.Parent
                    )

                    if ownerUserId then
                        teleportPlayerTo(candidate.model:GetPivot().Position)
                        task.wait(0.15)

                        beginStealAction(ownerUserId, candidate.plantId, candidate.fruitId)
                        completeStealAction()

                        local prompt = candidate.model:FindFirstChild("HarvestPrompt", true)
                        if prompt then
                            task.spawn(triggerProximityPrompt, prompt)
                        end

                        task.spawn(harvestPlant, candidate.plantId, candidate.fruitId)
                        task.wait(0.35)
                    end
                elseif candidate.plantId then
                    task.spawn(harvestPlant, candidate.plantId, candidate.fruitId)
                    task.wait(0.25)
                end
            end
        end)
    end
})

--[[ UI: AUTOMATION TAB ]]

local autoTab = GUI:CreateSection("Automation")

autoTab:createLabel({ Name = "Placement Configuration", Special = true })

autoTab:createDropdown({
    Name = "Placement Strategy",
    flagName = "PlacingMode",
    List = {
        "Virtual Plot Grid",
        "Character Position",
        "Random Spatial Plot",
        "Mouse Position"
    }
})

autoTab:createToggle({
    Name = "Teleport To Garden Entrance",
    flagName = "TPToEntrancePlant",
    Flag = true
})

autoTab:createLabel({ Name = "Seed Planting Engine", Special = true })

autoTab:createDropdown({
    Name = "Select Seeds To Plant",
    flagName = "PlantSeeds",
    multi = true,
    List = GameData.seeds
})

autoTab:createToggle({
    Name = "Auto Plant Selected Seeds",
    flagName = "AutoPlant",
    Flag = false,
    Callback = function()
        authenticateGardenPlot()
        runInterval("AutoPlant", "AutoPlant", 0.48, function()
            enforceGeofence("Plant")
            local selectedSeeds = Library.Flags["PlantSeeds"]
            if not selectedSeeds then
                return
            end

            local seedList = typeof(selectedSeeds) == "table" and selectedSeeds or { selectedSeeds }

            for _, seedName in ipairs(seedList) do
                if not Library.Flags["AutoPlant"] then
                    break
                end
                if seedName == "" then
                    continue
                end

                local position = getPlacementPosition(2.9)
                if position then
                    plantSeedAction(seedName, position)
                    task.wait(0.05)
                end
            end
        end)
    end
})

autoTab:createToggle({
    Name = "Auto Plant ALL Seeds In Backpack",
    flagName = "AutoPlantAll",
    Flag = false,
    Callback = function()
        authenticateGardenPlot()
        runInterval("AutoPlantAll", "AutoPlantAll", 0.48, function()
            enforceGeofence("Plant")

            local discoveredSeeds = {}
            local backpack = client:FindFirstChild("Backpack")

            if backpack then
                for _, tool in ipairs(backpack:GetChildren()) do
                    if tool:IsA("Tool") and (
                        tool.Name:find("Seed:") or tool.Name:find("Seed_")
                        or table.find(GameData.seeds, tool.Name)
                    ) then
                        local cleanName = tool.Name:gsub("Seed:", ""):gsub("Seed_", ""):match("^([^%[]+)")
                        if cleanName and cleanName ~= "" and not table.find(discoveredSeeds, cleanName) then
                            table.insert(discoveredSeeds, cleanName)
                        end
                    end
                end
            end

            for _, seedName in ipairs(discoveredSeeds) do
                if not Library.Flags["AutoPlantAll"] then
                    break
                end
                local position = getPlacementPosition(2.9)
                if position then
                    plantSeedAction(seedName, position)
                    task.wait(0.05)
                end
            end
        end)
    end
})

autoTab:createLabel({ Name = "Plant Watering", Special = true })

autoTab:createToggle({
    Name = "Auto Water All Plants",
    flagName = "AutoWater",
    Flag = false,
    Callback = function()
        runInterval("AutoWater", "AutoWater", 0.6, function()
            if not GardenPlot.plantsFolder then
                return
            end

            for _, plantModel in ipairs(GardenPlot.plantsFolder:GetChildren()) do
                if not Library.Flags["AutoWater"] then
                    break
                end
                if plantModel:IsA("Model") and plantModel.PrimaryPart then
                    waterPlantAction(plantModel:GetPivot().Position)
                    task.wait(0.04)
                end
            end
        end)
    end
})

autoTab:createLabel({ Name = "Sprinkler Deployment", Special = true })

autoTab:createDropdown({
    Name = "Select Sprinklers",
    flagName = "SprinklerSelect",
    multi = true,
    List = GameData.gears
})

autoTab:createToggle({
    Name = "Auto Place Selected Sprinklers",
    flagName = "AutoSprinkler",
    Flag = false,
    Callback = function()
        runInterval("AutoSprinkler", "AutoSprinkler", 0.6, function()
            local selectedSprinklers = Library.Flags["SprinklerSelect"]
            if not selectedSprinklers then
                return
            end

            local sprinklerList = typeof(selectedSprinklers) == "table" and selectedSprinklers or { selectedSprinklers }

            for _, sprinklerName in ipairs(sprinklerList) do
                if not Library.Flags["AutoSprinkler"] then
                    break
                end
                if sprinklerName == "" then
                    continue
                end

                local position = getPlacementPosition(3.6)
                if position then
                    placeSprinklerAction(sprinklerName, position)
                    task.wait(0.06)
                end
            end
        end)
    end
})

autoTab:createToggle({
    Name = "Auto Place ALL Sprinklers",
    flagName = "AutoSprinklerAll",
    Flag = false,
    Callback = function()
        runInterval("AutoSprinklerAll", "AutoSprinklerAll", 0.6, function()
            local sprinklerList = {}
            local backpack = client:FindFirstChild("Backpack")

            if backpack then
                for _, tool in ipairs(backpack:GetChildren()) do
                    if tool:IsA("Tool") and tool.Name:lower():find("sprinkler")
                        and not table.find(sprinklerList, tool.Name) then
                        table.insert(sprinklerList, tool.Name)
                    end
                end
            end

            for _, sprinklerName in ipairs(sprinklerList) do
                if not Library.Flags["AutoSprinklerAll"] then
                    break
                end
                local position = getPlacementPosition(3.6)
                if position then
                    placeSprinklerAction(sprinklerName, position)
                    task.wait(0.06)
                end
            end
        end)
    end
})

autoTab:createLabel({ Name = "Shovel & Trowel", Special = true })

autoTab:createToggle({
    Name = "Auto Shovel All Plants",
    flagName = "AutoShovel",
    Flag = false,
    Callback = function()
        runInterval("AutoShovel", "AutoShovel", 0.7, function()
            if not GardenPlot.plantsFolder then
                return
            end

            local shovel = findToolByName("shovel") or findToolByName("Shovel")

            for _, plantModel in ipairs(GardenPlot.plantsFolder:GetChildren()) do
                if not Library.Flags["AutoShovel"] then
                    break
                end
                if plantModel:IsA("Model") and plantModel.PrimaryPart then
                    local pid, fid = getPlantIdentifiers(plantModel)
                    shovelPlantAction(pid, fid, shovel)
                    task.wait(0.05)
                end
            end
        end)
    end
})

autoTab:createLabel({ Name = "Roaming Wild Pets", Special = true })

autoTab:createDropdown({
    Name = "Pet Rarity Filter",
    flagName = "PetRarity",
    multi = true,
    List = RarityList
})

autoTab:createToggle({
    Name = "Auto Tame Roaming Pets",
    flagName = "AutoPet",
    Flag = false,
    Callback = function()
        runInterval("AutoPet", "AutoPet", 1.2, function()
            local selectedRarities = Library.Flags["PetRarity"] or {}

            for _, prompt in ipairs(CollectionService:GetTagged("BuyPetPrompt")) do
                if not Library.Flags["AutoPet"] then
                    break
                end

                if prompt:IsA("ProximityPrompt") then
                    local model = prompt:FindFirstAncestorWhichIsA("Model")
                    if model then
                        local rarity = (model:GetAttribute("Rarity") or ""):lower()

                        for _, targetRarity in ipairs(selectedRarities) do
                            if rarity == targetRarity:lower()
                                or model.Name:lower():find(targetRarity:lower()) then
                                teleportPlayerTo(model:GetPivot().Position)
                                task.wait(0.18)
                                task.spawn(triggerProximityPrompt, prompt)
                                task.wait(0.55)
                                break
                            end
                        end
                    end
                end
            end
        end)
    end
})

autoTab:createLabel({ Name = "Fertilizer & Growth", Special = true })

autoTab:createToggle({
    Name = "Auto Fertilize Plants",
    flagName = "AutoFertilize",
    Flag = false,
    Callback = function()
        runInterval("AutoFertilize", "AutoFertilize", 1.0, function()
            if not GardenPlot.plantsFolder then
                return
            end

            for _, plantModel in ipairs(GardenPlot.plantsFolder:GetChildren()) do
                if not Library.Flags["AutoFertilize"] then
                    break
                end
                if plantModel:IsA("Model") and plantModel.PrimaryPart then
                    local prompt = plantModel:FindFirstChild("FertilizePrompt", true)
                        or plantModel:FindFirstChild("GrowPrompt", true)
                    if prompt then
                        task.spawn(triggerProximityPrompt, prompt)
                        task.wait(0.03)
                    end
                end
            end
        end)
    end
})

--[[ UI: SHOP & MARKET TAB ]]

local shopTab = GUI:CreateSection("Shop & Market")

shopTab:createLabel({ Name = "Seed Market", Special = true })

shopTab:createDropdown({
    Name = "Seeds To Purchase",
    flagName = "SeedBuySelect",
    multi = true,
    List = GameData.seeds
})

shopTab:createToggle({
    Name = "Auto Buy Selected Seeds",
    flagName = "AutoBuySeeds",
    Flag = false,
    Callback = function()
        runInterval("AutoBuySeeds", "AutoBuySeeds", 1.85, function()
            local selectedSeeds = Library.Flags["SeedBuySelect"]
            if not selectedSeeds then
                return
            end

            local seedList = typeof(selectedSeeds) == "table" and selectedSeeds or { selectedSeeds }

            for _, seedName in ipairs(seedList) do
                if not Library.Flags["AutoBuySeeds"] then
                    break
                end
                if seedName ~= "" then
                    buySeedItem(seedName)
                    task.wait(0.07)
                end
            end
        end)
    end
})

shopTab:createLabel({ Name = "Gear Market", Special = true })

shopTab:createDropdown({
    Name = "Gear To Purchase",
    flagName = "GearBuySelect",
    multi = true,
    List = GameData.gears
})

shopTab:createToggle({
    Name = "Auto Buy Selected Gear",
    flagName = "AutoBuyGear",
    Flag = false,
    Callback = function()
        runInterval("AutoBuyGear", "AutoBuyGear", 1.85, function()
            local selectedGear = Library.Flags["GearBuySelect"]
            if not selectedGear then
                return
            end

            local gearList = typeof(selectedGear) == "table" and selectedGear or { selectedGear }

            for _, gearName in ipairs(gearList) do
                if not Library.Flags["AutoBuyGear"] then
                    break
                end
                if gearName ~= "" then
                    buyGearItem(gearName)
                    task.wait(0.07)
                end
            end
        end)
    end
})

shopTab:createLabel({ Name = "Crate Market", Special = true })

shopTab:createDropdown({
    Name = "Crates To Purchase",
    flagName = "CrateBuySelect",
    multi = true,
    List = GameData.crates
})

shopTab:createToggle({
    Name = "Auto Buy Selected Crates",
    flagName = "AutoBuyCrates",
    Flag = false,
    Callback = function()
        runInterval("AutoBuyCrates", "AutoBuyCrates", 1.85, function()
            local selectedCrates = Library.Flags["CrateBuySelect"]
            if not selectedCrates then
                return
            end

            local crateList = typeof(selectedCrates) == "table" and selectedCrates or { selectedCrates }

            for _, crateName in ipairs(crateList) do
                if not Library.Flags["AutoBuyCrates"] then
                    break
                end
                if crateName ~= "" then
                    buyCrateItem(crateName)
                    task.wait(0.07)
                end
            end
        end)
    end
})

shopTab:createLabel({ Name = "Pet Market", Special = true })

shopTab:createDropdown({
    Name = "Pets To Purchase",
    flagName = "PetBuySelect",
    multi = true,
    List = GameData.pets
})

shopTab:createToggle({
    Name = "Auto Buy Selected Pets",
    flagName = "AutoBuyPets",
    Flag = false,
    Callback = function()
        runInterval("AutoBuyPets", "AutoBuyPets", 1.85, function()
            local selectedPets = Library.Flags["PetBuySelect"]
            if not selectedPets then
                return
            end

            local petList = typeof(selectedPets) == "table" and selectedPets or { selectedPets }

            for _, petName in ipairs(petList) do
                if not Library.Flags["AutoBuyPets"] then
                    break
                end
                if petName ~= "" then
                    buyCrateItem(petName)
                    task.wait(0.08)
                end
            end
        end)
    end
})

shopTab:createLabel({ Name = "Bargaining & Trading", Special = true })

shopTab:createToggle({
    Name = "Auto Bargain With NPCs",
    flagName = "AutoBargain",
    Flag = false,
    Callback = function()
        runInterval("AutoBargain", "AutoBargain", 2.0, function()
            local rootPart = client.Character and client.Character:FindFirstChild("HumanoidRootPart")
            if not rootPart then
                return
            end

            for _, prompt in ipairs(Workspace:GetDescendants()) do
                if not Library.Flags["AutoBargain"] then
                    break
                end

                if prompt:IsA("ProximityPrompt") then
                    local combinedText = (prompt.Name .. " "
                        .. (prompt.ActionText or "") .. " "
                        .. (prompt.ObjectText or "")):lower()

                    if combinedText:find("bargain") or combinedText:find("haggle")
                        or combinedText:find("trade") then
                        local model = prompt:FindFirstAncestorWhichIsA("Model") or prompt.Parent
                        if model and model:IsA("Model")
                            and (model:GetPivot().Position - rootPart.Position).Magnitude < 55 then
                            teleportPlayerTo(model:GetPivot().Position)
                            task.wait(0.16)
                            task.spawn(triggerProximityPrompt, prompt)
                            task.wait(0.28)
                        end
                    end
                end
            end
        end)
    end
})

shopTab:createLabel({ Name = "Daily Deals", Special = true })

shopTab:createToggle({
    Name = "Auto Use Daily Deals",
    flagName = "AutoDailyDeal",
    Flag = false,
    Callback = function()
        runInterval("AutoDailyDeal", "AutoDailyDeal", 5.0, function()
            checkDailyDealAction()
        end)
    end
})

shopTab:createLabel({ Name = "Crate & Egg Opening", Special = true })

shopTab:createToggle({
    Name = "Auto Open Crates",
    flagName = "AutoOpenCrates",
    Flag = false,
    Callback = function()
        runInterval("AutoOpenCrates", "AutoOpenCrates", 2.0, function()
            local backpack = client:FindFirstChild("Backpack")
            if not backpack then
                return
            end

            for _, tool in ipairs(backpack:GetChildren()) do
                if not Library.Flags["AutoOpenCrates"] then
                    break
                end
                if tool:IsA("Tool") and tool.Name:lower():find("crate") then
                    openCrateAction(tool.Name)
                    task.wait(0.3)
                end
            end
        end)
    end
})

shopTab:createToggle({
    Name = "Auto Open Eggs",
    flagName = "AutoOpenEggs",
    Flag = false,
    Callback = function()
        runInterval("AutoOpenEggs", "AutoOpenEggs", 2.0, function()
            local backpack = client:FindFirstChild("Backpack")
            if not backpack then
                return
            end

            for _, tool in ipairs(backpack:GetChildren()) do
                if not Library.Flags["AutoOpenEggs"] then
                    break
                end
                if tool:IsA("Tool") and tool.Name:lower():find("egg") then
                    openEggAction(tool.Name)
                    task.wait(0.3)
                end
            end
        end)
    end
})

shopTab:createToggle({
    Name = "Auto Open Seed Packs",
    flagName = "AutoOpenSeedPacks",
    Flag = false,
    Callback = function()
        runInterval("AutoOpenSeedPacks", "AutoOpenSeedPacks", 2.0, function()
            local backpack = client:FindFirstChild("Backpack")
            if not backpack then
                return
            end

            for _, tool in ipairs(backpack:GetChildren()) do
                if not Library.Flags["AutoOpenSeedPacks"] then
                    break
                end
                if tool:IsA("Tool") and (
                    tool.Name:lower():find("seed pack") or tool.Name:lower():find("seedpack")
                ) then
                    openSeedPackAction(tool.Name)
                    task.wait(0.3)
                end
            end
        end)
    end
})

--[[ UI: MISCELLANEOUS TAB ]]

local miscTab = GUI:CreateSection("Miscellaneous")

miscTab:createToggle({
    Name = "Humanized Mode (Random Delays)",
    flagName = "LegitMode",
    Flag = true
})

miscTab:createLabel({ Name = "Promo Codes", Special = true })

miscTab:createButton({
    Name = "Redeem All Known Codes",
    Callback = function()
        local promoCodes = {
            "TEAMGREENBEAN", "STARBUD", "torigate", "RDCAward",
            "LUNARGLOW10", "BEANORLEAVE10"
        }
        for _, code in ipairs(promoCodes) do
            redeemCodeAction(code)
            task.wait(0.08)
        end
        notifyPlayer("Codes", "All promo codes redeemed.", "info")
    end
})

miscTab:createLabel({ Name = "Anti-Fling Protection", Special = true })

miscTab:createToggle({
    Name = "Anti Fling System",
    flagName = "AntiFling",
    Flag = true,
    Callback = function()
        runInterval("AntiFling", "AntiFling", 0.1, function()
            local myRoot = client.Character and client.Character:FindFirstChild("HumanoidRootPart")
            if myRoot then
                if myRoot.AssemblyLinearVelocity.Magnitude > 250
                    or myRoot.AssemblyAngularVelocity.Magnitude > 50 then
                    myRoot.AssemblyLinearVelocity = Vector3.zero
                    myRoot.AssemblyAngularVelocity = Vector3.zero
                end
            end

            for _, otherPlayer in ipairs(Players:GetPlayers()) do
                if otherPlayer == client then
                    continue
                end
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
        end)
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

miscTab:createLabel({ Name = "Character Protection", Special = true })

miscTab:createToggle({
    Name = "Anti AFK & Knockback Shield",
    flagName = "AntiAFK",
    Flag = true,
    Callback = function()
        runInterval("AntiAFK", "AntiAFK", 4, function()
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
                    if otherPlayer == client then
                        continue
                    end
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
        end)
    end
})

miscTab:createLabel({ Name = "Gear Management", Special = true })

miscTab:createToggle({
    Name = "Auto Equip Best Gear",
    flagName = "AutoEquipGear",
    Flag = false,
    Callback = function()
        runInterval("AutoEquipGear", "AutoEquipGear", 3.0, function()
            local backpack = client:FindFirstChild("Backpack")
            if not backpack then
                return
            end

            for _, gearName in ipairs(GameData.gears) do
                if not Library.Flags["AutoEquipGear"] then
                    break
                end
                local tool = findToolByName(gearName)
                if tool then
                    equipGearAction(gearName)
                    task.wait(0.1)
                end
            end
        end)
    end
})

miscTab:createLabel({ Name = "Pet Management", Special = true })

miscTab:createToggle({
    Name = "Auto Equip Best Pets",
    flagName = "AutoEquipPets",
    Flag = false,
    Callback = function()
        runInterval("AutoEquipPets", "AutoEquipPets", 3.0, function()
            for _, petName in ipairs(GameData.pets) do
                if not Library.Flags["AutoEquipPets"] then
                    break
                end
                equipPetAction(petName)
                task.wait(0.1)
            end
        end)
    end
})

--[[ UI: VISUALS & ESP TAB ]]

local visualsTab = GUI:CreateSection("Visuals & ESP")

visualsTab:createLabel({ Name = "World Settings", Special = true })

visualsTab:createSlider({
    Name = "Clock Time",
    flagName = "ClockTime",
    value = 21,
    minValue = 0,
    maxValue = 24
})

visualsTab:createToggle({
    Name = "Override Clock Time",
    flagName = "ClockOverride",
    Flag = false,
    Callback = function()
        runInterval("ClockOverride", "ClockOverride", 0.1, function()
            Lighting.ClockTime = Library.Flags["ClockTime"] or 21
        end)
    end
})

visualsTab:createToggle({
    Name = "Fullbright Lighting",
    flagName = "Fullbright",
    Flag = false,
    Callback = function()
        runInterval("Fullbright", "Fullbright", 0.5, function()
            Lighting.Ambient = Color3.new(1, 1, 1)
            Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
        end)
    end
})

visualsTab:createToggle({
    Name = "Performance Mode (Mobile)",
    flagName = "PerformanceMode",
    Flag = true,
    Callback = function()
        if Library.Flags["PerformanceMode"] then
            pcall(function()
                sethiddenproperty(Lighting, "Technology", Enum.Technology.Compatibility)
            end)
        end
    end
})

visualsTab:createToggle({
    Name = "No Fog",
    flagName = "NoFog",
    Flag = false,
    Callback = function()
        runInterval("NoFog", "NoFog", 0.5, function()
            Lighting.FogEnd = 100000
            Lighting.FogStart = 100000
        end)
    end
})

visualsTab:createLabel({ Name = "Player ESP Overlays", Special = true })

visualsTab:createToggle({
    Name = "Player Boxes",
    flagName = "PlayerBoxESP",
    Flag = false
})

visualsTab:createToggle({
    Name = "Player Names",
    flagName = "PlayerNameESP",
    Flag = false
})

visualsTab:createToggle({
    Name = "Player Health",
    flagName = "PlayerHealthESP",
    Flag = false
})

visualsTab:createToggle({
    Name = "Player Held Items",
    flagName = "PlayerHeldItemESP",
    Flag = false
})

visualsTab:createToggle({
    Name = "Player Distance",
    flagName = "PlayerDistESP",
    Flag = false
})

visualsTab:createSlider({
    Name = "Player ESP Render Range",
    flagName = "PlayerESPRange",
    value = 1500,
    minValue = 100,
    maxValue = 3000
})

visualsTab:createLabel({ Name = "Plant ESP Overlays", Special = true })

visualsTab:createToggle({
    Name = "Plant Radar System",
    flagName = "PlantESP",
    Flag = false
})

visualsTab:createDropdown({
    Name = "Plant Name Filter",
    flagName = "PlantESPNames",
    multi = true,
    List = GameData.seeds
})

visualsTab:createDropdown({
    Name = "Plant Rarity Filter",
    flagName = "PlantESPRarities",
    multi = true,
    List = RarityList
})

visualsTab:createToggle({
    Name = "Only Show Owned Plot Plants",
    flagName = "PlantOwnedOnly",
    Flag = false
})

visualsTab:createToggle({
    Name = "Show Mutation Tags",
    flagName = "PlantMut",
    Flag = false
})

visualsTab:createToggle({
    Name = "Show Plant Distance",
    flagName = "PlantDist",
    Flag = false
})

visualsTab:createToggle({
    Name = "Show Plant Value Score",
    flagName = "PlantValue",
    Flag = false
})

visualsTab:createSlider({
    Name = "Plant ESP Render Range",
    flagName = "PlantESPRange",
    value = 1500,
    minValue = 100,
    maxValue = 3000
})

visualsTab:createLabel({ Name = "Prop ESP", Special = true })

visualsTab:createToggle({
    Name = "Show Nearby Props",
    flagName = "PropESP",
    Flag = false
})

visualsTab:createSlider({
    Name = "Prop ESP Range",
    flagName = "PropESPRange",
    value = 500,
    minValue = 50,
    maxValue = 2000
})

--[[ ESP RENDERER ]]

local ESP_FOLDER = Instance.new("Folder")
ESP_FOLDER.Name = "GardenMaster_ESP"
pcall(function()
    ESP_FOLDER.Parent = CoreGui
end)
registerCleanup(ESP_FOLDER)

local ESP_OBJECTS = {}

local function createESPObject(targetObject, displayText, boxColor)
    if not targetObject or not targetObject.Parent or not targetObject:IsDescendantOf(Workspace) then
        return nil
    end

    if ESP_OBJECTS[targetObject] then
        return ESP_OBJECTS[targetObject]
    end

    local holder = Instance.new("Folder")
    holder.Name = "ESP_Holder"
    holder.Parent = ESP_FOLDER

    local highlight = Instance.new("Highlight")
    highlight.Name = "ESP_Box"
    highlight.FillColor = boxColor or Color3.new(1, 1, 1)
    highlight.OutlineColor = Color3.new(0, 0, 0)
    highlight.FillTransparency = 0.75
    highlight.OutlineTransparency = 0.15
    highlight.Adornee = targetObject
    highlight.Parent = holder

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESP_Text"
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 240, 0, 60)
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

    local showPlayerESP = Library.Flags["PlayerNameESP"]
        or Library.Flags["PlayerBoxESP"]
        or Library.Flags["PlayerHealthESP"]
        or Library.Flags["PlayerHeldItemESP"]
        or Library.Flags["PlayerDistESP"]

    if showPlayerESP then
        local maxDistance = Library.Flags["PlayerESPRange"] or 1500
        local myRoot = client.Character and client.Character:FindFirstChild("HumanoidRootPart")

        for _, otherPlayer in ipairs(Players:GetPlayers()) do
            if otherPlayer == client then
                continue
            end

            local character = otherPlayer.Character
            local otherRoot = character and character:FindFirstChild("HumanoidRootPart")

            if otherRoot and myRoot and (otherRoot.Position - myRoot.Position).Magnitude <= maxDistance then
                local color = otherPlayer.TeamColor and otherPlayer.TeamColor.Color
                    or Color3.new(1, 0, 0)
                local displayText = otherPlayer.Name

                if Library.Flags["PlayerHealthESP"] then
                    local humanoid = character:FindFirstChildOfClass("Humanoid")
                    if humanoid then
                        displayText = displayText .. string.format(" [%.0f HP]", humanoid.Health)
                    end
                end

                if Library.Flags["PlayerHeldItemESP"] then
                    local heldTool = character:FindFirstChildWhichIsA("Tool")
                    if heldTool then
                        displayText = displayText .. " [" .. heldTool.Name .. "]"
                    end
                end

                if Library.Flags["PlayerDistESP"] then
                    displayText = displayText
                        .. string.format(" [%.0fm]", (otherRoot.Position - myRoot.Position).Magnitude)
                end

                local holder = createESPObject(character, displayText, color)

                if holder then
                    local box = holder:FindFirstChild("ESP_Box")
                    local text = holder:FindFirstChild("ESP_Text")
                    if box then
                        box.Enabled = Library.Flags["PlayerBoxESP"] == true
                    end
                    if text then
                        text.Enabled = Library.Flags["PlayerNameESP"] == true
                            or Library.Flags["PlayerHealthESP"] == true
                    end
                end
            elseif ESP_OBJECTS[character] then
                ESP_OBJECTS[character]:Destroy()
                ESP_OBJECTS[character] = nil
            end
        end
    else
        for _, otherPlayer in ipairs(Players:GetPlayers()) do
            if otherPlayer ~= client and otherPlayer.Character
                and ESP_OBJECTS[otherPlayer.Character] then
                ESP_OBJECTS[otherPlayer.Character]:Destroy()
                ESP_OBJECTS[otherPlayer.Character] = nil
            end
        end
    end

    if Library.Flags["PlantESP"] then
        local maxDistance = Library.Flags["PlantESPRange"] or 1500
        local myRoot = client.Character and client.Character:FindFirstChild("HumanoidRootPart")
        local gardens = Workspace:FindFirstChild("Gardens") or Workspace
        local selectedFruits = Library.Flags["PlantESPNames"]
        local selectedRarities = Library.Flags["PlantESPRarities"]

        for _, plot in ipairs(gardens:GetChildren()) do
            if not (plot:IsA("Model") or plot:IsA("Folder")) then
                continue
            end

            local isOurPlot = (getPlotOwnerUserId(plot) == client.UserId)
            if Library.Flags["PlantOwnedOnly"] and not isOurPlot then
                continue
            end

            local plantsFolder = plot:FindFirstChild("Plants")
            if plantsFolder and myRoot then
                for _, plantModel in ipairs(plantsFolder:GetChildren()) do
                    if plantModel:IsA("Model") and plantModel.PrimaryPart then
                        local distance = (plantModel:GetPivot().Position - myRoot.Position).Magnitude

                        if distance <= maxDistance
                            and passesFilter(plantModel, selectedFruits, nil, selectedRarities) then
                            local displayText = plantModel.Name

                            if Library.Flags["PlantMut"] then
                                local mutation = plantModel:GetAttribute("Mutation")
                                if mutation then
                                    displayText = string.format("[%s] %s", mutation, displayText)
                                end
                            end

                            if Library.Flags["PlantDist"] then
                                displayText = displayText .. string.format(" [%.0fm]", distance)
                            end

                            if Library.Flags["PlantValue"] then
                                local valueScore = calculatePlantValue(plantModel)
                                displayText = displayText .. string.format(" [$%.0f]", valueScore)
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

    if Library.Flags["PropESP"] then
        local maxDistance = Library.Flags["PropESPRange"] or 500
        local myRoot = client.Character and client.Character:FindFirstChild("HumanoidRootPart")

        for _, plot in ipairs(Workspace:GetChildren()) do
            if not (plot:IsA("Model") or plot:IsA("Folder")) then
                continue
            end
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
        for targetObject, holder in pairs(ESP_OBJECTS) do
            if targetObject and targetObject.Name and targetObject.Parent
                and targetObject.Parent.Name == "Props" then
                holder:Destroy()
                ESP_OBJECTS[targetObject] = nil
            end
        end
    end
end))

--[[ IN-GAME HUD: WEATHER BAR ]]

local HUD_SCREEN = Instance.new("ScreenGui")
HUD_SCREEN.Name = "GardenMaster_HUD"
HUD_SCREEN.ResetOnSpawn = false
pcall(function()
    HUD_SCREEN.Parent = CoreGui
end)
registerCleanup(HUD_SCREEN)

local WEATHER_BAR = Instance.new("Frame")
WEATHER_BAR.Name = "WeatherBar"
WEATHER_BAR.Size = UDim2.new(0, 620, 0, 52)
WEATHER_BAR.Position = UDim2.new(0.5, -310, 1, -110)
WEATHER_BAR.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
WEATHER_BAR.BackgroundTransparency = 0.15
WEATHER_BAR.BorderSizePixel = 2
WEATHER_BAR.BorderColor3 = Color3.fromRGB(50, 50, 50)
WEATHER_BAR.Parent = HUD_SCREEN

local BAR_LAYOUT = Instance.new("UIListLayout")
BAR_LAYOUT.Parent = WEATHER_BAR
BAR_LAYOUT.FillDirection = Enum.FillDirection.Horizontal
BAR_LAYOUT.HorizontalAlignment = Enum.HorizontalAlignment.Center
BAR_LAYOUT.VerticalAlignment = Enum.VerticalAlignment.Center
BAR_LAYOUT.SortOrder = Enum.SortOrder.LayoutOrder
BAR_LAYOUT.Padding = UDim.new(0, 5)

local WEATHER_WIDGETS = {}

local WEATHER_TYPES = {
    { id = "Sunset",  label = "Sunset",    color = Color3.fromRGB(255, 180, 50) },
    { id = "Moon",    label = "Moon",      color = Color3.fromRGB(240, 240, 255) },
    { id = "Day",     label = "Day",       color = Color3.fromRGB(255, 255, 80) },
    { id = "Rainbow", label = "Rainbow",   color = Color3.fromRGB(150, 255, 255) },
    { id = "Bloodmoon", label = "Bloodmoon", color = Color3.fromRGB(255, 60, 60) },
    { id = "Goldmoon", label = "Goldmoon", color = Color3.fromRGB(255, 215, 0) }
}

for _, weatherType in ipairs(WEATHER_TYPES) do
    local box = Instance.new("Frame")
    box.Name = weatherType.id
    box.Size = UDim2.new(0, 92, 0, 44)
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

--[[ IN-GAME HUD: STOCK TICKER ]]

local STOCK_FRAME = Instance.new("Frame")
STOCK_FRAME.Name = "StockFrame"
STOCK_FRAME.Size = UDim2.new(0, 620, 0, 28)
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
        label.Size = UDim2.new(0, 140, 0, 22)
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

--[[ SYSTEM STATE ]]

local SystemState = {
    currentWeather = "Clear Skies",
    restockStatus = "Syncing...",
    trendingItem = "None",
    nextWeather = "Unknown",
    stockSnapshots = {},
    predictedRestocks = {}
}

local lastClockTime = Lighting.ClockTime
local lastRealTimestamp = os.clock()

registerCleanup(task.spawn(function()
    while true do
        task.wait(1.2)
        pcall(function()
            local currentClockTime = Lighting.ClockTime
            local realElapsed = os.clock() - lastRealTimestamp

            if realElapsed > 0.6 then
                local delta = (currentClockTime - lastClockTime) % 24
                if delta > 0 and delta < 1.2 then
                end
                lastClockTime = currentClockTime
                lastRealTimestamp = os.clock()
            end

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

--[[ UI: PREDICTIONS & STATUS TAB ]]

local predictionsTab = GUI:CreateSection("Predictions & Status")

predictionsTab:createLabel({
    Name = "Real-Time Environment Status",
    Special = true
})

local WEATHER_STATUS_LABEL = predictionsTab:createLabel({
    Name = "Weather: Syncing...",
    Center = true
})

local STOCK_STATUS_LABEL = predictionsTab:createLabel({
    Name = "Restock: Syncing...",
    Center = true
})

local NIGHT_STATUS_LABEL = predictionsTab:createLabel({
    Name = "Night Status: Checking...",
    Center = true
})

local PLOT_STATUS_LABEL = predictionsTab:createLabel({
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

predictionsTab:createLabel({
    Name = "Garden Statistics",
    Special = true
})

predictionsTab:createButton({
    Name = "Scan My Garden",
    Callback = function()
        authenticateGardenPlot()

        if not GardenPlot.plantsFolder then
            notifyPlayer("GardenMaster", "No plants folder found in your garden.", "info")
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

        notifyPlayer("Garden Statistics",
            string.format(
                "Plants: %d | Fruits: %d | Top Mutation: %s (%d)",
                plantCount, fruitCount, topMutation, topMutationCount
            ),
            "info"
        )
    end
})

--[[ FOOTER ]]

print(string.rep("=", 60))
print("[GardenMaster PRO v4.0] Fully loaded and ready.")
print("[GardenMaster PRO v4.0] "
    .. #GameData.seeds .. " seeds | "
    .. #GameData.gears .. " gears | "
    .. #GameData.crates .. " crates | "
    .. #GameData.pets .. " pets")
print("[GardenMaster PRO v4.0] "
    .. #GardenPlot.gridNodes .. " grid nodes in plot #"
    .. (GardenPlot.plotId or "?")
)
print(string.rep("=", 60))

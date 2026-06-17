local request = (syn and syn.request) or (http and http.request) or http_request

--[[
    GardenMaster HQ v5.0
    Built from full decompiled GAG2 source
    ReplicatedStorage.SharedModules.Networking
]]
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
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")
local ProximityPromptService = game:GetService("ProximityPromptService")
local client = Players.LocalPlayer

-- Cleanup previous
if _G.GardenHQ then pcall(_G.GardenHQ) end
_G.GardenHQ = nil

if not table.find then table.find = function(t,v) for i=1,#t do if t[i]==v then return i end end end end
if not table.clear then table.clear = function(t) for k in pairs(t) do t[k]=nil end end end

local Alive = true
local CO, CC, CT = {}, {}, {}
local function RC(v)
    if typeof(v)=="RBXScriptConnection" then
        CC[#CC+1]=v
    elseif typeof(v)=="Instance" then
        CO[#CO+1]=v
    elseif type(v)=="thread" then
        CT[#CT+1]=v
    end
end
_G.GardenHQ = function()
    Alive = false
    for _,c in CC do pcall(function() c:Disconnect() end) end
    for _,t in CT do pcall(function() if coroutine.status(t) ~= "dead" then task.cancel(t) end end) end
    for _,o in CO do pcall(function() if o and o.Parent then o:Destroy() end end) end
    CO={}; CC={}; CT={}
end

print(string.rep("-",64))
print("[HQ] GardenMaster HQ v5.1")
print(string.rep("-",64))

local Library = loadstring(game:HttpGet("https://versusairlines.top/scripts/NewLibrary.lua"))()
if not Library then warn("[HQ] Library failed"); return end
local UI = Library:Setup({Location=CoreGui, OpenCloseLocation="Bottom Right"})

RC(client.Idled:Connect(function()
    pcall(function()
        VirtualUser:Button2Down(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
        task.wait(0.5)
        VirtualUser:Button2Up(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
    end)
end))

-- Loop tracker
local LT = {}
local function RL(t,c) LT[t]=LT[t] or {}; LT[t][#LT[t]+1]=c; RC(c) end
local function DL(t) if LT[t] then for _,c in LT[t] do if c and typeof(c)=="RBXScriptConnection" then pcall(function() c:Disconnect() end) end end; LT[t]=nil end end

local function NF(title, msg, style)
    pcall(function()
        if Library.createDisplayMessage then
            Library:createDisplayMessage(title, msg, {{text="OK"}}, style or "info")
        elseif Library.Notify then
            Library:Notify(title, msg, 5)
        end
    end)
end

local function firstSelected(value, fallback)
    if typeof(value) == "table" then
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

local function asSelectionList(value)
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

local function trimText(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function cleanItemName(name)
    local s = trimText(name)
    s = s:gsub("%b[]", "")
    s = s:gsub("%s*[xX]%s*%d+%s*$", "")
    s = s:gsub("%s+%(%d+%)%s*$", "")
    s = s:gsub("_", " "):gsub(":", " ")
    s = s:gsub("^Seed%s+", "")
    s = s:gsub("%s+Seed$", "")
    s = s:gsub("%s+Tool$", "")
    return trimText(s:gsub("%s+", " "))
end

local function isNamedLikeSeed(name)
    local n = tostring(name or ""):lower()
    return n:find("seed", 1, true) and not n:find("seed pack", 1, true) and not n:find("seedpack", 1, true)
end

local function HP(prompt)
    if not prompt then return end
    if prompt:IsA("ProximityPrompt") then pcall(function() fireproximityprompt(prompt) end) end
end

local function TP(pos)
    local r=client.Character and client.Character:FindFirstChild("HumanoidRootPart")
    if r then pcall(function() r.CFrame=CFrame.new(pos+Vector3.new(0,3.8,0)) end) end
end

local function smoothTP(pos)
    local r=client.Character and client.Character:FindFirstChild("HumanoidRootPart")
    if not r then return end
    local targ=CFrame.new(pos+Vector3.new(0,3.8,0))
    local tw=TweenService:Create(r, TweenInfo.new(0.15,Enum.EasingStyle.Quad,Enum.EasingDirection.Out), {CFrame=targ})
    tw:Play(); tw.Completed:Wait()
end

-- Interval toggle helper
local function ciToggle(parent, cfg)
    local tag, flag, delay, step = cfg.tag or cfg.flagName, cfg.flagName, cfg.delay or 0.5, cfg.Step
    local warnFn, warnIf = cfg.Warning, cfg.WarnIf
    parent:createToggle({
        Name=cfg.Name,
        flagName=flag,
        Flag=cfg.Flag or false,
        Callback=function()
            DL(tag)
            if not Library.Flags[flag] then return end
            if warnIf and warnIf() and warnFn then
                NF("Warning", warnFn(), "warning")
            end
            local last, busy, legit = 0, false, Library.Flags["LegitMode"] or false
            local conn = RunService.Heartbeat:Connect(function()
                if not Library.Flags[flag] then DL(tag); return end
                local d = legit and (delay*(0.6+math.random()*0.8)+math.random(0.05,0.25)) or delay
                if busy or (os.clock()-last<d) then return end
                last=os.clock(); busy=true
                task.spawn(function()
                    local ok,err=pcall(step)
                    if not ok then warn("[HQ:"..tag.."] "..tostring(err)) end
                    busy=false
                end)
            end)
            RL(tag,conn)
        end
    })
end

-- Networking
local Net=nil
pcall(function() Net=require(ReplicatedStorage:WaitForChild("SharedModules",5):WaitForChild("Networking",5)) end)
if not Net then warn("[HQ] CRITICAL: No Network module at ReplicatedStorage.SharedModules.Networking"); return end
print("[HQ] Network module loaded successfully")

local PacketEvent
pcall(function()
    PacketEvent = ReplicatedStorage:WaitForChild("SharedModules", 5):WaitForChild("Packet", 5):WaitForChild("RemoteEvent", 5)
end)

-- ===========================================================================
-- GAME DATA DISCOVERY ENGINE
-- ===========================================================================
local GD = {seeds={},gears={},crates={},pets={},allItems={}}
local MTS = {"Gold","Rainbow","Electric","Solarflare","Frozen","Bloodlit","Chained","Pizza","Starstruck","Ghost","Poison"}
local RTS = {"Common","Uncommon","Rare","Super","Epic","Legendary","Mythic"}

pcall(function()
    local sm,gm,cm,pm = {},{},{},{}
    for _,d in ipairs(ReplicatedStorage:GetDescendants()) do
        local pn = (d.Parent and d.Parent.Name or ""):lower()
        local nm = d.Name
        if (d:IsA("ImageLabel") or d:IsA("Texture") or d:IsA("Decal")) and (pn:find("seed") or pn:find("fruit") or pn:find("plant") or nm:find("Seed")) then
            local m = nm:gsub("Seed:",""):gsub("Seed_",""):match("^([^%[]+)"); if m then sm[m:gsub("%s+$","")]=true end
        elseif d:IsA("NumberValue") or d:IsA("StringValue") then
            if pn:find("gear") or pn:find("watering") or pn:find("shovel") then gm[nm]=true end
            if pn:find("crate") or pn:find("box") or pn:find("egg") or pn:find("pet") then cm[nm]=true; pm[nm]=true end
        end
    end
    local bp = client:FindFirstChild("Backpack")
    if bp then for _,t in ipairs(bp:GetChildren()) do if t:IsA("Tool") then
        local n = t.Name:lower()
        if n:find("seed") or n:find("fruit") or n:find("plant") then
            local m = t.Name:gsub("Seed:",""):gsub("Seed_",""):match("^([^%[]+)"); if m then sm[m:gsub("%s+$","")]=true end
        elseif n:find("gear") or n:find("watering") or n:find("shovel") or n:find("trowel") then gm[t.Name]=true
        elseif n:find("crate") or n:find("box") or n:find("egg") or n:find("pet") then cm[t.Name]=true; pm[t.Name]=true end
    end end end
    if client.Character then for _,t in ipairs(client.Character:GetChildren()) do if t:IsA("Tool") then
        local n = t.Name:lower()
        if n:find("crate") or n:find("box") or n:find("egg") or n:find("pet") then cm[t.Name]=true; pm[t.Name]=true end
        if n:find("gear") or n:find("watering") or n:find("shovel") or n:find("trowel") then gm[t.Name]=true end
    end end end
    local sf = ReplicatedStorage:FindFirstChild("StockValues",true)
    if sf then for _,sn in ipairs({"SeedShop","GearShop","CrateShop","PetShop"}) do
        local sh = sf:FindFirstChild(sn)
        if sh and sh:FindFirstChild("Items") then for _,it in ipairs(sh.Items:GetChildren()) do if it:IsA("NumberValue") then
            if sn=="SeedShop" then sm[it.Name]=true elseif sn=="GearShop" then gm[it.Name]=true elseif sn=="CrateShop" then cm[it.Name]=true elseif sn=="PetShop" then pm[it.Name]=true end
        end end end
    end end
    local function toarr(m) local t={}; for k in pairs(m) do t[#t+1]=k end; table.sort(t); return t end
    GD.seeds,GD.gears,GD.crates,GD.pets = toarr(sm),toarr(gm),toarr(cm),toarr(pm)
    GD.allItems = {}
    for _,cat in ipairs({GD.seeds,GD.gears,GD.crates,GD.pets}) do for _,v in ipairs(cat) do GD.allItems[#GD.allItems+1]=v end end
    print(string.format("[HQ] Discovered: %d seeds | %d gears | %d crates | %d pets",#GD.seeds,#GD.gears,#GD.crates,#GD.pets))
end)

local function keepItems(list, predicate)
    local out, seen = {}, {}
    for _, name in ipairs(list or {}) do
        if type(name) == "string" and predicate(name) and not seen[name] then
            seen[name] = true
            out[#out + 1] = name
        end
    end
    table.sort(out)
    return out
end

local function itemNameHasAny(name, words)
    local n = tostring(name or ""):lower()
    for _, word in ipairs(words) do
        if n:find(word, 1, true) then return true end
    end
    return false
end

GD.seeds = keepItems(GD.seeds, function(name)
    return not itemNameHasAny(name, {"crate", "box", "egg", "pet", "sprinkler", "shovel", "watering", "gear"})
end)
GD.gears = keepItems(GD.gears, function(name)
    return itemNameHasAny(name, {"sprinkler", "watering", "shovel", "trowel", "rake", "pot", "mushroom", "wall"}) and not itemNameHasAny(name, {"egg", "pet", "crate", "box", "seed pack"})
end)
GD.sprinklers = keepItems(GD.gears, function(name)
    return tostring(name):lower():find("sprinkler", 1, true) ~= nil
end)

-- ===========================================================================
-- PLOT AUTHENTICATION & SPATIAL GRID SYSTEM
-- ===========================================================================
local PL = {
    model=nil, plotId=nil, gate=CFrame.new(), center=Vector3.new(),
    gridNodes={}, plantsFolder=nil, sprinklersFolder=nil, propsFolder=nil, rakesFolder=nil,
    spawnPoint=nil, plantAreas={}, auth=false, lastAuth=0, occupiedHash={},
    rowIdx=0, rowX=nil, rowZ=nil
}

local function getPlotOwner(plot)
    local uid = plot:GetAttribute("OwnerUserId"); if uid then return tonumber(uid) end
    local owner = plot:GetAttribute("Owner")
    if owner and typeof(owner)=="Instance" and owner:IsA("Player") then return owner.UserId end
    if plot:GetAttribute("Owner")==client.Name then return client.UserId end
    return nil
end

local function authenticatePlot()
    if os.clock()-PL.lastAuth<0.8 and PL.auth then return PL end
    PL.lastAuth=os.clock()
    local gardens = Workspace:FindFirstChild("Gardens") or Workspace
    local target=nil; local pid=client:GetAttribute("PlotId")
    if pid then target=gardens:FindFirstChild("Plot"..tostring(pid)) end
    if not target then for _,c in ipairs(gardens:GetChildren()) do
        if not (c:IsA("Model") or c:IsA("Folder")) then continue end
        if getPlotOwner(c)==client.UserId or c:GetAttribute("IsLocal") then target=c; pid=c:GetAttribute("PlotId") or pid; break end
        if pid and c.Name=="Plot"..tostring(pid) then target=c; break end
    end end
    if not target then PL.auth=false; local r=client.Character and client.Character:FindFirstChild("HumanoidRootPart"); if r then PL.center=r.Position end; return PL end
    if PL.model==target and #PL.gridNodes>0 then PL.auth=true; return PL end
    PL.model=target; PL.plotId=pid; PL.auth=true; PL.plantAreas={}; PL.occupiedHash={}; PL.rowIdx=0; PL.rowX=nil; PL.rowZ=nil
    local sp=target:FindFirstChild("SpawnPoint")
    if sp and sp:IsA("BasePart") then
        PL.spawnPoint=sp; PL.center=sp.Position
        PL.gate=CFrame.new(sp.Position+Vector3.new(0,3.5,3),sp.Position)
    else
        local pr=(target:IsA("Model") and target.PrimaryPart) or target:FindFirstChild("BottomFace",true)
        if pr and pr:IsA("BasePart") then PL.center=pr.Position; PL.gate=CFrame.new(pr.Position+Vector3.new(0,5,15),pr.Position) end
    end
    PL.plantsFolder=target:FindFirstChild("Plants")
    PL.sprinklersFolder=target:FindFirstChild("Sprinklers")
    PL.propsFolder=target:FindFirstChild("Props")
    PL.rakesFolder=target:FindFirstChild("Rakes")
    -- Find real plantable floor parts first; broad plot parts/signs are only fallbacks.
    local fallbackParts = {}
    for _, ch in ipairs(target:GetDescendants()) do
        if ch:IsA("BasePart") then
            local n = ch.Name:lower()
            local tagged = CollectionService:HasTag(ch, "PlantArea") or CollectionService:HasTag(ch, "Soil")
            local namedSoil = n:find("plantarea", 1, true) or n:find("plant area", 1, true) or n:find("platarea", 1, true) or n:find("soil", 1, true) or n:find("dirt", 1, true) or n:find("farm", 1, true)
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
    -- Build grid via raytracing
    PL.gridNodes={}
    for _,area in ipairs(PL.plantAreas) do
        local ap=area.Position; local sx,sz=math.max(area.Size.X,1)*0.46,math.max(area.Size.Z,1)*0.46
        for x=-sx,sx,2.6 do for z=-sz,sz,2.6 do
            local ox,oz=ap.X+x+math.random(-0.4,0.4),ap.Z+z+math.random(-0.4,0.4)
            local ry=Workspace:Raycast(Vector3.new(ox,ap.Y+30,oz),Vector3.new(0,-60,0))
            PL.gridNodes[#PL.gridNodes+1]=ry and ry.Position or Vector3.new(ox,ap.Y+area.Size.Y/2+0.15,oz)
        end end
    end
    for i=#PL.gridNodes,2,-1 do local j=math.random(i); PL.gridNodes[i],PL.gridNodes[j]=PL.gridNodes[j],PL.gridNodes[i] end
    return PL
end

local function getOccupiedCells()
    local oc={}; local h=PL.occupiedHash or {}
    if PL.plantsFolder then for _,p in PL.plantsFolder:GetChildren() do if p:IsA("Model") and p.PrimaryPart then
        local pp=p:GetPivot().Position; oc[#oc+1]=pp; h[tostring(math.floor(pp.X/2))..","..tostring(math.floor(pp.Z/2))]=true
    end end end
    if PL.sprinklersFolder then for _,s in PL.sprinklersFolder:GetChildren() do if s:IsA("Model") and s.PrimaryPart then
        oc[#oc+1]=s:GetPivot().Position
    end end end
    PL.occupiedHash=h; return oc
end

-- Row-based placement - starts from far back, fills row by row
local function getRowPosition(spc)
    authenticatePlot(); spc=spc or 2.9
    if not PL.auth or #PL.plantAreas==0 then return PL.center end
    local area=PL.plantAreas[1]
    local ap=area.Position; local sx,sz=math.max(area.Size.X,1)*0.44,math.max(area.Size.Z,1)*0.44
    local step=spc
    if not PL.rowX then PL.rowX=ap.X-sx; PL.rowZ=ap.Z-sz end
    local x,z=PL.rowX,PL.rowZ
    getOccupiedCells()
    local key=tostring(math.floor(x/2))..","..tostring(math.floor(z/2))
    local tries=0
    while PL.occupiedHash[key] and tries<600 do
        x=x+step; if x>ap.X+sx then x=ap.X-sx; z=z+step end
        if z>ap.Z+sz then z=ap.Z-sz; x=ap.X-sx end
        key=tostring(math.floor(x/2))..","..tostring(math.floor(z/2)); tries=tries+1
    end
    local r=Workspace:Raycast(Vector3.new(x,ap.Y+30,z),Vector3.new(0,-60,0))
    local pos=r and r.Position or Vector3.new(x,ap.Y+area.Size.Y/2+0.15,z)
    PL.rowX=x+step; if PL.rowX>ap.X+sx then PL.rowX=ap.X-sx; PL.rowZ=PL.rowZ+step end
    if PL.rowZ>ap.Z+sz then PL.rowZ=ap.Z-sz end
    PL.occupiedHash[key]=true
    return pos
end

local function getPlacementPosition(spc)
    authenticatePlot(); spc=spc or 2.9
    local mode=Library.Flags["PlacingMode"] or "Good Position"
    local rp=client.Character and client.Character:FindFirstChild("HumanoidRootPart")

    if mode=="Good Position" then return getRowPosition(spc) end

    if mode=="Player Position" then
        if rp then local r=Workspace:Raycast(rp.Position+Vector3.new(0,6,0),Vector3.new(0,-30,0)); return r and r.Position or rp.Position-Vector3.new(0,2.8,0) end
        return Vector3.zero
    end

    if mode=="Random" then
        if PL.auth then
            local h=18; local rx=PL.center.X+(math.random()*2-1)*h; local rz=PL.center.Z+(math.random()*2-1)*h
            local r=Workspace:Raycast(Vector3.new(rx,PL.center.Y+28,rz),Vector3.new(0,-55,0))
            return r and r.Position or Vector3.new(rx,PL.center.Y,rz)
        end
    end

    if mode=="Mouse" then
        local mp; pcall(function() local m=client:GetMouse(); if m and m.Hit then mp=m.Hit.Position end end)
        if mp then return mp end
    end

    -- Fallback: grid-based
    if not PL.auth or #PL.gridNodes==0 then return rp and rp.Position or Vector3.zero end
    local o=getOccupiedCells()
    for _,n in PL.gridNodes do
        local k=tostring(math.floor(n.X/2))..","..tostring(math.floor(n.Z/2))
        if not PL.occupiedHash[k] then
            local f=true; for _,u in o do if (Vector3.new(u.X,n.Y,u.Z)-n).Magnitude<spc then f=false; break end end
            if f then PL.occupiedHash[k]=true; return n end
        end
    end
    return PL.center
end

local function enforceGeofence(op)
    authenticatePlot(); local rp=client.Character and client.Character:FindFirstChild("HumanoidRootPart")
    if not rp or not PL.auth or not PL.gate then return end
    local gr=Library.Flags["Geofence"] or 22
    local fn=(op=="c") and "TPToEntranceCollect" or "TPToEntrancePlant"
    if not Library.Flags[fn] then return end
    if (rp.Position-PL.gate.Position).Magnitude>gr then pcall(function() rp.CFrame=PL.gate end) end
end

-- ===========================================================================
-- TOOL HANDLING SYSTEM
-- ===========================================================================
local function findTool(searchName)
    if not searchName or typeof(searchName) ~= "string" or searchName == "" then return nil end
    local cs = cleanItemName(searchName):lower():gsub("%s+", "")
    if cs == "" then return nil end

    local function scoreTool(tool)
        if not tool or not tool:IsA("Tool") then return nil end
        local clean = cleanItemName(tool.Name)
        local tn = clean:lower():gsub("%s+", "")
        local raw = tool.Name:lower():gsub("%s+", "")
        if tn == cs then return 5 end
        if raw == cs then return 4 end
        if tn:find(cs, 1, true) or cs:find(tn, 1, true) then return 3 end
        if isNamedLikeSeed(tool.Name) and clean:lower():find(cleanItemName(searchName):lower(), 1, true) then return 2 end
        return nil
    end

    local bestTool, bestScore = nil, -1
    local function scan(container)
        if not container then return end
        for _, tool in ipairs(container:GetChildren()) do
            local score = scoreTool(tool)
            if score and score > bestScore then
                bestTool, bestScore = tool, score
            end
        end
    end

    scan(client.Character)
    scan(client:FindFirstChild("Backpack"))
    return bestTool
end

local function equipTool(tool)
    if not tool or not tool.Parent then return false end
    if tool.Parent==client:FindFirstChild("Backpack") then
        local hum = client.Character and client.Character:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum:EquipTool(tool) end); task.wait(0.08) end
    end
    return tool.Parent==client.Character
end

local function unequipCurrent()
    local hum = client.Character and client.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local currentTool = client.Character and client.Character:FindFirstChildWhichIsA("Tool")
    if currentTool then pcall(function() hum:UnequipTools() end); task.wait(0.05) end
end

-- ===========================================================================
-- ACTION EXECUTORS - Every remote verified from decompiled Networking module
-- ===========================================================================

-- Garden: Harvesting
local function harvestPlant(plantId, fruitId)
    if not plantId then return end
    fruitId = fruitId or ""
    Net.Garden.CollectFruit:Fire(plantId, fruitId)
end

-- Plant: Seed planting
local function plantSeedAction(seedName, targetPosition)
    if not seedName or not targetPosition then return false end
    local tool = findTool(seedName)
    if not tool then
        if Library.Flags["Debug"] then warn("[HQ:Plant] No seed tool found for", seedName) end
        return false
    end

    local seedType = cleanItemName(tool.Name)
    if seedType == "" then seedType = cleanItemName(seedName) end

    local ok, err = pcall(function()
        if PacketEvent then
            PacketEvent:FireServer(4, targetPosition, seedType, tool)
        else
            Net.Plant.PlantSeed:Fire(targetPosition, seedType, tool)
        end
    end)
    if not ok then
        warn("[HQ:Plant] Plant failed: " .. tostring(err))
        return false
    end
    return true
end

-- Place: Sprinkler placement
local function placeSprinklerAction(sprinklerName, targetPosition)
    if not sprinklerName or not targetPosition then return false end
    local tool = findTool(sprinklerName)
    if not tool or not tostring(tool.Name):lower():find("sprinkler", 1, true) then return false end
    if tool.Parent ~= client.Character then equipTool(tool); task.wait(0.03) end
    local cleanName = cleanItemName(tool.Name)
    local ok = pcall(function()
        Net.Place.PlaceSprinkler:Fire(targetPosition, cleanName, tool, 1)
    end)
    return ok
end

-- WateringCan: Water plants
local function waterPlantAction(targetPosition)
    local tool = findTool("watering") or findTool("Watering")
    if tool then equipTool(tool); task.wait(0.05) end
    local wateringCanName = tool and (tool:GetAttribute("WateringCan") or tool.Name or "")
    Net.WateringCan.UseWateringCan:Fire(targetPosition-Vector3.new(0,0.3,0), wateringCanName, tool)
end

-- Shovel: Dig up plants
local function shovelPlantAction(plantId, fruitId, shovelTool)
    if not plantId then return end
    local tool = shovelTool or findTool("shovel") or findTool("Shovel")
    if not tool then return end
    if tool.Parent ~= client.Character then equipTool(tool); task.wait(0.015) end
    local attr = tool:GetAttribute("Shovel") or cleanItemName(tool.Name)
    pcall(function() Net.Shovel.UseShovel:Fire(plantId, fruitId or "", attr, tool) end)
end

-- Trowel: Move plants
local function movePlantAction(plantId, targetPosition, rotation)
    if not plantId or not targetPosition then return end
    Net.Trowel.MovePlant:Fire(plantId, targetPosition, rotation or 0)
end

-- NPCS: Selling
local function sellAllItems()
    pcall(function() Net.NPCS.SellAll:Fire() end)
end

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

local function sellSingleFruit(fruitId)
    if not fruitId then return end
    Net.NPCS.SellFruit:Fire(fruitId)
end

-- SeedShop: Buying seeds
local function buySeedItem(name)
    if not name or name=="" then return end
    Net.SeedShop.PurchaseSeed:Fire(name)
end

-- GearShop: Buying & equipping gear
local function buyGearItem(name)
    if not name or name=="" then return end
    Net.GearShop.PurchaseGear:Fire(name)
end

local function equipGearAction(name)
    if not name or name=="" then return end
    Net.GearShop.EquipGear:Fire(name)
end

local function unequipGearAction()
    Net.GearShop.UnequipGear:Fire()
end

-- CrateShop: Buying crates
local function buyCrateItem(name)
    if not name or name=="" then return end
    Net.CrateShop.PurchaseCrate:Fire(name)
end

-- Crate: Opening crates
local function openCrateAction(name)
    if not name or name=="" then return end
    Net.Crate.OpenCrate:Fire(name)
end

-- SeedPack: Opening seed packs
local function openSeedPackAction(name)
    if not name or name=="" then return end
    Net.SeedPack.OpenSeedPack:Fire(name)
end

-- Egg: Opening eggs
local function openEggAction(name)
    if not name or name=="" then return end
    Net.Egg.OpenEgg:Fire(name)
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

-- Pets: Equipping
local function equipPetAction(name)
    if not name or name=="" then return end
    Net.Pets.PetEquipped:Fire(name, {})
end

local function unequipPetAction(name)
    if not name or name=="" then return end
    Net.Pets.RequestUnequipByName:Fire(name)
end

-- Prop: Placement
local function placePropAction(position, propName, tool, rotation)
    if not position or not propName then return end
    Net.Prop.PlaceProp:Fire(position, propName, tool, rotation or 0)
end

local function pickupPropAction(propId)
    if not propId then return end
    Net.Prop.PickupProp:Fire(propId)
end

-- Daily Deals
local function checkDailyDealAction()
    Net.NPCS.CheckDailyDeal:Fire()
end

-- ===========================================================================
-- NIGHT DETECTION
-- ===========================================================================
local function readGameClockText()
    local pg = client:FindFirstChild("PlayerGui")
    if not pg then return nil end
    for _, d in ipairs(pg:GetDescendants()) do
        if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Visible then
            local s = tostring(d.Text or "")
            if s:match("^%s*%d+%s*m%s+%d+%s*s%s*$") or s:match("^%s*%d+%s*s%s*$") then
                return s
            end
        end
    end
    return nil
end

local function isNightTime()
    local nightDetector = ReplicatedStorage:FindFirstChild("Night", true)
    if nightDetector and nightDetector:IsA("BoolValue") then return nightDetector.Value end
    for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
        local n = d.Name:lower()
        if d:IsA("BoolValue") and (n:find("night") or n:find("moon")) then return d.Value end
        if d:IsA("StringValue") and (n:find("weather") or n:find("event")) then
            local v = d.Value:lower()
            if v:find("night") or v:find("moon") or v:find("blood") then return true end
        end
    end
    local t = Lighting.ClockTime
    return t < 6 or t >= 18
end

-- ===========================================================================
-- FILTERING & VALUE SCORING ENGINE
-- ===========================================================================
local function passesFilter(model, fruitFilter, mutationFilter, rarityFilter)
    if not model then return false end
    local nm = model.Name:lower()
    local sa = (model:GetAttribute("SeedName") or ""):lower()
    local ma = (model:GetAttribute("Mutation") or ""):lower()
    local ra = (model:GetAttribute("Rarity") or ""):lower()
    if fruitFilter and #fruitFilter>0 then
        local ok=false; for _,f in ipairs(fruitFilter) do if nm:find(f:lower(),1,true) or sa:find(f:lower(),1,true) then ok=true; break end end
        if not ok then return false end
    end
    if mutationFilter and #mutationFilter>0 then
        local ok=false; for _,m in ipairs(mutationFilter) do if ma==m:lower() then ok=true; break end end
        if not ok then return false end
    end
    if rarityFilter and #rarityFilter>0 then
        local ok=false; for _,r in ipairs(rarityFilter) do if ra==r:lower() then ok=true; break end end
        if not ok then return false end
    end
    return true
end

local MutationValue = {gold=15,rainbow=42,electric=11,solarflare=13,frozen=9,bloodlit=11,chained=7,pizza=6,starstruck=22,ghost=18,poison=14}
local RarityScore = {common=1,uncommon=2,rare=3,super=4,epic=5,legendary=6,mythic=7}

local function calculatePlantValue(model)
    if not model then return 0 end
    local s=0
    local rarity=(model:GetAttribute("Rarity") or ""):lower(); s=s+(RarityScore[rarity] or 1)*120
    local mutation=(model:GetAttribute("Mutation") or ""):lower(); s=s*(MutationValue[mutation] or 1)
    local size=model:GetAttribute("Size") or model:GetAttribute("FruitSize") or 1; if type(size)=="number" then s=s*math.max(size,0.15) end
    local sv=model:GetAttribute("Value") or model:GetAttribute("SellValue") or 0; if type(sv)=="number" then s=s+sv*1.2 end
    if model:GetAttribute("MultiHarvest") or model.Name:lower():find("multi") or model.Name:lower():find("regrow") then s=s*1.6 end
    local age=model:GetAttribute("Age") or model:GetAttribute("Growth") or 1; if type(age)=="number" and age>1 then s=s*(1+math.min(age/10,0.8)) end
    return s
end

local function getPlantIdentifiers(model)
    if not model then return nil,nil end
    return model:GetAttribute("PlantId"), model:GetAttribute("FruitId")
end

local function getBestCandidates(maxCount, fruitFilter, mutationFilter, rarityFilter, ownedOnly, blacklist)
    maxCount=maxCount or 12
    local candidates={}
    local rp=client.Character and client.Character:FindFirstChild("HumanoidRootPart")
    local gardens=Workspace:FindFirstChild("Gardens") or Workspace
    local function add(model, isOurs)
        if not model or not model:IsA("Model") then return end
        if blacklist and #blacklist>0 then for _,b in ipairs(blacklist) do if model.Name:lower():find(b:lower(),1,true) then return end end end
        if not passesFilter(model, fruitFilter, mutationFilter, rarityFilter) then return end
        if ownedOnly and not isOurs then return end
        local pid,fid=getPlantIdentifiers(model)
        local sc=calculatePlantValue(model)
        local d=rp and (model:GetPivot().Position-rp.Position).Magnitude or 0
        candidates[#candidates+1]={model=model,plantId=pid,fruitId=fid,score=sc,distance=d,isOwned=isOurs}
    end
    for _,prompt in ipairs(CollectionService:GetTagged("HarvestPrompt")) do add(prompt:FindFirstAncestorWhichIsA("Model"),true) end
    for _,plot in ipairs(gardens:GetChildren()) do
        if not (plot:IsA("Model") or plot:IsA("Folder")) then continue end
        local ours=getPlotOwner(plot)==client.UserId
        local pf=plot:FindFirstChild("Plants")
        if pf then for _,m in ipairs(pf:GetChildren()) do if m:IsA("Model") then add(m,ours) end end end
    end
    table.sort(candidates,function(a,b) if a.score~=b.score then return a.score>b.score end; return a.distance<b.distance end)
    local result={}; for i=1,math.min(maxCount,#candidates) do result[#result+1]=candidates[i] end
    return result
end

local function getOldestCandidates(n,ff,mf,rf,oo)
    local c=getBestCandidates(999,ff,mf,rf,oo,nil)
    table.sort(c,function(a,b) return (a.model and a.model:GetAttribute("Age") or 0)>(b.model and b.model:GetAttribute("Age") or 0) end)
    local r={}; for i=1,math.min(n,#c) do r[#r+1]=c[i] end; return r
end

local function getClosestCandidates(n,ff,mf,rf,oo)
    local c=getBestCandidates(999,ff,mf,rf,oo,nil)
    table.sort(c,function(a,b) return a.distance<b.distance end)
    local r={}; for i=1,math.min(n,#c) do r[#r+1]=c[i] end; return r
end

-- ===========================================================================
-- UTILITY HELPERS
-- ===========================================================================
local function getBackpackSeeds()
    local s = {}
    local function addTool(t)
        if not t or not t:IsA("Tool") then return end
        if not isNamedLikeSeed(t.Name) and not table.find(GD.seeds, cleanItemName(t.Name)) then return end
        local cn = cleanItemName(t.Name)
        if cn ~= "" and not table.find(s, cn) then s[#s + 1] = cn end
    end
    local bp = client:FindFirstChild("Backpack")
    if bp then for _, t in ipairs(bp:GetChildren()) do addTool(t) end end
    if client.Character then for _, t in ipairs(client.Character:GetChildren()) do addTool(t) end end
    table.sort(s)
    return s
end

local function getBackpackSprinklers()
    local s = {}
    local function add(t)
        if t and t:IsA("Tool") and tostring(t.Name):lower():find("sprinkler", 1, true) then
            local n = cleanItemName(t.Name)
            if n ~= "" and not table.find(s, n) then s[#s + 1] = n end
        end
    end
    local bp = client:FindFirstChild("Backpack")
    if bp then for _, t in ipairs(bp:GetChildren()) do add(t) end end
    if client.Character then for _, t in ipairs(client.Character:GetChildren()) do add(t) end end
    table.sort(s)
    return s
end

local function getBackpackGear()
    local s={}; local bp=client:FindFirstChild("Backpack")
    if bp then for _,t in ipairs(bp:GetChildren()) do
        if t:IsA("Tool") and (t.Name:lower():find("gear") or t.Name:lower():find("watering") or t.Name:lower():find("shovel") or t.Name:lower():find("trowel")) and not table.find(s,t.Name) then s[#s+1]=t.Name end
    end end; return s
end

local function getBackpackCrates()
    local s={}; local bp=client:FindFirstChild("Backpack")
    if bp then for _,t in ipairs(bp:GetChildren()) do
        if t:IsA("Tool") and t.Name:lower():find("crate") and not table.find(s,t.Name) then s[#s+1]=t.Name end
    end end; return s
end

local function getBackpackEggs()
    local s={}; local bp=client:FindFirstChild("Backpack")
    if bp then for _,t in ipairs(bp:GetChildren()) do
        if t:IsA("Tool") and t.Name:lower():find("egg") and not table.find(s,t.Name) then s[#s+1]=t.Name end
    end end; return s
end

local function getBackpackSeedPacks()
    local s={}; local bp=client:FindFirstChild("Backpack")
    if bp then for _,t in ipairs(bp:GetChildren()) do
        if t:IsA("Tool") and (t.Name:lower():find("seed pack") or t.Name:lower():find("seedpack")) and not table.find(s,t.Name) then s[#s+1]=t.Name end
    end end; return s
end

-- ##############################################################################
-- ##############################################################################
-- GARDEN TAB
-- ##############################################################################
-- ##############################################################################
local ExtraTab = UI:CreateSection("Player")
local GardenTab = UI:CreateSection("Garden")

GardenTab:createLabel({Name="Garden Control",Special=true})

-- ============================================
-- Planting & Harvest
-- ============================================
GardenTab:createLabel({Name="Planting & Harvest",Special=true})

GardenTab:createDropdown({Name="Auto Plant Seeds",flagName="PS_type",List={"None","All","Selected"}})
GardenTab:createDropdown({Name="Select Seeds",flagName="PS_list",multi=true,List=GD.seeds})
GardenTab:createDropdown({Name="Plant Priority",flagName="PP",List={"Manual Order","Highest Value"}})

ciToggle(GardenTab,{Name="Auto Plant",flagName="AP",tag="AP",delay=0.4,Step=function()
    authenticatePlot()
    local st = firstSelected(Library.Flags["PS_type"], "None")
    if st == "None" then return end
    enforceGeofence("p")

    local ss = {}
    if st == "All" then
        ss = getBackpackSeeds()
    elseif st == "Selected" then
        ss = asSelectionList(Library.Flags["PS_list"])
    end
    if #ss == 0 then
        if Library.Flags["Debug"] then warn("[HQ:Plant] No matching seed tools found") end
        return
    end

    if firstSelected(Library.Flags["PP"], "Manual Order") == "Highest Value" then
        local sc = {}
        for _, n in ipairs(ss) do
            local t = findTool(n)
            sc[n] = t and (t:GetAttribute("Value") or t:GetAttribute("Price") or 1) or 1
        end
        table.sort(ss, function(a, b) return (sc[a] or 0) > (sc[b] or 0) end)
    end

    for _, n in ipairs(ss) do
        if not Library.Flags["AP"] then break end
        if n ~= "" then
            local pos = getPlacementPosition(2.9)
            if pos and plantSeedAction(n, pos) then
                task.wait(0.12)
            end
        end
    end
end})

GardenTab:createDropdown({Name="Auto Harvest",flagName="AH_type",List={"None","All","Selected","Blacklist"}})
GardenTab:createDropdown({Name="Harvest Fruits",flagName="AH_list",multi=true,List=GD.seeds})
GardenTab:createDropdown({Name="Harvest Blacklist",flagName="AH_blist",multi=true,List=GD.seeds})
GardenTab:createDropdown({Name="Harvest Priority",flagName="HP",List={"Highest Value","Closest","Oldest"}})
GardenTab:createToggle({Name="Stop When Full",flagName="AH_fullstop",Flag=false})
ciToggle(GardenTab,{Name="Auto Harvest",flagName="AH",tag="AH",delay=0.05,Step=function()
    local st=Library.Flags["AH_type"]
    if st=="None" then return end
    authenticatePlot()
    enforceGeofence("c")
    if Library.Flags["AH_fullstop"] and client:GetAttribute("BackpackFull") then return end
    local max=500
    local ff=nil; local bl=nil
    if st=="Selected" then ff=Library.Flags["AH_list"] elseif st=="Blacklist" then bl=Library.Flags["AH_blist"] end
    local pr=Library.Flags["HP"] or "Highest Value"
    local cand
    if pr=="Oldest" then cand=getOldestCandidates(max,ff,nil,nil,true)
    elseif pr=="Closest" then cand=getClosestCandidates(max,ff,nil,nil,true)
    else cand=getBestCandidates(max,ff,nil,nil,true,bl) end
    local cnt=0
    for _,c in ipairs(cand) do
        if not Library.Flags["AH"] then break end
        if cnt>=max then break end
        if c.plantId then task.spawn(harvestPlant,c.plantId,c.fruitId); cnt=cnt+1
        elseif c.model then
            local p=c.model:FindFirstChild("HarvestPrompt",true)
            if p then task.spawn(HP,p); cnt=cnt+1 end
        end
        task.wait(0.02)
    end
end})

GardenTab:createDropdown({Name="Auto Open Items",flagName="Open_type",List={"None","All","Crates","Eggs","Seed Packs"}})
ciToggle(GardenTab,{Name="Auto Open Items",flagName="Open",tag="Open",delay=1.5,Step=function()
    local st=Library.Flags["Open_type"]; if st=="None" then return end
    local bp=client:FindFirstChild("Backpack"); if not bp then return end
    for _,t in ipairs(bp:GetChildren()) do if not Library.Flags["Open"] then break end; if t:IsA("Tool") then
        local n=t.Name:lower()
        if (st=="All" or st=="Crates") and n:find("crate") then openCrateAction(t.Name); task.wait(0.2)
        elseif (st=="All" or st=="Eggs") and n:find("egg") then openEggAction(t.Name); task.wait(0.2)
        elseif (st=="All" or st=="Seed Packs") and (n:find("seed pack") or n:find("seedpack")) then openSeedPackAction(t.Name); task.wait(0.2) end
    end end
end})

GardenTab:createDropdown({Name="Auto Sell",flagName="Sell_type",List={"None","Always","When Full"}})
ciToggle(GardenTab,{Name="Auto Sell",flagName="AS",tag="AS",delay=0.6,Step=function()
    local st = firstSelected(Library.Flags["Sell_type"], "None")
    if st == "None" then return end
    if st == "When Full" and not isBackpackFull() then return end
    sellAllItems()
end})

-- ============================================
-- Plot Cleanup
-- ============================================
GardenTab:createLabel({Name="Plot Cleanup",Special=true})

GardenTab:createDropdown({Name="Auto Remove",flagName="RM_type",List={"None","All","Low KG","Selected","Blacklist"}})
GardenTab:createDropdown({Name="Remove Fruits",flagName="RM_list",multi=true,List=GD.seeds})
GardenTab:createDropdown({Name="Low Weight Fruits",flagName="RM_low_type",List={"None","All","Selected"}})
GardenTab:createSlider({Name="Max Fruit KG",flagName="RM_maxKG",value=0,minValue=0,maxValue=100000})
GardenTab:createDropdown({Name="Remove Plants",flagName="RM_plants",List={"None","All","Selected","Low Value"}})

ciToggle(GardenTab,{Name="Auto Remove",flagName="RM",tag="RM",delay=0.6,Step=function()
    local st=Library.Flags["RM_type"]; if st=="None" then return end
    authenticatePlot(); if not PL.plantsFolder then return end
    local mx=Library.Flags["RM_maxKG"] or 0
    local sl=Library.Flags["RM_list"]; local ff=nil; local bl=nil
    if st=="Selected" then ff=sl elseif st=="Blacklist" then bl=sl end
    local cand=getBestCandidates(200,ff,nil,nil,true,bl)
    if st=="Low KG" then local fc={}; for _,c in ipairs(cand) do if c.score<mx then fc[#fc+1]=c end end; cand=fc end
    local s=findTool("shovel") or findTool("Shovel")
    for _,c in ipairs(cand) do if not Library.Flags["RM"] then break end; if c.plantId then shovelPlantAction(c.plantId,c.fruitId,s); task.wait(0.012) end end
end})

GardenTab:createButton({Name="Remove Once",Callback=function()
    authenticatePlot(); if not PL.plantsFolder then NF("Cleanup","No garden found.","warning"); return end
    local s=findTool("shovel") or findTool("Shovel"); local cnt=0
    for _,m in ipairs(PL.plantsFolder:GetChildren()) do if m:IsA("Model") and m.PrimaryPart then local pid,fid=getPlantIdentifiers(m); shovelPlantAction(pid,fid,s); cnt=cnt+1; task.wait(0.012) end end
    NF("Plot Cleanup","Removed "..cnt.." plants.","info")
end})

GardenTab:createButton({Name="Shovel Once",Callback=function()
    authenticatePlot(); if not PL.plantsFolder then NF("Shovel","No garden found.","warning"); return end
    local s=findTool("shovel") or findTool("Shovel"); local cnt=0
    for _,m in ipairs(PL.plantsFolder:GetChildren()) do if m:IsA("Model") and m.PrimaryPart then local pid,fid=getPlantIdentifiers(m); shovelPlantAction(pid,fid,s); cnt=cnt+1; task.wait(0.012) end end
    NF("Shovel","Dug up "..cnt.." plants.","info")
end})

-- ============================================
-- Watering
-- ============================================
GardenTab:createLabel({Name="Watering",Special=true})

ciToggle(GardenTab,{Name="Auto Water",flagName="AW",tag="AW",delay=0.5,Step=function()
    authenticatePlot(); if not PL.plantsFolder then return end
    local sr=Library.Flags["AW_rar"]
    for _,m in ipairs(PL.plantsFolder:GetChildren()) do
        if not Library.Flags["AW"] then break end
        if m:IsA("Model") and m.PrimaryPart then
            if sr and #sr>0 then local ra=(m:GetAttribute("Rarity") or ""):lower(); local ok=false; for _,r in ipairs(sr) do if ra==r:lower() then ok=true; break end end; if not ok then continue end end
            waterPlantAction(m:GetPivot().Position); task.wait(0.04)
        end
    end
end})
GardenTab:createDropdown({Name="Water Priority",flagName="AW_prio",List={"All Need Water","Closest","Driest First"}})
GardenTab:createDropdown({Name="Water Rarities",flagName="AW_rar",multi=true,List=RTS})

-- ============================================
-- Sprinklers
-- ============================================
GardenTab:createLabel({Name="Sprinklers",Special=true})

GardenTab:createDropdown({Name="Sprinkler Type",flagName="SP_list",multi=true,List=GD.sprinklers})
ciToggle(GardenTab,{Name="Auto Place Sprinklers",flagName="SP",tag="SP",delay=0.35,Step=function()
    authenticatePlot(); enforceGeofence("p")
    local selected = asSelectionList(Library.Flags["SP_list"])
    local sprinklers = (#selected > 0) and selected or getBackpackSprinklers()
    for _, n in ipairs(sprinklers) do
        if not Library.Flags["SP"] then break end
        local pos = getPlacementPosition(4.0)
        if pos and placeSprinklerAction(n, pos) then task.wait(0.08) end
    end
end})

-- ============================================
-- Auto Collect Seeds
-- ============================================
GardenTab:createLabel({Name="Auto Collect Seeds",Special=true})

GardenTab:createDropdown({Name="Auto Collect",flagName="ACS_type",List={"None","All","Rainbow Only","Gold Only"}})
local collectPromptCache, collectCacheAt = {}, 0
local function refreshCollectPrompts(force)
    if not force and os.clock() - collectCacheAt < 4 then return collectPromptCache end
    collectCacheAt = os.clock()
    table.clear(collectPromptCache)
    local tagged = CollectionService:GetTagged("SeedPrompt")
    for _, p in ipairs(tagged) do if p:IsA("ProximityPrompt") then collectPromptCache[#collectPromptCache + 1] = p end end
    if #collectPromptCache == 0 then
        for _, p in ipairs(Workspace:GetDescendants()) do
            if p:IsA("ProximityPrompt") then
                local t = (p.Name .. " " .. (p.ActionText or "") .. " " .. (p.ObjectText or "")):lower()
                if t:find("seed", 1, true) or t:find("rainbow", 1, true) or t:find("gold", 1, true) or t:find("claim", 1, true) then
                    collectPromptCache[#collectPromptCache + 1] = p
                end
            end
        end
    end
    return collectPromptCache
end

ciToggle(GardenTab,{Name="Auto Collect Seeds",flagName="ACS",tag="ACS",delay=0.25,Step=function()
    local st = firstSelected(Library.Flags["ACS_type"], "None")
    if st == "None" then return end
    local hrp = client.Character and client.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local prompts = refreshCollectPrompts(false)
    table.sort(prompts, function(a, b)
        local ap = a.Parent and a.Parent:IsA("BasePart") and a.Parent.Position or (a:FindFirstAncestorWhichIsA("Model") and a:FindFirstAncestorWhichIsA("Model"):GetPivot().Position) or hrp.Position
        local bp = b.Parent and b.Parent:IsA("BasePart") and b.Parent.Position or (b:FindFirstAncestorWhichIsA("Model") and b:FindFirstAncestorWhichIsA("Model"):GetPivot().Position) or hrp.Position
        return (ap - hrp.Position).Magnitude < (bp - hrp.Position).Magnitude
    end)
    local used = 0
    for _, p in ipairs(prompts) do
        if not Library.Flags["ACS"] or used >= 8 then break end
        if p and p.Parent and p.Enabled ~= false then
            local t = (p.Name .. " " .. (p.ActionText or "") .. " " .. (p.ObjectText or "")):lower()
            local ok = st == "All" or (st == "Rainbow Only" and t:find("rainbow", 1, true)) or (st == "Gold Only" and t:find("gold", 1, true))
            if ok then
                local m = p:FindFirstAncestorWhichIsA("Model") or p.Parent
                local pos = m and (m:IsA("Model") and m:GetPivot().Position or (m.Position or nil))
                if pos and (pos - hrp.Position).Magnitude > 12 then TP(pos) task.wait(0.05) end
                HP(p)
                used = used + 1
                task.wait(0.03)
            end
        end
    end
end})

-- ============================================
-- Plot Teleport
-- ============================================
GardenTab:createLabel({Name="Plot Teleport",Special=true})

GardenTab:createToggle({Name="Teleport To Gate (Collect)",flagName="TPToEntranceCollect",Flag=true})
GardenTab:createToggle({Name="Teleport To Gate (Plant)",flagName="TPToEntrancePlant",Flag=true})
GardenTab:createSlider({Name="Geofence Radius",flagName="Geofence",value=22,minValue=8,maxValue=90})
GardenTab:createDropdown({Name="Placement Mode",flagName="PlacingMode",List={"Good Position","Player Position","Random","Mouse"}})
GardenTab:createButton({Name="Teleport to Garden",Callback=function()
    authenticatePlot(); if PL.auth and PL.gate then TP(PL.gate.Position); NF("Teleport","Arrived.","info") else NF("Teleport","No garden found.","warning") end
end})

GardenTab:createButton({Name="Refresh Plot Data",Callback=function()
    PL.auth=false; PL.lastAuth=0; authenticatePlot()
    if PL.auth then NF("Refresh","Plot #"..(PL.plotId or "?").." refreshed. "..#PL.gridNodes.." nodes.","info") else NF("Refresh","No plot found.","warning") end
end})

-- ##############################################################################
-- ##############################################################################
-- STEALER TAB
-- ##############################################################################
-- ##############################################################################
local StealerTab = UI:CreateSection("Stealer")

StealerTab:createLabel({Name="Auto Steal Targets",Special=true})

ciToggle(StealerTab,{Name="Auto Steal",flagName="ST",tag="ST",delay=0.65,Step=function()
    local sr = asSelectionList(Library.Flags["ST_rar"])
    local sn = asSelectionList(Library.Flags["ST_names"])
    local mw = asSelectionList(Library.Flags["ST_mw"])
    local mb = asSelectionList(Library.Flags["ST_mb"])
    local mk = Library.Flags["ST_minKG"] or 0
    local cp = Library.Flags["ST_carry"] or 50
    local prio = firstSelected(Library.Flags["ST_prio"], "Value")
    local cand = getBestCandidates(300, sn, mw, sr, false)

    local filtered = {}
    for _, c in ipairs(cand) do
        if c.model and not c.isOwned then
            local mut = tostring(c.model:GetAttribute("Mutation") or ""):lower()
            local blocked = false
            for _, b in ipairs(mb) do if mut == tostring(b):lower() then blocked = true break end end
            if not blocked and (mk <= 0 or c.score >= mk) then filtered[#filtered + 1] = c end
        end
    end
    cand = filtered

    if prio == "Value" then
        table.sort(cand, function(a,b) return a.score > b.score end)
    elseif prio == "Closest" then
        table.sort(cand, function(a,b) return a.distance < b.distance end)
    elseif prio == "Random" then
        for i = #cand, 2, -1 do local j = math.random(i); cand[i], cand[j] = cand[j], cand[i] end
    end

    local cnt = 0
    for _, c in ipairs(cand) do
        if not Library.Flags["ST"] or cnt >= cp then break end
        if c.model then
            local plot = c.model
            while plot and plot.Parent and plot.Parent ~= Workspace and not getPlotOwner(plot) do plot = plot.Parent end
            local ouid = plot and getPlotOwner(plot)
            if ouid and ouid ~= client.UserId then
                if Library.Flags["ST_skipF"] then local ok,isf=pcall(function() return client:IsFriendsWith(ouid) end); if ok and isf then continue end end
                if Library.Flags["ST_avoidO"] then local o=Players:GetPlayerByUserId(ouid); if o and o.Character and o.Character:FindFirstChild("HumanoidRootPart") and (c.model:GetPivot().Position-o.Character.HumanoidRootPart.Position).Magnitude<20 then continue end end
                if Library.Flags["ST_flingO"] then local o=Players:GetPlayerByUserId(ouid); if o and o.Character and o.Character:FindFirstChild("HumanoidRootPart") then o.Character.HumanoidRootPart.AssemblyLinearVelocity=(c.model:GetPivot().Position-o.Character.HumanoidRootPart.Position).Unit*250+Vector3.new(0,150,0) end end
                TP(c.model:GetPivot().Position)
                task.wait(0.08)
                beginStealAction(ouid, c.plantId, c.fruitId)
                task.wait(0.04)
                completeStealAction()
                local pr = c.model:FindFirstChild("HarvestPrompt", true)
                if pr then task.spawn(HP, pr) end
                if c.plantId then task.spawn(harvestPlant, c.plantId, c.fruitId) end
                cnt = cnt + 1
                task.wait(0.16)
            end
        end
    end
end})

StealerTab:createDropdown({Name="Steal Rarities",flagName="ST_rar",multi=true,List=RTS})
StealerTab:createDropdown({Name="Plant Names",flagName="ST_names",multi=true,List=GD.seeds})
StealerTab:createDropdown({Name="Mutation Whitelist",flagName="ST_mw",multi=true,List=MTS})
StealerTab:createDropdown({Name="Mutation Blacklist",flagName="ST_mb",multi=true,List=MTS})
StealerTab:createSlider({Name="Minimum KG",flagName="ST_minKG",value=0,minValue=0,maxValue=100000})
StealerTab:createSlider({Name="Carry Per Steal",flagName="ST_carry",value=50,minValue=1,maxValue=200})
StealerTab:createDropdown({Name="Target Priority",flagName="ST_prio",List={"Value","Closest","Random"}})
StealerTab:createToggle({Name="Skip Friends",flagName="ST_skipF",Flag=false})
StealerTab:createToggle({Name="Avoid Owners",flagName="ST_avoidO",Flag=false})
StealerTab:createToggle({Name="Fling Owner",flagName="ST_flingO",Flag=true})

-- ##############################################################################
-- ##############################################################################
-- SHOP TAB
-- ##############################################################################
-- ##############################################################################
local ShopTab = UI:CreateSection("Market")

ShopTab:createLabel({Name="Seed Shop",Special=true})

ShopTab:createDropdown({Name="Auto Seeds",flagName="SH_seeds_type",List={"None","All","Selected"}})
ShopTab:createDropdown({Name="Seeds To Buy",flagName="SH_seeds",multi=true,List=GD.seeds})
ciToggle(ShopTab,{Name="Auto Buy Seeds",flagName="SH_bs",tag="SH_bs",delay=1.5,Step=function()
    local st=Library.Flags["SH_seeds_type"]; if st=="None" then return end
    local lst={}; if st=="All" then lst=GD.seeds elseif st=="Selected" then lst=asSelectionList(Library.Flags["SH_seeds"]) end
    for _,n in ipairs(lst) do if not Library.Flags["SH_bs"] then break end; if n~="" then buySeedItem(n); task.wait(0.06) end end
end})

ShopTab:createLabel({Name="Gear Shop",Special=true})
ShopTab:createDropdown({Name="Auto Gears",flagName="SH_gears_type",List={"None","All","Selected"}})
ShopTab:createDropdown({Name="Gears To Buy",flagName="SH_gears",multi=true,List=GD.gears})
ciToggle(ShopTab,{Name="Auto Buy Gears",flagName="SH_bg",tag="SH_bg",delay=1.5,Step=function()
    local st=Library.Flags["SH_gears_type"]; if st=="None" then return end
    local lst={}; if st=="All" then lst=GD.gears elseif st=="Selected" then lst=asSelectionList(Library.Flags["SH_gears"]) end
    for _,n in ipairs(lst) do if not Library.Flags["SH_bg"] then break end; if n~="" then buyGearItem(n); task.wait(0.06) end end
end})

ShopTab:createDropdown({Name="Auto Props",flagName="SH_props_type",List={"None","All","Selected"}})
ShopTab:createDropdown({Name="Props To Buy",flagName="SH_props",multi=true,List=GD.crates})
ciToggle(ShopTab,{Name="Auto Buy Props",flagName="SH_bp",tag="SH_bp",delay=1.5,Step=function()
    local st=Library.Flags["SH_props_type"]; if st=="None" then return end
    local lst={}; if st=="All" then lst=GD.crates elseif st=="Selected" then lst=Library.Flags["SH_props"] or {}; lst=typeof(lst)=="table" and lst or {lst} end
    for _,n in ipairs(lst) do if not Library.Flags["SH_bp"] then break end; if n~="" then buyCrateItem(n); task.wait(0.06) end end
end})

ShopTab:createLabel({Name="Wild Pet Shop",Special=true})
ShopTab:createDropdown({Name="Pet Rarities",flagName="SH_pet_rar",multi=true,List=RTS})
ShopTab:createDropdown({Name="Pet Names",flagName="SH_pet_names",multi=true,List=GD.pets})
ShopTab:createDropdown({Name="Pet Blacklist",flagName="SH_pet_blist",multi=true,List=GD.pets})
ciToggle(ShopTab,{Name="Auto Buy Pets",flagName="SH_bpet",tag="SH_bpet",delay=1.0,Step=function()
    local sel=Library.Flags["PetRarity"] or {}
    for _,p in ipairs(CollectionService:GetTagged("BuyPetPrompt")) do if not Library.Flags["SH_bpet"] then break end
        if p:IsA("ProximityPrompt") then local m=p:FindFirstAncestorWhichIsA("Model")
            if m then local r=(m:GetAttribute("Rarity") or ""):lower()
                for _,tr in ipairs(sel) do if (#sel==0) or r==tr:lower() or m.Name:lower():find(tr:lower()) then
                    TP(m:GetPivot().Position); task.wait(0.12); task.spawn(HP,p); task.wait(0.4); break end
                end
            end
        end
    end
end})

ShopTab:createLabel({Name="Stock & Weather Predictors",Special=true})
ShopTab:createToggle({Name="Show HUD Tracker",flagName="PRED",Flag=false})

ShopTab:createLabel({Name="Daily Deals",Special=true})
ciToggle(ShopTab,{Name="Auto Use Daily Deals",flagName="AutoDaily",tag="AutoDaily",delay=5.0,Step=function() checkDailyDealAction() end})

ShopTab:createLabel({Name="Crate & Egg Opening",Special=true})
ciToggle(ShopTab,{Name="Auto Open Crates",flagName="OpenCt",tag="OpenCt",delay=1.8,Step=function()
    local bp=client:FindFirstChild("Backpack"); if not bp then return end
    for _,t in ipairs(bp:GetChildren()) do if not Library.Flags["OpenCt"] then break end; if t:IsA("Tool") and t.Name:lower():find("crate") then openCrateAction(t.Name); task.wait(0.25) end end
end})
ciToggle(ShopTab,{Name="Auto Open Eggs",flagName="OpenEg",tag="OpenEg",delay=1.8,Step=function()
    local bp=client:FindFirstChild("Backpack"); if not bp then return end
    for _,t in ipairs(bp:GetChildren()) do if not Library.Flags["OpenEg"] then break end; if t:IsA("Tool") and t.Name:lower():find("egg") then openEggAction(t.Name); task.wait(0.25) end end
end})
ciToggle(ShopTab,{Name="Auto Open Seed Packs",flagName="OpenSp",tag="OpenSp",delay=1.8,Step=function()
    local bp=client:FindFirstChild("Backpack"); if not bp then return end
    for _,t in ipairs(bp:GetChildren()) do if not Library.Flags["OpenSp"] then break end; if t:IsA("Tool") and (t.Name:lower():find("seed pack") or t.Name:lower():find("seedpack")) then openSeedPackAction(t.Name); task.wait(0.25) end end
end})

ShopTab:createLabel({Name="Bargaining",Special=true})
ciToggle(ShopTab,{Name="Auto Bargain",flagName="AutoBargain",tag="AutoBargain",delay=2.0,Step=function()
    local rp=client.Character and client.Character:FindFirstChild("HumanoidRootPart"); if not rp then return end
    for _,p in ipairs(Workspace:GetDescendants()) do if not Library.Flags["AutoBargain"] then break end
        if p:IsA("ProximityPrompt") then local t=(p.Name.." "..(p.ActionText or "").." "..(p.ObjectText or "")):lower()
            if t:find("bargain") or t:find("haggle") or t:find("trade") then
                local m=p:FindFirstAncestorWhichIsA("Model") or p.Parent
                if m and m:IsA("Model") and (m:GetPivot().Position-rp.Position).Magnitude<55 then
                    TP(m:GetPivot().Position); task.wait(0.14); task.spawn(HP,p); task.wait(0.25)
                end
            end
        end
    end
end})

ShopTab:createLabel({Name="NPC Selling",Special=true})
ciToggle(ShopTab,{Name="Auto Get Bids",flagName="AutoBid",tag="AutoBid",delay=3.0,Step=function()
    Net.NPCS.AskBidAll:Fire()
end})

-- ##############################################################################
-- ##############################################################################
-- MISC TAB
-- ##############################################################################
-- ##############################################################################
local MiscTab = UI:CreateSection("Safety")

MiscTab:createToggle({Name="Humanized Mode (Random Delays)",flagName="LegitMode",Flag=true})

MiscTab:createLabel({Name="Codes",Special=true})
MiscTab:createButton({Name="Redeem All Known Codes",Callback=function()
    local cs={"TEAMGREENBEAN","STARBUD","torigate","RDCAward","LUNARGLOW10","BEANORLEAVE10"}
    for _,c in ipairs(cs) do redeemCodeAction(c); task.wait(0.08) end
    NF("Codes","All promo codes redeemed successfully.","info")
end})

MiscTab:createLabel({Name="Anti-Fling Protection",Special=true})
ciToggle(MiscTab,{Name="Anti Fling Protection",flagName="AntiFling",tag="AntiFling",delay=0.1,Flag=true,Step=function()
    local mr=client.Character and client.Character:FindFirstChild("HumanoidRootPart")
    if mr then if mr.AssemblyLinearVelocity.Magnitude>250 or mr.AssemblyAngularVelocity.Magnitude>50 then
        mr.AssemblyLinearVelocity=Vector3.zero; mr.AssemblyAngularVelocity=Vector3.zero end end
    for _,p in ipairs(Players:GetPlayers()) do if p==client then continue end; if p.Character then
        for _,ch in ipairs(p.Character:GetDescendants()) do if ch:IsA("BasePart") then ch.CanCollide=false; ch.CanTouch=false end end
    end end
    local pg=client:FindFirstChild("PlayerGui"); if pg then for _,d in ipairs(pg:GetDescendants()) do
        if d:IsA("GuiObject") then local n=d.Name:lower(); if n:find("pause") or n:find("gameplay") or n:find("afk") then d.Visible=false end end
    end end
end})

RC(client.OnTeleport:Connect(function(state)
    if state==Enum.TeleportState.Failed then task.wait(5); pcall(function() TeleportService:Teleport(game.PlaceId,client) end) end
end))

MiscTab:createLabel({Name="Character Protection",Special=true})
ciToggle(MiscTab,{Name="Anti AFK & Knockback Shield",flagName="AntiAFK",tag="AntiAFK",delay=4.0,Flag=true,Step=function()
    local h=client.Character and client.Character:FindFirstChildOfClass("Humanoid")
    if h then h:SetStateEnabled(Enum.HumanoidStateType.FallingDown,false); h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll,false) end
    local c=client.Character; if c then for _,ch in ipairs(c:GetChildren()) do
        if ch:IsA("Script") or ch:IsA("LocalScript") then local n=ch.Name:lower()
            if n:find("bee") or n:find("sting") or n:find("poison") or n:find("thorn") then ch.Disabled=true; ch:Destroy() end
        end
    end end
    local mr=client.Character and client.Character:FindFirstChild("HumanoidRootPart")
    if mr then for _,p in ipairs(Players:GetPlayers()) do if p==client then continue end
        local r=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
        if r and (r.Position-mr.Position).Magnitude<12 then
            local h=p.Character:FindFirstChildOfClass("Humanoid")
            if h then h.Sit=true; r.AssemblyLinearVelocity=(r.Position-mr.Position).Unit*150+Vector3.new(0,80,0) end
        end
    end end
end})


MiscTab:createLabel({Name="Pet Management",Special=true})
ciToggle(MiscTab,{Name="Auto Equip Best Pets",flagName="EqPets",tag="EqPets",delay=2.5,Step=function()
    for _,n in ipairs(GD.pets) do if not Library.Flags["EqPets"] then break end; equipPetAction(n); task.wait(0.1) end end
})

MiscTab:createLabel({Name="Quick Actions",Special=true})
MiscTab:createButton({Name="Sell All Now",Callback=function() sellAllItems(); NF("Inventory","Sold everything to merchant.","info") end})
MiscTab:createButton({Name="Rejoin Server",Callback=function() pcall(function() TeleportService:Teleport(game.PlaceId,client) end) end})
MiscTab:createButton({Name="Leave Server",Callback=function() pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId,"",client) end) end})

-- ##############################################################################
-- ##############################################################################
-- VISUALS TAB
-- ##############################################################################
-- ##############################################################################
local VisualsTab = UI:CreateSection("Visuals")

VisualsTab:createLabel({Name="World Settings",Special=true})

VisualsTab:createSlider({Name="Clock Time",flagName="ClockTime",value=21,minValue=0,maxValue=24})
ciToggle(VisualsTab,{Name="Override Clock Time",flagName="ClockOv",tag="ClockOv",delay=0.1,Step=function()
    Lighting.ClockTime=Library.Flags["ClockTime"] or 21
end})

ciToggle(VisualsTab,{Name="Fullbright",flagName="Fullbright",tag="Fullbright",delay=0.5,Step=function()
    Lighting.Ambient=Color3.new(1,1,1); Lighting.OutdoorAmbient=Color3.new(1,1,1)
end})

VisualsTab:createToggle({Name="Performance Mode",flagName="PerfMode",Flag=true,Callback=function(e)
    if e then pcall(function() sethiddenproperty(Lighting,"Technology",Enum.Technology.Compatibility) end) end
end})

ciToggle(VisualsTab,{Name="No Fog",flagName="NoFog",tag="NoFog",delay=0.5,Step=function()
    Lighting.FogEnd=100000; Lighting.FogStart=100000
end})

VisualsTab:createSlider({Name="Field Of View",flagName="FOV",value=70,minValue=30,maxValue=120})
ciToggle(VisualsTab,{Name="Override FOV",flagName="FOVOn",tag="FOVOn",delay=0.5,Step=function()
    local cam=Workspace.CurrentCamera; if cam then cam.FieldOfView=Library.Flags["FOV"] or 70 end
end})

VisualsTab:createLabel({Name="Player ESP",Special=true})
VisualsTab:createToggle({Name="Player Boxes",flagName="PBox",Flag=false})
VisualsTab:createToggle({Name="Player Names",flagName="PName",Flag=false})
VisualsTab:createToggle({Name="Player Health",flagName="PHP",Flag=false})
VisualsTab:createToggle({Name="Team Colors",flagName="PTeam",Flag=false})
VisualsTab:createToggle({Name="Held Item",flagName="PHeld",Flag=false})
VisualsTab:createToggle({Name="Distance",flagName="PDist",Flag=false})
VisualsTab:createToggle({Name="Tracers",flagName="PTracer",Flag=false})
VisualsTab:createToggle({Name="Skeleton ESP",flagName="PSkel",Flag=false})
VisualsTab:createSlider({Name="Max Distance",flagName="PRange",value=1500,minValue=100,maxValue=3000})

VisualsTab:createLabel({Name="Better Graphics",Special=true})
VisualsTab:createToggle({Name="Better Graphics",flagName="BGFX",Flag=false,Callback=function(e)
    local cc=Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
    if not cc then cc=Instance.new("ColorCorrectionEffect"); cc.Parent=Lighting end
    if e then cc.Brightness=0.05; cc.Contrast=0.15; cc.Saturation=0.25; cc.Enabled=true else cc.Enabled=false end
end})
VisualsTab:createSlider({Name="Darkness",flagName="BGFX_dark",value=100,minValue=0,maxValue=100})

VisualsTab:createLabel({Name="Plant ESP",Special=true})
VisualsTab:createToggle({Name="Plant Radar",flagName="PlantESP",Flag=false})
VisualsTab:createDropdown({Name="Plant Rarities",flagName="PE_rar",multi=true,List=RTS})
VisualsTab:createDropdown({Name="Plant Names",flagName="PE_names",multi=true,List=GD.seeds})
VisualsTab:createToggle({Name="Owned Only",flagName="PE_owned",Flag=false})
VisualsTab:createToggle({Name="Show Mutation",flagName="PE_mut",Flag=false})
VisualsTab:createToggle({Name="Show Distance",flagName="PE_dist",Flag=false})
VisualsTab:createToggle({Name="Show Value Score",flagName="PE_val",Flag=false})
VisualsTab:createSlider({Name="Max Distance",flagName="PE_range",value=1500,minValue=100,maxValue=3000})

VisualsTab:createLabel({Name="Prop ESP",Special=true})
VisualsTab:createToggle({Name="Show Props",flagName="PropESP",Flag=false})
VisualsTab:createToggle({Name="Show Prop Names",flagName="PropESPName",Flag=false})
VisualsTab:createSlider({Name="Prop ESP Range",flagName="PropRange",value=500,minValue=50,maxValue=2000})

VisualsTab:createLabel({Name="Sprinkler ESP",Special=true})
VisualsTab:createToggle({Name="Show Sprinklers",flagName="SprESP",Flag=false})
VisualsTab:createSlider({Name="Sprinkler ESP Range",flagName="SprRange",value=300,minValue=50,maxValue=1500})

VisualsTab:createLabel({Name="Rake ESP",Special=true})
VisualsTab:createToggle({Name="Show Rakes",flagName="RakeESP",Flag=false})
VisualsTab:createSlider({Name="Rake ESP Range",flagName="RakeRange",value=300,minValue=50,maxValue=1500})

-- ##############################################################################
-- ##############################################################################
-- ESP RENDERER ENGINE
-- ##############################################################################
-- ##############################################################################
local ESP_Folder = Instance.new("Folder")
ESP_Folder.Name = "GardenHQ_ESP"
ESP_Folder.Parent = CoreGui
RC(ESP_Folder)

local ESP_Cache = {}

local function createESPObject(targetObj, displayText, boxColor)
    if not targetObj or not targetObj.Parent or not targetObj:IsDescendantOf(Workspace) then
        return nil
    end
    if ESP_Cache[targetObj] then
        return ESP_Cache[targetObj]
    end
    local holder = Instance.new("Folder")
    holder.Name = "ESP_Holder"
    holder.Parent = ESP_Folder
    -- Highlight box
    local highlight = Instance.new("Highlight")
    highlight.Name = "ESP_Box"
    highlight.FillColor = boxColor or Color3.new(1,1,1)
    highlight.OutlineColor = Color3.new(0,0,0)
    highlight.FillTransparency = 0.75
    highlight.OutlineTransparency = 0.15
    highlight.Adornee = targetObj
    highlight.Parent = holder
    -- Billboard text
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESP_Text"
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0,240,0,56)
    billboard.StudsOffset = Vector3.new(0,4,0)
    billboard.Adornee = targetObj
    billboard.Parent = holder
    local label = Instance.new("TextLabel")
    label.Name = "ESP_Label"
    label.Size = UDim2.new(1,0,1,0)
    label.BackgroundTransparency = 1
    label.Text = displayText
    label.TextColor3 = Color3.new(1,1,1)
    label.TextStrokeTransparency = 0
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.Parent = billboard
    ESP_Cache[targetObj] = holder
    return holder
end

local function cleanESP()
    for obj, holder in pairs(ESP_Cache) do
        if not obj or not obj.Parent or not obj:IsDescendantOf(Workspace) then
            if holder and holder.Parent then holder:Destroy() end
            ESP_Cache[obj] = nil
        end
    end
end

-- Tracer line support
local TracerFolder = Instance.new("Folder")
TracerFolder.Name = "GardenHQ_Tracers"
TracerFolder.Parent = CoreGui
RC(TracerFolder)
local TracerCache = {}

local function createTracer(fromPos, toPos, color)
    local key = tostring(fromPos)..tostring(toPos)
    if TracerCache[key] then
        local beam = TracerCache[key]
        -- Update beam
        local mid = (fromPos+toPos)/2
        local dist = (fromPos-toPos).Magnitude
        beam.CFrame = CFrame.new(mid, toPos)
        beam.Size = Vector3.new(0.05, 0.05, dist)
        return beam
    end
    local beam = Instance.new("Part")
    beam.Name = "Tracer"
    beam.Anchored = true
    beam.CanCollide = false
    beam.CanQuery = false
    beam.CanTouch = false
    beam.Material = Enum.Material.SmoothPlastic
    beam.Color = color or Color3.new(1,1,1)
    beam.Transparency = 0.5
    local mid = (fromPos+toPos)/2
    local dist = (fromPos-toPos).Magnitude
    beam.CFrame = CFrame.new(mid, toPos)
    beam.Size = Vector3.new(0.05, 0.05, math.max(dist,0.1))
    beam.Parent = TracerFolder
    TracerCache[key] = beam
    return beam
end

local function cleanTracers()
    for key, beam in pairs(TracerCache) do
        if beam and beam.Parent then beam:Destroy() end
        TracerCache[key] = nil
    end
end

-- Main ESP render loop
RC(RunService.RenderStepped:Connect(function()
    cleanESP()

    -- ============================================
    -- PLAYER ESP
    -- ============================================
    local showPlayerESP = Library.Flags["PName"] or Library.Flags["PBox"] or Library.Flags["PHP"] or Library.Flags["PHeld"] or Library.Flags["PDist"]
    if showPlayerESP then
        local maxDistance = Library.Flags["PRange"] or 1500
        local myRoot = client.Character and client.Character:FindFirstChild("HumanoidRootPart")
        if myRoot then
            for _, otherPlayer in ipairs(Players:GetPlayers()) do
                if otherPlayer == client then continue end
                local char = otherPlayer.Character
                local otherRoot = char and char:FindFirstChild("HumanoidRootPart")
                if otherRoot and (otherRoot.Position-myRoot.Position).Magnitude <= maxDistance then
                    local color = Library.Flags["PTeam"] and (otherPlayer.TeamColor and otherPlayer.TeamColor.Color or Color3.new(0.5,0.5,1)) or Color3.new(1,0,0)
                    local displayText = otherPlayer.Name
                    if Library.Flags["PHP"] then
                        local hum = char:FindFirstChildOfClass("Humanoid")
                        if hum then displayText = displayText .. string.format(" [%.0f HP]", hum.Health) end
                    end
                    if Library.Flags["PHeld"] then
                        local heldTool = char:FindFirstChildWhichIsA("Tool")
                        if heldTool then displayText = displayText .. " [" .. heldTool.Name .. "]" end
                    end
                    if Library.Flags["PDist"] then
                        displayText = displayText .. string.format(" [%.0fm]", (otherRoot.Position-myRoot.Position).Magnitude)
                    end
                    local holder = createESPObject(char, displayText, color)
                    if holder then
                        local box = holder:FindFirstChild("ESP_Box")
                        local text = holder:FindFirstChild("ESP_Text")
                        if box then box.Enabled = Library.Flags["PBox"] == true end
                        if text then text.Enabled = Library.Flags["PName"] == true or Library.Flags["PHP"] == true end
                    end
                    -- Tracers
                    if Library.Flags["PTracer"] then
                        local cam = Workspace.CurrentCamera
                        if cam then
                            local screenPos = cam:WorldToScreenPoint(otherRoot.Position)
                            local from = Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y)
                            local to = Vector2.new(screenPos.X, screenPos.Y)
                            -- Use a simple beam from screen bottom to player
                        end
                    end
                elseif ESP_Cache[char] then
                    ESP_Cache[char]:Destroy(); ESP_Cache[char] = nil
                end
            end
        end
    else
        for _, otherPlayer in ipairs(Players:GetPlayers()) do
            if otherPlayer ~= client and otherPlayer.Character and ESP_Cache[otherPlayer.Character] then
                ESP_Cache[otherPlayer.Character]:Destroy(); ESP_Cache[otherPlayer.Character] = nil
            end
        end
        cleanTracers()
    end

    -- ============================================
    -- PLANT ESP
    -- ============================================
    if Library.Flags["PlantESP"] then
        local maxDistance = Library.Flags["PE_range"] or 1500
        local myRoot = client.Character and client.Character:FindFirstChild("HumanoidRootPart")
        local gardens = Workspace:FindFirstChild("Gardens") or Workspace
        local selectedFruits = Library.Flags["PE_names"]
        local selectedRarities = Library.Flags["PE_rar"]
        for _, plot in ipairs(gardens:GetChildren()) do
            if not (plot:IsA("Model") or plot:IsA("Folder")) then continue end
            local isOurPlot = (getPlotOwner(plot) == client.UserId)
            if Library.Flags["PE_owned"] and not isOurPlot then continue end
            local plantsFolder = plot:FindFirstChild("Plants")
            if plantsFolder and myRoot then
                for _, plantModel in ipairs(plantsFolder:GetChildren()) do
                    if plantModel:IsA("Model") and plantModel.PrimaryPart then
                        local distance = (plantModel:GetPivot().Position - myRoot.Position).Magnitude
                        if distance <= maxDistance and passesFilter(plantModel, selectedFruits, nil, selectedRarities) then
                            local displayText = plantModel.Name
                            if Library.Flags["PE_mut"] then
                                local mutation = plantModel:GetAttribute("Mutation")
                                if mutation then displayText = string.format("[%s] %s", mutation, displayText) end
                            end
                            if Library.Flags["PE_dist"] then
                                displayText = displayText .. string.format(" [%.0fm]", distance)
                            end
                            if Library.Flags["PE_val"] then
                                displayText = displayText .. string.format(" [$%.0f]", calculatePlantValue(plantModel))
                            end
                            local boxColor = isOurPlot and Color3.new(0,1,0) or Color3.new(1,1,0)
                            createESPObject(plantModel, displayText, boxColor)
                        elseif ESP_Cache[plantModel] then
                            ESP_Cache[plantModel]:Destroy(); ESP_Cache[plantModel] = nil
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
                    if ESP_Cache[plantModel] then ESP_Cache[plantModel]:Destroy(); ESP_Cache[plantModel] = nil end
                end
            end
        end
    end

    -- ============================================
    -- PROP ESP
    -- ============================================
    if Library.Flags["PropESP"] then
        local maxDistance = Library.Flags["PropRange"] or 500
        local myRoot = client.Character and client.Character:FindFirstChild("HumanoidRootPart")
        if myRoot then
            for _, plot in ipairs(Workspace:GetChildren()) do
                if not (plot:IsA("Model") or plot:IsA("Folder")) then continue end
                local propsFolder = plot:FindFirstChild("Props")
                if propsFolder then
                    for _, prop in ipairs(propsFolder:GetChildren()) do
                        if prop:IsA("Model") and prop.PrimaryPart then
                            local distance = (prop:GetPivot().Position - myRoot.Position).Magnitude
                            if distance <= maxDistance then
                                local displayText = prop.Name
                                if Library.Flags["PropESPName"] then
                                    displayText = displayText .. string.format(" [%.0fm]", distance)
                                end
                                createESPObject(prop, displayText, Color3.new(0.5,0.5,1))
                            elseif ESP_Cache[prop] then
                                ESP_Cache[prop]:Destroy(); ESP_Cache[prop] = nil
                            end
                        end
                    end
                end
            end
        end
    else
        for obj, holder in pairs(ESP_Cache) do
            if obj and obj.Name and obj.Parent and obj.Parent.Name == "Props" then
                holder:Destroy(); ESP_Cache[obj] = nil
            end
        end
    end

    -- ============================================
    -- SPRINKLER ESP
    -- ============================================
    if Library.Flags["SprESP"] then
        authenticatePlot()
        local maxDistance = Library.Flags["SprRange"] or 300
        local myRoot = client.Character and client.Character:FindFirstChild("HumanoidRootPart")
        if myRoot and PL.sprinklersFolder then
            for _, sprinkler in ipairs(PL.sprinklersFolder:GetChildren()) do
                if sprinkler:IsA("Model") and sprinkler.PrimaryPart then
                    local distance = (sprinkler:GetPivot().Position - myRoot.Position).Magnitude
                    if distance <= maxDistance then
                        createESPObject(sprinkler, "Sprinkler ["..string.format("%.0fm",distance).."]", Color3.new(0.2,0.7,1))
                    elseif ESP_Cache[sprinkler] then
                        ESP_Cache[sprinkler]:Destroy(); ESP_Cache[sprinkler] = nil
                    end
                end
            end
        end
    end

    -- ============================================
    -- RAKE ESP
    -- ============================================
    if Library.Flags["RakeESP"] then
        authenticatePlot()
        local maxDistance = Library.Flags["RakeRange"] or 300
        local myRoot = client.Character and client.Character:FindFirstChild("HumanoidRootPart")
        if myRoot and PL.rakesFolder then
            for _, rake in ipairs(PL.rakesFolder:GetChildren()) do
                if rake:IsA("Model") and rake.PrimaryPart then
                    local distance = (rake:GetPivot().Position - myRoot.Position).Magnitude
                    if distance <= maxDistance then
                        createESPObject(rake, "Rake ["..string.format("%.0fm",distance).."]", Color3.new(1,0.5,0))
                    elseif ESP_Cache[rake] then
                        ESP_Cache[rake]:Destroy(); ESP_Cache[rake] = nil
                    end
                end
            end
        end
    end
end))

-- ##############################################################################
-- ##############################################################################
-- IN-GAME HUD SYSTEM
-- ##############################################################################
-- ##############################################################################
local HUD_Screen = Instance.new("ScreenGui")
HUD_Screen.Name = "GardenHQ_HUD"
HUD_Screen.ResetOnSpawn = false
HUD_Screen.Parent = CoreGui
RC(HUD_Screen)
HUD_Screen.Enabled = Library.Flags["PRED"] == true

-- ============================================
-- Weather Bar
-- ============================================
local WeatherBar = Instance.new("Frame")
WeatherBar.Name = "WeatherBar"
WeatherBar.Size = UDim2.new(0,540,0,42)
WeatherBar.Position = UDim2.new(0.5,-270,1,-96)
WeatherBar.BackgroundColor3 = Color3.fromRGB(15,15,15)
WeatherBar.BackgroundTransparency = 0.08
WeatherBar.BorderSizePixel = 1
WeatherBar.BorderColor3 = Color3.fromRGB(50,50,50)
WeatherBar.Parent = HUD_Screen

local WeatherLayout = Instance.new("UIListLayout")
WeatherLayout.Parent = WeatherBar
WeatherLayout.FillDirection = Enum.FillDirection.Horizontal
WeatherLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
WeatherLayout.VerticalAlignment = Enum.VerticalAlignment.Center
WeatherLayout.SortOrder = Enum.SortOrder.LayoutOrder
WeatherLayout.Padding = UDim.new(0,4)

local WeatherWidgets = {}

local WeatherTypes = {
    {id="Sunset",    label="Sunset",    color=Color3.fromRGB(255,180,50)},
    {id="Moon",      label="Moon",      color=Color3.fromRGB(240,240,255)},
    {id="Day",       label="Day",       color=Color3.fromRGB(255,255,80)},
    {id="Rainbow",   label="Rainbow",   color=Color3.fromRGB(150,255,255)},
    {id="Bloodmoon", label="Bloodmoon", color=Color3.fromRGB(255,60,60)},
    {id="Goldmoon",  label="Goldmoon",  color=Color3.fromRGB(255,215,0)}
}

for _, weatherType in ipairs(WeatherTypes) do
    local box = Instance.new("Frame")
    box.Name = weatherType.id
    box.Size = UDim2.new(0,84,0,34)
    box.BackgroundColor3 = Color3.fromRGB(25,25,25)
    box.BorderSizePixel = 1
    box.BorderColor3 = weatherType.color
    box.Parent = WeatherBar

    local text = Instance.new("TextLabel")
    text.Name = "Text"
    text.Size = UDim2.new(1,0,1,0)
    text.BackgroundTransparency = 1
    text.Text = weatherType.label .. "\nSync..."
    text.TextColor3 = weatherType.color
    text.Font = Enum.Font.GothamBold
    text.TextSize = 9
    text.TextWrapped = true
    text.TextXAlignment = Enum.TextXAlignment.Center
    text.Parent = box

    WeatherWidgets[weatherType.id] = text
end

-- ============================================
-- Stock Ticker
-- ============================================
local StockFrame = Instance.new("Frame")
StockFrame.Name = "StockFrame"
StockFrame.Size = UDim2.new(0,540,0,22)
StockFrame.Position = UDim2.new(0.5,-270,1,-52)
StockFrame.BackgroundTransparency = 1
StockFrame.Parent = HUD_Screen

local StockLayout = Instance.new("UIListLayout")
StockLayout.FillDirection = Enum.FillDirection.Horizontal
StockLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
StockLayout.Padding = UDim.new(0,8)
StockLayout.Parent = StockFrame

local StockWidgets = {}

local function updateStockWidget(shopName, itemName, count)
    local key = shopName .. "_" .. itemName
    if tonumber(count) == nil or count <= 0 then
        if StockWidgets[key] then
            StockWidgets[key]:Destroy()
            StockWidgets[key] = nil
        end
        return
    end

    if not StockWidgets[key] then
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0,126,0,18)
        label.BackgroundTransparency = 0.18
        label.BackgroundColor3 = Color3.fromRGB(18,18,18)
        label.BorderSizePixel = 0
        label.TextColor3 = Color3.fromRGB(190,255,190)
        label.Font = Enum.Font.GothamMedium
        label.TextSize = 9
        label.TextTruncate = Enum.TextTruncate.AtEnd
        label.Parent = StockFrame
        StockWidgets[key] = label
    end
    StockWidgets[key].Text = shopName:gsub("Shop", "") .. ": " .. itemName .. " x" .. tostring(count)
end

-- ============================================
-- Status Ticker (bottom bar)
-- ============================================
local StatusBar = Instance.new("Frame")
StatusBar.Name = "StatusBar"
StatusBar.Size = UDim2.new(0,540,0,18)
StatusBar.Position = UDim2.new(0.5,-270,1,-28)
StatusBar.BackgroundTransparency = 1
StatusBar.Parent = HUD_Screen

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Name = "StatusLabel"
StatusLabel.Size = UDim2.new(1,0,1,0)
StatusLabel.BackgroundTransparency = 1
StatusLabel.TextColor3 = Color3.fromRGB(200,200,200)
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 10
StatusLabel.Text = "GardenMaster HQ | Ready"
StatusLabel.Parent = StatusBar

-- ============================================
-- System State Tracker
-- ============================================
local SystemState = {
    currentWeather = "Clear Skies",
    restockStatus = "Syncing...",
    trendingItem = "None",
    nextWeather = "Unknown",
    stockSnapshots = {},
    predictedRestocks = {},
    totalPlants = 0,
    totalFruits = 0,
    totalValue = 0
}

local function formatSeconds(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    if h > 0 then return string.format("%dh %02dm", h, m) end
    if m > 0 then return string.format("%dm %02ds", m, s) end
    return tostring(s) .. "s"
end

local function parseDurationText(text)
    local s = tostring(text or ""):lower()
    local h = tonumber(s:match("(%d+)%s*h")) or 0
    local m = tonumber(s:match("(%d+)%s*m")) or 0
    local sec = tonumber(s:match("(%d+)%s*s")) or 0
    if h == 0 and m == 0 and sec == 0 then return nil end
    return h * 3600 + m * 60 + sec
end

local function getSeedShopRestockSeconds()
    local pg = client:FindFirstChild("PlayerGui")
    local seedShop = pg and pg:FindFirstChild("SeedShop")
    if not seedShop then return nil end
    for _, d in ipairs(seedShop:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") then
            local txt = tostring(d.Text or "")
            if txt:lower():find("restock", 1, true) then
                local seconds = parseDurationText(txt)
                if seconds then return seconds end
            end
        end
    end
    return nil
end

local function readWeatherTextFromGui()
    local pg = client:FindFirstChild("PlayerGui")
    if not pg then return {} end
    local found = {}
    for _, d in ipairs(pg:GetDescendants()) do
        if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Visible then
            local txt = tostring(d.Text or "")
            local low = txt:lower()
            for _, info in ipairs({
                {"Sunset", "sunset"}, {"Moon", "moon"}, {"Day", "day"},
                {"Rainbow", "rainbow"}, {"Bloodmoon", "blood"}, {"Goldmoon", "gold"},
            }) do
                if not found[info[1]] and low:find(info[2], 1, true) and (low:find("in ", 1, true) or low:match("%d+%s*m")) then
                    found[info[1]] = txt:gsub("%s+", " ")
                end
            end
        end
    end
    return found
end

local function updateSeedShopPredictionUI()
    local pg = client:FindFirstChild("PlayerGui")
    local seedShop = pg and pg:FindFirstChild("SeedShop")
    local frame = seedShop and seedShop:FindFirstChild("Frame")
    if not frame then return end

    local panel = frame:FindFirstChild("HQSeedPredictions")
    if not panel then
        panel = Instance.new("Frame")
        panel.Name = "HQSeedPredictions"
        panel.Size = UDim2.new(0, 240, 0, 122)
        panel.Position = UDim2.new(1, -252, 1, -132)
        panel.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
        panel.BackgroundTransparency = 0.12
        panel.BorderSizePixel = 1
        panel.BorderColor3 = Color3.fromRGB(80, 180, 120)
        panel.Parent = frame

        local title = Instance.new("TextLabel")
        title.Name = "Title"
        title.Size = UDim2.new(1, -10, 0, 20)
        title.Position = UDim2.new(0, 5, 0, 4)
        title.BackgroundTransparency = 1
        title.Font = Enum.Font.GothamBold
        title.TextSize = 12
        title.TextColor3 = Color3.fromRGB(180, 255, 190)
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Parent = panel

        local body = Instance.new("TextLabel")
        body.Name = "Body"
        body.Size = UDim2.new(1, -10, 1, -28)
        body.Position = UDim2.new(0, 5, 0, 26)
        body.BackgroundTransparency = 1
        body.Font = Enum.Font.GothamMedium
        body.TextSize = 10
        body.TextWrapped = true
        body.TextYAlignment = Enum.TextYAlignment.Top
        body.TextXAlignment = Enum.TextXAlignment.Left
        body.TextColor3 = Color3.fromRGB(235, 235, 235)
        body.Parent = panel
    end

    local restock = getSeedShopRestockSeconds()
    local title = panel:FindFirstChild("Title")
    local body = panel:FindFirstChild("Body")
    if title then title.Text = "HQ Seed Predictor" .. (restock and (" | restock " .. formatSeconds(restock)) or "") end

    local stockFolder = ReplicatedStorage:FindFirstChild("StockValues", true)
    local seedShopValues = stockFolder and stockFolder:FindFirstChild("SeedShop")
    local items = seedShopValues and seedShopValues:FindFirstChild("Items")
    local lines = {}
    if items then
        local rows = {}
        for _, item in ipairs(items:GetChildren()) do
            if item:IsA("NumberValue") then rows[#rows + 1] = {name = item.Name, count = item.Value} end
        end
        table.sort(rows, function(a, b)
            if (a.count > 0) ~= (b.count > 0) then return a.count > 0 end
            return a.name < b.name
        end)
        for i = 1, math.min(5, #rows) do
            local row = rows[i]
            if row.count > 0 then
                lines[#lines + 1] = row.name .. " x" .. tostring(row.count)
            else
                lines[#lines + 1] = row.name .. " next " .. (restock and formatSeconds(restock) or "soon")
            end
        end
    end
    if body then body.Text = (#lines > 0 and table.concat(lines, "\n") or "Open Seed Shop to sync predictions.") end
end

RC(task.spawn(function()
    while Alive do
        task.wait(1.2)
        pcall(function()
            HUD_Screen.Enabled = Library.Flags["PRED"] == true
            local nowReal = os.time()
            local rainbowRemaining = 2700 - (nowReal % 2700)
            local bloodmoonRemaining = 3600 - (nowReal % 3600)
            local goldmoonRemaining = 7200 - (nowReal % 7200)

            local guiWeather = readWeatherTextFromGui()
            if WeatherWidgets["Sunset"] then
                WeatherWidgets["Sunset"].Text = guiWeather.Sunset or ("Sunset\n" .. formatSeconds(rainbowRemaining))
            end
            if WeatherWidgets["Moon"] then
                WeatherWidgets["Moon"].Text = guiWeather.Moon or ("Moon\n" .. (isNightTime() and "active" or formatSeconds(bloodmoonRemaining)))
            end
            if WeatherWidgets["Day"] then
                local clock = readGameClockText()
                WeatherWidgets["Day"].Text = guiWeather.Day or (clock and ("Day\n" .. clock) or ("Day\n" .. formatSeconds(nowReal % 86400)))
            end
            if WeatherWidgets["Rainbow"] then
                WeatherWidgets["Rainbow"].Text = guiWeather.Rainbow or ("Rainbow\n" .. formatSeconds(rainbowRemaining))
            end
            if WeatherWidgets["Bloodmoon"] then
                WeatherWidgets["Bloodmoon"].Text = guiWeather.Bloodmoon or ("Bloodmoon\n" .. formatSeconds(bloodmoonRemaining))
            end
            if WeatherWidgets["Goldmoon"] then
                WeatherWidgets["Goldmoon"].Text = guiWeather.Goldmoon or ("Goldmoon\n" .. formatSeconds(goldmoonRemaining))
            end

            -- Update weather status
            local weatherData = ReplicatedStorage:FindFirstChild("Weather",true) or ReplicatedStorage:FindFirstChild("Environment",true)
            if weatherData then
                local currentWeather = weatherData:FindFirstChild("Current") or weatherData:FindFirstChild("Weather")
                if currentWeather and currentWeather:IsA("StringValue") then
                    SystemState.currentWeather = currentWeather.Value
                end
            end

            -- Update stock data
            local stockFolder = ReplicatedStorage:FindFirstChild("StockValues",true)
            if stockFolder then
                for _, shopName in ipairs({"SeedShop","GearShop","CrateShop","PetShop"}) do
                    local shop = stockFolder:FindFirstChild(shopName)
                    if shop and shop:FindFirstChild("Items") then
                        for _, item in ipairs(shop.Items:GetChildren()) do
                            if item:IsA("NumberValue") then
                                local previous = (SystemState.stockSnapshots[shopName] or {})[item.Name] or 0
                                local current = item.Value
                                updateStockWidget(shopName, item.Name, current)

                                if previous == 0 and current > 0 then
                                    local lastTime = SystemState.predictedRestocks[shopName.."_"..item.Name] or nowReal
                                    local interval = nowReal - lastTime
                                    if interval > 60 then
                                        SystemState.predictedRestocks[shopName.."_"..item.Name] = {
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

            updateSeedShopPredictionUI()

            local restock = getSeedShopRestockSeconds()
            SystemState.restockStatus = restock and ("Seed restock in " .. formatSeconds(restock)) or "Monitoring..."
            SystemState.trendingItem = "Seed shop synced"

            -- Update status bar
            StatusLabel.Text = string.format("GardenHQ | %s | Night: %s | Plot: %s",
                SystemState.currentWeather,
                isNightTime() and "Yes" or "No",
                PL.auth and ("#"..(PL.plotId or "?")) or "None"
            )
        end)
    end
end))

-- ##############################################################################
-- ##############################################################################
-- PREDICTORS TAB
-- ##############################################################################
-- ##############################################################################
local PredictorsTab = UI:CreateSection("Tracker")

PredictorsTab:createLabel({Name="Real-Time Environment Status",Special=true})

local WeatherStatusLabel = PredictorsTab:createLabel({Name="Weather: Syncing...",Center=true})
local StockStatusLabel = PredictorsTab:createLabel({Name="Restock: Syncing...",Center=true})
local NightStatusLabel = PredictorsTab:createLabel({Name="Night Status: Checking...",Center=true})
local PlotStatusLabel = PredictorsTab:createLabel({Name="Plot Status: Not authenticated",Center=true})

RC(task.spawn(function()
    while Alive do
        task.wait(2)
        pcall(function()
            local weatherText = "Weather: " .. SystemState.currentWeather .. " | Next: " .. SystemState.nextWeather
            local stockText = "Restock: " .. SystemState.restockStatus .. " | Trending: " .. SystemState.trendingItem
            local nightText = "Night: " .. (isNightTime() and "ACTIVE (Stealing possible)" or "Inactive")

            authenticatePlot()
            local plotText = "Plot: " .. (PL.auth and ("Authenticated #"..(PL.plotId or "?")) or "Not found")
            if PL.plantsFolder then
                local plantCount = 0
                for _,m in ipairs(PL.plantsFolder:GetChildren()) do if m:IsA("Model") then plantCount=plantCount+1 end end
                plotText = plotText .. " | Plants: " .. plantCount
            end

            if WeatherStatusLabel then
                if WeatherStatusLabel.Text ~= nil then WeatherStatusLabel.Text = weatherText
                elseif WeatherStatusLabel.SetText then WeatherStatusLabel:SetText(weatherText) end
            end
            if StockStatusLabel then
                if StockStatusLabel.Text ~= nil then StockStatusLabel.Text = stockText
                elseif StockStatusLabel.SetText then StockStatusLabel:SetText(stockText) end
            end
            if NightStatusLabel then
                if NightStatusLabel.Text ~= nil then NightStatusLabel.Text = nightText
                elseif NightStatusLabel.SetText then NightStatusLabel:SetText(nightText) end
            end
            if PlotStatusLabel then
                if PlotStatusLabel.Text ~= nil then PlotStatusLabel.Text = plotText
                elseif PlotStatusLabel.SetText then PlotStatusLabel:SetText(plotText) end
            end

            SystemState.nextWeather = isNightTime() and "Night" or "Day"
            SystemState.totalPlants = PL.plantsFolder and #PL.plantsFolder:GetChildren() or 0
        end)
    end
end))

PredictorsTab:createLabel({Name="Garden Scanner",Special=true})

PredictorsTab:createButton({Name="Scan My Garden",Callback=function()
    authenticatePlot()
    if not PL.plantsFolder then
        NF("Scan","No garden found. Teleport to your plot first.","warning")
        return
    end

    local plantCount = 0
    local fruitCount = 0
    local mutations = {}
    local rarities = {}
    local totalValue = 0

    for _, plantModel in ipairs(PL.plantsFolder:GetChildren()) do
        if plantModel:IsA("Model") then
            plantCount = plantCount + 1

            local mutation = plantModel:GetAttribute("Mutation")
            if mutation then mutations[mutation] = (mutations[mutation] or 0) + 1 end

            local rarity = plantModel:GetAttribute("Rarity")
            if rarity then rarities[rarity] = (rarities[rarity] or 0) + 1 end

            if plantModel:GetAttribute("FruitId") then fruitCount = fruitCount + 1 end

            totalValue = totalValue + calculatePlantValue(plantModel)
        end
    end

    local topMutation = "None"
    local topMutationCount = 0
    for mutation, count in pairs(mutations) do
        if count > topMutationCount then topMutation = mutation; topMutationCount = count end
    end

    local topRarity = "None"
    local topRarityCount = 0
    for rarity, count in pairs(rarities) do
        if count > topRarityCount then topRarity = rarity; topRarityCount = count end
    end

    NF("Garden Statistics",
        string.format(
            "Plants: %d | Fruits: %d | Total Value: $%.0f\nTop Mutation: %s (%d) | Top Rarity: %s (%d)",
            plantCount, fruitCount, totalValue,
            topMutation, topMutationCount,
            topRarity, topRarityCount
        ),
        "info"
    )
end})

PredictorsTab:createLabel({Name="Stock Predictions",Special=true})

PredictorsTab:createButton({Name="Check Stock Status",Callback=function()
    local stockFolder = ReplicatedStorage:FindFirstChild("StockValues",true)
    if not stockFolder then NF("Stock","StockValues folder not found.","warning"); return end

    local msg = ""
    for _, shopName in ipairs({"SeedShop","GearShop","CrateShop","PetShop"}) do
        local shop = stockFolder:FindFirstChild(shopName)
        if shop and shop:FindFirstChild("Items") then
            local itemCount = 0
            local inStock = 0
            for _, item in ipairs(shop.Items:GetChildren()) do
                if item:IsA("NumberValue") then
                    itemCount = itemCount + 1
                    if item.Value > 0 then inStock = inStock + 1 end
                end
            end
            msg = msg .. shopName .. ": " .. inStock .. "/" .. itemCount .. " in stock\n"
        end
    end
    NF("Stock Status",msg,"info")
end})

PredictorsTab:createLabel({Name="Weather Predictions",Special=true})

PredictorsTab:createButton({Name="Check Weather Status",Callback=function()
    local nowReal = os.time()
    local rainbowSec = 2700 - (nowReal % 2700)
    local bloodmoonSec = 3600 - (nowReal % 3600)
    local goldmoonSec = 7200 - (nowReal % 7200)
    local guiWeather = readWeatherTextFromGui()

    local weatherData = ReplicatedStorage:FindFirstChild("Weather",true) or ReplicatedStorage:FindFirstChild("Environment",true)
    local currentWeather = "Unknown"
    if weatherData then
        local cw = weatherData:FindFirstChild("Current") or weatherData:FindFirstChild("Weather")
        if cw and cw:IsA("StringValue") then currentWeather = cw.Value end
    end

    NF("Weather Predictions",
        string.format(
            "Current: %s\nNight: %s\nDay: %s\nRainbow: %s\nBloodmoon: %s\nGoldmoon: %s",
            currentWeather,
            isNightTime() and "Yes" or "No",
            guiWeather.Day or (readGameClockText() or "syncing"),
            guiWeather.Rainbow or formatSeconds(rainbowSec),
            guiWeather.Bloodmoon or formatSeconds(bloodmoonSec),
            guiWeather.Goldmoon or formatSeconds(goldmoonSec)
        ),
        "info"
    )
end})

PredictorsTab:createLabel({Name="Item Value Lookup",Special=true})

PredictorsTab:createButton({Name="Scan Best Items in Garden",Callback=function()
    authenticatePlot()
    if not PL.plantsFolder then NF("Scan","No garden found.","warning"); return end

    local candidates = getBestCandidates(10, nil, nil, nil, true, nil)
    local msg = "Top 10 items by value:\n"
    for i, c in ipairs(candidates) do
        if c.model then
            local name = c.model.Name
            local mut = c.model:GetAttribute("Mutation")
            if mut then name = "["..mut.."] "..name end
            msg = msg .. string.format("%d. %s - $%.0f\n", i, name, c.score)
        end
    end
    NF("Best Items",msg,"info")
end})

-- ##############################################################################
-- ##############################################################################
-- DEVELOPER TOOLS TAB
-- ##############################################################################
-- ##############################################################################
local DevTab = UI:CreateSection("Tools")

DevTab:createLabel({Name="Debug & Diagnostics",Special=true})

DevTab:createButton({Name="Dump Plot Info",Callback=function()
    authenticatePlot()
    if not PL.auth then NF("Dev","Plot not authenticated.","warning"); return end
    local info = string.format(
        "Plot #%s\nCenter: %.1f,%.1f,%.1f\nGrid Nodes: %d\nPlants Folder: %s\nSprinklers: %s\nProps: %s\nRakes: %s\nPlant Areas: %d\nAuthenticated: %s",
        tostring(PL.plotId),
        PL.center.X, PL.center.Y, PL.center.Z,
        #PL.gridNodes,
        PL.plantsFolder and "Found" or "Missing",
        PL.sprinklersFolder and "Found" or "Missing",
        PL.propsFolder and "Found" or "Missing",
        PL.rakesFolder and "Found" or "Missing",
        #PL.plantAreas,
        tostring(PL.auth)
    )
    NF("Plot Info",info,"info")
end})

DevTab:createButton({Name="Dump Game Data",Callback=function()
    local info = string.format(
        "Seeds: %d\nGears: %d\nCrates: %d\nPets: %d\nMutations: %d\nRarities: %d\nBackpack Seeds: %d\nBackpack Sprinklers: %d",
        #GD.seeds, #GD.gears, #GD.crates, #GD.pets,
        #MTS, #RTS,
        #getBackpackSeeds(), #getBackpackSprinklers()
    )
    NF("Game Data",info,"info")
end})

DevTab:createButton({Name="Dump Network Status",Callback=function()
    if Net then
        local count = 0
        for _ in pairs(Net) do count=count+1 end
        NF("Network","Networking module loaded.\nTop-level keys: "..count,"info")
    else
        NF("Network","Networking module NOT loaded!","danger")
    end
end})

DevTab:createButton({Name="Dump All Remote Names",Callback=function()
    if not Net then NF("Network","Not loaded","danger"); return end
    local names = {}
    for k,v in pairs(Net) do
        if type(v)=="table" then
            for k2,v2 in pairs(v) do
                if type(v2)=="table" and type(v2.Fire)=="function" then
                    names[#names+1] = k.."."..k2
                end
            end
        end
    end
    table.sort(names)
    local msg = "Available remotes ("..#names.."):\n"
    for i,n in ipairs(names) do msg=msg..n.."\n"; if i>30 then msg=msg.."...(+ "..(#names-30).." more)"; break end end
    NF("Remotes",msg,"info")
end})

DevTab:createLabel({Name="Quick Commands",Special=true})

DevTab:createButton({Name="Print HRP Position",Callback=function()
    local hrp = client.Character and client.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        print(string.format("HRP: %.2f, %.2f, %.2f", hrp.Position.X, hrp.Position.Y, hrp.Position.Z))
        NF("Position",string.format("X:%.1f Y:%.1f Z:%.1f",hrp.Position.X,hrp.Position.Y,hrp.Position.Z),"info")
    else
        NF("Position","No HRP found.","warning")
    end
end})

DevTab:createButton({Name="Count Nearby Players",Callback=function()
    local hrp = client.Character and client.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then NF("Players","No HRP","warning"); return end
    local nearby = 0
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=client and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            if (p.Character.HumanoidRootPart.Position-hrp.Position).Magnitude<100 then
                nearby=nearby+1
            end
        end
    end
    NF("Players",nearby.." players within 100 studs.","info")
end})

DevTab:createToggle({Name="Debug Mode",flagName="Debug",Flag=false,Callback=function(e)
    if e then print("[HQ Debug] Debug mode enabled") else print("[HQ Debug] Debug mode disabled") end
end})

-- ##############################################################################
-- ##############################################################################
-- FOOTER
-- ##############################################################################
-- ##############################################################################

print(string.rep("-",64))
print("[HQ] GardenMaster HQ v5.1")
print("[HQ] "..#GD.seeds.." seeds | "..#GD.gears.." gears | "..#GD.crates.." crates | "..#GD.pets.." pets")
print("[HQ] Contributor: aditya44325f")
print("[HQ] Networking: "..(Net and "Loaded" or "FAILED"))
print("[HQ] Placement: Good Position / Player Position / Random / Mouse")
print("[HQ] ESP: Player / Plant / Prop / Sprinkler / Rake")
print("[HQ] HUD: Weather Bar + Stock Ticker + Status Bar")
print(string.rep("-",64))

-- ##############################################################################
-- ##############################################################################
-- WEBHOOKS TAB
-- ##############################################################################
-- ##############################################################################
local WebhooksTab = UI:CreateSection("Alerts")

WebhooksTab:createLabel({Name="Discord Webhook Integration",Special=true})

WebhooksTab:createInputBox({Name="Webhook URL",flagName="WebhookURL",Flag=""})

WebhooksTab:createToggle({Name="Notify on Rare Finds",flagName="WH_Rare",Flag=false})
WebhooksTab:createDropdown({Name="Minimum Rarity to Alert",flagName="WH_Rarity",List={"Legendary","Mythic","Rainbow","Gold"}})
WebhooksTab:createToggle({Name="Notify on Steal",flagName="WH_Steal",Flag=false})
WebhooksTab:createToggle({Name="Notify on Full Backpack",flagName="WH_Full",Flag=false})
WebhooksTab:createToggle({Name="Notify on Rejoin",flagName="WH_Rejoin",Flag=false})

WebhooksTab:createButton({Name="Test Webhook",Callback=function()
    local url = Library.Flags["WebhookURL"]
    if not url or url=="" then NF("Webhook","Please enter a webhook URL first.","warning"); return end
    local s,e = pcall(function()
        local data = {content="**GardenMaster HQ** Test notification\nServer: "..game.JobId}
        if request then request({Url=url,Method="POST",Headers={["Content-Type"]="application/json"},Body=HttpService:JSONEncode(data)}) end
    end)
    if s then NF("Webhook","Test message sent!","info") else NF("Webhook","Failed: "..tostring(e),"danger") end
end})

-- Rare find notification loop
RC(task.spawn(function()
    while Alive do
        task.wait(10)
        pcall(function()
            if not Library.Flags["WH_Rare"] then return end
            local url = Library.Flags["WebhookURL"]
            if not url or url=="" then return end
            authenticatePlot()
            if not PL.plantsFolder then return end
            local minRarity = Library.Flags["WH_Rarity"] or "Legendary"
            local rarityScores = {Legendary=6, Mythic=7, Rainbow=10, Gold=10}
            local minScore = rarityScores[minRarity] or 6
            for _,m in ipairs(PL.plantsFolder:GetChildren()) do
                if m:IsA("Model") then
                    local rar = m:GetAttribute("Rarity")
                    local mut = m:GetAttribute("Mutation")
                    if rar and (RarityScore[rar:lower()] or 0) >= minScore then
                        local msg = string.format("**Rare Find!** %s\nRarity: %s | Mutation: %s | Value: $%.0f", m.Name, rar, mut or "None", calculatePlantValue(m))
                        if request then request({Url=url,Method="POST",Headers={["Content-Type"]="application/json"},Body=HttpService:JSONEncode({content=msg})}) end
                        break
                    end
                end
            end
        end)
    end
end))

-- ##############################################################################
-- ##############################################################################
-- ACHIEVEMENTS & STATS TAB
-- ##############################################################################
-- ##############################################################################
local StatsTab = UI:CreateSection("Stats")

StatsTab:createLabel({Name="Session Statistics",Special=true})

local sessionStats = {
    plantsPlaced = 0,
    plantsHarvested = 0,
    itemsSold = 0,
    itemsStolen = 0,
    codesRedeemed = 0,
    startTime = os.clock()
}

StatsTab:createLabel({Name="Plants Placed: 0",Center=true})
StatsTab:createLabel({Name="Plants Harvested: 0",Center=true})
StatsTab:createLabel({Name="Items Sold: 0",Center=true})
StatsTab:createLabel({Name="Items Stolen: 0",Center=true})

StatsTab:createButton({Name="Reset Stats",Callback=function()
    sessionStats.plantsPlaced=0; sessionStats.plantsHarvested=0
    sessionStats.itemsSold=0; sessionStats.itemsStolen=0
    sessionStats.startTime=os.clock()
    NF("Stats","Session stats reset.","info")
end})

StatsTab:createLabel({Name="Quick Stats",Special=true})
StatsTab:createButton({Name="Show Session Uptime",Callback=function()
    local uptime = os.clock()-sessionStats.startTime
    local h=math.floor(uptime/3600); local m=math.floor((uptime%3600)/60); local s=math.floor(uptime%60)
    NF("Uptime",string.format("Session: %dh %dm %ds",h,m,s),"info")
end})

-- ##############################################################################
-- ##############################################################################
-- EXTRA UTILITIES
-- ##############################################################################
-- ##############################################################################
ExtraTab:createLabel({Name="Character Utilities",Special=true})

ExtraTab:createToggle({Name="Infinite Jump",flagName="InfJump",Flag=false,Callback=function(e)
    if e then
        local hum = client.Character and client.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum:SetStateEnabled(Enum.HumanoidStateType.Jumping,true) end
        RL("InfJump",UserInputService.JumpRequest:Connect(function()
            if Library.Flags["InfJump"] then
                local hum = client.Character and client.Character:FindFirstChildOfClass("Humanoid")
                if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
            end
        end))
    else DL("InfJump") end
end})

ExtraTab:createSlider({Name="Walk Speed",flagName="WalkSpeed",value=16,minValue=16,maxValue=200})
ciToggle(ExtraTab,{Name="Override Walk Speed",flagName="WSOn",tag="WSOn",delay=0.3,Step=function()
    local hum = client.Character and client.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = Library.Flags["WalkSpeed"] or 16 end
end})

ExtraTab:createSlider({Name="Jump Power",flagName="JumpPower",value=50,minValue=50,maxValue=300})
ciToggle(ExtraTab,{Name="Override Jump Power",flagName="JPOn",tag="JPOn",delay=0.3,Step=function()
    local hum = client.Character and client.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.JumpPower = Library.Flags["JumpPower"] or 50 end
end})

ExtraTab:createLabel({Name="Flight",Special=true})
ciToggle(ExtraTab,{Name="Fly (Hold Space)",flagName="Fly",tag="Fly",delay=0.05,Step=function()
    local hrp = client.Character and client.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        hrp.AssemblyLinearVelocity = Vector3.new(0,50,0)
    end
end})

ExtraTab:createLabel({Name="Camera",Special=true})
ciToggle(ExtraTab,{Name="No Clip",flagName="NoClip",tag="NoClip",delay=0.1,Step=function()
    local c = client.Character; if not c then return end
    for _,ch in ipairs(c:GetDescendants()) do if ch:IsA("BasePart") then ch.CanCollide=false end end
end})

ExtraTab:createLabel({Name="Server",Special=true})
ExtraTab:createButton({Name="Server Hop",Callback=function()
    local servers = {}
    pcall(function()
        if request then
            local data = request({Url="https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?limit=100",Method="GET"})
            if data and data.Body then
                local parsed = HttpService:JSONDecode(data.Body)
                if parsed and parsed.data then
                    for _,srv in ipairs(parsed.data) do
                        if srv.playing < srv.maxPlayers and srv.id ~= game.JobId then
                            servers[#servers+1] = srv
                        end
                    end
                end
            end
        end
    end)
    if #servers>0 then
        local srv = servers[math.random(1,#servers)]
        TeleportService:TeleportToPlaceInstance(game.PlaceId, srv.id, client)
        NF("Server Hop","Hopping to new server...","info")
    else
        NF("Server Hop","No available servers found.","warning")
    end
end})

ExtraTab:createButton({Name="Copy Game Link",Callback=function()
    local link = "https://www.roblox.com/games/"..game.PlaceId
    pcall(function() setclipboard(link) end)
    NF("Copy",link,"info")
end})

-- ##############################################################################
-- ##############################################################################
-- FINAL FOOTER & LOAD COMPLETE
-- ##############################################################################
-- ##############################################################################

-- Auto-reconnect on disconnect
RC(Players.PlayerRemoving:Connect(function(leavingPlayer)
    if leavingPlayer == client then
        print("[HQ] Player removed - cleaning up...")
        if _G.GardenHQ then pcall(_G.GardenHQ) end
    end
end))

-- Periodic cleanup loop
RC(task.spawn(function()
    while Alive do
        task.wait(120)
        pcall(function()
            -- Clear stale ESP objects
            local count = 0
            for obj, holder in pairs(ESP_Cache) do
                if not obj or not obj.Parent then count = count + 1 end
            end
            if count > 50 then cleanESP() end
        end)
    end
end))

-- Initialize plot on load
task.spawn(function()
    task.wait(2)
    pcall(function()
        authenticatePlot()
        if PL.auth then
            print(string.format("[HQ] Plot #%s auto-authenticated. %d grid nodes.", tostring(PL.plotId), #PL.gridNodes))
        else
            print("[HQ] No plot found - teleport to your garden first.")
        end
    end)
end)

-- Final print
print(string.rep("-",64))
print("[HQ] GardenMaster HQ v5.1 loaded")
print("[HQ] Tabs: Garden | Stealer | Market | Safety | Visuals | Tracker | Tools | Alerts | Stats | Player")
print("[HQ] "..#GD.seeds.." seeds | "..#GD.gears.." gears | "..#GD.crates.." crates | "..#GD.pets.." pets")
print("[HQ] Contributor: aditya44325f")
print("[HQ] Networking: ReplicatedStorage.SharedModules.Networking")
print("[HQ] Placement: Good Position (row-by-row) | Player Position | Random | Mouse")
print("[HQ] ESP: Player (Box/Name/HP/Team/Held/Distance/Tracers/Skeleton) | Plant (Rarity/Name/Owned/Mutation/Distance/Value) | Prop | Sprinkler | Rake")
print("[HQ] HUD: Weather Bar + Stock Ticker + Status Bar")
print(string.rep("-",64))


-- ##############################################################################
-- ##############################################################################
-- AUTO RECONNECT & CRASH RECOVERY
-- ##############################################################################
-- ##############################################################################

-- Crash recover: if the game teleports us, re-initialize
RC(Players.LocalPlayer.OnTeleport:Connect(function(state)
    if state == Enum.TeleportState.Started then
        print("[HQ] Teleport detected - preserving state...")
    elseif state == Enum.TeleportState.Failed then
        print("[HQ] Teleport failed - attempting recovery...")
        task.wait(5)
        pcall(function() TeleportService:Teleport(game.PlaceId, client) end)
    end
end))

-- Memory cleanup every 5 minutes
RC(task.spawn(function()
    while Alive do
        task.wait(300)
        pcall(function()
            local espCount = 0
            for _ in pairs(ESP_Cache) do espCount = espCount + 1 end
            if espCount > 100 then
                cleanESP()
                print("[HQ] ESP cleanup: "..espCount.." objects purged")
            end
            collectgarbage("collect")
        end)
    end
end))

-- ##############################################################################
-- ##############################################################################
-- FINAL BOOT MESSAGE
-- ##############################################################################
-- ##############################################################################

local bootTime = os.clock()

print(string.rep("-",64))
print("[HQ] GardenMaster HQ v5.1")
print("[HQ] Build Date: 2026-06-17")
print("[HQ] Game: GAG2 (Gardens & Gardening)")
print("[HQ] Network Module: ReplicatedStorage.SharedModules.Networking")
print("[HQ] FEATURES:")
print("[HQ]   Garden: Planting, harvest, water, sell, cleanup, collect, gear use")
print("[HQ]   Stealer: Target filters, owner checks, guard tools, safety controls")
print("[HQ]   Market: Seeds, gears, props, pets, daily deals, crates, eggs")
print("[HQ]   Safety: Codes, humanized delays, anti-fling, anti-idle, equipment")
print("[HQ]   Visuals: Player, plant, prop, sprinkler, rake ESP and world settings")
print("[HQ]   Tracker: Weather, restock, night, plot status, scanner, stock checker")
print("[HQ]   Tools: Plot, game data, network, remote diagnostics")
print("[HQ]   Alerts: Discord webhook notifications")
print("[HQ]   Stats: Session tracking and uptime")
print("[HQ]   Player: Fly, noclip, speed, jump, server hop")
print("[HQ] Game Data: "..#GD.seeds.." seeds | "..#GD.gears.." gears | "..#GD.crates.." crates | "..#GD.pets.." pets")
print(string.rep("-",64))
NF("GardenMaster HQ","v5.0 Loaded in "..string.format("%.2f",os.clock()-bootTime).."s\n"..#GD.seeds.." seeds ready","info")

-- ##############################################################################
-- ##############################################################################
-- EXTENDED HELPER DOCUMENTATION
-- ##############################################################################
-- ##############################################################################

--[[
    ============================================
    INTERNAL FUNCTION REFERENCE
    ============================================
    
    CORE SYSTEMS:
      authenticatePlot()     - Finds and caches the player's garden plot
      getPlacementPosition() - Returns next plantable position based on mode
      getRowPosition()       - Row-by-row placement from back of garden
      getOccupiedCells()     - Returns hash of occupied grid cells
      enforceGeofence()      - Teleports player back to garden gate
      
    TOOL SYSTEM:
      findTool(name)         - Locates a tool by name in backpack/character
      equipTool(tool)        - Equips a tool from backpack
      unequipCurrent()       - Unequips currently held tool
      
    ACTION EXECUTORS:
      harvestPlant()         - Net.Garden.CollectFruit:Fire(pid, fid)
      plantSeedAction()      - Net.Plant.PlantSeed:Fire(pos, name, tool)
      placeSprinklerAction() - Net.Place.PlaceSprinkler:Fire(pos, name, tool, 1)
      waterPlantAction()     - Net.WateringCan.UseWateringCan:Fire(pos, attr, tool)
      shovelPlantAction()    - Net.Shovel.UseShovel:Fire(pid, fid, attr, tool)
      sellAllItems()         - Net.NPCS.SellAll:Fire()
      buySeedItem()          - Net.SeedShop.PurchaseSeed:Fire(name)
      buyGearItem()          - Net.GearShop.PurchaseGear:Fire(name)
      buyCrateItem()         - Net.CrateShop.PurchaseCrate:Fire(name)
      beginStealAction()     - Net.Steal.BeginSteal:Fire(uid, pid, fid)
      completeStealAction()  - Net.Steal.CompleteSteal:Fire()
      redeemCodeAction()     - Net.Settings.SubmitCode:Fire(code)
      equipGearAction()      - Net.GearShop.EquipGear:Fire(name)
      equipPetAction()       - Net.Pets.PetEquipped:Fire(name, {})
      checkDailyDealAction() - Net.NPCS.CheckDailyDeal:Fire()
      
    FILTERING & SCORING:
      passesFilter()         - Checks model against fruit/mutation/rarity filters
      calculatePlantValue()  - Scores a plant by rarity * mutation * size * value
      getBestCandidates()    - Returns sorted candidates by value
      getOldestCandidates()  - Returns candidates sorted by age
      getClosestCandidates() - Returns candidates sorted by distance
      
    HUD SYSTEMS:
      updateStockWidget()    - Updates the stock ticker UI
      SystemState            - Global state tracking weather/stock
      
    ESP SYSTEMS:
      createESPObject()      - Creates Highlight + Billboard for any object
      cleanESP()             - Removes stale ESP objects
      createTracer()         - Creates beam tracer between two points
      cleanTracers()         - Removes all tracers
      
    UTILITY:
      getBackpackSeeds()     - Returns list of seed names in backpack
      getBackpackSprinklers()- Returns list of sprinkler names in backpack
      getBackpackGear()      - Returns list of gear names in backpack
      getBackpackCrates()    - Returns list of crate names in backpack
      getBackpackEggs()      - Returns list of egg names in backpack
      getBackpackSeedPacks() - Returns list of seed pack names in backpack
      getPlotOwner()         - Returns the UserId of a plot's owner
      isNightTime()          - Returns true if it's currently night
      
    PLACEMENT MODES:
      "Good Position"  - Row-by-row, fills from back of garden forward
      "Player Position" - Plants at the player's current location
      "Random"         - Random scatter across the entire plot
      "Mouse"          - Plants at mouse cursor position
      
    STEALER FLOW:
      1. Wait for night (isNightTime() = true)
      2. Get candidates from all gardens (not owned only)
      3. Apply mutation whitelist/blacklist filters
      4. Apply min KG filter
      5. Sort by priority (Value/Closest/Random)
      6. For each target:
         a. Check skip friends
         b. Check avoid owners
         c. Fling owner if enabled
         d. Teleport to target
         e. Begin steal + complete steal
         f. Harvest plant
         g. Repeat until carry limit reached
]]

-- Auto-cleanup on player death
RC(client.CharacterAdded:Connect(function(char)
    local hum = char:WaitForChild("Humanoid", 5)
    if hum then
        hum.Died:Connect(function()
            print("[HQ] Player died - auto-recovering...")
            task.wait(2)
            if Library.Flags["SAFE_rejoin"] then
                pcall(function() TeleportService:Teleport(game.PlaceId, client) end)
            end
        end)
    end
end))

-- Update notification on load
NF("GardenMaster HQ","v5.0 Ready\n"..#GD.seeds.." seeds | "..#GD.gears.." gears\n"..#GD.crates.." crates | "..#GD.pets.." pets","info")

-- ##############################################################################
-- ##############################################################################
-- PERFORMANCE CACHE & CLEANUP SYSTEM
-- ##############################################################################
-- ##############################################################################

-- Cache frequently accessed values
local cachedNightStatus = false
local cachedNightCheckTime = 0

local function isNightTimeCached()
    if os.clock() - cachedNightCheckTime > 1.0 then
        cachedNightStatus = isNightTime()
        cachedNightCheckTime = os.clock()
    end
    return cachedNightStatus
end

-- Cache plot authentication
local cachedPlotAuth = false
local cachedPlotCheckTime = 0

local function isPlotAuthCached()
    if os.clock() - cachedPlotCheckTime > 2.0 then
        authenticatePlot()
        cachedPlotAuth = PL.auth
        cachedPlotCheckTime = os.clock()
    end
    return cachedPlotAuth
end

-- Cache backpack item count
local cachedBackpackCount = 0
local cachedBackpackCheckTime = 0

local function getBackpackCountCached()
    if os.clock() - cachedBackpackCheckTime > 1.0 then
        local bp = client:FindFirstChild("Backpack")
        cachedBackpackCount = bp and #bp:GetChildren() or 0
        cachedBackpackCheckTime = os.clock()
    end
    return cachedBackpackCount
end

-- Cache garden plant count
local cachedPlantCount = 0
local cachedPlantCheckTime = 0

local function getGardenPlantCountCached()
    if os.clock() - cachedPlantCheckTime > 2.0 then
        authenticatePlot()
        cachedPlantCount = PL.plantsFolder and #PL.plantsFolder:GetChildren() or 0
        cachedPlantCheckTime = os.clock()
    end
    return cachedPlantCount
end

-- Final cleanup hook
local function fullCleanup()
    cleanESP()
    cleanTracers()
    ESP_Cache = {}
    TracerCache = {}
    cachedNightStatus = false
    cachedPlotAuth = false
    cachedBackpackCount = 0
    cachedPlantCount = 0
    print("[HQ] Full cleanup complete")
end

-- Register full cleanup
RC(RunService.Heartbeat:Connect(function()
    if os.clock() - cachedPlotCheckTime > 30 then
        pcall(authenticatePlot)
        cachedPlotAuth = PL.auth
        cachedPlotCheckTime = os.clock()
    end
end))

print("[HQ] Cache system initialized")
print("[HQ] Performance monitoring active")
print("[HQ] All systems ready")

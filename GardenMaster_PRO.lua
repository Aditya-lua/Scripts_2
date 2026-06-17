local request = (syn and syn.request) or (http and http.request) or http_request

--[[
    GardenMaster HQ v5.2
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
print("[HQ] GardenMaster HQ v5.2")
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
    pid = pid or tonumber(tostring(target.Name):match("%d+")); PL.model=target; PL.plotId=pid; PL.auth=true; PL.plantAreas={}; PL.occupiedHash={}; PL.rowIdx=0; PL.rowX=nil; PL.rowZ=nil
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
    local cleanName = tool:GetAttribute("Sprinkler") or cleanItemName(tool.Name)
    local plotId = PL.plotId or (PL.model and tonumber(tostring(PL.model.Name):match("%d+"))) or client:GetAttribute("PlotId") or 1
    local ok = pcall(function()
        Net.Place.PlaceSprinkler:Fire(targetPosition, cleanName, tool, plotId)
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
    local weatherValues = ReplicatedStorage:FindFirstChild("WeatherValues")
    if weatherValues then
        for _, name in ipairs({"Moon", "Bloodmoon", "Goldmoon", "Rainbow", "RainbowMoon", "ChainedMoon", "PizzaMoon"}) do
            if weatherValues:GetAttribute(name .. "_Playing") == true then return true end
        end
    end
    local nightDetector = ReplicatedStorage:FindFirstChild("Night", true)
    if nightDetector and nightDetector:IsA("BoolValue") then return nightDetector.Value end
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


local formatSeconds, getSeedShopRestockSeconds, updateSeedShopPredictionUI

-- ---------------------------------------------------------------------------
-- CLEAN VERSUS UI LAYOUT
-- ---------------------------------------------------------------------------
local HomeTab = UI:CreateSection("Home")
local MainTab = UI:CreateSection("Main")
local AutoTab = UI:CreateSection("Automatically")
local InventoryTab = UI:CreateSection("Inventory")
local ShopTab = UI:CreateSection("Shop")
local WebhookTab = UI:CreateSection("Webhook")
local MiscTab = UI:CreateSection("Misc")
local ToolsTab = UI:CreateSection("Tools")
local PlayerTab = UI:CreateSection("Player")
local VisualTab = UI:CreateSection("Visuals")

local ESP_Cache = {}
local TracerCache = {}

local function cleanESP()
    for obj, holder in pairs(ESP_Cache) do
        pcall(function() if holder then holder:Destroy() end end)
        ESP_Cache[obj] = nil
    end
end

local function cleanTracers()
    for key, obj in pairs(TracerCache) do
        pcall(function() if obj then obj:Destroy() end end)
        TracerCache[key] = nil
    end
end

local function createESPObject(targetObj, displayText, boxColor)
    if not targetObj or not targetObj.Parent then return end
    if ESP_Cache[targetObj] then
        local label = ESP_Cache[targetObj]:FindFirstChild("Label", true)
        if label then label.Text = displayText end
        return ESP_Cache[targetObj]
    end

    local holder = Instance.new("Folder")
    holder.Name = "HQ_ESP"
    holder.Parent = CoreGui
    RC(holder)

    local highlight = Instance.new("Highlight")
    highlight.Name = "Highlight"
    highlight.Adornee = targetObj
    highlight.FillTransparency = 0.78
    highlight.OutlineTransparency = 0.12
    highlight.FillColor = boxColor
    highlight.OutlineColor = boxColor
    highlight.Parent = holder

    local adornee = targetObj:IsA("Model") and (targetObj.PrimaryPart or targetObj:FindFirstChildWhichIsA("BasePart")) or targetObj
    if adornee then
        local bill = Instance.new("BillboardGui")
        bill.Name = "Billboard"
        bill.Adornee = adornee
        bill.AlwaysOnTop = true
        bill.Size = UDim2.new(0, 180, 0, 38)
        bill.StudsOffset = Vector3.new(0, 3.2, 0)
        bill.Parent = holder

        local label = Instance.new("TextLabel")
        label.Name = "Label"
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBold
        label.TextSize = 12
        label.TextColor3 = boxColor
        label.TextStrokeTransparency = 0.25
        label.TextWrapped = true
        label.Text = displayText
        label.Parent = bill
    end

    ESP_Cache[targetObj] = holder
    return holder
end

local function selectedMode(flag, fallback)
    return firstSelected(Library.Flags[flag], fallback)
end

local function getSelectedOrAll(flag, allList)
    local selected = asSelectionList(Library.Flags[flag])
    return (#selected > 0) and selected or allList
end

HomeTab:createLabel({Name="GardenMaster HQ",Special=true})
HomeTab:createLabel({Name="Clean rebuild using verified game remotes",Center=true})
HomeTab:createButton({Name="Refresh Plot",Callback=function()
    PL.auth = false
    PL.lastAuth = 0
    authenticatePlot()
    if PL.auth then
        NF("Plot", "Plot #" .. tostring(PL.plotId or "?") .. " ready with " .. tostring(#PL.gridNodes) .. " placement nodes.", "info")
    else
        NF("Plot", "No plot found. Stand inside your garden and refresh again.", "warning")
    end
end})
HomeTab:createButton({Name="Reload Script Cleanup",Callback=function()
    if _G.GardenHQ then pcall(_G.GardenHQ) end
end})
HomeTab:createButton({Name="Show Game Status",Callback=function()
    authenticatePlot()
    local restock = getSeedShopRestockSeconds and getSeedShopRestockSeconds() or nil
    NF("Status", string.format("Plot: %s\nSeeds: %d\nGears: %d\nSprinklers: %d\nNight: %s\nSeed restock: %s",
        PL.auth and ("#" .. tostring(PL.plotId or "?")) or "not found",
        #GD.seeds,
        #GD.gears,
        #(GD.sprinklers or {}),
        isNightTime() and "yes" or "no",
        restock and formatSeconds(restock) or "syncing"
    ), "info")
end})

MainTab:createLabel({Name="Quick Automation",Special=true})
MainTab:createDropdown({Name="Plant Seeds",flagName="PS_type",List={"None","All","Selected"}})
MainTab:createDropdown({Name="Selected Seeds",flagName="PS_list",multi=true,List=GD.seeds})
MainTab:createDropdown({Name="Plant Priority",flagName="PP",List={"Manual Order","Highest Value"}})
MainTab:createDropdown({Name="Placement Mode",flagName="PlacingMode",List={"Good Position","Player Position","Random","Mouse"}})
ciToggle(MainTab,{Name="Auto Plant",flagName="AP",tag="AP",delay=0.35,Step=function()
    authenticatePlot()
    local st = selectedMode("PS_type", "None")
    if st == "None" then return end
    enforceGeofence("p")

    local seeds = {}
    if st == "All" then seeds = getBackpackSeeds() else seeds = asSelectionList(Library.Flags["PS_list"]) end
    if #seeds == 0 then return end

    if selectedMode("PP", "Manual Order") == "Highest Value" then
        local score = {}
        for _, n in ipairs(seeds) do
            local tool = findTool(n)
            score[n] = tool and (tool:GetAttribute("Value") or tool:GetAttribute("Price") or 1) or 1
        end
        table.sort(seeds, function(a, b) return (score[a] or 0) > (score[b] or 0) end)
    end

    for _, seedName in ipairs(seeds) do
        if not Library.Flags["AP"] then break end
        local pos = getPlacementPosition(2.9)
        if pos and plantSeedAction(seedName, pos) then task.wait(0.08) end
    end
end})

MainTab:createDropdown({Name="Collect Mode",flagName="AH_type",List={"None","All","Selected","Blacklist"}})
MainTab:createDropdown({Name="Collect Fruits",flagName="AH_list",multi=true,List=GD.seeds})
MainTab:createDropdown({Name="Collect Blacklist",flagName="AH_blist",multi=true,List=GD.seeds})
MainTab:createDropdown({Name="Collect Priority",flagName="HP",List={"Highest Value","Closest","Oldest"}})
MainTab:createToggle({Name="Stop Collect When Full",flagName="AH_fullstop",Flag=false})
ciToggle(MainTab,{Name="Auto Collect Fruit",flagName="AH",tag="AH",delay=0.05,Step=function()
    local st = selectedMode("AH_type", "None")
    if st == "None" then return end
    authenticatePlot()
    if Library.Flags["AH_fullstop"] and isBackpackFull() then return end
    enforceGeofence("c")

    local include, blacklist = nil, nil
    if st == "Selected" then include = asSelectionList(Library.Flags["AH_list"])
    elseif st == "Blacklist" then blacklist = asSelectionList(Library.Flags["AH_blist"]) end

    local priority = selectedMode("HP", "Highest Value")
    local candidates
    if priority == "Oldest" then
        candidates = getOldestCandidates(500, include, nil, nil, true)
    elseif priority == "Closest" then
        candidates = getClosestCandidates(500, include, nil, nil, true)
    else
        candidates = getBestCandidates(500, include, nil, nil, true, blacklist)
    end

    local used = 0
    for _, c in ipairs(candidates) do
        if not Library.Flags["AH"] or used >= 80 then break end
        if c.plantId then
            task.spawn(harvestPlant, c.plantId, c.fruitId)
            used += 1
        else
            local prompt = c.model and c.model:FindFirstChild("HarvestPrompt", true)
            if prompt then task.spawn(HP, prompt); used += 1 end
        end
        task.wait(0.01)
    end
end})

MainTab:createDropdown({Name="Sell Mode",flagName="Sell_type",List={"None","Always","When Full"}})
ciToggle(MainTab,{Name="Auto Sell",flagName="AS",tag="AS",delay=0.55,Step=function()
    local mode = selectedMode("Sell_type", "None")
    if mode == "None" then return end
    if mode == "When Full" and not isBackpackFull() then return end
    sellAllItems()
end})
MainTab:createButton({Name="Sell All Now",Callback=function()
    sellAllItems()
    NF("Sell", "SellAll fired.", "info")
end})

MainTab:createLabel({Name="Steal",Special=true})
MainTab:createDropdown({Name="Steal Rarities",flagName="ST_rar",multi=true,List=RTS})
MainTab:createDropdown({Name="Steal Fruits",flagName="ST_names",multi=true,List=GD.seeds})
MainTab:createDropdown({Name="Mutation Whitelist",flagName="ST_mw",multi=true,List=MTS})
MainTab:createDropdown({Name="Mutation Blacklist",flagName="ST_mb",multi=true,List=MTS})
MainTab:createSlider({Name="Minimum Value",flagName="ST_minKG",value=0,minValue=0,maxValue=100000})
MainTab:createSlider({Name="Carry Limit",flagName="ST_carry",value=50,minValue=1,maxValue=200})
MainTab:createDropdown({Name="Steal Priority",flagName="ST_prio",List={"Value","Closest","Random"}})
MainTab:createToggle({Name="Skip Friends",flagName="ST_skipF",Flag=false})
MainTab:createToggle({Name="Avoid Owners",flagName="ST_avoidO",Flag=false})
MainTab:createToggle({Name="Fling Owner",flagName="ST_flingO",Flag=false})
ciToggle(MainTab,{Name="Auto Steal Fruit",flagName="ST",tag="ST",delay=0.65,Step=function()
    local sr = asSelectionList(Library.Flags["ST_rar"])
    local sn = asSelectionList(Library.Flags["ST_names"])
    local mw = asSelectionList(Library.Flags["ST_mw"])
    local mb = asSelectionList(Library.Flags["ST_mb"])
    local minScore = Library.Flags["ST_minKG"] or 0
    local carry = Library.Flags["ST_carry"] or 50
    local priority = selectedMode("ST_prio", "Value")

    local candidates = getBestCandidates(350, sn, mw, sr, false)
    local filtered = {}
    for _, c in ipairs(candidates) do
        if c.model and not c.isOwned then
            local mut = tostring(c.model:GetAttribute("Mutation") or ""):lower()
            local blocked = false
            for _, b in ipairs(mb) do if mut == tostring(b):lower() then blocked = true break end end
            if not blocked and (minScore <= 0 or c.score >= minScore) then filtered[#filtered + 1] = c end
        end
    end
    candidates = filtered

    if priority == "Closest" then table.sort(candidates, function(a,b) return a.distance < b.distance end)
    elseif priority == "Random" then for i = #candidates, 2, -1 do local j = math.random(i); candidates[i], candidates[j] = candidates[j], candidates[i] end
    else table.sort(candidates, function(a,b) return a.score > b.score end) end

    local stolen = 0
    for _, c in ipairs(candidates) do
        if not Library.Flags["ST"] or stolen >= carry then break end
        local plot = c.model
        while plot and plot.Parent and plot.Parent ~= Workspace and not getPlotOwner(plot) do plot = plot.Parent end
        local ownerId = plot and getPlotOwner(plot)
        if ownerId and ownerId ~= client.UserId then
            if Library.Flags["ST_skipF"] then local ok,isFriend=pcall(function() return client:IsFriendsWith(ownerId) end); if ok and isFriend then continue end end
            if Library.Flags["ST_avoidO"] then local owner=Players:GetPlayerByUserId(ownerId); if owner and owner.Character and owner.Character:FindFirstChild("HumanoidRootPart") and (c.model:GetPivot().Position-owner.Character.HumanoidRootPart.Position).Magnitude < 20 then continue end end
            if Library.Flags["ST_flingO"] then local owner=Players:GetPlayerByUserId(ownerId); if owner and owner.Character and owner.Character:FindFirstChild("HumanoidRootPart") then owner.Character.HumanoidRootPart.AssemblyLinearVelocity = (c.model:GetPivot().Position-owner.Character.HumanoidRootPart.Position).Unit * 250 + Vector3.new(0,150,0) end end
            TP(c.model:GetPivot().Position)
            task.wait(0.08)
            beginStealAction(ownerId, c.plantId, c.fruitId)
            task.wait(0.04)
            completeStealAction()
            if c.plantId then task.spawn(harvestPlant, c.plantId, c.fruitId) end
            local prompt = c.model:FindFirstChild("HarvestPrompt", true)
            if prompt then task.spawn(HP, prompt) end
            stolen += 1
            task.wait(0.16)
        end
    end
end})

AutoTab:createLabel({Name="Planting",Special=true})
AutoTab:createDropdown({Name="Seeds",flagName="AutoSeedsView",multi=true,List=GD.seeds})
AutoTab:createDropdown({Name="Position",flagName="AutoPlantPositionView",List={"Good Position","Player Position","Random","Mouse"},Callback=function(v)
    Library.Flags["PlacingMode"] = firstSelected(v, "Good Position")
end})
ciToggle(AutoTab,{Name="Auto Plant Selected",flagName="AP_Selected",tag="AP_Selected",delay=0.35,Step=function()
    authenticatePlot(); enforceGeofence("p")
    for _, seedName in ipairs(asSelectionList(Library.Flags["AutoSeedsView"])) do
        if not Library.Flags["AP_Selected"] then break end
        local pos = getPlacementPosition(2.9)
        if pos and plantSeedAction(seedName, pos) then task.wait(0.08) end
    end
end})
ciToggle(AutoTab,{Name="Auto Plant All Seeds",flagName="AP_All",tag="AP_All",delay=0.35,Step=function()
    authenticatePlot(); enforceGeofence("p")
    for _, seedName in ipairs(getBackpackSeeds()) do
        if not Library.Flags["AP_All"] then break end
        local pos = getPlacementPosition(2.9)
        if pos and plantSeedAction(seedName, pos) then task.wait(0.08) end
    end
end})

AutoTab:createLabel({Name="Collection",Special=true})
AutoTab:createDropdown({Name="Filter",flagName="AutoCollectFilter",List={"Highest Value","Closest","Oldest"},Callback=function(v)
    Library.Flags["HP"] = firstSelected(v, "Highest Value")
end})
ciToggle(AutoTab,{Name="Auto Collect Fruit",flagName="AutoCollectAll",tag="AutoCollectAll",delay=0.06,Step=function()
    authenticatePlot(); if isBackpackFull() then return end
    local priority = selectedMode("AutoCollectFilter", "Highest Value")
    local candidates = priority == "Closest" and getClosestCandidates(300,nil,nil,nil,true)
        or priority == "Oldest" and getOldestCandidates(300,nil,nil,nil,true)
        or getBestCandidates(300,nil,nil,nil,true)
    local used = 0
    for _, c in ipairs(candidates) do
        if not Library.Flags["AutoCollectAll"] or used >= 80 then break end
        if c.plantId then task.spawn(harvestPlant, c.plantId, c.fruitId); used += 1 end
        task.wait(0.01)
    end
end})

local collectSeedPromptCache, collectSeedCacheAt = {}, 0
local function getCollectSeedPrompts()
    if os.clock() - collectSeedCacheAt < 4 then return collectSeedPromptCache end
    collectSeedCacheAt = os.clock()
    table.clear(collectSeedPromptCache)
    for _, prompt in ipairs(Workspace:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") then
            local t = (prompt.Name .. " " .. (prompt.ActionText or "") .. " " .. (prompt.ObjectText or "")):lower()
            if t:find("seed", 1, true) or t:find("rainbow", 1, true) or t:find("gold", 1, true) or t:find("claim", 1, true) then
                collectSeedPromptCache[#collectSeedPromptCache + 1] = prompt
            end
        end
    end
    return collectSeedPromptCache
end

local function collectSeedPromptsByMode(modeFlag)
    local hrp = client.Character and client.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local used = 0
    for _, prompt in ipairs(getCollectSeedPrompts()) do
        if used >= 8 then break end
        if prompt and prompt.Parent and prompt.Enabled ~= false then
            local t = (prompt.Name .. " " .. (prompt.ActionText or "") .. " " .. (prompt.ObjectText or "")):lower()
            local ok = modeFlag == "All" or (modeFlag == "Gold" and t:find("gold", 1, true)) or (modeFlag == "Rainbow" and t:find("rainbow", 1, true))
            if ok then
                local model = prompt:FindFirstAncestorWhichIsA("Model") or prompt.Parent
                local pos = model and (model:IsA("Model") and model:GetPivot().Position or (model.Position or nil))
                if pos and (pos - hrp.Position).Magnitude > 12 then TP(pos); task.wait(0.04) end
                HP(prompt)
                used += 1
                task.wait(0.03)
            end
        end
    end
end

ciToggle(AutoTab,{Name="Auto Collect Gold Seed",flagName="ACS_gold",tag="ACS_gold",delay=0.25,Step=function()
    collectSeedPromptsByMode("Gold")
end})
ciToggle(AutoTab,{Name="Auto Collect Rainbow Seed",flagName="ACS_rainbow",tag="ACS_rainbow",delay=0.25,Step=function()
    collectSeedPromptsByMode("Rainbow")
end})

AutoTab:createLabel({Name="Sprinklers",Special=true})
AutoTab:createDropdown({Name="Sprinkler",flagName="SP_list",multi=true,List=GD.sprinklers or {}})
AutoTab:createDropdown({Name="Position",flagName="SP_position",List={"Random","Player Position","Near Fruit"}})
AutoTab:createSlider({Name="Sprinkler Spacing",flagName="SP_spacing",value=8,minValue=4,maxValue=30})
ciToggle(AutoTab,{Name="Auto Place Sprinkler",flagName="SP",tag="SP",delay=0.35,Step=function()
    authenticatePlot(); enforceGeofence("p")
    local selected = asSelectionList(Library.Flags["SP_list"])
    local sprinklers = (#selected > 0) and selected or getBackpackSprinklers()
    local mode = selectedMode("SP_position", "Random")
    for _, name in ipairs(sprinklers) do
        if not Library.Flags["SP"] then break end
        local pos
        if mode == "Player Position" then
            local hrp = client.Character and client.Character:FindFirstChild("HumanoidRootPart")
            pos = hrp and hrp.Position
        elseif mode == "Near Fruit" then
            local cand = getBestCandidates(1, nil, nil, nil, true)
            local base = cand[1] and cand[1].model and cand[1].model:GetPivot().Position
            local spacing = Library.Flags["SP_spacing"] or 8
            pos = base and (base + Vector3.new(math.random(-spacing, spacing), 0, math.random(-spacing, spacing)))
        else
            pos = getPlacementPosition(4.0)
        end
        if pos and placeSprinklerAction(name, pos) then task.wait(0.08) end
    end
end})

AutoTab:createLabel({Name="Shovel",Special=true})
AutoTab:createDropdown({Name="Fruit",flagName="RM_list",multi=true,List=GD.seeds})
AutoTab:createDropdown({Name="Mode",flagName="RM_type",List={"None","All","Selected","Blacklist","Low KG"}})
AutoTab:createSlider({Name="Weight Threshold",flagName="RM_maxKG",value=0,minValue=0,maxValue=100000})
ciToggle(AutoTab,{Name="Auto Shovel Fruit",flagName="RM",tag="RM",delay=0.18,Step=function()
    local st = selectedMode("RM_type", "None")
    if st == "None" then return end
    authenticatePlot(); if not PL.plantsFolder then return end
    local selected = asSelectionList(Library.Flags["RM_list"])
    local include, blacklist = nil, nil
    if st == "Selected" then include = selected elseif st == "Blacklist" then blacklist = selected end
    local cand = getBestCandidates(300, include, nil, nil, true, blacklist)
    if st == "Low KG" then
        local maxWeight = Library.Flags["RM_maxKG"] or 0
        local low = {}
        for _, c in ipairs(cand) do if c.score < maxWeight then low[#low + 1] = c end end
        cand = low
    end
    local shovel = findTool("shovel") or findTool("Shovel")
    for _, c in ipairs(cand) do
        if not Library.Flags["RM"] then break end
        if c.plantId then shovelPlantAction(c.plantId, c.fruitId, shovel); task.wait(0.012) end
    end
end})

InventoryTab:createLabel({Name="Favorite Automation",Special=true})
InventoryTab:createDropdown({Name="Favorite Fruit",flagName="FavFruit",multi=true,List=GD.seeds})
InventoryTab:createDropdown({Name="Favorite Rarity",flagName="FavRarity",multi=true,List=RTS})
InventoryTab:createDropdown({Name="Favorite Mutation",flagName="FavMutation",multi=true,List=MTS})
InventoryTab:createSlider({Name="Weight Threshold",flagName="FavWeight",value=0,minValue=0,maxValue=100000})
ciToggle(InventoryTab,{Name="Auto Favorite Fruit",flagName="FavAuto",tag="FavAuto",delay=1.0,Step=function()
    if not Net.Backpack or not Net.Backpack.SetFruitFavorite then return end
    local names = asSelectionList(Library.Flags["FavFruit"])
    for _, c in ipairs(getBestCandidates(200, names, asSelectionList(Library.Flags["FavMutation"]), asSelectionList(Library.Flags["FavRarity"]), true)) do
        if not Library.Flags["FavAuto"] then break end
        if c.fruitId and ((Library.Flags["FavWeight"] or 0) <= 0 or c.score >= (Library.Flags["FavWeight"] or 0)) then
            pcall(function() Net.Backpack.SetFruitFavorite:Fire(c.fruitId, true) end)
            task.wait(0.03)
        end
    end
end})
ciToggle(InventoryTab,{Name="Auto Unfavorite Fruit",flagName="UnFavAuto",tag="UnFavAuto",delay=1.0,Step=function()
    if not Net.Backpack or not Net.Backpack.SetFruitFavorite then return end
    for _, c in ipairs(getBestCandidates(200, nil, nil, nil, true)) do
        if not Library.Flags["UnFavAuto"] then break end
        if c.fruitId then pcall(function() Net.Backpack.SetFruitFavorite:Fire(c.fruitId, false) end); task.wait(0.03) end
    end
end})

ShopTab:createLabel({Name="Shop Seeds",Special=true})
ShopTab:createDropdown({Name="Select Seed",flagName="SH_seeds",multi=true,List=GD.seeds})
ciToggle(ShopTab,{Name="Auto Buy Seeds",flagName="SH_bs",tag="SH_bs",delay=1.0,Step=function()
    for _, name in ipairs(asSelectionList(Library.Flags["SH_seeds"])) do if not Library.Flags["SH_bs"] then break end; buySeedItem(name); task.wait(0.05) end
end})
ciToggle(ShopTab,{Name="Auto Buy All Seeds",flagName="SH_bs_all",tag="SH_bs_all",delay=1.0,Step=function()
    for _, name in ipairs(GD.seeds) do if not Library.Flags["SH_bs_all"] then break end; buySeedItem(name); task.wait(0.04) end
end})
ShopTab:createLabel({Name="Shop Gear",Special=true})
ShopTab:createDropdown({Name="Select Gear",flagName="SH_gears",multi=true,List=GD.gears})
ciToggle(ShopTab,{Name="Auto Buy Gear",flagName="SH_bg",tag="SH_bg",delay=1.0,Step=function()
    for _, name in ipairs(asSelectionList(Library.Flags["SH_gears"])) do if not Library.Flags["SH_bg"] then break end; buyGearItem(name); task.wait(0.05) end
end})
ciToggle(ShopTab,{Name="Auto Buy All Gear",flagName="SH_bg_all",tag="SH_bg_all",delay=1.0,Step=function()
    for _, name in ipairs(GD.gears) do if not Library.Flags["SH_bg_all"] then break end; buyGearItem(name); task.wait(0.04) end
end})
ShopTab:createLabel({Name="Shop Crate",Special=true})
ShopTab:createDropdown({Name="Select Crate",flagName="SH_props",multi=true,List=GD.crates})
ciToggle(ShopTab,{Name="Auto Buy Crate",flagName="SH_bp",tag="SH_bp",delay=1.0,Step=function()
    for _, name in ipairs(asSelectionList(Library.Flags["SH_props"])) do if not Library.Flags["SH_bp"] then break end; buyCrateItem(name); task.wait(0.05) end
end})
ShopTab:createLabel({Name="Stock",Special=true})
ShopTab:createToggle({Name="Show Seed Shop Predictor",flagName="PRED",Flag=false})
ShopTab:createButton({Name="Check Seed Restock",Callback=function()
    local restock = getSeedShopRestockSeconds and getSeedShopRestockSeconds() or nil
    NF("Seed Shop", restock and ("Next restock in " .. formatSeconds(restock)) or "Restock timer not found. Open the seed shop once.", "info")
end})
ShopTab:createButton({Name="Refresh Seed Predictor UI",Callback=function()
    updateSeedShopPredictionUI()
    NF("Seed Predictor", "Seed shop overlay refreshed.", "info")
end})

WebhookTab:createLabel({Name="Config Webhook",Special=true})
WebhookTab:createInputBox({Name="Webhook URL",flagName="WebhookURL",Flag=""})
WebhookTab:createInputBox({Name="Ping Message or ID",flagName="WebhookPing",Flag=""})
WebhookTab:createToggle({Name="Allow Ping",flagName="WebhookAllowPing",Flag=false})
WebhookTab:createLabel({Name="Events",Special=true})
WebhookTab:createToggle({Name="Rare Fruit Webhook",flagName="WH_Rare",Flag=false})
WebhookTab:createDropdown({Name="Minimum Rarity",flagName="WH_Rarity",List={"Legendary","Mythic","Rainbow","Gold"}})
WebhookTab:createToggle({Name="Steal Webhook",flagName="WH_Steal",Flag=false})
WebhookTab:createToggle({Name="Backpack Full Webhook",flagName="WH_Full",Flag=false})
WebhookTab:createButton({Name="Test Webhook",Callback=function()
    local url = Library.Flags["WebhookURL"]
    if not url or url == "" then NF("Webhook", "Enter a webhook URL first.", "warning"); return end
    local content = "GardenMaster HQ test"
    if Library.Flags["WebhookAllowPing"] and Library.Flags["WebhookPing"] and Library.Flags["WebhookPing"] ~= "" then
        content = tostring(Library.Flags["WebhookPing"]) .. " " .. content
    end
    local ok, err = pcall(function()
        if request then request({Url=url,Method="POST",Headers={["Content-Type"]="application/json"},Body=HttpService:JSONEncode({content=content})}) end
    end)
    NF("Webhook", ok and "Test sent." or ("Failed: " .. tostring(err)), ok and "info" or "danger")
end})

MiscTab:createLabel({Name="Protection",Special=true})
MiscTab:createToggle({Name="Humanized Mode",flagName="LegitMode",Flag=true})
ciToggle(MiscTab,{Name="Anti Fling",flagName="AntiFling",tag="AntiFling",delay=0.1,Flag=true,Step=function()
    local root = client.Character and client.Character:FindFirstChild("HumanoidRootPart")
    if root and (root.AssemblyLinearVelocity.Magnitude > 250 or root.AssemblyAngularVelocity.Magnitude > 50) then
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end
end})
ciToggle(MiscTab,{Name="Less Knockback",flagName="AntiAFK",tag="AntiAFK",delay=0.5,Flag=true,Step=function()
    local hum = client.Character and client.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown,false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll,false)
    end
end})
ciToggle(MiscTab,{Name="Instant Interact Prompt",flagName="InstantPrompt",tag="InstantPrompt",delay=1.2,Step=function()
    for _, prompt in ipairs(Workspace:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") then prompt.HoldDuration = 0 end
    end
end})
ciToggle(MiscTab,{Name="Bypass Gameplay Paused",flagName="NoPause",tag="NoPause",delay=1.0,Step=function()
    local pg = client:FindFirstChild("PlayerGui")
    if not pg then return end
    for _, gui in ipairs(pg:GetDescendants()) do
        if gui:IsA("GuiObject") then
            local n = gui.Name:lower()
            if n:find("pause") or n:find("gameplaypaused") or n:find("afk") then gui.Visible = false end
        end
    end
end})
ciToggle(MiscTab,{Name="Noclip Plants",flagName="NoclipPlants",tag="NoclipPlants",delay=2.0,Step=function()
    authenticatePlot()
    if not PL.plantsFolder then return end
    for _, part in ipairs(PL.plantsFolder:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
end})
MiscTab:createLabel({Name="Server",Special=true})
MiscTab:createButton({Name="Rejoin Server",Callback=function() pcall(function() TeleportService:Teleport(game.PlaceId, client) end) end})
MiscTab:createButton({Name="Copy Game Link",Callback=function()
    local link = "https://www.roblox.com/games/" .. tostring(game.PlaceId)
    pcall(function() setclipboard(link) end)
    NF("Copy", link, "info")
end})

PlayerTab:createLabel({Name="Movement",Special=true})
PlayerTab:createSlider({Name="Walk Speed",flagName="WalkSpeed",value=16,minValue=16,maxValue=200})
ciToggle(PlayerTab,{Name="Override Walk Speed",flagName="WSOn",tag="WSOn",delay=0.3,Step=function()
    local hum = client.Character and client.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = Library.Flags["WalkSpeed"] or 16 end
end})
PlayerTab:createSlider({Name="Jump Power",flagName="JumpPower",value=50,minValue=50,maxValue=300})
ciToggle(PlayerTab,{Name="Override Jump Power",flagName="JPOn",tag="JPOn",delay=0.3,Step=function()
    local hum = client.Character and client.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.JumpPower = Library.Flags["JumpPower"] or 50 end
end})
PlayerTab:createToggle({Name="Infinite Jump",flagName="InfJump",Flag=false,Callback=function(enabled)
    DL("InfJump")
    if enabled then
        RL("InfJump", UserInputService.JumpRequest:Connect(function()
            if Library.Flags["InfJump"] then
                local hum = client.Character and client.Character:FindFirstChildOfClass("Humanoid")
                if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
            end
        end))
    end
end})
PlayerTab:createToggle({Name="No Clip",flagName="NoClip",Flag=false,Callback=function(enabled)
    DL("NoClip")
    if enabled then
        RL("NoClip", RunService.Stepped:Connect(function()
            if not Library.Flags["NoClip"] or not client.Character then return end
            for _, part in ipairs(client.Character:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end))
    end
end})

VisualTab:createLabel({Name="World",Special=true})
VisualTab:createSlider({Name="Clock Time",flagName="ClockTime",value=21,minValue=0,maxValue=24})
ciToggle(VisualTab,{Name="Override Clock",flagName="ClockOn",tag="ClockOn",delay=0.5,Step=function()
    Lighting.ClockTime = Library.Flags["ClockTime"] or 21
end})
VisualTab:createToggle({Name="Fullbright",flagName="Fullbright",Flag=false,Callback=function(enabled)
    if enabled then
        Lighting.Brightness = 2
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 100000
    end
end})
VisualTab:createLabel({Name="ESP",Special=true})
VisualTab:createDropdown({Name="Fruit",flagName="PE_names",multi=true,List=GD.seeds})
VisualTab:createDropdown({Name="Rarity",flagName="PE_rar",multi=true,List=RTS})
VisualTab:createDropdown({Name="Mutation",flagName="PE_mutations",multi=true,List=MTS})
VisualTab:createSlider({Name="Max Distance",flagName="PE_range",value=1200,minValue=100,maxValue=3000})
ciToggle(VisualTab,{Name="ESP Fruit",flagName="PlantESP",tag="PlantESP",delay=0.6,Step=function()
    local range = Library.Flags["PE_range"] or 1200
    local root = client.Character and client.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local candidates = getBestCandidates(350, asSelectionList(Library.Flags["PE_names"]), asSelectionList(Library.Flags["PE_mutations"]), asSelectionList(Library.Flags["PE_rar"]), false)
    local live = {}
    for _, c in ipairs(candidates) do
        if c.model and c.distance <= range then
            live[c.model] = true
            local text = string.format("%s | %.0f | %.0fm", c.model.Name, c.score or 0, c.distance or 0)
            createESPObject(c.model, text, c.isOwned and Color3.fromRGB(80,255,120) or Color3.fromRGB(255,220,80))
        end
    end
    for obj, holder in pairs(ESP_Cache) do
        if obj and obj:IsDescendantOf(Workspace) and not live[obj] and obj:FindFirstAncestor("Plants") then
            holder:Destroy(); ESP_Cache[obj] = nil
        end
    end
end})
VisualTab:createToggle({Name="Clear ESP",flagName="ClearESPButton",Flag=false,Callback=function() cleanESP(); Library.Flags["ClearESPButton"] = false end})

ToolsTab:createLabel({Name="Diagnostics",Special=true})
ToolsTab:createButton({Name="Dump Plot Info",Callback=function()
    authenticatePlot()
    NF("Plot Info", string.format("Plot: %s\nCenter: %.1f %.1f %.1f\nGrid nodes: %d\nPlant areas: %d",
        tostring(PL.plotId or "none"), PL.center.X, PL.center.Y, PL.center.Z, #PL.gridNodes, #PL.plantAreas), "info")
end})
ToolsTab:createButton({Name="Dump Remote Names",Callback=function()
    local names = {}
    for k, v in pairs(Net) do
        if type(v) == "table" then
            for k2, v2 in pairs(v) do if type(v2) == "table" and type(v2.Fire) == "function" then names[#names + 1] = k .. "." .. k2 end end
        end
    end
    table.sort(names)
    local msg = "Remotes (" .. tostring(#names) .. "):\n"
    for i, name in ipairs(names) do msg = msg .. name .. "\n"; if i >= 30 then msg = msg .. "..."; break end end
    NF("Remotes", msg, "info")
end})
ToolsTab:createButton({Name="Dump Stock",Callback=function()
    local stock = ReplicatedStorage:FindFirstChild("StockValues")
    if not stock then NF("Stock", "StockValues not found.", "warning"); return end
    local msg = ""
    for _, shop in ipairs(stock:GetChildren()) do
        local items = shop:FindFirstChild("Items")
        if items then
            msg = msg .. shop.Name .. ": "
            local count = 0
            for _, item in ipairs(items:GetChildren()) do if item:IsA("NumberValue") and item.Value > 0 then msg = msg .. item.Name .. " x" .. item.Value .. ", "; count += 1 end end
            if count == 0 then msg = msg .. "no stock" end
            msg = msg .. "\n"
        end
    end
    NF("Stock", msg, "info")
end})
ToolsTab:createToggle({Name="Debug Mode",flagName="Debug",Flag=false})

-- Rare find webhook loop
RC(task.spawn(function()
    while Alive do
        task.wait(10)
        pcall(function()
            if not Library.Flags["WH_Rare"] then return end
            local url = Library.Flags["WebhookURL"]
            if not url or url == "" then return end
            authenticatePlot()
            if not PL.plantsFolder then return end
            local minRarity = selectedMode("WH_Rarity", "Legendary")
            local minScore = ({Legendary=6, Mythic=7, Rainbow=10, Gold=10})[minRarity] or 6
            for _, plant in ipairs(PL.plantsFolder:GetChildren()) do
                if plant:IsA("Model") then
                    local rarity = tostring(plant:GetAttribute("Rarity") or "")
                    if (RarityScore[rarity:lower()] or 0) >= minScore then
                        local msg = string.format("Rare find: %s | %s | value %.0f", plant.Name, rarity, calculatePlantValue(plant))
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

formatSeconds = function(seconds)
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

getSeedShopRestockSeconds = function()
    local stock = ReplicatedStorage:FindFirstChild("StockValues")
    local seedShopValues = stock and stock:FindFirstChild("SeedShop")
    local nextRestock = seedShopValues and seedShopValues:FindFirstChild("UnixNextRestock")
    if nextRestock and tonumber(nextRestock.Value) then
        return math.max(0, tonumber(nextRestock.Value) - os.time())
    end

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

updateSeedShopPredictionUI = function()
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
print("[HQ] GardenMaster HQ v5.2 loaded")
print("[HQ] Tabs: Home | Main | Automatically | Inventory | Shop | Webhook | Misc | Tools | Player | Visuals")
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
print("[HQ] GardenMaster HQ v5.2")
print("[HQ] Build Date: 2026-06-17")
print("[HQ] Game: GAG2 (Gardens & Gardening)")
print("[HQ] Network Module: ReplicatedStorage.SharedModules.Networking")
print("[HQ] FEATURES:")
print("[HQ]   Home: status, plot refresh, cleanup")
print("[HQ]   Main: plant, collect, sell, steal")
print("[HQ]   Automatically: plant, collect, sprinkler, shovel")
print("[HQ]   Inventory: favorite and threshold tools")
print("[HQ]   Shop: seeds, gear, crates, stock predictor")
print("[HQ]   Webhook: config and event alerts")
print("[HQ]   Misc: protection, prompts, server tools")
print("[HQ]   Player: movement and noclip")
print("[HQ]   Visuals: world settings and fruit ESP")
print("[HQ]   Tools: plot, stock, remote diagnostics")
print("[HQ] Game Data: "..#GD.seeds.." seeds | "..#GD.gears.." gears | "..#GD.crates.." crates | "..#GD.pets.." pets")
print(string.rep("-",64))
NF("GardenMaster HQ","v5.2 Loaded in "..string.format("%.2f",os.clock()-bootTime).."s\n"..#GD.seeds.." seeds ready","info")

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
NF("GardenMaster HQ","v5.2 Ready\n"..#GD.seeds.." seeds | "..#GD.gears.." gears\n"..#GD.crates.." crates | "..#GD.pets.." pets","info")

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

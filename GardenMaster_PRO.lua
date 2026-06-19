local request = (syn and syn.request) or (http and http.request) or http_request

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
local Camera = Workspace.CurrentCamera
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

local Char = client.Character or client.CharacterAdded:Wait()
local Hum = Char:WaitForChild("Humanoid")
local HRP = Char:WaitForChild("HumanoidRootPart")
local Backpack = client:WaitForChild("Backpack")

local Net = nil
pcall(function()
    Net = require(ReplicatedStorage:WaitForChild("SharedModules", 15):WaitForChild("Networking", 15))
end)
if not Net then warn("[GAG2] Networking module not reachable") end

local function fire(path, ...)
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

local PlotData = { auth = false, model = nil, id = nil, center = Vector3.zero, grid = {} }
local ESP_Cache = {}

local Seeds = {}
local Gear = {}
local Crates = {}
local Pets = {}
local PetRarities = {}
local Mutations = {}

local function autoDetectLists()
    pcall(function()
        local seedData = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("SeedData"))
        for _, entry in ipairs(seedData) do
            if type(entry) == "table" and entry.SeedName and entry.RestockShop then
                table.insert(Seeds, entry.SeedName)
            end
        end
    end)
    if #Seeds == 0 then
        Seeds = {
            "Carrot","Strawberry","Blueberry","Tulip","Tomato","Apple","Bamboo",
            "Corn","Cactus","Pineapple","Mushroom","Green Bean","Banana","Grape",
            "Coconut","Mango","Dragon Fruit","Acorn","Cherry","Sunflower",
            "Venus Fly Trap","Pomegranate","Poison Apple","Moon Bloom",
            "Dragon's Breath","Ghost Pepper","Poison Ivy","Baby Cactus",
            "Glow Mushroom","Romanesco","Horned Melon","Gold","Rainbow"
        }
    end

    pcall(function()
        local gearData = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("GearShopData"))
        for _, entry in ipairs(gearData) do
            if type(entry) == "table" and entry.ItemName then
                table.insert(Gear, entry.ItemName)
            end
        end
    end)
    if #Gear == 0 then
        Gear = {
            "Common Watering Can","Common Sprinkler","Sign","Lantern",
            "Uncommon Sprinkler","Rare Sprinkler","Legendary Sprinkler",
            "Super Sprinkler","Trowel","Speed Mushroom","Jump Mushroom",
            "Gnome","Shrink Mushroom","Supersize Mushroom","Invisibility Mushroom",
            "Wheelbarrow","Teleporter","Super Watering Can","Basic Pot","Flashbang"
        }
    end

    pcall(function()
        local eggData = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("EggData"))
        for _, entry in ipairs(eggData.Data) do
            if type(entry) == "table" and entry.EggName and entry.EggName ~= "Test Egg" then
                table.insert(Crates, entry.EggName)
            end
        end
    end)
    pcall(function()
        local crateData = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("CrateData"))
        for _, entry in ipairs(crateData:GetAllCrates()) do
            if type(entry) == "table" and entry.Name then
                table.insert(Crates, entry.Name)
            end
        end
    end)
    pcall(function()
        local guildCrate = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("GuildCrateData"))
        for _, entry in ipairs(guildCrate:GetAllCrates()) do
            if type(entry) == "table" and entry.Name then
                table.insert(Crates, entry.Name)
            end
        end
    end)
    if #Crates == 0 then
        Crates = {
            "Common Egg","Epic Egg","Common Guild Crate","Uncommon Guild Crate",
            "Rare Guild Crate","Legendary Guild Crate","Epic Guild Crate","Mythic Guild Crate",
            "Arch Crate","Bear Trap Crate","Bench Crate","Bridge Crate","Conveyor Crate",
            "Fence Crate","Ladder Crate","Owner Door Crate","Roleplay Crate",
            "Seesaw Crate","Sign Crate","Spring Crate","Teleporter Pad Crate",
            "Common Bear Trap","Gold Bear Trap","Rainbow Bear Trap"
        }
    end
    local seen = {}
    local dedup = {}
    for _, c in ipairs(Crates) do
        if not seen[c] then seen[c] = true; table.insert(dedup, c) end
    end
    Crates = dedup

    pcall(function()
        local petData = require(ReplicatedStorage:WaitForChild("SharedData"):WaitForChild("PetData"))
        local rar = {}
        for name, entry in pairs(petData) do
            if type(entry) == "table" and entry.DisplayName then
                table.insert(Pets, entry.DisplayName)
                if entry.Rarity then table.insert(rar, entry.Rarity) end
            end
        end
        table.sort(Pets)
        local seenR = {}
        for _, r in ipairs(rar) do
            if not seenR[r] then seenR[r] = true; table.insert(PetRarities, r) end
        end
        table.sort(PetRarities)
    end)
    if #Pets == 0 then
        Pets = {
            "Raccoon","Monkey","Robin","Frog","Bunny","Deer","Owl","Bee",
            "Unicorn","Black Dragon","Ice Serpent","Golden Dragonfly"
        }
        PetRarities = {"Common","Uncommon","Rare","Legendary","Mythic","Super"}
    end

    pcall(function()
        local mutData = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("MutationData"))
        for name, entry in pairs(mutData) do
            if type(entry) == "table" and entry.PriceMultiplier then
                table.insert(Mutations, name)
            end
        end
        table.sort(Mutations)
    end)
    if #Mutations == 0 then
        Mutations = {"Gold","Rainbow","Electric","Frozen","Bloodlit","Chained","Starstruck"}
    end
end

autoDetectLists()

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

local function getHRP()
    local c = client.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getHum()
    local c = client.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

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

    local areas, fb, fba = {}, nil, 0
    for _,d in ipairs(m:GetDescendants()) do
        if d:IsA("BasePart") then
            local n = d.Name:lower()
            local tagged = CollectionService:HasTag(d,"PlantArea") or CollectionService:HasTag(d,"Soil")
            if tagged or n:find("plantarea") or n:find("soil") or n:find("dirt") or n:find("farm") then
                table.insert(areas, d)
            elseif d == m.PrimaryPart or n:find("base") or n:find("floor") then
                local a = d.Size.X * d.Size.Z
                if a > fba then fba = a; fb = d end
            end
        end
    end
    if #areas == 0 and fb then table.insert(areas, fb) end

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

local function moveTo(target)
    local hrp = getHRP()
    if not hrp or not target then return end
    local mode = Library.Flags["TransportMode"] or "Tween"
    local goal = target + Vector3.new(0, 3.5, 0)
    if mode == "Teleport" then
        pcall(function() hrp.CFrame = CFrame.new(goal) end)
        return
    end
    local dist = (hrp.Position - target).Magnitude
    local dur = math.clamp(dist / 80, 0.15, 2)
    local ok, tw = pcall(function()
        return TweenService:Create(hrp, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(goal) })
    end)
    if ok and tw then tw:Play(); tw.Completed:Wait() end
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
    scan(client.Character)
    scan(Backpack)
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

local function saveFile(name, data)
    pcall(function() if writefile then writefile("GAG2_"..name..".json", data) end end)
end

local function loadFile(name)
    local ok, data = pcall(function() if readfile then return readfile("GAG2_"..name..".json") end end)
    if ok and data and data ~= "" then return data end
    return nil
end

local function interval(tag, flag, delayTime, callback)
    Library:CleanupConnectionsByTag(tag)
    delayTime = math.max(tonumber(delayTime) or 0.1, 0.05)
    if not Library.Flags[flag] then return end

    local last = 0
    local running = false
    local slowWarnAt = 0
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
            local startedAt = os.clock()
            local ok2, err = pcall(callback)
            local elapsed = os.clock() - startedAt
            if not ok2 then warn("[interval:" .. tostring(tag) .. "]", err)
            elseif elapsed > 10 and os.clock() - slowWarnAt > 5 then
                slowWarnAt = os.clock()
                warn(string.format("[Versus] slow interval %s took %.3fs", tostring(tag), elapsed))
            end
            task.wait()
            running = false
        end)
    end)
    Library:TrackConnection(conn, tag)
end

local function notify(title, desc, style)
    Library:createDisplayMessage(title, desc, {{ text = "OK" }}, style or "info")
end

local Webhook = { url = "", ping = "", allowPing = false }
pcall(function()
    local d = loadFile("Webhook")
    if d then Webhook = HttpService:JSONDecode(d) end
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

local function sendHook(content, title)
    if not Webhook.url or Webhook.url == "" then return end
    local ping = ""
    if Webhook.allowPing and Webhook.ping and Webhook.ping ~= "" then
        ping = Webhook.ping .. " "
    end
    local body = HttpService:JSONEncode({
        ["content"] = ping .. (title and ("**"..title.."**\n"..content) or content),
        ["username"] = "GAG2 Hub",
    })
    task.spawn(function() httpPost(Webhook.url, body) end)
end

local StockHist = {}
local WeatherHist = {}
local LastStock = {}
local LastWeather = {}

pcall(function()
    local d = loadFile("Stock"); if d then StockHist = HttpService:JSONDecode(d) end
end)
pcall(function()
    local d = loadFile("Weather"); if d then WeatherHist = HttpService:JSONDecode(d) end
end)

local function fmtFuture(s)
    s = math.max(0, math.floor(s))
    local h = math.floor(s/3600); local m = math.floor((s%3600)/60); local d = math.floor(h/24)
    if d > 0 then return d.." day"..(d>1 and "s" or "") end
    if h > 0 then return h.." hour"..(h>1 and "s" or "") end
    if m > 0 then return m.." minute"..(m>1 and "s" or "") end
    if s > 1 then return s.." seconds" end
    return "a moment"
end

local function fmtAgo(s)
    s = math.max(0, math.floor(s))
    local h = math.floor(s/3600); local m = math.floor((s%3600)/60); local d = math.floor(h/24)
    if d > 0 then return d.." day"..(d>1 and "s" or "").." ago" end
    if h > 0 then return h.." hour"..(h>1 and "s" or "").." ago" end
    if m == 1 then return "a minute ago" end
    if m > 0 then return m.." minutes ago" end
    if s > 10 then return s.." seconds ago" end
    return "a moment ago"
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
    local total = 0
    for _,i in ipairs(h.intervals) do total = total + i end
    local avg = math.floor(total / #h.intervals)
    local last = h.appearances[#h.appearances]
    if not last then return nil end
    local nextT = last.time + avg
    local remaining = nextT - os.time()
    local amtTotal = 0
    for _,a in ipairs(h.appearances) do amtTotal = amtTotal + (a.amount or 1) end
    return remaining, math.floor(amtTotal / #h.appearances + 0.5), avg
end

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
    local total = 0
    for _,i in ipairs(h.intervals) do total = total + i end
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

local function makeESP(obj, text, color)
    if not obj or not obj:IsDescendantOf(Workspace) then return end
    if ESP_Cache[obj] then
        if ESP_Cache[obj].label and ESP_Cache[obj].label.Parent then
            ESP_Cache[obj].label.Text = text
        end
        if ESP_Cache[obj].hl and ESP_Cache[obj].hl.Parent then
            ESP_Cache[obj].hl.OutlineColor = color
            ESP_Cache[obj].hl.FillColor = color
        end
        return
    end
    local ad = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
    if not ad then return end
    local bb = Instance.new("BillboardGui")
    bb.Name = "GAG2_ESP"
    bb.Size = UDim2.new(0, 140, 0, 32)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.Adornee = ad
    bb.Parent = obj
    local lb = Instance.new("TextLabel", bb)
    lb.Size = UDim2.new(1, 0, 1, 0)
    lb.BackgroundTransparency = 1
    lb.TextColor3 = color or Color3.new(1,1,1)
    lb.TextStrokeTransparency = 0.4
    lb.Text = text or obj.Name
    lb.TextSize = 13
    lb.Font = Enum.Font.GothamBold
    local hl = Instance.new("Highlight", obj)
    hl.Name = "GAG2_HL"
    hl.FillColor = color or Color3.new(1,1,1)
    hl.FillTransparency = 0.85
    hl.OutlineColor = color or Color3.new(1,1,1)
    hl.OutlineTransparency = 0
    ESP_Cache[obj] = { bb = bb, hl = hl, label = lb }
end

local function clearESP()
    for obj,_ in pairs(ESP_Cache) do
        pcall(function()
            if obj and obj.Parent then
                for _,c in ipairs(obj:GetChildren()) do
                    if c.Name == "GAG2_ESP" or c.Name == "GAG2_HL" then c:Destroy() end
                end
            end
        end)
    end
    ESP_Cache = {}
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
    elseif l == "common" then return Color3.fromRGB(200,200,200)
    end
    return Color3.fromRGB(200,200,200)
end

local function doHarvest()
    local pf = plantsFolder(); if not pf then return end
    local count = 0
    for _,plant in ipairs(pf:GetChildren()) do
        if not plant:IsA("Model") then continue end
        local pid = plant:GetAttribute("PlantId")
        if not pid then continue end
        local hp = plant:FindFirstChild("HarvestPrompt", true)
        if hp and hp:IsA("ProximityPrompt") and hp.Enabled then
            firePrompt(hp)
            count = count + 1
            task.wait(0.12)
        end
        local fruits = plant:FindFirstChild("Fruits")
        if fruits then
            for _,f in ipairs(fruits:GetChildren()) do
                local fp = f:FindFirstChild("HarvestPrompt", true)
                if fp and fp:IsA("ProximityPrompt") and fp.Enabled then
                    fire("Garden.CollectFruit", pid, f:GetAttribute("FruitId") or f.Name)
                    count = count + 1
                    task.wait(0.1)
                end
            end
        end
    end
    return count
end

local function occupiedPositions()
    local occ = {}
    local pf = plantsFolder()
    if pf then
        for _,c in ipairs(pf:GetChildren()) do
            if c:IsA("Model") and c.PrimaryPart then
                table.insert(occ, c.PrimaryPart.Position)
            end
        end
    end
    local sf = sprinklersFolder()
    if sf then
        for _,c in ipairs(sf:GetChildren()) do
            if c:IsA("Model") and c.PrimaryPart then
                table.insert(occ, c.PrimaryPart.Position)
            end
        end
    end
    return occ
end

local function doPlant()
    local seed = Library.Flags["PlantSeed"] or "Carrot"
    if seed == "" then return false end
    local tool = findTool(seed)
    if not tool then return false end
    if not equipTool(tool) then return false end
    if not authPlot() then return false end
    local occ = occupiedPositions()
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = { client.Character }
    for _,pos in ipairs(PlotData.grid) do
        local ray = Workspace:Raycast(pos + Vector3.new(0,30,0), Vector3.new(0,-60,0), rp)
        local fp = ray and ray.Position or pos
        local taken = false
        for _,o in ipairs(occ) do
            if (Vector3.new(o.X, fp.Y, o.Z) - fp).Magnitude < 2.5 then taken = true; break end
        end
        if not taken then
            fire("Plant.PlantSeed", fp, seed, tool)
            return true
        end
    end
    return false
end

local function doSteal()
    if Library.Flags["StealOnlyNight"] and not isNight() then return end
    local hrp = getHRP(); if not hrp then return end
    local gardens = Workspace:FindFirstChild("Gardens"); if not gardens then return end
    local carry = Library.Flags["StealCarry"] or 20
    local stolen = 0
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
            local pid = plant:GetAttribute("PlantId"); if not pid then continue end
            local pos = plant.PrimaryPart and plant.PrimaryPart.Position or hrp.Position
            local sp = plant:FindFirstChild("StealPrompt", true)
            if sp and sp:IsA("ProximityPrompt") and sp.Enabled then
                if Library.Flags["StealMove"] then moveTo(pos) end
                task.wait(0.2)
                fire("Steal.BeginSteal", oid, pid, "")
                task.wait(0.1)
                fire("Steal.CompleteSteal")
                stolen = stolen + 1
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
                            fire("Steal.BeginSteal", oid, pid, fid)
                            task.wait(0.1)
                            fire("Steal.CompleteSteal")
                            stolen = stolen + 1
                            task.wait(0.25)
                            break
                        end
                    end
                end
            end
        end
    end
end

local function doSell() fire("NPCS.SellAll") end

local function doBuySeed()
    local s = Library.Flags["BuySeed"] or "Carrot"
    if s ~= "" then fire("SeedShop.PurchaseSeed", s) end
end

local function doBuyGear()
    local g = Library.Flags["BuyGear"] or "Common Sprinkler"
    if g ~= "" then fire("GearShop.PurchaseGear", g) end
end

local function findBestSprinklerSpot(radius)
    local pf = plantsFolder(); if not pf then return nil, 0 end
    local positions = {}
    for _,p in ipairs(pf:GetChildren()) do
        if p:IsA("Model") and p.PrimaryPart then table.insert(positions, p.PrimaryPart.Position) end
    end
    if #positions == 0 then return nil, 0 end
    if not authPlot() then return nil, 0 end
    local best, bestCount = nil, 0
    local step = 3
    for x = PlotData.center.X - 25, PlotData.center.X + 25, step do
        for z = PlotData.center.Z - 25, PlotData.center.Z + 25, step do
            local pos = Vector3.new(x, PlotData.center.Y, z)
            local count = 0
            for _,pp in ipairs(positions) do
                if (Vector3.new(pp.X, pos.Y, pp.Z) - pos).Magnitude <= radius then
                    count = count + 1
                end
            end
            if count > bestCount then bestCount = count; best = pos end
        end
    end
    return best, bestCount
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
    if nameFilter and nameFilter ~= "" and nameFilter ~= "All" then
        if not pname:find(nameFilter:lower(), 1, true) then return false end
    end
    if rarityFilter and rarityFilter ~= "" and rarityFilter ~= "All" then
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

local function rejoin()
    pcall(function() TeleportService:Teleport(game.PlaceId, client) end)
end

pcall(function()
    if syn and syn.queue_on_teleport then
        syn.queue_on_teleport('loadstring(game:HttpGet("YOUR_LOADER_URL"))()')
    end
end)

local Home     = Setup:CreateSection("Home")
local Main     = Setup:CreateSection("Main")
local Auto     = Setup:CreateSection("Automatically")
local Inv      = Setup:CreateSection("Inventory")
local Shop     = Setup:CreateSection("Shop")
local Webhook  = Setup:CreateSection("Webhook")
local Misc     = Setup:CreateSection("Misc")

-- HOME
Home:createLabel({ Name = "GAG_2", Special = true })
Home:createLabel({ Name = "Grow a Garden 2 executor script", Center = true })

Home:createDropdown({ Name = "Movement Mode", flagName = "TransportMode", List = {"Tween","Teleport"}, Flag = "Tween" })

Home:createButton({ Name = "Refresh Plot", Callback = function()
    authPlot(true)
    local ok = PlotData.auth
    local msg = ok and ("Plot #"..tostring(PlotData.id).." | "..#PlotData.grid.." nodes") or "No plot found"
    notify("Plot", msg, ok and "info" or "warning")
end })

Home:createButton({ Name = "TP to Garden", Callback = function()
    if authPlot() then moveTo(PlotData.center) end
end })

Home:createButton({ Name = "Sell All Now", Callback = function()
    doSell()
    notify("Sell", "SellAll fired", "info")
end })

Home:createLabel({ Name = "Stats", Special = true })
Home:createButton({ Name = "Check Stock", Callback = function()
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
                if rem and rem > 0 then
                    table.insert(lines, "  "..it.name.." - OUT (restock "..fmtFuture(rem).." x"..(amt or 1)..")")
                elseif rem and rem <= 0 then
                    table.insert(lines, "  "..it.name.." - OUT (any moment x"..(amt or 1)..")")
                else
                    table.insert(lines, "  "..it.name.." - OUT (learning...)")
                end
            end
        end
    end
    notify("Stock", table.concat(lines, "\n"), "info")
end })

Home:createButton({ Name = "Check Weather", Callback = function()
    trackWeather()
    local w = getCurrentWeather()
    local lines = {"=== WEATHER ==="}
    local any = false
    for _,wt in ipairs(WeatherTypes) do
        local d = w[wt.attr]
        if d and d.playing then
            any = true
            table.insert(lines, wt.name.." - ACTIVE ("..fmtFuture(d.remaining).." left)")
        end
    end
    if not any then table.insert(lines, "No active weather") end
    for _,wt in ipairs(WeatherTypes) do
        local rem = predictWeather(wt.attr)
        if rem and rem > 0 then
            table.insert(lines, wt.name.." next in "..fmtFuture(rem))
        end
    end
    notify("Weather", table.concat(lines, "\n"), "info")
end })

Home:createButton({ Name = "Clear Predictions", Callback = function()
    StockHist = {}
    WeatherHist = {}
    pcall(function() saveFile("Stock", "{}") end)
    pcall(function() saveFile("Weather", "{}") end)
    notify("Cleared", "All prediction history wiped", "info")
end })

-- MAIN
Main:createLabel({ Name = "- [ Harvest ] -", Special = true })
Main:createToggle({ Name = "Auto Harvest", flagName = "AutoHarvest", Flag = false, Callback = function()
    interval("AutoHarvest", "AutoHarvest", 0.5, doHarvest)
end })

Main:createLabel({ Name = "- [ Plant ] -", Special = true })
Main:createDropdown({ Name = "Seed", flagName = "PlantSeed", List = Seeds, Flag = "Carrot" })
Main:createToggle({ Name = "Auto Plant", flagName = "AutoPlant", Flag = false, Callback = function()
    interval("AutoPlant", "AutoPlant", 1.5, doPlant)
end })

Main:createLabel({ Name = "- [ Sell ] -", Special = true })
Main:createToggle({ Name = "Auto Sell", flagName = "AutoSell", Flag = false, Callback = function()
    interval("AutoSell", "AutoSell", 6, doSell)
end })

Main:createLabel({ Name = "- [ Water ] -", Special = true })
Main:createToggle({ Name = "Auto Water", flagName = "AutoWater", Flag = false, Callback = function()
    interval("AutoWater", "AutoWater", 1, function()
        local pf = plantsFolder(); if not pf then return end
        for _,p in ipairs(pf:GetChildren()) do
            if not p:IsA("Model") then continue end
            local gp = p:FindFirstChild("GrowPrompt", true)
            if gp and gp:IsA("ProximityPrompt") and gp.Enabled then
                firePrompt(gp)
                task.wait(0.1)
            end
        end
    end)
end })

-- AUTOMATICALLY
Auto:createLabel({ Name = "- [ Steal ] -", Special = true })
Auto:createToggle({ Name = "Auto Steal", flagName = "AutoSteal", Flag = false, Callback = function()
    interval("AutoSteal", "AutoSteal", 0.8, doSteal)
end })
Auto:createToggle({ Name = "Only At Night", flagName = "StealOnlyNight", Flag = true })
Auto:createToggle({ Name = "Move To Plants", flagName = "StealMove", Flag = true })
Auto:createSlider({ Name = "Carry Limit", flagName = "StealCarry", value = 20, minValue = 1, maxValue = 100 })

Auto:createLabel({ Name = "- [ Auto Buy Seeds ] -", Special = true })
Auto:createDropdown({ Name = "Seed", flagName = "BuySeed", List = Seeds, Flag = "Carrot" })
Auto:createToggle({ Name = "Auto Buy Seed", flagName = "AutoBuySeed", Flag = false, Callback = function()
    interval("AutoBuySeed", "AutoBuySeed", 3, doBuySeed)
end })

Auto:createLabel({ Name = "- [ Auto Buy Gear ] -", Special = true })
Auto:createDropdown({ Name = "Gear", flagName = "BuyGear", List = Gear, Flag = "Common Sprinkler" })
Auto:createToggle({ Name = "Auto Buy Gear", flagName = "AutoBuyGear", Flag = false, Callback = function()
    interval("AutoBuyGear", "AutoBuyGear", 3, doBuyGear)
end })

Auto:createLabel({ Name = "- [ Auto Buy Crate ] -", Special = true })
Auto:createDropdown({ Name = "Crate", flagName = "BuyCrate", List = Crates, Flag = "Common Egg" })
Auto:createToggle({ Name = "Auto Buy Crate", flagName = "AutoBuyCrate", Flag = false, Callback = function()
    interval("AutoBuyCrate", "AutoBuyCrate", 4, function()
        fire("EggShop.PurchaseEgg", Library.Flags["BuyCrate"])
    end)
end })
Auto:createToggle({ Name = "Auto Buy All Crate", flagName = "AutoBuyAllCrate", Flag = false, Callback = function()
    interval("AutoBuyAllCrate", "AutoBuyAllCrate", 8, function()
        for _,c in ipairs(Crates) do
            fire("EggShop.PurchaseEgg", c)
            task.wait(0.4)
        end
    end)
end })

Auto:createLabel({ Name = "- [ Sprinkler ] -", Special = true })
Auto:createSlider({ Name = "Radius", flagName = "SprinklerRadius", value = 20, minValue = 10, maxValue = 60 })
Auto:createButton({ Name = "Find Best Spot", Callback = function()
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
end })
Auto:createButton({ Name = "Place Sprinkler", Callback = function()
    local r = Library.Flags["SprinklerRadius"] or 20
    local pos, count = findBestSprinklerSpot(r)
    if not pos then notify("Error", "No best spot", "danger"); return end
    local g = Library.Flags["BuyGear"] or "Common Sprinkler"
    local tool = findTool(g)
    if not tool then notify("Error", "No sprinkler in inventory", "danger"); return end
    if not equipTool(tool) then return end
    fire("Place.PlaceSprinkler", pos, g, tool, PlotData.id or 1)
    notify("Placed", "Covers "..count.." plants", "info")
end })

-- INVENTORY
Inv:createLabel({ Name = "- [ Tools ] -", Special = true })
Inv:createButton({ Name = "Equip Current Tool", Callback = function()
    local c = client.Character
    if c then
        local t = c:FindFirstChildWhichIsA("Tool")
        if t then pcall(function() Hum:EquipTool(t) end) end
    end
end })
Inv:createButton({ Name = "Drop All Tools", Callback = function()
    local bp = client:FindFirstChild("Backpack")
    if bp then
        for _,t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") then t.Parent = Workspace end
        end
    end
end })
Inv:createToggle({ Name = "Keep Tool Equipped", flagName = "KeepTool", Flag = false, Callback = function()
    interval("KeepTool", "KeepTool", 0.5, function()
        local want = Library.Flags["PlantSeed"]
        if want and want ~= "" then
            local t = findTool(want)
            if t and t.Parent ~= client.Character then pcall(function() Hum:EquipTool(t) end) end
        end
    end)
end })

Inv:createLabel({ Name = "- [ Pet ] -", Special = true })
Inv:createDropdown({ Name = "Pet To Equip", flagName = "EquipPet", List = Pets, Flag = "Raccoon" })
Inv:createButton({ Name = "Equip Pet", Callback = function()
    fire("Pet.EquipPet", Library.Flags["EquipPet"])
end })

-- SHOP
Shop:createLabel({ Name = "- [ Shop Seeds ] -", Special = true })
Shop:createDropdown({ Name = "Seed", flagName = "BuySeed", List = Seeds, Flag = "Carrot" })
Shop:createToggle({ Name = "Auto Buy Seed", flagName = "AutoBuySeed", Flag = false, Callback = function()
    interval("AutoBuySeed", "AutoBuySeed", 3, doBuySeed)
end })
Shop:createButton({ Name = "Buy Now", Callback = doBuySeed })

Shop:createLabel({ Name = "- [ Shop Gear ] -", Special = true })
Shop:createDropdown({ Name = "Gear", flagName = "BuyGear", List = Gear, Flag = "Common Sprinkler" })
Shop:createToggle({ Name = "Auto Buy Gear", flagName = "AutoBuyGear", Flag = false, Callback = function()
    interval("AutoBuyGear", "AutoBuyGear", 3, doBuyGear)
end })
Shop:createToggle({ Name = "Auto Buy All Gear", flagName = "AutoBuyAllGear", Flag = false, Callback = function()
    interval("AutoBuyAllGear", "AutoBuyAllGear", 6, function()
        for _,g in ipairs(Gear) do
            fire("GearShop.PurchaseGear", g)
            task.wait(0.3)
        end
    end)
end })
Shop:createButton({ Name = "Buy Now", Callback = doBuyGear })

Shop:createLabel({ Name = "- [ Shop Crate ] -", Special = true })
Shop:createDropdown({ Name = "Crate", flagName = "BuyCrate", List = Crates, Flag = "Common Egg" })
Shop:createToggle({ Name = "Auto Buy Crate", flagName = "AutoBuyCrate", Flag = false, Callback = function()
    interval("AutoBuyCrate", "AutoBuyCrate", 4, function()
        fire("EggShop.PurchaseEgg", Library.Flags["BuyCrate"])
    end)
end })
Shop:createToggle({ Name = "Auto Buy All Crate", flagName = "AutoBuyAllCrate", Flag = false, Callback = function()
    interval("AutoBuyAllCrate", "AutoBuyAllCrate", 8, function()
        for _,c in ipairs(Crates) do
            fire("EggShop.PurchaseEgg", c)
            task.wait(0.4)
        end
    end)
end })
Shop:createButton({ Name = "Buy Now", Callback = function()
    fire("EggShop.PurchaseEgg", Library.Flags["BuyCrate"])
end })

-- WEBHOOK
Webhook:createLabel({ Name = "- [ Config Webhook ] -", Special = true })
Webhook:createInput({ Name = "Webhook URL", Placeholder = "https://discord.com/api/webhooks/...", RemoveTextAfterFocusLost = false, flagName = "WebhookURL", Callback = function(t)
    Webhook.url = t
    pcall(function() saveFile("Webhook", HttpService:JSONEncode(Webhook)) end)
end })
Webhook:createInput({ Name = "Ping Message/ID", Placeholder = "<@your_id>", RemoveTextAfterFocusLost = false, flagName = "PingID", Callback = function(t)
    Webhook.ping = t
    pcall(function() saveFile("Webhook", HttpService:JSONEncode(Webhook)) end)
end })
Webhook:createToggle({ Name = "Allow Ping On Webhook", flagName = "AllowPing", Flag = false, Callback = function(v)
    Webhook.allowPing = v
    pcall(function() saveFile("Webhook", HttpService:JSONEncode(Webhook)) end)
end })
Webhook:createButton({ Name = "Test Webhook", Callback = function()
    sendHook("Test from GAG_2 - "..os.date("%c"), "Webhook OK")
    notify("Webhook", "Test sent", "info")
end })

Webhook:createLabel({ Name = "- [ Pets Purchase Webhook ] -", Special = true })
Webhook:createToggle({ Name = "Notify On Pet Purchase", flagName = "NotifyPet", Flag = false })
Webhook:createDropdown({ Name = "Select Pets", flagName = "WhPet", List = {"All", unpack(Pets)}, Flag = "All" })
Webhook:createDropdown({ Name = "Select Rarity Pets", flagName = "WhPetRarity", List = {"All", unpack(PetRarities)}, Flag = "All" })
Webhook:createDropdown({ Name = "Select Size Pets", flagName = "WhPetSize", List = {"All","1","2","3","4","5","10","20","50","100"}, Flag = "All" })

Webhook:createLabel({ Name = "- [ Webhook Collection Event Seed ] -", Special = true })
Webhook:createToggle({ Name = "Webhook Collection Event Seed", flagName = "WhEventSeed", Flag = false })
Webhook:createDropdown({ Name = "Select Event Seed", flagName = "WhEventSeedName", List = {"All", unpack(Seeds)}, Flag = "All" })

Webhook:createLabel({ Name = "- [ Stock Webhook ] -", Special = true })
Webhook:createToggle({ Name = "Notify On Restock", flagName = "NotifyRestock", Flag = false })

-- MISC — ESP
Misc:createLabel({ Name = "- [ ESP Fruit ] -", Special = true })
Misc:createDropdown({ Name = "Select ESP Fruit", flagName = "ESPFruit", List = {"All", unpack(Seeds)}, Flag = "All" })
Misc:createDropdown({ Name = "Select ESP Rarity", flagName = "ESPRarity", List = {"All", unpack(PetRarities)}, Flag = "All" })
Misc:createDropdown({ Name = "Select ESP Mutation", flagName = "ESPMutation", List = {"All", unpack(Mutations)}, Flag = "All" })
Misc:createToggle({ Name = "ESP Fruit", flagName = "ESPFruitOn", Flag = false, Callback = function()
    interval("ESPFruit", "ESPFruitOn", 2, function()
        clearESP()
        local gardens = Workspace:FindFirstChild("Gardens")
        if not gardens then return end
        local fruitFilter = Library.Flags["ESPFruit"] or "All"
        local rarityFilter = Library.Flags["ESPRarity"] or "All"
        local mutationFilter = Library.Flags["ESPMutation"] or "All"
        for _,plot in ipairs(gardens:GetChildren()) do
            if not (plot:IsA("Model") or plot:IsA("Folder")) then continue end
            local pf = plot:FindFirstChild("Plants")
            if not pf then continue end
            for _,plant in ipairs(pf:GetChildren()) do
                if not plant:IsA("Model") then continue end
                local sname = plant:GetAttribute("SeedName") or plant.Name
                local rarity = plant:GetAttribute("Rarity") or "Common"
                local mut = plant:GetAttribute("Mutation") or ""
                if fruitFilter ~= "All" and not sname:lower():find(fruitFilter:lower(), 1, true) then continue end
                if rarityFilter ~= "All" and rarity ~= rarityFilter then continue end
                if mutationFilter ~= "All" and mut ~= mutationFilter then continue end
                local text = sname.." | "..rarity
                if mut ~= "" then text = text.." ["..mut.."]" end
                if plot ~= PlotData.model then text = text.." [STEAL]" end
                makeESP(plant, text, rarityColor(rarity))
            end
        end
    end)
end })

Misc:createLabel({ Name = "- [ ESP Spawned Pets ] -", Special = true })
Misc:createDropdown({ Name = "Select Pets", flagName = "ESPPet", List = {"All", unpack(Pets)}, Flag = "All" })
Misc:createDropdown({ Name = "Select Rarity Pets", flagName = "ESPPetRarity", List = {"All", unpack(PetRarities)}, Flag = "All" })
Misc:createDropdown({ Name = "Select Size Pets", flagName = "ESPPetSize", List = {"All","1","2","3","4","5","10","20","50","100"}, Flag = "All" })
Misc:createToggle({ Name = "ESP Spawned Pets", flagName = "ESPPetOn", Flag = false, Callback = function()
    interval("ESPPet", "ESPPetOn", 2, function()
        local nameFilter = Library.Flags["ESPPet"] or "All"
        local rarityFilter = Library.Flags["ESPPetRarity"] or "All"
        local sizeFilter = Library.Flags["ESPPetSize"] or "All"
        for _,pet in ipairs(findPets()) do
            if petMatches(pet, nameFilter, rarityFilter, sizeFilter) then
                local pname = pet:GetAttribute("PetName") or pet.Name
                local rarity = pet:GetAttribute("Rarity") or "Common"
                local size = pet:GetAttribute("Size") or 1
                makeESP(pet, pname.." | "..rarity.." | x"..tostring(size), rarityColor(rarity))
            end
        end
    end)
end })

Misc:createLabel({ Name = "- [ ESP NPCs ] -", Special = true })
Misc:createToggle({ Name = "ESP NPCs", flagName = "ESPNPCOn", Flag = false, Callback = function()
    interval("ESPNPC", "ESPNPCOn", 3, function()
        local npcs = Workspace:FindFirstChild("NPCS") or Workspace:FindFirstChild("NPCs")
        if npcs then
            for _,npc in ipairs(npcs:GetChildren()) do
                if npc:IsA("Model") then makeESP(npc, npc.Name, Color3.fromRGB(100,200,255)) end
            end
        end
    end)
end })

-- MISC — Edit
Misc:createLabel({ Name = "- [ Edit ] -", Special = true })
Misc:createToggle({ Name = "Bypass Gameplay Paused", flagName = "BypassPause", Flag = false, Callback = function()
    interval("BypassPause", "BypassPause", 0.5, function()
        local pg = client:FindFirstChild("PlayerGui")
        if pg then
            for _,g in ipairs(pg:GetChildren()) do
                if g:IsA("ScreenGui") and g.Name:lower():find("pause") then g.Enabled = false end
            end
        end
    end)
end })
Misc:createToggle({ Name = "Noclip Plants", flagName = "NoclipPlants", Flag = false, Callback = function()
    interval("NoclipPlants", "NoclipPlants", 0, function()
        local pf = plantsFolder()
        if pf then
            for _,d in ipairs(pf:GetDescendants()) do
                if d:IsA("BasePart") then d.CanCollide = false end
            end
        end
    end)
end })
Misc:createToggle({ Name = "Anti-Fling", flagName = "AntiFling", Flag = false, Callback = function()
    interval("AntiFling", "AntiFling", 0.2, function()
        local hrp = getHRP()
        if hrp then
            if hrp.Velocity.Magnitude > 200 then
                hrp.Velocity = Vector3.zero
                hrp.AngularVelocity = Vector3.zero
            end
        end
    end)
end })
Misc:createToggle({ Name = "Less Knockback", flagName = "LessKnockback", Flag = false, Callback = function()
    interval("LessKnockback", "LessKnockback", 0.2, function()
        local hrp = getHRP()
        if hrp then
            if hrp.Velocity.Magnitude > 60 then hrp.Velocity = hrp.Velocity * 0.5 end
        end
    end)
end })
Misc:createToggle({ Name = "Instant Interact Prompt", flagName = "InstantPrompt", Flag = false, Callback = function()
    interval("InstantPrompt", "InstantPrompt", 1, function()
        for _,pp in ipairs(Workspace:GetDescendants()) do
            if pp:IsA("ProximityPrompt") then pp.HoldDuration = 0 end
        end
    end)
end })
Misc:createToggle({ Name = "Fullbright", flagName = "Fullbright", Flag = false, Callback = function(v)
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
end })
Misc:createSlider({ Name = "Walk Speed", flagName = "WalkSpeed", value = 16, minValue = 16, maxValue = 200 })
Misc:createToggle({ Name = "Auto Speed", flagName = "AutoSpeed", Flag = false, Callback = function()
    interval("AutoSpeed", "AutoSpeed", 0.5, function()
        local h = getHum()
        if h then h.WalkSpeed = Library.Flags["WalkSpeed"] or 16 end
    end)
end })
Misc:createSlider({ Name = "Jump Power", flagName = "JumpPower", value = 50, minValue = 50, maxValue = 250 })
Misc:createToggle({ Name = "Auto Jump", flagName = "AutoJump", Flag = false, Callback = function()
    interval("AutoJump", "AutoJump", 0.3, function()
        local h = getHum()
        if h then h.JumpPower = Library.Flags["JumpPower"] or 50 end
        if h and h:GetState() == Enum.HumanoidStateType.Freefall then
            h:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end)
end })

Misc:createLabel({ Name = "- [ More FPS ] -", Special = true })
Misc:createToggle({ Name = "More FPS", flagName = "MoreFPS", Flag = false, Callback = function(v)
    if v then
        LightingService.GlobalShadows = false
        LightingService.FogEnd = 9e9
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
        for _,d in ipairs(Workspace:GetDescendants()) do
            if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Beam") then
                d.Enabled = false
            end
        end
    end
end })

Misc:createLabel({ Name = "- [ Misc Garden ] -", Special = true })
Misc:createToggle({ Name = "Auto Plant Best Seed", flagName = "AutoPlantBest", Flag = false, Callback = function()
    interval("AutoPlantBest", "AutoPlantBest", 4, doPlant)
end })
Misc:createToggle({ Name = "Auto Replant After Harvest", flagName = "AutoReplant", Flag = false, Callback = function()
    interval("AutoReplant", "AutoReplant", 2, doPlant)
end })
Misc:createToggle({ Name = "Anti-Stuck Recover", flagName = "AntiStuckRecover", Flag = false })

Misc:createLabel({ Name = "- [ Server ] -", Special = true })
Misc:createButton({ Name = "Rejoin Server", Callback = rejoin })
Misc:createButton({ Name = "Hop Server", Callback = function()
    if hopServer() then notify("Server", "Hopping...", "info")
    else notify("Server", "Hop failed", "danger") end
end })
Misc:createButton({ Name = "Copy Place ID", Callback = function()
    pcall(function() setclipboard(tostring(game.PlaceId)) end)
end })

-- tracking
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
                            local name = item.Name
                            local count = item.Value
                            local was = prev[shop.Name][name] or 0
                            if was == 0 and count > 0 then
                                sendHook("**"..shop.Name.."** restocked: `"..name.."` x"..count, "Restock")
                            end
                            prev[shop.Name][name] = count
                        end
                    end
                end
            end
        end)
    end
end)

-- anti-stuck
task.spawn(function()
    local lastPos, stuck = nil, 0
    while task.wait(1) do
        pcall(function()
            local hrp = getHRP()
            if not hrp then return end
            if lastPos then
                if (hrp.Position - lastPos).Magnitude < 0.3 then stuck = stuck + 1
                else stuck = 0 end
                if stuck > 30 and Library.Flags["AntiStuckRecover"] then
                    hrp.CFrame = hrp.CFrame + Vector3.new(0,5,0)
                    stuck = 0
                end
            end
            lastPos = hrp.Position
        end)
    end
end)

client.CharacterAdded:Connect(function(c)
    Char = c
    Hum = c:WaitForChild("Humanoid")
    HRP = c:WaitForChild("HumanoidRootPart")
    task.wait(1)
    authPlot(true)
end)

task.spawn(function()
    task.wait(2)
    authPlot()
    if PlotData.auth then
        print("[GAG2] Ready | Plot #"..tostring(PlotData.id).." | "..#PlotData.grid.." nodes")
    end
end)

notify("GAG_2", "Loaded successfully", "info")
print("[GAG2] Loaded")

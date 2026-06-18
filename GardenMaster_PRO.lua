--[[
    GAG 2 ─ Grow a Garden 2 autofarm
    built from decompiled source, networking verified
]]

-- ----- services -----
local client  = game:GetService("Players").LocalPlayer
local Tween   = game:GetService("TweenService")
local Http    = game:GetService("HttpService")
local Run     = game:GetService("RunService")
local UIS     = game:GetService("UserInputService")
local Light   = game:GetService("Lighting")
local VUser   = game:GetService("VirtualUser")
local Core    = game:GetService("CoreGui")
local RepStor = game:GetService("ReplicatedStorage")
local ColServ = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TeleSvc = game:GetService("TeleportService")
local Wkspc   = game:GetService("Workspace")

-- ----- safe http -----
local request
pcall(function() request = syn and syn.request end)
if not request then pcall(function() request = http and http.request end) end
if not request then pcall(function() request = http_request end) end
if not request then
    request = function(t)
        local ok, r = pcall(function()
            return game:HttpGetAsync(t.Url)
        end)
        return ok and {Body = r, StatusCode = 200} or {Body = "", StatusCode = 0}
    end
end

-- ----- cleanup -----
if _G.VA_Unload then pcall(_G.VA_Unload) end
_G.VA_Unload = nil

local _alive = true
local _conns, _inst, _thrds = {}, {}, {}
local function Track(v)
    if typeof(v)=="RBXScriptConnection" then _conns[#_conns+1]=v
    elseif typeof(v)=="Instance" then _inst[#_inst+1]=v
    elseif type(v)=="thread" then _thrds[#_thrds+1]=v end
end
_G.VA_Unload = function()
    _alive=false
    for _,c in _conns do pcall(function() c:Disconnect() end) end
    for _,t in _thrds do pcall(function() if coroutine.status(t)~="dead" then task.cancel(t) end end) end
    for _,o in _inst do pcall(function() if o and o.Parent then o:Destroy() end end) end
    _conns={}; _inst={}; _thrds={}
end

-- ----- anti-afk -----
Track(client.Idled:Connect(function()
    pcall(function()
        VUser:Button2Down(Vector2.new(),Wkspc.CurrentCamera.CFrame)
        task.wait(1)
        VUser:Button2Up(Vector2.new(),Wkspc.CurrentCamera.CFrame)
    end)
end))

-- ----- networking -----
local Net = nil
do
    local ok,mod = pcall(function()
        return require(RepStor:WaitForChild("SharedModules",10):WaitForChild("Networking",10))
    end)
    if ok and mod then Net=mod
    else warn("[VA] net fail: "..tostring(mod)); return end
end
local PacketEvent
pcall(function()
    PacketEvent=RepStor:WaitForChild("SharedModules",5):WaitForChild("Packet",5):WaitForChild("RemoteEvent",5)
end)

-- ----- flags table (shared across library variants) -----


-- ----- helpers -----
local function trim(s) return tostring(s or ""):gsub("^%s+",""):gsub("%s+$","") end
local function cleanName(n)
    if not n then return "" end
    local s=trim(n):gsub("%b[]",""):gsub("%s*%*%s*x%d+%s*$",""):gsub("%s+(%d+)%s*$","")
    s=s:gsub("_"," "):gsub(":"," "):gsub("^Seed%s+",""):gsub("%s+Seed$",""):gsub("%s+Tool$","")
    return trim(s:gsub("%s+"," "))
end
local function isSeedLike(n)
    if not n then return false end
    local l=tostring(n):lower()
    return l:find("seed",1,true) and not l:find("seed pack",1,true) and not l:find("seedpack",1,true)
end
local function toList(v)
    local L={}
    if typeof(v)=="table" then
        for k,val in pairs(v) do
            if type(k)=="number" and type(val)=="string" and val~="" and val~="None" then L[#L+1]=val
            elseif type(k)=="string" and val==true and k~="" and k~="None" then L[#L+1]=k end
        end
    elseif type(v)=="string" and v~="" and v~="None" then L[1]=v end
    return L
end
local function fmt(s)
    s=math.max(0,math.floor(s or 0))
    local h=math.floor(s/3600); local m=math.floor((s%3600)/60); local sec=s%60
    if h>0 then return string.format("%dh %02dm",h,m) end
    if m>0 then return string.format("%dm %02ds",m,sec) end
    return sec.."s"
end
local function selMode(flag,fb)
    local v=Flags[flag]
    if typeof(v)=="table" then
        if v[1] then return v[1] end
        for k,val in pairs(v) do if val==true then return k end end
        return fb
    end
    return v or fb
end

-- ----- transport -----
local function movePlayer(pos)
    local hrp=client.Character and client.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local mode=Flags["TransportMode"] or "Tween"
    local tcf=CFrame.new(pos+Vector3.new(0,3.8,0))
    if mode=="Tween" then
        local d=(hrp.Position-pos).Magnitude
        local dur=math.clamp(d/100,0.15,1.5)
        local tw=Tween:Create(hrp,TweenInfo.new(dur,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{CFrame=tcf})
        tw:Play(); tw.Completed:Wait()
    else pcall(function() hrp.CFrame=tcf end) end
end
local function fireP(p) if p and p:IsA("ProximityPrompt") then pcall(function() fireproximityprompt(p) end) end end

-- ----- tools -----
local function findTool(sn)
    if not sn or sn=="" then return nil end
    local cs=cleanName(sn):lower():gsub("%s+","")
    if cs=="" then return nil end
    local function score(t)
        if not t or not t:IsA("Tool") then return nil end
        local tn=cleanName(t.Name):lower():gsub("%s+","")
        local raw=t.Name:lower():gsub("%s+","")
        if tn==cs then return 5 end
        if raw==cs then return 4 end
        if tn:find(cs,1,true) or cs:find(tn,1,true) then return 3 end
        if isSeedLike(t.Name) and cleanName(t.Name):lower():find(cleanName(sn):lower(),1,true) then return 2 end
        return nil
    end
    local best,bs=nil,-1
    local function scan(c)
        if not c then return end
        for _,t in ipairs(c:GetChildren()) do local s=score(t); if s and s>bs then best,bs=t,s end end
    end
    scan(client.Character); scan(client:FindFirstChild("Backpack"))
    return best
end
local function equipT(t)
    if not t or not t.Parent then return false end
    if t.Parent==client:FindFirstChild("Backpack") then
        local h=client.Character and client.Character:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() h:EquipTool(t) end); task.wait(0.08) end
    end
    return t.Parent==client.Character
end

-- ----- game data -----
local GD={seeds={},gears={},crates={},pets={},sprinklers={}}
local MTS={"Gold","Rainbow","Electric","Solarflare","Frozen","Bloodlit","Chained","Pizza","Starstruck","Ghost","Poison"}
local RTS={"Common","Uncommon","Rare","Super","Epic","Legendary","Mythic"}
local function refreshGD()
    local stock=RepStor:FindFirstChild("StockValues"); if not stock then return end
    local function read(sn)
        local L={}; local shop=stock:FindFirstChild(sn); local items=shop and shop:FindFirstChild("Items")
        if items then for _,it in ipairs(items:GetChildren()) do if it:IsA("NumberValue") then L[#L+1]=it.Name end end end
        table.sort(L); return L
    end
    GD.seeds=read("SeedShop"); GD.gears=read("GearShop"); GD.crates=read("CrateShop")
    GD.sprinklers={}
    for _,g in ipairs(GD.gears) do if g:lower():find("sprinkler",1,true) then GD.sprinklers[#GD.sprinklers+1]=g end end
    GD.pets=read("PetShop")
end
refreshGD()
Track(task.spawn(function() while _alive do task.wait(30); pcall(refreshGD) end end))

-- ----- remote wrappers -----
local function harvest(pid,fid) if pid then pcall(function() Net.Garden.CollectFruit:Fire(pid,fid or "") end) end end
local function plant(seed,pos)
    if not seed or not pos then return false end
    local t=findTool(seed); if not t then return false end
    local st=cleanName(t.Name); if st=="" then st=cleanName(seed) end
    pcall(function()
        if PacketEvent then PacketEvent:FireServer(4,pos,st,t) else Net.Plant.PlantSeed:Fire(pos,st,t) end
    end)
    return true
end
local function placeSpr(name,pos)
    if not name or not pos then return false end
    local t=findTool(name); if not t then return false end
    if not tostring(t.Name):lower():find("sprinkler",1,true) then return false end
    if t.Parent~=client.Character then equipT(t); task.wait(0.03) end
    local cn=t:GetAttribute("Sprinkler") or cleanName(t.Name)
    pcall(function() Net.Place.PlaceSprinkler:Fire(pos,cn,t,PL.plotId or 1) end)
    return true
end
local function sellAll() pcall(function() Net.NPCS.SellAll:Fire() end) end
local function buySeed(n) if n and n~="" then pcall(function() Net.SeedShop.PurchaseSeed:Fire(n) end) end end
local function buyGear(n) if n and n~="" then pcall(function() Net.GearShop.PurchaseGear:Fire(n) end) end end
local function buyCrate(n) if n and n~="" then pcall(function() Net.CrateShop.PurchaseCrate:Fire(n) end) end end
local function openCrate(n) if n and n~="" then pcall(function() Net.Crate.OpenCrate:Fire(n) end) end end
local function openEgg(n) if n and n~="" then pcall(function() Net.Egg.OpenEgg:Fire(n) end) end end
local function beginSteal(uid,pid,fid) pcall(function() Net.Steal.BeginSteal:Fire(uid,pid,fid or "") end) end
local function completeSteal() pcall(function() Net.Steal.CompleteSteal:Fire() end) end
local function submitCode(c) if c and c~="" then pcall(function() Net.Settings.SubmitCode:Fire(c) end) end end
local function movePlant(pid,pos,rot) if pid and pos then pcall(function() Net.Trowel.MovePlant:Fire(pid,pos,rot or 0) end) end end

-- ----- night -----
local function isNight()
    local wv=RepStor:FindFirstChild("WeatherValues")
    if wv then for _,nm in ipairs({"Moon","Bloodmoon","Goldmoon","Rainbow","RainbowMoon","ChainedMoon","PizzaMoon"}) do
        if wv:GetAttribute(nm.."_Playing")==true then return true end
    end end
    local nd=RepStor:FindFirstChild("Night",true)
    if nd and nd:IsA("BoolValue") then return nd.Value end
    local t=Light.ClockTime; return t<6 or t>=18
end
local function bpFull()
    if client:GetAttribute("BackpackFull") then return true end
    local bp=client:FindFirstChild("Backpack")
    if bp and bp:GetAttribute("BackpackFull") then return true end
    local mx=client:GetAttribute("BackpackMax") or 0
    if bp and mx>0 and #bp:GetChildren()>=mx then return true end
    return false
end
local function bpSeeds()
    local s={}
    local bp=client:FindFirstChild("Backpack")
    if bp then for _,t in ipairs(bp:GetChildren()) do if t:IsA("Tool") and isSeedLike(t.Name) then s[#s+1]=t.Name end end end
    local ch=client.Character
    if ch then for _,t in ipairs(ch:GetChildren()) do if t:IsA("Tool") and isSeedLike(t.Name) then s[#s+1]=t.Name end end end
    return s
end
local function bpSprinklers()
    local L={}
    local bp=client:FindFirstChild("Backpack")
    if bp then for _,t in ipairs(bp:GetChildren()) do if t:IsA("Tool") and t.Name:lower():find("sprinkler",1,true) then L[#L+1]=t.Name end end end
    return L
end

-- ----- plot -----
PL={auth=false,model=nil,plotId=nil,center=Vector3.zero,gate=nil,gridNodes={},plantAreas={},occupiedHash={},plantsFolder=nil,sprinklersFolder=nil,rowX=nil,rowZ=nil,lastAuth=0}
local function plotOwner(plot)
    if not plot then return nil end
    local uid=plot:GetAttribute("UserId") or plot:GetAttribute("OwnerId") or plot:GetAttribute("Owner")
    if type(uid)=="number" then return uid end
    local sv=plot:FindFirstChild("OwnerUserId") or plot:FindFirstChild("OwnerId")
    if sv and sv:IsA("ValueBase") then return sv.Value end
    -- Fallback: GAG 2 tracks ownership via player:GetAttribute("PlotId") -> "Plot"..id
    local plotNum=tonumber(tostring(plot.Name):match("Plot (%d+)"))
    if plotNum then for _,plr in ipairs(Players:GetPlayers()) do if plr:GetAttribute("PlotId")==plotNum then return plr.UserId end end end
    return nil
end
local function authPlot()
    if PL.auth and (os.clock()-PL.lastAuth)<30 then return PL end
    PL.lastAuth=os.clock()
    local gardens=Wkspc:FindFirstChild("Gardens") or Wkspc
    local target,pid
    for _,p in ipairs(gardens:GetChildren()) do
        if p:IsA("Model") or p:IsA("Folder") then
            if plotOwner(p)==client.UserId then target=p; pid=tonumber(tostring(p.Name):match("%d+")); break end
        end
    end
    if not target then
        local hrp=client.Character and client.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local closest,cd=nil,math.huge
            for _,p in ipairs(gardens:GetChildren()) do
                if p:IsA("Model") or p:IsA("Folder") then
                    local pr=p.PrimaryPart or p:FindFirstChildWhichIsA("BasePart")
                    if pr then local dist=(pr.Position-hrp.Position).Magnitude
                        if dist<cd then closest=p; cd=dist; pid=tonumber(tostring(p.Name):match("%d+")) end
                    end
                end
            end
            if closest and cd<50 then target=closest end
        end
    end
    if not target then return PL end
    PL.model=target; PL.plotId=pid or tonumber(tostring(target.Name):match("%d+"))
    PL.auth=true; PL.plantAreas={}; PL.occupiedHash={}; PL.rowX=nil; PL.rowZ=nil
    local sp=target:FindFirstChild("SpawnPoint")
    if sp and sp:IsA("BasePart") then
        PL.center=sp.Position; PL.gate=CFrame.new(sp.Position+Vector3.new(0,3.5,3),sp.Position)
    else
        local pr=(target:IsA("Model") and target.PrimaryPart) or target:FindFirstChild("BottomFace",true)
        if pr and pr:IsA("BasePart") then PL.center=pr.Position; PL.gate=CFrame.new(pr.Position+Vector3.new(0,5,15),pr.Position) end
    end
    PL.plantsFolder=target:FindFirstChild("Plants"); PL.sprinklersFolder=target:FindFirstChild("Sprinklers")
    local fb={}
    for _,ch in ipairs(target:GetDescendants()) do
        if ch:IsA("BasePart") then
            local n=ch.Name:lower()
            local tagged=ColServ:HasTag(ch,"PlantArea") or ColServ:HasTag(ch,"Soil")
            local ns=n:find("plantarea",1,true) or n:find("plant area",1,true) or n:find("soil",1,true) or n:find("dirt",1,true) or n:find("farm",1,true)
            if tagged or ns then PL.plantAreas[#PL.plantAreas+1]=ch
            elseif n=="bottomface" or n=="base" or n=="floor" or n:find("garden",1,true) then fb[#fb+1]=ch end
        end
    end
    if #PL.plantAreas==0 then
        table.sort(fb,function(a,b) return (a.Size.X*a.Size.Z)>(b.Size.X*b.Size.Z) end)
        if fb[1] then PL.plantAreas[#PL.plantAreas+1]=fb[1]
        else local b=target:FindFirstChild("BottomFace",true) or (target:IsA("Model") and target.PrimaryPart)
            if b and b:IsA("BasePart") then PL.plantAreas[#PL.plantAreas+1]=b end
        end
    end
    table.sort(PL.plantAreas,function(a,b) return (a.Size.X*a.Size.Z)>(b.Size.X*b.Size.Z) end)
    PL.gridNodes={}
    for _,area in ipairs(PL.plantAreas) do
        local ap=area.Position; local sx,sz=math.max(area.Size.X,1)*0.46,math.max(area.Size.Z,1)*0.46
        for x=-sx,sx,2.6 do for z=-sz,sz,2.6 do
            local ox=ap.X+x+math.random(-0.4,0.4); local oz=ap.Z+z+math.random(-0.4,0.4)
            local ry=Wkspc:Raycast(Vector3.new(ox,ap.Y+30,oz),Vector3.new(0,-60,0))
            PL.gridNodes[#PL.gridNodes+1]=ry and ry.Position or Vector3.new(ox,ap.Y+area.Size.Y/2+0.15,oz)
        end end
    end
    for i=#PL.gridNodes,2,-1 do local j=math.random(i); PL.gridNodes[i],PL.gridNodes[j]=PL.gridNodes[j],PL.gridNodes[i] end
    return PL
end

-- ----- placement -----
local function occupiedCells()
    local oc,h={},PL.occupiedHash or {}
    if PL.plantsFolder then for _,p in PL.plantsFolder:GetChildren() do
        if p:IsA("Model") and p.PrimaryPart then local pp=p:GetPivot().Position; oc[#oc+1]=pp; h[math.floor(pp.X/2)..","..math.floor(pp.Z/2)]=true end
    end end
    if PL.sprinklersFolder then for _,s in PL.sprinklersFolder:GetChildren() do
        if s:IsA("Model") and s.PrimaryPart then oc[#oc+1]=s:GetPivot().Position end
    end end
    PL.occupiedHash=h; return oc
end
local function rowPos(spc)
    authPlot(); spc=spc or 2.9
    if not PL.auth or #PL.plantAreas==0 then return PL.center end
    local area=PL.plantAreas[1]; local ap=area.Position
    local sx,sz=math.max(area.Size.X,1)*0.44,math.max(area.Size.Z,1)*0.44
    if not PL.rowX then PL.rowX=ap.X-sx; PL.rowZ=ap.Z-sz end
    local x,z=PL.rowX,PL.rowZ; occupiedCells()
    local key=math.floor(x/2)..","..math.floor(z/2); local tries=0
    while PL.occupiedHash[key] and tries<600 do
        x=x+spc; if x>ap.X+sx then x=ap.X-sx; z=z+spc end
        if z>ap.Z+sz then z=ap.Z-sz; x=ap.X-sx end
        key=math.floor(x/2)..","..math.floor(z/2); tries=tries+1
    end
    local r=Wkspc:Raycast(Vector3.new(x,ap.Y+30,z),Vector3.new(0,-60,0))
    local pos=r and r.Position or Vector3.new(x,ap.Y+area.Size.Y/2+0.15,z)
    PL.rowX=x+spc; if PL.rowX>ap.X+sx then PL.rowX=ap.X-sx; PL.rowZ=PL.rowZ+spc end
    if PL.rowZ>ap.Z+sz then PL.rowZ=ap.Z-sz end
    PL.occupiedHash[key]=true; return pos
end
local function placePos(spc)
    authPlot(); spc=spc or 2.9
    local mode=Flags["PlacingMode"] or "Row Fill"
    local hrp=client.Character and client.Character:FindFirstChild("HumanoidRootPart")
    if mode=="Row Fill" then return rowPos(spc) end
    if mode=="At Player" then
        if hrp then local r=Wkspc:Raycast(hrp.Position+Vector3.new(0,6,0),Vector3.new(0,-30,0)); return r and r.Position or hrp.Position-Vector3.new(0,2.8,0) end
        return Vector3.zero
    end
    if mode=="Random" and PL.auth then
        local h=18; local rx=PL.center.X+(math.random()*2-1)*h; local rz=PL.center.Z+(math.random()*2-1)*h
        local r=Wkspc:Raycast(Vector3.new(rx,PL.center.Y+28,rz),Vector3.new(0,-55,0))
        return r and r.Position or Vector3.new(rx,PL.center.Y,rz)
    end
    if mode=="At Mouse" then
        local mp; pcall(function() local m=client:GetMouse(); if m and m.Hit then mp=m.Hit.Position end end)
        if mp then return mp end
    end
    if not PL.auth or #PL.gridNodes==0 then return hrp and hrp.Position or Vector3.zero end
    local o=occupiedCells()
    for _,n in PL.gridNodes do
        local k=math.floor(n.X/2)..","..math.floor(n.Z/2)
        if not PL.occupiedHash[k] then
            local ok=true
            for _,u in o do if (Vector3.new(u.X,n.Y,u.Z)-n).Magnitude<2.5 then ok=false; break end end
            if ok then PL.occupiedHash[k]=true; return n end
        end
    end
    return hrp and hrp.Position or Vector3.zero
end
local function geofence(mode)
    if not PL.auth or not PL.gate then return end
    local hrp=client.Character and client.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local range=mode=="p" and 60 or mode=="c" and 100 or 80
    if (hrp.Position-PL.center).Magnitude>range then movePlayer(PL.gate.Position) end
end

-- ----- value scoring -----
local MutVal={gold=15,rainbow=42,electric=11,solarflare=13,frozen=9,bloodlit=11,chained=7,pizza=6,starstruck=22,ghost=18,poison=14}
local RarityScore={common=1,uncommon=2,rare=3,super=4,epic=5,legendary=6,mythic=7,gold=10,rainbow=10}
local function passFilter(m,fruitF,mutF,rarF)
    if not m then return false end
    local nm=m.Name:lower(); local ma=(m:GetAttribute("Mutation") or ""):lower(); local ra=(m:GetAttribute("Rarity") or ""):lower()
    if fruitF and #fruitF>0 then local ok=false; for _,f in ipairs(fruitF) do if nm:find(f:lower(),1,true) then ok=true; break end end; if not ok then return false end end
    if mutF and #mutF>0 then local ok=false; for _,mu in ipairs(mutF) do if ma==mu:lower() then ok=true; break end end; if not ok then return false end end
    if rarF and #rarF>0 then local ok=false; for _,r in ipairs(rarF) do if ra==r:lower() then ok=true; break end end; if not ok then return false end end
    return true
end
local function plantValue(m)
    if not m then return 0 end; local s=0
    local ra=(m:GetAttribute("Rarity") or ""):lower(); s=s+(RarityScore[ra] or 1)*120
    local mu=(m:GetAttribute("Mutation") or ""):lower(); s=s*(MutVal[mu] or 1)
    local sz=m:GetAttribute("Size") or m:GetAttribute("FruitSize") or 1
    if type(sz)=="number" then s=s*math.max(sz,0.15) end
    local sv=m:GetAttribute("Value") or m:GetAttribute("SellValue") or 0
    if type(sv)=="number" then s=s+sv*1.2 end
    if m:GetAttribute("MultiHarvest") then s=s*1.6 end
    local age=m:GetAttribute("Age") or m:GetAttribute("Growth") or 1
    if type(age)=="number" and age>1 then s=s*(1+math.min(age/10,0.8)) end
    return s
end
local function getCandidates(mx,fruitF,mutF,rarF,ownedOnly,blist)
    mx=mx or 12; local candidates={}
    local hrp=client.Character and client.Character:FindFirstChild("HumanoidRootPart")
    local gardens=Wkspc:FindFirstChild("Gardens") or Wkspc
    local pom={}
    for _,p in ipairs(gardens:GetChildren()) do
        if p:IsA("Model") or p:IsA("Folder") then
            local ow=plotOwner(p); if ow then pom[p]=ow; local pff=p:FindFirstChild("Plants")
                if pff then for _,mm in ipairs(pff:GetChildren()) do if mm:IsA("Model") then pom[mm]=ow end end end
            end
        end
    end
    local function add(m,isOurs)
        if not m or not m:IsA("Model") then return end
        if blist and #blist>0 then for _,b in ipairs(blist) do if m.Name:lower():find(b:lower(),1,true) then return end end end
        if not passFilter(m,fruitF,mutF,rarF) then return end
        if ownedOnly and not isOurs then return end
        local pid=m:GetAttribute("PlantId"); local fid=m:GetAttribute("FruitId")
        local sc=plantValue(m); local d=hrp and (m:GetPivot().Position-hrp.Position).Magnitude or 0
        local po=pom[m]
        local finalOwner = po or m:GetAttribute("UserId")
        candidates[#candidates+1]={model=m,plantId=pid,fruitId=fid,score=sc,distance=d,isOwned=isOurs,plotOwner=finalOwner,position=m:GetPivot().Position}
    end
    for _,prompt in ipairs(ColServ:GetTagged("HarvestPrompt")) do add(prompt:FindFirstAncestorWhichIsA("Model"),true) end
    for _,p in ipairs(gardens:GetChildren()) do
        if p:IsA("Model") or p:IsA("Folder") then
            local poResult=plotOwner(p); local ours=poResult==client.UserId; local pff=p:FindFirstChild("Plants")
            if pff then for _,mm in ipairs(pff:GetChildren()) do if mm:IsA("Model") then add(mm,ours) end end end
        end
    end
    table.sort(candidates,function(a,b) if a.score~=b.score then return a.score>b.score end; return a.distance<b.distance end)
    local r={}; for i=1,math.min(mx,#candidates) do r[#r+1]=candidates[i] end; return r
end

-- ----- weather / stock -----
local WTypes={{id="Starfall",label="Starfall",color=Color3.fromRGB(255,220,100),mutations={"Starstruck"}},{id="Snowfall",label="Snowfall",color=Color3.fromRGB(180,220,255),mutations={"Frozen"}},{id="Rainbow",label="Rainbow",color=Color3.fromRGB(120,255,200),mutations={"Rainbow"}},{id="Rain",label="Rain",color=Color3.fromRGB(100,150,255),mutations={}},{id="Lighting",label="Lighting",color=Color3.fromRGB(255,255,150),mutations={"Electric"}}}
local function readWeather()
    local wv=RepStor:FindFirstChild("WeatherValues"); if not wv then return {} end
    local states={}
    for _,wt in ipairs(WTypes) do
        local folder=wv:FindFirstChild(wt.id); local playing,endTime=false,0
        if folder then local pv=folder:FindFirstChild("Playing"); local ev=folder:FindFirstChild("EndTime")
            if pv and pv:IsA("BoolValue") then playing=pv.Value end
            if ev and ev:IsA("NumberValue") then endTime=ev.Value end
        else playing=wv:GetAttribute(wt.id.."_Playing")==true; endTime=wv:GetAttribute(wt.id.."_EndTime") or 0 end
        states[wt.id]={playing=playing,remaining=playing and math.max(0,endTime-os.time()) or 0,mutations=wt.mutations,label=wt.label,color=wt.color}
    end; return states
end
local function readStock()
    local stock=RepStor:FindFirstChild("StockValues"); if not stock then return {} end
    local data={}
    for _,shop in ipairs(stock:GetChildren()) do
        local items=shop:FindFirstChild("Items"); if items then
            local sd={}
            for _,it in ipairs(items:GetChildren()) do if it:IsA("NumberValue") then sd[#sd+1]={name=it.Name,count=it.Value} end end
            table.sort(sd,function(a,b) return a.name<b.name end); data[shop.Name]=sd
        end
    end; return data
end
local function restockUnix(sn)
    local stock=RepStor:FindFirstChild("StockValues"); local shop=stock and stock:FindFirstChild(sn)
    local nr=shop and shop:FindFirstChild("UnixNextRestock"); if nr and tonumber(nr.Value) then return tonumber(nr.Value) end; return nil
end
local StockSnap={}; local RestockHist={}
local function trackStock()
    local stock=RepStor:FindFirstChild("StockValues"); if not stock then return end; local now=os.time()
    for _,shop in ipairs(stock:GetChildren()) do
        local items=shop:FindFirstChild("Items"); if not items then continue end
        for _,it in ipairs(items:GetChildren()) do
            if not it:IsA("NumberValue") then continue end
            local key=shop.Name.."."..it.Name; local prev=StockSnap[key] or 0; local curr=it.Value
            if prev==0 and curr>0 then
                if not RestockHist[key] then RestockHist[key]={} end
                local hist=RestockHist[key]; hist[#hist+1]={time=now,count=curr}
                if #hist>10 then table.remove(hist,1) end
            end; StockSnap[key]=curr
        end
    end
end
local function predictRestock(sn,iname)
    local key=sn.."."..iname; local hist=RestockHist[key]; if not hist or #hist<2 then return nil,nil end
    local ti,ct=0,0
    for i=2,#hist do ti=ti+(hist[i].time-hist[i-1].time); ct=ct+1 end
    if ct==0 then return nil,nil end
    local avgI=ti/ct; local lastR=hist[#hist].time; local nextP=lastR+avgI; local avgC=0
    for _,h in ipairs(hist) do avgC=avgC+h.count end; avgC=math.floor(avgC/#hist)
    return nextP,avgC
end

-- ----- search fruits -----
local function searchFruits(fn,mt,rr,mnVal,incOwn)
    local results={}
    local hrp=client.Character and client.Character:FindFirstChild("HumanoidRootPart")
    local gardens=Wkspc:FindFirstChild("Gardens") or Wkspc
    for _,p in ipairs(gardens:GetChildren()) do
        if not (p:IsA("Model") or p:IsA("Folder")) then continue end
        local po=plotOwner(p); local isOurs=po==client.UserId
        if not incOwn and isOurs then continue end
        local pff=p:FindFirstChild("Plants"); if not pff then continue end
        for _,m in ipairs(pff:GetChildren()) do
            if not m:IsA("Model") then continue end
            if fn and #fn>0 then local ok=false; local nm=m.Name:lower()
                for _,f in ipairs(fn) do if nm:find(f:lower(),1,true) then ok=true; break end end
                if not ok then continue end
            end
            local mu=(m:GetAttribute("Mutation") or ""):lower()
            if mt and #mt>0 then local ok=false
                for _,mm in ipairs(mt) do if mu==mm:lower() then ok=true; break end end
                if not ok then continue end
            end
            local ra=(m:GetAttribute("Rarity") or ""):lower()
            if rr and #rr>0 then local ok=false
                for _,r in ipairs(rr) do if ra==r:lower() then ok=true; break end end
                if not ok then continue end
            end
            local val=plantValue(m); if mnVal and val<mnVal then continue end
            local pos=m:GetPivot().Position; local d=hrp and (pos-hrp.Position).Magnitude or 0
            local finalOwner = po or m:GetAttribute("UserId")
            results[#results+1]={model=m,plantId=m:GetAttribute("PlantId"),fruitId=m:GetAttribute("FruitId"),score=val,distance=d,isOwned=isOurs,plotOwner=finalOwner,position=pos}
        end
    end
    table.sort(results,function(a,b) if a.score~=b.score then return a.score>b.score end; return a.distance<b.distance end)
    return results
end

-- ----- ground items -----
local function findGround(itemType)
    local items={}
    local hrp=client.Character and client.Character:FindFirstChild("HumanoidRootPart")
    local pr=Flags["PickupRange"] or 50
    for _,obj in ipairs(Wkspc:GetDescendants()) do
        if not obj:IsA("BasePart") then continue end
        local prompt=obj:FindFirstChildWhichIsA("ProximityPrompt"); if not prompt then continue end
        local at=prompt.ActionText:lower(); local on=obj.Name:lower()
        local matches=false
        if itemType=="seeds" then matches=at:find("pick up",1,true) or at:find("collect",1,true) or at:find("take",1,true) or isSeedLike(obj.Name)
        elseif itemType=="gear" then matches=on:find("gear",1,true) or at:find("gear",1,true)
        elseif itemType=="crates" then matches=on:find("crate",1,true)
        else matches=true end
        if not matches then continue end
        local d=hrp and (obj.Position-hrp.Position).Magnitude or math.huge; if d>pr then continue end
        items[#items+1]={model=obj,name=obj.Name,prompt=prompt,position=obj.Position,distance=d}
    end
    table.sort(items,function(a,b) return a.distance<b.distance end); return items
end

-- ----- pets -----
local function tameWildPet(pm)
    if not pm or not pm:IsA("Model") then return end; if pm:GetAttribute("Wild")~=true then return end
    local primary=pm.PrimaryPart or pm:FindFirstChildWhichIsA("BasePart")
    if primary then movePlayer(primary.Position); task.wait(0.3)
        for _,pr in ipairs(pm:GetDescendants()) do
            if pr:IsA("ProximityPrompt") then local at=pr.ActionText:lower()
                if at:find("tame",1,true) or at:find("catch",1,true) then fireP(pr); task.wait(0.5); break end
            end
        end
    end
    local pid=pm:GetAttribute("PetId") or pm:GetAttribute("Id")
    if pid then pcall(function() if Net.Pets and Net.Pets.TamePet then Net.Pets.TamePet:Fire(pid)
        elseif Net.Tame and Net.Tame.TamePet then Net.Tame.TamePet:Fire(pid) end end) end
end
local function buyPetSlot()
    pcall(function()
        if Net.Pets and Net.Pets.PurchaseSlot then Net.Pets.PurchaseSlot:Fire()
        elseif Net.Pets and Net.Pets.BuySlot then Net.Pets.BuySlot:Fire()
        elseif Net.PetShop and Net.PetShop.PurchaseSlot then Net.PetShop.PurchaseSlot:Fire()
        else
            for _,obj in ipairs(Wkspc:GetDescendants()) do
                if obj:IsA("Model") and obj.Name:lower():find("pet",1,true) and obj.Name:lower():find("shop",1,true) then
                    local pr=obj:FindFirstChildWhichIsA("ProximityPrompt")
                    if pr then movePlayer(obj.PrimaryPart and obj.PrimaryPart.Position or obj:GetPivot().Position); task.wait(0.3); fireP(pr); break end
                end
            end
        end
    end)
end
local function equipBestPets()
    local pf=client:FindFirstChild("Pets"); if not pf then return end
    local pets={}
    for _,p in ipairs(pf:GetChildren()) do
        if p:IsA("Model") or p:IsA("Folder") or p:IsA("Tool") then
            local ra=(p:GetAttribute("Rarity") or ""):lower(); local val=p:GetAttribute("Value") or p:GetAttribute("Power") or 1
            pets[#pets+1]={model=p,name=p.Name,value=val,rs=RarityScore[ra] or 0}
        end
    end
    table.sort(pets,function(a,b) if a.rs~=b.rs then return a.rs>b.rs end; return (a.value or 0)>(b.value or 0) end)
    pcall(function() Net.Pets.RequestUnequip:Fire() end); task.wait(0.3)
    local mx=client:GetAttribute("MaxPetSlots") or 3; local eq=0
    for _,p in ipairs(pets) do
        if eq>=mx then break end
        local pid=p.model:GetAttribute("PetId") or p.model:GetAttribute("Id") or p.model.Name
        if pid then pcall(function() if Net.Pets and Net.Pets.EquipPet then Net.Pets.EquipPet:Fire(pid)
            elseif Net.Pets and Net.Pets.RequestEquip then Net.Pets.RequestEquip:Fire(pid) end end)
            eq=eq+1; task.wait(0.1)
        end
    end
end

-- ----- pvp -----
local function whackPlayer(tp)
    if not tp then return end; local tc=tp.Character; if not tc then return end
    local shovel=findTool("shovel") or findTool("Shovel")
    if shovel and shovel.Parent~=client.Character then equipT(shovel); task.wait(0.05) end
    if shovel and shovel.Parent==client.Character then
        pcall(function() if Net.Shovel and Net.Shovel.UseShovel then
            Net.Shovel.UseShovel:Fire(tp.UserId,"","",cleanName(shovel.Name) or "Shovel",shovel) end end)
    end
end
local function shovelAura(range)
    if not PL.auth then authPlot(); if not PL.auth then return end end
    local mh=client.Character and client.Character:FindFirstChild("HumanoidRootPart"); if not mh then return end
    local shovel=findTool("shovel") or findTool("Shovel"); if not shovel then return end
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr==client then continue end; local ch=plr.Character; local h=ch and ch:FindFirstChild("HumanoidRootPart")
        if h and (h.Position-mh.Position).Magnitude<=range and (h.Position-PL.center).Magnitude<35 then
            pcall(function() if Net.Shovel and Net.Shovel.UseShovel then
                Net.Shovel.UseShovel:Fire(plr.UserId,"","",cleanName(shovel.Name) or "Shovel",shovel) end end)
            task.wait(0.05)
        end
    end
end

-- ----- misc actions -----
local function expandGarden()
    pcall(function()
        if Net.Garden and Net.Garden.Expand then Net.Garden.Expand:Fire()
        elseif Net.Plot and Net.Plot.Expand then Net.Plot.Expand:Fire()
        elseif Net.Settings and Net.Settings.ExpandGarden then Net.Settings.ExpandGarden:Fire() end
    end)
end
local function serverHop()
    pcall(function()
        local srvs={}
        local url="https://games.roblox.com/v1/games/"..tostring(game.PlaceId).."/servers/Public?limit=100&sortOrder=Asc"
        local ok,res=pcall(function() return request({Url=url,Method="GET",Headers={["Content-Type"]="application/json"}}) end)
        if ok and res and res.StatusCode==200 then
            local data=Http:JSONDecode(res.Body)
            if data and data.data then for _,s in ipairs(data.data) do if s.playing and s.playing<s.maxPlayers then srvs[#srvs+1]=s.id end end end
        end
        if #srvs>0 then TeleSvc:TeleportToPlaceInstance(game.PlaceId,srvs[math.random(#srvs)],client)
        else TeleSvc:Teleport(game.PlaceId,client) end
    end)
end
local function sendWebhook(url,msg,emb)
    if not url or url=="" then return end
    task.spawn(function() pcall(function()
        local payload={content=msg}; if emb then payload.embeds={emb} end
        local body=Http:JSONEncode(payload)
        request({Url=url,Method="POST",Headers={["Content-Type"]="application/json"},Body=body})
    end) end)
end

-- ----- esp -----
local ESP_Cache={}
local function createESP(obj,text,color)
    if ESP_Cache[obj] then local h=ESP_Cache[obj]
        if h and h.Parent then local bb=h:FindFirstChild("BB")
            if bb then local lb=bb:FindFirstChild("Label"); if lb then lb.Text=text end end
        end; return
    end
    local h=Instance.new("Folder"); h.Name="ESP_"..obj.Name
    local hl=Instance.new("Highlight"); hl.FillColor=color or Color3.fromRGB(255,255,255); hl.FillTransparency=0.7
    hl.OutlineColor=color or Color3.fromRGB(255,255,255); hl.OutlineTransparency=0; hl.Adornee=obj; hl.Parent=h
    local bb=Instance.new("BillboardGui"); bb.Name="BB"; bb.Size=UDim2.new(0,200,0,50)
    bb.StudsOffset=Vector3.new(0,3,0); bb.AlwaysOnTop=true
    bb.Adornee=obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")) or obj; bb.Parent=h
    local lb=Instance.new("TextLabel"); lb.Name="Label"; lb.Size=UDim2.new(1,0,1,0); lb.BackgroundTransparency=1
    lb.Text=text; lb.TextColor3=color or Color3.fromRGB(255,255,255); lb.TextScaled=true; lb.Font=Enum.Font.GothamBold; lb.Parent=bb
    h.Parent=Core; ESP_Cache[obj]=h
end
local function cleanESP()
    for _,h in pairs(ESP_Cache) do pcall(function() h:Destroy() end) end; ESP_Cache={}
end

-- ----- predictor hud -----
local PredHUD=Instance.new("ScreenGui"); PredHUD.Name="VA_Pred"; PredHUD.ResetOnSpawn=false; PredHUD.Parent=Core; PredHUD.Enabled=false; Track(PredHUD)
local PredCon=Instance.new("Frame"); PredCon.Name="PredCon"; PredCon.Size=UDim2.new(0,200,0,0)
PredCon.Position=UDim2.new(1,-210,0,10); PredCon.BackgroundColor3=Color3.fromRGB(16,16,20); PredCon.BackgroundTransparency=0.05
PredCon.BorderSizePixel=1; PredCon.BorderColor3=Color3.fromRGB(50,50,60); PredCon.Parent=PredHUD
Instance.new("UICorner",PredCon).CornerRadius=UDim.new(0,8)
local PredLay=Instance.new("UIListLayout"); PredLay.Parent=PredCon; PredLay.SortOrder=Enum.SortOrder.LayoutOrder
PredLay.Padding=UDim.new(0,2); PredLay.HorizontalAlignment=Enum.HorizontalAlignment.Center
local PredPad=Instance.new("UIPadding"); PredPad.Parent=PredCon
PredPad.PaddingTop=UDim.new(0,6); PredPad.PaddingBottom=UDim.new(0,6); PredPad.PaddingLeft=UDim.new(0,6); PredPad.PaddingRight=UDim.new(0,6)
PredLay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() PredCon.Size=UDim2.new(0,200,0,PredLay.AbsoluteContentSize.Y+12) end)
local function mkLabel(txt,color,order)
    local lb=Instance.new("TextLabel"); lb.Size=UDim2.new(1,0,0,14); lb.BackgroundTransparency=1
    lb.TextColor3=color or Color3.fromRGB(200,200,210); lb.Font=Enum.Font.GothamMedium; lb.TextSize=9
    lb.TextXAlignment=Enum.TextXAlignment.Left; lb.Text=txt; lb.LayoutOrder=order; lb.Parent=PredCon; return lb
end
local function mkDiv(order)
    local d=Instance.new("Frame"); d.Size=UDim2.new(1,0,0,1); d.BackgroundColor3=Color3.fromRGB(50,50,60)
    d.BorderSizePixel=0; d.LayoutOrder=order; d.Parent=PredCon
end
local PredTitle=mkLabel("\226\156\136 Versus Airlines",Color3.fromRGB(100,200,255),1); PredTitle.Font=Enum.Font.GothamBold; PredTitle.TextSize=10; mkDiv(2)
local PredNight=mkLabel("\226\152\128 Day",Color3.fromRGB(255,220,100),3)
local PredSR=mkLabel("Seeds: --",Color3.fromRGB(180,255,180),4); local PredGR=mkLabel("Gear: --",Color3.fromRGB(180,255,180),5); mkDiv(6)
local PredWL={}; for i,wt in ipairs(WTypes) do PredWL[wt.id]=mkLabel(wt.label..": --",wt.color,7+i) end
local we=7+#WTypes+1; mkDiv(we)
local PredSL={}; for i=1,6 do PredSL[i]=mkLabel("",Color3.fromRGB(160,255,160),we+i); PredSL[i].Visible=false end
local PredPT=mkLabel("Predictions:",Color3.fromRGB(255,200,100),we+8); PredPT.Font=Enum.Font.GothamBold
local PredPL={}; for i=1,4 do PredPL[i]=mkLabel("",Color3.fromRGB(200,200,140),we+8+i); PredPL[i].Visible=false end

Track(task.spawn(function() while _alive do task.wait(1.5); pcall(function()
    PredHUD.Enabled=Flags["ShowPred"]==true; if not Flags["ShowPred"] then return end
    local night=isNight(); PredNight.Text=night and "\240\159\140\153 Night" or "\226\152\128 Day"
    local su=restockUnix("SeedShop"); local gu=restockUnix("GearShop")
    PredSR.Text="Seeds: "..(su and fmt(math.max(0,su-os.time())) or "...")
    PredGR.Text="Gear: "..(gu and fmt(math.max(0,gu-os.time())) or "...")
    local weather=readWeather()
    for _,wt in ipairs(WTypes) do local w=weather[wt.id]; local lb=PredWL[wt.id]
        if w and lb then if w.playing then lb.Text=wt.label..": "..fmt(w.remaining); lb.TextColor3=wt.color
        else lb.Text=wt.label..": --"; lb.TextColor3=Color3.fromRGB(80,80,90) end end
    end
    local sd=readStock(); local shown=0
    for sn,items in pairs(sd) do for _,it in ipairs(items) do if it.count>0 and shown<6 then shown=shown+1
        local lb=PredSL[shown]; if lb then lb.Text=sn:gsub("Shop","")..": "..it.name.." x"..it.count; lb.Visible=true end end end end
    for i=shown+1,6 do if PredSL[i] then PredSL[i].Visible=false end end
    trackStock(); local ps=0
    for sn,items in pairs(sd) do for _,it in ipairs(items) do if it.count==0 and ps<4 then
        local nt,ac=predictRestock(sn,it.name); if nt then ps=ps+1; local lb=PredPL[ps]
            if lb then local rem=math.max(0,nt-os.time())
                if rem>0 then lb.Text=it.name..": ~"..fmt(rem).." (x"..ac..")" else lb.Text=it.name..": soon (x"..ac..")" end
                lb.Visible=true
            end
        end end end end
    for i=ps+1,4 do if PredPL[i] then PredPL[i].Visible=false end end; PredPT.Visible=ps>0
end) end end))

-- ----- shop overlay -----
Track(task.spawn(function() while _alive do task.wait(2); pcall(function()
    if not Flags["ShowPred"] then local pg=client:FindFirstChild("PlayerGui")
        local shop=pg and pg:FindFirstChild("SeedShop"); local frame=shop and shop:FindFirstChild("Frame")
        local panel=frame and frame:FindFirstChild("VA_SeedPanel"); if panel then panel:Destroy() end; return
    end
    local pg=client:FindFirstChild("PlayerGui"); local shop=pg and pg:FindFirstChild("SeedShop")
    local frame=shop and shop:FindFirstChild("Frame"); if not frame then return end
    local panel=frame:FindFirstChild("VA_SeedPanel")
    if not panel then
        panel=Instance.new("Frame"); panel.Name="VA_SeedPanel"; panel.Size=UDim2.new(0,200,0,120)
        panel.Position=UDim2.new(1,-210,0,10); panel.BackgroundColor3=Color3.fromRGB(16,16,20)
        panel.BackgroundTransparency=0.05; panel.BorderSizePixel=1; panel.BorderColor3=Color3.fromRGB(80,180,120); panel.Parent=frame
        Instance.new("UICorner",panel).CornerRadius=UDim.new(0,6)
        local title=Instance.new("TextLabel"); title.Name="Title"; title.Size=UDim2.new(1,-10,0,16)
        title.Position=UDim2.new(0,5,0,4); title.BackgroundTransparency=1; title.Font=Enum.Font.GothamBold
        title.TextSize=10; title.TextColor3=Color3.fromRGB(160,255,180); title.TextXAlignment=Enum.TextXAlignment.Left; title.Parent=panel
        local body=Instance.new("TextLabel"); body.Name="Body"; body.Size=UDim2.new(1,-10,1,-24)
        body.Position=UDim2.new(0,5,0,22); body.BackgroundTransparency=1; body.Font=Enum.Font.GothamMedium
        body.TextSize=9; body.TextWrapped=true; body.TextYAlignment=Enum.TextYAlignment.Top
        body.TextXAlignment=Enum.TextXAlignment.Left; body.TextColor3=Color3.fromRGB(220,220,230); body.Parent=panel
    end
    local title=panel:FindFirstChild("Title"); local body=panel:FindFirstChild("Body")
    local su=restockUnix("SeedShop"); local ss=su and math.max(0,su-os.time()) or nil
    if title then title.Text="\226\156\136 Restock: "..(ss and fmt(ss) or "...") end
    if body then local sd=readStock(); local seeds=sd["SeedShop"]
        if seeds then local lines={}; local so=0
            for _,it in ipairs(seeds) do if it.count>0 then lines[#lines+1]="\226\156\133 "..it.name.." x"..it.count else so=so+1 end end
            if so>0 then lines[#lines+1]="\n+"..so.." sold out" end; body.Text=table.concat(lines,"\n")
        end
    end
end) end end))


-- ===================================================================
-- VERSUS AIRLINES UI
-- ===================================================================
print("[GAG 2] Versus Airlines loading...")

local Library = loadstring(game:HttpGet("https://versusairlines.top/scripts/NewLibrary.lua"))()
if not Library then warn("[VA] Library failed"); return end

local UI = Library:Setup({
    Location = Core,
    OpenCloseLocation = "Bottom Right"
})

-- Link Flags to the library's internal flag table.
-- Versus Airlines stores toggle/dropdown values in Library.Flags.
-- All feature callbacks read from this table.
local Flags = Library.Flags

local function notify(title, desc, style)
    Library:createDisplayMessage(title, desc, {{ text = "OK" }}, style or "info")
end

-- ----- interval helper (Versus Airlines template) -----
-- Store connection tags in a local table instead of relying on Library:TrackConnection
-- to avoid https://versusairlines.top/developers.html API dependency for tracking
local _trackedConns = {}
local function cleanupTag(tag)
    if _trackedConns[tag] then
        for _, c in ipairs(_trackedConns[tag]) do pcall(function() c:Disconnect() end) end
        _trackedConns[tag] = nil
    end
    Library:CleanupConnectionsByTag(tag)
end
local function trackConn(tag, conn)
    if not _trackedConns[tag] then _trackedConns[tag] = {} end
    _trackedConns[tag][#_trackedConns[tag] + 1] = conn
    Library:TrackConnection(conn, tag)
end
local function interval(tag, flag, delay, cb)
    cleanupTag(tag)
    delay = math.max(tonumber(delay) or 0.1, 0.05)
    if not Flags[flag] then return end
    local last = 0; local running = false
    local conn = Run.Heartbeat:Connect(function()
        if not Flags[flag] then cleanupTag(tag); return end
        local now = os.clock()
        if running or now - last < delay then return end
        last = now; running = true
        task.spawn(function()
            local ok, err = pcall(cb)
            if not ok then warn("[interval:"..tostring(tag).."]", err) end
            task.wait(); running = false
        end)
    end)
    trackConn(tag, conn)
end

-- ----- buildToggle -----
local function buildToggle(parent, cfg)
    local tag, flag, delay, step = cfg.tag or cfg.flagName, cfg.flagName, cfg.delay or 0.5, cfg.step
    parent:createToggle({
        Name = cfg.Name,
        flagName = flag,
        Flag = cfg.Flag or false,
        Callback = function()
            cleanupTag(tag)
            if not Flags[flag] then return end
            local actualDelay = Flags["LegitMode"]
                and (delay * (0.6 + math.random() * 0.8) + math.random(0.05, 0.25))
                or delay
            interval(tag, flag, actualDelay, step)
        end
    })
end

-- ----- tabs -----
local HomeTab   = UI:CreateSection("Home")
local FarmTab   = UI:CreateSection("Farm")
local StealTab  = UI:CreateSection("Steal")
local SearchTab = UI:CreateSection("Search")
local ShopTab   = UI:CreateSection("Shop")
local PetTab    = UI:CreateSection("Pets")
local PredTab   = UI:CreateSection("Predictors")
local PlayerTab = UI:CreateSection("Player")
local VisualsTab= UI:CreateSection("Visuals")
local MiscTab   = UI:CreateSection("Misc")

-- HOME
HomeTab:createLabel({Name = "Versus Airlines | GAG 2", Special = true})
HomeTab:createLabel({Name = "v2.0 — Fixed", Center = true})

HomeTab:createLabel({Name = "Transport", Special = true})
HomeTab:createDropdown({
    Name = "Movement Mode", flagName = "TransportMode",
    List = {"Tween", "Teleport"}, Flag = "Tween",
    Description = "Tween is safer. Teleport is fast but may be detected."
})

HomeTab:createLabel({Name = "Plot", Special = true})
HomeTab:createDropdown({
    Name = "Placement Position", flagName = "PlacingMode",
    List = {"Row Fill", "At Player", "Random", "At Mouse"}, Flag = "Row Fill",
    Description = "Where to place seeds and sprinklers."
})

HomeTab:createButton({Name = "Refresh Plot", Callback = function()
    PL.auth = false; PL.lastAuth = 0; authPlot()
    if PL.auth then notify("Plot", "Plot #"..tostring(PL.plotId or "?").." — "..#PL.gridNodes.." nodes", "info")
    else notify("Plot", "No plot found. Stand in your garden.", "warning") end
end})

HomeTab:createButton({Name = "Show Status", Callback = function()
    authPlot(); local ru = restockUnix("SeedShop")
    notify("Status", string.format(
        "Plot: %s\nSeeds: %d | Gears: %d\nNight: %s\nRestock: %s",
        PL.auth and ("#"..tostring(PL.plotId or "?")) or "none",
        #GD.seeds, #GD.gears,
        isNight() and "yes" or "no",
        ru and fmt(math.max(0, ru - os.time())) or "syncing"
    ), "info")
end})

HomeTab:createButton({Name = "Rejoin Server", Callback = function()
    pcall(function() TeleSvc:Teleport(game.PlaceId, client) end)
end})

-- FARM
FarmTab:createLabel({Name = "Planting", Special = true})
FarmTab:createDropdown({Name = "Mode", flagName = "PS_type", List = {"None", "All Backpack", "Selected"}, Flag = "None"})
FarmTab:createDropdown({Name = "Select Seeds", flagName = "PS_list", multi = true, List = GD.seeds})
FarmTab:createDropdown({Name = "Priority", flagName = "PP", List = {"Manual Order", "Highest Value"}})

buildToggle(FarmTab, {
    Name = "Auto Plant", flagName = "AP", tag = "AP", delay = 0.35,
    step = function()
        authPlot(); local st = selMode("PS_type", "None")
        if st == "None" then return end; geofence("p")
        local seeds = st == "All Backpack" and bpSeeds() or toList(Flags["PS_list"])
        if #seeds == 0 then return end
        if selMode("PP", "Manual Order") == "Highest Value" then
            local sc = {}
            for _, n in ipairs(seeds) do
                local t = findTool(n); sc[n] = t and (t:GetAttribute("Value") or t:GetAttribute("Price") or 1) or 1
            end
            table.sort(seeds, function(a, b) return (sc[a] or 0) > (sc[b] or 0) end)
        end
        for _, sn in ipairs(seeds) do
            if not Flags["AP"] then break end
            local pos = placePos(2.9); if pos then plant(sn, pos); task.wait(0.08) end
        end
    end
})

FarmTab:createLabel({Name = "Collection", Special = true})
FarmTab:createDropdown({Name = "Filter", flagName = "AH_type", List = {"None", "All", "Selected", "Blacklist"}, Flag = "None"})
FarmTab:createDropdown({Name = "Fruits", flagName = "AH_list", multi = true, List = GD.seeds})
FarmTab:createDropdown({Name = "Blacklist", flagName = "AH_blist", multi = true, List = GD.seeds})

buildToggle(FarmTab, {
    Name = "Auto Harvest", flagName = "AH", tag = "AH", delay = 0.18,
    step = function()
        local st = selMode("AH_type", "None"); if st == "None" then return end
        authPlot(); geofence("c")
        local inc, bl
        if st == "Selected" then inc = toList(Flags["AH_list"])
        elseif st == "Blacklist" then bl = toList(Flags["AH_blist"]) end
        local cands = getCandidates(120, inc, nil, nil, true, bl)
        for _, c in ipairs(cands) do
            if not Flags["AH"] then break end
            movePlayer(c.model:GetPivot().Position); task.wait(0.08)
            pcall(function() fireP(c.model:FindFirstChildWhichIsA("ProximityPrompt")) end)
            if c.plantId then harvest(c.plantId, c.fruitId) end; task.wait(0.05)
        end
    end
})

FarmTab:createLabel({Name = "Selling", Special = true})
FarmTab:createButton({Name = "Sell All Now", Callback = function()
    sellAll(); notify("Sell", "SellAll fired", "info")
end})

FarmTab:createLabel({Name = "Sprinklers", Special = true})
FarmTab:createDropdown({Name = "Sprinkler", flagName = "SP_list", multi = true, List = GD.sprinklers or {}})

buildToggle(FarmTab, {
    Name = "Auto Sprinkler", flagName = "SP", tag = "SP", delay = 0.35,
    step = function()
        authPlot(); geofence("p")
        local sel = toList(Flags["SP_list"]); local spr = #sel > 0 and sel or bpSprinklers()
        for _, n in ipairs(spr) do
            if not Flags["SP"] then break end
            local pos = placePos(4.0); if pos then placeSpr(n, pos); task.wait(0.08) end
        end
    end
})

FarmTab:createLabel({Name = "Shovel", Special = true})
FarmTab:createDropdown({Name = "Mode", flagName = "RM_type", List = {"None", "All", "Selected", "Blacklist"}, Flag = "None"})
FarmTab:createDropdown({Name = "Fruit", flagName = "RM_list", multi = true, List = GD.seeds})

buildToggle(FarmTab, {
    Name = "Auto Shovel", flagName = "RM", tag = "RM", delay = 0.18,
    step = function()
        local st = selMode("RM_type", "None"); if st == "None" then return end
        authPlot(); if not PL.plantsFolder then return end
        local inc, bl
        if st == "Selected" then inc = toList(Flags["RM_list"])
        elseif st == "Blacklist" then bl = toList(Flags["RM_list"]) end
        local cands = getCandidates(300, inc, nil, nil, true, bl)
        local shovel = findTool("shovel") or findTool("Shovel")
        for _, c in ipairs(cands) do
            if not Flags["RM"] then break end
            if c.plantId then
                pcall(function() Net.Shovel.UseShovel:Fire(c.plantId, c.fruitId or "", cleanName(shovel and shovel.Name or ""), shovel) end)
                task.wait(0.012)
            end
        end
    end
})

FarmTab:createLabel({Name = "Trowel", Special = true})
FarmTab:createSlider({Name = "Trowel Spacing", flagName = "TR_spacing", value = 3, minValue = 1, maxValue = 10})

buildToggle(FarmTab, {
    Name = "Auto Replant (Trowel)", flagName = "TR", tag = "TR", delay = 0.5,
    step = function()
        authPlot(); if not PL.plantsFolder then return end
        local sp = Flags["TR_spacing"] or 3
        for _, p in ipairs(PL.plantsFolder:GetChildren()) do
            if not Flags["TR"] then break end
            if not p:IsA("Model") or not p.PrimaryPart then continue end
            local pid = p:GetAttribute("PlantId"); if not pid then continue end
            local cp = p:GetPivot().Position; local tp = placePos(sp)
            if tp and (cp - tp).Magnitude > 2 then movePlant(pid, tp, 0); task.wait(0.15) end
        end
    end
})

FarmTab:createLabel({Name = "Collect Seeds", Special = true})
FarmTab:createSlider({Name = "Pickup Range", flagName = "PickupRange", value = 50, minValue = 10, maxValue = 200})

buildToggle(FarmTab, {
    Name = "Auto Collect Ground Seeds", flagName = "ACS_all", tag = "ACS_all", delay = 1.0,
    step = function()
        for _, it in ipairs(findGround("seeds")) do
            if not Flags["ACS_all"] then break end
            movePlayer(it.position); task.wait(0.15); fireP(it.prompt); task.wait(0.1)
        end
    end
})

buildToggle(FarmTab, {
    Name = "Auto Collect Gold Seeds", flagName = "ACS_gold", tag = "ACS_gold", delay = 0.5,
    step = function()
        for _, it in ipairs(findGround("seeds")) do
            if not Flags["ACS_gold"] then break end
            if it.name:lower():find("gold", 1, true) then
                movePlayer(it.position); task.wait(0.15); fireP(it.prompt); task.wait(0.1)
            end
        end
    end
})

buildToggle(FarmTab, {
    Name = "Auto Collect Rainbow Seeds", flagName = "ACS_rainbow", tag = "ACS_rainbow", delay = 0.5,
    step = function()
        for _, it in ipairs(findGround("seeds")) do
            if not Flags["ACS_rainbow"] then break end
            if it.name:lower():find("rainbow", 1, true) then
                movePlayer(it.position); task.wait(0.15); fireP(it.prompt); task.wait(0.1)
            end
        end
    end
})

-- STEAL
StealTab:createLabel({Name = "Night Stealing", Special = true})
StealTab:createDropdown({Name = "Rarities", flagName = "ST_rar", multi = true, List = RTS})
StealTab:createDropdown({Name = "Fruits", flagName = "ST_names", multi = true, List = GD.seeds})
StealTab:createDropdown({Name = "Mut Whitelist", flagName = "ST_mw", multi = true, List = MTS})
StealTab:createDropdown({Name = "Mut Blacklist", flagName = "ST_mb", multi = true, List = MTS})
StealTab:createSlider({Name = "Min Value", flagName = "ST_minKG", value = 0, minValue = 0, maxValue = 100000})
StealTab:createSlider({Name = "Carry Limit", flagName = "ST_carry", value = 50, minValue = 1, maxValue = 200})
StealTab:createDropdown({Name = "Priority", flagName = "ST_prio", List = {"Value", "Closest", "Random"}})
StealTab:createToggle({Name = "Skip Friends", flagName = "ST_skipF", Flag = false})
StealTab:createToggle({Name = "Avoid Owners", flagName = "ST_avoidO", Flag = false})

buildToggle(StealTab, {
    Name = "Auto Steal", flagName = "ST", tag = "ST", delay = 0.65,
    step = function()
        if not isNight() then return end
        local sr = toList(Flags["ST_rar"]); local sn = toList(Flags["ST_names"])
        local mw = toList(Flags["ST_mw"]); local mb = toList(Flags["ST_mb"])
        local minS = Flags["ST_minKG"] or 0; local carry = Flags["ST_carry"] or 50
        local prio = selMode("ST_prio", "Value")
        local cands = getCandidates(350, sn, mw, sr, false)
        local filt = {}
        for _, c in ipairs(cands) do
            if c.model and not c.isOwned then
                local mu = tostring(c.model:GetAttribute("Mutation") or ""):lower()
                local blocked = false
                for _, b in ipairs(mb) do if mu == tostring(b):lower() then blocked = true; break end end
                if not blocked and (minS <= 0 or c.score >= minS) then filt[#filt + 1] = c end
            end
        end
        cands = filt
        if prio == "Closest" then table.sort(cands, function(a, b) return a.distance < b.distance end)
        elseif prio == "Random" then
            for i = #cands, 2, -1 do local j = math.random(i); cands[i], cands[j] = cands[j], cands[i] end
        else table.sort(cands, function(a, b) return a.score > b.score end) end
        local stolen = 0
        for _, c in ipairs(cands) do
            if not Flags["ST"] or stolen >= carry then break end
            local plot = c.model
            while plot and plot.Parent and plot.Parent ~= Wkspc and not plotOwner(plot) do plot = plot.Parent end
            local oid = plot and plotOwner(plot); if not oid or oid == client.UserId then continue end
            if Flags["ST_skipF"] then
                local ok, isf = pcall(function() return client:IsFriendsWith(oid) end)
                if ok and isf then continue end
            end
            if Flags["ST_avoidO"] then
                local owner = Players:GetPlayerByUserId(oid)
                if owner and owner.Character and owner.Character:FindFirstChild("HumanoidRootPart") then
                    if (c.model:GetPivot().Position - owner.Character.HumanoidRootPart.Position).Magnitude < 20 then continue end
                end
            end
            movePlayer(c.model:GetPivot().Position); task.wait(0.15)
            beginSteal(oid, c.plantId, c.fruitId); task.wait(0.08)
            completeSteal(); task.wait(0.05)
            if c.plantId then task.spawn(harvest, c.plantId, c.fruitId) end
            stolen = stolen + 1; task.wait(0.2)
        end
    end
})

-- SEARCH
SearchTab:createLabel({Name = "Fruit Searcher", Special = true})
SearchTab:createDropdown({Name = "Fruits", flagName = "SR_names", multi = true, List = GD.seeds})
SearchTab:createDropdown({Name = "Rarity", flagName = "SR_rar", multi = true, List = RTS})
SearchTab:createDropdown({Name = "Mutation", flagName = "SR_mut", multi = true, List = MTS})
SearchTab:createSlider({Name = "Min Value", flagName = "SR_minVal", value = 0, minValue = 0, maxValue = 100000})
SearchTab:createToggle({Name = "Include Own Garden", flagName = "SR_own", Flag = false})
SearchTab:createSlider({Name = "Results", flagName = "SR_count", value = 10, minValue = 1, maxValue = 50})

SearchTab:createButton({Name = "Search Now", Callback = function()
    local r = searchFruits(
        toList(Flags["SR_names"]), toList(Flags["SR_mut"]), toList(Flags["SR_rar"]),
        Flags["SR_minVal"] or 0, Flags["SR_own"] or false
    )
    local ct = Flags["SR_count"] or 10; local lines = {"Found " .. #r .. " fruits"}
    for i = 1, math.min(ct, #r) do
        local rr = r[i]
        lines[#lines + 1] = string.format("%s | %.0f | Owner: %s", rr.model.Name, rr.score, rr.isOwned and "YOU" or tostring(rr.plotOwner or "?"))
    end
    notify("Search", table.concat(lines, "\n"), "info")
end})

SearchTab:createButton({Name = "Teleport to Best", Callback = function()
    local r = searchFruits(
        toList(Flags["SR_names"]), toList(Flags["SR_mut"]), toList(Flags["SR_rar"]),
        Flags["SR_minVal"] or 0, Flags["SR_own"] or false
    )
    if #r > 0 then movePlayer(r[1].position); notify("Search", "Teleported to " .. r[1].model.Name, "info")
    else notify("Search", "No results found", "warning") end
end})

-- SHOP
ShopTab:createLabel({Name = "Seeds", Special = true})
ShopTab:createDropdown({Name = "Select Seeds", flagName = "SH_seeds", multi = true, List = GD.seeds})

buildToggle(ShopTab, {
    Name = "Auto Buy Selected Seeds", flagName = "SH_bs", tag = "SH_bs", delay = 1.0,
    step = function()
        for _, n in ipairs(toList(Flags["SH_seeds"])) do
            if not Flags["SH_bs"] then break end; buySeed(n); task.wait(0.15)
        end
    end
})

buildToggle(ShopTab, {
    Name = "Buy All In-Stock Seeds", flagName = "SH_bs_all", tag = "SH_bs_all", delay = 1.0,
    step = function()
        local sd = readStock(); local seeds = sd["SeedShop"]; if not seeds then return end
        for _, it in ipairs(seeds) do
            if not Flags["SH_bs_all"] then break end
            if it.count > 0 then buySeed(it.name); task.wait(0.15) end
        end
    end
})

ShopTab:createLabel({Name = "Gear", Special = true})
ShopTab:createDropdown({Name = "Select Gear", flagName = "SH_gears", multi = true, List = GD.gears})

buildToggle(ShopTab, {
    Name = "Auto Buy Selected Gear", flagName = "SH_bg", tag = "SH_bg", delay = 1.0,
    step = function()
        for _, n in ipairs(toList(Flags["SH_gears"])) do
            if not Flags["SH_bg"] then break end; buyGear(n); task.wait(0.15)
        end
    end
})

ShopTab:createLabel({Name = "Crates", Special = true})
ShopTab:createDropdown({Name = "Select Crate", flagName = "SH_crates", multi = true, List = GD.crates})

buildToggle(ShopTab, {
    Name = "Auto Buy Selected Crate", flagName = "SH_bp", tag = "SH_bp", delay = 1.0,
    step = function()
        for _, n in ipairs(toList(Flags["SH_crates"])) do
            if not Flags["SH_bp"] then break end; buyCrate(n); task.wait(0.15)
        end
    end
})

ShopTab:createLabel({Name = "Open", Special = true})

buildToggle(ShopTab, {
    Name = "Auto Open Crates", flagName = "SH_oc", tag = "SH_oc", delay = 2.0,
    step = function()
        local bp = client:FindFirstChild("Backpack"); if not bp then return end
        for _, t in ipairs(bp:GetChildren()) do
            if not Flags["SH_oc"] then break end
            if t:IsA("Tool") and t.Name:lower():find("crate", 1, true) then openCrate(t.Name); task.wait(0.5) end
        end
    end
})

buildToggle(ShopTab, {
    Name = "Auto Open Eggs", flagName = "SH_oe", tag = "SH_oe", delay = 2.0,
    step = function()
        local bp = client:FindFirstChild("Backpack"); if not bp then return end
        for _, t in ipairs(bp:GetChildren()) do
            if not Flags["SH_oe"] then break end
            if t:IsA("Tool") and t.Name:lower():find("egg", 1, true) then openEgg(t.Name); task.wait(0.5) end
        end
    end
})

ShopTab:createLabel({Name = "Stock", Special = true})
ShopTab:createButton({Name = "Check Seed Stock", Callback = function()
    local sd = readStock(); local seeds = sd["SeedShop"]
    if not seeds then notify("Stock", "No data", "warning"); return end
    local lines = {}; local ru = restockUnix("SeedShop")
    lines[#lines + 1] = "Restock: " .. (ru and fmt(math.max(0, ru - os.time())) or "?")
    for _, it in ipairs(seeds) do
        lines[#lines + 1] = it.name .. ": " .. (it.count > 0 and ("x" .. it.count) or "SOLD OUT")
    end
    notify("Seed Stock", table.concat(lines, "\n"), "info")
end})

ShopTab:createButton({Name = "Check Gear Stock", Callback = function()
    local sd = readStock(); local gears = sd["GearShop"]
    if not gears then notify("Stock", "No data", "warning"); return end
    local lines = {}
    for _, it in ipairs(gears) do
        lines[#lines + 1] = it.name .. ": " .. (it.count > 0 and ("x" .. it.count) or "SOLD OUT")
    end
    notify("Gear Stock", table.concat(lines, "\n"), "info")
end})

-- PETS
PetTab:createLabel({Name = "Equip", Special = true})
PetTab:createButton({Name = "Equip Best Pets", Callback = function()
    equipBestPets(); notify("Pets", "Equipped best pets", "info")
end})
PetTab:createButton({Name = "Unequip All Pets", Callback = function()
    pcall(function() Net.Pets.RequestUnequip:Fire() end); notify("Pets", "Unequipped all pets", "info")
end})

buildToggle(PetTab, {
    Name = "Auto Equip Best Pets", flagName = "AutoEquipPets", tag = "AutoEquipPets", delay = 10.0,
    step = function() equipBestPets() end
})

PetTab:createLabel({Name = "Taming", Special = true})
PetTab:createSlider({Name = "Tame Range", flagName = "TameRange", value = 50, minValue = 10, maxValue = 200})

buildToggle(PetTab, {
    Name = "Auto Tame Wild Pets", flagName = "AutoTame", tag = "AutoTame", delay = 2.0,
    step = function()
        local range = Flags["TameRange"] or 50
        local hrp = client.Character and client.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        for _, obj in ipairs(Wkspc:GetDescendants()) do
            if not Flags["AutoTame"] then break end
            if obj:IsA("Model") and obj:GetAttribute("Wild") == true then
                local pr = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                if pr and (pr.Position - hrp.Position).Magnitude <= range then
                    tameWildPet(obj); task.wait(1)
                end
            end
        end
    end
})

PetTab:createLabel({Name = "Slots", Special = true})
PetTab:createButton({Name = "Buy Pet Slot", Callback = function()
    buyPetSlot(); notify("Pets", "Pet slot purchase requested", "info")
end})

buildToggle(PetTab, {
    Name = "Auto Buy Pet Slots", flagName = "AutoPetSlots", tag = "AutoPetSlots", delay = 5.0,
    step = function() buyPetSlot() end
})

-- PREDICTORS
PredTab:createLabel({Name = "HUD", Special = true})
PredTab:createToggle({Name = "Show Predictor HUD", flagName = "ShowPred", Flag = false})

PredTab:createLabel({Name = "Weather", Special = true})
PredTab:createButton({Name = "Check Weather", Callback = function()
    local weather = readWeather(); local lines = {}
    for _, wt in ipairs(WTypes) do
        local w = weather[wt.id]
        if w then
            if w.playing then
                lines[#lines + 1] = wt.label .. ": ACTIVE (" .. fmt(w.remaining) .. ")"
                if #w.mutations > 0 then lines[#lines + 1] = "  -> " .. table.concat(w.mutations, ", ") end
            else lines[#lines + 1] = wt.label .. ": inactive" end
        end
    end
    notify("Weather", table.concat(lines, "\n"), "info")
end})

PredTab:createButton({Name = "Active Mutations", Callback = function()
    local weather = readWeather(); local active = {}
    for _, wt in ipairs(WTypes) do
        local w = weather[wt.id]
        if w and w.playing and #w.mutations > 0 then
            for _, mut in ipairs(w.mutations) do
                active[#active + 1] = mut .. " (" .. wt.label .. ", " .. fmt(w.remaining) .. ")"
            end
        end
    end
    notify("Mutations", #active > 0 and table.concat(active, "\n") or "No weather mutations active.", #active > 0 and "info" or "warning")
end})

PredTab:createLabel({Name = "Stock Predictions", Special = true})
PredTab:createButton({Name = "Show Predictions", Callback = function()
    local sd = readStock(); local lines = {}
    for sn, items in pairs(sd) do
        for _, it in ipairs(items) do
            if it.count == 0 then
                local nt, ac = predictRestock(sn, it.name)
                if nt then
                    local rem = math.max(0, nt - os.time())
                    lines[#lines + 1] = it.name .. ": ~" .. fmt(rem) .. " (x" .. ac .. ")"
                else lines[#lines + 1] = it.name .. ": no data yet" end
            end
        end
    end
    notify("Predictions", #lines > 0 and table.concat(lines, "\n") or "No prediction data yet. Need 2+ restock cycles.", "info")
end})

PredTab:createLabel({Name = "Auto-Buy Restocked", Special = true})
PredTab:createDropdown({Name = "Target Seeds", flagName = "PredBuySeeds", multi = true, List = GD.seeds})

buildToggle(PredTab, {
    Name = "Buy When Restocked", flagName = "PredBuy", tag = "PredBuy", delay = 2.0,
    step = function()
        local targets = toList(Flags["PredBuySeeds"]); if #targets == 0 then return end
        local sd = readStock(); local seeds = sd["SeedShop"]; if not seeds then return end
        local sm = {}; for _, it in ipairs(seeds) do sm[it.name] = it.count end
        for _, n in ipairs(targets) do
            if not Flags["PredBuy"] then break end
            if (sm[n] or 0) > 0 then buySeed(n); task.wait(0.15) end
        end
    end
})

-- PLAYER
PlayerTab:createLabel({Name = "Movement", Special = true})
PlayerTab:createSlider({Name = "Walk Speed", flagName = "WalkSpeed", value = 16, minValue = 16, maxValue = 200})
PlayerTab:createSlider({Name = "Jump Power", flagName = "JumpPower", value = 50, minValue = 50, maxValue = 300})

buildToggle(PlayerTab, {
    Name = "Auto Walk Speed", flagName = "ApplyWalkSpeed", tag = "ApplyWalkSpeed", delay = 1.0, Flag = false,
    step = function()
        local s = Flags["WalkSpeed"] or 16
        local hum = client.Character and client.Character:FindFirstChildOfClass("Humanoid")
        if hum and hum.WalkSpeed ~= s then hum.WalkSpeed = s end
    end
})

buildToggle(PlayerTab, {
    Name = "Auto Jump Power", flagName = "ApplyJumpPower", tag = "ApplyJumpPower", delay = 1.0, Flag = false,
    step = function()
        local p = Flags["JumpPower"] or 50
        local hum = client.Character and client.Character:FindFirstChildOfClass("Humanoid")
        if hum and hum.JumpPower ~= p then hum.JumpPower = p end
    end
})

PlayerTab:createLabel({Name = "Flight", Special = true})
PlayerTab:createSlider({Name = "Fly Speed", flagName = "FlySpeed", value = 50, minValue = 10, maxValue = 200})

buildToggle(PlayerTab, {
    Name = "Fly", flagName = "Fly", tag = "Fly", delay = 0.05,
    step = function()
        local s = Flags["FlySpeed"] or 50
        local hrp = client.Character and client.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local hum = client.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = true end
        local dir = Vector3.zero
        if UIS:IsKeyDown(Enum.KeyCode.W) then dir = dir + Wkspc.CurrentCamera.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then dir = dir - Wkspc.CurrentCamera.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then dir = dir - Wkspc.CurrentCamera.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then dir = dir + Wkspc.CurrentCamera.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0, 1, 0) end
        if dir.Magnitude > 0 then hrp.Velocity = dir.Unit * s end
    end
})

-- VISUALS
VisualsTab:createLabel({Name = "ESP", Special = true})
VisualsTab:createToggle({Name = "Show ESP", flagName = "ShowESP", Flag = false})

buildToggle(VisualsTab, {
    Name = "Fruit ESP", flagName = "FruitESP", tag = "FruitESP", delay = 2.0,
    step = function()
        if not Flags["ShowESP"] then return end
        local r = searchFruits(nil, nil, {"Legendary", "Mythic", "Epic"}, 0, false)
        for i = 1, math.min(15, #r) do
            local rr = r[i]
            local txt = rr.model.Name .. " | " .. string.format("%.0f", rr.score)
            local clr = (RarityScore[(rr.model:GetAttribute("Rarity") or ""):lower()] or 1) >= 6
                and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(255, 200, 50)
            createESP(rr.model, txt, clr)
        end
    end
})

VisualsTab:createButton({Name = "Clear ESP", Callback = function()
    cleanESP(); notify("ESP", "Cleared", "info")
end})

VisualsTab:createLabel({Name = "Fullbright", Special = true})
VisualsTab:createToggle({Name = "Fullbright", flagName = "Fullbright", Flag = false, Callback = function(enabled)
    if enabled then
        Light.Ambient = Color3.fromRGB(255, 255, 255)
        Light.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        Light.Brightness = 4; Light.ClockTime = 14; Light.FogEnd = 100000; Light.GlobalShadows = false
    else
        Light.Ambient = Color3.fromRGB(0, 0, 0)
        Light.OutdoorAmbient = Color3.fromRGB(0, 0, 0)
        Light.Brightness = 3; Light.GlobalShadows = true
    end
end})

-- MISC
MiscTab:createLabel({Name = "Safety", Special = true})
MiscTab:createToggle({Name = "Humanized Mode", flagName = "LegitMode", Flag = true, Description = "Adds randomized delays to all actions."})

buildToggle(MiscTab, {
    Name = "Anti Knockback", flagName = "AntiKB", tag = "AntiKB", delay = 0.3,
    step = function()
        local root = client.Character and client.Character:FindFirstChild("HumanoidRootPart")
        if root and (root.AssemblyLinearVelocity.Magnitude > 250 or root.AssemblyAngularVelocity.Magnitude > 50) then
            root.AssemblyLinearVelocity = Vector3.zero; root.AssemblyAngularVelocity = Vector3.zero
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
        for _, pp in ipairs(Wkspc:GetDescendants()) do
            if pp:IsA("ProximityPrompt") then pp.HoldDuration = 0 end
        end
    end
})

buildToggle(MiscTab, {
    Name = "Bypass AFK Popup", flagName = "NoPause", tag = "NoPause", delay = 1.0,
    step = function()
        local pg = client:FindFirstChild("PlayerGui"); if not pg then return end
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
        authPlot(); if not PL.plantsFolder then return end
        for _, p in ipairs(PL.plantsFolder:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end
})

MiscTab:createLabel({Name = "Codes", Special = true})
MiscTab:createInputBox({Name = "Code", flagName = "CodeInput", Flag = ""})
MiscTab:createButton({Name = "Redeem Code", Callback = function()
    local c = Flags["CodeInput"]; if c and c ~= "" then submitCode(c); notify("Code", "Submitted: " .. c, "info") end
end})

MiscTab:createLabel({Name = "PvP", Special = true})
MiscTab:createSlider({Name = "Shovel Aura Range", flagName = "ShovelRange", value = 15, minValue = 5, maxValue = 50})

buildToggle(MiscTab, {
    Name = "Anti Steal (Whack Thieves)", flagName = "AntiSteal", tag = "AntiSteal", delay = 0.5,
    step = function()
        authPlot(); if not PL.auth then return end
        local mh = client.Character and client.Character:FindFirstChild("HumanoidRootPart")
        if not mh then return end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == client then continue end
            local ch = plr.Character; local h = ch and ch:FindFirstChild("HumanoidRootPart")
            if h and (h.Position - PL.center).Magnitude < 30 then
                if plr:GetAttribute("IsStealingFruit") or plr:GetAttribute("CarryingStolenFruit") then
                    whackPlayer(plr); task.wait(0.2)
                end
            end
        end
    end
})

buildToggle(MiscTab, {
    Name = "Shovel Aura", flagName = "ShovelAura", tag = "ShovelAura", delay = 0.3,
    step = function()
        local range = Flags["ShovelRange"] or 15; shovelAura(range)
    end
})

MiscTab:createLabel({Name = "Garden", Special = true})
MiscTab:createButton({Name = "Expand Garden", Callback = function()
    expandGarden(); notify("Garden", "Expand request fired", "info")
end})

buildToggle(MiscTab, {
    Name = "Auto Expand Garden", flagName = "AutoExpand", tag = "AutoExpand", delay = 5.0,
    step = function() expandGarden() end
})

MiscTab:createLabel({Name = "Performance", Special = true})
MiscTab:createToggle({Name = "White Screen", flagName = "WhiteScreen", Flag = false, Callback = function(enabled)
    Run:Set3dRenderingEnabled(not enabled)
end})

MiscTab:createToggle({Name = "Low Graphics", flagName = "LowGraphics", Flag = false, Callback = function(enabled)
    if enabled then
        Light.GlobalShadows = false; Light.FogEnd = 100000; Light.Brightness = 0
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        for _, obj in ipairs(Wkspc:GetDescendants()) do
            if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then obj.Enabled = false end
        end
    else
        Light.GlobalShadows = true; Light.Brightness = 3
        settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
    end
end})

MiscTab:createLabel({Name = "Server", Special = true})
MiscTab:createButton({Name = "Server Hop", Callback = function() serverHop() end})
MiscTab:createButton({Name = "Copy Game Link", Callback = function()
    local link = "https://www.roblox.com/games/" .. tostring(game.PlaceId)
    pcall(function() setclipboard(link) end); notify("Link", link, "info")
end})

MiscTab:createLabel({Name = "Webhook", Special = true})
MiscTab:createInputBox({Name = "Webhook URL", flagName = "WebhookURL", Flag = ""})
MiscTab:createInputBox({Name = "Ping ID", flagName = "WebhookPing", Flag = ""})
MiscTab:createToggle({Name = "Rare Fruit Webhook", flagName = "WH_Rare", Flag = false})
MiscTab:createDropdown({Name = "Min Rarity", flagName = "WH_Rarity", List = {"Legendary", "Mythic", "Rainbow", "Gold"}})
MiscTab:createToggle({Name = "Steal Webhook", flagName = "WH_Steal", Flag = false})
MiscTab:createToggle({Name = "Backpack Full Webhook", flagName = "WH_Full", Flag = false})
MiscTab:createButton({Name = "Test Webhook", Callback = function()
    local url = Flags["WebhookURL"]; if not url or url == "" then notify("Webhook", "Enter a URL first", "warning"); return end
    local content = "Versus Airlines | GAG 2 test"
    local ping = Flags["WebhookPing"]; if ping and ping ~= "" then content = ping .. " " .. content end
    sendWebhook(url, content); notify("Webhook", "Test sent", "info")
end})

-- ----- lifecycle -----
Track(Players.PlayerRemoving:Connect(function(l) if l == client then if _G.VA_Unload then pcall(_G.VA_Unload) end end end))
Track(client.CharacterAdded:Connect(function(char)
    local hum = char:WaitForChild("Humanoid", 5)
    if hum then hum.Died:Connect(function() task.wait(2) end) end
end))
Track(task.spawn(function() while _alive do task.wait(120); pcall(function()
    local stale = 0; for obj in pairs(ESP_Cache) do if not obj or not obj.Parent then stale = stale + 1 end end
    if stale > 50 then cleanESP() end
end) end end))
Track(Run.Heartbeat:Connect(function() if os.clock() - PL.lastAuth > 30 then pcall(authPlot) end end))
Track(task.spawn(function() while _alive do task.wait(300); pcall(function()
    local espC = 0; for _ in pairs(ESP_Cache) do espC = espC + 1 end
    if espC > 100 then cleanESP() end; collectgarbage("collect")
end) end end))

-- Webhooks
Track(task.spawn(function() while _alive do task.wait(15); pcall(function()
    if not Flags["WH_Rare"] then return end; local url = Flags["WebhookURL"]; if not url or url == "" then return end
    authPlot(); if not PL.plantsFolder then return end
    local minR = selMode("WH_Rarity", "Legendary")
    local minS = ({Legendary = 6, Mythic = 7, Rainbow = 10, Gold = 10})[minR] or 6
    local ping = Flags["WebhookPing"]
    for _, p in ipairs(PL.plantsFolder:GetChildren()) do
        if p:IsA("Model") then
            local ra = tostring(p:GetAttribute("Rarity") or ""):lower()
            if (RarityScore[ra] or 0) >= minS then
                local msg = string.format("Rare: %s | %s | value %.0f", p.Name, ra, plantValue(p))
                if ping and ping ~= "" then msg = ping .. " " .. msg end
                sendWebhook(url, msg); break
            end
        end
    end
end) end end))

Track(task.spawn(function() while _alive do task.wait(10); pcall(function()
    if not Flags["WH_Full"] then return end; if not bpFull() then return end
    local url = Flags["WebhookURL"]; if not url or url == "" then return end
    local ping = Flags["WebhookPing"]; local msg = "Backpack is full!"
    if ping and ping ~= "" then msg = ping .. " " .. msg end
    sendWebhook(url, msg); task.wait(60)
end) end end))

Track(task.spawn(function() while _alive do task.wait(5); pcall(function()
    if not Flags["WH_Steal"] then return end; local url = Flags["WebhookURL"]; if not url or url == "" then return end
    if not isNight() then return end; authPlot(); if not PL.auth then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == client then continue end
        local ch = plr.Character; local h = ch and ch:FindFirstChild("HumanoidRootPart")
        if h and (h.Position - PL.center).Magnitude < 30 then
            if plr:GetAttribute("IsStealingFruit") or plr:GetAttribute("CarryingStolenFruit") then
                local ping = Flags["WebhookPing"]
                local msg = string.format("Thief: %s (%d)", plr.Name, plr.UserId)
                if ping and ping ~= "" then msg = ping .. " " .. msg end
                sendWebhook(url, msg); task.wait(10); break
            end
        end
    end
end) end end))

Track(Players.LocalPlayer.OnTeleport:Connect(function(state)
    if state == Enum.TeleportState.Started then print("[GAG 2] Teleport detected")
    elseif state == Enum.TeleportState.Failed then
        print("[GAG 2] Teleport failed - retrying..."); task.wait(5)
        pcall(function() TeleSvc:Teleport(game.PlaceId, client) end)
    end
end))

task.spawn(function() task.wait(2); pcall(function() authPlot()
    if PL.auth then print(string.format("[GAG 2] Plot #%s authenticated. %d grid nodes.", tostring(PL.plotId), #PL.gridNodes)) end
end) end)

notify("Versus Airlines", "GAG 2 loaded\n" .. #GD.seeds .. " seeds | " .. #GD.gears .. " gears | " .. #GD.crates .. " crates", "info")
print("[GAG 2] Versus Airlines ready")

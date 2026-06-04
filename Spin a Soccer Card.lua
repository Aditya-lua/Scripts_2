-- // SSC Elite Farm
-- // Dev :- Aditya
-- // Owner :- Cammy

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local MPS = game:GetService("MarketplaceService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local client = Players.LocalPlayer

pcall(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/SenhorLDS/ProjectLDSHUB/refs/heads/main/Anti%20AFK"))()
end)

local gm = getrawmetatable(game)
setreadonly(gm, false)
local oldNamecall = gm.__namecall

gm.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    if not checkcaller() and _G.DisablePopups then
        if typeof(self) == "Instance" and (self.ClassName == "MarketplaceService" or self == MPS) then
            if method == "PromptProductPurchase" or method == "PromptGamePassPurchase" or method == "PromptPurchase" then
                return
            end
        end
    end
    return oldNamecall(self, ...)
end)
setreadonly(gm, true)

task.spawn(function()
    while task.wait(0.5) do
        local pgui = client:FindFirstChild("PlayerGui")
        if not pgui then continue end
        
        if _G.DisablePopups then
            for _, name in ipairs({"RebirthPrompt", "OfflineRewardPrompt", "BoothPurchasePrompt"}) do
                local prompt = pgui:FindFirstChild(name)
                if prompt and prompt:IsA("ScreenGui") and prompt.Enabled then
                    prompt.Enabled = false
                end
            end
        end
        
        if _G.DisableNotifs then
            local notif = pgui:FindFirstChild("Notification")
            if notif and notif:IsA("ScreenGui") then
                notif.Enabled = false
                local mainFrame = notif:FindFirstChild("Main")
                if mainFrame then
                    for _, child in ipairs(mainFrame:GetChildren()) do
                        if child:IsA("Frame") and child.Name ~= "Placeholder" and child.Name ~= "PlaceholderAnnouncement" then
                            child.Visible = false
                        end
                    end
                end
            end
        end
    end
end)

local Library = loadstring(game:HttpGet("https://versusairlines.top/scripts/NewLibrary.lua"))()
local Setup = Library:Setup({
    Location = CoreGui,
    OpenCloseLocation = "Bottom Left"
})

local Networker = require(RS.Source.Shared.Networker)

local function getRemote(name)
    local ok, r = pcall(function() return Networker.get_remote(name) end)
    if ok and r then return r end
    local rf = RS:FindFirstChild("Remotes")
    return rf and rf:FindFirstChild(name) or nil
end

local function getFunction(name)
    local ok, r = pcall(function() return Networker.get_remotefunction(name) end)
    if ok and r then return r end
    local rf = RS:FindFirstChild("Remotes")
    return rf and rf:FindFirstChild(name) or nil
end

local remotes = {
    OpenPack          = getRemote("OpenPack"),
    BuyPack           = getRemote("BuyPack"),
    EquipCard         = getRemote("EquipCard"),
    CollectSlot       = getRemote("CollectSlot"),
    SellCards         = getRemote("SellCards"),
    DeletePacks       = getRemote("DeletePacks"),
    Rebirth           = getRemote("Rebirth"),
    BuyGemShopItem    = getRemote("BuyGemShopItem"),
    ClaimAllIndexGems = getRemote("ClaimAllIndexGems"),
    DailyReward       = getRemote("DailyReward"),
    OfflineReward     = getRemote("OfflineReward"),
    SpinWheel         = getRemote("SpinWheel"),
    Tournament        = getRemote("Tournament"),
    RedeemCode        = getRemote("RedeemCode"),
    UsePotion         = getRemote("UsePotion"),
    PackSettings      = getRemote("PackSettings"),
}

local funcs = {
    SpinWheelData   = getFunction("SpinWheelData"),
    TournamentState = getFunction("TournamentState"),
}

local PackConfig    = require(RS.Source.Shared.Configs.PackConfig)
local CardConfig    = require(RS.Source.Shared.Configs.CardConfig)
local RebirthConfig = require(RS.Source.Shared.Configs.RebirthConfig)
local PlayerStore   = require(RS.Source.Shared.State.PlayerStore)

local WeatherStore
pcall(function() WeatherStore = require(RS.Source.Shared.State.WeatherStore) end)

local stats = {
    opened = 0, bought = 0, sold = 0, 
    rebirths = 0, gemBuys = 0, collects = 0, 
    codesRedeemed = false
}

local function getPlayerData()
    local ok, state = pcall(function() return PlayerStore() end)
    if not ok or not state or not state.players then return nil end
    return state.players[tostring(client.UserId)]
end

local function getInventory() local d = getPlayerData() return d and d.inventory or {} end
local function getSlots() local d = getPlayerData() return d and d.slots or {} end
local function getCash() local d = getPlayerData() return d and d.cash or 0 end
local function getGems() local d = getPlayerData() return d and d.gems or 0 end
local function getRebirthLevel() local d = getPlayerData() return d and d.rebirth or 0 end

local function getActiveWeathers()
    if WeatherStore then
        local ok, state = pcall(function() return WeatherStore() end)
        if ok and state and type(state.activeWeathers) == "table" then
            local active = {}
            local now = Workspace:GetServerTimeNow()
            for name, data in pairs(state.activeWeathers) do
                if data and data.endTime and data.endTime > now then
                    table.insert(active, name)
                end
            end
            if #active > 0 then return table.concat(active, ", ") end
        end
    end
    return "None"
end

local function formatCash(n)
    n = tonumber(n) or 0
    if n >= 1e12 then return string.format("%.2fT", n / 1e12)
    elseif n >= 1e9 then return string.format("%.2fB", n / 1e9)
    elseif n >= 1e6 then return string.format("%.2fM", n / 1e6)
    elseif n >= 1e3 then return string.format("%.1fK", n / 1e3)
    end
    return tostring(math.floor(n))
end

local function getPackList()
    local list = {}
    for name, data in pairs(PackConfig.Packs or {}) do
        if not data.HideFromShop then table.insert(list, name) end
    end
    table.sort(list, function(a, b)
        local pa, pb = PackConfig.Packs[a], PackConfig.Packs[b]
        return (pa and pa.LayoutOrder or 999) < (pb and pb.LayoutOrder or 999)
    end)
    return list
end

local pList = getPackList()
if #pList == 0 then pList = { "Bronze" } end

local rarityOrder = {
    ["Bronze"] = 1, ["Silver"] = 2, ["Gold"] = 3, ["Legendary"] = 4, ["Mythic"] = 5, 
    ["Azure Zenith"] = 6, ["Crimson Zenith"] = 7, ["Divine"] = 8, ["Primordial"] = 9, 
    ["Oblivion"] = 10, ["Eternity"] = 11, ["Astral"] = 12, ["Sovereign"] = 13, 
    ["Vandal"] = 14, ["The Monarch"] = 15, ["Tyrant"] = 16, ["Verdant"] = 17, 
    ["Silvane"] = 18, ["Lunar"] = 19, ["Solar"] = 20, ["Nether"] = 21, 
    ["Aether"] = 22, ["Player of the Month"] = 23, ["Exclusive"] = 24, ["Secret Exclusive"] = 25,
}

local rarityList = {}
for r in pairs(rarityOrder) do table.insert(rarityList, r) end
table.sort(rarityList, function(a, b) return (rarityOrder[a] or 99) < (rarityOrder[b] or 99) end)

local function getRarityLevel(rarity) return rarityOrder[rarity] or 0 end

local function canRebirth()
    local ok, result = pcall(function() return RebirthConfig and RebirthConfig.GetMaxRebirth and RebirthConfig.GetMaxRebirth() end)
    local maxR = (ok and result) or 999
    
    local d = getPlayerData()
    if not d then return false end
    
    local rLvl = d.rebirth or 0
    if rLvl >= maxR then return false end
    
    local rData
    if RebirthConfig and RebirthConfig.GetRebirth then
        local ok2, rd = pcall(function() return RebirthConfig.GetRebirth(rLvl + 1) end)
        rData = ok2 and rd or nil
    end
    
    if not rData then return false end
    if (d.cash or 0) < (rData.CashRequired or math.huge) then return false end
    if rData.GemsRequired and (d.gems or 0) < rData.GemsRequired then return false end
    
    return true
end

local SlotController = nil
local function equipBest()
    if not SlotController then
        local ok, ctrl = pcall(function() return require(RS.Source.Client.Controllers.SlotController) end)
        if ok and ctrl then SlotController = ctrl end
    end
    if SlotController and SlotController.equipBestCards then
        local ok, _ = pcall(SlotController.equipBestCards)
        if ok then return true end
    end
    
    local inv, slots = getInventory(), getSlots()
    if not inv or not slots then return false end

    local candidates = {}
    for _, c in ipairs(inv) do
        if c and c.id and c.uuid and c.id ~= "LocalCard" and c.id ~= "OwnerVulnone" and not c.throneCard and not c.locked then
            local cfg = CardConfig.Cards[c.id]
            table.insert(candidates, { uuid = c.uuid, id = c.id, income = cfg and cfg.IncomeRate or 0 })
        end
    end
    table.sort(candidates, function(a, b) return a.income > b.income end)

    local slotCount = 0
    for _ in pairs(slots) do slotCount = slotCount + 1 end
    if slotCount == 0 then slotCount = 6 end

    local equipped = 0
    for i = 1, math.min(#candidates, slotCount) do
        local card = candidates[i]
        local cur = slots[tostring(i)] or slots[i]
        local curIncome = 0
        
        if cur and cur.card then
            local curCfg = CardConfig.Cards[cur.card.id]
            curIncome = curCfg and curCfg.IncomeRate or 0
        end
        
        if card.income > curIncome then
            remotes.EquipCard:FireServer(card.uuid, i)
            equipped = equipped + 1
            task.wait(0.1)
        end
    end
    return equipped > 0
end

getgenv().WebhookURL = ""
getgenv().WebhookPingID = ""

local req = (syn and syn.request) or (http and http.request) or http_request or request

local function dispatchWebhook(data)
    local url = getgenv().WebhookURL or ""
    if url == "" or not req then return end

    local ping = getgenv().WebhookPingID or ""
    if ping ~= "" then data.content = "<@" .. ping .. ">" end

    pcall(function()
        req({
            Url = url,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(data),
        })
    end)
end

if remotes.OpenPack then
    remotes.OpenPack.OnClientEvent:Connect(function(img, cData, color, uuid, chances, isNew, pName)
        if img == "x" or type(cData) ~= "table" then return end
        if not Library.Flags["WebhookRareRolls"] then return end

        local tFlag = Library.Flags["WebhookRarityThresh"]
        local tName = type(tFlag) == "string" and tFlag or (type(tFlag) == "table" and tFlag[1] or "Mythic")
        local tLvl = getRarityLevel(tName)
        local cLvl = getRarityLevel(cData.Rarity or "Common")

        if cLvl >= tLvl then
            local thumb = ""
            local imgId = string.match(cData.ImageId or "", "%d+")
            if imgId then
                pcall(function()
                    local r = req({
                        Url = "https://thumbnails.roblox.com/v1/assets?assetIds=" .. imgId .. "&returnPolicy=PlaceHolder&size=420x420&format=Png&isCircular=false",
                        Method = "GET"
                    })
                    if r and r.Body then
                        local parsed = HttpService:JSONDecode(r.Body)
                        if parsed.data and parsed.data[1] and parsed.data[1].imageUrl then
                            thumb = parsed.data[1].imageUrl
                        end
                    end
                end)
            end

            local cfg = CardConfig.Cards[cData.id]
            local income = cfg and cfg.IncomeRate or cData.IncomeRate or 0
            
            dispatchWebhook({
                embeds = {{
                    title = "[*] Rare Card Rolled!",
                    description = "A high-tier card has been acquired.",
                    color = 16766720,
                    thumbnail = { url = thumb },
                    fields = {
                        { name = "Card Name", value = cData.DisplayName or cData.Name, inline = false },
                        { name = "Rarity", value = cData.Rarity or "Unknown", inline = false },
                        { name = "Pack", value = pName or "Unknown", inline = false },
                        { name = "Income", value = "$" .. formatCash(income) .. "/s", inline = false },
                        { name = "New Discovery", value = isNew and "Yes" or "No", inline = false },
                        { name = "Player", value = "||" .. client.Name .. "||", inline = false },
                    },
                    footer = { text = "SSC Elite Farm - " .. os.date("%H:%M:%S") }
                }}
            })
        end
    end)
end

local pIdx, bIdx = 1, 1
task.spawn(function()
    while task.wait() do
        if Library.Flags["AutoOpenPacks"] then
            local d = Library.Flags["PackDelay"] or 0
            pcall(function()
                local flag = Library.Flags["SelectedPacks"]
                local selected = type(flag) == "table" and flag or { tostring(flag or "Bronze") }

                if #selected > 0 then
                    if pIdx > #selected then pIdx = 1 end
                    local name = selected[pIdx]
                    pIdx = pIdx + 1

                    local pData = getPlayerData()
                    if pData and pData.packs and (pData.packs[name] or 0) > 0 then
                        remotes.OpenPack:FireServer(name)
                        stats.opened = stats.opened + 1
                    end
                end
            end)
            if d > 0 then task.wait(d) end
        end
    end
end)

local tmr = { col = 0, sell = 0, del = 0, buy = 0, gem = 0, reb = 0, eq = 0, idx = 0, spin = 0, daily = 0, off = 0, tourn = 0, pot = 0, wh = os.clock() }

task.spawn(function()
    while task.wait(0.2) do
        local now = os.clock()
        _G.DisablePopups = Library.Flags["DisablePopups"]
        _G.DisableNotifs = Library.Flags["DisableNotifs"]

        if Library.Flags["WebhookStats"] then
            local delay = Library.Flags["WebhookStatsDelay"] or 15
            if (now - tmr.wh) >= (delay * 60) then
                tmr.wh = now
                dispatchWebhook({
                    embeds = {{
                        title = "[+] SSC Farm Analytics",
                        description = "[$] **Cash:** $" .. formatCash(getCash()) .. "\n" ..
                                      "[*] **Gems:** " .. formatCash(getGems()) .. "\n" ..
                                      "[#] **Rebirth Level:** " .. getRebirthLevel() .. "\n" ..
                                      "[>] **Packs Opened:** " .. formatCash(stats.opened) .. "\n" ..
                                      "[?] **Active Weather:** " .. getActiveWeathers() .. "\n" ..
                                      "[!] **Session Rebirths:** " .. stats.rebirths,
                        color = 3447003,
                        footer = { text = "SSC Elite Farm - User: " .. client.Name }
                    }}
                })
            end
        end

        if Library.Flags["AutoIndex"] and (now - tmr.idx) >= 15 then
            tmr.idx = now; pcall(function() remotes.ClaimAllIndexGems:FireServer() end)
        end
        
        if Library.Flags["AutoSpin"] and (now - tmr.spin) >= 8 then
            tmr.spin = now
            pcall(function()
                if funcs.SpinWheelData then
                    local ok, d = pcall(function() return funcs.SpinWheelData:InvokeServer() end)
                    if ok and type(d) == "table" then
                        if d.canClaimFree then remotes.SpinWheel:FireServer("claim_free") end
                        if type(d.spins) == "number" and d.spins > 0 then remotes.SpinWheel:FireServer("spin") end
                    end
                end
            end)
        end
        
        if Library.Flags["AutoDaily"] and (now - tmr.daily) >= 60 then
            tmr.daily = now; pcall(function() remotes.DailyReward:FireServer("claim") end)
        end
        
        if Library.Flags["AutoOffline"] and (now - tmr.off) >= 60 then
            tmr.off = now; pcall(function() remotes.OfflineReward:FireServer("claim_normal") end)
        end
        
        if Library.Flags["AutoUsePotion"] and (now - tmr.pot) >= 305 then
            tmr.pot = now
            pcall(function()
                local flag = Library.Flags["TargetPotion"]
                local selected = type(flag) == "table" and flag or { tostring(flag or "") }
                
                for _, pName in ipairs(selected) do
                    if pName ~= "" and remotes.UsePotion then
                        remotes.UsePotion:FireServer(pName)
                        task.wait(0.5) 
                    end
                end
            end)
        end
        
        if Library.Flags["AutoRedeemCodes"] and not stats.codesRedeemed then
            stats.codesRedeemed = true
            task.spawn(function()
                local codes = {}
                local url = "https://raw.githubusercontent.com/Aditya-lua/Scripts_2/refs/heads/main/SSC_CODES.txt" 
                local ok, res = pcall(function() return game:HttpGet(url) end)
                if ok and res then
                    for line in res:gmatch("[^\r\n]+") do
                        local clean = line:gsub("%s+", "") 
                        if clean ~= "" and #clean >= 3 then table.insert(codes, clean) end
                    end
                end
                if remotes.RedeemCode and #codes > 0 then
                    for _, c in ipairs(codes) do
                        pcall(function() remotes.RedeemCode:FireServer(string.lower(c)) end)
                        task.wait(1.5)
                    end
                    pcall(function() Library:createDisplayMessage("Codes", "Redeemed " .. #codes .. " codes.", {{text="OK"}}, "info") end)
                end
            end)
        end

        if (Library.Flags["AutoTournament"] or Library.Flags["AutoTourneyEquip"]) and (now - tmr.tourn) >= 15 then
            tmr.tourn = now
            pcall(function()
                local pData = getPlayerData()
                local isQueued = pData and pData.tournament and pData.tournament.queue ~= nil

                if funcs.TournamentState and remotes.Tournament then
                    local ok, tState = pcall(function() return funcs.TournamentState:InvokeServer() end)
                    if ok and type(tState) == "table" and tState.queueWindowOpen then
                        if Library.Flags["AutoTourneyEquip"] then
                            remotes.Tournament:FireServer("equip_best")
                            task.wait(1) 
                        end
                        if Library.Flags["AutoTournament"] and not isQueued and not tState.queued then
                            remotes.Tournament:FireServer("join")
                        end
                    end
                end
            end)
        end

        if Library.Flags["AutoCollect"] and (now - tmr.col) >= (Library.Flags["CollectDelay"] or 3) then
            tmr.col = now
            pcall(function()
                for idx, slot in pairs(getSlots()) do
                    if slot and slot.card then
                        remotes.CollectSlot:FireServer(tonumber(idx))
                        stats.collects = stats.collects + 1
                        task.wait(0.05)
                    end
                end
            end)
        end

        if Library.Flags["AutoSell"] and (now - tmr.sell) >= 8 then
            tmr.sell = now
            pcall(function()
                local flag = Library.Flags["SellThreshold"]
                local tName = type(flag) == "string" and flag or (type(flag) == "table" and flag[1] or "Silver")
                local tLvl = getRarityLevel(tName)

                local toSell = {}
                for _, c in ipairs(getInventory()) do
                    if c and c.id and c.uuid and not c.throneCard and not c.locked and c.id ~= "LocalCard" and c.id ~= "OwnerVulnone" then
                        local cfg = CardConfig.Cards[c.id]
                        if cfg and getRarityLevel(cfg.Rarity) < tLvl then
                            table.insert(toSell, c.uuid)
                        end
                    end
                end
                if #toSell > 0 then
                    remotes.SellCards:FireServer(toSell)
                    stats.sold = stats.sold + #toSell
                end
            end)
        end

        if Library.Flags["AutoDeletePacks"] and (now - tmr.del) >= 10 then
            tmr.del = now
            pcall(function()
                local flag = Library.Flags["DeletePacksList"]
                local sel = type(flag) == "table" and flag or {}
                if #sel > 0 and remotes.DeletePacks then
                    remotes.DeletePacks:FireServer(sel)
                end
            end)
        end

        if Library.Flags["AutoEquip"] and (now - tmr.eq) >= 8 then
            tmr.eq = now; pcall(equipBest)
        end

        if Library.Flags["AutoBuyPacks"] and (now - tmr.buy) >= (Library.Flags["BuyDelay"] or 2) then
            tmr.buy = now
            pcall(function()
                local flag = Library.Flags["SelectedBuyPacks"]
                local sel = type(flag) == "table" and flag or { tostring(flag or "Bronze") }

                if #sel > 0 then
                    if bIdx > #sel then bIdx = 1 end
                    local name = sel[bIdx]
                    bIdx = bIdx + 1

                    local pd = PackConfig.Packs[name]
                    if pd and (pd.Price or 0) > 0 and getCash() >= pd.Price then
                        remotes.BuyPack:FireServer(name)
                        stats.bought = stats.bought + 1
                    end
                end
            end)
        end

        if Library.Flags["AutoGemShop"] and (now - tmr.gem) >= 10 then
            tmr.gem = now
            pcall(function()
                local flag = Library.Flags["GemShopItemUI"]
                local key = type(flag) == "string" and flag or (type(flag) == "table" and flag[1] or "Lucky Item")
                local map = { ["Lucky Item"] = "lucky", ["Auto Equip Best"] = "fixed_1", ["Auto Skip"] = "fixed_2", ["Inventory +500"] = "fixed_3", ["Scarlet Item"] = "scarlet" }
                local id = map[key] or "lucky"

                if getGems() >= (Library.Flags["MinGems"] or 100) then
                    remotes.BuyGemShopItem:FireServer(id)
                    stats.gemBuys = stats.gemBuys + 1
                end
            end)
        end

        local rbCD = Library.Flags["ForceRebirth"] and 30 or 15
        if Library.Flags["AutoRebirth"] and (now - tmr.reb) >= rbCD then
            tmr.reb = now
            pcall(function()
                if Library.Flags["ForceRebirth"] or canRebirth() then
                    local old = getRebirthLevel()
                    remotes.Rebirth:FireServer()
                    task.wait(1.5)
                    if getRebirthLevel() > old then 
                        stats.rebirths = stats.rebirths + 1 
                    end
                end
            end)
        end
    end
end)

local TabFarm = Setup:CreateSection("Farm & Packs")
TabFarm:createLabel({ Name = "Plot Automation", Special = true })
TabFarm:createToggle({ Name = "Auto Collect Cash", flagName = "AutoCollect", Flag = false, Callback = function() end })
TabFarm:createSlider({ Name = "Collect Delay (Seconds)", flagName = "CollectDelay", value = 3, minValue = 1, maxValue = 60, Callback = function() end })
TabFarm:createToggle({ Name = "Auto Equip Best Cards", flagName = "AutoEquip", Flag = false, Callback = function() end })
TabFarm:createToggle({ Name = "Auto Sell Cards", flagName = "AutoSell", Flag = false, Callback = function() end })
TabFarm:createDropdown({ Name = "Sell Below Rarity:", flagName = "SellThreshold", Flag = { "Silver" }, List = rarityList, multi = false, Callback = function() end })

TabFarm:createLabel({ Name = "Pack Roller Configuration", Special = true })
TabFarm:createToggle({
    Name = "Hide Native Roll Animation", 
    flagName = "HideAnim", Flag = false,
    Callback = function(v)
        pcall(function()
            if remotes.PackSettings then
                remotes.PackSettings:FireServer("packAutoOpen", v)
                task.wait(0.1)
                remotes.PackSettings:FireServer("packHideAnimation", v)
                remotes.PackSettings:FireServer("packAutoSkip", v)
            end
        end)
    end,
})
TabFarm:createToggle({ Name = "Custom Script Auto Open", flagName = "AutoOpenPacks", Flag = false, Callback = function() end })

local packDropdown = TabFarm:createDropdown({ Name = "Select Packs to Open", flagName = "SelectedPacks", Flag = { pList[1] or "Bronze" }, List = pList, multi = true, Callback = function() end })
TabFarm:createButton({ Name = "Select ALL Packs (To Open)", Callback = function() pcall(function() packDropdown:Set(pList) end) Library.Flags["SelectedPacks"] = pList pIdx = 1 end })
TabFarm:createSlider({ Name = "Custom Pack Delay (0 = Instant)", flagName = "PackDelay", value = 0, minValue = 0, maxValue = 5, Callback = function() end })

TabFarm:createLabel({ Name = "Shop & Store Automation", Special = true })
TabFarm:createToggle({ Name = "Auto Buy Shop Packs", flagName = "AutoBuyPacks", Flag = false, Callback = function() end })
local buyPackDropdown = TabFarm:createDropdown({ Name = "Select Packs to Buy", flagName = "SelectedBuyPacks", Flag = { pList[1] or "Bronze" }, List = pList, multi = true, Callback = function() end })
TabFarm:createButton({ Name = "Select ALL Shop Packs", Callback = function() pcall(function() buyPackDropdown:Set(pList) end) Library.Flags["SelectedBuyPacks"] = pList bIdx = 1 end })
TabFarm:createSlider({ Name = "Pack Buy Delay (Seconds)", flagName = "BuyDelay", value = 2, minValue = 1, maxValue = 30, Callback = function() end })

TabFarm:createToggle({ Name = "Auto Buy Gem Shop", flagName = "AutoGemShop", Flag = false, Callback = function() end })
TabFarm:createDropdown({ Name = "Target Gem Shop Item", flagName = "GemShopItemUI", Flag = { "Lucky Item" }, List = { "Lucky Item", "Auto Equip Best", "Auto Skip", "Inventory +500", "Scarlet Item" }, multi = false, Callback = function() end })
TabFarm:createSlider({ Name = "Min Gems to Keep", flagName = "MinGems", value = 100, minValue = 0, maxValue = 10000, Callback = function() end })

TabFarm:createLabel({ Name = "Inventory Cleanup", Special = true })
TabFarm:createToggle({ Name = "Auto Delete Packs", flagName = "AutoDeletePacks", Flag = false, Callback = function() end })
TabFarm:createDropdown({ Name = "Select Packs to Delete", flagName = "DeletePacksList", Flag = { pList[1] or "Bronze" }, List = pList, multi = true, Callback = function() end })

local TabPassive = Setup:CreateSection("Passives & Rebirth")
TabPassive:createLabel({ Name = "Silent Income Generators", Special = true })
TabPassive:createToggle({ Name = "Auto Claim Index Gems", flagName = "AutoIndex", Flag = false, Callback = function() end })
TabPassive:createToggle({ Name = "Auto Spin Wheel", flagName = "AutoSpin", Flag = false, Callback = function() end })
TabPassive:createToggle({ Name = "Auto Daily Rewards", flagName = "AutoDaily", Flag = false, Callback = function() end })
TabPassive:createToggle({ Name = "Auto Offline Rewards", flagName = "AutoOffline", Flag = false, Callback = function() end })

TabPassive:createLabel({ Name = "Consumables", Special = true })
TabPassive:createToggle({ Name = "Auto Use Potion", flagName = "AutoUsePotion", Flag = false, Callback = function() end })
TabPassive:createDropdown({ Name = "Select Potion", flagName = "TargetPotion", Flag = { "Snowstorm Potion" }, List = { "Snowstorm Potion", "Thunderstorm Potion", "Toxic Rain Potion", "Blood Moon Potion", "Solar Eclipse Potion" }, multi = true, Callback = function() end })

TabPassive:createLabel({ Name = "Progression & One-Time", Special = true })
TabPassive:createToggle({ Name = "Auto Redeem All Codes", flagName = "AutoRedeemCodes", Flag = false, Callback = function() end })
TabPassive:createToggle({ Name = "Auto Rebirth", flagName = "AutoRebirth", Flag = false, Callback = function() end })
TabPassive:createToggle({ Name = "Force Rebirth", flagName = "ForceRebirth", Flag = false, Callback = function() end })

TabPassive:createLabel({ Name = "Tournament Automation", Special = true })
TabPassive:createToggle({ Name = "Auto Tourney Equip", flagName = "AutoTourneyEquip", Flag = false, Callback = function() end })
TabPassive:createToggle({ Name = "Auto Join Tournament", flagName = "AutoTournament", Flag = false, Callback = function() end })

local TabWebhook = Setup:CreateSection("Webhooks")
TabWebhook:createLabel({ Name = "Discord Integration", Special = true })
TabWebhook:createInputBox({ Name = "Webhook URL", flagName = "WebhookURL", Flag = "", Callback = function(val) getgenv().WebhookURL = val end })
TabWebhook:createInputBox({ Name = "Discord User ID", flagName = "WebhookPingID", Flag = "", Callback = function(val) getgenv().WebhookPingID = tostring(val):gsub("[^%d]", "") end })
TabWebhook:createLabel({ Name = "Rare Card Tracker", Special = true })
TabWebhook:createToggle({ Name = "Enable Rare Rolls Webhook", flagName = "WebhookRareRolls", Flag = false, Callback = function() end })
TabWebhook:createDropdown({ Name = "Minimum Rarity to Log", flagName = "WebhookRarityThresh", Flag = { "Mythic" }, List = rarityList, multi = false, Callback = function() end })
TabWebhook:createLabel({ Name = "Automated Analytics", Special = true })
TabWebhook:createToggle({ Name = "Enable Stats Webhook", flagName = "WebhookStats", Flag = false, Callback = function() end })
TabWebhook:createSlider({ Name = "Stats Update Frequency (Mins)", flagName = "WebhookStatsDelay", value = 15, minValue = 1, maxValue = 60, Callback = function() end })
TabWebhook:createButton({ Name = "Send Test Webhook", Callback = function() pcall(function() Library:createDisplayMessage("Test", "Webhook fired.", {{text="OK"}}, "info") end) end })

local TabMisc = Setup:CreateSection("Misc & Settings")
TabMisc:createLabel({ Name = "Game Modifications", Special = true })
TabMisc:createToggle({ Name = "Disable Game Popups", flagName = "DisablePopups", Flag = false, Callback = function() end })
TabMisc:createToggle({ Name = "Disable Game Notifications", flagName = "DisableNotifs", Flag = false, Callback = function() end })
TabMisc:createToggle({ 
    Name = "Hide Game HUD", flagName = "HideHUD", Flag = false, 
    Callback = function(v) local h = client:FindFirstChild("PlayerGui") and client.PlayerGui:FindFirstChild("HUD") if h then h.Enabled = not v end end 
})

TabMisc:createLabel({ Name = "Quick Actions", Special = true })
TabMisc:createButton({ Name = "Equip Best Cards Now", Callback = function() equipBest() pcall(function() Library:createDisplayMessage("Equipped", "Success.", {{text="OK"}}, "info") end) end })
TabMisc:createButton({
    Name = "Sell Below Threshold Now",
    Callback = function()
        local tName = type(Library.Flags["SellThreshold"]) == "string" and Library.Flags["SellThreshold"] or (type(Library.Flags["SellThreshold"]) == "table" and Library.Flags["SellThreshold"][1] or "Silver")
        local tLvl = getRarityLevel(tName)
        local toSell = {}
        for _, c in ipairs(getInventory()) do
            if c and c.id and c.uuid and not c.throneCard and not c.locked and c.id ~= "LocalCard" and c.id ~= "OwnerVulnone" then
                if (CardConfig.Cards[c.id] and getRarityLevel(CardConfig.Cards[c.id].Rarity) < tLvl) then table.insert(toSell, c.uuid) end
            end
        end
        if #toSell > 0 then pcall(function() remotes.SellCards:FireServer(toSell) end) end
    end,
})

local TabStats = Setup:CreateSection("Analytics")
TabStats:createLabel({ Name = "Live Session Analytics", Special = true })
local l_cash = TabStats:createLabel({ Name = "Cash: $0" })
local l_gems = TabStats:createLabel({ Name = "Gems: 0" })
local l_reb = TabStats:createLabel({ Name = "Rebirth Level: 0" })
local l_pack = TabStats:createLabel({ Name = "Packs Opened: 0" })
local l_buy = TabStats:createLabel({ Name = "Packs Bought: 0" })
local l_sell = TabStats:createLabel({ Name = "Cards Sold: 0" })
local l_col = TabStats:createLabel({ Name = "Collects: 0" })
local l_gemB = TabStats:createLabel({ Name = "Gem Buys: 0" })
local l_sReb = TabStats:createLabel({ Name = "Session Rebirths: 0" })
local l_wea = TabStats:createLabel({ Name = "Active Weather: None" })

local lastUI = 0
RunService.Heartbeat:Connect(function()
    local now = os.clock()
    if now - lastUI >= 0.5 then
        lastUI = now
        pcall(function()
            if l_cash and l_cash.Set then
                l_cash:Set("Cash: $" .. formatCash(getCash()))
                l_gems:Set("Gems: " .. math.floor(getGems()))
                l_reb:Set("Rebirth Level: " .. getRebirthLevel())
                l_pack:Set("Packs Opened: " .. stats.opened)
                l_buy:Set("Packs Bought: " .. stats.bought)
                l_sell:Set("Cards Sold: " .. stats.sold)
                l_col:Set("Collects: " .. stats.collects)
                l_gemB:Set("Gem Buys: " .. stats.gemBuys)
                l_sReb:Set("Session Rebirths: " .. stats.rebirths)
                l_wea:Set("Active Weather: " .. getActiveWeathers())
            end
        end)
    end
end)

TabStats:createButton({
    Name = "Reset Stats",
    Callback = function()
        stats = { opened=0, bought=0, sold=0, rebirths=0, gemBuys=0, collects=0, codesRedeemed=true }
    end,
})

print("[SSC Farm] Loaded successfully.")

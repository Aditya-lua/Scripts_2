-- // ============================================
-- // SSC Elite Farm
-- // Dev    :- Aditya
-- // Owner  :- Cammy
-- // Build   :- 1.0 (Bulked)
-- // ============================================

-- ============ SERVICES ============
local Players          = game:GetService("Players")
local RS               = game:GetService("ReplicatedStorage")
local CoreGui          = game:GetService("CoreGui")
local HttpService      = game:GetService("HttpService")
local MPS              = game:GetService("MarketplaceService")
local Workspace        = game:GetService("Workspace")
local RunService       = game:GetService("RunService")
local VirtualUser      = game:GetService("VirtualUser")

-- ============ CLIENT ============
local client           = Players.LocalPlayer

-- ============ CONSTANTS ============
local CODES_URL        = "https://raw.githubusercontent.com/Aditya-lua/Scripts_2/refs/heads/main/SSC_CODES.txt"
local LIBRARY_URL      = "https://versusairlines.top/scripts/NewLibrary.lua"
local ROBLOX_THUMBS    = "https://thumbnails.roblox.com/v1/assets?assetIds=%s&returnPolicy=PlaceHolder&size=420x420&format=Png&isCircular=false"

local COLLECT_DEFAULT  = 3
local STATS_DELAY_DEFAULT = 15
local MIN_GEMS_DEFAULT = 100
local SELL_DEFAULT     = "Silver"
local RARITY_THRESH_DEFAULT = "Mythic"
local CODE_WAIT        = 1.5
local REBIRTH_CD_NORMAL = 15
local REBIRTH_CD_FORCE  = 30

local GEM_SHOP_MAP = {
    ["Lucky Item"]       = "lucky",
    ["Auto Equip Best"]  = "fixed_1",
    ["Auto Skip"]        = "fixed_2",
    ["Inventory +500"]   = "fixed_3",
    ["Scarlet Item"]     = "scarlet",
}

-- ============ HTTP REQUEST ============
local req = (syn and syn.request)
         or (http and http.request)
         or http_request
         or request

-- ============ ANTI AFK ============
client.Idled:Connect(function()
    VirtualUser:Button2Down(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
    task.wait(1)
    VirtualUser:Button2Up(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
end)

-- ============ POPUP BLOCKER (NAMECALL HOOK) ============
local gm = getrawmetatable(game)
setreadonly(gm, false)
local oldNamecall = gm.__namecall

gm.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    if not checkcaller() and _G.DisablePopups then
        local isMPS = typeof(self) == "Instance"
                   and (self.ClassName == "MarketplaceService" or self == MPS)
        if isMPS then
            local blockedMethods = {
                PromptProductPurchase  = true,
                PromptGamePassPurchase = true,
                PromptPurchase         = true,
            }
            if blockedMethods[method] then
                return
            end
        end
    end
    return oldNamecall(self, ...)
end)

setreadonly(gm, true)

-- ============ GUI SUPPRESSOR LOOP ============
local POPUP_NAMES = { "RebirthPrompt", "OfflineRewardPrompt", "BoothPurchasePrompt" }

task.spawn(function()
    while task.wait(0.5) do
        local pgui = client:FindFirstChild("PlayerGui")
        if not pgui then continue end

        if _G.DisablePopups then
            for _, promptName in ipairs(POPUP_NAMES) do
                local promptGui = pgui:FindFirstChild(promptName)
                if promptGui and promptGui:IsA("ScreenGui") and promptGui.Enabled then
                    promptGui.Enabled = false
                end
            end
        end

        if _G.DisableNotifs then
            local notifGui = pgui:FindFirstChild("Notification")
            if notifGui and notifGui:IsA("ScreenGui") then
                notifGui.Enabled = false
                local mainFrame = notifGui:FindFirstChild("Main")
                if mainFrame then
                    for _, child in ipairs(mainFrame:GetChildren()) do
                        local isFrame       = child:IsA("Frame")
                        local isPlaceholder = child.Name == "Placeholder"
                                           or child.Name == "PlaceholderAnnouncement"
                        if isFrame and not isPlaceholder then
                            child.Visible = false
                        end
                    end
                end
            end
        end
    end
end)

-- ============ LIBRARY SETUP ============
print("[SSC Farm] Loading library...")
local Library = loadstring(game:HttpGet(LIBRARY_URL))()

local Setup = Library:Setup({
    Location          = CoreGui,
    OpenCloseLocation = "Bottom Left",
})

print("[SSC Farm] Library loaded.")

-- ============ HELPERS ============
local function notify(title, desc, style)
    pcall(function()
        Library:createDisplayMessage(title, desc, { { text = "OK" } }, style or "info")
    end)
end

local function interval(tag, flag, delayTime, callback)
    Library:CleanupConnectionsByTag(tag)
    if not Library.Flags[flag] then return end

    local lastTick = 0
    local conn = RunService.Heartbeat:Connect(function()
        if not Library.Flags[flag] then
            Library:CleanupConnectionsByTag(tag)
            return
        end
        local now = os.clock()
        if now - lastTick >= delayTime then
            lastTick = now
            pcall(callback)
        end
    end)

    Library:TrackConnection(conn, tag)
end

-- ============ NETWORKER / REMOTES ============
local Networker = require(RS.Source.Shared.Networker)

local function getRemote(name)
    local ok, result = pcall(function()
        return Networker.get_remote(name)
    end)
    if ok and result then return result end

    local folder = RS:FindFirstChild("Remotes")
    if folder then return folder:FindFirstChild(name) end
    return nil
end

local function getFunction(name)
    local ok, result = pcall(function()
        return Networker.get_remotefunction(name)
    end)
    if ok and result then return result end

    local folder = RS:FindFirstChild("Remotes")
    if folder then return folder:FindFirstChild(name) end
    return nil
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
    RedeemCode        = getRemote("RedeemCode"),
}

local funcs = {
    SpinWheelData = getFunction("SpinWheelData"),
}

-- ============ CONFIGS ============
local PackConfig    = require(RS.Source.Shared.Configs.PackConfig)
local CardConfig    = require(RS.Source.Shared.Configs.CardConfig)
local RebirthConfig = require(RS.Source.Shared.Configs.RebirthConfig)
local PlayerStore   = require(RS.Source.Shared.State.PlayerStore)

local WeatherStore = nil
pcall(function()
    WeatherStore = require(RS.Source.Shared.State.WeatherStore)
end)

-- ============ SESSION STATS ============
local stats = {
    opened        = 0,
    bought        = 0,
    sold          = 0,
    rebirths      = 0,
    gemBuys       = 0,
    collects      = 0,
    codesRedeemed = false,
}

-- ============ PLAYER DATA ACCESSORS ============
local function getPlayerData()
    local ok, state = pcall(function() return PlayerStore() end)
    if not ok or not state or not state.players then return nil end
    return state.players[tostring(client.UserId)]
end

local function getInventory()
    local data = getPlayerData()
    return data and data.inventory or {}
end

local function getSlots()
    local data = getPlayerData()
    return data and data.slots or {}
end

local function getCash()
    local data = getPlayerData()
    return data and data.cash or 0
end

local function getGems()
    local data = getPlayerData()
    return data and data.gems or 0
end

local function getRebirthLevel()
    local data = getPlayerData()
    return data and data.rebirth or 0
end

-- ============ WEATHER ============
local function getActiveWeathers()
    if not WeatherStore then return "None" end

    local ok, state = pcall(function() return WeatherStore() end)
    if not ok or not state or type(state.activeWeathers) ~= "table" then
        return "None"
    end

    local active = {}
    local now = Workspace:GetServerTimeNow()

    for weatherName, weatherData in pairs(state.activeWeathers) do
        local hasEndTime = weatherData and weatherData.endTime
        local isActive   = hasEndTime and weatherData.endTime > now
        if isActive then
            table.insert(active, weatherName)
        end
    end

    if #active > 0 then
        return table.concat(active, ", ")
    end

    return "None"
end

-- ============ FORMATTERS ============
local function formatCash(n)
    n = tonumber(n) or 0

    if n >= 1e12 then
        return string.format("%.2fT", n / 1e12)
    elseif n >= 1e9 then
        return string.format("%.2fB", n / 1e9)
    elseif n >= 1e6 then
        return string.format("%.2fM", n / 1e6)
    elseif n >= 1e3 then
        return string.format("%.1fK", n / 1e3)
    end

    return tostring(math.floor(n))
end

-- ============ PACK LIST ============
local function getPackList()
    local list = {}

    for packName, packData in pairs(PackConfig.Packs or {}) do
        if not packData.HideFromShop then
            table.insert(list, packName)
        end
    end

    table.sort(list, function(a, b)
        local pa = PackConfig.Packs[a]
        local pb = PackConfig.Packs[b]
        local orderA = pa and pa.LayoutOrder or 999
        local orderB = pb and pb.LayoutOrder or 999
        return orderA < orderB
    end)

    return list
end

-- ============ RARITY SYSTEM ============
local rarityOrder = {
    ["Bronze"]            = 1,
    ["Silver"]            = 2,
    ["Gold"]              = 3,
    ["Legendary"]         = 4,
    ["Mythic"]            = 5,
    ["Azure Zenith"]      = 6,
    ["Crimson Zenith"]    = 7,
    ["Divine"]            = 8,
    ["Primordial"]        = 9,
    ["Oblivion"]          = 10,
    ["Eternity"]          = 11,
    ["Astral"]            = 12,
    ["Sovereign"]         = 13,
    ["Vandal"]            = 14,
    ["The Monarch"]       = 15,
    ["Tyrant"]            = 16,
    ["Verdant"]           = 17,
    ["Silvane"]           = 18,
    ["Lunar"]             = 19,
    ["Solar"]             = 20,
    ["Nether"]            = 21,
    ["Aether"]            = 22,
    ["Player of the Month"] = 23,
    ["Exclusive"]         = 24,
    ["Secret Exclusive"]  = 25,
}

local rarityList = {}
for rarityName in pairs(rarityOrder) do
    table.insert(rarityList, rarityName)
end
table.sort(rarityList, function(a, b)
    return (rarityOrder[a] or 99) < (rarityOrder[b] or 99)
end)

local function getRarityLevel(rarity)
    return rarityOrder[rarity] or 0
end

-- ============ REBIRTH CHECK ============
local function canRebirth()
    local ok, maxResult = pcall(function()
        return RebirthConfig and RebirthConfig.GetMaxRebirth and RebirthConfig.GetMaxRebirth()
    end)
    local maxRebirth = (ok and maxResult) or 999

    local playerData = getPlayerData()
    if not playerData then return false end

    local currentRebirth = playerData.rebirth or 0
    if currentRebirth >= maxRebirth then return false end

    local nextLevel = currentRebirth + 1
    local rebirthData = nil

    if RebirthConfig and RebirthConfig.GetRebirth then
        local ok2, rd = pcall(function()
            return RebirthConfig.GetRebirth(nextLevel)
        end)
        rebirthData = ok2 and rd or nil
    end

    if not rebirthData then return false end

    local cashRequired = rebirthData.CashRequired or math.huge
    local gemsRequired = rebirthData.GemsRequired or 0

    if (playerData.cash or 0) < cashRequired then return false end
    if gemsRequired > 0 and (playerData.gems or 0) < gemsRequired then return false end

    return true
end

-- ============ EQUIP BEST CARDS ============
local SlotController = nil

local function equipBest()
    if not SlotController then
        local ok, ctrl = pcall(function()
            return require(RS.Source.Client.Controllers.SlotController)
        end)
        if ok and ctrl then SlotController = ctrl end
    end

    if SlotController and SlotController.equipBestCards then
        local ok = pcall(SlotController.equipBestCards)
        if ok then return true end
    end

    local inventory = getInventory()
    local slots     = getSlots()
    if not inventory or not slots then return false end

    local BLOCKED_IDS = { LocalCard = true, OwnerVulnone = true }

    local candidates = {}
    for _, card in ipairs(inventory) do
        local isValid = card
                     and card.id
                     and card.uuid
                     and not BLOCKED_IDS[card.id]
                     and not card.throneCard
                     and not card.locked

        if isValid then
            local cfg    = CardConfig.Cards[card.id]
            local income = cfg and cfg.IncomeRate or 0
            table.insert(candidates, {
                uuid   = card.uuid,
                id     = card.id,
                income = income,
            })
        end
    end

    table.sort(candidates, function(a, b)
        return a.income > b.income
    end)

    local slotCount = 0
    for _ in pairs(slots) do
        slotCount = slotCount + 1
    end
    if slotCount == 0 then slotCount = 6 end

    local equippedCount = 0
    for slotIndex = 1, math.min(#candidates, slotCount) do
        local candidate   = candidates[slotIndex]
        local currentSlot = slots[tostring(slotIndex)] or slots[slotIndex]
        local currentIncome = 0

        if currentSlot and currentSlot.card then
            local curCfg    = CardConfig.Cards[currentSlot.card.id]
            currentIncome   = curCfg and curCfg.IncomeRate or 0
        end

        if candidate.income > currentIncome then
            remotes.EquipCard:FireServer(candidate.uuid, slotIndex)
            equippedCount = equippedCount + 1
            task.wait(0.1)
        end
    end

    return equippedCount > 0
end

-- ============ WEBHOOK ============
getgenv().WebhookURL    = ""
getgenv().WebhookPingID = ""

local function dispatchWebhook(payload)
    local url = getgenv().WebhookURL or ""
    if url == "" or not req then return end

    local pingId = getgenv().WebhookPingID or ""
    if pingId ~= "" then
        payload.content = "<@" .. pingId .. ">"
    end

    pcall(function()
        req({
            Url     = url,
            Method  = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body    = HttpService:JSONEncode(payload),
        })
    end)
end

-- ============ RARE ROLL WEBHOOK LISTENER ============
if remotes.OpenPack then
    remotes.OpenPack.OnClientEvent:Connect(function(img, cData, color, uuid, chances, isNew, pName)
        if img == "x" or type(cData) ~= "table" then return end
        if not Library.Flags["WebhookRareRolls"] then return end

        local threshFlag  = Library.Flags["WebhookRarityThresh"]
        local threshName  = type(threshFlag) == "string" and threshFlag
                         or (type(threshFlag) == "table" and threshFlag[1])
                         or RARITY_THRESH_DEFAULT
        local threshLevel = getRarityLevel(threshName)
        local cardLevel   = getRarityLevel(cData.Rarity or "Common")

        if cardLevel < threshLevel then return end

        local thumbnailUrl = ""
        local imageId = string.match(cData.ImageId or "", "%d+")

        if imageId then
            pcall(function()
                local thumbResponse = req({
                    Url    = string.format(ROBLOX_THUMBS, imageId),
                    Method = "GET",
                })
                if thumbResponse and thumbResponse.Body then
                    local parsed = HttpService:JSONDecode(thumbResponse.Body)
                    if parsed.data and parsed.data[1] and parsed.data[1].imageUrl then
                        thumbnailUrl = parsed.data[1].imageUrl
                    end
                end
            end)
        end

        local cardCfg = CardConfig.Cards[cData.id]
        local income  = cardCfg and cardCfg.IncomeRate or cData.IncomeRate or 0

        dispatchWebhook({
            embeds = {{
                title       = "[*] Rare Card Rolled!",
                description = "A high-tier card has been acquired.",
                color       = 16766720,
                thumbnail   = { url = thumbnailUrl },
                fields = {
                    { name = "Card Name",      value = cData.DisplayName or cData.Name, inline = false },
                    { name = "Rarity",         value = cData.Rarity or "Unknown",       inline = false },
                    { name = "Pack",           value = pName or "Unknown",              inline = false },
                    { name = "Income",         value = "$" .. formatCash(income) .. "/s", inline = false },
                    { name = "New Discovery",  value = isNew and "Yes" or "No",         inline = false },
                    { name = "Player",         value = "||" .. client.Name .. "||",     inline = false },
                },
                footer = { text = "SSC Elite Farm - " .. os.date("%H:%M:%S") },
            }}
        })
    end)
end

-- ============ FAST LOOP: OPEN & BUY PACKS ============
-- Unthrottled; respects per-slider delay values
local openPackIndex = 1
local buyPackIndex  = 1

task.spawn(function()
    while task.wait() do

        -- Auto Open Packs
        if Library.Flags["AutoOpenPacks"] then
            local packDelay = Library.Flags["PackDelay"] or 0

            pcall(function()
                local flag     = Library.Flags["SelectedPacks"]
                local selected = type(flag) == "table" and flag or { tostring(flag or "Bronze") }

                if #selected > 0 then
                    if openPackIndex > #selected then openPackIndex = 1 end
                    local packName = selected[openPackIndex]
                    openPackIndex  = openPackIndex + 1

                    local playerData = getPlayerData()
                    local hasPack    = playerData
                                    and playerData.packs
                                    and (playerData.packs[packName] or 0) > 0

                    if hasPack then
                        remotes.OpenPack:FireServer(packName)
                        stats.opened = stats.opened + 1
                    end
                end
            end)

            if packDelay > 0 then task.wait(packDelay) end
        end

        -- Auto Buy Packs
        if Library.Flags["AutoBuyPacks"] then
            local buyDelay = Library.Flags["BuyDelay"] or 0

            pcall(function()
                local flag     = Library.Flags["SelectedBuyPacks"]
                local selected = type(flag) == "table" and flag or { "Bronze" }

                if #selected > 0 then
                    if buyPackIndex > #selected then buyPackIndex = 1 end
                    local packName = selected[buyPackIndex]
                    buyPackIndex   = buyPackIndex + 1

                    local packData  = PackConfig.Packs[packName]
                    local packPrice = packData and (packData.Price or 0) or 0
                    local canAfford = packPrice > 0 and getCash() >= packPrice

                    if canAfford then
                        remotes.BuyPack:FireServer(packName)
                        stats.bought = stats.bought + 1
                    end
                end
            end)

            if buyDelay > 0 then task.wait(buyDelay) end
        end
    end
end)

-- ============ MAIN PROCESSING LOOP (0.2s throttled) ============
local timers = {
    collect  = 0,
    sell     = 0,
    delPacks = 0,
    gemShop  = 0,
    rebirth  = 0,
    equip    = 0,
    index    = 0,
    spin     = 0,
    daily    = 0,
    offline  = 0,
    webhook  = os.clock(),
}

task.spawn(function()
    while task.wait(0.2) do
        local now = os.clock()

        -- Sync globals
        _G.DisablePopups = Library.Flags["DisablePopups"]
        _G.DisableNotifs = Library.Flags["DisableNotifs"]

        -- Stats Webhook
        if Library.Flags["WebhookStats"] then
            local statsDelay = Library.Flags["WebhookStatsDelay"] or STATS_DELAY_DEFAULT
            local elapsed    = now - timers.webhook

            if elapsed >= (statsDelay * 60) then
                timers.webhook = now
                dispatchWebhook({
                    embeds = {{
                        title       = "[+] SSC Farm Analytics",
                        description = "[$] **Cash:** $"         .. formatCash(getCash())    .. "\n"
                                   .. "[*] **Gems:** "          .. formatCash(getGems())    .. "\n"
                                   .. "[#] **Rebirth Level:** " .. getRebirthLevel()        .. "\n"
                                   .. "[>] **Packs Opened:** "  .. formatCash(stats.opened) .. "\n"
                                   .. "[?] **Active Weather:** ".. getActiveWeathers()      .. "\n"
                                   .. "[!] **Session Rebirths:** " .. stats.rebirths,
                        color  = 3447003,
                        footer = { text = "SSC Elite Farm - User: " .. client.Name },
                    }}
                })
            end
        end

        -- Auto Index Gems
        if Library.Flags["AutoIndex"] and (now - timers.index) >= 15 then
            timers.index = now
            pcall(function()
                remotes.ClaimAllIndexGems:FireServer()
            end)
        end

        -- Auto Spin Wheel
        if Library.Flags["AutoSpin"] and (now - timers.spin) >= 8 then
            timers.spin = now
            pcall(function()
                if not funcs.SpinWheelData then return end

                local ok, spinData = pcall(function()
                    return funcs.SpinWheelData:InvokeServer()
                end)

                if ok and type(spinData) == "table" then
                    if spinData.canClaimFree then
                        remotes.SpinWheel:FireServer("claim_free")
                    end
                    if type(spinData.spins) == "number" and spinData.spins > 0 then
                        remotes.SpinWheel:FireServer("spin")
                    end
                end
            end)
        end

        -- Auto Daily Reward
        if Library.Flags["AutoDaily"] and (now - timers.daily) >= 60 then
            timers.daily = now
            pcall(function()
                remotes.DailyReward:FireServer("claim")
            end)
        end

        -- Auto Offline Reward
        if Library.Flags["AutoOffline"] and (now - timers.offline) >= 60 then
            timers.offline = now
            pcall(function()
                remotes.OfflineReward:FireServer("claim_normal")
            end)
        end

        -- Auto Redeem Codes (one-time per session)
        if Library.Flags["AutoRedeemCodes"] and not stats.codesRedeemed then
            stats.codesRedeemed = true

            task.spawn(function()
                local codes   = {}
                local ok, res = pcall(function()
                    return game:HttpGet(CODES_URL)
                end)

                if ok and type(res) == "string" then
                    for line in res:gmatch("[^\r\n]+") do
                        local cleaned = line:gsub("%s+", "")
                        if cleaned ~= "" and #cleaned >= 3 then
                            table.insert(codes, cleaned)
                        end
                    end
                end

                if remotes.RedeemCode and #codes > 0 then
                    for _, code in ipairs(codes) do
                        pcall(function()
                            remotes.RedeemCode:FireServer(string.lower(code))
                        end)
                        task.wait(CODE_WAIT)
                    end
                    notify("Codes", "Redeemed " .. #codes .. " codes.", "info")
                end
            end)
        end

        -- Auto Collect Cash
        local collectDelay = Library.Flags["CollectDelay"] or COLLECT_DEFAULT
        if Library.Flags["AutoCollect"] and (now - timers.collect) >= collectDelay then
            timers.collect = now
            pcall(function()
                for slotIndex, slotData in pairs(getSlots()) do
                    if slotData and slotData.card then
                        remotes.CollectSlot:FireServer(tonumber(slotIndex))
                        stats.collects = stats.collects + 1
                        task.wait(0.05)
                    end
                end
            end)
        end

        -- Auto Sell Cards
        if Library.Flags["AutoSell"] and (now - timers.sell) >= 8 then
            timers.sell = now
            pcall(function()
                local threshFlag  = Library.Flags["SellThreshold"]
                local threshName  = type(threshFlag) == "string" and threshFlag
                                 or (type(threshFlag) == "table" and threshFlag[1])
                                 or SELL_DEFAULT
                local threshLevel = getRarityLevel(threshName)

                local toSell = {}
                for _, card in ipairs(getInventory()) do
                    local BLOCKED_IDS = { LocalCard = true, OwnerVulnone = true }
                    local isEligible  = card
                                     and card.id
                                     and card.uuid
                                     and not card.throneCard
                                     and not card.locked
                                     and not BLOCKED_IDS[card.id]

                    if isEligible then
                        local cfg         = CardConfig.Cards[card.id]
                        local cardRarity  = cfg and cfg.Rarity or nil
                        local cardLevel   = getRarityLevel(cardRarity)
                        if cardLevel < threshLevel then
                            table.insert(toSell, card.uuid)
                        end
                    end
                end

                if #toSell > 0 then
                    remotes.SellCards:FireServer(toSell)
                    stats.sold = stats.sold + #toSell
                end
            end)
        end

        -- Auto Delete Packs
        if Library.Flags["AutoDeletePacks"] and (now - timers.delPacks) >= 10 then
            timers.delPacks = now
            pcall(function()
                local flag     = Library.Flags["DeletePacksList"]
                local selected = type(flag) == "table" and flag or {}
                if #selected > 0 and remotes.DeletePacks then
                    remotes.DeletePacks:FireServer(selected)
                end
            end)
        end

        -- Auto Equip Best
        if Library.Flags["AutoEquip"] and (now - timers.equip) >= 8 then
            timers.equip = now
            pcall(equipBest)
        end

        -- Auto Gem Shop
        if Library.Flags["AutoGemShop"] and (now - timers.gemShop) >= 10 then
            timers.gemShop = now
            pcall(function()
                local itemFlag = Library.Flags["GemShopItemUI"]
                local itemKey  = type(itemFlag) == "string" and itemFlag
                              or (type(itemFlag) == "table" and itemFlag[1])
                              or "Lucky Item"
                local itemId   = GEM_SHOP_MAP[itemKey] or "lucky"
                local minGems  = Library.Flags["MinGems"] or MIN_GEMS_DEFAULT

                if getGems() >= minGems then
                    remotes.BuyGemShopItem:FireServer(itemId)
                    stats.gemBuys = stats.gemBuys + 1
                end
            end)
        end

        -- Auto Rebirth
        local rebirthCooldown = Library.Flags["ForceRebirth"] and REBIRTH_CD_FORCE or REBIRTH_CD_NORMAL
        if Library.Flags["AutoRebirth"] and (now - timers.rebirth) >= rebirthCooldown then
            timers.rebirth = now
            pcall(function()
                local shouldRebirth = Library.Flags["ForceRebirth"] or canRebirth()
                if not shouldRebirth then return end

                local levelBefore = getRebirthLevel()
                remotes.Rebirth:FireServer()
                task.wait(1.5)

                if getRebirthLevel() > levelBefore then
                    stats.rebirths = stats.rebirths + 1
                end
            end)
        end
    end
end)

-- ============ UI: SECTIONS ============
local TabFarm    = Setup:CreateSection("Farm & Packs")
local TabPassive = Setup:CreateSection("Passives & Rebirth")
local TabWebhook = Setup:CreateSection("Webhooks")
local TabMisc    = Setup:CreateSection("Misc & Settings")
local TabStats   = Setup:CreateSection("Analytics")

local pList = getPackList()
if #pList == 0 then pList = { "Bronze" } end

-- ============ UI: FARM TAB ============
TabFarm:createLabel({ Name = "Paid Contributor :- aditya44325f", Special = true })

TabFarm:createLabel({ Name = "Plot Automation", Special = true })

TabFarm:createToggle({
    Name        = "Auto Collect Cash",
    flagName    = "AutoCollect",
    Flag        = false,
    Description = "Automatically fires CollectSlot for all active card slots.",
    Callback    = function() end,
})

TabFarm:createSlider({
    Name        = "Collect Delay (Seconds)",
    flagName    = "CollectDelay",
    value       = COLLECT_DEFAULT,
    minValue    = 1,
    maxValue    = 60,
    Description = "How often (in seconds) to collect from each slot.",
    Callback    = function() end,
})

TabFarm:createToggle({
    Name        = "Auto Equip Best Cards",
    flagName    = "AutoEquip",
    Flag        = false,
    Description = "Sorts your inventory by income and equips the highest earners.",
    Callback    = function() end,
})

TabFarm:createToggle({
    Name        = "Auto Sell Cards",
    flagName    = "AutoSell",
    Flag        = false,
    Description = "Sells all cards below the chosen rarity threshold every 8 seconds.",
    Callback    = function() end,
})

TabFarm:createDropdown({
    Name        = "Sell Below Rarity:",
    flagName    = "SellThreshold",
    Flag        = { SELL_DEFAULT },
    List        = rarityList,
    multi       = false,
    Description = "Cards below this rarity will be sold automatically.",
    Callback    = function() end,
})

TabFarm:createLabel({ Name = "Pack Roller Configuration", Special = true })

TabFarm:createToggle({
    Name        = "Custom Script Auto Open",
    flagName    = "AutoOpenPacks",
    Flag        = false,
    Description = "Continuously opens packs from your selected list.",
    Callback    = function() end,
})

local packDropdown = TabFarm:createDropdown({
    Name        = "Select Packs to Open",
    flagName    = "SelectedPacks",
    Flag        = { pList[1] },
    List        = pList,
    multi       = true,
    Description = "Pick which packs to roll. Cycles through all selected.",
    Callback    = function() end,
})

TabFarm:createButton({
    Name        = "Select ALL Packs (To Open)",
    Description = "Adds every available pack to the open queue.",
    Callback    = function()
        pcall(function() packDropdown:Set(pList) end)
        Library.Flags["SelectedPacks"] = pList
        openPackIndex = 1
    end,
})

TabFarm:createSlider({
    Name        = "Custom Pack Delay (0 = Instant)",
    flagName    = "PackDelay",
    value       = 0,
    minValue    = 0,
    maxValue    = 5,
    Description = "Adds a wait between each pack open. 0 = no delay.",
    Callback    = function() end,
})

TabFarm:createLabel({ Name = "Shop & Store Automation", Special = true })

TabFarm:createToggle({
    Name        = "Auto Buy Shop Packs",
    flagName    = "AutoBuyPacks",
    Flag        = false,
    Description = "Buys packs from the shop whenever you can afford them.",
    Callback    = function() end,
})

local buyPackDropdown = TabFarm:createDropdown({
    Name        = "Select Packs to Buy",
    flagName    = "SelectedBuyPacks",
    Flag        = { pList[1] },
    List        = pList,
    multi       = true,
    Description = "Which packs to purchase from the shop.",
    Callback    = function() end,
})

TabFarm:createButton({
    Name        = "Select ALL Shop Packs",
    Description = "Adds every pack to the buy queue.",
    Callback    = function()
        pcall(function() buyPackDropdown:Set(pList) end)
        Library.Flags["SelectedBuyPacks"] = pList
        buyPackIndex = 1
    end,
})

TabFarm:createSlider({
    Name        = "Pack Buy Delay (Seconds)",
    flagName    = "BuyDelay",
    value       = 0,
    minValue    = 0,
    maxValue    = 900,
    Description = "Delay between each shop purchase. 0 = instant.",
    Callback    = function() end,
})

TabFarm:createToggle({
    Name        = "Auto Buy Gem Shop",
    flagName    = "AutoGemShop",
    Flag        = false,
    Description = "Automatically purchases the selected gem shop item.",
    Callback    = function() end,
})

TabFarm:createDropdown({
    Name        = "Target Gem Shop Item",
    flagName    = "GemShopItemUI",
    Flag        = { "Lucky Item" },
    List        = { "Lucky Item", "Auto Equip Best", "Auto Skip", "Inventory +500", "Scarlet Item" },
    multi       = false,
    Description = "Which item to buy from the gem shop.",
    Callback    = function() end,
})

TabFarm:createSlider({
    Name        = "Min Gems to Keep",
    flagName    = "MinGems",
    value       = MIN_GEMS_DEFAULT,
    minValue    = 0,
    maxValue    = 10000,
    Description = "Gem shop purchases only fire if your gems exceed this value.",
    Callback    = function() end,
})

TabFarm:createLabel({ Name = "Inventory Cleanup", Special = true })

TabFarm:createToggle({
    Name        = "Auto Delete Packs",
    flagName    = "AutoDeletePacks",
    Flag        = false,
    Description = "Deletes selected pack types from your inventory every 10 seconds.",
    Callback    = function() end,
})

TabFarm:createDropdown({
    Name        = "Select Packs to Delete",
    flagName    = "DeletePacksList",
    Flag        = { pList[1] },
    List        = pList,
    multi       = true,
    Description = "Packs selected here will be permanently deleted.",
    Warning     = function() return "Deleted packs cannot be recovered." end,
    WarnIf      = function() return Library.Flags["AutoDeletePacks"] == true end,
    Callback    = function() end,
})

-- ============ UI: PASSIVES TAB ============
TabPassive:createLabel({ Name = "Silent Income Generators", Special = true })

TabPassive:createToggle({
    Name        = "Auto Claim Index Gems",
    flagName    = "AutoIndex",
    Flag        = false,
    Description = "Claims all index gems every 15 seconds.",
    Callback    = function() end,
})

TabPassive:createToggle({
    Name        = "Auto Spin Wheel",
    flagName    = "AutoSpin",
    Flag        = false,
    Description = "Spins the wheel and claims free spins every 8 seconds.",
    Callback    = function() end,
})

TabPassive:createToggle({
    Name        = "Auto Daily Rewards",
    flagName    = "AutoDaily",
    Flag        = false,
    Description = "Claims the daily reward every 60 seconds.",
    Callback    = function() end,
})

TabPassive:createToggle({
    Name        = "Auto Offline Rewards",
    flagName    = "AutoOffline",
    Flag        = false,
    Description = "Claims offline reward income every 60 seconds.",
    Callback    = function() end,
})

TabPassive:createLabel({ Name = "Progression & One-Time", Special = true })

TabPassive:createToggle({
    Name        = "Auto Redeem All Codes",
    flagName    = "AutoRedeemCodes",
    Flag        = false,
    Description = "Fetches and redeems all known SSC codes. Runs once per session.",
    Callback    = function() end,
})

TabPassive:createToggle({
    Name        = "Auto Rebirth",
    flagName    = "AutoRebirth",
    Flag        = false,
    Description = "Rebirths automatically when requirements are met.",
    Callback    = function() end,
})

TabPassive:createToggle({
    Name        = "Force Rebirth",
    flagName    = "ForceRebirth",
    Flag        = false,
    Description = "Fires the rebirth remote regardless of requirements.",
    Warning     = function() return "May rebirth before requirements are met." end,
    WarnIf      = function() return Library.Flags["ForceRebirth"] == true end,
    Callback    = function() end,
})

-- ============ UI: WEBHOOKS TAB ============
TabWebhook:createLabel({ Name = "Discord Integration", Special = true })

TabWebhook:createInputBox({
    Name        = "Webhook URL",
    flagName    = "WebhookURL",
    Flag        = "",
    Description = "Paste your Discord channel webhook URL here.",
    Callback    = function(val)
        getgenv().WebhookURL = val
    end,
})

TabWebhook:createInputBox({
    Name        = "Discord User ID",
    flagName    = "WebhookPingID",
    Flag        = "",
    Description = "Paste your Discord User ID to be pinged on rare rolls.",
    Callback    = function(val)
        getgenv().WebhookPingID = tostring(val):gsub("[^%d]", "")
    end,
})

TabWebhook:createLabel({ Name = "Rare Card Tracker", Special = true })

TabWebhook:createToggle({
    Name        = "Enable Rare Rolls Webhook",
    flagName    = "WebhookRareRolls",
    Flag        = false,
    Description = "Sends a Discord embed whenever a card above the threshold is rolled.",
    Callback    = function() end,
})

TabWebhook:createDropdown({
    Name        = "Minimum Rarity to Log",
    flagName    = "WebhookRarityThresh",
    Flag        = { RARITY_THRESH_DEFAULT },
    List        = rarityList,
    multi       = false,
    Description = "Only cards at or above this rarity will trigger the webhook.",
    Callback    = function() end,
})

TabWebhook:createLabel({ Name = "Automated Analytics", Special = true })

TabWebhook:createToggle({
    Name        = "Enable Stats Webhook",
    flagName    = "WebhookStats",
    Flag        = false,
    Description = "Periodically sends session stats to your Discord webhook.",
    Callback    = function() end,
})

TabWebhook:createSlider({
    Name        = "Stats Update Frequency (Mins)",
    flagName    = "WebhookStatsDelay",
    value       = STATS_DELAY_DEFAULT,
    minValue    = 1,
    maxValue    = 60,
    Description = "How many minutes between each stats post.",
    Callback    = function() end,
})

TabWebhook:createButton({
    Name        = "Send Test Webhook",
    Description = "Fires a test message to verify your webhook URL is working.",
    Callback    = function()
        if (getgenv().WebhookURL or "") == "" then
            notify("Webhook", "No webhook URL set.", "warning")
            return
        end
        dispatchWebhook({
            embeds = {{
                title       = "[~] Test Webhook",
                description = "SSC Elite Farm webhook is working correctly.",
                color       = 5763719,
                footer      = { text = "SSC Elite Farm - " .. client.Name },
            }}
        })
        notify("Webhook", "Test sent.", "info")
    end,
})

-- ============ UI: MISC TAB ============
TabMisc:createLabel({ Name = "Game Modifications", Special = true })

TabMisc:createToggle({
    Name        = "Disable Game Popups",
    flagName    = "DisablePopups",
    Flag        = false,
    Description = "Blocks purchase prompts like rebirth and booth popups.",
    Callback    = function() end,
})

TabMisc:createToggle({
    Name        = "Disable Game Notifications",
    flagName    = "DisableNotifs",
    Flag        = false,
    Description = "Hides all in-game notification frames from the PlayerGui.",
    Callback    = function() end,
})

TabMisc:createToggle({
    Name        = "Hide Game HUD",
    flagName    = "HideHUD",
    Flag        = false,
    Description = "Toggles the game's main HUD ScreenGui.",
    Callback    = function(v)
        local playerGui = client:FindFirstChild("PlayerGui")
        if not playerGui then return end
        local hud = playerGui:FindFirstChild("HUD")
        if hud then hud.Enabled = not v end
    end,
})

TabMisc:createLabel({ Name = "Quick Actions", Special = true })

TabMisc:createButton({
    Name        = "Equip Best Cards Now",
    Description = "Immediately runs the equip logic without waiting for the auto loop.",
    Callback    = function()
        local success = equipBest()
        if success then
            notify("Equipped", "Best cards equipped successfully.", "info")
        else
            notify("Equipped", "No upgrades found or already optimal.", "info")
        end
    end,
})

TabMisc:createButton({
    Name        = "Sell Below Threshold Now",
    Description = "Immediately sells all cards below the current rarity threshold.",
    Callback    = function()
        local flag     = Library.Flags and Library.Flags["SellThreshold"]
        local tName    = type(flag) == "table" and flag[1]
                      or (type(flag) == "string" and flag)
                      or SELL_DEFAULT
        local tLevel   = getRarityLevel(tName)
        local toSell   = {}
        local BLOCKED  = { LocalCard = true, OwnerVulnone = true }

        for _, card in ipairs(getInventory()) do
            local isEligible = card
                            and card.id
                            and card.uuid
                            and not card.throneCard
                            and not card.locked
                            and not BLOCKED[card.id]

            if isEligible then
                local cfg   = CardConfig.Cards[card.id]
                if cfg and getRarityLevel(cfg.Rarity) < tLevel then
                    table.insert(toSell, card.uuid)
                end
            end
        end

        if #toSell > 0 then
            pcall(function() remotes.SellCards:FireServer(toSell) end)
            notify("Sold", #toSell .. " cards cleared.", "info")
        else
            notify("Sold", "No cards matched the threshold.", "info")
        end
    end,
})

TabMisc:createButton({
    Name        = "Bug Report",
    Description = "Opens the built-in Versus bug reporter.",
    Callback    = function()
        pcall(function() Library:PromptBugReport() end)
    end,
})

-- ============ UI: STATS TAB ============
TabStats:createLabel({ Name = "Live Session Analytics", Special = true })

local label_cash     = TabStats:createLabel({ Name = "Cash: $0" })
local label_gems     = TabStats:createLabel({ Name = "Gems: 0" })
local label_rebirth  = TabStats:createLabel({ Name = "Rebirth Level: 0" })
local label_opened   = TabStats:createLabel({ Name = "Packs Opened: 0" })
local label_bought   = TabStats:createLabel({ Name = "Packs Bought: 0" })
local label_sold     = TabStats:createLabel({ Name = "Cards Sold: 0" })
local label_collect  = TabStats:createLabel({ Name = "Collects: 0" })
local label_gemBuys  = TabStats:createLabel({ Name = "Gem Buys: 0" })
local label_sRebirth = TabStats:createLabel({ Name = "Session Rebirths: 0" })
local label_weather  = TabStats:createLabel({ Name = "Active Weather: None" })

-- ============ STATS UPDATE LOOP ============
local lastUIUpdate = 0

RunService.Heartbeat:Connect(function()
    local now = os.clock()
    if now - lastUIUpdate < 0.5 then return end
    lastUIUpdate = now

    pcall(function()
        if not (label_cash and label_cash.Set) then return end

        label_cash:Set("Cash: $"              .. formatCash(getCash()))
        label_gems:Set("Gems: "               .. math.floor(getGems()))
        label_rebirth:Set("Rebirth Level: "   .. getRebirthLevel())
        label_opened:Set("Packs Opened: "     .. stats.opened)
        label_bought:Set("Packs Bought: "     .. stats.bought)
        label_sold:Set("Cards Sold: "         .. stats.sold)
        label_collect:Set("Collects: "        .. stats.collects)
        label_gemBuys:Set("Gem Buys: "        .. stats.gemBuys)
        label_sRebirth:Set("Session Rebirths: " .. stats.rebirths)
        label_weather:Set("Active Weather: "  .. getActiveWeathers())
    end)
end)

TabStats:createButton({
    Name        = "Reset Stats",
    Description = "Clears all session counters back to zero.",
    Callback    = function()
        stats = {
            opened        = 0,
            bought        = 0,
            sold          = 0,
            rebirths      = 0,
            gemBuys       = 0,
            collects      = 0,
            codesRedeemed = true,
        }
        notify("Stats", "Session stats have been reset.", "info")
    end,
})

-- ============ DONE ============
print("[SSC Farm] Loaded successfully — SSC Elite Farm v2.0")

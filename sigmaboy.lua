--[[
    REX: REINCARNATION // RAYFIELD PRO ULTIMATE
    ===========================================
    1. Automatic Mine Reset Loop:
       - Listens to Remotes.MineStates.MineResetting & MineRegenerated.
       - Waits until Mine is completely regenerated.
       - Teleports via official GenerateTP remote to Selected Layer or Pre-Reset position!
    2. Real-Time 1M+ Ore & Event Discord Tracker:
       - Hooked into Remotes.WriteToTopBar & ChildAdded for 100% reliable instant detection.
       - Sends Webhook with @user, custom GIF, and exact ore details.
       - Alerts 5 times spaced 30 seconds apart.
       - Option: Stop Mining & Walking when a 1M+ ore spawns.
    3. High-Performance Instant ESP:
       - Renders instantly at extreme distances (up to 5,000m+).
       - Filter presets including dedicated "1M+ Ores Only".
       - Shows Name, Tier, Exact Rarity (e.g. 1/42,100,021), and Distance.
       - GPU-accelerated Highlights (Chams) + Billboard Labels.
    4. Auto Walk Forward, Auto Mine Straight, Auto Use Ability (Keybind: X), and Anti-AFK (20m kick bypass).
--]]

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService       = game:GetService("HttpService")
local VirtualUser       = game:GetService("VirtualUser")
local CollectionService = game:GetService("CollectionService")

local lp = Players.LocalPlayer
repeat task.wait() until lp

if _G.REX_RAYFIELD_CLEANUP then
    pcall(_G.REX_RAYFIELD_CLEANUP)
end

local isScriptAlive = true
local scriptConnections = {}

-- Cleanup Previous Sessions
local activeDrawings = {}
local function clearAllDrawings()
    for part, d in pairs(activeDrawings) do
        pcall(function()
            if d.txt then d.txt.Visible = false; d.txt:Remove() end
            if d.box then d.box.Visible = false; d.box:Remove() end
            if d.boxOutline then d.boxOutline.Visible = false; d.boxOutline:Remove() end
            if d.boxFill then d.boxFill.Visible = false; d.boxFill:Remove() end
        end)
        activeDrawings[part] = nil
    end
end

_G.REX_RAYFIELD_CLEANUP = function()
    isScriptAlive = false
    for _, conn in ipairs(scriptConnections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(scriptConnections)
    clearAllDrawings()
end

-- Game Remotes & Data Modules
local Remotes        = ReplicatedStorage:WaitForChild("Remotes", 10)
local MineRemote     = Remotes and Remotes:FindFirstChild("SetPlayerMineRay")
local MineStates     = Remotes and Remotes:FindFirstChild("MineStates")
local GenerateTP     = Remotes and Remotes:FindFirstChild("GenerateTP")
local WriteToTopBar  = Remotes and Remotes:FindFirstChild("WriteToTopBar")

-- Metamethod protection: Prevents the game's default PickaxeClientScript from sending SetPlayerMineRay(false) during active autofarming
local isAutoMining = false
pcall(function()
    if hookmetamethod and checkcaller and newcclosure then
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if not checkcaller() and method == "FireServer" and self == MineRemote then
                local args = {...}
                if isAutoMining and args[1] == false then
                    return
                end
            end
            return oldNamecall(self, ...)
        end))
    end
end)

local GameInfo = nil
pcall(function()
    GameInfo = require(ReplicatedStorage.Modules.GameInformation)
end)

local function getGI()
    if GameInfo then return GameInfo end
    pcall(function() GameInfo = require(ReplicatedStorage.Modules.GameInformation) end)
    return GameInfo
end

-- Official Teleportation Board Layers
local BoardLayers = {
    ["Pre-Reset Location (Last Position)"] = "Prev",
    ["Basalt Layer"]                       = "region_basalt",
    ["Granite Layer"]                      = "region_granite",
    ["Diorite Layer"]                      = "region_diorite",
    ["Obsidian Layer"]                     = "region_obsidian",
    ["Marble Layer"]                       = "region_marble",
    ["Mantle Layer"]                       = "region_mantle",
    ["Outer Core Layer"]                   = "region_outer_core",
    ["Inner Core Layer"]                   = "region_inner_core",
    ["Surface (Top)"]                      = "region_surface",
    ["Stone Layer"]                        = "region_stone",
}

local BoardLayerNames = {
    "Pre-Reset Location (Last Position)",
    "Basalt Layer",
    "Granite Layer",
    "Diorite Layer",
    "Obsidian Layer",
    "Marble Layer",
    "Mantle Layer",
    "Outer Core Layer",
    "Inner Core Layer",
    "Surface (Top)",
    "Stone Layer"
}

-- Tier Registry & Color Utilities (Vibrant High-Visibility Neon Palette)
local TierColors = {
    [1]  = Color3.fromRGB(160, 160, 160), -- Layer
    [2]  = Color3.fromRGB(200, 200, 200), -- Common
    [3]  = Color3.fromRGB(255, 65,  65),  -- Uncommon
    [4]  = Color3.fromRGB(255, 140, 20),  -- Rare
    [5]  = Color3.fromRGB(175, 45,  255), -- Master
    [6]  = Color3.fromRGB(30,  230, 180), -- Surreal
    [7]  = Color3.fromRGB(255, 40,  240), -- Mythic
    [8]  = Color3.fromRGB(255, 215, 50),  -- Exotic (10k+)
    [9]  = Color3.fromRGB(60,  245, 120), -- Exquisite
    [10] = Color3.fromRGB(0,   215, 255), -- Transcendent (1M+)
    [11] = Color3.fromRGB(220, 255, 20),  -- Enigmatic (73M+)
    [12] = Color3.fromRGB(0,   240, 255), -- Unfathomable (276M+ Neon Cyan)
    [13] = Color3.fromRGB(255, 20,  160), -- Otherworldly (Neon Vivid Magenta)
    [14] = Color3.fromRGB(255, 240, 140), -- Imaginary (Glowing Gold)
    [15] = Color3.fromRGB(255, 255, 255), -- Zenith (Pure Bright White)
    [16] = Color3.fromRGB(200, 80,  255), -- Exclusive (Radiant Ultraviolet)
}

local TierNamesToNum = {
    ["Layer"] = 1, ["Common"] = 2, ["Uncommon"] = 3, ["Rare"] = 4,
    ["Master"] = 5, ["Surreal"] = 6, ["Mythic"] = 7, ["Exotic"] = 8,
    ["Exquisite"] = 9, ["Transcendent"] = 10, ["Enigmatic"] = 11,
    ["Unfathomable"] = 12, ["Otherworldly"] = 13, ["Imaginary"] = 14,
    ["Zenith"] = 15, ["Exclusive"] = 16
}

local function formatNum(n)
    if not n or n == 0 then return "0" end
    local formatted = tostring(math.floor(n))
    while true do
        local k
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

local oreInfoCache = {}
local function getOreInfo(partOrName)
    local rawName = type(partOrName) == "string" and partOrName or (partOrName and partOrName.Name)
    if not rawName then return {name = "Unknown", tierNum = 1, tierName = "Layer", color = TierColors[1], rarityText = "1/1", rarityNum = 1} end
    
    local nameLower = rawName:lower()
    if oreInfoCache[nameLower] then return oreInfoCache[nameLower] end

    local GI = getGI()
    local oreData = GI and GI.ores and (GI.ores[rawName] or GI.ores[nameLower])
    local finalName = (oreData and oreData.name) or rawName:gsub("_", " "):gsub("(%a)([%w_']*)", function(f, r) return f:upper() .. r:lower() end)
    local tierName = (oreData and oreData.tier and type(oreData.tier) == "table" and oreData.tier.name) or (oreData and type(oreData.tier) == "string" and oreData.tier) or "Common"
    local tierNum = (oreData and oreData.tier and type(oreData.tier) == "table" and oreData.tier.tierNum) or (TierNamesToNum[tierName] or 2)
    local color = TierColors[tierNum] or Color3.fromRGB(193, 193, 193)

    local baseRarityNum = (oreData and oreData.spawnInfo and oreData.spawnInfo.rarityRepresentation) or 0
    local rarityText = (oreData and oreData.spawnInfo and oreData.spawnInfo.rarityText) or nil

    if not rarityText and baseRarityNum > 0 then
        rarityText = "1/" .. formatNum(baseRarityNum)
    elseif rarityText and not rarityText:find("^1/") and baseRarityNum > 0 then
        rarityText = "1/" .. rarityText
    elseif not rarityText then
        rarityText = tierNum >= 8 and ("1/" .. formatNum(10000 * (tierNum - 7))) or ("Tier " .. tierNum)
    end

    local res = {
        name = finalName,
        tierName = tierName,
        tierNum = tierNum,
        color = color,
        rarityText = rarityText,
        rarityNum = baseRarityNum
    }
    oreInfoCache[nameLower] = res
    return res
end

local CommonLayerBlocks = {
    ["stone"] = true, ["granite"] = true, ["diorite"] = true,
    ["basalt"] = true, ["marble"] = true, ["space_rock"] = true,
    ["mantle"] = true, ["outer_core"] = true, ["inner_core"] = true,
    ["bedrock"] = true, ["sand"] = true, ["dirt"] = true, ["grass"] = true
}

-- Core Script Configuration
local Cfg = {
    AutoMine                = false,
    AutoTPResetLoop         = true,
    TargetResetLayer        = "Pre-Reset Location (Last Position)",
    AutoTPOre               = false,
    AutoTP1M                = false,
    ReturnToOldPos          = true,
    ReturnToOldPosTarget    = true,
    CustomTPCoords          = "",
    DrillDown               = false,
    DrillStopY              = 0,
    AutoWalkForward         = false,
    AutoMineStraight        = false,
    AutoUseAbility          = false,
    AbilityKeybind          = Enum.KeyCode.X,
    AntiAFK                 = true,
    StopOn1MSpawn           = true,
    LegitMining             = false,
    ContinueFrom1MPos       = false,
    -- 1M+ Hunter & Layer Rotation System
    HunterMode              = "Smart Hybrid (Recommended)",
    HunterSniffOnReset      = true,
    HunterPrioritizeEvents  = true,
    HunterTargetOre         = "Chrysalis",
    RouletteLayers          = {
        "Mantle Layer",
        "Inner Core Layer",
        "Outer Core Layer",
        "Granite Layer",
        "Obsidian Layer",
        "Marble Layer",
        "Basalt Layer",
        "Diorite Layer"
    },
    RouletteIndex           = 1,
    ESPEnabled              = true,
    ESPChams                = true,
    ESPFilter               = "1M+ Ores Only",
    ESPMaxDist              = 25000,
    -- Independent Multi-Webhook System
    WebhookURL_1M           = "",
    WebhookURL_Progress     = "",
    WebhookURL_Reset        = "",
    WebhookURL_Events       = "",
    WebhookURL_General      = "",
    WebhookURL              = "", -- Fallback
    WebhookInterval         = 300,
    AutoWebhookProgress     = false,
    WebhookResetAlerts      = true,
    Webhook1MAlerts         = true,
    WebhookEventAlerts      = true,
    EventWebhookLogs        = true,
    EventWebhookInterval    = 300,
    LegitSteering           = true,
    HumanizedJitter         = true,
    StealthMode             = false,
    StealthRadius           = 35,
    PingUserOnEvent         = true,
    DiscordUserId           = "",
}

-- ============================================================
-- EXECUTOR CONFIGURATION SYSTEM (workspace/REXOverhub/config.json)
-- ============================================================
local CONFIG_FOLDER = "REXOverhub"
local CONFIG_FILE = "REXOverhub/config.json"

local function saveConfig()
    if not writefile then return false end
    local success = pcall(function()
        if makefolder and not isfolder(CONFIG_FOLDER) then
            makefolder(CONFIG_FOLDER)
        end
        local saveTable = {
            AutoMine            = Cfg.AutoMine,
            AutoMineStraight    = Cfg.AutoMineStraight,
            AutoWalkForward     = Cfg.AutoWalkForward,
            AutoTPResetLoop     = Cfg.AutoTPResetLoop,
            TargetResetLayer    = Cfg.TargetResetLayer,
            AutoTPOre           = Cfg.AutoTPOre,
            AutoTP1M            = Cfg.AutoTP1M,
            ReturnToOldPos      = Cfg.ReturnToOldPos,
            ReturnToOldPosTarget = Cfg.ReturnToOldPosTarget,
            LegitMining         = Cfg.LegitMining,
            ContinueFrom1MPos   = Cfg.ContinueFrom1MPos,
            HunterMode          = Cfg.HunterMode,
            HunterSniffOnReset  = Cfg.HunterSniffOnReset,
            HunterPrioritizeEvents = Cfg.HunterPrioritizeEvents,
            HunterTargetOre     = Cfg.HunterTargetOre,
            RouletteLayers      = Cfg.RouletteLayers,
            RouletteIndex       = Cfg.RouletteIndex,
            CustomTPCoords      = Cfg.CustomTPCoords,
            DrillDown           = Cfg.DrillDown,
            DrillStopY          = Cfg.DrillStopY,
            AutoUseAbility      = Cfg.AutoUseAbility,
            AntiAFK             = Cfg.AntiAFK,
            StopOn1MSpawn       = Cfg.StopOn1MSpawn,
            ESPEnabled          = Cfg.ESPEnabled,
            ESPChams            = Cfg.ESPChams,
            ESPFilter           = Cfg.ESPFilter,
            ESPMaxDist          = Cfg.ESPMaxDist,
            WebhookURL_1M       = Cfg.WebhookURL_1M,
            WebhookURL_Progress = Cfg.WebhookURL_Progress,
            WebhookURL_Reset    = Cfg.WebhookURL_Reset,
            WebhookURL_Events   = Cfg.WebhookURL_Events,
            WebhookURL_General  = Cfg.WebhookURL_General,
            WebhookInterval     = Cfg.WebhookInterval,
            AutoWebhookProgress = Cfg.AutoWebhookProgress,
            WebhookResetAlerts  = Cfg.WebhookResetAlerts,
            Webhook1MAlerts     = Cfg.Webhook1MAlerts,
            WebhookEventAlerts  = Cfg.WebhookEventAlerts,
            EventWebhookLogs    = Cfg.EventWebhookLogs,
            EventWebhookInterval = Cfg.EventWebhookInterval,
            LegitSteering       = Cfg.LegitSteering,
            HumanizedJitter     = Cfg.HumanizedJitter,
            StealthMode         = Cfg.StealthMode,
            StealthRadius       = Cfg.StealthRadius,
            PingUserOnEvent     = Cfg.PingUserOnEvent,
            DiscordUserId       = Cfg.DiscordUserId,
        }
        writefile(CONFIG_FILE, HttpService:JSONEncode(saveTable))
    end)
    return success
end

local function loadConfig()
    if not readfile or not isfile or not isfile(CONFIG_FILE) then
        saveConfig()
        return false
    end
    local success, content = pcall(readfile, CONFIG_FILE)
    if not success or not content or content == "" then return false end

    local successDecode, decoded = pcall(function()
        return HttpService:JSONDecode(content)
    end)
    if not successDecode or type(decoded) ~= "table" then return false end

    for k, v in pairs(decoded) do
        if Cfg[k] ~= nil then
            Cfg[k] = v
        end
    end
    return true
end

-- Load saved config immediately
loadConfig()

-- ============================================================
-- LIVE GAME STATS & REPLICA RECEIVER
-- ============================================================
local Stats = {
    Start = os.clock(),
    InitialMined = 0,
    SessionMined = 0,
}

local function getReplicaData()
    local res = nil
    pcall(function()
        local ClientUtils = require(game:GetService("ReplicatedStorage").Modules.Utils.ClientUtils)
        local rep = ClientUtils.getReplica()
        if rep and rep.Data then
            res = rep.Data
        end
    end)
    return res
end

local function getMinedStats()
    local repData = getReplicaData()
    local currentTotal = (repData and repData.mined and type(repData.mined) == "number") and repData.mined or 0
    if Stats.InitialMined == 0 and currentTotal > 0 then
        Stats.InitialMined = currentTotal
    end
    local sessionMined = (currentTotal > 0 and Stats.InitialMined > 0) and math.max(0, currentTotal - Stats.InitialMined) or Stats.SessionMined
    return sessionMined, currentTotal
end

-- Hook live replica changes for instant event updates
pcall(function()
    local ClientUtils = require(game:GetService("ReplicatedStorage").Modules.Utils.ClientUtils)
    local rep = ClientUtils.getReplica()
    if rep then
        if rep.Data and type(rep.Data.mined) == "number" and rep.Data.mined > 0 then
            Stats.InitialMined = rep.Data.mined
        end
        rep:ListenToChange("mined", function(newMined)
            if type(newMined) == "number" then
                if Stats.InitialMined == 0 then
                    Stats.InitialMined = newMined
                end
                Stats.SessionMined = math.max(0, newMined - Stats.InitialMined)
            end
        end)
    end
end)

local function getCurrentLayer()
    local pGui = lp:FindFirstChild("PlayerGui")
    if pGui then
        local coreUI = pGui:FindFirstChild("CoreGameplayUI")
        local selOre = coreUI and coreUI:FindFirstChild("SelectedOre")
        local tb = selOre and selOre:FindFirstChild("TextBox")
        if tb and tb.Text and tb.Text ~= "" then
            return tb.Text
        end
    end
    return Cfg.TargetResetLayer
end

local function getCurrentDepth()
    local pGui = lp:FindFirstChild("PlayerGui")
    if pGui then
        local topBar = pGui:FindFirstChild("TopBar")
        local mainH = topBar and topBar:FindFirstChild("TopBar") and topBar.TopBar:FindFirstChild("StatsHolder") and topBar.TopBar.StatsHolder:FindFirstChild("MainHolder")
        local dText = mainH and mainH:FindFirstChild("Depth") and mainH.Depth:FindFirstChild("Text")
        if dText and dText.Text ~= "" then
            return dText.Text
        end
    end
    local root = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    return root and string.format("%.0fm", math.abs(root.Position.Y)) or "Unknown"
end

local function getMineCapacity()
    local pGui = lp:FindFirstChild("PlayerGui")
    if pGui then
        local topBar = pGui:FindFirstChild("TopBar")
        local mainH = topBar and topBar:FindFirstChild("TopBar") and topBar.TopBar:FindFirstChild("StatsHolder") and topBar.TopBar.StatsHolder:FindFirstChild("MainHolder")
        local cText = mainH and mainH:FindFirstChild("Capacity") and mainH.Capacity:FindFirstChild("Text")
        if cText and cText.Text ~= "" then
            return cText.Text
        end
    end
    return "Unknown"
end

local function getEquippedPickaxe()
    local pick = nil
    pcall(function()
        local repData = getReplicaData()
        if repData and repData.equippedPickaxe then
            pick = tostring(repData.equippedPickaxe):gsub("_", " "):gsub("(%a)([%w_']*)", function(f, r) return f:upper() .. r:lower() end)
        end
    end)
    return pick or "None"
end

local isResetWaiting = false
local rareOreSpawnedActive = false
local lockedWalkDir = nil
local sendWebhook = nil
local handleRareOreSpawned = nil

-- Official Board Teleport Function
local function teleportViaBoard(layerName)
    local code = BoardLayers[layerName]
    if code and GenerateTP then
        pcall(function()
            GenerateTP:FireServer(code)
        end)
        return true
    end
    return false
end

-- Coordinate Parsing & Direct Teleport Functions
local function parseCoords(str)
    if not str or str == "" then return nil end
    local clean = str:gsub("[Vector3CFramenw%s%(%){}]", " ")
    local nums = {}
    for n in clean:gmatch("[-+]?%d+%.?%d*") do
        table.insert(nums, tonumber(n))
    end
    if #nums >= 3 then
        return Vector3.new(nums[1], nums[2], nums[3])
    end
    return nil
end

-- Safe Teleport System (Zero Momentum + Atomic PivotTo)
local function safeTeleport(pos, offset, lookAt)
    local char = lp.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum or not pos then return false end

    offset = offset or Vector3.new(0, 3.6, 0)
    local targetPos = pos + offset

    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    lockedWalkDir = nil

    if lookAt then
        char:PivotTo(CFrame.new(targetPos, Vector3.new(lookAt.X, targetPos.Y, lookAt.Z)))
    else
        char:PivotTo(CFrame.new(targetPos))
    end
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero

    return true
end

local teleportToPosition = safeTeleport

-- ============================================================
-- GLOBAL RARE ORE REGISTRY & DYNAMIC SCANNER (ALL LAYERS & EVENTS)
-- ============================================================
local rareOresRegistry = {}
local isScanningMine = false
local scanOresForESP = nil

-- Area, Layer & Ownership Utilities
local function getRegionName(regKey)
    if not regKey or regKey == "" then return "Unknown Layer" end
    local GI = getGI()
    if GI and GI.regions then
        for worldName, worldTable in pairs(GI.regions) do
            if type(worldTable) == "table" and worldName ~= "centroids" then
                local entry = worldTable[regKey]
                if type(entry) == "table" and entry.name then
                    return entry.name
                end
            end
        end
    end
    local clean = tostring(regKey):gsub("^region_", ""):gsub("_", " "):gsub("(%a)([%w_']*)", function(f, r) return f:upper() .. r:lower() end)
    return clean .. (clean:lower():find("layer") and "" or " Layer")
end

local function getAreaFromPosition(pos)
    if not pos then return "Unknown Area", "Unknown Depth" end
    local regKey = nil
    local depthStr = string.format("%.0fm", math.abs(pos.Y))
    pcall(function()
        local GenUtils = require(ReplicatedStorage.Modules.Utils.GenerationUtils)
        if GenUtils then
            if GenUtils.getRegionGivenPosition then
                regKey = GenUtils.getRegionGivenPosition(pos)
            end
            if GenUtils.toMapDepth then
                local d = GenUtils.toMapDepth(pos.Y)
                if d then depthStr = string.format("%sm", formatNum(d)) end
            end
        end
    end)
    local regionName = getRegionName(regKey)
    return regionName, depthStr
end

local function getOreOwnership(part)
    if not part or not part.Parent then return "invalid", nil, "Unknown" end
    local ownerId = part:GetAttribute("owner")
    if not ownerId then
        -- In case attribute replicates a split frame after ChildAdded
        task.wait(0.04)
        if not part or not part.Parent then return "invalid", nil, "Unknown" end
        ownerId = part:GetAttribute("owner")
    end
    if ownerId then
        local p = Players:GetPlayerByUserId(ownerId)
        local pName = p and p.Name
        if not pName then
            pcall(function() pName = Players:GetNameFromUserIdAsync(ownerId) end)
        end
        pName = pName or ("ID: " .. tostring(ownerId))

        if ownerId == lp.UserId then
            return "mine", ownerId, pName
        else
            return "other", ownerId, pName
        end
    end
    return "public", nil, "Public / World Spawn"
end

local function registerRareOre(part)
    if not part or not part.Parent then return false end
    local rawName = part.Name
    local nLower = rawName:lower()
    if CommonLayerBlocks[nLower] then return false end

    local info = getOreInfo(rawName)
    local is1M = (info.rarityNum >= 1000000 or info.tierNum >= 10)
    local is100k = (info.rarityNum >= 100000 or info.tierNum >= 9)
    local is10k = (info.rarityNum >= 10000 or info.tierNum >= 8)
    local isRare = (info.tierNum >= 4 or info.rarityNum >= 1000)

    if isRare or is10k or is100k or is1M then
        local cPos = part:IsA("BasePart") and part.Position or (part:IsA("Model") and part:GetPivot().Position)
        local pSize = part:IsA("BasePart") and part.Size or (part:IsA("Model") and part:GetExtentsSize())
        if not cPos then return false end

        local ownership, ownerId, ownerName = getOreOwnership(part)

        rareOresRegistry[part] = {
            part = part,
            pos = cPos,
            size = pSize or Vector3.new(4, 4, 4),
            info = info,
            is1M = is1M,
            is100k = is100k,
            is10k = is10k,
            isRare = isRare,
            ownership = ownership,
            ownerId = ownerId,
            ownerName = ownerName
        }

        part.AncestryChanged:Connect(function(_, parent)
            if not parent then
                rareOresRegistry[part] = nil
                local dObj = activeDrawings[part]
                if dObj then
                    pcall(function()
                        if dObj.txt then dObj.txt.Visible = false; dObj.txt:Remove() end
                        if dObj.box then dObj.box.Visible = false; dObj.box:Remove() end
                        if dObj.boxOutline then dObj.boxOutline.Visible = false; dObj.boxOutline:Remove() end
                        if dObj.boxFill then dObj.boxFill.Visible = false; dObj.boxFill:Remove() end
                    end)
                    activeDrawings[part] = nil
                end
            end
        end)

        return true, info, is1M, cPos, ownership, ownerName
    end
    return false
end

local function populateRareOresRegistry()
    if isScanningMine then return end
    isScanningMine = true

    -- 1. Placed ores and blocks
    for _, folderName in ipairs({"PlacedOres", "PlacedBlocks"}) do
        local folder = workspace:FindFirstChild(folderName)
        if folder then
            for _, item in ipairs(folder:GetChildren()) do
                registerRareOre(item)
            end
        end
    end

    -- 2. Tagged ScriptedOre
    for _, item in ipairs(CollectionService:GetTagged("ScriptedOre")) do
        registerRareOre(item)
    end

    -- 3. Asynchronous chunked scan over workspace.Mine (zero frame stutter)
    task.spawn(function()
        local mine = workspace:FindFirstChild("Mine")
        if not mine then isScanningMine = false; return end
        local children = mine:GetChildren()
        local total = #children
        local batchSize = 15000

        for i = 1, total, batchSize do
            if not isScriptAlive or isResetWaiting then break end
            local maxI = math.min(i + batchSize - 1, total)
            for idx = i, maxI do
                local part = children[idx]
                if part and part:IsA("BasePart") then
                    local nLower = part.Name:lower()
                    if not CommonLayerBlocks[nLower] then
                        registerRareOre(part)
                    end
                end
            end
            task.wait()
        end
        isScanningMine = false
        if scanOresForESP then scanOresForESP() end
    end)
end

local function teleportToClosestRareOre()
    local char = lp.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false, "No character found" end

    local bestOre = nil
    local bestDist = math.huge

    for part, data in pairs(rareOresRegistry) do
        if part and part.Parent and data.is1M then
            local cPos = data.pos or (part:IsA("BasePart") and part.Position)
            if cPos then
                local d = (cPos - root.Position).Magnitude
                if d < bestDist then
                    bestDist = d
                    bestOre = {name = data.info.name, pos = cPos, dist = d, rarity = data.info.rarityText}
                end
            end
        end
    end

    if bestOre then
        safeTeleport(bestOre.pos, Vector3.new(0, 5.5, 0))
        return true, string.format("Teleported to %s [%s] (%.0fm away)!", bestOre.name, bestOre.rarity, bestOre.dist)
    end
    return false, "No 1M+ rare ores currently spawned on the map."
end

-- ============================================================
-- AUTOMATIC MINE RESET & REGENERATION LOOP & WEBHOOKS
-- ============================================================
local wasWalkingBeforeReset = false
local wasMiningBeforeReset = false
local wasMiningStraightBeforeReset = false

local function updateWalkState(enabled)
    Cfg.AutoWalkForward = enabled
    if not enabled then
        lockedWalkDir = nil
        local char = lp.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum:Move(Vector3.zero, false) end
    else
        local char = lp.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then
            local look = root.CFrame.LookVector
            local flat = Vector3.new(look.X, 0, look.Z)
            lockedWalkDir = flat.Magnitude > 0.001 and flat.Unit or Vector3.new(0, 0, -1)
        end
    end
end

-- ============================================================
-- MULTI-CHANNEL DISCORD WEBHOOK ENGINE
-- ============================================================
local GIF_URL = "https://i.pinimg.com/originals/60/75/0d/60750dbe8cf4d1da3446fbee8c2aeea1.gif"

local function getWebhookURL(category)
    if category == "1M" and Cfg.WebhookURL_1M ~= "" then return Cfg.WebhookURL_1M end
    if category == "Progress" and Cfg.WebhookURL_Progress ~= "" then return Cfg.WebhookURL_Progress end
    if category == "Reset" and Cfg.WebhookURL_Reset ~= "" then return Cfg.WebhookURL_Reset end
    if category == "Events" and Cfg.WebhookURL_Events ~= "" then return Cfg.WebhookURL_Events end
    if category == "Events" and Cfg.WebhookURL_1M ~= "" then return Cfg.WebhookURL_1M end
    if Cfg.WebhookURL_General ~= "" then return Cfg.WebhookURL_General end
    if Cfg.WebhookURL ~= "" then return Cfg.WebhookURL end
    return ""
end

sendWebhook = function(category, customTitle, customDetail, is1MAlert, extraFields)
    local targetURL = getWebhookURL(category)
    if not targetURL or targetURL == "" then return end
    local req = (syn and syn.request) or http_request or (fluxus and fluxus.request) or request
    if not req then return end

    local elapsed = math.max(1, math.floor(os.clock() - Stats.Start))
    local minutes = math.max(0.1, elapsed / 60)
    local hours = math.max(0.01, elapsed / 3600)

    local sessionMined, totalMined = getMinedStats()
    local oresPerMin = string.format("%.1f", sessionMined / minutes)
    local oresPerHour = formatNum(sessionMined / hours)
    local timeStr = string.format("%02d:%02d:%02d", math.floor(elapsed/3600), math.floor((elapsed%3600)/60), elapsed%60)
    local curLayer = getCurrentLayer()
    local curDepth = getCurrentDepth()
    local curCapacity = getMineCapacity()
    local pickaxe = getEquippedPickaxe()

    local mention = ""
    if is1MAlert and Cfg.PingUserOnEvent then
        mention = Cfg.DiscordUserId ~= "" and ("<@" .. Cfg.DiscordUserId .. "> ") or "@everyone "
    end

    local color = 0x4A6FA5
    local botName = "REX Reincarnation"
    if category == "1M" then
        color = 0xFF0044
        botName = "REX 1M+ Ore Tracker"
    elseif category == "Events" then
        color = 0x9B59B6
        botName = "REX World Events"
    elseif category == "Reset" then
        color = 0xFFA500
        botName = "REX Mine Reset Watchdog"
    elseif category == "Progress" then
        color = 0x00D668
        botName = "REX Mining Progress"
    end

    local fields = {}
    if extraFields and type(extraFields) == "table" then
        for _, f in ipairs(extraFields) do
            table.insert(fields, f)
        end
    end
    table.insert(fields, {name = "Event Status", value = customDetail or "Notification Triggered", inline = false})
    table.insert(fields, {name = "Session Duration", value = timeStr, inline = true})
    table.insert(fields, {name = "Session Mined", value = string.format("%s (%s/min | %s/hr)", formatNum(sessionMined), oresPerMin, oresPerHour), inline = true})
    table.insert(fields, {name = "Total All-Time Mined", value = formatNum(totalMined), inline = true})
    table.insert(fields, {name = "Current Layer", value = curLayer, inline = true})
    table.insert(fields, {name = "Depth / Capacity", value = string.format("%s | %s", curDepth, curCapacity), inline = true})
    table.insert(fields, {name = "Equipped Pickaxe", value = pickaxe, inline = true})

    local payload = {
        content = mention ~= "" and (mention .. "**" .. customTitle .. "**") or nil,
        username = botName,
        embeds = {{
            title = customTitle or "REX Notification",
            color = color,
            thumbnail = { url = GIF_URL },
            fields = fields,
            footer = { text = "REX Reincarnation | Account: " .. lp.Name }
        }}
    }

    task.spawn(function()
        pcall(function()
            req({
                Url = targetURL,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = HttpService:JSONEncode(payload)
            })
        end)
    end)
end

-- Periodic Mining Progress Background Loop
task.spawn(function()
    while isScriptAlive do
        task.wait(Cfg.WebhookInterval or 300)
        if Cfg.AutoWebhookProgress then
            local sMined, tMined = getMinedStats()
            sendWebhook("Progress", "Mining Progress Report", string.format("Session active. Mined this session: %s | Total: %s", formatNum(sMined), formatNum(tMined)), false)
        end
    end
end)

-- ============================================================
-- 1M+ HUNTER: EVENT BUFFS, LAYER ROULETTE & MAP RESET SNIFFER
-- ============================================================
local EventToLayerMap = {
    ["spristium"]          = "Granite Layer",
    ["quandrium"]          = "Diorite Layer",
    ["candilium"]          = "Inner Core Layer",
    ["cleopatrite"]        = "Outer Core Layer",
    ["blazuine"]           = "Obsidian Layer",
    ["inclemetite"]        = "Basalt Layer",
    ["euclideum"]          = "Mantle Layer",
    ["u_omega"]            = "Inner Core Layer",
    ["idolium"]            = "Marble Layer",
    ["sentient_viscera"]   = "Obsidian Layer",
    ["inkonium"]           = "Obsidian Layer",
    ["combustal"]          = "Outer Core Layer",
    ["vitrilyx"]           = "Mantle Layer",
    ["pastelorium"]        = "Stone Layer",
    ["vaporwave_crystal"]  = "Stone Layer",
    ["lucidium"]           = "Diorite Layer",
    ["temporum"]           = "Marble Layer",
    ["magnetyx"]           = "Mantle Layer",
    ["illusory_bubblegram"]= "Diorite Layer",
}

local OreToLayerMap = {
    -- Inner Core (10)
    ["Chrysalis"] = "Inner Core Layer",
    ["Valkyrie"] = "Inner Core Layer",
    ["Elbrus' Pride"] = "Inner Core Layer",
    ["Ω"] = "Inner Core Layer",
    ["Xynarium"] = "Inner Core Layer",
    ["Vulkavium"] = "Inner Core Layer",
    ["Emberstyx"] = "Inner Core Layer",
    ["Infernus Flammea"] = "Inner Core Layer",
    ["Accretium"] = "Inner Core Layer",
    ["Thundarian"] = "Inner Core Layer",
    -- Outer Core (9)
    ["Dynamo of Fate"] = "Outer Core Layer",
    ["Gargantium"] = "Outer Core Layer",
    ["Dyronsinite"] = "Outer Core Layer",
    ["Cleopatrite"] = "Outer Core Layer",
    ["Suncindium"] = "Outer Core Layer",
    ["Bonfire"] = "Outer Core Layer",
    ["Heatnado"] = "Outer Core Layer",
    ["Combustal"] = "Outer Core Layer",
    ["Flaeon"] = "Outer Core Layer",
    -- Mantle (10)
    ["Scribbal"] = "Mantle Layer",
    ["Glitzar"] = "Mantle Layer",
    ["Magnetyx"] = "Mantle Layer",
    ["Albinite"] = "Mantle Layer",
    ["Exoretic"] = "Mantle Layer",
    ["Scarfyte"] = "Mantle Layer",
    ["Euclideum"] = "Mantle Layer",
    ["Vitrilyx"] = "Mantle Layer",
    ["Polonium"] = "Mantle Layer",
    ["Poiseon"] = "Mantle Layer",
    -- Granite (9)
    ["Terratomere"] = "Granite Layer",
    ["Candilium"] = "Granite Layer",
    ["Runealith"] = "Granite Layer",
    ["Erodimium"] = "Granite Layer",
    ["Spristium"] = "Granite Layer",
    ["Elegascene"] = "Granite Layer",
    ["Oviridis"] = "Granite Layer",
    ["Astatine"] = "Granite Layer",
    ["Elexinite"] = "Granite Layer",
    -- Obsidian (9)
    ["Nyctophyte"] = "Obsidian Layer",
    ["Ravenmare"] = "Obsidian Layer",
    ["Inkonium"] = "Obsidian Layer",
    ["Sentient Viscera"] = "Obsidian Layer",
    ["Speatrium"] = "Obsidian Layer",
    ["Formidulus"] = "Obsidian Layer",
    ["Obscuralis"] = "Obsidian Layer",
    ["Blazuine"] = "Obsidian Layer",
    ["Exolite"] = "Obsidian Layer",
    -- Marble (9)
    ["Idolium"] = "Marble Layer",
    ["Musereign"] = "Marble Layer",
    ["Elementium"] = "Marble Layer",
    ["Luminatite"] = "Marble Layer",
    ["Trinitium"] = "Marble Layer",
    ["Aether"] = "Marble Layer",
    ["Ornalium"] = "Marble Layer",
    ["Temporum"] = "Marble Layer",
    ["Photoprisma"] = "Marble Layer",
    -- Basalt (8)
    ["Inclemetite"] = "Basalt Layer",
    ["Bulbalescense"] = "Basalt Layer",
    ["Cybernetium"] = "Basalt Layer",
    ["Glacielle"] = "Basalt Layer",
    ["Azuryl"] = "Basalt Layer",
    ["Nauticalis"] = "Basalt Layer",
    ["Snoblintium"] = "Basalt Layer",
    ["Freon"] = "Basalt Layer",
    -- Diorite (8)
    ["Illusory Bubblegram"] = "Diorite Layer",
    ["Eclipsicle"] = "Diorite Layer",
    ["Polarium"] = "Diorite Layer",
    ["Lucidium"] = "Diorite Layer",
    ["Quandrium"] = "Diorite Layer",
    ["Acceleratium"] = "Diorite Layer",
    ["Monocage"] = "Diorite Layer",
    ["Neptunium"] = "Diorite Layer",
    -- Stone (8)
    ["Endozivite"] = "Stone Layer",
    ["Vaporwave Crystal"] = "Stone Layer",
    ["Gradience"] = "Stone Layer",
    ["Pastelorium"] = "Stone Layer",
    ["Pasivium"] = "Stone Layer",
    ["Penumbrosia"] = "Stone Layer",
    ["Scertanium"] = "Stone Layer",
    ["Aegistone"] = "Stone Layer",
}

local OreList1M = {
    "Chrysalis", "Dynamo of Fate", "Nyctophyte", "Valkyrie", "Illusory Bubblegram",
    "Inclemetite", "Endozivite", "Terratomere", "Scribbal", "Idolium",
    "Glitzar", "Vaporwave Crystal", "Candilium", "Elbrus' Pride", "Bulbalescense",
    "Ravenmare", "Ω", "Magnetyx", "Musereign", "Gargantium",
    "Inkonium", "Dyronsinite", "Gradience", "Runealith", "Elementium",
    "Eclipsicle", "Cybernetium", "Polarium", "Pastelorium", "Albinite",
    "Lucidium", "Exoretic", "Erodimium", "Sentient Viscera", "Luminatite",
    "Trinitium", "Glacielle", "Quandrium", "Speatrium", "Xynarium",
    "Azuryl", "Scarfyte", "Vulkavium", "Cleopatrite", "Spristium",
    "Pasivium", "Aether", "Suncindium", "Emberstyx", "Euclideum",
    "Elegascene", "Formidulus", "Nauticalis", "Bonfire", "Infernus Flammea",
    "Oviridis", "Obscuralis", "Penumbrosia", "Ornalium", "Heatnado",
    "Vitrilyx", "Acceleratium", "Combustal", "Polonium", "Temporum",
    "Monocage", "Neptunium", "Snoblintium", "Astatine", "Accretium",
    "Scertanium", "Flaeon", "Poiseon", "Freon", "Aegistone",
    "Thundarian", "Exolite", "Photoprisma", "Elexinite"
}

local function getActiveEventLayer()
    local GI = getGI()
    local evInfo = GI and GI.eventInfo
    if evInfo and evInfo.active and evInfo.timeRemaining and evInfo.timeRemaining > 0 then
        local evId = evInfo.eventId or (evInfo.event and evInfo.event.name)
        if evId and EventToLayerMap[evId:lower()] then
            local evName = (evInfo.event and evInfo.event.name) or evId
            return EventToLayerMap[evId:lower()], evName, math.floor(evInfo.timeRemaining)
        end
    end
    return nil, nil, 0
end

-- ============================================================
-- WORLD EVENT WATCHDOG & BUFFER ZONE WEBHOOK ENGINE
-- ============================================================
local lastActiveEventId = nil
local lastActiveEventName = nil
local lastActiveEventLayer = nil
local lastEventHeartbeat = 0
local warned5MinRemaining = false
local eventBlocksMinedStart = 0

task.spawn(function()
    while isScriptAlive do
        task.wait(5)
        local GI = getGI()
        local evInfo = GI and GI.eventInfo
        local isEvActive = evInfo and evInfo.active and evInfo.timeRemaining and evInfo.timeRemaining > 0
        local curEvId = isEvActive and (evInfo.eventId or (evInfo.event and evInfo.event.name)) or nil

        if isEvActive and curEvId then
            local evName = (evInfo.event and evInfo.event.name) or curEvId
            local evLayer = EventToLayerMap[curEvId:lower()] or "Unknown Layer"
            local timeLeft = math.floor(evInfo.timeRemaining)
            local minsLeft = math.floor(timeLeft / 60)
            local secsLeft = timeLeft % 60
            local timeFormatted = string.format("%dm %02ds", minsLeft, secsLeft)
            local evEffects = evInfo.event and evInfo.event.eventEffects
            local effectsDesc = (type(evEffects) == "table" and table.concat(evEffects, " | ")) or (type(evEffects) == "string" and evEffects) or "+15-20% Rare Ore Spawn Rate Boost"

            -- 1. EVENT STARTED TRIGGER
            if curEvId ~= lastActiveEventId then
                lastActiveEventId = curEvId
                lastActiveEventName = evName
                lastActiveEventLayer = evLayer
                warned5MinRemaining = false
                lastEventHeartbeat = os.clock()
                local _, totalMinedNow = getMinedStats()
                eventBlocksMinedStart = totalMinedNow

                if Cfg.EventWebhookLogs and Cfg.WebhookEventAlerts then
                    local extraFields = {
                        {name = "Event Name", value = evName, inline = true},
                        {name = "Buffed Layer", value = evLayer, inline = true},
                        {name = "Duration Remaining", value = timeFormatted, inline = true},
                        {name = "Buff / Effects", value = effectsDesc, inline = false},
                        {name = "1M+ Hunter Action", value = Cfg.HunterPrioritizeEvents and string.format("Auto-Routing prioritizes %s for maximum 1M+ spawn rates!", evLayer) or "Event priority is disabled in settings.", inline = false},
                    }
                    sendWebhook("Events", "WORLD EVENT STARTED: " .. evName, string.format("Active world event buff is live! Target layer: %s (+15-20%% luck buff).", evLayer), true, extraFields)
                end

            else
                -- 2. 5-MINUTE EXPIRING WARNING ALERT
                if not warned5MinRemaining and timeLeft <= 300 and timeLeft > 20 then
                    warned5MinRemaining = true
                    if Cfg.EventWebhookLogs and Cfg.WebhookEventAlerts then
                        local _, curMined = getMinedStats()
                        local minedInEvent = math.max(0, curMined - eventBlocksMinedStart)
                        local extraFields = {
                            {name = "Event Name", value = evName, inline = true},
                            {name = "Buffed Layer", value = evLayer, inline = true},
                            {name = "Time Remaining", value = timeFormatted .. " (Ending Soon!)", inline = true},
                            {name = "Mined During Event", value = string.format("%s blocks", formatNum(minedInEvent)), inline = true},
                            {name = "Buffer Zone Status", value = "Prepare for event conclusion and rotation to next layer.", inline = false},
                        }
                        sendWebhook("Events", string.format("EVENT EXPIRING SOON: %s (%s Left)", evName, timeFormatted), string.format("World event buff in %s will expire in %s! Buffer zone watchdog active.", evLayer, timeFormatted), false, extraFields)
                    end
                end

                -- 3. PERIODIC EVENT STATUS HEARTBEAT
                local interval = Cfg.EventWebhookInterval or 300
                if os.clock() - lastEventHeartbeat >= interval then
                    lastEventHeartbeat = os.clock()
                    if Cfg.EventWebhookLogs and Cfg.WebhookEventAlerts then
                        local _, curMined = getMinedStats()
                        local minedInEvent = math.max(0, curMined - eventBlocksMinedStart)
                        local extraFields = {
                            {name = "Event Name", value = evName, inline = true},
                            {name = "Buffed Layer", value = evLayer, inline = true},
                            {name = "Time Remaining", value = timeFormatted, inline = true},
                            {name = "Mined in Event Buff", value = string.format("%s blocks", formatNum(minedInEvent)), inline = true},
                        }
                        sendWebhook("Events", string.format("EVENT STATUS HEARTBEAT: %s", evName), string.format("Ongoing event buff active in %s. Status update.", evLayer), false, extraFields)
                    end
                end
            end

        elseif not isEvActive and lastActiveEventId ~= nil then
            -- 4. EVENT CONCLUDED RECAP
            local _, curMined = getMinedStats()
            local totalMinedInEvent = math.max(0, curMined - eventBlocksMinedStart)

            if Cfg.EventWebhookLogs and Cfg.WebhookEventAlerts then
                local extraFields = {
                    {name = "Concluded Event", value = tostring(lastActiveEventName), inline = true},
                    {name = "Layer Was", value = tostring(lastActiveEventLayer), inline = true},
                    {name = "Total Blocks Mined", value = string.format("%s blocks", formatNum(totalMinedInEvent)), inline = true},
                    {name = "Hunter Transition", value = "1M+ Hunter has rotated back to standard layer rotation / wishlist.", inline = false},
                }
                sendWebhook("Events", "WORLD EVENT ENDED: " .. tostring(lastActiveEventName), string.format("The event buff in %s has expired. Hunter transitioning smoothly to next rotation.", tostring(lastActiveEventLayer)), false, extraFields)
            end

            lastActiveEventId = nil
            lastActiveEventName = nil
            lastActiveEventLayer = nil
            warned5MinRemaining = false
        end
    end
end)

local function sniffFreshReset1MOre()
    local bestOre, bestPart, bestDist = nil, nil, math.huge
    local char = lp.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local myPos = root and root.Position or Vector3.zero

    for part, data in pairs(rareOresRegistry) do
        if part and part.Parent and data.is1M then
            local ownership = data.ownership
            if not ownership then
                ownership, _, _ = getOreOwnership(part)
            end
            if ownership ~= "other" then
                local cPos = data.pos or (part:IsA("BasePart") and part.Position)
                if cPos then
                    local d = (cPos - myPos).Magnitude
                    if d < bestDist then
                        bestDist = d
                        bestOre = data
                        bestPart = part
                    end
                end
            end
        end
    end

    if bestOre and bestPart then
        return bestPart, bestOre
    end
    return nil, nil
end

local function determineNextResetLayer()
    -- Mode 1: Smart Hybrid (Event -> Roulette -> Fallback)
    if Cfg.HunterMode == "Smart Hybrid (Recommended)" then
        if Cfg.HunterPrioritizeEvents then
            local evLayer, evName, timeLeft = getActiveEventLayer()
            if evLayer then
                return evLayer, string.format("Event Active: %s (%d mins left)", evName, math.floor(timeLeft / 60))
            end
        end
        if #Cfg.RouletteLayers > 0 then
            Cfg.RouletteIndex = (Cfg.RouletteIndex % #Cfg.RouletteLayers) + 1
            local nextLayer = Cfg.RouletteLayers[Cfg.RouletteIndex]
            saveConfig()
            return nextLayer, string.format("Layer Roulette (%d/%d)", Cfg.RouletteIndex, #Cfg.RouletteLayers)
        end
        return Cfg.TargetResetLayer, "Default Target"
    end

    -- Mode 2: Event Priority Only
    if Cfg.HunterMode == "Event Priority Only" then
        local evLayer, evName, timeLeft = getActiveEventLayer()
        if evLayer then
            return evLayer, string.format("Event Active: %s (%d mins left)", evName, math.floor(timeLeft / 60))
        end
        return Cfg.TargetResetLayer, "Standard Reset Target (No Event Active)"
    end

    -- Mode 3: Target Ore Wishlist
    if Cfg.HunterMode == "Target Ore Wishlist" and Cfg.HunterTargetOre ~= "" and Cfg.HunterTargetOre ~= "None" then
        local targetLayer = OreToLayerMap[Cfg.HunterTargetOre]
        if targetLayer then
            return targetLayer, "Hunting Specific Target: " .. Cfg.HunterTargetOre
        end
        return Cfg.TargetResetLayer, "Target Ore Layer Not Found"
    end

    -- Mode 4: Layer Roulette
    if Cfg.HunterMode == "Layer Roulette" then
        if #Cfg.RouletteLayers > 0 then
            Cfg.RouletteIndex = (Cfg.RouletteIndex % #Cfg.RouletteLayers) + 1
            local nextLayer = Cfg.RouletteLayers[Cfg.RouletteIndex]
            saveConfig()
            return nextLayer, string.format("Layer Roulette (%d/%d)", Cfg.RouletteIndex, #Cfg.RouletteLayers)
        end
        return Cfg.TargetResetLayer, "Roulette Empty"
    end

    -- Mode 5: Disabled / Standard
    return Cfg.TargetResetLayer, "Standard Reset Target"
end

-- Mine Reset Watchdog with Safe Return & Webhook Alerts
local function setupMineResetWatchdog()
    if not MineStates then return end

    local function onResetStarted()
        if isResetWaiting then return end
        isResetWaiting = true

        -- Capture active states before reset
        wasWalkingBeforeReset = Cfg.AutoWalkForward
        wasMiningBeforeReset = Cfg.AutoMine
        wasMiningStraightBeforeReset = Cfg.AutoMineStraight

        -- Stop movement immediately so player doesn't run into void while blocks are cleared
        local char = lp.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if hum then hum:Move(Vector3.zero, false) end

        local preResetCFrame = root and root.CFrame

        -- Pause mining remote
        if MineRemote then pcall(function() MineRemote:FireServer(false) end) end

        if Cfg.WebhookResetAlerts then
            sendWebhook("Reset", "Mine Reset Initiated", "The mine is resetting. Walking & mining have paused automatically.", false)
        end

        pcall(function()
            if Rayfield then
                Rayfield:Notify({Title = "Mine Reset Started", Content = "Movement & mining paused. Waiting for regeneration...", Duration = 3})
            end
        end)

        task.spawn(function()
            -- Wait for MineRegenerated signal or game state to return to "Active"
            local regenSignal = MineStates:FindFirstChild("MineRegenerated")
            local regenerated = false
            local conn
            if regenSignal then
                conn = regenSignal.OnClientEvent:Connect(function()
                    regenerated = true
                end)
            end

            local GI = getGI()
            local waited = 0
            -- Wait until signal fires OR GI.mineState flips to Active (max 20s)
            while not regenerated and (GI and GI.mineState ~= "Active") and waited < 20 and isScriptAlive do
                task.wait(0.5)
                waited = waited + 0.5
            end
            if conn then conn:Disconnect() end

            -- Allow blocks to settle into physics grid
            task.wait(1.5)

            -- 1. Check Fresh Reset Map Sniffer (if enabled)
            local foundFresh1M = false
            if Cfg.HunterSniffOnReset and Cfg.HunterMode ~= "Disabled" and handleRareOreSpawned then
                populateRareOresRegistry()
                task.wait(0.4)
                local freshPart, freshData = sniffFreshReset1MOre()
                if freshPart and freshData then
                    foundFresh1M = true
                    local cPos = freshData.pos or freshPart.Position
                    local areaName, depthStr = getAreaFromPosition(cPos)
                    pcall(function()
                        if Rayfield then
                            Rayfield:Notify({
                                Title = "FRESH RESET 1M+ SNIPED!",
                                Content = string.format("Found %s (%s) on map reset! Targeting...", freshData.info.name, freshData.info.rarityText),
                                Duration = 5
                            })
                        end
                    end)
                    handleRareOreSpawned(freshData.info.name, freshData.info.rarityText, "Fresh Reset Spawn Sniffer", freshPart, cPos, freshData.ownership, freshData.ownerName, areaName, depthStr)
                end
            end

            -- 2. If no fresh 1M+ ore was sniped, execute smart layer routing!
            if not foundFresh1M and Cfg.AutoTPResetLoop then
                local destinationLayer, reason = determineNextResetLayer()

                pcall(function()
                    if Rayfield then
                        Rayfield:Notify({Title = "Mine Regenerated", Content = string.format("Teleporting to %s\n[%s]", destinationLayer, reason), Duration = 3})
                    end
                end)

                if destinationLayer == "Pre-Reset Location (Last Position)" then
                    teleportViaBoard("Prev")
                    task.delay(1.2, function()
                        if preResetCFrame and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
                            local curPos = lp.Character.HumanoidRootPart.Position
                            if (curPos - preResetCFrame.Position).Magnitude > 50 then
                                safeTeleport(preResetCFrame.Position, Vector3.new(0, 5.5, 0))
                            end
                        end
                    end)
                else
                    teleportViaBoard(destinationLayer)
                end

                task.wait(1.0)
            elseif not foundFresh1M then
                pcall(function()
                    if Rayfield then
                        Rayfield:Notify({Title = "Mine Regenerated", Content = "Mine active. Resuming movement...", Duration = 2})
                    end
                end)
            end

            if Cfg.WebhookResetAlerts then
                sendWebhook("Reset", "Mine Regenerated", "Mine has regenerated! Returned to target layer and resumed operations.", false)
            end

            isResetWaiting = false
            populateRareOresRegistry()

            -- Resume walking forward and mining seamlessly if they were active before the reset!
            if wasWalkingBeforeReset and Cfg.AutoWalkForward then
                local c = lp.Character
                local r = c and c:FindFirstChild("HumanoidRootPart")
                if r then
                    local look = r.CFrame.LookVector
                    local flat = Vector3.new(look.X, 0, look.Z)
                    lockedWalkDir = flat.Magnitude > 0.001 and flat.Unit or Vector3.new(0, 0, -1)
                end
                pcall(function()
                    if Rayfield then
                        Rayfield:Notify({Title = "Resumed", Content = "Auto-walk and mining resumed!", Duration = 2})
                    end
                end)
            end
        end)
    end

    local resetSignal = MineStates:FindFirstChild("MineResetting")
    if resetSignal then
        table.insert(scriptConnections, resetSignal.OnClientEvent:Connect(onResetStarted))
    end

    task.spawn(function()
        while isScriptAlive do
            task.wait(1)
            local GI = getGI()
            if GI and GI.mineState == "Regenerating" and not isResetWaiting then
                onResetStarted()
            end
        end
    end)
end
setupMineResetWatchdog()

local recentAlerts = {}
local activeMining1MTask = false

handleRareOreSpawned = function(oreName, rarityLabel, sourceMsg, part, cPos, ownership, ownerName, areaName, depthStr)
    -- Resolve position if not provided
    if part and not cPos then
        cPos = part:IsA("BasePart") and part.Position or (part:IsA("Model") and part:GetPivot().Position)
    end

    -- Determine area and depth if missing
    if not areaName or not depthStr then
        if cPos then
            areaName, depthStr = getAreaFromPosition(cPos)
        else
            areaName = getCurrentLayer()
            depthStr = getCurrentDepth()
        end
    end

    ownership = ownership or "unknown"
    ownerName = ownerName or "Unknown"

    local now = os.clock()
    local dedupeKey = oreName .. "_" .. (cPos and string.format("%.0f_%.0f", cPos.X, cPos.Z) or tostring(ownerName))
    if recentAlerts[dedupeKey] and (now - recentAlerts[dedupeKey] < 45) then
        return
    end
    recentAlerts[dedupeKey] = now

    local isOther = (ownership == "other")
    local isMine = (ownership == "mine")
    local isPublic = (ownership == "public")
    local coordStr = cPos and string.format("%.0f, %.0f, %.0f", cPos.X, cPos.Y, cPos.Z) or "Unknown"

    -- 1. IF SPAWNED FOR ANOTHER PLAYER:
    if isOther then
        -- DO NOT STOP autofarming or walking! Character continues farming in a straight line without breaking!
        pcall(function()
            if Rayfield then
                Rayfield:Notify({
                    Title = "1M+ Ore (Other Player)",
                    Content = string.format("%s (%s)\nSpawned for: %s\nArea: %s (%s)\nAutofarm continuing straight!", oreName, rarityLabel, ownerName, areaName, depthStr),
                    Duration = 6
                })
            end
        end)

        -- Send Discord Webhook alerting user with ping, exact area, and owner info
        if Cfg.Webhook1MAlerts then
            local extraFields = {
                {name = "Ore Name", value = oreName, inline = true},
                {name = "Rarity", value = rarityLabel, inline = true},
                {name = "Spawned For", value = string.format("%s (Another Player - Ore Protected/Unmineable)", ownerName), inline = false},
                {name = "Area / Layer", value = string.format("%s (%s)", areaName, depthStr), inline = true},
                {name = "Coordinates", value = coordStr, inline = true},
                {name = "Autofarm Status", value = "Autofarm continuing in straight line without stopping (Ore protected by server)", inline = false},
            }
            sendWebhook("1M", string.format("1M+ ORE DETECTED: %s (Spawned for %s)", oreName, ownerName), "A 1M+ ore spawned for another player. Server ownership rules protect this ore. Autofarm is continuing straight forward uninterrupted!", true, extraFields)
        end
        return
    end

    -- 2. IF SPAWNED FOR LOCAL PLAYER OR PUBLIC SPAWN:
    local targetDesc = isMine and ("Spawned for YOU (" .. lp.Name .. ")") or "Public / World Spawn"
    local miningModeStr = Cfg.LegitMining and "Safe / Legit (Walking & Mining, No TP)" or (Cfg.AutoTP1M and "Auto-Teleport Onto Block" or "Manual Alert (Stop On 1M)")

    pcall(function()
        if Rayfield then
            Rayfield:Notify({
                Title = "1M+ RARE ORE DETECTED!",
                Content = string.format("%s (%s)\n%s\nArea: %s (%s)\nMode: %s", oreName, rarityLabel, targetDesc, areaName, depthStr, miningModeStr),
                Duration = 8
            })
        end
    end)

    if Cfg.Webhook1MAlerts then
        local extraFields = {
            {name = "Ore Name", value = oreName, inline = true},
            {name = "Rarity", value = rarityLabel, inline = true},
            {name = "Spawned For", value = targetDesc, inline = false},
            {name = "Area / Layer", value = string.format("%s (%s)", areaName, depthStr), inline = true},
            {name = "Coordinates", value = coordStr, inline = true},
            {name = "Mining Mode", value = miningModeStr, inline = false},
        }
        task.spawn(function()
            for i = 1, 3 do
                if not isScriptAlive then break end
                sendWebhook("1M", string.format("1M+ RARE ORE DETECTED (%d/3): %s", i, oreName), "Your 1M+ ore is active! Mining ore and will continue forward from block location.", true, extraFields)
                if i < 3 then task.wait(25) end
            end
        end)
    end

    -- EXECUTE MINING FOR YOUR / PUBLIC 1M+ ORE
    if Cfg.LegitMining then
        -- SAFE / LEGIT MINING MODE (NO TELEPORTATION)
        if activeMining1MTask then return end
        activeMining1MTask = true
        rareOreSpawnedActive = true

        task.spawn(function()
            local timeout = os.clock() + 60
            while isScriptAlive and not isResetWaiting and os.clock() < timeout do
                if not part or not part.Parent then break end
                local char = lp.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if not root or not hum then break end

                local pPos = part:IsA("BasePart") and part.Position or cPos
                local myPos = root.Position
                local flatDelta = Vector3.new(pPos.X - myPos.X, 0, pPos.Z - myPos.Z)
                local dist = (pPos - myPos).Magnitude

                if dist > 8 then
                    if flatDelta.Magnitude > 0.1 then
                        hum:Move(flatDelta.Unit, false)
                    end
                else
                    hum:Move(Vector3.zero, false)
                end

                if MineRemote then
                    local origin = char:FindFirstChild("Head") and char.Head.Position or (myPos + Vector3.new(0, 1.5, 0))
                    local dir = (pPos - origin).Unit
                    pcall(function() MineRemote:FireServer(true, origin, dir, pPos) end)
                    if CachedTool then pcall(function() CachedTool:Activate() end) end
                end
                task.wait(0.1)
            end

            -- Ore cleared! Continue mining based on the NEW pos where the block was found:
            rareOreSpawnedActive = false
            activeMining1MTask = false

            if isScriptAlive and not isResetWaiting then
                local char = lp.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root then
                    local look = root.CFrame.LookVector
                    local flat = Vector3.new(look.X, 0, look.Z)
                    lockedWalkDir = flat.Magnitude > 0.001 and flat.Unit or Vector3.new(0, 0, -1)
                end
                if Cfg.ContinueFrom1MPos then
                    Cfg.AutoWalkForward = true
                    Cfg.AutoMineStraight = true
                end
                pcall(function()
                    if Rayfield then
                        Rayfield:Notify({
                            Title = "1M+ Ore Cleared!",
                            Content = "Safe mining complete! Resuming straight forward mining from new position.",
                            Duration = 4
                        })
                    end
                end)
            end
        end)

    elseif Cfg.AutoTP1M and cPos then
        -- AUTO-TP MODE (BLATANT / INSTANT TP)
        if activeMining1MTask then return end
        activeMining1MTask = true
        rareOreSpawnedActive = true

        task.spawn(function()
            local char = lp.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local pre1MCFrame = root and root.CFrame

            task.wait(0.05)
            safeTeleport(cPos, Vector3.new(0, 3.6, 0), cPos)
            task.wait(0.1)

            local timeout = os.clock() + 30
            local GI = getGI()
            local rayParams = GI and GI.constants and GI.constants.mineRaycastParams

            while isScriptAlive and not isResetWaiting and os.clock() < timeout do
                if not part or not part.Parent then break end
                char = lp.Character
                root = char and char:FindFirstChild("HumanoidRootPart")
                hum = char and char:FindFirstChildOfClass("Humanoid")
                if not root or not hum then break end

                -- Stand completely still while mining
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
                hum:Move(Vector3.zero, false)

                local pPos = (part:IsA("BasePart") and part.Position) or cPos
                local origin = char:FindFirstChild("Head") and char.Head.Position or (root.Position + Vector3.new(0, 1.5, 0))
                local dir = (pPos - origin).Unit
                local rayResult = rayParams and workspace:Raycast(origin, dir * 18, rayParams)
                local hitPos = rayResult and rayResult.Position or (pPos + Vector3.new(0, 2.0, 0))

                isAutoMining = true
                if MineRemote then
                    pcall(function() MineRemote:FireServer(true, origin, dir, hitPos) end)
                    if CachedTool then pcall(function() CachedTool:Activate() end) end
                end
                task.wait(0.05)
            end

            -- Ore cleared!
            isAutoMining = false
            rareOreSpawnedActive = false
            activeMining1MTask = false

            if isScriptAlive and not isResetWaiting then
                if Cfg.ReturnToOldPos and pre1MCFrame then
                    char = lp.Character
                    root = char and char:FindFirstChild("HumanoidRootPart")
                    if char and root then
                        char:PivotTo(pre1MCFrame)
                        root.AssemblyLinearVelocity = Vector3.zero
                        root.AssemblyAngularVelocity = Vector3.zero
                    end
                    pcall(function()
                        if Rayfield then
                            Rayfield:Notify({
                                Title = "1M+ Ore Mined!",
                                Content = "Mined ore and returned safely back to your previous position!",
                                Duration = 4
                            })
                        end
                    end)
                elseif Cfg.ContinueFrom1MPos then
                    char = lp.Character
                    root = char and char:FindFirstChild("HumanoidRootPart")
                    if root then
                        local look = root.CFrame.LookVector
                        local flat = Vector3.new(look.X, 0, look.Z)
                        lockedWalkDir = flat.Magnitude > 0.001 and flat.Unit or Vector3.new(0, 0, -1)
                    end
                    Cfg.AutoWalkForward = true
                    Cfg.AutoMineStraight = true
                    pcall(function()
                        if Rayfield then
                            Rayfield:Notify({
                                Title = "1M+ Ore Mined!",
                                Content = "Continuing forward mining from new position!",
                                Duration = 4
                            })
                        end
                    end)
                end
            end
        end)

    elseif Cfg.StopOn1MSpawn then
        -- Manual stop mode
        rareOreSpawnedActive = true
        Cfg.AutoMine = false
        Cfg.AutoWalkForward = false
        Cfg.DrillDown = false
        if MineRemote then pcall(function() MineRemote:FireServer(false) end) end
        local char = lp.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum:Move(Vector3.zero, false) end

        if part then
            local conn
            conn = part.AncestryChanged:Connect(function(_, parent)
                if not parent then
                    if conn then conn:Disconnect() end
                    rareOreSpawnedActive = false
                end
            end)
        end
    end
end

-- Listen to Remotes.WriteToTopBar for Rare Ore Announcements
if WriteToTopBar then
    table.insert(scriptConnections, WriteToTopBar.OnClientEvent:Connect(function(msg, details, oreId)
        if oreId then
            local info = getOreInfo(oreId)
            if info.rarityNum >= 1000000 or info.tierNum >= 10 then
                task.spawn(function()
                    local foundPart, foundPos, foundOwnership, foundOwnerName, foundArea, foundDepth = nil, nil, nil, nil, nil, nil
                    for _ = 1, 10 do
                        for part, data in pairs(rareOresRegistry) do
                            if data and data.info and data.info.name:lower() == info.name:lower() and part and part.Parent then
                                foundPart = part
                                foundPos = data.pos or (part:IsA("BasePart") and part.Position)
                                foundOwnership = data.ownership
                                foundOwnerName = data.ownerName
                                break
                            end
                        end
                        if foundPart then break end
                        task.wait(0.1)
                    end

                    if foundPart then
                        if not foundOwnership then
                            foundOwnership, _, foundOwnerName = getOreOwnership(foundPart)
                        end
                        foundArea, foundDepth = getAreaFromPosition(foundPos)
                    else
                        local parsedOwner = nil
                        if msg then
                            parsedOwner = msg:match("^([%w_]+)%s+has%s+found") or msg:match("^([%w_]+)%s+has%s+rolled") or msg:match("^([%w_]+)")
                        end
                        if parsedOwner and parsedOwner ~= lp.Name then
                            foundOwnership = "other"
                            foundOwnerName = parsedOwner
                        else
                            foundOwnership = "unknown"
                        end
                    end

                    handleRareOreSpawned(info.name, info.rarityText, msg or "TopBar Announcement", foundPart, foundPos, foundOwnership, foundOwnerName, foundArea, foundDepth)
                end)
            end
        elseif msg and (msg:find("spine") or msg:find("ringing") or msg:find("shakes") or msg:find("feeblings") or msg:find("blur")) then
            handleRareOreSpawned("Special Server Event", "1M+ Event Spawn", msg, nil, nil, "public", "Server Event", nil, nil)
        end
    end))
end

-- World Event Listeners (Remotes.Events.EventStarted, EventEnded, and SupernaturalSpawn)
if Remotes then
    local EventsFolder = Remotes:FindFirstChild("Events")
    if EventsFolder then
        local evStarted = EventsFolder:FindFirstChild("EventStarted")
        if evStarted then
            table.insert(scriptConnections, evStarted.OnClientEvent:Connect(function(evData)
                if not evData then return end
                local ev = evData.event or {}
                local evInfo = ev.information or {}
                local evName = ev.name or evData.eventId or "World Event"
                local evMsg = evInfo.message or ev.eventEffects or "A special world event has started!"
                local oreRarity = evInfo.oreRarity and ("1/" .. formatNum(evInfo.oreRarity)) or "Special Event Rarity"
                local evLength = evInfo.eventLength and string.format("%d mins", math.floor(evInfo.eventLength / 60)) or "Limited Time"

                pcall(function()
                    if Rayfield then
                        Rayfield:Notify({
                            Title = "WORLD EVENT: " .. evName:upper(),
                            Content = evMsg,
                            Duration = 8
                        })
                    end
                end)

                if Cfg.WebhookEventAlerts then
                    sendWebhook("Events", "WORLD EVENT STARTED: " .. evName, string.format("Event: %s\nBuff/Effects: %s\nSpecial Ore Rarity: %s\nDuration: %s\nBroadcast: %s", evName, ev.eventEffects or "None", oreRarity, evLength, evMsg), true)
                end
            end))
        end

        local evEnded = EventsFolder:FindFirstChild("EventEnded")
        if evEnded then
            table.insert(scriptConnections, evEnded.OnClientEvent:Connect(function(evData)
                if not evData then return end
                local ev = evData.event or {}
                local evName = ev.name or evData.eventId or "World Event"
                pcall(function()
                    if Rayfield then
                        Rayfield:Notify({
                            Title = "EVENT ENDED",
                            Content = evName .. " has ended.",
                            Duration = 4
                        })
                    end
                end)
                if Cfg.WebhookEventAlerts then
                    sendWebhook("Events", "WORLD EVENT ENDED: " .. evName, string.format("Event '%s' has concluded.", evName), false)
                end
            end))
        end
    end

    local superSpawn = Remotes:FindFirstChild("SupernaturalSpawn")
    if superSpawn then
        table.insert(scriptConnections, superSpawn.OnClientEvent:Connect(function(oreId)
            local info = getOreInfo(oreId)
            pcall(function()
                if Rayfield then
                    Rayfield:Notify({
                        Title = "SUPERNATURAL SPAWN!",
                        Content = string.format("%s (%s) has spawned!", info.name, info.rarityText),
                        Duration = 8
                    })
                end
            end)
            if Cfg.WebhookEventAlerts or Cfg.Webhook1MAlerts then
                sendWebhook("Events", "SUPERNATURAL SPAWN: " .. info.name, string.format("Ore: %s\nRarity: %s (Tier %d: %s)\nA supernatural spawn was detected in the realm!", info.name, info.rarityText, info.tierNum, info.tierName), true)
            end
        end))
    end
end

-- Real-Time Detection for newly spawned blocks in Mine & Placed folders
local function handleNewBlockAdded(child)
    if isResetWaiting or not child then return end
    task.spawn(function()
        local added, info, is1M, cPos, ownership, ownerName = registerRareOre(child)
        if added and is1M then
            local areaName, depthStr = getAreaFromPosition(cPos)
            handleRareOreSpawned(info.name, info.rarityText, "1M+ Ore Spawned Into World", child, cPos, ownership, ownerName, areaName, depthStr)
            if scanOresForESP then scanOresForESP() end
        end
    end)
end

-- Connect real-time listeners to Mine, Placed folders, and ScriptedOre
local mineFolder = workspace:FindFirstChild("Mine")
if mineFolder then
    table.insert(scriptConnections, mineFolder.ChildAdded:Connect(handleNewBlockAdded))
end

for _, folderName in ipairs({"PlacedOres", "PlacedBlocks"}) do
    local folder = workspace:FindFirstChild(folderName)
    if folder then
        table.insert(scriptConnections, folder.ChildAdded:Connect(handleNewBlockAdded))
    end
end

table.insert(scriptConnections, CollectionService:GetInstanceAddedSignal("ScriptedOre"):Connect(function(item)
    handleNewBlockAdded(item)
end))

-- ============================================================
-- 2D DRAWING CHAMS & ESP ENGINE (ZERO CAMERA JITTER, PURE 2D, ZERO LAG)
-- ============================================================
local trackedOres = {}
local lastScanTime = 0
local camera = workspace.CurrentCamera

local function getOrCreateDrawing(part)
    local d = activeDrawings[part]
    if d then return d end

    local boxOutline = Drawing.new("Square")
    boxOutline.Thickness = 3
    boxOutline.Filled = false
    boxOutline.Color = Color3.fromRGB(0, 0, 0)
    boxOutline.Visible = false

    local box = Drawing.new("Square")
    box.Thickness = 1.5
    box.Filled = false
    box.Visible = false

    local boxFill = Drawing.new("Square")
    boxFill.Filled = true
    boxFill.Transparency = 0.3
    boxFill.Visible = false

    local txt = Drawing.new("Text")
    txt.Size = 13
    txt.Center = true
    txt.Outline = true
    txt.OutlineColor = Color3.fromRGB(0, 0, 0)
    txt.Visible = false

    d = {boxOutline = boxOutline, box = box, boxFill = boxFill, txt = txt}
    activeDrawings[part] = d
    return d
end

function scanOresForESP()
    if not Cfg.ESPEnabled then
        trackedOres = {}
        return
    end

    local char = lp.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local searchPos = root.Position
    local candidates = {}

    for part, data in pairs(rareOresRegistry) do
        if part and part.Parent and part:IsDescendantOf(workspace) then
            local cPos = data.pos or (part:IsA("BasePart") and part.Position or (part:IsA("Model") and part:GetPivot().Position))
            if cPos then
                local dist = (cPos - searchPos).Magnitude
                local info = data.info
                local pass = false

                if Cfg.ESPFilter == "1M+ Ores Only" then
                    pass = data.is1M or (info.rarityNum >= 1000000 or info.tierNum >= 10)
                elseif Cfg.ESPFilter == "100k+ Ores Only" then
                    pass = data.is1M or data.is100k or (info.rarityNum >= 100000 or info.tierNum >= 9)
                elseif Cfg.ESPFilter == "10k+ (Exotic+)" then
                    pass = data.is1M or data.is100k or data.is10k or (info.rarityNum >= 10000 or info.tierNum >= 8)
                elseif Cfg.ESPFilter == "Rare+ (Tier 4+)" then
                    pass = data.is1M or data.is100k or data.is10k or data.isRare or (info.tierNum >= 4 or info.rarityNum >= 1000)
                elseif Cfg.ESPFilter == "All Ores" then
                    pass = true
                end

                -- 1M+ ores IGNORE distance limit completely! They render across the whole world!
                if pass and (data.is1M or (Cfg.ESPFilter == "100k+ Ores Only" and data.is100k) or dist <= Cfg.ESPMaxDist) then
                    table.insert(candidates, {
                        part = part,
                        pos = cPos,
                        size = data.size or Vector3.new(4, 4, 4),
                        info = info,
                        dist = dist,
                        is1M = data.is1M or (info.rarityNum >= 1000000 or info.tierNum >= 10),
                        is100k = data.is100k or (info.rarityNum >= 100000 or info.tierNum >= 9),
                        ownership = data.ownership,
                        ownerName = data.ownerName
                    })
                end
            end
        else
            rareOresRegistry[part] = nil
        end
    end

    -- For "All Ores", use high-speed C++ engine spatial query to grab nearby common/uncommon ores in 1ms!
    if Cfg.ESPFilter == "All Ores" then
        local mineFolder = workspace:FindFirstChild("Mine")
        if mineFolder then
            local overlapParams = OverlapParams.new()
            overlapParams.FilterType = Enum.RaycastFilterType.Include
            overlapParams.FilterDescendantsInstances = {mineFolder}
            overlapParams.MaxParts = 60

            local nearbyParts = workspace:GetPartBoundsInRadius(searchPos, 180, overlapParams)
            for _, part in ipairs(nearbyParts) do
                if part and part:IsA("BasePart") and not rareOresRegistry[part] then
                    local nLower = part.Name:lower()
                    if not CommonLayerBlocks[nLower] then
                        local info = getOreInfo(part.Name)
                        local cPos = part.Position
                        local dist = (cPos - searchPos).Magnitude
                        table.insert(candidates, {
                            part = part,
                            pos = cPos,
                            size = part.Size,
                            info = info,
                            dist = dist,
                            is1M = false,
                            is100k = false,
                            ownership = "public",
                            ownerName = "Nearby Ore"
                        })
                    end
                end
            end
        end
    end

    -- Sort: 1M+ ores first, then 100k+ ores, then highest rarity, then closest
    table.sort(candidates, function(a, b)
        if a.is1M ~= b.is1M then return a.is1M end
        if a.is100k ~= b.is100k then return a.is100k end
        if a.info.rarityNum ~= b.info.rarityNum then return a.info.rarityNum > b.info.rarityNum end
        return a.dist < b.dist
    end)

    local topCandidates = {}
    local maxDisplayCount = Cfg.ESPFilter == "All Ores" and 60 or (Cfg.ESPFilter == "Rare+ (Tier 4+)" and 50 or 40)
    for _, cand in ipairs(candidates) do
        if cand.is1M or cand.is100k or #topCandidates < maxDisplayCount then
            table.insert(topCandidates, cand)
        end
    end
    trackedOres = topCandidates
end

-- RenderStepped 2D Drawing Chams update (Zero-Lag, Pure 2D)
table.insert(scriptConnections, RunService.RenderStepped:Connect(function()
    if not Cfg.ESPEnabled or not Drawing then
        clearAllDrawings()
        return
    end

    local now = os.clock()
    if now - lastScanTime > 0.8 then
        lastScanTime = now
        scanOresForESP()
    end

    local char = lp.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local activeThisFrame = {}
    local vpSize = camera.ViewportSize
    local screenCenter = Vector2.new(vpSize.X / 2, vpSize.Y / 2)

    for _, item in ipairs(trackedOres) do
        local part = item.part
        if part and part.Parent and part:IsDescendantOf(workspace) then
            local cPos = item.pos
            local pSize = item.size or Vector3.new(4, 4, 4)
            if part:IsA("BasePart") then
                cPos = part.Position
                pSize = part.Size
            elseif part:IsA("Model") then
                cPos = part:GetPivot().Position
                pSize = part:GetExtentsSize()
            end

            local screenPos, onScreen = camera:WorldToViewportPoint(cPos)
            local dist = math.floor((cPos - root.Position).Magnitude)

            if onScreen and screenPos.Z > 0 then
                activeThisFrame[part] = true
                local dObj = getOrCreateDrawing(part)

                local topPos = camera:WorldToViewportPoint(cPos + Vector3.new(0, pSize.Y / 2, 0))
                local botPos = camera:WorldToViewportPoint(cPos - Vector3.new(0, pSize.Y / 2, 0))
                local boxHeight = math.clamp(math.abs(topPos.Y - botPos.Y), 14, 200)
                local boxWidth = math.max(14, boxHeight)

                local boxTopLeft = Vector2.new(screenPos.X - boxWidth / 2, screenPos.Y - boxHeight / 2)

                -- 2D Cham Box (Outline + Accent Box + Tinted Glow Fill)
                if Cfg.ESPChams then
                    dObj.boxOutline.Size = Vector2.new(boxWidth, boxHeight)
                    dObj.boxOutline.Position = boxTopLeft
                    dObj.boxOutline.Visible = true

                    dObj.box.Size = Vector2.new(boxWidth, boxHeight)
                    dObj.box.Position = boxTopLeft
                    dObj.box.Color = item.info.color
                    dObj.box.Visible = true

                    dObj.boxFill.Size = Vector2.new(boxWidth, boxHeight)
                    dObj.boxFill.Position = boxTopLeft
                    dObj.boxFill.Color = item.info.color
                    dObj.boxFill.Visible = true
                else
                    dObj.boxOutline.Visible = false
                    dObj.box.Visible = false
                    dObj.boxFill.Visible = false
                end

                -- Text Label with Ownership Tag
                local ownerTag = ""
                if item.ownership == "other" and item.ownerName then
                    ownerTag = string.format("\n[Owner: %s (Locked)]", item.ownerName)
                elseif item.ownership == "mine" then
                    ownerTag = "\n[★ YOUR ORE ★]"
                end

                dObj.txt.Text = string.format("%s [T%d %s]\nOdds: %s (%dm)%s", item.info.name, item.info.tierNum, item.info.tierName, item.info.rarityText, dist, ownerTag)
                dObj.txt.Position = Vector2.new(screenPos.X, boxTopLeft.Y - 28)
                dObj.txt.Color = item.info.color
                dObj.txt.Visible = true

            elseif item.is1M or item.info.rarityNum >= 1000000 or (Cfg.ESPFilter == "100k+ Ores Only" and (item.is100k or item.info.rarityNum >= 100000)) then
                -- Off-Screen Directional Edge Pointer for 1M+ Ores so you never miss them!
                activeThisFrame[part] = true
                local dObj = getOrCreateDrawing(part)

                local camCF = camera.CFrame
                local rel = camCF:PointToObjectSpace(cPos)
                local angle = math.atan2(-rel.Y, rel.X)
                local edgeX = screenCenter.X + math.cos(angle) * (screenCenter.X - 90)
                local edgeY = screenCenter.Y + math.sin(angle) * (screenCenter.Y - 70)
                edgeX = math.clamp(edgeX, 60, vpSize.X - 60)
                edgeY = math.clamp(edgeY, 50, vpSize.Y - 50)

                local ownerTag = (item.ownership == "other" and item.ownerName) and string.format(" [%s]", item.ownerName) or ""
                dObj.txt.Text = string.format("▶ %s [%s]%s (%dm)", item.info.name, item.info.rarityText, ownerTag, dist)
                dObj.txt.Position = Vector2.new(edgeX, edgeY)
                dObj.txt.Color = item.info.color
                dObj.txt.Visible = true

                dObj.box.Visible = false
                dObj.boxOutline.Visible = false
                dObj.boxFill.Visible = false
            end
        end
    end

    for part, dObj in pairs(activeDrawings) do
        if not activeThisFrame[part] then
            if dObj.txt then dObj.txt.Visible = false end
            if dObj.box then dObj.box.Visible = false end
            if dObj.boxOutline then dObj.boxOutline.Visible = false end
            if dObj.boxFill then dObj.boxFill.Visible = false end
            if not part or not part.Parent then
                pcall(function()
                    if dObj.txt then dObj.txt:Remove() end
                    if dObj.box then dObj.box:Remove() end
                    if dObj.boxOutline then dObj.boxOutline:Remove() end
                    if dObj.boxFill then dObj.boxFill:Remove() end
                end)
                activeDrawings[part] = nil
            end
        end
    end
end))

-- ============================================================
-- MINING, DRILLING, WALK FORWARD & ABILITY CONTROLS
-- ============================================================
local CachedTool = nil
local function refreshTool(char)
    if not char then CachedTool = nil; return end
    CachedTool = char:FindFirstChildOfClass("Tool")
    if not CachedTool then
        local bp = lp:FindFirstChild("Backpack")
        if bp then
            local t = bp:FindFirstChildOfClass("Tool")
            if t then t.Parent = char; CachedTool = t end
        end
    end
end

local function setPickaxeScriptState(enabled)
    pcall(function()
        local char = lp.Character
        local tool = char and char:FindFirstChildOfClass("Tool")
        if tool then
            local s = tool:FindFirstChild("PickaxeClientScript")
            if s and s:IsA("LocalScript") and s.Enabled ~= enabled then s.Enabled = enabled end
        end
    end)
end

-- Auto Use Ability Function (Full Multi-Trigger Suite)
local function useToolAbility()
    -- 1. Click any active ToolUI buttons (PickaxeUIs and LeftHandGearUIs)
    pcall(function()
        local toolUI = lp:FindFirstChild("PlayerGui") and lp.PlayerGui:FindFirstChild("ToolUI")
        if toolUI then
            local pu = toolUI:FindFirstChild("PickaxeUIs")
            if pu then
                for _, f in ipairs(pu:GetChildren()) do
                    if f:IsA("GuiObject") and f.Visible then
                        local act = f:FindFirstChild("Activate") or f:FindFirstChildWhichIsA("ImageButton") or f:FindFirstChildWhichIsA("TextButton")
                        if act and act:IsA("GuiButton") then
                            if firesignal then pcall(function() firesignal(act.MouseButton1Click) end) end
                            pcall(function() act:Activate() end)
                        end
                    end
                end
            end
            local lgu = toolUI:FindFirstChild("LeftHandGearUIs")
            if lgu then
                for _, f in ipairs(lgu:GetChildren()) do
                    if f:IsA("GuiObject") and f.Visible then
                        local act = f:FindFirstChild("Activate") or f:FindFirstChildWhichIsA("ImageButton") or f:FindFirstChildWhichIsA("TextButton")
                        if act and act:IsA("GuiButton") then
                            if firesignal then pcall(function() firesignal(act.MouseButton1Click) end) end
                            pcall(function() act:Activate() end)
                        end
                    end
                end
            end
        end
    end)

    -- 2. Simulate Keybinds (X for Pickaxe, F for Left-Hand Gear)
    pcall(function()
        local VIM = game:GetService("VirtualInputManager")
        VIM:SendKeyEvent(true, Enum.KeyCode.X, false, game)
        task.wait(0.02)
        VIM:SendKeyEvent(false, Enum.KeyCode.X, false, game)
        VIM:SendKeyEvent(true, Enum.KeyCode.F, false, game)
        task.wait(0.02)
        VIM:SendKeyEvent(false, Enum.KeyCode.F, false, game)
    end)

    -- 3. Tool activation & ability remote
    local char = lp.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    if tool then
        local abilityRemote = tool:FindFirstChild("Ability") or tool:FindFirstChild("UseAbility") or tool:FindFirstChild("RemoteEvent")
        if abilityRemote and abilityRemote:IsA("RemoteEvent") then
            pcall(function() abilityRemote:FireServer() end)
        end
        pcall(function() tool:Activate() end)
    end
end

-- Keybind X to use ability manually or auto-loop
table.insert(scriptConnections, UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Cfg.AbilityKeybind then
        useToolAbility()
    end
    if Cfg.AutoWalkForward and (input.KeyCode == Enum.KeyCode.W or input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.S or input.KeyCode == Enum.KeyCode.D) then
        task.defer(function()
            local c = lp.Character
            local r = c and c:FindFirstChild("HumanoidRootPart")
            if r then
                local look = r.CFrame.LookVector
                local flat = Vector3.new(look.X, 0, look.Z)
                if flat.Magnitude > 0.001 then
                    lockedWalkDir = flat.Unit
                end
            end
        end)
    end
end))

task.spawn(function()
    while isScriptAlive do
        task.wait(1.5)
        if Cfg.AutoUseAbility then
            useToolAbility()
        end
    end
end)

-- Anti-AFK Engine
table.insert(scriptConnections, lp.Idled:Connect(function()
    if Cfg.AntiAFK then
        VirtualUser:Button2Down(Vector2.zero, workspace.CurrentCamera.CFrame)
        task.wait(0.2)
        VirtualUser:Button2Up(Vector2.zero, workspace.CurrentCamera.CFrame)
    end
end))

-- Main Mining Loop
local LastTarget = nil
local lastTargetSearch = 0
local lastAutoTPTime = 0
local lastJitterTime = 0
local lastSteeringRayTime = 0
local lastNearPlayerCheckTime = 0
local isNearOtherPlayer = false
local lastStealthMineSwing = 0

-- Target Ore Sniping & Safe Return State
local preTargetCFrame = nil
local isSnipingTarget = false
local snipingTargetPart = nil
local snipingStartTime = 0

table.insert(scriptConnections, RunService.RenderStepped:Connect(function()
    local char = lp.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end

    -- CRITICAL SAFETY LOCK: If a 1M+ ore is active or being legitly mined, yield 100% control to handleRareOreSpawned!
    if rareOreSpawnedActive or activeMining1MTask or isResetWaiting then
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        hum:Move(Vector3.zero, false)
        return
    end

    local nowClock = os.clock()

    -- Active Ore Sniping Execution: Stand completely still, precision mine ore until destroyed, then return to preTargetCFrame!
    if isSnipingTarget then
        if snipingTargetPart and snipingTargetPart.Parent and (nowClock - snipingStartTime < 15) then
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            hum:Move(Vector3.zero, false)

            local pPos = (snipingTargetPart:IsA("BasePart") and snipingTargetPart.Position) or (snipingTargetPart:IsA("Model") and snipingTargetPart:GetPivot().Position)
            if pPos then
                if (pPos - root.Position).Magnitude > 8 then
                    safeTeleport(pPos, Vector3.new(0, 3.6, 0), pPos)
                end

                setPickaxeScriptState(false)
                if not CachedTool or CachedTool.Parent ~= char then refreshTool(char) end

                local origin = char:FindFirstChild("Head") and char.Head.Position or (root.Position + Vector3.new(0, 1.5, 0))
                local dir = (pPos - origin).Unit
                local GI = getGI()
                local rayParams = GI and GI.constants and GI.constants.mineRaycastParams
                local rayResult = rayParams and workspace:Raycast(origin, dir * 18, rayParams)
                local hitPos = (rayResult and rayResult.Position) or (pPos + Vector3.new(0, 2.0, 0))

                isAutoMining = true
                pcall(function() MineRemote:FireServer(true, origin, dir, hitPos) end)
                if CachedTool then pcall(function() CachedTool:Activate() end) end
                Stats.OresMined = Stats.OresMined + 1
            end
            return
        else
            -- Target ore destroyed or timed out! Return cleanly back to old pos!
            if Cfg.ReturnToOldPosTarget and preTargetCFrame then
                char:PivotTo(preTargetCFrame)
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
                preTargetCFrame = nil
            end
            isSnipingTarget = false
            snipingTargetPart = nil
            LastTarget = nil
            isAutoMining = false
        end
    end

    -- Player Proximity Stealth Check (every 0.5s)
    if Cfg.StealthMode and (nowClock - lastNearPlayerCheckTime > 0.5) then
        lastNearPlayerCheckTime = nowClock
        isNearOtherPlayer = false
        local sRadius = Cfg.StealthRadius or 35
        for _, otherPlayer in ipairs(Players:GetPlayers()) do
            if otherPlayer ~= lp and otherPlayer.Character then
                local oRoot = otherPlayer.Character:FindFirstChild("HumanoidRootPart")
                if oRoot and (oRoot.Position - root.Position).Magnitude <= sRadius then
                    isNearOtherPlayer = true
                    break
                end
            end
        end
    elseif not Cfg.StealthMode then
        isNearOtherPlayer = false
    end

    -- Auto Walk Forward (Smooth, straight world direction with legit obstacle avoidance & micro-jitter)
    if Cfg.AutoWalkForward and not isSnipingTarget then
        if not lockedWalkDir then
            local look = root.CFrame.LookVector
            local flat = Vector3.new(look.X, 0, look.Z)
            lockedWalkDir = flat.Magnitude > 0.001 and flat.Unit or Vector3.new(0, 0, -1)
        end

        -- Humanized Micro-Jitter (Anti-robotic slight heading variation every 2.5 - 4s)
        if Cfg.HumanizedJitter and (nowClock - lastJitterTime > 3.0) then
            lastJitterTime = nowClock + (math.random() * 1.5 - 0.75)
            local jitterAngle = (math.random() - 0.5) * 0.012 -- ~0.35 degrees
            local cosA = math.cos(jitterAngle)
            local sinA = math.sin(jitterAngle)
            lockedWalkDir = Vector3.new(
                lockedWalkDir.X * cosA - lockedWalkDir.Z * sinA,
                0,
                lockedWalkDir.X * sinA + lockedWalkDir.Z * cosA
            ).Unit
        end

        -- Legit Obstacle Navigation & Ledge Step-Over
        if Cfg.LegitSteering and (nowClock - lastSteeringRayTime > 0.08) then
            lastSteeringRayTime = nowClock
            local headPos = char:FindFirstChild("Head") and char.Head.Position or (root.Position + Vector3.new(0, 1.5, 0))
            local footPos = root.Position - Vector3.new(0, 2.2, 0)
            local GI = getGI()
            local rayParams = GI and GI.constants and GI.constants.mineRaycastParams

            -- 1. Check for small ledges / curbs at foot level
            local footRay = workspace:Raycast(footPos, lockedWalkDir * 4.0, rayParams)
            local headRay = workspace:Raycast(headPos, lockedWalkDir * 6.0, rayParams)

            if footRay and footRay.Instance and (not headRay or not headRay.Instance) then
                -- Foot hits a low curb/ledge, but head is clear -> Jump naturally over it!
                if hum.FloorMaterial ~= Enum.Material.Air then
                    hum.Jump = true
                end
            elseif headRay and headRay.Instance then
                -- Facing a solid rock face/wall -> Check left and right 35-degree corridors
                local rotLeft = CFrame.Angles(0, math.rad(35), 0)
                local rotRight = CFrame.Angles(0, math.rad(-35), 0)
                local leftDir = (rotLeft * Vector3.new(lockedWalkDir.X, 0, lockedWalkDir.Z)).Unit
                local rightDir = (rotRight * Vector3.new(lockedWalkDir.X, 0, lockedWalkDir.Z)).Unit

                local leftHit = workspace:Raycast(headPos, leftDir * 8.0, rayParams)
                local rightHit = workspace:Raycast(headPos, rightDir * 8.0, rayParams)

                if not leftHit and rightHit then
                    -- Left is open corridor -> Smoothly steer left
                    lockedWalkDir = (lockedWalkDir:Lerp(leftDir, 0.09)).Unit
                elseif not rightHit and leftHit then
                    -- Right is open corridor -> Smoothly steer right
                    lockedWalkDir = (lockedWalkDir:Lerp(rightDir, 0.09)).Unit
                elseif not leftHit and not rightHit then
                    -- Both open -> gentle bias towards left
                    lockedWalkDir = (lockedWalkDir:Lerp(leftDir, 0.05)).Unit
                end
            end
        end

        hum:Move(lockedWalkDir, false)
    end

    if not (Cfg.AutoMine or Cfg.DrillDown or Cfg.AutoMineStraight) then return end
    if not MineRemote then return end

    -- Stealth Mode: Throttle mining swing cadence if another player is nearby
    if isNearOtherPlayer then
        if nowClock - lastStealthMineSwing < 0.38 then
            return
        end
        lastStealthMineSwing = nowClock
    end

    setPickaxeScriptState(false)
    if not CachedTool or CachedTool.Parent ~= char then refreshTool(char) end

    local origin = char:FindFirstChild("Head") and char.Head.Position or (root.Position + Vector3.new(0, 1.5, 0))
    local GI = getGI()
    local rayParams = GI and GI.constants and GI.constants.mineRaycastParams

    -- 1. DRILL STRAIGHT DOWN
    if Cfg.DrillDown then
        if Cfg.DrillStopY and Cfg.DrillStopY > 0 and math.abs(root.Position.Y) >= Cfg.DrillStopY then
            Cfg.DrillDown = false
            pcall(function()
                if Rayfield then
                    Rayfield:Notify({Title = "Drill Down Stopped", Content = string.format("Reached target depth of %dm!", Cfg.DrillStopY), Duration = 3})
                end
            end)
            return
        end

        hum:Move(Vector3.zero, false)
        local downDir = Vector3.new(0, -1, 0)
        local rayResult = workspace:Raycast(origin, downDir * 28, rayParams)

        if rayResult and rayResult.Instance then
            pcall(function() MineRemote:FireServer(true, origin, downDir, rayResult.Position) end)
            if CachedTool then pcall(function() CachedTool:Activate() end) end
            Stats.OresMined = Stats.OresMined + 1

            if rayResult.Distance < 4.2 then
                -- Block right under feet: keep grounded without fighting floor collision
                local curVel = root.AssemblyLinearVelocity
                root.AssemblyLinearVelocity = Vector3.new(0, math.clamp(curVel.Y, -10, 0), 0)
            else
                -- Block broken: smoothly descend through shaft
                root.AssemblyLinearVelocity = Vector3.new(0, -42, 0)
            end
        else
            -- Open air below: descend through shaft
            root.AssemblyLinearVelocity = Vector3.new(0, -42, 0)
        end
        return
    end

    -- 2. AUTO MINE STRAIGHT FORWARD
    if Cfg.AutoMineStraight then
        local lookDir = root.CFrame.LookVector
        local rayDist = isNearOtherPlayer and 14 or 35
        local rayResult = rayParams and workspace:Raycast(origin, lookDir * rayDist, rayParams)
        if rayResult and rayResult.Instance then
            isAutoMining = true
            pcall(function() MineRemote:FireServer(true, origin, lookDir, rayResult.Position) end)
            if CachedTool then pcall(function() CachedTool:Activate() end) end
            Stats.OresMined = Stats.OresMined + 1
        else
            isAutoMining = false
        end
        return
    end

    -- 3. AUTO MINE (TARGET ORIENTED)
    local now = os.clock()
    if not LastTarget or not LastTarget.Parent or (now - lastTargetSearch > 0.3) or (LastTarget.Position - root.Position).Magnitude > 540 then
        lastTargetSearch = now
        LastTarget = nil

        local mineFolder = workspace:FindFirstChild("Mine")
        local placedFolder = workspace:FindFirstChild("PlacedBlocks")
        local filterList = {}
        if mineFolder then table.insert(filterList, mineFolder) end
        if placedFolder then table.insert(filterList, placedFolder) end

        local overlapParams = OverlapParams.new()
        overlapParams.FilterType = Enum.RaycastFilterType.Include
        overlapParams.FilterDescendantsInstances = filterList
        overlapParams.MaxParts = 200

        local parts = workspace:GetPartBoundsInRadius(root.Position, Cfg.AutoTPOre and 250 or 40, overlapParams)
        local closestDist = math.huge
        for _, part in ipairs(parts) do
            if part:IsA("BasePart") then
                local dist = (part.Position - root.Position).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    LastTarget = part
                end
            end
        end
    end

    if LastTarget and LastTarget.Parent then
        local targetOwner = LastTarget:GetAttribute("owner")
        if targetOwner and targetOwner ~= lp.UserId then
            LastTarget = nil
            isAutoMining = false
            return
        end

        local pPos = (LastTarget:IsA("BasePart") and LastTarget.Position) or (LastTarget:IsA("Model") and LastTarget:GetPivot().Position)
        if not pPos then
            LastTarget = nil
            isAutoMining = false
            return
        end

        if Cfg.AutoTPOre and not Cfg.LegitMining and not isNearOtherPlayer and (pPos - root.Position).Magnitude > 10 then
            preTargetCFrame = root.CFrame
            isSnipingTarget = true
            snipingTargetPart = LastTarget
            snipingStartTime = nowClock

            safeTeleport(pPos, Vector3.new(0, 3.6, 0), pPos)
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            hum:Move(Vector3.zero, false)
            return
        end

        local dir = (pPos - origin).Unit
        local rayDist = (Cfg.LegitMining or isNearOtherPlayer) and 24 or 500
        local rayResult = rayParams and workspace:Raycast(origin, dir * rayDist, rayParams)
        local hitPos = (rayResult and rayResult.Position) or (pPos + Vector3.new(0, 2.0, 0))

        isAutoMining = true
        pcall(function() MineRemote:FireServer(true, origin, dir, hitPos) end)
        if CachedTool then pcall(function() CachedTool:Activate() end) end
        Stats.OresMined = Stats.OresMined + 1
    else
        isAutoMining = false
    end
end))

-- ============================================================
-- RAYFIELD UI INITIALIZATION
-- ============================================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "REX: Reincarnation | Overhub Ultimate",
    LoadingTitle = "REX Overhub",
    LoadingSubtitle = "1M+ Ore & Board Edition",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
})

-- TAB 1: AUTO MINE
local MineTab = Window:CreateTab("Auto Mine", 4483362458)
MineTab:CreateSection("Mining Automation")

MineTab:CreateToggle({
    Name = "Enable Auto Mine",
    CurrentValue = Cfg.AutoMine,
    Callback = function(Value)
        Cfg.AutoMine = Value
        saveConfig()
        if not Value then setPickaxeScriptState(true); pcall(function() MineRemote:FireServer(false) end) end
    end
})

MineTab:CreateToggle({
    Name = "Auto Mine Straight Ahead",
    CurrentValue = Cfg.AutoMineStraight,
    Callback = function(Value)
        Cfg.AutoMineStraight = Value
        saveConfig()
        if not Value then setPickaxeScriptState(true); pcall(function() MineRemote:FireServer(false) end) end
    end
})

MineTab:CreateToggle({
    Name = "Auto Walk Forward",
    CurrentValue = Cfg.AutoWalkForward,
    Callback = function(Value)
        updateWalkState(Value)
        saveConfig()
    end
})

MineTab:CreateToggle({
    Name = "Safe / Legit Mining Mode",
    CurrentValue = Cfg.LegitMining,
    Callback = function(Value)
        Cfg.LegitMining = Value
        if Value and Cfg.AutoTPOre then
            Cfg.AutoTPOre = false
        end
        saveConfig()
        pcall(function()
            if Rayfield then
                Rayfield:Notify({
                    Title = Value and "Safe Mining Enabled" or "Safe Mining Disabled",
                    Content = Value and "Instant TP disabled. Mines & walks naturally towards targets!" or "Standard mining active.",
                    Duration = 3
                })
            end
        end)
    end
})

MineTab:CreateToggle({
    Name = "Auto Teleport To Target Ore",
    CurrentValue = Cfg.AutoTPOre,
    Callback = function(Value)
        Cfg.AutoTPOre = Value
        saveConfig()
    end
})

MineTab:CreateToggle({
    Name = "Return to Old Pos After Target Ore",
    CurrentValue = Cfg.ReturnToOldPosTarget,
    Callback = function(Value)
        Cfg.ReturnToOldPosTarget = Value
        saveConfig()
    end
})

MineTab:CreateSection("Vertical Drill")
MineTab:CreateToggle({
    Name = "Drill Straight Down",
    CurrentValue = Cfg.DrillDown,
    Callback = function(Value)
        Cfg.DrillDown = Value
        saveConfig()
        if not Value then setPickaxeScriptState(true); pcall(function() MineRemote:FireServer(false) end) end
    end
})

MineTab:CreateSlider({
    Name = "Drill Stop Depth (0 = Continuous)",
    Range = {0, 30000},
    Increment = 500,
    Suffix = "m",
    CurrentValue = Cfg.DrillStopY or 0,
    Callback = function(Value)
        Cfg.DrillStopY = Value
        saveConfig()
    end
})

-- TAB 2: TELEPORT BOARD & RESET LOOP
local ResetTab = Window:CreateTab("Board & Reset", 4483362458)
ResetTab:CreateSection("Auto-Reset Mine Loop")

ResetTab:CreateToggle({
    Name = "Enable Auto-Return On Mine Reset",
    CurrentValue = Cfg.AutoTPResetLoop,
    Callback = function(Value)
        Cfg.AutoTPResetLoop = Value
        saveConfig()
    end
})

ResetTab:CreateDropdown({
    Name = "Target Layer For Reset Loop",
    Options = BoardLayerNames,
    CurrentOption = {Cfg.TargetResetLayer},
    Callback = function(Option)
        Cfg.TargetResetLayer = Option[1]
        saveConfig()
    end
})

ResetTab:CreateSection("Official Board Teleport Buttons")
for _, layerName in ipairs(BoardLayerNames) do
    ResetTab:CreateButton({
        Name = "Teleport: " .. layerName,
        Callback = function()
            if teleportViaBoard(layerName) then
                Rayfield:Notify({Title = "Teleported", Content = "Teleported to " .. layerName .. "!", Duration = 2})
            end
        end
    })
end

-- TAB 3: 1M+ HUNTER & SMART ROUTING
local HunterTab = Window:CreateTab("1M+ Hunter", 4483362458)
HunterTab:CreateSection("Smart 1M+ Auto-Routing Engine")

HunterTab:CreateDropdown({
    Name = "1M+ Hunter Mode",
    Options = {
        "Smart Hybrid (Recommended)",
        "Event Priority Only",
        "Layer Roulette",
        "Target Ore Wishlist",
        "Disabled"
    },
    CurrentOption = {Cfg.HunterMode},
    Callback = function(Option)
        Cfg.HunterMode = Option[1]
        saveConfig()
        Rayfield:Notify({Title = "Hunter Mode Updated", Content = "Active Mode: " .. Option[1], Duration = 3})
    end
})

HunterTab:CreateToggle({
    Name = "Fresh Reset Map Sniffer",
    CurrentValue = Cfg.HunterSniffOnReset,
    Callback = function(Value)
        Cfg.HunterSniffOnReset = Value
        saveConfig()
        pcall(function()
            if Rayfield then
                Rayfield:Notify({
                    Title = Value and "Reset Sniffer Active" or "Reset Sniffer Disabled",
                    Content = Value and "Will scan the whole map for free 1M+ spawns immediately when mine regenerates!" or "Reset sniffer off.",
                    Duration = 3
                })
            end
        end)
    end
})

HunterTab:CreateToggle({
    Name = "Prioritize Active Event Layers (+15-20% Buff)",
    CurrentValue = Cfg.HunterPrioritizeEvents,
    Callback = function(Value)
        Cfg.HunterPrioritizeEvents = Value
        saveConfig()
    end
})

HunterTab:CreateSection("Target Ore Bounty Wishlist")

HunterTab:CreateDropdown({
    Name = "Target 1M+ Ore",
    Options = OreList1M,
    CurrentOption = {Cfg.HunterTargetOre},
    Callback = function(Option)
        Cfg.HunterTargetOre = Option[1]
        saveConfig()
        local nativeLayer = OreToLayerMap[Option[1]] or "Unknown Layer"
        Rayfield:Notify({
            Title = "Bounty Selected: " .. Option[1],
            Content = "Native Spawn Layer: " .. nativeLayer,
            Duration = 4
        })
    end
})

HunterTab:CreateButton({
    Name = "Teleport to Target Ore's Layer Now",
    Callback = function()
        local nativeLayer = OreToLayerMap[Cfg.HunterTargetOre]
        if nativeLayer then
            if teleportViaBoard(nativeLayer) then
                Rayfield:Notify({Title = "Teleported", Content = string.format("Teleported to %s for %s!", nativeLayer, Cfg.HunterTargetOre), Duration = 3})
            end
        else
            Rayfield:Notify({Title = "Notice", Content = "Could not resolve layer for " .. tostring(Cfg.HunterTargetOre), Duration = 3})
        end
    end
})

HunterTab:CreateSection("Layer Roulette & Event Sniping")

HunterTab:CreateButton({
    Name = "Teleport to Active Event Layer Now (+15-20% Buff)",
    Callback = function()
        local evLayer, evName, timeLeft = getActiveEventLayer()
        if evLayer then
            if teleportViaBoard(evLayer) then
                Rayfield:Notify({
                    Title = "Event Sniped!",
                    Content = string.format("Teleported to %s for %s event! (%d mins left)", evLayer, evName, math.floor(timeLeft / 60)),
                    Duration = 4
                })
            end
        else
            Rayfield:Notify({Title = "No Active Event", Content = "No active world event buff is running right now in Natura.", Duration = 3})
        end
    end
})

HunterTab:CreateButton({
    Name = "Cycle to Next Layer in Roulette Now",
    Callback = function()
        if #Cfg.RouletteLayers > 0 then
            Cfg.RouletteIndex = (Cfg.RouletteIndex % #Cfg.RouletteLayers) + 1
            local nextLayer = Cfg.RouletteLayers[Cfg.RouletteIndex]
            saveConfig()
            if teleportViaBoard(nextLayer) then
                Rayfield:Notify({Title = "Roulette Cycled", Content = string.format("Teleported to %s (%d/%d)", nextLayer, Cfg.RouletteIndex, #Cfg.RouletteLayers), Duration = 3})
            end
        end
    end
})

HunterTab:CreateButton({
    Name = "Force Whole-Map 1M+ Ore Sweep Now",
    Callback = function()
        populateRareOresRegistry()
        local foundPart, foundData = sniffFreshReset1MOre()
        if foundPart and foundData then
            local cPos = foundData.pos or foundPart.Position
            safeTeleport(cPos, Vector3.new(0, 5.5, 0))
            Rayfield:Notify({
                Title = "1M+ Ore Found!",
                Content = string.format("Found and teleported to %s (%s)!", foundData.info.name, foundData.info.rarityText),
                Duration = 4
            })
        else
            Rayfield:Notify({Title = "Map Sweep Complete", Content = "No unmined 1M+ ores currently sitting on the map.", Duration = 3})
        end
    end
})

HunterTab:CreateSection("Legit Steering & Humanized Farming")

HunterTab:CreateToggle({
    Name = "Legit Obstacle Steering (Natural Openings)",
    CurrentValue = Cfg.LegitSteering,
    Callback = function(Value)
        Cfg.LegitSteering = Value
        saveConfig()
    end
})

HunterTab:CreateToggle({
    Name = "Humanized Micro-Jitter (Anti-Bot Pathing)",
    CurrentValue = Cfg.HumanizedJitter,
    Callback = function(Value)
        Cfg.HumanizedJitter = Value
        saveConfig()
    end
})

HunterTab:CreateToggle({
    Name = "Player Proximity Stealth Mode",
    CurrentValue = Cfg.StealthMode,
    Callback = function(Value)
        Cfg.StealthMode = Value
        saveConfig()
    end
})

HunterTab:CreateSlider({
    Name = "Stealth Detection Radius",
    Range = {15, 100},
    Increment = 5,
    Suffix = " studs",
    CurrentValue = Cfg.StealthRadius,
    Callback = function(Value)
        Cfg.StealthRadius = Value
        saveConfig()
    end
})

-- TAB 4: CUSTOM TP & 1M+ ORES
local CustomTpTab = Window:CreateTab("Coordinates & 1M+ TP", 4483362458)

CustomTpTab:CreateSection("Live 1M+ Rare Ore Instant TP")

CustomTpTab:CreateToggle({
    Name = "Auto-TP to 1M+ Ore When Spawned",
    CurrentValue = Cfg.AutoTP1M,
    Callback = function(Value)
        Cfg.AutoTP1M = Value
        saveConfig()
    end
})

CustomTpTab:CreateToggle({
    Name = "Safe / Legit Mode (Walk & Mine, No TP)",
    CurrentValue = Cfg.LegitMining,
    Callback = function(Value)
        Cfg.LegitMining = Value
        saveConfig()
        pcall(function()
            if Rayfield then
                Rayfield:Notify({
                    Title = Value and "Safe Mode Active" or "Safe Mode Inactive",
                    Content = Value and "Will walk naturally to 1M+ ores without instant teleportation." or "Auto-TP will teleport directly.",
                    Duration = 3
                })
            end
        end)
    end
})

CustomTpTab:CreateToggle({
    Name = "Return to Old Pos After 1M+ Mine",
    CurrentValue = Cfg.ReturnToOldPos,
    Callback = function(Value)
        Cfg.ReturnToOldPos = Value
        saveConfig()
    end
})

CustomTpTab:CreateToggle({
    Name = "Continue Mining Forward from 1M+ Pos",
    CurrentValue = Cfg.ContinueFrom1MPos,
    Callback = function(Value)
        Cfg.ContinueFrom1MPos = Value
        saveConfig()
    end
})

CustomTpTab:CreateButton({
    Name = "Teleport to Closest 1M+ Ore",
    Callback = function()
        local success, msg = teleportToClosestRareOre()
        Rayfield:Notify({
            Title = success and "Teleported!" or "Notice",
            Content = msg,
            Duration = 3
        })
    end
})

CustomTpTab:CreateButton({
    Name = "Resume Forward Farm (From Current Position)",
    Callback = function()
        rareOreSpawnedActive = false
        activeMining1MTask = false
        updateWalkState(true)
        Cfg.AutoMine = true
        Cfg.AutoMineStraight = true
        saveConfig()
        pcall(function()
            if Rayfield then
                Rayfield:Notify({
                    Title = "Autofarm Resumed",
                    Content = "Resumed forward mining from current position!",
                    Duration = 3
                })
            end
        end)
    end
})

CustomTpTab:CreateSection("Paste Coordinates Teleport")

local inpCoords = CustomTpTab:CreateInput({
    Name = "Target Coords",
    PlaceholderText = "Paste e.g. 6, 20000, 6 or Vector3...",
    RemoveTextOnFocus = false,
    Callback = function(Text)
        Cfg.CustomTPCoords = Text
        saveConfig()
    end
})
if Cfg.CustomTPCoords ~= "" then pcall(function() inpCoords:Set(Cfg.CustomTPCoords) end) end

CustomTpTab:CreateButton({
    Name = "Teleport Directly Onto Block (Safe Clearance +5.5m)",
    Callback = function()
        local targetPos = parseCoords(Cfg.CustomTPCoords)
        if not targetPos then
            Rayfield:Notify({Title = "Invalid Format", Content = "Could not parse coordinates! Use e.g. 6, 20000, 6", Duration = 3})
            return
        end
        if safeTeleport(targetPos, Vector3.new(0, 5.5, 0)) then
            Rayfield:Notify({Title = "Teleported", Content = string.format("Safely teleported onto %.0f, %.0f, %.0f", targetPos.X, targetPos.Y, targetPos.Z), Duration = 2})
        end
    end
})

CustomTpTab:CreateButton({
    Name = "Teleport Beside Block (+5.5m Height Clearance)",
    Callback = function()
        local targetPos = parseCoords(Cfg.CustomTPCoords)
        if not targetPos then
            Rayfield:Notify({Title = "Invalid Format", Content = "Could not parse coordinates! Use e.g. 6, 20000, 6", Duration = 3})
            return
        end
        if safeTeleport(targetPos, Vector3.new(5, 5.5, 5)) then
            Rayfield:Notify({Title = "Teleported", Content = string.format("Safely teleported near %.0f, %.0f, %.0f", targetPos.X, targetPos.Y, targetPos.Z), Duration = 2})
        end
    end
})

CustomTpTab:CreateButton({
    Name = "Copy My Current Coordinates",
    Callback = function()
        local char = lp.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then
            local pos = root.Position
            local coordStr = string.format("%.0f, %.0f, %.0f", pos.X, pos.Y, pos.Z)
            pcall(function()
                if setclipboard then setclipboard(coordStr) end
            end)
            Rayfield:Notify({Title = "Coordinates Copied!", Content = "Position: " .. coordStr .. (setclipboard and " (Copied to Clipboard)" or ""), Duration = 4})
        end
    end
})

-- TAB 4: ORE ESP & CHAMS
local EspTab = Window:CreateTab("Ore ESP", 4483362458)
EspTab:CreateSection("Zero-Lag 2D Drawing Chams")

EspTab:CreateToggle({
    Name = "Enable Ore ESP (2D Screen)",
    CurrentValue = Cfg.ESPEnabled,
    Callback = function(Value)
        Cfg.ESPEnabled = Value
        saveConfig()
        if not Value then clearAllDrawings() end
    end
})

EspTab:CreateToggle({
    Name = "Enable 2D Block Chams (Box & Glow)",
    CurrentValue = Cfg.ESPChams,
    Callback = function(Value)
        Cfg.ESPChams = Value
        saveConfig()
    end
})

EspTab:CreateDropdown({
    Name = "ESP Filter",
    Options = {"1M+ Ores Only", "100k+ Ores Only", "10k+ (Exotic+)", "Rare+ (Tier 4+)", "All Ores"},
    CurrentOption = {Cfg.ESPFilter},
    Callback = function(Option)
        Cfg.ESPFilter = Option[1]
        saveConfig()
        clearAllDrawings()
        scanOresForESP()
    end
})

EspTab:CreateSlider({
    Name = "Max ESP Distance",
    Range = {100, 50000},
    Increment = 500,
    Suffix = "m",
    CurrentValue = Cfg.ESPMaxDist,
    Callback = function(Value)
        Cfg.ESPMaxDist = Value
        saveConfig()
        clearAllDrawings()
        scanOresForESP()
    end
})

-- TAB 5: WEBHOOKS & NOTIFICATIONS
local WebhookTab = Window:CreateTab("Webhooks", 4483362458)

WebhookTab:CreateSection("1M+ Rare Ore Webhook")
local inp1M = WebhookTab:CreateInput({
    Name = "Webhook URL",
    PlaceholderText = "Paste 1M+ Webhook URL...",
    RemoveTextOnFocus = false,
    Callback = function(Text)
        Cfg.WebhookURL_1M = Text
        saveConfig()
    end
})
if Cfg.WebhookURL_1M ~= "" then pcall(function() inp1M:Set(Cfg.WebhookURL_1M) end) end

local inpDiscord = WebhookTab:CreateInput({
    Name = "User ID (@Ping)",
    PlaceholderText = "Discord ID (blank = @everyone)",
    RemoveTextOnFocus = false,
    Callback = function(Text)
        Cfg.DiscordUserId = Text
        saveConfig()
    end
})
if Cfg.DiscordUserId ~= "" then pcall(function() inpDiscord:Set(Cfg.DiscordUserId) end) end

WebhookTab:CreateToggle({
    Name = "Alerts Enabled",
    CurrentValue = Cfg.Webhook1MAlerts,
    Callback = function(Value)
        Cfg.Webhook1MAlerts = Value
        saveConfig()
    end
})

WebhookTab:CreateToggle({
    Name = "Stop On 1M+ Spawn",
    CurrentValue = Cfg.StopOn1MSpawn,
    Callback = function(Value)
        Cfg.StopOn1MSpawn = Value
        saveConfig()
    end
})

WebhookTab:CreateButton({
    Name = "Test 1M+ Alert (Your Ore)",
    Callback = function()
        if getWebhookURL("1M") == "" then
            Rayfield:Notify({Title = "Error", Content = "Please enter a 1M+ or Fallback Webhook URL first!", Duration = 3})
            return
        end
        handleRareOreSpawned("Cosmilite", "1/42,100,021", "Manual Test Simulation", nil, nil, "mine", lp.Name, "Mantle Layer", "6,083m")
        Rayfield:Notify({Title = "Test Sent", Content = "Your Ore test webhook notification sent!", Duration = 3})
    end
})

WebhookTab:CreateButton({
    Name = "Test 1M+ Alert (Other Player Spawn)",
    Callback = function()
        if getWebhookURL("1M") == "" then
            Rayfield:Notify({Title = "Error", Content = "Please enter a 1M+ or Fallback Webhook URL first!", Duration = 3})
            return
        end
        handleRareOreSpawned("Cosmilite", "1/42,100,021", "Manual Test Simulation", nil, nil, "other", "OtherPlayer_99", "Outer Core Layer", "14,200m")
        Rayfield:Notify({Title = "Test Sent", Content = "Other player test webhook notification sent! (Autofarm not interrupted)", Duration = 3})
    end
})

WebhookTab:CreateSection("World Events Webhook")
local inpEvents = WebhookTab:CreateInput({
    Name = "Event Webhook URL",
    PlaceholderText = "Paste Event Webhook (blank = 1M+ URL)...",
    RemoveTextOnFocus = false,
    Callback = function(Text)
        Cfg.WebhookURL_Events = Text
        saveConfig()
    end
})
if Cfg.WebhookURL_Events ~= "" then pcall(function() inpEvents:Set(Cfg.WebhookURL_Events) end) end

WebhookTab:CreateToggle({
    Name = "Event Alerts Enabled",
    CurrentValue = Cfg.WebhookEventAlerts,
    Callback = function(Value)
        Cfg.WebhookEventAlerts = Value
        saveConfig()
    end
})

WebhookTab:CreateToggle({
    Name = "Lifecycle Logs (Start/5m Warning/End)",
    CurrentValue = Cfg.EventWebhookLogs,
    Callback = function(Value)
        Cfg.EventWebhookLogs = Value
        saveConfig()
    end
})

WebhookTab:CreateSlider({
    Name = "Event Heartbeat Interval",
    Range = {2, 15},
    Increment = 1,
    Suffix = " mins",
    CurrentValue = math.floor((Cfg.EventWebhookInterval or 300) / 60),
    Callback = function(Value)
        Cfg.EventWebhookInterval = Value * 60
        saveConfig()
    end
})

WebhookTab:CreateButton({
    Name = "Test World Event Alert",
    Callback = function()
        if getWebhookURL("Events") == "" then
            Rayfield:Notify({Title = "Error", Content = "Please enter an Event, 1M+, or Fallback Webhook URL first!", Duration = 3})
            return
        end
        local GI = getGI()
        local evInfo = GI and GI.eventInfo
        local evName = (evInfo and evInfo.event and evInfo.event.name) or "Spristium"
        local evMsg = (evInfo and evInfo.event and evInfo.event.information and evInfo.event.information.message) or "An almighty crystal glitters green deep in the Granite layer..."
        local evBuff = (evInfo and evInfo.event and evInfo.event.eventEffects) or "All ores in the Granite layer are +15% more common."
        local evRarity = (evInfo and evInfo.event and evInfo.event.information and evInfo.event.information.oreRarity and ("1/" .. formatNum(evInfo.event.information.oreRarity))) or "1/8,600,000"

        sendWebhook("Events", "WORLD EVENT STARTED: " .. evName, string.format("Event: %s\nBuff / Effects: %s\nSpecial Ore Rarity: %s\nDuration: 45 mins\nDescription: %s", evName, evBuff, evRarity, evMsg), true)
        Rayfield:Notify({Title = "Test Sent", Content = "World event webhook notification triggered!", Duration = 3})
    end
})

WebhookTab:CreateSection("Mine Reset Webhook")
local inpReset = WebhookTab:CreateInput({
    Name = "Reset Webhook URL",
    PlaceholderText = "Paste Reset Webhook URL...",
    RemoveTextOnFocus = false,
    Callback = function(Text)
        Cfg.WebhookURL_Reset = Text
        saveConfig()
    end
})
if Cfg.WebhookURL_Reset ~= "" then pcall(function() inpReset:Set(Cfg.WebhookURL_Reset) end) end

WebhookTab:CreateToggle({
    Name = "Reset Alerts Enabled",
    CurrentValue = Cfg.WebhookResetAlerts,
    Callback = function(Value)
        Cfg.WebhookResetAlerts = Value
        saveConfig()
    end
})

WebhookTab:CreateButton({
    Name = "Test Mine Reset Alert",
    Callback = function()
        if getWebhookURL("Reset") == "" then
            Rayfield:Notify({Title = "Error", Content = "Please enter a Reset or Fallback Webhook URL first!", Duration = 3})
            return
        end
        sendWebhook("Reset", "Mine Reset Simulation", "Test simulation: Mine has begun resetting. Walking and mining paused.", false)
    end
})

WebhookTab:CreateSection("Mining Progress Reports")
local inpProgress = WebhookTab:CreateInput({
    Name = "Progress URL",
    PlaceholderText = "Paste Progress Webhook URL...",
    RemoveTextOnFocus = false,
    Callback = function(Text)
        Cfg.WebhookURL_Progress = Text
        saveConfig()
    end
})
if Cfg.WebhookURL_Progress ~= "" then pcall(function() inpProgress:Set(Cfg.WebhookURL_Progress) end) end

WebhookTab:CreateToggle({
    Name = "Reports Enabled",
    CurrentValue = Cfg.AutoWebhookProgress,
    Callback = function(Value)
        Cfg.AutoWebhookProgress = Value
        saveConfig()
    end
})

WebhookTab:CreateSlider({
    Name = "Report Interval",
    Range = {1, 60},
    Increment = 1,
    Suffix = "min",
    CurrentValue = math.floor(Cfg.WebhookInterval / 60),
    Callback = function(Value)
        Cfg.WebhookInterval = Value * 60
        saveConfig()
    end
})

WebhookTab:CreateButton({
    Name = "Test Progress Report",
    Callback = function()
        if getWebhookURL("Progress") == "" then
            Rayfield:Notify({Title = "Error", Content = "Please enter a Progress or Fallback Webhook URL first!", Duration = 3})
            return
        end
        sendWebhook("Progress", "Mining Progress Report (Test)", "Manual test: Mining statistics sent successfully!", false)
    end
})

WebhookTab:CreateSection("General Fallback Webhook")
local inpGeneral = WebhookTab:CreateInput({
    Name = "Fallback URL",
    PlaceholderText = "Used if specific URL above is empty...",
    RemoveTextOnFocus = false,
    Callback = function(Text)
        Cfg.WebhookURL_General = Text
        Cfg.WebhookURL = Text
        saveConfig()
    end
})
if Cfg.WebhookURL_General ~= "" then pcall(function() inpGeneral:Set(Cfg.WebhookURL_General) end) end

-- TAB 6: UTILITIES & PERFORMANCE
local UtilTab = Window:CreateTab("Utilities", 4483362458)

UtilTab:CreateSection("Settings & Config File Manager")
UtilTab:CreateButton({
    Name = "Save Settings Now to File",
    Callback = function()
        if saveConfig() then
            Rayfield:Notify({Title = "Config Saved!", Content = "Saved all settings to workspace/REXOverhub/config.json", Duration = 3})
        else
            Rayfield:Notify({Title = "Save Error", Content = "Executor writefile function not available!", Duration = 3})
        end
    end
})

UtilTab:CreateButton({
    Name = "Reload Settings from File",
    Callback = function()
        if loadConfig() then
            Rayfield:Notify({Title = "Config Loaded!", Content = "All settings reloaded from file!", Duration = 3})
        else
            Rayfield:Notify({Title = "Notice", Content = "No existing config file found yet.", Duration = 3})
        end
    end
})

UtilTab:CreateSection("Character & Abilities")

UtilTab:CreateToggle({
    Name = "Auto Use Tool Ability (Loop)",
    CurrentValue = Cfg.AutoUseAbility,
    Callback = function(Value)
        Cfg.AutoUseAbility = Value
        saveConfig()
    end
})

UtilTab:CreateButton({
    Name = "Trigger Tool Ability Now [X]",
    Callback = function()
        useToolAbility()
    end
})

UtilTab:CreateToggle({
    Name = "Anti-AFK (20-Min Kick Bypasser)",
    CurrentValue = Cfg.AntiAFK,
    Callback = function(Value)
        Cfg.AntiAFK = Value
        saveConfig()
    end
})

populateRareOresRegistry()
Rayfield:Notify({Title = "REX Overhub Ultimate", Content = "Loaded! Config auto-saving active.", Duration = 3})

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
    CustomTPCoords          = "",
    DrillDown               = false,
    DrillStopY              = 1400,
    AutoWalkForward         = false,
    AutoMineStraight        = false,
    AutoUseAbility          = false,
    AbilityKeybind          = Enum.KeyCode.X,
    AntiAFK                 = true,
    StopOn1MSpawn           = true,
    LegitMining             = false,
    ContinueFrom1MPos       = true,
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
            LegitMining         = Cfg.LegitMining,
            ContinueFrom1MPos   = Cfg.ContinueFrom1MPos,
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

-- Anti-Stuck Safe Teleport System (Uses char:PivotTo with +5.5m clearance and collision reset)
local function safeTeleport(pos, offset)
    local char = lp.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum or not pos then return false end

    -- Safe clearance: REX blocks are 4x4x4 (center to top face is +2.0 studs).
    -- Humanoid hip height + leg length means feet are 3.0 studs below HumanoidRootPart.
    -- Offset Y + 5.5 ensures feet land at +2.5 studs (safely 0.5 studs above the block surface, never clipping into geometry).
    offset = offset or Vector3.new(0, 5.5, 0)
    local targetPos = pos + offset

    -- 1. Zero all momentum so player doesn't slide into walls or fling
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero

    -- 2. Clear locked walk direction so character doesn't walk into old orientation
    lockedWalkDir = nil

    -- 3. Pivot the character model atomically (avoids limb motor desync)
    char:PivotTo(CFrame.new(targetPos))

    -- 4. Temporarily disable limb collisions for 0.15s to guarantee no clipping wedge
    for _, part in ipairs(char:GetChildren()) do
        if part:IsA("BasePart") and part ~= root then
            part.CanCollide = false
        end
    end

    -- 5. Force humanoid physics recovery
    task.defer(function()
        task.wait(0.05)
        if hum and hum.Parent then
            hum:ChangeState(Enum.HumanoidStateType.Freefall)
            task.wait(0.05)
            hum:ChangeState(Enum.HumanoidStateType.Running)
        end
    end)

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
    local isRare = (info.rarityNum >= 10000 or info.tierNum >= 4)

    if isRare or is1M then
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

            if Cfg.AutoTPResetLoop then
                pcall(function()
                    if Rayfield then
                        Rayfield:Notify({Title = "Mine Regenerated", Content = "Auto-teleporting to " .. Cfg.TargetResetLayer .. "!", Duration = 3})
                    end
                end)

                if Cfg.TargetResetLayer == "Pre-Reset Location (Last Position)" then
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
                    teleportViaBoard(Cfg.TargetResetLayer)
                end

                task.wait(1.0)
            else
                pcall(function()
                    if Rayfield then
                        Rayfield:Notify({Title = "Mine Regenerated", Content = "Mine active. Resuming movement...", Duration = 2})
                    end
                end)
            end

            if Cfg.WebhookResetAlerts then
                sendWebhook("Reset", "Mine Regenerated", "Mine has regenerated! Returned to " .. Cfg.TargetResetLayer .. " and resumed operations.", false)
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

local function handleRareOreSpawned(oreName, rarityLabel, sourceMsg, part, cPos, ownership, ownerName, areaName, depthStr)
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
            task.wait(0.1)
            safeTeleport(cPos, Vector3.new(0, 5.5, 0))
            task.wait(0.2)

            local timeout = os.clock() + 30
            while isScriptAlive and not isResetWaiting and os.clock() < timeout do
                if not part or not part.Parent then break end
                local char = lp.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                local pPos = part:IsA("BasePart") and part.Position or cPos
                local origin = char and char:FindFirstChild("Head") and char.Head.Position or (root and root.Position + Vector3.new(0, 1.5, 0)) or pPos

                if MineRemote and origin then
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
                            Title = "1M+ Ore Mined!",
                            Content = "Continuing forward mining from new position!",
                            Duration = 4
                        })
                    end
                end)
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
                elseif Cfg.ESPFilter == "10k+ (Exotic+)" then
                    pass = (info.rarityNum >= 10000 or info.tierNum >= 8)
                elseif Cfg.ESPFilter == "Rare+ (Tier 4+)" then
                    pass = (info.tierNum >= 4)
                elseif Cfg.ESPFilter == "All Ores" then
                    pass = true
                end

                -- 1M+ ores IGNORE distance limit completely! They render across the whole world!
                if pass and (data.is1M or info.rarityNum >= 1000000 or dist <= Cfg.ESPMaxDist) then
                    table.insert(candidates, {
                        part = part,
                        pos = cPos,
                        size = data.size or Vector3.new(4, 4, 4),
                        info = info,
                        dist = dist,
                        is1M = data.is1M or (info.rarityNum >= 1000000 or info.tierNum >= 10),
                        ownership = data.ownership,
                        ownerName = data.ownerName
                    })
                end
            end
        else
            rareOresRegistry[part] = nil
        end
    end

    -- Sort: 1M+ ores first, then highest rarity, then closest
    table.sort(candidates, function(a, b)
        if a.is1M ~= b.is1M then return a.is1M end
        if a.info.rarityNum ~= b.info.rarityNum then return a.info.rarityNum > b.info.rarityNum end
        return a.dist < b.dist
    end)

    local topCandidates = {}
    for _, cand in ipairs(candidates) do
        if cand.is1M or #topCandidates < 40 then
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

            elseif item.is1M or item.info.rarityNum >= 1000000 then
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

-- Auto Use Ability Function
local function useToolAbility()
    local char = lp.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    if tool then
        local abilityRemote = tool:FindFirstChild("Ability") or tool:FindFirstChild("UseAbility") or tool:FindFirstChild("RemoteEvent")
        if abilityRemote and abilityRemote:IsA("RemoteEvent") then
            pcall(function() abilityRemote:FireServer() end)
        else
            pcall(function() tool:Activate() end)
        end
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

table.insert(scriptConnections, RunService.RenderStepped:Connect(function()
    local char = lp.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end

    -- Auto Walk Forward (Smooth, straight world direction, pauses during reset/1M+ alerts)
    if Cfg.AutoWalkForward and not isResetWaiting and not (Cfg.StopOn1MSpawn and rareOreSpawnedActive) then
        if not lockedWalkDir then
            local look = root.CFrame.LookVector
            local flat = Vector3.new(look.X, 0, look.Z)
            lockedWalkDir = flat.Magnitude > 0.001 and flat.Unit or Vector3.new(0, 0, -1)
        end
        hum:Move(lockedWalkDir, false)
    end

    if isResetWaiting or (Cfg.StopOn1MSpawn and rareOreSpawnedActive) then return end
    if not (Cfg.AutoMine or Cfg.DrillDown or Cfg.AutoMineStraight) then return end
    if not MineRemote then return end

    setPickaxeScriptState(false)
    if not CachedTool or CachedTool.Parent ~= char then refreshTool(char) end

    local origin = char:FindFirstChild("Head") and char.Head.Position or (root.Position + Vector3.new(0, 1.5, 0))
    local GI = getGI()
    local rayParams = GI and GI.constants and GI.constants.mineRaycastParams

    -- 1. DRILL STRAIGHT DOWN
    if Cfg.DrillDown then
        if Cfg.DrillStopY and root.Position.Y <= Cfg.DrillStopY then
            Cfg.DrillDown = false
            return
        end
        local downDir = Vector3.new(0, -1, 0)
        local rayResult = workspace:Raycast(origin, downDir * 40, rayParams)
        if rayResult and rayResult.Instance then
            pcall(function() MineRemote:FireServer(true, origin, downDir, rayResult.Position) end)
            if CachedTool then pcall(function() CachedTool:Activate() end) end
            Stats.OresMined = Stats.OresMined + 1
        end
        local curVel = root.AssemblyLinearVelocity
        root.AssemblyLinearVelocity = Vector3.new(0, math.clamp(curVel.Y, -90, -25), 0)
        return
    end

    -- 2. AUTO MINE STRAIGHT FORWARD
    if Cfg.AutoMineStraight then
        local lookDir = root.CFrame.LookVector
        local rayResult = workspace:Raycast(origin, lookDir * 35, rayParams)
        if rayResult and rayResult.Instance then
            pcall(function() MineRemote:FireServer(true, origin, lookDir, rayResult.Position) end)
            if CachedTool then pcall(function() CachedTool:Activate() end) end
            Stats.OresMined = Stats.OresMined + 1
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
            return
        end

        if Cfg.AutoTPOre and not Cfg.LegitMining and (LastTarget.Position - root.Position).Magnitude > 12 then
            local nowTP = os.clock()
            if nowTP - lastAutoTPTime > 1.2 then
                lastAutoTPTime = nowTP
                safeTeleport(LastTarget.Position, Vector3.new(0, 5.5, 0))
            end
        end

        local dir = (LastTarget.Position - origin).Unit
        local rayDist = Cfg.LegitMining and 28 or 500
        local rayResult = workspace:Raycast(origin, dir * rayDist, rayParams)
        if rayResult and rayResult.Instance then
            pcall(function() MineRemote:FireServer(true, origin, dir, rayResult.Position) end)
            if CachedTool then pcall(function() CachedTool:Activate() end) end
            Stats.OresMined = Stats.OresMined + 1
        else
            LastTarget = nil
        end
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
    ConfigurationSaving = { Enabled = true, FolderName = "REXOverhub", FileName = "UltimateConfig" },
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

-- TAB 3: CUSTOM TP & 1M+ ORES
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
    Options = {"1M+ Ores Only", "10k+ (Exotic+)", "Rare+ (Tier 4+)", "All Ores"},
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

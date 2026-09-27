--[[
    Rayn Hub | Steal a Egg
    UI/Foundation build
    No key system.

    NOTE:
    Game-specific actions such as Auto Steal, Auto Capture, Anti Hit,
    God Mode, Faster Steal, Egg ESP and Auto Place require the actual
    game's current objects/remotes. This build provides the complete
    UI/config framework and implements the features that can be done
    generically. Game-specific hooks are intentionally isolated below.
]]

-- Game guard: Rayn Hub is intended for this Steal a Egg place.
local TARGET_PLACE_ID = 107778070777162

if game.PlaceId ~= TARGET_PLACE_ID then
    warn("[Rayn Hub] Wrong game. This script is only for Steal a Egg.")
    return
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local RaynHub = {
    Name = "Rayn Hub",
    GameName = "Steal a Egg",
    ConfigFile = "RaynHub_StealAEgg.json",
    Config = {
        ShowFloatingLogo = true,
        AutoSave = true,
        LoadOnStart = true,

        AutoSteal = false,
        AutoCapture = false,
        ContestRange = 45,
        AvoidTraps = false,
        TargetPriority = "Best Rarity",
        ReturnToPlot = false,
        ReturnToLastPosition = false,
        AntiAFK = true,
        AutoExecute = false,
        AutoReconnect = false,

        GodMode = false,
        AntiHit = false,
        FasterSteal = false,
        GlideSpeed = 850,
        AntiTreadmill = false,

        BatAura = false,
        AutoBestBat = false,

        EggESP = false,
        EggESPMaxDistance = 1200,
        ESPShowEveryone = false,
        OnlyMutated = false,

        AutoPlaceSelected = false,
        AutoPlaceAll = false,
        AutoHatchReady = false,

        AutoTreadmill = false,
        AutoTreadmillUpgrade = false,
        AutoUpgradePen = false,

        FPSBoost = false,

        SelectedAreas = {},
        SelectedRarities = {},
        SelectedMutations = {},
        MatchAllMutations = false,
    }
}

--////////////////////////////////////////////////////////////
-- Helpers
--////////////////////////////////////////////////////////////

local function safeCall(fn, ...)
    local ok, result = pcall(fn, ...)
    if ok then return result end
end

local function hasFileAPI()
    return type(writefile) == "function"
       and type(readfile) == "function"
       and type(isfile) == "function"
end

local function saveConfig()
    if not hasFileAPI() then return false end
    local ok, data = pcall(function()
        return HttpService:JSONEncode(RaynHub.Config)
    end)
    if not ok then return false end
    return pcall(writefile, RaynHub.ConfigFile, data)
end

local function loadConfig()
    if not hasFileAPI() or not isfile(RaynHub.ConfigFile) then return false end
    local ok, data = pcall(readfile, RaynHub.ConfigFile)
    if not ok then return false end

    local decodedOk, decoded = pcall(function()
        return HttpService:JSONDecode(data)
    end)
    if not decodedOk or type(decoded) ~= "table" then return false end

    for k, v in pairs(decoded) do
        RaynHub.Config[k] = v
    end
    return true
end

local function getCharacter()
    return LocalPlayer.Character
end

local function getHumanoid()
    local c = getCharacter()
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function getRoot()
    local c = getCharacter()
    return c and c:FindFirstChild("HumanoidRootPart")
end

--////////////////////////////////////////////////////////////
-- Game-specific hooks
--////////////////////////////////////////////////////////////

local GameHooks = {}

function GameHooks.AutoSteal()
    -- Hook the game's current steal/capture RemoteEvent here.
end

function GameHooks.AutoCapture()
    -- Hook the game's current capture interaction here.
end

function GameHooks.AntiHit()
    -- Game-specific protection requires the current combat implementation.
end

function GameHooks.GodMode()
    -- Do not fake this: connect to the game's current health/damage system.
end

function GameHooks.FasterSteal()
    -- Hook the current steal movement/remote implementation.
end

function GameHooks.EggESP()
    -- ESP scanner hook for the game's current egg objects.
end

function GameHooks.AutoPlace()
    -- Hook current egg placement interaction.
end

function GameHooks.AutoHatch()
    -- Hook current egg hatch interaction.
end

--////////////////////////////////////////////////////////////
-- Generic features
--////////////////////////////////////////////////////////////

local noclipConnection
local afkConnection
local fpsBoostApplied = false

local function setNoclip(enabled)
    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end

    if not enabled then return end

    noclipConnection = RunService.Stepped:Connect(function()
        local character = getCharacter()
        if not character then return end
        for _, obj in ipairs(character:GetDescendants()) do
            if obj:IsA("BasePart") then
                obj.CanCollide = false
            end
        end
    end)
end

local function antiAFK()
    if afkConnection then
        afkConnection:Disconnect()
        afkConnection = nil
    end

    if not RaynHub.Config.AntiAFK then return end

    afkConnection = LocalPlayer.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end

local function applyFPSBoost(enabled)
    -- Conservative optimization: do not destroy map objects or remove textures.
    if not enabled then
        return
    end

    local Lighting = game:GetService("Lighting")
    safeCall(function()
        Lighting.GlobalShadows = false
    end)

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ParticleEmitter") or obj:IsA("Trail") then
            obj.Enabled = false
        elseif obj:IsA("PostEffect") then
            obj.Enabled = false
        end
    end

    fpsBoostApplied = true
end

local function rejoin()
    safeCall(function()
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end)
end

local function serverHop()
    -- Uses Roblox's public games endpoint through HttpGet when supported.
    if type(request) ~= "function" and type(http_request) ~= "function" and type(syn) ~= "table" then
        return
    end

    local req = request or http_request or (syn and syn.request)
    if type(req) ~= "function" then return end

    local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId)
    local ok, response = pcall(req, {Url = url, Method = "GET"})
    if not ok or not response or not response.Body then return end

    local decoded = safeCall(function()
        return HttpService:JSONDecode(response.Body)
    end)
    if not decoded or not decoded.data then return end

    for _, server in ipairs(decoded.data) do
        if server.id ~= game.JobId and server.playing < server.maxPlayers then
            safeCall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
            end)
            break
        end
    end
end

local function getPing()
    local ok, value = pcall(function()
        local item = Stats.Network.ServerStatsItem["Data Ping"]
        return item:GetValue()
    end)
    return ok and math.floor(value + 0.5) or 0
end

--////////////////////////////////////////////////////////////
-- UI
--////////////////////////////////////////////////////////////

local gui = Instance.new("ScreenGui")
gui.Name = "RaynHub"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = PlayerGui

local function corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = parent
end

local function stroke(parent, transparency)
    local s = Instance.new("UIStroke")
    s.Color = Color3.fromRGB(45, 38, 58)
    s.Transparency = transparency or 0
    s.Thickness = 1
    s.Parent = parent
end

local function label(parent, text, size, color)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextSize = size or 14
    l.Font = Enum.Font.Gotham
    l.TextColor3 = color or Color3.fromRGB(225, 225, 235)
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = parent
    return l
end

local function button(parent, text)
    local b = Instance.new("TextButton")
    b.AutoButtonColor = false
    b.BackgroundColor3 = Color3.fromRGB(25, 21, 29)
    b.Text = text
    b.TextSize = 13
    b.Font = Enum.Font.GothamMedium
    b.TextColor3 = Color3.fromRGB(225, 225, 235)
    b.Parent = parent
    corner(b, 7)
    stroke(b, 0.25)
    return b
end

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.fromOffset(900, 560)
Main.Position = UDim2.new(0.5, -450, 0.5, -280)
Main.BackgroundColor3 = Color3.fromRGB(13, 11, 15)
Main.Parent = gui
corner(Main, 14)
stroke(Main, 0.05)

local Top = Instance.new("Frame")
Top.Size = UDim2.new(1, 0, 0, 52)
Top.BackgroundColor3 = Color3.fromRGB(17, 14, 20)
Top.Parent = Main
corner(Top, 14)

local Title = label(Top, "Rayn Hub", 16, Color3.fromRGB(145, 105, 255))
Title.Position = UDim2.fromOffset(18, 7)
Title.Size = UDim2.fromOffset(105, 20)
Title.Font = Enum.Font.GothamBold

local GameTitle = label(Top, "|  Steal a Egg", 13, Color3.fromRGB(125, 120, 135))
GameTitle.Position = UDim2.fromOffset(115, 8)
GameTitle.Size = UDim2.fromOffset(150, 20)

local StatsLabel = label(Top, "60 FPS  |  0 ms  |  00:00:00", 12, Color3.fromRGB(150, 145, 160))
StatsLabel.Position = UDim2.fromOffset(270, 8)
StatsLabel.Size = UDim2.fromOffset(300, 20)

local Search = Instance.new("TextBox")
Search.PlaceholderText = "search..."
Search.Text = ""
Search.ClearTextOnFocus = false
Search.TextSize = 12
Search.Font = Enum.Font.Gotham
Search.TextColor3 = Color3.fromRGB(220, 220, 230)
Search.PlaceholderColor3 = Color3.fromRGB(110, 105, 120)
Search.BackgroundColor3 = Color3.fromRGB(24, 20, 28)
Search.Size = UDim2.fromOffset(160, 30)
Search.Position = UDim2.new(1, -175, 0, 11)
Search.Parent = Top
corner(Search, 8)

local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.fromOffset(190, 508)
Sidebar.Position = UDim2.fromOffset(0, 52)
Sidebar.BackgroundColor3 = Color3.fromRGB(16, 13, 18)
Sidebar.Parent = Main

local Content = Instance.new("ScrollingFrame")
Content.Size = UDim2.new(1, -190, 1, -52)
Content.Position = UDim2.fromOffset(190, 52)
Content.BackgroundColor3 = Color3.fromRGB(11, 9, 13)
Content.BorderSizePixel = 0
Content.ScrollBarThickness = 4
Content.CanvasSize = UDim2.new()
Content.Parent = Main

local ContentPadding = Instance.new("UIPadding")
ContentPadding.PaddingTop = UDim.new(0, 18)
ContentPadding.PaddingLeft = UDim.new(0, 18)
ContentPadding.PaddingRight = UDim.new(0, 18)
Content.PaddingBottom = UDim.new(0, 18)
ContentPadding.Parent = Content

local ContentLayout = Instance.new("UIListLayout")
ContentLayout.Padding = UDim.new(0, 12)
ContentLayout.Parent = Content

ContentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    Content.CanvasSize = UDim2.new(0, 0, 0, ContentLayout.AbsoluteContentSize.Y + 30)
end)

-- Floating logo: image slot is intentionally configurable.
local Floating = Instance.new("ImageButton")
Floating.Name = "FloatingLogo"
Floating.Size = UDim2.fromOffset(64, 64)
Floating.Position = UDim2.new(0, 24, 0.5, -32)
Floating.BackgroundColor3 = Color3.fromRGB(22, 19, 28)
Floating.Image = "" -- Put your uploaded Roblox image asset id here.
Floating.Parent = gui
corner(Floating, 32)
stroke(Floating, 0.1)

local FloatingText = label(Floating, "R", 24, Color3.fromRGB(145, 105, 255))
FloatingText.TextXAlignment = Enum.TextXAlignment.Center
FloatingText.Size = UDim2.fromScale(1, 1)

Floating.MouseButton1Click:Connect(function()
    Main.Visible = not Main.Visible
end)

--////////////////////////////////////////////////////////////
-- Dragging
--////////////////////////////////////////////////////////////

do
    local dragging = false
    local dragStart, startPos

    Top.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = Main.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        local delta = input.Position - dragStart
        Main.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end)
end

--////////////////////////////////////////////////////////////
-- Controls
--////////////////////////////////////////////////////////////

local function clearContent()
    for _, child in ipairs(Content:GetChildren()) do
        if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
            child:Destroy()
        end
    end
end

local function section(titleText)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 44)
    frame.BackgroundColor3 = Color3.fromRGB(18, 15, 22)
    frame.Parent = Content
    corner(frame, 9)

    local t = label(frame, titleText, 14, Color3.fromRGB(225, 220, 235))
    t.Position = UDim2.fromOffset(14, 12)
    t.Size = UDim2.new(1, -28, 0, 22)
    t.Font = Enum.Font.GothamBold

    return frame
end

local function toggle(titleText, key, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 42)
    frame.BackgroundColor3 = Color3.fromRGB(19, 16, 23)
    frame.Parent = Content
    corner(frame, 8)

    local t = label(frame, titleText, 13)
    t.Position = UDim2.fromOffset(14, 10)
    t.Size = UDim2.new(1, -75, 0, 22)

    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(44, 24)
    b.Position = UDim2.new(1, -58, 0.5, -12)
    b.BackgroundColor3 = Color3.fromRGB(35, 30, 42)
    b.Text = ""
    b.Parent = frame
    corner(b, 12)

    local dot = Instance.new("Frame")
    dot.Size = UDim2.fromOffset(18, 18)
    dot.Position = UDim2.fromOffset(3, 3)
    dot.BackgroundColor3 = Color3.fromRGB(190, 185, 205)
    dot.Parent = b
    corner(dot, 9)

    local function render()
        local on = RaynHub.Config[key] == true
        b.BackgroundColor3 = on and Color3.fromRGB(72, 48, 150) or Color3.fromRGB(35, 30, 42)
        dot.Position = on and UDim2.new(1, -21, 0, 3) or UDim2.fromOffset(3, 3)
        dot.BackgroundColor3 = on and Color3.fromRGB(225, 220, 255) or Color3.fromRGB(190, 185, 205)
    end

    b.MouseButton1Click:Connect(function()
        RaynHub.Config[key] = not RaynHub.Config[key]
        render()
        if callback then safeCall(callback, RaynHub.Config[key]) end
        if RaynHub.Config.AutoSave then saveConfig() end
    end)

    render()
    return frame
end

local function action(titleText, callback)
    local b = button(Content, titleText)
    b.Size = UDim2.new(1, 0, 0, 38)
    b.MouseButton1Click:Connect(function()
        safeCall(callback)
    end)
    return b
end

local function info(textValue)
    local l = label(Content, textValue, 12, Color3.fromRGB(135, 130, 145))
    l.Size = UDim2.new(1, 0, 0, 24)
    return l
end

--////////////////////////////////////////////////////////////
-- Pages
--////////////////////////////////////////////////////////////

local function pageHome()
    clearContent()
    section("Quick actions")
    action("Save Config", saveConfig)
    action("Load Config", function()
        if loadConfig() then
            antiAFK()
            if RaynHub.Config.FPSBoost then applyFPSBoost(true) end
        end
    end)
    action("Rejoin", rejoin)
    action("Server Hop", serverHop)
    toggle("Show Floating Logo", "ShowFloatingLogo", function(v)
        Floating.Visible = v
    end)

    section("Status")
    info("FPS / ping / players / time are shown in the header.")
    info("Config file: " .. RaynHub.ConfigFile)
    info(hasFileAPI() and "Executor file API: available" or "Executor file API: unavailable")
end

local function pageEggs()
    clearContent()

    section("Auto Steal")
    toggle("Auto Steal Eggs", "AutoSteal", function(v)
        if v then GameHooks.AutoSteal() end
    end)
    toggle("Auto Capture Egg", "AutoCapture", function(v)
        if v then GameHooks.AutoCapture() end
    end)
    info("Contest Free Range: " .. tostring(RaynHub.Config.ContestRange) .. " studs")
    toggle("Avoid Traps", "AvoidTraps")

    section("Target Priority")
    info("Best Rarity / Best KG / Best $/s / Best Mutation / Closest / Custom")
    action("Target: " .. RaynHub.Config.TargetPriority, function()
        local list = {"Best Rarity", "Best KG", "Best $/s", "Best Mutation", "Closest", "Custom"}
        local current = table.find(list, RaynHub.Config.TargetPriority) or 1
        current = current % #list + 1
        RaynHub.Config.TargetPriority = list[current]
        pageEggs()
    end)

    section("Return / Session")
    toggle("Return To Plot", "ReturnToPlot")
    toggle("Return To Last Position", "ReturnToLastPosition")
    toggle("Anti AFK", "AntiAFK", function() antiAFK() end)
    toggle("Auto Execute", "AutoExecute")
    toggle("Auto Reconnect", "AutoReconnect")

    section("Auto Steal Filter")
    info("Areas / Rarities / Mutations are designed as multi-select filters.")
    info("Select Secret + Divine + Eternal to make those the only rarity targets.")
    toggle("Match ALL Selected Mutations", "MatchAllMutations")
    toggle("Only Mutated Eggs", "OnlyMutated")
    info("Game-specific filter values are intentionally not guessed.")
end

local function pageEggAutomation()
    clearContent()
    section("Egg Automation")
    toggle("Auto Place Selected", "AutoPlaceSelected", function(v)
        if v then GameHooks.AutoPlace() end
    end)
    toggle("Auto Place All", "AutoPlaceAll", function(v)
        if v then GameHooks.AutoPlace() end
    end)
    toggle("Auto Hatch Ready", "AutoHatchReady", function(v)
        if v then GameHooks.AutoHatch() end
    end)
    info("Selected egg/area/mutation lists will be connected to the game's current egg objects.")
end

local function pageProgression()
    clearContent()
    section("Progression")
    toggle("Auto Upgrade Pen", "AutoUpgradePen")
    toggle("Auto Treadmill Training", "AutoTreadmill")
    toggle("Auto Treadmill Upgrade", "AutoTreadmillUpgrade")
    toggle("Auto Equip Best Gear", "AutoBestBat")
end

local function pagePets()
    clearContent()
    section("Pets")
    toggle("Auto Equip Best Pets", "AutoBestBat")
    info("Pet-specific automation requires the game's current inventory objects.")
end

local function pageVisual()
    clearContent()
    section("Performance")
    toggle("FPS Boost", "FPSBoost", function(v)
        if v then applyFPSBoost(true) end
    end)
    info("FPS Boost is conservative: it does not delete the map or remove textures.")

    section("Egg ESP")
    toggle("Egg ESP", "EggESP", function(v)
        if v then GameHooks.EggESP() end
    end)
    info("ESP target: Egg name + rarity + distance.")
    info("Egg ESP Filter: rarity-only filtering.")
    toggle("Only Mutated Eggs", "OnlyMutated")
    info("Max distance: " .. tostring(RaynHub.Config.EggESPMaxDistance) .. " studs")
end

local function pageContest()
    clearContent()
    section("Contest Players")
    toggle("Bat Aura", "BatAura", function(v)
        -- Game-specific attack targeting belongs in GameHooks.
    end)
    toggle("Auto Equip Best Bat", "AutoBestBat")
    info("Bat Aura is intended to auto-attack nearby contest targets.")
end

local function pageOP()
    clearContent()
    section("OP Stuff")
    toggle("God Mode", "GodMode", function(v)
        if v then GameHooks.GodMode() end
    end)
    toggle("Anti Hit", "AntiHit", function(v)
        if v then GameHooks.AntiHit() end
    end)
    toggle("Faster Steal", "FasterSteal", function(v)
        if v then GameHooks.FasterSteal() end
    end)
    info("Glide speed: " .. tostring(RaynHub.Config.GlideSpeed) .. " studs/s")
    toggle("Anti Treadmill", "AntiTreadmill")
end

-- Sidebar buttons
local pages = {
    {"Home", pageHome},
    {"Eggs", pageEggs},
    {"Egg Automation", pageEggAutomation},
    {"Progression", pageProgression},
    {"Pets", pagePets},
    {"Visual", pageVisual},
    {"Contest", pageContest},
    {"OP Stuff", pageOP},
}

local sideLayout = Instance.new("UIListLayout")
sideLayout.Padding = UDim.new(0, 4)
sideLayout.Parent = Sidebar

local sidePad = Instance.new("UIPadding")
sidePad.PaddingTop = UDim.new(0, 18)
sidePad.PaddingLeft = UDim.new(0, 12)
sidePad.PaddingRight = UDim.new(0, 12)
sidePad.Parent = Sidebar

for _, item in ipairs(pages) do
    local b = button(Sidebar, item[1])
    b.Size = UDim2.new(1, 0, 0, 36)
    b.MouseButton1Click:Connect(item[2])
end

--////////////////////////////////////////////////////////////
-- Live header
--////////////////////////////////////////////////////////////

local last = os.clock()
local frames = 0
local fps = 60

RunService.RenderStepped:Connect(function()
    frames += 1
    local now = os.clock()
    if now - last >= 1 then
        fps = frames / (now - last)
        frames = 0
        last = now

        local timeText = os.date("%H:%M:%S")
        local ping = getPing()
        local playerCount = #Players:GetPlayers()

        StatsLabel.Text = string.format(
            "%d FPS  |  %d ms  |  %s  |  %d players",
            math.floor(fps + 0.5),
            ping,
            timeText,
            playerCount
        )
    end
end)

--////////////////////////////////////////////////////////////
-- Respawn / reconnect
--////////////////////////////////////////////////////////////

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    antiAFK()
end)

-- Load config and initialize
if RaynHub.Config.LoadOnStart then
    loadConfig()
end

Floating.Visible = RaynHub.Config.ShowFloatingLogo
antiAFK()

if RaynHub.Config.FPSBoost then
    applyFPSBoost(true)
end

pageHome()

return RaynHub

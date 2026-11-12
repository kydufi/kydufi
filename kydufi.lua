local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local GameWindowFocused = true
local GameWindowFocusConnections = {}
pcall(function()
    table.insert(GameWindowFocusConnections, UserInputService.WindowFocused:Connect(function()
        GameWindowFocused = true
    end))
    table.insert(GameWindowFocusConnections, UserInputService.WindowFocusReleased:Connect(function()
        GameWindowFocused = false
    end))
    local focused = UserInputService:IsWindowFocused()
    if type(focused) == "boolean" then GameWindowFocused = focused end
end)
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
-- Runtime is an extensible registry of optional feature hooks.
local Runtime: { [string]: any } = { Closed = false, Cleanups = {} }
Runtime.Cleanup = function()
    if Runtime.Closed then return end
    Runtime.Closed = true
    for _, callback in ipairs(Runtime.Cleanups) do pcall(callback) end
    table.clear(Runtime.Cleanups)
end
local function onCleanup(callback)
    if Runtime.Closed then pcall(callback) else table.insert(Runtime.Cleanups, callback) end
end
Runtime.Version = "compact-topnav-3-stability1"
Runtime.StartupLog = {}
Runtime.Trace = function(stage)
    Runtime.LastStage = tostring(stage)
    local message = "[Bootlean Fisch " .. Runtime.Version .. "] " .. Runtime.LastStage
    table.insert(Runtime.StartupLog, os.date("!%Y-%m-%dT%H:%M:%SZ") .. " " .. message)
    if #Runtime.StartupLog > 48 then table.remove(Runtime.StartupLog, 1) end
    print(message)
    if type(writefile) == "function" then
        pcall(writefile, "BootleanFisch-last-run.txt", table.concat(Runtime.StartupLog, "\n") .. "\n")
    end
end
Runtime.Trace("Starting")
do
    local ok, environment = pcall(function() return type(getgenv) == "function" and getgenv() or _G end)
    if ok and type(environment) == "table" then
        local previous = rawget(environment, "BootleanFischRuntime")
        local previousCleanup = type(previous) == "table" and rawget(previous, "Cleanup")
        if type(previousCleanup) == "function" then pcall(previousCleanup) end
        pcall(function() environment.BootleanFischRuntime = Runtime end)
    end
end
Runtime.Trace("Previous runtime cleaned")
onCleanup(function()
    for _, connection in ipairs(GameWindowFocusConnections) do pcall(function() connection:Disconnect() end) end
end)
local HUB_NAME = "Bootlean Fisch"
local SETTINGS_FOLDER = "BootleanFisch"
local SETTINGS_PATH = SETTINGS_FOLDER .. "/settings_" .. tostring(LocalPlayer.UserId) .. ".json"

local function readSavedSettings()
    if type(isfile) ~= "function" or type(readfile) ~= "function" then
        return {}
    end

    local ok, data = pcall(function()
        if not isfile(SETTINGS_PATH) then return nil end
        return HttpService:JSONDecode(readfile(SETTINGS_PATH))
    end)
    return ok and type(data) == "table" and data or {}
end

local SavedSettings = readSavedSettings()

local function savedBoolean(key, defaultValue)
    local value = SavedSettings[key]
    if type(value) == "boolean" then
        return value
    end
    return defaultValue
end

local function savedNumber(key, defaultValue, minimum, maximum)
    local value = tonumber(SavedSettings[key])
    if not value then return defaultValue end
    return math.clamp(value, minimum, maximum)
end

local CoordinateValues = { X = "0", Y = "0", Z = "0" }
if type(SavedSettings.Coordinates) == "table" then
    for _, axis in ipairs({ "X", "Y", "Z" }) do
        local value = SavedSettings.Coordinates[axis]
        if value ~= nil then
            CoordinateValues[axis] = tostring(value)
        end
    end
end

local MainPointName = (tostring(SavedSettings.MainPointName or "Main Point"):gsub("%c", ""):match("^%s*(.-)%s*$") or ""):sub(1, 48)
if MainPointName == "" then MainPointName = "Main Point" end
local SavedMainPoint
if type(SavedSettings.MainPoint) == "table" then
    local pointX = tonumber(SavedSettings.MainPoint.X)
    local pointY = tonumber(SavedSettings.MainPoint.Y)
    local pointZ = tonumber(SavedSettings.MainPoint.Z)
    if pointX and pointY and pointZ
        and math.abs(pointX) <= 100000
        and math.abs(pointY) <= 100000
        and math.abs(pointZ) <= 100000 then
        SavedMainPoint = Vector3.new(pointX, pointY, pointZ)
    end
end

local GPSState = { Points = {}, SelectedPoint = nil }
do
    local seen = {}
    local points = type(SavedSettings.SavedPoints) == "table" and SavedSettings.SavedPoints or {}
    for _, point in ipairs(points) do
        if #GPSState.Points >= 100 then break end
        if type(point) == "table" then
            local name = (tostring(point.Name or ""):gsub("%c", ""):match("^%s*(.-)%s*$") or ""):sub(1, 48)
            local x, y, z = tonumber(point.X), tonumber(point.Y), tonumber(point.Z)
            if name ~= "" and not seen[name] and x and y and z
                and x == x and y == y and z == z
                and math.abs(x) <= 100000 and math.abs(y) <= 100000 and math.abs(z) <= 100000 then
                table.insert(GPSState.Points, { Name = name, X = x, Y = y, Z = z })
                seen[name] = true
            end
        end
    end
    if SavedMainPoint and not seen[MainPointName] and #GPSState.Points < 100 then
        table.insert(GPSState.Points, { Name = MainPointName, X = SavedMainPoint.X, Y = SavedMainPoint.Y, Z = SavedMainPoint.Z })
    end
    local selected = tostring(SavedSettings.SelectedPoint or MainPointName)
    for _, point in ipairs(GPSState.Points) do
        if point.Name == selected then GPSState.SelectedPoint = selected; break end
    end
end

local DEFAULT_TOGGLE_KEY = "RightControl"
local ToggleKeyName = tostring(SavedSettings.ToggleKey or DEFAULT_TOGGLE_KEY)
local toggleKeyExists = pcall(function()
    assert(Enum.KeyCode[ToggleKeyName] and Enum.KeyCode[ToggleKeyName] ~= Enum.KeyCode.Unknown)
end)
if not toggleKeyExists or ToggleKeyName == "LeftShift" or ToggleKeyName == "RightShift" then
    ToggleKeyName = DEFAULT_TOGGLE_KEY
end

local savedAccent = tostring(SavedSettings.Accent or "#72a6e6")
if not savedAccent:match("^#%x%x%x%x%x%x$") then
    savedAccent = "#72a6e6"
end

local AppearanceState = {
    Theme = tostring(SavedSettings.Theme or "Dark"),
    Accent = savedAccent,
    Acrylic = savedBoolean("Acrylic", false),
    Transparency = savedNumber("Transparency", 0, 0, 0.3),
    Scale = savedNumber("Scale", 0.8, 0.7, 1.15),
}
-- The clean remake drops the old tiny/transparent layout once, then keeps new preferences.
if SavedSettings.GUIRevision ~= "compact-topnav-3" then
    AppearanceState.Theme = "Dark"
    AppearanceState.Accent = "#72a6e6"
    AppearanceState.Acrylic = false
    AppearanceState.Transparency = 0
    AppearanceState.Scale = 0.8
end
local WaypointVisible = savedBoolean("WaypointVisible", true)
local VisualState = {
    Preset = tostring(SavedSettings.VisualPreset or "Balanced"),
    PostFX = savedBoolean("PostFX", true),
    NoFog = savedBoolean("NoFog", false),
    Brightness = tonumber(SavedSettings.Brightness),
    Saturation = tonumber(SavedSettings.Saturation) or 0,
    Contrast = tonumber(SavedSettings.Contrast) or 0,
    FieldOfView = tonumber(SavedSettings.FieldOfView),
}
VisualState.Options = {}
do
    local savedOptions = type(SavedSettings.VisualOptions) == "table" and SavedSettings.VisualOptions or {}
    for _, key in ipairs({ "Particles", "TrailsBeams", "PartShadows", "Textures", "Reflections", "LightShadows", "WaterEffects", "Bloom", "SunRays", "Blur", "DepthOfField" }) do
        VisualState.Options[key] = savedOptions[key] ~= false
    end
    VisualState.Options.FlatMaterials = savedOptions.FlatMaterials == true
    VisualState.Options.Shadows = type(savedOptions.Shadows) == "boolean" and savedOptions.Shadows or (savedOptions.Shadows == nil and Lighting.GlobalShadows)
end
if VisualState.Brightness then VisualState.Brightness = math.clamp(VisualState.Brightness, 0, 5) end
VisualState.Saturation = math.clamp(VisualState.Saturation, -1, 1)
VisualState.Contrast = math.clamp(VisualState.Contrast, -1, 1)
if VisualState.FieldOfView then VisualState.FieldOfView = math.clamp(VisualState.FieldOfView, 50, 120) end
if VisualState.Preset ~= "Performance"
    and VisualState.Preset ~= "Balanced"
    and VisualState.Preset ~= "Quality" then
    VisualState.Preset = "Balanced"
end
local savedSkyColor = tostring(SavedSettings.SkyColor or "#D7C6FF")
if not savedSkyColor:match("^#%x%x%x%x%x%x$") then
    savedSkyColor = "#D7C6FF"
end
local SkyState = {
    Enabled = savedBoolean("SkyTint", false),
    Color = savedSkyColor,
}
local AquariumGoal = tostring(SavedSettings.AquariumGoal or "Items")
if AquariumGoal ~= "Items" and AquariumGoal ~= "XP" and AquariumGoal ~= "Cash" then
    AquariumGoal = "Items"
end
local AquariumReminder = savedBoolean("AquariumReminder", false)

Runtime.ReadPlayerStat = function(keys)
    local sources = { LocalPlayer:FindFirstChild("stats"), LocalPlayer:FindFirstChild("leaderstats") }
    local replicated = ReplicatedStorage:FindFirstChild("playerstats") or ReplicatedStorage:FindFirstChild("PlayerStats")
    local playerStats = replicated and (replicated:FindFirstChild(LocalPlayer.Name) or replicated:FindFirstChild(tostring(LocalPlayer.UserId)))
    if playerStats then
        table.insert(sources, playerStats:FindFirstChild("stats") or playerStats:FindFirstChild("Stats") or playerStats)
    end
    for _, key in ipairs(keys) do
        local attribute = tonumber(LocalPlayer:GetAttribute(key))
        if attribute then return attribute end
        for _, folder in pairs(sources) do
            local value = folder and (folder:FindFirstChild(key) or folder:FindFirstChild(key:lower()))
            if value and value:IsA("ValueBase") then
                local ok, number = pcall(function() return tonumber(value.Value) end)
                if ok and number then return number end
            end
        end
    end
    return nil
end

local NavigationMode = SavedSettings.NavigationMode == "GPS" and "GPS" or "Teleport"

local Config = {
    Enabled = false,
    TeleportBusy = false,
    AutomationBusy = false,
    AquariumBusy = false,
    EventTravelPending = false,
    TeleportRadius = savedNumber("TeleportRadius",48,12,96),
    TeleportSearchHeight = savedNumber("TeleportSearchHeight",160,48,256),
    LastFishingError = "",
    AutoCast = savedBoolean("AutoCast", true),
    AutoShake = savedBoolean("AutoShake", true),
    AutoReel = savedBoolean("AutoReel", true),
    CatchNotifications = savedBoolean("CatchNotifications", true),
    InstantBobber = savedBoolean("InstantBobber", true),
    Power = savedNumber("Power", 100, 10, 100),
    PerfectCast = savedBoolean("PerfectCast", true),
    Delay = savedNumber("Delay", 1, 0, 10),
    AutoNotes = savedBoolean("AutoNotes", true),
    NoteLead = savedNumber("NoteLead", 0.08, 0.02, 0.4),
    NoteKeyword = (tostring(SavedSettings.NoteKeyword or "note"):lower():gsub("[^%w]", "")),
    ReelUpdateInterval = 0.05, -- 20 updates/sec instead of every rendered frame
    CastTimeout = 150,
    ReelTimeout = 20,
    FishingPhase = "Disabled",
}
onCleanup(function() Config.Enabled = false; Config.FishingMode = nil end)
do
    local frames, elapsed, slow, worst = 0, 0, 0, 0
    local ok, connection = pcall(function()
        return game:GetService("RunService").Heartbeat:Connect(function(dt)
            if Runtime.Closed or dt <= 0 then return end
            frames, elapsed = frames + 1, elapsed + dt
            worst = math.max(worst, dt)
            if dt > 1 / 45 then slow = slow + 1 end
            if elapsed >= 2 then
                Runtime.FrameStats = { FPS = frames / elapsed, WorstMs = worst * 1000, SlowFrames = slow }
                frames, elapsed, slow, worst = 0, 0, 0, 0
            end
        end)
    end)
    if ok then onCleanup(function() connection:Disconnect() end) end
end

local LoopThread
local Busy = false
local AutoFishToggle, AutoNotesToggle
local ShakeArgs
local AutoShakeHookRunning = true
local WrappedShakeCallback
local ShakeCallbackSource
local CachedShakeUI
local FishingState: { Generation: number, Phase: string, ShakeStartedAt: number, LastShakeInputAt: number, LastCastAt: number, CastRequest: any, Character: any, HadActivity: boolean?, MissingSince: number?, NextCastAt: number? } = { Generation = 0, Phase = "Idle", ShakeStartedAt = 0, LastShakeInputAt = 0, LastCastAt = 0 }
local LastReelRetry
local LastReelRetryAt = 0
local CastPendingAt = 0
local CatchTimerStartedAt
local CatchTimerResultText
local CatchTimerResultUntil = 0
local CatchTimerParagraph
local CatchTimerRunning = true
local updateCatchTimerText
local observeLocalCatchReel

local function saveLocalSettings()
    if type(writefile) ~= "function" then
        return false, "This executor does not provide local file saving."
    end

    local ok, err = pcall(function()
        if type(isfolder) == "function" and not isfolder(SETTINGS_FOLDER) then
            if type(makefolder) ~= "function" then
                error("Folder creation is unavailable.")
            end
            makefolder(SETTINGS_FOLDER)
        elseif type(isfolder) ~= "function" and type(makefolder) == "function" then
            pcall(makefolder, SETTINGS_FOLDER)
        end

        local data = {
            UserId = LocalPlayer.UserId,
            GUIRevision = "compact-topnav-3",
            NavigationMode = NavigationMode,
            VisitedLocations = Runtime.DiscoveryVisits,
            TeleportRadius = Config.TeleportRadius,
            TeleportSearchHeight = Config.TeleportSearchHeight,
            ToggleKey = ToggleKeyName,
            AutoCast = Config.AutoCast,
            AutoShake = Config.AutoShake,
            AutoReel = Config.AutoReel,
            CatchNotifications = Config.CatchNotifications,
            InstantBobber = Config.InstantBobber,
            Power = Config.Power,
            PerfectCast = Config.PerfectCast,
            Delay = Config.Delay,
            AutoNotes = Config.AutoNotes,
            NoteLead = Config.NoteLead,
            NoteKeyword = Config.NoteKeyword,
            Theme = AppearanceState.Theme,
            Accent = AppearanceState.Accent,
            Acrylic = AppearanceState.Acrylic,
            Transparency = AppearanceState.Transparency,
            Scale = AppearanceState.Scale,
            VisualPreset = VisualState.Preset,
            VisualOptions = VisualState.Options,
            PostFX = VisualState.PostFX,
            NoFog = VisualState.NoFog,
            Brightness = VisualState.Brightness,
            Saturation = VisualState.Saturation,
            Contrast = VisualState.Contrast,
            FieldOfView = VisualState.FieldOfView,
            SkyTint = SkyState.Enabled,
            SkyColor = SkyState.Color,
            AquariumGoal = AquariumGoal,
            AquariumReminder = AquariumReminder,
            WaypointVisible = WaypointVisible,
            MainPointName = MainPointName,
            SavedPoints = GPSState.Points,
            SelectedPoint = GPSState.SelectedPoint,
            Coordinates = CoordinateValues,
            MainPoint = SavedMainPoint and {
                X = SavedMainPoint.X,
                Y = SavedMainPoint.Y,
                Z = SavedMainPoint.Z,
            } or nil,
        }
        writefile(SETTINGS_PATH, HttpService:JSONEncode(data))
    end)

    return ok, err
end

local function setShakeStatus(message)
    -- Status feedback is intentionally hidden to keep the Fishing tab compact.
end

local function getUIContainer()
    local ok, hui = pcall(function()
        return gethui and gethui()
    end)
    if ok and hui then return hui end

    local ok2, coreGui = pcall(function()
        return game:GetService("CoreGui")
    end)
    if ok2 and coreGui then return coreGui end

    return LocalPlayer:WaitForChild("PlayerGui")
end

Runtime.Trace("Loading game controllers")
local Packages = ReplicatedStorage:WaitForChild("packages")
local Net = require(Packages:WaitForChild("Net"))

local ReelController = require(
    ReplicatedStorage:WaitForChild("client")
        :WaitForChild("legacyControllers")
        :WaitForChild("ReelController")
)

local CastRemote = Net:RemoteFunction("FishingRod/Cast")
local ResetRemote = Net:RemoteEvent("FishingRod/Reset")
local ShakeStartRF = Net:RemoteFunction("LureShake/Start")

local function invokeCastWithTimeout(power, perfectCast, timeout)
    local request = FishingState.CastRequest
    if not request then
        request = { Done = false, Deadline = os.clock() + timeout, ObservedActivity = false }
        FishingState.CastRequest = request
        request.Worker = task.spawn(function()
            request.OK, request.Value = pcall(function()
                return CastRemote:InvokeServer(power, perfectCast)
            end)
            request.Done = true
        end)
    end
    if request.Done then
        if FishingState.CastRequest == request then FishingState.CastRequest = nil end
        return request.OK, request.Value, if request.OK then nil else tostring(request.Value), request.ObservedActivity
    end
    if os.clock() >= request.Deadline then
        if request.Worker then pcall(function() task.cancel(request.Worker) end) end
        if FishingState.CastRequest == request then FishingState.CastRequest = nil end
        FishingState.LastCastAt = os.clock()
        return false, nil, "Cast request timed out.", request.ObservedActivity
    end
    -- Never await this invocation in the fishing loop. Its server handler may
    -- itself be waiting for the client SHAKE callback to complete.
    return nil, nil, "Cast request pending.", request.ObservedActivity
end

-- Only inspect the executor callback while auto shake is in use. Some
-- executors implement callback reads natively; idle startup needs no hook.
local function installShakeInterceptor()
    if Runtime.Closed or not Config.Enabled or not Config.AutoShake then return false end
    if WrappedShakeCallback then
        local ok, current = pcall(function()
            return ShakeStartRF.OnClientInvoke
        end)
        if ok and current == WrappedShakeCallback then
            setShakeStatus("Shake callback hooked; waiting for prompt.")
            return true
        end
    end

    local original
    local propertyOK, current = pcall(function()
        return ShakeStartRF.OnClientInvoke
    end)
    if propertyOK and type(current) == "function" and current ~= WrappedShakeCallback then
        original = current
    end

    if not original and type(getcallbackvalue) == "function" then
        if not Runtime.ShakeNativeReadLogged then
            Runtime.ShakeNativeReadLogged = true
            Runtime.Trace("Auto Shake: reading native callback")
        end
        local ok, callback = pcall(getcallbackvalue, ShakeStartRF, "OnClientInvoke")
        if ok and type(callback) == "function" then
            original = callback
        end
    end

    if not original then
        local ok, callback = pcall(function()
            return ShakeStartRF.OnClientInvoke
        end)
        if ok and type(callback) == "function" then
            original = callback
        end
    end

    if not original or original == WrappedShakeCallback then
        if not original then
            setShakeStatus("Waiting for the game's shake callback.")
        end
        return false
    end

    ShakeCallbackSource = original
    local wrapper = function(...)
        local args = table.pack(...)
        ShakeArgs = args
        FishingState.ShakeStartedAt = os.clock()
        local result = table.pack(pcall(original, table.unpack(args, 1, args.n)))
        if ShakeArgs == args then ShakeArgs = nil end
        if not result[1] then error(result[2], 0) end
        return table.unpack(result, 2, result.n)
    end

    local ok = pcall(function()
        ShakeStartRF.OnClientInvoke = wrapper
    end)
    if ok then
        WrappedShakeCallback = wrapper
        setShakeStatus("Shake callback hooked; waiting for prompt.")
        return true
    end

    setShakeStatus("Callback hook unavailable; waiting for shake UI.")

    return false
end

onCleanup(function()
    AutoShakeHookRunning = false
    ShakeArgs = nil
    if WrappedShakeCallback and type(ShakeCallbackSource) == "function" then
        local ok, callback = pcall(function() return ShakeStartRF.OnClientInvoke end)
        if (not ok or type(callback) ~= "function") and type(getcallbackvalue) == "function" then
            ok, callback = pcall(getcallbackvalue, ShakeStartRF, "OnClientInvoke")
        end
        if ok and callback == WrappedShakeCallback then
            pcall(function() ShakeStartRF.OnClientInvoke = ShakeCallbackSource end)
        end
    end
end)
task.spawn(function()
    while AutoShakeHookRunning and not Runtime.Closed do
        if Config.Enabled and Config.AutoShake then installShakeInterceptor() end
        task.wait(1)
    end
end)

local function isRod(tool)
    return tool
        and tool:IsA("Tool")
        and tool:FindFirstChild("events") ~= nil
end

local function getEquippedRod()
    local character = LocalPlayer.Character
    if not character then return nil end

    for _, tool in ipairs(character:GetChildren()) do
        if isRod(tool) then return tool end
    end
    return nil
end

local function matchesFishingMode(tool)
    if not isRod(tool) then return false end
    if Config.FishingMode ~= "Aria" then return true end
    local name = tool.Name:lower():gsub("[^%w]", "")
    return name:find("pinion", 1, true) ~= nil and name:find("aria", 1, true) ~= nil
end

local function getAnyRod()
    local equipped = getEquippedRod()
    if equipped and matchesFishingMode(equipped) then return equipped end

    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not backpack or not humanoid then return nil end

    for _, tool in ipairs(backpack:GetChildren()) do
        if matchesFishingMode(tool) then
            local ok = pcall(function()
                humanoid:EquipTool(tool)
            end)

            if ok then
                local deadline = os.clock() + 2
                repeat
                    task.wait(0.1)
                    equipped = getEquippedRod()
                    if equipped and matchesFishingMode(equipped) then return equipped end
                until os.clock() >= deadline or not Config.Enabled
            end
        end
    end

    return nil
end

local function hasBobber(rod)
    if not rod then return false end

    local bobber = rod:FindFirstChild("bobber")
    if bobber then return true end

    local values = rod:FindFirstChild("values")
    local casted = values and values:FindFirstChild("casted")
    if casted then
        local ok, value = pcall(function()
            return casted.Value
        end)
        return ok and value == true
    end

    return false
end

local function solveReel(reel)
    if observeLocalCatchReel and reel then observeLocalCatchReel(reel) end
    if not Config.Enabled or not Config.AutoReel or not reel then return false end
    if ReelController.ActiveReel ~= reel then return true end
    -- Aria's note controller owns the bar for the whole reel.
    if Config.FishingMode == "Aria" then return false end
    local now = os.clock()
    if LastReelRetry == reel and now < LastReelRetryAt then return false end

    local notesMode = Config.FishingMode == "Aria"
    local noteBar = notesMode and Runtime.NoteHold and Runtime.NoteHold(reel) or nil
    local ok, err = pcall(function()
        if Config.InstantBobber and not notesMode then
            local frozenUntil = tonumber(reel.frozenUntil) or 0
            reel.frozenUntil = math.max(frozenUntil, tick() + 0.12)
        end
        if notesMode then
            if noteBar then
                reel.barPosition = noteBar
                reel.onbar = true
            else
                reel.onbar = false
            end
        elseif reel.fishPosition ~= nil then
            reel.barPosition = reel.fishPosition
            reel.onbar = true
        end
    end)
    if not ok then Config.LastFishingError = "Reel update: " .. tostring(err) end
    if Config.InstantBobber and not notesMode then
        local readyOK, ready = pcall(function() return reel.ready == true end)
        if readyOK and ready then
            LastReelRetry, LastReelRetryAt = reel, now + 0.75
            local finished, finishError = pcall(function() reel:EndMinigame(true) end)
            if not finished then Config.LastFishingError = "Reel finish: " .. tostring(finishError) end
        end
    end
    return ReelController.ActiveReel ~= reel
end

local function findShakeField(value, names, depth, visited)
    if type(value) ~= "table" or depth > 4 or visited[value] then return nil end
    visited[value] = true

    for key, item in pairs(value) do
        local normalizedKey = string.lower(tostring(key)):gsub("[^%w]", "")
        if names[normalizedKey] and item ~= nil then
            return item
        end
    end

    for _, item in pairs(value) do
        if type(item) == "table" then
            local found = findShakeField(item, names, depth + 1, visited)
            if found ~= nil then return found end
        end
    end
    return nil
end

local function getShakeField(args, names)
    return findShakeField(args, names, 0, {})
end

local getActiveShakeUI, findShakeClickTarget
do
local discovery: { [string]: any } = { Gui = nil, Candidates = {}, Targets = setmetatable({}, { __mode = "k" }), Connections = {}, TextConnections = {}, TextCount = 0, Running = true }

local function visibleInPlayerGui(instance)
    local current = instance
    while current and current ~= discovery.Gui do
        if current:IsA("ScreenGui") and not current.Enabled then return false end
        if current:IsA("GuiObject") and not current.Visible then return false end
        current = current.Parent
    end
    return current == discovery.Gui
end

local function exactShakeText(instance)
    if not (instance:IsA("TextLabel") or instance:IsA("TextButton")) then return false end
    local text = tostring(instance.Text or ""):gsub("<[^>]->", ""):lower():gsub("[^%a]", "")
    return text == "shake"
end

local function resolveShakeLabel(label)
    if not visibleInPlayerGui(label) then return nil end
    local current = label
    for _ = 1, 5 do
        if not current or current == discovery.Gui or current:IsA("ScreenGui") then break end
        if current:IsA("GuiButton") then return current end
        if current ~= label and current:IsA("GuiObject") then
            local size = current.AbsoluteSize
            local aspect = size.Y > 0 and size.X / size.Y or 0
            if size.X >= 40 and size.Y >= 40 and size.X <= 400 and size.Y <= 400
                and aspect >= 0.7 and aspect <= 1.3 then
                return current
            end
        end
        current = current.Parent
    end
    return nil
end

findShakeClickTarget = function(scope)
    if not scope or not scope.Parent or not visibleInPlayerGui(scope) then return nil end
    local cached = discovery.Targets[scope]
    if cached and cached.Target.Parent and cached.Label.Parent
        and exactShakeText(cached.Label) and visibleInPlayerGui(cached.Label) then
        return cached.Target
    end
    discovery.Targets[scope] = nil
    local queue = { scope }
    local cursor = 1
    while cursor <= #queue and cursor <= 200 do
        local instance = queue[cursor]
        cursor += 1
        if exactShakeText(instance) then
            local target = resolveShakeLabel(instance)
            if target then
                local record = { Target = target, Label = instance }
                discovery.Targets[scope] = record
                discovery.Targets[target] = record
                return target
            end
        end
        for _, child in ipairs(instance:GetChildren()) do
            if #queue >= 200 then break end
            table.insert(queue, child)
        end
    end
    return nil
end

local function indexShakeInstance(instance)
    local name = instance.Name:lower():gsub("[^%a]", "")
    if name == "shakeui" or name == "lureshake" or name == "shakeminigame" or exactShakeText(instance) then
        discovery.Candidates[instance] = true
    end
    -- New UI text is often assigned after parenting. Watch blank labels only,
    -- under a fixed budget, and release each watch once it has been populated.
    if (instance:IsA("TextLabel") or instance:IsA("TextButton")) and instance.Text == ""
        and discovery.TextCount < 256 and not discovery.TextConnections[instance] then
        local ancestor = instance.Parent
        for _ = 1, 5 do
            if not ancestor or ancestor == discovery.Gui then break end
            local scope = ancestor.Name:lower()
            if scope:find("windui", 1, true) or scope:find("chat", 1, true)
                or scope:find("inventory", 1, true) or scope:find("bestiary", 1, true) then return end
            ancestor = ancestor.Parent
        end
        discovery.TextCount += 1
        discovery.TextConnections[instance] = instance:GetPropertyChangedSignal("Text"):Connect(function()
            if exactShakeText(instance) then discovery.Candidates[instance] = true end
            if instance.Text ~= "" then
                local connection = discovery.TextConnections[instance]
                if connection then connection:Disconnect() end
                discovery.TextConnections[instance] = nil
                discovery.TextCount = math.max(0, discovery.TextCount - 1)
            end
        end)
    end
end

local function attachShakeGui(gui)
    for _, connection in ipairs(discovery.Connections) do connection:Disconnect() end
    for _, connection in pairs(discovery.TextConnections) do connection:Disconnect() end
    table.clear(discovery.Connections)
    table.clear(discovery.TextConnections)
    discovery.TextCount = 0
    discovery.Gui = gui
    table.clear(discovery.Candidates)
    table.clear(discovery.Targets)
    if not gui then return end
    table.insert(discovery.Connections, gui.DescendantAdded:Connect(indexShakeInstance))
    table.insert(discovery.Connections, gui.DescendantRemoving:Connect(function(instance)
        discovery.Candidates[instance] = nil
        discovery.Targets[instance] = nil
        local connection = discovery.TextConnections[instance]
        if connection then
            connection:Disconnect()
            discovery.TextConnections[instance] = nil
            discovery.TextCount = math.max(0, discovery.TextCount - 1)
        end
        if CachedShakeUI == instance then CachedShakeUI = nil end
    end))
    task.spawn(function()
        for index, instance in ipairs(gui:GetDescendants()) do
            if not discovery.Running or discovery.Gui ~= gui then return end
            indexShakeInstance(instance)
            if index % 300 == 0 then task.wait() end
        end
    end)
end

getActiveShakeUI = function()
    local gui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if gui ~= discovery.Gui then attachShakeGui(gui) end
    if not gui then return nil end
    if CachedShakeUI then
        local target = findShakeClickTarget(CachedShakeUI)
        if target then return target end
        CachedShakeUI = nil
    end
    for candidate in pairs(discovery.Candidates) do
        if candidate.Parent then
            local target = findShakeClickTarget(candidate)
            if target then CachedShakeUI = target; return target end
        else
            discovery.Candidates[candidate] = nil
        end
    end
    return nil
end

onCleanup(function()
    discovery.Running = false
    for _, connection in ipairs(discovery.Connections) do connection:Disconnect() end
    for _, connection in pairs(discovery.TextConnections) do connection:Disconnect() end
    table.clear(discovery.Connections)
    table.clear(discovery.TextConnections)
    table.clear(discovery.Candidates)
    table.clear(discovery.Targets)
    CachedShakeUI = nil
end)
end

local function clickShakeTarget(target, route)
    if not target or not target:IsA("GuiObject") then
        return false, "Shake button was not found."
    end

    local x = math.floor(target.AbsolutePosition.X + target.AbsoluteSize.X / 2)
    local y = math.floor(target.AbsolutePosition.Y + target.AbsoluteSize.Y / 2)
    route = route or 1

    local function sendButtonSignal(signal, ...)
        local arguments = table.pack(...)
        local listeners
        if type(getconnections) == "function" then
            local ok, connections = pcall(getconnections, signal)
            if ok and type(connections) == "table" then
                listeners = {}
                for _, connection in ipairs(connections) do
                    local enabled = true
                    pcall(function() enabled = connection.Enabled ~= false end)
                    if enabled then table.insert(listeners, connection) end
                end
                if #listeners == 0 then return false end
            end
        end
        if type(firesignal) == "function" then
            return pcall(firesignal, signal, table.unpack(arguments, 1, arguments.n))
        end
        local sent = false
        for _, connection in ipairs(listeners or {}) do
            local ok = pcall(function()
                connection:Fire(table.unpack(arguments, 1, arguments.n))
            end)
            sent = sent or ok
        end
        return sent
    end

    -- These routes address the Roblox client, so switching the active desktop
    -- window does not redirect them to another application. A successful pcall
    -- only means input was sent; handleShake checks for progress before retrying.
    if route == 1 and target:IsA("GuiButton") then
        if sendButtonSignal(target.MouseButton1Click) then return true, "button click" end
        return false, "No button click listener."
    elseif route == 2 and target:IsA("GuiButton") then
        if sendButtonSignal(target.Activated) then return true, "button activation" end
        return false, "No activation listener."
    elseif route == 3 and target:IsA("GuiButton") then
        local down = sendButtonSignal(target.MouseButton1Down, x, y)
        local up = sendButtonSignal(target.MouseButton1Up, x, y)
        return down or up, "button press"
    elseif route == 4 then
        local ok = pcall(function()
            local virtualInput = game:GetService("VirtualInputManager")
            virtualInput:SendMouseButtonEvent(x, y, 0, true, game, 0)
            task.wait(0.03)
            virtualInput:SendMouseButtonEvent(x, y, 0, false, game, 0)
        end)
        return ok, "game input"
    elseif route ~= 6 then
        return false, "Input route unavailable."
    end

    local focusOK, focused = pcall(function() return UserInputService:IsWindowFocused() end)
    if focusOK and type(focused) == "boolean" then GameWindowFocused = focused end
    if not GameWindowFocused then return false, "Game window is unfocused." end

    if type(mousemoveabs) == "function" and type(mouse1click) == "function" then
        local ok = pcall(function()
            mousemoveabs(x, y)
            mouse1click()
        end)
        if ok then return true, "screen click" end
    end

    if type(mousemoverel) == "function" and type(mouse1click) == "function" then
        local ok, mousePosition = pcall(function()
            return UserInputService:GetMouseLocation()
        end)
        if ok and mousePosition then
            local clicked = pcall(function()
                mousemoverel(x - mousePosition.X, y - mousePosition.Y)
                mouse1click()
            end)
            if clicked then return true, "screen click" end
        end
    end

    return false, "No screen-click input is available."
end

local handleShake
do
local previousTarget, previousPosition, previousSize
local routeIndex, unchangedSince = 1, 0
local routes = { 1, 2, 3, 4, 6 }

handleShake = function()
    if not Config.Enabled or not Config.AutoShake or Config.TeleportBusy
        or ReelController.ActiveReel then return false end
    local target = getActiveShakeUI()
    if not target then return false end
    local now = os.clock()
    local scale = tonumber(getShakeField(ShakeArgs, { shakescale = true, scale = true })) or 1
    local cooldown = math.clamp(0.25 / math.max(scale, 0.25), 0.15, 0.8)
    if now - FishingState.LastShakeInputAt < cooldown then return false end
    local position, size = target.AbsolutePosition, target.AbsoluteSize
    if target ~= previousTarget or position ~= previousPosition or size ~= previousSize then
        previousTarget, previousPosition, previousSize = target, position, size
        routeIndex, unchangedSince = 1, now
    elseif now - unchangedSince >= 0.75 then
        routeIndex = routeIndex % #routes + 1
        unchangedSince = now
    end
    local lastReason
    for _ = 1, #routes do
        local sent, reason = clickShakeTarget(target, routes[routeIndex])
        if sent then
            FishingState.LastShakeInputAt = os.clock()
            return true
        end
        routeIndex = routeIndex % #routes + 1
        lastReason = reason
    end
    Config.LastFishingError = tostring(lastReason or "No SHAKE input route is available.")
    FishingState.LastShakeInputAt = os.clock()
    return false
end
end

local function fishingTick(generation)
    if not Config.Enabled or Runtime.Closed or generation ~= FishingState.Generation then return end
    local function phase(name)
        FishingState.Phase = name
        Config.FishingPhase = name
    end
    if Config.TeleportBusy or Config.AutomationBusy or Config.AquariumBusy then phase("Paused"); return end
    local character = LocalPlayer.Character
    if not character then phase("Waiting for character"); return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then phase("Waiting for character"); return end
    if FishingState.Character ~= character then
        FishingState.Character = character
        FishingState.HadActivity = false
        FishingState.MissingSince = nil
        CastPendingAt = 0
        ShakeArgs = nil
    end
    local now = os.clock()
    local reel = ReelController.ActiveReel
    local prompt = getActiveShakeUI()
    if (reel or prompt) and FishingState.CastRequest then
        FishingState.CastRequest.ObservedActivity = true
        FishingState.CastRequest.Deadline = now + 8
    end
    if reel then
        phase("Reel")
        FishingState.HadActivity = true
        FishingState.MissingSince = nil
        solveReel(reel)
        if ReelController.ActiveReel ~= reel then
            FishingState.NextCastAt = os.clock() + math.max(0, Config.Delay)
            CastPendingAt = 0
            FishingState.HadActivity = false
        end
        return
    end
    if prompt then
        phase("Shake")
        FishingState.HadActivity = true
        FishingState.MissingSince = nil
        handleShake()
        return
    end
    local rod = getAnyRod()
    if generation ~= FishingState.Generation or not Config.Enabled then return end
    if not rod then phase(Config.FishingMode == "Aria" and "Waiting for Pinion's Aria" or "Waiting for rod"); return end
    if hasBobber(rod) then
        if FishingState.CastRequest then
            FishingState.CastRequest.ObservedActivity = true
            FishingState.CastRequest.Deadline = now + 8
        end
        phase("Waiting for bite")
        FishingState.HadActivity = true
        FishingState.MissingSince = nil
        CastPendingAt = 0
        return
    end
    -- During a normal phase change the bobber/prompt can disappear a frame
    -- before the reel arrives. Give that handoff a short grace period.
    if FishingState.HadActivity then
        FishingState.MissingSince = FishingState.MissingSince or now
        if now - FishingState.MissingSince < 1 then phase("Waiting for phase"); return end
        FishingState.HadActivity = false
        FishingState.MissingSince = nil
        FishingState.NextCastAt = math.max(FishingState.NextCastAt or 0, now + 0.5)
        CastPendingAt = 0
    end
    -- The real game callback may begin before its GUI is replicated. Wait for
    -- its prompt instead of casting over an already-started shake.
    if ShakeArgs then
        if now - FishingState.ShakeStartedAt < 12 then phase("Waiting for shake"); return end
        Config.LastFishingError = "Shake callback is waiting without a visible SHAKE prompt."
        ShakeArgs = nil
        FishingState.NextCastAt = now + 1
    end
    if not FishingState.CastRequest and CastPendingAt > 0 and now - CastPendingAt < 3.5 then
        phase("Waiting for bobber")
        return
    end
    CastPendingAt = 0
    if not FishingState.CastRequest and not Config.AutoCast then phase("Idle"); return end
    if not FishingState.CastRequest and (now < (FishingState.NextCastAt or 0) or now - FishingState.LastCastAt < 3.5) then
        phase("Recast delay")
        return
    end

    if Config.EventTravelPending and not FishingState.CastRequest then phase("Waiting for event travel"); return end
    phase("Casting")
    if not FishingState.CastRequest then
        FishingState.LastCastAt = now
        CatchTimerStartedAt = now
        CatchTimerResultText = nil
        CatchTimerResultUntil = 0
        if updateCatchTimerText then pcall(updateCatchTimerText) end
    end
    local castOK, castResult, castError, observedActivity = invokeCastWithTimeout(
        math.clamp(Config.Power, 0, 100), Config.PerfectCast, 8
    )
    if generation ~= FishingState.Generation or not Config.Enabled then return end
    if castOK == nil then phase("Cast pending"); return end
    if castOK and (castResult == true or castResult == nil or hasBobber(rod)
        or ReelController.ActiveReel ~= nil or getActiveShakeUI() ~= nil) then
        CastPendingAt = observedActivity and 0 or os.clock()
        phase(observedActivity and "Recast delay" or "Waiting for bobber")
    else
        Config.LastFishingError = castError or ("Cast rejected: " .. tostring(castResult))
        -- A timed-out client invocation may have reached the server. Preserve
        -- a grace period and observe its result before another request is sent.
        FishingState.LastCastAt = os.clock()
        FishingState.NextCastAt = os.clock() + 3.5
        phase("Waiting after cast")
    end
end

local function autofishLoop(generation)
    while Config.Enabled and not Runtime.Closed and generation == FishingState.Generation do
        Busy = true
        local ok, err = pcall(fishingTick, generation)
        if not ok and generation == FishingState.Generation then
            Config.LastFishingError = tostring(err)
            Config.FishingPhase = "Retrying"
        end
        if generation == FishingState.Generation then Busy = false end
        task.wait(ok and 0.1 or 0.5)
    end
    if generation == FishingState.Generation then Busy = false end
end

local SyncFishingToggles = false
local function syncFishingControls()
    SyncFishingToggles = true
    if AutoFishToggle then pcall(function() AutoFishToggle:Set(Config.Enabled and Config.FishingMode == "Normal", false) end) end
    if AutoNotesToggle then pcall(function() AutoNotesToggle:Set(Config.Enabled and Config.FishingMode == "Aria", false) end) end
    SyncFishingToggles = false
end

local function setEnabled(state)
    local enabled = state == true
    if Runtime.Closed then return end
    if enabled and not Config.FishingMode then
        Config.FishingMode = "Normal"
        Config.AutoNotes = false
    end
    if enabled == Config.Enabled and LoopThread and coroutine.status(LoopThread) ~= "dead" then syncFishingControls(); return end
    Config.Enabled = enabled
    FishingState.Generation += 1
    local generation = FishingState.Generation
    Busy = false
    if enabled then
        LoopThread = task.spawn(autofishLoop, generation)
    else
        Config.FishingMode = nil
        Config.FishingPhase = "Disabled"
        ShakeArgs = nil
        FishingState.HadActivity = false
        FishingState.MissingSince = nil
        CatchTimerStartedAt = nil
        CatchTimerResultText = nil
        CatchTimerResultUntil = 0
        if updateCatchTimerText then pcall(updateCatchTimerText) end
    end
    syncFishingControls()
end

local function setFishingMode(mode, state)
    if Runtime.Closed or SyncFishingToggles then return end
    local enabled = state == true
    if enabled then
        if mode ~= "Normal" and mode ~= "Aria" then return end
        Config.FishingMode = mode
        Config.AutoNotes = mode == "Aria"
        setEnabled(true)
    elseif Config.FishingMode == mode then
        Config.FishingMode = nil
        setEnabled(false)
    end
    syncFishingControls()
    saveLocalSettings()
end
Runtime.SetFishingMode = setFishingMode

onCleanup(function()
    FishingState.Generation += 1
    Busy = false
    local request = FishingState.CastRequest
    if request and request.Worker and not request.Done then pcall(function() task.cancel(request.Worker) end) end
    FishingState.CastRequest = nil
end)

-- Clean up an older copy of this UI.
local container = getUIContainer()
local oldUI = container:FindFirstChild("WindUI")
if oldUI then
    pcall(function()
        oldUI:Destroy()
    end)
end

Runtime.Trace("Loading interface library")
local WindUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"
))()
local AvailableThemes = WindUI:GetThemes()
if not AvailableThemes[AppearanceState.Theme] then
    AppearanceState.Theme = "Dark"
end

local UIViewport = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
local UIWidth = math.min(840, math.max(380, UIViewport.X - 48))
local UIHeight = math.min(600, math.max(360, UIViewport.Y - 72))
local Window = WindUI:CreateWindow({
    Title = HUB_NAME,
    Folder = "BootleanFischUI",
    Icon = "fish",
    Theme = AppearanceState.Theme,
    Acrylic = AppearanceState.Acrylic,
    SideBarWidth = 185,
    Size = UDim2.fromOffset(UIWidth, UIHeight),
    MinSize = Vector2.new(math.min(640, UIWidth), math.min(440, UIHeight)),
    MaxSize = Vector2.new(1100, 800),
    Resizable = true,
    AutoScale = false,
    Radius = 12,
    ElementsRadius = 10,
    Transparent = AppearanceState.Transparency > 0,
    ToggleKey = Enum.KeyCode[ToggleKeyName],
    OpenButton = { Enabled = false },
})
pcall(function()
    Window.IsOpenButtonEnabled = false
    if Window.OpenButtonMain then Window.OpenButtonMain:Visible(false) end
end)
-- Create navigation first so the main categories stay grouped at the top.
-- WindUI holds one destroy callback; dispatch all component cleanups together.
Window:OnDestroy(Runtime.Cleanup)
pcall(function()
    local screen = WindUI.ScreenGui or container:FindFirstChild("WindUI")
    if screen then
        local connection = screen.Destroying:Connect(Runtime.Cleanup)
        onCleanup(function() connection:Disconnect() end)
    end
end)
-- Keep WindUI's tab instances and native selection callbacks; change their layout only.
local function installTopNavigation(window, tabs)
    local elements = assert(window.UIElements, "Window UIElements are missing")
    local main = assert(elements.Main and elements.Main:FindFirstChild("Main"), "Window main frame is missing")
    local sidebar = assert(elements.SideBarContainer, "Window sidebar is missing")
    local content = assert(elements.MainBar, "Window content frame is missing")
    local header = assert(main:FindFirstChild("Topbar"), "Window header is missing")
    local headerLeft = header:FindFirstChild("Left")
    local headerTitle = headerLeft and headerLeft:FindFirstChild("Title")
    local items = {}
    for _, tab in ipairs(tabs) do
        local button = assert(tab.UIElements and tab.UIElements.Main, "A native tab button is missing")
        local frame = assert(button:FindFirstChild("Frame"), "A native tab frame is missing")
        local text = assert(frame:FindFirstChild("TextLabel"), "A native tab label is missing")
        table.insert(items, { Tab = tab, Button = button, Frame = frame, Text = text })
    end

    local topHeight = window.Topbar and window.Topbar.Height or 52
    local navHeight = 36
    local nav = Instance.new("ScrollingFrame")
    nav.Name = "BootleanTopNavigation"
    nav.BackgroundTransparency = 1
    nav.BorderSizePixel = 0
    nav.Position = UDim2.fromOffset(48, math.max(0, (topHeight - navHeight) / 2))
    nav.Size = UDim2.new(1, -98, 0, navHeight)
    nav.CanvasSize = UDim2.new()
    nav.AutomaticCanvasSize = Enum.AutomaticSize.X
    nav.ScrollingDirection = Enum.ScrollingDirection.X
    nav.ScrollBarThickness = 2
    nav.ScrollBarImageTransparency = 0.5
    nav.ScrollBarImageColor3 = Color3.fromRGB(130, 142, 160)
    nav.ClipsDescendants = true
    nav.ZIndex = 8
    nav.Parent = main
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 4)
    layout.Parent = nav
    local textService = game:GetService("TextService")

    for index, item in ipairs(items) do
        local width = math.ceil(textService:GetTextSize(item.Tab.Title, 14, Enum.Font.GothamMedium, Vector2.new(1000, 100)).X) + 20
        item.Button.AutomaticSize = Enum.AutomaticSize.None
        item.Button.Size = UDim2.fromOffset(math.max(52, width), 32)
        item.Button.LayoutOrder = index
        item.Button.Parent = nav
        item.Frame.AutomaticSize = Enum.AutomaticSize.None
        item.Frame.Size = UDim2.fromScale(1, 1)
        local padding = item.Frame:FindFirstChildOfClass("UIPadding")
        if padding then
            padding.PaddingTop, padding.PaddingBottom = UDim.new(), UDim.new()
            padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
        end
        local row = item.Frame:FindFirstChildOfClass("UIListLayout")
        if row then row.HorizontalAlignment = Enum.HorizontalAlignment.Center end
        if item.Tab.UIElements.Icon then item.Tab.UIElements.Icon.Visible = false end
        item.Text.AutomaticSize = Enum.AutomaticSize.None
        item.Text.Size = UDim2.fromScale(1, 1)
        item.Text.TextSize = 14
        item.Text.TextWrapped = false
        item.Text.TextXAlignment = Enum.TextXAlignment.Center
    end

    sidebar.Visible = false
    if headerTitle then headerTitle.Visible = false end
    content.AnchorPoint = Vector2.new(0, 0)
    content.Position = UDim2.fromOffset(0, topHeight)
    content.Size = UDim2.new(1, 0, 1, -topHeight)
    return nav
end

-- Compact native WindUI elements into responsive rows without replacing their callbacks.
local function compactControls(target)
    local currentGroup
    local gap = 6
    local groups = {}
    local proxy = {}
    local compactMethods = { Toggle = true, Button = true, Slider = true, Input = true, Dropdown = true, Colorpicker = true, Keybind = true }
    local function reflow(group)
        if Runtime.Closed or not group.Root.Parent or #group.Items == 0 then return end
        local scale = tonumber(WindUI.UIScale) or AppearanceState.Scale or 1
        local width = group.Root.AbsoluteSize.X / math.max(scale, 0.1)
        if width < 100 then width = UIWidth - 48 end
        local columns = math.min(#group.Items, math.clamp(math.floor((width + gap) / 216), 1, 3))
        if group.Columns == columns and group.Count == #group.Items then return end
        group.Columns, group.Count = columns, #group.Items
        for _, item in ipairs(group.Items) do item.Parent = group.Root end
        for _, row in ipairs(group.Rows) do row:Destroy() end
        table.clear(group.Rows)
        for index, item in ipairs(group.Items) do
            local rowIndex = math.floor((index - 1) / columns) + 1
            local row = group.Rows[rowIndex]
            if not row then
                row = Instance.new("Frame")
                row.Name = "CardRow"
                row.BackgroundTransparency = 1
                row.Size = UDim2.new(1, 0, 0, 0)
                row.AutomaticSize = Enum.AutomaticSize.Y
                row.LayoutOrder = rowIndex
                row.Parent = group.Root
                local layout = Instance.new("UIListLayout")
                layout.FillDirection = Enum.FillDirection.Horizontal
                layout.SortOrder = Enum.SortOrder.LayoutOrder
                layout.VerticalAlignment = Enum.VerticalAlignment.Top
                layout.Padding = UDim.new(0, gap)
                layout.Parent = row
                group.Rows[rowIndex] = row
            end
            item.LayoutOrder = index
            item.AutomaticSize = Enum.AutomaticSize.Y
            item.Size = UDim2.new(1 / columns, -(gap * (columns - 1) / columns), 0, 0)
            item.Parent = row
        end
    end
    local function groupFor(frame)
        if currentGroup and #currentGroup.Items < 3 then return currentGroup end
        local root = Instance.new("Frame")
        root.Name = "BootleanCardGroup"
        root.BackgroundTransparency = 1
        root.Size = UDim2.new(1, -7, 0, 0)
        root.AutomaticSize = Enum.AutomaticSize.Y
        root.LayoutOrder = frame.LayoutOrder
        root.Parent = frame.Parent
        local layout = Instance.new("UIListLayout")
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, gap)
        layout.Parent = root
        currentGroup = { Root = root, Items = {}, Rows = {} }
        table.insert(groups, currentGroup)
        local group = currentGroup
        local connection = root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() reflow(group) end)
        onCleanup(function() connection:Disconnect() end)
        return group
    end
    for method in pairs(compactMethods) do
        proxy[method] = function(_, config)
            local control = target[method](target, config)
            local frame = control.ElementFrame or (control.UIElements and control.UIElements.Main)
            if not frame then currentGroup = nil; return control end
            local group = groupFor(frame)
            table.insert(group.Items, frame)
            reflow(group)
            return control
        end
    end
    setmetatable(proxy, { __index = function(_, key)
        local value = target[key]
        if type(value) ~= "function" then return value end
        return function(_, ...)
            currentGroup = nil
            return value(target, ...)
        end
    end })
    return proxy
end

local FishingTab = Window:Tab({ Title = "Fishing", Icon = "fish" })
local EventsTab = Window:Tab({ Title = "Events", Icon = "calendar-days" })
local NavigationTab = Window:Tab({ Title = "GPS / Teleport", Icon = "navigation" })

local ShopTab = Window:Tab({ Title = "Shop", Icon = "shopping-bag" })
local AquariumTab = Window:Tab({ Title = "Aquarium", Icon = "fish" })
local VisualsTab = Window:Tab({ Title = "Visuals", Icon = "eye" })
local SettingsTab = Window:Tab({ Title = "Settings", Icon = "settings" })
local topNavOK, topNavError = pcall(installTopNavigation, Window, {
    FishingTab, EventsTab, NavigationTab, ShopTab, AquariumTab, VisualsTab, SettingsTab,
})
if not topNavOK then
    warn("[Bootlean GUI] Top navigation: " .. tostring(topNavError))
    WindUI:Notify({ Title = "GUI layout", Content = "Top navigation could not be attached. " .. tostring(topNavError), Duration = 8 })
end
pcall(function() Window:DisableTopbarButtons({ "Minimize", "Fullscreen" }) end)
local GPSTab, TeleportTab
local function setNavigationView(value, persist)
    if value ~= "GPS" and value ~= "Teleport" then return end
    NavigationMode = value
    if GPSTab then GPSTab.ElementFrame.Visible = value == "GPS" end
    if TeleportTab then TeleportTab.ElementFrame.Visible = value == "Teleport" end
    if NavigationTab.UIElements and NavigationTab.UIElements.ContainerFrame then
        NavigationTab.UIElements.ContainerFrame.CanvasPosition = Vector2.new(0, 0)
    end
    if persist then saveLocalSettings() end
end
NavigationTab:Dropdown({
    Title = "Navigation mode",
    Values = { "Teleport", "GPS" },
    Value = NavigationMode,
    Callback = function(value) setNavigationView(value, true) end,
})
GPSTab = NavigationTab:VStack({})
TeleportTab = NavigationTab:VStack({})
setNavigationView(NavigationMode, false)
GPSTab, TeleportTab = compactControls(GPSTab), compactControls(TeleportTab)
FishingTab, EventsTab = compactControls(FishingTab), compactControls(EventsTab)
ShopTab, AquariumTab = compactControls(ShopTab), compactControls(AquariumTab)
VisualsTab, SettingsTab = compactControls(VisualsTab), compactControls(SettingsTab)
pcall(function() Window:SelectTab(1) end)
Runtime.Trace("Interface created")

pcall(function() Window:SetBackgroundTransparency(AppearanceState.Transparency) end)
FishingTab:Section({ Title = "Fishing Modes" })
local FishingModeCards = FishingTab:HStack({})
AutoFishToggle = FishingModeCards:Toggle({
    Title = "Normal Auto Fish",
    Desc = "Standard fishing",
    Value = false,
    Callback = function(value) setFishingMode("Normal", value) end,
})
AutoNotesToggle = FishingModeCards:Toggle({
    Title = "Pinion's Aria Notes",
    Desc = "Follow the falling notes",
    Value = false,
    Callback = function(value) setFishingMode("Aria", value) end,
})
FishingModeCards.ElementFrame.AutomaticSize = Enum.AutomaticSize.None
FishingModeCards.ElementFrame.Size = UDim2.new(1, 0, 0, 72)
for _, modeControl in ipairs({ AutoFishToggle, AutoNotesToggle }) do
    modeControl.ElementFrame.AutomaticSize = Enum.AutomaticSize.None
    modeControl.ElementFrame.Size = UDim2.new(0.5, -3, 1, 0)
end

FishingTab:Section({ Title = "Cast and Reel" })
local AutoCastToggle = FishingTab:Toggle({
    Title = "Auto Cast",
    Value = Config.AutoCast,
    Callback = function(value)
        Config.AutoCast = value == true
        saveLocalSettings()
    end,
})

local AutoShakeToggle = FishingTab:Toggle({
    Title = "Auto Shake",
    Value = Config.AutoShake,
    Callback = function(value)
        Config.AutoShake = value == true
        if not Config.AutoShake then
            ShakeArgs = nil
            setShakeStatus("Auto Shake is disabled.")
        else
            setShakeStatus("Waiting for shake UI or server callback.")
        end
        saveLocalSettings()
    end,
})

local AutoReelToggle = FishingTab:Toggle({
    Title = "Auto Reel",
    Value = Config.AutoReel,
    Callback = function(value)
        Config.AutoReel = value == true
        saveLocalSettings()
    end,
})

local InstantBobberToggle = FishingTab:Toggle({
    Title = "Instant Bobber",
    Value = Config.InstantBobber,
    Callback = function(value)
        Config.InstantBobber = value == true
        saveLocalSettings()
    end,
})

local CastPowerSlider = FishingTab:Slider({
    Title = "Cast Power",
    Step = 1,
    Value = { Min = 10, Max = 100, Default = Config.Power },
    Callback = function(value)
        Config.Power = value
        saveLocalSettings()
    end,
})

local PerfectCastToggle = FishingTab:Toggle({
    Title = "Perfect Cast",
    Value = Config.PerfectCast,
    Callback = function(value)
        Config.PerfectCast = value == true
        saveLocalSettings()
    end,
})

local RecastDelaySlider = FishingTab:Slider({
    Title = "Recast Delay",
    Step = 0.5,
    Value = { Min = 0, Max = 10, Default = Config.Delay },
    Callback = function(value)
        Config.Delay = value
        saveLocalSettings()
    end,
})

CatchTimerParagraph = FishingTab:Paragraph({
    Title = "Current Catch Timer",
    Desc = "Waiting for the next catch.",
    Image = "timer",
    ImageSize = 18,
})
FishingTab:Button({
    Title = "Reset Bobber",
    Callback = function()
        pcall(function()
            ResetRemote:FireServer()
        end)
    end,
})

do
local RunService = game:GetService("RunService")
local Gui = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui")
local Notes: { [string]: any } = {
    Running = true,
    Keyword = (Config.NoteKeyword ~= "" and Config.NoteKeyword or "note"),
    Candidates = setmetatable({}, { __mode = "k" }),
    Last = setmetatable({}, { __mode = "k" }),
    BarCache = setmetatable({}, { __mode = "k" }),
    BarMissAt = setmetatable({}, { __mode = "k" }),
    Connections = {}, Hold = nil, RodOK = false, RodCheckAt = 0, ScanId = 0,
}
local function norm(value) return (string.lower(tostring(value or "")):gsub("[^%w]", "")) end
local blocked = { "windui", "bootlean", "chat", "inventory", "bestiary", "backpack", "hotbar", "notif" }

local function treeVisible(instance)
    local current = instance
    while current and current ~= Gui do
        if current:IsA("ScreenGui") and not current.Enabled then return false end
        if current:IsA("GuiObject") and not current.Visible then return false end
        current = current.Parent
    end
    return current == Gui
end

local function scopeRoot(instance)
    local current, reelRoot = instance, nil
    while current and current ~= Gui do
        local name = norm(current.Name)
        for _, word in ipairs(blocked) do
            if name:find(word, 1, true) then return nil end
        end
        if current ~= instance and name:find("reel", 1, true) then reelRoot = current end
        current = current.Parent
    end
    if current ~= Gui then return nil end
    return reelRoot or instance:FindFirstAncestorOfClass("ScreenGui")
end

local function index(instance)
    if not instance:IsA("GuiObject") then return end
    local name = norm(instance.Name)
    if name == "" or not name:find(Notes.Keyword, 1, true) then return end
    if name == "notes" or name:find("container", 1, true) or name:find("template", 1, true) or name:find("folder", 1, true) then return end
    local root = scopeRoot(instance)
    if root then Notes.Candidates[instance] = root end
end

local function rescan()
    Notes.ScanId += 1
    local id = Notes.ScanId
    table.clear(Notes.Candidates)
    task.spawn(function()
        for count, instance in ipairs(Gui:GetDescendants()) do
            if not Notes.Running or id ~= Notes.ScanId then return end
            index(instance)
            if count % 300 == 0 then task.wait() end
        end
    end)
end

local barNames = { bar = true, playerbar = true, controlbar = true, catchbar = true, reelbar = true, playerbarframe = true }
local function findBar(root)
    local cached = Notes.BarCache[root]
    if cached and cached.Parent then return cached end
    local now = os.clock()
    if Notes.BarMissAt[root] and now < Notes.BarMissAt[root] then return nil end
    local queue, cursor, found = root:GetChildren(), 1, nil
    while cursor <= #queue and cursor <= 300 do
        local item = queue[cursor]; cursor += 1
        if item:IsA("GuiObject") and barNames[norm(item.Name)] then found = item; break end
        for _, child in ipairs(item:GetChildren()) do table.insert(queue, child) end
    end
    if found then Notes.BarCache[root] = found else Notes.BarMissAt[root] = now + 1 end
    return found
end

local function pinionEquipped()
    local rod = getEquippedRod()
    local name = rod and norm(rod.Name) or ""
    return name:find("pinion", 1, true) ~= nil and name:find("aria", 1, true) ~= nil
end
local function notesRod()
    local now = os.clock()
    if now >= Notes.RodCheckAt then Notes.RodCheckAt = now + 0.5; Notes.RodOK = pinionEquipped() end
    return Notes.RodOK
end

-- Returns the bar position (0..1) under the nearest falling note, or nil.
local function computeTarget()
    local now = os.clock()
    local bestDistance, bestFraction
    for note, root in pairs(Notes.Candidates) do
        if note.Parent and root.Parent and treeVisible(note) then
            local size, position = note.AbsoluteSize, note.AbsolutePosition
            if size.X > 0 and size.Y > 0 and size.X <= 180 and size.Y <= 180 then
                local cx = position.X + size.X / 2
                local top, bottom = position.Y, position.Y + size.Y
                local last = Notes.Last[note]
                local speed = 0
                if last then
                    local elapsed = now - last.t
                    if elapsed >= 1 / 240 and elapsed <= 0.5 then
                        local measured = (position.Y + size.Y / 2 - last.y) / elapsed
                        if measured >= 0 and measured <= 3000 then
                            speed = last.speed and (last.speed * 0.65 + measured * 0.35) or measured
                        end
                    end
                    last.y, last.t, last.speed = position.Y + size.Y / 2, now, speed
                else
                    Notes.Last[note] = { y = position.Y + size.Y / 2, t = now, speed = 0 }
                end
                local bar = findBar(root)
                if not bar or not bar.Parent or not bar.Parent:IsA("GuiObject") then
                    Notes.Error = "Note lane was not found. Capture Aria diagnostics in Settings."
                    continue
                end
                local track = bar.Parent
                local trackSize, trackPos = track.AbsoluteSize, track.AbsolutePosition
                if trackSize.X > 0 and trackSize.Y > 0 and cx >= trackPos.X and cx <= trackPos.X + trackSize.X then
                    local barTop, barBottom
                    if bar then
                        barTop = bar.AbsolutePosition.Y
                        barBottom = barTop + bar.AbsoluteSize.Y
                    else
                        barTop = trackPos.Y + trackSize.Y * 0.8
                        barBottom = trackPos.Y + trackSize.Y
                    end
                    local distance = barTop - bottom
                    local overlapsHitLine = bottom >= barTop and top <= barBottom
                    local lead = math.max(12, math.min(math.max(speed, 0), 3000) * Config.NoteLead)
                    local approaching = distance >= 0 and distance <= lead
                    local notPassed = top <= barBottom
                    if notPassed and (overlapsHitLine or approaching) then
                        local score = math.max(0, distance)
                        if not bestDistance or score < bestDistance then
                            bestDistance = score
                            bestFraction = math.clamp((cx - trackPos.X) / trackSize.X, 0, 1)
                        end
                    end
                end
            end
        end
    end
    return bestFraction
end

local function step()
    if not Notes.Running or Runtime.Closed then return end
    if not (Config.Enabled and Config.FishingMode == "Aria" and Config.AutoReel and Config.AutoNotes) then Notes.Hold = nil; return end
    local reel = ReelController.ActiveReel
    if not reel or not notesRod() or next(Notes.Candidates) == nil then Notes.Hold = nil; return end
    local ok, fraction = pcall(computeTarget)
    if not ok then
        Notes.Hold = nil
        Notes.Error = tostring(fraction)
        Config.LastFishingError = "Aria target: " .. Notes.Error
        if Notes.LastReportedError ~= Notes.Error then
            Notes.LastReportedError = Notes.Error
            warn("[Bootlean Aria] " .. Notes.Error)
        end
        return
    end
    if ok and fraction then
        Notes.Error = nil
        Notes.Hold = { Fraction = fraction, At = os.clock(), Reel = reel }
        pcall(function() reel.barPosition = fraction; reel.onbar = true end)
    else
        Notes.Hold = nil
    end
end

Runtime.NoteHold = function(reel)
    local hold = Notes.Hold
    if hold and hold.Reel == reel and os.clock() - hold.At < 0.15 then return hold.Fraction end
    return nil
end
Runtime.NotesActive = function()
    return Config.Enabled and Config.FishingMode == "Aria" and Config.AutoNotes and notesRod()
end

table.insert(Notes.Connections, Gui.DescendantAdded:Connect(index))
table.insert(Notes.Connections, Gui.DescendantRemoving:Connect(function(instance)
    Notes.Candidates[instance] = nil
    Notes.Last[instance] = nil
end))
local NoteRenderBinding = "BootleanFischAriaNotes"
local bound, bindError = pcall(function()
    RunService:UnbindFromRenderStep(NoteRenderBinding)
    RunService:BindToRenderStep(NoteRenderBinding, Enum.RenderPriority.Last.Value, step)
end)
if not bound then
    Notes.Error = "Render binding failed: " .. tostring(bindError)
    table.insert(Notes.Connections, RunService.RenderStepped:Connect(step))
end
rescan()

local function dumpUI()
    local lines = { "Bootlean notes dump", "Pinion's Aria equipped: " .. tostring(pinionEquipped()), "Keyword: " .. Notes.Keyword }
    local reel = ReelController.ActiveReel
    table.insert(lines, "ActiveReel: " .. tostring(reel ~= nil))
    if reel then
        local keys = {}
        pcall(function()
            for key, value in pairs(reel) do
                local kind = type(value)
                if (kind == "number" or kind == "boolean" or kind == "string") and #keys < 40 then
                    table.insert(keys, tostring(key) .. "=" .. tostring(value))
                end
            end
        end)
        table.sort(keys)
        table.insert(lines, "reel: " .. table.concat(keys, ", "))
    end
    table.insert(lines, "Indexed note objects:")
    local shown = 0
    for note in pairs(Notes.Candidates) do
        shown += 1
        if shown > 20 then break end
        table.insert(lines, string.format("  %s [%s] visible=%s pos=%.0f,%.0f size=%.0f,%.0f", note:GetFullName(), note.ClassName,
            tostring(treeVisible(note)), note.AbsolutePosition.X, note.AbsolutePosition.Y, note.AbsoluteSize.X, note.AbsoluteSize.Y))
    end
    local foundGui = false
    for _, gui in ipairs(Gui:GetChildren()) do
        local name = norm(gui.Name)
        if gui:IsA("ScreenGui") and name:find("reel", 1, true) and not name:find("windui", 1, true) then
            foundGui = true
            table.insert(lines, "GUI " .. gui.Name .. " enabled=" .. tostring(gui.Enabled))
            local queue, cursor = {}, 1
            for _, child in ipairs(gui:GetChildren()) do table.insert(queue, { child, 1 }) end
            while cursor <= #queue and cursor <= 150 do
                local item, depth = queue[cursor][1], queue[cursor][2]
                cursor += 1
                local extra = ""
                if item:IsA("GuiObject") then
                    extra = string.format(" vis=%s pos=%.0f,%.0f size=%.0f,%.0f", tostring(item.Visible),
                        item.AbsolutePosition.X, item.AbsolutePosition.Y, item.AbsoluteSize.X, item.AbsoluteSize.Y)
                end
                table.insert(lines, string.rep("  ", depth) .. item.Name .. " [" .. item.ClassName .. "]" .. extra)
                for _, child in ipairs(item:GetChildren()) do table.insert(queue, { child, depth + 1 }) end
            end
        end
    end
    if not foundGui then
        local names = {}
        for _, gui in ipairs(Gui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Enabled then table.insert(names, gui.Name) end
        end
        table.insert(lines, "No ScreenGui named *reel*. Enabled ScreenGuis: " .. table.concat(names, ", "))
    end
    local text = table.concat(lines, "\n")
    local copied = type(setclipboard) == "function" and pcall(setclipboard, text)
    pcall(function() WindUI:Notify({ Title = "Reel UI dump", Content = copied and "Dump copied to clipboard." or text:sub(1, 400), Duration = 6 }) end)
end

FishingTab:Section({ Title = "Pinion's Aria Notes" })
local NotesStatus = FishingTab:Paragraph({ Title = "Notes Status", Desc = "", Image = "music", ImageSize = 18 })

local NoteLeadSlider = FishingTab:Slider({
    Title = "Note Lead Time",
    Step = 0.01,
    Value = { Min = 0.02, Max = 0.4, Default = Config.NoteLead },
    Callback = function(value) Config.NoteLead = math.clamp(tonumber(value) or 0.08, 0.02, 0.4); saveLocalSettings() end,
})
local NoteKeywordInput = FishingTab:Input({
    Title = "Note Object Keyword",
    Value = Config.NoteKeyword,
    Placeholder = "note",
    Callback = function(value)
        local keyword = norm(value)
        if keyword == "" then keyword = "note" end
        Config.NoteKeyword, Notes.Keyword = keyword, keyword
        rescan()
        saveLocalSettings()
    end,
})
FishingTab:Button({
    Title = "Copy Reel UI Dump (5 s delay)",
    Icon = "clipboard-copy",
    Callback = function()
        pcall(function() WindUI:Notify({ Title = "Reel UI dump", Content = "Start the reel minigame now — dumping in 5 seconds.", Duration = 5 }) end)
        task.delay(5, function() pcall(dumpUI) end)
    end,
})

Runtime.ResetNotes = function()
    Config.AutoNotes, Config.NoteLead, Config.NoteKeyword = true, 0.08, "note"
    Notes.Keyword = "note"
    rescan()
    pcall(function() NoteLeadSlider:Set(0.08) end)
    pcall(function() NoteKeywordInput:Set("note") end)
end

task.spawn(function()
    local previous
    while Notes.Running do
        local count = 0
        for _ in pairs(Notes.Candidates) do count += 1 end
        local reel = ReelController.ActiveReel
        local mode = Config.FishingMode == "Aria" and "Pinion's Aria Notes"
            or Config.FishingMode == "Normal" and "Normal" or "off"
        local follows = Config.FishingMode == "Aria"
            and ((reel and Runtime.NoteHold and Runtime.NoteHold(reel)) and "note" or "waiting for note")
            or Config.FishingMode == "Normal" and "fish" or "off"
        local text = string.format("Mode: %s\nRod: %s\nNote objects indexed: %d\nBar: %s%s",
            mode, notesRod() and "Pinion's Aria detected" or "not equipped", count, follows,
            Notes.Error and ("\n" .. Notes.Error) or "")
        if text ~= previous then previous = text; pcall(function() NotesStatus:SetDesc(text) end) end
        task.wait(0.5)
    end
end)

onCleanup(function()
    Notes.Running = false
    pcall(function() RunService:UnbindFromRenderStep(NoteRenderBinding) end)
    Notes.ScanId += 1
    Notes.Hold = nil
    for _, connection in ipairs(Notes.Connections) do pcall(function() connection:Disconnect() end) end
    table.clear(Notes.Candidates)
    Runtime.NoteHold, Runtime.NotesActive, Runtime.ResetNotes = nil, nil, nil
end)
end

do
local CatchConnections = {}
local CatchNotifiedTools = setmetatable({}, { __mode = "k" })
local CatchKnownTools = setmetatable({}, { __mode = "k" })
local CatchWatchedContainers = setmetatable({}, { __mode = "k" })
local CatchGuiTextConnections = setmetatable({}, { __mode = "k" })
local CatchGuiVisibilityConnections = setmetatable({}, { __mode = "k" })
local CatchGuiScopes = setmetatable({}, { __mode = "k" })
local CatchGuiQueue = { Items = {}, Head = 1, Scheduled = false }
local CatchTimerPreviousActivity = false
local CatchCycle = { Serial = 0, Reported = 0, Reel = nil, LastReelAt = 0 }

observeLocalCatchReel = function(reel)
    if not CatchTimerRunning then return end
    if not reel then
        CatchCycle.Reel = nil
        return
    end
    if CatchCycle.Reel ~= reel then
        CatchCycle.Reel = reel
        CatchCycle.Serial = CatchCycle.Serial + 1
    end
    CatchCycle.LastReelAt = os.clock()
end

local function hasPendingLocalCatch()
    observeLocalCatchReel(ReelController.ActiveReel)
    return CatchCycle.Serial > CatchCycle.Reported
        and os.clock() - CatchCycle.LastReelAt < 12
end

local function formatCatchElapsed(seconds)
    seconds = math.max(0, tonumber(seconds) or 0)
    local minutes = math.floor(seconds / 60)
    local wholeSeconds = math.floor(seconds % 60)
    local tenths = math.floor((seconds % 1) * 10)
    return string.format("%02d:%02d.%d", minutes, wholeSeconds, tenths)
end

updateCatchTimerText = function()
    if not CatchTimerParagraph then return end
    if CatchTimerStartedAt then
        CatchTimerParagraph:SetDesc("Current catch: " .. formatCatchElapsed(os.clock() - CatchTimerStartedAt))
    elseif CatchTimerResultText and os.clock() < CatchTimerResultUntil then
        CatchTimerParagraph:SetDesc(CatchTimerResultText)
    else
        CatchTimerParagraph:SetDesc("Waiting for the next catch.")
    end
end

local function reportCaughtFish(name, weight)
    name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" or not tonumber(weight) or weight <= 0 or not hasPendingLocalCatch() then return false end

    local now = os.clock()
    CatchCycle.Reported = CatchCycle.Serial

    local elapsed = CatchTimerStartedAt and math.max(0, now - CatchTimerStartedAt) or nil
    CatchTimerStartedAt = nil
    if elapsed then
        CatchTimerResultText = "Caught in " .. formatCatchElapsed(elapsed)
    else
        CatchTimerResultText = "Catch detected; timer was not active."
    end
    CatchTimerResultUntil = now + 4
    pcall(updateCatchTimerText)

    if Config.CatchNotifications then
        local weightText = weight and string.format("%.2f kg", weight) or "weight unavailable"
        pcall(function()
            WindUI:Notify({ Title = "Fish caught", Content = name .. " — " .. weightText, Duration = 5 })
        end)
    end
    return true
end

local function parseCatchAnnouncement(text)
    text = tostring(text or "")
        :gsub("<[^>]->", "")
        :gsub("&nbsp;", " ")
        :gsub("\194\160", " ")
        :gsub("%s+", " ")
    local lower = string.lower(text)
    local _, youCaughtEnd = lower:find("you%s+caught")
    local caughtStart, caughtEnd = lower:find("caught", 1, true)
    if not caughtEnd then return nil end
    if youCaughtEnd then
        caughtEnd = youCaughtEnd
    elseif not lower:sub(1, caughtStart - 1):match("^%s*$") then
        -- Ignore server-wide lines such as "PlayerName caught ...".
        return nil
    end
    local weightStart, _, weightString = lower:find("([%d%,%.]+)%s*kg")
    local normalizedWeight = weightString
    if normalizedWeight and string.find(normalizedWeight, ",", 1, true) then
        if string.find(normalizedWeight, ".", 1, true) or normalizedWeight:match(",%d%d%d$") then
            normalizedWeight = normalizedWeight:gsub(",", "")
        else
            normalizedWeight = normalizedWeight:gsub(",", ".")
        end
    end
    local weight = tonumber(normalizedWeight)
    if not weightStart or not caughtEnd or not weight or weightStart <= caughtEnd then return nil end

    local namePart = text:sub(caughtEnd + 1, weightStart - 1)
    local lowerNamePart = string.lower(namePart)
    local atStart = lowerNamePart:match(".*()%s+at%s*$")
    if atStart then namePart = namePart:sub(1, atStart - 1) end
    namePart = namePart:gsub("^%s*[Aa]n?%s+", ""):gsub("^%s+", ""):gsub("%s+$", "")
    namePart = namePart:gsub("[%s%p]+$", "")
    if namePart == "" then return nil end
    return namePart, weight
end

local function handleCatchText(text)
    if not hasPendingLocalCatch() then return false end
    local name, weight = parseCatchAnnouncement(text)
    if name then
        return reportCaughtFish(name, weight)
    end
    return false
end

local function getCaughtFishDetails(tool)
    if not tool:IsA("Tool") or isRod(tool) then return nil end
    local name = tool.Name
    local weight
    local isFish = false
    local hasRarity = false

    local function inspect(instance)
        local ok, attributes = pcall(function() return instance:GetAttributes() end)
        if ok then
            for key, value in pairs(attributes) do
                local normalized = string.lower(tostring(key)):gsub("[^%w]", "")
                if normalized == "fishname" or normalized == "fishid" or normalized == "species" then
                    if type(value) == "string" and value ~= "" then name = value end
                    isFish = true
                elseif normalized == "itemtype" or normalized == "category" then
                    if string.lower(tostring(value)) == "fish" then isFish = true end
                elseif normalized == "weight" or normalized == "fishweight" then
                    weight = tonumber(value) or weight
                    if not weight and type(value) == "string" then weight = tonumber(value:match("[%d%.]+")) end
                elseif normalized == "rarity" or normalized == "fishrarity" then
                    hasRarity = true
                end
            end
        end
        if instance:IsA("ValueBase") then
            local normalized = string.lower(instance.Name):gsub("[^%w]", "")
            local value
            pcall(function() value = instance.Value end)
            if normalized == "weight" or normalized == "fishweight" then
                weight = tonumber(value) or weight
                if not weight and type(value) == "string" then weight = tonumber(value:match("[%d%.]+")) end
            elseif normalized == "rarity" or normalized == "fishrarity" then
                hasRarity = true
            elseif normalized == "fishname" or normalized == "species" then
                if type(value) == "string" and value ~= "" then name = value end
                isFish = true
            end
        end
    end

    inspect(tool)
    for _, descendant in ipairs(tool:GetDescendants()) do inspect(descendant) end
    if not weight then weight = tonumber(tool.Name:match("([%d%.]+)%s*[kK][gG]")) end
    if weight and hasRarity then isFish = true end
    if not isFish then return nil end
    return { Name = name, Weight = weight }
end

local function watchCatchContainer(container)
    if not container or CatchWatchedContainers[container] then return end
    CatchWatchedContainers[container] = true
    -- Existing tools are inventory, not fresh catches. Remember them before
    -- listening so equipping/unequipping or selecting an aquarium fish is quiet.
    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("Tool") then CatchKnownTools[child] = true end
    end
    table.insert(CatchConnections, container.ChildAdded:Connect(function(child)
        if not child:IsA("Tool") or CatchKnownTools[child] then return end
        CatchKnownTools[child] = true
        if not hasPendingLocalCatch() then return end
        local serial = CatchCycle.Serial
        task.spawn(function()
            -- Metadata can replicate after ChildAdded. Wait briefly without
            -- treating a later equipment move as another acquisition.
            for _ = 1, 8 do
                if not CatchTimerRunning or not child.Parent or CatchNotifiedTools[child] then return end
                if CatchCycle.Serial ~= serial or not hasPendingLocalCatch() then return end
                local fish = getCaughtFishDetails(child)
                if fish and fish.Weight then
                    CatchNotifiedTools[child] = true
                    reportCaughtFish(fish.Name, fish.Weight)
                    return
                end
                task.wait(0.15)
            end
        end)
    end))
end

local function isPersonalCatchScope(instance, playerGui)
    local current = instance
    local scope
    while current and current ~= playerGui do
        local name = string.lower(current.Name):gsub("[^%w]", "")
        if string.find(name, "windui", 1, true)
            or string.find(name, "bootlean", 1, true)
            or string.find(name, "chat", 1, true)
            or string.find(name, "bestiary", 1, true)
            or string.find(name, "inventory", 1, true)
            or string.find(name, "global", 1, true)
            or string.find(name, "server", 1, true) then
            return false
        end
        if string.find(name, "catchresult", 1, true)
            or string.find(name, "caughtfish", 1, true)
            or string.find(name, "fishcaught", 1, true)
            or string.find(name, "catchscreen", 1, true)
            or string.find(name, "catchui", 1, true)
            or string.find(name, "reelresult", 1, true)
            or string.find(name, "catchnotification", 1, true) then
            scope = current
        end
        current = current.Parent
    end
    return scope ~= nil and current == playerGui, scope
end

local function isVisibleCatchText(instance, playerGui)
    local current = instance
    while current and current ~= playerGui do
        if current:IsA("ScreenGui") and not current.Enabled then return false end
        if current:IsA("GuiObject") and not current.Visible then return false end
        current = current.Parent
    end
    return current == playerGui
end

local flushCatchGuiQueue
local function queueCatchRecord(record, force)
    if not CatchTimerRunning or not Config.CatchNotifications or not record.Alive
        or not hasPendingLocalCatch() then return end
    record.Force = record.Force or force == true
    if not record.Queued then
        if #CatchGuiQueue.Items - CatchGuiQueue.Head + 1 >= 128 then return end
        record.Queued = true
        table.insert(CatchGuiQueue.Items, record)
    end
    if not CatchGuiQueue.Scheduled then
        CatchGuiQueue.Scheduled = true
        task.delay(0.06, function() flushCatchGuiQueue() end)
    end
end

flushCatchGuiQueue = function()
    if not CatchTimerRunning or not Config.CatchNotifications or not hasPendingLocalCatch() then
        for index = CatchGuiQueue.Head, #CatchGuiQueue.Items do
            local record = CatchGuiQueue.Items[index]
            record.Queued, record.Force = false, false
        end
        table.clear(CatchGuiQueue.Items)
        CatchGuiQueue.Head, CatchGuiQueue.Scheduled = 1, false
        return
    end
    -- Text/visibility bursts are coalesced; at most 16 personal labels per slice.
    for _ = 1, 16 do
        local record = CatchGuiQueue.Items[CatchGuiQueue.Head]
        if not record then break end
        CatchGuiQueue.Head = CatchGuiQueue.Head + 1
        local force = record.Force
        record.Queued, record.Force = false, false
        if record.Alive then pcall(record.Check, force) end
    end
    if CatchGuiQueue.Head <= #CatchGuiQueue.Items then
        if CatchGuiQueue.Head > 64 then
            local remaining = {}
            for index = CatchGuiQueue.Head, #CatchGuiQueue.Items do table.insert(remaining, CatchGuiQueue.Items[index]) end
            CatchGuiQueue.Items, CatchGuiQueue.Head = remaining, 1
        end
        task.delay(0.05, function() flushCatchGuiQueue() end)
    else
        table.clear(CatchGuiQueue.Items)
        CatchGuiQueue.Head, CatchGuiQueue.Scheduled = 1, false
    end
end

local function unwatchCatchText(instance)
    local record = CatchGuiTextConnections[instance]
    if not record then return end
    record.Alive = false
    for _, connection in ipairs(record.Connections) do connection:Disconnect() end
    for ancestor in pairs(record.VisibilityAncestors) do
        local visibility = CatchGuiVisibilityConnections[ancestor]
        if visibility then
            visibility.Records[record] = nil
            if next(visibility.Records) == nil then
                visibility.Connection:Disconnect()
                CatchGuiVisibilityConnections[ancestor] = nil
            end
        end
    end
    record.Scope.Records[record] = nil
    record.Scope.Count = math.max(0, record.Scope.Count - 1)
    CatchGuiTextConnections[instance] = nil
end

local function watchCatchText(instance, playerGui, checkCurrentText)
    if CatchGuiTextConnections[instance] then return end
    if not (instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox")) then return end
    local personal, scopeRoot = isPersonalCatchScope(instance, playerGui)
    if not personal then return end
    local scope = CatchGuiScopes[scopeRoot]
    if not scope then
        scope = { Records = {}, Count = 0, NextOrder = 0, LastAggregateAt = 0 }
        CatchGuiScopes[scopeRoot] = scope
    end
    if scope.Count >= 64 then return end
    scope.Count = scope.Count + 1
    scope.NextOrder = scope.NextOrder + 1
    local record = {
        Alive = true, Connections = {}, VisibilityAncestors = {}, Scope = scope,
        Instance = instance, Order = scope.NextOrder,
        Text = instance.Text, WasVisible = isVisibleCatchText(instance, playerGui),
    }
    scope.Records[record] = true
    record.Check = function(force)
        if not record.Alive or not instance.Parent then return end
        local currentText = instance.Text
        local visible = isVisibleCatchText(instance, playerGui)
        local changed = currentText ~= record.Text or (visible and not record.WasVisible)
        record.Text, record.WasVisible = currentText, visible
        if not visible or (not changed and force ~= true) then return end
        if not CatchTimerRunning or not Config.CatchNotifications or not hasPendingLocalCatch() then return end
        if handleCatchText(currentText) then return end
        local lowerText = string.lower(tostring(currentText or ""))
        if not string.find(lowerText, "caught", 1, true) and not string.find(lowerText, "kg", 1, true) then return end
        local now = os.clock()
        if scope.LastAggregateAt > 0 and now - scope.LastAggregateAt < 0.05 then return end
        scope.LastAggregateAt = now
        local fragments = {}
        local ordered = {}
        for otherRecord in pairs(scope.Records) do
            table.insert(ordered, otherRecord)
            if #ordered > 32 then return end
        end
        table.sort(ordered, function(left, right) return left.Order < right.Order end)
        for _, otherRecord in ipairs(ordered) do
            local other = otherRecord.Instance
            if otherRecord.Alive and other.Parent and isVisibleCatchText(other, playerGui) then
                local fragment = tostring(other.Text or "")
                if fragment ~= "" then table.insert(fragments, fragment) end
            end
        end
        if #fragments > 1 then handleCatchText(table.concat(fragments, " ")) end
    end
    table.insert(record.Connections, instance:GetPropertyChangedSignal("Text"):Connect(function()
        queueCatchRecord(record, false)
    end))
    local ancestor = instance
    while ancestor and ancestor ~= playerGui do
        local propertyName = ancestor:IsA("ScreenGui") and "Enabled" or (ancestor:IsA("GuiObject") and "Visible")
        if propertyName then
            local visibility = CatchGuiVisibilityConnections[ancestor]
            if not visibility then
                visibility = { Records = {} }
                local registeredVisibility = visibility
                visibility.Connection = ancestor:GetPropertyChangedSignal(propertyName):Connect(function()
                    for childRecord in pairs(registeredVisibility.Records) do queueCatchRecord(childRecord, false) end
                end)
                CatchGuiVisibilityConnections[ancestor] = visibility
            end
            visibility.Records[record] = true
            record.VisibilityAncestors[ancestor] = true
        end
        ancestor = ancestor.Parent
    end
    CatchGuiTextConnections[instance] = record
    if checkCurrentText then queueCatchRecord(record, true) end
end

local function watchCurrentCatchContainers()
    watchCatchContainer(LocalPlayer:FindFirstChildOfClass("Backpack"))
    watchCatchContainer(LocalPlayer.Character)
end

watchCurrentCatchContainers()
table.insert(CatchConnections, LocalPlayer.ChildAdded:Connect(function(child)
    if child:IsA("Backpack") then watchCatchContainer(child) end
end))
table.insert(CatchConnections, LocalPlayer.CharacterAdded:Connect(watchCatchContainer))

local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui")
table.insert(CatchConnections, playerGui.DescendantAdded:Connect(function(instance)
    watchCatchText(instance, playerGui, true)
end))
table.insert(CatchConnections, playerGui.DescendantRemoving:Connect(function(instance)
    unwatchCatchText(instance)
end))
task.spawn(function()
    local pending = playerGui:GetChildren()
    local cursor = 1
    while cursor <= #pending do
        if not CatchTimerRunning then return end
        local instance = pending[cursor]
        cursor = cursor + 1
        watchCatchText(instance, playerGui, false)
        for _, child in ipairs(instance:GetChildren()) do table.insert(pending, child) end
        if cursor % 80 == 0 then task.wait(0.02) end
    end
end)

onCleanup(function()
    CatchTimerRunning = false
    observeLocalCatchReel = nil
    CatchTimerStartedAt = nil
    CatchTimerResultText = nil
    for instance in pairs(CatchGuiTextConnections) do unwatchCatchText(instance) end
    table.clear(CatchGuiQueue.Items)
    CatchGuiQueue.Head, CatchGuiQueue.Scheduled = 1, false
    for _, connection in ipairs(CatchConnections) do connection:Disconnect() end
end)

task.spawn(function()
    local nextTimerTextUpdate = 0
    while CatchTimerRunning do
        observeLocalCatchReel(ReelController.ActiveReel)
        local activeFishing = ReelController.ActiveReel ~= nil
        if not activeFishing then
            local rod = getEquippedRod()
            if rod then
                local ok, bobberActive = pcall(hasBobber, rod)
                activeFishing = ok and bobberActive == true
            end
        end
        if not activeFishing then
            CatchTimerPreviousActivity = false
        elseif not CatchTimerStartedAt
            and not CatchTimerPreviousActivity
            and os.clock() >= CatchTimerResultUntil then
            CatchTimerStartedAt = os.clock()
            CatchTimerResultText = nil
            CatchTimerResultUntil = 0
        end
        if activeFishing then CatchTimerPreviousActivity = true end
        if os.clock() >= nextTimerTextUpdate then
            nextTimerTextUpdate = os.clock() + 0.5
            pcall(updateCatchTimerText)
        end
        task.wait(0.1)
    end
end)
end
local function normalizeEventText(value)
    return string.lower(tostring(value or "")):gsub("[^%w]", "")
end

do
EventsTab:Section({ Title = "Weather and Sky" })
local EventView = { Category = "All", ConfirmedOnly = false, Search = "" }
EventsTab:Dropdown({ Title = "Event Category", Values = { "All", "World / Boss", "Goblins", "Seasonal" }, Value = "All", Callback = function(value) EventView.Category = value end })
EventsTab:Toggle({ Title = "Confirmed Locations Only", Value = false, Callback = function(value) EventView.ConfirmedOnly = value == true end })
EventsTab:Input({ Title = "Find Event or Island", Placeholder = "Shark, Moosewood...", Callback = function(value) EventView.Search = tostring(value or ""):lower() end })
local WeatherParagraph = EventsTab:Paragraph({
    Title = "Active Weather",
    Desc = "Scanning...",
    Image = "cloud-sun",
    ImageSize = 20,
})

EventsTab:Section({ Title = "World and Boss Events" })
local WorldBossParagraph = EventsTab:Paragraph({
    Title = "Detected Events",
    Desc = "Scanning...",
    Image = "activity",
    ImageSize = 20,
})

EventsTab:Section({ Title = "Boosts and Admin Events" })
local BoostAdminParagraph = EventsTab:Paragraph({
    Title = "Detected Boosts",
    Desc = "Scanning...",
    Image = "zap",
    ImageSize = 20,
})

EventsTab:Section({ Title = "Seasonal and Limited Events" })
local SeasonalParagraph = EventsTab:Paragraph({
    Title = "Detected Seasonal Events",
    Desc = "Scanning...",
    Image = "sparkles",
    ImageSize = 20,
})

local ServerInfoParagraph = EventsTab:Paragraph({
    Title = "Server Info",
    Desc = "Loading...",
    Image = "server",
    ImageSize = 20,
})

local OtherEventParagraph = EventsTab:Paragraph({
    Title = "Other active event notices",
    Desc = "Scanning...",
    Image = "bell-ring",
    ImageSize = 18,
})

local EventDefinitions = {
    -- Time, weather, and sky events.
    { Key = "clear", Title = "Clear", Group = "weather", Terms = { "clearweather", "weatherclear", "weatherchangedtoclear", "clearskies" }, ExactTerms = { "clear" } },
    { Key = "fog", Title = "Foggy", Group = "weather", Terms = { "heavyfog", "foggy", "fogweather", "fog" } },
    { Key = "windy", Title = "Windy", Group = "weather", Terms = { "windyweather", "windy" } },
    { Key = "rain", Title = "Rain", Group = "weather", Terms = { "rainweather", "rainbegins", "rainstarted", "raining" }, ExactTerms = { "rain" }, ExcludeTerms = { "rainbow", "rainstorm" } },
    { Key = "tempest", Title = "Thunderstorm / Tempest", Group = "weather", Terms = { "tempest", "thunderstorm" }, WorkspaceTerms = { "tempest", "thunderstorm" } },
    { Key = "starfall", Title = "Starfall", Group = "weather", Terms = { "starfall", "fallenstars" }, WorkspaceTerms = { "starfall", "fallenstar" } },
    { Key = "rainbow", Title = "Rainbow", Group = "weather", Terms = { "rainbowtotem", "rainbowweather", "rainbowevent", "rainbow" } },
    { Key = "eclipse", Title = "Eclipse", Group = "weather", Terms = { "solareclipse", "eclipse" }, WorkspaceTerms = { "eclipse" } },
    { Key = "aurora", Title = "Aurora Borealis", Group = "weather", Terms = { "auroraborealis", "auroraevent" }, WorkspaceTerms = { "auroraborealis" } },
    { Key = "bluemoon", Title = "Blue Moon", Group = "weather", Terms = { "bluemoon", "bluemoonweather" }, WorkspaceTerms = { "bluemoon" } },
    { Key = "meteor", Title = "Meteor", Group = "weather", Terms = { "meteorrain", "meteorevent", "meteorstrike", "meteor" }, WorkspaceTerms = { "meteor", "meteorite" } },
    { Key = "blizzard", Title = "Blizzard", Group = "weather", Terms = { "blizzard" }, WorkspaceTerms = { "blizzard" } },
    { Key = "avalanche", Title = "Avalanche", Group = "weather", Terms = { "avalanche" }, WorkspaceTerms = { "avalanche" } },
    { Key = "sovereignsurge", Title = "Sovereign Surge", Group = "weather", Terms = { "sovereignsurge" }, WorkspaceTerms = { "sovereignsurge" } },
    { Key = "sovereignstorm", Title = "Sovereign Storm", Group = "weather", Terms = { "sovereignstorm" }, WorkspaceTerms = { "sovereignstorm" } },
    { Key = "sovereignreckoning", Title = "Sovereign Reckoning", Group = "weather", Terms = { "sovereignreckoning" }, WorkspaceTerms = { "sovereignreckoning" } },
    { Key = "shinySurge", Title = "Shiny Surge", Group = "boosts", Terms = { "shinysurge" } },
    { Key = "mutationSurge", Title = "Mutation Surge", Group = "boosts", Terms = { "mutationsurge" } },
    { Key = "fireflies", Title = "Night of the Fireflies", Group = "weather", Terms = { "nightofthefireflies", "firefliesevent" } },
    { Key = "luminous", Title = "Night of the Luminous", Group = "weather", Terms = { "nightoftheluminous", "luminousevent" } },
    { Key = "moonlit", Title = "Moonlit Mirage", Group = "weather", Terms = { "moonlitmirage", "moonlitbonus" } },
    { Key = "highweight", Title = "High Weight Fish", Group = "boosts", Terms = { "highweightfish", "highweight" } },
    { Key = "zeusstorm", Title = "Zeus's Storm", Group = "weather", Terms = { "zeusstorm", "lightningstorm" }, WorkspaceTerms = { "zeusstorm" } },
    { Key = "luckypool", Title = "Lucky Pool", Group = "world", Terms = { "luckypool" }, WorkspaceTerms = { "luckypool" } },

    -- World spawns, migrations, hunts, and NPC events.
    { Key = "fishabundance", Title = "Fish Abundance", Group = "world", Terms = { "fishabundance", "abundancepool" }, WorkspaceTerms = { "abundance", "fishpool" } },
    { Key = "orca", Title = "Orca Migration / Hunt", Group = "world", Terms = { "orcamigration", "killerwhalemigration", "orcahunt" }, ExcludeTerms = { "ancientorca" }, WorkspaceTerms = { "orcamigration", "orcahunt", "orca" } },
    { Key = "ancientorca", Title = "Ancient Orca Migration", Group = "world", Terms = { "ancientorcamigration", "albinoorcamigration" }, WorkspaceTerms = { "ancientorca", "albinoorca" } },
    { Key = "whalemigration", Title = "Whale Migration", Group = "world", Terms = { "whalemigration", "bluewhalemigration", "mobymigration" }, WorkspaceTerms = { "whalemigration", "bluewhalemigration", "mobymigration" } },
    { Key = "bluewhalehunt", Title = "Blue Whale Hunt", Group = "world", Terms = { "bluewhalehunt", "bluewhalespotted" }, WorkspaceTerms = { "bluewhalehunt", "bluewhale" } },
    { Key = "mobwhalehunt", Title = "Moby & Blue Whale Hunt", Group = "world", Terms = { "mobyandbluewhalehunt", "mobybluewhalehunt", "mobyhunt" }, WorkspaceTerms = { "mobybluewhale", "mobyhunt" } },
    { Key = "sharkhunt", Title = "Shark Hunt", Group = "world", Terms = { "sharkhunt", "globalsharkhunt" }, WorkspaceTerms = { "sharkhunt" } },
    { Key = "megamouth", Title = "Megamouth Shark Hunt", Group = "world", Terms = { "megamouthsharkhunt", "megamouthshark" }, WorkspaceTerms = { "megamouthsharkhunt", "megamouthshark" } },
    { Key = "greatwhite", Title = "Great White Shark Hunt", Group = "world", Terms = { "greatwhitesharkhunt", "greatwhiteshark", "greatwhite" }, WorkspaceTerms = { "greatwhitesharkhunt", "greatwhiteshark", "greatwhite" } },
    { Key = "greathammerhead", Title = "Great Hammerhead Shark Hunt", Group = "world", Terms = { "greathammerheadsharkhunt", "greathammerheadshark", "greathammerhead" }, WorkspaceTerms = { "greathammerheadsharkhunt", "greathammerheadshark", "greathammerhead" } },
    { Key = "whaleshark", Title = "Whale Shark Hunt", Group = "world", Terms = { "whalesharkhunt", "whaleshark" }, ExcludeTerms = { "colossalwhaleshark" }, WorkspaceTerms = { "whalesharkhunt", "whaleshark" } },
    { Key = "babybloop", Title = "Baby Bloop Fish Hunt", Group = "world", Terms = { "babybloopfishhunt", "babybloopfish", "babyblobfishhunt", "babyblobfish" }, WorkspaceTerms = { "babybloopfishhunt", "babybloopfish", "babyblobfishhunt", "babyblobfish" } },
    { Key = "bloopfish", Title = "Bloop Fish Hunt", Group = "world", Terms = { "bloopfishhunt", "enragedbloopfish", "bloopfishspotted" }, ExcludeTerms = { "bloopfishes" }, WorkspaceTerms = { "bloopfishhunt", "enragedbloopfish", "bloopfish" } },
    { Key = "mosslurker", Title = "Mosslurker Hunt", Group = "world", Terms = { "mosslurkerhunt", "mosslurker" }, WorkspaceTerms = { "mosslurkerhunt", "mosslurker" } },
    { Key = "narwhal", Title = "Narwhal Hunt", Group = "world", Terms = { "narwhalhunt", "narwhalspotted" }, WorkspaceTerms = { "narwhalhunt", "narwhal" } },
    { Key = "magiciannarwhal", Title = "Magician Narwhal Hunt", Group = "world", Terms = { "magiciannarwhalhunt", "magiciannarwhal" }, WorkspaceTerms = { "magiciannarwhalhunt", "magiciannarwhal" } },
    { Key = "dreadfin", Title = "Dreadfin Hunt", Group = "world", Terms = { "dreadfinhunt", "dreadfin" }, WorkspaceTerms = { "dreadfinhunt", "dreadfin" } },
    { Key = "apexsharkhunt", Title = "Apex Shark Hunt", Group = "world", Terms = { "apexsharkhunt" }, WorkspaceTerms = { "apexsharkhunt" } },
    { Key = "colossalwhaleshark", Title = "Colossal Whale Shark", Group = "world", Terms = { "colossalwhalesharkhunt", "colossalwhaleshark", "colossalveil" }, WorkspaceTerms = { "colossalwhalesharkhunt", "colossalwhaleshark", "colossalveil" } },
    { Key = "greaterwhiteshark", Title = "Greater White Shark", Group = "world", Terms = { "greaterwhiteshark" }, WorkspaceTerms = { "greaterwhiteshark" } },
    { Key = "ancienthammerhead", Title = "Ancient Hammerhead Shark", Group = "world", Terms = { "ancienthammerheadshark", "ancienthammerhead" }, WorkspaceTerms = { "ancienthammerheadshark", "ancienthammerhead" } },
    { Key = "absolutedarkness", Title = "Absolute Darkness", Group = "world", Terms = { "absolutedarkness", "ancientdepthserpentpool" }, WorkspaceTerms = { "absolutedarkness", "yellowpool" } },
    { Key = "megalodon", Title = "Megalodon Hunt", Group = "world", Terms = { "megalodonhunt", "megalodonevent" }, ExcludeTerms = { "ancientmegalodon", "phantommegalodon" }, WorkspaceTerms = { "megalodonhunt", "megalodonabundance", "megalodon" } },
    { Key = "ancientmegalodon", Title = "Ancient Megalodon", Group = "world", Terms = { "ancientmegalodon" }, WorkspaceTerms = { "ancientmegalodon" } },
    { Key = "phantommegalodon", Title = "Phantom Megalodon", Group = "world", Terms = { "phantommegalodon" }, WorkspaceTerms = { "phantommegalodon" } },
    { Key = "apexfishhunt", Title = "Apex Fish Hunt", Group = "world", Terms = { "apexfishhunt" }, WorkspaceTerms = { "apexfishhunt" } },
    { Key = "kraken", Title = "Kraken Hunt", Group = "world", Terms = { "krakenhunt", "krakenencounter" }, WorkspaceTerms = { "krakenhunt", "krakenpool" } },
    { Key = "ancientkraken", Title = "Ancient Kraken Hunt", Group = "world", Terms = { "ancientkrakenhunt", "ancientkraken" }, WorkspaceTerms = { "ancientkraken" } },
    { Key = "scylla", Title = "Scylla Hunt", Group = "world", Terms = { "scyllahunt" }, WorkspaceTerms = { "scyllahunt" } },
    { Key = "colossaldragon", Title = "Colossal Dragon Hunt", Group = "world", Terms = { "colossaldragonhunt", "colossaldragon" }, WorkspaceTerms = { "colossaldragon" } },
    { Key = "octophant", Title = "Octophant Hunt", Group = "world", Terms = { "octophanthunt", "octophant" }, WorkspaceTerms = { "octophant" } },
    { Key = "whalepool", Title = "Whalepool / Fish Swarm", Group = "world", Terms = { "whalepool", "fishswarm" }, WorkspaceTerms = { "whalepool", "fishswarm" } },
    { Key = "strangewhirlpool", Title = "Strange Whirlpool", Group = "world", Terms = { "strangewhirlpool", "glowingwhirlpool" }, WorkspaceTerms = { "strangewhirlpool" } },
    { Key = "sunkenchests", Title = "Sunken Chests", Group = "world", Terms = { "sunkenchests", "sunkentreasure", "mythicsunkenchest" }, WorkspaceTerms = { "sunkenchest" } },
    { Key = "nuke", Title = "Nuke", Group = "world", Terms = { "nukeexplosion", "nukeevent", "nuclearpool" }, WorkspaceTerms = { "nuke" } },
    { Key = "lanternkeeper", Title = "Lantern Keeper", Group = "world", Terms = { "lanternkeeper" }, WorkspaceTerms = { "lanternkeeper" } },
    { Key = "merchant", Title = "Travelling Merchant", Group = "world", Terms = { "travellingmerchant", "travelingmerchant" }, WorkspaceTerms = { "travellingmerchant", "travelingmerchant" } },
    { Key = "goblins", Title = "Goblins", Group = "world", Terms = {}, WorkspaceTerms = { "goblin" }, ExcludeTerms = { "goblinshark" } },

    -- Timed boosts and the admin event roster from the Fisch Wiki.
    { Key = "luck2x", Title = "2x Luck Event", Group = "boosts", Terms = { "2xluck", "doubleluck", "luckboostx2" } },
    { Key = "exp2x", Title = "2x EXP Event", Group = "boosts", Terms = { "2xexp", "2xexperience", "doubleexp", "xpboostx2" } },
    { Key = "shiny2x", Title = "2x Shiny Event", Group = "boosts", Terms = { "2xshiny", "doubleshiny" } },
    { Key = "mutation2x", Title = "2x Mutation Event", Group = "boosts", Terms = { "2xmutation", "doublemutation" } },
    { Key = "developer", Title = "Server Boss / Developer Event", Group = "boosts", Terms = { "serverboss", "developerevent", "devevent", "adminspawnedevent" } },
    { Key = "adminspawn", Title = "Admin Spawned Event", Group = "boosts", Terms = { "adminspawn", "adminevent" } },
    { Key = "aliens", Title = "Aliens", Group = "boosts", Terms = { "aliensevent", "aliens" } },
    { Key = "apexleviathans", Title = "Apex Leviathans", Group = "boosts", Terms = { "apexleviathans" } },
    { Key = "bucketbloom", Title = "Bucket Bloom", Group = "boosts", Terms = { "bucketbloom" } },
    { Key = "bloopfishes", Title = "Bloop Fishes Admin Event", Group = "boosts", Terms = { "bloopfishesadminevent", "bloopfishevent", "bloopfishes" } },
    { Key = "blackmarketadmin", Title = "Black Market", Group = "boosts", Terms = { "blackmarketadminevent", "blackmarketvendor", "blackmarket" } },
    { Key = "blackout", Title = "Blackout", Group = "boosts", Terms = { "blackoutevent", "blackoutadminevent", "blackout" } },
    { Key = "crates", Title = "Crates", Group = "boosts", Terms = { "cratesevent", "cratesadminevent", "crates" } },
    { Key = "buffedgoldstorm", Title = "Buffed Goldstorm", Group = "boosts", Terms = { "buffedgoldstorm" } },
    { Key = "cosmicrelics", Title = "Cosmic Relics", Group = "boosts", Terms = { "cosmicrelics" } },
    { Key = "corruption", Title = "Corruption", Group = "boosts", Terms = { "corruption" } },
    { Key = "earthquake", Title = "Earthquake", Group = "boosts", Terms = { "earthquake" } },
    { Key = "egghorde", Title = "Egg Horde", Group = "boosts", Terms = { "egghorde" } },
    { Key = "emojis", Title = "Emojis", Group = "boosts", Terms = { "emojisevent", "emojisadminevent", "emojis" } },
    { Key = "emberflame", Title = "Emberflame Hogchokers", Group = "boosts", Terms = { "emberflamehogchokers", "emberflamehogchoker" } },
    { Key = "food", Title = "Food", Group = "boosts", Terms = { "foodevent", "foodadminevent" }, ExactTerms = { "food" } },
    { Key = "fishadmin", Title = "Fish Admin Event", Group = "boosts", Terms = { "fishadminevent", "fishadmin" }, ExactTerms = { "fish" } },
    { Key = "ghastlytide", Title = "Ghastly Tide", Group = "boosts", Terms = { "ghastlytide" } },
    { Key = "galaxy", Title = "Galaxy", Group = "boosts", Terms = { "galaxyevent", "galaxyadminevent" }, ExactTerms = { "galaxy" } },
    { Key = "glitchstorm", Title = "Glitchstorm", Group = "boosts", Terms = { "glitchstorm" } },
    { Key = "globalsharkhunt", Title = "Global Shark Hunt", Group = "boosts", Terms = { "globalsharkhuntadminevent" } },
    { Key = "goldstorm", Title = "Goldstorm", Group = "boosts", Terms = { "goldstorm" } },
    { Key = "heavenlysparkles", Title = "Heavenly Sparkles", Group = "boosts", Terms = { "heavenlysparkles" } },
    { Key = "luckycosmicrelics", Title = "Lucky Cosmic Relics", Group = "boosts", Terms = { "luckycosmicrelics" } },
    { Key = "leviathanrampage", Title = "Leviathan Rampage", Group = "boosts", Terms = { "leviathanrampage" } },
    { Key = "madness", Title = "Madness", Group = "boosts", Terms = { "madness" } },
    { Key = "mayhem", Title = "Mayhem", Group = "boosts", Terms = { "mayhem" }, ExcludeTerms = { "megamayhem" }, WorkspaceTerms = { "mayhem" } },
    { Key = "megamayhem", Title = "Mega Mayhem", Group = "boosts", Terms = { "megamayhem" }, WorkspaceTerms = { "megamayhem" } },
    { Key = "mangoadmin", Title = "Mango Admin Event", Group = "boosts", Terms = { "mangoadminevent" }, ExactTerms = { "mango" } },
    { Key = "nulltide", Title = "Nulltide", Group = "boosts", Terms = { "nulltide" } },
    { Key = "noliferod", Title = "Original No-Life Rod Event", Group = "boosts", Terms = { "originalnoliferod", "originalliferod", "noliferodadmin", "noliferod" } },
    { Key = "overgrowth", Title = "Overgrowth", Group = "boosts", Terms = { "overgrowth" } },
    { Key = "pondemperor", Title = "Pond Emperor Uprising", Group = "boosts", Terms = { "pondemperoruprising" } },
    { Key = "purechaos", Title = "Pure Chaos", Group = "boosts", Terms = { "purechaos" } },
    { Key = "rainstorm", Title = "Rainstorm", Group = "boosts", Terms = { "rainstorm" } },
    { Key = "relicstorm", Title = "Relic Storm", Group = "boosts", Terms = { "relicstorm" } },
    { Key = "sharksssss", Title = "Sharkssss", Group = "boosts", Terms = { "sharksssss", "sharkksssss" } },
    { Key = "secretstorm", Title = "Secret Storm", Group = "boosts", Terms = { "secretstorm" } },
    { Key = "semichaos", Title = "Semi Chaos", Group = "boosts", Terms = { "semichaos" } },
    { Key = "skiesofanguish", Title = "Skies of Anguish", Group = "boosts", Terms = { "skiesofanguish" } },
    { Key = "snowstorm", Title = "Snowstorm", Group = "boosts", Terms = { "snowstorm" } },
    { Key = "spectraltide", Title = "Spectral Tide", Group = "boosts", Terms = { "spectraltide" } },
    { Key = "supersizer", Title = "Supersizer", Group = "boosts", Terms = { "supersizer" } },
    { Key = "tacos", Title = "Tacos", Group = "boosts", Terms = { "tacosevent", "tacos" } },
    { Key = "tentacles", Title = "Tentacles", Group = "boosts", Terms = { "tentacles" } },
    { Key = "verdantvortex", Title = "Verdant Vortex", Group = "boosts", Terms = { "verdantvortex" } },
    { Key = "volcano", Title = "Volcano", Group = "boosts", Terms = { "volcanoevent", "volcanoadminevent" } },
    { Key = "67warriors", Title = "67 Warriors", Group = "boosts", Terms = { "67warriors", "sixsevenwarriors" } },

    -- Seasonal and limited-time notices.
    { Key = "fischmas", Title = "Fischmas / Christmas", Group = "seasonal", Terms = { "fischmas", "christmasevent", "wintervillageevent" } },
    { Key = "halloween", Title = "Halloween / FischFright", Group = "seasonal", Terms = { "halloweenevent", "spookyevent", "fischfright" } },
    { Key = "valentines", Title = "Valentine's Day / Lovestorm", Group = "seasonal", Terms = { "valentinesevent", "valentinesday", "lovestorm" } },
    { Key = "tournament", Title = "Fishing Tournament", Group = "seasonal", Terms = { "fishingtournament", "serverleaderboard", "tournamentleaderboard" } },
    { Key = "deepsea", Title = "Atlantis / Deep Sea Event", Group = "seasonal", Terms = { "atlantisupdate", "deepseaupdate", "marianasveilupdate" } },
    { Key = "ingredienthunt", Title = "Ingredient Hunt", Group = "seasonal", Terms = { "ingredienthunt" } },
    { Key = "frightfulpool", Title = "Frightful Pool", Group = "seasonal", Terms = { "frightfulpool" } },
    { Key = "goldentidepools", Title = "Golden Tide Pools", Group = "seasonal", Terms = { "goldentidepools", "goldentidepool" } },
    { Key = "luckyevent", Title = "Lucky Event", Group = "seasonal", Terms = { "luckyevent" } },
}

local IslandNames = {
    { Name = "Moosewood", Terms = { "moosewood" } },
    { Name = "Roslit Bay", Terms = { "roslitbay" } },
    { Name = "Forsaken Shores", Terms = { "forsakenshores" } },
    { Name = "Mushgrove Swamp", Terms = { "mushgroveswamp" } },
    { Name = "Snowcap Island", Terms = { "snowcapisland", "snowcap" } },
    { Name = "Sunstone Island", Terms = { "sunstoneisland", "sunstone" } },
    { Name = "Terrapin Island", Terms = { "terrapinisland", "terrapin" } },
    { Name = "Ancient Isles", Terms = { "ancientisle", "ancientisles" } },
    { Name = "Statue of Sovereignty", Terms = { "statueofsovereignty", "sovereignty" } },
    { Name = "Atlantis", Terms = { "atlantis" } },
    { Name = "Veil of the Forsaken", Terms = { "veiloftheforsaken" } },
    { Name = "Northern Summit", Terms = { "northsummit", "northernsummit" } },
    { Name = "Northern Expedition", Terms = { "northernexpedition", "northexpedition" } },
    { Name = "Tidefall", Terms = { "tidefall" } },
    { Name = "Everturn Forest", Terms = { "everturnforest", "everturn" } },
    { Name = "The Deep", Terms = { "thedeep", "depths" } },
    { Name = "Gasta Cliffs", Terms = { "gastacliffs", "gasta" } },
    { Name = "Sandstone Island", Terms = { "sandstoneisland", "sandstone" } },
    { Name = "Lost Jungle", Terms = { "lostjungle" } },
    { Name = "Drylands", Terms = { "drylands" } },
    { Name = "Scoria Reach", Terms = { "scoriareach", "scotiareach" } },
    { Name = "Grand Reef", Terms = { "grandreef" } },
    { Name = "North Sea", Terms = { "northsea" } },
    { Name = "Skycrest", Terms = { "skycrest" } },
}

local EventCounts = {}
local WatchedInstances = setmetatable({}, { __mode = "k" })
local LocationModels = setmetatable({}, { __mode = "k" })
local AttributeMatches = setmetatable({}, { __mode = "k" })
local GuiVisibilityConnections = setmetatable({}, { __mode = "k" })
local MonitorConnections = {}
local MonitorRunning = true
local EventInstances: { [string]: { [any]: any } } = {}
local UnknownEventInstances = setmetatable({}, { __mode = "k" })
local MatchCaches = { workspace = {}, gui = {} }
local MatchCacheSizes = { workspace = 0, gui = 0 }
local GuiWork = { First = 1, Last = 0 }
local VisibilityWork = { First = 1, Last = 0 }
local WatchWork = { First = 1, Last = 0 }
local PendingWatches = setmetatable({}, { __mode = "k" })
local ParagraphText = setmetatable({}, { __mode = "k" })
local IslandCache = setmetatable({}, { __mode = "k" })
local LocationSnapshot = { Until = 0, Positions = {} }

local function queueGuiRecord(instance, record)
    if not MonitorRunning or record.Queued then return end
    record.Queued = true
    GuiWork.Last = GuiWork.Last + 1
    GuiWork[GuiWork.Last] = { Instance = instance, Record = record }
end

local function enqueueWatch(instance, source, recursive)
    if not MonitorRunning then return end
    local queued = PendingWatches[instance]
    if queued then
        queued.Recursive = queued.Recursive or recursive
        return
    end
    local work = { Instance = instance, Source = source, Recursive = recursive }
    PendingWatches[instance] = work
    WatchWork.Last = WatchWork.Last + 1
    WatchWork[WatchWork.Last] = work
end

local function setParagraphText(paragraph, value)
    if ParagraphText[paragraph] == value then return end
    ParagraphText[paragraph] = value
    paragraph:SetDesc(value)
end


local function findEventMatches(value, source)
    local normalized = normalizeEventText(value)
    if source == "workspace" then normalized = normalized:gsub("%d+$", "") end
    local cacheKey = source == "workspace" and "workspace" or "gui"
    local cache = MatchCaches[cacheKey]
    if cache[normalized] then return cache[normalized] end
    local matches = {}
    if normalized == "" or not normalized:find("%a")
        or (source ~= "workspace" and string.find(normalized, "caught", 1, true)) then
        return matches
    end

    for _, eventInfo in ipairs(EventDefinitions) do
        local terms = eventInfo.Terms
        if source == "workspace" then
            terms = eventInfo.WorkspaceTerms
            if not terms and eventInfo.Group == "boosts" then
                terms = eventInfo.Terms
            end
            terms = terms or {}
        end
        local excluded = false
        for _, term in ipairs(eventInfo.ExcludeTerms or {}) do
            if string.find(normalized, term, 1, true) then
                excluded = true
                break
            end
        end
        if not excluded then
            for _, term in ipairs(eventInfo.ExactTerms or {}) do
                if normalized == term then
                    matches[eventInfo.Key] = true
                    break
                end
            end
            for _, term in ipairs(terms or {}) do
                if matches[eventInfo.Key] then break end
                if string.find(normalized, term, 1, true) then
                    matches[eventInfo.Key] = true
                    break
                end
            end
        end
    end

    if MatchCacheSizes[cacheKey] >= 512 then
        MatchCaches[cacheKey] = {}
        MatchCacheSizes[cacheKey] = 0
        cache = MatchCaches[cacheKey]
    end
    cache[normalized] = matches
    MatchCacheSizes[cacheKey] = MatchCacheSizes[cacheKey] + 1
    return matches
end

local function findIslandName(value)
    local normalized = normalizeEventText(value)
    for _, islandInfo in ipairs(IslandNames) do
        for _, term in ipairs(islandInfo.Terms) do
            if string.find(normalized, term, 1, true) then
                return islandInfo.Name
            end
        end
    end
    return nil
end

local function getModelPosition(model)
    local ok, position = pcall(function()
        return model:GetPivot().Position
    end)
    return ok and position or nil
end

local function getGoblinIsland(model)
    local position = getModelPosition(model)
    local cached = IslandCache[model]
    if cached and os.clock() < cached.Until and position and cached.Position
        and (position - cached.Position).Magnitude < 150 then
        return cached.Name
    end
    local ancestor = model
    while ancestor and ancestor ~= Workspace do
        local islandName = findIslandName(ancestor.Name)
        if islandName then
            IslandCache[model] = { Name = islandName, Position = position, Until = os.clock() + 3 }
            return islandName
        end
        ancestor = ancestor.Parent
    end

    if not position then return "Unknown island" end
    if Runtime.FindNearestIsland then
        local nearest = Runtime.FindNearestIsland(position)
        if nearest then
            local name = "Near " .. nearest
            IslandCache[model] = { Name = name, Position = position, Until = os.clock() + 3 }
            return name
        end
    end

    if os.clock() >= LocationSnapshot.Until then
        LocationSnapshot.Positions = {}
        for islandModel, islandName in pairs(LocationModels) do
            if islandModel.Parent then
                local islandPosition = getModelPosition(islandModel)
                if islandPosition then
                    table.insert(LocationSnapshot.Positions, { Model = islandModel, Name = islandName, Position = islandPosition })
                end
            end
        end
        LocationSnapshot.Until = os.clock() + 3
    end

    local nearestName
    local nearestDistance = math.huge
    for _, location in ipairs(LocationSnapshot.Positions) do
        if location.Model ~= model and location.Model.Parent then
            local distance = (position - location.Position).Magnitude
            if distance < nearestDistance then
                nearestDistance = distance
                nearestName = location.Name
            end
        end
    end

    if nearestName and nearestDistance <= 1500 then
        IslandCache[model] = { Name = nearestName, Position = position, Until = os.clock() + 3 }
        return nearestName
    end
    IslandCache[model] = { Name = "Unknown island", Position = position, Until = os.clock() + 3 }
    return "Unknown island"
end

local function liveGoblinTarget(instance)
    local model = instance
    for _ = 1, 5 do
        if not model or model == Workspace then return nil end
        if model:IsA("Model") and normalizeEventText(model.Name):find("goblin", 1, true) then break end
        model = model.Parent
    end
    if not model or not model:IsA("Model") or not model:IsDescendantOf(Workspace)
        or normalizeEventText(model.Name):find("goblinshark", 1, true)
        or model:FindFirstAncestorOfClass("Tool") or Players:GetPlayerFromCharacter(model) then return nil end
    local ancestor = model
    for _ = 1, 6 do
        if not ancestor or ancestor == Workspace then break end
        local key = normalizeEventText(ancestor.Name)
        if key:find("template", 1, true) or key:find("preview", 1, true) or key:find("display", 1, true) then return nil end
        ancestor = ancestor.Parent
    end
    for _, key in ipairs({ "Active", "Alive", "QuestAvailable", "CanQuest", "Available" }) do
        if model:GetAttribute(key) == false then return nil end
    end
    for _, key in ipairs({ "Inactive", "Dead", "Disabled", "QuestCompleted" }) do
        if model:GetAttribute(key) == true then return nil end
    end
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health <= 0 then return nil end
    local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true)
    local click = model:FindFirstChildWhichIsA("ClickDetector", true)
    if prompt and (not prompt.Enabled or prompt.MaxActivationDistance <= 0) then prompt = nil end
    if click and click.MaxActivationDistance <= 0 then click = nil end
    if not prompt and not click then return nil end
    local position = getModelPosition(model)
    if not position then return nil end
    return { Key = "goblins", Title = "Goblin", Group = "world", Island = getGoblinIsland(model), Position = position, Instance = model, QuestPrompt = prompt, ClickDetector = click, Confirmed = true }
end

Runtime.GetGoblins = function()
    local targets, seen = {}, {}
    for instance in pairs(EventInstances.goblins or {}) do
        local target = liveGoblinTarget(instance)
        if target and not seen[target.Instance] then
            seen[target.Instance] = true
            table.insert(targets, target)
            if #targets >= 8 then break end
        end
    end
    return targets
end

local function getEventIslandList(eventKey)
    local found = {}
    for instance in pairs(EventInstances[eventKey] or {}) do
        local record = WatchedInstances[instance]
        if not record then continue end
        if record.Matches[eventKey] then
            local locationText
            if record.Source == "workspace" then
                local islandName = getGoblinIsland(instance)
                local position = getModelPosition(instance)
                if position then
                    locationText = string.format("%s (X %.0f, Y %.0f, Z %.0f)", islandName, position.X, position.Y, position.Z)
                else
                    locationText = islandName
                end
            elseif record.Source == "gui" then
                local islandName = findIslandName(record.Text)
                if islandName then locationText = islandName end
            end
            if locationText then
                found[locationText] = true
            end
        end
    end

    local names = {}
    for name in pairs(found) do table.insert(names, name) end
    table.sort(names)
    if #names == 0 then return nil end
    local shown = {}
    for index = 1, math.min(#names, 3) do
        table.insert(shown, names[index])
    end
    if #names > 3 then
        table.insert(shown, string.format("+%d more", #names - 3))
    end
    return table.concat(shown, "; ")
end

local function hasAnnouncementContext(value)
    local normalized = normalizeEventText(value)
    local contextTerms = {
        "begun", "begin", "started", "start", "spotted", "appeared",
        "spawned", "migration", "hunt", "event", "active", "weather",
        "sighting", "nearby", "seen", "summoned", "surfaced", "emerged",
        "tournament", "leaderboard",
    }

    for _, term in ipairs(contextTerms) do
        if string.find(normalized, term, 1, true) then
            return true
        end
    end

    return false
end

local function isGuiTreeVisible(instance)
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui then return false end

    local current = instance
    while current and current ~= playerGui do
        local visible = true
        pcall(function()
            if current:IsA("ScreenGui") then
                visible = current.Enabled
            elseif current:IsA("GuiObject") then
                visible = current.Visible
            end
        end)
        if not visible then return false end
        current = current.Parent
    end
    return current == playerGui
end

local function isAnnouncementScope(instance)
    local scopeTerms = {
        "announcement", "notification", "event", "weather", "servernotice",
        "systemmessage", "alert", "banner", "globalmessage", "toast",
    }
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local current = instance.Parent
    while current and current ~= playerGui do
        local normalized = normalizeEventText(current.Name)
        for _, term in ipairs(scopeTerms) do
            if string.find(normalized, term, 1, true) then
                return true
            end
        end
        current = current.Parent
    end
    return false
end

local function changeEventCounts(matches, amount, instance)
    for key in pairs(matches) do
        EventCounts[key] = math.max(0, (EventCounts[key] or 0) + amount)
        if instance then
            local members = EventInstances[key]
            if not members then
                members = setmetatable({}, { __mode = "k" })
                EventInstances[key] = members
            end
            members[instance] = amount > 0 and true or nil
        end
    end
end

local function looksLikeEventNotice(value)
    local normalized = normalizeEventText(value)
    local terms = {
        "event", "hunt", "migration", "abundance", "spawn", "appeared",
        "weather", "storm", "shark", "whale", "kraken", "boss", "chest",
        "whirlpool", "merchant", "lanternkeeper", "nuke", "pool", "fish",
    }
    for _, term in ipairs(terms) do
        if string.find(normalized, term, 1, true) then return true end
    end
    return false
end

local function looksLikeEventModel(value)
    local normalized = normalizeEventText(value)
    local terms = {
        "event", "hunt", "migration", "abundance", "boss", "pool", "shark",
        "whale", "kraken", "scylla", "nuke", "whirlpool", "merchant", "meteor",
        "avalanche", "storm", "tide", "spawn", "leviathan",
    }
    for _, term in ipairs(terms) do
        if string.find(normalized, term, 1, true) then return true end
    end
    return false
end

local function updateGuiRecord(instance, record)
    local text = ""
    pcall(function()
        text = instance.Text
    end)
    text = tostring(text or "")
    local visible = isGuiTreeVisible(instance)
    if record.InputText == text and record.Visible == visible then return end
    record.InputText, record.Visible = text, visible
    changeEventCounts(record.Matches, -1, instance)
    record.Matches = {}
    record.UnknownNotice = nil
    UnknownEventInstances[instance] = nil
    record.Text = text
    if not visible then return end

    local eventText = text
    local matches = findEventMatches(eventText)
    local hasKnownEvent = next(matches) ~= nil
    local hasContext = hasAnnouncementContext(eventText)

    -- Some server banners split the event name and its status across several
    -- labels. Combine nearby visible text only for announcement-like entries.
    if not hasKnownEvent and (hasContext or record.AnnouncementScope) then
        local ancestor = instance.Parent
        local depth = 0
        while ancestor and ancestor ~= LocalPlayer:FindFirstChildOfClass("PlayerGui") and depth < 2 do
            local fragments = {}
            local count = 0
            local pending = ancestor:GetChildren()
            local cursor = 1
            local visited = 0
            while cursor <= #pending and visited < 48 and count <= 24 do
                local descendant = pending[cursor]
                cursor = cursor + 1
                visited = visited + 1
                if descendant:IsA("TextLabel") or descendant:IsA("TextButton") or descendant:IsA("TextBox") then
                    if isGuiTreeVisible(descendant) then
                        local textOK, fragment = pcall(function() return descendant.Text end)
                        if textOK and fragment ~= "" then
                            count = count + 1
                            if count > 24 then break end
                            table.insert(fragments, tostring(fragment))
                        end
                    end
                else
                    for _, child in ipairs(descendant:GetChildren()) do
                        table.insert(pending, child)
                    end
                end
            end
            if count > 1 and count <= 24 then
                local combinedText = table.concat(fragments, " ")
                local combinedMatches = findEventMatches(combinedText)
                if next(combinedMatches) then
                    eventText = combinedText
                    matches = combinedMatches
                    hasKnownEvent = true
                    hasContext = hasAnnouncementContext(combinedText)
                    break
                end
            end
            ancestor = ancestor.Parent
            depth = depth + 1
        end
    end

    record.Text = eventText
    if hasContext or hasKnownEvent then
        record.Matches = matches
        changeEventCounts(record.Matches, 1, instance)
        if not hasKnownEvent and hasContext and looksLikeEventNotice(eventText) then
            local cleaned = tostring(eventText):gsub("%s+", " "):match("^%s*(.-)%s*$")
            if #cleaned > 3 and #cleaned <= 180 then
                record.UnknownNotice = cleaned
                UnknownEventInstances[instance] = true
            end
        end
    end
end

local function connectGuiVisibility(instance, record)
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local current = instance
    record.VisibilityBranches = {}

    while current and current ~= playerGui do
        local propertyName
        if current:IsA("ScreenGui") then
            propertyName = "Enabled"
        elseif current:IsA("GuiObject") then
            propertyName = "Visible"
        end

        if propertyName then
            local branch = GuiVisibilityConnections[current]
            if not branch then
                branch = { Members = setmetatable({}, { __mode = "k" }) }
                branch.Connection = current:GetPropertyChangedSignal(propertyName):Connect(function()
                    if not MonitorRunning then return end
                    if branch.Queued then branch.Restart = true; return end
                    branch.Queued = true
                    VisibilityWork.Last = VisibilityWork.Last + 1
                    VisibilityWork[VisibilityWork.Last] = branch
                end)
                GuiVisibilityConnections[current] = branch
            end
            branch.Members[instance] = record
            table.insert(record.VisibilityBranches, { Instance = current, Branch = branch })
        end
        current = current.Parent
    end
end

local function updateAttributeEventCounts()
    local roots = { Lighting, Workspace, ReplicatedStorage, LocalPlayer }
    local signalAttributes = {
        weather = true,
        currentweather = true,
        weatherstatus = true,
        currentevent = true,
        activeevent = true,
        serverevent = true,
        serverboost = true,
    }

    for _, root in ipairs(roots) do
        local matches = {}
        local ok, attributes = pcall(function()
            return root:GetAttributes()
        end)
        if ok then
            for key, value in pairs(attributes) do
                local normalizedKey = normalizeEventText(key)
                if signalAttributes[normalizedKey] then
                    local detected = findEventMatches(tostring(key) .. " " .. tostring(value))
                    for eventKey in pairs(detected) do
                        matches[eventKey] = true
                    end
                end
            end
        end

        changeEventCounts(AttributeMatches[root] or {}, -1)
        AttributeMatches[root] = matches
        changeEventCounts(matches, 1)
    end
end

local function watchInstance(instance, source)
    if WatchedInstances[instance] then return end

    if source == "workspace" then
        local isModel = instance:IsA("Model")
        local isFolder = instance:IsA("Folder")
        local isPart = instance:IsA("BasePart")
        if not (isModel or isFolder or isPart) then return end

        if isModel then
            local islandName = findIslandName(instance.Name)
            if islandName then
                LocationModels[instance] = islandName
            end
        end

        local matches = findEventMatches(instance.Name, "workspace")
        local unknownEventModel = isModel and looksLikeEventModel(instance.Name)
        if next(matches) == nil and not unknownEventModel then return end

        -- Equipped fish and inventory models are not active world spawns.
        if instance:FindFirstAncestorOfClass("Tool") then return end
        local ancestor = instance
        while ancestor and ancestor ~= Workspace do
            if ancestor:IsA("Model") and Players:GetPlayerFromCharacter(ancestor) then return end
            ancestor = ancestor.Parent
        end

        if next(matches) == nil then
            if unknownEventModel then
                WatchedInstances[instance] = {
                    Source = source,
                    Matches = {},
                    UnknownNotice = tostring(instance.Name),
                }
                UnknownEventInstances[instance] = true
            end
            return
        end

        WatchedInstances[instance] = {
            Source = source,
            Matches = matches,
        }
        changeEventCounts(matches, 1, instance)
        return
    end

    if not (instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox")) then
        return
    end

    -- Reading our own event output would keep the same event active forever.
    local ancestor = instance
    while ancestor and ancestor ~= LocalPlayer:FindFirstChildOfClass("PlayerGui") do
        local key = normalizeEventText(ancestor.Name)
        if string.find(key, "windui", 1, true) or string.find(key, "bootlean", 1, true) then return end
        ancestor = ancestor.Parent
    end

    local record = {
        Source = source,
        Matches = {},
        AnnouncementScope = isAnnouncementScope(instance),
    }
    WatchedInstances[instance] = record
    queueGuiRecord(instance, record)
    record.TextConnection = instance:GetPropertyChangedSignal("Text"):Connect(function()
        queueGuiRecord(instance, record)
    end)
    connectGuiVisibility(instance, record)
end

local function unwatchInstance(instance)
    LocationModels[instance] = nil
    IslandCache[instance] = nil
    local record = WatchedInstances[instance]
    if not record then return end

    changeEventCounts(record.Matches, -1, instance)
    UnknownEventInstances[instance] = nil
    if record.TextConnection then
        record.TextConnection:Disconnect()
    end
    for _, membership in ipairs(record.VisibilityBranches or {}) do
        local branch = membership.Branch
        branch.Members[instance] = nil
        if not next(branch.Members) then
            branch.Connection:Disconnect()
            GuiVisibilityConnections[membership.Instance] = nil
        end
    end
    WatchedInstances[instance] = nil
end

local function watchContainer(container, source)
    table.insert(MonitorConnections, container.DescendantAdded:Connect(function(instance)
        enqueueWatch(instance, source, false)
    end))
    table.insert(MonitorConnections, container.DescendantRemoving:Connect(function(instance)
        PendingWatches[instance] = nil
        unwatchInstance(instance)
    end))
    enqueueWatch(container, source, true)
end

local function processMonitorWork()
    local deadline = os.clock() + 0.0004
    local processed = 0
    while WatchWork.First <= WatchWork.Last and processed < 64 and os.clock() < deadline do
        local work = WatchWork[WatchWork.First]
        WatchWork[WatchWork.First] = nil
        WatchWork.First = WatchWork.First + 1
        local instance = work.Instance
        if PendingWatches[instance] == work then
            PendingWatches[instance] = nil
            if instance.Parent or instance == Workspace then
                watchInstance(instance, work.Source)
                if work.Recursive then
                    for _, child in ipairs(instance:GetChildren()) do enqueueWatch(child, work.Source, true) end
                end
            end
        end
        processed = processed + 1
    end
    if WatchWork.First > WatchWork.Last then WatchWork.First, WatchWork.Last = 1, 0 end

    -- Visibility signals enqueue only their affected branch, not the whole GUI.
    -- Walk branch members incrementally so even a large menu toggle stays cheap.
    processed = 0
    deadline = os.clock() + 0.0003
    while VisibilityWork.First <= VisibilityWork.Last and processed < 64 and os.clock() < deadline do
        local branch = VisibilityWork[VisibilityWork.First]
        if branch.Cursor and not branch.Members[branch.Cursor] then branch.Cursor = nil end
        local instance, record = next(branch.Members, branch.Cursor)
        if instance then
            branch.Cursor = instance
            queueGuiRecord(instance, record)
        elseif branch.Restart then
            branch.Restart, branch.Cursor = nil, nil
        else
            branch.Queued, branch.Cursor = nil, nil
            VisibilityWork[VisibilityWork.First] = nil
            VisibilityWork.First = VisibilityWork.First + 1
        end
        processed = processed + 1
    end
    if VisibilityWork.First > VisibilityWork.Last then VisibilityWork.First, VisibilityWork.Last = 1, 0 end

    processed = 0
    deadline = os.clock() + 0.0005
    while GuiWork.First <= GuiWork.Last and processed < 16 and os.clock() < deadline do
        local work = GuiWork[GuiWork.First]
        GuiWork[GuiWork.First] = nil
        GuiWork.First = GuiWork.First + 1
        work.Record.Queued = false
        if work.Instance.Parent and WatchedInstances[work.Instance] == work.Record then
            updateGuiRecord(work.Instance, work.Record)
        end
        processed = processed + 1
    end
    if GuiWork.First > GuiWork.Last then GuiWork.First, GuiWork.Last = 1, 0 end
end

local function formatDuration(totalSeconds)
    totalSeconds = math.max(0, math.floor(tonumber(totalSeconds) or 0))
    local days = math.floor(totalSeconds / 86400)
    local hours = math.floor((totalSeconds % 86400) / 3600)
    local minutes = math.floor((totalSeconds % 3600) / 60)
    local seconds = totalSeconds % 60

    if days > 0 then
        return string.format("%dd %02d:%02d:%02d", days, hours, minutes, seconds)
    end
    return string.format("%02d:%02d:%02d", hours, minutes, seconds)
end

local function formatGameClock(clockTime)
    local hours = math.floor(clockTime) % 24
    local minutes = math.floor((clockTime % 1) * 60)
    return string.format("%02d:%02d", hours, minutes)
end

local function getEventStatus(eventInfo)
    if eventInfo.Key == "goblins" then
        local goblins = Runtime.GetGoblins()
        if #goblins == 0 then return nil end
        local islands, seen = {}, {}
        for _, target in ipairs(goblins) do
            if not seen[target.Island] then seen[target.Island] = true; table.insert(islands, target.Island) end
        end
        table.sort(islands)
        return "Goblins — " .. tostring(#goblins) .. " available — " .. table.concat(islands, ", ")
    end
    if (EventCounts[eventInfo.Key] or 0) > 0 then
        if eventInfo.Group == "world" then
            local islands = getEventIslandList(eventInfo.Key)
            if islands then
                return eventInfo.Title .. " — Active — " .. islands
            end
        end
        return eventInfo.Title .. " — Active"
    end
    return nil
end

local EventCards = {}
local function eventTargets(eventInfo)
    if eventInfo.Key == "goblins" then return Runtime.GetGoblins() end
    local targets, seen = {}, {}
    for instance in pairs(EventInstances[eventInfo.Key] or {}) do
        local record = WatchedInstances[instance]
        if record and record.Source == "workspace" and instance.Parent then
            local position = getModelPosition(instance)
            if position then
                local key = string.format("%.0f/%.0f/%.0f", position.X / 12, position.Y / 12, position.Z / 12)
                if not seen[key] then
                    seen[key] = true
                    local island = getGoblinIsland(instance)
                    if island == "Unknown island" and Runtime.FindNearestIsland then
                        local nearest = Runtime.FindNearestIsland(position)
                        if nearest then island = "Near " .. nearest end
                    end
                    table.insert(targets, { Key = eventInfo.Key, Title = eventInfo.Title, Group = eventInfo.Group, Island = island, Position = position, Instance = instance, Confirmed = true })
                    if #targets >= 4 then break end
                end
            end
        end
    end
    if #targets == 0 then
        for instance in pairs(EventInstances[eventInfo.Key] or {}) do
            local record = WatchedInstances[instance]
            local island = record and record.Source == "gui" and findIslandName(record.Text)
            local position = island and Runtime.ResolveIslandPosition and Runtime.ResolveIslandPosition(island)
            if position then
                table.insert(targets, { Key = eventInfo.Key, Title = eventInfo.Title, Group = eventInfo.Group, Island = island .. " (announced area)", Position = position, Confirmed = false })
                break
            end
        end
    end
    return targets
end

local function refreshEventCards()
    local targets = {}
    local created = 0
    for _, eventInfo in ipairs(EventDefinitions) do
        if eventInfo.Group == "world" or eventInfo.Group == "seasonal" then
            for _, target in ipairs(eventTargets(eventInfo)) do table.insert(targets, target) end
        end
    end
    table.sort(targets, function(a, b)
        if a.Title == b.Title then return a.Island < b.Island end
        return a.Title < b.Title
    end)
    Runtime.EventTargets = targets
    local filtered = {}
    for _, target in ipairs(targets) do
        local category = EventView.Category
        local matches = category == "All" or (category == "Goblins" and target.Key == "goblins")
            or (category == "World / Boss" and target.Group == "world") or (category == "Seasonal" and target.Group == "seasonal")
        local search = (target.Title .. " " .. target.Island):lower()
        if matches and (not EventView.ConfirmedOnly or target.Confirmed) and (EventView.Search == "" or search:find(EventView.Search, 1, true)) then table.insert(filtered, target) end
    end
    targets = filtered
    for index = 1, math.min(#targets, 20) do
        local target = targets[index]
        local card = EventCards[index]
        if not card then
            if created >= 2 then continue end
            created = created + 1
            card = {}
            EventCards[index] = card
            local currentCard = card
            card.Paragraph = EventsTab:Paragraph({
                Title = target.Title, Desc = target.Island, Image = "map-pin", ImageSize = 18,
                Buttons = {{ Title = "Teleport", Icon = "navigation", Callback = function()
                    local selected = currentCard.Target
                    if not selected or not Runtime.TeleportTo then return end
                    if selected.Key == "goblins" then
                        local live = selected.Instance and liveGoblinTarget(selected.Instance)
                        if not live then currentCard.Paragraph:SetDesc("Goblin is no longer available."); return end
                        selected = live
                    elseif selected.Instance and not selected.Instance.Parent then
                        currentCard.Paragraph:SetDesc("Event is no longer loaded."); return
                    end
                    local moved, reason = Runtime.TeleportTo(selected.Title, selected.Position)
                    if not moved then
                        pcall(function() WindUI:Notify({ Title = selected.Title, Content = tostring(reason or "No clear land at this event."), Duration = 4 }) end)
                    end
                end }},
            })
        end
        card.Target = target
        local title = target.Title .. (target.Key == "goblins" and " — NPC available" or target.Confirmed and " — Active" or " — Announced")
        if card.Title ~= title then card.Title = title; pcall(function() card.Paragraph:SetTitle(title) end) end
        local text = target.Island .. string.format("\nX %.0f   Y %.0f   Z %.0f", target.Position.X, target.Position.Y, target.Position.Z)
        setParagraphText(card.Paragraph, text)
        pcall(function() card.Paragraph.ParagraphFrame.UIElements.Main.Visible = true end)
    end
    for index = #targets + 1, #EventCards do
        EventCards[index].Target = nil
        pcall(function() EventCards[index].Paragraph.ParagraphFrame.UIElements.Main.Visible = false end)
    end
end

local function refreshEventMonitor()
    updateAttributeEventCounts()
    refreshEventCards()

    local groupLines = {
        weather = {},
        world = {},
        boosts = {},
        seasonal = {},
    }
    local unknownNoticeSet = {}

    for _, eventInfo in ipairs(EventDefinitions) do
        local line = getEventStatus(eventInfo)
        if line and groupLines[eventInfo.Group] then
            table.insert(groupLines[eventInfo.Group], line)
        end
    end

    for instance in pairs(UnknownEventInstances) do
        local record = WatchedInstances[instance]
        if not record then continue end
        if record.UnknownNotice then
            local notice = record.UnknownNotice
            if record.Source == "workspace" then
                local position = getModelPosition(instance)
                local islandName = getGoblinIsland(instance)
                if position then
                    notice = string.format("%s — %s (X %.0f, Y %.0f, Z %.0f)", notice, islandName, position.X, position.Y, position.Z)
                end
            end
            unknownNoticeSet[notice] = true
        end
    end
    local unknownNotices = {}
    for notice in pairs(unknownNoticeSet) do table.insert(unknownNotices, notice) end
    table.sort(unknownNotices)
    while #unknownNotices > 8 do table.remove(unknownNotices) end

    local function linesOrNone(lines)
        return #lines > 0 and table.concat(lines, "\n") or "None"
    end

    setParagraphText(WeatherParagraph, linesOrNone(groupLines.weather))
    setParagraphText(WorldBossParagraph, linesOrNone(groupLines.world))
    setParagraphText(BoostAdminParagraph, linesOrNone(groupLines.boosts))
    setParagraphText(SeasonalParagraph, linesOrNone(groupLines.seasonal))
    setParagraphText(OtherEventParagraph, linesOrNone(unknownNotices))

    local jobId = tostring(game.JobId or "")
    if jobId == "" then
        jobId = "Unavailable"
    end

    local playerCount = #Players:GetPlayers()
    local maxPlayers = "?"
    pcall(function()
        maxPlayers = tostring(Players.MaxPlayers)
    end)

    local sessionSeconds = 0
    pcall(function()
        sessionSeconds = Workspace.DistributedGameTime
    end)

    local gameClock = 0
    pcall(function()
        gameClock = Lighting.ClockTime
    end)

    setParagraphText(ServerInfoParagraph, table.concat({
        "Server ID: " .. jobId,
        "Place ID: " .. tostring(game.PlaceId),
        "Players: " .. tostring(playerCount) .. " / " .. maxPlayers,
        "In-game time: " .. formatGameClock(gameClock),
        "Connected for: " .. formatDuration(sessionSeconds),
        "Server uptime: unavailable to the client.",
    }, "\n"))
end

local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui")
task.spawn(function()
    watchContainer(Workspace, "workspace")
end)
task.spawn(function()
    watchContainer(PlayerGui, "gui")
end)

onCleanup(function()
    MonitorRunning = false
    Runtime.GetGoblins = nil
    Runtime.EventTargets = {}
    AutoShakeHookRunning = false
    Config.Enabled = false
    CastPendingAt = 0
    for _, connection in ipairs(GameWindowFocusConnections) do
        pcall(function() connection:Disconnect() end)
    end
    for _, connection in ipairs(MonitorConnections) do
        connection:Disconnect()
    end
    for _, branch in pairs(GuiVisibilityConnections) do branch.Connection:Disconnect() end
    for instance, record in pairs(WatchedInstances) do
        if record.TextConnection then
            record.TextConnection:Disconnect()
        end
        WatchedInstances[instance] = nil
    end
    table.clear(GuiWork)
    table.clear(VisibilityWork)
    table.clear(WatchWork)
    table.clear(PendingWatches)
end)

task.spawn(function()
    local nextRefresh = 0
    while MonitorRunning do
        pcall(processMonitorWork)
        if os.clock() >= nextRefresh then
            pcall(refreshEventMonitor)
            nextRefresh = os.clock() + 1
        end
        task.wait(0.05)
    end
end)

end
do
ShopTab:Section({
    Title = "Shops",
})

local ShopDefinitions = {
    { Title = "Daily Shop", Terms = { "dailyshop", "dailyshopui" }, TextTerms = { "dailyshop" } },
    { Title = "Boat Shop", Terms = { "boatshop", "boatstore", "shipwright", "boatdealer" }, TextTerms = { "boatshop", "shipwright" } },
}

local function shopNameMatches(value, terms)
    local normalized = normalizeEventText(value)
    for _, term in ipairs(terms) do
        if normalized == term or string.find(normalized, term, 1, true) then
            return true
        end
    end
    return false
end

local function shopScreenNameMatches(value, terms)
    local normalized = normalizeEventText(value)
    for _, term in ipairs(terms) do
        if normalized == term then return true end
    end
    return false
end

local function shopTitleTextMatches(value, terms)
    local normalized = normalizeEventText(value)
    for _, term in ipairs(terms or {}) do
        if normalized == term then return true end
    end
    return false
end

local function hasBlockedShopAncestor(instance, screenGui)
    local blockedTerms = { "admin", "event", "announcement", "notification", "popup", "dialog" }
    local current = instance
    while current do
        local normalized = normalizeEventText(current.Name)
        for _, term in ipairs(blockedTerms) do
            if string.find(normalized, term, 1, true) then return true end
        end
        if current == screenGui then break end
        current = current.Parent
    end
    return false
end

local function openExistingShopUI(shopInfo)
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui then return false end

    for _, screenGui in ipairs(playerGui:GetChildren()) do
        if screenGui:IsA("ScreenGui") and not shopNameMatches(screenGui.Name, { "windui", "bootlean" }) then
            local matchedScreen = shopScreenNameMatches(screenGui.Name, shopInfo.Terms)
                and not hasBlockedShopAncestor(screenGui, screenGui)
            local target

            if not hasBlockedShopAncestor(screenGui, screenGui) then
                for _, descendant in ipairs(screenGui:GetDescendants()) do
                    if descendant:IsA("GuiObject")
                        and shopNameMatches(descendant.Name, shopInfo.Terms)
                        and not hasBlockedShopAncestor(descendant, screenGui) then
                        target = descendant
                        break
                    end
                end

                if not target then
                    for _, descendant in ipairs(screenGui:GetDescendants()) do
                        if (descendant:IsA("TextLabel") or descendant:IsA("TextButton") or descendant:IsA("TextBox"))
                            and not hasBlockedShopAncestor(descendant, screenGui) then
                            local text = ""
                            pcall(function() text = descendant.Text end)
                            if shopTitleTextMatches(text, shopInfo.TextTerms) then
                                local panel = descendant.Parent
                                local candidate
                                while panel and panel ~= screenGui do
                                    if panel:IsA("GuiObject") and panel.AbsoluteSize.X >= 180 and panel.AbsoluteSize.Y >= 120 then
                                        candidate = panel
                                    end
                                    panel = panel.Parent
                                end
                                target = candidate or (descendant.Parent and descendant.Parent:IsA("GuiObject") and descendant.Parent)
                                if target then break end
                            end
                        end
                    end
                end
            end

            if target or matchedScreen then
                -- Match an exact shop title or a specifically named shop panel.
                pcall(function()
                    screenGui.Enabled = true
                end)
                local node = target
                while node and node ~= screenGui do
                    pcall(function()
                        node.Visible = true
                    end)
                    node = node.Parent
                end
                return true
            end
        end
    end

    return false
end

Runtime.OpenBoatShop = function() return openExistingShopUI(ShopDefinitions[2]) end
onCleanup(function() Runtime.OpenBoatShop = nil end)
for _, shopInfo in ipairs(ShopDefinitions) do
    local currentShop = shopInfo
    ShopTab:Button({
        Title = currentShop.Title,
        Icon = "store",
        Callback = function()
            if openExistingShopUI(currentShop) then
                WindUI:Notify({
                    Title = currentShop.Title,
                    Content = "Opened the menu already loaded by the game.",
                    Duration = 3,
                })
            else
                WindUI:Notify({
                    Title = currentShop.Title,
                    Content = "No matching local shop panel is loaded. Open it through normal in-game interaction first.",
                    Duration = 5,
                })
            end
        end,
    })
end

end

local AquariumGoalDropdown, AquariumReminderToggle
do
AquariumTab:Section({ Title = "Aquarium" })
local AquariumStatus = AquariumTab:Paragraph({ Title = "Aquarium Status", Desc = "Checking access...", Image = "fish", ImageSize = 18 })
local function aquariumLevel()
    if Runtime.ReadPlayerStat then
        local level = Runtime.ReadPlayerStat({ "Level", "level" })
        if level then return level end
    end
    for _, key in ipairs({ "Level", "level" }) do
        local value = tonumber(LocalPlayer:GetAttribute(key))
        if value then return value end
    end
    for _, folderName in ipairs({ "leaderstats", "stats" }) do
        local folder = LocalPlayer:FindFirstChild(folderName)
        local value = folder and (folder:FindFirstChild("Level") or folder:FindFirstChild("level"))
        if value then local ok, level = pcall(function() return tonumber(value.Value) end); if ok and level then return level end end
    end
    return nil
end
local function aquariumAccess()
    local level = aquariumLevel()
    if level and level < 25 then
        AquariumStatus:SetDesc("Locked — unlocks at level 25. Current level: " .. tostring(level))
        return false
    end
    AquariumStatus:SetDesc(level and ("Unlocked — level " .. tostring(level)) or "Access unknown — requires level 25. Open the in-game Aquarium menu.")
    return true
end
aquariumAccess()
local AquariumPlanParagraph = AquariumTab:Paragraph({
    Title = "Recommended focus",
    Desc = "",
    Image = "sparkles",
    ImageSize = 18,
})

local AquariumGoalDetails = {
    Items = "Item drops — ranks distinct fish by their known item-drop rate.",
    XP = "Experience — ranks inventory fish with a known base XP value. Unknown values are excluded.",
    Cash = "Money — ranks readable inventory values; base-price estimates are labelled. Aquarium yield may differ.",
}

local AquariumSelectionParagraph
local AquariumRanked = {}
local AquariumFishLibrary = { Loaded = false, Data = {} }
local function aquariumNormalizeText(value)
    return string.lower(tostring(value or "")):gsub("[^%w]", "")
end

local AquariumItemRatesByRarity = {
    trash = 1, common = 2, uncommon = 2, unusual = 3, rare = 3,
    legendary = 5, mythical = 6, exotic = 7, secret = 5, limited = 5,
    gemstone = 8, relic = 9, fragment = 10, apex = 3, special = 4,
    divinesecret = 12,
}
local function aquariumMetadataKey(key, value, metadata)
    local normalizedKey = aquariumNormalizeText(key)
    if normalizedKey == "rarity" or normalizedKey == "fishrarity" then
        metadata.Rarity = tostring(value)
        metadata.IsFish = true
    elseif normalizedKey == "fishname" or normalizedKey == "fishid" or normalizedKey == "species" then
        if type(value) == "string" then metadata.Name = value end
        metadata.IsFish = true
    elseif normalizedKey == "basexp" or normalizedKey == "fishxp" or normalizedKey == "experience" or normalizedKey == "baseexperience" or normalizedKey == "xp" then
        metadata.XP = tonumber(value) or metadata.XP
        metadata.IsFish = true
    elseif normalizedKey == "sellprice" or normalizedKey == "sellvalue" or normalizedKey == "fishvalue" or normalizedKey == "fishprice" or normalizedKey == "basevalue" or normalizedKey == "value" or normalizedKey == "price" then
        metadata.Cash = tonumber(value) or metadata.Cash
        metadata.IsFish = true
    elseif normalizedKey == "itemsperhour" or normalizedKey == "itemrate" or normalizedKey == "aquariumitemrate" then
        metadata.Items = tonumber(value) or metadata.Items
        metadata.IsFish = true
    elseif normalizedKey == "weight" or normalizedKey == "fishweight" then
        metadata.Weight = tonumber(value) or metadata.Weight
        metadata.IsFish = true
    end
end

local function readAquariumFishMetadata(tool)
    local metadata = { Name = tool.Name, IsFish = false }
    local function inspect(instance)
        local ok, attributes = pcall(function() return instance:GetAttributes() end)
        if ok then
            for key, value in pairs(attributes) do
                aquariumMetadataKey(key, value, metadata)
            end
        end
        if instance:IsA("ValueBase") then
            pcall(function() aquariumMetadataKey(instance.Name, instance.Value, metadata) end)
        end
    end

    inspect(tool)
    for _, descendant in ipairs(tool:GetDescendants()) do
        inspect(descendant)
    end
    return metadata
end

local function loadAquariumFishLibrary()
    if AquariumFishLibrary.Loaded then return end
    AquariumFishLibrary.Loaded = true
    local shared = ReplicatedStorage:FindFirstChild("shared") or ReplicatedStorage:FindFirstChild("Shared")
    local modules = shared and (shared:FindFirstChild("modules") or shared:FindFirstChild("Modules"))
    local library = modules and (modules:FindFirstChild("library") or modules:FindFirstChild("Library"))
    local module = library and (library:FindFirstChild("fish") or library:FindFirstChild("Fish"))
    if not module or not module:IsA("ModuleScript") then return end
    local done = false
    local worker = task.spawn(function()
        local ok, data = pcall(require, module)
        if ok and type(data) == "table" then AquariumFishLibrary.Data = data.Fish or data.Fishes or data end
        done = true
    end)
    local deadline = os.clock() + 2
    while not done and os.clock() < deadline and not Runtime.Closed do task.wait(0.05) end
    if not done then pcall(task.cancel, worker) end
end

local function completeAquariumMetadata(metadata)
    local definition = AquariumFishLibrary.Data[metadata.Name]
    if type(definition) ~= "table" then
        local wanted = aquariumNormalizeText(metadata.Name)
        for name, data in pairs(AquariumFishLibrary.Data) do
            if type(name) == "string" and type(data) == "table" and aquariumNormalizeText(name) == wanted then definition = data; break end
        end
    end
    if type(definition) == "table" then
        metadata.Rarity = metadata.Rarity or definition.Rarity
        metadata.XP = metadata.XP or tonumber(definition.XP or definition.Experience)
        if not metadata.Cash and tonumber(definition.Price) then
            metadata.Cash = tonumber(definition.Price)
            metadata.BaseCashOnly = true
        end
        metadata.IsFish = true
    end
    return metadata
end

local function selectBestAquariumFish()
    if not aquariumAccess() then return end
    loadAquariumFishLibrary()
    local inventory = {}
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    local character = LocalPlayer.Character
    for _, container in pairs({ backpack, character }) do
        if container then
            for _, item in ipairs(container:GetChildren()) do
                if item:IsA("Tool") and not isRod(item) then
                    local metadata = completeAquariumMetadata(readAquariumFishMetadata(item))
                    if metadata.IsFish then
                        local score
                        local detail
                        local approximate = false
                        if AquariumGoal == "Items" then
                            score = metadata.Items or AquariumItemRatesByRarity[aquariumNormalizeText(metadata.Rarity)]
                            detail = score and string.format("%g items/hr", score)
                        elseif AquariumGoal == "XP" then
                            score = metadata.XP
                            detail = score and string.format("%g base XP", score)
                        else
                            score = metadata.Cash
                            approximate = metadata.BaseCashOnly == true
                            detail = score and (approximate and string.format("%g base price (before size/mutations)", score) or string.format("%g value", score))
                        end
                        if score and score > 0 then
                            local key = aquariumNormalizeText(metadata.Name)
                            local candidate = { Name = metadata.Name, Score = score, Detail = detail, Rarity = metadata.Rarity, Tool = item, Approximate = approximate }
                            if not inventory[key] or candidate.Score > inventory[key].Score then
                                inventory[key] = candidate
                            end
                        end
                    end
                end
            end
        end
    end

    local ranked = {}
    for _, candidate in pairs(inventory) do table.insert(ranked, candidate) end
    table.sort(ranked, function(a, b)
        if a.Approximate ~= b.Approximate then return not a.Approximate end
        if a.Score == b.Score then return a.Name < b.Name end
        return a.Score > b.Score
    end)
    AquariumRanked = ranked

    if #ranked == 0 then
        AquariumSelectionParagraph:SetDesc("No readable " .. AquariumGoal .. " data. Open the Aquarium menu and equip a fish once, then retry.")
        return
    end

    local selected = ranked[1]
    local equipped = selected.Tool.Parent == character
    if not equipped and character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            pcall(function() humanoid:EquipTool(selected.Tool) end)
            equipped = selected.Tool.Parent == character
        end
    end

    local lines = {}
    table.insert(lines, string.format("Selected: %s — %s", selected.Name, equipped and "equipped" or "equip manually"))
    for index = 1, math.min(#ranked, 10) do
        local candidate = ranked[index]
        local suffix = candidate.Rarity and (" — " .. candidate.Rarity) or ""
        table.insert(lines, string.format("%d. %s — %s%s", index, candidate.Name, candidate.Detail, suffix))
    end
    if #ranked > 10 then
        table.insert(lines, string.format("+%d more", #ranked - 10))
    end
    AquariumSelectionParagraph:SetDesc(table.concat(lines, "\n"))
    pcall(function()
        WindUI:Notify({
            Title = "Aquarium",
            Content = equipped and (selected.Name .. " selected for " .. AquariumGoal .. ". Click an empty aquarium slot to add it.") or ("Best match: " .. selected.Name .. ". Equip it and click an empty aquarium slot."),
            Duration = 5,
        })
    end)
end
local function aquariumButtonEmpty(button)
    if button:GetAttribute("Occupied") == true then return false end
    if button:GetAttribute("Empty") == true or button:GetAttribute("Occupied") == false then return true end
    local text = ""
    pcall(function() text = button.Text end)
    text = tostring(text):lower():gsub("<[^>]->", ""):match("^%s*(.-)%s*$")
    return text == "empty" or text == "add fish" or text == "place fish"
end
local function fillAquariumSlots()
        if not aquariumAccess() then return end
        if Config.Enabled or Config.AutomationBusy then AquariumStatus:SetDesc("Stop Auto Fish and active routes before filling slots."); return end
        selectBestAquariumFish()
        if #AquariumRanked == 0 then return end
        local gui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local pending, cursor, slots = gui and gui:GetChildren() or {}, 1, {}
        while cursor <= #pending and cursor <= 6000 do
            local instance = pending[cursor]; cursor = cursor + 1
            if cursor % 120 == 0 then task.wait() end
            local ancestor, isAquarium, visible = instance, false, true
            while ancestor and ancestor ~= gui do
                if ancestor.Name:lower():find("aquarium", 1, true) then isAquarium = true end
                if ancestor.Name:lower():find("windui", 1, true) then isAquarium = false; break end
                if ancestor:IsA("GuiObject") and not ancestor.Visible then visible = false end
                if ancestor:IsA("ScreenGui") and not ancestor.Enabled then visible = false end
                ancestor = ancestor.Parent
            end
            if isAquarium and visible and instance:IsA("GuiButton") and aquariumButtonEmpty(instance) then table.insert(slots, instance) end
            if not instance:IsA("TextLabel") then for _, child in ipairs(instance:GetChildren()) do table.insert(pending, child) end end
        end
        if #slots == 0 then AquariumStatus:SetDesc("Open your Aquarium menu. No confirmed empty slots are visible."); return end
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end
        local filled = 0
        for index = 1, math.min(#slots, #AquariumRanked, 8) do
            if Runtime.Closed or LocalPlayer.Character ~= character or Config.Enabled then break end
            local candidate, slot = AquariumRanked[index], slots[index]
            if not candidate.Tool.Parent or not slot.Parent or not aquariumButtonEmpty(slot) then break end
            humanoid:EquipTool(candidate.Tool)
            task.wait(0.15)
            local activated = Runtime.ActivateGuiButton and Runtime.ActivateGuiButton(slot)
            if not activated then AquariumStatus:SetDesc("The slot has no usable button callback. The selected fish is equipped."); return end
            local deadline = os.clock() + 2
            while slot.Parent and aquariumButtonEmpty(slot) and os.clock() < deadline do task.wait(0.1) end
            if slot.Parent and aquariumButtonEmpty(slot) then AquariumStatus:SetDesc("The game did not confirm the slot change; stopped."); return end
            filled = filled + 1
        end
        AquariumStatus:SetDesc("Filled " .. tostring(filled) .. " empty slots.")
end
local function updateAquariumPlan()
    local goal = AquariumGoalDetails[AquariumGoal] and AquariumGoal or "Items"
    AquariumPlanParagraph:SetDesc(AquariumGoalDetails[goal])
end

AquariumTab:Section({ Title = "1. Choose Reward" })
AquariumGoalDropdown = AquariumTab:Dropdown({
    Title = "Reward goal",
    Values = { "Items", "XP", "Cash" },
    Value = AquariumGoal,
    Callback = function(value)
        if value ~= "Items" and value ~= "XP" and value ~= "Cash" then return end
        AquariumGoal = value
        updateAquariumPlan()
        saveLocalSettings()
    end,
})

AquariumTab:Section({ Title = "2. Rank Your Inventory" })
AquariumTab:Button({
    Title = "Select Best",
    Icon = "list-checks",
    Callback = function()
        local ok, err = pcall(selectBestAquariumFish)
        if not ok then
            pcall(function() AquariumSelectionParagraph:SetDesc("Selection failed: " .. tostring(err)) end)
            pcall(function() WindUI:Notify({ Title = "Aquarium", Content = "Could not select a fish. " .. tostring(err), Duration = 5 }) end)
        end
    end,
})

AquariumSelectionParagraph = AquariumTab:Paragraph({
    Title = "Best available fish",
    Desc = "",
    Image = "list-ordered",
    ImageSize = 18,
})
AquariumTab:Section({ Title = "3. Place Selected Fish" })
AquariumTab:Button({ Title = "Fill Empty Slots", Icon = "list-plus", Callback = function()
    if Config.AquariumBusy then return end
    Config.AquariumBusy = true
    local ok, err = pcall(fillAquariumSlots)
    Config.AquariumBusy = false
    if not ok then AquariumStatus:SetDesc("Slot filling stopped: " .. tostring(err):sub(1,160)) end
end })
AquariumReminderToggle = AquariumTab:Toggle({
    Title = "Hourly aquarium reminder",
    Value = AquariumReminder,
    Callback = function(value)
        AquariumReminder = value == true
        saveLocalSettings()
    end,
})

updateAquariumPlan()

local AquariumReminderRunning = true
onCleanup(function()
    AquariumReminderRunning = false
end)
task.spawn(function()
    local elapsed = 0
    while AquariumReminderRunning do
        if AquariumReminder then
            task.wait(60)
            if AquariumReminderRunning and AquariumReminder then
                elapsed = elapsed + 60
                if elapsed >= 3600 then
                    elapsed = 0
                    WindUI:Notify({
                        Title = "Aquarium",
                        Content = "Review your " .. AquariumGoal .. " focus and collect available rewards.",
                        Duration = 5,
                    })
                end
            else
                elapsed = 0
            end
        else
            elapsed = 0
            task.wait(5)
        end
    end
end)

end

SettingsTab:Section({
    Title = "Appearance",
})

local function getThemeNames()
    local names = {}
    local themes = WindUI:GetThemes()

    for _, name in ipairs({ "Dark", "Light" }) do
        if themes[name] then table.insert(names, name) end
    end

    table.sort(names)
    return names
end

local SelectedTheme = AppearanceState.Theme
local ThemeNames = getThemeNames()
local ThemeDropdown
local WaypointMarker
local refreshWaypoint

local function colorToHex(color)
    local ok, hex = pcall(function()
        return color:ToHex()
    end)
    if not ok or type(hex) ~= "string" then return AppearanceState.Accent end
    hex = hex:gsub("^#", "")
    if not hex:match("^%x%x%x%x%x%x$") then return AppearanceState.Accent end
    return "#" .. string.lower(hex)
end

local function applyCustomAccent(color, shouldSave)
    local customName = "Bootlean Fisch Accent"
    local themes = WindUI:GetThemes()
    local sourceTheme = themes[AppearanceState.Theme] or themes.Dark
    local customTheme = {}

    if type(sourceTheme) == "table" then
        for key, value in pairs(sourceTheme) do
            customTheme[key] = value
        end
    end

    customTheme.Name = customName
    customTheme.Accent = color
    customTheme.Button = color
    customTheme.Icon = color

    local ok = pcall(function()
        WindUI:AddTheme(customTheme)
        WindUI:SetTheme(customName)
    end)

    if ok then
        AppearanceState.Accent = colorToHex(color)
        if refreshWaypoint then refreshWaypoint() end
        if shouldSave ~= false then saveLocalSettings() end
    end
    return ok
end

ThemeDropdown = SettingsTab:Dropdown({
    Title = "Theme",
    Values = ThemeNames,
    Value = AppearanceState.Theme,
    Callback = function(themeName)
        SelectedTheme = tostring(themeName)
        AppearanceState.Theme = SelectedTheme
        pcall(function()
            WindUI:SetTheme(SelectedTheme)
        end)
        pcall(function()
            applyCustomAccent(Color3.fromHex(AppearanceState.Accent), false)
        end)
        saveLocalSettings()
    end,
})

local AccentColorPicker = SettingsTab:Colorpicker({
    Title = "Accent",
    Default = Color3.fromHex(AppearanceState.Accent),
    Callback = applyCustomAccent,
})

local AcrylicToggle = SettingsTab:Toggle({
    Title = "Background blur",
    Value = AppearanceState.Acrylic,
    Callback = function(enabled)
        AppearanceState.Acrylic = enabled == true
        pcall(function()
            WindUI:ToggleAcrylic(AppearanceState.Acrylic)
        end)
        saveLocalSettings()
    end,
})

local TransparencySlider = SettingsTab:Slider({
    Title = "Background transparency",
    Step = 0.05,
    Value = { Min = 0, Max = 0.3, Default = AppearanceState.Transparency },
    Callback = function(value)
        AppearanceState.Transparency = math.clamp(tonumber(value) or 0, 0, 0.3)
        pcall(function()
            Window:SetBackgroundTransparency(AppearanceState.Transparency)
        end)
        saveLocalSettings()
    end,
})

local function setWindowScale(scale)
    local setMethodOK, setMethod = pcall(function()
        return Window.SetUIScale
    end)
    if setMethodOK and type(setMethod) == "function" then
        local ok = pcall(function() Window:SetUIScale(scale) end)
        if ok then return true end
    end

    local screen = container:FindFirstChild("WindUI")
    if not screen then return false end
    for _, descendant in ipairs(screen:GetDescendants()) do
        if descendant:IsA("TextLabel") and string.find(descendant.Text, HUB_NAME, 1, true) then
            local root = descendant
            while root.Parent and root.Parent ~= screen do
                root = root.Parent
            end
            if root:IsA("GuiObject") then
                local uiScale = root:FindFirstChild("BootleanUIScale")
                if not uiScale then
                    uiScale = Instance.new("UIScale")
                    uiScale.Name = "BootleanUIScale"
                    uiScale.Parent = root
                end
                uiScale.Scale = scale
                return true
            end
        end
    end
    return false
end

local ScaleSlider = SettingsTab:Slider({
    Title = "Interface scale",
    Step = 0.05,
    Value = { Min = 0.7, Max = 1.15, Default = AppearanceState.Scale },
    Callback = function(value)
        AppearanceState.Scale = math.clamp(tonumber(value) or 0.8, 0.7, 1.15)
        setWindowScale(AppearanceState.Scale)
        saveLocalSettings()
    end,
})

SettingsTab:Section({ Title = "Controls" })
local function createWindowKeybind(initialValue)
    return SettingsTab:Keybind({
        Title = "Open / close GUI",
        Value = initialValue,
        Callback = function(value)
            if type(value) ~= "string" then return end
            local ok, keyCode = pcall(function()
                return Enum.KeyCode[value]
            end)
        if not ok or not keyCode or keyCode == Enum.KeyCode.Unknown then
                WindUI:Notify({ Title = "GUI Keybind", Content = "That key is not available.", Duration = 3 })
                return
            end
            local applied = pcall(function()
                Window:SetToggleKey(keyCode)
            end)
            if applied then
                ToggleKeyName = value
                saveLocalSettings()
            else
                WindUI:Notify({ Title = "GUI Keybind", Content = "WindUI could not update the toggle key.", Duration = 3 })
            end
        end,
    })
end
createWindowKeybind(ToggleKeyName)

SettingsTab:Section({ Title = "Local Account Config" })
SettingsTab:Button({
    Title = "Capture Aria diagnostics",
    Icon = "activity",
    Callback = function()
        if type(loadfile) ~= "function" then error("This executor does not provide loadfile.") end
        local diagnostic, err = loadfile("Aria-diagnostika.lua")
        if type(diagnostic) ~= "function" then error(tostring(err or "Aria-diagnostika.lua is missing from the executor workspace.")) end
        task.spawn(diagnostic)
        WindUI:Notify({ Title = "Aria diagnostic", Content = "Waiting for the next reel. The result will be saved locally.", Duration = 5 })
    end,
})
SettingsTab:Button({
    Title = "Reload local script",
    Icon = "refresh-cw",
    Callback = function()
        if type(loadfile) ~= "function" then error("This executor does not provide loadfile.") end
        local reload, err = loadfile("BootleanFisch-Rebuilt.lua")
        if type(reload) ~= "function" then error(tostring(err or "BootleanFisch-Rebuilt.lua is missing from the executor workspace.")) end
        task.defer(reload)
    end,
})
SettingsTab:Button({
    Title = "Copy Performance Diagnostics", Icon = "activity", Callback = function()
        local stats = Runtime.FrameStats or {}
        local visual = Runtime.GetVisualStats and Runtime.GetVisualStats() or {}
        local lines = {
            "Bootlean Fisch performance 2026-11-08c",
            string.format("Approx. FPS: %.1f | Worst frame: %.1f ms | Frames below45FPS: %d", stats.FPS or 0, stats.WorstMs or 0, stats.SlowFrames or 0),
            "Visual preset: " .. tostring(VisualState.Preset),
            "Fishing phase: " .. tostring(Config.FishingPhase or "Idle"),
        }
        for key, value in pairs(visual) do if type(value) == "number" or type(value) == "string" or type(value) == "boolean" then table.insert(lines, tostring(key) .. ": " .. tostring(value)) end end
        local text = table.concat(lines, "\n")
        local copied = type(setclipboard) == "function" and pcall(setclipboard, text)
        pcall(function() WindUI:Notify({ Title = "Performance", Content = copied and "Performance diagnostics copied." or text, Duration = 8 }) end)
    end,
})
SettingsTab:Button({
    Title = "Copy Fishing Diagnostics",
    Icon = "clipboard-copy",
    Callback = function()
        local rod = getEquippedRod()
        local lines = {
            "Bootlean Fisch 2026-11-08c",
            "Auto Fish: " .. tostring(Config.Enabled),
            "Auto Cast / Shake / Reel: " .. tostring(Config.AutoCast) .. " / " .. tostring(Config.AutoShake) .. " / " .. tostring(Config.AutoReel),
            "Phase: " .. tostring(Config.FishingPhase or "Idle"),
            "Last error: " .. tostring(Config.LastFishingError or "None"),
            "Rod equipped: " .. tostring(rod and rod.Name or "None"),
            "Bobber / Reel / Shake: " .. tostring(hasBobber(rod)) .. " / " .. tostring(ReelController.ActiveReel ~= nil) .. " / " .. tostring(getActiveShakeUI() ~= nil),
            "Focused: " .. tostring(GameWindowFocused),
            "GUI signals / connections: " .. tostring(type(firesignal) == "function") .. " / " .. tostring(type(getconnections) == "function"),
        }
        local copied = type(setclipboard) == "function" and pcall(setclipboard, table.concat(lines, "\n"))
        pcall(function() WindUI:Notify({ Title = "Fishing Diagnostics", Content = copied and "Diagnostics copied." or table.concat(lines, "\n"), Duration = 8 }) end)
    end,
})
local VisualPresetDropdown, PostFXToggle, WaypointToggle, NoFogToggle, SkyTintToggle
local SkyColorPicker, CatchNotificationsToggle
local BrightnessSlider, SaturationSlider, ContrastSlider, FOVSlider
local OriginalBrightness, OriginalFieldOfView, LocalColorCorrection
local applyNoFog, applySkyTint
CatchNotificationsToggle = SettingsTab:Toggle({
    Title = "Catch notifications",
    Value = Config.CatchNotifications,
    Callback = function(enabled)
        Config.CatchNotifications = enabled == true
        saveLocalSettings()
    end,
})
SettingsTab:Button({
    Title = "Save settings now",
    Icon = "save",
    Callback = function()
        local ok = saveLocalSettings()
        WindUI:Notify({
            Title = "Bootlean Fisch",
            Content = ok and ("Saved for Roblox UserId " .. tostring(LocalPlayer.UserId) .. ".")
                or "This executor cannot write local config files.",
            Duration = 4,
        })
    end,
})

SettingsTab:Button({
    Title = "Reset settings",
    Icon = "rotate-ccw",
    Callback = function()
        Config.FishingMode = nil
        setEnabled(false)
        Config.AutoCast = true
        Config.AutoShake = true
        Config.AutoReel = true
        Config.CatchNotifications = true
        Config.InstantBobber = true
        Config.Power = 100
        Config.PerfectCast = true
        Config.Delay = 1
        AppearanceState.Theme = "Dark"
        AppearanceState.Accent = "#72a6e6"
        AppearanceState.Acrylic = false
        AppearanceState.Transparency = 0
        AppearanceState.Scale = 0.8
        VisualState.Brightness = OriginalBrightness
        VisualState.Saturation = 0
        VisualState.Contrast = 0
        VisualState.FieldOfView = OriginalFieldOfView
        VisualState.Preset = "Balanced"
        VisualState.PostFX = true
        VisualState.NoFog = false
        SkyState.Enabled = false
        SkyState.Color = "#D7C6FF"
        AquariumGoal = "Items"
        AquariumReminder = false
        WaypointVisible = true
        if Runtime.ResetVisualOptions then pcall(Runtime.ResetVisualOptions) end
        if Runtime.ResetNotes then pcall(Runtime.ResetNotes) end
        pcall(function() applyNoFog(false) end)

        pcall(function() AutoCastToggle:Set(true) end)
        pcall(function() AutoShakeToggle:Set(true) end)
        pcall(function() AutoReelToggle:Set(true) end)
        pcall(function() CatchNotificationsToggle:Set(true) end)
        pcall(function() InstantBobberToggle:Set(true) end)
        pcall(function() CastPowerSlider:Set(100) end)
        pcall(function() PerfectCastToggle:Set(true) end)
        pcall(function() RecastDelaySlider:Set(1) end)
        pcall(function() ThemeDropdown:Select("Dark") end)
        pcall(function() AccentColorPicker:Set(Color3.fromHex("#72a6e6")) end)
        pcall(function() AcrylicToggle:Set(false) end)
        pcall(function() TransparencySlider:Set(0) end)
        pcall(function() ScaleSlider:Set(0.8) end)
        pcall(function() VisualPresetDropdown:Select("Balanced") end)
        pcall(function() PostFXToggle:Set(true) end)
        pcall(function() NoFogToggle:Set(false) end)
        pcall(function() SkyTintToggle:Set(false) end)
        pcall(function() SkyColorPicker:Set(Color3.fromHex("#D7C6FF")) end)
        pcall(function() AquariumGoalDropdown:Select("Items") end)
        pcall(function() AquariumReminderToggle:Set(false) end)
        pcall(function() applySkyTint(false) end)
        pcall(function() WaypointToggle:Set(true) end)
        pcall(function() BrightnessSlider:Set(OriginalBrightness) end)
        pcall(function() SaturationSlider:Set(0) end)
        pcall(function() ContrastSlider:Set(0) end)
        pcall(function() FOVSlider:Set(OriginalFieldOfView) end)
        saveLocalSettings()
        WindUI:Notify({ Title = "Bootlean Fisch", Content = "Settings reset to defaults.", Duration = 3 })
    end,
})

-- Keep the visuals initializer in its own function: unoptimized executors cap
-- each function at 200 registers, including locals in nested do blocks.
local function initializeVisuals()
VisualsTab:Section({ Title = "Local Visual Quality" })
local PresetNames = { "Performance", "Balanced", "Quality" }
local Options = VisualState.Options
local OptionDefaults = {
    Particles = true, TrailsBeams = true, PartShadows = true, Textures = true,
    Reflections = true, LightShadows = true, WaterEffects = true, Bloom = true,
    SunRays = true, Blur = true, DepthOfField = true, FlatMaterials = false,
    Shadows = Lighting.GlobalShadows,
}
local OriginalGlobalShadows = Lighting.GlobalShadows
OriginalBrightness = Lighting.Brightness
local OriginalFogStart, OriginalFogEnd = Lighting.FogStart, Lighting.FogEnd
local OriginalSkyTop, OriginalSkyBottom = Lighting.ColorShift_Top, Lighting.ColorShift_Bottom
local OriginalCameraFOVs = setmetatable({}, { __mode = "k" })
local Records = setmetatable({}, { __mode = "k" })
local SkyObjects, PostEffects = setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })
local Connections, OptionControls = {}, {}
local UpdatingControls = false
local Worker: { [string]: any } = {
    Running = true, WorldIndexed = false, IndexFirst = 1, IndexLast = 0,
    ApplyFirst = 1, ApplyLast = 0, IndexQueue = {}, ApplyQueue = {},
    PendingIndex = setmetatable({}, { __mode = "k" }), PendingApply = setmetatable({}, { __mode = "k" }),
    Sweep = false, SweepKey = nil, SweepFilter = nil, Indexed = 0, Applied = 0, Writes = 0,
    LastBatchMs = 0, LastBatchOperations = 0,
}
local ProtectionCache = {}
local function saveVisualSettings()
    Worker.SaveDueAt = os.clock() + 0.3
end
local terrain = Workspace:FindFirstChildOfClass("Terrain")
local WaterOriginals = {}
if terrain then
    for _, property in ipairs({ "WaterWaveSize", "WaterWaveSpeed", "WaterReflectance" }) do
        pcall(function() WaterOriginals[property] = terrain[property] end)
    end
end
local startingCamera = Workspace.CurrentCamera
OriginalFieldOfView = startingCamera and startingCamera.FieldOfView or 70
if startingCamera then OriginalCameraFOVs[startingCamera] = startingCamera.FieldOfView end

local function setProperty(instance, property, value)
    if value == nil then return end
    pcall(function()
        if instance[property] ~= value then
            instance[property] = value
            Worker.Writes = Worker.Writes + 1
        end
    end)
end

local function isProtected(instance)
    local cached = ProtectionCache[instance]
    if cached ~= nil then return cached end
    local visited, protected = {}, false
    local current = instance
    for _ = 1, 16 do
        if not current or current == Workspace or current == Lighting then break end
        local known = ProtectionCache[current]
        if known ~= nil then protected = known; break end
        table.insert(visited, current)
        local name = tostring(current.Name or ""):lower()
        if name:find("bootlean", 1, true) or name:find("windui", 1, true) or name == "npcs"
            or current:IsA("Tool") or (current:IsA("Model") and current:FindFirstChildOfClass("Humanoid")) then
            protected = true
            break
        end
        current = current.Parent
    end
    for _, object in ipairs(visited) do ProtectionCache[object] = protected end
    return protected
end

local KindsByClass = {
    Atmosphere = "Atmosphere", Clouds = "Clouds", BloomEffect = "Bloom", SunRaysEffect = "SunRays",
    BlurEffect = "Blur", DepthOfFieldEffect = "DepthOfField", ColorCorrectionEffect = "ColorCorrection",
    ParticleEmitter = "Particles", Fire = "Particles", Smoke = "Particles", Sparkles = "Particles",
    Trail = "TrailsBeams", Beam = "TrailsBeams", PointLight = "Light", SpotLight = "Light", SurfaceLight = "Light",
    Decal = "Texture", Texture = "Texture", SpecialMesh = "Mesh",
}
local function kindOf(instance)
    if instance == LocalColorCorrection then return "OwnColorCorrection" end
    local kind = KindsByClass[instance.ClassName]
    if kind then return kind end
    if instance:IsA("BasePart") and not instance:IsA("Terrain") then return "Part" end
    return nil
end

local function enqueueApply(instance)
    if not Worker.Running or Worker.PendingApply[instance] then return end
    Worker.PendingApply[instance] = true
    Worker.ApplyLast = Worker.ApplyLast + 1
    Worker.ApplyQueue[Worker.ApplyLast] = instance
end

local function enqueueIndex(instance, recursive)
    if not Worker.Running or not instance then return end
    local existing = Worker.PendingIndex[instance]
    if existing then existing.Recursive = existing.Recursive or recursive; return end
    local work = { Instance = instance, Recursive = recursive }
    Worker.PendingIndex[instance] = work
    Worker.IndexLast = Worker.IndexLast + 1
    Worker.IndexQueue[Worker.IndexLast] = work
end

local function remember(record, instance, property)
    if record.Original[property] ~= nil then return end
    pcall(function() record.Original[property] = instance[property] end)
end

local function applyRecord(instance, record)
    if not instance.Parent then return end
    local original, kind = record.Original, record.Kind
    if kind ~= "OwnColorCorrection" and isProtected(instance) then
        for property, value in pairs(original) do setProperty(instance, property, value) end
        return
    end
    if kind == "Atmosphere" then
        setProperty(instance, "Density", VisualState.NoFog and 0 or original.Density)
        setProperty(instance, "Haze", VisualState.NoFog and 0 or original.Haze)
        setProperty(instance, "Glare", VisualState.NoFog and 0 or original.Glare)
        local color = SkyState.Enabled and Color3.fromHex(SkyState.Color) or nil
        setProperty(instance, "Color", color or original.Color)
        setProperty(instance, "Decay", color and color:Lerp(Color3.new(0.18, 0.18, 0.2), 0.3) or original.Decay)
    elseif kind == "Clouds" then
        local color = SkyState.Enabled and Color3.fromHex(SkyState.Color) or nil
        setProperty(instance, "Color", color and color:Lerp(Color3.new(1, 1, 1), 0.28) or original.Color)
    elseif kind == "Particles" or kind == "TrailsBeams" then
        setProperty(instance, "Enabled", Options[kind] and original.Enabled or false)
    elseif kind == "Light" then
        setProperty(instance, "Shadows", Options.LightShadows and original.Shadows or false)
    elseif kind == "Texture" then
        setProperty(instance, "Transparency", Options.Textures and original.Transparency or 1)
    elseif kind == "Mesh" then
        setProperty(instance, "TextureId", Options.Textures and original.TextureId or "")
    elseif kind == "Part" then
        setProperty(instance, "CastShadow", Options.PartShadows and original.CastShadow or false)
        setProperty(instance, "Reflectance", Options.Reflections and original.Reflectance or 0)
        local flat = Options.FlatMaterials and instance.Transparency < 0.95 and original.Material ~= Enum.Material.Glass
        setProperty(instance, "Material", flat and Enum.Material.SmoothPlastic or original.Material)
        setProperty(instance, "MaterialVariant", flat and "" or original.MaterialVariant)
    elseif kind == "OwnColorCorrection" then
        setProperty(instance, "Enabled", VisualState.Saturation ~= 0 or VisualState.Contrast ~= 0)
    else
        local enabled = VisualState.PostFX and (Options[kind] ~= false)
        setProperty(instance, "Enabled", enabled and original.Enabled or false)
    end
    Worker.Applied = Worker.Applied + 1
end

local function indexInstance(instance, protected)
    local kind = kindOf(instance)
    if not kind then return end
    if protected == nil then protected = isProtected(instance) end
    if kind ~= "OwnColorCorrection" and protected then return end
    local record = Records[instance]
    if not record then
        record = { Kind = kind, Original = {} }
        Records[instance] = record
        if kind == "Atmosphere" then
            for _, property in ipairs({ "Density", "Haze", "Glare", "Color", "Decay" }) do remember(record, instance, property) end
            SkyObjects[instance] = true
        elseif kind == "Clouds" then
            remember(record, instance, "Color")
            SkyObjects[instance] = true
        elseif kind == "Part" then
            for _, property in ipairs({ "CastShadow", "Reflectance", "Material", "MaterialVariant" }) do remember(record, instance, property) end
        elseif kind == "Texture" then remember(record, instance, "Transparency")
        elseif kind == "Mesh" then remember(record, instance, "TextureId")
        elseif kind == "Light" then remember(record, instance, "Shadows")
        else
            remember(record, instance, "Enabled")
            if kind ~= "Particles" and kind ~= "TrailsBeams" then PostEffects[instance] = true end
        end
    end
    if kind == "Atmosphere" and not record.Connections then
        record.Connections = {}
        for _, property in ipairs({ "Density", "Haze", "Glare", "Color", "Decay" }) do
            table.insert(record.Connections, instance:GetPropertyChangedSignal(property):Connect(function()
                local fogProperty = property == "Density" or property == "Haze" or property == "Glare"
                if (fogProperty and VisualState.NoFog) or (not fogProperty and SkyState.Enabled) then
                    enqueueApply(instance)
                else
                    record.Original[property] = instance[property]
                end
            end))
        end
    end
    enqueueApply(instance)
end

local function needsWorldIndex()
    return not Options.Particles or not Options.TrailsBeams or not Options.PartShadows or not Options.Textures
        or not Options.Reflections or not Options.LightShadows or Options.FlatMaterials
end

local RefreshKinds = {
    Particles = { Particles = true }, TrailsBeams = { TrailsBeams = true },
    PartShadows = { Part = true }, Reflections = { Part = true }, FlatMaterials = { Part = true },
    Textures = { Texture = true, Mesh = true }, LightShadows = { Light = true },
    Shadows = {}, WaterEffects = {}, Bloom = { Bloom = true }, SunRays = { SunRays = true },
    Blur = { Blur = true }, DepthOfField = { DepthOfField = true },
}
local function refreshKnownObjects(option)
    local filter = option and RefreshKinds[option] or nil
    if filter and next(filter) == nil then return end
    if not Worker.Sweep then
        Worker.SweepFilter = filter and table.clone(filter) or nil
    elseif Worker.SweepFilter and filter then
        for kind in pairs(filter) do Worker.SweepFilter[kind] = true end
    else
        Worker.SweepFilter = nil
    end
    Worker.Sweep = true
    Worker.SweepKey = nil
    if needsWorldIndex() and not Worker.WorldIndexed then
        Worker.WorldIndexed = true
        enqueueIndex(Workspace, true)
    end
end

local function applyGlobals()
    setProperty(Lighting, "GlobalShadows", Options.Shadows)
    setProperty(Lighting, "FogStart", VisualState.NoFog and 0 or OriginalFogStart)
    setProperty(Lighting, "FogEnd", VisualState.NoFog and 100000 or OriginalFogEnd)
    local color = SkyState.Enabled and Color3.fromHex(SkyState.Color) or nil
    setProperty(Lighting, "ColorShift_Top", color and color:Lerp(Color3.new(1, 1, 1), 0.55) or OriginalSkyTop)
    setProperty(Lighting, "ColorShift_Bottom", color and color:Lerp(Color3.new(0.45, 0.45, 0.48), 0.5) or OriginalSkyBottom)
    if terrain then
        for property, original in pairs(WaterOriginals) do setProperty(terrain, property, Options.WaterEffects and original or 0) end
    end
end

local function processApplyOne()
    if Worker.ApplyFirst > Worker.ApplyLast then return false end
    local instance = Worker.ApplyQueue[Worker.ApplyFirst]
    Worker.ApplyQueue[Worker.ApplyFirst] = nil
    Worker.ApplyFirst = Worker.ApplyFirst + 1
    Worker.PendingApply[instance] = nil
    local record = Records[instance]
    if record then pcall(applyRecord, instance, record) end
    if Worker.ApplyFirst > Worker.ApplyLast then Worker.ApplyFirst, Worker.ApplyLast = 1, 0 end
    return true
end

local function processIndexOne()
    if Worker.IndexFirst > Worker.IndexLast then return false end
    local work = Worker.IndexQueue[Worker.IndexFirst]
    local instance = work.Instance
    if not work.Indexed then
        work.Indexed = true
        Worker.Indexed = Worker.Indexed + 1
        if instance.Parent or instance == Workspace or instance == Lighting then
            local protected = isProtected(instance)
            indexInstance(instance, protected)
            if work.Recursive and not protected then
                work.Children, work.ChildIndex = instance:GetChildren(), 1
            end
        end
    end
    if work.Children then
        -- Wide folders expand incrementally instead of queuing thousands of children in one call.
        local emitted = 0
        while work.ChildIndex <= #work.Children and emitted < 12 do
            enqueueIndex(work.Children[work.ChildIndex], true)
            work.ChildIndex = work.ChildIndex + 1
            emitted = emitted + 1
        end
    end
    Worker.IndexQueue[Worker.IndexFirst] = nil
    Worker.IndexFirst = Worker.IndexFirst + 1
    if work.Children and work.ChildIndex <= #work.Children then
        -- Rotate expansion behind the discovered children so they can be applied immediately.
        Worker.IndexLast = Worker.IndexLast + 1
        Worker.IndexQueue[Worker.IndexLast] = work
    else
        Worker.PendingIndex[instance] = nil
    end
    if Worker.IndexFirst > Worker.IndexLast then Worker.IndexFirst, Worker.IndexLast = 1, 0 end
    return true
end

local function processSweepOne()
    if not Worker.Sweep then return false end
    local ok, instance = pcall(next, Records, Worker.SweepKey)
    if not ok then instance = next(Records) end
    Worker.SweepKey = instance
    if not instance then
        Worker.Sweep, Worker.SweepFilter = false, nil
        return false
    end
    local record = Records[instance]
    if record and (not Worker.SweepFilter or Worker.SweepFilter[record.Kind]) then enqueueApply(instance) end
    return true
end

local function processVisualWork()
    local started = os.clock()
    local fps = Runtime.FrameStats and Runtime.FrameStats.FPS
    local deadline = started + (fps and fps < 35 and 0.001 or 0.0025)
    local operations = 0
    table.clear(ProtectionCache)
    while operations < 192 and os.clock() < deadline do
        -- Apply first, then discover. An ongoing world scan cannot starve visible changes.
        local worked = processApplyOne()
        worked = processIndexOne() or worked
        worked = processSweepOne() or worked
        if not worked then break end
        operations = operations + 1
    end
    Worker.LastBatchMs = (os.clock() - started) * 1000
    Worker.LastBatchOperations = operations
    if Worker.SaveDueAt and os.clock() >= Worker.SaveDueAt then
        Worker.SaveDueAt = nil
        pcall(saveLocalSettings)
    end
end

local function refreshSkyObjects()
    applyGlobals()
    for instance in pairs(SkyObjects) do enqueueApply(instance) end
end
applyNoFog = function(enabled)
    VisualState.NoFog = enabled == true
    refreshSkyObjects()
end
applySkyTint = function(enabled)
    SkyState.Enabled = enabled == true
    refreshSkyObjects()
end
local function setPostFX(enabled)
    VisualState.PostFX = enabled == true
    for instance in pairs(PostEffects) do enqueueApply(instance) end
end

local ApplyingCameraFOV = false
local function applyCameraFOV(value)
    if ApplyingCameraFOV then return end
    local camera = Workspace.CurrentCamera
    if not camera then return end
    if OriginalCameraFOVs[camera] == nil then OriginalCameraFOVs[camera] = camera.FieldOfView end
    ApplyingCameraFOV = true
    setProperty(camera, "FieldOfView", math.clamp(tonumber(value) or OriginalCameraFOVs[camera], 50, 120))
    ApplyingCameraFOV = false
end

local CameraFOVConnection
local function watchCameraFOV(camera)
    if CameraFOVConnection then pcall(function() CameraFOVConnection:Disconnect() end); CameraFOVConnection = nil end
    if not camera then return end
    if OriginalCameraFOVs[camera] == nil then OriginalCameraFOVs[camera] = camera.FieldOfView end
    local ok, connection = pcall(function()
        return camera:GetPropertyChangedSignal("FieldOfView"):Connect(function()
            local desired = VisualState.FieldOfView
            if ApplyingCameraFOV or not desired or camera ~= Workspace.CurrentCamera then return end
            desired = math.clamp(tonumber(desired) or OriginalCameraFOVs[camera], 50, 120)
            if math.abs(camera.FieldOfView - desired) > 0.01 then
                setProperty(camera, "FieldOfView", desired)
            end
        end)
    end)
    if ok and connection then
        CameraFOVConnection = connection
        table.insert(Connections, connection)
    end
end

local FOVLockRunService = game:GetService("RunService")
local FOVLockBinding = "BootleanFischFOVLock"
local FOVLockBound, FOVLockError = pcall(function()
    FOVLockRunService:UnbindFromRenderStep(FOVLockBinding)
    FOVLockRunService:BindToRenderStep(FOVLockBinding, Enum.RenderPriority.Camera.Value + 1, function()
        local desired = VisualState.FieldOfView
        if desired then applyCameraFOV(desired) end
    end)
end)
if not FOVLockBound then
    table.insert(Connections, FOVLockRunService.RenderStepped:Connect(function()
        if VisualState.FieldOfView then applyCameraFOV(VisualState.FieldOfView) end
    end))
    warn("[Bootlean FOV] Using RenderStepped fallback: " .. tostring(FOVLockError))
end
onCleanup(function()
    pcall(function() FOVLockRunService:UnbindFromRenderStep(FOVLockBinding) end)
end)

LocalColorCorrection = Instance.new("ColorCorrectionEffect")
LocalColorCorrection.Name = "BootleanFischColorCorrection"
LocalColorCorrection.Saturation = VisualState.Saturation
LocalColorCorrection.Contrast = VisualState.Contrast
LocalColorCorrection.Enabled = VisualState.Saturation ~= 0 or VisualState.Contrast ~= 0
LocalColorCorrection.Parent = Lighting
indexInstance(LocalColorCorrection)

local function refreshOptionControls()
    UpdatingControls = true
    for key, control in pairs(OptionControls) do pcall(function() control:Set(Options[key]) end) end
    if PostFXToggle then pcall(function() PostFXToggle:Set(VisualState.PostFX) end) end
    if VisualPresetDropdown then pcall(function() VisualPresetDropdown:Select(VisualState.Preset) end) end
    UpdatingControls = false
end

local function applyVisualPreset(preset, persist)
    if preset ~= "Performance" and preset ~= "Balanced" and preset ~= "Quality" then preset = "Balanced" end
    VisualState.Preset = preset
    for key, value in pairs(OptionDefaults) do Options[key] = value end
    if preset == "Performance" then
        for _, key in ipairs({ "Shadows", "Particles", "TrailsBeams", "PartShadows", "Reflections", "LightShadows", "WaterEffects", "Bloom", "SunRays", "Blur", "DepthOfField" }) do Options[key] = false end
        Options.FlatMaterials = true
        VisualState.PostFX = false
    elseif preset == "Quality" then
        Options.Shadows = true
        VisualState.PostFX = true
    else
        VisualState.PostFX = true
    end
    applyGlobals()
    refreshKnownObjects()
    if persist ~= false then refreshOptionControls(); saveVisualSettings() end
end
Runtime.ResetVisualOptions = function()
    for key, value in pairs(OptionDefaults) do Options[key] = value end
    VisualState.Preset = "Balanced"
    applyGlobals()
    refreshKnownObjects()
    refreshOptionControls()
end
Runtime.GetVisualStats = function()
    return { Indexed = Worker.Indexed, Applied = Worker.Applied, Writes = Worker.Writes,
        IndexPending = math.max(0, Worker.IndexLast - Worker.IndexFirst + 1), ApplyPending = math.max(0, Worker.ApplyLast - Worker.ApplyFirst + 1),
        LastBatchMs = Worker.LastBatchMs, LastBatchOperations = Worker.LastBatchOperations }
end

VisualPresetDropdown = VisualsTab:Dropdown({ Title = "Quality preset", Values = PresetNames, Value = VisualState.Preset,
    Callback = function(value)
        if UpdatingControls or tostring(value) == VisualState.Preset then return end
        applyVisualPreset(tostring(value), true)
    end })
for _, entry in ipairs({
    { "Shadows", "World shadows" }, { "PartShadows", "Object shadows" }, { "LightShadows", "Local light shadows" },
    { "Particles", "Particles, smoke and fire" }, { "TrailsBeams", "Trails and beams" },
    { "Textures", "Environment textures and decals" }, { "FlatMaterials", "Simple environment materials" },
    { "Reflections", "Object reflections" }, { "WaterEffects", "Water waves and reflections" },
    { "Bloom", "Bloom" }, { "SunRays", "Sun rays" }, { "Blur", "Blur" }, { "DepthOfField", "Depth of field" },
}) do
    local key, title = entry[1], entry[2]
    OptionControls[key] = VisualsTab:Toggle({ Title = title, Value = Options[key], Callback = function(enabled)
        if UpdatingControls or Options[key] == (enabled == true) then return end
        Options[key] = enabled == true
        applyGlobals()
        refreshKnownObjects(key)
        saveVisualSettings()
    end })
end

BrightnessSlider = VisualsTab:Slider({ Title = "Brightness", Step = 0.1, Value = { Min = 0, Max = 5, Default = VisualState.Brightness or OriginalBrightness }, Callback = function(value)
    VisualState.Brightness = math.clamp(tonumber(value) or OriginalBrightness, 0, 5)
    setProperty(Lighting, "Brightness", VisualState.Brightness)
    saveVisualSettings()
end })
SaturationSlider = VisualsTab:Slider({ Title = "Color saturation", Step = 0.05, Value = { Min = -1, Max = 1, Default = VisualState.Saturation }, Callback = function(value)
    VisualState.Saturation = math.clamp(tonumber(value) or 0, -1, 1)
    LocalColorCorrection.Saturation = VisualState.Saturation
    enqueueApply(LocalColorCorrection)
    saveVisualSettings()
end })
ContrastSlider = VisualsTab:Slider({ Title = "Color contrast", Step = 0.05, Value = { Min = -1, Max = 1, Default = VisualState.Contrast }, Callback = function(value)
    VisualState.Contrast = math.clamp(tonumber(value) or 0, -1, 1)
    LocalColorCorrection.Contrast = VisualState.Contrast
    enqueueApply(LocalColorCorrection)
    saveVisualSettings()
end })
local FOVLockStatusParagraph
FOVSlider = VisualsTab:Slider({ Title = "Locked camera FOV", Step = 1, Value = { Min = 50, Max = 120, Default = VisualState.FieldOfView or OriginalFieldOfView }, Callback = function(value)
    VisualState.FieldOfView = math.clamp(tonumber(value) or OriginalFieldOfView, 50, 120)
    applyCameraFOV(VisualState.FieldOfView)
    if FOVLockStatusParagraph then FOVLockStatusParagraph:SetDesc("Locked at " .. tostring(VisualState.FieldOfView) .. ". Camera and quest changes are overridden.") end
    saveVisualSettings()
end })
FOVLockStatusParagraph = VisualsTab:Paragraph({
    Title = "FOV lock",
    Desc = VisualState.FieldOfView and ("Locked at " .. tostring(VisualState.FieldOfView) .. ". Camera and quest changes are overridden.") or "Choose a FOV with the slider to enable the lock.",
    Image = "lock",
    ImageSize = 16,
})
PostFXToggle = VisualsTab:Toggle({ Title = "Post-processing effects", Value = VisualState.PostFX, Callback = function(enabled)
    if UpdatingControls or VisualState.PostFX == (enabled == true) then return end
    setPostFX(enabled)
    saveVisualSettings()
end })
NoFogToggle = VisualsTab:Toggle({ Title = "No Fog", Value = VisualState.NoFog, Callback = function(enabled)
    applyNoFog(enabled)
    saveVisualSettings()
end })
SkyTintToggle = VisualsTab:Toggle({ Title = "Custom sky and cloud color", Value = SkyState.Enabled, Callback = function(enabled)
    applySkyTint(enabled)
    saveVisualSettings()
end })
SkyColorPicker = VisualsTab:Colorpicker({ Title = "Sky color", Default = Color3.fromHex(SkyState.Color), Callback = function(color)
    SkyState.Color = colorToHex(color)
    if SkyState.Enabled then refreshSkyObjects() end
    saveVisualSettings()
end })

-- Event callbacks enqueue only one instance. Scene traversal and property
-- writes happen in the budgeted worker, never in DescendantAdded callbacks.
table.insert(Connections, Lighting.DescendantAdded:Connect(function(instance) enqueueIndex(instance, false) end))
table.insert(Connections, Lighting.DescendantRemoving:Connect(function(instance)
    local record = Records[instance]
    if record then
        for _, connection in ipairs(record.Connections or {}) do pcall(function() connection:Disconnect() end) end
        record.Connections = nil
    end
end))
table.insert(Connections, Workspace.DescendantAdded:Connect(function(instance)
    if needsWorldIndex() or instance:IsA("Clouds") or instance:IsA("PostEffect") then enqueueIndex(instance, false) end
    if Worker.WorldIndexed and instance:IsA("Humanoid") then refreshKnownObjects() end
end))
watchCameraFOV(Workspace.CurrentCamera)
table.insert(Connections, Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    local camera = Workspace.CurrentCamera
    watchCameraFOV(camera)
    if camera then enqueueIndex(camera, true) end
    if VisualState.FieldOfView then applyCameraFOV(VisualState.FieldOfView) end
end))
for _, property in ipairs({ "FogStart", "FogEnd" }) do
    table.insert(Connections, Lighting:GetPropertyChangedSignal(property):Connect(function()
        if VisualState.NoFog then
            setProperty(Lighting, property, property == "FogStart" and 0 or 100000)
        elseif property == "FogStart" then OriginalFogStart = Lighting.FogStart
        else OriginalFogEnd = Lighting.FogEnd end
    end))
end

enqueueIndex(Lighting, true)
if terrain then enqueueIndex(terrain, true) end
if Workspace.CurrentCamera then enqueueIndex(Workspace.CurrentCamera, true) end
-- Preserve saved individual choices. A Performance preset chosen before these
-- options existed still gets a useful one-time migration.
if VisualState.Preset == "Performance" and type(SavedSettings.VisualOptions) ~= "table" then applyVisualPreset("Performance", false)
else applyGlobals(); if needsWorldIndex() then refreshKnownObjects() end end
if VisualState.Brightness then setProperty(Lighting, "Brightness", VisualState.Brightness) end
if VisualState.FieldOfView then applyCameraFOV(VisualState.FieldOfView) end
setWindowScale(AppearanceState.Scale)
pcall(function() applyCustomAccent(Color3.fromHex(AppearanceState.Accent), false) end)
table.insert(Connections, FOVLockRunService.Heartbeat:Connect(function()
    if not Worker.Running then return end
    if Worker.IndexFirst <= Worker.IndexLast or Worker.ApplyFirst <= Worker.ApplyLast or Worker.Sweep or Worker.SaveDueAt then
        processVisualWork()
    end
end))

onCleanup(function()
    Worker.Running = false
    if Worker.SaveDueAt then Worker.SaveDueAt = nil; pcall(saveLocalSettings) end
    for _, connection in ipairs(Connections) do pcall(function() connection:Disconnect() end) end
    Runtime.ResetVisualOptions = nil
    Runtime.GetVisualStats = nil
    local count = 0
    for instance, record in pairs(Records) do
        for _, connection in ipairs(record.Connections or {}) do pcall(function() connection:Disconnect() end) end
        if instance and instance.Parent and instance ~= LocalColorCorrection then
            for property, original in pairs(record.Original) do setProperty(instance, property, original) end
        end
        count = count + 1
        if count % 48 == 0 then task.wait() end
    end
    for property, original in pairs(WaterOriginals) do if terrain then setProperty(terrain, property, original) end end
    setProperty(Lighting, "GlobalShadows", OriginalGlobalShadows)
    setProperty(Lighting, "Brightness", OriginalBrightness)
    setProperty(Lighting, "FogStart", OriginalFogStart)
    setProperty(Lighting, "FogEnd", OriginalFogEnd)
    setProperty(Lighting, "ColorShift_Top", OriginalSkyTop)
    setProperty(Lighting, "ColorShift_Bottom", OriginalSkyBottom)
    for camera, original in pairs(OriginalCameraFOVs) do if camera then setProperty(camera, "FieldOfView", original) end end
    if LocalColorCorrection then pcall(function() LocalColorCorrection:Destroy() end) end
    table.clear(Worker.IndexQueue)
    table.clear(Worker.ApplyQueue)
    table.clear(Worker.PendingIndex)
    table.clear(Worker.PendingApply)
    table.clear(Records)
    table.clear(ProtectionCache)
end)
end
Runtime.Trace("Applying visual settings")
initializeVisuals()
Runtime.Trace("Visual settings ready")

do
-- Land/dock anchors: https://fisch.wiki/wiki/shipwright/
-- Additional anchors: /castaway-cliffs/ and /lost-jungle/.
local Destinations = {
    { Name = "Moosewood", Position = Vector3.new(360, 135, 260) },
    { Name = "Roslit Bay", Position = Vector3.new(-1455, 135, 740) },
    { Name = "Mushgrove Swamp", Position = Vector3.new(2455, 130, -665) },
    { Name = "Sunstone Island", Position = Vector3.new(-945, 130, -1115) },
    { Name = "Snowcap Island", Position = Vector3.new(2615, 135, 2400) },
    { Name = "Terrapin Island", Position = Vector3.new(-190, 130, 1925) },
    { Name = "Forsaken Shores", Position = Vector3.new(-2480, 135, 1540) },
    { Name = "Ancient Isle", Position = Vector3.new(5869, 143, 7) },
    { Name = "Grand Reef", Position = Vector3.new(-3600, 143, 476) },
    { Name = "Statue of Sovereignty", Position = Vector3.new(25, 135, -1010) },
    { Name = "Northern Expedition", Position = Vector3.new(19609, 131, 5186) },
    { Name = "Castaway Cliffs", Position = Vector3.new(657, 133.6, -1623) },
    { Name = "Lost Jungle", Position = Vector3.new(-2710, 150, -2050) },
}
local ByName, Names = {}, {}
for _, destination in ipairs(Destinations) do ByName[destination.Name] = destination; table.insert(Names, destination.Name) end
table.sort(Names)
local SelectedIsland = "Moosewood"
local Running, Generation = true, 0
local Status = TeleportTab:Paragraph({ Title = "Teleport", Desc = "Select an island.", Image = "navigation", ImageSize = 18 })
local function setStatus(text)
    Runtime.LastTeleportStatus = text
    if Running then Status:SetDesc(text) end
end

Config.TeleportRadius = savedNumber("TeleportRadius", 48, 12, 96)
Config.TeleportSearchHeight = savedNumber("TeleportSearchHeight", 160, 48, 256)
local function dangerousSurface(result)
    if not result or result.Material == Enum.Material.Water then return true end
    local material = string.lower(tostring(result.Material))
    if string.find(material, "lava", 1, true) then return true end
    local instance = result.Instance
    for _ = 1, 4 do
        if not instance or instance == Workspace then break end
        local name = string.lower(instance.Name)
        -- Folder names describe whole regions, not the surface being touched.
        -- Explicit hazard attributes still apply at every ancestor.
        if instance == result.Instance then
            for _, word in ipairs({ "lava", "killbrick", "killpart", "deathbrick", "acid", "damagetrigger", "poison" }) do
                if string.find(name, word, 1, true) then return true end
            end
        end
        for _, attribute in ipairs({ "IsLava", "KillBrick", "IsHazard", "Damage" }) do
            local value = instance:GetAttribute(attribute)
            if value == true or (type(value) == "number" and value > 0) then return true end
        end
        instance = instance.Parent
    end
    return false
end

local function findSafeLanding(anchor, root, params, cancelled)
    local height = math.max(6, root.Size.Y + 4)
    local spread = math.max(1.5, root.Size.X / 2 + 0.5)
    local hazards = OverlapParams.new()
    hazards.FilterType = Enum.RaycastFilterType.Exclude
    hazards.FilterDescendantsInstances = params.FilterDescendantsInstances
    hazards.RespectCanCollide = false
    hazards.MaxParts = 96
    local footOffsets = { Vector3.new(spread, 0, 0), Vector3.new(-spread, 0, 0), Vector3.new(0, 0, spread), Vector3.new(0, 0, -spread) }
    local candidates = { Vector3.zero }
    for _, radius in ipairs({ 6, 12, 24, Config.TeleportRadius }) do
        for i = 0, 7 do
            local angle = i * math.pi / 4
            table.insert(candidates, Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius))
        end
    end
    for index, offset in ipairs(candidates) do
        if cancelled() then return nil end
        if index % 4 == 0 then task.wait() end
        local origin = anchor + offset + Vector3.new(0, 24, 0)
        local result = Workspace:Raycast(origin, Vector3.new(0, -64, 0), params)
        if not result or dangerousSurface(result) then
            -- Wiki Y values can describe a dock, NPC or a region entrance.
            -- Retry vertically before declaring streamed terrain missing.
            local rise = Config.TeleportSearchHeight
            result = Workspace:Raycast(anchor + offset + Vector3.new(0, rise, 0), Vector3.new(0, -(rise + 256), 0), params)
        end
        if result and not dangerousSurface(result) and result.Normal.Y >= 0.75 then
            local floor = result.Position
            local supported = true
            for _, footOffset in ipairs(footOffsets) do
                local support = Workspace:Raycast(floor + footOffset + Vector3.new(0, 3, 0), Vector3.new(0, -6, 0), params)
                if dangerousSurface(support) or support.Normal.Y < 0.75 or math.abs(support.Position.Y - floor.Y) > 2 then supported = false; break end
            end
            if supported then
                -- Check above the center and all four corners, then across the
                -- body. Rays avoid treating an island mesh's entire bounding
                -- box as solid air while still rejecting ceilings and walls.
                local headroomOffsets = { Vector3.zero, table.unpack(footOffsets) }
                for _, bodyOffset in ipairs(headroomOffsets) do
                    if Workspace:Raycast(floor + bodyOffset + Vector3.new(0, 1.5, 0), Vector3.new(0, height - 1.5, 0), params) then supported = false; break end
                end
                if supported then
                    for _, bodyOffset in ipairs(footOffsets) do
                        if Workspace:Raycast(floor + Vector3.new(0, 3, 0), bodyOffset * 1.5, params) then supported = false; break end
                    end
                end
                if supported then
                    local overlapping = Workspace:GetPartBoundsInBox(
                        CFrame.new(floor + Vector3.new(0, height / 2 + 0.25, 0)),
                        Vector3.new(spread * 2, height, spread * 2), hazards
                    )
                    -- A crowded bounds query is not evidence that the floor is unsafe.
                    for _, part in ipairs(overlapping) do
                        if part ~= result.Instance and dangerousSurface({ Instance = part, Material = part.Material }) then supported = false; break end
                    end
                end
                if supported then return floor + Vector3.new(0, math.max(3.5, root.Size.Y / 2 + 2.5), 0) end
            end
        end
    end
    return nil
end

local function teleportTo(name, anchor)
    if Config.TeleportBusy then setStatus("A teleport is already running."); return false, Runtime.LastTeleportStatus end
    if Config.Enabled or Busy or ReelController.ActiveReel or ShakeArgs or getActiveShakeUI() or hasBobber(getEquippedRod())
        or (FishingState.CastRequest and not FishingState.CastRequest.Done) then
        setStatus("Finish fishing and switch Auto Fish off before teleporting.")
        return false, Runtime.LastTeleportStatus
    end
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root or humanoid.Health <= 0 or root.Anchored then setStatus("Character is not ready."); return false, Runtime.LastTeleportStatus end
    if not anchor or anchor.X ~= anchor.X or anchor.Y ~= anchor.Y or anchor.Z ~= anchor.Z
        or math.abs(anchor.X) > 100000 or math.abs(anchor.Y) > 100000 or math.abs(anchor.Z) > 100000 then
        setStatus("The destination coordinates are invalid.")
        return false, Runtime.LastTeleportStatus
    end
    Config.TeleportBusy = true
    Generation = Generation + 1
    local generation = Generation
    local function cancelled()
        return not Running or Generation ~= generation or LocalPlayer.Character ~= character
            or humanoid.Health <= 0 or not root.Parent or Config.Enabled
    end
    local worker
    local arrived = false
    local ok, failure = pcall(function()
        if humanoid.SeatPart then
            humanoid.Sit = false
            humanoid.Jump = true
            local deadline = os.clock() + 1
            while humanoid.SeatPart and os.clock() < deadline and not cancelled() do task.wait(0.05) end
            if humanoid.SeatPart then setStatus("Leave the boat seat first."); return end
        end
        if cancelled() then return end
        setStatus("Loading " .. name .. "...")
        if Workspace.StreamingEnabled then
            local done = false
            worker = task.spawn(function()
                pcall(function() LocalPlayer:RequestStreamAroundAsync(anchor, 4) end)
                done = true
            end)
            local deadline = os.clock() + 5
            while not done and os.clock() < deadline and not cancelled() do task.wait(0.05) end
            if not done then pcall(task.cancel, worker) end
            worker = nil
        end
        if cancelled() then return end
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { character }
        params.IgnoreWater = false
        params.RespectCanCollide = true
        setStatus("Checking landing...")
        local landing = findSafeLanding(anchor, root, params, cancelled)
        if cancelled() then return end
        if not landing then setStatus("No supported, dry landing found near " .. name .. ". Move closer to load the area, or increase Landing Search Radius."); return end
        local originalPosition = root.Position
        local desiredRoot = CFrame.new(landing) * root.CFrame.Rotation
        local pivotOffset = root.CFrame:ToObjectSpace(character:GetPivot())
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        character:PivotTo(desiredRoot * pivotOffset)
        task.wait(0.7)
        if cancelled() then return end
        if (root.Position - landing).Magnitude > 12 then
            setStatus("The server did not keep the move. No retry was made.")
            return
        end
        local surface = Workspace:Raycast(root.Position, Vector3.new(0, -10, 0), params)
        if dangerousSurface(surface) then
            local rollback = findSafeLanding(originalPosition, root, params, cancelled)
            if rollback and not cancelled() then
                character:PivotTo(CFrame.new(rollback) * root.CFrame.Rotation * root.CFrame:ToObjectSpace(character:GetPivot()))
            end
            setStatus("Landing became unsafe; the move was stopped.")
            return
        end
        setStatus(name .. " — arrived.")
        arrived = true
    end)
    if worker then pcall(task.cancel, worker) end
    Config.TeleportBusy = false
    if not ok then setStatus("Teleport failed: " .. tostring(failure):sub(1, 160))
    elseif Generation ~= generation then setStatus("Teleport cancelled.") end
    return arrived, Runtime.LastTeleportStatus
end

Runtime.TeleportTo = teleportTo
Runtime.IslandDestinations = Destinations
Runtime.ResolveIslandPosition = function(name)
    local key = tostring(name or ""):lower():gsub("[^%w]", "")
    local aliases = { ancientisles = "ancientisle", northernsummit = "northernexpedition", northsummit = "northernexpedition", sovereignty = "statueofsovereignty" }
    key = aliases[key] or key
    for _, destination in ipairs(Destinations) do
        if destination.Name:lower():gsub("[^%w]", "") == key then return destination.Position end
    end
    return nil
end
Runtime.FindNearestIsland = function(position)
    local best, distance = nil, math.huge
    for _, destination in ipairs(Destinations) do
        local delta = destination.Position - position
        local flatDistance = math.sqrt(delta.X * delta.X + delta.Z * delta.Z)
        if math.abs(delta.Y) < 250 and flatDistance < distance then best, distance = destination.Name, flatDistance end
    end
    if distance <= 2500 then return best, distance end
    return nil
end
Runtime.FindSafeLanding = findSafeLanding
Runtime.DangerousSurface = dangerousSurface

TeleportTab:Dropdown({
    Title = "Island", Values = Names, Value = SelectedIsland, SearchBarEnabled = true,
    Callback = function(value) if ByName[value] then SelectedIsland = value end end,
})
TeleportTab:Button({ Title = "Teleport to Island", Icon = "navigation", Callback = function()
    local destination = ByName[SelectedIsland]
    if destination then teleportTo(destination.Name, destination.Position) end
end })
do
    TeleportTab:Section({ Title = "Fishing Destinations" })
    local spots = {
        { Name = "XP / Cash — Captain's Goldfish", Island = "Forsaken Shores", Note = "Freshwater pond below the waterfall. Truffle Worm; prefers day and summer. Teleport lands at the island, then walk to the pond." },
        { Name = "Reef Bestiary — Grand Reef", Island = "Grand Reef", Note = "Reef species and general progression. Lands on the island; cast toward reef water." },
        { Name = "Ancient Isle Bestiary", Island = "Ancient Isle", Note = "Island fish collection. Safe island arrival; choose a shoreline casting spot." },
        { Name = "Swamp Bestiary", Island = "Mushgrove Swamp", Note = "Swamp species. Safe island arrival; fish in the swamp pools." },
    }
    local names, selected = {}, spots[1]
    for _, spot in ipairs(spots) do table.insert(names, spot.Name) end
    local info = TeleportTab:Paragraph({ Title = "Fishing Spot", Desc = selected.Note, Image = "fish", ImageSize = 18 })
    TeleportTab:Dropdown({ Title = "Fishing Destination", Values = names, Value = selected.Name, SearchBarEnabled = true, Callback = function(value)
        for _, spot in ipairs(spots) do if spot.Name == value then selected = spot; info:SetDesc(spot.Note); break end end
    end })
    TeleportTab:Button({ Title = "Teleport to Fishing Island", Icon = "fish", Callback = function()
        local destination = ByName[selected.Island]
        if destination then teleportTo(selected.Name, destination.Position) end
    end })
end
TeleportTab:Button({ Title = "Teleport to Marked GPS Point", Icon = "map-pin", Callback = function()
    if SavedMainPoint then teleportTo(MainPointName, SavedMainPoint) else setStatus("Mark a point in GPS first.") end
end })
TeleportTab:Button({ Title = "Cancel Teleport", Icon = "x", Callback = function()
    if Config.TeleportBusy then Generation = Generation + 1 end
end })
do
-- Item locations: https://fisch.wiki/wiki/tools/ and /winter-cloak/.
-- Camp arrival: https://fisch.wiki/wiki/innkeeper/ (Glacial Grotto).
TeleportTab:Section({ Title = "Equipment by Island" })
local equipment = {
    { Name = "GPS", Island = "Moosewood", Note = "Near the village pond; Wiki list price C$ 100." },
    { Name = "Fish Radar", Island = "Moosewood", Note = "Beside the dock; Wiki list price C$ 8,000." },
    { Name = "Basic Diving Gear", Island = "Moosewood", Note = "Crates near the Shipwright; Wiki list price C$ 3,000." },
    { Name = "Glider", Island = "Roslit Bay", Note = "Campsite log; Wiki list price C$ 1,035." },
    { Name = "Fish Radar", Island = "Roslit Bay", Note = "Dock area; scan for its exact loaded position." },
    { Name = "Glider", Island = "Ancient Isle", Note = "Near the Merchant; Wiki list price C$ 900." },
    { Name = "Winter Cloak", Island = "Northern Expedition", Position = Vector3.new(20168,780,5721), Kind = "Wiki item coordinates", Note = "Wiki list price C$ 7,500. Mountain cold and oxygen mechanics still apply." },
    { Name = "Pickaxe", Island = "Northern Expedition", Note = "Overgrowth Caves campsite, by two tents and the Avalanche Rod. Wiki list price C$ 5,000." },
    { Name = "Basic Oxygen Tank", Island = "Northern Expedition", Note = "Mountain entry equipment. Scan loaded offers to locate the item." },
    { Name = "Beginner Oxygen Tank", Island = "Northern Expedition", Note = "Overgrowth Caves campsite; scan the loaded camp for its position." },
    { Name = "Intermediate Oxygen Tank", Island = "Northern Expedition", Note = "Mountain progression equipment; scan loaded camps for its position." },
    { Name = "Advanced Oxygen Tank", Island = "Northern Expedition", Position = Vector3.new(19890,1154,5510), Kind = "Glacial Grotto camp arrival", Note = "Near the upper campsite. This is a camp anchor, not an exact item position; live offers take priority." },
    { Name = "Advanced Glider", Island = "Northern Expedition", Position = Vector3.new(19890,1154,5510), Kind = "Glacial Grotto camp arrival", Note = "Near the upper campfire; Wiki list price C$ 10,000. Oxygen and cold protection required." },
    { Name = "Advanced Diving Gear", Island = "Desolate Deep", Note = "Left cave merchant. Wiki list price C$ 15,000. Unlock and dive access required; live GPS only." },
    { Name = "Flippers", Island = "Desolate Deep", Note = "Desolate Deep merchant equipment. Live GPS only." },
    { Name = "Super Flippers", Island = "Desolate Deep", Note = "Desolate Pocket equipment. Live GPS only." },
    { Name = "Glider", Island = "Desolate Deep", Note = "Desolate Pocket market. Live GPS only." },
    { Name = "Advanced Diving Gear", Island = "Atlantis", Note = "Beside the Atlantis Merchant. Live GPS only; area access required." },
    { Name = "Water Bubble", Island = "Grand Reef", Note = "Bubble Mermaid quest reward; requires 3 Resin and C$ 25,000. Teleport reaches the island; it does not complete the quest." },
}
local selectedIsland, selectedItem = "Moosewood", "GPS"
local islands, seen, live = {}, {}, {}
for _, item in ipairs(equipment) do if not seen[item.Island] then seen[item.Island] = true; table.insert(islands,item.Island) end end
table.sort(islands)
local function itemNames(island)
    local names = {}
    for _, item in ipairs(equipment) do if item.Island == island then table.insert(names,item.Name) end end
    table.sort(names); return names
end
local function selectedEquipment()
    for _, item in ipairs(equipment) do if item.Island == selectedIsland and item.Name == selectedItem then return item end end
    return nil
end
local info = TeleportTab:Paragraph({ Title = "Equipment Location", Desc = "", Image = "backpack", ImageSize = 18 })
local function refreshEquipment()
    local item = selectedEquipment()
    if not item then return end
    local position = live[item] or item.Position
    info:SetDesc(item.Name .. " — " .. item.Island .. "\n" .. item.Note .. "\n"
        .. (live[item] and "Exact loaded position" or item.Position and item.Kind or ByName[item.Island] and "Island arrival; scan nearby offers for exact GPS" or "No verified GPS yet; load this area and scan")
        .. (position and string.format("\nX %.1f   Y %.1f   Z %.1f",position.X,position.Y,position.Z) or ""))
end
local itemDropdown
TeleportTab:Dropdown({ Title = "Equipment Island", Values = islands, Value = selectedIsland, SearchBarEnabled = true, Callback = function(value)
    if not seen[value] then return end
    selectedIsland = value
    local names = itemNames(value); selectedItem = names[1]
    if itemDropdown then itemDropdown:Refresh(names); itemDropdown:Select(selectedItem) end
    refreshEquipment()
end })
itemDropdown = TeleportTab:Dropdown({ Title = "Equipment", Values = itemNames(selectedIsland), Value = selectedItem, SearchBarEnabled = true, Callback = function(value)
    selectedItem = value; refreshEquipment()
end })
TeleportTab:Button({ Title = "Scan Loaded Equipment", Icon = "search", Callback = function()
    local queue, cursor = { Workspace }, 1
    local deadline = os.clock() + 0.001
    while queue[cursor] and cursor <= 20000 and Running do
        local object = queue[cursor]; cursor = cursor + 1
        if object:IsA("Tool") or (object:IsA("Model") and Players:GetPlayerFromCharacter(object)) then continue end
        local name = object.Name
        if object:IsA("ProximityPrompt") then name = object.ObjectText end
        local key = tostring(name):lower():gsub("[^%w]", "")
        for _, item in ipairs(equipment) do
            if key == item.Name:lower():gsub("[^%w]", "") then
                local part = object:IsA("ProximityPrompt") and object.Parent or object
                local ok, position = pcall(function()
                    if part:IsA("Attachment") then return part.WorldPosition end
                    if part:IsA("BasePart") then return part.Position end
                    if part:IsA("Model") then return part:GetPivot().Position end
                    return nil
                end)
                if ok and position then
                    local region = Runtime.FindNearestIsland and Runtime.FindNearestIsland(position)
                    local ancestor = object
                    for _ = 1, 8 do
                        if not ancestor or ancestor == Workspace then break end
                        local text = ancestor.Name:lower():gsub("[^%w]", "")
                        if text:find(item.Island:lower():gsub("[^%w]", ""),1,true)
                            or (item.Island == "Northern Expedition" and (text:find("glacialgrotto",1,true) or text:find("frigidcavern",1,true) or text:find("overgrowthcaves",1,true))) then region = item.Island; break end
                        ancestor = ancestor.Parent
                    end
                    if region == item.Island then live[item] = position end
                end
            end
        end
        for _, child in ipairs(object:GetChildren()) do
            if not object:IsA("BasePart") or child:IsA("ProximityPrompt") or child:IsA("Attachment") then table.insert(queue,child) end
        end
        if cursor % 80 == 0 or os.clock() >= deadline then task.wait(); deadline = os.clock() + 0.001 end
    end
    refreshEquipment()
end })
TeleportTab:Button({ Title = "Teleport to Equipment", Icon = "navigation", Callback = function()
    local item = selectedEquipment()
    local position = item and (live[item] or item.Position or ByName[item.Island] and ByName[item.Island].Position)
    if not position then info:SetDesc("No verified location is loaded. Visit the unlocked area and scan equipment first."); return end
    teleportTo(item.Name,position)
end })
refreshEquipment()
end

TeleportTab:Section({ Title = "Landing Settings" })
TeleportTab:Slider({ Title = "Landing Search Radius", Step = 6, Value = { Min = 12, Max = 96, Default = Config.TeleportRadius }, Callback = function(value)
    Config.TeleportRadius = math.clamp(tonumber(value) or 48, 12, 96); saveLocalSettings()
end })
TeleportTab:Slider({ Title = "Vertical Search Height", Step = 16, Value = { Min = 48, Max = 256, Default = Config.TeleportSearchHeight }, Callback = function(value)
    Config.TeleportSearchHeight = math.clamp(tonumber(value) or 160, 48, 256); saveLocalSettings()
end })

do
    TeleportTab:Section({ Title = "Discovery Journal" })
    Runtime.DiscoveryVisits = {}
    if type(SavedSettings.VisitedLocations) == "table" then
        for _, destination in ipairs(Destinations) do
            if SavedSettings.VisitedLocations[destination.Name] == true then Runtime.DiscoveryVisits[destination.Name] = true end
        end
    end
    local selected, routeGeneration = Names[1], 0
    local journal = TeleportTab:Paragraph({ Title = "Island Visits", Desc = "", Image = "book-open", ImageSize = 18 })
    local function refreshJournal()
        local visited, missing = 0, {}
        for _, name in ipairs(Names) do
            if Runtime.DiscoveryVisits[name] then visited = visited + 1 else table.insert(missing, name) end
        end
        journal:SetDesc(string.format("Visited %d / %d\n%s\n%s", visited, #Names,
            Runtime.DiscoveryVisits[selected] and (selected .. " — Visited") or (selected .. " — Not recorded"),
            #missing == 0 and "All listed islands visited." or ("Unvisited: " .. table.concat(missing, ", "))))
    end
    TeleportTab:Paragraph({ Title = "Visit Tracking", Desc = "Records grounded visits near listed island landings for this account. Game discovery rewards depend on the game's own region triggers and requirements.", Image = "info", ImageSize = 16 })
    TeleportTab:Dropdown({ Title = "Discovery Destination", Values = Names, Value = selected, SearchBarEnabled = true, Callback = function(value)
        if ByName[value] then selected = value; refreshJournal() end
    end })
    TeleportTab:Button({ Title = "Visit Selected Island", Icon = "navigation", Callback = function()
        local destination = ByName[selected]
        if destination then teleportTo(destination.Name, destination.Position) end
    end })
    TeleportTab:Button({ Title = "Visit Unrecorded Islands", Icon = "route", Callback = function()
        routeGeneration = routeGeneration + 1
        local token = routeGeneration
        for _, name in ipairs(Names) do
            if token ~= routeGeneration or not Running then break end
            if not Runtime.DiscoveryVisits[name] then
                if not teleportTo(name, ByName[name].Position) then break end
                task.wait(2.5)
            end
        end
    end })
    TeleportTab:Button({ Title = "Stop Discovery Route", Icon = "square", Callback = function()
        routeGeneration = routeGeneration + 1; Generation = Generation + 1
    end })
    task.spawn(function()
        while Running do
            local character = LocalPlayer.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if root and humanoid and humanoid.Health > 0 and humanoid.FloorMaterial ~= Enum.Material.Air then
                for _, destination in ipairs(Destinations) do
                    if not Runtime.DiscoveryVisits[destination.Name] and (root.Position - destination.Position).Magnitude <= 80 then
                        Runtime.DiscoveryVisits[destination.Name] = true; saveLocalSettings(); refreshJournal()
                    end
                end
            end
            task.wait(2)
        end
    end)
    refreshJournal()
end
onCleanup(function()
    Running = false; Generation = Generation + 1; Config.TeleportBusy = false
    if Runtime.TeleportTo == teleportTo then Runtime.TeleportTo = nil; Runtime.IslandDestinations = nil; Runtime.ResolveIslandPosition = nil; Runtime.FindNearestIsland = nil; Runtime.FindSafeLanding = nil; Runtime.DangerousSurface = nil end
end)
end

do
GPSTab:Section({ Title = "Coordinates" })
local GPSRunning = true
local CurrentLocationParagraph = GPSTab:Paragraph({ Title = "Current Position", Desc = "Waiting for character...", Image = "crosshair", ImageSize = 20 })
local MainPointParagraph = GPSTab:Paragraph({ Title = "Marked Point", Desc = "No point marked.", Image = "map-pin", ImageSize = 20 })
local CoordinateInputs = {}
local PointNameInput
local SavedPointsDropdown
local UpdatingFields = false
local PasteText = ""
local WaypointKey

local function gpsNotice(message)
    pcall(function() WindUI:Notify({ Title = "GPS", Content = message, Duration = 4 }) end)
end

local function validCoordinate(value)
    value = tonumber(value)
    return value and value == value and math.abs(value) <= 100000 and value or nil
end

local function formatCoordinates(position)
    return string.format("X: %.2f   Y: %.2f   Z: %.2f", position.X, position.Y, position.Z)
end

local function cleanPointName(value)
    local name = (tostring(value or ""):gsub("%c", ""):match("^%s*(.-)%s*$") or ""):sub(1, 48)
    return name ~= "" and name or "Main Point"
end

local function getCurrentPosition()
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    return root and root.Position or nil
end

local function refreshMainPointDisplay()
    MainPointParagraph:SetDesc(SavedMainPoint and (MainPointName .. "\n" .. formatCoordinates(SavedMainPoint)) or "No point marked.")
end

refreshWaypoint = function()
    local key = SavedMainPoint and (MainPointName .. ":" .. tostring(SavedMainPoint) .. ":" .. AppearanceState.Accent) or ""
    if WaypointVisible and WaypointMarker and WaypointMarker.Parent and WaypointKey == key then return end
    if WaypointMarker then WaypointMarker:Destroy(); WaypointMarker = nil end
    WaypointKey = nil
    if not GPSRunning or not WaypointVisible or not SavedMainPoint then return end
    local marker = Instance.new("Part")
    marker.Name = "BootleanFischMainPoint"
    marker.Size = Vector3.new(0.25, 0.25, 0.25)
    marker.Position = SavedMainPoint
    marker.Anchored = true
    marker.CanCollide = false
    marker.CanTouch = false
    marker.CanQuery = false
    marker.Transparency = 1
    marker.Parent = Workspace
    local base = Instance.new("Attachment")
    base.Parent = marker
    local top = Instance.new("Attachment")
    top.Position = Vector3.new(0, 1800, 0)
    top.Parent = marker
    local beam = Instance.new("Beam")
    beam.Name = "WaypointPillar"
    beam.Attachment0 = base
    beam.Attachment1 = top
    beam.FaceCamera = true
    beam.Width0 = 3
    beam.Width1 = 3
    beam.LightEmission = 1
    beam.Color = ColorSequence.new(Color3.fromHex(AppearanceState.Accent))
    beam.Transparency = NumberSequence.new(0.2)
    beam.Parent = marker
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "WaypointBillboard"
    billboard.Adornee = marker
    billboard.AlwaysOnTop = true
    billboard.LightInfluence = 0
    billboard.MaxDistance = 100000
    billboard.Size = UDim2.fromOffset(260, 76)
    billboard.StudsOffset = Vector3.new(0, 8, 0)
    billboard.Parent = marker
    local label = Instance.new("TextLabel")
    label.Name = "WaypointName"
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.GothamBold
    label.Text = MainPointName
    label.TextColor3 = Color3.fromHex(AppearanceState.Accent)
    label.TextSize = 18
    label.TextWrapped = true
    label.TextStrokeTransparency = 0.15
    label.Parent = billboard
    WaypointMarker = marker
    WaypointKey = key
end

local function setCoordinateFields(position)
    UpdatingFields = true
    for _, axis in ipairs({ "X", "Y", "Z" }) do
        CoordinateValues[axis] = string.format("%.2f", position[axis])
        if CoordinateInputs[axis] then CoordinateInputs[axis]:Set(CoordinateValues[axis]) end
    end
    UpdatingFields = false
end

local function markPoint(name, position)
    MainPointName = cleanPointName(name)
    SavedMainPoint = position
    WaypointVisible = true
    setCoordinateFields(position)
    if PointNameInput then PointNameInput:Set(MainPointName) end
    refreshMainPointDisplay()
    refreshWaypoint()
    if WaypointToggle then WaypointToggle:Set(true) end
    saveLocalSettings()
end

Runtime.MarkGPSPoint = markPoint

local function getPointFromFields()
    local x, y, z = validCoordinate(CoordinateValues.X), validCoordinate(CoordinateValues.Y), validCoordinate(CoordinateValues.Z)
    if x and y and z then return Vector3.new(x, y, z) end
    return nil
end

-- Accept the format produced by Copy Current XYZ, labelled axes, and Vector3.new.
local function parseGPSCoordinates(value)
    local text = tostring(value or ""):lower():match("^%s*(.-)%s*$")
    local wrapped = text:match("^vector3%.new%s*%((.*)%)$") or text:match("^cframe%.new%s*%((.*)%)$")
    if wrapped then text = wrapped end
    local numberPattern = "[+%-]?%d*%.?%d+[eE]?[+%-]?%d*"
    local values = {}
    if text:find("[xyz]%s*[:=]") then
        for _, axis in ipairs({ "x", "y", "z" }) do
            local pattern = axis .. "%s*[:=]%s*(" .. numberPattern .. ")"
            local number, count
            text, count = text:gsub(pattern, function(found) number = found; return " " end)
            if count ~= 1 then return nil end
            table.insert(values, validCoordinate(number) or false)
        end
    else
        for token in text:gmatch("[^%s,;()%[%]{}]+") do
            if not token:match("^" .. numberPattern .. "$") then return nil end
            table.insert(values, validCoordinate(token) or false)
        end
        text = ""
    end
    if #values ~= 3 or not values[1] or not values[2] or not values[3] then return nil end
    if text:gsub("[%s,;()%[%]{}]", "") ~= "" then return nil end
    return Vector3.new(values[1], values[2], values[3])
end

PointNameInput = GPSTab:Input({
    Title = "Point Name", Value = MainPointName,
    Callback = function(value) MainPointName = cleanPointName(value) end,
})
for _, axis in ipairs({ "X", "Y", "Z" }) do
    local currentAxis = axis
    CoordinateInputs[currentAxis] = GPSTab:Input({
        Title = currentAxis, Value = CoordinateValues[currentAxis],
        Callback = function(value)
            CoordinateValues[currentAxis] = tostring(value or "")
            if not UpdatingFields then saveLocalSettings() end
        end,
    })
end

GPSTab:Button({
    Title = "Copy Current X / Y / Z", Icon = "copy",
    Callback = function()
        local position = getCurrentPosition()
        if not position then gpsNotice("Character position is unavailable."); return end
        local ok = type(setclipboard) == "function" and pcall(setclipboard, string.format("%.2f, %.2f, %.2f", position.X, position.Y, position.Z))
        gpsNotice(ok and "Current coordinates copied." or "Clipboard writing is unavailable.")
    end,
})

GPSTab:Input({
    Title = "Paste Coordinates", Placeholder = "X, Y, Z — paste here with Ctrl+V", Value = "",
    Callback = function(value) PasteText = tostring(value or "") end,
})
GPSTab:Button({
    Title = "Paste and Mark", Icon = "clipboard-paste",
    Callback = function()
        local text = PasteText
        if text:match("^%s*$") and type(getclipboard) == "function" then
            local ok, clipboardText = pcall(getclipboard)
            if ok and type(clipboardText) == "string" then text = clipboardText end
        end
        local position = parseGPSCoordinates(text)
        if not position then gpsNotice("Paste three coordinates into Paste Coordinates, for example 100, 135, -200."); return end
        markPoint(MainPointName, position)
    end,
})
GPSTab:Button({
    Title = "Mark X / Y / Z", Icon = "map-pin",
    Callback = function()
        local position = getPointFromFields()
        if not position then gpsNotice("Enter valid X, Y, Z coordinates between -100000 and 100000."); return end
        markPoint(MainPointName, position)
    end,
})

GPSTab:Section({ Title = "Saved Points" })
local function findSavedPoint(name)
    for _, point in ipairs(GPSState.Points) do if point.Name == name then return point end end
    return nil
end
local function savedPointOptions()
    local values = {}
    for _, point in ipairs(GPSState.Points) do table.insert(values, point.Name) end
    table.sort(values)
    if #values == 0 then table.insert(values, "No saved points") end
    return values
end
local function refreshSavedPoints()
    if not SavedPointsDropdown then return end
    local values = savedPointOptions()
    SavedPointsDropdown.Value = GPSState.SelectedPoint or values[1]
    SavedPointsDropdown:Refresh(values)
end
GPSTab:Button({
    Title = "Save Point", Icon = "save",
    Callback = function()
        local position = getPointFromFields()
        if not position then gpsNotice("Enter valid X, Y, and Z first."); return end
        local name = cleanPointName(MainPointName)
        local point = findSavedPoint(name)
        if not point then
            if #GPSState.Points >= 100 then gpsNotice("You can save up to 100 points."); return end
            point = { Name = name }
            table.insert(GPSState.Points, point)
        end
        point.X, point.Y, point.Z = position.X, position.Y, position.Z
        GPSState.SelectedPoint = name
        markPoint(name, position)
        refreshSavedPoints()
    end,
})
SavedPointsDropdown = GPSTab:Dropdown({
    Title = "Saved Point", Values = savedPointOptions(), Value = GPSState.SelectedPoint,
    SearchBarEnabled = true,
    Callback = function(value)
        if findSavedPoint(value) then GPSState.SelectedPoint = value; saveLocalSettings() end
    end,
})
GPSTab:Button({
    Title = "Show Selected Point", Icon = "locate-fixed",
    Callback = function()
        local point = findSavedPoint(GPSState.SelectedPoint)
        if not point then gpsNotice("Save and select a point first."); return end
        WaypointVisible = true
        markPoint(point.Name, Vector3.new(point.X, point.Y, point.Z))
        if WaypointToggle then WaypointToggle:Set(true) end
    end,
})
WaypointToggle = GPSTab:Toggle({
    Title = "Show Waypoint", Value = WaypointVisible,
    Callback = function(enabled) WaypointVisible = enabled == true; refreshWaypoint(); saveLocalSettings() end,
})

do
GPSTab:Section({ Title = "NPCs by Island" })
local NpcDirectory = {}
local function normalizeNpcText(value) return string.lower(tostring(value or "")):gsub("[^%w]", "") end
local function addNpc(name, region, aliases)
    table.insert(NpcDirectory, { Name = name, Region = region, Aliases = aliases or { (name:gsub("%s+—.*$", "")) } })
end
-- Names and regions follow the Fisch Wiki NPC directory; runtime models provide exact XYZ.
addNpc("Merchant — Nearest", nil, { "merchant" })
addNpc("Travelling Merchant", nil, { "travellingmerchant", "travelingmerchant" })
addNpc("Black Market", nil, { "blackmarket" })
addNpc("Angler — Nearest", nil, { "angler", "anglernpc" })
addNpc("Shipwright — Nearest", nil, { "shipwright", "shipwrightnpc" })
addNpc("Inn Keeper — Nearest", nil, { "innkeeper", "beachkeeper" })
addNpc("Submariner — Volcanic Vents", "Volcanic Vents", { "submariner", "submarinershipwright" })
addNpc("Submariner — Challenger's Deep", "Challenger's Deep", { "submariner", "submarinershipwright" })
addNpc("Submariner — Abyssal Zenith", "Abyssal Zenith", { "submariner", "submarinershipwright" })
addNpc("Submariner — Calm Zone", "Calm Zone", { "submariner", "submarinershipwright" })
addNpc("Appraiser", "Moosewood")
addNpc("Lantern Keeper", "Moosewood", { "lanternkeeper", "thelanternkeeper" })
addNpc("Pierre", "Moosewood")
addNpc("Phineas", "Moosewood")
addNpc("Daisy", "Moosewood")
addNpc("Lucas", "Moosewood")
addNpc("Captain Ahab", "Moosewood", { "captainahab", "captainahabnpc" })
addNpc("Alfie", "Roslit Bay")
addNpc("Ashe", "Roslit Bay")
addNpc("Dr. Glimmerfin", "Roslit Bay", { "drglimmerfin", "drglimmerfinnpc" })
addNpc("Orc", "Roslit Bay")
addNpc("Lazy Worker", "Roslit Bay", { "lazyworker", "lazyworkers" })
addNpc("Wilson", "Snowcap Island")
addNpc("Merlin", "Sunstone Island")
addNpc("Rhea", "Sunstone Island")
addNpc("Jack", "Terrapin Island")
addNpc("Agaric", "Mushgrove Swamp")
addNpc("Guard", "Mushgrove Swamp")
addNpc("Jack Marrow", "Forsaken Shores")
addNpc("Cole", "Statue of Sovereignty")
addNpc("Marina", "Statue of Sovereignty")
addNpc("Synth", "Vertigo", { "synth", "synph" })
addNpc("Perdido", "Vertigo")
addNpc("The Keeper", "Vertigo", { "thekeeper", "keeper" })
addNpc("??? NPC — Vertigo", "Vertigo", { "unknownnpc", "mysterynpc", "questionmarknpc" })
addNpc("Nick — The Depths", "The Depths", { "nick" })
addNpc("Aspicientis", "The Depths")
addNpc("Occultus", "The Depths")
addNpc("Tenebris", "The Depths")
addNpc("Caleia", "The Arch")
addNpc("Minish", "Harvesters Spike")
addNpc("Roddy", "Desolate Deep")
addNpc("Clarence", "Desolate Deep")
addNpc("Chiseler", "Ancient Isle")
addNpc("Meteoriticist", "Ancient Isle")
addNpc("Pirate", "Ancient Isle")
addNpc("Hiker — Northern Expedition", "Northern Expedition", { "hiker" })
addNpc("Bubble Mermaid", "Grand Reef", { "bubblemermaid" })
addNpc("Captain Neptune", "Grand Reef", { "captainneptune", "captainneptunenpc" })
addNpc("Spirit of Ares", "Atlantis")
addNpc("Spirit of Apollo", "Atlantis")
addNpc("Spirit of Athena", "Atlantis")
addNpc("Spirit of Hades", "Atlantis")
addNpc("Spirit of Nyx", "Atlantis")
addNpc("Spirit of Poseidon", "Atlantis")
addNpc("Spirit of Zeus", "Atlantis")
addNpc("Spirit of Cronus", "Atlantis")
addNpc("Fabulous Deity", "Calm Zone", { "fabulousdeity" })
addNpc("Crazy Cat Lady", "Underground Music Venue", { "crazycatlady" })
addNpc("Hollow", "Underground Music Venue")
addNpc("Hex", "Underground Music Venue")
addNpc("Rick", "Underground Music Venue")
addNpc("Buildaroo", "Underground Music Venue")
addNpc("Nick — Underground Music Venue", "Underground Music Venue", { "nick" })
addNpc("Fayelie", "Underground Music Venue")
addNpc("Goth", "Underground Music Venue")
addNpc("Holladay", "Underground Music Venue")
addNpc("Dr. Crookspine", "The Laboratory", { "drcrookspine" })
addNpc("Architect Brickshell", "Oil Rig", { "architectbrickshell" })
addNpc("Construction Sam", "The Laboratory")
addNpc("Construction Jim", "The Laboratory")
addNpc("Construction Steel", "The Laboratory")
addNpc("Brother Silas", "Moosewood")
addNpc("Marley", "Moosewood")
addNpc("Willow", "Moosewood")
addNpc("Sage", "Moosewood")
addNpc("Clover McRich", "Moosewood", { "clovermcrich" })
addNpc("Ringo", "Moosewood")
addNpc("Easter Bunny", "Sunstone Island", { "easterbunny" })
addNpc("The Dreamer's Eye", "Moosewood", { "thedreamerseye", "dreamerseye" })
addNpc("Dr. Finneus", "Roslit Bay", { "drfinneus" })
addNpc("Valentine's Day NPC", "Sweetheart Shores", { "valentinesdaynpc", "valentinenpc" })
addNpc("Santa", "Winter Village", { "santa", "santaclaus" })
addNpc("Runaway Elf", "Winter Village", { "runawayelf" })
addNpc("Tom Elf", "Moosewood", { "tomelf" })
addNpc("Ben Elf", "Winter Village", { "benelf" })
addNpc("Autumn Elf", "Winter Village", { "autumnelf" })
addNpc("Town Mayor", "Winter Village", { "townmayor" })
addNpc("Pilgrim", "Moosewood")
addNpc("Beatrix", "Moosewood", { "beatrix", "witchnpc" })

for _, island in ipairs({ "Moosewood", "Roslit Bay", "Snowcap Island", "Sunstone Island", "Terrapin Island", "Mushgrove Swamp", "Forsaken Shores" }) do
    for _, role in ipairs({ "Merchant", "Angler", "Shipwright", "Inn Keeper" }) do
        addNpc(role, island, role == "Inn Keeper" and { "innkeeper", "beachkeeper" } or { role, role .. "npc" })
    end
end
local NpcsByIsland = {}
local NpcAliasRegions = {}
for _, entry in ipairs(NpcDirectory) do
    local island = entry.Region or "Nearby / Travelling"
    NpcsByIsland[island] = NpcsByIsland[island] or {}
    NpcsByIsland[island][entry.Name] = entry
    for _, alias in ipairs(entry.Aliases) do
        local key = normalizeNpcText(alias)
        NpcAliasRegions[key] = NpcAliasRegions[key] or {}
        NpcAliasRegions[key][island] = true
    end
end
local Islands = {}
for island in pairs(NpcsByIsland) do table.insert(Islands, island) end
table.sort(Islands)
local SelectedIsland = "Moosewood"
local SelectedNpcName
local markSelectedNpc
local NpcDropdown
local MarkingNpc = false
local NpcTargetParagraph = GPSTab:Paragraph({ Title = "NPC Waypoint", Desc = "Select an island and NPC.", Image = "map-pin", ImageSize = 18 })
local function npcOptions(island)
    local values = { "Select NPC" }
    local names = {}
    for name in pairs(NpcsByIsland[island] or {}) do table.insert(names, name) end
    table.sort(names)
    for _, name in ipairs(names) do table.insert(values, name) end
    return values
end
GPSTab:Dropdown({
    Title = "Island", Values = Islands, Value = SelectedIsland, SearchBarEnabled = true,
    Callback = function(value)
        if not NpcsByIsland[value] then return end
        SelectedIsland = value
        SelectedNpcName = nil
        NpcTargetParagraph:SetDesc(value .. " — select an NPC.")
        if NpcDropdown then
            NpcDropdown.Value = "Select NPC"
            NpcDropdown:Refresh(npcOptions(value))
        end
    end,
})
NpcDropdown = GPSTab:Dropdown({
    Title = "NPC", Values = npcOptions(SelectedIsland), Value = "Select NPC", SearchBarEnabled = true,
    Callback = function(value)
        SelectedNpcName = NpcsByIsland[SelectedIsland][value] and value or nil
        if SelectedNpcName and markSelectedNpc then task.defer(markSelectedNpc) end
    end,
})

-- Known NPC land positions from Fisch Wiki /shipwright/, /merchant/, /innkeeper/.
local NpcCoordinateFallbacks = {
    ["Moosewood"] = { Shipwright = Vector3.new(360,135,260), Merchant = Vector3.new(466,151,225), ["Inn Keeper"] = Vector3.new(487,151,231), Pierre = Vector3.new(390,135,200) },
    ["Roslit Bay"] = { Shipwright = Vector3.new(-1455,135,740), Merchant = Vector3.new(-1454,133,675), ["Inn Keeper"] = Vector3.new(-1512,133,631), Alfie = Vector3.new(-1510,140,760) },
    ["Sunstone Island"] = { Shipwright = Vector3.new(-945,130,-1115), Merchant = Vector3.new(-930,130,-1105), ["Inn Keeper"] = Vector3.new(-904,130,-1104) },
    ["Snowcap Island"] = { Shipwright = Vector3.new(2615,135,2400), Merchant = Vector3.new(2717,157,2374), ["Inn Keeper"] = Vector3.new(2660,155,2395) },
    ["Mushgrove Swamp"] = { Shipwright = Vector3.new(2455,130,-665) },
    ["Terrapin Island"] = { Shipwright = Vector3.new(-190,130,1925) },
    ["Forsaken Shores"] = { Shipwright = Vector3.new(-2480,135,1540), Merchant = Vector3.new(-2509,135,1582), ["Inn Keeper"] = Vector3.new(-2476,133,1573) },
    ["Ancient Isle"] = { Shipwright = Vector3.new(5869,143,7), Merchant = Vector3.new(6080,195,309), ["Inn Keeper"] = Vector3.new(6074,198,335) },
    ["Statue of Sovereignty"] = { Shipwright = Vector3.new(25,135,-1010) },
    ["Grand Reef"] = { Shipwright = Vector3.new(-3600,143,476) },
    ["The Depths"] = { Merchant = Vector3.new(958,-711,1263) },
    ["Vertigo"] = { Synth = Vector3.new(-139.8,-515.2,1138.3) },
}
local NpcModelCache = { Until = 0, Models = {} }
local function indexedNpcModels()
    if os.clock() < NpcModelCache.Until then return NpcModelCache.Models end
    local models, pending, cursor = {}, Workspace:GetChildren(), 1
    local deadline = os.clock() + 0.001
    while cursor <= #pending do
        if not GPSRunning then return {} end
        local instance = pending[cursor]
        cursor = cursor + 1
        if instance:IsA("Model") then table.insert(models, instance) end
        if not instance:IsA("BasePart") then
            for _, child in ipairs(instance:GetChildren()) do table.insert(pending, child) end
        end
        if cursor % 160 == 0 or os.clock() >= deadline then task.wait(); deadline = os.clock() + 0.001 end
    end
    NpcModelCache.Models, NpcModelCache.Until = models, os.clock() + 5
    return models
end

local function getNpcWorldPosition(instance)
    if instance:IsA("BasePart") then return instance.Position end
    local root = instance:FindFirstChild("HumanoidRootPart") or instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
    return root and root.Position or nil
end

local function findNpcTarget(entry)
    local currentPosition = getCurrentPosition()
    local bestInstance, bestScore
    local wantedRegion = normalizeNpcText(entry.Region)
    local regionPositions = {}
    local candidates = {}
    local descendants = indexedNpcModels()
    for index, instance in ipairs(descendants) do
        if not GPSRunning then return nil end
        if index % 500 == 0 then task.wait() end
        if instance:IsA("Model") and instance:IsDescendantOf(Workspace) and not instance:FindFirstAncestorOfClass("Tool") and not Players:GetPlayerFromCharacter(instance) then
            local key = normalizeNpcText(instance.Name)
            local score = 0
            local matchedAlias
            for _, alias in ipairs(entry.Aliases) do
                local aliasKey = normalizeNpcText(alias)
                if key == aliasKey or key == aliasKey .. "npc" or key == aliasKey .. "model" then
                    score, matchedAlias = 120, aliasKey
                    break
                end
            end
            if wantedRegion ~= "" and (key == wantedRegion or key == wantedRegion .. "island") then
                local root = instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
                if root then table.insert(regionPositions, root.Position) end
            end
            if score > 0 and getNpcWorldPosition(instance) then
                table.insert(candidates, { Instance = instance, Score = score, Alias = matchedAlias })
            end
        end
    end
    for _, candidate in ipairs(candidates) do
        local instance = candidate.Instance
        local position = getNpcWorldPosition(instance)
        local path = normalizeNpcText(instance:GetFullName())
        local inRegion = wantedRegion == "" or string.find(path, wantedRegion, 1, true) ~= nil
        local explicitlyElsewhere = false
        if not inRegion then
            for island in pairs(NpcsByIsland) do
                if island ~= "Nearby / Travelling" and island ~= entry.Region
                    and string.find(path, normalizeNpcText(island), 1, true) then
                    explicitlyElsewhere = true
                    break
                end
            end
        end
        if not inRegion and not explicitlyElsewhere then
            for _, regionPosition in ipairs(regionPositions) do
                if (position - regionPosition).Magnitude <= 1200 then inRegion = true; break end
            end
            if not inRegion then
                local regionCount = 0
                for _ in pairs(NpcAliasRegions[candidate.Alias] or {}) do regionCount = regionCount + 1 end
                -- A unique named NPC needs no island folder in the game tree.
                -- Shared roles such as Merchant still require a region match.
                inRegion = regionCount == 1
            end
        end
        -- Do not silently point to a different island's NPC with the same name.
        if inRegion then
            local score = candidate.Score
            if currentPosition then score = score - (position - currentPosition).Magnitude / 100000 end
            if not bestScore or score > bestScore then bestInstance, bestScore = instance, score end
        end
    end
    return bestInstance
end

markSelectedNpc = function()
        if MarkingNpc then return end
        local entry = SelectedNpcName and NpcsByIsland[SelectedIsland][SelectedNpcName]
        if not entry then gpsNotice("Select an island and NPC first."); return end
        MarkingNpc = true
        NpcTargetParagraph:SetDesc("Finding " .. entry.Name .. "...")
        local ok, target = pcall(findNpcTarget, entry)
        MarkingNpc = false
        if not GPSRunning then return end
        if SelectedNpcName ~= entry.Name or (entry.Region and SelectedIsland ~= entry.Region) then
            task.defer(markSelectedNpc)
            return
        end
        local position = ok and target and getNpcWorldPosition(target)
        local region = NpcCoordinateFallbacks[entry.Region]
        local fallback = not position and region and region[entry.Name]
        position = position or fallback
        if not position then
            NpcTargetParagraph:SetDesc(entry.Name .. " — not loaded in " .. (entry.Region or "the nearby world") .. ".")
            return
        end
        WaypointVisible = true
        markPoint(entry.Name .. " — " .. (entry.Region or "Nearby"), position)
        if WaypointToggle then WaypointToggle:Set(true) end
        NpcTargetParagraph:SetDesc(entry.Name .. (fallback and " — Wiki coordinates" or " — Live position") .. "\n" .. formatCoordinates(SavedMainPoint))
end
GPSTab:Button({ Title = "Mark Selected NPC", Icon = "locate-fixed", Callback = markSelectedNpc })
end

refreshMainPointDisplay()
refreshWaypoint()
onCleanup(function()
    GPSRunning = false
    Runtime.MarkGPSPoint = nil
    if WaypointMarker then WaypointMarker:Destroy(); WaypointMarker = nil end
end)
task.spawn(function()
    local previousText
    while GPSRunning do
        local position = getCurrentPosition()
        local text = position and formatCoordinates(position) or "Character not loaded."
        if text ~= previousText then CurrentLocationParagraph:SetDesc(text); previousText = text end
        if WaypointMarker and position and SavedMainPoint then
            local billboard = WaypointMarker:FindFirstChild("WaypointBillboard")
            local label = billboard and billboard:FindFirstChild("WaypointName")
            if label then label.Text = MainPointName .. string.format("\n%.0f studs", (position - SavedMainPoint).Magnitude) end
        end
        task.wait(0.5)
    end
end)
end

do
local Workflow: { [string]: any } = { Running = true, Busy = false, Generation = 0 }
local function plain(value) return tostring(value or ""):gsub("<[^>]->", ""):lower():gsub("%s+", " "):match("^%s*(.-)%s*$") end
local function visible(instance)
    local current = instance
    while current do
        local name = plain(current.Name)
        if name:find("windui", 1, true) or name:find("bootlean", 1, true) then return false end
        if current:IsA("GuiObject") and not current.Visible then return false end
        if current:IsA("ScreenGui") and not current.Enabled then return false end
        current = current.Parent
    end
    return true
end

Runtime.ActivateGuiButton = function(button)
    if not button or not button.Parent or not button:IsA("GuiButton") or not visible(button) then return false end
    for _, name in ipairs({ "MouseButton1Click", "Activated" }) do
        local signal = button[name]
        local known, listeners = false, {}
        if type(getconnections) == "function" then
            local ok, result = pcall(getconnections, signal)
            if ok and type(result) == "table" then known, listeners = true, result end
        end
        local enabled = {}
        for _, connection in ipairs(listeners) do
            local ok, active = pcall(function() return connection.Enabled ~= false end)
            if ok and active then table.insert(enabled, connection) end
        end
        if not known or #enabled > 0 then
            if type(firesignal) == "function" then
                local ok = pcall(firesignal, signal)
                if ok then return true end
            else
                local sent = false
                for _, connection in ipairs(enabled) do sent = pcall(function() connection:Fire() end) or sent end
                if sent then return true end
            end
        end
    end
    local focused = GameWindowFocused
    pcall(function() focused = UserInputService:IsWindowFocused() end)
    if not focused then return false end
    local x = button.AbsolutePosition.X + button.AbsoluteSize.X / 2
    local y = button.AbsolutePosition.Y + button.AbsoluteSize.Y / 2
    return pcall(function()
        local input = game:GetService("VirtualInputManager")
        input:SendMouseButtonEvent(x,y,0,true,game,0)
        task.wait(0.03)
        input:SendMouseButtonEvent(x,y,0,false,game,0)
    end)
end

local function rootAndHumanoid()
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if humanoid and root and humanoid.Health > 0 then return root, humanoid, character end
    return nil
end
local function instancePosition(instance)
    if not instance then return nil end
    if instance:IsA("BasePart") then return instance.Position end
    if instance:IsA("Attachment") then return instance.WorldPosition end
    if instance:IsA("Model") then return instance:GetPivot().Position end
    return instancePosition(instance.Parent)
end
local function interact(prompt, click)
    local root = rootAndHumanoid()
    if not root then return false end
    if prompt and prompt.Parent and prompt.Enabled then
        local position = instancePosition(prompt.Parent)
        if not position or (root.Position - position).Magnitude > prompt.MaxActivationDistance + 2 then return false end
        if type(fireproximityprompt) == "function" then return pcall(fireproximityprompt, prompt) end
        return pcall(function() prompt:InputHoldBegin(); task.wait(math.min(3, prompt.HoldDuration) + 0.1); prompt:InputHoldEnd() end)
    end
    if click and click.Parent and type(fireclickdetector) == "function" then
        local position = instancePosition(click.Parent)
        if position and (root.Position - position).Magnitude <= click.MaxActivationDistance + 2 then return pcall(fireclickdetector, click) end
    end
    return false
end
Runtime.InteractWorldPrompt = interact

local function scanTree(root, callback, limit)
    local queue, cursor = root and root:GetChildren() or {}, 1
    local deadline = os.clock() + 0.001
    while cursor <= #queue and cursor <= (limit or 30000) and Workflow.Running do
        local instance = queue[cursor]; cursor = cursor + 1
        if callback(instance) == false then return end
        if not instance:IsA("BasePart") and not instance:IsA("TextLabel") then
            for _, child in ipairs(instance:GetChildren()) do table.insert(queue, child) end
        elseif instance:IsA("BasePart") then
            for _, child in ipairs(instance:GetChildren()) do
                if child:IsA("ProximityPrompt") or child:IsA("ClickDetector") then callback(child) end
            end
        end
        if cursor % 80 == 0 or os.clock() >= deadline then task.wait(); deadline = os.clock() + 0.001 end
    end
end
local function guiTexts()
    local result = {}
    local gui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    scanTree(gui, function(instance)
        if (instance:IsA("TextLabel") or instance:IsA("TextButton")) and visible(instance) then
            table.insert(result, { Instance = instance, Text = plain(instance.Text) })
        end
    end, 6000)
    return result
end
local function buttonFor(instance)
    for _ = 1, 4 do
        if not instance then return nil end
        if instance:IsA("GuiButton") then return instance end
        if instance:IsA("ScreenGui") then return nil end
        instance = instance.Parent
    end
    return nil
end
local function scopedText(instance, maxNodes)
    local texts, queue, cursor = {}, instance and instance:GetChildren() or {}, 1
    while cursor <= #queue and cursor <= (maxNodes or 80) do
        local child = queue[cursor]; cursor = cursor + 1
        if (child:IsA("TextLabel") or child:IsA("TextButton")) and visible(child) then table.insert(texts, plain(child.Text)) end
        if not child:IsA("TextLabel") then for _, item in ipairs(child:GetChildren()) do table.insert(queue, item) end end
    end
    return table.concat(texts, " ")
end
local function dialogText(button)
    local ancestor = button and button.Parent
    for _ = 1, 5 do
        if not ancestor or ancestor:IsA("ScreenGui") then break end
        local name = plain(ancestor.Name)
        if name:find("dialog", 1, true) or name:find("confirm", 1, true)
            or name:find("purchase", 1, true) or name:find("goblin", 1, true) then
            return scopedText(ancestor, 100)
        end
        ancestor = ancestor.Parent
    end
    return ""
end
local function beginWorkflow()
    if Workflow.Busy or Config.AutomationBusy or Config.TeleportBusy or Config.AquariumBusy then return false, "Another automatic action is running." end
    if Config.Enabled or Busy or ReelController.ActiveReel or hasBobber(getEquippedRod()) or getActiveShakeUI() then return false, "Finish fishing and switch Auto Fish off first." end
    if not rootAndHumanoid() then return false, "Character is not ready." end
    Workflow.Busy = true
    Workflow.Owner = Workflow.Generation
    Config.AutomationBusy = true
    return true
end
local function finishWorkflow(generation)
    if generation and Workflow.Owner ~= generation then return end
    Workflow.Busy = false
    Config.AutomationBusy = false
    local root, humanoid = rootAndHumanoid()
    if root and humanoid then humanoid:Move(Vector3.zero, false); humanoid:MoveTo(root.Position) end
end

-- Purchases use only real, loaded rod purchase prompts with a readable C$ price.
TeleportTab:Section({ Title = "Rod Purchase Route (Beta)" })
local Rods, RodSelection = {}, {}
local RodBudget = 50000
local RodDropdown
local RodStatus = TeleportTab:Paragraph({ Title = "Rod Purchases", Desc = "Scan to find buyable rods in the loaded world.", Image = "fish", ImageSize = 18 })
local function readPrice(instance)
    local text = ""
    pcall(function() text = tostring(instance.ActionText or "") .. " " .. tostring(instance.ObjectText or "") end)
    local listed = text:match("([%d,%.]+)%s*[cC]%$") or text:match("[cC]%$%s*([%d,%.]+)")
    if listed then local value = tonumber((listed:gsub(",", ""))); if value then return value end end
    local current = instance
    for _ = 1, 4 do
        if not current or current == Workspace then break end
        for _, key in ipairs({ "Price", "Cost", "BuyPrice" }) do
            local value = tonumber(current:GetAttribute(key))
            local child = current:FindFirstChild(key)
            if not value and child and child:IsA("ValueBase") then pcall(function() value = tonumber(child.Value) end) end
            if value and value >= 0 and value < 1000000000 then return value end
        end
        current = current.Parent
    end
    return nil
end
local function ownedRod(name)
    for _, container in pairs({ LocalPlayer:FindFirstChildOfClass("Backpack"), LocalPlayer.Character }) do
        if container and container:FindFirstChild(name) then return true end
    end
    for _, folderName in ipairs({ "Rods", "rods", "OwnedRods" }) do
        local folder = LocalPlayer:FindFirstChild(folderName, true)
        local owned = folder and folder:FindFirstChild(name)
        if owned then
            local ok, value = pcall(function() return owned.Value end)
            if not ok or value ~= false then return true end
        end
    end
    return false
end
local function cashBalance()
    if Runtime.ReadPlayerStat then
        local value = Runtime.ReadPlayerStat({ "coins", "Cash", "Coins", "Money", "C$" })
        if value then return value end
    end
    for _, key in ipairs({ "Cash", "Coins", "Money", "C$" }) do
        local value = tonumber(LocalPlayer:GetAttribute(key))
        if value then return value end
        for _, folderName in ipairs({ "leaderstats", "stats" }) do
            local folder = LocalPlayer:FindFirstChild(folderName)
            local child = folder and (folder:FindFirstChild(key) or folder:FindFirstChild(key:lower()))
            if child and child:IsA("ValueBase") then local ok, number = pcall(function() return tonumber(child.Value) end); if ok and number then return number end end
        end
    end
    return nil
end
local WikiRods = {
    { Name = "Training Rod", Price = 300, Island = "Moosewood", Source = "https://fisch.wiki/wiki/training-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Plastic Rod", Price = 750, Island = "Moosewood", Source = "https://fisch.wiki/wiki/plastic-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Carbon Rod", Price = 2000, Island = "Moosewood", Source = "https://fisch.wiki/wiki/carbon-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Long Rod", Price = 3000, Island = "Moosewood", Source = "https://fisch.wiki/wiki/long-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Fast Rod", Price = 4000, Island = "Moosewood", Source = "https://fisch.wiki/wiki/fast-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Lucky Rod", Price = 4500, Island = "Moosewood", Source = "https://fisch.wiki/wiki/lucky-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Stone Rod", Price = 2000, Island = "Ancient Isles", Source = "https://fisch.wiki/wiki/stone-rod/", Position = Vector3.new(5502.1, 146.7, -315.9), LocationKind = "Rod island", Unavailable = false, Crafted = false },
    { Name = "Phoenix Rod", Price = 50000, Island = "Ancient Isles", Source = "https://fisch.wiki/wiki/phoenix-rod/", Position = Vector3.new(5971, 273, 852), LocationKind = "Rod cave", Unavailable = false, Crafted = false },
    { Name = "Steady Rod", Price = 7000, Island = "Roslit Bay", Source = "https://fisch.wiki/wiki/steady-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Fortune Rod", Price = 11000, Island = "Roslit Bay", Source = "https://fisch.wiki/wiki/fortune-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Rapid Rod", Price = 12000, Island = "Roslit Bay", Source = "https://fisch.wiki/wiki/rapid-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Spiritbinder", Price = 500000, Island = "Ancient Archives", Source = "https://fisch.wiki/wiki/spiritbinder/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = true },
    { Name = "Evil Pitchfork", Price = 2500000, Island = "Ancient Archives", Source = "https://fisch.wiki/wiki/evil-pitchfork/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = true },
    { Name = "Elder Mossripper", Price = 350000, Island = "Ancient Archives", Source = "https://fisch.wiki/wiki/elder-mossripper/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = true },
    { Name = "Toxic Spire Rod", Price = 170000, Island = "Ancient Archives", Source = "https://fisch.wiki/wiki/toxic-spire-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Vineweaver Rod", Price = 150000, Island = "Ancient Archives", Source = "https://fisch.wiki/wiki/vineweaver-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = true },
    { Name = "Frog Rod", Price = 12000, Island = "Mushgrove Swamp", Source = "https://fisch.wiki/wiki/frog-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Magnet Rod", Price = 15000, Island = "Terrapin Island", Source = "https://fisch.wiki/wiki/magnet-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Wildflower Rod", Price = 7000, Island = "Terrapin Island", Source = "https://fisch.wiki/wiki/wildflower-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Eidolon Rod", Price = 2000000, Island = "Cultist Lair", Source = "https://fisch.wiki/wiki/eidolon-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Dreambreaker", Price = 5000000, Island = "Cultist Lair", Source = "https://fisch.wiki/wiki/dreambreaker/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Nocturnal Rod", Price = 11000, Island = "Vertigo", Source = "https://fisch.wiki/wiki/nocturnal-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Aurora Rod", Price = 70000, Island = "Vertigo", Source = "https://fisch.wiki/wiki/aurora-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Arctic Rod", Price = 25000, Island = "Northern Summit", Source = "https://fisch.wiki/wiki/arctic-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Ice Warpers Rod", Price = 65000, Island = "Northern Summit", Source = "https://fisch.wiki/wiki/ice-warpers-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Avalanche Rod", Price = 35000, Island = "Overgrowth Caves", Source = "https://fisch.wiki/wiki/avalanche-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Crystalized Rod", Price = 35000, Island = "Frigid Cavern", Source = "https://fisch.wiki/wiki/crystalized-rod/", Position = Vector3.new(19241, 410, 6037), LocationKind = "Rod — puzzle required", Unavailable = false, Crafted = false },
    { Name = "Summit Rod", Price = 500000, Island = "Frigid Cavern", Source = "https://fisch.wiki/wiki/summit-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Scurvy Rod", Price = 40000, Island = "Forsaken Shores", Source = "https://fisch.wiki/wiki/scurvy-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Tempest Rod", Price = 500000, Island = "Atlantis", Source = "https://fisch.wiki/wiki/tempest-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Abyssal Specter Rod", Price = 850000, Island = "Ethereal Abyss", Source = "https://fisch.wiki/wiki/abyssal-specter-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Poseidon Rod", Price = 700000, Island = "Poseidon Temple", Source = "https://fisch.wiki/wiki/poseidon-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Zeus Rod", Price = 850000, Island = "Zeus's Rod Room", Source = "https://fisch.wiki/wiki/zeus-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Kraken Rod", Price = 950000, Island = "Kraken Pool", Source = "https://fisch.wiki/wiki/kraken-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Depthseeker Rod", Price = 40000, Island = "Atlantis (Main)", Source = "https://fisch.wiki/wiki/depthseeker-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Champions Rod", Price = 90000, Island = "Atlantis (Main)", Source = "https://fisch.wiki/wiki/champions-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Reinforced Rod", Price = 20000, Island = "Desolate Deep", Source = "https://fisch.wiki/wiki/reinforced-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "The Boom Ball", Price = 50000, Island = "Desolate Deep", Source = "https://fisch.wiki/wiki/the-boom-ball/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Thalassar's ruin", Price = 14500000, Island = "Tidefall", Source = "https://fisch.wiki/wiki/thalassars-ruin/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Midas Rod", Price = 55000, Island = "Travelling Merchant", Source = "https://fisch.wiki/wiki/midas-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Mythical Rod", Price = 90000, Island = "Travelling Merchant", Source = "https://fisch.wiki/wiki/mythical-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Kings Rod", Price = 100000, Island = "Keepers Altar", Source = "https://fisch.wiki/wiki/kings-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Brick Rod", Price = 13337, Island = "Minish", Source = "https://fisch.wiki/wiki/brick-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Carrot Rod", Price = 75000, Island = "Carrot Garden", Source = "https://fisch.wiki/wiki/carrot-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Trident Rod", Price = 150000, Island = "Tridents Temple", Source = "https://fisch.wiki/wiki/trident-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Volcanic Rod", Price = 250000, Island = "Volcanic Vents", Source = "https://fisch.wiki/wiki/volcanic-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Rainbow Cluster Rod", Price = 250000, Island = "Castaway Cliffs", Source = "https://fisch.wiki/wiki/rainbow-cluster-rod/", Position = Vector3.new(460, 204, -1960), LocationKind = "Cave entrance — Rainbow event required", Unavailable = false, Crafted = false },
    { Name = "Great Dreamer Rod", Price = 700000, Island = "Cursed Isle", Source = "https://fisch.wiki/wiki/great-dreamer-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Rod Of The Depths", Price = 750000, Island = "The Depths", Source = "https://fisch.wiki/wiki/rod-of-the-depths/", Position = Vector3.new(1689.9, -902.4, 1437.7), LocationKind = "Rod — relic gates required", Unavailable = false, Crafted = false },
    { Name = "Destiny Rod", Price = 190000, Island = "Caleia at The Arch", Source = "https://fisch.wiki/wiki/destiny-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Scarlet Spincaster Rod", Price = 180000, Island = "Crimson Cavern", Source = "https://fisch.wiki/wiki/scarlet-spincaster-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = true },
    { Name = "Wicked Fang Rod", Price = 400000, Island = "Crimson Cavern", Source = "https://fisch.wiki/wiki/wicked-fang-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Ruinous Oath", Price = 5000000, Island = "Crimson Cavern", Source = "https://fisch.wiki/wiki/ruinous-oath/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Challenger's Rod", Price = 750000, Island = "Challenger's Deep", Source = "https://fisch.wiki/wiki/challengers-rod/", Position = Vector3.new(738, -3355, -1529), LocationKind = "Rod — deep area access required", Unavailable = false, Crafted = false },
    { Name = "Great Rod of Oscar", Price = 2500000, Island = "Oscar's Locker", Source = "https://fisch.wiki/wiki/great-rod-of-oscar/", Position = Vector3.new(499, -70, 4107), LocationKind = "Gate — Amulet required", Unavailable = false, Crafted = false },
    { Name = "Luminescent Oath", Price = 1000000, Island = "Luminescent Cavern", Source = "https://fisch.wiki/wiki/luminescent-oath/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Cerulean Fang Rod", Price = 800000, Island = "Luminescent Cavern", Source = "https://fisch.wiki/wiki/cerulean-fang-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Heaven's Rod", Price = 1750000, Island = "Glacial Grotto", Source = "https://fisch.wiki/wiki/heavens-rod/", Position = Vector3.new(19980, 916, 5384), LocationKind = "Vault — energy crystals required", Unavailable = false, Crafted = false },
    { Name = "Duskwire", Price = 500000, Island = "Underground Music Venue", Source = "https://fisch.wiki/wiki/duskwire/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Ethereal Prism Rod", Price = 3500000, Island = "Calm Zone", Source = "https://fisch.wiki/wiki/ethereal-prism-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Rod Of The Zenith", Price = 1500000, Island = "Abyssal Zenith", Source = "https://fisch.wiki/wiki/rod-of-the-zenith/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Tryhard Rod", Price = 100000000, Island = "RoRed", Source = "https://fisch.wiki/wiki/tryhard-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Cinder Block Rod", Price = 50000, Island = "The Laboratory", Source = "https://fisch.wiki/wiki/cinder-block-rod/", Position = Vector3.new(-1970, 260, -530), LocationKind = "Rod", Unavailable = false, Crafted = false },
    { Name = "Astraeus Serenade", Price = 50000000, Island = "Astraeus' Void", Source = "https://fisch.wiki/wiki/astraeus-serenade/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = true, Crafted = false },
    { Name = "Gingerbread Rod", Price = 5000, Island = "Fischmas 2", Source = "https://fisch.wiki/wiki/gingerbread-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Necrotic Rod", Price = 660000, Island = "FischFright 2", Source = "https://fisch.wiki/wiki/necrotic-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Paper Fan Rod", Price = 70000, Island = "Fischfest", Source = "https://fisch.wiki/wiki/paper-fan-rod/", Position = Vector3.new(990, 174, 9855), LocationKind = "Historical rod location", Unavailable = true, Crafted = false },
    { Name = "Polaris Serenade", Price = 50000000, Island = "Crystal Cove update", Source = "https://fisch.wiki/wiki/polaris-serenade/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = true, Crafted = false },
    { Name = "Candy Cane Rod", Price = 1500, Island = "Fischmas 1", Source = "https://fisch.wiki/wiki/candy-cane-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = true, Crafted = true },
    { Name = "Relic Rod", Price = 8000, Island = "The Archaeological Hunt", Source = "https://fisch.wiki/wiki/relic-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = true, Crafted = false },
    { Name = "Original No-Life Rod", Price = 1, Island = "Admin Event", Source = "https://fisch.wiki/wiki/original-no-life-rod/", Position = Vector3.new(376, 135, 196), LocationKind = "Rod — Admin event required", Unavailable = false, Crafted = false },
    { Name = "Frostbane Rod", Price = 1500000, Island = "Admin Event", Source = "https://fisch.wiki/wiki/frostbane-rod/", Position = Vector3.new(19895, 637, 5730), LocationKind = "Rod — Snowstorm required", Unavailable = false, Crafted = false },
    { Name = "Sanguine Spire", Price = 10000000, Island = "Admin Event", Source = "https://fisch.wiki/wiki/sanguine-spire/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Katana Rod", Price = 1000000, Island = "Black Market", Source = "https://fisch.wiki/wiki/katana-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Sword of Darkness", Price = 50000000, Island = "Black Market", Source = "https://fisch.wiki/wiki/sword-of-darkness/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = true, Crafted = false },
    { Name = "Electric Guitar", Price = 14444444, Island = "Black Market", Source = "https://fisch.wiki/wiki/electric-guitar/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = true, Crafted = false },
    { Name = "Upside-Down Rod", Price = 15000, Island = "Black Market", Source = "https://fisch.wiki/wiki/upside-down-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Bone Blade", Price = 2500000, Island = "Black Market", Source = "https://fisch.wiki/wiki/bone-blade/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
    { Name = "Moonlit Rod", Price = 75, Island = "Black Market", Source = "https://fisch.wiki/wiki/moonlit-rod/", LocationKind = "Live position required; island arrival is approximate.", Unavailable = false, Crafted = false },
}
local WikiByName, WikiNames = {}, {}
for _, rod in ipairs(WikiRods) do WikiByName[plain(rod.Name)] = rod; table.insert(WikiNames, rod.Name) end
table.sort(WikiNames)
local function scanRods()
    scanTree(Workspace, function(instance)
        local isPrompt, isClick = instance:IsA("ProximityPrompt"), instance:IsA("ClickDetector")
        if not isPrompt and not isClick then return end
        if (isPrompt and not instance.Enabled) or (isClick and instance.MaxActivationDistance <= 0) then return end
        local action = isPrompt and plain(instance.ActionText) or "buy"
        if not action:find("buy", 1, true) and not action:find("purchase", 1, true) then return end
        local name = isPrompt and tostring(instance.ObjectText or "") or ""
        local parent = instance.Parent
        if not plain(name):find("rod", 1, true) and not WikiByName[plain(name)] then
            for _ = 1, 4 do
                if not parent or parent == Workspace then break end
                if plain(parent.Name):find("rod", 1, true) or WikiByName[plain(parent.Name)] then name = parent.Name; break end
                parent = parent.Parent
            end
        end
        local currency = plain(name .. " " .. action .. " " .. tostring(instance:GetAttribute("Currency") or ""))
        if (not plain(name):find("rod", 1, true) and not WikiByName[plain(name)]) or currency:find("robux", 1, true) or currency:find("r$", 1, true)
            or currency:find("s$", 1, true) or currency:find("e$", 1, true) or currency:find("sunshell", 1, true) then return end
        local listed = WikiByName[plain(name)]
        if listed then name = listed.Name end
        local price, position = readPrice(instance), instancePosition(instance.Parent)
        if price and position then Rods[name] = { Name = name, Price = price, Position = position, Prompt = isPrompt and instance or nil, ClickDetector = isClick and instance or nil } end
    end)
    local names, total = {}, 0
    for name, rod in pairs(Rods) do
        if not ownedRod(name) then table.insert(names, name); total = total + rod.Price end
    end
    table.sort(names)
    RodSelection = names
    if RodDropdown then RodDropdown.Value = names; RodDropdown:Refresh(names) end
    RodStatus:SetDesc(string.format("%d discovered rods — listed total C$ %s\nBudget: C$ %s", #names, tostring(total), tostring(RodBudget)))
    return names
end
TeleportTab:Section({ Title = "Wiki Rod Catalogue" })
local WikiSelected = WikiNames[1]
local WikiRodInfo = TeleportTab:Paragraph({ Title = "Rod Location", Desc = "", Image = "book-open", ImageSize = 18 })
local function showWikiRod()
    local rod = WikiByName[plain(WikiSelected)]
    if not rod then return end
    local live = Rods[rod.Name]
    WikiRodInfo:SetDesc(rod.Name .. " — " .. rod.Island .. "\n" .. (ownedRod(rod.Name) and "Owned" or live and "Live C$ offer found" or rod.Unavailable and "Wiki: unavailable" or rod.Crafted and "Crafting — ingredients required" or "Offer / unlock conditions must be checked in game")
        .. "\n" .. (live and "Live GPS" or rod.LocationKind) .. (live and string.format(": %.1f, %.1f, %.1f", live.Position.X, live.Position.Y, live.Position.Z) or rod.Position and string.format(": %.1f, %.1f, %.1f", rod.Position.X, rod.Position.Y, rod.Position.Z) or "")
        .. "\nWiki list price: " .. tostring(rod.Price) .. " — current price verified before purchase")
end
TeleportTab:Dropdown({ Title = "Wiki Rod", Values = WikiNames, Value = WikiSelected, SearchBarEnabled = true, Callback = function(value)
    if WikiByName[plain(value)] then WikiSelected = value; showWikiRod() end
end })
local function visitWikiRod()
    scanRods()
    local rod = WikiByName[plain(WikiSelected)]
    local live = rod and Rods[rod.Name]
    if not rod then return end
    if rod.Unavailable and not live then WikiRodInfo:SetDesc("Wiki marks this rod unavailable. No live offer is loaded."); return end
    local position = live and live.Position or rod.Position or (Runtime.ResolveIslandPosition and Runtime.ResolveIslandPosition(rod.Island))
    if not position then WikiRodInfo:SetDesc(rod.Name .. " — " .. rod.Island .. "\nNo verified GPS or live offer. Visit the unlocked area and scan; no coordinates were guessed."); return end
    local moved, reason = Runtime.TeleportTo(rod.Name, position)
    if not moved then WikiRodInfo:SetDesc(tostring(reason)); return end
    scanRods(); showWikiRod()
    return rod.Name
end
TeleportTab:Button({ Title = "Teleport to Wiki Rod", Icon = "navigation", Callback = visitWikiRod })
TeleportTab:Button({ Title = "Add Wiki Rod to Purchase Route", Icon = "list-plus", Callback = function()
    local name = visitWikiRod()
    if name and Rods[name] then
        RodSelection = { name }
        if RodDropdown then RodDropdown:Select(RodSelection) end
        WikiRodInfo:SetDesc(name .. " — ready. Use Buy Selected Rods. The live price and budget will be checked.")
    elseif name then WikiRodInfo:SetDesc(name .. " — no readable live C$ offer found. Unlock conditions may be incomplete.") end
end })
showWikiRod()
TeleportTab:Section({ Title = "Live Purchase Route" })
TeleportTab:Button({ Title = "Scan Buyable Rods", Icon = "search", Callback = scanRods })
TeleportTab:Button({ Title = "Scan Rods on All Islands", Icon = "map", Callback = function()
    local allowed, reason = beginWorkflow()
    if not allowed then RodStatus:SetDesc(reason); return end
    local generation = Workflow.Generation
    local ok, err = pcall(function()
        for _, island in ipairs(Runtime.IslandDestinations or {}) do
            if generation ~= Workflow.Generation or Runtime.Closed then break end
            RodStatus:SetDesc("Scanning " .. island.Name .. "...")
            local moved = Runtime.TeleportTo(island.Name, island.Position)
            if moved and generation == Workflow.Generation then scanRods() end
            task.wait(0.3)
        end
        scanRods()
    end)
    finishWorkflow(generation)
    if not ok then RodStatus:SetDesc("Scan stopped: " .. tostring(err):sub(1,160)) end
end })
RodDropdown = TeleportTab:Dropdown({ Title = "Rods to Buy", Values = {}, Multi = true, AllowNone = true, SearchBarEnabled = true, Callback = function(values) RodSelection = type(values) == "table" and values or {} end })
TeleportTab:Input({ Title = "Maximum C$ to Spend", Value = "50000", Callback = function(value)
    local number = tonumber((tostring(value):gsub(",", "")))
    if number and number >= 0 and number <= 1000000000 then RodBudget = math.floor(number) end
end })
local function buyRodRoute(all)
    local allowed, reason = beginWorkflow()
    if not allowed then RodStatus:SetDesc(reason); return end
    local generation, spent, bought = Workflow.Generation, 0, 0
    local ok, err = pcall(function()
        local names = all and scanRods() or table.clone(RodSelection)
        for _, name in ipairs(names) do
            if Runtime.Closed or generation ~= Workflow.Generation then break end
            local rod = Rods[name]
            if not rod or ownedRod(name) then continue end
            if spent + rod.Price > RodBudget then RodStatus:SetDesc("Stopped at the C$ budget."); break end
            local before = cashBalance()
            if before and before < rod.Price then RodStatus:SetDesc("Not enough C$ for " .. name); break end
            RodStatus:SetDesc("Travelling to " .. name .. " — C$ " .. tostring(rod.Price))
            local moved, failure = Runtime.TeleportTo(name, rod.Position)
            if not moved then RodStatus:SetDesc(tostring(failure)); break end
            if generation ~= Workflow.Generation or Runtime.Closed then break end
            scanRods()
            rod = Rods[name]
            if not rod or not ((rod.Prompt and rod.Prompt.Parent and rod.Prompt.Enabled)
                or (rod.ClickDetector and rod.ClickDetector.Parent and rod.ClickDetector.MaxActivationDistance > 0)) then RodStatus:SetDesc(name .. " is no longer available."); break end
            if spent + rod.Price > RodBudget then RodStatus:SetDesc("The current price exceeds the C$ budget."); break end
            if not interact(rod.Prompt, rod.ClickDetector) then RodStatus:SetDesc("Could not interact with " .. name); break end
            local deadline = os.clock() + 4
            local confirmed = false
            local confirmationSent = false
            repeat
                if Runtime.Closed or generation ~= Workflow.Generation then break end
                if ownedRod(name) then confirmed = true; break end
                local after = cashBalance()
                if before and after and before - after >= rod.Price and rod.Price > 0 then confirmed = true; break end
                for _, entry in ipairs(confirmationSent and {} or guiTexts()) do
                    local button = buttonFor(entry.Instance)
                    if button and (entry.Text == "buy" or entry.Text == "purchase" or entry.Text == "yes") then
                        local text = dialogText(button)
                        if text:find(plain(name), 1, true) and not text:find("robux", 1, true) and generation == Workflow.Generation then confirmationSent = Runtime.ActivateGuiButton(button); break end
                    end
                end
                task.wait(0.35)
            until os.clock() >= deadline
            if not confirmed then RodStatus:SetDesc("Purchase of " .. name .. " was not confirmed. Route stopped."); break end
            spent, bought = spent + rod.Price, bought + 1
            RodStatus:SetDesc(string.format("Bought %d rods — C$ %s spent", bought, tostring(spent)))
            task.wait(0.4)
        end
    end)
    finishWorkflow(generation)
    if not ok then RodStatus:SetDesc("Route stopped: " .. tostring(err):sub(1, 160)) end
end
TeleportTab:Button({ Title = "Buy Selected Rods", Icon = "shopping-cart", Callback = function() buyRodRoute(false) end })
TeleportTab:Button({ Title = "Buy All Available Rods", Icon = "shopping-cart", Callback = function() buyRodRoute(true) end })
TeleportTab:Button({ Title = "Cancel Rod Route", Icon = "square", Callback = function() Workflow.Generation = Workflow.Generation + 1; RodStatus:SetDesc("Stopping rod route...") end })

onCleanup(function()
    Workflow.Running = false
    Workflow.Generation = Workflow.Generation + 1
    finishWorkflow()
    Runtime.ActivateGuiButton = nil
    Runtime.InteractWorldPrompt = nil
end)
end
Runtime.Trace("Ready")


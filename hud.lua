--[[
================================================================================
                    DEVELOPER AUTO-EXECUTION DOCUMENTATION
================================================================================

For administrative testing, accessibility analysis, or client-side debugging across 
multiple sessions, this script can be configured to load automatically on startup.

HOW TO CONFIGURE AUTO-EXECUTION:
1. Locate the installation directory of your client-side execution or debugging software.
2. Find the folder named 'autoexec' or 'auto-execute' (typically located in the workspace 
   or root directory of your client-side software).
3. Save this entire script as a text file (e.g., 'MasterUtility.lua') inside that folder.
4. When saved in the auto-execute folder, the software will automatically execute this 
   script the exact millisecond the client successfully teleports into a new game 
   instance (such as when using the '!rejoin' command). This ensures persistent visual 
   overrides and UI tracking without requiring manual execution after a server hop.

LIFECYCLE PROTECTION:
This script contains duplicate execution protection. If the script is re-run in the 
same session, it will automatically find, disconnect, and clean up any old visual elements 
and background loops before starting, preventing memory leaks or duplicate rendering lag.
================================================================================
]]

--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local terrain = Workspace:WaitForChild("Terrain")

--------------------------------------------------------------------------------
-- GLOBAL STATE FLAGS, PERSISTENT ARRAYS & CONFIGURATION (GLOBAL SCOPE)
--------------------------------------------------------------------------------
-- Core Functional Toggle Flags
local trackingEnabled = true
local environmentOverridesEnabled = true
local bypassSleepEnabled = true
local fullbrightActive = false
local packDensityActive = true
local carcassScannerActive = true
local rangeFinderActive = true
local rejoinCommandEnabled = true

-- Whitelist Registry (Declared Globally at the very top of the script)
local WhitelistedTable = {}

-- Proximity Alert Debounce Registry (Tracks active alert tier level: 0 to 3)
local triggeredAlerts: {[Model]: number} = {}

-- Biting Range Finder Configuration
local BASE_ATTACK_RANGE = 8 
local rangeSpherePart: Part? = nil

-- Global Caching and Reference Arrays
local potentialTargets = {}
local activeOverlays = {}
local speciesCache = {}
local activeCarcassGuis = {}
local registeredSleepOverlays = {}

-- Target Species Tracking Parameters
local TARGET_ATTRIBUTES = {"Species", "Creature", "DinoType"}
local TARGET_FOLDERS = {"Configuration", "Stats", "Data", "Identity"}
local TARGET_VALUE_NAMES = {"Species", "Type", "Name"}

-- Target Health Tracking Parameters
local ATTRIBUTE_HEALTH = "Health"            
local ATTRIBUTE_MAX_HEALTH = "MaxHealth"      
local VALUE_OBJ_HEALTH = "HealthValue"        
local VALUE_OBJ_MAX_HEALTH = "MaxHealthValue"  

local WEIGHT_DATA_KEY = "Weight"             
local OVERLAY_UI_NAME = "EntityTrackerOverlay"
local MAX_TRACKING_DISTANCE = 10000

--------------------------------------------------------------------------------
-- CACHED ORIGINAL ENVIRONMENTAL SETTINGS
--------------------------------------------------------------------------------
local originalWaterTransparency = terrain.WaterTransparency
local originalWaterReflectance = terrain.WaterReflectance
local originalFogEnd = Lighting.FogEnd
local originalAtmosphereDensities = {}

local originalGlobalShadows = Lighting.GlobalShadows
local originalAmbient = Lighting.Ambient
local originalOutdoorAmbient = Lighting.OutdoorAmbient
local originalBrightness = Lighting.Brightness
local originalClockTime = Lighting.ClockTime

for _, child in ipairs(Lighting:GetChildren()) do
	if child:IsA("Atmosphere") then
		originalAtmosphereDensities[child] = child.Density
	end
end

--------------------------------------------------------------------------------
-- DUP_PREVENTION: CLEANUP OF PRIOR SCRIPT RUNS
--------------------------------------------------------------------------------
local existingUI = playerGui:FindFirstChild("MasterUtilityUI")
if existingUI then
	existingUI:Destroy()
end

if _G.MasterUtilityConnections then
	for connectionName, connection in pairs(_G.MasterUtilityConnections) do
		if typeof(connection) == "RBXScriptConnection" and connection.Connected then
			connection:Disconnect()
		end
	end
end
_G.MasterUtilityConnections = {}

-- Safely purge any residual range-finder parts left over from previous runs
local function clearRangeSphereGlobal()
	local oldSphere = Workspace:FindFirstChild("BiteRangeIndicator")
	if oldSphere then oldSphere:Destroy() end
end
clearRangeSphereGlobal()

--------------------------------------------------------------------------------
-- GRAPHICAL INTERFACE SETUP (Programmatic Creation)
--------------------------------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MasterUtilityUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainPanel"
mainFrame.Size = UDim2.new(0, 240, 0, 280)
mainFrame.Position = UDim2.new(0.05, 0, 0.2, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Parent = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 8)
panelCorner.Parent = mainFrame

-- Header Bar (Handles Dragging)
local headerFrame = Instance.new("Frame")
headerFrame.Name = "Header"
headerFrame.Size = UDim2.new(1, 0, 0, 35)
headerFrame.BackgroundTransparency = 1
headerFrame.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -40, 1, 0)
titleLabel.Position = UDim2.new(0, 10, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Master Utility Panel"
titleLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
titleLabel.TextSize = 14
titleLabel.Font = Enum.Font.SourceSansBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = headerFrame

local minimizeButton = Instance.new("TextButton")
minimizeButton.Size = UDim2.new(0, 25, 0, 25)
minimizeButton.Position = UDim2.new(1, -30, 0, 5)
minimizeButton.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
minimizeButton.Text = "-"
minimizeButton.TextColor3 = Color3.fromRGB(240, 240, 240)
minimizeButton.TextSize = 14
minimizeButton.Font = Enum.Font.SourceSansBold
minimizeButton.Parent = headerFrame

local minButtonCorner = Instance.new("UICorner")
minButtonCorner.CornerRadius = UDim.new(0, 4)
minButtonCorner.Parent = minimizeButton

-- Button List Container (Collapsible ScrollingFrame)
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "Container"
scrollFrame.Size = UDim2.new(1, 0, 1, -35)
scrollFrame.Position = UDim2.new(0, 0, 0, 35)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 380) -- Updated dynamically via Whitelist toggle state
scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 80)
scrollFrame.ScrollBarThickness = 5
scrollFrame.Parent = mainFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.VerticalAlignment = Enum.VerticalAlignment.Top
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scrollFrame

-- Notification Feed Container (Anchored strictly to Bottom-Right corner)
local notificationContainer = Instance.new("Frame")
notificationContainer.Name = "NotificationFeed"
notificationContainer.Size = UDim2.new(0, 320, 0, 300)
notificationContainer.Position = UDim2.new(1, -330, 1, -310)
notificationContainer.BackgroundTransparency = 1
notificationContainer.BorderSizePixel = 0
notificationContainer.Parent = screenGui

local notifListLayout = Instance.new("UIListLayout")
notifListLayout.Padding = UDim.new(0, 5)
notifListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
notifListLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
notifListLayout.Parent = notificationContainer

local function createToggleButton(name: string, defaultText: string, order: number): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.new(1, -20, 0, 32)
	button.BackgroundColor3 = Color3.fromRGB(150, 0, 0) -- Muted dark Red (Default OFF state)
	button.Text = defaultText .. " (OFF)"
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 12
	button.Font = Enum.Font.SourceSansBold
	button.LayoutOrder = order
	button.Parent = scrollFrame

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = button

	return button
end

-- 1. BUTTON TEXT LABEL MAPPING
local trackingBtn = createToggleButton("ToggleTracking", "X-Ray Tracking", 1)
local whitelistBtn = createToggleButton("ToggleWhitelistMenu", "Radar Whitelist Manager", 2)
local packBtn = createToggleButton("TogglePack", "Pack Density Monitor", 3)
local carcassBtn = createToggleButton("ToggleCarcass", "Carcass Analytics", 4)
local rangeBtn = createToggleButton("ToggleRange", "Bite Range Finder", 5)
local fullbrightBtn = createToggleButton("ToggleFullbright", "Fullbright", 6)
local envBtn = createToggleButton("ToggleEnv", "Clear Water & Fog", 7)
local sleepBtn = createToggleButton("ToggleSleep", "Bypass Sleep GUI", 8)

-- Pack Spacing HUD Label (Positions directly below button layout)
local packSpacingHUD = Instance.new("TextLabel")
packSpacingHUD.Name = "PackSpacingHUD"
packSpacingHUD.Size = UDim2.new(1, -20, 0, 20)
packSpacingHUD.BackgroundTransparency = 1
packSpacingHUD.Text = "Pack Density: Off"
packSpacingHUD.TextColor3 = Color3.fromRGB(150, 150, 150)
packSpacingHUD.TextSize = 11
packSpacingHUD.Font = Enum.Font.SourceSansBold
packSpacingHUD.LayoutOrder = 10
packSpacingHUD.Parent = scrollFrame

-- High-Impact Center-Screen Warning Label (Flashes when pack thresholds are breached)
local centerWarning = Instance.new("TextLabel")
centerWarning.Name = "CenterWarningHUD"
centerWarning.Size = UDim2.new(1, 0, 0, 50)
centerWarning.Position = UDim2.new(0, 0, 0.35, 0)
centerWarning.BackgroundTransparency = 1
centerWarning.Text = "WARNING: High Pack Density - Debuff Imminent"
centerWarning.TextColor3 = Color3.fromRGB(220, 0, 0)
centerWarning.TextSize = 20
centerWarning.Font = Enum.Font.SourceSansBold
centerWarning.Visible = false
centerWarning.Parent = screenGui

--------------------------------------------------------------------------------
-- SUBMENU: RADAR WHITELIST MANAGER
--------------------------------------------------------------------------------
local whitelistSectionLabel = Instance.new("TextLabel")
whitelistSectionLabel.Size = UDim2.new(1, -20, 0, 25)
whitelistSectionLabel.BackgroundTransparency = 1
whitelistSectionLabel.Text = "=== RADAR WHITELIST MANAGER ==="
whitelistSectionLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
whitelistSectionLabel.TextSize = 10
whitelistSectionLabel.Font = Enum.Font.SourceSansBold
whitelistSectionLabel.LayoutOrder = 12
whitelistSectionLabel.Parent = scrollFrame

local inputContainer = Instance.new("Frame")
inputContainer.Size = UDim2.new(1, -20, 0, 35)
inputContainer.BackgroundTransparency = 1
inputContainer.LayoutOrder = 13
inputContainer.Parent = scrollFrame

local whitelistInput = Instance.new("TextBox")
whitelistInput.Size = UDim2.new(0.65, -5, 1, 0)
whitelistInput.Position = UDim2.new(0, 0, 0, 0)
whitelistInput.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
whitelistInput.TextColor3 = Color3.fromRGB(240, 240, 240)
whitelistInput.PlaceholderText = "Enter Username/Display..."
whitelistInput.Text = ""
whitelistInput.TextSize = 11
whitelistInput.Font = Enum.Font.SourceSans
whitelistInput.Parent = inputContainer

local inputCorner = Instance.new("UICorner")
inputCorner.CornerRadius = UDim.new(0, 4)
inputCorner.Parent = whitelistInput

local addWhitelistBtn = Instance.new("TextButton")
addWhitelistBtn.Size = UDim2.new(0.35, 0, 1, 0)
addWhitelistBtn.Position = UDim2.new(0.65, 5, 0, 0)
addWhitelistBtn.BackgroundColor3 = Color3.fromRGB(46, 117, 89)
addWhitelistBtn.Text = "Add"
addWhitelistBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
addWhitelistBtn.TextSize = 12
addWhitelistBtn.Font = Enum.Font.SourceSansBold
addWhitelistBtn.Parent = inputContainer

local addCorner = Instance.new("UICorner")
addCorner.CornerRadius = UDim.new(0, 4)
addCorner.Parent = addWhitelistBtn

local whitelistScroll = Instance.new("ScrollingFrame")
whitelistScroll.Size = UDim2.new(1, -20, 0, 80)
whitelistScroll.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
whitelistScroll.BorderSizePixel = 0
whitelistScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
whitelistScroll.ScrollBarThickness = 4
whitelistScroll.LayoutOrder = 14
whitelistScroll.Parent = scrollFrame

local scrollCorner = Instance.new("UICorner")
scrollCorner.CornerRadius = UDim.new(0, 4)
scrollCorner.Parent = whitelistScroll

local listLayoutScroll = Instance.new("UIListLayout")
listLayoutScroll.Padding = UDim.new(0, 4)
listLayoutScroll.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayoutScroll.Parent = whitelistScroll

local autoFillBtn = Instance.new("TextButton")
autoFillBtn.Name = "AutoFillPack"
autoFillBtn.Size = UDim2.new(1, -20, 0, 30)
autoFillBtn.BackgroundColor3 = Color3.fromRGB(45, 65, 95)
autoFillBtn.Text = "Auto-Fill Pack"
autoFillBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
autoFillBtn.TextSize = 12
autoFillBtn.Font = Enum.Font.SourceSansBold
autoFillBtn.LayoutOrder = 15
autoFillBtn.Parent = scrollFrame

local autoCorner = Instance.new("UICorner")
autoCorner.CornerRadius = UDim.new(0, 4)
autoCorner.Parent = autoFillBtn

--------------------------------------------------------------------------------
-- DRAG MECHANICS DESIGN
--------------------------------------------------------------------------------
local dragging, dragInput, dragStart, startPos

headerFrame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = mainFrame.Position

		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
	end
end)

headerFrame.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		dragInput = input
	end
end)

_G.MasterUtilityConnections.DragInput = UserInputService.InputChanged:Connect(function(input)
	if input == dragInput and dragging then
		local delta = input.Position - dragStart
		mainFrame.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
	end
end)

--------------------------------------------------------------------------------
-- STABLE SPATIAL UTILITIES, HELPERS & COMPLEMENTS
--------------------------------------------------------------------------------
local function escapePattern(str: string): string
	return string.gsub(str, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
end

local function isHashOrNumber(str: string): boolean
	if tonumber(str) then return true end
	if string.match(str, "^%x+$") and #str >= 8 then return true end
	if string.match(str, "%-%x+%-%x+%-%x+") then return true end
	return false
end

local function isValidSpeciesCandidate(val: string, modelName: string): boolean
	if type(val) ~= "string" or val == "" then return false end
	local valLower = string.lower(val)
	if valLower == string.lower(modelName) then return false end
	for _, player in ipairs(Players:GetPlayers()) do
		if valLower == string.lower(player.Name) or valLower == string.lower(player.DisplayName) then
			return false
		end
	end
	if isHashOrNumber(val) then return false end
	if string.find(valLower, "loading") or string.find(valLower, "level") then return false end
	return true
end

local function cleanTextLabelString(rawText: string): string?
	local cleaned = rawText
	for _, player in ipairs(Players:GetPlayers()) do
		cleaned = string.gsub(cleaned, escapePattern(player.Name), "")
		cleaned = string.gsub(cleaned, escapePattern(player.DisplayName), "")
	end
	cleaned = string.gsub(cleaned, "%b[]", "")
	cleaned = string.gsub(cleaned, "%b()", "")
	cleaned = string.gsub(cleaned, "[%-%:%|%s]+", " ")
	cleaned = string.gsub(cleaned, "^%s*(.-)%s*$", "%1")
	if cleaned ~= "" and #cleaned > 1 and not string.find(string.lower(cleaned), "level") then
		return cleaned
	end
	return nil
end

local function getPlayerDisplayName(model: Model): string
	local player = Players:FindFirstChild(model.Name)
	if player and player:IsA("Player") then
		return player.DisplayName
	end
	return "Wild/AI"
end

local function getDinoSpecies(model: Model): string
	for _, attrName in ipairs(TARGET_ATTRIBUTES) do
		local val = model:GetAttribute(attrName)
		if type(val) == "string" and val ~= "" then return val end
	end

	for _, folderName in ipairs(TARGET_FOLDERS) do
		local folder = model:FindFirstChild(folderName)
		if folder and (folder:IsA("Folder") or folder:IsA("Configuration") or folder:IsA("Model")) then
			for _, valName in ipairs(TARGET_VALUE_NAMES) do
				local valueObj = folder:FindFirstChild(valName)
				if valueObj and valueObj:IsA("ValueBase") then
					local valStr = tostring(valueObj.Value)
					if valStr ~= "" then return valStr end
				end
			end
		end
	end

	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("TextLabel") then
			local rawText = desc.Text
			if rawText ~= "" and not string.find(string.lower(rawText), "loading") then
				local cleaned = cleanTextLabelString(rawText)
				if cleaned then return cleaned end
			end
		end
	end

	local humanoid = model:FindFirstChildWhichIsA("Humanoid")
	if humanoid then return "Dinosaur" end
	return "Unknown Species"
end

local function getEntityWeight(model: Model): any?
	local attributeValue = model:GetAttribute(WEIGHT_DATA_KEY)
	if attributeValue ~= nil then return attributeValue end
	
	local valueInstance = model:FindFirstChild(WEIGHT_DATA_KEY)
	if valueInstance and valueInstance:IsA("ValueBase") then
		return valueInstance.Value
	end
	return nil
end

local function getEntityHealth(model: Model): (number, number)
	local attrHP = model:GetAttribute(ATTRIBUTE_HEALTH)
	local attrMaxHP = model:GetAttribute(ATTRIBUTE_MAX_HEALTH)
	if type(attrHP) == "number" then
		return attrHP, type(attrMaxHP) == "number" and attrMaxHP or 100
	end

	local hpValObj = model:FindFirstChild(VALUE_OBJ_HEALTH) or model:FindFirstChild("Health")
	if hpValObj and hpValObj:IsA("ValueBase") then
		local hp = tonumber(hpValObj.Value) or 0
		local maxHpValObj = model:FindFirstChild(VALUE_OBJ_MAX_HEALTH) or model:FindFirstChild("MaxHealth")
		return hp, maxHpValObj and tonumber(maxHpValObj.Value) or 100
	end

	local humanoid = model:FindFirstChildWhichIsA("Humanoid")
	if humanoid then return humanoid.Health, humanoid.MaxHealth end
	return 0, 100
end

local function getEntityPosition(model: Model): Vector3?
	local success, position = pcall(function()
		local part = model.PrimaryPart 
			or model:FindFirstChild("HumanoidRootPart") 
			or model:FindFirstChildWhichIsA("BasePart")
		if part then return part.Position end
		return nil
	end)
	return success and position or nil
end

local function getLocalPlayerPosition(): Vector3?
	local char = localPlayer.Character
	if not char then return nil end
	local root = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
	return root and root.Position or nil
end

local function untrackEntity(model: Model)
	local data = activeOverlays[model]
	if data then
		if data.Gui then data.Gui:Destroy() end
		activeOverlays[model] = nil
	end
	speciesCache[model] = nil
	triggeredAlerts[model] = nil
end

local function trackEntity(model: Model, adornee: BasePart)
	if not model or not adornee then return end
	if activeOverlays[model] then return end

	local safeOverlayName = if typeof(OVERLAY_UI_NAME) == "string" then OVERLAY_UI_NAME else "EntityTrackerOverlay"

	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Name = safeOverlayName
	billboardGui.Size = UDim2.new(0, 240, 0, 85)
	billboardGui.StudsOffset = Vector3.new(0, 4, 0)
	billboardGui.ResetOnSpawn = false
	billboardGui.AlwaysOnTop = true 
	billboardGui.MaxDistance = MAX_TRACKING_DISTANCE
	billboardGui.Adornee = adornee

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
	textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	textLabel.TextStrokeTransparency = 0.2
	textLabel.TextSize = 13
	textLabel.Font = Enum.Font.SourceSansBold
	textLabel.Text = "Retrieving Data..."
	textLabel.Parent = billboardGui

	billboardGui.Parent = playerGui

	activeOverlays[model] = {
		Gui = billboardGui,
		Label = textLabel,
		Adornee = adornee
	}
end

-- Safely and aggressively registers models on workspace spawn
local function evaluateModel(instance: Instance)
	if instance:IsA("Model") then
		if localPlayer.Character and instance == localPlayer.Character then return end
		if instance == Workspace then return end
		if instance.Name == "Camera" or instance:IsA("Status") then return end
		
		task.defer(function()
			if not instance.Parent then return end
			potentialTargets[instance] = true
		end)
	end
end

--------------------------------------------------------------------------------
-- NATIVE JAW REACH (BITE INDICATOR) INSTANTIATION HELPERS
--------------------------------------------------------------------------------
local function clearRangeSphere()
	if rangeSpherePart then
		rangeSpherePart:Destroy()
		rangeSpherePart = nil
	end
end

local function createRangeSphere(attachPart: BasePart)
	clearRangeSphere()
	
	local sphere = Instance.new("Part")
	sphere.Name = "BiteRangeIndicator"
	sphere.Shape = Enum.PartType.Ball
	sphere.Size = Vector3.new(BASE_ATTACK_RANGE * 2, BASE_ATTACK_RANGE * 2, BASE_ATTACK_RANGE * 2)
	sphere.Material = Enum.Material.ForceField
	sphere.Color = Color3.fromRGB(150, 0, 0)
	sphere.Transparency = 0.6
	sphere.CanCollide = false
	sphere.CanTouch = false
	sphere.CanQuery = false
	sphere.CastShadow = false
	sphere.Anchored = true -- manual CFrame updates in main RenderStepped loop
	
	sphere.CFrame = attachPart.CFrame
	sphere.Parent = Workspace

	rangeSpherePart = sphere
end

-- ============================================================================
-- HOISTED METRIC RETRIEVAL: SAFE LATENCY OVERRIDE (CORRECTED)
-- Fully declared at the top level of the script to prevent nil-calling crashes.
-- ============================================================================
local function getPlayerPing(): number
	local defaultPing = 0.05 -- 50ms baseline default fallback (seconds)
	
	local success, result = pcall(function()
		local statsService = game:GetService("Stats")
		local network = statsService:FindFirstChild("Network")
		local serverStats = network and network:FindFirstChild("ServerStatsItem")
		local pingItem = serverStats and serverStats:FindFirstChild("Ping")
		
		if pingItem then
			-- Execute GetValue() inside a guarded check
			local val = pingItem:GetValue()
			if typeof(val) == "number" then
				return val / 1000 -- Convert milliseconds to seconds
			end
		end
		return defaultPing
	end)
	
	if success and typeof(result) == "number" then
		return result
	end
	
	return defaultPing
end

--------------------------------------------------------------------------------
-- ACTIVE PACK MANAGEMENT & AUTO-FILL PACK LOGIC
--------------------------------------------------------------------------------
local function isAlliedPackMember(otherPlayer: Player): boolean
	if otherPlayer == localPlayer then return false end

	-- Species Verification
	local myChar = localPlayer.Character
	local otherChar = otherPlayer.Character
	if myChar and otherChar then
		local mySpecies = speciesCache[myChar] or getDinoSpecies(myChar)
		local otherSpecies = speciesCache[otherChar] or getDinoSpecies(otherChar)
		if mySpecies ~= "Unknown Species" and mySpecies == otherSpecies then
			return true
		end
	end

	-- Group ID Verification
	local myParty = localPlayer:GetAttribute("PartyID") or localPlayer:GetAttribute("GroupId") or localPlayer:GetAttribute("Squad")
	local otherParty = otherPlayer:GetAttribute("PartyID") or otherPlayer:GetAttribute("GroupId") or otherPlayer:GetAttribute("Squad")
	if myParty and otherParty and myParty == otherParty then
		return true
	end

	-- ValueObject Verification
	local mySquadObj = localPlayer:FindFirstChild("Party") or localPlayer:FindFirstChild("Squad")
	local otherSquadObj = otherPlayer:FindFirstChild("Party") or otherPlayer:FindFirstChild("Squad")
	if mySquadObj and otherSquadObj and mySquadObj:IsA("ValueBase") and otherSquadObj:IsA("ValueBase") then
		if mySquadObj.Value == otherSquadObj.Value and mySquadObj.Value ~= "" then
			return true
		end
	end

	return false
end

local function isAlliedPackModel(model: Model): boolean
	if localPlayer.Character and model == localPlayer.Character then return false end
	
	local player = Players:FindFirstChild(model.Name)
	if player then
		if isAlliedPackMember(player) then return true end
	end
	
	local myChar = localPlayer.Character
	if myChar then
		local mySpecies = speciesCache[myChar] or getDinoSpecies(myChar)
		local otherSpecies = speciesCache[model] or getDinoSpecies(model)
		if mySpecies ~= "Unknown Species" and mySpecies == otherSpecies then
			return true
		end
	end
	
	return false
end

-- Central Whitelist case-insensitive check utility using safe loops
local function checkIsWhitelisted(name: string): boolean
	local nameLower = string.lower(name)
	for _, whitelistedName in pairs(WhitelistedTable or {}) do
		if whitelistedName == nameLower then
			return true
		end
	end
	return false
end

-- Whitelist manual addition framework with search and loose fallback
local function addPlayerToWhitelist(rawName: string)
	local cleanName = string.gsub(rawName, "^%s*(.-)%s*$", "%1")
	if cleanName == "" then return end

	local cleanNameLower = string.lower(cleanName)
	local foundPlayer: Player? = nil

	for _, player in ipairs(Players:GetPlayers()) do
		if string.lower(player.DisplayName) == cleanNameLower then
			foundPlayer = player
			break
		end
	end

	local labelName = cleanName
	
	if foundPlayer then
		local usernameLower = string.lower(foundPlayer.Name)
		local displayLower = string.lower(foundPlayer.DisplayName)
		labelName = foundPlayer.DisplayName

		if not table.find(WhitelistedTable, usernameLower) then
			table.insert(WhitelistedTable, usernameLower)
		end
		if not table.find(WhitelistedTable, displayLower) then
			table.insert(WhitelistedTable, displayLower)
		end

		local entryButton = Instance.new("TextButton")
		entryButton.Size = UDim2.new(1, -10, 0, 24)
		entryButton.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
		entryButton.Text = labelName .. " [x]"
		entryButton.TextColor3 = Color3.fromRGB(220, 100, 100)
		entryButton.TextSize = 11
		entryButton.Font = Enum.Font.SourceSansBold
		entryButton.Parent = whitelistScroll

		local entryCorner = Instance.new("UICorner")
		entryCorner.CornerRadius = UDim.new(0, 4)
		entryCorner.Parent = entryButton

		whitelistScroll.CanvasSize = UDim2.new(0, 0, 0, listLayoutScroll.AbsoluteContentSize.Y + 10)

		entryButton.MouseButton1Click:Connect(function()
			local idx1 = table.find(WhitelistedTable, usernameLower)
			if idx1 then table.remove(WhitelistedTable, idx1) end
			local idx2 = table.find(WhitelistedTable, displayLower)
			if idx2 then table.remove(WhitelistedTable, idx2) end
			
			entryButton:Destroy()
			whitelistScroll.CanvasSize = UDim2.new(0, 0, 0, listLayoutScroll.AbsoluteContentSize.Y + 10)
		end)
	else
		if table.find(WhitelistedTable, cleanNameLower) then return end
		table.insert(WhitelistedTable, cleanNameLower)

		local entryButton = Instance.new("TextButton")
		entryButton.Size = UDim2.new(1, -10, 0, 24)
		entryButton.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
		entryButton.Text = labelName .. " (Raw) [x]"
		entryButton.TextColor3 = Color3.fromRGB(220, 100, 100)
		entryButton.TextSize = 11
		entryButton.Font = Enum.Font.SourceSansBold
		entryButton.Parent = whitelistScroll

		local entryCorner = Instance.new("UICorner")
		entryCorner.CornerRadius = UDim.new(0, 4)
		entryCorner.Parent = entryButton

		whitelistScroll.CanvasSize = UDim2.new(0, 0, 0, listLayoutScroll.AbsoluteContentSize.Y + 10)

		entryButton.MouseButton1Click:Connect(function()
			local idx = table.find(WhitelistedTable, cleanNameLower)
			if idx then table.remove(WhitelistedTable, idx) end
			
			entryButton:Destroy()
			whitelistScroll.CanvasSize = UDim2.new(0, 0, 0, listLayoutScroll.AbsoluteContentSize.Y + 10)
		end)
	end
end

--------------------------------------------------------------------------------
-- CARCASS SCANNING UTILITIES
--------------------------------------------------------------------------------
local function isFoodNode(inst: Instance): boolean
	local nameLower = string.lower(inst.Name)
	return string.find(nameLower, "carcass") 
		or string.find(nameLower, "meat") 
		or string.find(nameLower, "foodnode") 
		or string.find(nameLower, "fishpool")
end

local function getCarcassData(inst: Instance): (number, number, boolean)
	local yield = 100
	local spoilTime = 300
	local isRotten = false

	local attrYield = inst:GetAttribute("MeatAmount") or inst:GetAttribute("Nutrition") or inst:GetAttribute("FoodPoints")
	local attrRot = inst:GetAttribute("RotProgress") or inst:GetAttribute("SpoilTimer") or inst:GetAttribute("Rot")
	
	if not attrYield then
		local valObj = inst:FindFirstChild("FoodValue") or inst:FindFirstChild("Nutrition") or inst:FindFirstChild("Value")
		if valObj and valObj:IsA("ValueBase") then attrYield = valObj.Value end
	end
	if not attrRot then
		local valObj = inst:FindFirstChild("RotProgress") or inst:FindFirstChild("SpoilTimer") or inst:FindFirstChild("Rot")
		if valObj and valObj:IsA("ValueBase") then attrRot = valObj.Value end
	end

	yield = tonumber(attrYield) or 100
	spoilTime = tonumber(attrRot) or 300

	local attrIsRotten = inst:GetAttribute("IsRotten")
	if attrIsRotten ~= nil then
		isRotten = attrIsRotten
	else
		local rotPercent = inst:GetAttribute("RotPercent") or inst:GetAttribute("RotProgress")
		if rotPercent and tonumber(rotPercent) and tonumber(rotPercent) >= 100 then
			isRotten = true
		elseif spoilTime <= 0 then
			isRotten = true
		end
	end

	return yield, spoilTime, isRotten
end

local function createCarcassOverlay(item: Instance, adornee: BasePart)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CarcassTelemetryUI"
	billboard.Size = UDim2.new(0, 150, 0, 55)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 5000
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.Adornee = adornee

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.TextColor3 = Color3.fromRGB(255, 165, 0)
	textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	textLabel.TextStrokeTransparency = 0.2
	textLabel.TextSize = 10
	textLabel.Font = Enum.Font.SourceSansBold
	textLabel.Text = "Scanning..."
	textLabel.Parent = billboard

	billboard.Parent = playerGui
	activeCarcassGuis[item] = billboard
end

local function clearCarcassOverlays()
	for item, gui in pairs(activeCarcassGuis) do
		if gui then gui:Destroy() end
	end
	table.clear(activeCarcassGuis)
end

--------------------------------------------------------------------------------
-- REVISED UI PANEL ASSEMBLY & COMPONENT INTERACTIVE STATE WIRING
--------------------------------------------------------------------------------
-- Helper to update button visual colors and text states
local function updateButtonState(button: TextButton, state: boolean, text: string)
	if state then
		button.BackgroundColor3 = Color3.fromRGB(0, 150, 0) -- Vibrant Green (ON)
		button.Text = text .. " (ON)"
	else
		button.BackgroundColor3 = Color3.fromRGB(150, 0, 0) -- Muted dark Red (OFF)
		button.Text = text .. " (OFF)"
	end
end

-- Setup Whitelist Submenu Visibility Toggle Logic
local function updateSubmenuVisibility(state: boolean)
	whitelistSectionLabel.Visible = state
	inputContainer.Visible = state
	whitelistScroll.Visible = state
	autoFillBtn.Visible = state
	
	-- Dynamically adjust main ScrollingFrame CanvasSize based on visibility states
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, state and 540 or 380)
end

-- Initializing visual states to their respective runtime configurations
updateButtonState(trackingBtn, trackingEnabled, "X-Ray Tracking")
updateButtonState(whitelistBtn, false, "Radar Whitelist Manager") -- Starts closed
updateButtonState(packBtn, packDensityActive, "Pack Density Monitor")
updateButtonState(carcassBtn, carcassScannerActive, "Carcass Analytics")
updateButtonState(rangeBtn, rangeFinderActive, "Bite Range Finder")
updateButtonState(fullbrightBtn, fullbrightActive, "Fullbright")
updateButtonState(envBtn, environmentOverridesEnabled, "Clear Water & Fog")
updateButtonState(sleepBtn, bypassSleepEnabled, "Bypass Sleep GUI")

-- Initialize whitelist sub-menu to off on script startup
updateSubmenuVisibility(false)

-- 2. INTERACTIVE TOGGLE COLORIZATION & EVENT BINDINGS
trackingBtn.MouseButton1Click:Connect(function()
	trackingEnabled = not trackingEnabled
	updateButtonState(trackingBtn, trackingEnabled, "X-Ray Tracking")
	if not trackingEnabled then
		for model in pairs(activeOverlays) do
			untrackEntity(model)
		end
	end
end)

whitelistBtn.MouseButton1Click:Connect(function()
	local submenuState = not whitelistSectionLabel.Visible
	updateButtonState(whitelistBtn, submenuState, "Radar Whitelist Manager")
	updateSubmenuVisibility(submenuState)
end)

packBtn.MouseButton1Click:Connect(function()
	packDensityActive = not packDensityActive
	updateButtonState(packBtn, packDensityActive, "Pack Density Monitor")
end)

carcassBtn.MouseButton1Click:Connect(function()
	carcassScannerActive = not carcassScannerActive
	updateButtonState(carcassBtn, carcassScannerActive, "Carcass Analytics")
	if not carcassScannerActive then
		clearCarcassOverlays()
	end
end)

rangeBtn.MouseButton1Click:Connect(function()
	rangeFinderActive = not rangeFinderActive
	updateButtonState(rangeBtn, rangeFinderActive, "Bite Range Finder")
	if not rangeFinderActive then
		clearRangeSphere()
	end
end)

fullbrightBtn.MouseButton1Click:Connect(function()
	fullbrightActive = not fullbrightActive
	updateButtonState(fullbrightBtn, fullbrightActive, "Fullbright")
	
	if not fullbrightActive then
		Lighting.GlobalShadows = originalGlobalShadows
		Lighting.Ambient = originalAmbient
		Lighting.OutdoorAmbient = originalOutdoorAmbient
		Lighting.Brightness = originalBrightness
		Lighting.ClockTime = originalClockTime
	end
end)

envBtn.MouseButton1Click:Connect(function()
	environmentOverridesEnabled = not environmentOverridesEnabled
	updateButtonState(envBtn, environmentOverridesEnabled, "Clear Water & Fog")
	
	if not environmentOverridesEnabled then
		terrain.WaterTransparency = originalWaterTransparency
		terrain.WaterReflectance = originalWaterReflectance
		Lighting.FogEnd = originalFogEnd
		for atmosphere, originalDensity in pairs(originalAtmosphereDensities) do
			if atmosphere.Parent then
				atmosphere.Density = originalDensity
			end
		end
	end
end)

sleepBtn.MouseButton1Click:Connect(function()
	bypassSleepEnabled = not bypassSleepEnabled
	updateButtonState(sleepBtn, bypassSleepEnabled, "Bypass Sleep GUI")
end)

--------------------------------------------------------------------------------
-- BACKGROUND SCANNING LOOP (Carcass Evaluation Paced at 1.5 Seconds)
--------------------------------------------------------------------------------
task.spawn(function()
	while true do
		task.wait(1.5)
		if carcassScannerActive then
			pcall(function()
				local activeScan = {}
				for _, item in ipairs(Workspace:GetChildren()) do
					if (item:IsA("BasePart") or item:IsA("Model")) and isFoodNode(item) then
						activeScan[item] = true
						local adornee = item:IsA("Model") and (item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart")) or item
						if adornee and adornee:IsA("BasePart") then
							if not activeCarcassGuis[item] then createCarcassOverlay(item, adornee) end
							local gui = activeCarcassGuis[item]
							local label = gui and gui:FindFirstChildOfClass("TextLabel")
							if label then
								local yield, spoil, isRotten = getCarcassData(item)
								if isRotten then
									local flash = (math.floor(os.clock() * 3) % 2 == 0)
									label.TextColor3 = flash and Color3.fromRGB(220, 0, 0) or Color3.fromRGB(255, 140, 0)
									label.Text = string.format("[%s]\n[TOXIC - ROTTEN]\nYield: %d pts", string.upper(item.Name), yield)
								else
									label.TextColor3 = Color3.fromRGB(255, 165, 0)
									label.Text = string.format("[%s]\nYield: %d pts\nSpoils: %ds", string.upper(item.Name), yield, spoil)
								end
							end
						end
					end
				end
				for item, gui in pairs(activeCarcassGuis) do
					if not activeScan[item] or not item.Parent then
						if gui then gui:Destroy() end
						activeCarcassGuis[item] = nil
					end
				end
			end)
		end
	end
end)

--------------------------------------------------------------------------------
-- CORE RENDERING RUNTIME LOOP (Executed Every Frame)
-- Each major module is isolated inside its own pcall bubble for safety
--------------------------------------------------------------------------------
_G.MasterUtilityConnections.RenderStepped = RunService.RenderStepped:Connect(function()
	local localPos = getLocalPlayerPosition()
	local char = localPlayer.Character
	local root = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart) :: BasePart?

	-- isolated pcall block 1: Environmental Clearances (Water & Horizon Overrides)
	pcall(function()
		if environmentOverridesEnabled then
			terrain.WaterTransparency = 1
			terrain.WaterReflectance = 0
			if Lighting.FogEnd ~= 999999 then Lighting.FogEnd = 999999 end
			for _, child in ipairs(Lighting:GetChildren()) do
				if child:IsA("Atmosphere") and child.Density ~= 0 then child.Density = 0 end
			end
		end

		if bypassSleepEnabled then
			for frame in pairs(registeredSleepOverlays or {}) do
				if frame and frame.Parent then
					if frame.Visible then frame.Visible = false end
					if frame.BackgroundTransparency < 1 then frame.BackgroundTransparency = 1 end
				else
					registeredSleepOverlays[frame] = nil
				end
			end
		end
	end)

	-- isolated pcall block 2: Fullbright Processing
	pcall(function()
		if fullbrightActive then
			Lighting.GlobalShadows = false
			Lighting.Ambient = Color3.fromRGB(255, 255, 255)
			Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
			Lighting.Brightness = 2
			Lighting.ClockTime = 12
		end
	end)

	-- isolated pcall block 3: Bite Range Finder Latency Compensation Updates
	pcall(function()
		if rangeFinderActive and char and root then
			local headPart = char:FindFirstChild("Head") or root
			if headPart then
				if not rangeSpherePart or rangeSpherePart.Parent ~= Workspace then
					createRangeSphere(headPart)
				end

				local targetInBiteRange = false
				local closestTargetRoot: BasePart? = nil
				local closestDistance = math.huge

				-- Scan and map nearest hostile target
				for model in pairs(potentialTargets or {}) do
					if model == char then continue end
					local targetName = string.lower(model.Name)
					
					-- Whitelist check via robust, case-insensitive helper checks
					local isWhitelisted = checkIsWhitelisted(targetName)
					if not isWhitelisted then
						local playerObj = Players:FindFirstChild(model.Name)
						if playerObj and checkIsWhitelisted(playerObj.DisplayName) then
							isWhitelisted = true
						end
					end

					if not isWhitelisted then
						local targetPos = getEntityPosition(model)
						if targetPos then
							local distance = (headPart.Position - targetPos).Magnitude
							if distance < closestDistance then
								closestDistance = distance
								closestTargetRoot = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
							end
						end
					end
				end

				-- Determine strike eligibility (unmodified by visual offset)
				if closestDistance <= BASE_ATTACK_RANGE then
					targetInBiteRange = true
				end

				-- Apply Latency Compensated Offsets
				if rangeSpherePart then
					local ping = getPlayerPing() or 0.05
					local myVelocity = if root and root:IsA("BasePart") then root.AssemblyLinearVelocity else Vector3.new()
					local targetVelocity = Vector3.new()
					
					if closestTargetRoot and closestTargetRoot:IsA("BasePart") then
						targetVelocity = closestTargetRoot.AssemblyLinearVelocity
					end

					local relativeVelocity = myVelocity - targetVelocity
					local displacementOffset = relativeVelocity * ping

					local maxOffsetLimit = 12
					if displacementOffset.Magnitude > maxOffsetLimit then
						displacementOffset = displacementOffset.Unit * maxOffsetLimit
					end

					rangeSpherePart.CFrame = CFrame.new(headPart.Position + displacementOffset)

					if targetInBiteRange then
						rangeSpherePart.Color = Color3.fromRGB(255, 255, 255) -- neon white
					else
						rangeSpherePart.Color = Color3.fromRGB(150, 0, 0) -- warning red
					end
				end
			end
		else
			clearRangeSphere()
		end
	end)

	-- isolated pcall block 4: Track Pack Density Conditions
	pcall(function()
		local alliedPackCount = 0
		if packDensityActive and localPos then
			for model in pairs(potentialTargets or {}) do
				if isAlliedPackModel(model) then
					local targetPos = getEntityPosition(model)
					if targetPos then
						local distance = (localPos - targetPos).Magnitude
						if distance <= 80 then alliedPackCount = alliedPackCount + 1 end
					end
				end
			end
			packSpacingHUD.Text = string.format("Pack Density: %d/4", alliedPackCount)
			
			if alliedPackCount <= 2 then
				packSpacingHUD.TextColor3 = Color3.fromRGB(0, 200, 0)
				centerWarning.Visible = false
			elseif alliedPackCount == 3 then
				packSpacingHUD.TextColor3 = Color3.fromRGB(255, 140, 0)
				centerWarning.Visible = false
			else
				packSpacingHUD.TextColor3 = Color3.fromRGB(220, 0, 0)
				local flashState = (math.floor(os.clock() * 4) % 2 == 0)
				centerWarning.Visible = flashState
				if flashState then packSpacingHUD.TextColor3 = Color3.fromRGB(255, 255, 255) end
			end
		else
			packSpacingHUD.Text = "Pack Density: Off"
			packSpacingHUD.TextColor3 = Color3.fromRGB(150, 150, 150)
			centerWarning.Visible = false
		end
	end)

	-- isolated pcall block 5: X-Ray Tracking Updates & Multi-Tier Proximity Warnings
	pcall(function()
		if trackingEnabled then
			for model in pairs(potentialTargets or {}) do
				if char and model == char then
					potentialTargets[model] = nil
					untrackEntity(model)
					continue
				end

				if not model:IsDescendantOf(Workspace) then
					potentialTargets[model] = nil
					untrackEntity(model)
					continue
				end

				-- Safe verification of LocalPlayer character positioning metrics
				local localHasPosition = char and char.PrimaryPart ~= nil

				-- Whitelist filtration via case-insensitive helper checks
				local isTargetWhitelisted = checkIsWhitelisted(model.Name)
				if not isTargetWhitelisted then
					local playerObject = Players:FindFirstChild(model.Name)
					if playerObject and checkIsWhitelisted(playerObject.DisplayName) then
						isTargetWhitelisted = true
					end
				end

				local targetPos = getEntityPosition(model)
				local adorneePart = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")

				if not targetPos or not adorneePart then
					untrackEntity(model)
					continue
				end

				if not activeOverlays[model] then trackEntity(model, adorneePart) end

				-- Fetch and format identifiers
				local speciesName = speciesCache[model]
				if not speciesName then
					speciesName = getDinoSpecies(model)
					speciesCache[model] = speciesName
				end

				local displayName = getPlayerDisplayName(model)
				local identityLine = displayName .. " (" .. speciesName .. ")"

				local curHp, maxHp = getEntityHealth(model)
				local hpDisplay = string.format("HP: %d/%d", math.round(curHp), math.round(maxHp))

				local weightDisplay = "Weight: N/A"
				local rawWeight = getEntityWeight(model)
				if rawWeight then
					local numeric = tonumber(rawWeight)
					weightDisplay = string.format("Weight: %s kg", tostring(numeric and math.round(numeric) or rawWeight))
				end

				local distance = 0
				local distanceDisplay = "Distance: N/A"
				if localHasPosition and localPos then
					distance = (localPos - targetPos).Magnitude
					distanceDisplay = string.format("Distance: %d studs", math.round(distance))
				end

				local overlay = activeOverlays[model]
				if overlay then
					local currentTier = 0
					if localHasPosition then
						if distance <= 50 then
							currentTier = 3
						elseif distance <= 100 then
							currentTier = 2
						elseif distance <= 200 then
							currentTier = 1
						end
					end

					-- Alert colorization and notification triggers
					if isTargetWhitelisted then
						overlay.Label.TextColor3 = Color3.fromRGB(240, 240, 240)
						triggeredAlerts[model] = nil
					else
						if currentTier == 3 then
							overlay.Label.TextColor3 = Color3.fromRGB(220, 0, 0)
						elseif currentTier == 2 then
							overlay.Label.TextColor3 = Color3.fromRGB(255, 140, 0)
						elseif currentTier == 1 then
							overlay.Label.TextColor3 = Color3.fromRGB(0, 200, 0)
						else
							overlay.Label.TextColor3 = Color3.fromRGB(240, 240, 240)
						end

						-- Dynamic Squelch and Escalation Alerts
						if currentTier > 0 then
							local lastTriggeredTier = triggeredAlerts[model] or 0
							if currentTier > lastTriggeredTier then
								triggeredAlerts[model] = currentTier
								spawnProximityNotification(displayName, speciesName, distance, currentTier)
							end
						else
							if distance >= 220 then triggeredAlerts[model] = nil end
						end
					end

					overlay.Label.Text = string.format(
						"%s\n%s\n%s\n%s",
						identityLine,
						hpDisplay,
						weightDisplay,
						distanceDisplay
					)
				end
			end
		end
	end)
end)

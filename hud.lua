_G.ESP_MaxDistance = _G.ESP_MaxDistance or 500
_G.ToggleESP = _G.ToggleESP or false
_G.ESP_ShowPlayerName = _G.ESP_ShowPlayerName == nil and true or _G.ESP_ShowPlayerName
_G.ESP_ShowDinoName = _G.ESP_ShowDinoName == nil and true or _G.ESP_ShowDinoName
_G.ESP_ShowGrowthStage = _G.ESP_ShowGrowthStage == nil and true or _G.ESP_ShowGrowthStage
_G.ESP_ShowDistance = _G.ESP_ShowDistance == nil and true or _G.ESP_ShowDistance
_G.ToggleAutowalk = _G.ToggleAutowalk or false
_G.ToggleAutogrow = _G.ToggleAutogrow or false
_G.AutowalkTarget = _G.AutowalkTarget or nil

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local VirtualUser = game:GetService("VirtualUser")

pcall(function()
    VirtualUser:CaptureController()
end)

local UI_NAME = "DarkCyberUI_Overlay"

-- 1. Safety Check: Clean up any existing UI instances from previous runs
local existingUI = CoreGui:FindFirstChild(UI_NAME)
if existingUI then
    existingUI:Destroy()
end

-- Retrieve the local player safely to prevent loading delays
local localPlayer = Players.LocalPlayer
if not localPlayer then
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    localPlayer = Players.LocalPlayer
end

local displayName = localPlayer and localPlayer.DisplayName or "User"
local userId = localPlayer and localPlayer.UserId or 0
local avatarUrl = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(userId) .. "&w=150&h=150"

-- 2. Root Container Setup
local screenGui = Instance.new("ScreenGui")
screenGui.Name = UI_NAME
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = CoreGui

-- Styling Constants
local BG_GRADIENT_START = Color3.fromRGB(20, 10, 30) -- Midnight plum-purple
local BG_GRADIENT_END = Color3.fromRGB(15, 15, 15)   -- Deep Black
local ACCENT_COLOR = Color3.fromRGB(140, 0, 255)
local TEXT_COLOR = Color3.fromRGB(140, 0, 255)
local LIGHT_TEXT = Color3.fromRGB(180, 180, 180)
local PANEL_BG = Color3.fromRGB(10, 10, 10)
local FONT_FAMILY = Enum.Font.Gotham -- Softer, cleaner typography

-- Enhanced Sidebar Button Constants
local BUTTON_BG = Color3.fromRGB(30, 20, 45)         -- Deep purple-gray translucent tint
local BUTTON_BG_TRANSPARENCY = 0.5                  -- Subtle translucency for visual layering
local BUTTON_TEXT_COLOR = Color3.fromRGB(180, 80, 255) -- Highly vibrant purple text for contrast

-- Global Configuration State Store (ESP Configuration Settings Included)
local uiState = {
    toggles = {
        ["Clear Water"] = false,
        ["Clear Sleep"] = false,
        ["ESP Active"] = _G.ToggleESP,
        ["Show Player Names"] = _G.ESP_ShowPlayerName,
        ["Show Dino Species"] = _G.ESP_ShowDinoName,
        ["Show Growth Stage"] = _G.ESP_ShowGrowthStage,
        ["Show Distance"] = _G.ESP_ShowDistance,
        ["Autowalk Active"] = _G.ToggleAutowalk,
        ["Autogrow Active"] = _G.ToggleAutogrow,
    },
    sliders = {
        ["Smoothing Range Vector"] = 35,
        ["Draw Render Distance Limit"] = 75,
    },
    keybind = "RightShift"
}

-- Registry to update UI components programmatically upon configuration load
local toggleRegistry = {}
local sliderRegistry = {}
local keybindUpdateRegistry = nil

-- Keybind State Variable (Default: RightShift)
local currentKeybind = Enum.KeyCode.RightShift

-- Main Window Frame
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 680, 0, 420)
mainFrame.Position = UDim2.new(0.5, -340, 0.5, -210)
mainFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
-- Frame Visibility Adjustments: Set entirely transparent during intro phase
mainFrame.BackgroundTransparency = 1
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true -- Allows relocating the frame on-screen for review
mainFrame.Parent = screenGui

-- Rounded corners for Main Frame
local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 8)
mainCorner.Parent = mainFrame

-- Ambient Gradient Background (Midnight dark plum-purple to solid deep black)
local mainGradient = Instance.new("UIGradient")
mainGradient.Color = ColorSequence.new(BG_GRADIENT_START, BG_GRADIENT_END)
mainGradient.Rotation = 90
mainGradient.Parent = mainFrame

-- Outer frame border (Vibrant Purple UIStroke, initially disabled during intro)
local mainStroke = Instance.new("UIStroke")
mainStroke.Color = ACCENT_COLOR
mainStroke.Thickness = 1.5
mainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
mainStroke.Enabled = false
mainStroke.Parent = mainFrame

-- Window Header Frame (Initially invisible during intro phase)
local headerFrame = Instance.new("Frame")
headerFrame.Name = "Header"
headerFrame.Size = UDim2.new(1, 0, 0, 40)
headerFrame.BackgroundTransparency = 1
headerFrame.Visible = false
headerFrame.Parent = mainFrame

-- Top Branding Header Title (Exactly "T6 Hub")
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "TitleLabel"
titleLabel.Size = UDim2.new(1, -120, 1, 0)
titleLabel.Position = UDim2.new(0, 15, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "T6 Hub"
titleLabel.TextColor3 = TEXT_COLOR
titleLabel.TextSize = 13
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = headerFrame

-- Close Button (Updated to toggle visibility state non-destructively)
local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.Size = UDim2.new(0, 30, 0, 30)
closeButton.Position = UDim2.new(1, -40, 0.5, -15)
closeButton.BackgroundColor3 = BUTTON_BG
closeButton.BackgroundTransparency = BUTTON_BG_TRANSPARENCY
closeButton.Text = "X"
closeButton.TextColor3 = TEXT_COLOR
closeButton.TextSize = 12
closeButton.Font = FONT_FAMILY
closeButton.Parent = headerFrame

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeButton

local closeStroke = Instance.new("UIStroke")
closeStroke.Color = ACCENT_COLOR
closeStroke.Thickness = 1
closeStroke.Parent = closeButton

closeButton.MouseButton1Click:Connect(function()
    screenGui.Enabled = false -- Minimizes the interface without destroying state
end)

-- Horizontal Divider Line (Initially invisible)
local horizontalDivider = Instance.new("Frame")
horizontalDivider.Name = "HorizontalDivider"
horizontalDivider.Size = UDim2.new(1, -30, 0, 1)
horizontalDivider.Position = UDim2.new(0, 15, 0, 42)
horizontalDivider.BackgroundColor3 = ACCENT_COLOR
horizontalDivider.BorderSizePixel = 0
horizontalDivider.Visible = false
horizontalDivider.Parent = mainFrame


-- ============================================================================
-- INTERNAL LAYOUT SPLIT: LEFT SIDEBAR & RIGHT CONTENT CANVAS
-- ============================================================================

-- Left Navigation Sidebar (Initially invisible)
local sidebar = Instance.new("Frame")
sidebar.Name = "NavigationSidebar"
sidebar.Size = UDim2.new(0, 180, 1, -65)
sidebar.Position = UDim2.new(0, 15, 0, 52)
sidebar.BackgroundTransparency = 1
sidebar.Visible = false
sidebar.Parent = mainFrame

local sidebarLayout = Instance.new("UIListLayout")
sidebarLayout.Padding = UDim.new(0, 8)
sidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
sidebarLayout.Parent = sidebar

-- Vertical Divider Line between Sidebar and Content Area (Initially invisible)
local verticalDivider = Instance.new("Frame")
verticalDivider.Name = "VerticalDivider"
verticalDivider.Size = UDim2.new(0, 1, 1, -65)
verticalDivider.Position = UDim2.new(0, 205, 0, 52)
verticalDivider.BackgroundColor3 = Color3.fromRGB(45, 10, 80)
verticalDivider.BorderSizePixel = 0
verticalDivider.Visible = false
verticalDivider.Parent = mainFrame

-- Right Content Page Container (Initially invisible)
local container = Instance.new("Frame")
container.Name = "ContentContainer"
container.Size = UDim2.new(1, -230, 1, -65)
container.Position = UDim2.new(0, 215, 0, 52)
container.BackgroundTransparency = 1
container.Visible = false
container.Parent = mainFrame


-- ============================================================================
-- SELECTION MECHANIC & TEMPLATE SETUP
-- ============================================================================

local highlightBox = Instance.new("Frame")
highlightBox.Name = "HighlightBox"
highlightBox.Size = UDim2.new(1, 0, 1, 0)
highlightBox.BackgroundTransparency = 1
highlightBox.ZIndex = 3 -- Position above backgrounds to make active state highly distinct
highlightBox.Visible = false

local highlightCorner = Instance.new("UICorner")
highlightCorner.CornerRadius = UDim.new(0, 6)
highlightCorner.Parent = highlightBox

local highlightStroke = Instance.new("UIStroke")
highlightStroke.Color = ACCENT_COLOR
highlightStroke.Thickness = 1.5
highlightStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
highlightStroke.Parent = highlightBox


-- ============================================================================
-- REUSABLE CONTROL COMPONENT GENERATORS (Toggles & Sliders)
-- ============================================================================

local function createToggleComponent(parent, labelText, onToggleChanged)
    local toggleFrame = Instance.new("Frame")
    toggleFrame.Name = labelText .. "Toggle"
    toggleFrame.Size = UDim2.new(1, 0, 0, 40)
    toggleFrame.BackgroundTransparency = 1
    toggleFrame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -60, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = LIGHT_TEXT
    label.TextSize = 13
    label.Font = FONT_FAMILY
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Parent = toggleFrame

    local switch = Instance.new("Frame")
    switch.Size = UDim2.new(0, 42, 0, 22)
    switch.Position = UDim2.new(1, -45, 0.5, -11)
    switch.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    switch.Parent = toggleFrame

    local switchCorner = Instance.new("UICorner")
    switchCorner.CornerRadius = UDim.new(1, 0)
    switchCorner.Parent = switch

    local switchStroke = Instance.new("UIStroke")
    switchStroke.Color = Color3.fromRGB(60, 60, 60)
    switchStroke.Thickness = 1
    switchStroke.Parent = switch

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = UDim2.new(0, 3, 0.5, -8)
    knob.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
    knob.Parent = switch

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob

    -- Set initial state from state store
    local isActive = uiState.toggles[labelText] or false
    if isActive then
        knob.Position = UDim2.new(1, -19, 0.5, -8)
        switch.BackgroundColor3 = ACCENT_COLOR
    end

    -- Visual update function to bind to state store changes
    local function updateVisualState(newState)
        isActive = newState
        local targetPos = isActive and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        local targetColor = isActive and ACCENT_COLOR or Color3.fromRGB(45, 45, 45)

        TweenService:Create(knob, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = targetPos}):Play()
        TweenService:Create(switch, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = targetColor}):Play()
    end

    toggleRegistry[labelText] = updateVisualState

    switch.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isActive = not isActive
            uiState.toggles[labelText] = isActive
            updateVisualState(isActive)
            if onToggleChanged then
                onToggleChanged(isActive)
            end
        end
    end)
end

local function createSliderComponent(parent, labelText, defaultValue)
    local sliderFrame = Instance.new("Frame")
    sliderFrame.Name = labelText .. "Slider"
    sliderFrame.Size = UDim2.new(1, 0, 0, 50)
    sliderFrame.BackgroundTransparency = 1
    sliderFrame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -60, 0, 20)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = LIGHT_TEXT
    label.TextSize = 13
    label.Font = FONT_FAMILY
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = sliderFrame

    local percentLabel = Instance.new("TextLabel")
    percentLabel.Size = UDim2.new(0, 50, 0, 20)
    percentLabel.Position = UDim2.new(1, -50, 0, 0)
    percentLabel.BackgroundTransparency = 1
    percentLabel.Text = tostring(defaultValue or 50) .. "%"
    percentLabel.TextColor3 = ACCENT_COLOR
    percentLabel.TextSize = 13
    percentLabel.Font = FONT_FAMILY
    percentLabel.TextXAlignment = Enum.TextXAlignment.Right
    percentLabel.Parent = sliderFrame

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, 0, 0, 6)
    track.Position = UDim2.new(0, 0, 0, 32)
    track.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    track.BorderSizePixel = 0
    track.Parent = sliderFrame

    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(1, 0)
    trackCorner.Parent = track

    -- Get initial value from state store
    local value = uiState.sliders[labelText] or defaultValue or 50

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(value/100, 0, 1, 0)
    fill.BackgroundColor3 = ACCENT_COLOR
    fill.BorderSizePixel = 0
    fill.Parent = track

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new(value/100, 0, 0.5, 0)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.Parent = track

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob

    local knobStroke = Instance.new("UIStroke")
    knobStroke.Color = ACCENT_COLOR
    knobStroke.Thickness = 1.5
    knobStroke.Parent = knob

    -- Visual update function to bind to state store changes
    local function updateVisualState(newValue)
        value = newValue
        local relativeX = math.clamp(value / 100, 0, 1)
        fill.Size = UDim2.new(relativeX, 0, 1, 0)
        knob.Position = UDim2.new(relativeX, 0, 0.5, 0)
        percentLabel.Text = tostring(math.round(relativeX * 100)) .. "%"
    end

    sliderRegistry[labelText] = updateVisualState

    local dragging = false
    local function updateSlider(input)
        local relativeX = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        uiState.sliders[labelText] = math.round(relativeX * 100)
        updateVisualState(uiState.sliders[labelText])
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateSlider(input)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateSlider(input)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

-- Specialized Dynamic Slider Builder for Distance Custom Range Configuration
local function createDistanceSliderComponent(parent, labelText, minVal, maxVal, defaultValue, onValueChanged)
    local sliderFrame = Instance.new("Frame")
    sliderFrame.Name = labelText .. "Slider"
    sliderFrame.Size = UDim2.new(1, 0, 0, 50)
    sliderFrame.BackgroundTransparency = 1
    sliderFrame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -60, 0, 20)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = LIGHT_TEXT
    label.TextSize = 13
    label.Font = FONT_FAMILY
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = sliderFrame

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.new(0, 60, 0, 20)
    valueLabel.Position = UDim2.new(1, -60, 0, 0)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = tostring(defaultValue) .. "m"
    valueLabel.TextColor3 = ACCENT_COLOR
    valueLabel.TextSize = 13
    valueLabel.Font = FONT_FAMILY
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Parent = sliderFrame

    local track = Instance.new("Frame")
    track.Name = "SliderTrack"
    track.Size = UDim2.new(1, 0, 0, 6)
    track.Position = UDim2.new(0, 0, 0, 32)
    track.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    track.BorderSizePixel = 0
    track.Parent = sliderFrame -- FIXED PARENTING BUG: Correctly assigned to sliderFrame instead of self

    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(1, 0)
    trackCorner.Parent = track

    local value = defaultValue

    local fill = Instance.new("Frame")
    local initialPct = (value - minVal) / (maxVal - minVal)
    fill.Size = UDim2.new(initialPct, 0, 1, 0)
    fill.BackgroundColor3 = ACCENT_COLOR
    fill.BorderSizePixel = 0
    fill.Parent = track

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new(initialPct, 0, 0.5, 0)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.Parent = track

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob

    local knobStroke = Instance.new("UIStroke")
    knobStroke.Color = ACCENT_COLOR
    knobStroke.Thickness = 1.5
    knobStroke.Parent = knob

    local function updateVisualState(newValue)
        value = math.clamp(newValue, minVal, maxVal)
        local relativeX = (value - minVal) / (maxVal - minVal)
        fill.Size = UDim2.new(relativeX, 0, 1, 0)
        knob.Position = UDim2.new(relativeX, 0, 0.5, 0)
        valueLabel.Text = tostring(math.round(value)) .. "m"
    end

    local dragging = false
    local function updateSlider(input)
        local relativeX = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local calculatedValue = minVal + (relativeX * (maxVal - minVal))
        updateVisualState(calculatedValue)
        if onValueChanged then
            onValueChanged(math.round(calculatedValue))
        end
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateSlider(input)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateSlider(input)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end


-- ============================================================================
-- PERFORMANCE & ENVIRONMENT CONTROL LOGIC (Water & Sleep Removal)
-- ============================================================================

local clearWaterConnection = nil
local Terrain = workspace:FindFirstChildOfClass("Terrain")
local disabledAtmospheres = {}

-- Backup references to original environment parameters
local originalProps = {
    WaterTransparency = Terrain and Terrain.WaterTransparency or 1,
    WaterColor = Terrain and Terrain.WaterColor or Color3.fromRGB(0, 85, 127),
    WaterWaveSize = Terrain and Terrain.WaterWaveSize or 0.15,
    WaterWaveSpeed = Terrain and Terrain.WaterWaveSpeed or 10,
    FogStart = Lighting.FogStart,
    FogEnd = Lighting.FogEnd
}

-- 1. "Clear Water" Logic
local function toggleClearWater(state)
    if state then
        if Terrain then
            originalProps.WaterTransparency = Terrain.WaterTransparency
            originalProps.WaterColor = Terrain.WaterColor
            originalProps.WaterWaveSize = Terrain.WaterWaveSize
            originalProps.WaterWaveSpeed = Terrain.WaterWaveSpeed
        end
        originalProps.FogStart = Lighting.FogStart
        originalProps.FogEnd = Lighting.FogEnd

        clearWaterConnection = RunService.RenderStepped:Connect(function()
            if Terrain then
                Terrain.WaterTransparency = 1
                Terrain.WaterColor = Color3.fromRGB(15, 45, 60)
                Terrain.WaterWaveSize = 0
                Terrain.WaterWaveSpeed = 0
            end
            Lighting.FogStart = 999999
            Lighting.FogEnd = 999999

            for _, child in ipairs(Lighting:GetChildren()) do
                if child:IsA("BlurEffect") or child:IsA("DepthOfFieldEffect") then
                    child.Enabled = false
                elseif child:IsA("Atmosphere") then
                    child.Parent = screenGui
                    table.insert(disabledAtmospheres, child)
                end
            end
        end)
    else
        if clearWaterConnection then
            clearWaterConnection:Disconnect()
            clearWaterConnection = nil
        end

        if Terrain then
            Terrain.WaterTransparency = originalProps.WaterTransparency
            Terrain.WaterColor = originalProps.WaterColor
            Terrain.WaterWaveSize = originalProps.WaterWaveSize
            Terrain.WaterWaveSpeed = originalProps.WaterWaveSpeed
        end
        Lighting.FogStart = originalProps.FogStart
        Lighting.FogEnd = originalProps.FogEnd

        for _, child in ipairs(Lighting:GetChildren()) do
            if child:IsA("BlurEffect") or child:IsA("DepthOfFieldEffect") then
                child.Enabled = true
            end
        end
        for _, atmos in ipairs(disabledAtmospheres) do
            atmos.Parent = Lighting
        end
        table.clear(disabledAtmospheres)
    end
end

-- 2. "Clear Sleep" Logic
local sleepConnection = nil
local hiddenSleepFrames = {}

-- Safely inspects frames against scale dimensions and color properties
local function checkFrame(frame)
    if frame:IsA("Frame") then
        local successSize, size = pcall(function() return frame.Size end)
        local successColor, color = pcall(function() return frame.BackgroundColor3 end)
        if successSize and successColor then
            if size.X.Scale >= 1 and size.Y.Scale >= 1 and color.R < 0.1 then
                hiddenSleepFrames[frame] = true
                frame.Visible = false
            end
        end
    end
end

local function toggleClearSleep(state)
    if state then
        -- Initial environmental scan of current UI structures
        for _, desc in ipairs(localPlayer.PlayerGui:GetDescendants()) do
            checkFrame(desc)
        end
        -- Connect Child added listener to hook newly loaded overlays
        sleepConnection = localPlayer.PlayerGui.DescendantAdded:Connect(function(desc)
            checkFrame(desc)
        end)
    else
        if sleepConnection then
            sleepConnection:Disconnect()
            sleepConnection = nil
        end
        -- Revert visual state visibility parameters cleanly
        for frame, _ in pairs(hiddenSleepFrames) do
            pcall(function()
                if frame and frame.Parent then
                    frame.Visible = true
                end
            end)
        end
        table.clear(hiddenSleepFrames)
    end
end


-- ============================================================================
-- STREAMING-SAFE MULTI-DATA MODULAR PRIOR EXTINCTION ESP (STRICT STATE RULES)
-- ============================================================================

local activeTags = {}
local espContainer = nil

local BLOCKLIST = {
    "elbow", "body", "leg", "arm", "tail", "head", "neck", "wing", 
    "claw", "mesh", "part", "rig", "wild", "npc", "meshmodel", "handle"
}

local PREFERRED_PARTS = {
    "HumanoidRootPart", "RootPart", "Torso", "LowerTorso", "Spine", "Main"
}

local TARGET_TAGS = {
    "PlayerDino", "LiveCreature", "Character", "Dinosaur", "Creature", "Animal", "Player", "Live"
}

local function getESPContainer()
    if not espContainer or not espContainer.Parent then
        espContainer = Instance.new("Folder")
        espContainer.Name = "PriorExtinction_ESP_Container"
        espContainer.Parent = CoreGui
    end
    return espContainer
end

local function isBlockedPart(partName)
    local nameLower = partName:lower()
    for _, blocked in ipairs(BLOCKLIST) do
        if nameLower:find(blocked) then
            return true
        end
    end
    return false
end

local function findTargetPart(model)
    if not model:IsA("Model") then return nil end

    for _, name in ipairs(PREFERRED_PARTS) do
        local part = model:FindFirstChild(name, true)
        if part and part:IsA("BasePart") then
            return part
        end
    end

    if model.PrimaryPart then
        return model.PrimaryPart
    end

    local descendants = model:GetDescendants()
    for _, item in ipairs(descendants) do
        if item:IsA("BasePart") then
            if not isBlockedPart(item.Name) then
                return item
            end
        end
    end

    for _, item in ipairs(descendants) do
        if item:IsA("BasePart") then
            return item
        end
    end

    return nil
end

local function extractDetails(model)
    local species = nil
    local growth = nil

    species = model:GetAttribute("Species") or model:GetAttribute("Dinosaur") or model:GetAttribute("Type")
    growth = model:GetAttribute("Growth") or model:GetAttribute("Stage") or model:GetAttribute("GrowthStage") or model:GetAttribute("Age")

    for _, item in ipairs(model:GetDescendants()) do
        if not species then
            if item:IsA("StringValue") and (item.Name:lower() == "species" or item.Name:lower() == "dinosaur") then
                species = item.Value
            elseif item.Name:lower() == "species" or item.Name:lower() == "dinosaur" then
                species = item:GetAttribute("Value") or item:GetAttribute("Species")
            end
        end
        if not growth then
            if item:IsA("StringValue") and (item.Name:lower() == "growth" or item.Name:lower() == "stage" or item.Name:lower() == "age" or item.Name:lower() == "growthstage") then
                growth = item.Value
            elseif item:IsA("NumberValue") and item.Name:lower() == "growth" then
                growth = tostring(math.round(item.Value * 100)) .. "%"
            elseif item:IsA("StringValue") and item.Name:lower() == "growthstage" then
                growth = item.Value
            end
        end
    end

    if not species then
        species = model.Name
    end

    local growthStr = ""
    if growth then
        growthStr = " [" .. tostring(growth) .. "]"
    end

    return tostring(species), growthStr
end

local function createESPLabel(adornPart, titleText, subtitleText)
    local containerFolder = getESPContainer()
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "PE_DinoTag"
    billboard.Size = UDim2.new(0, 200, 0, 60)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 5000
    billboard.StudsOffset = Vector3.new(0, 4, 0)
    billboard.Adornee = adornPart
    billboard.Parent = containerFolder

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = titleText .. "\n" .. subtitleText
    textLabel.TextColor3 = Color3.fromRGB(160, 32, 240)
    textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    textLabel.TextStrokeTransparency = 0
    textLabel.TextSize = 13
    textLabel.Font = Enum.Font.GothamBold
    textLabel.RichText = true
    textLabel.TextYAlignment = Enum.TextYAlignment.Center
    textLabel.TextXAlignment = Enum.TextXAlignment.Center
    textLabel.Parent = billboard

    return billboard
end

local function processModel(model)
    if activeTags[model] then return end

    -- Duplication Check: Verify if an existing BillboardUI is already attached to a part inside this model
    local containerFolder = getESPContainer()
    for _, child in ipairs(containerFolder:GetChildren()) do
        if child:IsA("BillboardGui") and child.Name == "PE_DinoTag" and child.Adornee and child.Adornee:IsDescendantOf(model) then
            local species, growth = extractDetails(model)
            local targetPlayer = Players:GetPlayerFromCharacter(model)
            local title = targetPlayer and targetPlayer.DisplayName or targetPlayer and targetPlayer.Name or "Wild"
            
            -- Recycle the existing tag cleanly
            activeTags[model] = {
                tag = child,
                title = title,
                species = species,
                growth = growth
            }
            return
        end
    end

    -- Complete standard processing if no recycled tag was bound
    local targetPlayer = Players:GetPlayerFromCharacter(model)
    local playerDisplayName = targetPlayer and targetPlayer.DisplayName
    local playerUsername = targetPlayer and targetPlayer.Name

    local species, growth = extractDetails(model)
    local title = playerDisplayName or playerUsername or "Wild"

    local adornPart = findTargetPart(model)
    if adornPart then
        local tag = createESPLabel(adornPart, "", "")
        activeTags[model] = {
            tag = tag,
            title = title,
            species = species,
            growth = growth
        }
    end
end

local function scanEnvironment()
    -- 1. Scan Player List Active Characters (Tracing dynamic server parent mappings)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            local char = player.Character
            if char and char:IsA("Model") then
                processModel(char)
            end
        end
    end

    -- 2. CollectionService Sweep
    for _, tag in ipairs(TARGET_TAGS) do
        for _, inst in ipairs(CollectionService:GetInstancesByTag(tag)) do
            if inst:IsA("Model") and inst ~= localPlayer.Character then
                processModel(inst)
            end
        end
    end

    -- 3. Workspace Sweep (Dynamic recursive tracking of wild entities & carcasses)
    for _, child in ipairs(workspace:GetDescendants()) do
        if child:IsA("Model") and child ~= localPlayer.Character then
            local hasBaseParts = false

            for _, desc in ipairs(child:GetChildren()) do
                if desc:IsA("BasePart") then
                    hasBaseParts = true
                    break
                end
            end

            if not hasBaseParts then
                for _, desc in ipairs(child:GetDescendants()) do
                    if desc:IsA("BasePart") then
                        hasBaseParts = true
                        break
                    end
                end
            end

            if hasBaseParts then
                local isPlayerChar = Players:GetPlayerFromCharacter(child)
                local hasHumanoid = child:FindFirstChildOfClass("Humanoid")
                local hasDinoData = child:GetAttribute("Species") or child:FindFirstChild("Species", true)

                if isPlayerChar or hasHumanoid or hasDinoData then
                    processModel(child)
                end
            end
        end
    end
end

local function handleDynamicUpdates()
    local localCharacter = localPlayer and localPlayer.Character
    local localRoot = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
    
    -- Dynamic Reference Origin Tracking (Falls back safely to local camera position if character is missing)
    local originPos = nil
    if localRoot then
        originPos = localRoot.Position
    else
        local camera = workspace.CurrentCamera
        if camera then
            originPos = camera.CFrame.Position
        end
    end

    -- Directly extract current global toggle boolean states
    local showPlayer = _G.ESP_ShowPlayerName
    local showDino = _G.ESP_ShowDinoName
    local showGrowth = _G.ESP_ShowGrowthStage
    local showDistance = _G.ESP_ShowDistance or _G.ShowDistance or _G.DistanceESP
    local showTags = showPlayer or showDino or showGrowth or showDistance

    -- Dynamic evaluation of Range configuration at the absolute top of the processing loop
    local maxDistMeters = _G.ESP_MaxDistance or _G.MaxDistance or _G.ESPRange or 1000
    local maxDistStuds = maxDistMeters * 2.8

    for model, data in pairs(activeTags) do
        local tag = data.tag
        -- Persistent Verification: Verify if model has been deleted, unparented, or culled due to streaming replication
        if not model or not model.Parent then
            pcall(function() tag:Destroy() end)
            activeTags[model] = nil
        else
            if not tag:IsA("BillboardGui") then continue end
            
            -- Verify Adornee link integrity. Re-find target parts if dynamic replication flashes children properties
            local adorn = tag.Adornee
            if not adorn or not adorn.Parent then
                local newAdorn = findTargetPart(model)
                if newAdorn then
                    tag.Adornee = newAdorn
                    adorn = newAdorn
                else
                    pcall(function() tag:Destroy() end)
                    activeTags[model] = nil
                    continue
                end
            end

            -- Calculate distance from local player reference point
            local distStuds = 999999
            if originPos and adorn then
                distStuds = (originPos - adorn.Position).Magnitude
            end

            -- Range-Based Culling Filter & Blank Tag Prevention
            local withinRange = distStuds <= maxDistStuds
            if not showTags or not withinRange then
                tag.Enabled = false
            else
                tag.Enabled = true
                local label = tag:FindFirstChildOfClass("TextLabel")
                if label then
                    -- Real-Time Assembly of text lines based on exact global parameters (Fresh Local Text String Builder)
                    local lines = {}
                    
                    -- Player Display Name Line
                    if showPlayer then
                        table.insert(lines, tostring(data.title))
                    end
                    
                    -- Dino Species Name & Growth Stage Line
                    local line2Text = ""
                    if showDino then
                        line2Text = "[" .. tostring(data.species) .. "]"
                    end
                    
                    if showGrowth and data.growth and data.growth ~= "" then
                        if line2Text ~= "" then
                            line2Text = line2Text .. " " .. tostring(data.growth)
                        else
                            line2Text = tostring(data.growth)
                        end
                    end
                    
                    if line2Text ~= "" then
                        table.insert(lines, line2Text)
                    end

                    -- Meter Distance Calculation (Studs to Meters: divide studs by 2.8)
                    if showDistance then
                        local distMeters = math.floor(distStuds / 2.8)
                        table.insert(lines, tostring(distMeters) .. "m")
                    end
                    
                    -- Directly overwrite the existing label's text cleanly with single text formatting
                    label.Text = table.concat(lines, "\n")
                end
            end
        end
    end
end

local function clearPriorExtinctionESP()
    for model, data in pairs(activeTags) do
        pcall(function()
            if data and data.tag then data.tag:Destroy() end
        end)
    end
    table.clear(activeTags)
    if espContainer then
        pcall(function()
            espContainer:Destroy()
        end)
        espContainer = nil
    end
end

local isLooping = false
task.spawn(function()
    while true do
        if _G.ToggleESP then
            isLooping = true
            pcall(scanEnvironment)
            pcall(handleDynamicUpdates)
        else
            if isLooping then
                isLooping = false
                clearPriorExtinctionESP()
            end
        end
        task.wait(1)
    end
end)


-- ============================================================================
-- AUTOWALK & AUTOGROW OBSTACLE-AVOIDANCE SIMULATION ENGINES
-- ============================================================================

local blacklistedFoliage = {}

local function pressKey(key)
    if not activeKeys[key] then
        activeKeys[key] = true
        pcall(function()
            VirtualUser:SetKeyDown(key:lower())
        end)
    end
end

local function releaseKey(key)
    if activeKeys[key] then
        activeKeys[key] = nil
        pcall(function()
            VirtualUser:SetKeyUp(key:lower())
        end)
    end
end

local function releaseAllKeys()
    for key, _ in pairs(activeKeys) do
        releaseKey(key)
    end
end

local function getNearestDinoPosition()
    local nearestPos = nil
    local nearestDist = math.huge
    local localCharacter = localPlayer and localPlayer.Character
    local localRoot = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
    if not localRoot then return nil end

    for model, data in pairs(activeTags) do
        if model and model.Parent and model ~= localCharacter then
            local part = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or (data.tag and data.tag.Adornee)
            if part then
                local dist = (localRoot.Position - part.Position).Magnitude
                if dist < nearestDist then
                    nearestDist = dist
                    nearestPos = part.Position
                end
            end
        end
    end
    return nearestPos
end

local function getNearestFoliagePosition()
    local nearestFoliage = nil
    local nearestDist = math.huge
    local localCharacter = localPlayer and localPlayer.Character
    local localRoot = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
    if not localRoot then return nil, nil end

    for _, desc in ipairs(workspace:GetDescendants()) do
        if desc:IsA("Model") or desc:IsA("BasePart") then
            local nameL = desc.Name:lower()
            if (nameL:find("foliage") or nameL:find("tree") or nameL:find("fern") or nameL:find("bush") or nameL:find("berry") or nameL:find("food") or nameL:find("leaves")) and not blacklistedFoliage[desc] then
                local part = desc:IsA("BasePart") and desc or desc:FindFirstChildOfClass("BasePart") or desc.PrimaryPart
                if part then
                    local dist = (localRoot.Position - part.Position).Magnitude
                    if dist < nearestDist then
                        nearestDist = dist
                        nearestFoliage = desc
                    end
                end
            end
        end
    end
    
    if nearestFoliage then
        local targetPart = nearestFoliage:IsA("BasePart") and nearestFoliage or nearestFoliage:FindFirstChildOfClass("BasePart") or nearestFoliage.PrimaryPart
        return targetPart.Position, nearestFoliage
    end
    return nil, nil
end

local function runAutowalk()
    local character = localPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not character or not humanoid or not hrp then return end

    -- Establish path agents with custom settings
    local path = PathfindingService:CreatePath({
        AgentRadius = 5,
        AgentHeight = 6,
        AgentCanJump = true,
        AgentSlopeLimit = 45,
        Costs = {
            SteepIncline = 100,
            ObstacleZone = 100
        }
    })

    local targetPos = _G.AutowalkTarget or getNearestDinoPosition()
    if not targetPos then
        -- Generate random wandering destination if no players/dinos are available on the map
        local randomAngle = math.rad(math.random(0, 360))
        targetPos = hrp.Position + Vector3.new(math.cos(randomAngle) * 50, 0, math.sin(randomAngle) * 50)
    end

    -- Compute the navigation routes
    local success, errorMessage = pcall(function()
        path:ComputeAsync(hrp.Position, targetPos)
    end)

    if success and path.Status == Enum.PathStatus.Success then
        local waypoints = path:GetWaypoints()
        for i = 2, #waypoints do
            local masterAutowalkActive = _G.ToggleAutowalk or _G.Autowalk or _G.Misc_Autowalk
            if not masterAutowalkActive or localPlayer.Character ~= character then break end
            
            local waypoint = waypoints[i]
            local currentPos = hrp.Position
            
            -- Direction vector determination
            local lookDirection = (waypoint.Position - currentPos).Unit
            if lookDirection.Magnitude == 0 or tostring(lookDirection) == "nan, nan, nan" then
                lookDirection = hrp.CFrame.LookVector
            end

            -- Raycast parameters setup (exclude character & tags)
            local raycastParams = RaycastParams.new()
            raycastParams.FilterDescendantsInstances = {character, getESPContainer()}
            raycastParams.FilterType = Enum.RaycastFilterType.Exclude

            -- Horizontal Ray obstacle scan (avoid trees, rocks, steep terrain meshes)
            local frontHit = workspace:Raycast(currentPos + Vector3.new(0, 2, 0), lookDirection * 15, raycastParams)
            if frontHit then
                -- Perpendicular turn retreat to avoid collision
                releaseKey("W")
                pressKey("A")
                task.wait(0.5)
                releaseKey("A")
                break -- Recalculate path completely
            end

            -- Vertical Downward Ray cliff scan (avoid steep drops, hills, cliffs)
            local forwardOffset = currentPos + lookDirection * 8
            local downHit = workspace:Raycast(forwardOffset + Vector3.new(0, 5, 0), Vector3.new(0, -18, 0), raycastParams)
            
            if downHit then
                -- Steep hill evaluation
                local normal = downHit.Normal
                local angle = math.deg(math.acos(normal.Y))
                if angle > 45 then
                    -- Halt and reverse steering
                    releaseKey("W")
                    pressKey("D")
                    task.wait(0.5)
                    releaseKey("D")
                    break -- Recalculate path
                end
            else
                -- Void detected (cliff edge)
                releaseKey("W")
                pressKey("S")
                task.wait(0.4)
                releaseKey("S")
                pressKey("A")
                task.wait(0.5)
                releaseKey("A")
                break -- Recalculate path
            end

            -- Object Space Alignment Steering Calculations
            local localTarget = hrp.CFrame:PointToObjectSpace(waypoint.Position)
            local angle = math.deg(math.atan2(localTarget.X, -localTarget.Y))

            -- Steer Left vs Right input adjustments based on object space orientation coordinates
            if math.abs(angle) > 15 then
                if angle < 0 then
                    pressKey("A")
                    releaseKey("D")
                else
                    pressKey("D")
                    releaseKey("A")
                end
            else
                releaseKey("A")
                releaseKey("D")
            end

            -- Walk forward if generally facing the target waypoint
            if localTarget.Z < 0 or math.abs(angle) < 90 then
                pressKey("W")
            else
                releaseKey("W")
            end
            
            -- safety watchdog timer to prevent getting stuck
            local reached = false
            local timeout = 0
            while not reached and timeout < 20 do
                local loopCheckActive = _G.ToggleAutowalk or _G.Autowalk or _G.Misc_Autowalk
                if not loopCheckActive then break end
                if (hrp.Position - waypoint.Position).Magnitude < 4 then
                    reached = true
                end
                task.wait(0.1)
                timeout = timeout + 1
            end
        end
    else
        -- Unreachable target fallback direct walk input
        pressKey("W")
        task.wait(1)
    end
end

local function runAutogrow()
    local character = localPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not character or not humanoid or not hrp then return end

    local targetPos, foliageInstance = getNearestFoliagePosition()
    if not targetPos then
        -- Generate random wandering destination if no foliage is detected
        local randomAngle = math.rad(math.random(0, 360))
        targetPos = hrp.Position + Vector3.new(math.cos(randomAngle) * 50, 0, math.sin(randomAngle) * 50)
    end

    -- Compute the navigation routes
    local path = PathfindingService:CreatePath({
        AgentRadius = 5,
        AgentHeight = 6,
        AgentCanJump = true,
        AgentSlopeLimit = 45,
    })

    local success, errorMessage = pcall(function()
        path:ComputeAsync(hrp.Position, targetPos)
    end)

    if success and path.Status == Enum.PathStatus.Success then
        local waypoints = path:GetWaypoints()
        for i = 2, #waypoints do
            if not _G.ToggleAutogrow or localPlayer.Character ~= character then break end
            
            local waypoint = waypoints[i]
            local currentPos = hrp.Position

            -- Check distance to foliage to stop exactly 5 meters away (14 studs)
            local distanceToFoliage = (currentPos - targetPos).Magnitude
            if distanceToFoliage <= 14 then
                releaseAllKeys()
                
                -- Simulate physical eat interaction input 'E'
                pressKey("E")
                task.wait(0.2)
                releaseKey("E")
                
                -- Hold physical position to simulate eating action sequence
                task.wait(3)
                
                -- Temporarily blacklist foliage to prevent infinite loop on the same eaten instance
                if foliageInstance then
                    blacklistedFoliage[foliageInstance] = true
                    task.spawn(function()
                        task.wait(15)
                        blacklistedFoliage[foliageInstance] = nil
                    end)
                end
                break
            end

            -- Direction vector determination
            local lookDirection = (waypoint.Position - currentPos).Unit
            if lookDirection.Magnitude == 0 or tostring(lookDirection) == "nan, nan, nan" then
                lookDirection = hrp.CFrame.LookVector
            end

            -- Raycast parameters setup (exclude character & tags)
            local raycastParams = RaycastParams.new()
            raycastParams.FilterDescendantsInstances = {character, getESPContainer()}
            raycastParams.FilterType = Enum.RaycastFilterType.Exclude

            -- Horizontal Ray obstacle scan (avoid trees, rocks, steep terrain meshes)
            local frontHit = workspace:Raycast(currentPos + Vector3.new(0, 2, 0), lookDirection * 15, raycastParams)
            if frontHit then
                releaseKey("W")
                pressKey("A")
                task.wait(0.5)
                releaseKey("A")
                break -- Recalculate path completely
            end

            -- Vertical Downward Ray cliff scan (avoid steep drops, hills, cliffs)
            local forwardOffset = currentPos + lookDirection * 8
            local downHit = workspace:Raycast(forwardOffset + Vector3.new(0, 5, 0), Vector3.new(0, -18, 0), raycastParams)
            
            if downHit then
                -- Steep hill evaluation
                local normal = downHit.Normal
                local angle = math.deg(math.acos(normal.Y))
                if angle > 45 then
                    releaseKey("W")
                    pressKey("D")
                    task.wait(0.5)
                    releaseKey("D")
                    break -- Recalculate path
                end
            else
                -- Void detected (cliff edge)
                releaseKey("W")
                pressKey("S")
                task.wait(0.4)
                releaseKey("S")
                pressKey("A")
                task.wait(0.5)
                releaseKey("A")
                break -- Recalculate path
            end

            -- Object Space Alignment Steering Calculations
            local localTarget = hrp.CFrame:PointToObjectSpace(waypoint.Position)
            local angle = math.deg(math.atan2(localTarget.X, -localTarget.Y))

            -- Steer Left vs Right input adjustments based on object space orientation coordinates
            if math.abs(angle) > 15 then
                if angle < 0 then
                    pressKey("A")
                    releaseKey("D")
                else
                    pressKey("D")
                    releaseKey("A")
                end
            else
                releaseKey("A")
                releaseKey("D")
            end

            -- Walk forward if generally facing the target waypoint
            if localTarget.Z < 0 or math.abs(angle) < 90 then
                pressKey("W")
            else
                releaseKey("W")
            end
            
            -- safety watchdog timer to prevent getting stuck
            local reached = false
            local timeout = 0
            while not reached and timeout < 20 do
                if not _G.ToggleAutogrow then break end
                if (hrp.Position - waypoint.Position).Magnitude < 4 then
                    reached = true
                end
                task.wait(0.1)
                timeout = timeout + 1
            end
        end
    else
        -- Unreachable target fallback direct walk input
        local distanceToFoliage = (hrp.Position - targetPos).Magnitude
        if distanceToFoliage <= 14 then
            releaseAllKeys()
            pressKey("E")
            task.wait(0.2)
            releaseKey("E")
            task.wait(3)
            if foliageInstance then
                blacklistedFoliage[foliageInstance] = true
                task.spawn(function()
                    task.wait(15)
                    blacklistedFoliage[foliageInstance] = nil
                end)
            end
        else
            pressKey("W")
            task.wait(1)
        end
    end
end

-- Independent background thread handler for Autowalk loop execution
local isAutowalking = false
task.spawn(function()
    while true do
        local autowalkEnabled = _G.ToggleAutowalk or _G.Autowalk or _G.Misc_Autowalk
        if autowalkEnabled then
            isAutowalking = true
            pcall(runAutowalk)
        else
            if isAutowalking then
                isAutowalking = false
                releaseAllKeys()
            end
        end
        task.wait(0.1)
    end
end)

-- Independent background thread handler for Autogrow loop execution
local isAutogrowing = false
task.spawn(function()
    while true do
        local autogrowEnabled = _G.ToggleAutogrow
        if autogrowEnabled then
            isAutogrowing = true
            pcall(runAutogrow)
        else
            if isAutogrowing then
                isAutogrowing = false
                releaseAllKeys()
            end
        end
        task.wait(0.1)
    end
end)


-- ScreenGui Clean Deconstruct listener to prevent visual state memory leaks
screenGui.Destroying:Connect(function()
    toggleClearWater(false)
    toggleClearSleep(false)
    _G.ToggleESP = false
    _G.ToggleAutowalk = false
    _G.ToggleAutogrow = false
    releaseAllKeys()
    clearPriorExtinctionESP()
end)


-- ============================================================================
-- INTERACTIVE VISIBILITY KEYBIND TOGGLE (Non-Destructive Minimize API)
-- ============================================================================

-- Bind keyboard listener to cleanly switch active visibility without de-allocating configurations
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == currentKeybind then
        screenGui.Enabled = not screenGui.Enabled
    end
end)


-- ============================================================================
-- DYNAMIC PAGE DATA DICTIONARY (Precisely structured 7-tab configuration)
-- ============================================================================

local pagesData = {
    {
        id = "Home",
        title = "HOME PORTAL",
        desc = "",
        details = ""
    },
    {
        id = "Combat",
        title = "COMBAT CONFIGURATION",
        desc = "Manage automated battle loops and security control limits.",
        details = ""
    },
    {
        id = "Visuals",
        title = "VISUAL CONTROL ENGINE",
        desc = "Configure visual elements, rendering rates, and custom overlay filters.",
        details = ""
    },
    {
        id = "ESP",
        title = "EXTRA SENSORY PERCEPTION",
        desc = "Manage dimensional entity outlines and bounding box vectors.",
        details = ""
    },
    {
        id = "Misc",
        title = "MISCELLANEOUS CONTROLS",
        desc = "Modify user options, logging channels, and auxiliary engine rules.",
        details = "System Log: Autowalk Active\nObstacle Avoidance: Configured\nSlopes Cost Modifier: 100\nAgent Incline Limit: 45deg"
    },
    {
        id = "Configs",
        title = "INTERFACE CONFIGS",
        desc = "Persistent configuration profiles compiled as JSON state formats.",
        details = ""
    },
    {
        id = "Feedback",
        title = "USER FEEDBACK",
        desc = "Report overlay bugs or features directly to remote research endpoints.",
        details = ""
    }
}

local activeButtons = {}
local activePages = {}

-- Event-driven page switching logic
local function selectPage(targetId)
    for id, pageFrame in pairs(activePages) do
        pageFrame.Visible = (id == targetId)
    end

    local targetButton = activeButtons[targetId]
    if targetButton then
        highlightBox.Parent = targetButton
        highlightBox.Visible = true
    else
        highlightBox.Visible = false
    end
end

-- Generate Elements Dynamically
for i, data in ipairs(pagesData) do
    -- Create Sidebar Navigation Button
    local navButton = Instance.new("TextButton")
    navButton.Name = data.id .. "Btn"
    navButton.Size = UDim2.new(1, 0, 0, 32)
    navButton.BackgroundColor3 = BUTTON_BG
    navButton.BackgroundTransparency = BUTTON_BG_TRANSPARENCY
    navButton.BorderSizePixel = 0
    navButton.Text = "   " .. data.id:upper()
    navButton.TextColor3 = BUTTON_TEXT_COLOR
    navButton.TextSize = 11
    navButton.Font = FONT_FAMILY
    navButton.TextXAlignment = Enum.TextXAlignment.Left
    navButton.LayoutOrder = i
    navButton.Parent = sidebar

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = navButton

    local btnStroke = Instance.new("UIStroke")
    btnStroke.Color = Color3.fromRGB(45, 25, 65)
    btnStroke.Thickness = 1
    btnStroke.Parent = navButton

    activeButtons[data.id] = navButton

    -- Create Content Page Frame
    local pageFrame = Instance.new("Frame")
    pageFrame.Name = "Page" .. data.id
    pageFrame.Size = UDim2.new(1, 0, 1, 0)
    pageFrame.BackgroundTransparency = 1
    pageFrame.Visible = false
    pageFrame.Parent = container

    -- Specialized Page Building Cases
    if data.id == "Home" then
        -- Home Header Container
        local homeHeader = Instance.new("Frame")
        homeHeader.Name = "HomeHeader"
        homeHeader.Size = UDim2.new(1, 0, 0, 60)
        homeHeader.Position = UDim2.new(0, 0, 0, 0)
        homeHeader.BackgroundTransparency = 1
        homeHeader.Parent = pageFrame

        -- Circular Player Avatar Headshot
        local avatarImage = Instance.new("ImageLabel")
        avatarImage.Name = "UserAvatar"
        avatarImage.Size = UDim2.new(0, 50, 0, 50)
        avatarImage.Position = UDim2.new(0, 0, 0.5, -25)
        avatarImage.BackgroundTransparency = 1
        avatarImage.Image = avatarUrl
        avatarImage.Parent = homeHeader

        local avatarCorner = Instance.new("UICorner")
        avatarCorner.CornerRadius = UDim.new(1, 0)
        avatarCorner.Parent = avatarImage

        -- Two-Line Dynamic Greeting Layout
        local greetingContainer = Instance.new("Frame")
        greetingContainer.Name = "GreetingContainer"
        greetingContainer.Size = UDim2.new(1, -62, 1, 0)
        greetingContainer.Position = UDim2.new(0, 62, 0, 0)
        greetingContainer.BackgroundTransparency = 1
        greetingContainer.Parent = homeHeader

        local line1Label = Instance.new("TextLabel")
        line1Label.Name = "DynamicGreeting"
        line1Label.Size = UDim2.new(1, 0, 0.5, 0)
        line1Label.BackgroundTransparency = 1
        line1Label.Text = "Good Day " .. displayName
        line1Label.TextColor3 = TEXT_COLOR
        line1Label.TextSize = 14
        line1Label.Font = Enum.Font.GothamMedium
        line1Label.TextXAlignment = Enum.TextXAlignment.Left
        line1Label.TextYAlignment = Enum.TextYAlignment.Bottom
        line1Label.Parent = greetingContainer

        local line2Label = Instance.new("TextLabel")
        line2Label.Name = "StaticWelcome"
        line2Label.Size = UDim2.new(1, 0, 0.5, 0)
        line2Label.Position = UDim2.new(0, 0, 0.5, 0)
        line2Label.BackgroundTransparency = 1
        line2Label.Text = "Welcome To T6 Hub"
        line2Label.TextColor3 = LIGHT_TEXT
        line2Label.TextSize = 12
        line2Label.Font = FONT_FAMILY
        line2Label.TextXAlignment = Enum.TextXAlignment.Left
        line2Label.TextYAlignment = Enum.TextYAlignment.Top
        line2Label.Parent = greetingContainer

        -- Background chronological state checks to process dynamic hour parameters safely
        task.spawn(function()
            while task.wait(1) do
                local dateTable = os.date("*t")
                local hour = dateTable.hour

                -- Construct localized hour string greeting segment
                local greetingString = "Good Evening"
                if hour < 12 then
                    greetingString = "Good Morning"
                elseif hour < 18 then
                    greetingString = "Good Afternoon"
                end

                line1Label.Text = greetingString .. ", " .. displayName
            end
        end)

    elseif data.id == "Configs" then
        -- Core Titles
        local pageTitle = Instance.new("TextLabel")
        pageTitle.Size = UDim2.new(1, 0, 0, 24)
        pageTitle.BackgroundTransparency = 1
        pageTitle.Text = data.title
        pageTitle.TextColor3 = ACCENT_COLOR
        pageTitle.TextSize = 14
        pageTitle.Font = Enum.Font.GothamBold
        pageTitle.TextXAlignment = Enum.TextXAlignment.Left
        pageTitle.Parent = pageFrame

        local pageDesc = Instance.new("TextLabel")
        pageDesc.Size = UDim2.new(1, 0, 0, 30)
        pageDesc.Position = UDim2.new(0, 0, 0, 24)
        pageDesc.BackgroundTransparency = 1
        pageDesc.Text = data.desc
        pageDesc.TextColor3 = LIGHT_TEXT
        pageDesc.TextSize = 12
        pageDesc.Font = FONT_FAMILY
        pageDesc.TextWrapped = true
        pageDesc.TextXAlignment = Enum.TextXAlignment.Left
        pageDesc.TextYAlignment = Enum.TextYAlignment.Top
        pageDesc.Parent = pageFrame

        -- Active Config Card panel layout
        local detailsPanel = Instance.new("Frame")
        detailsPanel.Size = UDim2.new(1, 0, 1, -75)
        detailsPanel.Position = UDim2.new(0, 0, 0, 65)
        detailsPanel.BackgroundColor3 = PANEL_BG
        detailsPanel.BackgroundTransparency = 0.4
        detailsPanel.BorderSizePixel = 0
        detailsPanel.Parent = pageFrame

        local panelCorner = Instance.new("UICorner")
        panelCorner.CornerRadius = UDim.new(0, 6)
        panelCorner.Parent = detailsPanel

        local panelStroke = Instance.new("UIStroke")
        panelStroke.Color = Color3.fromRGB(40, 15, 60)
        panelStroke.Thickness = 1
        panelStroke.Parent = detailsPanel

        -- Profile Save Box Section
        local saveLabel = Instance.new("TextLabel")
        saveLabel.Size = UDim2.new(1, -30, 0, 20)
        saveLabel.Position = UDim2.new(0, 15, 0, 15)
        saveLabel.BackgroundTransparency = 1
        saveLabel.Text = "SAVE ACTIVE PROFILE"
        saveLabel.TextColor3 = LIGHT_TEXT
        saveLabel.TextSize = 11
        saveLabel.Font = Enum.Font.GothamBold
        saveLabel.TextXAlignment = Enum.TextXAlignment.Left
        saveLabel.Parent = detailsPanel

        local saveInput = Instance.new("TextBox")
        saveInput.Size = UDim2.new(1, -155, 0, 30)
        saveInput.Position = UDim2.new(0, 15, 0, 40)
        saveInput.BackgroundColor3 = PANEL_BG
        saveInput.BorderSizePixel = 0
        saveInput.PlaceholderText = "Profile Name..."
        saveInput.Text = ""
        saveInput.TextColor3 = Color3.fromRGB(255, 255, 255)
        saveInput.TextSize = 12
        saveInput.Font = FONT_FAMILY
        saveInput.TextXAlignment = Enum.TextXAlignment.Left
        saveInput.Parent = detailsPanel

        local inputPadding = Instance.new("UIPadding")
        inputPadding.PaddingLeft = UDim.new(0, 8)
        inputPadding.Parent = saveInput

        local inputCorner = Instance.new("UICorner")
        inputCorner.CornerRadius = UDim.new(0, 4)
        inputCorner.Parent = saveInput

        local inputStroke = Instance.new("UIStroke")
        inputStroke.Color = Color3.fromRGB(45, 25, 65)
        inputStroke.Thickness = 1
        inputStroke.Parent = saveInput

        -- Interactive "Save Profile" Configuration button with crisp high-fidelity rendering
        local saveBtn = Instance.new("TextButton")
        saveBtn.Size = UDim2.new(0, 110, 0, 30)
        saveBtn.Position = UDim2.new(1, -125, 0, 40)
        saveBtn.BackgroundColor3 = BUTTON_BG
        saveBtn.Text = "Save Profile"
        saveBtn.TextColor3 = BUTTON_TEXT_COLOR
        -- Anti-Aliasing Typography Adjustment: Defeat blurred rendering
        saveBtn.TextScaled = false
        saveBtn.TextSize = 14
        saveBtn.RichText = true
        saveBtn.Font = FONT_FAMILY
        saveBtn.Parent = detailsPanel

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 4)
        btnCorner.Parent = saveBtn

        local btnStroke = Instance.new("UIStroke")
        btnStroke.Color = ACCENT_COLOR
        btnStroke.Thickness = 1
        btnStroke.Parent = saveBtn

        -- Dropdown Container Profile Selector Section
        local loadLabel = Instance.new("TextLabel")
        loadLabel.Size = UDim2.new(1, -30, 0, 20)
        loadLabel.Position = UDim2.new(0, 15, 0, 85)
        loadLabel.BackgroundTransparency = 1
        loadLabel.Text = "LOAD PROFILE CONFIGURATION"
        loadLabel.TextColor3 = LIGHT_TEXT
        loadLabel.TextSize = 11
        loadLabel.Font = Enum.Font.GothamBold
        loadLabel.TextXAlignment = Enum.TextXAlignment.Left
        loadLabel.Parent = detailsPanel

        -- Dropdown Header Button
        local dropdownHeader = Instance.new("TextButton")
        dropdownHeader.Size = UDim2.new(1, -30, 0, 30)
        dropdownHeader.Position = UDim2.new(0, 15, 0, 110)
        dropdownHeader.BackgroundColor3 = PANEL_BG
        dropdownHeader.Text = "   Select Profile..."
        dropdownHeader.TextColor3 = BUTTON_TEXT_COLOR
        dropdownHeader.TextSize = 12
        dropdownHeader.Font = FONT_FAMILY
        dropdownHeader.TextXAlignment = Enum.TextXAlignment.Left
        dropdownHeader.Parent = detailsPanel

        local dropCorner = Instance.new("UICorner")
        dropCorner.CornerRadius = UDim.new(0, 4)
        dropCorner.Parent = dropdownHeader

        local dropStroke = Instance.new("UIStroke")
        dropStroke.Color = Color3.fromRGB(45, 25, 65)
        dropStroke.Thickness = 1
        dropStroke.Parent = dropdownHeader

        local dropdownList = Instance.new("ScrollingFrame")
        dropdownList.Size = UDim2.new(1, -30, 0, 90)
        dropdownList.Position = UDim2.new(0, 15, 0, 142)
        dropdownList.BackgroundColor3 = PANEL_BG
        dropdownList.BorderSizePixel = 0
        dropdownList.ScrollBarThickness = 4
        dropdownList.ScrollBarImageColor3 = ACCENT_COLOR
        dropdownList.Visible = false
        dropdownList.ZIndex = 5
        dropdownList.Parent = detailsPanel

        local dropListCorner = Instance.new("UICorner")
        dropListCorner.CornerRadius = UDim.new(0, 4)
        dropListCorner.Parent = dropdownList

        local dropListStroke = Instance.new("UIStroke")
        dropListStroke.Color = ACCENT_COLOR
        dropListStroke.Thickness = 1
        dropListStroke.Parent = dropdownList

        local dropdownLayout = Instance.new("UIListLayout")
        dropdownLayout.SortOrder = Enum.SortOrder.LayoutOrder
        dropdownLayout.Parent = dropdownList

        -- Expand/Collapse mechanism
        dropdownHeader.MouseButton1Click:Connect(function()
            dropdownList.Visible = not dropdownList.Visible
        end)

        -- Persistent Profile Management Engine: savefile/readfile mapping API
        local function serializeConfiguration(name)
            if not name or name == "" then return end
            uiState.keybind = currentKeybind.Name -- Include active keybind mapping in compilation
            local content = HttpService:JSONEncode(uiState)
            if writefile then
                pcall(function()
                    writefile("T6Hub_" .. name .. ".json", content)
                end)
            end
        end

        local function deserializeConfiguration(name)
            if not readfile then return end
            local success, content = pcall(readfile, "T6Hub_" .. name .. ".json")
            if success then
                local decodeSuccess, decoded = pcall(function() return HttpService:JSONDecode(content) end)
                if decodeSuccess and decoded then
                    -- Reset and assign loaded properties cleanly
                    if decoded.toggles then
                        for label, state in pairs(decoded.toggles) do
                            uiState.toggles[label] = state
                            if toggleRegistry[label] then
                                toggleRegistry[label](state)
                            end
                        end
                    end
                    if decoded.sliders then
                        for label, value in pairs(decoded.sliders) do
                            uiState.sliders[label] = value
                            if sliderRegistry[label] then
                                sliderRegistry[label](value)
                            end
                        end
                    end
                    if decoded.keybind then
                        local foundKey = Enum.KeyCode[decoded.keybind]
                        if foundKey then
                            currentKeybind = foundKey
                            if keybindUpdateRegistry then
                                keybindUpdateRegistry(currentKeybind.Name)
                            end
                        end
                    end
                end
            end
        end

        -- Update and populate options inside our custom dropdown
        local function rebuildDropdown()
            -- Clear previous dynamically built elements
            for _, child in ipairs(dropdownList:GetChildren()) do
                if child:IsA("TextButton") then
                    child:Destroy()
                end
            end

            local files = {}
            if listfiles then
                local success, fileList = pcall(listfiles, "")
                if success then
                    for _, filepath in ipairs(fileList) do
                        local match = filepath:match("T6Hub_(.*)%.json")
                        if match then
                            table.insert(files, match)
                        end
                    end
                end
            end

            -- Rebuild listing elements
            for _, configName in ipairs(files) do
                local selectBtn = Instance.new("TextButton")
                selectBtn.Size = UDim2.new(1, 0, 0, 30)
                selectBtn.BackgroundColor3 = PANEL_BG
                selectBtn.BackgroundTransparency = 1
                selectBtn.Text = "   " .. configName
                selectBtn.TextColor3 = LIGHT_TEXT
                selectBtn.TextSize = 11
                selectBtn.Font = FONT_FAMILY
                selectBtn.TextXAlignment = Enum.TextXAlignment.Left
                selectBtn.ZIndex = 6
                selectBtn.Parent = dropdownList

                selectBtn.MouseButton1Click:Connect(function()
                    deserializeConfiguration(configName)
                    dropdownHeader.Text = "   " .. configName
                    dropdownList.Visible = false
                end)
            end
            dropdownList.CanvasSize = UDim2.new(0, 0, 0, dropdownLayout.AbsoluteContentSize.Y)
        end

        saveBtn.MouseButton1Click:Connect(function()
            local rawName = saveInput.Text:gsub("%s+", "")
            if rawName ~= "" then
                serializeConfiguration(rawName)
                saveInput.Text = ""
                rebuildDropdown()
            end
        end)

        rebuildDropdown()

        -- Keybind Configuration UI Component Section
        local keybindLabel = Instance.new("TextLabel")
        keybindLabel.Size = UDim2.new(1, -30, 0, 20)
        keybindLabel.Position = UDim2.new(0, 15, 0, 155)
        keybindLabel.BackgroundTransparency = 1
        keybindLabel.Text = "MENU KEYBIND CONFIGURATION"
        keybindLabel.TextColor3 = LIGHT_TEXT
        keybindLabel.TextSize = 11
        keybindLabel.Font = Enum.Font.GothamBold
        keybindLabel.TextXAlignment = Enum.TextXAlignment.Left
        keybindLabel.Parent = detailsPanel

        local keybindBtn = Instance.new("TextButton")
        keybindBtn.Size = UDim2.new(1, -30, 0, 30)
        keybindBtn.Position = UDim2.new(0, 15, 0, 180)
        keybindBtn.BackgroundColor3 = PANEL_BG
        keybindBtn.Text = "   " .. currentKeybind.Name
        keybindBtn.TextColor3 = BUTTON_TEXT_COLOR
        keybindBtn.TextSize = 12
        keybindBtn.Font = FONT_FAMILY
        keybindBtn.TextXAlignment = Enum.TextXAlignment.Left
        keybindBtn.Parent = detailsPanel

        local keyCorner = Instance.new("UICorner")
        keyCorner.CornerRadius = UDim.new(0, 4)
        keyCorner.Parent = keybindBtn

        local keyStroke = Instance.new("UIStroke")
        keyStroke.Color = Color3.fromRGB(45, 25, 65)
        keyStroke.Thickness = 1
        keyStroke.Parent = keybindBtn

        -- Listening logic for hardware capture event
        local listeningForKey = false
        keybindBtn.MouseButton1Click:Connect(function()
            if listeningForKey then return end
            listeningForKey = true
            keybindBtn.Text = "   [Press Any Key]"

            local keyCaptureConnection
            keyCaptureConnection = UserInputService.InputBegan:Connect(function(input, gp)
                if input.UserInputType == Enum.UserInputType.Keyboard then
                    currentKeybind = input.KeyCode
                    keybindBtn.Text = "   " .. currentKeybind.Name
                    listeningForKey = false
                    keyCaptureConnection:Disconnect()
                end
            end)
        end)

        -- Expose keybind label update function externally
        keybindUpdateRegistry = function(keyName)
            keybindBtn.Text = "   " .. keyName
        end

    elseif data.id == "Feedback" then
        -- Bug report Feedback submission Panel
        local pageTitle = Instance.new("TextLabel")
        pageTitle.Size = UDim2.new(1, 0, 0, 24)
        pageTitle.BackgroundTransparency = 1
        pageTitle.Text = data.title
        pageTitle.TextColor3 = ACCENT_COLOR
        pageTitle.TextSize = 14
        pageTitle.Font = Enum.Font.GothamBold
        pageTitle.TextXAlignment = Enum.TextXAlignment.Left
        pageTitle.Parent = pageFrame

        local pageDesc = Instance.new("TextLabel")
        pageDesc.Size = UDim2.new(1, 0, 0, 24)
        pageDesc.Position = UDim2.new(0, 0, 0, 24)
        pageDesc.BackgroundTransparency = 1
        pageDesc.Text = data.desc
        pageDesc.TextColor3 = LIGHT_TEXT
        pageDesc.TextSize = 12
        pageDesc.Font = FONT_FAMILY
        pageDesc.TextWrapped = true
        pageDesc.TextXAlignment = Enum.TextXAlignment.Left
        pageDesc.TextYAlignment = Enum.TextYAlignment.Top
        pageDesc.Parent = pageFrame

        local detailsPanel = Instance.new("Frame")
        detailsPanel.Size = UDim2.new(1, 0, 1, -75)
        detailsPanel.Position = UDim2.new(0, 0, 0, 65)
        detailsPanel.BackgroundColor3 = PANEL_BG
        detailsPanel.BackgroundTransparency = 0.4
        detailsPanel.BorderSizePixel = 0
        detailsPanel.Parent = pageFrame

        local panelCorner = Instance.new("UICorner")
        panelCorner.CornerRadius = UDim.new(0, 6)
        panelCorner.Parent = detailsPanel

        local panelStroke = Instance.new("UIStroke")
        panelStroke.Color = Color3.fromRGB(40, 15, 60)
        panelStroke.Thickness = 1
        panelStroke.Parent = detailsPanel

        -- Multi-Line Feedback Input field
        local feedbackInput = Instance.new("TextBox")
        feedbackInput.Size = UDim2.new(1, -30, 1, -85)
        feedbackInput.Position = UDim2.new(0, 15, 0, 15)
        feedbackInput.BackgroundColor3 = PANEL_BG
        feedbackInput.BorderSizePixel = 0
        feedbackInput.MultiLine = true
        feedbackInput.ClearTextOnFocus = false
        feedbackInput.TextWrapped = true
        feedbackInput.PlaceholderText = "Type your feedback here..."
        feedbackInput.Text = ""
        feedbackInput.TextColor3 = Color3.fromRGB(255, 255, 255)
        feedbackInput.TextSize = 12
        feedbackInput.Font = FONT_FAMILY
        feedbackInput.TextXAlignment = Enum.TextXAlignment.Left
        feedbackInput.TextYAlignment = Enum.TextYAlignment.Top
        feedbackInput.Parent = detailsPanel

        local feedbackPadding = Instance.new("UIPadding")
        feedbackPadding.PaddingLeft = UDim.new(0, 10)
        feedbackPadding.PaddingTop = UDim.new(0, 10)
        feedbackPadding.PaddingRight = UDim.new(0, 10)
        feedbackPadding.Parent = feedbackInput

        local feedbackInputCorner = Instance.new("UICorner")
        feedbackInputCorner.CornerRadius = UDim.new(0, 6)
        feedbackInputCorner.Parent = feedbackInput

        local feedbackInputStroke = Instance.new("UIStroke")
        feedbackInputStroke.Color = Color3.fromRGB(45, 25, 65)
        feedbackInputStroke.Thickness = 1
        feedbackInputStroke.Parent = feedbackInput

        -- Interactive "Submit" feedback button with anti-aliasing typography adjustment
        local submitBtn = Instance.new("TextButton")
        submitBtn.Size = UDim2.new(1, -30, 0, 36)
        submitBtn.Position = UDim2.new(0, 15, 1, -51)
        submitBtn.BackgroundColor3 = BUTTON_BG
        submitBtn.Text = "SUBMIT FEEDBACK"
        submitBtn.TextColor3 = BUTTON_TEXT_COLOR
        -- Anti-Aliasing Typography Adjustment: Defeat blurred rendering
        submitBtn.TextScaled = false
        submitBtn.TextSize = 14
        submitBtn.RichText = true
        submitBtn.Font = Enum.Font.GothamBold
        submitBtn.Parent = detailsPanel

        local submitCorner = Instance.new("UICorner")
        submitCorner.CornerRadius = UDim.new(0, 6)
        submitCorner.Parent = submitBtn

        local submitStroke = Instance.new("UIStroke")
        submitStroke.Color = ACCENT_COLOR
        submitStroke.Thickness = 1.5
        submitStroke.Parent = submitBtn

        -- Webhook Routing Logic (Platform Compliant Forwarding Proxy)
        submitBtn.MouseButton1Click:Connect(function()
            local feedbackString = feedbackInput.Text
            if feedbackString == "" then return end

            local requestFunc = syn and syn.request or http and http.request or request
            if requestFunc then
                -- Package formatted secure JSON payload structure
                local bodyPayload = {
                    embeds = {
                        {
                            title = "User Feedback Received",
                            color = 9175295, -- Dec representation of ACCENT_COLOR
                            fields = {
                                { name = "User DisplayName", value = displayName, inline = true },
                                { name = "User ID", value = tostring(userId), inline = true },
                                { name = "Feedback", value = feedbackString }
                            }
                        }
                    }
                }

                -- Clean target submission through a secure platform-compliant proxy
                task.spawn(function()
                    pcall(function()
                        requestFunc({
                            Url = "https://webhook.lewisakura.moe/api/webhooks/1111111111111111/PlaceholderURLVariable",
                            Method = "POST",
                            Headers = { ["Content-Type"] = "application/json" },
                            Body = HttpService:JSONEncode(bodyPayload)
                        })
                    end)
                end)
            end

            feedbackInput.Text = ""
        end)

    else
        -- Standard dynamic configuration template page layout (Combat/Visuals/Misc/ESP)
        local pageTitle = Instance.new("TextLabel")
        pageTitle.Size = UDim2.new(1, 0, 0, 24)
        pageTitle.BackgroundTransparency = 1
        pageTitle.Text = data.title
        pageTitle.TextColor3 = ACCENT_COLOR
        pageTitle.TextSize = 14
        pageTitle.Font = Enum.Font.GothamBold
        pageTitle.TextXAlignment = Enum.TextXAlignment.Left
        pageTitle.Parent = pageFrame

        local pageDesc = Instance.new("TextLabel")
        pageDesc.Size = UDim2.new(1, 0, 0, 40)
        pageDesc.Position = UDim2.new(0, 0, 0, 30)
        pageDesc.BackgroundTransparency = 1
        pageDesc.Text = data.desc
        pageDesc.TextColor3 = LIGHT_TEXT
        pageDesc.TextSize = 12
        pageDesc.Font = FONT_FAMILY
        pageDesc.TextWrapped = true
        pageDesc.TextXAlignment = Enum.TextXAlignment.Left
        pageDesc.TextYAlignment = Enum.TextYAlignment.Top
        pageDesc.Parent = pageFrame

        local detailsPanel = Instance.new("Frame")
        detailsPanel.Size = UDim2.new(1, 0, 1, -85)
        detailsPanel.Position = UDim2.new(0, 0, 0, 75)
        detailsPanel.BackgroundColor3 = PANEL_BG
        detailsPanel.BackgroundTransparency = 0.4
        detailsPanel.BorderSizePixel = 0
        detailsPanel.Parent = pageFrame

        local panelCorner = Instance.new("UICorner")
        panelCorner.CornerRadius = UDim.new(0, 6)
        panelCorner.Parent = detailsPanel

        local panelStroke = Instance.new("UIStroke")
        panelStroke.Color = Color3.fromRGB(40, 15, 60)
        panelStroke.Thickness = 1
        panelStroke.Parent = detailsPanel

        if data.id == "Visuals" or data.id == "Combat" or data.id == "ESP" or data.id == "Misc" then
            local componentList = Instance.new("Frame")
            componentList.Size = UDim2.new(1, -30, 1, -30)
            componentList.Position = UDim2.new(0, 15, 0, 15)
            componentList.BackgroundTransparency = 1
            componentList.Parent = detailsPanel

            local componentLayout = Instance.new("UIListLayout")
            componentLayout.Padding = UDim.new(0, 12)
            componentLayout.SortOrder = Enum.SortOrder.LayoutOrder
            componentLayout.Parent = componentList

            if data.id == "Combat" then
                createToggleComponent(componentList, "Aim Target Tracking")
                createSliderComponent(componentList, "Smoothing Range Vector", 35)
            elseif data.id == "Visuals" then
                -- Clear Water Toggle
                createToggleComponent(componentList, "Clear Water", function(state)
                    toggleClearWater(state)
                end)
                -- Clear Sleep Toggle (Hides full-screen black sleep frames)
                createToggleComponent(componentList, "Clear Sleep", function(state)
                    toggleClearSleep(state)
                end)
                createSliderComponent(componentList, "Draw Render Distance Limit", 75)
            elseif data.id == "ESP" then
                -- ESP Active Toggle (Toggles global _G.ToggleESP variable)
                createToggleComponent(componentList, "ESP Active", function(state)
                    _G.ToggleESP = state
                end)
                -- Dynamic Modular Data Toggles
                createToggleComponent(componentList, "Show Player Names", function(state)
                    _G.ESP_ShowPlayerName = state
                end)
                createToggleComponent(componentList, "Show Dino Species", function(state)
                    _G.ESP_ShowDinoName = state
                end)
                createToggleComponent(componentList, "Show Growth Stage", function(state)
                    _G.ESP_ShowGrowthStage = state
                end)
                createToggleComponent(componentList, "Show Distance", function(state)
                    _G.ESP_ShowDistance = state
                end)
                -- Dynamic Max Distance Limit range configurator slider integration
                createDistanceSliderComponent(componentList, "ESP Max Distance", 50, 1500, _G.ESP_MaxDistance, function(val)
                    _G.ESP_MaxDistance = val
                end)
            elseif data.id == "Misc" then
                -- Autowalk Master Switch configuration inside Misc Tab
                createToggleComponent(componentList, "Autowalk Active", function(state)
                    _G.ToggleAutowalk = state
                end)
                createToggleComponent(componentList, "Autogrow Active", function(state)
                    _G.ToggleAutogrow = state
                end)
                -- Dynamic text specifications detailing
                if data.details and data.details ~= "" then
                    local panelText = Instance.new("TextLabel")
                    panelText.Size = UDim2.new(1, -20, 0, 80)
                    panelText.Position = UDim2.new(0, 10, 0, 130)
                    panelText.BackgroundTransparency = 1
                    panelText.Text = data.details
                    panelText.TextColor3 = TEXT_COLOR
                    panelText.TextSize = 11
                    panelText.Font = FONT_FAMILY
                    panelText.TextXAlignment = Enum.TextXAlignment.Left
                    panelText.TextYAlignment = Enum.TextYAlignment.Top
                    panelText.TextWrapped = true
                    panelText.LineHeight = 1.3
                    panelText.Parent = componentList
                end
            end
        else
            if data.details and data.details ~= "" then
                local panelText = Instance.new("TextLabel")
                panelText.Size = UDim2.new(1, -20, 1, -20)
                panelText.Position = UDim2.new(0, 10, 0, 10)
                panelText.BackgroundTransparency = 1
                panelText.Text = data.details
                panelText.TextColor3 = TEXT_COLOR
                panelText.TextSize = 11
                panelText.Font = FONT_FAMILY
                panelText.TextXAlignment = Enum.TextXAlignment.Left
                panelText.TextYAlignment = Enum.TextYAlignment.Top
                panelText.TextWrapped = true
                panelText.LineHeight = 1.3
                panelText.Parent = detailsPanel
            end
        end
    end

    activePages[data.id] = pageFrame

    navButton.MouseButton1Click:Connect(function()
        selectPage(data.id)
    end)
end

-- Initialize default page selection state
selectPage("Home")


-- ============================================================================
-- DYNAMIC TYPEWRITER INTRO LOGIC (Capitalized & Refined Timing)
-- ============================================================================

-- Create centered temporary "T6 HUB" label directly inside the Main Frame
local introLabel = Instance.new("TextLabel")
introLabel.Name = "BoundedIntroText"
introLabel.Size = UDim2.new(1, 0, 1, 0)
introLabel.Position = UDim2.new(0, 0, 0, 0)
introLabel.BackgroundTransparency = 1
introLabel.Text = "" -- Initialize empty per typewriter constraints
introLabel.TextColor3 = Color3.fromRGB(200, 50, 255) -- Neon Purple
introLabel.TextSize = 76
introLabel.Font = Enum.Font.FredokaOne -- Round, smooth modern typeface
introLabel.ZIndex = 4
introLabel.Parent = mainFrame

-- Start typewriter execution timeline sequence tracking (noticeably slower delay)
local targetString = "T6 HUB"
local characterDelay = 0.25 -- Increased delay so each letter typing out is distinct

for i = 1, #targetString do
    introLabel.Text = string.sub(targetString, 1, i)
    task.wait(characterDelay)
end

-- Transition Hold: Hold the completed text stably on screen before reveal
task.wait(0.8)

-- Clean transition: Fade out typewriter loading text
local fadeOutInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local fadeOutTween = TweenService:Create(introLabel, fadeOutInfo, {TextTransparency = 1})

fadeOutTween:Play()
fadeOutTween.Completed:Wait()

-- Destroy the temporary intro text cleanly
introLabel:Destroy()

-- Main UI Reveal Phase: Safely toggle, reveal container backgrounds, borders, and main assets
mainStroke.Transparency = 1 -- Setup outline to fade in
mainStroke.Enabled = true

local revealBgTween = TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0})
local revealStrokeTween = TweenService:Create(mainStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency = 0})

revealBgTween:Play()
revealStrokeTween:Play()

-- Yield slightly for layout rendering thread parity
task.wait(0.1)

headerFrame.Visible = true
horizontalDivider.Visible = true
sidebar.Visible = true
verticalDivider.Visible = true
container.Visible = true

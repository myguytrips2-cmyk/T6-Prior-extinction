local TOGGLE_KEY = "U"
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local localPlayer = Players.LocalPlayer

-- Active Thread Garbage Collector (Disconnects older running loops to stop multi-instance lag spikes)
if _G.DinoHUDConnection then
    pcall(function() _G.DinoHUDConnection:Disconnect() end)
    _G.DinoHUDConnection = nil
end

if CoreGui:FindFirstChild("DinoSurvivalHUD") then 
    pcall(function() CoreGui.DinoSurvivalHUD:Destroy() end) 
end

local hudContainer = Instance.new("ScreenGui") 
hudContainer.Name = "DinoSurvivalHUD"
hudContainer.ResetOnSpawn = false
hudContainer.Parent = CoreGui

local WAYPOINTS = {
    {Name = "Sandy Shores Oasis", Pos = Vector3.new(5100, -504, 916), Color = Color3.fromRGB(0, 210, 255)},
    {Name = "Great Swamp", Pos = Vector3.new(-1200, -480, -3400), Color = Color3.fromRGB(80, 220, 100)},
    {Name = "Central Drinking Hole", Pos = Vector3.new(200, -500, 400), Color = Color3.fromRGB(255, 200, 50)},
    {Name = "Deep Ocean Trench", Pos = Vector3.new(8500, -900, 4200), Color = Color3.fromRGB(50, 100, 255)},
    {Name = "Inland Safety Caves", Pos = Vector3.new(-3400, -320, 1800), Color = Color3.fromRGB(200, 100, 250)}
}

local HUDState = {
    LastMB1 = 0, LastMB2 = 0,
    MB1Max = 1.25, MB2Max = 3.40,
    BleedEnd = 0, BoneEnd = 0,
    TextCache = {}, CarcassCache = {}
}

local mapO = Instance.new("Frame") mapO.BackgroundTransparency = 1; mapO.Parent = hudContainer
local mBox = Instance.new("Frame") mBox.Size = UDim2.new(0, 280, 0, 50); mBox.BackgroundTransparency = 0.3; mBox.BackgroundColor3 = Color3.fromRGB(15, 15, 20); mBox.Parent = mapO
local c1 = Instance.new("UICorner") c1.CornerRadius = UDim.new(0, 6); c1.Parent = mBox
local subL = Instance.new("TextLabel") subL.Size = UDim2.new(1, 0, 0, 22); subL.Position = UDim2.new(0, 8, 0, 3); subL.TextColor3 = Color3.fromRGB(240, 180, 40); subL.Font = Enum.Font.Code; subL.TextSize = 13; subL.TextXAlignment = Enum.TextXAlignment.Left; subL.BackgroundTransparency = 1; subL.Parent = mBox
local adL = Instance.new("TextLabel") adL.Size = UDim2.new(1, 0, 0, 22); adL.Position = UDim2.new(0, 8, 0, 23); adL.TextColor3 = Color3.fromRGB(255, 255, 255); adL.Font = Enum.Font.Code; adL.TextSize = 13; adL.TextXAlignment = Enum.TextXAlignment.Left; adL.BackgroundTransparency = 1; adL.Parent = mBox

local dBox = Instance.new("Frame") dBox.Size = UDim2.new(0, 240, 0, 50); dBox.BackgroundTransparency = 0.3; dBox.BackgroundColor3 = Color3.fromRGB(20, 10, 10); dBox.Parent = mapO
local c2 = Instance.new("UICorner") c2.CornerRadius = UDim.new(0, 6); c2.Parent = dBox
local dT = Instance.new("TextLabel") dT.Size = UDim2.new(1, 0, 0, 18); dT.Position = UDim2.new(0, 8, 0, 2); dT.Text = "⚠️ NUTRIENT DEFICIENCIES (<90%)"; dT.TextColor3 = Color3.fromRGB(255, 75, 75); dT.Font = Enum.Font.SourceSansBold; dT.TextSize = 12; dT.TextXAlignment = Enum.TextXAlignment.Left; dT.BackgroundTransparency = 1; dT.Parent = dBox
local dA = Instance.new("TextLabel") dA.Size = UDim2.new(1, 0, 0, 24); dA.Position = UDim2.new(0, 8, 0, 20); dA.Text = "DIET OPTIMAL"; dA.TextColor3 = Color3.fromRGB(100, 255, 100); dA.Font = Enum.Font.Code; dA.TextSize = 12; dA.TextXAlignment = Enum.TextXAlignment.Left; dA.BackgroundTransparency = 1; dA.Parent = dBox
local aF = Instance.new("Frame") aF.Size = UDim2.new(0, 320, 0, 90); aF.Position = UDim2.new(0.015, 0, 0.72, 0); aF.BackgroundTransparency = 1; aF.Parent = hudContainer
local l1 = Instance.new("TextLabel") l1.Size = UDim2.new(1, 0, 0, 20); l1.TextColor3 = Color3.fromRGB(255, 255, 255); l1.Font = Enum.Font.Code; l1.TextSize = 14; l1.TextXAlignment = Enum.TextXAlignment.Left; l1.BackgroundTransparency = 1; l1.Parent = aF
local l2 = Instance.new("TextLabel") l2.Size = UDim2.new(1, 0, 0, 20); l2.Position = UDim2.new(0, 0, 0, 22); l2.TextColor3 = Color3.fromRGB(255, 255, 255); l2.Font = Enum.Font.Code; l2.TextSize = 14; l2.TextXAlignment = Enum.TextXAlignment.Left; l2.BackgroundTransparency = 1; l2.Parent = aF
local bL = Instance.new("TextLabel") bL.Size = UDim2.new(1, 0, 0, 20); bL.Position = UDim2.new(0, 0, 0, 44); bL.Font = Enum.Font.Code; bL.TextSize = 14; bL.TextXAlignment = Enum.TextXAlignment.Left; bL.BackgroundTransparency = 1; bL.Parent = aF
local fL = Instance.new("TextLabel") fL.Size = UDim2.new(1, 0, 0, 20); fL.Position = UDim2.new(0, 0, 0, 66); fL.Font = Enum.Font.Code; fL.TextSize = 14; fL.TextXAlignment = Enum.TextXAlignment.Left; fL.BackgroundTransparency = 1; fL.Parent = aF

local sT = Instance.new("TextLabel") sT.Size = UDim2.new(0, 150, 0, 20); sT.TextColor3 = Color3.fromRGB(255, 255, 255); sT.Font = Enum.Font.Code; sT.TextSize = 14; sT.BackgroundTransparency = 1; sT.Parent = hudContainer
local oT = Instance.new("TextLabel") oT.Size = UDim2.new(0, 150, 0, 20); oT.TextColor3 = Color3.fromRGB(255, 255, 255); oT.Font = Enum.Font.Code; oT.TextSize = 14; oT.BackgroundTransparency = 1; oT.Parent = hudContainer

if localPlayer then localPlayer.CameraMaxZoomDistance = 999999 localPlayer.CameraMinZoomDistance = 0.5 end
Lighting.Ambient, Lighting.OutdoorAmbient, Lighting.Brightness, Lighting.GlobalShadows = Color3.fromRGB(150, 150, 150), Color3.fromRGB(150, 150, 150), 1.5, false

_G.LMB, _G.RMB = _G.LMB or 0, _G.RMB or 0
local bEnd, fEnd = 0, 0
local cachedStaminaBar, cachedAirBar, cachedMapFrame = nil, nil, nil
local lastUICheckTime, lastCarcassScanTime = 0, 0

local function updateTextSafe(labelObject, dynamicString)
    if HUDState.TextCache[labelObject] ~= dynamicString then
        HUDState.TextCache[labelObject] = dynamicString
        labelObject.Text = dynamicString
    end
end

local function f4(v) return string.format("%04d", math.floor(v)) end

local function adjustFallbacks()
    local camera = Workspace.CurrentCamera
    if camera and not cachedStaminaBar then
        local viewY = math.max(400, camera.ViewportSize.Y)
        local viewX = math.max(100, camera.ViewportSize.X)
        sT.Position = UDim2.new(0, math.min(200, viewX * 0.15), 0, viewY - 220)
    end
end
Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(adjustFallbacks)
adjustFallbacks()

UserInputService.InputBegan:Connect(function(inputObj, isProcessed)
    local activeTextBox = UserInputService:GetFocusedTextBox()
    if activeTextBox and activeTextBox.Parent then return end
    if isProcessed then return end
    
    if inputObj.KeyCode == Enum.KeyCode[TOGGLE_KEY:upper()] then 
        hudContainer.Enabled = not hudContainer.Enabled 
    end
    if inputObj.UserInputType == Enum.UserInputType.MouseButton1 then 
        HUDState.LastMB1 = os.clock()
    elseif inputObj.UserInputType == Enum.UserInputType.MouseButton2 then 
        HUDState.LastMB2 = os.clock() 
    end
end)

local function getWP(name, color)
    local d = mapO:FindFirstChild(name)
    if not d then
        d = Instance.new("TextLabel") d.Name = name; d.Size = UDim2.new(0, 12, 0, 12); d.BackgroundColor3 = color; d.Text = "♦"; d.TextColor3 = Color3.fromRGB(255,255,255); d.Font = Enum.Font.SourceSansBold; d.TextSize = 11; d.TextXAlignment = Enum.TextXAlignment.Center
        local c = Instance.new("UICorner") c.CornerRadius = UDim.new(1, 0); c.Parent = d
        local h = Instance.new("TextLabel") h.Name = "HoverLabel"; h.Size = UDim2.new(0, 130, 0, 18); h.Position = UDim2.new(0, -60, 0, -22); h.BackgroundColor3 = Color3.fromRGB(10,10,15); h.TextColor3 = color; h.Font = Enum.Font.Code; h.TextSize = 11; h.BackgroundTransparency = 0.2; h.Visible = true; h.Parent = d
        local hc = Instance.new("UICorner") hc.CornerRadius = UDim.new(0, 4); hc.Parent = h
        d.Parent = mapO
    end
    return d
end

_G.DinoHUDConnection = RunService.RenderStepped:Connect(function()
    local char = localPlayer.Character
    local root = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
    local curTime, camera = os.clock(), Workspace.CurrentCamera
    
    local viewBoundsX = math.max(100, camera.ViewportSize.X)
    local viewBoundsY = math.max(100, camera.ViewportSize.Y)

    local terrain = Workspace:FindFirstChildOfClass("Terrain")
    if terrain then terrain.WaterTransparency = 1; terrain.WaterColor = Color3.fromRGB(15, 45, 60); terrain.WaterWaveSize = 0; terrain.WaterWaveSpeed = 0 end
    Lighting.FogStart, Lighting.FogEnd = 999999, 999999
    
    pcall(function()
        for _, o in ipairs(Lighting:GetChildren()) do 
            if o:IsA("Atmosphere") or o:IsA("BlurEffect") or o:IsA("DepthOfFieldEffect") then o:Destroy() end 
        end
        if localPlayer:FindFirstChild("PlayerGui") then
            for _, ui in ipairs(localPlayer.PlayerGui:GetDescendants()) do
                if ui:IsA("Frame") and (ui.Name:lower():match("sleep") or ui.Name:lower():match("blink") or ui.Name:lower():match("fade")) then ui.Visible = false; ui.BackgroundTransparency = 1 end
            end
        end
    end)

    local r1 = HUDState.MB1Max - (curTime - HUDState.LastMB1)
    if r1 > 0 then 
        updateTextSafe(l1, string.format("MB1 COOLDOWN: %ds %03dms", math.floor(r1), math.floor((r1 - math.floor(r1)) * 1000)))
        l1.TextColor3 = Color3.fromRGB(255, 100, 100)
    else 
        updateTextSafe(l1, "MB1 ATTACK: READY")
        l1.TextColor3 = Color3.fromRGB(100, 255, 100) 
    end
    
    local r2 = HUDState.MB2Max - (curTime - HUDState.LastMB2)
    if r2 > 0 then 
        updateTextSafe(l2, string.format("MB2 COOLDOWN: %ds %03dms", math.floor(r2), math.floor((r2 - math.floor(r2)) * 1000)))
        l2.TextColor3 = Color3.fromRGB(255, 100, 100)
    else 
        updateTextSafe(l2, "MB2 ATTACK: READY")
        l2.TextColor3 = Color3.fromRGB(100, 255, 100) 
    end
    if char and (char:FindFirstChild("BleedParticles") or char:FindFirstChild("BloodEffect")) and HUDState.BleedEnd < curTime then HUDState.BleedEnd = curTime + 15 end
    if HUDState.BleedEnd > curTime then 
        updateTextSafe(bL, string.format("STATUS: BLEEDING (%02.1fs)", HUDState.BleedEnd - curTime))
        bL.TextColor3 = Color3.fromRGB(255, 50, 50)
    else 
        updateTextSafe(bL, "STATUS: NO BLEED EFFECT")
        bL.TextColor3 = Color3.fromRGB(120, 120, 120) 
    end
    
    if char and char:FindFirstChild("Humanoid") and char.Humanoid.WalkSpeed < 12 and HUDState.BoneEnd < curTime then HUDState.BoneEnd = curTime + 30 end
    if HUDState.BoneEnd > curTime then 
        updateTextSafe(fL, string.format("STATUS: FRACTURED BONE (%02.1fs)", HUDState.BoneEnd - curTime))
        fL.TextColor3 = Color3.fromRGB(240, 140, 0)
    else 
        updateTextSafe(fL, "STATUS: SKELETON INTACT")
        fL.TextColor3 = Color3.fromRGB(120, 120, 120) 
    end

    if curTime - lastUICheckTime > 3 and localPlayer:FindFirstChild("PlayerGui") then
        lastUICheckTime = curTime
        cachedStaminaBar, cachedAirBar, cachedMapFrame = nil, nil, nil
        pcall(function()
            for _, u in ipairs(localPlayer.PlayerGui:GetDescendants()) do
                if u:IsA("TextLabel") and u.Text:match("/") and u.TextColor3.G > 0.8 then cachedStaminaBar = u
                elseif u:IsA("ImageLabel") and (u.Image:lower():match("bubble") or u.Name:lower():match("air")) then cachedAirBar = u 
                elseif u:IsA("Frame") and (u.Name:lower():match("minimap") or u.Name:lower():match("mapcontainer") or u:FindFirstChild("North")) then cachedMapFrame = u end
            end
        end)
    end

    if cachedStaminaBar and cachedStaminaBar.Parent then 
        staminaCustomText.Position = UDim2.new(0, cachedStaminaBar.AbsolutePosition.X + 85, 0, cachedStaminaBar.AbsolutePosition.Y)
        updateTextSafe(staminaCustomText, f4(59) .. " / " .. f4(59))
        cachedStaminaBar.Visible = false
    else 
        updateTextSafe(staminaCustomText, "[ " .. f4(59) .. " / " .. f4(59) .. " ]")
    end
    if cachedAirBar and cachedAirBar.Parent then 
        oT.Position = UDim2.new(0, cachedAirBar.AbsolutePosition.X + 60, 0, cachedAirBar.AbsolutePosition.Y)
        updateTextSafe(oT, "[ " .. f4(100) .. " / " .. f4(100) .. " ]")
    end

    local mX, mY, rad = viewBoundsX - 160, 160, 110
    if cachedMapFrame and cachedMapFrame.Parent then 
        mX = cachedMapFrame.AbsolutePosition.X + (cachedMapFrame.AbsoluteSize.X / 2)
        mY = cachedMapFrame.AbsolutePosition.Y + (cachedMapFrame.AbsoluteSize.Y / 2)
        local coreRingElement = cachedMapFrame:FindFirstChildOfClass("ImageLabel") or cachedMapFrame
        rad = math.min(coreRingElement.AbsoluteSize.X, coreRingElement.AbsoluteSize.Y) / 2 - 5
    end
    milestoneBox.Position = UDim2.new(0, mX - 270, 0, mY - rad - 62)
    dietBox.Position = UDim2.new(0, mX + 20, 0, mY - rad - 62)

    if root then
        pcall(function()
            local pct = math.clamp((root.Size.Y / 6) * 100, 5, 100)
            updateTextSafe(subL, string.format("TIME TO SUB-ADULT : %02dm 00s [%02d%%]", math.max(0, math.floor((55 - pct) * 0.45)), math.min(55, math.floor(pct))))
            updateTextSafe(adL, string.format("TIME TO FULL ADULT: %02dm 00s [%03d%%]", math.max(0, math.floor((100 - pct) * 0.68)), math.floor(pct)))
            if pct >= 55 then updateTextSafe(subL, "TIME TO SUB-ADULT : MET"); subL.TextColor3 = Color3.fromRGB(100, 255, 100) end
            if pct >= 100 then 
                updateTextSafe(adL, "TIME TO FULL ADULT: MET")
                adL.TextColor3 = Color3.fromRGB(100, 255, 100) 
            end
        end)
    end

    local h, w, d = 100, 100, 100
    pcall(function()
        if localPlayer:FindFirstChild("PlayerGui") then
            for _, v in ipairs(localPlayer.PlayerGui:GetDescendants()) do
                if v:IsA("TextLabel") and v.Visible then
                    local labelParentName = v.Parent and v.Parent.Name:lower() or ""
                    if labelParentName:match("stat") or labelParentName:match("bar") or labelParentName:match("hud") or labelParentName:match("container") then
                        local txt = v.Text or ""
                        local numString = txt:gsub("%D", "")
                        if numString ~= "" then
                            local num = tonumber(numString)
                            if num then
                                if v.Name:lower():match("hunger") or v.Name:lower():match("food") then h = num end
                                if v.Name:lower():match("water") or v.Name:lower():match("thirst") then w = num end
                                if v.Name:lower():match("diet") or v.Name:lower():match("nutrient") then d = num end
                            end
                        end
                    end
                end
            end
        end
    end)

    local active = {}
    if h < 90 then table.insert(active, "PROTEIN") end
    if w < 90 then table.insert(active, "HYDRATION") end
    if d < 90 then table.insert(active, "NUTRIENT") end
    if #active > 0 then 
        dBox.BackgroundColor3 = Color3.fromRGB(45, 15, 15)
        updateTextSafe(dA, "NEED: " .. table.concat(active, " | "))
        dA.TextColor3 = Color3.fromRGB(255, 100, 100)
    else 
        dBox.BackgroundColor3 = Color3.fromRGB(15, 20, 15)
        updateTextSafe(dA, "DIET OPTIMAL")
        dA.TextColor3 = Color3.fromRGB(100, 255, 100) 
    end

    if root then
        for _, wp in ipairs(WAYPOINTS) do
            pcall(function()
                local m = getWP(wp.Name, wp.Color)
                local worldOffset = wp.Pos - root.Position
                local localOffset = camera.CFrame:VectorToObjectSpace(worldOffset)
                local distance = math.floor(worldOffset.Magnitude)
                
                local relativeAngle = math.atan2(-localOffset.X, -localOffset.Z)
                m.Position = UDim2.new(0, mX + (math.sin(relativeAngle) * rad) - 6, 0, mY + (math.cos(relativeAngle) * rad) - 6)
                updateTextSafe(m.HoverLabel, string.format("%s (%04dm)", wp.Name:upper(), distance))
            end)
        end
    end

    if curTime - lastCarcassScanTime > 2.5 then
        lastCarcassScanTime = curTime
        HUDState.CarcassCache = {}
        pcall(function()
            for _, item in ipairs(Workspace:GetDescendants()) do
                if item:IsA("BasePart") and item.Parent and (item.Name:lower():match("meat") or item.Name:lower():match("corpse")) then
                    HUDState.CarcassCache[item] = item.Position
                end
            end
        end)
    end

    for item, initialPos in pairs(HUDState.CarcassCache) do
        pcall(function()
            if item and item.Parent and (item.Position - initialPos).Magnitude < 2 then
                local tag = item:FindFirstChild("CorpseDecayTag")
                if not tag then
                    tag = Instance.new("BillboardGui") tag.Name = "CorpseDecayTag"; tag.Size = UDim2.new(0, 150, 0, 25); tag.AlwaysOnTop = true; tag.MaxDistance = 400
                    local lbl = Instance.new("TextLabel") lbl.Name = "VolLabel"; lbl.Size = UDim2.new(1, 0, 1, 0); lbl.BackgroundTransparency = 0.3; lbl.BackgroundColor3 = Color3.fromRGB(10, 10, 15); lbl.Font = Enum.Font.Code; lbl.TextSize = 12; lbl.TextColor3 = Color3.fromRGB(255, 180, 50); lbl.Parent = tag
                    local cr = Instance.new("UICorner") cr.CornerRadius = UDim.new(0, 4); cr.Parent = lbl
                    tag.Parent = item
                end
                if item.Size then
                    local vol = math.floor(item.Size.X * item.Size.Y * item.Size.Z * 15)
                    if vol > 5 then updateTextSafe(tag.VolLabel, string.format("🥩 MEAT VOL: %04d UNIT", vol))
                    else updateTextSafe(tag.VolLabel, "Bone Leftovers (Depleted)"); tag.VolLabel.TextColor3 = Color3.fromRGB(150, 150, 150) end
                end
            end
        end)
    end

    for _, plyr in ipairs(Players:GetPlayers()) do
        if plyr ~= localPlayer and plyr.Character and plyr.Character:FindFirstChild("HumanoidRootPart") then
            pcall(function()
                local tRoot = plyr.Character.HumanoidRootPart
                local tag = tRoot:FindFirstChild("GrowthEstimatorTag")
                if not tag then
                    tag = Instance.new("BillboardGui") tag.Name = "GrowthEstimatorTag"; tag.Size = UDim2.new(0, 200, 0, 45); tag.AlwaysOnTop = true; tag.StudsOffset = Vector3.new(0, 6, 0)
                    local txt = Instance.new("TextLabel") txt.Name = "InfoLabel"; txt.Size = UDim2.new(1, 0, 0, 20); txt.BackgroundTransparency = 1; txt.Font = Enum.Font.SourceSansBold; txt.TextSize = 13; txt.Parent = tag
                    local subtxt = Instance.new("TextLabel") subtxt.Name = "StatusLabel"; subtxt.Size = UDim2.new(1, 0, 0, 20); subtxt.Position = UDim2.new(0,0,0,18); subtxt.BackgroundTransparency = 1; subtxt.Font = Enum.Font.Code; subtxt.TextSize = 11; subtxt.Parent = tag
                    tag.Parent = tRoot
                end
                
                local scaleY = tRoot.Size.Y
                local growthPercent = math.clamp(math.floor((scaleY / 6) * 100), 5, 100)
                local tierName = scaleY < 3 and "Juvenile" or (scaleY < 5.5 and "Sub-Adult" or "Adult")
                updateTextSafe(tag.InfoLabel, string.format("%s [%s ~ %d%%]", plyr.Name, tierName, growthPercent))
                tag.InfoLabel.TextColor3 = growthPercent > 70 and Color3.fromRGB(255, 70, 70) or Color3.fromRGB(100, 255, 100)

                local tBleed = plyr.Character:FindFirstChild("BleedParticles") or plyr.Character:FindFirstChild("BloodEffect")
                local tLimp = plyr.Character:FindFirstChild("Humanoid") and plyr.Character.Humanoid.WalkSpeed < 12
                local tBleed = plyr.Character:FindFirstChild("BleedParticles") or plyr.Character:FindFirstChild("BloodEffect")
                local tLimp = plyr.Character:FindFirstChild("Humanoid") and plyr.Character.Humanoid.WalkSpeed < 12
                if tBleed and tLimp then updateTextSafe(tag.StatusLabel, "⚠️ CRIPPLED & BLEEDING ⚠️"); tag.StatusLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
                elseif tBleed then updateTextSafe(tag.StatusLabel, "🩸 STATUS: BLEEDING"); tag.StatusLabel.TextColor3 = Color3.fromRGB(255, 75, 75)
                elseif tLimp then updateTextSafe(tag.StatusLabel, "🦴 STATUS: BONE BROKEN"); tag.StatusLabel.TextColor3 = Color3.fromRGB(240, 140, 0)
                else updateTextSafe(tag.StatusLabel, "💚 COND: HEALTHY"); tag.StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100) end
            end)
        end
    end
end)

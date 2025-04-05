local ESP = { 
    Enabled = false,
    Boxes = true,
    BoxShift = CFrame.new(0, -1.5, 0),
    BoxSize = Vector3.new(4, 6, 0),
    Color = Color3.fromRGB(255, 170, 0),
    FaceCamera = false,
    Names = true,
    TeamColor = true,
    Thickness = 2,
    AttachShift = 1,
    TeamMates = true,
    Players = true,
    Objects = setmetatable({}, {__mode="kv"}),
    Overrides = {}
}

local cam = workspace.CurrentCamera
local plrs = game:GetService("Players")
local plr = plrs.LocalPlayer
local mouse = plr:GetMouse()

local V3new = Vector3.new
local WorldToViewportPoint = cam.WorldToViewportPoint

local function Draw(obj, props)
    local new = Drawing.new(obj)
    props = props or {}
    for i, v in pairs(props) do
        new[i] = v
    end
    return new
end

function ESP:GetTeam(p)
    local ov = self.Overrides.GetTeam
    if ov then
        return ov(p)
    end
    return p and p.Team
end

function ESP:IsTeamMate(p)
    local ov = self.Overrides.IsTeamMate
    if ov then
        return ov(p)
    end
    return self:GetTeam(p) == self:GetTeam(plr)
end

function ESP:GetColor(obj)
    local ov = self.Overrides.GetColor
    if ov then
        return ov(obj)
    end
    local p = self:GetPlrFromChar(obj)
    return p and self.TeamColor and p.Team and p.Team.TeamColor.Color or self.Color
end

function ESP:GetPlrFromChar(char)
    local ov = self.Overrides.GetPlrFromChar
    if ov then
        return ov(char)
    end
    return plrs:GetPlayerFromCharacter(char)
end

function ESP:Toggle(bool)
    self.Enabled = bool
    if not bool then
        for i, v in pairs(self.Objects) do
            if v.Type == "Box" then
                if v.Temporary then
                    v:Remove()
                else
                    for i, v in pairs(v.Components) do
                        v.Visible = false
                    end
                end
            end
        end
    end
end

function ESP:AddObjectListener(parent, options)
    local function NewListener(c)
        if type(options.Type) == "string" and c:IsA(options.Type) or options.Type == nil then
            if type(options.Name) == "string" and c.Name == options.Name or options.Name == nil then
                if not options.Validator or options.Validator(c) then
                    local box = ESP:Add(c, {
                        PrimaryPart = type(options.PrimaryPart) == "string" and c:WaitForChild(options.PrimaryPart) or type(options.PrimaryPart) == "function" and options.PrimaryPart(c),
                        Color = type(options.Color) == "function" and options.Color(c) or options.Color,
                        Name = type(options.CustomName) == "function" and options.CustomName(c) or options.CustomName,
                        IsEnabled = options.IsEnabled,
                        RenderInNil = options.RenderInNil
                    })
                    if options.OnAdded then
                        coroutine.wrap(options.OnAdded)(box)
                    end
                end
            end
        end
    end

    if options.Recursive then
        parent.DescendantAdded:Connect(NewListener)
        for i, v in pairs(parent:GetDescendants()) do
            coroutine.wrap(NewListener)(v)
        end
    else
        parent.ChildAdded:Connect(NewListener)
        for i, v in pairs(parent:GetChildren()) do
            coroutine.wrap(NewListener)(v)
        end
    end
end

function ESP:Add(obj, options)
    if not obj.Parent and not options.RenderInNil then
        return warn(obj, "has no parent")
    end

    local box = setmetatable({
        Name = options.Name or obj.Name,
        Type = "Box",
        Color = options.Color or self:GetColor(obj),
        Size = options.Size or self.BoxSize,
        Object = obj,
        Player = options.Player or plrs:GetPlayerFromCharacter(obj),
        PrimaryPart = options.PrimaryPart or obj.ClassName == "Model" and (obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")) or obj:IsA("BasePart") and obj,
        Components = {},
        IsEnabled = options.IsEnabled,
        Temporary = options.Temporary,
        ColorDynamic = options.ColorDynamic,
        RenderInNil = options.RenderInNil
    }, boxBase)

    if self:GetBox(obj) then
        self:GetBox(obj):Remove()
    end

    box.Components["Quad"] = Draw("Quad", {
        Thickness = self.Thickness,
        Color = box.Color,
        Transparency = 1,
        Filled = false,
        Visible = self.Enabled and self.Boxes
    })

    box.Components["Name"] = Draw("Text", {
        Text = box.Name,
        Color = box.Color,
        Center = true,
        Outline = true,
        Size = 19,
        Visible = self.Enabled and self.Names
    })

    box.Components["Distance"] = Draw("Text", {
        Color = box.Color,
        Center = true,
        Outline = true,
        Size = 19,
        Visible = self.Enabled and self.Names
    })

    box.Components["Tracer"] = Draw("Line", {
        Thickness = ESP.Thickness,
        Color = box.Color,
        Transparency = 1,
        Visible = self.Enabled and self.Tracers
    })
    self.Objects[obj] = box
    
    obj.AncestryChanged:Connect(function(_, parent)
        if parent == nil then
            box:Remove()
        end
    end)

    local hum = obj:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.Died:Connect(function()
            box:Remove()
        end)
    end

    return box
end

local function is_gunsight(t)
    local sightparts = gun_system.currentgun and gun_system.currentgun.aimsightdata
    for _, sightdata in next, sightparts do
        if sightdata.sightpart == t then
            return true
        end
    end
    return false
end

local old_index = hookmetamethod(game, "__index", function(t, k)
    if k == "CFrame" and config.aimbot.silent_aim and gun_system.currentgun and (is_gunsight(t) or t == gun_system.currentgun.barrel) then
        local r = weighted_random({hit = config.aimbot.hit_chance, miss = 100 - config.aimbot.hit_chance})
        local cf = old_index(t, k)
        local c_player, c_bodyparts = get_closest()
        
        if c_player and c_bodyparts and c_player.Team ~= plr.Team and r == "hit" then
            return CFrame.new(
                cf.Position,
                c_bodyparts[config.aimbot.target_part].Position
            )
        end
    end
    return old_index(t, k)
end)

local function CharAdded(char)
    local p = plrs:GetPlayerFromCharacter(char)
    if not char:FindFirstChild("HumanoidRootPart") then
        local ev
        ev = char.ChildAdded:Connect(function(c)
            if c.Name == "HumanoidRootPart" then
                ev:Disconnect()
                ESP:Add(char, { Name = p.Name, Player = p, PrimaryPart = c })
            end
        end)
    else
        ESP:Add(char, { Name = p.Name, Player = p, PrimaryPart = char.HumanoidRootPart })
    end
end

local function PlayerAdded(p)
    p.CharacterAdded:Connect(CharAdded)
    if p.Character then
        coroutine.wrap(CharAdded)(p.Character)
    end
end

plrs.PlayerAdded:Connect(PlayerAdded)
for _, v in pairs(plrs:GetPlayers()) do
    if v ~= plr then
        PlayerAdded(v)
    end
end

game:GetService("RunService").RenderStepped:Connect(function()
    cam = workspace.CurrentCamera
    for _, v in (ESP.Enabled and pairs or ipairs)(ESP.Objects) do
        if v.Update then
            local success, err = pcall(v.Update, v)
            if not success then
                warn("[ESP Error]", err, v.Object:GetFullName())
            end
        end
    end
end)

local screenGui = Instance.new("ScreenGui")
screenGui.Parent = plr.PlayerGui

local frame = Instance.new("Frame")
frame.Parent = screenGui
frame.Size = UDim2.new(0, 200, 0, 300)
frame.Position = UDim2.new(0, 10, 0, 10)
frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
frame.BackgroundTransparency = 0.5
frame.BorderSizePixel = 0

local titleLabel = Instance.new("TextLabel")
titleLabel.Parent = frame
titleLabel.Size = UDim2.new(1, 0, 0, 50)
titleLabel.Text = "Aimbot & ESP"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 20
titleLabel.BackgroundTransparency = 1
titleLabel.TextAlign = Enum.TextAlign.Center

local espToggleButton = Instance.new("TextButton")
espToggleButton.Parent = frame
espToggleButton.Size = UDim2.new(1, 0, 0, 50)
espToggleButton.Position = UDim2.new(0, 0, 0, 60)
espToggleButton.Text = "Toggle ESP"
espToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
espToggleButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
espToggleButton.TextSize = 18

local aimbotToggleButton = Instance.new("TextButton")
aimbotToggleButton.Parent = frame
aimbotToggleButton.Size = UDim2.new(1, 0, 0, 50)
aimbotToggleButton.Position = UDim2.new(0, 0, 0, 120)
aimbotToggleButton.Text = "Toggle Aimbot"
aimbotToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
aimbotToggleButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
aimbotToggleButton.TextSize = 18

espToggleButton.MouseButton1Click:Connect(function()
    ESP:Toggle(not ESP.Enabled)
    if ESP.Enabled then
        espToggleButton.Text = "Toggle ESP (ON)"
    else
        espToggleButton.Text = "Toggle ESP (OFF)"
    end
end)

aimbotToggleButton.MouseButton1Click:Connect(function()
    config.aimbot.enabled = not config.aimbot.enabled
    if config.aimbot.enabled then
        aimbotToggleButton.Text = "Toggle Aimbot (ON)"
    else
        aimbotToggleButton.Text = "Toggle Aimbot (OFF)"
    end
end)

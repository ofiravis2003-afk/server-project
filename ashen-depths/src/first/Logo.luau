--!strict
-- The game's logo, built from UI (no image to upload): "ASHEN" in carved gold over "DEPTHS", a thin gold rule
-- with an ember diamond between them, and a soft orange glow behind. Lives in ReplicatedFirst so the loading
-- screen can show it before anything else has arrived.
--   Logo.Build(parent, size?) -> the logo's frame (centered on its Position; size = its width in pixels)
--   Logo.Fade(frame, visible, seconds) -> fades every part of it in or out
--   Logo.Embers(frame) -> sparks drifting up from the logo while it is on screen

local TweenService = game:GetService("TweenService")

local Logo = {}

local TITLE = Font.fromEnum(Enum.Font.Fondamento)
local GOLD_TOP = Color3.fromRGB(255, 226, 150)
local GOLD_MID = Color3.fromRGB(232, 168, 66)
local GOLD_LOW = Color3.fromRGB(150, 74, 24)

local function word(parent: Instance, text: string, y: number, height: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = text
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromScale(0.5, y)
	label.Size = UDim2.fromScale(1, height)
	label.BackgroundTransparency = 1
	label.FontFace = TITLE
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = text
	label.Parent = parent
	local gold = Instance.new("UIGradient")
	gold.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, GOLD_TOP),
		ColorSequenceKeypoint.new(0.55, GOLD_MID),
		ColorSequenceKeypoint.new(1, GOLD_LOW),
	})
	gold.Rotation = 90
	gold.Parent = label
	local edge = Instance.new("UIStroke")
	edge.Color = Color3.fromRGB(40, 16, 6)
	edge.Thickness = 2
	edge.Parent = label
	return label
end

local function rule(parent: Instance, x: number, flip: boolean)
	local line = Instance.new("Frame")
	line.Name = "Rule"
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Position = UDim2.fromScale(x, 0.585)
	line.Size = UDim2.new(0.36, 0, 0, 2)
	line.BackgroundColor3 = GOLD_MID
	line.BorderSizePixel = 0
	line.Parent = parent
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new(if flip then 0 else 1, if flip then 1 else 0)
	fade.Parent = line
end

function Logo.Build(parent: Instance, width: number?): Frame
	local w = width or 520
	local frame = Instance.new("Frame")
	frame.Name = "Logo"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Size = UDim2.fromOffset(w, w * 0.5)
	frame.BackgroundTransparency = 1
	frame.Parent = parent
	-- the glow: a round soft light behind the words
	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromScale(1.3, 1.1)
	glow.BackgroundColor3 = Color3.fromRGB(255, 110, 30)
	glow.BackgroundTransparency = 0
	glow.BorderSizePixel = 0
	glow.ZIndex = 0
	glow.Parent = frame
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(1, 0)
	round.Parent = glow
	local soft = Instance.new("UIGradient")
	soft.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.82),
		NumberSequenceKeypoint.new(0.5, 0.92),
		NumberSequenceKeypoint.new(1, 1),
	})
	soft.Parent = glow

	word(frame, "ASHEN", 0.02, 0.5)
	word(frame, "DEPTHS", 0.64, 0.34)
	rule(frame, 0.27, false)
	rule(frame, 0.73, true)
	local gem = Instance.new("Frame")
	gem.Name = "Gem"
	gem.AnchorPoint = Vector2.new(0.5, 0.5)
	gem.Position = UDim2.fromScale(0.5, 0.585)
	gem.Size = UDim2.fromOffset(w * 0.022, w * 0.022)
	gem.Rotation = 45
	gem.BackgroundColor3 = Color3.fromRGB(255, 140, 50)
	gem.BorderSizePixel = 0
	gem.Parent = frame
	local gemEdge = Instance.new("UIStroke")
	gemEdge.Color = GOLD_TOP
	gemEdge.Thickness = 1.5
	gemEdge.Parent = gem
	-- the glow breathes slowly
	task.spawn(function()
		while glow.Parent do
			local t = os.clock()
			glow.Size = UDim2.fromScale(1.3 + math.sin(t * 1.6) * 0.04, 1.1 + math.sin(t * 1.6) * 0.04)
			task.wait(1 / 30)
		end
	end)
	return frame
end

function Logo.Fade(frame: Frame, visible: boolean, seconds: number)
	local info = TweenInfo.new(seconds)
	for _, d in frame:GetDescendants() do
		if d:IsA("TextLabel") then
			TweenService:Create(d, info, { TextTransparency = if visible then 0 else 1 }):Play()
		elseif d:IsA("UIStroke") then
			TweenService:Create(d, info, { Transparency = if visible then 0 else 1 }):Play()
		elseif d:IsA("Frame") then
			TweenService:Create(d, info, { BackgroundTransparency = if visible then 0 else 1 }):Play()
		end
	end
end

-- Hides it at once (to fade it in afterwards).
function Logo.Hide(frame: Frame)
	for _, d in frame:GetDescendants() do
		if d:IsA("TextLabel") then
			d.TextTransparency = 1
		elseif d:IsA("UIStroke") then
			d.Transparency = 1
		elseif d:IsA("Frame") then
			d.BackgroundTransparency = 1
		end
	end
end

-- Little embers rising past the logo, until it is destroyed.
function Logo.Embers(frame: Frame)
	task.spawn(function()
		while frame.Parent do
			local spark = Instance.new("Frame")
			local size = math.random(3, 6)
			spark.AnchorPoint = Vector2.new(0.5, 0.5)
			spark.Size = UDim2.fromOffset(size, size)
			spark.Position = UDim2.fromScale(0.1 + math.random() * 0.8, 1.1)
			spark.BackgroundColor3 = if math.random() < 0.5 then Color3.fromRGB(255, 170, 70) else Color3.fromRGB(255, 110, 40)
			spark.BackgroundTransparency = 0.1
			spark.BorderSizePixel = 0
			spark.Parent = frame
			local round = Instance.new("UICorner")
			round.CornerRadius = UDim.new(1, 0)
			round.Parent = spark
			local rise = math.random(25, 45) / 10
			TweenService:Create(spark, TweenInfo.new(rise, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
				Position = spark.Position + UDim2.fromScale((math.random() - 0.5) * 0.3, -1.3),
				BackgroundTransparency = 1,
			}):Play()
			task.delay(rise, function()
				spark:Destroy()
			end)
			task.wait(0.12)
		end
	end)
end

return Logo

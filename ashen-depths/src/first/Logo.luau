--!strict
-- The game's logo: the Emberwell title art (fire rising from the well, crossed swords, the chains; made in
-- ashen-depths/tools/logo), with embers drifting up past it. Lives in ReplicatedFirst so the loading screen can
-- show it before anything else has arrived.
--   Logo.Build(parent, width?) -> the logo (centered on its Position; width in pixels)
--   Logo.Fade(logo, visible, seconds) / Logo.Hide(logo) -> fade it in or out / hide it at once
--   Logo.Embers(logo) -> sparks drifting up past the logo while it is on screen

local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")

local Logo = {}

local IMAGE = "rbxassetid://133223945778413"
local ASPECT = 1024 / 551 -- the image's width over its height

function Logo.Build(parent: Instance, width: number?): Frame
	local w = width or 520
	local frame = Instance.new("Frame")
	frame.Name = "Logo"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Size = UDim2.fromOffset(w, w / ASPECT)
	frame.BackgroundTransparency = 1
	frame.Parent = parent
	local art = Instance.new("ImageLabel")
	art.Name = "Art"
	art.Size = UDim2.fromScale(1, 1)
	art.BackgroundTransparency = 1
	art.Image = IMAGE
	art.ScaleType = Enum.ScaleType.Fit
	art.ZIndex = 2
	art.Parent = frame
	task.spawn(function()
		pcall(ContentProvider.PreloadAsync, ContentProvider, { art })
	end)
	return frame
end

function Logo.Fade(frame: Frame, visible: boolean, seconds: number)
	local art = frame:FindFirstChild("Art")
	if art then
		TweenService:Create(art, TweenInfo.new(seconds), { ImageTransparency = if visible then 0 else 1 }):Play()
	end
end

function Logo.Hide(frame: Frame)
	local art = frame:FindFirstChild("Art") :: ImageLabel?
	if art then
		art.ImageTransparency = 1
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
			spark.Position = UDim2.fromScale(0.25 + math.random() * 0.5, 0.8)
			spark.BackgroundColor3 = if math.random() < 0.5 then Color3.fromRGB(255, 170, 70) else Color3.fromRGB(255, 110, 40)
			spark.BackgroundTransparency = 0.1
			spark.BorderSizePixel = 0
			spark.ZIndex = 3
			spark.Parent = frame
			local round = Instance.new("UICorner")
			round.CornerRadius = UDim.new(1, 0)
			round.Parent = spark
			local rise = math.random(25, 45) / 10
			TweenService:Create(spark, TweenInfo.new(rise, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
				Position = spark.Position + UDim2.fromScale((math.random() - 0.5) * 0.4, -1.1),
				BackgroundTransparency = 1,
			}):Play()
			task.delay(rise, function()
				spark:Destroy()
			end)
			task.wait(0.15)
		end
	end)
end

return Logo

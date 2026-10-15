--!strict
-- A boss's entrance scene, when its lair locks: black bars slide in, the camera leaves the player and closes in on
-- the boss, it speaks its lines (typed out at the bottom), and its name comes up big before the fight begins.
-- The player can't move or attack while it plays (attribute "Cutscene" on the player).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Fonts = require(ReplicatedStorage.Shared.Fonts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local BAR_HEIGHT = 0.13 -- of the screen

local BossIntro = {}

local function bar(gui: ScreenGui, top: boolean): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = Color3.new(0, 0, 0)
	f.BorderSizePixel = 0
	f.Size = UDim2.fromScale(1, BAR_HEIGHT)
	f.AnchorPoint = Vector2.new(0, if top then 1 else 0)
	f.Position = UDim2.fromScale(0, if top then 0 else 1)
	f.ZIndex = 10
	f.Parent = gui
	return f
end

local function label(parent: Instance, font: Font, size: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = font
	l.TextSize = size
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.5
	l.TextWrapped = true
	l.ZIndex = 11
	l.Parent = parent
	return l
end

local function play(model: Model, title: string, subtitle: string, lines: { string }, duration: number)
	local player = Players.LocalPlayer
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local bossRoot = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root or not bossRoot then
		return
	end
	local head = model:FindFirstChild("mixamorig:Head", true) :: Bone?

	player:SetAttribute("Cutscene", true)
	local walkSpeed, jumpPower = humanoid.WalkSpeed, humanoid.JumpPower
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0

	-- Everything else on screen (weapon bar, gold, floor name, Roblox's own buttons) steps aside while it plays.
	local hidden: { ScreenGui } = {}
	for _, other in player:WaitForChild("PlayerGui"):GetChildren() do
		if other:IsA("ScreenGui") and other.Enabled then
			other.Enabled = false
			table.insert(hidden, other)
		end
	end
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, false)

	local gui = Instance.new("ScreenGui")
	gui.Name = "BossIntro"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local top = bar(gui, true)
	local bottom = bar(gui, false)
	local slide = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(top, slide, { Position = UDim2.fromScale(0, BAR_HEIGHT) }):Play()
	TweenService:Create(bottom, slide, { Position = UDim2.fromScale(0, 1 - BAR_HEIGHT) }):Play()

	local speaker = label(bottom, Fonts.Title, 22, Color3.fromRGB(230, 180, 110))
	speaker.Size = UDim2.new(0.8, 0, 0, 26)
	speaker.Position = UDim2.new(0.1, 0, 0.08, 0)
	speaker.TextXAlignment = Enum.TextXAlignment.Left
	speaker.Text = title
	speaker.TextTransparency = 1
	local words = label(bottom, Fonts.Body, 20, Color3.fromRGB(235, 228, 215))
	words.Size = UDim2.new(0.8, 0, 0.6, 0)
	words.Position = UDim2.new(0.1, 0, 0.36, 0)
	words.TextXAlignment = Enum.TextXAlignment.Left
	words.TextYAlignment = Enum.TextYAlignment.Top
	words.Text = ""

	-- The camera: first over the player's shoulder toward the boss, then in close on its face.
	local camera = workspace.CurrentCamera
	local before = camera.CameraType
	camera.CameraType = Enum.CameraType.Scriptable
	local function face(): Vector3
		return if head then head.TransformedWorldCFrame.Position else bossRoot.Position + Vector3.new(0, 4, 0)
	end
	local toBoss = (bossRoot.Position - root.Position) * Vector3.new(1, 0, 1)
	toBoss = if toBoss.Magnitude > 0.1 then toBoss.Unit else root.CFrame.LookVector
	local shoulder = root.Position - toBoss * 9 + Vector3.new(0, 5, 0) + toBoss:Cross(Vector3.yAxis) * 3
	camera.CFrame = CFrame.lookAt(shoulder, face())
	TweenService:Create(camera, TweenInfo.new(duration * 0.3, Enum.EasingStyle.Sine), {
		CFrame = CFrame.lookAt(shoulder + toBoss * 6, face()),
	}):Play()
	task.delay(duration * 0.3, function()
		if not gui.Parent then
			return
		end
		local look = bossRoot.CFrame.LookVector
		local side = look:Cross(Vector3.yAxis)
		local near = face() + look * 10 + side * 3 - Vector3.new(0, 1.5, 0)
		camera.CFrame = CFrame.lookAt(near + look * 3, face())
		TweenService:Create(camera, TweenInfo.new(duration * 0.5, Enum.EasingStyle.Sine), {
			CFrame = CFrame.lookAt(near - side * 1.5, face()),
		}):Play()
	end)

	-- Its words, typed out one line after another.
	task.spawn(function()
		task.wait(0.8)
		TweenService:Create(speaker, TweenInfo.new(0.4), { TextTransparency = 0 }):Play()
		local perLine = (duration * 0.72) / math.max(#lines, 1)
		for _, line in lines do
			if not gui.Parent then
				return
			end
			local started = os.clock()
			for i = 1, #line do
				words.Text = line:sub(1, i)
				task.wait(0.028)
			end
			task.wait(math.max(perLine - (os.clock() - started), 0.6))
		end
	end)

	-- Its name, big, just before the fight.
	task.delay(duration - 2.6, function()
		if not gui.Parent then
			return
		end
		local name = label(gui, Fonts.Title, 64, Color3.fromRGB(240, 210, 160))
		name.AnchorPoint = Vector2.new(0.5, 0.5)
		name.Size = UDim2.new(0.9, 0, 0, 72)
		name.Position = UDim2.fromScale(0.5, 0.42)
		name.Text = title
		name.TextTransparency = 1
		name.TextStrokeTransparency = 1
		local sub = label(gui, Fonts.Title, 26, Color3.fromRGB(200, 170, 130))
		sub.AnchorPoint = Vector2.new(0.5, 0.5)
		sub.Size = UDim2.new(0.9, 0, 0, 32)
		sub.Position = UDim2.fromScale(0.5, 0.52)
		sub.Text = subtitle
		sub.TextTransparency = 1
		sub.TextStrokeTransparency = 1
		local show = TweenInfo.new(0.5)
		TweenService:Create(name, show, { TextTransparency = 0, TextStrokeTransparency = 0.3 }):Play()
		TweenService:Create(sub, show, { TextTransparency = 0, TextStrokeTransparency = 0.5 }):Play()
		task.wait(1.8)
		TweenService:Create(name, show, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		TweenService:Create(sub, show, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)

	task.wait(duration)
	TweenService:Create(top, slide, { Position = UDim2.fromScale(0, 0) }):Play()
	TweenService:Create(bottom, slide, { Position = UDim2.fromScale(0, 1) }):Play()
	words.Text = ""
	speaker.Text = ""
	camera.CameraType = if before == Enum.CameraType.Scriptable then Enum.CameraType.Custom else before
	humanoid.WalkSpeed = walkSpeed
	humanoid.JumpPower = jumpPower
	player:SetAttribute("Cutscene", nil)
	for _, other in hidden do
		other.Enabled = true
	end
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, true)
	task.wait(0.7)
	gui:Destroy()
end

function BossIntro.Start()
	Remotes.Event("BossIntro").OnClientEvent:Connect(function(model: Model, title: string, subtitle: string, lines: { string }, duration: number)
		if typeof(model) == "Instance" and model:IsA("Model") then
			task.spawn(play, model, title, subtitle, lines, duration)
		end
	end)
end

return BossIntro

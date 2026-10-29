--!strict
-- A new adventurer's first look at Emberhold: the screen fades in on the town from above, the camera sweeps
-- down to the Great Well and over to the Guild Hall while title cards tell where they are, then hands over
-- to Aldric (IntroService on the server). A Skip button goes straight to Aldric. Afterwards, the objective: a line at the top of the screen and a
-- pillar of light over the Well and a trail of glowing arrows on the ground leading to it, until they get there.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Fonts = require(ReplicatedStorage.Shared.Fonts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Intro = {}

local GOLD = Color3.fromRGB(240, 190, 90)
local TEXT = Color3.fromRGB(230, 220, 205)
local GUIDE_ARROW = "rbxassetid://111233344208279" -- tools/logo/guide_chevron.png

local function card(parent: Instance): (TextLabel, TextLabel)
	local title = Instance.new("TextLabel")
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.fromScale(0.5, 0.12)
	title.Size = UDim2.new(0.8, 0, 0, 64)
	title.BackgroundTransparency = 1
	title.FontFace = Fonts.Title
	title.TextScaled = true
	title.TextColor3 = GOLD
	title.TextStrokeTransparency = 0.5
	title.TextTransparency = 1
	title.TextStrokeTransparency = 1
	title.Parent = parent
	local sub = Instance.new("TextLabel")
	sub.AnchorPoint = Vector2.new(0.5, 0)
	sub.Position = UDim2.fromScale(0.5, 0.12)
	sub.Size = UDim2.new(0.8, 0, 0, 30)
	sub.Position = UDim2.new(0.5, 0, 0.12, 70)
	sub.BackgroundTransparency = 1
	sub.FontFace = Fonts.Body
	sub.TextScaled = true
	sub.TextColor3 = TEXT
	sub.TextTransparency = 1
	sub.TextStrokeTransparency = 1
	sub.Parent = parent
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 24
	limit.Parent = sub
	return title, sub
end

local function show(label: TextLabel, text: string, visible: boolean)
	if visible then
		label.Text = text
	end
	TweenService:Create(label, TweenInfo.new(0.8), { TextTransparency = if visible then 0 else 1, TextStrokeTransparency = if visible then 0.5 else 1 }):Play()
end

function Intro.Start()
	local player = Players.LocalPlayer

	Remotes.Event("IntroStart").OnClientEvent:Connect(function()
		local gui = Instance.new("ScreenGui")
		gui.Name = "Intro"
		gui.IgnoreGuiInset = true
		gui.DisplayOrder = 50
		gui.ResetOnSpawn = false
		gui.Parent = player:WaitForChild("PlayerGui")
		local black = Instance.new("Frame")
		black.Size = UDim2.fromScale(1, 1)
		black.BackgroundColor3 = Color3.new(0, 0, 0)
		black.BorderSizePixel = 0
		black.Parent = gui
		local title, sub = card(gui)

		-- everything else on screen steps aside
		local hidden = {}
		for _, other in player.PlayerGui:GetChildren() do
			if other:IsA("ScreenGui") and other ~= gui and other.Enabled then
				other.Enabled = false
				table.insert(hidden, other)
			end
		end
		local coreWasOn = {}
		for _, kind in Enum.CoreGuiType:GetEnumItems() do
			if kind ~= Enum.CoreGuiType.All then
				local ok, on = pcall(function()
					return StarterGui:GetCoreGuiEnabled(kind)
				end)
				coreWasOn[kind] = ok and on
			end
		end
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
		end)
		local character = player.Character or player.CharacterAdded:Wait()
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0

		local camera = workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Scriptable
		local well = Vector3.new(0, 4, 0)
		local town = workspace:FindFirstChild("Town")
		local aldric = town and town:FindFirstChild("Aldric", true)
		local guild = if aldric and aldric:IsA("Model") then aldric:GetPivot().Position + Vector3.new(0, 4, 0) else Vector3.new(-45, 6, -64)

		local flying: Tween? = nil
		local function fly(from: CFrame, to: CFrame, seconds: number)
			camera.CFrame = from
			local t = TweenService:Create(camera, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { CFrame = to })
			flying = t
			t:Play()
			t.Completed:Wait()
		end

		-- back to the player, Aldric takes over (at the end of the fly-over, or when it's skipped)
		local finished = false
		local skip: TextButton
		local function finish()
			if finished then
				return
			end
			finished = true
			skip:Destroy()
			-- (hidden outright: a skipped fly-over may still have a title card on its way in)
			title.Visible = false
			sub.Visible = false
			TweenService:Create(black, TweenInfo.new(0.6), { BackgroundTransparency = 0 }):Play()
			task.wait(0.7)
			for _, other in hidden do
				other.Enabled = true
			end
			for kind, on in coreWasOn do
				pcall(function()
					StarterGui:SetCoreGuiEnabled(kind, on)
				end)
			end
			humanoid.WalkSpeed = 16
			humanoid.JumpPower = 50
			camera.CameraType = Enum.CameraType.Custom
			Remotes.Event("IntroReady"):FireServer()
			task.wait(0.4)
			TweenService:Create(black, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
			task.delay(1, function()
				gui:Destroy()
			end)
		end

		skip = Instance.new("TextButton")
		skip.Name = "Skip"
		skip.AnchorPoint = Vector2.new(1, 1)
		skip.Position = UDim2.new(1, -24, 1, -24)
		skip.Size = UDim2.fromOffset(120, 44)
		skip.BackgroundColor3 = Color3.fromRGB(30, 22, 16)
		skip.BackgroundTransparency = 0.2
		skip.FontFace = Fonts.Body
		skip.TextSize = 20
		skip.TextColor3 = TEXT
		skip.Text = "Skip"
		skip.ZIndex = 5
		skip.Parent = gui
		local skipCorner = Instance.new("UICorner")
		skipCorner.CornerRadius = UDim.new(0, 8)
		skipCorner.Parent = skip
		local skipStroke = Instance.new("UIStroke")
		skipStroke.Color = GOLD
		skipStroke.Thickness = 1.5
		skipStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		skipStroke.Parent = skip

		local flight = task.spawn(function()
			-- 1: the town from above, the screen fading in
			camera.CFrame = CFrame.lookAt(Vector3.new(160, 120, 220), well)
			task.wait(0.5)
			TweenService:Create(black, TweenInfo.new(2), { BackgroundTransparency = 1 }):Play()
			show(title, "Emberhold", true)
			task.delay(0.6, function()
				show(sub, "The last town above the ash", true)
			end)
			fly(CFrame.lookAt(Vector3.new(160, 120, 220), well), CFrame.lookAt(Vector3.new(60, 60, 110), well), 6)
			show(title, "", false)
			show(sub, "", false)
			-- 2: down to the Great Well
			task.delay(0.8, function()
				show(title, "The Great Well", true)
				show(sub, "Below it, the Depths. The dead still guard their king.", true)
			end)
			fly(CFrame.lookAt(Vector3.new(60, 60, 110), well), CFrame.lookAt(Vector3.new(14, 12, 26), well), 5)
			task.wait(1)
			show(title, "", false)
			show(sub, "", false)
			-- 3: across to the Guild Hall, where Aldric waits
			task.delay(0.6, function()
				show(title, "The Adventurers' Guild", true)
				show(sub, "Every adventurer starts here.", true)
			end)
			fly(CFrame.lookAt(Vector3.new(14, 12, 26), well), CFrame.lookAt(guild + Vector3.new(10, 6, 26), guild), 4)
			task.wait(1)
			finish()
		end)

		skip.Activated:Connect(function()
			if finished then
				return
			end
			task.cancel(flight)
			if flying then
				flying:Cancel()
			end
			finish()
		end)
	end)

	-- the objective: a line at the top and a pillar of light at the place, until the player reaches it
	Remotes.Event("Objective").OnClientEvent:Connect(function(text: any, where: any)
		if type(text) ~= "string" or typeof(where) ~= "Vector3" then
			return
		end
		local gui = Instance.new("ScreenGui")
		gui.Name = "Objective"
		gui.ResetOnSpawn = false
		gui.Parent = player:WaitForChild("PlayerGui")
		local line = Instance.new("TextLabel")
		line.AnchorPoint = Vector2.new(0.5, 0)
		line.Position = UDim2.new(0.5, 0, 0, 12)
		line.Size = UDim2.fromOffset(420, 40)
		line.BackgroundColor3 = Color3.fromRGB(20, 16, 16)
		line.BackgroundTransparency = 0.2
		line.FontFace = Fonts.Title
		line.TextSize = 22
		line.TextColor3 = GOLD
		line.Text = "◆  " .. text
		line.Parent = gui
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 8)
		c.Parent = line
		local beam = Instance.new("Part")
		beam.Name = "ObjectiveBeam"
		beam.Anchored = true
		beam.CanCollide = false
		beam.CanQuery = false
		beam.Shape = Enum.PartType.Cylinder
		beam.Size = Vector3.new(200, 5, 5)
		beam.CFrame = CFrame.new(where + Vector3.new(0, 100, 0)) * CFrame.Angles(0, 0, math.rad(90))
		beam.Color = Color3.fromRGB(255, 190, 90)
		beam.Material = Enum.Material.Neon
		beam.Transparency = 0.7
		beam.CastShadow = false
		beam.Parent = workspace
		local pulse = TweenService:Create(beam, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.88 })
		pulse:Play()
		-- a trail of glowing arrows on the ground from the player's feet to the place, moving toward it
		local goal = Instance.new("Attachment")
		goal.Name = "ObjectiveGoal"
		goal.CFrame = CFrame.Angles(0, 0, math.rad(90)) -- (the beam lies in the plane its attachments' Axis is normal to)
		goal.Parent = beam
		goal.WorldPosition = Vector3.new(where.X, where.Y - 1.5, where.Z)
		local trail = Instance.new("Beam")
		trail.Name = "ObjectiveTrail"
		trail.Texture = GUIDE_ARROW
		trail.TextureMode = Enum.TextureMode.Static
		trail.TextureLength = 3
		trail.TextureSpeed = 1.2
		trail.Width0, trail.Width1 = 2.6, 2.6
		trail.FaceCamera = false
		trail.LightEmission = 1
		trail.LightInfluence = 0
		trail.Color = ColorSequence.new(Color3.fromRGB(255, 200, 110))
		trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.08, 0.15), NumberSequenceKeypoint.new(1, 0.15) })
		trail.Attachment1 = goal
		trail.Parent = beam
		local function follow(character: Model)
			local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not root or not trail.Parent then
				return
			end
			local feet = Instance.new("Attachment")
			feet.Name = "ObjectiveFeet"
			feet.Position = Vector3.new(0, -(root.Size.Y / 2 + (if humanoid then humanoid.HipHeight else 2)) + 0.25, 0)
			feet.Parent = root
			trail.Attachment0 = feet
		end
		if player.Character then
			task.spawn(follow, player.Character)
		end
		local respawn = player.CharacterAdded:Connect(follow)
		local conn: RBXScriptConnection
		conn = RunService.Heartbeat:Connect(function()
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(where.X, 0, where.Z)).Magnitude < 14 then
				conn:Disconnect()
				respawn:Disconnect()
				pulse:Cancel()
				trail:Destroy()
				line.Text = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
					then "◆  Hold the button at the Well to descend"
					else "◆  Hold E at the Well to descend"
				task.delay(8, function()
					gui:Destroy()
					beam:Destroy()
				end)
			end
		end)
	end)
end

return Intro

--!strict
-- The way to go (the "Objective" remote, from IntroService in town and FloorService in the Depths): a line at the
-- top of the screen, a pillar of light over the place and a trail of glowing arrows on the ground leading to it.
-- On arrival the line says what to do there (the server's arrival text, "{hold}" becoming "Hold E" or "Hold the
-- button"), then fades. A new objective replaces the old one, and a new floor clears it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Fonts = require(ReplicatedStorage.Shared.Fonts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local GOLD = Color3.fromRGB(240, 190, 90)
local GUIDE_ARROW = "rbxassetid://80020066849273" -- tools/logo/guide_chevron.png (the arrow points up the picture)
local ARRIVED_RANGE = 14

local Guide = {}

local clearCurrent: (() -> ())? = nil

local function holdText(text: string): string
	local hold = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then "Hold the button" else "Hold E"
	return (string.gsub(text, "{hold}", hold))
end

local function show(text: string, where: Vector3, arrived: string?)
	if clearCurrent then
		clearCurrent()
	end
	local player = Players.LocalPlayer
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
	local fit = Instance.new("UITextSizeConstraint")
	fit.MaxTextSize = 22
	fit.Parent = line
	line.TextScaled = true
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
	goal.Parent = beam
	local goalAt = Vector3.new(where.X, where.Y - 1.5, where.Z)
	goal.WorldPosition = goalAt
	local trail = Instance.new("Beam")
	trail.Name = "ObjectiveTrail"
	trail.Texture = GUIDE_ARROW
	trail.TextureMode = Enum.TextureMode.Static
	trail.TextureLength = 4
	trail.TextureSpeed = 1.2
	trail.Width0, trail.Width1 = 3.4, 3.4
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
	local function clear()
		conn:Disconnect()
		respawn:Disconnect()
		pulse:Cancel()
		gui:Destroy()
		beam:Destroy()
		if clearCurrent == clear then
			clearCurrent = nil
		end
	end
	clearCurrent = clear
	conn = RunService.Heartbeat:Connect(function()
		-- the beam is as wide as its attachments' secondary (Y) axis: keep both ends' Y level and across the
		-- path, so it lies flat on the ground
		local feet = trail.Attachment0
		if feet then
			local from = feet.WorldPosition
			local flat = Vector3.new(goalAt.X, from.Y, goalAt.Z)
			if (flat - from).Magnitude > 0.1 then
				local across = CFrame.Angles(0, 0, math.rad(90))
				feet.WorldCFrame = CFrame.lookAt(from, flat) * across
				goal.WorldCFrame = CFrame.lookAt(flat, flat + (flat - from)) * across -- (at the player's ground height)
			end
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(where.X, 0, where.Z)).Magnitude < ARRIVED_RANGE then
			conn:Disconnect()
			respawn:Disconnect()
			pulse:Cancel()
			trail:Destroy()
			if arrived then
				line.Text = "◆  " .. holdText(arrived)
			end
			task.delay(if arrived then 8 else 2, function()
				if clearCurrent == clear then
					clear()
				end
			end)
		end
	end)
end

function Guide.Start()
	Remotes.Event("Objective").OnClientEvent:Connect(function(text: any, where: any, arrived: any)
		if type(text) ~= "string" or typeof(where) ~= "Vector3" then
			return
		end
		show(text, where, if type(arrived) == "string" then arrived else nil)
	end)
	-- a new floor: whatever was pointed at is behind
	Remotes.Event("FloorStarted").OnClientEvent:Connect(function()
		if clearCurrent then
			clearCurrent()
		end
	end)
end

return Guide

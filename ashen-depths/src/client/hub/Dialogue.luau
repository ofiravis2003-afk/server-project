--!strict
-- Talking to a townsperson: the camera turns to their face, a panel at the bottom shows their name and title
-- and types out what they say a page at a time. Buttons: Next (more of the same), Tell me more, the
-- townsperson's own action (Brakka's Trade), and Goodbye. Walking away ends it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Dialogues = require(ReplicatedStorage.Shared.Dialogues)
local Fonts = require(ReplicatedStorage.Shared.Fonts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local PANEL = Color3.fromRGB(18, 14, 16)
local EDGE = Color3.fromRGB(120, 90, 50)
local TEXT = Color3.fromRGB(235, 228, 215)
local GOLD = Color3.fromRGB(240, 190, 90)
local TALK_RANGE = 16

local Dialogue = {}

local function label(parent: Instance, font: Font, size: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = font
	l.TextSize = size
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.6
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.TextWrapped = true
	l.Parent = parent
	return l
end

function Dialogue.Start()
	local player = Players.LocalPlayer
	local actionRemote = Remotes.Event("DialogueAction")

	local gui = Instance.new("ScreenGui")
	gui.Name = "Dialogue"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -24)
	panel.Size = UDim2.new(0.7, 0, 0, 190)
	panel.BackgroundColor3 = PANEL
	panel.BackgroundTransparency = 0.08
	panel.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(820, 190)
	limit.MinSize = Vector2.new(340, 190)
	limit.Parent = panel
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = EDGE
	stroke.Thickness = 2
	stroke.Parent = panel

	local name = label(panel, Fonts.Title, 26, GOLD)
	name.Position = UDim2.fromOffset(18, 10)
	name.Size = UDim2.new(1, -36, 0, 28)
	local title = label(panel, Fonts.Body, 14, Color3.fromRGB(180, 165, 140))
	title.Position = UDim2.fromOffset(18, 38)
	title.Size = UDim2.new(1, -36, 0, 18)
	local words = label(panel, Fonts.Body, 19, TEXT)
	words.Position = UDim2.fromOffset(18, 64)
	words.Size = UDim2.new(1, -36, 0, 70)

	local buttons = Instance.new("Frame")
	buttons.AnchorPoint = Vector2.new(1, 1)
	buttons.Position = UDim2.new(1, -14, 1, -12)
	buttons.Size = UDim2.new(1, -28, 0, 36)
	buttons.BackgroundTransparency = 1
	buttons.Parent = panel
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.HorizontalAlignment = Enum.HorizontalAlignment.Right
	row.Padding = UDim.new(0, 8)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = buttons

	local talking: Model? = nil
	local talkingKey: string? = nil
	local pages: { string } = {}
	local page = 0
	local askedMore = false
	local typing = 0
	local cameraBefore: Enum.CameraType? = nil
	local walkSpeed, jumpPower = 16, 50

	local close: () -> ()
	local showPage: () -> ()

	local function button(text: string, order: number, color: Color3, onClick: () -> ())
		local b = Instance.new("TextButton")
		b.Name = text:gsub(" ", "")
		b.LayoutOrder = order
		b.AutomaticSize = Enum.AutomaticSize.X
		b.Size = UDim2.fromOffset(0, 36)
		b.BackgroundColor3 = color
		b.FontFace = Fonts.Title
		b.TextSize = 17
		b.TextColor3 = TEXT
		b.Text = text
		b.Parent = buttons
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 16)
		pad.PaddingRight = UDim.new(0, 16)
		pad.Parent = b
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 6)
		c.Parent = b
		local s = Instance.new("UIStroke")
		s.Color = EDGE
		s.Thickness = 1.5
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = b
		b.Activated:Connect(onClick)
	end

	showPage = function()
		local key = talking and (talkingKey or talking.Name)
		local d = key and Dialogues[key]
		if not d then
			return
		end
		for _, child in buttons:GetChildren() do
			if child:IsA("GuiButton") then
				child:Destroy()
			end
		end
		local text = pages[page] or ""
		typing += 1
		local mine = typing
		task.spawn(function()
			for i = 1, #text do
				if typing ~= mine then
					return
				end
				words.Text = text:sub(1, i)
				task.wait(0.018)
			end
		end)
		local last = page >= #pages
		if not last then
			button("Next", 1, Color3.fromRGB(50, 44, 40), function()
				page += 1
				showPage()
			end)
		else
			if d.More and not askedMore then
				button("Tell me more", 1, Color3.fromRGB(50, 44, 40), function()
					askedMore = true
					pages = d.More :: { string }
					page = 1
					showPage()
				end)
			end
		end
		-- their own button (Trade, Quests) is there from the first page
		-- (a Required talk shows its button only on the last page, and can't be left)
		for i, action in if d.Required and not last then {} else d.Actions or { d.Action } do
			button(action, 1 + i, Color3.fromRGB(120, 70, 25), function()
				actionRemote:FireServer(key, action)
				close()
			end)
		end
		if not d.Required then
			button("Goodbye", 9, Color3.fromRGB(60, 30, 30), function()
				close()
			end)
		end
	end

	close = function()
		if not talking then
			return
		end
		talking = nil
		typing += 1
		gui.Enabled = false
		local camera = workspace.CurrentCamera
		camera.CameraType = if cameraBefore and cameraBefore ~= Enum.CameraType.Scriptable then cameraBefore else Enum.CameraType.Custom
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = walkSpeed
			humanoid.JumpPower = jumpPower
		end
	end

	local function open(model: Model, key: string?)
		local d = Dialogues[key or model.Name]
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not d or not humanoid or talking then
			return
		end
		talking = model
		talkingKey = key
		pages = d.Lines
		page = 1
		askedMore = false
		name.Text = d.Name
		title.Text = d.Title
		walkSpeed, jumpPower = humanoid.WalkSpeed, humanoid.JumpPower
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		-- the camera turns to their face, a little to the side
		local head = model:FindFirstChild("mixamorig:Head", true) :: Bone?
		local face = if head then head.TransformedWorldCFrame.Position else model:GetPivot().Position + Vector3.new(0, 4, 0)
		local look = model:GetPivot().LookVector
		local camera = workspace.CurrentCamera
		cameraBefore = camera.CameraType
		camera.CameraType = Enum.CameraType.Scriptable
		local goal = CFrame.lookAt(face + look * 6.5 + look:Cross(Vector3.yAxis) * 2.2 + Vector3.new(0, 0.3, 0), face - Vector3.new(0, 0.6, 0))
		TweenService:Create(camera, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = goal }):Play()
		gui.Enabled = true
		showPage()
	end

	Remotes.Event("DialogueOpen").OnClientEvent:Connect(function(model: Instance, key: any)
		if typeof(model) == "Instance" and model:IsA("Model") then
			open(model, if type(key) == "string" then key else nil)
		end
	end)
	-- the player steps out of the shot while talking (their own screen only)
	local function hideSelf(hidden: boolean)
		local character = player.Character
		if character then
			for _, part in character:GetDescendants() do
				if part:IsA("BasePart") or part:IsA("Decal") then
					part.LocalTransparencyModifier = if hidden then 1 else 0
				end
			end
		end
	end
	RunService.RenderStepped:Connect(function()
		if talking then
			hideSelf(true)
		end
	end)
	local closeBefore = close
	close = function()
		local was = talking
		closeBefore()
		if was then
			hideSelf(false)
		end
	end

	RunService.Heartbeat:Connect(function()
		local model = talking
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if model and (not root or (root.Position - model:GetPivot().Position).Magnitude > TALK_RANGE) then
			close()
		end
	end)
end

return Dialogue

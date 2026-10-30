--!strict
-- A page of Ilvane's journal, read on screen: an old sheet of parchment in the middle with its title and
-- text, the world blurred behind it. The server sends LoreShow with the page id (when a lectern is read in
-- the Depths, or a page is reread in Emberhold). Close, or walk away, to put it down.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Fonts = require(ReplicatedStorage.Shared.Fonts)
local Lore = require(ReplicatedStorage.Shared.Lore)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local PARCHMENT = Color3.fromRGB(222, 202, 160)
local INK = Color3.fromRGB(58, 38, 24)
local FADED = Color3.fromRGB(120, 92, 60)
local EDGE = Color3.fromRGB(120, 86, 48)

local LorePage = {}

local function label(parent: Instance, font: Font, size: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = font
	l.TextSize = size
	l.TextColor3 = color
	l.TextWrapped = true
	l.Parent = parent
	return l
end

function LorePage.Start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "LorePage"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 7
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local sheet = Instance.new("Frame")
	sheet.AnchorPoint = Vector2.new(0.5, 0.5)
	sheet.Position = UDim2.fromScale(0.5, 0.5)
	sheet.Size = UDim2.fromOffset(460, 520)
	sheet.BackgroundColor3 = PARCHMENT
	sheet.Rotation = -1
	sheet.Parent = gui
	local fit = Instance.new("UIScale")
	fit.Parent = sheet
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = sheet
	local stroke = Instance.new("UIStroke")
	stroke.Color = EDGE
	stroke.Thickness = 3
	stroke.Parent = sheet
	-- age: darker toward the edges
	local age = Instance.new("UIGradient")
	age.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(190, 160, 110)),
		ColorSequenceKeypoint.new(0.2, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.8, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 150, 100)),
	})
	age.Rotation = 90
	age.Parent = sheet

	local from = label(sheet, Fonts.Body, 14, FADED)
	from.Position = UDim2.fromOffset(30, 22)
	from.Size = UDim2.new(1, -60, 0, 18)
	local title = label(sheet, Fonts.Title, 30, INK)
	title.Position = UDim2.fromOffset(30, 44)
	title.Size = UDim2.new(1, -60, 0, 70)
	local rule = Instance.new("Frame")
	rule.Position = UDim2.fromOffset(60, 118)
	rule.Size = UDim2.new(1, -120, 0, 2)
	rule.BackgroundColor3 = FADED
	rule.BorderSizePixel = 0
	rule.Parent = sheet
	local body = label(sheet, Fonts.Title, 20, INK) -- an old hand
	body.Position = UDim2.fromOffset(34, 134)
	body.Size = UDim2.new(1, -68, 1, -210)
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.LineHeight = 1.15
	local count = label(sheet, Fonts.Body, 14, FADED)
	count.AnchorPoint = Vector2.new(0, 1)
	count.Position = UDim2.new(0, 30, 1, -24)
	count.Size = UDim2.fromOffset(200, 18)
	count.TextXAlignment = Enum.TextXAlignment.Left

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 1)
	close.Position = UDim2.new(1, -24, 1, -18)
	close.Size = UDim2.fromOffset(110, 34)
	close.BackgroundColor3 = Color3.fromRGB(90, 60, 36)
	close.FontFace = Fonts.Title
	close.TextSize = 17
	close.TextColor3 = PARCHMENT
	close.Text = "Close"
	close.Parent = sheet
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0, 6)
	cc.Parent = close

	local blur = Instance.new("BlurEffect")
	blur.Name = "LoreBlur"
	blur.Size = 0
	blur.Enabled = false
	blur.Parent = Lighting

	local openedAt: Vector3? = nil
	local function hide()
		gui.Enabled = false
		openedAt = nil
		blur.Enabled = false
		blur.Size = 0
	end
	close.Activated:Connect(hide)

	Remotes.Event("LoreShow").OnClientEvent:Connect(function(id: any, found: any)
		local page = type(id) == "string" and Lore.ById[id]
		if not page then
			return
		end
		from.Text = Lore.From(page)
		title.Text = page.Title
		body.Text = page.Text
		count.Text = if type(found) == "number" then `Pages found: {found} of {Lore.SetSize(page.Set)}` else ""
		local screen = workspace.CurrentCamera.ViewportSize
		fit.Scale = math.min(1, (screen.Y - 60) / sheet.Size.Y.Offset, (screen.X - 24) / sheet.Size.X.Offset)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		openedAt = root and root.Position
		gui.Enabled = true
		blur.Enabled = true
		TweenService:Create(blur, TweenInfo.new(0.4), { Size = 14 }):Play()
		sheet.Position = UDim2.new(0.5, 0, 0.5, 24)
		TweenService:Create(sheet, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
	end)

	-- walking away puts it down
	task.spawn(function()
		while true do
			task.wait(0.3)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if gui.Enabled and openedAt and (not root or (root.Position - openedAt).Magnitude > 14) then
				hide()
			end
		end
	end)
end

return LorePage

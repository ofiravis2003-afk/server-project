--!strict
-- Once, when an adventurer comes back to town having reached floor 3 (ShopService fires "AskLike"): a small card
-- thanking them and asking for a like and a favourite on the game page, with a button to invite friends.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")

local Fonts = require(ReplicatedStorage.Shared.Fonts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local GOLD = Color3.fromRGB(240, 190, 90)
local TEXT = Color3.fromRGB(230, 220, 205)
local DARK = Color3.fromRGB(20, 16, 16)

local LikeAsk = {}

local function button(parent: Instance, text: string, x: number, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(0.5, 1)
	b.Position = UDim2.new(x, 0, 1, -14)
	b.Size = UDim2.fromOffset(150, 38)
	b.BackgroundColor3 = color
	b.FontFace = Fonts.Title
	b.TextSize = 18
	b.TextColor3 = DARK
	b.Text = text
	b.AutoButtonColor = true
	b.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = b
	return b
end

local function show()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "LikeAsk"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 8
	gui.Parent = player:WaitForChild("PlayerGui")
	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 1.4)
	card.Size = UDim2.fromOffset(400, 190)
	card.BackgroundColor3 = DARK
	card.BackgroundTransparency = 0.08
	card.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Color = GOLD
	stroke.Thickness = 1.5
	stroke.Transparency = 0.3
	stroke.Parent = card
	local scale = Instance.new("UIScale")
	scale.Scale = math.min(1, (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.X or 800) / 460)
	scale.Parent = card

	local title = Instance.new("TextLabel")
	title.Position = UDim2.fromOffset(16, 12)
	title.Size = UDim2.new(1, -32, 0, 32)
	title.BackgroundTransparency = 1
	title.FontFace = Fonts.Title
	title.TextSize = 24
	title.TextColor3 = GOLD
	title.Text = "Enjoying Emberwell?"
	title.Parent = card
	local body = Instance.new("TextLabel")
	body.Position = UDim2.fromOffset(20, 48)
	body.Size = UDim2.new(1, -40, 0, 70)
	body.BackgroundTransparency = 1
	body.FontFace = Fonts.Body
	body.TextSize = 17
	body.TextWrapped = true
	body.TextColor3 = TEXT
	body.Text = "We're a small team. A 👍 and a ⭐ on the game page help other adventurers find the Well. And the Depths are better with friends!"
	body.Parent = card

	local invite = button(card, "Invite friends", 0.3, GOLD)
	local close = button(card, "Maybe later", 0.7, Color3.fromRGB(150, 140, 130))
	local function dismiss()
		local out = TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromScale(0.5, 1.4) })
		out:Play()
		out.Completed:Wait()
		gui:Destroy()
	end
	invite.Activated:Connect(function()
		pcall(SocialService.PromptGameInvite, SocialService, player)
		dismiss()
	end)
	close.Activated:Connect(dismiss)
	TweenService:Create(card, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.72) }):Play()
end

function LikeAsk.Start()
	Remotes.Event("AskLike").OnClientEvent:Connect(show)
end

return LikeAsk

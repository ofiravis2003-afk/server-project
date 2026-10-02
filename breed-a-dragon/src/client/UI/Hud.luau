--!strict
-- The always-on-screen HUD: the Embers counter, "+N" popups and short messages.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)

local ORANGE = Color3.fromRGB(255, 140, 50)
local DARK = Color3.fromRGB(25, 20, 30)

local Hud = {}

local screenGui: ScreenGui
local counterFrame: Frame
local counterLabel: TextLabel
local messageLabel: TextLabel
local messageToken = 0

local function addCorner(parent: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function build()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "Hud"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	counterFrame = Instance.new("Frame")
	counterFrame.Name = "EmbersCounter"
	counterFrame.AnchorPoint = Vector2.new(0.5, 0)
	counterFrame.Position = UDim2.new(0.5, 0, 0, 12)
	counterFrame.Size = UDim2.fromOffset(200, 48)
	counterFrame.BackgroundColor3 = DARK
	counterFrame.BackgroundTransparency = 0.15
	counterFrame.Parent = screenGui
	addCorner(counterFrame, 14)

	local stroke = Instance.new("UIStroke")
	stroke.Color = ORANGE
	stroke.Thickness = 2
	stroke.Parent = counterFrame

	counterLabel = Instance.new("TextLabel")
	counterLabel.BackgroundTransparency = 1
	counterLabel.Size = UDim2.fromScale(1, 1)
	counterLabel.Font = Enum.Font.FredokaOne
	counterLabel.TextScaled = true
	counterLabel.TextColor3 = Color3.new(1, 1, 1)
	counterLabel.Text = `{Config.Currency.Icon} 0`
	counterLabel.Parent = counterFrame

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = counterLabel

	messageLabel = Instance.new("TextLabel")
	messageLabel.Name = "Message"
	messageLabel.AnchorPoint = Vector2.new(0.5, 0)
	messageLabel.Position = UDim2.new(0.5, 0, 0, 70)
	messageLabel.Size = UDim2.new(0.9, 0, 0, 36)
	messageLabel.BackgroundColor3 = DARK
	messageLabel.BackgroundTransparency = 0.2
	messageLabel.Font = Enum.Font.GothamBold
	messageLabel.TextScaled = true
	messageLabel.TextColor3 = Color3.new(1, 1, 1)
	messageLabel.Visible = false
	messageLabel.Parent = screenGui
	addCorner(messageLabel, 10)

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(600, 36)
	sizeLimit.Parent = messageLabel

	screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function showGain(amount: number)
	local popup = Instance.new("TextLabel")
	popup.BackgroundTransparency = 1
	popup.AnchorPoint = Vector2.new(0.5, 0)
	popup.Position = UDim2.new(0.5, math.random(-40, 40), 1, 4)
	popup.Size = UDim2.fromOffset(120, 28)
	popup.Font = Enum.Font.FredokaOne
	popup.TextScaled = true
	popup.TextColor3 = ORANGE
	popup.TextStrokeTransparency = 0.4
	popup.Text = "+" .. NumberFormat.Abbreviate(amount)
	popup.Parent = counterFrame

	local tween = TweenService:Create(popup, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = popup.Position + UDim2.fromOffset(0, 40),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	tween.Completed:Once(function()
		popup:Destroy()
	end)
	tween:Play()
end

-- Shows a short message under the counter for `duration` seconds.
function Hud.ShowMessage(text: string, duration: number?)
	messageToken += 1
	local token = messageToken
	messageLabel.Text = text
	messageLabel.Visible = true
	task.delay(duration or 5, function()
		if messageToken == token then
			messageLabel.Visible = false
		end
	end)
end

function Hud.Start()
	build()

	task.spawn(function()
		local leaderstats = Players.LocalPlayer:WaitForChild("leaderstats")
		local embers = leaderstats:WaitForChild(Config.Currency.Name) :: NumberValue

		local last = embers.Value
		counterLabel.Text = `{Config.Currency.Icon} {NumberFormat.Abbreviate(last)}`
		embers.Changed:Connect(function(value)
			counterLabel.Text = `{Config.Currency.Icon} {NumberFormat.Abbreviate(value)}`
			if value > last then
				showGain(value - last)
			end
			last = value
		end)
	end)
end

return Hud

--!strict
-- A tip on screen (TipService on the server): a card above the hotbar for a few seconds, one at a time.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Device = require(ReplicatedStorage.Shared.Device)
local Fonts = require(ReplicatedStorage.Shared.Fonts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Tips = require(ReplicatedStorage.Shared.Tips)

local SHOW_SECONDS = 9

local TipCard = {}

function TipCard.Start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "Tips"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 7
	gui.Parent = player:WaitForChild("PlayerGui")

	local queue: { string } = {}
	local showing = false

	local function showNext()
		local id = table.remove(queue, 1)
		if not id then
			showing = false
			return
		end
		showing = true
		local text = ((Tips :: any)[id] :: string):gsub("{attack}", if Device.Touch() then "Tap the ⚔ button" else "Click")
		local card = Instance.new("Frame")
		card.AnchorPoint = Vector2.new(0.5, 1)
		card.Position = UDim2.new(0.5, 0, 1, -110)
		card.Size = UDim2.fromOffset(520, 0)
		card.AutomaticSize = Enum.AutomaticSize.Y
		card.BackgroundColor3 = Color3.fromRGB(22, 18, 20)
		card.BackgroundTransparency = 0.08
		card.Parent = gui
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0, 10)
		round.Parent = card
		local edge = Instance.new("UIStroke")
		edge.Color = Color3.fromRGB(240, 190, 90)
		edge.Thickness = 1.5
		edge.Parent = card
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 10)
		pad.PaddingBottom = UDim.new(0, 10)
		pad.PaddingLeft = UDim.new(0, 14)
		pad.PaddingRight = UDim.new(0, 14)
		pad.Parent = card
		local limit = Instance.new("UISizeConstraint")
		limit.MaxSize = Vector2.new(520, 400)
		limit.Parent = card
		local fit = Instance.new("UIScale")
		local screen = workspace.CurrentCamera.ViewportSize
		fit.Scale = math.min(1, (screen.X - 24) / 520)
		fit.Parent = card
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, 0, 0, 0)
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.FontFace = Fonts.Body
		label.TextSize = 18
		label.TextWrapped = true
		label.RichText = true
		label.TextColor3 = Color3.fromRGB(235, 228, 215)
		label.Text = `<font color="#F0BE5A">Tip:</font> {text}`
		label.Parent = card
		card.Position = UDim2.new(0.5, 0, 1, -80)
		TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 1, -110) }):Play()
		task.delay(SHOW_SECONDS, function()
			TweenService:Create(card, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			TweenService:Create(edge, TweenInfo.new(0.4), { Transparency = 1 }):Play()
			task.wait(0.45)
			card:Destroy()
			task.wait(0.4)
			showNext()
		end)
	end

	Remotes.Event("Tip").OnClientEvent:Connect(function(id: any)
		if type(id) ~= "string" or (Tips :: any)[id] == nil then
			return
		end
		table.insert(queue, id)
		if not showing then
			showNext()
		end
	end)
end

return TipCard

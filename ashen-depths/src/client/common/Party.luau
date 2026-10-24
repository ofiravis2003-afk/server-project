--!strict
-- The party on screen (PartyService on the server):
--   a list of the party's members under the stats (the leader in gold), in both places
--   in Emberhold: a Party button by the bag opening a window with the party (Leave) and everyone else in town
--   (Invite), and a card at the top when someone invites this player (Accept / Decline, until it runs out)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")

local Device = require(ReplicatedStorage.Shared.Device)
local Fonts = require(ReplicatedStorage.Shared.Fonts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local PANEL = Color3.fromRGB(22, 18, 20)
local EDGE = Color3.fromRGB(120, 90, 50)
local ROW = Color3.fromRGB(34, 28, 30)
local TEXT = Color3.fromRGB(230, 222, 208)
local GOLD = Color3.fromRGB(240, 190, 90)
local MAX_SIZE = 4

type Member = { UserId: number, Name: string }
type State = { LeaderId: number, Members: { Member } }

local Party = {}

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function stroke(parent: Instance)
	local s = Instance.new("UIStroke")
	s.Color = EDGE
	s.Thickness = 1.5
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

local function label(parent: Instance, font: Font, size: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = font
	l.TextSize = size
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.6
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

local function button(parent: Instance, text: string, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.BackgroundColor3 = color
	b.FontFace = Fonts.Title
	b.TextSize = 18
	b.TextColor3 = TEXT
	b.Text = text
	b.Parent = parent
	corner(b, 6)
	stroke(b)
	return b
end

function Party.Start(inTown: boolean)
	local player = Players.LocalPlayer
	local action = Remotes.Event("PartyAction")
	local state: State? = nil

	local gui = Instance.new("ScreenGui")
	gui.Name = "Party"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 4
	gui.Parent = player:WaitForChild("PlayerGui")

	-- the members, under the stats box
	local list = Instance.new("Frame")
	list.Name = "Members"
	list.Position = UDim2.fromOffset(12, if inTown then 92 else 162) -- (in the Depths: under the floor and keys panel)
	list.Size = UDim2.fromOffset(220, 0)
	list.AutomaticSize = Enum.AutomaticSize.Y
	list.BackgroundColor3 = PANEL
	list.BackgroundTransparency = 0.25
	list.Visible = false
	list.Parent = gui
	corner(list, 8)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.Parent = list
	local stack = Instance.new("UIListLayout")
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.Padding = UDim.new(0, 2)
	stack.Parent = list

	local function drawList()
		for _, child in list:GetChildren() do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		local s = state
		list.Visible = s ~= nil
		if not s then
			return
		end
		local head = label(list, Fonts.Title, 16, GOLD)
		head.Size = UDim2.new(1, -10, 0, 20)
		head.Text = "Party"
		head.LayoutOrder = 0
		for i, member in s.Members do
			local line = label(list, Fonts.Body, 15, TEXT)
			line.Size = UDim2.new(1, -10, 0, 19)
			line.LayoutOrder = i
			local leads = member.UserId == s.LeaderId
			line.Text = "• " .. member.Name .. (if leads then "  (leader)" else "")
			if leads then
				line.TextColor3 = GOLD
			end
		end
	end

	-- Emberhold: the window and the invites
	local redraw: () -> () = function() end
	if inTown then
		local open = button(gui, "Party", PANEL)
		open.AnchorPoint = Vector2.new(1, 1)
		open.Position = UDim2.new(1, -106, 1, -14)
		open.Size = UDim2.fromOffset(84, 40)
		if Device.Touch() then
			open.AnchorPoint = Vector2.new(1, 0)
			open.Position = UDim2.new(1, -116, 0, -28) -- (next to the bag, up in the top bar's row)
			open.Size = UDim2.fromOffset(96, 48)
			open.TextSize = 22
		end

		local panel = Instance.new("Frame")
		panel.AnchorPoint = Vector2.new(0.5, 0.5)
		panel.Position = UDim2.fromScale(0.5, 0.5)
		panel.Size = UDim2.fromOffset(400, 460)
		panel.BackgroundColor3 = PANEL
		panel.BackgroundTransparency = 0.05
		panel.Visible = false
		panel.Parent = gui
		corner(panel, 10)
		stroke(panel)
		local fit = Instance.new("UIScale")
		fit.Parent = panel
		local title = label(panel, Fonts.Title, 28, GOLD)
		title.Position = UDim2.fromOffset(16, 10)
		title.Size = UDim2.new(1, -60, 0, 32)
		title.Text = "Party"
		local line = label(panel, Fonts.Body, 15, Color3.fromRGB(200, 190, 175))
		line.Position = UDim2.fromOffset(16, 42)
		line.Size = UDim2.new(1, -32, 0, 36)
		line.TextWrapped = true
		line.TextYAlignment = Enum.TextYAlignment.Top
		line.Text = `Up to {MAX_SIZE} adventurers: +10% XP and gold together. The leader takes the party down the Well.`
		local close = button(panel, "X", Color3.fromRGB(70, 40, 40))
		close.AnchorPoint = Vector2.new(1, 0)
		close.Position = UDim2.new(1, -10, 0, 10)
		close.Size = UDim2.fromOffset(32, 32)
		close.MouseButton1Click:Connect(function()
			panel.Visible = false
		end)
		-- friends who aren't playing yet: Roblox's own invite window (ReferralService rewards both of you)
		local bring = button(panel, "Invite friends", Color3.fromRGB(150, 100, 30))
		bring.AnchorPoint = Vector2.new(1, 0)
		bring.Position = UDim2.new(1, -50, 0, 10)
		bring.Size = UDim2.fromOffset(140, 32)
		bring.TextSize = 16
		bring.MouseButton1Click:Connect(function()
			local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
			if ok and can then
				pcall(SocialService.PromptGameInvite, SocialService, player)
			end
		end)
		local rows = Instance.new("ScrollingFrame")
		rows.Position = UDim2.fromOffset(12, 86)
		rows.Size = UDim2.new(1, -24, 1, -98)
		rows.BackgroundTransparency = 1
		rows.BorderSizePixel = 0
		rows.ScrollBarThickness = 6
		rows.AutomaticCanvasSize = Enum.AutomaticSize.Y
		rows.CanvasSize = UDim2.new()
		rows.Parent = panel
		local rowStack = Instance.new("UIListLayout")
		rowStack.SortOrder = Enum.SortOrder.LayoutOrder
		rowStack.Padding = UDim.new(0, 6)
		rowStack.Parent = rows

		local function heading(text: string, order: number)
			local h = label(rows, Fonts.Title, 19, GOLD)
			h.Size = UDim2.new(1, -8, 0, 26)
			h.LayoutOrder = order
			h.Text = text
		end
		local function row(name: string, order: number, buttonText: string?, color: Color3?, onClick: (() -> ())?)
			local r = Instance.new("Frame")
			r.Size = UDim2.new(1, -8, 0, 44)
			r.BackgroundColor3 = ROW
			r.LayoutOrder = order
			r.Parent = rows
			corner(r, 8)
			local n = label(r, Fonts.Body, 17, TEXT)
			n.Position = UDim2.fromOffset(12, 0)
			n.Size = UDim2.new(1, -130, 1, 0)
			n.TextTruncate = Enum.TextTruncate.AtEnd
			n.Text = name
			if buttonText and onClick then
				local b = button(r, buttonText, color or Color3.fromRGB(40, 70, 45))
				b.AnchorPoint = Vector2.new(1, 0.5)
				b.Position = UDim2.new(1, -8, 0.5, 0)
				b.Size = UDim2.fromOffset(104, 32)
				b.TextSize = 17
				b.MouseButton1Click:Connect(onClick)
			end
		end

		redraw = function()
			for _, child in rows:GetChildren() do
				if not child:IsA("UIListLayout") then
					child:Destroy()
				end
			end
			local s = state
			local inParty: { [number]: boolean } = {}
			local order = 0
			local leading = s == nil or s.LeaderId == player.UserId
			if s then
				heading("Your party", order)
				for _, member in s.Members do
					order += 1
					inParty[member.UserId] = true
					local you = member.UserId == player.UserId
					row(member.Name .. (if you then " (you)" else "") .. (if member.UserId == s.LeaderId then "  · leader" else ""), order,
						if you then "Leave" else nil, Color3.fromRGB(70, 40, 40), if you then function()
							action:FireServer("Leave")
						end else nil)
				end
			end
			order += 1
			heading("Adventurers in town", order)
			local full = s ~= nil and #s.Members >= MAX_SIZE
			local anyone = false
			for _, other in Players:GetPlayers() do
				if other ~= player and not inParty[other.UserId] then
					anyone = true
					order += 1
					local canInvite = leading and not full
					row(other.DisplayName, order, if canInvite then "Invite" else nil, nil, if canInvite then function()
						action:FireServer("Invite", other)
					end else nil)
				end
			end
			if not anyone then
				order += 1
				local none = label(rows, Fonts.Text, 15, Color3.fromRGB(170, 160, 150))
				none.Size = UDim2.new(1, -8, 0, 24)
				none.LayoutOrder = order
				none.Text = "No one else is in town right now."
			end
		end

		open.MouseButton1Click:Connect(function()
			panel.Visible = not panel.Visible
			if panel.Visible then
				local screen = workspace.CurrentCamera.ViewportSize
				fit.Scale = math.min(1.3, (screen.Y - 90) / panel.Size.Y.Offset, (screen.X - 24) / panel.Size.X.Offset)
				redraw()
			end
		end)
		Players.PlayerAdded:Connect(function()
			if panel.Visible then
				redraw()
			end
		end)
		Players.PlayerRemoving:Connect(function()
			task.defer(function()
				if panel.Visible then
					redraw()
				end
			end)
		end)

		-- an invite: a card at the top of the screen
		Remotes.Event("PartyInvite").OnClientEvent:Connect(function(from: any, seconds: any)
			if typeof(from) ~= "Instance" or not from:IsA("Player") then
				return
			end
			local card = Instance.new("Frame")
			card.Name = "PartyInvite"
			card.AnchorPoint = Vector2.new(0.5, 0)
			card.Position = UDim2.new(0.5, 0, 0, -120)
			card.Size = UDim2.fromOffset(380, 104)
			card.BackgroundColor3 = PANEL
			card.BackgroundTransparency = 0.05
			card.Parent = gui
			corner(card, 10)
			stroke(card)
			local text = label(card, Fonts.Body, 18, TEXT)
			text.Position = UDim2.fromOffset(14, 10)
			text.Size = UDim2.new(1, -28, 0, 40)
			text.TextWrapped = true
			text.TextXAlignment = Enum.TextXAlignment.Center
			text.Text = `{from.DisplayName} invites you to their party!`
			local done = false
			local function finish(answer: string?)
				if done then
					return
				end
				done = true
				if answer then
					action:FireServer(answer, from)
				end
				TweenService:Create(card, TweenInfo.new(0.3), { Position = UDim2.new(0.5, 0, 0, -120) }):Play()
				task.delay(0.35, function()
					card:Destroy()
				end)
			end
			local yes = button(card, "Accept", Color3.fromRGB(40, 70, 45))
			yes.Position = UDim2.new(0.5, -124, 1, -46)
			yes.Size = UDim2.fromOffset(116, 36)
			yes.MouseButton1Click:Connect(function()
				finish("Accept")
			end)
			local no = button(card, "Decline", Color3.fromRGB(70, 40, 40))
			no.Position = UDim2.new(0.5, 8, 1, -46)
			no.Size = UDim2.fromOffset(116, 36)
			no.MouseButton1Click:Connect(function()
				finish("Decline")
			end)
			TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0, 12) }):Play()
			task.delay(if type(seconds) == "number" then seconds else 30, function()
				finish(nil)
			end)
		end)
	end

	Remotes.Event("PartyUpdated").OnClientEvent:Connect(function(newState: any)
		state = if type(newState) == "table" then newState else nil
		drawList()
		redraw()
	end)
end

return Party

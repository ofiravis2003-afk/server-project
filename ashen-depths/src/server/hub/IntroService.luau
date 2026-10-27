--!strict
-- A new adventurer's first minute in Emberhold (data.IntroDone not yet set):
--   1. they arrive at the south gate and the camera flies over the town and the Great Well (client/hub/Intro)
--   2. Aldric greets them (the AldricIntro dialogue) and they take the Guild Brand: a burning mark on the hand
--   3. the way down is marked: "Descend the Great Well", a beam of light over it, until they go
-- Players who have been here before (JoinCount > 1 when this was added) skip it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.Parent.Common.DataService)
local Onboarding = require(script.Parent.Parent.Common.Onboarding)

local IntroService = {}

local inIntro: { [Player]: boolean } = {}

-- The Brand: a small ember on the back of the right hand that never goes out.
local function brand(character: Model)
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not hand or hand:FindFirstChild("GuildBrand") then
		return
	end
	local at = Instance.new("Attachment")
	at.Name = "GuildBrand"
	at.Parent = hand
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 150, 60)
	glow.Range = 4
	glow.Brightness = 0.8
	glow.Parent = at
	local embers = Instance.new("ParticleEmitter")
	embers.Color = ColorSequence.new(Color3.fromRGB(255, 190, 110), Color3.fromRGB(255, 100, 30))
	embers.LightEmission = 1
	embers.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0) })
	embers.Lifetime = NumberRange.new(0.4, 0.8)
	embers.Rate = 5
	embers.Speed = NumberRange.new(0.3, 0.8)
	embers.SpreadAngle = Vector2.new(180, 180)
	embers.Acceleration = Vector3.new(0, 2, 0)
	embers.Parent = at
end

-- Starts the intro for a player (also from the Studio command bar to watch it again).
function IntroService.Begin(player: Player, town: { Model: Model, Spawn: CFrame })
	local character = player.Character or player.CharacterAdded:Wait()
	character:WaitForChild("HumanoidRootPart", 10)
	inIntro[player] = true
	Onboarding.Step(player, "Joined")
	-- in at the south gate, looking up the road at the Well
	local gate = town.Spawn.Position + Vector3.new(0, 0, 80)
	character:PivotTo(CFrame.lookAt(gate, Vector3.new(0, gate.Y, 0)))
	Remotes.Event("IntroStart"):FireClient(player)
end

function IntroService.Start(town: { Model: Model, Spawn: CFrame, Well: BasePart })
	local dialogueRemote = Remotes.Event("DialogueOpen")
	local objectiveRemote = Remotes.Event("Objective")
	local notifyRemote = Remotes.Event("Notify")

	DataService.OnLoaded(function(player, data)
		if data.IntroDone == nil then
			data.IntroDone = (data.JoinCount or 0) > 1 -- old players already know the way
		end
		if not data.IntroDone then
			IntroService.Begin(player, town)
		else
			local character = player.Character or player.CharacterAdded:Wait()
			brand(character)
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			local data = DataService.GetData(player)
			if data and data.IntroDone then
				task.defer(brand, character)
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		inIntro[player] = nil
	end)
	-- Studio only: ServerStorage.DevIntro:Invoke(player) plays the intro again (the save isn't changed until
	-- the Brand is taken, and taking it again changes nothing)
	if game:GetService("RunService"):IsStudio() then
		local dev = Instance.new("BindableFunction")
		dev.Name = "DevIntro"
		dev.OnInvoke = function(player: Player)
			task.spawn(IntroService.Begin, player, town)
			return true
		end
		dev.Parent = game:GetService("ServerStorage")
	end

	-- the fly-over is done: Aldric steps up
	Remotes.Event("IntroReady").OnServerEvent:Connect(function(player)
		if not inIntro[player] then
			return
		end
		Onboarding.Step(player, "IntroWatched")
		local aldric = town.Model:FindFirstChild("Aldric", true)
		local character = player.Character
		if not aldric or not aldric:IsA("Model") or not character then
			return
		end
		local front = aldric:GetPivot() * CFrame.new(0, 3, -6)
		character:PivotTo(CFrame.lookAt(front.Position, aldric:GetPivot().Position + Vector3.new(0, 3, 0)))
		task.wait(0.3)
		dialogueRemote:FireClient(player, aldric, "AldricIntro")
	end)

	-- "Take the Brand" (AldricIntro's button, handled by ShopService's DialogueAction)
	function IntroService.TakeBrand(player: Player)
		local data = DataService.GetData(player)
		if not inIntro[player] or not data then
			return
		end
		inIntro[player] = nil
		data.IntroDone = true
		Onboarding.Step(player, "TookBrand")
		if player.Character then
			brand(player.Character)
		end
		notifyRemote:FireClient(player, "The Guild Brand burns into your hand. It will bring you home.")
		objectiveRemote:FireClient(player, "Descend the Great Well", town.Well.Position)
	end
end

return IntroService

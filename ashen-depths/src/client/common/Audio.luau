--!strict
-- Music and sound effects on the player's screen.
--   Music: the town's tune in Emberhold, the Depths' in the dungeon, the boss theme while a boss bar is up
--          (crossfading between them).
--   Effects: Audio.Play(name, position?) from client code (a swing), the "Sound" remote from the server
--          (gates, chests, deaths, level ups), and the damage numbers already sent for every hit, heal and
--          reward (a hit on a monster, the player hurt, gold).
-- Ids and volumes live in shared/Sounds.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sounds = require(ReplicatedStorage.Shared.Sounds)

local Audio = {}

local player = Players.LocalPlayer
local lastPlayed: { [string]: number } = {}

-- One effect: at a place in the world (heard from there), or flat (heard everywhere).
function Audio.Play(name: string, position: Vector3?)
	local def = (Sounds.Effects :: any)[name]
	if not def then
		return
	end
	-- the same sound at most every 0.06 s (a cleave hitting six monsters is one sound, not six)
	local now = os.clock()
	if now - (lastPlayed[name] or 0) < 0.06 then
		return
	end
	lastPlayed[name] = now
	local sound = Instance.new("Sound")
	sound.SoundId = def.Id
	sound.Volume = def.Volume
	sound.PlaybackSpeed = 0.94 + math.random() * 0.12 -- a little different every time
	if position then
		local at = Instance.new("Attachment")
		at.WorldPosition = position
		at.Parent = workspace.Terrain
		sound.RollOffMaxDistance = 120
		sound.Parent = at
		sound.Ended:Once(function()
			at:Destroy()
		end)
		task.delay(10, function()
			at:Destroy()
		end)
	else
		sound.Parent = SoundService
		sound.Ended:Once(function()
			sound:Destroy()
		end)
		task.delay(10, function()
			sound:Destroy()
		end)
	end
	sound:Play()
end

function Audio.Start(place: string)
	-- music: two tracks, one playing, crossfaded
	local tracks: { [string]: Sound } = {}
	for name, def in Sounds.Music do
		local s = Instance.new("Sound")
		s.Name = "Music" .. name
		s.SoundId = def.Id
		s.Looped = true
		s.Volume = 0
		s:SetAttribute("FullVolume", def.Volume)
		s.Parent = SoundService
		tracks[name] = s
	end
	local current: string? = nil
	local function playMusic(name: string)
		if current == name then
			return
		end
		for other, s in tracks do
			if other ~= name and s.IsPlaying then
				local fade = TweenService:Create(s, TweenInfo.new(1.5), { Volume = 0 })
				fade:Play()
				fade.Completed:Once(function()
					if current ~= other then
						s:Stop()
					end
				end)
			end
		end
		current = name
		local s = tracks[name]
		if s then
			if not s.IsPlaying then
				s:Play()
			end
			TweenService:Create(s, TweenInfo.new(2), { Volume = s:GetAttribute("FullVolume") :: number }):Play()
		end
	end
	playMusic(place)
	local ambience = (Sounds.Ambience :: any)[place]
	if ambience then
		local s = Instance.new("Sound")
		s.Name = "Ambience"
		s.SoundId = ambience.Id
		s.Volume = ambience.Volume
		s.Looped = true
		s.Parent = SoundService
		s:Play()
	end
	if place == "Town" then
		-- a far-off caw every so often
		task.spawn(function()
			while true do
				task.wait(25 + math.random() * 35)
				Audio.Play("Caw")
			end
		end)
	end
	if place == "Depths" then
		-- the boss theme while a boss bar is on screen
		task.spawn(function()
			while true do
				task.wait(1)
				local bar = player.PlayerGui:FindFirstChild("BossBar")
				local showing = false
				if bar then
					for _, d in bar:GetDescendants() do
						if d:IsA("Frame") and d.Parent == bar and d.Visible then
							showing = true
						end
					end
				end
				playMusic(if showing then "Boss" else "Depths")
			end
		end)
		Remotes.Event("BossIntro").OnClientEvent:Connect(function(model: any)
			local at = if typeof(model) == "Instance" and model:IsA("Model") then model:GetPivot().Position else nil
			Audio.Play("BossRoar", at)
			playMusic("Boss")
		end)
	end

	-- from the server
	Remotes.Event("Sound").OnClientEvent:Connect(function(name: any, position: any)
		if type(name) == "string" then
			Audio.Play(name, if typeof(position) == "Vector3" then position else nil)
		end
	end)
	-- from the numbers that pop up: a hit, the player hurt, gold
	Remotes.Event("DamageNumber").OnClientEvent:Connect(function(position: any, _value: any, kind: any)
		if typeof(position) ~= "Vector3" then
			return
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local mine = root ~= nil and (root.Position - position).Magnitude < 4
		if kind == "Hurt" then
			if mine then
				Audio.Play("Hurt")
			end
		elseif kind == "Reward" then
			Audio.Play("Gold", position)
		elseif kind == "Heal" then
			-- (the potion's own gulp comes from the server)
		else
			Audio.Play("Hit", position)
		end
	end)
end

return Audio

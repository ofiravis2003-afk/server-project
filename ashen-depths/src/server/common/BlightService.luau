--!strict
-- Blight (chapter II, the Rotwood Caverns): the green ember's spores. Infected monsters add stacks to whoever
-- they hit (up to MAX); each stack takes HEAL_CUT off all healing (potions, the tome, resting), and at MAX
-- stacks the rot also eats a little health every second. Out of a fight it fades a stack at a time; an
-- Antidote clears it at once. The stacks are the player attribute "Blight" (shown by client/dungeon/BlightHud).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local BlightService = {}

local MAX = 5
local HEAL_CUT = 0.1 -- per stack
local FADE_AFTER = 12 -- seconds since the last spore before stacks start to fade
local FADE_EVERY = 6 -- then one stack every this many seconds
local ROT_PER_SECOND = 0.01 -- of max health, at MAX stacks

local lastHit: { [Player]: number } = {}
local lastFade: { [Player]: number } = {}

local function stacks(player: Player): number
	return (player:GetAttribute("Blight") :: number?) or 0
end

function BlightService.Add(player: Player, amount: number)
	local now = os.clock()
	lastHit[player] = now
	lastFade[player] = now
	player:SetAttribute("Blight", math.min(stacks(player) + amount, MAX))
end

function BlightService.Clear(player: Player)
	player:SetAttribute("Blight", nil)
end

-- What healing is worth for this player right now (1 = all of it).
function BlightService.HealMultiplier(player: Player): number
	return 1 - HEAL_CUT * stacks(player)
end

function BlightService.Start()
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 1 then
			return
		end
		elapsed = 0
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			local n = stacks(player)
			if n <= 0 then
				continue
			end
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Health <= 0 then
				BlightService.Clear(player) -- (a fresh start after falling)
				continue
			end
			if n >= MAX then
				humanoid:TakeDamage(humanoid.MaxHealth * ROT_PER_SECOND)
			end
			if now - (lastHit[player] or 0) > FADE_AFTER and now - (lastFade[player] or 0) > FADE_EVERY then
				lastFade[player] = now
				player:SetAttribute("Blight", if n - 1 > 0 then n - 1 else nil)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastHit[player] = nil
		lastFade[player] = nil
	end)
end

return BlightService

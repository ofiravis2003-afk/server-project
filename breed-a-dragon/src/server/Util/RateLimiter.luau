--!strict
-- Stops a player from triggering an action faster than `cooldown` seconds (anti auto-clicker / exploit spam).

local Players = game:GetService("Players")

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type RateLimiter = typeof(setmetatable({} :: { cooldown: number, last: { [Player]: number } }, RateLimiter))

function RateLimiter.new(cooldown: number): RateLimiter
	local self = setmetatable({ cooldown = cooldown, last = {} }, RateLimiter)
	Players.PlayerRemoving:Connect(function(player)
		self.last[player] = nil
	end)
	return self
end

-- Returns true (and starts the cooldown) if the player is allowed to act now.
function RateLimiter.Check(self: RateLimiter, player: Player): boolean
	local now = os.clock()
	local last = self.last[player]
	if last and now - last < self.cooldown then
		return false
	end
	self.last[player] = now
	return true
end

return RateLimiter

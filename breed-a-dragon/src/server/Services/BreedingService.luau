--!strict
-- Breeding: two of a player's dragons lay a Bred Egg in a free nest.
-- The baby's genes are decided now (each trait from one parent, with a small chance of a
-- mutation) and stored in the egg; it hatches like any other egg (see EggService).
-- Parents are not used up, they just rest for a while.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Genes = require(ReplicatedStorage.Shared.Genes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CurrencyService = require(script.Parent.CurrencyService)
local DataService = require(script.Parent.DataService)
local DragonService = require(script.Parent.DragonService)
local EggService = require(script.Parent.EggService)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)

export type BreedResult = { Ok: boolean, Message: string? }

local BreedingService = {}

local rng = Random.new()
local breedLimiter = RateLimiter.new(0.5)
local breedRemote = Remotes.Function("BreedDragons")

local function formatWait(seconds: number): string
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function BreedingService.Breed(player: Player, idA: any, idB: any): BreedResult
	local data = DataService.GetData(player)
	if not data or type(idA) ~= "string" or type(idB) ~= "string" then
		return { Ok = false }
	end
	if idA == idB then
		return { Ok = false, Message = "A dragon can't breed with itself." }
	end
	local a, b = data.Dragons[idA], data.Dragons[idB]
	if not a or not b then
		return { Ok = false }
	end

	local now = os.time()
	for _, parent in { a, b } do
		if parent.RestUntil and parent.RestUntil > now then
			local name = Genes.GetName(parent.Genes)
			return { Ok = false, Message = `{name} is resting. Try again in {formatWait(parent.RestUntil - now)}.` }
		end
	end
	if not EggService.HasFreeNest(player) then
		return { Ok = false, Message = "Your nests are full! Hatch an egg first." }
	end

	local fee = DragonStats.BreedFee(a.Genes, b.Genes)
	if not CurrencyService.Spend(player, fee) then
		local missing = math.ceil(fee - CurrencyService.Get(player))
		return {
			Ok = false,
			Message = `Breeding these two costs {fee}. You need {missing} more {Config.Currency.Name}.`,
		}
	end

	local baby, mutated =
		Genes.Breed(a.Genes, b.Genes, rng, Config.Breeding.MutationChance, Config.Breeding.MutationWeights)
	local generation = math.max(a.Generation or 1, b.Generation or 1) + 1
	local nest = EggService.PlaceEgg(player, "Bred", DragonStats.BreedTime(a.Genes, b.Genes), {
		Genes = baby,
		Generation = generation,
		Mutated = mutated,
	})
	if not nest then
		CurrencyService.Add(player, fee) -- shouldn't happen (we checked), but never keep the fee
		return { Ok = false, Message = "Your nests are full! Hatch an egg first." }
	end

	a.RestUntil = now + Config.Breeding.ParentRest
	b.RestUntil = now + Config.Breeding.ParentRest
	DragonService.Publish(player)
	return {
		Ok = true,
		Message = `💞 {Genes.GetName(a.Genes)} and {Genes.GetName(b.Genes)} laid a Bred Egg in nest {nest}!`,
	}
end

function BreedingService.Start()
	breedRemote.OnServerInvoke = function(player, idA, idB)
		if not breedLimiter:Check(player) then
			return { Ok = false }
		end
		return BreedingService.Breed(player, idA, idB)
	end
end

return BreedingService

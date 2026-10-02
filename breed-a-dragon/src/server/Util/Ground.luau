--!strict
-- Where the "middle of the map" is: the point on the ground under the SpawnLocation.

local Ground = {}

function Ground.GetSpawnCenter(): Vector3
	local spawnLocation = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if not spawnLocation then
		return Vector3.zero
	end
	local position = spawnLocation.Position
	return Vector3.new(position.X, position.Y - spawnLocation.Size.Y / 2, position.Z)
end

return Ground

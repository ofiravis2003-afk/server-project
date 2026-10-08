-- Pulls the game's code from GitHub into the open Studio place (instead of Rojo, which is blocked here).
-- Run it in Studio (through the Studio MCP, or paste into the Command Bar) after setting COMMIT and PLACE,
-- then press Ctrl+S. COMMIT should be a full commit hash, so GitHub's cache never serves old files.
--
-- Same layout as hub.project.json / dungeon.project.json:
--   src/shared            -> ReplicatedStorage.Shared
--   src/server/common     -> ServerScriptService.Server.Common
--   src/server/<place>    -> ServerScriptService.Server.<Hub|Dungeon>
--   src/client/common     -> StarterPlayer.StarterPlayerScripts.Client.Common
--   src/client/<place>    -> StarterPlayer.StarterPlayerScripts.Client.<Hub|Dungeon>
-- Scripts in those folders that no longer exist on GitHub are deleted.
-- Studio blocks web requests by default; this turns them on only while it runs, then restores the setting.

local COMMIT = "PUT_COMMIT_HASH_HERE"
local PLACE = if game.PlaceId == 94536878288268 then "dungeon" else "hub"

local REPO = "ofiravis2003-afk/server-project"
local ROOT = "ashen-depths/src/"

local HttpService = game:GetService("HttpService")
local httpWasEnabled = HttpService.HttpEnabled
HttpService.HttpEnabled = true
local ScriptEditorService = game:GetService("ScriptEditorService")

local placeFolder = if PLACE == "dungeon" then "Dungeon" else "Hub"
local targets = {
	["shared"] = { "ReplicatedStorage", "Shared" },
	["server/common"] = { "ServerScriptService", "Server", "Common" },
	["server/" .. PLACE] = { "ServerScriptService", "Server", placeFolder },
	["client/common"] = { "StarterPlayer", "StarterPlayerScripts", "Client", "Common" },
	["client/" .. PLACE] = { "StarterPlayer", "StarterPlayerScripts", "Client", placeFolder },
}

local function folderAt(path: { string }): Instance
	local current: Instance = game:GetService(path[1])
	for i = 2, #path do
		local child = current:FindFirstChild(path[i])
		if not child then
			child = Instance.new("Folder")
			child.Name = path[i]
			child.Parent = current
		end
		current = child
	end
	return current
end

local function sync(): string
local tree = HttpService:JSONDecode(
	HttpService:GetAsync(`https://api.github.com/repos/{REPO}/git/trees/{COMMIT}?recursive=1`)
)

local wanted: { [Instance]: { [string]: boolean } } = {}
local count = 0
for _, entry in tree.tree do
	local rel = entry.type == "blob" and entry.path:sub(1, #ROOT) == ROOT and entry.path:sub(#ROOT + 1)
	if rel and rel:sub(-5) == ".luau" then
		local dir, file = rel:match("^(.*)/([^/]+)%.luau$")
		local target = dir and targets[dir]
		if target then
			local name, className = file, "ModuleScript"
			if file:sub(-7) == ".server" then
				name, className = file:sub(1, -8), "Script"
			elseif file:sub(-7) == ".client" then
				name, className = file:sub(1, -8), "LocalScript"
			end
			local source = HttpService:GetAsync(`https://raw.githubusercontent.com/{REPO}/{COMMIT}/{entry.path}`)
			local parent = folderAt(target)
			local script = parent:FindFirstChild(name)
			if script and script.ClassName ~= className then
				script:Destroy()
				script = nil
			end
			if not script then
				script = Instance.new(className)
				script.Name = name
				script.Parent = parent
			end
			ScriptEditorService:UpdateSourceAsync(script :: LuaSourceContainer, function()
				return source
			end)
			wanted[parent] = wanted[parent] or {}
			wanted[parent][name] = true
			count += 1
		end
	end
end

local removed = 0
for _, path in targets do
	local parent = folderAt(path)
	for _, child in parent:GetChildren() do
		if child:IsA("LuaSourceContainer") and not (wanted[parent] and wanted[parent][child.Name]) then
			child:Destroy()
			removed += 1
		end
	end
end

return `Synced {count} scripts from {COMMIT:sub(1, 7)} into {PLACE}, removed {removed}`
end

local ok, result = pcall(sync)
HttpService.HttpEnabled = httpWasEnabled
return if ok then result else `Sync failed: {result}`

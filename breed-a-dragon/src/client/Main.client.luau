--!strict
-- Client entry point: builds the UI and listens to the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CrystalEffects = require(script.Parent.Effects.CrystalEffects)
local HatchReveal = require(script.Parent.UI.HatchReveal)
local Hud = require(script.Parent.UI.Hud)
local NestPanel = require(script.Parent.UI.NestPanel)

Hud.Start()
CrystalEffects.Start()
NestPanel.Start()

Remotes.Event("Notify").OnClientEvent:Connect(function(text: string)
	Hud.ShowMessage(text, 5)
end)

local hatchRemote = Remotes.Function("HatchEgg")
NestPanel.OnHatch(function(nest)
	local ok, result = pcall(hatchRemote.InvokeServer, hatchRemote, nest)
	if ok and type(result) == "table" and result.Ok and result.Genes and result.Egg then
		HatchReveal.Play(result.Egg, result.Genes)
		return
	end
	NestPanel.Shake(nest)
	if ok and type(result) == "table" and result.Message then
		Hud.ShowMessage(result.Message, 4)
	end
end)

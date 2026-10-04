--!strict
-- Client entry point: builds the UI and listens to the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CrystalEffects = require(script.Parent.Effects.CrystalEffects)
local DragonPets = require(script.Parent.Effects.DragonPets)
local ElderEffects = require(script.Parent.Effects.ElderEffects)
local Dialog = require(script.Parent.UI.Dialog)
local DragonsPanel = require(script.Parent.UI.DragonsPanel)
local HatchReveal = require(script.Parent.UI.HatchReveal)
local Hud = require(script.Parent.UI.Hud)
local NestPanel = require(script.Parent.UI.NestPanel)
local QuestTracker = require(script.Parent.UI.QuestTracker)

Hud.Start()
CrystalEffects.Start()
NestPanel.Start()
DragonPets.Start()
ElderEffects.Start()
Dialog.Start()
QuestTracker.Start()
DragonsPanel.Start(function(text)
	Hud.ShowMessage(text, 4)
end)

Remotes.Event("Notify").OnClientEvent:Connect(function(text: string)
	Hud.ShowMessage(text, 5)
end)

Remotes.Event("ShowDialog").OnClientEvent:Connect(function(lines)
	if type(lines) == "table" then
		Dialog.Say(lines)
	end
end)

local hatchRemote = Remotes.Function("HatchEgg")
NestPanel.OnHatch(function(nest)
	local ok, result = pcall(hatchRemote.InvokeServer, hatchRemote, nest)
	if ok and type(result) == "table" and result.Ok and result.Genes and result.Egg then
		HatchReveal.Play(result.Egg, result.Genes, {
			WorldFirst = result.WorldFirst,
			Mutated = result.Mutated,
			NewGenes = result.NewGenes,
		})
		return
	end
	NestPanel.Shake(nest)
	if ok and type(result) == "table" and result.Message then
		Hud.ShowMessage(result.Message, 4)
	end
end)

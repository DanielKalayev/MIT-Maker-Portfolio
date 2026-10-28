local Contestants = {}
local plrTemplate = require(script.Parent.PlrTemplate)
local inventoryTemplate = require(game.ReplicatedStorage.DeltaruneModules.Inventory)

function Contestants.new(player, name : StringValue, color : Color3, maxHealth : IntValue, attack : IntValue, defense : IntValue, magic : IntValue)
	local self = plrTemplate.new(player, name, color, maxHealth, attack, defense, magic)
	self.Inventory = inventoryTemplate.new()
	self.Money = 0
--	self.AttackAnim = "113023460775863"
	self.AttackAnim = "89214752331647"
	return self
end


return Contestants

local PlrTemplate = {}

PlrTemplate.Avatar = nil

function PlrTemplate.new(player, name : StringValue, color : Color3, maxHealth : IntValue, attack : IntValue, defense : IntValue, magic : IntValue)
	local self = setmetatable({}, {__index = PlrTemplate})
	self.Player = player
	self.Name = name
	self.Color = color
	self.MaxHealth = maxHealth
	self.Health = maxHealth
	self.Attack = attack
	self.Defense = defense
	self.Magic = magic
	return self
end

function PlrTemplate:LoadCharacter()
	print("loaded ".. self.Name .. "'s avatar")
	
	self.Player:LoadCharacter()
	local modelFound, model = pcall(function()
		return game.ReplicatedStorage.PlayerModels:FindFirstChild(self.Avatar)
	end)
	if not modelFound then return end
	
	if not self.Avatar then return end
	wait()
	local pos = self.Player.Character.PrimaryPart.CFrame
	
	local clone = model:Clone()
	
	for i, child in clone:GetDescendants() do
		local success, isAnchored = pcall(function()
			return child.Anchored
		end)
		if success and isAnchored then
			child.Anchored = false
		end
	end

	clone.Name = self.Player.Name
	self.Player.Character = clone
	clone.Parent = workspace
	clone:PivotTo(pos)
	
	for i, child in game:GetService("StarterPlayer"):WaitForChild("StarterCharacterScripts"):GetChildren() do
		if clone:FindFirstChild(child.Name) then continue end
		child:Clone().Parent = clone
	end
end 


return PlrTemplate

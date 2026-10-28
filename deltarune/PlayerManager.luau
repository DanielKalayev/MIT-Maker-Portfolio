local PlayerManager = {}

local plrChecker = require(game.ReplicatedStorage.Modules.PlayerChecker)
local characterModule = require(game.ReplicatedStorage.DeltaruneModules.Players)

PlayerManager.Contestants = {}
PlayerManager.Spectators = {}

PlayerManager.ContestantOrder = {
	[1] = "xryanpinkle",
	[2] = "Voidphobia",
	[3] = "Gorificruby",
	[4] = "Pinnapple_z",
}

local testContestantOrder = {
	[1] = "xryanpinkle",
	[2] = "Pengy1119",
	[3] = "Avalancheisgood",
	[4] = "Pinnapple_z"
}

PlayerManager.SpectatorOrder = {
	[1] = "Avalancheisgood",
	[2] = "Pengy1119"
}
--Avalancheisgood
--Pengy1119
--xryanpinkle

PlayerManager.activeContestantOrder = testContestantOrder

function PlayerManager:FindContestantByPlayer(plr : Player)
	for i, char in PlayerManager.Contestants do
		if char.Player == plr then
			return char
		end
	end
	return nil
end

local customSpawns = false
local spawnsList = game.Workspace["wood area 1"].Spawns

function SpawnPlayer(plr, character)
	if not customSpawns then return end

	local hrp = plrChecker.hrp(plr)
	if not hrp then return end

	local name = character.Name
	local spawnPnt = spawnsList:FindFirstChild(name.."Spawn")
	if not spawnPnt then return end

	hrp.Position = spawnPnt.Position + Vector3.new(0,2.5,0)
end

function AddContestant(plr, char)
	local orderNum = table.find(PlayerManager.activeContestantOrder, plr.Name)

	local character = characterModule.new(plr, orderNum, true)
	table.insert(PlayerManager.Contestants, character)
	print("Added " .. plr.Name .. " as a contestant.")

	task.delay(0.1, function()
		character:LoadCharacter()
		task.wait(2)
		SpawnPlayer(plr, character)
	end)
end

function AddSpectator(plr)
	local orderNum = table.find(PlayerManager.SpectatorOrder, plr.Name)

	local character = characterModule.new(plr, orderNum, false)
	table.insert(PlayerManager.Spectators, plr)
	print("Added " .. plr.Name .. " as a spectator.")

	task.delay(0.1, function()
		character:LoadCharacter()
	end)
end

function AddPlayerToRole(plr : Player)
	if table.find(PlayerManager.activeContestantOrder, plr.Name) then
		AddContestant(plr)
	elseif table.find(PlayerManager.SpectatorOrder, plr.Name) then
		AddSpectator(plr)
	else
		plr:Kick("You're not permitted to be here.")
	end
end

function PlayerManager:Setup()
	game.Players.PlayerAdded:Connect(function(plr : Player)
		AddPlayerToRole(plr)
	end)

	for i, player : Player in game.Players:GetPlayers() do
		AddPlayerToRole(player)
	end
end

return PlayerManager

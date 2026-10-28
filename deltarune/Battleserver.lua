local BattleServer = {}

--Main Events
local MainEventFolder = game.ReplicatedStorage.Events.Battles
local DRBattleEvent = MainEventFolder.DRBattle
local soulEvent = MainEventFolder.SoulMove

--Services
local ts = game:GetService("TweenService")

local plrChecker = require(game.ReplicatedStorage.Modules.PlayerChecker)
local charModule = require(game.ReplicatedStorage.DeltaruneModules.Players)
local playerManager = require(script.Parent.PlayerManager)

local testevent = game.ReplicatedStorage.Events.Test
local freezeEvent = game.ReplicatedStorage.Events.MovementEvent
local sprintEvent = game.ReplicatedStorage.Events.ShiftRunToggle

--States
local battling = false
local soulMode = false

--References
local arenas = {
	["Wood"] = workspace.FightMaps:WaitForChild("fight scene wood"),
	["Office"] = workspace.FightMaps:WaitForChild("fight scene office")
}

--Battle Arenas
local arenaData = {}
local activeArena = nil

local arenaPlrs = {}
local arenaEnemies = {}
local arenaVFX = {}

local battleFolder = workspace.BattleFolder
local camObj = nil

--Avalancheisgood
--Pengy1119
--xryanpinkle

local plrList = {}
local charList = {}

local activeSouls = {}

local currentPlr = 1
local currentButton = 1

local turn = 1

local selectionNum = 1
local currentMenu = nil

-- Fight queue system
local fightQueue = {}
local isProcessingFights = false
local FIGHT_DELAY = 0.5 -- Minimum delay between fight calculations in seconds

local enemyEvent = game.ReplicatedStorage.Events.EnemyDetect

function BattleServer:SetupArenas()
	
	local tempChars = {}

	for i = 1, 4 do
		table.insert(tempChars, charModule.new(nil, i, true))
	end
	
	for name, arena in pairs(arenas) do
		local charFolder = arena:FindFirstChild("Characters")
		arenaData[name] = {
			plrDummies = {
				charFolder:FindFirstChild("Plr1"),
				charFolder:FindFirstChild("Plr2"),
				charFolder:FindFirstChild("Plr3"),
				charFolder:FindFirstChild("Plr4")},
			enemyDummies = {},
			plrAnims = {
				idleAnims = {},
				fightAnims = {},
			},
		}
		
		for i, tempAgent in tempChars do
			local tempChar = game.ReplicatedStorage.PlayerModels.BattleRigs:FindFirstChild(tempAgent.Name .. "BattleChar")
			if not tempChar then continue end
			local dum = arenaData[name].plrDummies[i]
			
			local clone = tempChar:Clone()
			clone.Parent = charFolder
			clone:PivotTo(dum.HumanoidRootPart.CFrame)
			dum:Destroy()
			arenaData[name].plrDummies[i] = clone
			
			local humanoid = clone:FindFirstChild("Humanoid")
			if humanoid then
				local animator = humanoid:FindFirstChildOfClass("Animator")
				if not animator then continue end

				local idleTrack
				local fightTrack

				local targetIdle = tempAgent.IdleAnim
				local targetFight = tempAgent.AttackAnim

				if targetIdle then
					local idleAnim = Instance.new("Animation")
					idleAnim.AnimationId = "rbxassetid://" .. targetIdle
					idleTrack = animator:LoadAnimation(idleAnim)
					arenaData[name].plrAnims.idleAnims[i] = idleTrack
					idleTrack:Play()
				end
				if targetFight then
					local attackAnim = Instance.new("Animation")
					attackAnim.AnimationId = "rbxassetid://" .. targetFight
					fightTrack = animator:LoadAnimation(attackAnim)
					arenaData[name].plrAnims.fightAnims[i] = fightTrack
				end
			end
		end
		
		for i, dummy in charFolder:GetChildren() do
			if string.find(dummy.Name, "Enemy") then
				local val = Instance.new("CFrameValue", dummy)
				val.Name = "OrgPos"
				val.Value = dummy:GetPivot()
				table.insert(arenaData[name].enemyDummies, dummy)
			end
		end
	end
end

function resetAll()
	plrList = {}
	savedButtons = {
		[1] = 1,
		[2] = 1,
		[3] = 1,
		[4] = 1
	}
	currentPlr = 1
	currentButton = 1
	turn = 1
	fightQueue = {}
	isProcessingFights = false
end

function resetUIVals(dir)
	if dir == "Next" then
		currentButton = 1
	elseif dir == "Back" then
		currentButton = savedButtons[currentPlr]
	end
end

function checkPlrTurn()
	DRBattleEvent:FireAllClients("turn", false)

	local success, plrsTurn = pcall(function()
		return charList[currentPlr].Player
	end)

	if not success or not plrsTurn then
		plrsTurn = game.Players:GetPlayers()[1]
	end

	DRBattleEvent:FireClient(plrsTurn, "turn", true)
end

function getPlrFromNum(num)
	return charList[num].Player or game.Players:GetPlayers()[1]
end

local function createSelectionTemplate()
	return {
		["FightTarget"] = nil,
		["Act"] = nil,
		["ActTarget"] = nil,
		["Item"] = nil,
		["SpareTarget"] = nil,
		["Defend"] = nil
	}
end

local plrSelectionData = {
	[1] = createSelectionTemplate(),
	[2] = createSelectionTemplate(),
	[3] = createSelectionTemplate(),
	[4] = createSelectionTemplate()
}

local dmgCounter

function BattleServer:StartBattle(enemy, arenaName)
	resetAll()
	
	local players = playerManager.Contestants
	local order = playerManager.activeContestantOrder
	
	plrList = players
	activeArena = arenaName
	
	local enemies = {enemy}
	
	local function findPlrSlot(plrName)
		for i, char in players do
			if char.Player.Name == plrName then
				return i
			end
		end
		return nil
	end

	for i, supposedToBe in order do
		local plrAttempt = findPlrSlot(supposedToBe)
		if plrAttempt then
			charList[i] = plrList[plrAttempt]
		else
			charList[i] = charModule.new(nil, i, true)
		end
	end	
	
	print(charList)
	
	arenaEnemies = {}
	
	for i, dummy in arenaData[activeArena].enemyDummies do
		if string.find(dummy.Name, "Enemy"..#enemies) then
			table.insert(arenaEnemies, dummy)
		end
		if not table.find(arenaEnemies, dummy) then
			dummy:PivotTo(dummy:GetPivot() * CFrame.new(Vector3.new(0,-20,0)))
		end
	end
	
	for i, dummy in arenaEnemies do
		
		local slashVFX = game.ReplicatedStorage.DRBattleAssets.SlashVFX.MainVFXTemplate

		if slashVFX then
			slashVFX = slashVFX:Clone()
			slashVFX.Parent = arenas[activeArena]:FindFirstChild("TempModels")
			for i, child in slashVFX:GetChildren() do
				child.CFrame = dummy.HumanoidRootPart.CFrame
			end
			slashVFX.CFrame = dummy.HumanoidRootPart.CFrame
			arenaVFX[i] = slashVFX
		end
	end

	camObj = arenas[activeArena]:FindFirstChild("camera")

	for i, agent in plrList do --CHECK LATER THIS LINE!!!
		local plr = agent.Player
		local hrp = plrChecker.hrp(plr)
		if not hrp then continue end
		local hum = plrChecker.hum(plr)
		if not hum then continue end

		sprintEvent:FireClient(plr, false)
		hum.WalkSpeed = 0
		hum.JumpPower = 0

		--for _, track in pairs(hum:GetPlayingAnimationTracks()) do
		--	track:Stop()
		--end

		local data = {
			charList,
			enemies
		}
		DRBattleEvent:FireClient(plr, "Start", data, camObj:GetPivot(), arenaData[activeArena].enemyDummies[1], arenaData[activeArena].plrDummies)
	end
	checkPlrTurn()
end

function cyclePlr(val, selectionData)
	-- Store the selection data for the current player
	if selectionData then
		plrSelectionData[currentPlr] = selectionData
		--print("Player " .. currentPlr .. " selection data saved:")
		for k, v in pairs(selectionData) do
			--print("  " .. k .. ": " .. tostring(v))
		end
	end

	savedButtons[currentPlr] = currentButton
	currentPlr += val

	if currentPlr < 1 then
		currentPlr = 1
		return "error"
	end

	if currentPlr > 4 then
		currentPlr = 4
		DRBattleEvent:FireAllClients("turn", false)
		task.delay(0.3, function()
			processTurn()
		end)
		return "battleStart"
	end

	checkPlrTurn()
	if val > 0 then
		resetUIVals("Next")
	elseif val < 0 then
		resetUIVals("Back")
	end
	return "cycleBar"
end

function fireAllButOne(plrExempt, action, data)
	for i, player in game.Players:GetPlayers() do
		if player.Name == plrExempt.Name then continue end
		DRBattleEvent:FireClient(player, action, data)
	end
end

function spawnDmgThing(num, color)
	if not arenaVFX then return end
	local dmgBlock = arenaVFX[1]:FindFirstChild("DamageCounter")
	local gui = dmgBlock:FindFirstChild("BillboardGui")
	local template = gui:FindFirstChild("Template")
	if not gui or not template then return end

	-- Create a new BillboardGui for this damage number
	local cloneGui = gui:Clone()
	cloneGui.Parent = dmgBlock
	cloneGui.Enabled = true

	local textLabel = cloneGui:FindFirstChild("Template")
	textLabel.TextColor3 = color
	textLabel.Text = tostring(num)
	textLabel.Visible = true

	local xScale = math.random(1,2)
	if xScale % 2 == 0 then
		xScale = 0.2
	else
		xScale = 0.6
	end
	local yScale = math.random(-2,2)

	local posScale = UDim2.new(xScale, 0, 0.5, 0)
	textLabel.Position = UDim2.new(0.5,0,0.5,0)

	-- Start slightly above
	cloneGui.StudsOffset = Vector3.new(0, yScale + 2, 0)

	-- Tween it upward
	ts:Create(cloneGui, TweenInfo.new(
		0.7,
		Enum.EasingStyle.Bounce,
		Enum.EasingDirection.Out
		), {
			StudsOffset = Vector3.new(0, yScale, 0)
		}):Play()
	ts:Create(textLabel, TweenInfo.new(0.7), {Position = posScale}):Play()
	-- Fade the text out


	task.delay(2, function()
		ts:Create(textLabel, TweenInfo.new(0.7), {TextTransparency = 1}):Play()
		ts:Create(textLabel.UIStroke, TweenInfo.new(0.7), {Transparency = 1}):Play()
		ts:Create(cloneGui, TweenInfo.new(0.5, Enum.EasingStyle.Circular, Enum.EasingDirection.In), {StudsOffset = Vector3.new(0, 12, 0)}):Play()
		game.Debris:AddItem(cloneGui, 0.5)
	end)
end

local listOfActions = {{},{},{},{},{}}

local boxFullSize = Vector3.new(0.001, 7.5, 7.5)
local boxSmallSize = Vector3.new(0.001, 0.1, 0.1)

function startSoul()
	if soulMode then return end
	soulMode = true
	
	DRBattleEvent:FireAllClients("soulMode")
	local pvpFolder = game.ReplicatedStorage.DRBattleAssets.PVP
	local soulFolder = game.ReplicatedStorage.DRBattleAssets.Souls
	
	local box = pvpFolder.Box:Clone()
	local bg = pvpFolder.BG:Clone()
	local area = pvpFolder.Area:Clone()
	box.Parent = battleFolder
	bg.Parent = battleFolder
	area.Parent = battleFolder
	local cntrCF = camObj.CFrame * CFrame.new(0,0,-8)
	box:PivotTo(cntrCF)
	area.CFrame = cntrCF * CFrame.Angles(0,math.rad(-90), 0)
	bg.CFrame = camObj.CFrame * CFrame.new(0,0,-8.2)
	box:PivotTo(box:GetPivot() * CFrame.Angles(0,math.rad(90), 0))
	bg.CFrame *= CFrame.Angles(0,math.rad(90), 0)
	
	box.Size = boxSmallSize
	bg.Transparency = 1
	box.Orientation = box.Orientation + Vector3.new(-270,0,0)
	
	local startInfo = TweenInfo.new(0.7, Enum.EasingStyle.Linear, Enum.EasingDirection.In)
	local boxCF = box.CFrame
	activeSouls = {}
	
	for i, char in charList do
		local plr = char.Player
		if not plr then continue end
		local finalSoul = nil
		for _, soul in soulFolder:GetChildren() do
			local plrNum = soul:GetAttribute("Plr")
			if not plrNum then continue end
			
			if plrNum ~= i then continue end

			local clonedSoul = soul:Clone()
			clonedSoul.Parent = battleFolder.Souls
			
			local orgPos = arenaData[activeArena].plrDummies[i]:FindFirstChild("HumanoidRootPart").Position

			-- local offsets (in box space)
			local right = plrNum % 2 == 0 and -1 or 1
			local down = plrNum <= 2 and 1 or -1
			local offset = Vector3.new(right, down, 0)

			-- transform offset by box orientation
			local pos = (boxCF * CFrame.Angles(math.rad(-90), math.rad(90), 0) * CFrame.new(offset))
			clonedSoul:PivotTo(pos)
			clonedSoul:PivotTo(CFrame.new(orgPos))
			
			ts:Create(clonedSoul:FindFirstChild("Hitbox"), TweenInfo.new(0.4, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut), {CFrame = CFrame.new(pos.Position)}):Play()
			
			activeSouls[plrNum] = clonedSoul
			DRBattleEvent:FireClient(getPlrFromNum(plrNum), "setupSoul", clonedSoul)
		end
	end
	
	local boxTween = ts:Create(box, startInfo, {Size = boxFullSize, Orientation = box.Orientation + Vector3.new(270,0,0)})
	boxTween:Play()
	local bgTween = ts:Create(bg, TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut), {Transparency = 0.65})
	task.delay(0.4, function()
		bgTween:Play()
	end)
	
	boxTween.Completed:Once(function()
		task.wait(0.05)
		DRBattleEvent:FireAllClients("soulMove", {true, area})
		local mod = require(game.ReplicatedStorage.DeltaruneModules.Enemies.TestEnemy.ProjectileAttack)
		local attack = mod.new(area)
	end)
end

function processTurn()
	--[[for i = 1, 4 do
		local selection = plrSelectionData[i]
		print("Player " .. i .. " selection:")
		for k, v in pairs(selection) do
			print("  " .. k .. ": " .. tostring(v))
		end

		if selection.FightTarget then
			print("Player " .. i .. " is fighting target " .. selection.FightTarget)
		elseif selection.Act then
			print("Player " .. i .. " is using act " .. selection.Act .. " on target " .. (selection.ActTarget or "none"))
		elseif selection.Item then
			print("Player " .. i .. " is using item " .. selection.Item)
		elseif selection.SpareTarget then
			print("Player " .. i .. " is sparing target " .. selection.SpareTarget)
		elseif selection.Defend then
			print("Player " .. i .. " is defending")
		end
	end]]
	print("processing")
	-- Reset for next turn
	--resetTurn()

	listOfActions = {{},{},{},{},{}}

	for i, selectionData in plrSelectionData do
		if selectionData.FightTarget then
			local plr = getPlrFromNum(i)
			table.insert(listOfActions[5], {"Fight", {i, plr}})
		elseif selectionData.Act and selectionData.ActTarget then
			table.insert(listOfActions[i], {"Act", {i, selectionData.Act, selectionData.ActTarget}})
		elseif selectionData.Item then
			table.insert(listOfActions[i], {"Item", {i, selectionData.Item}})
		elseif selectionData.SpareTarget then
			table.insert(listOfActions[i], {"Spare", {i, selectionData.SpareTarget}})
		elseif selectionData.Defend then
			table.insert(listOfActions[i], i)
		end
	end

	--fight stuff
	task.spawn(function()
		for i, actions in listOfActions do
			if #actions <= 0 then continue end

			local success, isFightSlot = pcall(function()
				return listOfActions[i][1][1] == "Fight"
			end)

			if success and isFightSlot then
				local tab = {}
				for i, plr in actions do
					if not table.find(tab, plr) then
						table.insert(tab, plr)
						DRBattleEvent:FireClient(plr[2][2], "turn", "FightTurn")
					end
				end
			end

			if success and isFightSlot then
				local tab = {}
				for i, v in actions do
					table.insert(tab, v[2])
				end
				DRBattleEvent:FireAllClients(actions[1][1], tab)
			else
				DRBattleEvent:FireAllClients(actions[1], actions[2])
			end

			repeat wait(0.1) until listOfActions[i] == nil

		end
		print("ok is done now")
		startSoul()
	end)
end

-- Queue system for fight calculations
function addToFightQueue(data)
	table.insert(fightQueue, data)
	if not isProcessingFights then
		processNextFight()
	end
end

function processNextFight()
	if #fightQueue == 0 then
		isProcessingFights = false
		print("done")
		listOfActions[5] = nil
		return
	end

	isProcessingFights = true
	local nextFight = table.remove(fightQueue, 1)

	-- Execute the fight calculation
	calculateFight(nextFight)

	-- Wait for the delay before processing the next fight
	task.wait(FIGHT_DELAY)
	processNextFight()
end

function calculateFight(data)
	local plrNum = data[1]
	local xPos = data[2]
	local distanceFromTarget = data[3]
	local behindMultiplier = data[4] --false = in front, true = behind, nil = center
	local plrChar = charList[plrNum]
	local plr = getPlrFromNum(plrNum)

	local dataToSend = {
		plrNum,
		xPos
	}
	fireAllButOne(plr, "FightUpd", dataToSend)

	--task.delay(math.random(10, 75) / 100, function()
	local dmgStat = plrChar.Attack
	if distanceFromTarget == nil then
		distanceFromTarget = dmgStat
	end
	local damage = dmgStat - distanceFromTarget

	if behindMultiplier == nil and distanceFromTarget ~= nil then
		DRBattleEvent:FireAllClients("slashSFX", "HitCrit")
		damage *= 1.5
	end

	damage = math.floor(damage)

	DRBattleEvent:FireAllClients("personSlash", plrChar.Name)
	
	local idleTrack = arenaData[activeArena].plrAnims.idleAnims[plrNum]
	local fightTrack = arenaData[activeArena].plrAnims.fightAnims[plrNum]
	local vfx = arenaVFX[1]

	if idleTrack and fightTrack then
		idleTrack:Stop()
		fightTrack:Play()
		task.delay(fightTrack.Length, function()
			idleTrack:Play()
		end)
	end
	local plrColor = plrChar.Color
	if damage == 0 then
		spawnDmgThing("Miss", plrColor)
	else
		spawnDmgThing(damage, plrColor)
	end
	
	if vfx then
		local charVFX = vfx:FindFirstChild(plrChar.Name)
		for i, particle in charVFX:GetDescendants() do
			if particle:IsA("ParticleEmitter") then
				particle:Emit()
			end
		end
	end

	task.delay(0.4, function()
		DRBattleEvent:FireAllClients("slashSFX", "SlashHit")
	end)
	--end)

	task.delay(1, function()
		DRBattleEvent:FireClient(plr, "turn", false)
	end)
end

function updateCharClient()
	DRBattleEvent:FireAllClients("updAllPlrData", charList)
end

function TakeDamage(data)
	local plrNum = data[1]
	local dmg = data[2]
	local plrChar = charList[plrNum]
	local health = plrChar.Health - dmg
	if health < 0 then
		health = 0
	end
	plrChar.Health = health
	updateCharClient()
end

function resetTurn()
	for i = 1, 4 do
		plrSelectionData[i] = createSelectionTemplate()
	end
	currentPlr = 1
	turn += 1
	print("Turn " .. turn .. " starting")
	cyclePlr(0, nil)
end

-- Modified event handler
DRBattleEvent.OnServerEvent:Connect(function(plr, action, data)
	if action == "buttonChange" then
		currentButton = data
		fireAllButOne(plr, action, currentButton)
	elseif action == "buttonToggle" then
		local direction, selectionData
		-- Handle both old format (just number) and new format (table)
		if type(data) == "table" then
			direction = data.direction
			selectionData = data.selectionData
		else
			direction = data
			selectionData = nil
		end

		local returnData = cyclePlr(direction, selectionData)
		DRBattleEvent:FireAllClients(returnData, {currentPlr, currentButton})
	elseif action == "setMenu" then
		fireAllButOne(plr, action, data)
	elseif action == "menuUpd" then
		fireAllButOne(plr, action, data)

	elseif action == "fightCallback" then	
		addToFightQueue(data)  -- Changed to queue the fight instead of calling directly
	elseif action == "error" then
		fireAllButOne(plr, action)
	elseif action == "moveSFX" then
		fireAllButOne(plr, action)
	elseif action == "selectSFX" then
		fireAllButOne(plr, action)
	elseif action == "TakeDamage" then
		if not soulMode then return end
		TakeDamage(data)
	end
end)

soulEvent.OnServerEvent:Connect(function(plr, soulNum, cf)
	if not soulMode then return end
	activeSouls[soulNum]:FindFirstChild("Hitbox").CFrame = cf
end)

enemyEvent.Event:Connect(function(enemy)
	if battling then return end
	battling = true
	BattleServer:StartBattle(enemy, "Wood")
end)

return BattleServer

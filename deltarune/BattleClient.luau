local ts = game:GetService("TweenService")
local uis = game:GetService("UserInputService")
local rs = game:GetService("RunService")

local players = game.Players
local player = players.LocalPlayer
local camera = workspace.CurrentCamera

local battleActivated = false

local plrChecker = require(game.ReplicatedStorage.Modules.PlayerChecker)
local event = game.ReplicatedStorage.Events.Battles.DRBattle

local localView = require(script.LocalView)

local abilityList = require(game.ReplicatedStorage.DeltaruneModules.Abilities.AbilityList)
local itemModuleList = require(game.ReplicatedStorage.DeltaruneModules.Inventory.Items)

local soulScript = require(script.SoulBattle)

--sounds
local soundFolder = script.SoundsFolder

local startSFX = soundFolder.Start
local hornSFX = soundFolder.Horn
local music = soundFolder.Music
local menuMove = soundFolder.MenuMove
local selectSFX = soundFolder.Select
local errorSFX = soundFolder.Error

function playSound(sound : Sound)
	if sound.IsPlaying then
		sound:Stop()
	end
	sound:Play()
end

local mainMenu = script.Parent.MainBar.MainArea

local bg = script.Parent.BG
local topLeftBG = bg.TopLeft
local botRightBG = bg.BottomRight
ts:Create(topLeftBG, TweenInfo.new(15, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {Position = UDim2.new(-1,0,-1,0)}):Play()
ts:Create(botRightBG, TweenInfo.new(15, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {Position = UDim2.new(1,0,1,0)}):Play()
bg.Visible = false
bg.Transparency = 1

local mainBar = script.Parent.MainBar
local normBarPos = UDim2.new(0.5, 0, 0.3, 0)
local soulBarPos = UDim2.new(0.5, 0, 0.493, 0)
local hiddenBarPos = UDim2.new(0.5, 0, 1, 0)
mainBar.Position = hiddenBarPos

script.Parent.Enabled = false

local plr1 = mainBar.Plr1
local plr2 = mainBar.Plr2
local plr3 = mainBar.Plr3
local plr4 = mainBar.Plr4

local menuEnabled = false
local menuControlled = false

local bars = {
	plr1,
	plr2,
	plr3,
	plr4
}

local colorSchemes = {
	[1] = Color3.new(0.415686, 1, 0.952941),
	[2] = Color3.new(1, 0, 1),
	[3] = Color3.new(0.333333, 1, 0.498039),
	[4] = Color3.new(1, 0.262745, 0.0392157)
}

local hpNormalSize = UDim2.new(0.258, 0,0.2, 0)

local currentBarNum = 1
local currentBarTween = nil
local activeBar = plr1

local barTweenies = {}
local barTweenCoroutine = nil

local buttons = {
	"Fight",
	"Act",
	"Item",
	"Spare",
	"Defend"
}
local currentButtonNum = 1
local currentButton = nil

local normButtonColor = Color3.fromRGB(255, 170, 0)
local selectedButtonColor = Color3.fromRGB(255, 255, 0)

for i, v in ipairs(bars) do
	local color = colorSchemes[i]
	v.BorderColor3 = color
	v.Buttons.BorderColor3 = color
	v.HPBar.BackgroundColor3 = color
	if i ~= currentButtonNum then
		v.Position = UDim2.new(v.Position.X.Scale, v.Position.X.Offset, 1, 0)
		v.BorderSizePixel = 0
	end
	for j, k in v.Buttons:GetChildren() do
		k.BackgroundColor3 = normButtonColor
		k.ButtonText.Visible = false
	end
end

local selectionDict = {
	{"Target"}, -- fight
	{"Act", "Target"}, --act
	{"Item"}, --item
	{"Target"}, --spare
	{nil} -- defend
}

local actList = mainMenu.Acts
local enemyList = mainMenu.EnemyList
local itemList = mainMenu.Items

local slashMenu = mainMenu.Fights

local selectionNum = 1
local currentMenu = nil
local selectionToMenuDict = {
	["Target"] = enemyList,
	["Act"] = actList,
	["Item"] = itemList
}
local inMenuTrackerNum = 1

local battlePlayers

local tempEnemies = {
	"Enemy1", 
	"Enemy2",
	"Enemy3"
}

function try(data, tcamSpot, enemy, plrs)
	local hrp = plrChecker.hrp(player)
	if not hrp then return end
	script.Parent.Enabled = true

	game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

	hornSFX:Play()
	task.delay(1, function()
		startSFX:Play()
	end)

	localView:try(data, camera, tcamSpot, enemy, plrs)

	task.delay(1, function()
		bg.Visible = true
		ts:Create(bg, TweenInfo.new(0.4), {Transparency = 0}):Play()
	end)
	battlePlayers = data[1]
	for i, plr in battlePlayers do
		updGuiToPlayer(i, plr)
		--print(plr)
	end
	task.wait(1.4)
	startUI()

	for i, back in bg:GetDescendants() do
		if back:IsA("ImageLabel") then
			ts:Create(back, TweenInfo.new(0.4), {ImageTransparency = 1}):Play()
		end
	end
	ts:Create(bg, TweenInfo.new(0.4), {Transparency = 1}):Play()

	localView:fade(tcamSpot)
	music:Play()
end

function updColors()
	for i, v in ipairs(bars) do
		local color = colorSchemes[i]
		v.BorderColor3 = color
		v.Buttons.BorderColor3 = color
		v.HPBar.BackgroundColor3 = color
	end
end

local turnTween = nil
local turnText = script.Parent.TurnText

local itemSlotList = {}
for i, slot in itemList.List:GetChildren() do
	if slot:IsA("TextLabel") then 
		table.insert(itemSlotList, slot)
	end
end

function turnAnnounce()
	if turnTween then turnTween:Cancel() end
	turnTween = ts:Create(turnText, TweenInfo.new(1.5), {TextTransparency = 1})

	turnText.Visible = true
	turnText.TextTransparency = 0
	task.delay(1, function()
		turnTween:Play()
	end)
end

function updGuiToPlayer(slot, playerObj)
	local plrBar = bars[slot]
	plrBar.Visible = true
	plrBar:FindFirstChild("Name").Text = playerObj.Name
	plrBar.MaxHP.Text = playerObj.MaxHealth
	plrBar.MinHP.Text = playerObj.Health
	colorSchemes[slot] = playerObj.Color
	updColors()
end

function resetBars()
	for i, v in ipairs(bars) do
		local tweeeeen = ts:Create(v, TweenInfo.new(0.1), {Position = UDim2.new(v.Position.X.Scale, v.Position.X.Offset, 1, 0)}):Play()
		v.BorderSizePixel = 0
	end
end

function setBar(val, buttonVal)
	if val == "Reset" then
		resetBars()
		resetMenus()
		return
	end

	if val - currentBarNum > 0 then
		if selectSFX.IsPlaying then
			selectSFX:Stop()
		end
		selectSFX:Play()
	else
		if menuMove.IsPlaying then
			menuMove:Stop()
		end
		menuMove:Play()
	end

	currentBarNum = val
	selectionNum = 1
	currentMenu = nil
	resetMenus()

	if activeBar then
		if currentBarTween then
			currentBarTween:Cancel()
			currentBarTween = nil
		end
		activeBar.Position = UDim2.new(activeBar.Position.X.Scale, activeBar.Position.X.Offset, 1, 0)
		activeBar.BorderSizePixel = 0
		activeBar.Buttons.BorderSizePixel = 0
		activeBar.ZIndex = 1
		for i, tweenie in barTweenies do
			tweenie[1]:Destroy()
			tweenie[2]:Cancel()
			tweenie = nil
		end
	end
	if barTweenCoroutine then
		coroutine.close(barTweenCoroutine)
	end
	activeBar = bars[val]
	activeBar.BorderSizePixel = 5
	activeBar.Buttons.BorderSizePixel = 4
	activeBar.ZIndex = 2
	setButton(buttonVal, false)

	barTweenCoroutine = coroutine.create(function()
		for i = 1, 8 do
			local barThing = Instance.new("Frame")
			barThing.Parent = activeBar:FindFirstChild("Buttons")
			barThing.Size = UDim2.new(0, 5, 1, 0)
			barThing.BackgroundColor3 = barThing.Parent.BorderColor3
			barThing.BackgroundTransparency = 0.2
			barThing.ZIndex = 0
			local tween
			local tweenInf = TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1)
			if i % 2 == 0 then
				barThing.AnchorPoint = Vector2.new(0, 0.5)
				barThing.Position = UDim2.new(0, 1, 0.5, 0)
				tween = ts:Create(barThing, tweenInf, {BackgroundTransparency = 1, Position = UDim2.new(0.25, 0, 0.5, 0), Size = UDim2.new(0, 5, 0.7, 0)})
			else
				barThing.AnchorPoint = Vector2.new(1, 0.5)
				barThing.Position = UDim2.new(1, -1, 0.5, 0)
				tween = ts:Create(barThing, tweenInf, {BackgroundTransparency = 1, Position = UDim2.new(0.75, 0, 0.5, 0), Size = UDim2.new(0, 5, 0.7, 0)})
			end
			local data = {barThing, tween}
			tween:Play()
			table.insert(barTweenies, data)
			if i % 2 == 0 then
				task.wait(0.25)
			end
		end
	end)
	coroutine.resume(barTweenCoroutine)

	currentBarTween = ts:Create(activeBar, TweenInfo.new(0.3), {Position = UDim2.new(activeBar.Position.X.Scale, activeBar.Position.X.Offset, 0.897, 0)})
	currentBarTween:Play()
end

function setButton(val, makeNoise : boolean)
	currentButtonNum = val
	if currentButtonNum < 1 then
		currentButtonNum = 5
	end
	if currentButtonNum > 5 then
		currentButtonNum = 1
	end
	local newButton = activeBar.Buttons:FindFirstChild(buttons[currentButtonNum])
	if currentButton then
		currentButton.BackgroundColor3 = normButtonColor
		currentButton.ButtonText.Visible = false
	end

	newButton.BackgroundColor3 = selectedButtonColor
	newButton.ButtonText.Visible = true
	newButton.ButtonText.ZIndex = 5

	if currentButton ~= newButton and makeNoise then
		if menuMove.IsPlaying then
			menuMove:Stop()
		end
		menuMove:Play()
	end

	currentButton = newButton
end

function startUI()
	local startTween = ts:Create(mainBar, TweenInfo.new(0.4), {Position = normBarPos})
	startTween:Play()
	setBar("Reset")
	startTween.Completed:Connect(function()
		menuEnabled = true
		setBar(1, 1)
		if menuControlled then
			turnAnnounce()
		end
	end)
end

setButton(1, false)

local playerSelectionData = {
	["FightTarget"] = nil,
	["Act"] = nil,
	["ActTarget"] = nil,
	["Item"] = nil,
	["SpareTarget"] = nil,
	["Defend"] = nil
}

function setMenu(num, depth, override)
	local maxMenuNum = #selectionDict[num]
	if depth > maxMenuNum then

		if currentButtonNum == 1 then -- Fight
			playerSelectionData["FightTarget"] = inMenuTrackerNum
		elseif currentButtonNum == 2 then -- Act
			playerSelectionData["ActTarget"] = inMenuTrackerNum -- Could be different if you have sub-menus
		elseif currentButtonNum == 3 then -- Item
			playerSelectionData["Item"] = inMenuTrackerNum
		elseif currentButtonNum == 4 then -- Spare
			playerSelectionData["SpareTarget"] = inMenuTrackerNum
		elseif currentButtonNum == 5 then -- Defend
			playerSelectionData["Defend"] = true
		end

		local data = {
			direction = 1,
			selectionData = playerSelectionData
		}
		event:FireServer("buttonToggle", data)
		return true
	elseif depth < 1 then
		currentMenu = nil
		resetMenus()
		if override then return end
		event:FireServer("setMenu", depth)
		allMove()
		return false
	else
		local menu = selectionToMenuDict[selectionDict[num][depth]]
		setupMenu(menu, Color3.new(0,1,1))
		if override then return end
		event:FireServer("setMenu", depth)
		allSelect()
	end
	selectionNum = depth
end

function resetPlayerSelectionData()
	playerSelectionData = {
		["FightTarget"] = nil,
		["Act"] = nil,
		["ActTarget"] = nil,
		["Item"] = nil,
		["SpareTarget"] = nil,
		["Defend"] = nil
	}
end

function resetMenus()
	for i, menuuu in mainMenu:GetChildren() do
		menuuu.Visible = false
	end
end
resetMenus()


local activeFightBars = {}
local passiveFightBars = {}
local canSlash = false
--[[local testFights = {
	{1, player},
	{3, player},
	{4, nil}
}]]

function calculateFight(distance, pos, plrFightNum, behind)
	--distance = nil, means it missed. behind should also be nil
	--otherwise distance = number, for damage calc
	--plrfightnum = bar number for which one to do blah blah
	--behind says if its behind or in front of target, otherwise if nil for perfect + distance wtv

	--should fire server and relay ts data
	--plrNum, where it is (pos), distance from the thingie, behind or not 
	event:FireServer("fightCallback", {plrFightNum, pos, distance, behind})
end

function setupMenu(menu, color, data)
	currentMenu = menu
	resetMenus()
	if menu == actList then
		for i, ability in menu:GetChildren() do
			if ability.Name ~= "Desc" then
				local heart = ability:FindFirstChild("Heart")
				heart.Visible = false
				heart.ImageColor3 = color
			end
		end
		local actDict = {
			actList.Passive,
			actList.Act1,
			actList.Act2,
			actList.DuoAct,
			actList.AllAct
		}
		local function setDesc()
			local desc = actList.Desc
			local abilityName = actDict[1]:FindFirstChild("Name").Text
			local ability = abilityList:GetAbilityData(abilityName)
			if ability then
				desc:FindFirstChild("Text").Text = ability.Description
			end
		end
		setDesc()
		menu:FindFirstChild("Passive").Heart.Visible = true
	elseif menu == itemList then
		for i, item in itemList.List:GetChildren() do
			if not item:IsA("TextLabel") then continue end
			local heart = item:FindFirstChild("Heart")
			heart.Visible = false
			heart.ImageColor3 = color
		end
		local function setDesc()
			local desc = itemList.Desc
			local itemName = itemSlotList[1].Text
			local item = itemModuleList:GetItemData(itemName)
			if item then
				desc.Text = item.Description
			end
		end
		setDesc()
		itemSlotList[1].Heart.Visible = true
	elseif menu == enemyList then
		local template = enemyList.List.Template
		template.Visible = false
		for i, child in enemyList.List:GetChildren() do
			if child.Name ~= "Template" and child:IsA("Frame") then
				child:Destroy()
			end
		end
		for i, enemy in tempEnemies do
			local newEnemy = template:Clone()
			newEnemy.Name = enemy
			newEnemy.Visible = true
			newEnemy:FindFirstChild("EnemyName"):FindFirstChild("Heart").Visible = false
			newEnemy:FindFirstChild("EnemyName"):FindFirstChild("Heart").ImageColor3 = color
			newEnemy:FindFirstChild("EnemyName").Text = enemy
			newEnemy.Parent = enemyList.List
		end
		enemyList.List:FindFirstChild("Enemy1"):FindFirstChild("EnemyName"):FindFirstChild("Heart").Visible = true
	elseif menu == slashMenu then
		if data and not canSlash then
			currentMenu = slashMenu
			activeFightBars = {}
			passiveFightBars = {}
			local template = slashMenu.List:FindFirstChild("Template")
			template.Visible = false

			for i, child in slashMenu.List:GetChildren() do
				if child.Name ~= "Template" and child:IsA("Frame") then
					child:Destroy()
				end
			end

			local timeToTake = math.random(20,75) / 100
			local rate = 0.005

			for i, slot in data do
				local newTemplate = template:Clone()

				local plrActive = battlePlayers[slot[1]]

				local normColor = plrActive.Color
				local H, S, V = normColor:ToHSV()

				local brightColor = Color3.new(
					math.clamp(normColor.R * 1.4, 0, 1),
					math.clamp(normColor.G * 1.4, 0, 1),
					math.clamp(normColor.B * 1.4, 0, 1)
				)
				local darkColor = Color3.new(
					normColor.R * 0.7,
					normColor.G * 0.7,
					normColor.B * 0.7
				)

				newTemplate.Name = plrActive.Name
				newTemplate:FindFirstChild("Name").Text = plrActive.Name
				newTemplate:FindFirstChild("ColorBar").BackgroundColor3 = darkColor
				newTemplate:FindFirstChild("Area").BorderColor3 = normColor
				newTemplate:FindFirstChild("Area").Space.BorderColor3 = brightColor
				newTemplate.Parent = slashMenu.List
				local moving = newTemplate:FindFirstChild("Moving")

				local zeroPos = newTemplate.Area.Position.X.Scale - 0.01
				local targetRange = newTemplate.Area.Space.Size.X.Offset / newTemplate.AbsoluteSize.X / 2
				local targetPos = newTemplate.Area.Position.X.Scale + targetRange

				local steps = timeToTake / rate
				local totalDistance = rate * steps

				local spawnPos = zeroPos + totalDistance
				--spawnPos = math.min(spawnPos, 1)

				if slot[2] == player then

					moving.Position = UDim2.new(spawnPos, 0, moving.Position.Y.Scale, 0)
					local movingBar = coroutine.create(function()

						local startTime = tick()
						local cnt = 0

						local spawnThingy = function()
							task.spawn(function()
								local clone = moving:Clone()
								clone.Parent = moving.Parent
								local tween = ts:Create(clone, TweenInfo.new(0.3), {BackgroundTransparency = 1, Size = UDim2.new(0, 15, 1.2, 0)})
								tween:Play()
								tween.Completed:Once(function()
									clone:Destroy()
								end)
							end)
						end
						canSlash = true
						while moving.Position.X.Scale > zeroPos do
							moving.Position = UDim2.new(moving.Position.X.Scale - rate, 0, moving.Position.Y.Scale, 0)
							task.wait(rate)
							cnt += 1
							if cnt >= 7 then
								cnt = 0
								spawnThingy()
							end
						end
						print("miss")
						ts:Create(moving, TweenInfo.new(0.4), {BackgroundTransparency = 1 , Size = UDim2.new(0, 7, 0.8, 0)}):Play()
						activeFightBars = {}
						calculateFight(nil, moving.Position.X.Scale, slot[1], nil)
						canSlash = false
					end)
					table.insert(activeFightBars, {newTemplate, movingBar, {targetPos, targetRange}, slot[1]})
					coroutine.resume(movingBar)
				else
					moving.Visible = false
					table.insert(passiveFightBars, {slot[1], newTemplate})
				end
				newTemplate.Visible = true
			end

		end
	end
	if currentMenu == itemList and #battlePlayers[currentBarNum].Inventory.Storage.Items <= 0 then
		allError()
		resetMenus()
		currentMenu = nil
		return
	end
	currentMenu.Visible = true
	inMenuTrackerNum = 1
end

function allError()
	if errorSFX.IsPlaying then
		errorSFX:Stop()
	end
	errorSFX:Play()
	event:FireServer("error")
end

function allMove()
	if menuMove.IsPlaying then
		menuMove:Stop()
	end
	menuMove:Play()
	event:FireServer("moveSFX")
end

function allSelect()
	if selectSFX.IsPlaying then
		selectSFX:Stop()
	end
	selectSFX:Play()
	event:FireServer("selectSFX")
end

function interactWithMenu(keycode, override, data)
	if not keycode then return end
	local key = uis:GetStringForKeyCode(keycode)
	if not key then return end

	if currentMenu == nil and not override then
		if key == "Z" then
			local doSelectSFX = setMenu(currentButtonNum, 1)
			if doSelectSFX then return end
			allSelect()
		elseif key == "X" then
			event:FireServer("buttonToggle", -1)
		end
		return
	end

	if currentMenu == actList then
		local actDict = {
			actList.Passive,
			actList.Act1,
			actList.Act2,
			actList.DuoAct,
			actList.AllAct
		}
		local function hoverAct()
			for i, act in actDict do
				act:FindFirstChild("Heart").Visible = false
			end
			actDict[inMenuTrackerNum].Heart.Visible = true
		end

		local function setDesc()
			local desc = actList.Desc
			local abilityName = actDict[inMenuTrackerNum]:FindFirstChild("Name").Text
			local ability = abilityList:GetAbilityData(abilityName)
			if ability then
				desc:FindFirstChild("Text").Text = ability.Description
			end
		end

		local numToChangeTo = inMenuTrackerNum
		if override then
			hoverAct()
			setDesc()
			return
		end
		if key == "W" then
			numToChangeTo -= 3
		elseif key == "S" then
			numToChangeTo += 3
		elseif key == "A" then
			numToChangeTo -= 1
		elseif key == "D" then
			numToChangeTo += 1
		elseif key == "Z" then
			playerSelectionData["Act"] = inMenuTrackerNum
			setMenu(currentButtonNum, selectionNum + 1)
			return
		elseif key == "X" then
			setMenu(currentButtonNum, selectionNum - 1)
			return
		end
		if numToChangeTo < 1 or numToChangeTo > 5 then
			allError()
		else
			inMenuTrackerNum = numToChangeTo
			setDesc()
			hoverAct()
			allMove()
			event:FireServer("menuUpd", inMenuTrackerNum)
		end
	elseif currentMenu == itemList then
		local function hoverAct()
			for i, item in itemSlotList do
				item:FindFirstChild("Heart").Visible = false
			end
			itemSlotList[inMenuTrackerNum].Heart.Visible = true
		end

		local function setDesc()
			local desc = itemList.Desc
			local abilityName = itemSlotList[inMenuTrackerNum].Text
			local ability = itemModuleList:GetItemData(abilityName)
			if ability then
				desc.Text = ability.Description
			end
		end

		local numToChangeTo = inMenuTrackerNum
		if override then
			hoverAct()
			setDesc()
			return
		end

		if key == "W" then
			if numToChangeTo % 2 == 0 then
				numToChangeTo -= 1
			else
				numToChangeTo += 1
			end
		elseif key == "S" then
			if numToChangeTo % 2 == 0 then
				numToChangeTo -= 1
			else
				numToChangeTo += 1
			end
		elseif key == "A" then
			numToChangeTo -= 2
		elseif key == "D" then
			numToChangeTo += 2
		elseif key == "Z" then
			playerSelectionData["Item"] = inMenuTrackerNum
			setMenu(currentButtonNum, selectionNum + 1)
			return
		elseif key == "X" then
			setMenu(currentButtonNum, selectionNum - 1)
			return
		end
		if numToChangeTo < 1 then
			numToChangeTo = 10 + numToChangeTo
		elseif numToChangeTo > 10 then
			numToChangeTo = numToChangeTo - 10
		end
		if itemSlotList[numToChangeTo].Text == "" then
			allError()
			return
		end
		inMenuTrackerNum = numToChangeTo
		setDesc()
		hoverAct()
		allMove()
		event:FireServer("menuUpd", inMenuTrackerNum)
	elseif currentMenu == enemyList then
		local enemyDict = {}
		for i, child in enemyList.List:GetChildren() do
			if child.Name ~= "Template" and child:IsA("Frame") then
				table.insert(enemyDict, child)
			end
		end
		if #enemyDict <= 0 then return end
		local function hoverAct()
			for i, enemy in enemyDict do
				enemy:FindFirstChild("EnemyName"):FindFirstChild("Heart").Visible = false
			end
			enemyDict[inMenuTrackerNum]:FindFirstChild("EnemyName"):FindFirstChild("Heart").Visible = true
		end

		if override then
			hoverAct()
			return
		end
		local numToChangeTo = inMenuTrackerNum
		if key == "W" then
			numToChangeTo -= 1
		elseif key == "S" then
			numToChangeTo += 1
		elseif key == "Z" then
			setMenu(currentButtonNum, selectionNum + 1)
			return
		elseif key == "X" then
			setMenu(currentButtonNum, selectionNum - 1)
			return
		end
		if numToChangeTo < 1 or numToChangeTo > #enemyDict then
			allError()
		elseif key ~= "A" and key ~= "D" then
			inMenuTrackerNum = numToChangeTo
			hoverAct()
			allMove()
			event:FireServer("menuUpd", inMenuTrackerNum)
		end
	elseif currentMenu == slashMenu then
		if override then
			local passiveFightBar 
			for i, menu in passiveFightBars do
				if menu[1] == data[1] then
					passiveFightBar = menu[2]
					break
				end
			end
			local pos = data[2]
			if not passiveFightBar then return end
			local moving = passiveFightBar:FindFirstChild("Moving")
			moving.BackgroundColor3 = passiveFightBar.Area.Space.BorderColor3
			moving.Position = UDim2.new(pos, moving.Position.X.Offset, moving.Position.Y.Scale, moving.Position.Y.Offset)
			task.spawn(function()
				local clone = moving:Clone()
				clone.Parent = moving.Parent
				clone.Visible = true
				local tween = ts:Create(clone, TweenInfo.new(0.3), {BackgroundTransparency = 1, Size = UDim2.new(0, 15, 1.2, 0)})
				tween:Play()
				tween.Completed:Once(function()
					clone:Destroy()
				end)
			end)
			moving.BackgroundTransparency = 1
			moving.Visible = true
			ts:Create(moving, TweenInfo.new(0.175), {BackgroundTransparency = 0}):Play()
			task.delay(0.4, function()
				ts:Create(moving, TweenInfo.new(0.6), {BackgroundTransparency = 1 , Size = UDim2.new(0, 12, 1.2, 0)}):Play()
			end)

		end
		if not canSlash then return end
		if key == "Z" then
			for i, routine in activeFightBars do
				local uiThing = routine[1]
				coroutine.close(routine[2])
				local moving = uiThing:FindFirstChild("Moving")
				local targetSpot = routine[3][1]
				local range = routine[3][2]

				local distance = math.abs(targetSpot - moving.Position.X.Scale)
				if distance <= range then
					print("good")
					moving.BackgroundColor3 = Color3.new(1,1,0)
					calculateFight(distance, moving.Position.X.Scale, routine[4], nil)
				elseif moving.Position.X.Scale < targetSpot then
					print("behind")
					calculateFight(distance, moving.Position.X.Scale, routine[4], true)
				else
					print("ahead")
					calculateFight(distance, moving.Position.X.Scale, routine[4], false)
				end
				canSlash = false
				local tween = ts:Create(moving, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {BackgroundTransparency = 1, Size = UDim2.new(0, 8, 1.4, 0)})
				tween:Play()
			end
			activeFightBars = {}
		end
	end
end

uis.InputBegan:Connect(function(input, e)
	if e or not menuControlled or not menuEnabled then return end--or player.Name ~= "Pengy1119" then return end
	if input.KeyCode == Enum.KeyCode.D then
		if currentMenu then 
			interactWithMenu(input.KeyCode)
			return
		end
		setButton(currentButtonNum + 1, true)
		event:FireServer("buttonChange", currentButtonNum)
	elseif input.KeyCode == Enum.KeyCode.A then
		if currentMenu then 
			interactWithMenu(input.KeyCode)
			return
		end
		setButton(currentButtonNum - 1, true)
		event:FireServer("buttonChange", currentButtonNum)
	elseif input.KeyCode == Enum.KeyCode.W then
		if currentMenu then 
			interactWithMenu(input.KeyCode)
			return
		end
	elseif input.KeyCode == Enum.KeyCode.S then
		if currentMenu then 
			interactWithMenu(input.KeyCode)
			return
		end
	elseif input.KeyCode == Enum.KeyCode.Z then
		interactWithMenu(input.KeyCode)
	elseif input.KeyCode == Enum.KeyCode.X then
		interactWithMenu(input.KeyCode)
	elseif input.KeyCode == Enum.KeyCode.L then
		--setupMenu(slashMenu, nil, testFights)
	end
end)

function sfxMake(soundName)
	local sfx = script.SoundsFolder:FindFirstChild(soundName)
	if not sfx then return end
	local clone = sfx:Clone()
	clone.Parent = script
	clone:Play()
	game.Debris:AddItem(clone, clone.TimeLength)
end

function plrsfxMake(soundName)
	local sfx = script.SoundsFolder.SlashSFX:FindFirstChild(soundName)
	if not sfx then return end
	local clone = sfx:Clone()
	clone.Parent = script
	clone:Play()
	game.Debris:AddItem(clone, clone.TimeLength)
end

function startSoul(data)
	local lowerTween = ts:Create(mainBar, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Position = soulBarPos})
	lowerTween:Play()
end

event.OnClientEvent:Connect(function(quota, data, tcamSpot, enemy, plrs)
	if quota == "Start" then
		try(data, tcamSpot, enemy, plrs)
	elseif quota == "buttonChange" then
		setButton(data, true)
	elseif quota == "cycleBar" then
		setBar(data[1], data[2])
	elseif quota == "setMenu" then
		setMenu(currentButtonNum, data, true)
	elseif quota == "menuUpd" then
		inMenuTrackerNum = data
		interactWithMenu(Enum.KeyCode.LeftShift, true)
	elseif quota == "turn" then
		if data == "FightTurn" then
			menuControlled = true
			return
		end
		menuControlled = data
		if data == true then
			resetPlayerSelectionData() -- Reset when it becomes this player's turn
		end
		if not menuEnabled or data ~= true then return end
		turnAnnounce()
	elseif quota == "battleStart" then
		playSound(selectSFX)
		setBar("Reset")

	elseif quota == "Fight" then
		--print(data)
		setupMenu(slashMenu, nil, data)	
	elseif quota == "FightUpd" then
		interactWithMenu(Enum.KeyCode.LeftShift, true, data)

	elseif quota == "error" then
		if errorSFX.IsPlaying then
			errorSFX:Stop()
		end
		errorSFX:Play()
	elseif quota == "moveSFX" then
		if menuMove.IsPlaying then
			menuMove:Stop()
		end
		menuMove:Play()
	elseif quota == "selectSFX" then
		if selectSFX.IsPlaying then
			selectSFX:Stop()
		end
		selectSFX:Play()
	elseif quota == "slashSFX" then
		sfxMake(data)
	elseif quota == "personSlash" then
		plrsfxMake(data)
	elseif quota == "soulMode" then
		startSoul(data)
	elseif quota == "setupSoul" then
		soulScript:setupHeart(data)
	elseif quota == "soulMove" then
		soulScript:ToggleMovement(data)
	elseif quota == "updAllPlrData" then
		battlePlayers = data
	end
end)

function update()
	if not menuEnabled or not battlePlayers then return end
	local currentPlr = battlePlayers[currentBarNum]
	for i, ability in actList:GetChildren() do
		if ability.Name == "Desc" then continue end
		local plrAbility = currentPlr.Abilities[ability.Name]
		ability:FindFirstChild("Name").Text = plrAbility.Name
	end
	local itemsTaken = {}
	for i, item in currentPlr.Inventory.Storage.Items do
		itemSlotList[i].Text = item.Name
		table.insert(itemsTaken, i)
	end
	for i, slot in itemSlotList do
		if table.find(itemsTaken, i) then continue end
		itemSlotList[i].Text = ""
	end
	for slot, playerObj in battlePlayers do
		local plrBar = bars[slot]
		plrBar.MinHP.Text = playerObj.Health
		plrBar.HPBar.Size = UDim2.new(math.max(hpNormalSize.X.Scale * (playerObj.Health / playerObj.MaxHealth), 0), 0, hpNormalSize.Y.Scale, 0)
	end
end

rs.Heartbeat:Connect(function()
	update()
end)

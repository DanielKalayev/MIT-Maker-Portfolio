local hostEvent = game.ReplicatedStorage.Events.HostEvent

local canvas = script.Parent
local plrList = canvas.PlayerList
local template = plrList.Template

local questions = {}
local totalQuestions = nil

local buttonList = {}

local startButton = canvas:FindFirstChild("StartButton")
local skipButton = canvas:FindFirstChild("SkipButton")

local leftButton = canvas:FindFirstChild("Left")
local rightButton = canvas:FindFirstChild("Right")
local slideNumText = canvas:FindFirstChild("SlideNumber")

local currentPlr = nil
local selectedButton = nil

function updateCompleted(button : TextButton, playerData)
	button:FindFirstChild("Completed").Text = tostring(#playerData) .. "/" .. tostring(totalQuestions)
	if #playerData >= totalQuestions and skipButton then
		skipButton.Visible = true
		skipButton.Interactable = true
	end
end

script.Parent.Enabled = false
skipButton.Visible = false
skipButton.Interactable = false

local slideNum = 1

function presentPlr(plr : Player)
	slideNum = 1
	slideNumText.Visible = true
	slideNumText.Text = tostring(slideNum) .. "/" .. tostring(totalQuestions)
	currentPlr = plr
	hostEvent:FireServer("Present", currentPlr.UserId, 1)
	
	leftButton.Visible = true
	leftButton.Interactable = true
	rightButton.Visible = true
	rightButton.Interactable = true
end

function clearPresent()
	currentPlr = nil
	slideNumText.Visible = false
	leftButton.Visible = false
	leftButton.Interactable = false
	rightButton.Visible = false
	rightButton.Interactable = false
	hostEvent:FireServer("ClearPresent")
end

function shiftSlide(num)
	slideNum += num
	if slideNum <= 0 or slideNum > totalQuestions then
		slideNum -= num
		return
	end
	slideNumText.Text = tostring(slideNum) .. "/" .. tostring(totalQuestions)
	hostEvent:FireServer("Present", currentPlr.UserId, slideNum)
end

hostEvent.OnClientEvent:Connect(function(quota, value)
	if quota == "Update" then
		for userID : Player, data in value do
			local plr : Player = game.Players:GetPlayerByUserId(userID)
			if not plr then continue end
			if not buttonList[plr] then
				local newButton = template:Clone()
				newButton.Name = plr.Name
				
				newButton:FindFirstChild("PlrName").Text = plr.Name .. " (" .. plr.DisplayName .. ")" 
				
				
				newButton:FindFirstChild("PlayerIcon").Image = "rbxthumb://type=AvatarHeadShot&id=" .. plr.UserId .. "&w=420&h=420"
				
				newButton.Parent = plrList
				newButton.Visible = true
				buttonList[plr] = newButton
			end
			updateCompleted(buttonList[plr], data)
		end
	elseif quota == "Setup" then
		questions = value
		totalQuestions = #questions
		startButton.Interactable = true
		startButton.Visible = true
		script.Parent.Enabled = true
	elseif quota == "Started" then
		startButton.Interactable = false
		startButton.Visible = false
	elseif quota == "Present" then
		skipButton:Destroy()
		for plr, button in buttonList do
			button.Interactable = true
			button.Activated:Connect(function()
				if selectedButton == button then
					clearPresent()
					selectedButton = nil
					return
				end
				selectedButton = button
				presentPlr(plr)
			end)
		end
	end
end)

startButton.Activated:Once(function()
	hostEvent:FireServer("Start")
end)

skipButton.Activated:Once(function()
	hostEvent:FireServer("Skip")
end)

leftButton.Activated:Connect(function()
	shiftSlide(-1)
end)

rightButton.Activated:Connect(function()
	shiftSlide(1)
end)

leftButton.Visible = false
leftButton.Interactable = false
rightButton.Visible = false
rightButton.Interactable = false
slideNumText.Visible = false
local event = game.ReplicatedStorage.Events.JobEvent
local questionEvent = game.ReplicatedStorage.Events.QuestionEvent
local jobSong = game.Workspace.Music.MainTheme

local projector = game.Workspace["Projector Screen"].Screen

local question = require(script.Question)

local questions = {
	question.new("Who is void tuah", question.PromptType.Text),
	question.new("Draw void", question.PromptType.Drawing),
	question.new("Larping legends", question.PromptType.Drawing),
	question.new("Green blue purple or nurple", question.PromptType.Drawing),
	question.new("The 3 sigmas in a tree, tell their ultimate story", question.PromptType.Text),
	question.new("Why has your life taken a toll on you?", question.PromptType.Text),
	question.new("Draw void again", question.PromptType.Drawing),
	question.new("Have you ever thought negatively of yourself?", question.PromptType.Text),
	question.new("plort or glort", question.PromptType.Drawing),
	question.new("How much would you pay jimmy for balogna", question.PromptType.Text),
	question.new("Draw a source of depression", question.PromptType.Drawing),
	question.new("draw a burger", question.PromptType.Drawing),
	question.new("Favorite color?", question.PromptType.Drawing),
	question.new("With great power comes...?", question.PromptType.Text),
	question.new("Empire state building, burj kalifa, or i fell tower", question.PromptType.Drawing),
	question.new("Void tuah never", question.PromptType.Drawing),
	question.new("Are you done?", question.PromptType.Text),
	question.new("Draw void again.", question.PromptType.Drawing),
	question.new("Why are you not done?", question.PromptType.Text),
	question.new("One last beef steak", question.PromptType.Drawing),
}
local playerSlides = {}

local hostEvent = game.ReplicatedStorage.Events.HostEvent
local hosts = {}

game.Players.PlayerAdded:Connect(function(plr : Player)
	if plr.UserId ~= 3044253828 and plr.UserId ~= 505172123 and plr.UserId ~= 992685329 then return end

	table.insert(hosts, plr)
	hostEvent:FireClient(plr, "Setup", questions)

	plr.CharacterAdded:Connect(function(char)
		if plr.UserId ~= 3044253828 then return end
		local torso : Part = char:FindFirstChild("Torso")
		torso.Size = Vector3.new(3,2,3)
	end)
end)

if not jobSong.IsLoaded then
	jobSong.Loaded:Wait()
end

local totalTime = math.floor(jobSong.TimeLength)
local lastTimer = totalTime

local playing = false

local introScreen = projector.IntroScreen
local presentScreen = projector.PresentScreen

local questionText = presentScreen.Question
local personText = presentScreen.Person

local textResponse = presentScreen.Canvas.TextResponse
local drawingResponse = presentScreen.Canvas.DrawingResponse

function ClearPresent()
	textResponse.Text = ""
	drawingResponse:ClearAllChildren()
	personText.Text = ""
	questionText.Text = ""
end

function present(userID, slideNum)
	local playerData = playerSlides[userID]
	if not playerData then return end
	local plr = game.Players:GetPlayerByUserId(userID)
	if not plr then return end
	local slide = playerData[slideNum]
	if not slide then return end
	
	ClearPresent()
	
	personText.Text = plr.Name
	questionText.Text = "Question " .. tostring(slideNum) .. ": " .. questions[slideNum].Question
	
	if slide.Drawing then
		for _, dotData in ipairs(slide.Drawing) do
			local paint = Instance.new("Frame")
			paint.BackgroundColor3 = dotData.color
			paint.BorderSizePixel = 0
			paint.Position = UDim2.fromScale(dotData.x, dotData.y)
			paint.Size = UDim2.new(10 / slide.Resolution.X, 0, 10 / slide.Resolution.Y, 0)
			paint.Parent = drawingResponse
		end
	elseif slide.Text then
		textResponse.Text = slide.Text
	end
end

hostEvent.OnServerEvent:Connect(function(plr, quota, playerID, slideNum)
	if quota == "Start" and not playing then
		playing = true
		for i, plr in game.Players:GetPlayers() do
			if table.find(hosts, plr) then
				event:FireClient(plr, "Host")
				hostEvent:FireClient(plr, "Started")
			else
				event:FireClient(plr, "Start")
			end
		end
		jobSong:Play()
		
		
		task.spawn(function()
			while playing do
				task.wait()
				local timer = math.floor(math.max(0, jobSong.TimeLength - jobSong.TimePosition))

				if timer ~= lastTimer then 
					lastTimer = timer
					event:FireAllClients("Timer", timer)
				end

				if timer <= 0 then
					playing = false
					event:FireAllClients("End")
					for i, host in hosts do
						hostEvent:FireClient(host, "Present")
						presentScreen.Enabled = true
						introScreen.Enabled = false
					end
				end
			end
		end)
	elseif quota == "Skip" then
		if not playing then return end
		playing = false
		event:FireAllClients("Skip")
		event:FireAllClients("End")
		for i, host in hosts do
			hostEvent:FireClient(host, "Present")
			presentScreen.Enabled = true
			introScreen.Enabled = false
		end
		jobSong:Stop()
	elseif quota == "Present" then
		present(playerID, slideNum)
	elseif quota == "ClearPresent" then
		ClearPresent()
	end
end)

questionEvent.OnServerInvoke = function(plr : Player, quota : string, data)
	if quota == "Submit" then
		table.insert(playerSlides[plr.UserId], data)
		for i, host in hosts do
			hostEvent:FireAllClients("Update", playerSlides)
		end
		return true
	elseif quota == "Request" then
		if not playerSlides[plr.UserId] then
			playerSlides[plr.UserId] = {}
			for i, host in hosts do
				hostEvent:FireClient(host, "Update", playerSlides)
			end
		end
		return questions
	end
end

presentScreen.Enabled = false
introScreen.Enabled = true
ClearPresent()

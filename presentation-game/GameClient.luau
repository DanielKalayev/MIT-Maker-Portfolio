local jobEvent = game.ReplicatedStorage.Events.JobEvent
local questionEvent = game.ReplicatedStorage.Events.QuestionEvent
local bright = game.Lighting.ColorCorrection

local jobText = script.Parent.TextLabel
local timeText = script.Parent.Timer
local vignette = script.Parent.Vignette

local questionText = script.Parent.QuestionText
local questionNum = script.Parent.QuestionNum

local ts = game:GetService("TweenService")

local writingEvent = game.ReplicatedStorage.Events.WritingEvent
local totalNum = 0
local currentNum = 1

local questions = {}

jobEvent.OnClientEvent:Connect(function(quota, data)
	if quota == "Start" then
		startJob()
	elseif quota == "Host" then
		timeText.Visible = true
	elseif quota == "Timer" then
		if data < 0 then return end
		local minutes = math.floor(data / 60)
		local secs = data % 60
		local textString = string.format("%d:%02d", minutes, secs)
		timeText.Text = textString
		if data <= 30 then
			timeText.TextColor = BrickColor.new(255, 0, 0)
		else
			timeText.TextColor = BrickColor.new(255, 255, 255)
		end

		if data == 30 then
			ts:Create(vignette, TweenInfo.new(29), {ImageTransparency = 0}):Play()
		end
	elseif quota == "Skip" then
		jobText.Visible = true
		jobText.Text = "Host skipped the round."
		task.wait(2)
		jobText.Visible = false
	elseif quota == "End" then
		timeText.TextColor = BrickColor.new(0, 255, 0)
		ts:Create(vignette, TweenInfo.new(1), {ImageTransparency = 1}):Play()
		writingEvent:Fire("Toggle", false)
		questionNum.Visible = false
		questionText.Visible = false
		task.wait(3)
		script.Parent.Enabled = false

	end
end)

function setupQuestion()
	local currentQuestion = questions[currentNum]
	questionNum.Text = "Question ".. tostring(currentNum) .. "/" .. tostring(totalNum)
	questionText.Text = currentQuestion.Question
	writingEvent:Fire("Mode", currentQuestion.Prompt)
end

function startJob()
	local tween = ts:Create(bright, TweenInfo.new(6.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Brightness = 1})
	tween:Play()

	tween.Completed:Once(function()
		task.wait(0.1)

		questions = questionEvent:InvokeServer("Request", currentNum)
		totalNum = #questions
		setupQuestion()

		bright.Brightness = 0
		jobText.Visible = true
		timeText.Visible = true

		questionNum.Visible = true
		questionText.Visible = true

		writingEvent:Fire("Toggle", true)
		task.wait(2)
		jobText.Visible = false
	end)
end

writingEvent.Event:Connect(function(quota, data)
	if quota == "Submit" then
		local result = questionEvent:InvokeServer(quota, data)
		if result then
			writingEvent:Fire("Recieved")
			currentNum += 1
			if currentNum > totalNum then
				writingEvent:Fire("Toggle", false)
				jobText.Visible = true
				questionNum.Visible = false
				questionText.Visible = false
				jobText.Text = "Finished! Wait for others."
				task.wait(2)
				jobText.Visible = false
				return
			end
			setupQuestion()
		end
	end
end)

timeText.Visible = false
questionNum.Visible = false
questionText.Visible = false
script.Parent.Enabled = true

task.spawn(function()
	repeat
		local success = pcall(function() 
			game:GetService("StarterGui"):SetCore("ResetButtonCallback", false)
		end)
		task.wait(1)
	until success
end)

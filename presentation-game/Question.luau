local Question = {}

Question.PromptType = {
	Text = "Text",
	Drawing = "Drawing"
}

Question.new = function(question : string, prompt : string)
	local self = setmetatable({}, {__index = Question})
	
	self.Question = question
	self.Prompt = prompt
	
	return self
end

return Question

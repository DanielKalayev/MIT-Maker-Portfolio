local rs = game:GetService("RunService")

local labelTemplate = script.BillboardGui

local p0 = workspace.P0
local p1 = workspace.P1
local move = workspace.Move
local points = {p0}

local controlFolder = workspace.ControlPoints:GetChildren()

table.sort(controlFolder, function(a, b)
	local numA = tonumber(string.match(a.Name, "%d+")) or 0
	local numB = tonumber(string.match(b.Name, "%d+")) or 0

	return numA < numB
end)

for i, point : Part in controlFolder do
	table.insert(points, point)
	
	local label = labelTemplate:Clone()
	label.Parent = point
	label.TextLabel.Text = i
end

table.insert(points, p1)


local duration = 1

local function getPascalRow(n)
	local row = {1}
	for i = 1, n do
		row[i + 1] = row[i] * (n - i + 1) / i
	end
	return row
end

local n = #points - 1
local coeff = getPascalRow(n)

local function GetCurveAtTime(t)
	local targetPos = Vector3.zero

	for i = 0, n do
		local coef = coeff[i + 1]
		local term = coef * ((1 - t)^(n - i)) * (t^i) * points[i + 1].Position
		targetPos += term
	end
	
	return targetPos
end

function doCurve()
	local t = 0
	
	while true do
		t = 0

		while t < duration do
			
			local pos = GetCurveAtTime(t)
			
			move.Position = pos

			local dt = task.wait()
			t = math.clamp(t + dt, 0, 1)
		end

		task.wait(0.5)

		while t > 0 do

			local pos = GetCurveAtTime(t)

			move.Position = pos

			local dt = task.wait()
			t = math.clamp(t - dt, 0, 1)
		end

		task.wait(0.5)

	end
end

local drawPoints = 15 + (5 * n - 2)

function drawCurve()
	local fold = Instance.new("Folder")
	fold.Parent = workspace

	for i = 1, drawPoints do
		local p = Instance.new("Part")
		p.Name = "Draw" .. i
		p.Size = Vector3.new(1,1,1)
		p.Anchored = true
		p.Color = Color3.new(1,1,0)
		p.Material = Enum.Material.Neon
		p.CastShadow = false
		p.Parent = fold
	end

	rs.Heartbeat:Connect(function()
		local t = 1

		for i, part in fold:GetChildren() do
			local newT = t * (i / drawPoints)
			local pos = GetCurveAtTime(newT)
			part.Position = pos
		end
	end)
end

drawCurve()

task.wait(3)

doCurve()

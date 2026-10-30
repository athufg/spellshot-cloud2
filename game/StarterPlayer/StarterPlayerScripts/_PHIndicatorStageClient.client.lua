-- TEMPORARY pH Indicator checkpoint stage (Claude, 2026-10-20): shot tag + per-side particle rates; remove when wired
task.wait(4)
local g = Instance.new("ScreenGui") g.Name = "_ShotTag" g.IgnoreGuiInset = true g.ResetOnSpawn = false
local f = Instance.new("Frame") f.Size = UDim2.fromOffset(24, 24) f.AnchorPoint = Vector2.new(1, 1) f.Position = UDim2.new(1, -4, 1, -4) f.BorderSizePixel = 0 f.Parent = g
g.Parent = game.Players.LocalPlayer.PlayerGui
game:GetService("RunService"):BindToRenderStep("ShotTag", 2000, function() g.Enabled = true f.BackgroundColor3 = Color3.fromRGB(math.min(255, (workspace:GetAttribute("ShotTag") or 0) * 10), 255, 0) end)
local S = Vector3.new(-90, 0, -45)
local SITES = { [1] = { -8, 2, 7.5 }, [3] = { -3, 3, 2.8 }, [5] = { -6, 0, 5 } }
workspace:GetAttributeChangedSignal("ShotTag"):Connect(function()
	local n = workspace:GetAttribute("ShotTag")
	local site = SITES[n]
	if not site then return end
	local acc = { Default = { 0, 0 }, PH = { 0, 0 } }
	for _ = 1, 15 do                                   -- (15 samples over 1.5 s, both sides each time)
		for side, sx in pairs({ Default = site[1], PH = -site[1] }) do
			local c = S + Vector3.new(sx, 0, site[2])
			for _, e in ipairs(workspace:GetDescendants()) do
				if e:IsA("ParticleEmitter") and e.Enabled and e.Parent:IsA("BasePart") then
					local p = e.Parent.Position
					if Vector2.new(p.X - c.X, p.Z - c.Z).Magnitude < site[3] and p.Y < 14 then
						acc[side][1] += e.Rate / 15
						if e.Name == "PHFizz" then acc[side][2] += e.Rate / 15 end
					end
				end
			end
		end
		task.wait(0.1)
	end
	workspace:SetAttribute("PHRates" .. n, string.format("Default %.1f/s, PH %.1f/s (fizz %.1f) = %+.0f%%", acc.Default[1], acc.PH[1], acc.PH[2], (acc.PH[1] - acc.Default[1]) / math.max(0.01, acc.Default[1]) * 100))
end)
-- the flow probe (attribute PHProbe = Vector3 centre): every frame for 6 s, the colours of the pH cloud's puffs
workspace:GetAttributeChangedSignal("PHProbe"):Connect(function()
	local c0 = workspace:GetAttribute("PHProbe")
	if typeof(c0) ~= "Vector3" then return end
	local parts = {}
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("BasePart") and (d.Position - c0).Magnitude < 7 and (d.Material == Enum.Material.Plaster or d.Material == Enum.Material.Neon or d.Material == Enum.Material.SmoothPlastic) and d.Transparency < 0.95 and d:FindFirstChildOfClass("SpecialMesh") then table.insert(parts, d) end
	end
	local ser, pos = {}, {}
	for i, p in ipairs(parts) do ser[i] = {} pos[i] = p.Position end
	local t0, frames = os.clock(), 0
	local conn
	conn = game:GetService("RunService").RenderStepped:Connect(function()
		frames += 1
		for i, p in ipairs(parts) do local col = p.Color ser[i][frames] = { col.R, col.G, col.B, os.clock() - t0 } end
		if os.clock() - t0 > 6 then
			conn:Disconnect()
			local D = math.sqrt((255 - 70) ^ 2 + (110 - 225) ^ 2 + (80 - 170) ^ 2) / 255
			local fast, step = 0, 0
			for i = 1, #parts do
				local s = ser[i]
				for a = 1, #s - 1 do
					local dx = math.sqrt((s[a + 1][1] - s[a][1]) ^ 2 + (s[a + 1][2] - s[a][2]) ^ 2 + (s[a + 1][3] - s[a][3]) ^ 2) / D
					if dx > step then step = dx end
					for b = a + 1, #s do
						if s[b][4] - s[a][4] >= 1 then
							local d1 = math.sqrt((s[b][1] - s[a][1]) ^ 2 + (s[b][2] - s[a][2]) ^ 2 + (s[b][3] - s[a][3]) ^ 2) / D
							if d1 > fast then fast = d1 end
							break
						end
					end
				end
			end
			local function lum(s, k) return 0.3 * s[k][1] + 0.59 * s[k][2] + 0.11 * s[k][3] end
			local function corr(i, j)
				local n = math.min(#ser[i], #ser[j]) local mx, my = 0, 0
				for k = 1, n do mx += lum(ser[i], k) my += lum(ser[j], k) end mx /= n my /= n
				local sxy, sxx, syy = 0, 0, 0
				for k = 1, n do local a, b = lum(ser[i], k) - mx, lum(ser[j], k) - my sxy += a * b sxx += a * a syy += b * b end
				return (sxx > 0 and syy > 0) and sxy / math.sqrt(sxx * syy) or nil
			end
			local near, far, nn, nf = 0, 0, 0, 0
			for i = 1, #parts do for j = i + 1, #parts do
				local dd = (pos[i] - pos[j]).Magnitude local r = corr(i, j)
				if r then if dd < 3 then near += r nn += 1 elseif dd > 6 then far += r nf += 1 end end
			end end
			workspace:SetAttribute("PHProbeOut", string.format("%d pieces, %d frames: fastest 1-s change %.1f%% of range, max frame step %.2f%%, corr near %.2f (%d) far %.2f (%d)",
				#parts, frames, fast * 100, step * 100, nn > 0 and near / nn or 0, nn, nf > 0 and far / nf or 0, nf))
		end
	end)
end)

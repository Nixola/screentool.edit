print = function(...)
	local t = {...}
	for i, v in ipairs(t) do t[i] = tostring(v) end
	io.stderr:write(table.concat(t, "\t") .. "\n")
end

math.clamp = function(min, x, max)
	return math.max(min > max and max or min, math.min(min > max and min or max, x))
end

math.round = function(x) return math.floor(x + 0.5) end
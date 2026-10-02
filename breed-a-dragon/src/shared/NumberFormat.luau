--!strict
-- Turns big numbers into short text: 1500 -> "1.50K", 2300000 -> "2.30M".

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local NumberFormat = {}

function NumberFormat.Abbreviate(n: number): string
	if n < 0 then
		return "-" .. NumberFormat.Abbreviate(-n)
	end
	if n < 1000 then
		return tostring(math.floor(n))
	end

	local tier = math.min(math.floor(math.log10(n) / 3), #SUFFIXES - 1)
	local value = n / 10 ^ (tier * 3)
	local pattern = if value >= 100 then "%.0f%s" elseif value >= 10 then "%.1f%s" else "%.2f%s"
	return string.format(pattern, value, SUFFIXES[tier + 1])
end

return NumberFormat

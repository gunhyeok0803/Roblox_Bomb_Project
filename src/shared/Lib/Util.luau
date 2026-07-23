--!strict
local Util = {}
function Util.count(dict: { [any]: any }): number
	local n = 0
	for _ in dict do n += 1 end
	return n
end
function Util.weightedPick(list: { any }, getWeight: (any) -> number, rng: Random): any
	local total = 0
	for _, item in list do total += getWeight(item) end
	local r = rng:NextNumber(0, total)
	local acc = 0
	for _, item in list do
		acc += getWeight(item)
		if r <= acc then return item end
	end
	return list[#list]
end
return Util

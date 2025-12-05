-- Aunber's Minecraft Inspired RNG Module

export type LootEntry = {
	name: string?, -- Must be the entry's name or at index [1] in an array;
	weight: number?, -- Must be at index [2] in an array;
	quality: number?, -- Must be at index [3] in an array;
	data: any?, -- Any data sent along with the entry. Indexes must be [>3] in an array;
}

local lootModule = {}

local _defaultRng = Random.new()

local function tblLength( tbl )
	local result = 0
	
	for _, _ in pairs( tbl ) do
		result += 1
	end
	
	return result
end

local function insertValue( tbl, value )
	table.insert( tbl, value ); return value
end

function lootModule.weightChance( lootTable: { LootEntry }, multiplier: number?, receiveRewards: boolean?, weightRng: Random? )
	if receiveRewards == nil then receiveRewards = true end
	
	weightRng = weightRng or _defaultRng
	multiplier = multiplier or 0
	
	local totalWeight = 0
	
	local rewards = {}
	
	for _n, item in pairs( lootTable ) do
		local name = item.name or (typeof(_n) ~= "number" and _n) or item[1]
		assert( typeof( name ) == "string", "The name of a entry must be a string" )
		
		local weight = item.weight or item[2]
		assert( typeof( weight ) == "number", "The weight of a entry must be a number" )
		
		local quality = item.quality or item[3] or 0
		assert( typeof( quality ) == "number", "The quality of a entry must be a number" )
		
		totalWeight += insertValue( rewards, {
			name = name,
			weight = (multiplier ~= 0 and math.floor(weight + quality * multiplier)) or weight,
			value = table.move( item, 4, tblLength(item), 1, {}),
		}).weight
	end

	local searchWeight = (receiveRewards and 0)
	local weightIndex = (receiveRewards and weightRng:NextInteger( 1, totalWeight ))
	
	for _, reward in pairs( rewards ) do
		local weightScaled = (reward.weight / totalWeight) * 100
		
		if receiveRewards then
			searchWeight += reward.weight
			
			if searchWeight >= weightIndex then
				return reward, weightScaled
			end
		else
			reward.weightScaled = weightScaled
		end
	end  
	
	assert( receiveRewards ~= true, "Failed to find a reward" )
	
	return rewards
end

return lootModule

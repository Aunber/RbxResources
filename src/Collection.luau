local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TableUtil = require( ReplicatedStorage.Packages.TableUtil )
local Janitor = require( ReplicatedStorage.Packages.Janitor )
local Signal = require( ReplicatedStorage.Packages.Signal )

type Constructor = { new: ( table: { any }? ) -> Collection }
export type Collection = {
	Size: number,
	Add: typeof(
		function<T>( self: Collection, index: string, value: T, overwrite: boolean? ): T
			return (nil:: T)
		end
	),
	Remove: ( self: Collection, index: string ) -> any?,
}

local _functions = {
	Size = function( self: Collection )
		return #TableUtil.Keys( self._container )
	end,
}

local Collection = { __type = "Collection" }
Collection.__index = function( tbl, index )
	local value = rawget( tbl, index )
	if value then return value end

	if _functions[ index ] then
		return _functions[ index ]( tbl )
	end

	return Collection[ index ]
end

function Collection.new( tbl ): Collection
	local _janitor = Janitor.new()

	local self = setmetatable({
		_container = (tbl and TableUtil.Copy( tbl, true )) or {},

		Updated = _janitor:Add(Signal.new()),
		Added = _janitor:Add(Signal.new()),
		Removed = _janitor:Add(Signal.new()),

		Destroy = _janitor,
	}, Collection )

	_janitor:Add(function()
		table.clear( self._items )
		table.clear( self )

		setmetatable( self, nil )
	end)

	return self
end

function Collection:Add( index, value, overwrite )

end

function Collection:Remove( index )
	if self._container[ index ] then
		local v = self._container[ index ]
		self._container[ index ] = nil

		return v
	end
end

return Collection :: Constructor

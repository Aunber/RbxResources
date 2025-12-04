-- Aunber's input system v2, inspired by Roblox's without instances [ November, 2025 ]
-- Don't ask what happened to v1... We don't speak of v1.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Components = script:WaitForChild("Components")

local InputSystem = {
	_windowFocused = true,
	_menuOpened = false,
	_registry = {},
}

function InputSystem:GameFocused()
	return self._windowFocused and not self._menuOpened
end

export type InputContext = { 
	_sink: boolean,
	_priority: number, 
	_enabled : boolean,
	_actions : { InputAction },

	Enable : ( self: InputContext ) -> (),
	Disable : ( self: InputContext ) -> (),

	AddAction : ( self: InputContext, action: InputAction, name: string? ) -> (),
	RemoveAction: ( self: InputContext, action: InputAction, name: string? ) -> (),

	GetAction : ( self: InputContext, name: string ) -> InputAction,
	GetActions : ( self: InputContext ) -> { InputAction },
	
	Destroy: ( self: InputContext ) -> (),
}

export type InputAction = {
	_enabled: boolean,
	_active : boolean,
	_inputBinds : { InputBinding },
	_functions : { ( inputObject: InputObject, gameProcessedEvent: boolean ) -> () },

	Trigger: ( self: InputAction, ...any ) -> (),

	Enable : ( self: InputAction ) -> (),
	Disable : ( self: InputAction ) -> (),

	AddBinding : ( self: InputAction, binding: InputBinding ) -> (),
	RemoveBinding: ( self: InputAction, binding: InputBinding ) -> (),

	Destroy: ( self: InputAction ) -> (),
}

export type InputBinding = {
	_inputs: { CustomInputTypes },
	_state: Enum.UserInputState,	

	Process: ( inputObject: InputObject, gameProcessedEvent: boolean ) -> boolean,

	Destroy: ( self: InputBinding ) -> (),
}

export type CustomInputTypes = Enum.UserInputType | Enum.KeyCode

local InputContext do
	InputContext = {
		new = function( actions: { InputAction }, priority: number?, sink: boolean? )
			local contextObject = setmetatable({
				_priority = priority or 1000,
				_sink = sink or false,
				_enabled = true,
				_actions = {},
			}, { __index = InputContext }) :: InputContext
			
			if typeof(actions) ~= "table" then
				actions = { actions }
			end
			
			for name, action in pairs( actions ) do
				contextObject:AddAction( action, name )
			end
			
			return contextObject
		end,
		Enable = function( self: InputContext )
			self._enabled = true
		end,
		Disable = function( self: InputContext )
			self._enabled = false
		end,
		AddAction = function( self: InputContext, action: InputAction, name: string )
			self._actions[ name or #self._actions+1 ] = action
			
			for input, registered in pairs( InputSystem._registry ) do
				for _, register in pairs( registered ) do
					if register.action == action then
						register.context = self
					end	
				end
			end
		end,
		RemoveAction = function( self: InputContext, action: InputAction, name: string )
			for input, registered in pairs( InputSystem._registry ) do
				for _, register in pairs( registered ) do
					if register.action == action then
						register.context = nil
					end
				end
			end
			
			if name then self._actions[ name ] = nil; return end

			local index = table.find( self._actions, action )
			if not index then return end

			table.remove( self._actions, index )
		end,
		GetAction = function( self: InputContext, name: string )
			return self._actions[ name ]
		end,
		GetActions = function( self: InputContext )
			return self._actions
		end,
		Destroy = function( self: InputContext )
			for _, action in pairs( self._actions ) do
				self:RemoveAction( action )
			end

			table.clear( self._actions )
			table.clear( self )
			
			return setmetatable( self, nil )
		end,
	}
end

local InputAction do
	InputAction = {
		new = function( inputBinds: { InputBinding }, callback: ( inputObject: InputObject, gameProcessedEvent: boolean ) -> (), enabled: boolean? )
			local actionObject = setmetatable({
				_functions = typeof( callback ) == "table" and callback or { callback },
				_inputBinds =  {},
				_enabled = (enabled ~= nil and enabled) or true,
				_active = false,
			}, { __index = InputAction }) :: InputAction

			if typeof( inputBinds ) ~= "table" then
				inputBinds = { inputBinds }
			end

			for _, binding in pairs( inputBinds ) do
				actionObject:AddBinding( binding )
			end

			return actionObject
		end,
		Trigger = function( self: InputAction, ... )
			if self._active then return end
			self._active = true

			for _, func in pairs( self._functions ) do
				task.spawn( func, ... )
			end

			task.defer(function()
				self._active = false
			end)
		end,
		Enable = function( self: InputAction )
			self._enabled = true
		end,
		Disable = function( self: InputAction )
			self._enabled = false
		end,
		AddBinding = function( self: InputAction, binding )
			table.insert( self._inputBinds, binding )

			for _, input in pairs( binding._inputs ) do
				if not InputSystem._registry[ input ] then 
					InputSystem._registry[ input ] = {} 
				end 

				table.insert( InputSystem._registry[ input ], {
					bind = binding,
					action = self,
				})
			end
		end,
		RemoveBinding = function( self: InputAction, binding )
			local index = table.find( self._inputBinds, binding )
			if not index then return end

			table.remove( self._inputBinds, index )

			for _, input in pairs( binding._inputs ) do
				if not InputSystem._registry[ input ] then 
					continue
				end 
				
				for index, register in pairs(InputSystem._registry[ input ]) do
					if register.bind == binding and register.action == self then
						table.remove(InputSystem._registry[ input ], index)
					end
				end
			end
		end,
		Destroy = function( self: InputAction )
			for _, binding in pairs( self._inputBinds ) do
				self:RemoveBinding( binding )
			end
			
			table.clear( self._inputBinds )
			table.clear( self._functions )
			table.clear( self )

			return setmetatable( self, nil )
		end,
	}
end

local InputBinding do
	InputBinding = {
		new = function( inputs: CustomInputTypes|{ CustomInputTypes }, inputState: Enum.UserInputState )
			local bindObject = setmetatable({
				_inputs = typeof( inputs ) == "table" and inputs or { inputs },
				_state = inputState or Enum.UserInputState.Begin,
			}, { __index = InputBinding }) :: InputBinding
			
			return bindObject
		end,
		Process = function( self: InputBinding, inputObject: InputObject, gameProcessedEvent: boolean )
			if inputObject.KeyCode and table.find( self._inputs, inputObject.KeyCode ) then
				if inputObject.UserInputState == self._state then
					return true
				end
			end

			return false
		end,
		Destroy = function( self: InputBinding )
			for _, input in pairs( self._inputs ) do
				if not InputSystem._registry[ input ] then 
					continue
				end
				
				for index, register in pairs(InputSystem._registry[ input ]) do
					if register.bind == self then
						InputSystem._registry[ input ][ index ] = nil
					end
				end
			end
			
			table.clear( self._inputs )
			table.clear( self )

			return setmetatable( self, nil )
		end,
	}
end

function InputSystem.inputProcess( inputObject: InputObject, gameProcessedEvent: boolean )
	local inputState = inputObject.UserInputState

	local contextQueue = {}
	local activeContexts = {}

	local function insertQueue( entry )
		local context = entry.context
		if not context._enabled then return end

		if not activeContexts[ context ] then
			activeContexts[ context ] = { ref = context, entries = {} }
			table.insert( contextQueue, activeContexts[ context ] )
		end

		table.insert( activeContexts[ context ].entries, entry )
	end

	local inputRegistry = InputSystem._registry[ inputObject.KeyCode ] or InputSystem._registry[ inputObject.UserInputType ]
	
	if inputRegistry then
		if #inputRegistry <= 0 then
			InputSystem._registry[ inputObject.KeyCode ] = nil; 
			InputSystem._registry[ inputObject.UserInputType ] = nil;
			
			return
		end

		for _, entry in pairs( inputRegistry ) do
			local shouldProcess = entry.bind:Process( inputObject, gameProcessedEvent )

			if shouldProcess then
				if not entry.action._enabled then continue end
				
				if entry.context then
					insertQueue( entry); continue
				end

				entry.action:Trigger( inputObject, gameProcessedEvent )
			end
		end
	end

	table.sort( contextQueue, function( a, b )
		return a.ref._priority > b.ref._priority 
	end)

	for _, contextEntry in pairs( contextQueue ) do
		for _, entry in pairs( contextEntry.entries ) do
			entry.action:Trigger( inputObject, gameProcessedEvent )
		end

		if contextEntry.ref._sink then
			break
		end
	end
end

InputSystem.createContext = InputContext.new
InputSystem.createAction = InputAction.new
InputSystem.createBinding =  InputBinding.new
InputSystem.createBindingPair = function( inputs: CustomInputTypes|{ CustomInputTypes } )
	return {
		InputSystem.createBinding( inputs, Enum.UserInputState.Begin ),
		InputSystem.createBinding( inputs, Enum.UserInputState.End ),
	}
end

UserInputService.WindowFocused:Connect(function()
	InputSystem._windowFocused = true
end)

UserInputService.WindowFocusReleased:Connect(function()
	InputSystem._windowFocused = false
end)

GuiService.MenuOpened:Connect(function()
	InputSystem._menuOpened = true
end)

GuiService.MenuClosed:Connect(function()
	InputSystem._menuOpened = false
end)

UserInputService.InputBegan:Connect( InputSystem.inputProcess )
UserInputService.InputEnded:Connect( InputSystem.inputProcess )

return InputSystem

--[[ 
CONFIGURACIÓN DE GENERACIÓN DE MAPA. UBICAR EN UN MODULE SCRIPT COMO HIJO DE MAIN
]]

local a = {
	RootRooms = {
		Types = {"T", "+"},
		Templates = {}
	},
	CorridorRooms = {
		Types = {"I", "I2"},
		Templates = {}
	},
	CornerRooms = {
		Types = {"L", "L2"},
		Templates = {}
	},
	EndRooms = {
		Types = {"End"},
		Templates = {}
	},
	StartRooms = {
		Types = {"Start"},
		Templates = {}
	},
}

module = {
	Rooms = require(script.Parent.Rooms),

	CORRIDOR_LENGHT = NumberRange.new(1, 8),
	MAX_BRANCHES = 15,

	SPAWNPOS = CFrame.new(0, 30,0),

	roomGenerationTag = "Rooms"
}

return module
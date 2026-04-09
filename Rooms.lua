--[[ 
CONFIGURACIÓN DE TIPOS DE HABITACIONES. UBICAR EN UN MODULE SCRIPT COMO HIJO DE MAIN
]]

local Rooms = {
	{
		Family = "Root", 
		Type = "T",
		Templates = {}
	},
	{
		Family = "Root", 
		Type = "+",
		Templates = {}
	},
	{
		Family = "Corridor", 
		Type = "I",
		Templates = {}
	},
	{
		Family = "Corridor", 
		Type = "I2",
		RepRestriction = true,
		Templates = {}
	},
	{
		Family = "Corner", 
		Type = "L",
		RepRestriction = true,
		Templates = {}
	},
	{
		Family = "End", 
		Type = "E",
		Templates = {}
	},
	{
		Family = "Spawn", 
		Type = "S",
		Templates = {}
	},
	{
		Family = "Walls", 
		Type = "W",
		Templates = {}
	},
	{
		Family = "Habitation", 
		Type = "H",
		Templates = {}
	},
}

return Rooms
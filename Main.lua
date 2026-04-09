--[[ 
UBICAR EN UN SERVER SCRIPT
]]

local COLLECTION_SV = game:GetService("CollectionService")
local InsertService = game:GetService("InsertService")
debug_mode = true -- Activar para depuración

-- Funciones auxiliares
local FUNCTIONS = require(script.Functions)
searchForFolder = FUNCTIONS.searchForFolder
searchRootModel = FUNCTIONS.searchRootModel
chooseRandomTemplate = FUNCTIONS.chooseRandomTemplate
connectRooms = FUNCTIONS.connectRooms
subtractArrays = FUNCTIONS.subtractArrays
getOverlappingRooms = FUNCTIONS.getOverlappingRooms
getRoomsByFamily = FUNCTIONS.getRoomsByFamily
generateTemplates = FUNCTIONS.generateTemplates

-- Variables globales
local mapFolder = script.Parent
local generation_folder = (mapFolder.Generation) and mapFolder.Generation or Instance.new("Folder", mapFolder)
generation_folder.Name = "Generation"

local templates_folder = mapFolder:WaitForChild("Templates", 5) -- Carpeta de plantillas
if not templates_folder then warn("No encuentro la carpeta de plantillas (Templates). Verifica que exista dentro de mapFolder (Donde está almacenado este script.") end

-- Configuración
local CONFIG = require(script.Configuration)
Rooms = CONFIG.Rooms
CORRIDOR_LENGHT = CONFIG.CORRIDOR_LENGHT
MAX_BRANCHES = CONFIG.MAX_BRANCHES
SPAWNPOS = CONFIG.SPAWNPOS
roomGenerationTag = CONFIG.roomGenerationTag
-- Generación
rootsGenerated = {}
connectionQueue = {}

-- --- TEMPLATE SETUP ---
local function configureAttach(roomTemplate)
	local foundAttach = false
	for _, part in pairs(roomTemplate:GetDescendants()) do
		if part:IsA("BasePart") and (part.Name == "In" or part.Name == "Out") then
			local attach = part:FindFirstChildWhichIsA("Attachment")
			if attach then
				foundAttach = true
				part.Transparency = 1
				part.CanCollide = false
			end
		end
	end
	return foundAttach
end
for _, roomTypeFolder in pairs(templates_folder:GetChildren()) do
	if not roomTypeFolder:IsA("Folder") then continue end
	for _, roomTemplate in pairs(roomTypeFolder:GetChildren()) do
		if not roomTemplate:IsA("Model") or not roomTemplate:GetAttribute("Type") then continue end
		local templateType = roomTemplate:GetAttribute("Type")
		local foundAttach = configureAttach(roomTemplate)

		if foundAttach then
			for _, roomTable in pairs(Rooms) do
				if roomTable.Type == templateType then
					table.insert(roomTable.Templates, roomTemplate)
					break
				end
			end
		else
			warn("⚠️ Mal configurada: ", roomTemplate:GetFullName())
		end

		local decorationsModel = roomTemplate:FindFirstChild("Decorations", true)
		if decorationsModel and (decorationsModel:IsA("Model") or decorationsModel:IsA("Folder")) then
			for i,object in pairs(decorationsModel:GetDescendants()) do
				if not object:IsA("BasePart") then continue end
				object.CanCollide = false
				object.CanQuery = false
				object.CanTouch = false
			end
		end
	end	
end


-- Función para generar un corredor
function generateCorridor(rootAttach)
	local validRooms = {
		table.unpack(getRoomsByFamily("Corridor")),
		table.unpack(getRoomsByFamily("Corner")),
		table.unpack(getRoomsByFamily("Habitation"))
	}	
	if #validRooms == 0 then warn("ERROR: Corridor can't be generated. 0 rooms found for selection.") return nil end

	local forceTypeForNextRoom = nil
	local corridorsPlaced = {}
	local corridorLarge = math.random(CORRIDOR_LENGHT.Min, CORRIDOR_LENGHT.Max)

	local rootFolder = searchForFolder(rootAttach)
	local currentAttach = rootAttach
	local corridorFolder = Instance.new("Folder")
	corridorFolder.Parent = (rootFolder) and rootFolder or generation_folder
	corridorFolder.Name = "Corridor"

	for corridorIndex=1, corridorLarge do
		local prevRoomType = #corridorsPlaced > 0 and corridorsPlaced[#corridorsPlaced]:GetAttribute("Type")
		local chosenTemplate = chooseRandomTemplate(validRooms, prevRoomType)

		local newCorridor = chosenTemplate:Clone()				
		newCorridor.Parent = corridorFolder
		newCorridor.Name = ("Section "..tostring(corridorIndex).."-"..tostring(newCorridor:GetAttribute("Type")))

		connectRooms(newCorridor, currentAttach)

		if debug_mode then task.wait(1/4) end
		if #getOverlappingRooms(newCorridor) > 0 then
			forceTypeForNextRoom = "T"
			if debug_mode then task.wait(3) end
			newCorridor:Destroy()
			--print("Overlapping corridor detected and fixed.")
			break
		else
			table.insert(corridorsPlaced, newCorridor)
			COLLECTION_SV:AddTag(newCorridor, roomGenerationTag)

			local nextAttach = newCorridor:FindFirstChild("Out", true):FindFirstChildWhichIsA("Attachment")

			if not nextAttach then break end
			currentAttach = nextAttach
		end		
	end

	return {currentAttach, forceTypeForNextRoom}
end


-- Función para generar paredes. Finales de camino óptimos
function generateWall(connection)
	local wallRooms = getRoomsByFamily("Walls")
	if #wallRooms == 0 then warn("Wall generation error: No walls found.") return end

	local chosenWall = wallRooms[math.random(1, #wallRooms)]
	local wallTemplates = chosenWall.Templates
	if #wallTemplates == 0 then warn("Wall generation error: No wall-templates found.") return end

	local newWall = wallTemplates[math.random(1, #wallTemplates)]:Clone()
	local rootFolder = searchForFolder(connection)
	newWall.Parent = rootFolder or generation_folder
	connectRooms(newWall, connection)
	return newWall
end


-- Función para generar la habitación raíz (simplificada)
function generateRoot(connectionAttach, forceType)
	local RootroomTemplates = getRoomsByFamily("Root")
	if #RootroomTemplates == 0 then warn("⚠️ Error de generación: Sin templates Root.") return nil end

	local newRootTemplate = (forceType) and
		chooseRandomTemplate(RootroomTemplates, nil, forceType) or
		chooseRandomTemplate(RootroomTemplates)	
	local newRoot = newRootTemplate:Clone()
	table.insert(rootsGenerated, newRoot)
	COLLECTION_SV:AddTag(newRoot, roomGenerationTag)

	local rootType = newRoot:GetAttribute("Type")
	local rootFolder = Instance.new("Folder", generation_folder)
	rootFolder.Name = ("Root_".. tostring(#rootsGenerated) .. "_".. rootType)
	newRoot.Parent = rootFolder

	if connectionAttach then
		connectRooms(newRoot, connectionAttach)
	else
		newRoot:PivotTo(SPAWNPOS)
	end

	if #getOverlappingRooms(newRoot) > 0 then
		newRoot:Destroy()
		generateWall(connectionAttach)
		--print("Overlapping root detected and fixed.")
		return {}
	end

	-- Recoger TODAS las salidas de esta nueva Raíz y devolverlas para la cola
	local rootOutputs = {}
	for _, outAttach in pairs(newRoot:GetDescendants()) do
		if outAttach:IsA("Attachment") and outAttach.Parent.Name == "Out" then
			table.insert(rootOutputs, outAttach)
		end
	end
	return rootOutputs -- Devuelve las salidas para la cola
end


-- Función para generar endRoom
local function GenerateEndRoom(connectionAttach)
	local endRooms = getRoomsByFamily("End")
	local endTemplate = (#endRooms > 0) and
		chooseRandomTemplate(endRooms) or nil
	if endTemplate then
		local rootFolder = searchForFolder(connectionAttach)
		local endRoomGenerated = endTemplate:Clone()
		endRoomGenerated.Parent = (rootFolder) and rootFolder or generation_folder
		connectRooms(endRoomGenerated, connectionAttach)
		return endRoomGenerated
	else return nil		
	end
end


-- Función para generar spawnRoom
function generateSpawnRoom(connection)
	local spawnRooms = getRoomsByFamily("Spawn")

	local startTemplate = (#spawnRooms > 0) and
		chooseRandomTemplate(spawnRooms) or nil
	if not startTemplate then return {} end

	-- Primera habitación generada
	local spawnRoom = startTemplate:Clone()
	spawnRoom.Parent = generation_folder
	COLLECTION_SV:AddTag(spawnRoom, roomGenerationTag)

	if typeof(connection) == "Instance" then
		connectRooms(spawnRoom, connection)
	else
		--print("'connection' no es un Attachment válido. Usando SpawnPOS.")
		spawnRoom:PivotTo(SPAWNPOS)
	end

	local spawnPoint = spawnRoom:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawnPoint then spawnPoint.Enabled = true end

	for i,instance in pairs(spawnRoom:GetDescendants()) do
		if not table.find(instance:GetTags(), "Beds") then continue end
		local bed = instance
		if bed:GetAttribute("Occupied") then bed:SetAttribute("Occupied", false) end
	end

	-- Verificar si la sala tiene una salida 'Out' válida
	local outAttach = spawnRoom:FindFirstChild("Out", true):FindFirstChildWhichIsA("Attachment")
	return {spawnRoom, outAttach}
end


-- 1. Generar el spawn
MAX_START_RETRIES = 10
local currentAttempt = 0
repeat currentAttempt += 1
	print("Intento de Inicio #" .. currentAttempt .. "/" .. MAX_START_RETRIES .. "...")

	local firstRoom, roomAttach = table.unpack(generateSpawnRoom())
	if not firstRoom then
		warn("Intento #" .. currentAttempt .. ": No se encontró una plantilla 'Start' válida. Reintentando...")
		task.wait(0.5)
		continue -- Pasa al siguiente intento del bucle 'repeat'
	end	

	if roomAttach then
		-- Éxito: La sala es válida
		table.insert(connectionQueue, roomAttach)
		print("Inicio generado con éxito en el intento #" .. currentAttempt .. ".")
		break
	else
		-- Fallo: La sala no tiene salida 'Out'
		warn("Intento #" .. currentAttempt .. ": La sala inicial no tiene una salida 'Out'. Reintentando...")
		firstRoom:Destroy() 
		task.wait(0.5)
	end	
until currentAttempt >= MAX_START_RETRIES
if currentAttempt >= MAX_START_RETRIES then 
	warn("ERROR CRÍTICO: Falló la generación de la habitación inicial después de " .. MAX_START_RETRIES .. " intentos. Abortando la generación.")
end


task.wait(2)
-- 2. Bucle principal basado en la cola
while #rootsGenerated < MAX_BRANCHES and #connectionQueue > 0 do
	local branchesToProcess = connectionQueue -- Las conexiones antiguas
	local newOutputsGenerated = {} -- ALMACENA SOLO LAS NUEVAS SALIDAS GENERADAS EN ESTE CICLO
	local processedBranches = {}     -- ALMACENA SOLO LAS RAMAS ANTIGUAS QUE FUERON USADAS

	-- Importante: Vaciamos la cola global para reconstruirla
	connectionQueue = {} 
	local generationStopped = false

	for _, prevAttach in pairs(branchesToProcess) do
		if #rootsGenerated >= MAX_BRANCHES then
			generationStopped = true
			break -- Detiene el bucle for interno inmediatamente
		end

		-- Marcar la rama como USADA
		table.insert(processedBranches, prevAttach)

		if debug_mode then task.wait(1) end
		local corridorResult = generateCorridor(prevAttach)
		local nextConnectionPoint = corridorResult[1]
		local rootForceType = corridorResult[2]
		local rootOutputs  = generateRoot(nextConnectionPoint, rootForceType)

		-- Las salidas de la nueva Root van a la cola temporal de salidas nuevas
		for _, outAttach in pairs(rootOutputs) do
			table.insert(newOutputsGenerated, outAttach)
		end
	end

	-- RECONSTRUCCIÓN DE LA COLA GLOBAL
	-- 1. Añadir siempre las salidas NUEVAS
	for _, attach in pairs(newOutputsGenerated) do
		table.insert(connectionQueue, attach)
	end
	-- 2. Manejo de las ramas NO utilizadas para la FASE DE CIERRE
	if generationStopped then
		-- Las ramas no utilizadas = (Todas las antiguas) MENOS (Las que usamos)
		local unusedBranches = subtractArrays(branchesToProcess, processedBranches)

		-- Añadimos las ramas restantes a la cola para que la FASE DE CIERRE las use
		for _, attach in pairs(unusedBranches) do
			table.insert(connectionQueue, attach)
		end
		-- Salimos del while loop
		break
	end
end


-- 3. Creamos los spawn restantes y conectamos a un end las salidas restantes
local players = game.Players:GetPlayers()
for i = 1, math.min(#players -1, #connectionQueue) do
	local randomPos = math.random(1, #connectionQueue)
	local conn = connectionQueue[randomPos]
	generateSpawnRoom(conn)
	table.remove(connectionQueue, randomPos)
end
for _, connection in pairs(connectionQueue) do
	if not connection or not connection.Parent then continue end

	local endRoom = GenerateEndRoom(connection)
	if not endRoom then continue end

	if #getOverlappingRooms(endRoom) > 0 then		
		endRoom:Destroy()
		local newWall = generateWall(connection)
		COLLECTION_SV:AddTag(newWall, roomGenerationTag)
	else
		COLLECTION_SV:AddTag(endRoom, roomGenerationTag)
	end
end
table.clear(connectionQueue)


-- 4. Final.
mapFolder:SetAttribute("Generated", true)
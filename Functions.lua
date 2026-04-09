--[[ 
UBICAR EN UN MODULE SCRIPT COMO HIJO DE MAIN
]]

local CONFIG = require(script.Parent.Configuration)
local COLLECTION_SV = game:GetService("CollectionService")

local utils = {
	-- Restar arrays
	subtractArrays = function(arrayA, arrayB)
		-- 1. Crear un 'Hash Set' (Tabla de búsqueda) con los elementos de B
		local lookupB = {}
		-- Usamos ipairs porque las tablas de Attachments son indexadas numéricamente
		for _, elementB in ipairs(arrayB) do
			-- Usar la referencia del Attachment como clave es rápido (O(1) look-up)
			lookupB[elementB] = true 
		end

		-- 2. Recorrer A e incluir solo los que NO están en el Hash Set
		local resultArray = {}

		for _, elementA in ipairs(arrayA) do
			-- Si el elemento de A NO existe como clave en lookupB (es decir, es nil),
			-- significa que es único de A.
			if lookupB[elementA] == nil then
				table.insert(resultArray, elementA)
			end
		end
		return resultArray
	end,
	
	-- Función para encontrar el folder padre de un modelo
	searchForFolder = function(descendant, max_try)
		local current = descendant
		local try = 1
		max_try = max_try or 5
		while current and try < max_try do
			if current:IsA("Folder") then
				return current
			end
			current = current.Parent
			try += 1
		end
		return nil
	end,
	
	-- Subimos la jerarquía para encontrar el MODELO DE RAÍZ etiquetado ("Rooms")
	searchRootModel = function(descendant)
		local roomGenerationTag = CONFIG.roomGenerationTag
		local current = descendant
		while current and current.Parent ~= nil and current ~= workspace do
			if COLLECTION_SV:HasTag(current, roomGenerationTag) then
				return current
			end
			current = current.Parent
		end
	end,
	
	-- Devolver rooms agrupadas por familia
	getRoomsByFamily = function(objectiveFamily: string)
		local Rooms = CONFIG.Rooms
		local grouped = {}
		for i, roomTable in ipairs(Rooms) do
			if roomTable.Family and roomTable.Family == objectiveFamily then
				table.insert(grouped, roomTable)
			end
		end
		return grouped
	end,	
	
	-- Seleccionar una room con probabilidad
	pickProbabilityTemplate = function(templatesTable)
		local totalProb = 0
		local probs = {}  -- tabla auxiliar para guardar las probabilidades por template

		-- Calcular probabilidades
		for _, template in ipairs(templatesTable) do
			local probAttribute = template:GetAttribute("Probability")

			if not probAttribute then
				print(template:GetFullName() .. " has no probability configured. Using default probability...")
			end

			local num = (probAttribute) and probAttribute.Min or 0
			local den = (probAttribute) and probAttribute.Max or 1
			local prob = num / den

			probs[template] = prob
			totalProb += prob
		end

		if totalProb <= 0 then
			--print("No valid probabilities found in templatesTable.")
			return nil
		end

		-- Elegir un número aleatorio entre 0 y el total
		local pick = math.random() * totalProb
		local accumulated = 0

		-- Buscar qué template le corresponde
		for _, template in ipairs(templatesTable) do
			local prob = probs[template]
			if prob then
				accumulated += prob
				if pick <= accumulated then
					return template
				end
			end
		end

		-- Si nada coincidió por redondeo
		return templatesTable[math.random(1, #templatesTable)]
	end,
	
	mirrorModel = function(modelToMirror, mirrorAxis: string, deleteNormal: boolean)
		mirrorAxis = (mirrorAxis) and mirrorAxis or "X"
		local mirrorOrigin = modelToMirror:GetPivot() -- punto de referencia del espejo

		-- Crear una copia
		local mirrored = modelToMirror:Clone()
		mirrored.Name = modelToMirror.Name .. "_Mirrored"

		-- Calcular la matriz de transformación para reflejar
		local pivotCFrame = mirrored:GetPivot()
		local offset = mirrorOrigin.Position

		-- Recorre todas las partes
		for _, part in ipairs(mirrored:GetDescendants()) do
			if part:IsA("BasePart") then
				local relativePos = pivotCFrame:PointToObjectSpace(part.Position)
				local mirroredPos

				if mirrorAxis == "X" then
					mirroredPos = Vector3.new(-relativePos.X, relativePos.Y, relativePos.Z)
				elseif mirrorAxis == "Y" then
					mirroredPos = Vector3.new(relativePos.X, -relativePos.Y, relativePos.Z)
				elseif mirrorAxis == "Z" then
					mirroredPos = Vector3.new(relativePos.X, relativePos.Y, -relativePos.Z)
				end

				part.Position = pivotCFrame:PointToWorldSpace(mirroredPos)

				-- Reflejar orientación
				local look = part.CFrame.LookVector
				local up = part.CFrame.UpVector

				if mirrorAxis == "X" then
					look = Vector3.new(-look.X, look.Y, look.Z)
					up = Vector3.new(-up.X, up.Y, up.Z)
				elseif mirrorAxis == "Y" then
					look = Vector3.new(look.X, -look.Y, up.Z)
					up = Vector3.new(up.X, -up.Y, up.Z)
				elseif mirrorAxis == "Z" then
					look = Vector3.new(look.X, look.Y, -look.Z)
					up = Vector3.new(up.X, up.Y, -up.Z)
				end

				part.CFrame = CFrame.lookAt(part.Position, part.Position + look, up)
			end
		end

		if deleteNormal then modelToMirror:Destroy() end
		return mirrored
	end,		
}

local module = {
	-- Función para elegir plantilla (Ahora acepta forceType como tercer parámetro)
	chooseRandomTemplate = function(roomsTables, prevRoomType, forceType)
		local MAX_ATTEMPTS = 100 -- Establecer un límite de seguridad
		local attempts = 0
		
		if #roomsTables == 0 then warn("No rooms available for selection!") return nil end		
		local availableTemplates = {}
		for i=1, #roomsTables do
			local actualroomTemplates = roomsTables[i].Templates
			if not actualroomTemplates then continue end
			for _, template in ipairs(actualroomTemplates) do
				table.insert(availableTemplates, template)
			end
		end
		if #availableTemplates == 0 then warn("No templates available for selection!") return nil end	
		
		local chosenTemplate
		repeat attempts +=	1
			chosenTemplate = utils.pickProbabilityTemplate(availableTemplates)
			if not chosenTemplate then
				local chosenRoom = roomsTables[math.random(1, #roomsTables)]
				chosenTemplate = chosenRoom.Templates[math.random(1, #chosenRoom.Templates)]
			end
			if not chosenTemplate then 
				print("FATAL ERROR: No templates selected with probability or random generation. Re-Trying...") 
				continue 
			end
			
			local newRoomType = chosenTemplate:GetAttribute("Type")
			local repRestriction = chosenTemplate:GetAttribute("RepRestriction")			

			local mirrorTemplate = math.random(1, 10)
			if mirrorTemplate == 1 and newRoomType ~= "S" then
				--chosenTemplate = utils.mirrorModel(chosenTemplate, "X")
			end
			
			if newRoomType then
				-- 1. RESTRICCIÓN DE TIPO FORZADO
				if forceType and newRoomType ~= forceType then
					continue -- No es el tipo que queremos forzar, busca de nuevo.
				end

				-- 2. RESTRICCIÓN DE REPETICIÓN
				if repRestriction and prevRoomType and newRoomType == prevRoomType then
					continue -- No cumple la restricción de repetición, busca de nuevo.
				end
			end

			-- 3. Si se pasa todas las restricciones, se selecciona la plantilla
			return chosenTemplate
		until attempts >= MAX_ATTEMPTS

		-- Si el código llega aquí, el 'MAX_ATTEMPTS' debería haber capturado el problema.
		warn("Could not find a valid room template! (Fallback)")
		return nil
	end,
	
	
	-- Conectar 2 rooms entre sí
	connectRooms = function(newRoom, connectionAttach)
		local Y_180_ROTATION = CFrame.Angles(0, math.pi, 0)
		local newInpart = newRoom:FindFirstChild("In", true)
		local newIn = (newInpart) and newInpart:FindFirstChildWhichIsA("Attachment")
		if not newIn then print("Room "..newRoom:GetFullName().." lacks 'In' attachment! Trying with and 'Out' one")
			local newOutPart = newRoom:FindFirstChild("Out", true)
			local newOut = (newOutPart) and newOutPart:FindFirstChildWhichIsA("Attachment")
			if not newOut then warn("Room "..newRoom:GetFullName().." lacks 'Out' attachment too! Aborting...") 
				return 
			else
				newIn = newOut
			end
		end

		local newRoomOriginalCFrame = newRoom:GetPivot()
		local CFrame_OutA = connectionAttach.WorldCFrame
		local CFrame_InB_Local = newRoomOriginalCFrame:Inverse() * newIn.WorldCFrame
		local CFrame_Transform = CFrame_OutA * Y_180_ROTATION * CFrame_InB_Local:Inverse()
		newRoom:PivotTo(CFrame_Transform)
		
		local connectionIndicatorIn = Instance.new("ObjectValue", newIn)
		connectionIndicatorIn.Name = "ConnectedRoom"
		connectionIndicatorIn.Value = connectionAttach
	end,
	
	
	-- Utilidades
	searchForFolder = utils.searchForFolder,
	searchRootModel = utils.searchRootModel,
	getRoomsByFamily = utils.getRoomsByFamily,
	subtractArrays = utils.subtractArrays,
	mirrorModel = utils.mirrorModel,

	
	getOverlappingRooms = function(currentRoom)
		local foundOverlaps = {}
		local overlapSet = {}

		-- 2. Obtener todas las partes que tocan el volumen
		for i,roomPart in pairs(currentRoom:GetDescendants()) do
			if not roomPart:IsA("BasePart") or not roomPart.CanCollide then continue end
			local partsInVolume = roomPart:GetTouchingParts() -- Obtener todas las partes que tocan la pieza actual
			
			-- 3. Filtrar los resultados
			for _, overlappingPart in pairs(partsInVolume) do
				if overlappingPart:IsDescendantOf(currentRoom) then continue end

				-- Subimos la jerarquía para encontrar el MODELO DE RAÍZ etiquetado ("Rooms")
				local collidingRootModel = utils.searchRootModel(overlappingPart)

				-- 4. Si encontramos un Modelo de Raíz válido que NO es el actual:
				if collidingRootModel and collidingRootModel ~= currentRoom then

					-- Verificar si el modelo de Root ya está en nuestro Set
					if not overlapSet[collidingRootModel] then
						-- Si no está, lo añadimos a la lista de resultados y al Set
						table.insert(foundOverlaps, collidingRootModel)

						-- Usamos el objeto (Model) como clave para marcarlo como 'visto'
						overlapSet[collidingRootModel] = true 
					end
				end
			end
			
		end
		return foundOverlaps
	end,
}

return module
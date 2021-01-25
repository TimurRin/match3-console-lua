-- DEV_MODE = true
GRID_SIZE = {x = 9, y = 9} -- поле 10х10; в ТЗ указаны значения координат поля с 0 (в луа индексы таблиц начинаются с 1), для оптимизации (недопуска в коде бессмысленных убавлений вида "GRID_SIZE.x - 1") отминусуем единичку прямо здесь. Разумеется можно "сдвигать" на -1 введённую координату при вводе команды на сдвиг кристалла, но может запутать при дебаге (особенно на крупных проектах)
crystals = {"A", "B", "C", "D", "E", "F"} -- варианты графического отображения кристаллов

neighbours = {
	{direction = "u", y = -1, check = {{y = 2}, {x = -1, y = 1}, {x = 1, y = 1}}, target = {y = 1}},
	{direction = "r", x = 1, check = {{x = -2}, {x = -1, y = -1}, {x = -1, y = 1}}, target = {x = -1}},
	{direction = "d", y = 1, check = {{y = -2}, {x = -1, y = -1}, {x = 1, y = -1}}, target = {y = -1}},
	{direction = "l", x = -1, check = {{x = 2}, {x = 1, y = -1}, {x = 1, y = 1}}, target = {x = 1}},
}

moveDirections = {}
for _index, _neighboursData in ipairs(neighbours) do
	moveDirections[_neighboursData.direction] = _neighboursData
end

moveCount = 0 -- количество ходов
tickCount = 0 -- количество действий поля

function init() -- создание поля
	grid = {} -- в каждой клетке поля будет указан индекс, ссылающийся на таблицу crystals
	matches = {} -- готовые для удаления комбинации
	possibleMatches = {} -- возможные комбинации

	mix() -- выставляем кристаллы
end

function tick() -- выполнение действий на поле
	tickCount = tickCount + 1
	if DEV_MODE then
		io.write(string.format("\n==========================================\n[Tick %d]\n==========================================\n", tickCount))
	end

	tickPossibleMatches()
	if #possibleMatches == 0 then
		mix()
		tick()
		return
	end

	-- ищем комбинации

	matches = {} -- обнуляем таблицу с комбинациями

	-- проверяем допустимые комбинации по осям
	tickMatchCheckGrid("x")
	tickMatchCheckGrid("y")

	if tickClearMatches() then
		tickGravity()
		mix(true)
		tick()
	end
end

function tickPossibleMatches()
	possibleMatches = {}
	possibleMatchesInteract = {}

	for _y = 0, GRID_SIZE.y do
		for _x = 0, GRID_SIZE.x do
			local _cell = "x" .. _x .. "y" .. _y
			local _crystalID = grid[_cell]
			for _index, _directionData in ipairs(neighbours) do
				local _directionTargetCell = "x" .. (_x + (_directionData.target.x or 0)) .. "y" .. (_y + (_directionData.target.y or 0))

				local _directionCell = "x" .. (_x + (_directionData.x or 0)) .. "y" .. (_y + (_directionData.y or 0))
				local _directionCrystalID = grid[_directionCell]
				if _crystalID == _directionCrystalID then
					for _index2, _directionCheckData in ipairs(_directionData.check) do
						local _directionCheckCell = "x" .. (_x + (_directionCheckData.x or 0)) .. "y" .. (_y + (_directionCheckData.y or 0))
						local _directionCheckCrystalID = grid[_directionCheckCell]
						if _crystalID == _directionCheckCrystalID then
							possibleMatches[#possibleMatches+1] = {crystalID = _crystalID, cells = {_cell, _directionCell, _directionCheckCell}}
							if not possibleMatchesInteract[_directionCheckCell] then possibleMatchesInteract[_directionCheckCell] = {} end
							if not possibleMatchesInteract[_directionTargetCell] then possibleMatchesInteract[_directionTargetCell] = {} end
							possibleMatchesInteract[_directionCheckCell][_crystalID] = true
							possibleMatchesInteract[_directionTargetCell][_crystalID] = true
						end
					end
				end
			end
		end
	end
end

function tickMatchCheckGrid(_typeA) -- проверка игрового поля на комбинации. функция необходима для недопуска повторения похожего кода, т.к. нам нужно последовательно проверить слева-справа и сверху-вниз
	local _typeB = _typeA == "y" and "x" or "y"
	for _a = 0, GRID_SIZE[_typeA] do
		local _params = {type = _typeA, crystalID = nil}

		for _b = 0, GRID_SIZE[_typeB] do
			local _cell = "x" .. (_typeA == "y" and _b or _a) .. "y" .. (_typeA == "y" and _a or _b)
			tickMatchCheckCell(_cell, _params)
		end

		if matches[#matches] and (#matches[#matches] < 3) then
			matches[#matches] = nil
		end
	end
end

function tickMatchCheckCell(_cell, _params) -- последовательная проверка каждой клетки оси вынесено в отдельную функцию для наглядности
	local _crystalID = grid[_cell]
	local _match = #matches
	if not _crystalID or _params.crystalID ~= _crystalID then
		if _match == 0 then
			_match = 1
		elseif matches[_match] and #matches[_match] >= 3 then
			_match = #matches + 1
		end
		_params.crystalID = _crystalID
		matches[_match] = {}
	end
	matches[_match][#matches[_match]+1] = _cell
	-- if (DEV_MODE or not isSilentTick) and #matches[_match] >= 3 then
		-- print(string.format("It's a match! %s %s: crystal %s match-%d", _params.type, _cell, crystals[_crystalID], #matches[_match]))
	-- end
end

function tickClearMatches()
	local _changes

	local _superCrystalCheck = {}

	if (DEV_MODE or not isSilentTick) and #matches > 0 then print(string.format("\nFound %d match(es)", #matches)) end

	for _index, _matchCell in ipairs(matches) do
		if DEV_MODE or not isSilentTick then
			print(string.format("Match %d: crystal %s match-%d", _index, grid[_matchCell[1]] and crystals[grid[_matchCell[1]]] or "-", #_matchCell))
		end
		for _index2, _cell in ipairs(_matchCell) do
			_changes = true
			grid[_cell] = nil
			_superCrystalCheck[_cell] = (_superCrystalCheck[_cell] or 0) + 1
			if DEV_MODE and _superCrystalCheck[_cell] >= 2 then
				print(string.format("%s got super crystal", _cell)) -- определяем место супер-кристалла на будущее (при помощи итерации таблицы neighbours можно определить Т- или Г-образность, если вид кристалла будет зависеть от этого)
			end
		end
	end

	if DEV_MODE then dump() end

	return _changes
end

function tickGravity()
	if DEV_MODE then print("Drop crystals...") end
	for _x = 0, GRID_SIZE.x do
		local _everythingFell = true
		local _y = GRID_SIZE.y
		while(_y >= 0) do
			local _cell = "x" .. _x .. "y" .. _y
			if not grid[_cell] then
				local _cellUpper = "x" .. _x .. "y" .. (_y - 1)
				if _everythingFell and grid[_cellUpper] then
					_everythingFell = false
				end
				grid[_cell] = grid[_cellUpper]
				grid[_cellUpper] = nil
			end
			if _y == 0 and not _everythingFell then
				_y = GRID_SIZE.y
				_everythingFell = true
			else
				_y = _y - 1
			end
		end
	end
	if DEV_MODE then dump() end
end

function move(_coords, _direction) -- выполнение хода игрока
	if DEV_MODE then print("Moving crystals...") end
	isSilentTick = false
	local _sourceCell = "x" .. _coords.x .. "y" .. _coords.y
	local _sourceCrystalID = grid[_sourceCell]
	if possibleMatchesInteract[_sourceCell] and moveDirections[_direction] then
		local _targetCell = "x" .. (_coords.x + (moveDirections[_direction].x or 0)) .. "y" .. (_coords.y + (moveDirections[_direction].y or 0))
		local _targetCrystalID = grid[_targetCell]
		if possibleMatchesInteract[_targetCell] and (possibleMatchesInteract[_targetCell][_sourceCrystalID] or possibleMatchesInteract[_sourceCell][_targetCrystalID]) then
			moveCount = moveCount + 1

			grid[_sourceCell] = _targetCrystalID
			grid[_targetCell] = _sourceCrystalID
			tick()
			if not DEV_MODE then
				dump()
			end
			return
		else

		end
	end
	print("[WARNING] No move made...")
end

function mix(_emptyOnly) -- перемешивание поля
	if DEV_MODE then print((_emptyOnly and "Adding" or "Generating new") .. " crystals...") end
	for _y = 0, GRID_SIZE.y do
		for _x = 0, GRID_SIZE.x do
			local _cell = "x" .. _x .. "y" .. _y
			if not _emptyOnly or not grid[_cell] then
				local _crystalID = math.random(#crystals) -- получаем случайный кристалл
				grid[_cell] = _crystalID
			end
		end
	end
	if not _emptyOnly then isSilentTick = true end
	if DEV_MODE then tickPossibleMatches() dump() end
end

function dump() -- вывод поля на экран
	local _header = string.format("| Move %d | Tick %d | Possible matches: %d |", moveCount, tickCount, #possibleMatches)
	local _border = string.rep("=", string.len(_header))
	io.write(string.format("\n%s\n%s\n%s\n", _border, _header, _border))
	io.write("\n")
	for _y = -2, GRID_SIZE.y do
		for _x = -2, GRID_SIZE.x do
			if _y >= 0 and _x >= 0 then
				local _cell = "x" .. _x .. "y" .. _y
				local _crystalID = grid[_cell]
				io.write(_crystalID and crystals[_crystalID] or " ")
			else
				io.write(((_x <= -1 and _y <= -1) and " ") or (_y == -2 and _x) or (_x == -2 and _y) or (_x == -1 and "|" or "-"))
			end
		end
		io.write("\n")
	end
	-- io.write("\n\n")
	io.write("\n")
end

init()
tick()
if not DEV_MODE then
	dump()
end

while(true) do
	if DEV_MODE then
		for _index, _data in ipairs(possibleMatches) do
			print(string.format("%02d. %s [%s + %s + %s]", _index, crystals[_data.crystalID], _data.cells[1], _data.cells[2], _data.cells[3]))
		end
	end
	io.write("'m [x] [y] [d]' - move; 'd' - " .. (DEV_MODE and "disable" or "enable") .. " DEV_MODE; 'q' - exit: ")
	local _input = io.read()

	local _command, _x, _y, _direction

	for _i in string.gmatch(_input, "%S+") do
		if not _command then
			_command = _i
		end
		if _command == "q" then
			exit()
		elseif _command == "d" then
			DEV_MODE = not DEV_MODE
		elseif _command == "m" then
			if not _x then
				_x = tonumber(_i)
			elseif not _y then
				_y = tonumber(_i)
			elseif not _direction then
				_direction = tostring(_i)
			end
		end
	end

	if _x and _y and _direction then
		move({x = _x, y = _y}, _direction)
	else
		tick()
		if not DEV_MODE then dump() end
	end
end
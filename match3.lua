--==================================================
--Match-3 [match3.lua]
--Разработал Timur Moziev (code@timurrin.ru) (2021/01/24)
-->>>> Простая имплементация жанра три-в-ряд, техническое задание для компании Red Brix Wall
--==================================================

-- DEV_MODE = true -- режим разработчика, отображает много промежуточной информации
GRID_SIZE = {x = 9, y = 9} -- поле 10х10; в ТЗ указаны значения координат поля с 0 (в луа индексы таблиц начинаются с 1), для оптимизации (недопуска в коде бессмысленных убавлений вида "GRID_SIZE.x - 1") отминусуем единичку прямо здесь. Разумеется можно "сдвигать" на -1 введённую координату при вводе команды на сдвиг кристалла, но может запутать при дебаге (особенно на крупных проектах)

crystals = { -- варианты графического отображения кристаллов + специальный, который не используется на данном этапе
	"A", "B", "C", "D", "E", "F",
	"W"
} 
currentCrystals = 6 -- текущее количество разновидностей кристаллов на поле
maxCrystals = 6 -- максимальное количество разновидностей обычных кристаллов
specialCrystallID = 7
SPECIAL_CRYSTALL_ENABLED = false -- реализация для появления спец-кристалла на поле (если включено, появляется только в случае если клетка была участником двух разноосевых рядов)

neighbours = { -- направления для проверки возможных рядов
	{direction = "u", y = -1, check = {{y = 2}, {x = -1, y = 1}, {x = 1, y = 1}}, target = {y = 1}},
	{direction = "r", x = 1, check = {{x = -2}, {x = -1, y = -1}, {x = -1, y = 1}}, target = {x = -1}},
	{direction = "d", y = 1, check = {{y = -2}, {x = -1, y = -1}, {x = 1, y = -1}}, target = {y = -1}},
	{direction = "l", x = -1, check = {{x = 2}, {x = 1, y = -1}, {x = 1, y = 1}}, target = {x = 1}},
}

moveDirections = {} -- таблица для поиска данных о направлении по ключу lrud
for _index, _neighboursData in ipairs(neighbours) do
	moveDirections[_neighboursData.direction] = _neighboursData
end

moveCount = 0 -- количество ходов
tickCount = 0 -- количество действий поля (в данной реализации действием считается "проверка возможных рядов > проверка текущих рядов > удаление текущих рядов > смещение висящих кристаллов вниз > заполнение пустых клеток")

-- вспомогательные функции

function getTextBorder(_text)
	local _header = string.format("| %s |", _text)
	local _border = string.rep("=", string.len(_header))
	return string.format("\n%s\n%s\n%s\n", _border, _header, _border)
end

-- главные функции

function init() -- создание поля
	grid = {} -- в каждой клетке поля будет указан индекс, ссылающийся на таблицу crystals
	matches = {} -- готовые для удаления ряды
	possibleMatches = {} -- возможные ряды

	mix() -- выставляем кристаллы
end

function tick() -- выполнение действий на поле
	tickCount = tickCount + 1
	if DEV_MODE then
		io.write(getTextBorder(string.format("Tick %d", tickCount)))
	end

	tickPossibleMatches() -- проверяем возможные ряды
	if #possibleMatches == 0 then -- если таковых нет
		mix() -- мешаем поле полностью. запускается режим "тихих тиков" ('isSilentTick'), который проверяет выставленные рандомом готовые ряды, и удаляет их прежде чем их увидит игрок
		tick() -- запускаем следующий тик для проверки изменений
		return
	end

	matches = {} -- обнуляем таблицу с готовыми рядами

	-- ищем готовые ряды по осям
	tickMatchCheckGrid("x")
	tickMatchCheckGrid("y")

	if tickClearMatches() then -- чистим готовые ряды. если есть изменения, скрипт продолжится в этом условии (функция возвращает true/false)
		tickGravity() -- роняем кристаллы
		mix(true) -- добавляем новые кристаллы в пустые клетки
		tick() -- сразу запускаем следующий тик
	end
end

function tickPossibleMatches() -- функция ищет потенциальные ряды на текущем поле
	possibleMatches = {}
	possibleMatchesInteract = {}

	for _y = 0, GRID_SIZE.y do
		for _x = 0, GRID_SIZE.x do
			local _cellID = "x" .. _x .. "y" .. _y
			local _crystalID = grid[_cellID] -- узнаём кристалл клетки, понадобится для сравнения
			for _index, _directionData in ipairs(neighbours) do -- ищем lrud-соседей
				local _directionTargetCell = "x" .. (_x + (_directionData.target.x or 0)) .. "y" .. (_y + (_directionData.target.y or 0))

				local _directionCellID = "x" .. (_x + (_directionData.x or 0)) .. "y" .. (_y + (_directionData.y or 0))
				local _directionCrystalID = grid[_directionCellID] -- получаем кристалл соседа
				if _crystalID == _directionCrystalID then -- если такой сосед находится...
					for _index2, _directionCheckData in ipairs(_directionData.check) do -- запускаем поиск "треугольником" в противоположную от соседа сторону
						local _directionCheckCellID = "x" .. (_x + (_directionCheckData.x or 0)) .. "y" .. (_y + (_directionCheckData.y or 0))
						local _directionCheckCrystalID = grid[_directionCheckCellID] -- получаем кристалл 
						if _crystalID == _directionCheckCrystalID then -- если наш вид кристалла найден...
							possibleMatches[#possibleMatches+1] = {crystalID = _crystalID, cells = {_cellID, _directionCellID, _directionCheckCellID}} -- добавляем в таблицу с возможными рядами вид кристалла и ид клеток
							if not possibleMatchesInteract[_directionCheckCellID] then possibleMatchesInteract[_directionCheckCellID] = {} end
							if not possibleMatchesInteract[_directionTargetCell] then possibleMatchesInteract[_directionTargetCell] = {} end
							possibleMatchesInteract[_directionCheckCellID][_crystalID] = true -- добавляем информацию про вид кристалла проверяемой клетки...
							possibleMatchesInteract[_directionTargetCell][_crystalID] = true -- ...и целевой, используется для проверок при ходах
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
		local _params = {type = _typeA, crystalID = nil} -- таблица для хранения данных при сплошной проверке

		for _b = 0, GRID_SIZE[_typeB] do
			local _cellID = "x" .. (_typeA == "y" and _b or _a) .. "y" .. (_typeA == "y" and _a or _b)
			tickMatchCheckCell(_cellID, _params)
		end

		if matches[#matches] and (#matches[#matches] < 3) then -- обнуляем неполный ряд на оси
			matches[#matches] = nil
		end
	end
end

function tickMatchCheckCell(_cellID, _params) -- последовательная проверка каждой клетки оси вынесено в отдельную функцию для наглядности
	local _crystalID = grid[_cellID]
	local _match = #matches
	if not _crystalID or _params.crystalID ~= _crystalID then -- если при сплошной проверки оси попадается другой кристалл, или если мы ещё ничего не искали...
		if _match == 0 then
			_match = 1 -- если готовых рядов ещё нет -- значит даём первый номер
		elseif matches[_match] and #matches[_match] >= 3 then -- если при сплошной проверке мы нашли ряд из трёх и более кристаллов, то создаём новый ряд
			_match = #matches + 1
		end
		_params.crystalID = _crystalID -- выставляем новый кристалл
		matches[_match] = {} -- создаём новую группу
	end
	matches[_match][#matches[_match]+1] = _cellID -- добавляем текущую клетку в потенциальный ряд
end

function tickClearMatches() -- очищение готовых рядов
	local _changes = false -- были ли удаления

	local _superCrystalCheck = {} -- одно из возможных определений супер-кристалла

	if (DEV_MODE or not isSilentTick) and #matches > 0 then print(string.format("\n[Tick %d] Found %d match(es)", tickCount, #matches)) end

	for _index, _matchCell in ipairs(matches) do
		local _rowSize = #_matchCell -- размер ряда (пригодится для получения супер-кристаллов)
		if DEV_MODE or not isSilentTick then
			print(string.format("Match %d: crystal %s match-%d", _index, grid[_matchCell[1]] and crystals[grid[_matchCell[1]]] or "-", _rowSize))
		end
		for _index2, _cellID in ipairs(_matchCell) do
			_changes = true
			grid[_cellID] = nil -- удаляем кристалл
			if SPECIAL_CRYSTALL_ENABLED then -- если супер-кристаллы включены
				_superCrystalCheck[_cellID] = (_superCrystalCheck[_cellID] or 0) + 1 -- проверка клетки на участие в нескольких рядах одновременно
				if DEV_MODE and _superCrystalCheck[_cellID] >= 2 then -- если участвовала в двух и более рядах...
					grid[_cellID] = specialCrystallID -- спауним супер-кристалл
					print(string.format("%s got super crystal", _cellID))
				end
			end
		end
	end

	if DEV_MODE then dump() end -- отображаем поле сразу после удаления кристаллов в режиме разработчика

	return _changes
end

function tickGravity() -- в этой функции мы спускаем висящие кристаллы вниз
	if DEV_MODE then print("Drop crystals...") end
	for _x = 0, GRID_SIZE.x do -- идём по X-оси, т.к. она горизонтальная
		local _everythingFell = true -- флажок на проверку того, что всё упало по Y-оси
		local _y = GRID_SIZE.y -- начинаем проверку кристаллов с "земли"
		while(_y >= 0) do -- опускаем кристаллы пока не достигнем "неба"
			local _cellID = "x" .. _x .. "y" .. _y
			if not grid[_cellID] then -- если клетка пустая
				local _cellIDUpper = "x" .. _x .. "y" .. (_y - 1)
				if _everythingFell and grid[_cellIDUpper] then -- если клетка над нами не пустая, то мы сообщаем что есть висящие кристаллы
					_everythingFell = false
				end
				grid[_cellID] = grid[_cellIDUpper] -- опускаем кристалл на одну клетку вниз
				grid[_cellIDUpper] = nil
			end
			if _y == 0 and not _everythingFell then -- если мы добрались до неба и у нас остались висящие кристаллы
				_y = GRID_SIZE.y -- то опять опускаемся на землю в этом же столбце
				_everythingFell = true
			else -- или же продолжаем идти к небу
				_y = _y - 1
			end
		end
	end
	if DEV_MODE then dump() end -- отображаем поле сразу после падения всех кристаллов в режиме разработчика
end

function move(_coords, _direction) -- выполнение хода игрока
	if DEV_MODE then print("Moving crystals...") end
	isSilentTick = false
	local _sourceCell = "x" .. _coords.x .. "y" .. _coords.y -- исходный кристалл, который мы двигаем в сторону
	local _sourceCrystalID = grid[_sourceCell] -- вид кристалла, который мы двигаем
	if possibleMatchesInteract[_sourceCell] and moveDirections[_direction] then -- если клетка участвует в потенциальном кристаллообмене и направление указано верно
		local _targetCell = "x" .. (_coords.x + (moveDirections[_direction].x or 0)) .. "y" .. (_coords.y + (moveDirections[_direction].y or 0))
		local _targetCrystalID = grid[_targetCell] -- то узнаём про кристалл в целевой клетке
		if possibleMatchesInteract[_targetCell] and (possibleMatchesInteract[_targetCell][_sourceCrystalID] or possibleMatchesInteract[_sourceCell][_targetCrystalID]) then -- если они могут обменяться...
			moveCount = moveCount + 1 -- засчитываем ход

			grid[_sourceCell] = _targetCrystalID -- меняем кристаллы
			grid[_targetCell] = _sourceCrystalID
			tick() -- проверяем что вышло
			if not DEV_MODE then
				dump() -- отображаем игроку результат
			end
			return
		end
	end
	print("[WARNING] No move made...")
end

function mix(_emptyOnly) -- перемешивание поля
	if DEV_MODE then print((_emptyOnly and "Adding" or "Generating new") .. " crystals...") end
	for _y = 0, GRID_SIZE.y do
		for _x = 0, GRID_SIZE.x do
			local _cellID = "x" .. _x .. "y" .. _y
			if not _emptyOnly or not grid[_cellID] then
				local _crystalID = math.random(currentCrystals) -- получаем случайный вид кристалла. режим isSilentTick удалит готовые ряды при полном миксе
				grid[_cellID] = _crystalID
			end
		end
	end
	if not _emptyOnly then isSilentTick = true end -- режим isSilentTick может быть включен только если мы перемешиваем поле полностью
	if DEV_MODE then tickPossibleMatches() dump() end -- отображаем разработчику результат
end

function dump() -- вывод поля на экран
	io.write(getTextBorder(string.format("Move %d | Tick %d | Possible matches: %d", moveCount, tickCount, #possibleMatches)))
	if DEV_MODE then -- отображаем разработчику дополнительную информацию
		io.write(string.format("%d match(es) possible:\n", #possibleMatches))
		for _index, _data in ipairs(possibleMatches) do
			io.write(string.format("%s [%s + %s + %s]", crystals[_data.crystalID], _data.cells[1], _data.cells[2], _data.cells[3]))
			if _index % 3 == 0 then
				io.write("\n")
			else
				io.write("   ")
			end
		end
	end
	io.write("\n\n")
	-- отображаем поле
	for _y = -2, GRID_SIZE.y do
		for _x = -2, GRID_SIZE.x do
			if _y >= 0 and _x >= 0 then
				local _cellID = "x" .. _x .. "y" .. _y
				local _crystalID = grid[_cellID]
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

-- основной цикл игры

while(true) do
	io.write("'m [x] [y] [d]' - move; 'd' - " .. (DEV_MODE and "disable" or "enable") .. " DEV_MODE; 'q' - exit: ") -- информация игроку
	local _input = io.read() -- получаем ввод данных

	local _command, _x, _y, _direction

	for _i in string.gmatch(_input, "%S+") do -- разбираем инпут, разделённый пробелами
		if not _command then -- первая часть инпута всегда команда
			_command = _i
		end
		if _command == "q" then -- если это выход - выходим
			exit()
		elseif _command == "d" then -- переключатель режима разработчика
			DEV_MODE = not DEV_MODE
		elseif _command == "m" then -- режим хода
			if not _x then -- узнаём X
				_x = tonumber(_i)
			elseif not _y then -- узнаём Y
				_y = tonumber(_i)
			elseif not _direction then -- узнаём направление
				_direction = tostring(_i)
			end
		end
	end

	if _x and _y and _direction then -- если всё введено верно, произойдёт ход
		move({x = _x, y = _y}, _direction)
	else -- в противном случае отображаем поле игроку ещё раз
		dump()
	end
end
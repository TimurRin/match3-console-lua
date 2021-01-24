GRID_SIZE = {x = 9, y = 9} -- поле 10х10; в ТЗ указаны значения координат поля с 0 (в луа индексы таблиц начинаются с 1), для оптимизации (недопуска в коде бессмысленных убавлений вида "GRID_SIZE.x - 1") отминусуем единичку прямо здесь. Разумеется можно "сдвигать" на -1 введённую координату при вводе команды на сдвиг кристалла, но может запутать при дебаге (особенно на крупных проектах)
crystals = {"A", "B", "C", "D", "E", "F"} -- варианты графического отображения кристаллов

checkDirections = {{y = -1}, {x = 1}, {y = 1}, {x = -1}}

tickCount = 0 -- количество действий поля

function init() -- создание поля
	grid = {} -- в каждой клетке поля будет указан индекс, ссылающийся на таблицу crystals
	matches = {} -- готовые для удаления комбинации

	mix() -- выставляем кристаллы 
end

function tick() -- выполнение действий на поле
	io.write(string.format("\nTick %d\n", tickCount))
	tickCount = tickCount + 1

	-- twoCellsmatches = {}
	-- local _twoCellsmatchesFound = {}
	
	-- for _y = 0, GRID_SIZE.y do
		-- for _x = 0, GRID_SIZE.x do
			-- local _cell = "x" .. _x .. "y" .. _y
			-- for _index, _directionData in ipairs(checkDirections) do
				-- local _directionCell = (_x + (_directionData.x or 0)) .. "_" .. (_y + (_directionData.y or 0))
				-- local _directionCrystalID = grid[_directionCell]
				-- if _directionCrystalID then
					-- if grid[_cell] == grid[_directionCell] then
						-- twoCellsmatches[#twoCellsmatches+1] = {_cell, _directionCell}
						-- _twoCellsmatchesFound[_cell] = (_twoCellsmatchesFound[_cell] or 0) + 1
						-- _twoCellsmatchesFound[_directionCell] = (_twoCellsmatchesFound[_directionCell] or 0) + 1
					-- end
				-- end
			-- end
		-- end
	-- end
	
	-- ищем комбинации
	
	matches = {} -- обнуляем таблицу с комбинациями

	 -- проверяем допустимые комбинации по осям
	tickMatchCheckGrid("x")
	tickMatchCheckGrid("y")

	local _changes -- переменная для запуска следующего тика, если есть новые изменения

	_changes = tickClearMatches() -- функция возвращает, были ли удаления
	
	
	-- if _changes then
		-- tick()
	-- end
end

function tickMatchCheckGrid(_typeA) -- проверка игрового поля на комбинации. функция необходима для недопуска повторения похожего кода, т.к. нам нужно последовательно проверить слева-справа и сверху-вниз
	local _typeB = _typeA == "y" and "x" or "y"
	for _a = 0, GRID_SIZE[_typeA] do
		local _match = {type = _typeA, crystalID = nil}

		for _b = 0, GRID_SIZE[_typeB] do
			local _cell = "x" .. (_typeA == "y" and _b or _a) .. "y" .. (_typeA == "y" and _a or _b)
			tickMatchCheckCell(_cell, _match)
		end

		if #matches[#matches] < 3 then
			matches[#matches] = nil
		end
	end
end

function tickMatchCheckCell(_cell, _match) -- последовательная проверка каждой клетки оси вынесено в отдельную функцию для наглядности
	local _crystalID = grid[_cell]
	local _match = #matches
	if _match.crystalID ~= _crystalID then
		if _match == 0 then
			_match = 1
		elseif #matches[_match] >= 3 then
			_match = #matches + 1
		end
		_match.crystalID = _crystalID
		matches[_match] = {}
	end
	matches[_match][#matches[_match]+1] = _cell
	if #matches[_match] >= 3 then
		print(string.format("%s %s: crystal %s spree %d", _match.type, _cell, crystals[_crystalID], #matches[_match]))
	end
end

function tickClearMatches()
	local _changes
	
	local _superCrystalCheck = {}
	
	for _index, _matchCell in ipairs(matches) do
		for _index2, _cell in ipairs(_matchCell) do
			_changes = true
			grid[_cell] = nil
			_superCrystalCheck[_cell] = (_superCrystalCheck[_cell] or 0) + 1
			if _superCrystalCheck[_cell] >= 2 then
				print(string.format("%s got super crystal", _cell)) -- определяем место супер-кристалла на будущее (при помощи итерации таблицы checkDirections можно определить Т- или Г-образность, если вид кристалла будет зависиеть от этого)
			end
		end
	end
	
	return _changes
end

function move(_from, _to) -- выполнение хода игрока
	print(_from)
end

function mix() -- перемешивание поля
	for _y = 0, GRID_SIZE.y do
		for _x = 0, GRID_SIZE.x do
			local _cell = "x" .. _x .. "y" .. _y
			local _crystalID = math.random(#crystals) -- получаем случайный кристалл
			grid[_cell] = _crystalID
		end
	end
end

function dump() -- вывод поля на экран
	io.write(string.format("\n============\n[Tick %d | Ready matches: %d]\n============\n", tickCount, #matches))
	for _y = -2, GRID_SIZE.y do
		for _x = -2, GRID_SIZE.x do
			if _y >= 0 and _x >= 0 then
				local _cell = "x" .. _x .. "y" .. _y
				local _crystalID = grid[_cell]
				-- if tickCount % 2 == 0 then
					io.write(_crystalID and crystals[_crystalID] or " ")
				-- else
					-- io.write(_crystalID and _twoCellsmatchesFound[_cell] or " ")
				-- end
			else
				io.write(((_x <= -1 and _y <= -1) and " ") or (_y == -2 and _x) or (_x == -2 and _y) or (_x == -1 and "|" or "-"))
			end
		end
		io.write("\n")
	end
	io.write("\n\n")
end

init()
-- tick()
-- dump()

while(true) do
	io.write("Temp input ")
	local _haha = io.read()
	-- print("BEFORE REMOVAL")
	-- dump()
	tick()
	-- print("AFTER REMOVAL")
	dump()
end
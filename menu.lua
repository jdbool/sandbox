---@type Plugin
local mode = ...

local server = server
local ipairs = ipairs
local TYPE_WORLD = TYPE_WORLD
local playersGetNonBots = players.getNonBots
local vehiclesGetAll = vehicles.getAll
local itemsGetAll = items.getAll
local humansGetAll = humans.getAll
local osRealClock = os.realClock

local tools = mode:require('tools')
local util = mode:require('util')

local TOP_FLAG = 0x01000000

local VEHICLE_COLORS = {
	[0] = 'Black',
	[1] = 'Red',
	[2] = 'Blue',
	[3] = 'Grey',
	[4] = 'White',
	[5] = 'Gold'
}

local OBJECT_BUTTONS = {
	{
		vehicle = assert(vehicleTypes.getByName('Town Car'))
	},
	{
		vehicle = assert(vehicleTypes.getByName('Turbo'))
	},
	{
		vehicle = assert(vehicleTypes.getByName('Turbo S'))
	},
	{
		vehicle = assert(vehicleTypes.getByName('Beamer'))
	},
	{
		vehicle = assert(vehicleTypes.getByName('Van'))
	},
	{
		vehicle = assert(vehicleTypes.getByName('Minivan'))
	},
	-- {
	-- 	vehicle = assert(vehicleTypes.getByName('Helicopter'))
	-- },
	{
		vehicle = assert(vehicleTypes.getByName('Hatchback'))
	},
	{
		item = assert(itemTypes.getByName('Box'))
	},
	{
		name = 'Plank',
		item = assert(itemTypes.getByName('Big Box'))
	},
	{
		item = assert(itemTypes.getByName('Bottle'))
	},
	{
		item = assert(itemTypes.getByName('Watermelon'))
	},
	{
		item = assert(itemTypes.getByName('AK-47'))
	},
	{
		item = assert(itemTypes.getByName('AK-47 Magazine'))
	},
	{
		item = assert(itemTypes.getByName('M-16'))
	},
	{
		item = assert(itemTypes.getByName('M-16 Magazine'))
	},
	{
		item = assert(itemTypes.getByName('MP5'))
	},
	{
		item = assert(itemTypes.getByName('MP5 Magazine'))
	},
	{
		item = assert(itemTypes.getByName('Uzi'))
	},
	{
		item = assert(itemTypes.getByName('Uzi Magazine'))
	},
	{
		item = assert(itemTypes.getByName('9mm'))
	},
	{
		item = assert(itemTypes.getByName('9mm Magazine'))
	},
	{
		item = assert(itemTypes.getByName('Bandage'))
	}
}

local BOT_TYPES = {
	{
		name = 'Goldmen',
		suitColor = 6,
		tieColor = 2,
		model = 1,
		team = 0
	},
	{
		name = 'Monsota',
		suitColor = 10,
		tieColor = 9,
		model = 1,
		team = 1
	},
	{
		name = 'OXS',
		suitColor = 11,
		tieColor = 8,
		model = 1,
		team = 2
	},
	{
		name = 'Nexaco',
		suitColor = 2,
		tieColor = 3,
		model = 1,
		team = 3
	},
	{
		name = 'Pentacom',
		suitColor = 1,
		tieColor = 7,
		model = 1,
		team = 4
	},
	{
		name = 'Prodocon',
		suitColor = 2,
		tieColor = 1,
		model = 1,
		team = 5
	},
	{
		name = 'Megacorp',
		suitColor = 1,
		tieColor = 0,
		model = 1,
		team = 6
	},
	{
		name = 'Civilian',
		suitColor = 0,
		tieColor = 0,
		model = 0,
		team = 17
	}
}

local SHIRT_COLORS = {
	{
		name = 'White',
		color = 0
	},
	{
		name = 'Pink',
		color = 1
	},
	{
		name = 'Light Yellow',
		color = 2
	},
	{
		name = 'Light Green',
		color = 3
	},
	{
		name = 'Light Blue',
		color = 4
	},
	{
		name = 'Red',
		color = 5
	},
	{
		name = 'Black',
		color = 9
	},
	{
		name = 'Dark Blue',
		color = 10
	},
	{
		name = 'Dark Green',
		color = 11
	}
}

local UTILITY_BUTTONS = {
	'Clear All',
	'Clear Vehicles',
	'Clear Items',
	'Clear Bots'
}

local TELEPORT_DESTINATIONS = {
	{ Vector(1037, 25.5, 1038), 'Goldmen' },
	{ Vector(1806, 25.5, 1010), 'RIO Inc.' },
	{ Vector(1930, 25.5, 1083), 'Water Treatment' },
	{ Vector(1068, 33.5, 1181), 'WNQY' },
	{ Vector(1366, 25.5, 1146), 'Hotdogs' },
	{ Vector(1614, 25.5, 1175), 'Gas' },
	{ Vector(1501, 33, 1218), 'Crab Legs' },
	{ Vector(1542, 33.5, 1286), 'Red Cube Park' },
	{ Vector(1819, 25.5, 1258), 'Hondo Park' },
	{ Vector(1342, 49.5, 1341), 'The Mall' },
	{ Vector(1785, 49.5, 1419), 'Lumber' },
	{ Vector(1476, 49.5, 1490), 'Isle of Burgers' },
	{ Vector(1692, 45.5, 1486), 'Museum' },
	{ Vector(1267, 49.25, 1521), 'Kamel Bldg.' },
	{ Vector(1848, 41.25, 1534), 'Cul-de-sac' },
	{ Vector(1506, 49.5, 1653), 'Library' },
	{ Vector(1086, 25.5, 1716), 'Monsota' },
	{ Vector(1929, 25.5, 1689), 'OXS' }
}

local nSpawn

mode:addHook(
	'PostResetGame',
	function ()
		nSpawn = 0
	end
)

mode:addEnableHandler(function ()
	nSpawn = 0
end)

mode:addDisableHandler(function ()
	nSpawn = nil
end)

---@param ply Player
local function drawMenu (ply)
	local data = ply.data
	local menuTab = data.sandboxMenuTab or 0

	local numButtons = 0

	for i, text in ipairs({ 'Objects', 'Bots', 'Teleport', 'Tool', 'Friends', 'Utilities' }) do
		local btn = ply:getMenuButton(numButtons)
		numButtons = numButtons + 1

		if i == 4 then
			local name
			local toolID = data.sandboxTool
			if toolID and toolID ~= 0 then
				name = tools[toolID].name
			else
				name = 'None'
			end

			text = text .. ' (' .. name .. ')'
		end

		btn.id = TOP_FLAG + i - 1
		btn.text = text

		if i - 1 == menuTab then
			btn.id = -1
		end
	end

	if menuTab == 0 then
		do
			local btn = ply:getMenuButton(numButtons)
			numButtons = numButtons + 1

			local color = data.sandboxColor or 0

			btn.id = 0
			btn.text = 'Paint Colour: ' .. VEHICLE_COLORS[color]
		end
		for i, object in ipairs(OBJECT_BUTTONS) do
			local btn = ply:getMenuButton(numButtons)
			numButtons = numButtons + 1

			local name = object.name
			if not name then
				if object.vehicle then
					name = object.vehicle.name
				else
					name = object.item.name
				end
			end

			btn.id = i
			btn.text = 'Spawn ' .. name
		end
	elseif menuTab == 1 then
		do
			local btn = ply:getMenuButton(numButtons)
			numButtons = numButtons + 1

			local type = data.sandboxBotMode or 0

			btn.id = 0
			btn.text = 'Mode: ' .. (type == 0 and 'AI' or 'Ragdoll')
		end
		for i, type in ipairs(BOT_TYPES) do
			local btn = ply:getMenuButton(numButtons)
			numButtons = numButtons + 1

			btn.id = i
			btn.text = 'Spawn ' .. type.name
		end
	elseif menuTab == 2 then
		for i, dest in ipairs(TELEPORT_DESTINATIONS) do
			local btn = ply:getMenuButton(numButtons)
			numButtons = numButtons + 1

			btn.id = i
			btn.text = dest[2]
		end
	elseif menuTab == 3 then
		do
			local btn = ply:getMenuButton(numButtons)
			numButtons = numButtons + 1

			btn.id = 0
			btn.text = 'None'
		end
		for i, tool in ipairs(tools) do
			local btn = ply:getMenuButton(numButtons)
			numButtons = numButtons + 1

			btn.id = i
			btn.text = tool.name
		end
	elseif menuTab == 4 then
		local pages = data.sandboxFriendsPages
		local pageNum = data.sandboxFriendsPage

		if pageNum > 1 then
			local btn = ply:getMenuButton(numButtons)
			numButtons = numButtons + 1

			btn.id = 0
			btn.text = 'Prev Page'
		end

		if pageNum < #pages then
			local btn = ply:getMenuButton(numButtons)
			numButtons = numButtons + 1

			btn.id = 1
			btn.text = 'Next Page'
		end

		for i, button in ipairs(pages[pageNum]) do
			if numButtons >= 32 then break end

			local btn = ply:getMenuButton(numButtons)
			numButtons = numButtons + 1

			btn.id = i + 1
			btn.text = button.text
		end
	elseif menuTab == 5 then
		local queue = data.sandboxUndoQueue
		if queue and #queue > 0 then
			local btn = ply:getMenuButton(numButtons)
			numButtons = numButtons + 1

			local action = queue[#queue]
			local secondsAgo = math.floor(osRealClock() - action.time)

			btn.id = 0
			btn.text = 'Undo ' .. action.name .. ' (' .. secondsAgo .. 's ago)'
		end

		do
			local btn = ply:getMenuButton(numButtons)
			numButtons = numButtons + 1

			local profile = util.getProfile(ply)
			local shirt = SHIRT_COLORS[profile.shirt or 1]

			btn.id = 1
			btn.text = 'Shirt Colour: ' .. shirt.name
		end

		for id, text in ipairs(UTILITY_BUTTONS) do
			local btn = ply:getMenuButton(numButtons)
			numButtons = numButtons + 1

			btn.id = id + 1
			btn.text = text
		end
	end

	ply.numMenuButtons = numButtons
end

mode:addHook(
	'ServerSend',
	function ()
		server.type = TYPE_WORLD

		for _, ply in ipairs(playersGetNonBots()) do
			if ply.human then
				ply.menuTab = 14

				drawMenu(ply)
			else
				ply.menuTab = 1
			end
		end
	end
)

mode:addHook(
	'PostServerSend',
	function ()
		server.type = 20

		for _, ply in ipairs(playersGetNonBots()) do
			ply.menuTab = 0
		end
	end
)

local function buildFriendsButtons (ply, data)
	local profile = util.getProfile(ply)
	local friends = profile.friends

	local nonBots = playersGetNonBots()
	table.sort(nonBots, function (a, b)
		return a.name:lower() < b.name:lower()
	end)

	local pages = {{}}
	local page = pages[1]

	for _, otherPly in ipairs(nonBots) do
		if otherPly ~= ply and (not isHiddenModerator or not isHiddenModerator(otherPly)) then
			if page and #page >= 22 then
				page = {}
				table.insert(pages, page)
			end

			local button = {}
			button.phoneNumber = otherPly.phoneNumber

			local key = tostring(otherPly.phoneNumber)
			if friends and friends[key] then
				button.text = 'Remove ' .. otherPly.name
			else
				button.text = 'Add ' .. otherPly.name
			end

			table.insert(page, button)
		end
	end

	data.sandboxFriendsPages = pages

	if not data.sandboxFriendsPage or data.sandboxFriendsPage > #pages or data.sandboxFriendsPage < 1 then
		data.sandboxFriendsPage = 1
	end
end

local function clickedMenuTab (ply, id, data)
	if id >= 0 and id <= 5 then
		if id == 4 then
			buildFriendsButtons(ply, data)
		end
		data.sandboxMenuTab = id

		local man = ply.human
		if man then
			events.createSound(21, man.pos, 0.1, 2)
		end
	end
end

local function getPlayersNumVehicles (ply)
	local phone = ply.phoneNumber
	local num = 0

	for _, vcl in ipairs(vehiclesGetAll()) do
		if vcl.data.sandboxCreatorPhone == phone then
			num = num + 1
		end
	end

	return num
end

local function getPlayersNumItems (ply)
	local phone = ply.phoneNumber
	local num = 0

	for _, item in ipairs(itemsGetAll()) do
		if item.data.sandboxCreatorPhone == phone then
			num = num + 1
		end
	end

	return num
end

local function getPlayersNumBots (ply)
	local phone = ply.phoneNumber
	local num = 0

	for _, man in ipairs(humansGetAll()) do
		if man.data.sandboxCreatorPhone == phone then
			if not man.player or man.player.isBot then
				num = num + 1
			end
		end
	end

	return num
end

local function clickedVehicle (ply, vehicleType)
	local man = ply.human
	if not man then return end

	do
		local limit = 250
		local numPlayers = #playersGetNonBots()

		if vehicles.getCount() >= limit then
			ply:sendMessage('[ X ] Global vehicle limit reached (' .. limit .. ')')
			util.sound('error', man.pos)
			return
		end

		local personalLimit = math.floor(limit / numPlayers)

		if getPlayersNumVehicles(ply) >= personalLimit then
			ply:sendMessage('[ X ] Personal vehicle limit reached (' .. personalLimit .. ')')
			util.sound('error', man.pos)
			return
		end
	end

	local ray = util.lineIntersectAll(man, getEyeLine(man, 2048))
	if not ray.hit then
		util.sound('error', man.pos)
		return
	end

	local pos = ray.pos:clone()
	local normal = ray.normal:clone()
	pos:add(normal)

	local color = ply.data.sandboxColor or 0
	local vcl = vehicles.create(vehicleType, pos, yawToRotMatrix(man.viewYaw - math.pi/2), color)
	if vcl then
		vcl.data.sandboxCreatorPhone = ply.phoneNumber
		vcl.rigidBody.data.sandboxCreatorPhone = ply.phoneNumber
		util.addUndoAction(ply, {
			obj = vcl,
			name = 'Spawn Vehicle'
		})
	end
	util.sound('general', man.pos)
end

local function clickedItem (ply, itemType)
	local man = ply.human
	if not man then return end

	do
		local limit = 500
		local numPlayers = #playersGetNonBots()

		if items.getCount() >= limit then
			ply:sendMessage('[ X ] Global item limit reached (' .. limit .. ')')
			util.sound('error', man.pos)
			return
		end

		local personalLimit = math.floor(limit / numPlayers)

		if getPlayersNumItems(ply) >= personalLimit then
			ply:sendMessage('[ X ] Personal item limit reached (' .. personalLimit .. ')')
			util.sound('error', man.pos)
			return
		end
	end

	local ray = util.lineIntersectAll(man, getEyeLine(man, 2048))
	if not ray.hit then
		util.sound('error', man.pos)
		return
	end

	local pos = ray.pos:clone()
	local normal = ray.normal:clone()
	pos:add(normal)

	local item = items.create(itemType, pos, yawToRotMatrix(man.viewYaw - math.pi/2))
	if item then
		item.despawnTime = 65536
		item.data.sandboxCreatorPhone = ply.phoneNumber
		item.rigidBody.data.sandboxCreatorPhone = ply.phoneNumber
		util.addUndoAction(ply, {
			obj = item,
			name = 'Spawn Item'
		})
	end
	util.sound('general', man.pos)
end

local function clickedObject (ply, id)
	if id == 0 then
		local color = ply.data.sandboxColor or 0
		color = (color + 1) % (#VEHICLE_COLORS + 1)
		ply.data.sandboxColor = color
		return
	end

	local button = OBJECT_BUTTONS[id]
	if not button then return end

	if button.vehicle then
		clickedVehicle(ply, button.vehicle)
	else
		clickedItem(ply, button.item)
	end
end

local function clickedBot (ply, id)
	local data = ply.data
	local botMode = data.sandboxBotMode or 0

	if id == 0 then
		data.sandboxBotMode = botMode == 0 and 1 or 0
		return
	end

	local type = BOT_TYPES[id]
	if not type then return end

	local man = ply.human
	if not man then return end

	do
		local limit = 150
		local numPlayers = #playersGetNonBots()

		if humans.getCount() >= limit then
			ply:sendMessage('[ X ] Global bot limit reached (' .. limit .. ')')
			util.sound('error', man.pos)
			return
		end

		local personalLimit = math.floor(limit / numPlayers)

		if getPlayersNumBots(ply) >= personalLimit then
			ply:sendMessage('[ X ] Personal bot limit reached (' .. personalLimit .. ')')
			util.sound('error', man.pos)
			return
		end
	end

	local ray = util.lineIntersectAll(man, getEyeLine(man, 2048))
	if not ray.hit then
		util.sound('error', man.pos)
		return
	end

	local pos = ray.pos:clone()
	local normal = ray.normal:clone()
	pos:add(normal)

	local bot = players.createBot()
	if bot then
		bot.name = 'Bot'
		bot.team = type.team or 0
		bot.gender = math.random(0, 1)
		bot.skinColor = math.random(0, 5)
		bot.hairColor = math.random(0, 12)
		bot.hair = math.random(0, 8)
		bot.eyeColor = math.random(0, 7)
		bot.head = math.random(0, 4)
		bot.suitColor = type.suitColor or 0
		bot.tieColor = type.tieColor or 0
		bot.model = type.model or 0

		local botMan = humans.create(pos, yawToRotMatrix(man.viewYaw + math.pi), bot)
		if botMan then
			botMan.data.sandboxCreatorPhone = ply.phoneNumber
			for i = 0, 15 do
				local body = botMan:getRigidBody(i)
				body.data.sandboxCreatorPhone = ply.phoneNumber
			end

			util.addUndoAction(ply, {
				obj = botMan,
				name = 'Spawn Bot'
			})
			bot:update()
			util.sound('general', man.pos)

			if botMode == 1 then
				botMan.isAlive = false
				botMan.data.sandboxRagdoll = true
			end
		else
			bot:remove()
		end
	end
end

local function clickedTeleport (ply, id)
	local dest = TELEPORT_DESTINATIONS[id]
	if not dest then return end

	local man = ply.human
	if not man then return end

	man:teleport(dest[1])
	man:setVelocity(Vector())
end

local function clickedTool (ply, id)
	local tool = tools[id]
	if id == 0 or tool then
		if ply.data.sandboxTool ~= id then
			local man = ply.human
			if man then
				ply.data.sandboxTool = id
				if tool and tool.usage then
					messagePlayerWrap(ply, '[' .. tool.name .. '] ' .. tool.usage)
					util.invokeTool(tools, 'onEquip', false, ply, man)
				end
			end
		end
	end
end

local function clickedFriend (ply, id)
	local data = ply.data

	if id == 0 then
		data.sandboxFriendsPage = data.sandboxFriendsPage - 1
		buildFriendsButtons(ply, data)
		return
	elseif id == 1 then
		data.sandboxFriendsPage = data.sandboxFriendsPage + 1
		buildFriendsButtons(ply, data)
		return
	end

	local button = data.sandboxFriendsPages[data.sandboxFriendsPage][id - 1]
	if not button then return end

	local otherPly = players.getByPhone(button.phoneNumber)
	if not otherPly or otherPly.isBot or otherPly == ply then
		buildFriendsButtons(ply, data)
		return
	end

	local profile = util.getProfile(ply)
	local key = tostring(otherPly.phoneNumber)

	if profile.friends and profile.friends[key] then
		profile.friends[key] = nil
		ply:sendMessage(string.format('Removed %s (%s) as a friend', otherPly.name, dashPhoneNumber(otherPly.phoneNumber)))
	else
		if not profile.friends then
			profile.friends = {}
		end
		profile.friends[key] = true
		ply:sendMessage(string.format('Added %s (%s) as a friend', otherPly.name, dashPhoneNumber(otherPly.phoneNumber)))
	end

	util.setProfilesDirty()
	buildFriendsButtons(ply, data)
end

local function clickedUndo (ply)
	local queue = ply.data.sandboxUndoQueue
	if not queue or #queue < 1 then return false end

	local action = table.remove(queue, #queue)
	if action.bond then
		if not action.bond.isActive then
			return false
		end

		action.bond.isActive = false
	elseif action.obj then
		if not action.obj.isActive then
			return false
		end

		util.eraseObjectBodyUndos(action.obj)
		action.obj:remove()

		util.clearOrphanedBonds()
		if action.obj.class == 'Human' then
			util.clearOrphanedBotPlayers()
		end
	elseif action.body then
		if not action.body.isActive then
			return false
		end

		if action.mass then
			action.body.mass = action.mass
		elseif action.noCollideAll ~= nil then
			action.body.data.sandboxNoCollideAll = action.noCollideAll and true or nil
		else
			return false
		end
	end

	return true, action
end

local function clickedUtility (ply, id)
	local man = ply.human
	if not man then return end

	local phone = ply.phoneNumber

	if id == 0 then
		local worked = clickedUndo(ply)
		util.sound(worked and 'general' or 'error', man.pos)
	elseif id == 1 then
		local profile = util.getProfile(ply)
		profile.shirt = ((profile.shirt or 1) % #SHIRT_COLORS) + 1
		util.setProfilesDirty()
	elseif id == 2 then
		local num = util.clearObjects(phone, vehiclesGetAll()) + util.clearObjects(phone, itemsGetAll()) + util.clearBots(phone)
		util.sound(num > 0 and 'general' or 'error', man.pos)
	elseif id == 3 then
		local num = util.clearObjects(phone, vehiclesGetAll())
		util.sound(num > 0 and 'general' or 'error', man.pos)
	elseif id == 4 then
		local num = util.clearObjects(phone, itemsGetAll())
		util.sound(num > 0 and 'general' or 'error', man.pos)
	elseif id == 5 then
		local num = util.clearBots(phone)
		util.sound(num > 0 and 'general' or 'error', man.pos)
	end
end

local function isClickRateLimited (ply)
	local now = osRealClock()
	local data = ply.data
	local lastClickTime = data.sandboxLastClickTime or 0

	if now - lastClickTime < 0.2 then
		return true
	end

	data.sandboxLastClickTime = now
	return false
end

local function clickedMenuButton (ply, id)
	local data = ply.data

	if id >= TOP_FLAG then
		id = id - TOP_FLAG
		clickedMenuTab(ply, id, data)
		return
	end

	if isClickRateLimited(ply) then return end

	local menuTab = data.sandboxMenuTab or 0
	if menuTab == 0 then
		clickedObject(ply, id)
	elseif menuTab == 1 then
		clickedBot(ply, id)
	elseif menuTab == 2 then
		clickedTeleport(ply, id)
	elseif menuTab == 3 then
		clickedTool(ply, id)
	elseif menuTab == 4 then
		clickedFriend(ply, id)
	elseif menuTab == 5 then
		clickedUtility(ply, id)
	end

	local man = ply.human
	if man then
		events.createSound(22, man.pos, 0.1, 2)
	end
end

---@param ply Player
local function clickedEnterCity (ply)
	if not ply.human then
		ply.model = 0

		local profile = util.getProfile(ply)
		local shirt = SHIRT_COLORS[profile.shirt or 1]
		ply.suitColor = shirt.color

		ply.tieColor = 0
		ply.team = 17

		local pos = Vector(1387 + nSpawn, 49.1, 1462)
		local man = humans.create(pos, orientations.n, ply)
		if man then
			if not hook.run('EventUpdatePlayer', ply) then
				ply:update()
				hook.run('PostEventUpdatePlayer', ply)
			end

			man.data.sandboxCreatorPhone = ply.phoneNumber
			for i = 0, 15 do
				local body = man:getRigidBody(i)
				body.data.sandboxCreatorPhone = ply.phoneNumber
			end

			nSpawn = (nSpawn + 1) % 64
		end
	end
end

mode:addHook(
	'PlayerActions',
	---@param ply Player
	function (ply)
		if ply.numActions ~= ply.lastNumActions then
			local action = ply:getAction(ply.lastNumActions)

			if action.type == 0 then
				if action.a == 14 then
					ply.lastNumActions = ply.numActions
					clickedMenuButton(ply, action.b)
				elseif action.a == 1 then
					clickedEnterCity(ply)
				end
			end
		end
	end
)

---@param ply Player
---@param man Human
local function handleControls (ply, man)
	if man.isAlive then
		man.stamina = 127
		man.maxStamina = 127

		local data = man.data

		local flags = man.inputFlags
		local lastFlags = data.sandboxLastInputFlags or 0
		data.sandboxLastInputFlags = man.inputFlags

		if not man:getInventorySlot(0).primaryItem and not man:getInventorySlot(1).primaryItem and not man.vehicle then
			local andLeft = bit32.band(flags, 1)
			local andRight = bit32.band(flags, 2)
			local andE = bit32.band(flags, 2048)

			if andLeft ~= bit32.band(lastFlags, 1) then
				if andLeft ~= 0 then
					if not isClickRateLimited(ply) then
						data.sandboxLeftDown = true
						util.invokeTool(tools, 'onLeftDown', true, ply, man)
					end
				elseif data.sandboxLeftDown then
					data.sandboxLeftDown = false
					util.invokeTool(tools, 'onLeftUp', true, ply, man)
				end
			elseif andLeft ~= 0 and data.sandboxLeftDown then
				util.invokeTool(tools, 'onLeftHeld', false, ply, man)
			end

			if andRight ~= bit32.band(lastFlags, 2) then
				if andRight ~= 0 then
					if not isClickRateLimited(ply) then
						data.sandboxRightDown = true
						util.invokeTool(tools, 'onRightDown', true, ply, man)
					end
				elseif data.sandboxRightDown then
					data.sandboxRightDown = false
					util.invokeTool(tools, 'onRightUp', true, ply, man)
				end
			elseif andRight ~= 0 and data.sandboxRightDown then
				util.invokeTool(tools, 'onRightHeld', false, ply, man)
			end

			if andE ~= bit32.band(lastFlags, 2048) then
				if andE ~= 0 then
					data.sandboxEDown = true
					util.invokeTool(tools, 'onEDown', false, ply, man)
				elseif data.sandboxEDown then
					data.sandboxEDown = false
					util.invokeTool(tools, 'onEUp', false, ply, man)
				end
			elseif andE ~= 0 and data.sandboxEDown then
				util.invokeTool(tools, 'onEHeld', false, ply, man)
			end

			man.lastInputFlags = man.inputFlags
		else
			util.abortTools(tools, man)
		end

		local andDelete = bit32.band(flags, 262144)
		if andDelete ~= bit32.band(lastFlags, 262144) then
			if andDelete ~= 0 then
				if not isClickRateLimited(ply) then
					local worked, action = clickedUndo(ply)
					if worked then
						ply:sendMessage('Undone ' .. action.name)
					end
					util.sound(worked and 'general' or 'error', man.pos)
				end
			end
		end
	else
		util.abortTools(tools, man)
	end
end

mode:addHook(
	'Physics',
	function ()
		for _, ply in ipairs(playersGetNonBots()) do
			local man = ply.human
			if man then
				handleControls(ply, man)
			end
		end
	end
)
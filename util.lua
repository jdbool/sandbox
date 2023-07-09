---@type Plugin
local mode = ...

local util = {}

local ipairs = ipairs
local tostring = tostring
local isActive = isActive
local osRealClock = os.realClock
local bondsGetAll = bonds.getAll
local playersGetAll = players.getAll
local humansGetAll = humans.getAll
local vehiclesGetAll = vehicles.getAll
local itemsGetAll = items.getAll
local physicsLineIntersectLevel = physics.lineIntersectLevel
local physicsLineIntersectLevelQuick = physics.lineIntersectLevelQuick
local physicsLineIntersectHuman = physics.lineIntersectHuman
local physicsLineIntersectHumanQuick = physics.lineIntersectHumanQuick
local physicsLineIntersectVehicle = physics.lineIntersectVehicle
local physicsLineIntersectVehicleQuick = physics.lineIntersectVehicleQuick
local physicsLineIntersectTriangle = physics.lineIntersectTriangle

local json = require 'main.json'

local PROFILES_FILE = 'sandbox-profiles.json'
local profiles = {}
local profilesDirty = false

function util.saveProfiles ()
	local f = io.open(PROFILES_FILE, 'w')
	if f then
		f:write(json.encode(profiles))
		f:close()
		mode:print('Profiles saved')
	end
end

function util.setProfilesDirty ()
	profilesDirty = true
end

function util.saveProfilesIfDirty ()
	if profilesDirty then
		util.saveProfiles()
		profilesDirty = false
	end
end

function util.loadProfiles ()
	local f = io.open(PROFILES_FILE, 'r')
	if f then
		local data = json.decode(f:read('*all'))
		profiles = data

		f:close()
		mode:print('Profiles loaded')
	end
end

---@param phone integer
---@param friendPhone integer
---@return boolean hasFriendAdded
function util.hasFriendAdded (phone, friendPhone)
	local key = tostring(phone)
	local profile = profiles[key]
	if not profile then return false end

	local friends = profile.friends
	if not friends then return false end

	return friends[tostring(friendPhone)] and true or false
end

---@param aPhone integer
---@param bPhone integer
---@return boolean areMutualFriends
function util.areMutualFriends (aPhone, bPhone)
	return util.hasFriendAdded(aPhone, bPhone) and util.hasFriendAdded(bPhone, aPhone)
end

---@param ply Player
---@return table? profile
function util.getProfile (ply)
	if ply.isBot then
		return nil
	end

	local key = tostring(ply.phoneNumber)

	if not profiles[key] then
		profiles[key] = {
			createdAt = os.time()
		}
	end

	profiles[key].name = ply.name

	return profiles[key]
end

---@param kind string
---@param pos Vector
---@param pitchScale? number
---@param volumeScale? number
function util.sound (kind, pos, pitchScale, volumeScale)
	pitchScale = pitchScale or 1.0
	volumeScale = volumeScale or 1.0

	if kind == 'snap' then
		-- Magazine
		events.createSound(39, pos, 0.75 * volumeScale, 2.0 * pitchScale)
	elseif kind == 'general' then
		-- Bullet casing
		events.createSound(40, pos, 0.75 * volumeScale, 2.0 * pitchScale)
	elseif kind == 'error' then
		-- Gear shift
		events.createSound(41, pos, 0.75 * volumeScale, 2.0 * pitchScale)
	end
end

---@param ply Player
---@param action table
function util.addUndoAction (ply, action)
	local data = ply.data
	if not data.sandboxUndoQueue then
		data.sandboxUndoQueue = {}
	end

	local queue = data.sandboxUndoQueue

	action.time = osRealClock()
	table.insert(queue, action)

	while #queue > 255 do
		table.remove(queue, 1)
	end
end

---Erase all undos where key = value.
---@param key string
---@param value? any
function util.eraseUndosWhere (key, value)
	for _, ply in ipairs(playersGetAll()) do
		local queue = ply.data.sandboxUndoQueue
		if queue and #queue > 0 then
			for i = #queue, 1, -1 do
				if queue[i][key] == value then
					table.remove(queue, i)
				end
			end
		end
	end
end

---Erase all undos associated with an object.
---@param obj Human|Item|Vehicle
function util.eraseObjectBodyUndos (obj)
	if obj.class == 'Human' then
		for i = 0, 15 do
			local body = obj:getRigidBody(i)
			util.eraseUndosWhere('body', body)
		end
	else
		util.eraseUndosWhere('body', obj.rigidBody)
	end
end

---@param body RigidBody
---@return integer numBonds
function util.countBodyBonds (body)
	local numBonds = 0

	for _, bond in ipairs(bondsGetAll()) do
		if bond.body == body or ((bond.type == 7 or bond.type == 8) and bond.otherBody == body) then
			numBonds = numBonds + 1
		end
	end

	return numBonds
end

---Clear all bonds with associated bodies that no longer exist.
---@return integer numRemoved
function util.clearOrphanedBonds ()
	local numRemoved = 0

	for _, bond in ipairs(bondsGetAll()) do
		if not bond.body.isActive or ((bond.type == 7 or bond.type == 8) and not bond.otherBody.isActive) then
			bond.isActive = false
			util.eraseUndosWhere('bond', bond)
			numRemoved = numRemoved + 1
		end
	end

	return numRemoved
end

---Clear all bot players that don't have a human.
---@return integer numRemoved
function util.clearOrphanedBotPlayers ()
	local numRemoved = 0

	for _, ply in ipairs(playersGetAll()) do
		if ply.isBot and not isActive(ply.human) then
			ply:remove()
			numRemoved = numRemoved + 1
		end
	end

	return numRemoved
end

---Clear objects associated with a phone number.
---@param phone integer
---@param objectTable any[]
---@return integer numRemoved
function util.clearObjects (phone, objectTable)
	local numRemoved = 0

	for _, obj in ipairs(objectTable) do
		if obj.data.sandboxCreatorPhone == phone then
			numRemoved = numRemoved + 1
			util.eraseObjectBodyUndos(obj)
			obj:remove()
			util.eraseUndosWhere('obj', obj)
		end
	end

	if numRemoved > 0 then
		util.clearOrphanedBonds()
	end

	return numRemoved
end

---Clear bots associated with a phone number.
---@param phone integer
---@return integer numRemoved
function util.clearBots (phone)
	local numRemoved = 0

	for _, man in ipairs(humansGetAll()) do
		if man.data.sandboxCreatorPhone == phone then
			local ply = man.player
			if not ply or ply.isBot then
				numRemoved = numRemoved + 1
				util.eraseObjectBodyUndos(man)
				man:remove()
				util.eraseUndosWhere('obj', man)
			end
		end
	end

	if numRemoved > 0 then
		util.clearOrphanedBonds()
		util.clearOrphanedBotPlayers()
	end

	return numRemoved
end

---Check if a line intersects a quad on a box with a normal.
---@param outPos Vector The vector to be changed to the intersection position.
---@param pos Vector The origin of the box.
---@param normal Vector The normal of the quad.
---@param distX number
---@param distY number
---@param distZ number
---@param posA Vector The first point of the line.
---@param posB Vector The second point of the line.
---@return number? fraction
local function intersectBoxQuad(outPos, pos, normal, distX, distY, distZ, posA, posB)
	local vert0 = pos - distX + distY - distZ
	local vert1 = pos + distX + distY - distZ
	local vert2 = pos - distX + distY + distZ
	local vert3 = pos + distX + distY + distZ

	local fraction = physicsLineIntersectTriangle(
		outPos,
		normal,
		posA, posB,
		vert0, vert1, vert2
	)
	if fraction then return fraction end

	return physicsLineIntersectTriangle(
		outPos,
		normal,
		posA, posB,
		vert3, vert2, vert1
	)
end

---Check if a line intersects an item's bounding box.
---@param item Item
---@param posA Vector The first point of the line.
---@param posB Vector The second point of the line.
---@return number? fraction
---@return Vector? pos
---@return Vector? normal
local function intersectItem(item, posA, posB)
	local center = item.type.boundsCenter

	local pos = item.pos
	local rot = item.rot

	local normalX = Vector(rot.x1, rot.y1, rot.z1)
	local normalY = Vector(rot.x2, rot.y2, rot.z2)
	local normalZ = Vector(rot.x3, rot.y3, rot.z3)

	local distX = normalX * center.x
	local distY = normalY * center.y
	local distZ = normalZ * center.z

	local outPos = Vector()

	local fraction = intersectBoxQuad(outPos, pos, normalX, -distY, distX, distZ, posA, posB)
	if fraction then return fraction, outPos, normalX end

	fraction = intersectBoxQuad(outPos, pos, -normalX, -distY, -distX, -distZ, posA, posB)
	if fraction then return fraction, outPos, -normalX end

	fraction = intersectBoxQuad(outPos, pos, normalY, distX, distY, distZ, posA, posB)
	if fraction then return fraction, outPos, normalY end

	fraction = intersectBoxQuad(outPos, pos, -normalY, -distX, -distY, distZ, posA, posB)
	if fraction then return fraction, outPos, -normalY end

	fraction = intersectBoxQuad(outPos, pos, normalZ, distX, distZ, -distY, posA, posB)
	if fraction then return fraction, outPos, normalZ end

	fraction = intersectBoxQuad(outPos, pos, -normalZ, distX, -distZ, distY, posA, posB)
	if fraction then return fraction, outPos, -normalZ end
end

---Check if a line intersects an item's bounding box quickly.
---@param item Item
---@param posA Vector The first point of the line.
---@param posB Vector The second point of the line.
---@return number? fraction
local function intersectItemQuick(item, posA, posB)
	local pos = item.pos

	if (
		posA.x - 4 > pos.x
		and posB.x - 4 > pos.x
	)
	or (
		posA.y - 4 > pos.y
		and posB.y - 4 > pos.y
	)
	or (
		posA.z - 4 > pos.z
		and posB.z - 4 > pos.z
	)
	or (
		posA.x + 4 < pos.x
		and posB.x + 4 < pos.x
	)
	or (
		posA.y + 4 < pos.y
		and posB.y + 4 < pos.y
	)
	or (
		posA.z + 4 < pos.z
		and posB.z + 4 < pos.z
	) then
		return nil
	end


	local center = item.type.boundsCenter

	local rot = item.rot

	local normalX = Vector(rot.x1, rot.y1, rot.z1)
	local normalY = Vector(rot.x2, rot.y2, rot.z2)
	local normalZ = Vector(rot.x3, rot.y3, rot.z3)

	local distX = normalX * center.x
	local distY = normalY * center.y
	local distZ = normalZ * center.z

	local outPos = Vector()

	local fraction = intersectBoxQuad(outPos, pos, normalX, -distY, distX, distZ, posA, posB)
	if fraction then return fraction end

	fraction = intersectBoxQuad(outPos, pos, -normalX, -distY, -distX, -distZ, posA, posB)
	if fraction then return fraction end

	fraction = intersectBoxQuad(outPos, pos, normalY, distX, distY, distZ, posA, posB)
	if fraction then return fraction end

	fraction = intersectBoxQuad(outPos, pos, -normalY, -distX, -distY, distZ, posA, posB)
	if fraction then return fraction end

	fraction = intersectBoxQuad(outPos, pos, normalZ, distX, distZ, -distY, posA, posB)
	if fraction then return fraction end

	fraction = intersectBoxQuad(outPos, pos, -normalZ, distX, -distZ, distY, posA, posB)
	return fraction
end

---Find the nearest thing that a ray hits.
---@param man? Human
---@param posA Vector
---@param posB Vector
---@return any?
function util.lineIntersectAllQuick (man, posA, posB)
	local fraction = 4096
	local object

	do
		local frac = physicsLineIntersectLevelQuick(posA, posB, false)
		if frac and frac < fraction then
			fraction = frac
		end
	end

	for _, human in ipairs(humansGetAll()) do
		if human ~= man then
			local frac = physicsLineIntersectHumanQuick(human, posA, posB, 0.0)
			if frac and frac < fraction then
				fraction = frac
				object = human
			end
		end
	end

	for _, vcl in ipairs(vehiclesGetAll()) do
		local frac = physicsLineIntersectVehicleQuick(vcl, posA, posB, false)
		if frac and frac < fraction then
			fraction = frac
			object = vcl
		end
	end

	for _, item in ipairs(itemsGetAll()) do
		if item.hasPhysics or item.physicsSettled then
			local frac = intersectItemQuick(item, posA, posB)
			if frac and frac < fraction then
				fraction = frac
				object = item
			end
		end
	end

	return object
end

---Find the nearest thing that a ray hits.
---@param man? Human
---@param posA Vector
---@param posB Vector
---@param withoutLevel? boolean
---@return table
function util.lineIntersectAll (man, posA, posB, withoutLevel)
	local hitRays = {}

	local ray

	if not withoutLevel then
		ray = physicsLineIntersectLevel(posA, posB, false)
		if ray.hit then
			ray.type = 'level'
			table.insert(hitRays, ray)
		end
	end

	for _, human in ipairs(humans.getAll()) do
		if human ~= man then
			ray = physicsLineIntersectHuman(human, posA, posB, 0.0)
			if ray.hit then
				ray.obj = human
				ray.type = 'human'
				table.insert(hitRays, ray)
			end
		end
	end

	for _, vcl in ipairs(vehicles.getAll()) do
		ray = physicsLineIntersectVehicle(vcl, posA, posB, false)
		if ray.hit then
			ray.obj = vcl
			ray.type = 'vehicle'
			table.insert(hitRays, ray)
		end
	end

	for _, item in ipairs(items.getAll()) do
		if item.hasPhysics or item.physicsSettled then
			local fraction, pos, normal = intersectItem(item, posA, posB)
			if fraction then
				table.insert(hitRays, {
					pos = pos,
					normal = normal,
					fraction = fraction,
					hit = true,
					obj = item,
					type = 'item'
				})
			end
		end
	end

	table.sort(hitRays, function(a, b)
		return a.fraction < b.fraction
	end)

	return hitRays[1] or { hit = false }
end

local utilLineIntersectAll = util.lineIntersectAll

---Run a tool function.
---@param tools table[]
---@param functionName string
---@param doRay boolean
---@param ply Player
---@param man Human
function util.invokeTool (tools, functionName, doRay, ply, man)
	local data = ply.data
	local toolID = data.sandboxTool
	if not toolID or toolID == 0 then return end

	local tool = tools[toolID]
	if tool[functionName] then
		local ray = doRay and utilLineIntersectAll(man, getEyeLine(man, 2048)) or nil
		tool[functionName](ply, man, data, ray)
	end
end

---Abort tool use and call the release function.
---@param tools table[]
---@param man Human
function util.abortTools (tools, man)
	local ply = man.player
	if ply then
		local data = man.data
		if data.sandboxLeftDown then
			data.sandboxLeftDown = nil
			util.invokeTool(tools, 'onLeftUp', true, ply, man)
		end
		if data.sandboxRightDown then
			data.sandboxRightDown = nil
			util.invokeTool(tools, 'onRightUp', true, ply, man)
		end
		if data.sandboxEDown then
			data.sandboxEDown = nil
			util.invokeTool(tools, 'onEUp', false, ply, man)
		end
	end
end

---@param ply Player
---@param man Human
---@param owner? Player
function util.alertNotFriend (ply, man, owner)
	if owner then
		ply:sendMessage(string.format('%s (%s) has not added you as a friend', owner.name, dashPhoneNumber(owner.phoneNumber)))
	end
	util.sound('error', man.pos)
end

local utilAlertNotFriend = util.alertNotFriend

---@param ply Player
---@param man Human
---@param ownerPhone integer
function util.alertNotFriendInfrequently (ply, man, ownerPhone)
	local now = osRealClock()
	local data = ply.data
	local lastAlertTime = data.sandboxLastAlertTime or 0

	if now - lastAlertTime >= 2 then
		data.sandboxLastAlertTime = now
		utilAlertNotFriend(ply, man, players.getByPhone(ownerPhone))
	end
end

return util
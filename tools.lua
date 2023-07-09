---@type Plugin
local mode = ...

local tools = {}

local util = mode:require('util')

local utilGetProfile = util.getProfile
local utilAlertNotFriend = util.alertNotFriend

local BODY_BOND_LIMIT = 8
local BONE_NAMES = {
	[0] = 'Crotch',
	[1] = 'Stomach',
	[2] = 'Chest',
	[3] = 'Head',
	[4] = 'Left Arm',
	[5] = 'Left Forearm',
	[6] = 'Left Hand',
	[7] = 'Right Arm',
	[8] = 'Right Forearm',
	[9] = 'Right Hand',
	[10] = 'Left Thigh',
	[11] = 'Left Shin',
	[12] = 'Left Foot',
	[13] = 'Right Thigh',
	[14] = 'Right Shin',
	[15] = 'Right Foot',
}

local function getLocalOffset (body, pos)
	local globalOffset = pos - body.pos
	return globalOffset * body.rot
end

local function resolveBody (ray)
	local type = ray.type
	local obj = ray.obj

	if type == 'human' then
		if obj.isActive then
			return obj:getRigidBody(ray.bone), BONE_NAMES[ray.bone]
		end
	elseif type == 'vehicle' then
		if obj.isActive then
			return obj.rigidBody, 'Vehicle'
		end
	elseif type == 'item' then
		if obj.isActive then
			obj.hasPhysics = true
			obj.physicsSettled = false
			obj.physicsSettledTimer = 0
			obj.rigidBody.isSettled = false

			return obj.rigidBody, 'Item'
		end
	end

	return nil, 'Level'
end

local function checkPermissions (ply, obj)
	local playerToCheck
	local phone = obj.data.sandboxCreatorPhone

	if phone then
		playerToCheck = players.getByPhone(phone)
	end

	if not playerToCheck or playerToCheck.isBot then
		return false
	end

	if playerToCheck == ply then
		return true, playerToCheck
	end

	local theirProfile = utilGetProfile(playerToCheck)
	local theirFriends = theirProfile.friends

	if not theirFriends or not theirFriends[tostring(ply.phoneNumber)] then
		return false, playerToCheck
	end

	return true, playerToCheck
end

table.insert(tools, {
	name = 'Grabber',
	usage = 'Hold left click to grab objects, right click to place a pin',
	onLeftDown = function (ply, man, data, ray)
		local body, bodyName = resolveBody(ray)

		if body then
			local hasPermission, owner = checkPermissions(ply, ray.obj)
			if not hasPermission then
				utilAlertNotFriend(ply, man, owner)
				return
			end

			if util.countBodyBonds(body) < BODY_BOND_LIMIT then
				local localPos = getLocalOffset(body, ray.pos)
				local bond = body:bondToLevel(localPos, ray.pos)
				if bond then
					data.sandboxGrabbingBond = bond
					data.sandboxGrabbingRay = ray
					local distance = man:getRigidBody(3).pos:dist(ray.pos)
					data.sandboxGrabbingDist = distance

					ply:sendMessage('Grabbing "' .. bodyName .. '"')
					util.sound('snap', man.pos)
				end
			else
				ply:sendMessage('[ X ] Body has too many bonds')
				util.sound('error', man.pos)
			end
		else
			util.sound('error', man.pos)
		end
	end,
	onLeftUp = function (_, man, data)
		local bond = data.sandboxGrabbingBond
		if bond then
			bond.isActive = false
			data.sandboxGrabbingBond = nil
			data.sandboxGrabbingRay = nil
			data.sandboxGrabbingDist = nil

			util.sound('snap', man.pos, 0.95)
		end
		data.sandboxGrabbingRot = nil
	end,
	onLeftHeld = function (_, man, data)
		local bond = data.sandboxGrabbingBond
		if bond then
			local distance = data.sandboxGrabbingDist
			local _, posB = getEyeLine(man, distance)
			bond.globalPos = posB
		end
	end,
	onRightDown = function (ply, man, data)
		local bond = data.sandboxGrabbingBond
		if bond then
			local _, bodyName = resolveBody(data.sandboxGrabbingRay)

			data.sandboxGrabbingBond = nil

			ply:sendMessage('Pinned "' .. bodyName .. '" (undo-able)')
			util.sound('snap', man.pos)

			util.addUndoAction(ply, {
				bond = bond,
				name = 'Pin'
			})
		end
	end
})

table.insert(tools, {
	name = 'Holder',
	usage = 'Hold left click to hold objects, right click to freeze, E + WASD to rotate',
	onLeftDown = function (ply, man, data, ray)
		local body, bodyName = resolveBody(ray)

		if body then
			local hasPermission, owner = checkPermissions(ply, ray.obj)
			if not hasPermission then
				utilAlertNotFriend(ply, man, owner)
				return
			end

			if util.countBodyBonds(body) < BODY_BOND_LIMIT then
				local localPos = getLocalOffset(body, ray.pos)
				local bond = body:bondToLevel(localPos, ray.pos)
				if bond then
					body.isSettled = false
					local bodyData = body.data
					bodyData.sandboxFreezePos = nil
					bodyData.sandboxFreezeRot = nil

					data.sandboxGrabbingBody = body
					data.sandboxGrabbingBond = bond
					data.sandboxGrabbingRay = ray
					local distance = man:getRigidBody(3).pos:dist(ray.pos)
					data.sandboxGrabbingDist = distance
					data.sandboxGrabbingRot = body.rot:clone()

					ply:sendMessage('Holding "' .. bodyName .. '"')
					util.sound('snap', man.pos)
				end
			else
				ply:sendMessage('[ X ] Body has too many bonds')
				util.sound('error', man.pos)
			end
		else
			util.sound('error', man.pos)
		end
	end,
	onLeftUp = function (_, man, data)
		local bond = data.sandboxGrabbingBond
		if bond then
			bond.isActive = false
			data.sandboxGrabbingBond = nil
			data.sandboxGrabbingRay = nil
			data.sandboxGrabbingDist = nil

			util.sound('snap', man.pos, 0.95)
		end
		data.sandboxGrabbingRot = nil
	end,
	onLeftHeld = function (_, man, data)
		local bond = data.sandboxGrabbingBond
		if bond then
			local distance = data.sandboxGrabbingDist
			local _, posB = getEyeLine(man, distance)
			bond.globalPos = posB

			local body = data.sandboxGrabbingBody
			body.rot:set(data.sandboxGrabbingRot)
			body.rotVel:set(RotMatrix())
		end
	end,
	onRightDown = function (ply, man, data)
		local bond = data.sandboxGrabbingBond
		if bond then
			local body = data.sandboxGrabbingBody
			local bodyData = body.data
			bodyData.sandboxFreezePos = body.pos
			bodyData.sandboxFreezeRot = body.rot

			bond.isActive = false

			data.sandboxGrabbingBond = nil
			data.sandboxGrabbingRay = nil
			data.sandboxGrabbingDist = nil
		end
	end,
	onEDown = function (ply, man, data)
		man.inputFlags = 0
	end,
	onEHeld = function (ply, man, data)
		local rot = data.sandboxGrabbingRot
		if rot then
			local walkInput = man.walkInput
			local strafeInput = man.strafeInput

			local speed = 2

			if walkInput ~= 0 then
				man.walkInput = 0
				local add = pitchToRotMatrix(walkInput / server.TPS * speed)
				rot = rot * add
				data.sandboxGrabbingRot = rot
			end

			if strafeInput ~= 0 then
				man.strafeInput = 0
				local add = yawToRotMatrix(strafeInput / server.TPS * speed)
				rot = rot * add
				data.sandboxGrabbingRot = rot
			end
		end
		man.inputFlags = 0
	end,
	onEUp = function (ply, man, data)
		man.inputFlags = 0
	end
})

table.insert(tools, {
	name = 'Remover',
	usage = 'Left click to remove objects',
	onLeftDown = function (ply, man, _, ray)
		if ray.obj then
			local hasPermission, owner = checkPermissions(ply, ray.obj)
			if not hasPermission then
				utilAlertNotFriend(ply, man, owner)
				return
			end

			if ray.type == 'human' then
				util.abortTools(tools, ray.obj)
			end
			util.eraseObjectBodyUndos(ray.obj)
			ray.obj:remove()
			util.eraseUndosWhere('obj', ray.obj)
			util.clearOrphanedBonds()
			util.clearOrphanedBotPlayers()
			ply:sendMessage('Removed a ' .. ray.type)
			util.sound('general', man.pos)
		else
			util.sound('error', man.pos)
		end
	end
})

table.insert(tools, {
	name = 'Bond',
	usage = 'Left click to bond two objects together, right click to reset first selection',
	onEquip = function (_, _, data)
		data.sandboxBondingFirst = nil
	end,
	onLeftDown = function (ply, man, data, ray)
		if not ray.hit then
			util.sound('error', man.pos)
			return
		end

		local body, bodyName = resolveBody(ray)

		if body then
			local hasPermission, owner = checkPermissions(ply, ray.obj)
			if not hasPermission then
				utilAlertNotFriend(ply, man, owner)
				return
			end

			if util.countBodyBonds(body) >= BODY_BOND_LIMIT then
				ply:sendMessage('[ X ] Body has too many bonds')
				util.sound('error', man.pos)
				return
			end
		end

		if not data.sandboxBondingFirst then
			data.sandboxBondingFirst = ray
			ply:sendMessage('Selected "' .. bodyName .. '", select another')
			util.sound('general', man.pos)
		else
			local firstRay = data.sandboxBondingFirst
			local firstBody, firstBodyName = resolveBody(firstRay)
			local bond

			if firstBody == body then
				ply:sendMessage("[ X ] Can't be the same, select something else")
				util.sound('error', man.pos)
				return
			elseif firstBody and util.countBodyBonds(firstBody) >= BODY_BOND_LIMIT then
				ply:sendMessage('[ X ] First body has too many bonds')
				util.sound('error', man.pos)
				return
			end

			if firstBody and body then
				local firstLocal = getLocalOffset(firstBody, firstRay.pos)
				local secondLocal = getLocalOffset(body, ray.pos)

				bond = firstBody:bondTo(body, firstLocal, secondLocal)
			elseif firstRay.type == 'vehicle' or ray.type == 'vehicle' then
				ply:sendMessage("[ X ] Can't bond vehicles to the level, select something else")
				util.sound('error', man.pos)
				return
			else
				local bondBody
				local bondLocalPos
				local bondGlobalPos
				local bondGlobalNormal

				if firstBody then
					bondBody = firstBody
					bondLocalPos = getLocalOffset(firstBody, firstRay.pos)
					bondGlobalPos = ray.pos
					bondGlobalNormal = ray.normal
				else
					bondBody = body
					bondLocalPos = getLocalOffset(body, ray.pos)
					bondGlobalPos = firstRay.pos
					bondGlobalNormal = ray.normal
				end

				bondGlobalNormal = bondGlobalNormal:clone()
				bondGlobalNormal:mult(0.05)
				bondLocalPos = bondLocalPos:clone()
				bondLocalPos:add(bondGlobalNormal)

				bond = bondBody:bondToLevel(bondLocalPos, bondGlobalPos)
			end

			data.sandboxBondingFirst = nil

			if not bond then
				util.sound('error', man.pos)
				return
			end

			ply:sendMessage('Bonded "' .. firstBodyName .. '" to "' .. bodyName .. '" (undo-able)')
			util.sound('snap', man.pos)

			util.addUndoAction(ply, {
				bond = bond,
				name = 'Bond'
			})
		end
	end,
	onRightDown = function (ply, man, data, _)
		if data.sandboxBondingFirst then
			data.sandboxBondingFirst = nil
			ply:sendMessage('Selection cleared')
			util.sound('general', man.pos)
		end
	end
})

table.insert(tools, {
	name = 'Mass',
	usage = 'Left click double mass, right click to halve',
	onLeftDown = function (ply, man, _, ray)
		local body, bodyName = resolveBody(ray)

		if body then
			local hasPermission, owner = checkPermissions(ply, ray.obj)
			if not hasPermission then
				utilAlertNotFriend(ply, man, owner)
				return
			end

			local before = body.mass
			local after = before * 2
			if after < 100000 then
				body.mass = after

				ply:sendMessage('Increased mass of "' .. bodyName .. '" to ' .. body.mass .. ' (undo-able)')
				util.sound('general', man.pos)

				util.addUndoAction(ply, {
					body = body,
					mass = before,
					name = 'Increase Mass'
				})
			else
				util.sound('error', man.pos)
			end
		else
			util.sound('error', man.pos)
		end
	end,
	onRightDown = function (ply, man, _, ray)
		local body, bodyName = resolveBody(ray)

		if body then
			local hasPermission, owner = checkPermissions(ply, ray.obj)
			if not hasPermission then
				utilAlertNotFriend(ply, man, owner)
				return
			end

			local min = ray.obj.class == 'Vehicle' and 8 or 0.01

			local before = body.mass
			local after = before * 0.5
			if after > min then
				body.mass = after

				ply:sendMessage('Decreased mass of "' .. bodyName .. '" to ' .. body.mass .. ' (undo-able)')
				util.sound('general', man.pos, 0.9)

				util.addUndoAction(ply, {
					body = body,
					mass = before,
					name = 'Decrease Mass'
				})
			else
				util.sound('error', man.pos)
			end
		else
			util.sound('error', man.pos)
		end
	end
})

table.insert(tools, {
	name = 'Ghost',
	usage = 'Left click to disable collisions with all other objects, right click to enable',
	onLeftDown = function (ply, man, _, ray)
		local body, bodyName = resolveBody(ray)

		if body then
			local hasPermission, owner = checkPermissions(ply, ray.obj)
			if not hasPermission then
				utilAlertNotFriend(ply, man, owner)
				return
			end

			if not body.data.sandboxNoCollideAll then
				body.data.sandboxNoCollideAll = true

				ply:sendMessage('Ghosted "' .. bodyName .. '" (undo-able)')

				util.addUndoAction(ply, {
					body = body,
					noCollideAll = false,
					name = 'Ghost'
				})
				util.sound('general', man.pos)
			else
				util.sound('error', man.pos)
			end
		else
			util.sound('error', man.pos)
		end
	end,
	onRightDown = function (ply, man, _, ray)
		local body, bodyName = resolveBody(ray)

		if body then
			local hasPermission, owner = checkPermissions(ply, ray.obj)
			if not hasPermission then
				utilAlertNotFriend(ply, man, owner)
				return
			end

			if body.data.sandboxNoCollideAll then
				body.data.sandboxNoCollideAll = nil

				ply:sendMessage('Un-ghosted "' .. bodyName .. '" (undo-able)')

				util.addUndoAction(ply, {
					body = body,
					noCollideAll = true,
					name = 'Un-Ghost'
				})
				util.sound('general', man.pos)
			else
				util.sound('error', man.pos)
			end
		else
			util.sound('error', man.pos)
		end
	end
})

table.insert(tools, {
	name = 'Teleport',
	usage = 'Left click to teleport',
	onLeftDown = function (_, man, _, ray)
		if ray.hit then
			local pos = ray.pos:clone()
			local normal = ray.normal:clone()
			pos:add(normal)
			man:teleport(pos)
			util.sound('general', man.pos)
		else
			util.sound('error', man.pos)
		end
	end
})

table.insert(tools, {
	name = 'Suicide',
	usage = 'Left click to die',
	onLeftDown = function (_, man)
		man.isAlive = false
		util.sound('general', man.pos)
	end
})

return tools
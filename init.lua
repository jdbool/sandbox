---@type Plugin
local mode = ...
mode.name = 'Sandbox'
mode.author = 'jdb'
mode.description = 'Do whatever.'

local server = server
local vehiclesGetAll = vehicles.getAll
local itemsGetAll = items.getAll
local humansGetAll = humans.getAll
local bulletsGetAll = bullets.getAll
local rigidBodiesGetAll = rigidBodies.getAll
local physicsLineIntersectAnyQuick = physics.lineIntersectAnyQuick

local HOOK_OVERRIDE = hook.override

local SAVE_PROFILES_TICKS = server.TPS * 6
-- local SUN_SPEED = 100
-- local TIME_MIDNIGHT = server.TPS * 60 * 60 * 24

local saveProfilesTicks

mode:require('reset')
mode:require('menu')
local util = mode:require('util')
local tools = mode:require('tools')

local utilAreMutualFriends = util.areMutualFriends
local utilHasFriendAdded = util.hasFriendAdded
local utilLineIntersectAllQuick = util.lineIntersectAllQuick
local utilAlertNotFriendInfrequently = util.alertNotFriendInfrequently

function mode.onEnable (isReload)
	util.loadProfiles()
	saveProfilesTicks = 0
	if not isReload then
		server:reset()
	end
end

function mode.onDisable ()
	saveProfilesTicks = nil
end

mode:addHook(
	'Logic',
	function ()
		saveProfilesTicks = saveProfilesTicks + 1
		if saveProfilesTicks >= SAVE_PROFILES_TICKS then
			saveProfilesTicks = 0
			util.saveProfilesIfDirty()
		end

		-- server.sunTime = (server.sunTime + SUN_SPEED) % TIME_MIDNIGHT
	end
)

mode:addHook(
	'ServerReceive',
	function ()
		server.type = TYPE_WORLD
	end
)

mode:addHook(
	'PostServerReceive',
	function ()
		server.type = 20
	end
)

-- Global text chat
function mode.hooks.PlayerChat (ply, message)
	if message:gsub('%W',''):lower():find('nigge') then
		message = "i'm an idiot"
	end

	local str = string.format('<%s> %s', ply.name, message)
	chat.announceWrap(str)

	local man = ply.human
	if man then
		man:speak(message, 1)
	end

	if log then
		log('[Chat][G] %s (%s): %s', ply.name, dashPhoneNumber(ply.phoneNumber), message)
	end

	return HOOK_OVERRIDE
end

function mode.hooks.HumanDelete (man)
	util.abortTools(tools, man)
end

function mode.hooks.PostHumanDelete (man)
	util.eraseUndosWhere('obj', man)
	util.clearOrphanedBonds()
	util.clearOrphanedBotPlayers()
end

function mode.hooks.PlayerDelete (ply)
	if ply.isBot then return end

	local man = ply.human
	if man then
		util.abortTools(tools, man)
		util.eraseObjectBodyUndos(man)
		man:remove()
		util.clearOrphanedBonds()
	end

	local phone = ply.phoneNumber
	util.clearObjects(phone, vehiclesGetAll())
	util.clearObjects(phone, itemsGetAll())
	util.clearBots(phone)
end

local tpaRequests = {}

mode.commands['/tpa'] = {
	info = "Teleport to somebody.",
	---@param ply Player
	---@param man Human?
	---@param args string[]
	call = function (ply, man, args)
		if not man or args[1] == nil then return end

		local victimPly = findOnePlayer(table.concat(args, ' '))

		assert(victimPly ~= ply, 'You cannot teleport to yourself')

		local victimMan = victimPly.human
		if not victimMan then
			error(string.format('%s is not spawned in', victimPly.name))
		end

		victimPly:sendMessage(string.format('%s has requested to teleport to you!', ply.name))
		victimPly:sendMessage('Type /tpaccept to accept.')
		tpaRequests[victimPly.phoneNumber] = ply.phoneNumber
		ply:sendMessage('Request sent.')
	end
}

mode.commands['/tpaccept'] = {
	info = "Accept a teleport request.",
	---@param victimPly Player
	---@param victimMan Human?
	call = function (victimPly, victimMan)
		if not victimMan then return end

		local ply = players.getByPhone(tpaRequests[victimPly.phoneNumber])
		assert(ply, 'No teleport requst found')

		local man = ply.human
		assert(man, string.format('%s is not spawned in.', ply.name))

		if man.vehicle then
			man.vehicle = nil
		end

		tpaRequests[victimPly.phoneNumber] = nil
		local pos = victimMan.pos:clone()
		pos.x = pos.x + 1
		pos.y = pos.y + 0.2
		man:teleport(pos)
		man:setVelocity(Vector())
	end
}

mode:addHook(
	'Physics',
	function ()
		local origin = Vector()

		for _, vcl in ipairs(vehiclesGetAll()) do
			local speed = vcl.vel:distSquare(origin)
			if speed > 4 then
				util.eraseObjectBodyUndos(vcl)
				vcl:remove()
				util.eraseUndosWhere('obj', vcl)
				util.clearOrphanedBonds()
			end
		end

		for _, item in ipairs(itemsGetAll()) do
			if item.hasPhysics or item.physicsSettled then
				local speed = item.vel:distSquare(origin)
				if speed > 4 then
					util.eraseObjectBodyUndos(item)
					item:remove()
					util.eraseUndosWhere('obj', item)
					util.clearOrphanedBonds()
				elseif item.data.sandboxCreatorPhone then
					item.despawnTime = 65536
				end
			end
		end

		for _, man in ipairs(humansGetAll()) do
			local speed = man:getRigidBody(0).vel:distSquare(origin)
			if speed > 4 then
				util.abortTools(tools, man)
				util.eraseObjectBodyUndos(man)
				man:remove()
				util.eraseUndosWhere('obj', man)
				util.clearOrphanedBonds()
				util.clearOrphanedBotPlayers()
			elseif man.data.sandboxRagdoll then
				man.despawnTime = 65536
			end
		end

		for _, body in ipairs(rigidBodiesGetAll()) do
			local data = body.data
			local pos = data.sandboxFreezePos
			if pos then
				body.isSettled = true
				body.pos:set(pos)
				body.vel:set(Vector())
				body.rot:set(data.sandboxFreezeRot)
				body.rotVel:set(RotMatrix())
			end
		end
	end
)

function mode.hooks.CollideBodies (aBody, bBody)
	local aData = aBody.data
	local bData = bBody.data

	if aData.sandboxNoCollideAll or bData.sandboxNoCollideAll then
		return HOOK_OVERRIDE
	end

	local aPhone = aData.sandboxCreatorPhone
	if not aPhone then return HOOK_OVERRIDE end

	local bPhone = bData.sandboxCreatorPhone
	if not bPhone then return HOOK_OVERRIDE end

	if aPhone == bPhone then return end

	if utilAreMutualFriends(aPhone, bPhone) then return end

	return HOOK_OVERRIDE
end

function mode.hooks.ItemLink (item, _, parentHuman)
	if item and parentHuman then
		local itemPhone = item.data.sandboxCreatorPhone
		if itemPhone then
			local manPhone = parentHuman.data.sandboxCreatorPhone
			if manPhone then
				if itemPhone ~= manPhone and not utilHasFriendAdded(itemPhone, manPhone) then
					local ply = parentHuman.player
					if ply then
						utilAlertNotFriendInfrequently(ply, parentHuman, itemPhone)
					end
					return HOOK_OVERRIDE
				end
			end
		end
	end
end

function mode.hooks.HumanGrabbing (man)
	local phone = man.data.sandboxCreatorPhone
	if not phone then return end

	if man.rightHandGrab then
		local otherPhone = man.rightHandGrab.data.sandboxCreatorPhone
		if otherPhone and otherPhone ~= phone and not utilHasFriendAdded(otherPhone, phone) then
			man.rightHandGrab = nil
			local ply = man.player
			if ply then
				utilAlertNotFriendInfrequently(ply, man, otherPhone)
			end
		end
	end

	if man.leftHandGrab then
		local otherPhone = man.leftHandGrab.data.sandboxCreatorPhone
		if otherPhone and otherPhone ~= phone and not utilHasFriendAdded(otherPhone, phone) then
			man.leftHandGrab = nil
			local ply = man.player
			if ply then
				utilAlertNotFriendInfrequently(ply, man, otherPhone)
			end
		end
	end
end

function mode.hooks.HumanCollisionVehicle (man, vcl)
	local phone = man.data.sandboxCreatorPhone
	if not phone then return end

	local vclPhone = vcl.data.sandboxCreatorPhone
	if not vclPhone then return end

	if phone ~= vclPhone and not utilHasFriendAdded(phone, vclPhone) then
		local ply = man.player
		if ply then
			utilAlertNotFriendInfrequently(ply, man, vclPhone)
		end
		return HOOK_OVERRIDE
	end
end

function mode.hooks.PhysicsBullets ()
	local doGC = false
	for _, bullet in ipairs(bulletsGetAll()) do
		local ply = bullet.player
		local man = ply.human
		if man then
			local obj = physicsLineIntersectAnyQuick(bullet.lastPos, bullet.lastPos + bullet.vel, man)
			if obj then
				local phone = man.data.sandboxCreatorPhone
				if phone then
					local objPhone = obj.data.sandboxCreatorPhone
					if objPhone then
						if phone ~= objPhone and not utilHasFriendAdded(objPhone, phone) then
							bullet.time = -1
							doGC = true
							utilAlertNotFriendInfrequently(ply, man, objPhone)
						end
					else
						bullet.time = -1
						doGC = true
					end
				end
			end
		else
			bullet.time = -1
			doGC = true
		end
	end
	if doGC then
		physics.garbageCollectBullets()
	end
end
---@type Plugin
local mode = ...

local server = server
local osRealClock = os.realClock

local EVENT_LIMIT = 30000
local EVENT_LIMIT_WARN = math.floor(EVENT_LIMIT * 0.9)

local eventLimitWarned
local currentTickTime
local numLongTicks

mode:addEnableHandler(function ()
	currentTickTime = osRealClock()
	numLongTicks = 0
end)

mode:addDisableHandler(function ()
	currentTickTime = nil
	eventLimitWarned = nil
end)

mode:addHook(
	'ResetGame',
	function ()
		server.type = 20
		server.levelToLoad = 'round'
	end
)

mode:addHook(
	'PostResetGame',
	function ()
		eventLimitWarned = false
		numLongTicks = 0

		server.state = STATE_GAME
		server.time = server.TPS * 60
		server.sunTime = 11 * 60 * 60 * server.TPS
	end
)

mode:addHook(
	'Logic',
	function ()
		local lastTickTime = currentTickTime
		currentTickTime = osRealClock()
		if currentTickTime - lastTickTime > (1 / 40) then
			numLongTicks = numLongTicks + 1
			if numLongTicks > 5 then
				server:reset()
				chat.announce(string.format('The game was reset - too much lag (%.2fmspf)', (currentTickTime - lastTickTime) * 1000))
				return
			end
		else
			numLongTicks = 0
		end

		local numEvents = #events
		if numEvents >= EVENT_LIMIT_WARN then
			if numEvents >= EVENT_LIMIT then
				server:reset()
			chat.announce('The game was reset - too many events')
			elseif not eventLimitWarned then
				eventLimitWarned = true
				chat.announce('There are too many events, the game may reset soon')
			end
		end
	end
)
--[[
	L_Switchboard1.lua - Core module for Switchboard
	Copyright 2019 Patrick H. Rigney, All Rights Reserved.
	This file is part of the Switchboard for Vera HA controllers.
--]]
--luacheck: std lua51,module,read globals luup,ignore 542 611 612 614 111/_,no max line length

module("L_Switchboard1", package.seeall)

local debugMode = false

local _PLUGIN_ID = 9194 -- luacheck: ignore 211
local _PLUGIN_NAME = "Switchboard"
local _PLUGIN_VERSION = "1.5develop-19223"
local _PLUGIN_URL = "https://www.toggledbits.com/"  -- luacheck: ignore 211

local _CONFIGVERSION = 19223
local _UIVERSION = 19200

local MYSID = "urn:toggledbits-com:serviceId:Switchboard1"
local MYTYPE = "urn:schemas-toggledbits-com:device:Switchboard:1"

local SWITCHSID = "urn:upnp-org:serviceId:SwitchPower1"
local VSSID = "urn:upnp-org:serviceId:VSwitch1"
local DIMMERSID = "urn:upnp-org:serviceId:Dimming1"
local HADSID = "urn:micasaverde-com:serviceId:HaDevice1"

local DEV_MFG = "rigpapa"
local DEV_MODEL = "Switchboard Virtual Binary Switch"

local pluginDevice = false
local isALTUI = false
local isOpenLuup = false
local runStamp = 1
local tickTasks = {}

-- A different kind of dfMap here
local dfMap = {
	  ['Dimmer'] =
			{ name="Dimmer", device_type="urn:schemas-upnp-org:device:DimmableLight:1", device_file="D_DimmableLight1.xml", category=2, subcategory=0, device_json="D_DimmableLight1.json", order=2 }
	, ['Binary'] =
			{ name="Binary Switch", device_type="urn:schemas-upnp-org:device:BinaryLight:1", device_file="D_BinaryLight1.xml", category=3, subcategory=1, device_json="D_BinaryLight1.json", order=1 }
	, ['TriState'] =
			{ name="Tri-state Switch", device_type="urn:schemas-upnp-org:device:BinaryLight:1", device_file="D_BinaryLight1.xml", category=3, subcategory=1, device_json="D_TriStateSwitch1.json", order=3 }
	, ['Cover'] =
			{ name="Window Covering", device_type="urn:schemas-micasaverde-com:device:WindowCovering:1", device_file="D_WindowCovering1.xml", category=8, subcategory=1, device_json="D_WindowCovering1.json", order=4 }
}

local function dump(t, seen)
	if t == nil then return "nil" end
	if seen == nil then seen = {} end
	local sep = ""
	local str = "{ "
	for k,v in pairs(t) do
		local val
		if type(v) == "table" then
			if seen[v] then val = "(recursion)"
			else
				seen[v] = true
				val = dump(v, seen)
			end
		elseif type(v) == "string" then
			if #v > 255 then val = string.format("%q", v:sub(1,252).."...")
			else val = string.format("%q", v) end
		elseif type(v) == "number" and (math.abs(v-os.time()) <= 86400) then
			val = tostring(v) .. "(" .. os.date("%x.%X", v) .. ")"
		else
			val = tostring(v)
		end
		str = str .. sep .. k .. "=" .. val
		sep = ", "
	end
	str = str .. " }"
	return str
end

local function L(msg, ...) -- luacheck: ignore 212
	local str
	local level = 50
	if type(msg) == "table" then
		str = tostring(msg.prefix or _PLUGIN_NAME) .. ": " .. tostring(msg.msg)
		level = msg.level or level
	else
		str = _PLUGIN_NAME .. ": " .. tostring(msg)
	end
	str = string.gsub(str, "%%(%d+)", function( n )
			n = tonumber(n, 10)
			if n < 1 or n > #arg then return "nil" end
			local val = arg[n]
			if type(val) == "table" then
				return dump(val)
			elseif type(val) == "string" then
				return string.format("%q", val)
			elseif type(val) == "number" and math.abs(val-os.time()) <= 86400 then
				return tostring(val) .. "(" .. os.date("%x.%X", val) .. ")"
			end
			return tostring(val)
		end
	)
	luup.log(str, level)
end

local function D(msg, ...)
	if debugMode then
		local t = debug.getinfo( 2 )
		local pfx = _PLUGIN_NAME .. "(" .. tostring(t.name) .. "@" .. tostring(t.currentline) .. ")"
		L( { msg=msg,prefix=pfx }, ... )
	end
end

local function checkVersion(dev)
	local ui7Check = luup.variable_get(MYSID, "UI7Check", dev) or ""
	if isOpenLuup then
		return true
	end
	if luup.version_branch == 1 and luup.version_major == 7 then
		if ui7Check == "" then
			-- One-time init for UI7 or better
			luup.variable_set( MYSID, "UI7Check", "true", dev )
		end
		return true
	end
	L({level=1,msg="firmware %1 (%2.%3.%4) not compatible"}, luup.version,
		luup.version_branch, luup.version_major, luup.version_minor)
	return false, "Firmware "..luup.version.." is not compatible"
end

-- Initialize a variable if it does not already exist.
local function initVar( name, dflt, dev, sid )
	assert( dev ~= nil, "initVar requires dev" )
	assert( sid ~= nil, "initVar requires SID for "..name )
	local currVal = luup.variable_get( sid, name, dev )
	if currVal == nil then
		luup.variable_set( sid, name, tostring(dflt), dev )
		return tostring(dflt)
	end
	return currVal
end

-- Set variable, only if value has changed.
local function setVar( sid, name, val, dev, force )
	val = (val == nil) and "" or tostring(val)
	local s = luup.variable_get( sid, name, dev ) or ""
	-- D("setVar(%1,%2,%3,%4) old value %5", sid, name, val, dev, s )
	if s ~= val or force then
		luup.variable_set( sid, name, val, dev )
		return true, s
	end
	return false, s
end

-- Get numeric variable, or return default value if not set or blank
local function getVarNumeric( name, dflt, dev, sid )
	assert( dev ~= nil )
	assert( name ~= nil )
	assert( sid ~= nil )
	local s = luup.variable_get( sid, name, dev ) or ""
	if s == "" then return dflt end
	return tonumber(s) or dflt
end

-- Schedule a timer tick for a future (absolute) time. If the time is sooner than
-- any currently scheduled time, the task tick is advanced; otherwise, it is
-- ignored (as the existing task will come sooner), unless repl=true, in which
-- case the existing task will be deferred until the provided time.
local function scheduleTick( tinfo, timeTick, flags )
	D("scheduleTick(%1,%2,%3)", tinfo, timeTick, flags)
	flags = flags or {}
	if type(tinfo) ~= "table" then tinfo = { id=tinfo } end
	local tkey = tostring( tinfo.id or error("task ID or obj required") )
	assert( not tinfo.args or type(tinfo.args)=="table" )
	assert( not tinfo.func or type(tinfo.func)=="function" )
	if ( timeTick or 0 ) == 0 then
		D("scheduleTick() clearing task %1", tinfo)
		tickTasks[tkey] = nil
		return
	elseif tickTasks[tkey] then
		-- timer already set, update
		tickTasks[tkey].func = tinfo.func or tickTasks[tkey].func
		tickTasks[tkey].args = tinfo.args or tickTasks[tkey].args
		tickTasks[tkey].info = tinfo.info or tickTasks[tkey].info
		if tickTasks[tkey].when == nil or timeTick < tickTasks[tkey].when or flags.replace then
			-- Not scheduled, requested sooner than currently scheduled, or forced replacement
			tickTasks[tkey].when = timeTick
		end
		D("scheduleTick() updated %1 to %2", tkey, tickTasks[tkey])
	else
		-- New task
		assert(tinfo.owner ~= nil) -- required for new task
		assert(tinfo.func ~= nil) -- required for new task
		tickTasks[tkey] = { id=tostring(tinfo.id), owner=tinfo.owner,
			when=timeTick, func=tinfo.func, args=tinfo.args or {},
			info=tinfo.info or "" }
		D("scheduleTick() new task %1 at %2", tinfo, timeTick)
	end
	-- If new tick is earlier than next plugin tick, reschedule
	tickTasks._plugin = tickTasks._plugin or {}
	if tickTasks._plugin.when == nil or timeTick < tickTasks._plugin.when then
		tickTasks._plugin.when = timeTick
		local delay = timeTick - os.time()
		if delay < 1 then delay = 1 end
		D("scheduleTick() rescheduling plugin tick for %1s to %2", delay, timeTick)
		runStamp = runStamp + 1
		luup.call_delay( "switchboardTick", delay, runStamp )
	end
	return tkey
end

local function gatewayStatus( m )
	setVar( MYSID, "Message", m or "", pluginDevice )
end

local function getChildDevices( typ, parent, filter )
	parent = parent or pluginDevice
	local res = {}
	for k,v in pairs(luup.devices) do
		if v.device_num_parent == parent and ( typ == nil or v.device_type == typ ) and ( filter==nil or filter(k, v) ) then
			table.insert( res, k )
		end
	end
	return res
end

--[[ Prep for adding new children via the luup.chdev mechanism. The existingChildren
	 table (array) should contain device IDs of existing children that will be
	 preserved. Any existing child not listed will be dropped. If the table is nil,
	 all existing children in luup.devices will be preserved.
--]]
local function prepForNewChildren( )
	D("prepForNewChildren()")
	local existingChildren = {}
	for k,v in pairs( luup.devices ) do
		if v.device_num_parent == pluginDevice then
			local d = {}
			d.devnum = k
			d.device = v
			d.device_file = luup.attr_get( "device_file", k ) or ""
			d.device_json = luup.attr_get( "device_json", k ) or "D_BinarySwitch1.json"
			d.behavior = luup.variable_get( MYSID, "Behavior", k ) or "Binary"
			if d.device_file ~= "" then
				table.insert( existingChildren, d )
			end
		end
	end
	local ptr = luup.chdev.start( pluginDevice )
	for _,d in ipairs( existingChildren ) do
		local v = d.device
		D("prepForNewChildren() appending existing child %1 (%2/%3)", v.description, d.devnum, v.id)
		luup.chdev.append( pluginDevice, ptr, v.id, v.description, "",
			d.device_file, "", "", false )
	end
	return ptr, existingChildren
end

-- One-time init for switch
local function initSwitch( switch )
	D("initSwitch(%1)", switch)

	local s = getVarNumeric( "Version", 0, switch, MYSID )
	if s == 0 then
		L("Initializing new child switch %1", switch)
		initVar( "Target", "0", switch, SWITCHSID )
		initVar( "Status", "0", switch, SWITCHSID )

		local b = luup.variable_get( MYSID, "Behavior", switch ) or ""
		if b == "" or not dfMap[b] then
			b = "Binary"
			luup.variable_set( MYSID, "Behavior", "Binary", switch )
			luup.attr_set('category_num', "3", switch)
			luup.attr_set('subcategory_num', "0", switch)
			luup.attr_set( 'manufacturer', DEV_MFG, switch )
			luup.attr_set( 'model', DEV_MODEL, switch )
		end
		if b == "Binary" or b == "TriState" then
			initVar( "ImpulseTime", "0", switch, MYSID )
			initVar( "ImpulseResetTime", "0", switch, MYSID )
			initVar( "AlwaysUpdateStatus", "0", switch, MYSID )
			-- Old VSwitch states
			initVar( "Target", "0", switch, VSSID )
			initVar( "Status", "0", switch, VSSID )
			initVar( "Text1", "Text1", switch, VSSID )
			initVar( "Text2", "Text2", switch, VSSID )
		elseif b == "Dimmer" then
			initVar( "LoadLevelTarget", 0, switch, DIMMERSID )
			initVar( "LoadLevelStatus", 0, switch, DIMMERSID )
			initVar( "LoadLevelLast", 100, switch, DIMMERSID )
		elseif b == "Cover" then
			initVar( "LoadLevelTarget", 0, switch, DIMMERSID )
			initVar( "LoadLevelStatus", 0, switch, DIMMERSID )
			initVar( "RampRatePerSecond", 5, switch, MYSID )
		end

		luup.variable_set( MYSID, "Version", _CONFIGVERSION, switch )
		return
	end

	if s < 000002 then
		luup.attr_set( 'manufacturer', DEV_MFG, switch )
		luup.attr_set( 'model', DEV_MODEL, switch )
	end

	if s < 000003 then
		initVar( "AlwaysUpdateStatus", 0, switch, MYSID )
	end

	if s < 19098 then
		local b = "Binary"
		if luup.attr_get( "device_json", switch ) == "D_TriStateSwitch1.json" then
			b = "TriState"
		elseif luup.devices[switch].device_type == "urn:schemas-upnp-org:device:DimmableLight:1" then
			b = "Dimmer"
		end
		luup.variable_set( MYSID, "Behavior", b, switch )
	end

	if s < 19223 then
		local b = luup.variable_get( MYSID, "Behavior", switch )
		if b == "Cover" then
			-- Before 19223 initialized wrong SID
			initVar( "RampRatePerSecond", 5, switch, MYSID )
			luup.variable_set( DIMMERSID, "RampRatePerSecond", nil, switch ) -- deletes on newer firmware
		end
	end

	setVar( MYSID, "Version", _CONFIGVERSION, switch )
end

local resetSwitch -- forward declaration

-- Check switches
local function startSwitches( dev )
	D("startSwitches()")
	local switches = getChildDevices( nil, dev )
	for _,switch in ipairs( switches ) do
		D("startSwitches() starting switch %1 (%2)", luup.devices[switch].description, switch)
		initSwitch( switch )

		-- If switch had a pending impulse reset before restart, reschedule it.
		local reset = getVarNumeric( "ImpulseResetTime", 0, switch, MYSID )
		if reset > 0 then
			L({level=2,msg="Recovering impulse reset for %1 (%2), was due %3"},
				luup.devices[switch].description, switch, reset)
			scheduleTick( { id="impulse"..switch, owner=switch, func=resetSwitch }, reset )
		end
	end
	return #switches
end

resetSwitch = function( switch, taskid )
	D("resetSwitch(%1,%2)", switch, taskid)
	local resetTime = getVarNumeric( "ImpulseResetTime", 0, switch, MYSID )
	local now = os.time()
	D("resetSwitch() reset time %1 now %2", resetTime, now)
	if now < resetTime then
		-- Early call, we're not there yet.
		D("resetSwitch() early call, deferring to %1", resetTime)
		scheduleTick( taskid, resetTime )
	elseif resetTime == 0 or now >= resetTime then
		-- Use action to reset state.
		D("resetSwitch() resetting switch")
		luup.call_action( SWITCHSID, "SetTarget", { newTargetState="0" }, switch )
	end
end


local function rampRun( pdev, taskid )
	local level = getVarNumeric( "LoadLevelStatus", 0, pdev, DIMMERSID )
	local target = getVarNumeric( "LoadLevelTarget", 0, pdev, DIMMERSID )
	local rate = math.floor( getVarNumeric( "RampRatePerSecond", 5, pdev, MYSID ) )
	if rate < 1 then rate = 1 elseif rate > 100 then rate = 100 end
	local diff = target - level
	if diff > 0 and diff > rate then
		diff = rate
	elseif diff < 0 and (-diff) > rate then
		diff = -rate
	end
	level = level + diff
	if level < 0 then level = 0 elseif level > 100 then level = 100 end
	setVar( DIMMERSID, "LoadLevelStatus", level, pdev )
	if level == 0 then
		setVar( SWITCHSID, "Status", 0, pdev )
	elseif level > 0 then
		setVar( SWITCHSID, "Status", 1, pdev )
	end
	if ( target - level ) ~= 0 then
		scheduleTick( taskid, os.time()+1 )
	end
end

local function rampStart( pdev )
	if getVarNumeric( "RampRatePerSecond", 5, pdev, MYSID ) == 0 then
		-- Special config: if ramp rate is 0, just go right to the target level.
		local target = getVarNumeric( "LoadLevelTarget", 0, pdev, DIMMERSID )
		setVar( DIMMERSID, "LoadLevelStatus", target, pdev )
		if target <= 0 then
			setVar( SWITCHSID, "Status", 0, pdev )
		elseif target > 0 then
			setVar( SWITCHSID, "Status", 1, pdev )
		end
	else
		scheduleTick( { id="ramp"..tostring(pdev), owner=pdev, func=rampRun }, os.time()+1 )
	end
end

local function rampStop( pdev )
	scheduleTick( "ramp"..tostring(pdev), 0 )
end

--[[
	***************************************************************************
	A C T I O N   I M P L E M E N T A T I O N
	***************************************************************************
--]]

function actionSetState( state, dev )
	D("actionSetState(%1,%2)",state,dev)
	-- Switch on/off
	local behavior = luup.variable_get( MYSID, "Behavior", dev ) or "Binary"
	local status
	if tostring(state) == "2" and behavior == "TriState" then -- tri-state
		status = "2"
	else
		if type(state) == "string" then state = ( tonumber(state) or 0 ) ~= 0
		elseif type(state) == "number" then state = state ~= 0 end
		local invert = getVarNumeric( "ReverseOnOff", 0, dev, HADSID) ~= 0
		if invert then status = not state else status = state end
		state = state and "1" or "0"
		status = status and "1" or "0"
	end
	D("actionSetState() state=%1, status=%2", state, status)

	luup.variable_set( SWITCHSID, "Target", state, dev )

	-- For window covering, set target level and ramp.
	if behavior == "Cover" then
		setVar( DIMMERSID, "LoadLevelTarget", state=="0" and 0 or 100, dev )
		rampStart( dev )
		return true
	end

	luup.variable_set( VSSID, "Target", state, dev )
	local force = getVarNumeric( "AlwaysUpdateStatus", 0, dev, MYSID ) ~= 0
	local changed = setVar( SWITCHSID, "Status", status, dev, force )
	setVar( VSSID, "Status", status, dev, force )

	if status == "0" then
		-- Turn off
		D("actionSetState() clearing impulse task")
		scheduleTick( "impulse"..dev, 0 )
		setVar( MYSID, "ImpulseResetTime", "0", dev )
		-- Dimmer?
		if behavior == "Dimmer" then
			if changed then
				-- Transition on->off, save current brightness.
				local brightness = luup.variable_get( DIMMERSID, "LoadLevelStatus", dev )
				setVar( DIMMERSID, "LoadLevelLast", brightness, dev )
			end
			setVar( DIMMERSID, "LoadLevelStatus", 0, dev, force )
		end
	elseif changed then
		-- Dimmer? If transition off->on, restore saved brightness
		if behavior == "Dimmer" and changed then
			local brightness = luup.variable_get( DIMMERSID, "LoadLevelLast", dev ) or 100
			setVar( DIMMERSID, "LoadLevelTarget", brightness, dev, force )
			setVar( DIMMERSID, "LoadLevelStatus", brightness, dev, force )
		end
		-- Transition to on (or tri-state void) status. Timer may run in any
		-- status other than "off".
		local delay = getVarNumeric( "ImpulseTime", 0, dev, MYSID )
		if delay > 0 then
			D("actionSetState() impulse reset in %1 secs", delay)
			delay = delay + os.time()
			setVar( MYSID, "ImpulseResetTime", delay, dev )
			scheduleTick( { id="impulse"..dev, owner=dev, func=resetSwitch }, delay )
		end
	end
	return true
end

function actionSetBrightness( level, dev )
	D("actionSetBrightness(%1,%2)", level, dev)
	level = tonumber( level or 0 ) or 0
	if level < 0 then level = 0 elseif level > 100 then level = 100 end
	local b = luup.variable_get( MYSID, "Behavior", dev ) or "Binary"
	if level == 0 then -- cover always sets brightness
		return actionSetState( "0", dev )
	end

	setVar( DIMMERSID, "LoadLevelTarget", tostring(level), dev )

	if b == "Cover" then
		rampStart( dev )
		return true
	end

	local st = getVarNumeric( "Status", 0, dev, SWITCHSID )
	if level > 0 and st == 0 then
		setVar( SWITCHSID, "Target", 1, dev )
		setVar( VSSID, "Target", 1, dev )
		setVar( SWITCHSID, "Status", 1, dev )
		setVar( VSSID, "Status", 1, dev )
	elseif level == 0 and st ~= 0 then
		setVar( SWITCHSID, "Target", 0, dev )
		setVar( VSSID, "Target", 0, dev )
		setVar( SWITCHSID, "Status", 0, dev )
		setVar( VSSID, "Status", 0, dev )
	end
	local force = getVarNumeric( "AlwaysUpdateStatus", 0, dev, MYSID ) ~= 0
	setVar( DIMMERSID, "LoadLevelStatus", tostring(level), dev, force )
	return true
end

function actionToggleState( dev )
	D("actionToggleState(%1)", dev)
	local t = getVarNumeric( "Target", 0, dev, SWITCHSID )
	local b = luup.variable_get( MYSID, "Behavior", dev ) or "Binary"
	D("actionToggleState() b=%1, target=%2", b, t)
	if "TriState" == b then
		-- TriState rolls On->Void->Off->Void->On...
		if t ~= 2 then
			setVar( MYSID, "TSPriorState", t, dev )
			actionSetState( "2", dev )
		else
			local l = getVarNumeric( "TSPriorState", 0, dev, MYSID ) ~= 0
			D("actionToggleState() prior=%1", l)
			actionSetState( l and 0 or 1, dev )
		end
	else
		actionSetState( (t~=0) and 0 or 1, dev )
	end
	return true
end

function actionWCUp( pdev )
	D("actionWCUp(%1)", pdev )
	setVar( DIMMERSID, "LoadLevelTarget", 100, pdev )
	setVar( SWITCHSID, "Target", 1, pdev )
	rampStart( pdev )
	return true
end

function actionWCDown( pdev )
	D("actionWCUp(%1)", pdev )
	setVar( DIMMERSID, "LoadLevelTarget", 0, pdev )
	setVar( SWITCHSID, "Target", 0, pdev )
	rampStart( pdev )
	return true
end

function actionWCStop( pdev )
	D("actionWCStop(%1)", pdev)
	rampStop( pdev )
	return true
end

function actionSetVisibility( switch, vis, pdev ) -- luacheck: ignore 212
	switch = tonumber(switch) or -1
	if ( vis or "" ) == "" then
		-- If vis not provided, toggle.
		local m = luup.attr_get( 'invisible', switch )
		vis = ( m == "1" ) and "1" or "0"
	end
	L("Setting %1 (%2) visibility %3", luup.devices[switch].description, switch, tostring(vis)~="0")
	luup.attr_set( 'invisible', (tostring(vis)~="0") and "0" or "1", switch )
end

function jobAddSwitch( count, pdev )
	assert(luup.devices[pdev].device_type == MYTYPE)
	count = tonumber(count) or 1
	L("Adding %1 children", count)
	gatewayStatus( "Creating children. Please hard-refresh your browser!" )
	local ptr,children = prepForNewChildren()
	local id = 0
	for _,d in ipairs( children ) do
		local did = tonumber(d.device.id) or 0
		if did > id then id = did end
	end
	for _=1,count do
		id = id + 1
		luup.chdev.append( pdev, ptr, id, "Virtual Switch "..id, "", "D_BinaryLight1.xml", "", "", false )
	end
	luup.chdev.sync( pdev, ptr )
	return 4,0
end

function jobAddChild( ctype, pdev )
	assert(luup.devices[pdev].device_type == MYTYPE)
	assert(dfMap[ctype])
	local df = dfMap[ctype]
	L("Adding %1 child (type %2)", df.name, ctype)
	gatewayStatus( "Creating child. Please hard-refresh your browser!" )
	local ptr,children = prepForNewChildren()
	local id = 0
	for _,d in ipairs( children ) do
		local did = tonumber(d.device.id) or 0
		if did > id then id = did end
	end
	id = id + 1
	local vv = { MYSID .. ",Behavior=" .. ctype }
	table.insert( vv, ",device_json=" .. df.device_json )
	table.insert( vv, ",category_num=" .. df.category or 3 )
	table.insert( vv, ",manufacturer=" .. DEV_MFG )
	table.insert( vv, ",model=Switchboard Virtual " .. df.name )
	if df.subcategory_num then
		table.insert( vv, ",subcategory_num=" .. df.subcategory )
	end
	luup.chdev.append( pdev, ptr, id, "Virtual "..df.name.." "..id, "",
		df.device_file,
		"",
		table.concat( vv, "\n" ),
		false )
	luup.chdev.sync( pdev, ptr )
	return 4,0
end

-- Enable or disable debug
function actionSetDebug( state, tdev )
	assert(tdev == pluginDevice) -- on master only
	if string.find( ":debug:true:t:yes:y:1:", string.lower(tostring(state)) ) then
		debugMode = true
	else
		local n = tonumber(state or "0") or 0
		debugMode = n ~= 0
	end
	if debugMode then
		D("Debug enabled")
	end
end

-- Dangerous debug stuff. Remove all child devices except switchs.
function jobMasterClear( dev )
	assert( luup.devices[dev].device_type == MYTYPE )
	L({level=2,msg="Master clear of all child devices requested on %2 (%1)"},
		luup.devices[dev].description, dev)
	gatewayStatus( "Clearing children..." )
	local ptr = luup.chdev.start( dev )
	luup.chdev.sync( dev, ptr )
	return 4,0
end

--[[
	***************************************************************************
	P L U G I N   B A S E
	***************************************************************************
--]]
-- plugin_runOnce() looks to see if a core state variable exists; if not, a
-- one-time initialization takes place.
local function plugin_runOnce( pdev )
	local s = getVarNumeric("Version", 0, pdev, MYSID)
	if s == 0 then
		L("First run, setting up new plugin instance...")
		initVar( "Message", "", pdev, MYSID )
		initVar( "DebugMode", 0, pdev, MYSID )

		luup.attr_set('category_num', 1, pdev)

		luup.variable_set( MYSID, "Version", _CONFIGVERSION, pdev )
		return
	end

	-- Update version last.
	if s ~= _CONFIGVERSION then
		luup.variable_set( MYSID, "Version", _CONFIGVERSION, pdev )
	end
end

-- Start plugin running.
function startPlugin( pdev )
	L("plugin version %2 master device %3 (#%1)", pdev, _PLUGIN_VERSION, luup.devices[pdev].description)

	luup.variable_set( MYSID, "Message", "Initializing...", pdev )
	luup.variable_set( MYSID, "_UIV", _UIVERSION, pdev )

	-- Early inits
	pluginDevice = pdev
	isALTUI = false
	isOpenLuup = false
	tickTasks = {}

	-- Debug?
	if getVarNumeric( "DebugMode", 0, pdev, MYSID ) ~= 0 then
		debugMode = true
		D("startPlugin() debug enabled by state variable DebugMode")
	end

	-- Check for ALTUI and OpenLuup
	for k,v in pairs(luup.devices) do
		if v.device_type == "urn:schemas-upnp-org:device:altui:1" and v.device_num_parent == 0 then
			D("start() detected ALTUI at %1", k)
			isALTUI = true
		elseif v.device_type == "openLuup" then
			D("start() detected openLuup")
			isOpenLuup = true
			local vv = getVarNumeric( "Vnumber", 0, k, "openLuup" )
			if vv < 190202 then
				L({level=1,msg="OpenLuup must be >= 190202; you have %1. Can't continue."}, vv)
				luup.variable_set( MYSID, "Message", "See log. Unsupported firmware " .. tostring(vv), pdev )
				luup.set_failure( 1, pdev )
				return false, "Incompatible openLuup ver " .. tostring(vv), _PLUGIN_NAME
			end
	   end
		if isALTUI and isOpenLuup then break end -- nothing more to do.
	end

	-- Check UI version
	local okv,err = checkVersion( pdev )
	if not okv then
		L({level=1,msg="This plugin does not run on this firmware: %1"}, err)
		gatewayStatus( err, pdev )
		luup.set_failure( 1, pdev )
		return false, err, _PLUGIN_NAME
	end

	-- One-time stuff
	plugin_runOnce( pdev )

	-- More inits
	if isOpenLuup then
		local loader = require "openLuup.loader"
		if loader.find_file == nil then
			gatewayStatus( "openLuup upgrade required; must be 2018.11.21 or higher", pdev )
			L{level=1,msg="Your openLuup needs to be 2018.11.21 or higher; please update."}
			luup.set_failure( 1, pdev )
			return false, "Please update to 2018.11.21 or higher.", _PLUGIN_NAME
		end
		if not ( loader.find_file( "D_BinaryLight1.xml" ) and
				loader.find_file( "D_BinaryLight1.json" )
				) then
			gatewayStatus( "Incomplete installation; see log for details", pdev )
			L{level=1,msg="You have not completed the install of the supplemental files for openLuup. Please see the README file at https://github.com/toggledbits/Switchboard-Vera/blob/master/README.md"}
			luup.set_failure( 1, pdev )
			return false, "Incomplete installation; see log for details", _PLUGIN_NAME
		end
	end

	-- Start switches
	local count = startSwitches( pdev )
	gatewayStatus( string.format( "%d virtual switches", count ), pdev )

	-- Return success
	luup.set_failure( 0, pdev )
	return true, "Ready", _PLUGIN_NAME
end

-- Plugin timer tick. Using the tickTasks table, we keep track of
-- tasks that need to be run and when, and try to stay on schedule. This
-- keeps us light on resources: typically one system timer only for any
-- number of devices.
local functions = { [tostring(resetSwitch)]='resetSwitch', [tostring(rampRun)]='rampRun' }
function tick(p)
	D("tick(%1) pluginDevice=%2", p, pluginDevice)
	local stepStamp = tonumber(p,10)
	assert(stepStamp ~= nil)
	if stepStamp ~= runStamp then
		D( "tick() stamp mismatch (got %1, expecting %2), newer thread running. Bye!",
			stepStamp, runStamp )
		return
	end

	local now = os.time()
	local nextTick = nil
	tickTasks._plugin.when = 0 -- marker

	-- Since the tasks can manipulate the tickTasks table (via calls to
	-- scheduleTick()), the iterator is likely to be disrupted, so make a
	-- separate list of tasks that need service (to-do list).
	local todo = {}
	for t,v in pairs(tickTasks) do
		if t ~= "_plugin" and v.when ~= nil and v.when <= now then
			-- Task is due or past due
			D("tick() inserting eligible task %1 when %2 now %3", v.id, v.when, now)
			v.when = nil -- clear time; timer function will need to reschedule
			table.insert( todo, v )
		end
	end

	-- Run the to-do list tasks.
	D("tick() to-do list is %1", todo)
	for _,v in ipairs(todo) do
		local fname = functions[tostring(v.func)] or tostring(v.func)
		D("tick() calling %3(%4,%5) for %1 (task %2 %3)", v.owner,
			(luup.devices[v.owner] or {}).description, fname, v.owner, v.id,
			v.info)
		-- Call timer function with arguments ownerdevicenum,taskid[,args]
		-- The extra arguments are set up when the task is set/updated.
		local success, err = pcall( v.func, v.owner, v.id, unpack(v.args or {}) )
		if not success then
			L({level=1,msg="Device %1 (%2) tick failed: %3"}, v.owner, (luup.devices[v.owner] or {}).description, err)
		else
			D("tick() successful return from %2(%1)", v.owner, fname)
		end
	end

	-- Things change while we work. Take another pass to find next task.
	for t,v in pairs(tickTasks) do
		if t ~= "_plugin" and v.when ~= nil then
			if nextTick == nil or v.when < nextTick then
				nextTick = v.when
			end
		end
	end

	-- Figure out next master tick, or don't resched if no tasks waiting.
	if nextTick ~= nil then
		D("tick() next eligible task scheduled for %1", os.date("%x %X", nextTick))
		now = os.time() -- Get the actual time now; above tasks can take a while.
		local delay = nextTick - now
		if delay < 1 then delay = 1 end
		tickTasks._plugin.when = now + delay
		D("tick() scheduling next tick(%3) for %1 (%2)", delay, tickTasks._plugin.when,p)
		luup.call_delay( "switchboardTick", delay, p )
	else
		D("tick() not rescheduling, nextTick=%1, stepStamp=%2, runStamp=%3", nextTick, stepStamp, runStamp)
		tickTasks._plugin = nil
	end
end

local function getDevice( dev, pdev, v )
	if v == nil then v = luup.devices[dev] end
	if json == nil then json = require("dkjson") end
	local devinfo = {
		  devNum=dev
		, ['type']=v.device_type
		, description=v.description or ""
		, room=v.room_num or 0
		, udn=v.udn or ""
		, id=v.id
		, parent=v.device_num_parent or pdev
		, ['device_json'] = luup.attr_get( "device_json", dev )
		, ['impl_file'] = luup.attr_get( "impl_file", dev )
		, ['device_file'] = luup.attr_get( "device_file", dev )
		, manufacturer = luup.attr_get( "manufacturer", dev ) or ""
		, model = luup.attr_get( "model", dev ) or ""
		, category = luup.attr_get( "category_num", dev ) or ""
		, subcategory = luup.attr_get( "subcategory_num", dev ) or ""
	}
	local rc,t,httpStatus,uri
	if isOpenLuup then
		uri = "http://localhost:3480/data_request?id=status&DeviceNum=" .. dev .. "&output_format=json"
	else
		uri = "http://localhost/port_3480/data_request?id=status&DeviceNum=" .. dev .. "&output_format=json"
	end
	rc,t,httpStatus = luup.inet.wget(uri, 15)
	if httpStatus ~= 200 or rc ~= 0 then
		devinfo['_comment'] = string.format( 'State info could not be retrieved, rc=%s, http=%s', tostring(rc), tostring(httpStatus) )
		return devinfo
	end
	local d = json.decode(t)
	local key = "Device_Num_" .. dev
	if d ~= nil and d[key] ~= nil and d[key].states ~= nil then d = d[key].states else d = nil end
	devinfo.states = d or {}
	return devinfo
end

-- A "safer" JSON encode for Lua structures that may contain recursive refereance.
-- This output is intended for display ONLY, it is not to be used for data transfer.
local function alt_json_encode( st, seen )
	seen = seen or {}
	str = "{"
	local comma = false
	for k,v in pairs(st) do
		str = str .. ( comma and "," or "" )
		comma = true
		str = str .. '"' .. k .. '":'
		if type(v) == "table" then
			if seen[v] then str = str .. '"(recursion)"'
			else
				seen[v] = k
				str = str .. alt_json_encode( v, seen )
			end
		else
			str = str .. stringify( v, seen )
		end
	end
	str = str .. "}"
	return str
end

-- Stringify a primitive type
stringify = function( v, seen )
	if v == nil then
		return "(nil)"
	elseif type(v) == "number" or type(v) == "boolean" then
		return tostring(v)
	elseif type(v) == "table" then
		return alt_json_encode( v, seen )
	end
	return string.format( "%q", tostring(v) )
end

function requestHandler( lul_request, lul_parameters, lul_outputformat )
	D("request(%1,%2,%3) luup.device=%4", lul_request, lul_parameters, lul_outputformat, luup.device)
	local action = lul_parameters['action'] or lul_parameters['command'] or ""
	local deviceNum = tonumber( lul_parameters['device'], 10 ) or luup.device
	if action == "debug" then
		local err,msg,job,args = luup.call_action( MYSID, "SetDebug", { debug=1 }, deviceNum )
		return string.format("Device #%s result: %s, %s, %s, %s", tostring(deviceNum), tostring(err), tostring(msg), tostring(job), dump(args)), "text/plain"
	end

	if action == "getvtypes" then
		local json = require("dkjson")
		local r = {}
		if isOpenLuup then
			-- For openLuup, only show device types for resources that are installed
			local loader = require "openLuup.loader"
			if loader.find_file ~= nil then
				for k,v in pairs( dfMap ) do
					if loader.find_file( v.device_file ) then
						r[k] = v
					end
				end
			else
				L{level=1,msg="PLEASE UPGRADE YOUR OPENLUUP TO 181122 OR HIGHER FOR FULL SUPPORT OF SITESENSOR VIRTUAL DEVICES"}
			end
		else
			r = dfMap
		end
		return json.encode( r ), "application/json"

	elseif action == "status" then
		local st = {
			name=_PLUGIN_NAME,
			plugin=_PLUGIN_ID,
			version=_PLUGIN_VERSION,
			configversion=_CONFIGVERSION,
			uiversion=_UIVERSION,
			author="Patrick H. Rigney (rigpapa)",
			url=_PLUGIN_URL,
			['type']=MYTYPE,
			responder=luup.device,
			timestamp=os.time(),
			system = {
				version=luup.version,
				isOpenLuup=isOpenLuup,
				isALTUI=isALTUI,
				hardware=luup.attr_get("model",0),
				lua=tostring((_G or {})._VERSION)
			},
			devices={}
		}
		for k,v in pairs( luup.devices ) do
			if v.device_type == MYTYPE or v.device_num_parent == pluginDevice then
				local devinfo = getDevice( k, pluginDevice, v ) or {}
				table.insert( st.devices, devinfo )
			end
		end
		return alt_json_encode( st ), "application/json"

	else
		return string.format("Action %q not implemented", action), "text/plain"
	end
end

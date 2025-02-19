function widget:GetInfo()
	return {
		name = "Minimap",
		desc = "",
		author = "Floris",
		date = "April 2020",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

local maxAllowedWidth = 0.26
local maxAllowedHeight = 0.32
local leftClickMove = true

local vsx, vsy = Spring.GetViewGeometry()

local minimized = false
local maximized = false

local maxHeight = maxAllowedHeight
local maxWidth = math.min(maxHeight * (Game.mapX / Game.mapY), maxAllowedWidth * (vsx / vsy))
local usedWidth = math.floor(maxWidth * vsy)
local usedHeight = math.floor(maxHeight * vsy)
local backgroundRect = { 0, 0, 0, 0 }

local delayedSetup = false
local sec = 0
local sec2 = 0

local spGetCameraState = Spring.GetCameraState
local math_isInRect = math.isInRect

local wasOverview = false
local leftclicked = false

local RectRound, UiElement, elementCorner, elementPadding, elementMargin
local dlistGuishader, dlistMinimap, oldMinimapGeometry, chobbyInterface

local dualscreenMode = ((Spring.GetConfigInt("DualScreenMode", 0) or 0) == 1)

local function checkGuishader(force)
	if WG['guishader'] then
		if force and dlistGuishader then
			dlistGuishader = gl.DeleteList(dlistGuishader)
		end
		if not dlistGuishader then
			dlistGuishader = gl.CreateList(function()
				RectRound(backgroundRect[1], backgroundRect[2] - elementPadding, backgroundRect[3] + elementPadding, backgroundRect[4], elementCorner)
			end)
			WG['guishader'].InsertDlist(dlistGuishader, 'minimap')
		end
	elseif dlistGuishader then
		dlistGuishader = gl.DeleteList(dlistGuishader)
	end
end

local function clear()
	dlistMinimap = gl.DeleteList(dlistMinimap)
	if WG['guishader'] and dlistGuishader then
		WG['guishader'].DeleteDlist('minimap')
		dlistGuishader = nil
	end
end

function widget:ViewResize()
	local newDualscreenMode = ((Spring.GetConfigInt("DualScreenMode", 0) or 0) == 1)
	if dualscreenMode ~= newDualscreenMode then
		dualscreenMode = newDualscreenMode
		if dualscreenMode then
			clear()
		else
			widget:Initialize()
		end
		return
	end

	vsx, vsy = Spring.GetViewGeometry()

	elementPadding = WG.FlowUI.elementPadding
	elementCorner = WG.FlowUI.elementCorner
	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element
	elementMargin = WG.FlowUI.elementMargin

	if WG['topbar'] ~= nil then
		local topbarArea = WG['topbar'].GetPosition()
		maxAllowedWidth = (topbarArea[1] - elementMargin - elementPadding) / vsx
	end

	maxWidth = math.min(maxAllowedHeight * (Game.mapX / Game.mapY), maxAllowedWidth * (vsx / vsy))
	if maxWidth >= maxAllowedWidth * (vsx / vsy) then
		maxHeight = maxWidth / (Game.mapX / Game.mapY)
	else
		maxHeight = maxAllowedHeight
	end

	usedWidth = math.floor(maxWidth * vsy)
	usedHeight = math.floor(maxHeight * vsy)

	backgroundRect = { 0, vsy - (usedHeight), usedWidth, vsy }

	if not dualscreenMode then
		Spring.SendCommands(string.format("minimap geometry %i %i %i %i", 0, 0, usedWidth, usedHeight))
		checkGuishader(true)
	end
	dlistMinimap = gl.DeleteList(dlistMinimap)
end

function widget:Initialize()
	oldMinimapGeometry = Spring.GetMiniMapGeometry()
	gl.SlaveMiniMap(true)

	widget:ViewResize()

	if Spring.GetConfigInt("MinimapMinimize", 0) == 1 then
		Spring.SendCommands("minimap minimize 1")
	end
	_, _, _, _, minimized, maximized = Spring.GetMiniMapGeometry()

	WG['minimap'] = {}
	WG['minimap'].getHeight = function()
		return usedHeight + elementPadding
	end
	WG['minimap'].getMaxHeight = function()
		return math.floor(maxAllowedHeight * vsy), maxAllowedHeight
	end
	WG['minimap'].setMaxHeight = function(value)
		maxAllowedHeight = value
		widget:ViewResize()
	end
	WG['minimap'].getLeftClickMove = function()
		return leftClickMove
	end
	WG['minimap'].setLeftClickMove = function(value)
		leftClickMove = value
	end
end

function widget:GameStart()
	widget:ViewResize()
end

function widget:Shutdown()
	clear()
	gl.SlaveMiniMap(false)

	if not dualscreenMode then
		Spring.SendCommands("minimap geometry " .. oldMinimapGeometry)
	end
end

function widget:Update(dt)
	if not delayedSetup then
		sec = sec + dt
		if sec > 2 then
			delayedSetup = true
			widget:ViewResize()
		end
	end

	sec2 = sec2 + dt
	if sec2 <= 0.25 then return end
	sec2 = 0

	if dualscreenMode then return end

	_, _, _, _, minimized, maximized = Spring.GetMiniMapGeometry()
	Spring.SetConfigInt("MinimapMinimized", minimized and 1 or 0)

	if minimized or maximized then
		return
	end

	Spring.SendCommands(string.format("minimap geometry %i %i %i %i", 0, 0, usedWidth, usedHeight))
	checkGuishader()
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1, 19) == 'LobbyOverlayActive1')
	end
end

local st = spGetCameraState()
local stframe = 0
function widget:DrawScreen()
	if chobbyInterface then return end

	if dualscreenMode and not minimized then
		gl.DrawMiniMap()
		return
	end

	if minimized or maximized then
		clear()
	else
		local x, y, b = Spring.GetMouseState()
		if math_isInRect(x, y, backgroundRect[1], backgroundRect[2] - elementPadding, backgroundRect[3] + elementPadding, backgroundRect[4]) then
			if not math_isInRect(x, y, backgroundRect[1], backgroundRect[2] + 1, backgroundRect[3] - 1, backgroundRect[4]) then
				Spring.SetMouseCursor('cursornormal')
			end
		end
	end
	if dlistGuishader and WG['guishader'] then
		WG['guishader'].RemoveDlist('minimap')
		dlistGuishader = gl.DeleteList(dlistGuishader)
	end

	stframe = stframe + 1
	if stframe % 10 == 0 then
		st = spGetCameraState()
	end
	if st.name == "ov" then
		-- overview camera
		if dlistGuishader and WG['guishader'] then
			WG['guishader'].RemoveDlist('minimap')
			dlistGuishader = gl.DeleteList(dlistGuishader)
			wasOverview = true
		end

	elseif not (minimized or maximized) then
		if wasOverview then
			gl.SlaveMiniMap(true)
			wasOverview = false
		end

		if dlistGuishader and WG['guishader'] then
			WG['guishader'].InsertDlist(dlistGuishader, 'minimap')
		end
		if not dlistMinimap then
			dlistMinimap = gl.CreateList(function()
				UiElement(backgroundRect[1], backgroundRect[2] - elementPadding, backgroundRect[3] + elementPadding, backgroundRect[4], 0, 0, 1, 0)
			end)
		end
		gl.CallList(dlistMinimap)
	end

	gl.DrawMiniMap()
end

function widget:GetConfigData()
	return {
		maxHeight = maxAllowedHeight,
		leftClickMove = leftClickMove
	}
end

function widget:SetConfigData(data)
	if data.maxHeight ~= nil then
		maxAllowedHeight = data.maxHeight
	end
	if data.leftClickMove ~= nil then
		leftClickMove = data.leftClickMove
	end
end


local function minimapToWorld(x, y)
	local px = (x/usedWidth) * (Game.mapX * 512)
	local pz = ((vsy-y)/usedHeight) * (Game.mapY * 512)
	return px, Spring.GetGroundHeight(px,pz), pz
end

function widget:MouseMove(x, y)
	if not dualscreenMode then
		if leftclicked and leftClickMove then
			local px, py, pz = minimapToWorld(x, y)
			if py then
				Spring.SetCameraTarget(px, py, pz, 0.04)
			end
		end
	end
end

function widget:MousePress(x, y, button)
	if Spring.IsGUIHidden() then return end
	if dualscreenMode then return end
	if minimized then return end

	leftclicked = false

	if math_isInRect(x, y, backgroundRect[1], backgroundRect[2] - elementPadding, backgroundRect[3] + elementPadding, backgroundRect[4]) then
		if not math_isInRect(x, y, backgroundRect[1], backgroundRect[2] + 1, backgroundRect[3] - 1, backgroundRect[4]) then
			return true
		elseif button == 1 and leftClickMove then
			leftclicked = true
			local px, py, pz = minimapToWorld(x, y)
			if py then
				Spring.SetCameraTarget(px, py, pz, 0.2)
				return true
			end
		end
	end
end

function widget:MouseRelease(x, y, button)
	if dualscreenMode then return end

	leftclicked = false
end

local smooth = require "smooth"
local CP = require "colorPicker"

require "utils"

local i = love.graphics.newImage(love.image.newImageData(love.filesystem.newFileData(io.stdin:read "*a", "input.png")))
local W, H = i:getWidth(), i:getHeight()
local elements = {}
local undone = {}

local settings = {
	color = setmetatable({1, 1, 1}, {__call = function(self) return {unpack(self)} end}),
	radius = 3,
	fontSize = 12
}
local font = setmetatable({}, {__index = function(t, i) if tonumber(i) then t[i] = love.graphics.newFont(i) return t[i] end end})

local line
local text
local cropping
local viewport = {0, 0, W, H}
local cp

local bg

local canvas = love.graphics.newCanvas(W, H)

local time = 0
local splash = .5

local zoom = love.graphics.newQuad(0, 0, 16, 16, 1, 1)

local cursors = {}
cursors.base = love.mouse.getSystemCursor("arrow")
cursors.cropping = love.mouse.getSystemCursor("crosshair")
cursors.text = love.mouse.getSystemCursor("ibeam")

do
	local quad = love.graphics.newQuad(0, 0, W, H, 16, 16)
	local img = love.graphics.newImage(love.image.newImageData(love.filesystem.newFileData(love.data.decode("string", "base64", 
		[[iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAACXBIWXMAAC4jAAAuIwF4pT92AAAA
K0lEQVQ4y2OcOXPmfwY84OzZs/ikGZgYKASjBgwGA1gIxbOxsfFoIA5/AwAHZQhTm7rVdAAAAABJ
RU5ErkJggg==
]]), "bg.png")))
	img:setWrap("repeat", "repeat")
	bg = function()
		love.graphics.draw(img, quad)
	end
end

local resize = function(newViewport)
	W, H = newViewport[3], newViewport[4]
	canvas = love.graphics.newCanvas(W, H)
	viewport = {unpack(newViewport)}
	love.window.setMode(W, H)
end

local addElement = function(element, redone)
	elements[#elements + 1] = element
	if not redone then
		undone = {}
	end
	if element.t == "crop" then
		resize(element.viewport)
	end
end

local undo = function()
	if #elements == 0 then return end
	local element = elements[#elements]
	undone[#undone + 1] = element
	elements[#elements] = nil
	if element.t == "crop" then
		resize(element.oldViewport)
	end
end

local redo = function()
	if #undone == 0 then return end
	addElement(undone[#undone], true)
	undone[#undone] = nil
end

local drawElement = function(e, x, y)
	x = x or 0
	y = y or 0
	if e.c then
		love.graphics.setColor(e.c)
	end
	if e.t == "line" then
		if #e < 4 then return end
		love.graphics.push()
		love.graphics.translate(-x, -y)
		love.graphics.setLineWidth(e.size or settings.radius)
		love.graphics.line(smooth(e, 3))
		love.graphics.pop()
	elseif e.t == "text" then
		local c = ""
		if e.time and (e.time - time)%1 < 0.5 then
			c = "|"
		end
		love.graphics.setFont(font[e.size or settings.fontSize])
		love.graphics.print(e.text .. c, e.x or x, e.y or y)
	end
end


love.window.setMode(W, H)
love.window.setTitle("NixEdit")
love.keyboard.setKeyRepeat(true)


love.update = function(dt)
	time = time + dt
	splash = splash - dt
	if cp then
		cp:update()
	end
end


love.draw = function(pure)
	local mx, my = love.mouse.getPosition()
	love.graphics.setCanvas(canvas)
	love.graphics.setColor(1,1,1)
	if not pure then
		bg()
	end
	love.graphics.push()
	love.graphics.translate(-viewport[1], -viewport[2])
	love.graphics.draw(i)
	for i, v in ipairs(elements) do
		drawElement(v)
	end

	if pure then
		love.graphics.setCanvas()
		return
	end

	love.graphics.setCanvas()
	love.graphics.setColor(1,1,1)
	love.graphics.pop()
	love.graphics.draw(canvas)
	if cp then
		love.graphics.setColor(0, 0, 0, 0.1)
		love.graphics.rectangle("fill", 0, 0, W+1, H+1)
		cp:draw()
	end
	if line then
		drawElement(line, viewport[1], viewport[2])
	elseif text then
		drawElement(text, love.mouse.getPosition())
	else
		love.graphics.setColor(settings.color)
		love.graphics.setLineWidth(1)
		love.graphics.circle("line", love.mouse.getX(), love.mouse.getY(), settings.radius, settings.radius*4)
	end
	if splash > 0 then
		love.graphics.setColor(1, 1, 1, (splash)^2)
		bg()
		love.graphics.setColor(0, 0, 0, (splash*2)^2)
		love.graphics.setFont(font[H/10])
		love.graphics.printf("EDIT", 0, H/3, W, "center")
	end
	if choosing then
		zoom:setViewport(mx, my, 1, 1, W, H)
		love.graphics.setColor(1,1,1)
		love.graphics.draw(canvas, zoom, mx - 8, my - 8, 0, 16, 16)
		love.graphics.setColor(1, 1, 1, 0.6)
		love.graphics.rectangle("line", mx - 9, my - 9, 18, 18)
	end
	if love.keyboard.isDown("space") then
		if cropping then
			local font = font[12]
			love.graphics.setColor(1,1,1, .5)
			love.graphics.setFont(font)

			love.graphics.print(cropping.viewport[3] .. "x" .. cropping.viewport[4], cropping.viewport[1] + 2 - viewport[1], cropping.viewport[2] - viewport[2])
			local mrx, mry, mlx, mly, mtx, mty, mbx, mby

			local ml = cropping.viewport[1] - viewport[1]
			mlx = math.max(0, cropping.viewport[1] - font:getWidth(ml) - 2 - viewport[1])
			mly = cropping.viewport[2] + cropping.viewport[4] / 2 - font:getHeight() / 2 - viewport[2]
			love.graphics.print(ml, math.floor(mlx), math.floor(mly))

			local mr = W - cropping.viewport[1] - cropping.viewport[3] + viewport[1]
			mrx = math.min(W - font:getWidth(mr), cropping.viewport[1] + cropping.viewport[3] - viewport[1])
			mry = mly
			love.graphics.print(mr, math.floor(mrx), math.floor(mry))

			local mt = cropping.viewport[2] - viewport[2]
			mtx = cropping.viewport[1] - viewport[1]
			mty = math.max(0, cropping.viewport[2] - font:getHeight() - viewport[2])
			love.graphics.printf(mt, mtx, mty, cropping.viewport[3], "center")

			local mb = H - cropping.viewport[2] - cropping.viewport[4] + viewport[2]
			mbx = cropping.viewport[1] - viewport[1]
			mby = math.min(H - font:getHeight(), cropping.viewport[2] + cropping.viewport[4] - viewport[2])
			love.graphics.printf(H - cropping.viewport[2] - cropping.viewport[4], mbx, mby, cropping.viewport[3], "center")
		elseif text then
			--obviously nothing
		elseif choosing then

		else --both when drawing a line and when nothing else is happening
			love.graphics.setColor(1, 1, 1, 0.3)
			love.graphics.setLineWidth(1)
			love.graphics.line(0, my - .5, W, my - .5)
			love.graphics.line(mx - .5, 0, mx - .5, H)
		end
	end
	if cropping then
		local x, y, w, h = unpack(cropping.viewport)
		x = x - viewport[1]
		y = y - viewport[2]
		love.graphics.setColor(1,1,1, .5)
		love.graphics.setLineWidth(2)
		love.graphics.rectangle("line", x, y, w, h)
		love.graphics.stencil(function() love.graphics.rectangle("fill", x, y, w, h) end, "invert")
		love.graphics.setStencilTest("notequal", 255)
		love.graphics.setColor(0, 0, 0, .5)
		love.graphics.rectangle("fill", 0, 0, W, H)
	end
end


love.mousepressed = function(x, y, b)
	x = x + viewport[1]
	y = y + viewport[2]
	if cropping then
		if b == 1 then
			cropping.held = true
			cropping.viewport[1] = x
			cropping.viewport[2] = y
			cropping.viewport[3] = 1
			cropping.viewport[4] = 1
			cropping.origin = {x, y}
		end
	elseif text then

	elseif choosing then

	elseif line then

	else
		if b == 1 then
			line = {x, y, c = settings.color(), t = "line", straight = love.keyboard.isDown("lshift", "rshift")}
		elseif b == 2 then
			CP:create(x - 128 - viewport[1], y - 128 - viewport[2], 128)
			cp = CP
		elseif b == 3 then
			choosing = true
		end
	end
end


love.mousemoved = function(x, y)
	x = x + viewport[1]
	y = y + viewport[2]
	if line then
		if love.keyboard.isDown("lctrl", "rctrl") and line.straight then
			local dy = y - line[2]
			local dx = x - line[1]
			local a = math.atan2(dy, dx)
			local d = (dy*dy + dx*dx) ^ .5
			a = math.floor(a / math.pi * 8 + .5)/8 * math.pi
			line[3] = line[1] + math.cos(a) * d
			line[4] = line[2] + math.sin(a) * d
		else
			line[math.max(3, #line + (line.straight and -1 or 1))] = x
			line[math.max(4, #line + (line.straight and 0 or 1))] = y
		end
	elseif cropping and cropping.held then
		if x >= cropping.origin[1] then
			cropping.viewport[3] = math.max(1, x - cropping.viewport[1])
			cropping.viewport[1] = cropping.origin[1]
		else
			cropping.viewport[1] = x
			cropping.viewport[3] = cropping.origin[1] - x
		end

		if y >= cropping.origin[2] then
			cropping.viewport[4] = math.max(1, y - cropping.viewport[2])
			cropping.viewport[2] = cropping.origin[2]
		else
			cropping.viewport[2] = y
			cropping.viewport[4] = cropping.origin[2] - y
		end
	end
end


love.mousereleased = function(x, y, b)
	x = x + viewport[1]
	y = y + viewport[2]
	if b == 1 then
		if cropping then
			cropping.held = false
		end
		if not line then
			return
		end
		addElement(line)
		line.size = settings.radius
		line = nil
	elseif b == 2 then
		if cp then
			settings.color[1], settings.color[2], settings.color[3] = unpack(cp.sc)
			cp = nil
			if text then
				text.c = settings.color()
			end
			if line then
				line.c = settings.color()
			end
		end
	elseif b == 3 then
		if choosing then
			choosing = false
			local mx, my = love.mouse.getPosition()
			love.graphics.captureScreenshot(function(imgD)
				local r, g, b = canvas:newImageData(1, 1, mx, my, 1, 1):getPixel(0, 0)
				settings.color[1], settings.color[2], settings.color[3] = r, g, b
			end)
		end
	end
end


love.keypressed = function(k, kk)
	if k == "escape" then
		text = nil
		cropping = nil
		choosing = nil
		line = nil
		cp = nil
		love.mouse.setCursor(cursors.base)
		return
	end

	if text then
		if k == "return" then
			if love.keyboard.isDown("lshift", "rshift") then
				text.text = text.text .. "\n"
			else
				addElement(text)
				text.x, text.y = love.mouse.getPosition()
				text.x = text.x + viewport[1]
				text.y = text.y + viewport[2]
				text.size = settings.fontSize
				text.time = nil
				text = nil
				love.mouse.setCursor(cursors.base)
			end
		end
		return
	elseif cropping then
		local magnitude = love.keyboard.isDown("lshift", "rshift") and math.floor(math.min(W/25, H/25)) or 1
		local dx = k == "left" and -magnitude or k == "right" and magnitude or 0
		local dy = k == "up" and -magnitude or k == "down" and magnitude or 0
		if love.keyboard.isDown("lalt") then
			cropping.viewport[3] = math.clamp(1, cropping.viewport[3] + dx, viewport[1] + W - cropping.viewport[1])
			cropping.viewport[4] = math.clamp(1, cropping.viewport[4] + dy, viewport[2] + H - cropping.viewport[2])
		else
			cropping.viewport[1] = math.clamp(0, cropping.viewport[1] + dx, viewport[1] + W - cropping.viewport[3])
			cropping.viewport[2] = math.clamp(0, cropping.viewport[2] + dy, viewport[2] + H - cropping.viewport[4])
		end
	elseif line then

	elseif choosing then

	else
		if k == "return" then
			text = {t = "text", text = "", time = time, c = settings.color()}
			love.mouse.setCursor(cursors.text)
		elseif k == "c" then
			cropping = {viewport = {unpack(viewport)}}
			love.mouse.setCursor(cursors.cropping)
		end
	end

end

love.keyreleased = function(k, kk)
	if cropping then
		if k == "return" then
			local element = {t = "crop", oldViewport = viewport}
			element.viewport = {unpack(cropping.viewport)}
			addElement(element)
			cropping = false
			love.mouse.setCursor(cursors.base)
			return
		end
	else
		if k == "z" and love.keyboard.isDown("lctrl", "rctrl") then
			undo()
		elseif k == "y" and love.keyboard.isDown("lctrl", "rctrl") then
			redo()
		end
	end

end


love.textinput = function(c)
	if text then
		text.text = text.text .. c
	end
end


love.wheelmoved = function(x, y)
	if not text then
		settings.radius = math.max(1, settings.radius + y)
	else
		settings.fontSize = math.max(1, settings.fontSize + y)
	end
end


love.quit = function()
	
	love.draw(true)
	io.write(canvas:newImageData():encode("png"):getString())
end
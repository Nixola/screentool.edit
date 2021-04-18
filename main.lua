local smooth = require "smooth"
local CP = require "colorPicker"

local i = love.graphics.newImage(love.image.newImageData(love.filesystem.newFileData(io.stdin:read "*a", "input.png")))
local W, H = i:getWidth(), i:getHeight()
local elements = {}

local settings = {
	color = setmetatable({1, 1, 1}, {__call = function(self) return {unpack(self)} end}),
	radius = 3,
	fontSize = 12
}
local font = setmetatable({}, {__index = function(t, i) if tonumber(i) then t[i] = love.graphics.newFont(i) return t[i] end end})

local line
local text
local cp

local bg

local canvas = love.graphics.newCanvas(W, H)

local time = 0
local splash = .5

local zoom = love.graphics.newQuad(0, 0, 16, 16, 1, 1)

local straight
local snap

local lastElement = 0

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

local addElement = function(element)
	lastElement = lastElement + 1
	elements[lastElement] = element
	for i = lastElement + 1, #elements do
		elements[i] = nil
	end
end

local drawElement = function(e, x, y)
	love.graphics.setColor(e.c)
	if e.t == "line" then
		if #e < 4 then return end
		love.graphics.setLineWidth(e.size or settings.radius)
		love.graphics.line(smooth(e, 3))
	elseif e.t == "text" then
		local c = ""
		if e.time and (e.time - time)%1 < .5 then
			c = "|"
		end
		love.graphics.setFont(font[e.size or settings.fontSize])
		love.graphics.print(e.text .. c, x or e.x, y or e.y)
	end
end


love.window.setMode(W, H)
love.window.setTitle("NixEdit")


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
	love.graphics.draw(i)
	for i = 1, lastElement do
		drawElement(elements[i])
	end

	if pure then
		love.graphics.setCanvas()
		return
	end

	if line then
		drawElement(line)
	elseif text then
		drawElement(text, love.mouse.getPosition())
	else
		love.graphics.setColor(settings.color)
		love.graphics.setLineWidth(1)
		love.graphics.circle("line", love.mouse.getX(), love.mouse.getY(), settings.radius, settings.radius*4)
	end

	if cp then
		love.graphics.setColor(0, 0, 0, 0.1)
		love.graphics.rectangle("fill", 0, 0, W+1, H+1)
		cp:draw()
	end
	if splash > 0 then
		love.graphics.setColor(1, 1, 1, (splash)^2)
		bg()
		love.graphics.setColor(0, 0, 0, (splash*2)^2)
		love.graphics.setFont(font[H/10])
		love.graphics.printf("EDIT", 0, H/3, W, "center")
	end
	love.graphics.setCanvas()
	love.graphics.setColor(1,1,1)
	love.graphics.draw(canvas)
	if choosing then
		zoom:setViewport(mx, my, 1, 1, W, H)
		love.graphics.draw(canvas, zoom, mx - 8, my - 8, 0, 16, 16)
		love.graphics.setColor(1, 1, 1, 0.6)
		love.graphics.rectangle("line", mx - 9, my - 9, 18, 18)
	end
	if not text and love.keyboard.isDown("space") then
		love.graphics.setColor(1, 1, 1, 0.3)
		love.graphics.setLineWidth(1)
		love.graphics.line(0, my - .5, W, my - .5)
		love.graphics.line(mx - .5, 0, mx - .5, H)
	end

end


love.mousepressed = function(x, y, b)
	if b == 1 and not text then
		line = {x, y, c = settings.color(), t = "line", straight = straight}
	elseif b == 2 then
		CP:create(x - 128, y - 128, 128)
		cp = CP
	elseif b == 3 then
		choosing = true
	end
end


love.mousemoved = function(x, y)
	if line then
		if snap and line.straight then
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
	end
end


love.mousereleased = function(x, y, b)
	if b == 1 then
		if not line then
			return
		end
		addElement(line)
		line.size = settings.radius
		line = nil
	elseif b == 2 then
		settings.color[1], settings.color[2], settings.color[3] = unpack(cp.sc)
		cp = nil
		if text then
			text.c = settings.color()
		end
		if line then
			line.c = settings.color()
		end
	elseif b == 3 then
		choosing = false
		local mx, my = love.mouse.getPosition()
		love.graphics.captureScreenshot(function(imgD)
			local r, g, b = canvas:newImageData(1, 1, mx, my, 1, 1):getPixel(0, 0)
			settings.color[1], settings.color[2], settings.color[3] = r, g, b
		end)
	end
end


love.keypressed = function(k, kk)

	if k == "return" then
		if not text then
			text = {t = "text", text = "", time = time, c = settings.color()}
		elseif not love.keyboard.isDown("lshift", "rshift") then
			addElement(text)
			text.x, text.y = love.mouse.getPosition()
			text.size = settings.fontSize
			text.time = nil
			text = nil
		end
		return
	elseif k == "escape" then
		text = nil
		choosing = nil
	elseif k == "shift" or k == "rshift" or k == "lshift" then
		straight = true
	elseif k == "ctrl" or k == "rctrl" or k == "lctrl" then
		snap = true
	end

	if not text then
		if k == "z" and love.keyboard.isDown("lctrl", "rctrl") then
			--elements[#elements] = nil
			lastElement = math.max(0, lastElement - 1)
		elseif k == "y" and love.keyboard.isDown("lctrl", "rctrl") then
			lastElement = math.min(#elements, lastElement + 1)
		end
	end
end

love.keyreleased = function(k, kk)
	if k == "shift" or k == "lshift" or k == "rshift" then
		straight = false
	elseif k == "ctrl" or k == "rctrl" or k == "lctrl" then
		snap = false
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
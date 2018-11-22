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

local time = 0
splash = .5

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
	love.graphics.setColor(1,1,1)
	if not pure then
		bg()
	end
	love.graphics.draw(i)
	for i, v in ipairs(elements) do
		drawElement(v)
	end

	if pure then
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
end


love.mousepressed = function(x, y, b)
	if b == 1 and not text then
		line = {x, y, c = settings.color(), t = "line"}
	elseif b == 2 then
		CP:create(x - 128, y - 128, 128)
		cp = CP
	end
end


love.mousemoved = function(x, y)
	if line then
		line[#line + 1] = x
		line[#line + 1] = y
	end
end


love.mousereleased = function(x, y, b)
	if b == 1 then
		if not line then
			return
		end
		elements[#elements + 1] = line
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
	end
end


love.keypressed = function(k, kk)

	if k == "return" then
		if not text then
			text = {t = "text", text = "", time = time, c = settings.color()}
		elseif not love.keyboard.isDown("lshift", "rshift") then
			elements[#elements + 1] = text
			text.x, text.y = love.mouse.getPosition()
			text.time = nil
			text = nil
		end
		return
	end

	if not text then
		if k == "z" and love.keyboard.isDown("lctrl", "rctrl") then
			elements[#elements] = nil
		end
	else
		if k == "escape" then
			text = nil
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
	local c = love.graphics.newCanvas(W, H)
	love.graphics.setCanvas(c)
	love.draw(true)
	love.graphics.setCanvas()
	io.write(c:newImageData():encode("png"):getString())
end
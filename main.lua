local smooth = require "smooth"
local ColorPicker = require "colorPicker"
require "utils"
local utf8 = require "utf8"

local Editor = {}

Editor.input = love.graphics.newImage(love.image.newImageData(love.filesystem.newFileData(io.stdin:read "*a", "input.png")))
Editor.width, Editor.height = Editor.input:getWidth(), Editor.input:getHeight()
Editor.elements = {}
Editor.undone = {}

Editor.settings = {
	color = setmetatable({1, 1, 1}, {__call = function(self) return {unpack(self)} end}),
	radius = 3,
	fontSize = 12
}
Editor.font = setmetatable({}, {__index = function(t, i) if tonumber(i) then t[i] = love.graphics.newFont(i) return t[i] end end})

Editor.viewport = {0, 0, Editor.width, Editor.height}

Editor.canvas = love.graphics.newCanvas(Editor.width, Editor.height)

Editor.time = 0
Editor.splash = .5

Editor.zoom = love.graphics.newQuad(0, 0, 16, 16, 1, 1)

Editor.cursors = {}
Editor.cursors.base = love.mouse.getSystemCursor("arrow")
Editor.cursors.cropping = love.mouse.getSystemCursor("crosshair")
Editor.cursors.text = love.mouse.getSystemCursor("ibeam")

do
	local quad = love.graphics.newQuad(0, 0, Editor.width, Editor.height, 16, 16)
	local img = love.graphics.newImage(love.image.newImageData(love.filesystem.newFileData(love.data.decode("string", "base64", 
		[[iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAACXBIWXMAAC4jAAAuIwF4pT92AAAA
K0lEQVQ4y2OcOXPmfwY84OzZs/ikGZgYKASjBgwGA1gIxbOxsfFoIA5/AwAHZQhTm7rVdAAAAABJ
RU5ErkJggg==
]]), "bg.png")))
	img:setWrap("repeat", "repeat")
	Editor.bg = function(self)
		love.graphics.draw(img, quad)
	end
end

Editor.resize = function(self, newViewport)
	self.width, self.height = newViewport[3], newViewport[4]
	self.canvas = love.graphics.newCanvas(self.width, self.height)
	self.viewport = {unpack(newViewport)}
	love.window.setMode(self.width, self.height)
end

Editor.addElement = function(self, element, redone)
	self.elements[#self.elements + 1] = element
	if not redone then
		self.undone = {}
	end
	if element.t == "crop" then -- TODO: if element.onAdd
		self:resize(element.viewport)
	end
end

Editor.undo = function(self)
	if #self.elements == 0 then return end
	local element = self.elements[#self.elements]
	self.undone[#self.undone + 1] = element
	self.elements[#self.elements] = nil
	if element.t == "crop" then -- TODO: if element.onUndo
		self:resize(element.oldViewport)
	end
end

Editor.redo = function(self)
	if #self.undone == 0 then return end
	self:addElement(self.undone[#self.undone], true)
	self.undone[#self.undone] = nil
end

Editor.drawElement = function(self, e, x, y)
	x = x or 0
	y = y or 0
	if e.c then
		love.graphics.setColor(e.c)
	end
	if e.t == "line" then
		if #e < 4 then return end
		love.graphics.push()
		love.graphics.translate(-x, -y)
		love.graphics.setLineWidth(e.size or self.settings.radius)
		love.graphics.line(smooth(e, 3))
		love.graphics.pop()
	elseif e.t == "text" then
		local c = ""
		if e.time and (e.time - self.time)%1 < 0.5 then
			c = "|"
		end
		love.graphics.setFont(self.font[e.size or self.settings.fontSize])
		love.graphics.print(e.text .. c, e.x or x, e.y or y)
	elseif e.t == "fill" then -- TODO: x, y, w, h from e
		love.graphics.rectangle("fill", -1, -1, self.width+2, self.height+2)
	end
end


love.window.setMode(Editor.width, Editor.height)
love.window.setTitle("NixEdit")
love.keyboard.setKeyRepeat(true)


love.update = function(dt)
	Editor.time = Editor.time + dt
	Editor.splash = Editor.splash - dt
	if Editor.colorPicker then
		Editor.colorPicker:update()
	end
end


love.draw = function(pure)
	local mx, my = love.mouse.getPosition()
	love.graphics.setCanvas(Editor.canvas)
	love.graphics.setColor(1,1,1)
	if not pure then
		Editor:bg()
	end
	love.graphics.push()
	love.graphics.translate(-Editor.viewport[1], -Editor.viewport[2])
	love.graphics.draw(Editor.input)
	for i, v in ipairs(Editor.elements) do
		Editor:drawElement(v)
	end

	love.graphics.setCanvas()
	if pure then
		return
	end
	love.graphics.setColor(1,1,1)
	love.graphics.pop()
	love.graphics.draw(Editor.canvas)
	if Editor.colorPicker then
		love.graphics.setColor(0, 0, 0, 0.1)
		love.graphics.rectangle("fill", 0, 0, Editor.width+1, Editor.height+1)
		Editor.colorPicker:draw()
	end
	if Editor.line then
		Editor:drawElement(Editor.line, Editor.viewport[1], Editor.viewport[2])
	elseif Editor.text then
		Editor:drawElement(Editor.text, love.mouse.getPosition())
	else
		love.graphics.setColor(Editor.settings.color)
		love.graphics.setLineWidth(1)
		love.graphics.circle("line", love.mouse.getX(), love.mouse.getY(), Editor.settings.radius, Editor.settings.radius*4)
	end
	if Editor.splash > 0 then
		love.graphics.setColor(1, 1, 1, (Editor.splash)^2)
		Editor:bg()
		love.graphics.setColor(0, 0, 0, (Editor.splash*2)^2)
		love.graphics.setFont(Editor.font[Editor.height/10])
		love.graphics.printf("EDIT", 0, Editor.height/3, Editor.width, "center")
	end
	if Editor.choosing then
		Editor.zoom:setViewport(mx, my, 1, 1, Editor.width, Editor.height)
		love.graphics.setColor(1,1,1)
		love.graphics.draw(Editor.canvas, Editor.zoom, mx - 8, my - 8, 0, 16, 16)
		love.graphics.setColor(1, 1, 1, 0.6)
		love.graphics.rectangle("line", mx - 9, my - 9, 18, 18)
	end
	if love.keyboard.isDown("space") then
		if Editor.cropping then
			local font = Editor.font[12]
			love.graphics.setColor(1,1,1, .5)
			love.graphics.setFont(font)

			love.graphics.print(Editor.cropping.viewport[3] .. "x" .. Editor.cropping.viewport[4], Editor.cropping.viewport[1] + 2 - Editor.viewport[1], Editor.cropping.viewport[2] - Editor.viewport[2])
			local mrx, mry, mlx, mly, mtx, mty, mbx, mby
			--margin right x, margin right y, margin left x, .., margin top .., margin bottom; never fucking do that again

			local ml = Editor.cropping.viewport[1] - Editor.viewport[1]
			mlx = math.max(0, Editor.cropping.viewport[1] - font:getWidth(ml) - 2 - Editor.viewport[1])
			mly = Editor.cropping.viewport[2] + Editor.cropping.viewport[4] / 2 - font:getHeight() / 2 - Editor.viewport[2]
			love.graphics.print(ml, math.floor(mlx), math.floor(mly))

			local mr = Editor.width - Editor.cropping.viewport[1] - Editor.cropping.viewport[3] + Editor.viewport[1]
			mrx = math.min(Editor.width - font:getWidth(mr), Editor.cropping.viewport[1] + Editor.cropping.viewport[3] - Editor.viewport[1])
			mry = mly
			love.graphics.print(mr, math.floor(mrx), math.floor(mry))

			local mt = Editor.cropping.viewport[2] - Editor.viewport[2]
			mtx = Editor.cropping.viewport[1] - Editor.viewport[1]
			mty = math.max(0, Editor.cropping.viewport[2] - font:getHeight() - Editor.viewport[2])
			love.graphics.printf(mt, mtx, mty, Editor.cropping.viewport[3], "center")

			local mb = Editor.height - Editor.cropping.viewport[2] - Editor.cropping.viewport[4] + Editor.viewport[2]
			mbx = Editor.cropping.viewport[1] - Editor.viewport[1]
			mby = math.min(Editor.height - font:getHeight(), Editor.cropping.viewport[2] + Editor.cropping.viewport[4] - Editor.viewport[2])
			love.graphics.printf(Editor.height - Editor.cropping.viewport[2] - Editor.cropping.viewport[4], mbx, mby, Editor.cropping.viewport[3], "center")
		elseif Editor.text then
			-- obviously nothing
		elseif Editor.choosing then
			-- could display RGB?
		else -- both when drawing a line and when nothing else is happening
			love.graphics.setColor(1, 1, 1, 0.3)
			love.graphics.setLineWidth(1)
			love.graphics.line(0, my - .5, Editor.width, my - .5)
			love.graphics.line(mx - .5, 0, mx - .5, Editor.height)
		end
	end
	if Editor.cropping then
		local x, y, w, h = unpack(Editor.cropping.viewport)
		x = x - Editor.viewport[1]
		y = y - Editor.viewport[2]
		love.graphics.setColor(1,1,1, .5)
		love.graphics.setLineWidth(2)
		love.graphics.rectangle("line", x, y, w, h)
		love.graphics.stencil(function() love.graphics.rectangle("fill", x, y, w, h) end, "invert")
		love.graphics.setStencilTest("notequal", 255)
		love.graphics.setColor(0, 0, 0, .5)
		love.graphics.rectangle("fill", 0, 0, Editor.width, Editor.height)
	end
end


love.mousepressed = function(x, y, b)
	x = x + Editor.viewport[1]
	y = y + Editor.viewport[2]
	if Editor.cropping then
		if b == 1 then
			Editor.cropping.held = true
			Editor.cropping.viewport[1] = x
			Editor.cropping.viewport[2] = y
			Editor.cropping.viewport[3] = 1
			Editor.cropping.viewport[4] = 1
			Editor.cropping.origin = {x, y}
		end
	elseif Editor.text then

	elseif Editor.choosing then

	elseif Editor.line then

	else
		if b == 1 then
			Editor.line = {x, y, c = Editor.settings.color(), t = "line", straight = love.keyboard.isDown("lshift", "rshift")}
		elseif b == 2 then
			ColorPicker:create(x - 128 - Editor.viewport[1], y - 128 - Editor.viewport[2], 128)
			Editor.colorPicker = ColorPicker
		elseif b == 3 then
			Editor.choosing = true
		end
	end
end


love.mousemoved = function(x, y)
	x = x + Editor.viewport[1]
	y = y + Editor.viewport[2]
	if Editor.line then
		if love.keyboard.isDown("lctrl", "rctrl") and Editor.line.straight then
			local dy = y - Editor.line[2]
			local dx = x - Editor.line[1]
			local a = math.atan2(dy, dx)
			local d = (dy*dy + dx*dx) ^ .5
			a = math.floor(a / math.pi * 8 + .5)/8 * math.pi
			Editor.line[3] = Editor.line[1] + math.cos(a) * d
			Editor.line[4] = Editor.line[2] + math.sin(a) * d
		else
			Editor.line[math.max(3, #Editor.line + (Editor.line.straight and -1 or 1))] = x
			Editor.line[math.max(4, #Editor.line + (Editor.line.straight and 0 or 1))] = y
		end
	elseif Editor.cropping and Editor.cropping.held then
		if x >= Editor.cropping.origin[1] then
			Editor.cropping.viewport[3] = math.max(1, x - Editor.cropping.viewport[1])
			Editor.cropping.viewport[1] = Editor.cropping.origin[1]
		else
			Editor.cropping.viewport[1] = x
			Editor.cropping.viewport[3] = Editor.cropping.origin[1] - x
		end

		if y >= Editor.cropping.origin[2] then
			Editor.cropping.viewport[4] = math.max(1, y - Editor.cropping.viewport[2])
			Editor.cropping.viewport[2] = Editor.cropping.origin[2]
		else
			Editor.cropping.viewport[2] = y
			Editor.cropping.viewport[4] = Editor.cropping.origin[2] - y
		end
	end
end


love.mousereleased = function(x, y, b)
	x = x + Editor.viewport[1]
	y = y + Editor.viewport[2]
	if b == 1 then
		if Editor.cropping then
			Editor.cropping.held = false
		end
		if not Editor.line then
			return
		end
		Editor.line.size = Editor.settings.radius
		Editor:addElement(Editor.line)
		Editor.line = nil
	elseif b == 2 then
		if Editor.colorPicker then
			Editor.settings.color[1], Editor.settings.color[2], Editor.settings.color[3] = unpack(Editor.colorPicker.sc)
			Editor.colorPicker = nil
			if Editor.text then
				Editor.text.c = Editor.settings.color()
			end
			if Editor.line then
				Editor.line.c = Editor.settings.color()
			end
		end
	elseif b == 3 then
		if Editor.choosing then
			Editor.choosing = false
			local mx, my = love.mouse.getPosition()
			love.graphics.captureScreenshot(function(imgD)
				local r, g, b = Editor.canvas:newImageData(1, 1, mx, my, 1, 1):getPixel(0, 0)
				Editor.settings.color[1], Editor.settings.color[2], Editor.settings.color[3] = r, g, b
			end)
		end
	end
end


love.keypressed = function(k, kk)
	if k == "escape" then
		Editor.text = nil
		Editor.cropping = nil
		Editor.choosing = nil
		Editor.line = nil
		Editor.colorPicker = nil
		love.mouse.setCursor(cursors.base)
		return
	end

	if Editor.text then
		if k == "return" then
			if love.keyboard.isDown("lshift", "rshift") then
				Editor.text.text = Editor.text.text .. "\n"
			else
				Editor.text.x, Editor.text.y = love.mouse.getPosition()
				Editor.text.x = Editor.text.x + Editor.viewport[1]
				Editor.text.y = Editor.text.y + Editor.viewport[2]
				Editor.text.size = Editor.settings.fontSize
				Editor.text.time = nil
				Editor:addElement(Editor.text)
				Editor.text = nil
				love.mouse.setCursor(Editor.cursors.base)
			end
		elseif k == "backspace" then
			if utf8.len(Editor.text.text) > 0 then
				Editor.text.text = Editor.text.text:match("^(.*)" .. utf8.charpattern)
			end
		end
		return
	elseif Editor.cropping then
		local magnitude = love.keyboard.isDown("lshift", "rshift") and math.floor(math.min(Editor.width/25, Editor.height/25)) or 1
		local dx = k == "left" and -magnitude or k == "right" and magnitude or 0
		local dy = k == "up" and -magnitude or k == "down" and magnitude or 0
		if love.keyboard.isDown("lalt") then
			Editor.cropping.viewport[3] = math.clamp(1, Editor.cropping.viewport[3] + dx, Editor.viewport[1] + Editor.width - Editor.cropping.viewport[1])
			Editor.cropping.viewport[4] = math.clamp(1, Editor.cropping.viewport[4] + dy, Editor.viewport[2] + Editor.height - Editor.cropping.viewport[2])
		else
			Editor.cropping.viewport[1] = math.clamp(0, Editor.cropping.viewport[1] + dx, Editor.viewport[1] + Editor.width - Editor.cropping.viewport[3])
			Editor.cropping.viewport[2] = math.clamp(0, Editor.cropping.viewport[2] + dy, Editor.viewport[2] + Editor.height - Editor.cropping.viewport[4])
		end
	elseif Editor.line then

	elseif Editor.choosing then

	else
		if k == "return" then
			Editor.text = {t = "text", text = "", time = time, c = Editor.settings.color()}
			love.mouse.setCursor(Editor.cursors.text)
		elseif k == "c" then
			Editor.cropping = {viewport = {unpack(Editor.viewport)}}
			love.mouse.setCursor(Editor.cursors.cropping)
		elseif k == "f" then
			local element = {t = "fill", c = Editor.settings.color(), x = -1, y = -1, w = W+2, h = H+2}
			Editor:addElement(element)
		end
	end

end

love.keyreleased = function(k, kk)
	if Editor.cropping then
		if k == "return" then
			local element = {t = "crop", oldViewport = Editor.viewport}
			element.viewport = {unpack(Editor.cropping.viewport)}
			Editor:addElement(element)
			Editor.cropping = false
			love.mouse.setCursor(Editor.cursors.base)
			return
		end
	else
		if k == "z" and love.keyboard.isDown("lctrl", "rctrl") then
			Editor:undo()
		elseif k == "y" and love.keyboard.isDown("lctrl", "rctrl") then
			Editor:redo()
		end
	end

end


love.textinput = function(c)
	if Editor.text then
		Editor.text.text = Editor.text.text .. c
	end
end


love.wheelmoved = function(x, y)
	if not Editor.text then
		Editor.settings.radius = math.max(1, Editor.settings.radius + y)
	else
		Editor.settings.fontSize = math.max(1, Editor.settings.fontSize + y)
	end
end


love.quit = function()
	
	love.draw(true)
	io.write(Editor.canvas:newImageData():encode("png"):getString())
end
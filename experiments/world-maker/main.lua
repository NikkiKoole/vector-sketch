package.path = package.path .. ";../../?.lua"

local inspect = require "vendor.inspect"

local parentize = require 'lib.parentize'
local render = require 'lib.render'
local mesh = require 'lib.mesh'

local ui = require 'lib.ui'

function love.keypressed(key)
   if key == 'escape' then
      love.event.quit()
   end
end

function love.load()
   bgColor = { r = 0, g = 0, b = 0 }
   bgColor.r, bgColor.g, bgColor.b = hex2rgb('af9f5e')
   font = love.graphics.newFont("WindsorBT-Roman.otf", 24)
   love.graphics.setFont(font)

   activeButton = nil

   types = {
      ["add"] = {
         "places to be", "things that move",
         "things that are alive", "things that do *stuff*",
         "things that just look nice", "things to hold"
      },
      ["world"] = { "edit", "load", "save" },
      ["camera"] = { "bounds" },
      ["run"] = { "room" }
   }

   order = { "add", "world", "camera", "run" }

   world = {
      meta = {},
      rooms = {
      },
   }
   root = {
      folder = true,
      name = 'root',
      transforms = { g = { 0, 0, 0, 1, 1, 0, 0 }, l = { 1024 / 2, 768 / 2, 0, 4.0, 4.0, 0, 0 } },
      children = {}
   }

   parentize.parentize(root)
   mesh.meshAll(root)
   render.renderThings(root)

end

function love.mousemoved(x, y, dx, dy)
   if love.mouse.isDown(1) then
      root.transforms.l[1] = root.transforms.l[1] + dx
      root.transforms.l[2] = root.transforms.l[2] + dy
   end
end

function love.mousereleased()

   if not ui.mouseHovered then
      activeButton = nil
   end
end

function love.wheelmoved(x, y)
   local scale = root.transforms.l[4]

   local posx, posy = love.mouse.getPosition()
   local ix1, iy1 = root.transforms._g:inverseTransformPoint(posx, posy)

   root.transforms.l[4] = scale * ((y > 0) and 1.05 or 0.95)
   root.transforms.l[5] = scale * ((y > 0) and 1.05 or 0.95)

   --- ugh
   local tl = root.transforms.l
   root._localTransform = love.math.newTransform(tl[1], tl[2], tl[3], tl[4], tl[5], tl[6], tl[7])
   root.transforms._g = root._localTransform
   ---

   local ix2, iy2 = root.transforms._g:inverseTransformPoint(posx, posy)
   local dx = ix1 - ix2
   local dy = iy1 - iy2

   local dx3, dy3 = getGlobalDelta(root.transforms._g, dx, dy)
   root.transforms.l[1] = root.transforms.l[1] - dx3
   root.transforms.l[2] = root.transforms.l[2] - dy3

   -- do it again
   tl = root.transforms.l
   root._localTransform = love.math.newTransform(tl[1], tl[2], tl[3], tl[4], tl[5], tl[6], tl[7])
   root.transforms._g = root._localTransform
end

function getGlobalDelta(transform, dx, dy)
   -- this one is only used in the wheel moved offset stuff
   local dx1, dy1 = transform:transformPoint(0, 0)
   local dx2, dy2 = transform:transformPoint(dx, dy)
   local dx3 = dx2 - dx1
   local dy3 = dy2 - dy1
   return dx3, dy3
end

function eventBus(event)
   local calls = {
      ["add room"] = function() print("poep!") end
   }
   if calls[event] then calls[event]() end
end

function drawUI()
   local buttonMarginSide = 20
   local buttonHeight = 40
   local runningX = 10

   for i = 1, #order do
      local str = order[i]
      local w = font:getWidth(str) + buttonMarginSide
      if labelbutton(str, str, runningX, 10, w, buttonHeight).clicked then
         if activeButton == str then
            activeButton = nil
         else
            activeButton = str
         end
      end

      if activeButton == str then
         for j = 1, #types[str] do
            local id = str .. " " .. types[str][j]
            local width = math.max(font:getWidth(types[str][j]), font:getWidth(str)) + buttonMarginSide
            if labelbutton(id, types[str][j], runningX, 10 + j * buttonHeight, width, buttonHeight).clicked then
               eventBus(id)
            end
         end
      end
      runningX = runningX + w + buttonMarginSide
   end
end

function drawGrid(width, height)
   love.graphics.setColor(1, 1, 1)
   love.graphics.setLineWidth(root.transforms.l[5])
   local m2cm = 100
   for x = -width / 2 * m2cm, width / 2 * m2cm, m2cm do
      local sx, y = root.transforms._g:transformPoint(x, 0)
      if sx >= 0 and sx <= 1024 then
         love.graphics.line(sx, 0, sx, 768)
      end
   end
   for y = -height / 2 * m2cm, height / 2 * m2cm, m2cm do
      local x, sy = root.transforms._g:transformPoint(0, y)
      if sy >= 0 and sy <= 768 then
         love.graphics.line(0, sy, 1024, sy)
      end
   end

   local cx, cy = root.transforms._g:transformPoint(0, 0)
   love.graphics.rectangle("fill", cx - 5, cy - 5, 10, 10)

   love.graphics.setLineWidth(1)
end

function love.draw()

   ui.handleMouseClickStart()
   love.graphics.clear(bgColor.r, bgColor.g, bgColor.b)

   drawGrid(100, 10)

   render.renderThings(root)

   drawUI()
end

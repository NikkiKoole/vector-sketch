inspect = require 'inspect'
require 'ui'
require 'palettes'
require 'util'
polyline = require 'polyline'
poly = require 'poly'


function love.keypressed(key)
   if key == "escape" then
      if (editingModeSub ~= nil) then
	 editingModeSub = nil
      elseif (editingMode ~= nil) then
	 editingMode = nil
      else
	 if (quitDialog == true) then
	    love.event.quit()
	 elseif (quitDialog == false) then
	    quitDialog = true
	 end
      end
   else
      if (quitDialog) then
	 quitDialog = false
      end
   end
end

function toWorldPos(x, y)
   return (x / camera.scale) - camera.x, (y / camera.scale) - camera.y
end
function mouseOverPolyPoint(mx, my, ppx, ppy)
   local wx, wy = toWorldPos(mx, my)
   local dot_x = ppx - 5/camera.scale
   local dot_y = ppy - 5/camera.scale
   local dot_size = 10 / camera.scale
   return pointInRect(wx,wy, dot_x, dot_y, dot_size, dot_size)
end
function getIndexOfHoveredPolyPoint(mx, my, points)
   local wx, wy = toWorldPos(mx, my)
   for i = 1, #points do
      local dot_x = points[i][1] - 5/camera.scale
      local dot_y = points[i][2] - 5/camera.scale
      local dot_size = 10 / camera.scale
      if pointInRect(wx,wy, dot_x, dot_y, dot_size, dot_size) then
	 return i
      end
   end
   return 0
end

function getClosestEdgeIndex(wx, wy, points)
   local closestEdgeIndex = 0
   local closestDistance = 99999999999999
   for j = 1, #points do
      local next = (j == #points and 1) or j+1
      local d = distancePointSegment(wx, wy, points[j][1], points[j][2], points[next][1], points[next][2])
      if (d < closestDistance) then
	 closestDistance = d
	 closestEdgeIndex = j
      end
   end
   return closestEdgeIndex
end


function love.mousepressed(x,y, button)
   lastDraggedElement = nil
   if editingMode == nil then
      editingMode = 'move'
   end
   if (current_shape_index == 0 ) then return end

   local points = shapes[current_shape_index].points
   local wx, wy = toWorldPos(x, y)
   if editingMode == 'polyline' and not mouseState.hoveredSomething   then
      if (editingModeSub == 'polyline-add' ) then
	 table.insert(shapes[current_shape_index].points, {wx, wy})
      end

      local index =  getIndexOfHoveredPolyPoint(x, y, points)
      if (index > 0) then
	 if (editingModeSub == 'polyline-remove') then
	    table.remove (shapes[current_shape_index].points, index)
	 end
	 if (editingModeSub == 'polyline-edit') then
	    lastDraggedElement = {id='polyline', index=index}
	 end
      end

      if (editingModeSub == 'polyline-insert') then
	 local closestEdgeIndex = getClosestEdgeIndex(wx, wy, points)
	 table.insert(shapes[current_shape_index].points, closestEdgeIndex+1, {wx, wy})
      end
   end

end

function love.mousereleased(x,y, button)
   if editingMode == 'move' then
      editingMode = nil
   end
   lastDraggedElement = nil
end

function love.mousemoved(x,y, dx, dy)
   if editingMode == 'move' and love.mouse.isDown(1) or love.keyboard.isDown('space') then
      camera.x = camera.x + dx / camera.scale
      camera.y = camera.y + dy / camera.scale
   end
   if editingMode == 'backdrop' and  editingModeSub == 'backdrop-move' and love.mouse.isDown(1) then
      backdrop.x = backdrop.x + dx / camera.scale
      backdrop.y = backdrop.y + dy / camera.scale
   end

   if editingMode == 'polyline' and  editingModeSub == 'polyline-move' and love.mouse.isDown(1)  then
      local points = shapes[current_shape_index].points
      local beginIndex = 2 -- if first and last arent identical
      if points[1] == points[#points] then
      else
	 beginIndex = 1
      end

      for i = beginIndex, #points do
	 local p = shapes[current_shape_index].points[i]
	 shapes[current_shape_index].points[i][1] = p[1] + dx / camera.scale
	 shapes[current_shape_index].points[i][2] = p[2] + dy / camera.scale
      end
   end

   if (editingMode == 'polyline') and (editingModeSub == 'polyline-edit') then
      if (lastDraggedElement and lastDraggedElement.id == 'polyline') then
   	 local dragIndex = lastDraggedElement.index
   	 if dragIndex > 0 then
   	    local wx, wy = toWorldPos(x, y)
   	    local points = shapes[current_shape_index].points
   	    if (dragIndex <= #points) then
   	       points[dragIndex][1] = wx
   	       points[dragIndex][2] = wy
   	    end
   	 end
      end
   end
end

function love.wheelmoved(x,y)
   local posx, posy = love.mouse.getPosition()
   local wx = camera.x + ( posx / camera.scale)
   local wy = camera.y + ( posy / camera.scale)

   camera.scale =  camera.scale * ((y>0) and 1.1 or 0.9)

   local wx2 = camera.x + ( posx / camera.scale)
   local wy2 = camera.y + ( posy / camera.scale)

   camera.x = camera.x - (wx-wx2)
   camera.y = camera.y - (wy-wy2)
end

function love.load()
   love.window.setMode(1024+300, 768, {resizable=true, vsync=false, minwidth=400, minheight=300})

   camera = {x=0, y=0, scale=1}
   editingMode = nil
   editingModeSub = nil
   medium = love.graphics.newFont( "resources/fonts/MPLUSRounded1c-Medium.ttf", 16)
   love.graphics.setFont(medium)

   ui = {
      polyline = love.graphics.newImage("resources/ui/polyline.png"),
      polyline_add = love.graphics.newImage("resources/ui/polyline-add.png"),
      polyline_edit = love.graphics.newImage("resources/ui/polyline-edit.png"),
      polyline_remove = love.graphics.newImage("resources/ui/polyline-remove.png"),
      insert_link = love.graphics.newImage("resources/ui/insert-link.png"),
      backdrop = love.graphics.newImage("resources/ui/backdrop.png"),
      grid = love.graphics.newImage("resources/ui/grid.png"),
      palette = love.graphics.newImage("resources/ui/palette.png"),
      pen = love.graphics.newImage("resources/ui/pen.png"),
      pencil = love.graphics.newImage("resources/ui/pencil.png"),
      polygon = love.graphics.newImage("resources/ui/polygon.png"),
      add = love.graphics.newImage("resources/ui/add.png"),
      remove = love.graphics.newImage("resources/ui/remove.png"),
      delete = love.graphics.newImage("resources/ui/delete.png"),
      move = love.graphics.newImage("resources/ui/move.png"),
      visible = love.graphics.newImage("resources/ui/visible.png"),
      not_visible = love.graphics.newImage("resources/ui/not-visible.png"),
      resize = love.graphics.newImage("resources/ui/resize.png"),
      opacity = love.graphics.newImage("resources/ui/opacity.png"),
      settings = love.graphics.newImage("resources/ui/settings.png"),
      badge = love.graphics.newImage("resources/ui/badge.png"),
      layer_group = love.graphics.newImage("resources/ui/layer-group.png"),
      object_group = love.graphics.newImage("resources/ui/object-group.png"),
      rotate = love.graphics.newImage("resources/ui/rotate.png"),
      transform = love.graphics.newImage("resources/ui/transform.png"),
      next = love.graphics.newImage("resources/ui/next.png"),
      previous = love.graphics.newImage("resources/ui/previous.png"),
      lines = love.graphics.newImage("resources/ui/lines.png"),
      lines2 = love.graphics.newImage("resources/ui/lines2.png"),
      move_up = love.graphics.newImage("resources/ui/move-up.png"),
      move_down = love.graphics.newImage("resources/ui/move-down.png"),

   }

   cursors = {
      hand= love.mouse.getSystemCursor("hand"),
      arrow= love.mouse.getSystemCursor("arrow")
   }

   palette = {
      name='mix-and-match', -- nijntje , classic lego & fabuland
      colors={}
   }
   for i = 1, #miffy.colors do
      table.insert(palette.colors, miffy.colors[i])
   end
   for i = 1, #lego.colors do
      table.insert(palette.colors, lego.colors[i])
   end
   for i = 1, #fabuland.colors do
      table.insert(palette.colors, fabuland.colors[i])
   end

   mouseState = {
      hoveredSomething = false,
      down = false,
      lastDown = false,
      click = false,
   }

   -- shapes = { {
   -- 	 color = {1,0,0, 0.8},
   -- 	 points = {{100,100},{200,100},{200,200},{100,200}},
   -- }, {
   -- 	 color = {1,1,0, 0.8},
   -- 	 points = {{150,100},{250,100},{250,200},{150,200}},
   --    }, {
   -- 	 outline = true,
   -- 	 points = {}
   -- }}


   shapes = {
      {
color={0.00,0.00,0.00,1.00},
points={{44.35,12.37}, {51.96,11.02}, {67.36,9.62}, {75.09,9.54}, {81.34,10.90}, {90.51,13.83}, {96.74,15.21}, {99.95,15.44}, {103.25,15.86}, {109.92,16.76}, {113.01,18.01}, {115.27,20.17}, {118.72,25.37}, {120.00,28.23}, {120.00,28.64}, {120.00,31.57}, {120.00,39.67}, {120.00,52.94}, {120.00,61.04}, {120.00,63.97}, {120.00,64.38}, {118.39,74.77}, {114.45,95.40}, {111.64,105.53}, {110.57,105.70}, {108.43,106.04}, {107.36,106.21}, {106.94,100.52}, {106.89,89.12}, {107.81,77.75}, {109.56,66.47}, {110.71,60.89}, {111.84,55.26}, {112.19,46.71}, {111.23,41.11}, {110.31,38.38}, {109.29,46.38}, {107.77,58.50}, {105.66,66.26}, {103.99,69.95}, {100.45,76.58}, {92.73,89.47}, {88.57,95.73}, {86.47,98.22}, {81.19,101.65}, {75.02,103.21}, {68.57,103.19}, {65.45,102.66}, {60.45,101.71}, {52.89,100.12}, {48.14,98.31}, {45.94,97.03}, {44.17,95.08}, {41.43,90.64}, {38.39,83.28}, {36.38,78.45}, {34.35,73.03}, {31.71,61.81}, {29.96,44.51}, {29.21,33.00}, {27.12,34.44}, {22.87,37.33}, {21.23,39.23}, {20.56,43.47}, {20.44,51.97}, {22.04,64.71}, {23.31,73.15}, {23.24,78.17}, {22.18,88.17}, {21.38,93.13}, {20.82,95.64}, {19.81,99.47}, {18.55,101.72}, {17.63,102.66}, {16.53,103.31}, {14.13,103.80}, {10.43,102.99}, {8.26,101.77}, {7.95,95.98}, {8.53,84.42}, {9.76,72.87}, {10.52,61.31}, {10.38,55.52}, {10.20,49.52}, {10.18,37.51}, {10.59,31.52}, {11.21,28.35}, {14.07,22.78}, {18.58,18.34}, {24.12,15.19}, {27.09,14.14}, {31.37,13.45}, {40.05,12.98}, }
},
{
color={0.00,0.00,0.00,1.00},
points={{75.23,10.71}, {66.92,10.76}, {54.46,11.53}, {46.33,13.14}, {42.36,14.44}, {39.94,15.92}, {35.94,19.82}, {33.15,24.66}, {31.70,30.10}, {31.52,32.93}, {31.11,40.32}, {31.97,55.06}, {34.89,69.56}, {39.67,83.56}, {42.69,90.29}, {43.44,91.96}, {45.42,94.68}, {49.32,97.49}, {59.02,100.22}, {65.59,101.40}, {68.56,101.77}, {74.75,101.80}, {80.69,100.48}, {85.73,97.28}, {87.70,94.82}, {92.37,87.34}, {101.27,72.12}, {105.14,64.19}, {106.25,61.27}, {107.54,55.21}, {107.85,45.86}, {107.49,39.66}, {106.78,34.54}, {104.79,26.94}, {102.08,22.62}, {100.11,20.87}, {97.29,19.02}, {91.33,15.81}, {81.81,12.24}, }
},
{
color={0.00,0.00,0.00,1.00},
points={{11.32,33.28}, {11.18,42.70}, {11.48,61.55}, {10.83,70.95}, {10.00,78.60}, {8.89,93.95}, {8.70,101.65}, {10.23,101.84}, {13.29,102.16}, {14.83,102.17}, {15.90,101.95}, {17.60,100.80}, {19.25,98.00}, {19.89,96.00}, {21.12,88.55}, {22.25,77.24}, {21.82,69.72}, {21.07,66.00}, {20.29,62.33}, {19.32,54.86}, {19.26,47.33}, {20.27,39.91}, {21.24,36.29}, {23.24,35.19}, {27.36,33.20}, {29.44,32.27}, {30.96,27.46}, {35.43,18.50}, {38.39,14.43}, {36.12,14.22}, {31.55,14.44}, {27.06,15.48}, {22.82,17.28}, {18.99,19.78}, {15.76,22.93}, {13.27,26.67}, {11.71,30.95}, }
},
{
color={0.00,0.00,0.00,1.00},
points={{95.92,15.50}, {97.80,17.25}, {101.53,20.79}, {103.35,22.62}, {104.67,24.66}, {106.61,29.13}, {108.29,33.74}, {110.55,38.01}, {112.14,39.88}, {113.25,41.36}, {114.22,44.72}, {113.87,50.25}, {113.45,53.80}, {111.35,63.50}, {108.68,78.15}, {107.67,88.01}, {107.52,92.98}, {107.28,96.27}, {108.26,102.70}, {109.44,105.77}, {111.06,101.81}, {113.70,93.75}, {116.39,81.35}, {118.59,55.94}, {118.98,38.97}, {118.82,34.53}, {118.17,27.73}, {116.56,23.61}, {115.18,21.79}, {113.29,19.93}, {108.79,17.54}, {101.06,16.07}, }
},
{
color={0.00,0.00,0.00,1.00},
points={{44.60,17.49}, {55.55,17.32}, {77.44,17.54}, {88.36,18.36}, {77.41,18.36}, {55.52,18.34}, }
},
{
color={0.00,0.00,0.00,1.00},
points={{35.66,23.71}, {42.03,22.13}, {51.77,20.86}, {58.31,21.07}, {61.57,21.58}, {65.55,22.01}, {73.56,21.96}, {81.55,21.70}, {89.47,22.43}, {93.37,23.54}, {84.51,23.11}, {71.21,23.04}, {62.38,22.54}, {57.98,21.93}, {55.18,21.70}, {49.59,21.91}, {41.23,23.07}, }
},
{
color={0.00,0.00,0.00,1.00},
points={{38.24,30.65}, {41.22,30.49}, {45.49,31.31}, {48.07,32.70}, {49.23,33.68}, {48.10,34.91}, {45.78,37.32}, {44.46,38.35}, {42.55,38.28}, {38.76,38.02}, {36.87,37.82}, {37.22,36.03}, {37.91,32.44}, }
},
{
color={0.00,0.00,0.00,1.00},
points={{38.13,32.01}, {38.64,33.38}, {39.87,36.68}, {40.38,38.04}, {41.76,38.19}, {43.88,37.32}, {45.92,34.25}, {46.89,31.95}, {44.70,31.88}, {40.32,31.92}, }
},
{
color={0.00,0.00,0.00,1.00},
points={{77.17,31.06}, {81.92,31.10}, {91.38,31.85}, {95.97,33.07}, {94.72,35.63}, {92.34,39.06}, {89.73,39.65}, {87.94,39.08}, {86.22,38.84}, {83.20,37.35}, {79.43,33.67}, }
},
{
color={0.00,0.00,0.00,1.00},
points={{79.19,33.21}, {81.16,34.37}, {85.11,36.72}, {87.20,37.65}, {88.42,37.92}, {90.59,37.62}, {93.36,35.87}, {95.07,34.47}, {93.18,33.63}, {89.27,32.62}, {83.23,32.51}, }
},
{
color={0.00,0.00,0.00,1.00},
points={{40.98,32.98}, {42.04,33.00}, {44.14,33.06}, {45.20,33.10}, {44.90,33.82}, {44.29,35.27}, {43.98,35.99}, {43.31,36.00}, {41.68,36.02}, {41.01,36.03}, {41.00,35.34}, {40.99,33.67}, }
},
{
color={0.00,0.00,0.00,1.00},
points={{85.25,33.42}, {86.47,33.52}, {88.90,33.74}, {90.12,33.85}, {89.95,34.75}, {89.53,36.93}, {89.36,37.83}, {88.30,36.76}, {86.24,34.55}, }
},
{
color={0.00,0.00,0.00,1.00},
points={{47.19,52.14}, {48.04,49.85}, {50.45,45.32}, {53.87,41.66}, {58.36,39.86}, {61.02,39.96}, {63.52,39.75}, {68.41,40.50}, {72.84,42.65}, {76.44,46.03}, {77.80,48.13}, {79.09,51.04}, {80.90,57.11}, {81.71,63.41}, {81.51,69.76}, {81.03,72.90}, {80.15,79.05}, {78.59,88.28}, {76.43,94.06}, {74.76,96.74}, {73.66,98.07}, {70.58,99.34}, {67.15,98.94}, {64.31,97.06}, {63.41,95.63}, {62.58,92.25}, {62.34,85.22}, {62.23,81.73}, {60.47,85.43}, {57.64,91.15}, {54.80,94.04}, {52.88,94.94}, {51.30,94.87}, {48.33,93.73}, {45.85,91.59}, {44.10,88.86}, {43.59,87.39}, {43.27,82.95}, {43.43,74.06}, {45.25,60.82}, }
},
{
color={0.00,0.00,0.00,1.00},
points={{56.62,41.59}, {54.56,42.95}, {51.30,46.52}, {48.19,53.23}, {46.99,57.96}, {45.73,65.01}, {44.27,75.68}, {44.22,82.82}, {44.64,86.39}, {45.93,88.90}, {50.00,92.95}, {52.08,94.90}, {54.90,92.12}, {58.93,85.42}, {60.12,81.65}, {57.15,79.31}, {53.17,75.35}, {51.42,72.07}, {50.96,70.14}, {56.23,70.07}, {66.79,70.12}, {72.06,70.18}, {71.65,72.08}, {70.27,75.60}, {68.17,78.69}, {65.40,81.25}, {63.78,82.29}, {63.49,85.87}, {63.44,91.44}, {64.54,94.84}, {65.65,96.33}, {66.35,97.06}, {68.18,98.02}, {70.24,98.23}, {72.11,97.54}, {72.84,96.82}, {75.07,93.61}, {77.81,86.52}, {79.49,75.01}, {80.41,67.39}, {80.45,63.98}, {79.65,56.95}, {77.35,50.27}, {73.21,44.75}, {70.34,42.66}, {67.06,41.50}, {60.04,41.10}, }
},
{
color={0.00,0.00,0.00,1.00},
points={{120.00,83.78}, {119.33,83.51}, {118.57,82.57}, {118.57,81.42}, {119.33,80.48}, {120.00,80.21}, {120.00,80.77}, {120.00,83.22}, }
},
{
color={0.67,0.32,0.21,1.00},
points={{75.23,10.71}, {81.81,12.24}, {91.33,15.81}, {97.29,19.02}, {100.11,20.87}, {102.08,22.62}, {104.79,26.94}, {106.78,34.54}, {107.49,39.66}, {107.85,45.86}, {107.54,55.21}, {106.25,61.27}, {105.14,64.19}, {101.27,72.12}, {92.37,87.34}, {87.70,94.82}, {85.73,97.28}, {80.69,100.48}, {74.75,101.80}, {68.56,101.77}, {65.59,101.40}, {59.02,100.22}, {49.32,97.49}, {45.42,94.68}, {43.44,91.96}, {42.69,90.29}, {39.67,83.56}, {34.89,69.56}, {31.97,55.06}, {31.11,40.32}, {31.52,32.93}, {31.70,30.10}, {33.15,24.66}, {35.94,19.82}, {39.94,15.92}, {42.36,14.44}, {46.33,13.14}, {54.46,11.53}, {66.92,10.76}, }
},
{
color={0.67,0.32,0.21,1.00},
points={{44.60,17.49}, {55.52,18.34}, {77.41,18.36}, {88.36,18.36}, {77.44,17.54}, {55.55,17.32}, }
},
{
color={0.67,0.32,0.21,1.00},
points={{35.66,23.71}, {41.23,23.07}, {49.59,21.91}, {55.18,21.70}, {57.98,21.93}, {62.38,22.54}, {71.21,23.04}, {84.51,23.11}, {93.37,23.54}, {89.47,22.43}, {81.55,21.70}, {73.56,21.96}, {65.55,22.01}, {61.57,21.58}, {58.31,21.07}, {51.77,20.86}, {42.03,22.13}, }
},
{
color={0.67,0.32,0.21,1.00},
points={{38.24,30.65}, {37.91,32.44}, {37.22,36.03}, {36.87,37.82}, {38.76,38.02}, {42.55,38.28}, {44.46,38.35}, {45.78,37.32}, {48.10,34.91}, {49.23,33.68}, {48.07,32.70}, {45.49,31.31}, {41.22,30.49}, }
},
{
color={0.67,0.32,0.21,1.00},
points={{77.17,31.06}, {79.43,33.67}, {83.20,37.35}, {86.22,38.84}, {87.94,39.08}, {89.73,39.65}, {92.34,39.06}, {94.72,35.63}, {95.97,33.07}, {91.38,31.85}, {81.92,31.10}, }
},
{
color={0.67,0.32,0.21,1.00},
points={{47.19,52.14}, {45.25,60.82}, {43.43,74.06}, {43.27,82.95}, {43.59,87.39}, {44.10,88.86}, {45.85,91.59}, {48.33,93.73}, {51.30,94.87}, {52.88,94.94}, {54.80,94.04}, {57.64,91.15}, {60.47,85.43}, {62.23,81.73}, {62.34,85.22}, {62.58,92.25}, {63.41,95.63}, {64.31,97.06}, {67.15,98.94}, {70.58,99.34}, {73.66,98.07}, {74.76,96.74}, {76.43,94.06}, {78.59,88.28}, {80.15,79.05}, {81.03,72.90}, {81.51,69.76}, {81.71,63.41}, {80.90,57.11}, {79.09,51.04}, {77.80,48.13}, {76.44,46.03}, {72.84,42.65}, {68.41,40.50}, {63.52,39.75}, {61.02,39.96}, {58.36,39.86}, {53.87,41.66}, {50.45,45.32}, {48.04,49.85}, }
},
{
color={0.67,0.32,0.21,1.00},
points={{11.32,33.28}, {11.71,30.95}, {13.27,26.67}, {15.76,22.93}, {18.99,19.78}, {22.82,17.28}, {27.06,15.48}, {31.55,14.44}, {36.12,14.22}, {38.39,14.43}, {35.43,18.50}, {30.96,27.46}, {29.44,32.27}, {27.36,33.20}, {23.24,35.19}, {21.24,36.29}, {20.27,39.91}, {19.26,47.33}, {19.32,54.86}, {20.29,62.33}, {21.07,66.00}, {21.82,69.72}, {22.25,77.24}, {21.12,88.55}, {19.89,96.00}, {19.25,98.00}, {17.60,100.80}, {15.90,101.95}, {14.83,102.17}, {13.29,102.16}, {10.23,101.84}, {8.70,101.65}, {8.89,93.95}, {10.00,78.60}, {10.83,70.95}, {11.48,61.55}, {11.18,42.70}, }
},
{
color={0.67,0.32,0.21,1.00},
points={{95.92,15.50}, {101.06,16.07}, {108.79,17.54}, {113.29,19.93}, {115.18,21.79}, {116.56,23.61}, {118.17,27.73}, {118.82,34.53}, {118.98,38.97}, {118.59,55.94}, {116.39,81.35}, {113.70,93.75}, {111.06,101.81}, {109.44,105.77}, {108.26,102.70}, {107.28,96.27}, {107.52,92.98}, {107.67,88.01}, {108.68,78.15}, {111.35,63.50}, {113.45,53.80}, {113.87,50.25}, {114.22,44.72}, {113.25,41.36}, {112.14,39.88}, {110.55,38.01}, {108.29,33.74}, {106.61,29.13}, {104.67,24.66}, {103.35,22.62}, {101.53,20.79}, {97.80,17.25}, }
},
{
color={0.00,0.53,0.32,1.00},
points={{38.13,32.01}, {40.32,31.92}, {44.70,31.88}, {46.89,31.95}, {45.92,34.25}, {43.88,37.32}, {41.76,38.19}, {40.38,38.04}, {39.87,36.68}, {38.64,33.38}, }
},
{
color={0.00,0.53,0.32,1.00},
points={{40.98,32.98}, {40.99,33.67}, {41.00,35.34}, {41.01,36.03}, {41.68,36.02}, {43.31,36.00}, {43.98,35.99}, {44.29,35.27}, {44.90,33.82}, {45.20,33.10}, {44.14,33.06}, {42.04,33.00}, }
},
{
color={0.00,0.53,0.32,1.00},
points={{79.19,33.21}, {83.23,32.51}, {89.27,32.62}, {93.18,33.63}, {95.07,34.47}, {93.36,35.87}, {90.59,37.62}, {88.42,37.92}, {87.20,37.65}, {85.11,36.72}, {81.16,34.37}, }
},
{
color={0.00,0.53,0.32,1.00},
points={{85.25,33.42}, {86.24,34.55}, {88.30,36.76}, {89.36,37.83}, {89.53,36.93}, {89.95,34.75}, {90.12,33.85}, {88.90,33.74}, {86.47,33.52}, }
},
{
color={1.00,0.64,0.00,1.00},
points={{56.62,41.59}, {60.04,41.10}, {67.06,41.50}, {70.34,42.66}, {73.21,44.75}, {77.35,50.27}, {79.65,56.95}, {80.45,63.98}, {80.41,67.39}, {79.49,75.01}, {77.81,86.52}, {75.07,93.61}, {72.84,96.82}, {72.11,97.54}, {70.24,98.23}, {68.18,98.02}, {66.35,97.06}, {65.65,96.33}, {64.54,94.84}, {63.44,91.44}, {63.49,85.87}, {63.78,82.29}, {65.40,81.25}, {68.17,78.69}, {70.27,75.60}, {71.65,72.08}, {72.06,70.18}, {66.79,70.12}, {56.23,70.07}, {50.96,70.14}, {51.42,72.07}, {53.17,75.35}, {57.15,79.31}, {60.12,81.65}, {58.93,85.42}, {54.90,92.12}, {52.08,94.90}, {50.00,92.95}, {45.93,88.90}, {44.64,86.39}, {44.22,82.82}, {44.27,75.68}, {45.73,65.01}, {46.99,57.96}, {48.19,53.23}, {51.30,46.52}, {54.56,42.95}, }
},

{
color={0.00,0.00,0.00,1.00},
points={{24.57,21.01}, {25.40,21.02}, {27.08,21.03}, {27.92,21.04}, {29.49,31.27}, {32.89,51.68}, {34.00,61.97}, {31.08,61.47}, {25.23,60.48}, {22.31,60.00}, {21.66,60.62}, {20.38,61.85}, {19.73,62.47}, {21.27,66.88}, {23.80,73.63}, {26.80,76.99}, {29.00,78.01}, {30.61,78.78}, {33.99,79.65}, {39.17,79.45}, {45.50,76.70}, {49.18,73.08}, {50.85,70.06}, {51.39,68.39}, {52.77,63.52}, {55.66,53.84}, {57.43,49.10}, {59.11,49.62}, {63.14,50.88}, {64.82,51.40}, {66.02,52.66}, {67.54,55.62}, {68.61,60.65}, {69.33,63.95}, {70.07,67.94}, {70.59,76.03}, {69.90,84.12}, {68.04,92.02}, {66.69,95.84}, {65.57,97.86}, {62.09,100.38}, {55.33,102.05}, {51.01,103.03}, {46.57,103.39}, {37.56,103.06}, {28.72,101.23}, {20.42,97.78}, {16.60,95.42}, {14.51,93.74}, {11.06,89.93}, {7.46,83.30}, {4.82,73.37}, {3.60,63.02}, {3.15,57.98}, {2.76,51.67}, {2.28,42.07}, {3.64,36.04}, {5.23,33.24}, {6.55,31.37}, {9.64,27.97}, {11.35,26.43}, {13.57,25.84}, {18.18,25.53}, {20.48,25.40}, {20.07,30.33}, {18.74,37.62}, {17.05,42.24}, {15.87,44.43}, {17.81,45.85}, {21.92,48.34}, {24.09,49.39}, {23.88,42.29}, {24.42,28.10}, }
},
{
color={0.00,0.00,0.00,1.00},
points={{26.49,21.72}, {26.43,29.05}, {26.67,40.10}, {26.15,47.40}, {25.45,51.01}, {22.55,49.95}, {17.81,47.91}, {15.74,45.58}, {15.37,43.96}, {16.68,39.57}, {19.20,30.77}, {19.57,26.16}, {18.00,26.09}, {15.06,26.57}, {11.18,28.55}, {7.06,32.91}, {4.20,38.28}, {3.27,41.03}, {3.64,50.31}, {5.43,68.81}, {7.06,77.97}, {7.99,81.26}, {11.01,87.35}, {15.37,92.56}, {20.86,96.57}, {23.95,98.03}, {27.54,99.40}, {34.98,101.56}, {42.63,102.60}, {50.28,102.13}, {54.05,101.20}, {57.01,100.40}, {61.59,99.13}, {64.10,97.46}, {65.02,96.17}, {67.06,91.16}, {69.28,80.71}, {69.28,70.00}, {67.36,59.40}, {65.77,54.26}, {64.15,53.30}, {60.22,50.98}, {58.59,50.02}, {56.54,55.72}, {53.07,67.33}, {50.89,72.97}, {49.81,74.58}, {47.14,77.26}, {43.94,79.20}, {40.37,80.40}, {34.70,80.84}, {29.14,79.62}, {25.77,77.90}, {24.24,76.77}, {22.68,74.71}, {20.60,70.17}, {19.85,65.28}, {20.42,60.32}, {21.19,57.89}, {24.13,58.69}, {30.02,60.30}, {32.96,61.11}, {31.73,51.20}, {28.27,31.54}, }
},
{
color={0.00,0.00,0.00,1.00},
points={{23.52,43.82}, {24.13,43.87}, {25.59,43.99}, {26.20,44.04}, {26.02,42.68}, {25.66,39.98}, {25.48,38.63}, {24.97,39.92}, {23.99,42.52}, }
},
{
color={0.16,0.68,1.00,1.00},
points={{26.49,21.72}, {28.27,31.54}, {31.73,51.20}, {32.96,61.11}, {30.02,60.30}, {24.13,58.69}, {21.19,57.89}, {20.42,60.32}, {19.85,65.28}, {20.60,70.17}, {22.68,74.71}, {24.24,76.77}, {25.77,77.90}, {29.14,79.62}, {34.70,80.84}, {40.37,80.40}, {43.94,79.20}, {47.14,77.26}, {49.81,74.58}, {50.89,72.97}, {53.07,67.33}, {56.54,55.72}, {58.59,50.02}, {60.22,50.98}, {64.15,53.30}, {65.77,54.26}, {67.36,59.40}, {69.28,70.00}, {69.28,80.71}, {67.06,91.16}, {65.02,96.17}, {64.10,97.46}, {61.59,99.13}, {57.01,100.40}, {54.05,101.20}, {50.28,102.13}, {42.63,102.60}, {34.98,101.56}, {27.54,99.40}, {23.95,98.03}, {20.86,96.57}, {15.37,92.56}, {11.01,87.35}, {7.99,81.26}, {7.06,77.97}, {5.43,68.81}, {3.64,50.31}, {3.27,41.03}, {4.20,38.28}, {7.06,32.91}, {11.18,28.55}, {15.06,26.57}, {18.00,26.09}, {19.57,26.16}, {19.20,30.77}, {16.68,39.57}, {15.37,43.96}, {15.74,45.58}, {17.81,47.91}, {22.55,49.95}, {25.45,51.01}, {26.15,47.40}, {26.67,40.10}, {26.43,29.05}, }
},
Nikk
   }
   current_shape_index = 1

   backdrop = {
      grid = {cellsize=100}, -- cellsize is in px
      bg_color = {34/255,30/255,30/255},
      image = love.graphics.newImage("offshore-707.jpg"),
      visible = false,
      alpha = 0.5,
      x = 0,
      y = 0,
      scale = 1
   }

   lastDraggedElement = {}
   quitDialog = false
end

function drawGrid()
   local w, h = love.graphics.getDimensions( )
   local size = backdrop.grid.cellsize * camera.scale
   if (size < 10) then return end
   local vlines = math.floor(w/size)
   local hlines = math.floor(h/size)
   local xOffset = (camera.x * camera.scale) % size
   local yOffset = (camera.y * camera.scale) % size

   for x =0, vlines do
      love.graphics.line(xOffset + x*size, 0,xOffset +  x*size, h)
   end
   for y =0, hlines do
      love.graphics.line( 0, yOffset + y*size, w, yOffset +  y*size)
   end
end

function handleMouseClickStart()
   mouseState.hoveredSomething = false
   mouseState.down = love.mouse.isDown(1 )
   mouseState.click = false

   if mouseState.down ~= mouseState.lastDown then
      if mouseState.down  then
         mouseState.click  = true
      end
   end
   mouseState.lastDown =  mouseState.down
end


function love.draw()
   local mx,my = love.mouse.getPosition()
   local wx, wy = toWorldPos(mx, my)
   handleMouseClickStart()
   love.mouse.setCursor(cursors.arrow)
   local w, h = love.graphics.getDimensions( )
   love.graphics.clear(backdrop.bg_color[1], backdrop.bg_color[2], backdrop.bg_color[3])
   love.graphics.push()
   love.graphics.scale(camera.scale, camera.scale  )
   love.graphics.translate( camera.x, camera.y )
   if  backdrop.visible then
      love.graphics.setColor(1,1,1, backdrop.alpha)
      love.graphics.draw(backdrop.image, backdrop.x, backdrop.y, 0, backdrop.scale, backdrop.scale)
   end

   love.graphics.setColor(0,0,0)



   for i = 1, #shapes do
      local points = shapes[i].points
      if (#points >= 2 ) then

	 local scale = 1
	 local coords = {}
	 local coordsRound = {}
	 local ps = {}
	 for i=1, #points do
	    table.insert(coords, points[i][1])
	    table.insert(coords, points[i][2])
	    table.insert(coordsRound, points[i][1])
	    table.insert(coordsRound, points[i][2])
	 end

	 table.insert(coordsRound, points[1][1])
	 table.insert(coordsRound, points[1][2])

	 if (shapes[i].color) then

	    local c = shapes[i].color
	    love.graphics.setColor(c[1], c[2], c[3], c[4] or 1)

	    local c,a = poly.getPolygonCentroid(coordsRound)

	    local polys = decompose_complex_poly(coords, {})

	    local result = {}
	    for i=1 , #polys do
	       local p = polys[i]
	       if (#p >= 6) then
		  local triangles = love.math.triangulate(p)
		  for j = 1, #triangles do
		     local t = triangles[j]
		     local cx, cy = getTriangleCentroid(t)
		     if isPointInPath(cx,cy, p) then
			table.insert(result, t)
		     end
		  end
	       end
	    end
	    for j = 1, #result do
	       love.graphics.polygon('fill', result[j])
	    end

	    --love.graphics.setColor(1,1,1)
	    --love.graphics.circle("fill", c[1], c[2], 10)

	 end

	 love.graphics.setColor(0,0,0,1)

	 if (shapes[i].outline) then
	    love.graphics.setLineStyle('rough')
	    love.graphics.setLineJoin('bevel')
	    love.graphics.setLineWidth(2)

	    local vertices, indices, draw_mode = polyline(
	       love.graphics.getLineJoin(),
	       coordsRound, love.graphics.getLineWidth() / 2,
	       1/scale,
	       love.graphics.getLineStyle() == 'smooth')

	    local mesh = love.graphics.newMesh(#coordsRound * 2)
	    mesh:setVertices(vertices)
	    mesh:setDrawMode(draw_mode)
	    mesh:setVertexMap(indices)
	    if indices then
	       mesh:setDrawRange(1, #indices)
	    else
	       mesh:setDrawRange(1, #vertices)
	    end
	    love.graphics.draw(mesh)
	 end

	 love.graphics.setLineWidth(1)
      end
   end

   -- if (#shapes >= 2 and #shapes[1].points > 0  and #shapes[2].points > 0) then
   --    love.graphics.setColor(0,0,1,1)
   --    local region = poly.polygonClip(shapes[1], shapes[2])
   --    local coords = {}
   --    for i=1, #region do
   --    	 table.insert(coords, region[i].x)
   --    	 table.insert(coords, region[i].y)
   --    end

   --    local polys = decompose_complex_poly(coords, {})
   --    local result = {}
   --    for i=1 , #polys do
   --    	 local p = polys[i]
   --    	 if (#p >= 6) then
   --    	    local triangles = love.math.triangulate(p)
   --    	    for j = 1, #triangles do
   --    	       local t = triangles[j]
   --    	       local cx, cy = getTriangleCentroid(t)
   --    	       if isPointInPath(cx,cy, p) then
   --    		  table.insert(result, t)
   --    	       end
   --    	    end
   --    	 end
   --    end
   --    for j = 1, #result do
   --    	 love.graphics.polygon('fill', result[j])
   --    end
   -- end

   love.graphics.setColor(1,1,1,1)

   if editingMode == 'polyline' and  current_shape_index > 0  then
      local points = shapes[current_shape_index].points
      love.graphics.setLineWidth(2.0  / camera.scale )

      for i=1, #points do
	 local kind = "line"
	 if mouseOverPolyPoint(mx, my, points[i][1], points[i][2]) then
	    if (editingModeSub == 'polyline-remove' or editingModeSub == 'polyline-edit') then
	       kind= "fill"
	    end
	    if (editingModeSub == 'polyline-add') and i == 1 and  #points > 1 then
	       kind= "fill"
	    end
	 end

	 if (editingModeSub == 'polyline-add') and i == #points then
	    kind = 'fill'
	 end

	 if editingModeSub == 'polyline-insert' then
	    local closestEdgeIndex = getClosestEdgeIndex(wx, wy, points)
	    local nextIndex = (closestEdgeIndex == #points and 1) or closestEdgeIndex+1
	    if i == closestEdgeIndex or i == nextIndex then
	       kind = 'fill'
	    end

	 end
	 local dot_x = points[i][1] - 5/camera.scale
	 local dot_y =  points[i][2] - 5/camera.scale
	 local dot_size = 10 / camera.scale

	 love.graphics.rectangle(kind, dot_x, dot_y, dot_size, dot_size)
      end
      love.graphics.setLineWidth(1)
      love.graphics.setLineWidth(4/ camera.scale)
      if editingModeSub == 'polyline-rotate'  and #points > 0 then
	 local radius = 12  / camera.scale
	 local pivot = points[1]
	 local rotator = {x=pivot.x + 100, y=pivot.y}
	 love.graphics.setColor(1,1,1)

	 love.graphics.line(pivot.x, pivot.y, rotator.x, rotator.y)
	 love.graphics.setLineWidth(2/ camera.scale)
	 love.graphics.circle("fill", pivot.x, pivot.y , radius)
	 love.graphics.setColor(0,0,0)
	 love.graphics.circle("line", pivot.x, pivot.y , radius)

	 love.graphics.setColor(0,0,0)

	 love.graphics.circle("fill", rotator.x, rotator.y , radius)

	  love.graphics.setColor(1,1,1)
	 love.graphics.circle("line", rotator.x, rotator.y , radius)
      end

      love.graphics.setLineWidth(1)
   end

   love.graphics.pop()
   love.graphics.setColor(1,1,1, 0.1)

   drawGrid()
   love.graphics.push()
   local s = 0.5
   local buttons = {
      'move', 'polyline', 'backdrop'
   }
   local calcY = function(i, s)
      return (64 * i * s) + (10*i*s)
   end
   local calcX = function(i, s)
      return 16 + (64 * i * s) + (10*i*s)
   end

   for i = 1, #buttons do
      if imgbutton(buttons[i], ui[buttons[i]], calcX(0, s), calcY(i, s), s).clicked then
	 if (editingMode == buttons[i]) then
	    editingMode = nil
	    editingModeSub = nil
	 else
	    editingMode = buttons[i]
	    editingModeSub = nil
	 end

	 if (buttons[i] == 'polyline') then
	    editingModeSub = 'polyline-edit'
	 end
      end
   end

   if (editingMode == 'polyline') and current_shape_index > 0  then
      if imgbutton('polyline-insert', ui.insert_link,  calcX(1, s), calcY(2, s), s).clicked then
	 editingModeSub = 'polyline-insert'
      end
      if imgbutton('polyline-add', ui.polyline_add, calcX(2, s), calcY(2, s), s).clicked then
	 editingModeSub = 'polyline-add'
      end
      if imgbutton('polyline-remove', ui.polyline_remove,  calcX(3, s), calcY(2, s), s).clicked then
	 editingModeSub = 'polyline-remove'
      end
      if imgbutton('polyline-edit', ui.polyline_edit,  calcX(4, s), calcY(2, s), s).clicked then
	 editingModeSub = 'polyline-edit'
      end
      if imgbutton('polyline-palette', ui.palette,  calcX(5, s), calcY(2, s), s).clicked then
	 editingModeSub = 'polyline-palette'
      end
      if imgbutton('polyline-rotate', ui.rotate,  calcX(6, s), calcY(2, s), s).clicked then
	 editingModeSub = 'polyline-rotate'
      end

      if imgbutton('polyline-move', ui.move,  calcX(7, s), calcY(2, s), s).clicked then
	 editingModeSub = 'polyline-move'
      end
      if imgbutton('polyline-outside', shapes[current_shape_index].outline and ui.lines or ui.lines2,  calcX(8, s), calcY(2, s), s).clicked then
	 shapes[current_shape_index].outline = not shapes[current_shape_index].outline
      end

   end


   if (editingModeSub == 'polyline-palette') then
      for i = 1, #palette.colors do
	 local rgb = palette.colors[i].rgb
	 if rgbbutton('palette#'..i, {rgb[1]/255,rgb[2]/255,rgb[3]/255}, calcX(i, s),calcY(3, s) ,s).clicked then
	    shapes[current_shape_index].color =  {rgb[1]/255,rgb[2]/255,rgb[3]/255, shapes[current_shape_index].color[4] or 1}
	 end
      end
      local v =  h_slider("polyline_alpha", calcX(1, s), calcY(4, s)+ 12*s, 100,  shapes[current_shape_index].color[4] , 0, 1)
      if (v.value ~= nil) then
	 shapes[current_shape_index].color[4] = v.value
      end
   end

   if (editingMode == 'backdrop') then
      if imgbutton('backdrop-move', ui.move, calcX(1, s), calcY(4,s), s).clicked then
	 if (editingModeSub == 'backdrop-move') then
	    editingModeSub = nil
	 else
	    editingModeSub = 'backdrop-move'
	 end
      end

      if imgbutton('backdrop_visibility', backdrop.visible and ui.visible or ui.not_visible,
		   calcX(2, s), calcY(4, s), s).clicked then
	 editingModeSub = nil
	 backdrop.visible = not backdrop.visible
      end
      if imgbutton('polyline-palette', ui.palette,  calcX(3, s), calcY(4, s), s).clicked then
	 editingModeSub = 'backdrop-palette'
      end
      local v =  h_slider("backdrop_alpha", calcX(4, s), calcY(4, s)+ 12*s, 100, backdrop.alpha, 0, 1)
      if (v.value ~= nil) then
	 backdrop.alpha = v.value
	 editingModeSub = nil
      end
      if (editingModeSub == 'backdrop-palette') then
	 for i = 1, #palette.colors do
	    local rgb = palette.colors[i].rgb
	    if rgbbutton('palette#'..i, {rgb[1]/255,rgb[2]/255,rgb[3]/255}, calcX(i, s),calcY(3, s) ,s).clicked then
	       backdrop.bg_color =  {rgb[1]/255,rgb[2]/255,rgb[3]/255}
	    end
	 end
      end

      local s =  h_slider("backdrop_scale", calcX(1, s), calcY(5, s)+ 12*s, 100, backdrop.scale, 0, 5)
      if (s.value ~= nil) then
	 backdrop.scale = s.value
	 editingModeSub = nil
      end
   end

   -- now lets render the list of items on screen,
   -- i want this to be right alligned
   if iconlabelbutton('add-object', ui.add, nil, false,  'add shape',  w - (64 + 400+ 10)/2, calcY(1,s)+1*8*s, s).clicked then
      local shape = {
	 outline = true,
	 points = {},
      }
      table.insert(shapes, current_shape_index+1, shape)
      current_shape_index = current_shape_index + 1
      editingMode = 'polyline'
      editingModeSub = 'polyline-add'
   end

   for i=1, #shapes do
      if iconlabelbutton('object-group', ui.object_group, shapes[i].color, current_shape_index == i, "p-"..i,  w - (64 + 400+ 10)/2, calcY((i+1),s)+(i+1)*8*s, s).clicked then
	 current_shape_index = i
	 editingMode = 'polyline'
	  editingModeSub = 'polyline-edit'
      end
   end
   if (#shapes > 1) then
      if current_shape_index > 1 and imgbutton('polyline-move-up', ui.move_up,  w - (64 + 400+ 10 + 80 + 20)/2, calcY(2, s) + 16, s).clicked then
	 local taken_out = table.remove(shapes, current_shape_index)
	 current_shape_index =  current_shape_index - 1
	 table.insert(shapes, current_shape_index, taken_out)
      end
      if (current_shape_index < #shapes) and imgbutton('polyline-move-down', ui.move_down,  w - (64 + 400+ 10 + 80 + 20)/2, calcY(3, s) + 24, s).clicked then
	 local taken_out = table.remove(shapes, current_shape_index)
	 current_shape_index =  current_shape_index + 1
	 table.insert(shapes, current_shape_index, taken_out)
      end
   end
   if #shapes > 0 then
      if imgbutton('delete', ui.delete,  w - (64 + 400+ 10 + 80 + 20)/2, calcY(1, s) + 8, s).clicked then
	 local taken_out = table.remove(shapes, current_shape_index)
	 if current_shape_index  > #shapes then
	    current_shape_index = #shapes
	 end
	 if #shapes == 0 then
	    current_shape_index = 0
	 end
      end
   end


   love.graphics.pop()

   if quitDialog then
      love.graphics.setColor(1,1,1, 1)
      love.graphics.print("Sure you want to quit ? [ESC] ", 16, 4)
   end
end

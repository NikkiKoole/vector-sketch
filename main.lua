inspect = require 'inspect'
require 'ui'
require 'palettes'
require 'util'
polyline = require 'polyline'
poly = require 'poly'

-- todo
-- rename the individual shapes
-- copy shapes
-- save load file
-- have parent child relations between shapes
-- have a vertical scrollview for the shapes

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
   --medium = love.graphics.newFont( "resources/fonts/MPLUSRounded1c-Medium.ttf", 16)
   medium = love.graphics.newFont( "resources/fonts/WindsorBT-Roman.otf", 32)
   large = love.graphics.newFont( "resources/fonts/WindsorBT-Roman.otf", 64)
   condensed = medium --love.graphics.newFont( "resources/fonts/DomaineDispNar-Medium.otf", 32)

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
name="0-0-0",
color={0.00,0.53,0.32,1.00},
points={{435.60,17.53}, {454.52,29.50}, {479.06,32.56}, {505.11,70.61}, {505.66,135.65}, {493.68,156.18}, {495.57,171.21}, {464.06,184.36}, {451.31,172.40}, {483.52,105.86}, {472.97,106.18}, {455.77,147.54}, {456.76,91.51}, {446.02,67.31}, {439.67,66.81}, {444.82,108.84}, {435.27,134.64}, {396.56,105.40}, {395.43,116.44}, {422.84,152.05}, {425.43,171.57}, {423.90,218.64}, {403.77,228.98}, {393.88,216.66}, {371.29,211.28}, {367.83,186.07}, {362.01,191.64}, {347.99,183.94}, {343.93,142.36}, {328.30,136.97}, {327.57,123.77}, {349.26,81.41}, {344.02,65.30}, {358.32,41.29}, {388.65,22.64}, {421.74,29.55}, }
},

{
name="0-1-0",
color={0.00,0.53,0.32,1.00},
points={{284.70,338.95}, {295.72,386.19}, {301.78,337.99}, {313.60,375.76}, {314.95,357.04}, {321.96,380.92}, {330.18,375.81}, {335.68,383.61}, {345.01,365.86}, {356.84,389.07}, {352.70,405.03}, {307.33,413.62}, {308.51,408.34}, {286.08,402.73}, }
},
{
name="0-1-1",
color={0.00,0.53,0.32,1.00},
points={{286.43,341.62}, {285.87,368.55}, }
},
{
name="0-1-2",
color={0.00,0.53,0.32,1.00},
points={{303.31,350.11}, }
},
{
name="0-1-3",
color={0.00,0.53,0.32,1.00},
points={{302.45,381.44}, {303.41,358.57}, }
},
{
name="0-1-4",
color={0.00,0.53,0.32,1.00},
points={{306.17,363.50}, {307.54,376.30}, }
},
{
name="0-1-5",
color={0.00,0.53,0.32,1.00},
points={{288.88,388.12}, {289.17,366.62}, }
},
{
name="0-1-6",
color={0.00,0.53,0.32,1.00},
points={{317.27,370.11}, }
},
{
name="0-1-7",
color={0.00,0.53,0.32,1.00},
points={{341.99,386.50}, {345.65,369.08}, }
},
{
name="0-1-8",
color={0.00,0.53,0.32,1.00},
points={{325.97,378.96}, {328.24,387.66}, }
},
{
name="0-1-9",
color={0.00,0.53,0.32,1.00},
points={{331.32,379.28}, {335.18,391.83}, }
},
{
name="0-1-10",
color={0.00,0.53,0.32,1.00},
points={{305.12,381.54}, }
},
{
name="0-1-11",
color={0.00,0.53,0.32,1.00},
points={{343.95,391.36}, {346.52,384.14}, }
},
{
name="0-1-12",
color={0.00,0.53,0.32,1.00},
points={{346.23,394.37}, {348.43,388.67}, }
},
{
name="0-1-13",
color={0.00,0.53,0.32,1.00},
points={{294.12,388.54}, }
},
{
name="0-1-14",
color={0.00,0.53,0.32,1.00},
points={{350.82,392.24}, {352.21,397.30}, }
},
{
name="0-1-15",
color={0.00,0.53,0.32,1.00},
points={{324.53,392.13}, }
},
{
name="0-1-16",
color={0.00,0.53,0.32,1.00},
points={{343.08,392.31}, }
},
{
name="0-1-17",
color={0.00,0.53,0.32,1.00},
points={{294.32,393.18}, }
},
{
name="0-1-18",
color={0.00,0.53,0.32,1.00},
points={{304.16,395.82}, }
},
{
name="0-1-19",
color={0.00,0.53,0.32,1.00},
points={{289.18,399.32}, }
},
{
name="0-1-20",
color={0.00,0.53,0.32,1.00},
points={{295.42,398.33}, {302.87,403.36}, }
},
{
name="0-1-21",
color={0.00,0.53,0.32,1.00},
points={{307.40,399.15}, }
},
{
name="0-1-22",
color={0.00,0.53,0.32,1.00},
points={{322.93,399.72}, {327.46,402.02}, }
},
{
name="0-1-23",
color={0.00,0.53,0.32,1.00},
points={{348.18,402.22}, }
},
{
name="0-1-24",
color={0.00,0.53,0.32,1.00},
points={{327.80,407.17}, }
},

{
name="1-0-0",
color={1.00,0.00,0.30,1.00},
points={{174.86,51.98}, {188.77,71.41}, }
},

{
name="1-1-0",
color={1.00,0.00,0.30,1.00},
points={{172.01,59.19}, {215.61,115.60}, {218.70,139.94}, {164.38,76.10}, {164.28,89.56}, {82.67,188.24}, {171.14,84.43}, {228.60,151.59}, {274.51,183.89}, {223.74,145.41}, {232.83,145.08}, {231.93,128.92}, {291.83,182.76}, {231.90,118.74}, {297.56,184.85}, {259.55,188.48}, {166.87,108.71}, {82.20,196.03}, {69.80,179.10}, }
},

{
name="1-2-0",
color={1.00,0.00,0.30,1.00},
points={{199.79,84.91}, {220.00,113.46}, }
},

{
name="1-3-0",
color={1.00,0.00,0.30,1.00},
points={{221.05,133.34}, }
},

{
name="1-4-0",
color={1.00,0.00,0.30,1.00},
points={{91.35,157.43}, {97.39,147.56}, }
},

{
name="1-5-0",
color={1.00,0.00,0.30,1.00},
points={{120.83,163.19}, }
},

{
name="1-6-0",
color={1.00,0.00,0.30,1.00},
points={{223.73,161.15}, {254.40,187.40}, {248.27,190.80}, }
},

{
name="1-7-0",
color={1.00,0.00,0.30,1.00},
points={{116.10,162.38}, }
},

{
name="1-8-0",
color={1.00,0.00,0.30,1.00},
points={{100.40,177.39}, {119.39,164.27}, {89.67,194.83}, }
},

{
name="1-9-0",
color={1.00,0.00,0.30,1.00},
points={{90.13,188.11}, }
},

{
name="2-0-0",
color={0.00,0.00,0.00,1.00},
points={{165.71,61.73}, {172.47,55.09}, {196.53,79.22}, {215.92,113.01}, {221.09,89.01}, {232.55,86.19}, {235.03,141.74}, {226.77,145.31}, {274.51,183.89}, {221.60,146.60}, {171.14,84.43}, {82.67,188.24}, {164.28,89.56}, {168.95,82.80}, {162.63,76.09}, {187.56,96.43}, {218.70,139.94}, {219.23,118.73}, {172.01,59.19}, {140.21,86.99}, {73.64,179.25}, {134.51,90.45}, }
},
{
name="2-0-1",
color={0.00,0.00,0.00,1.00},
points={{223.43,90.47}, {220.83,142.86}, {229.45,143.68}, {231.22,92.28}, }
},

{
name="2-1-0",
color={0.00,0.00,0.00,1.00},
points={{165.43,106.81}, {247.57,172.49}, {256.34,188.80}, {164.75,112.08}, {79.37,202.71}, }
},
{
name="2-1-1",
color={0.00,0.00,0.00,1.00},
points={{116.10,162.38}, }
},
{
name="2-1-2",
color={0.00,0.00,0.00,1.00},
points={{90.13,188.11}, }
},

{
name="2-2-0",
color={0.00,0.00,0.00,1.00},
points={{231.98,124.61}, {289.26,180.44}, {268.52,168.50}, }
},

{
name="2-3-0",
color={0.00,0.00,0.00,1.00},
points={{299.02,181.68}, {301.06,176.82}, }
},

{
name="2-4-0",
color={0.00,0.00,0.00,1.00},
points={{191.04,201.63}, {248.03,203.99}, {254.68,231.46}, {253.72,403.09}, {189.20,408.88}, }
},
{
name="2-4-1",
color={0.00,0.00,0.00,1.00},
points={{193.00,203.70}, {197.13,276.54}, {189.65,402.25}, {250.56,401.96}, {251.31,224.86}, {238.09,208.77}, }
},

{
name="2-5-0",
color={0.00,0.00,0.00,1.00},
points={{99.58,233.79}, {169.16,238.73}, {173.08,348.70}, {99.08,352.94}, }
},
{
name="2-5-1",
color={0.00,0.00,0.00,1.00},
points={{129.00,235.74}, {104.01,237.00}, {102.84,337.62}, {168.78,338.92}, {166.80,237.05}, }
},
{
name="2-5-2",
color={0.00,0.00,0.00,1.00},
points={{154.57,341.64}, {166.47,342.24}, }
},
{
name="2-5-3",
color={0.00,0.00,0.00,1.00},
points={{99.26,343.27}, {109.70,350.99}, {170.89,346.76}, }
},

{
name="2-6-0",
color={0.00,0.00,0.00,1.00},
points={{199.01,299.90}, {225.01,300.01}, {203.25,306.41}, }
},

{
name="3-0-0",
color={0.67,0.32,0.21,1.00},
points={{438.77,67.54}, {450.82,72.11}, {456.76,91.51}, {453.27,145.82}, {475.87,99.93}, {481.65,104.32}, {472.43,139.71}, {449.18,180.74}, {453.17,288.78}, {441.27,357.14}, {444.70,388.92}, {413.93,394.67}, {397.91,392.38}, {416.20,366.06}, {409.21,267.84}, {424.95,214.29}, {425.43,171.57}, {422.84,152.05}, {393.64,109.16}, {411.25,113.38}, {432.76,138.51}, {444.82,108.84}, }
},
{
name="3-0-1",
color={0.67,0.32,0.21,1.00},
points={{402.12,390.25}, {412.39,387.61}, }
},

{
name="3-1-0",
color={0.67,0.32,0.21,1.00},
points={{166.87,108.71}, {199.08,135.83}, }
},

{
name="3-2-0",
color={0.67,0.32,0.21,1.00},
points={{139.94,142.93}, {164.75,112.08}, {248.27,190.80}, {265.98,188.10}, {263.12,266.94}, {276.99,389.77}, {269.72,402.98}, {253.72,403.09}, {250.19,207.71}, {191.04,201.63}, {188.04,409.04}, {73.08,408.54}, {85.23,203.59}, }
},
{
name="3-2-1",
color={0.67,0.32,0.21,1.00},
points={{145.00,163.98}, {187.65,166.22}, }
},
{
name="3-2-2",
color={0.67,0.32,0.21,1.00},
points={{123.25,180.77}, {212.72,183.77}, }
},
{
name="3-2-3",
color={0.67,0.32,0.21,1.00},
points={{100.01,212.14}, {172.27,213.64}, }
},
{
name="3-2-4",
color={0.67,0.32,0.21,1.00},
points={{99.58,233.79}, {99.08,352.94}, {173.08,348.70}, {169.94,234.32}, }
},

{
name="3-3-0",
color={0.67,0.32,0.21,1.00},
points={{200.10,136.61}, {209.17,145.15}, }
},

{
name="3-4-0",
color={0.67,0.32,0.21,1.00},
points={{213.07,149.91}, {218.20,153.84}, }
},

{
name="3-5-0",
color={0.67,0.32,0.21,1.00},
points={{251.31,224.86}, {251.75,243.68}, }
},

{
name="3-6-0",
color={0.67,0.32,0.21,1.00},
points={{129.00,235.74}, {143.44,236.27}, }
},

{
name="3-7-0",
color={0.67,0.32,0.21,1.00},
points={{251.20,272.73}, {251.07,338.23}, }
},

{
name="3-8-0",
color={0.67,0.32,0.21,1.00},
points={{102.60,339.58}, {103.45,333.73}, }
},

{
name="3-9-0",
color={0.67,0.32,0.21,1.00},
points={{154.57,341.64}, {166.84,341.79}, }
},

{
name="3-10-0",
color={0.67,0.32,0.21,1.00},
points={{187.92,368.99}, {189.52,390.52}, }
},

{
name="3-11-0",
color={0.67,0.32,0.21,1.00},
points={{192.68,408.41}, }
},

{
name="4-0-0",
color={0.49,0.15,0.33,1.00},
points={{223.43,90.47}, {229.52,88.98}, {231.55,140.52}, {223.70,143.13}, }
},

{
name="4-1-0",
color={0.49,0.15,0.33,1.00},
points={{221.81,94.55}, {221.60,100.38}, }
},

{
name="4-2-0",
color={0.49,0.15,0.33,1.00},
points={{231.95,132.29}, {231.05,119.07}, }
},

{
name="5-0-0",
color={1.00,0.80,0.67,1.00},
points={{145.00,163.98}, {187.65,166.22}, }
},

{
name="5-1-0",
color={1.00,0.80,0.67,1.00},
points={{123.25,180.77}, {212.72,183.77}, }
},

{
name="5-2-0",
color={1.00,0.80,0.67,1.00},
points={{100.01,212.14}, {176.61,212.53}, }
},

{
name="5-3-0",
color={1.00,0.80,0.67,1.00},
points={{99.26,343.27}, {171.07,344.52}, {140.47,351.81}, {100.92,350.97}, }
},

{
name="6-0-0",
color={1.00,0.64,0.00,1.00},
points={{193.00,203.70}, {244.63,208.43}, {249.72,220.72}, {250.56,401.96}, {189.84,406.16}, {197.13,276.54}, }
},
{
name="6-0-1",
color={1.00,0.64,0.00,1.00},
points={{199.01,299.90}, {224.98,304.12}, }
},

{
name="6-1-0",
color={1.00,0.64,0.00,1.00},
points={{212.81,202.97}, {247.19,204.25}, }
},

{
name="6-2-0",
color={1.00,0.64,0.00,1.00},
points={{250.59,217.36}, {250.12,204.50}, }
},

{
name="6-3-0",
color={1.00,0.64,0.00,1.00},
points={{215.50,406.35}, {251.01,403.90}, }
},

{
name="7-0-0",
color={0.16,0.68,1.00,1.00},
points={{104.01,237.00}, {162.16,236.94}, {167.64,244.85}, {168.78,338.92}, {102.97,337.28}, }
},

{
name="7-1-0",
color={0.16,0.68,1.00,1.00},
points={{169.21,242.54}, {169.47,237.46}, }
},



   }

   current_shape_index = 1

   backdrop = {
      grid = {cellsize=100}, -- cellsize is in px
      bg_color = {34/255,30/255,30/255},
      image = love.graphics.newImage("resources/backdrops/offshore-707.jpg"),
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


   local triangleCount = 0
   for i = 1, #shapes do
      local points = shapes[i].points
      if (#points >= 2 ) then

	 local scale = 1
	 local coords = {}
	 local coordsRound = {}
	 local ps = {}
	 for l=1, #points do
	    table.insert(coords, points[l][1])
	    table.insert(coords, points[l][2])
	    table.insert(coordsRound, points[l][1])
	    table.insert(coordsRound, points[l][2])
	 end

	 table.insert(coordsRound, points[1][1])
	 table.insert(coordsRound, points[1][2])

	 if (shapes[i].color) then

	    local c = shapes[i].color
	    love.graphics.setColor(c[1], c[2], c[3], c[4] or 1)

	    local c,a = poly.getPolygonCentroid(coordsRound)

	    local polys = decompose_complex_poly(coords, {})

	    local result = {}
	    for k=1 , #polys do
	       local p = polys[k]
	       if (#p >= 6) then
		  -- if a import breaks on triangulation errors uncomment this
		  --print(shapes[i].name, #p, inspect(p))
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
	       triangleCount = triangleCount + #result
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
    love.graphics.setFont(condensed)
   for i=1, #shapes do
      if iconlabelbutton('object-group', ui.object_group, shapes[i].color, current_shape_index == i, shapes[i].name or "p-"..i,  w - (64 + 400+ 10)/2, calcY((i+1),s)+(i+1)*8*s, s).clicked then
	 current_shape_index = i
	 editingMode = 'polyline'
	  editingModeSub = 'polyline-edit'
      end
   end
   love.graphics.setFont(medium)

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
   love.graphics.print(triangleCount, 2,2)
   if quitDialog then
      love.graphics.setFont(large)
      love.graphics.setColor(1,0.5,0.5, 1)
      love.graphics.print("Sure you want to quit ? [ESC] ", 116, 14)
      love.graphics.setColor(1,1,1, 1)
      love.graphics.print("Sure you want to quit ? [ESC] ", 115, 13)
      love.graphics.setFont(medium)
   end

end

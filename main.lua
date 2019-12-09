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
      local dot_x = points[i].x - 5/camera.scale
      local dot_y = points[i].y - 5/camera.scale
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
      local d = distancePointSegment(wx, wy, points[j].x, points[j].y, points[next].x, points[next].y)
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
	 table.insert(shapes[current_shape_index].points, {x=wx, y=wy})
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
	 table.insert(shapes[current_shape_index].points, closestEdgeIndex+1, {x=wx, y=wy})
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
	 shapes[current_shape_index].points[i].x = p.x + dx / camera.scale
	 shapes[current_shape_index].points[i].y = p.y + dy / camera.scale
      end
   end

   if (editingMode == 'polyline') and (editingModeSub == 'polyline-edit') then
      if (lastDraggedElement and lastDraggedElement.id == 'polyline') then
   	 local dragIndex = lastDraggedElement.index
   	 if dragIndex > 0 then
   	    local wx, wy = toWorldPos(x, y)
   	    local points = shapes[current_shape_index].points
   	    if (dragIndex <= #points) then
   	       points[dragIndex].x = wx
   	       points[dragIndex].y = wy
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
   -- 	 outline = true,
   -- 	 alpha = 0.8,
   -- 	 color = {1,0,0},
   -- 	 points = {{x=100,y=100},{x=200,y=100},{x=200,y=200},{x=100,y=200}},
   -- }, {
   -- 	 outline = true,
   -- 	 alpha = 0.8,
   -- 	 color = {1,1,0},
   -- 	 points = {{x=150,y=100},{x=250,y=100},{x=250,y=200},{x=150,y=200}},
   --    }, {
   -- 	 outline = true,
   -- 	 alpha = 1,
   -- 	 points = {}
   -- }}

   shapes = {
      {
outline=false,
alpha=1.00,
color={0,0,0},
points={{x=44.35,y=12.37}, {x=51.96421875000001,y=11.0221875}, {x=67.35765625,y=9.616562499999999}, {x=75.09,y=9.54}, {x=81.33828125000001,y=10.900625000000002}, {x=90.50650390625,y=13.826328125}, {x=96.73544921875,y=15.212734375}, {x=99.95,y=15.44}, {x=103.25484374999999,y=15.855625}, {x=109.92453125,y=16.761875}, {x=113.01,y=18.01}, {x=115.27078125,y=20.165156250000003}, {x=118.72359375,y=25.37171875}, {x=120,y=28.23}, {x=120,y=28.635981445312503}, {x=120,y=31.566108398437507}, {x=120,y=39.668085937499995}, {x=120,y=52.941914062500004}, {x=120,y=61.04389160156249}, {x=120,y=63.97401855468749}, {x=120,y=64.38}, {x=118.38578125000001,y=74.766875}, {x=114.45234375000001,y=95.401875}, {x=111.64,y=105.53}, {x=110.5690625,y=105.70093750000001}, {x=108.4309375,y=106.0390625}, {x=107.36,y=106.21}, {x=106.93587890625,y=100.51833984374998}, {x=106.89154296875,y=89.11861328124999}, {x=107.81048828125,y=77.74935546875}, {x=109.56240234375,y=66.47337890625}, {x=110.71,y=60.89}, {x=111.83999999999999,y=55.26203125}, {x=112.190859375,y=46.71080078125}, {x=111.22789062500001,y=41.10802734375}, {x=110.31,y=38.38}, {x=109.28593749999999,y=46.3840625}, {x=107.7738671875,y=58.4950390625}, {x=105.6634765625,y=66.25886718750002}, {x=103.99,y=69.95}, {x=100.44718749999998,y=76.576875}, {x=92.7315625,y=89.47437500000001}, {x=88.57,y=95.73}, {x=86.46626953124999,y=98.2212890625}, {x=81.19052734375,y=101.64574218749999}, {x=75.01619140625,y=103.21300781250001}, {x=68.57419921875001,y=103.18746093749999}, {x=65.45,y=102.66}, {x=60.446875000000006,y=101.70859375}, {x=52.891796875,y=100.11654296875}, {x=48.144140625000006,y=98.31494140625}, {x=45.94,y=97.03}, {x=44.17119140625,y=95.07951171875001}, {x=41.42716796875,y=90.63525390625}, {x=38.389843750000004,y=83.28390625}, {x=36.38,y=78.45}, {x=34.34638671875,y=73.02673828124999}, {x=31.709316406249997,y=61.81318359375}, {x=29.96328125,y=44.51296875}, {x=29.21,y=33}, {x=27.1165625,y=34.4403125}, {x=22.873437499999998,y=37.32843749999999}, {x=21.23,y=39.23}, {x=20.55771484375,y=43.471640625}, {x=20.43705078125,y=51.969921875}, {x=22.04140625,y=64.705625}, {x=23.31,y=73.15}, {x=23.241875,y=78.1675}, {x=22.179375,y=88.16875}, {x=21.38,y=93.13}, {x=20.82078125,y=95.64}, {x=19.80705078125,y=99.47062499999998}, {x=18.551152343749997,y=101.71812499999999}, {x=17.63,y=102.66}, {x=16.5333984375,y=103.30630859374999}, {x=14.127382812499999,y=103.79783203125}, {x=10.432812499999999,y=102.98765624999999}, {x=8.26,y=101.77}, {x=7.95447265625,y=95.98095703125}, {x=8.532636718750002,y=84.42302734375}, {x=9.76283203125,y=72.87400390625}, {x=10.52474609375,y=61.31232421875}, {x=10.38,y=55.52}, {x=10.197656250000001,y=49.51578125}, {x=10.18171875,y=37.507343750000004}, {x=10.59,y=31.52}, {x=11.207109375,y=28.35287109375}, {x=14.066953125,y=22.780332031250005}, {x=18.578671875000005,y=18.34451171875}, {x=24.123515625,y=15.190722656250001}, {x=27.09,y=14.14}, {x=31.3703125,y=13.45421875}, {x=40.04718749999999,y=12.98265625}, }
},
{
outline=false,
alpha=1.00,
color={0,0,0},
points={{x=75.23,y=10.71}, {x=66.91875,y=10.75703125}, {x=54.460078124999995,y=11.532753906249999}, {x=46.329296875,y=13.14482421875}, {x=42.36,y=14.44}, {x=39.94146484375,y=15.92232421875}, {x=35.93923828125,y=19.818378906249997}, {x=33.15248046875001,y=24.66177734375}, {x=31.704003906249998,y=30.09908203125}, {x=31.52,y=32.93}, {x=31.1107421875,y=40.3173828125}, {x=31.9675390625,y=55.0640234375}, {x=34.8877734375,y=69.5622265625}, {x=39.667070312499995,y=83.5588671875}, {x=42.69,y=90.29}, {x=43.444638671875,y=91.958349609375}, {x=45.420322265624996,y=94.680751953125}, {x=49.323984374999995,y=97.487890625}, {x=59.025,y=100.21812499999999}, {x=65.59,y=101.4}, {x=68.56498046875001,y=101.76613281250002}, {x=74.74697265625,y=101.80183593750002}, {x=80.68755859375001,y=100.4791015625}, {x=85.72580078125,y=97.28230468750002}, {x=87.7,y=94.82}, {x=92.36984375,y=87.3425}, {x=101.27453125,y=72.1175}, {x=105.14,y=64.19}, {x=106.24708984374999,y=61.266484375}, {x=107.54205078125,y=55.210390625}, {x=107.85265625,y=45.863749999999996}, {x=107.49,y=39.66}, {x=106.78125,y=34.5359375}, {x=104.793515625,y=26.938320312500004}, {x=102.08085937500002,y=22.6240234375}, {x=100.11,y=20.87}, {x=97.28751953125,y=19.022089843750003}, {x=91.32990234374999,y=15.81048828125}, {x=81.81046875,y=12.237031250000001}, }
},
{
outline=false,
alpha=1.00,
color={0,0,0},
points={{x=11.32,y=33.28}, {x=11.1759375,y=42.69562499999999}, {x=11.4803125,y=61.545624999999994}, {x=10.83,y=70.95}, {x=10.004999999999999,y=78.604375}, {x=8.895,y=93.95062500000002}, {x=8.7,y=101.65}, {x=10.230156249999999,y=101.8409375}, {x=13.294218749999999,y=102.1590625}, {x=14.83,y=102.17}, {x=15.898496093749998,y=101.9541015625}, {x=17.59908203125,y=100.8013671875}, {x=19.24703125,y=98.00468749999999}, {x=19.89,y=96}, {x=21.12203125,y=88.54921875}, {x=22.25142578125,y=77.23505859375}, {x=21.82115234375,y=69.71923828125}, {x=21.07,y=66}, {x=20.29349609375,y=62.33259765625}, {x=19.319394531249998,y=54.856699218749995}, {x=19.25701171875,y=47.32783203125}, {x=20.274160156249998,y=39.908183593749996}, {x=21.24,y=36.29}, {x=23.23984375,y=35.186562499999994}, {x=27.35578125,y=33.2046875}, {x=29.44,y=32.27}, {x=30.95796875,y=27.4575}, {x=35.42640625,y=18.5}, {x=38.39,y=14.43}, {x=36.122734375,y=14.220148925781249}, {x=31.5471875,y=14.44456787109375}, {x=27.056015625,y=15.482209472656251}, {x=22.816093749999997,y=17.27834716796875}, {x=18.994296874999996,y=19.778254394531253}, {x=15.7575,y=22.927204589843754}, {x=13.272578124999999,y=26.67047119140625}, {x=11.70640625,y=30.953327636718754}, }
},
{
outline=false,
alpha=1.00,
color={0,0,0},
points={{x=95.92,y=15.5}, {x=97.80375000000001,y=17.25234375}, {x=101.53375,y=20.79453125}, {x=103.35,y=22.62}, {x=104.66777343749999,y=24.66060546875}, {x=106.6058203125,y=29.13322265625}, {x=108.2935546875,y=33.73943359375}, {x=110.5466015625,y=38.01330078125}, {x=112.14,y=39.88}, {x=113.24669921875,y=41.355859375}, {x=114.21650390625,y=44.723828125}, {x=113.86828125,y=50.246874999999996}, {x=113.45,y=53.8}, {x=111.3534375,y=63.502187500000005}, {x=108.68261718749999,y=78.1451171875}, {x=107.67472656249998,y=88.00785156250001}, {x=107.52,y=92.98}, {x=107.27859375,y=96.26515625000002}, {x=108.25828125000001,y=102.70421875}, {x=109.44,y=105.77}, {x=111.061494140625,y=101.81410400390625}, {x=113.704716796875,y=93.75049560546876}, {x=116.388984375,y=81.34958984375001}, {x=118.59187500000002,y=55.936718750000004}, {x=118.98,y=38.97}, {x=118.82359375,y=34.527812499999996}, {x=118.17091796875,y=27.7338671875}, {x=116.56431640625001,y=23.606914062499996}, {x=115.18,y=21.79}, {x=113.2933984375,y=19.926269531249996}, {x=108.7889453125,y=17.543652343749997}, {x=101.0584375,y=16.06796875}, }
},
{
outline=false,
alpha=1.00,
color={0,0,0},
points={{x=44.6,y=17.49}, {x=55.545156250000005,y=17.32359375}, {x=77.44296874999999,y=17.54203125}, {x=88.36,y=18.36}, {x=77.41343749999999,y=18.361875000000005}, {x=55.5240625,y=18.343125}, }
},
{
outline=false,
alpha=1.00,
color={0,0,0},
points={{x=35.66,y=23.71}, {x=42.03156250000001,y=22.127031249999998}, {x=51.77230468750001,y=20.85736328125}, {x=58.309101562500004,y=21.07146484375}, {x=61.57,y=21.58}, {x=65.55238281250001,y=22.012441406249998}, {x=73.5565234375,y=21.96373046875}, {x=81.55222656249998,y=21.70080078125}, {x=89.4663671875,y=22.428339843750003}, {x=93.37,y=23.54}, {x=84.51171874999999,y=23.105625}, {x=71.21052734374999,y=23.038828125}, {x=62.37626953125,y=22.536484375}, {x=57.98,y=21.93}, {x=55.178515624999996,y=21.695585937500002}, {x=49.592421875,y=21.9148828125}, {x=41.234375,y=23.0746875}, }
},
{
outline=false,
alpha=1.00,
color={0,0,0},
points={{x=38.24,y=30.65}, {x=41.2171875,y=30.490625}, {x=45.4925390625,y=31.313281250000003}, {x=48.0654296875,y=32.70078125}, {x=49.23,y=33.68}, {x=48.1021875,y=34.91453125}, {x=45.779062499999995,y=37.32359375000001}, {x=44.46,y=38.35}, {x=42.55265625,y=38.278437499999995}, {x=38.76046875,y=38.0153125}, {x=36.87,y=37.82}, {x=37.221875000000004,y=36.0275}, {x=37.91062500000001,y=32.442499999999995}, }
},
{
outline=false,
alpha=1.00,
color={0,0,0},
points={{x=38.13,y=32.01}, {x=38.639062499999994,y=33.37828125}, {x=39.8709375,y=36.67734374999999}, {x=40.38,y=38.04}, {x=41.76345703125,y=38.193808593750006}, {x=43.88208984375001,y=37.32158203125}, {x=45.91921875,y=34.25015625}, {x=46.89,y=31.95}, {x=44.7,y=31.880625}, {x=40.32,y=31.921875}, }
},
{
outline=false,
alpha=1.00,
color={0,0,0},
points={{x=77.17,y=31.06}, {x=81.92156250000002,y=31.095625}, {x=91.37593750000002,y=31.853125000000002}, {x=95.97,y=33.07}, {x=94.718125,y=35.6290625}, {x=92.335234375,y=39.0557421875}, {x=89.72632812499998,y=39.6519140625}, {x=87.94,y=39.08}, {x=86.21763671875,y=38.837519531249995}, {x=83.19900390625,y=37.35365234375}, {x=79.42515625,y=33.672968749999995}, }
},
{
outline=false,
alpha=1.00,
color={0,0,0},
points={{x=79.19,y=33.21}, {x=81.16296875,y=34.365}, {x=85.10890624999999,y=36.72}, {x=87.2,y=37.65}, {x=88.4241015625,y=37.91859375}, {x=90.5901171875,y=37.617656249999996}, {x=93.3621875,y=35.8725}, {x=95.07,y=34.47}, {x=93.18015624999998,y=33.634511718750005}, {x=89.27203125,y=32.62025390625001}, {x=83.229375,y=32.513906250000005}, }
},
{
outline=false,
alpha=1.00,
color={0,0,0},
points={{x=40.98,y=32.98}, {x=42.0359375,y=33.004374999999996}, {x=44.144062500000004,y=33.064375}, {x=45.2,y=33.1}, {x=44.89828125,y=33.8215625}, {x=44.287343750000005,y=35.268437500000005}, {x=43.98,y=35.99}, {x=43.3078125,y=35.99906250000001}, {x=41.6821875,y=36.0209375}, {x=41.01,y=36.03}, {x=41.0025,y=35.33546875}, {x=40.9875,y=33.66890625}, }
},
{
outline=false,
alpha=1.00,
color={0,0,0},
points={{x=85.25,y=33.42}, {x=86.46656250000001,y=33.51671875}, {x=88.9034375,y=33.73640625}, {x=90.12,y=33.85}, {x=89.9478125,y=34.748906250000005}, {x=89.53218749999999,y=36.92546874999999}, {x=89.36,y=37.83}, {x=88.29875000000001,y=36.755624999999995}, {x=86.24375,y=34.550625}, }
},
{
outline=false,
alpha=1.00,
color={0,0,0},
points={{x=47.19,y=52.14}, {x=48.039785156250005,y=49.851328124999995}, {x=50.45232421875,y=45.318984375}, {x=53.86939453125,y=41.662265624999996}, {x=58.35568359375001,y=39.859921875}, {x=61.02,y=39.96}, {x=63.52232421875001,y=39.752421874999996}, {x=68.41494140625001,y=40.500703125}, {x=72.84490234375001,y=42.653359374999994}, {x=76.43626953124999,y=46.034140625000006}, {x=77.8,y=48.13}, {x=79.0896875,y=51.035117187500006}, {x=80.90499999999999,y=57.113476562500004}, {x=81.70781249999999,y=63.410273437499995}, {x=81.50562500000001,y=69.75863281250001}, {x=81.03,y=72.9}, {x=80.1515625,y=79.049375}, {x=78.5895703125,y=88.2828125}, {x=76.4255859375,y=94.061875}, {x=74.76,y=96.74}, {x=73.65625,y=98.06591796875}, {x=70.58343749999999,y=99.34103515625}, {x=67.15062499999999,y=98.94224609375}, {x=64.3103125,y=97.06361328125}, {x=63.41,y=95.63}, {x=62.57875,y=92.24593750000001}, {x=62.34125,y=85.21531250000001}, {x=62.23,y=81.73}, {x=60.46953125,y=85.42531249999999}, {x=57.644550781250004,y=91.1540234375}, {x=54.80302734375,y=94.0442578125}, {x=52.88,y=94.94}, {x=51.29875,y=94.86865234375}, {x=48.3321875,y=93.72798828124999}, {x=45.845625000000005,y=91.59029296874999}, {x=44.1015625,y=88.85587890625}, {x=43.59,y=87.39}, {x=43.26890625,y=82.94888671875}, {x=43.428281250000005,y=74.05962890625}, {x=45.249375,y=60.81890625}, }
},
{
outline=false,
alpha=1.00,
color={0,0,0},
points={{x=56.62,y=41.59}, {x=54.55779296875,y=42.9463671875}, {x=51.30103515625,y=46.523476562499994}, {x=48.18953125,y=53.230937499999996}, {x=46.99,y=57.96}, {x=45.72703125,y=65.00515625}, {x=44.27173828125001,y=75.67806640625}, {x=44.22458984375001,y=82.82107421875}, {x=44.64,y=86.39}, {x=45.930468749999996,y=88.89953125}, {x=49.99640625000001,y=92.94734374999999}, {x=52.08,y=94.9}, {x=54.89859375,y=92.12234375}, {x=58.92703125,y=85.42328125}, {x=60.12,y=81.65}, {x=57.153125,y=79.30734375}, {x=53.172734375000005,y=75.35068359375}, {x=51.417578125000006,y=72.06642578124999}, {x=50.96,y=70.14}, {x=56.23406250000001,y=70.07171875}, {x=66.7859375,y=70.11890625000001}, {x=72.06,y=70.18}, {x=71.65376953124999,y=72.0768359375}, {x=70.26896484375001,y=75.60425781250001}, {x=68.16556640625001,y=78.6938671875}, {x=65.39701171875001,y=81.24628906250001}, {x=63.78,y=82.29}, {x=63.49000000000001,y=85.86890625000001}, {x=63.439375,y=91.43853515625001}, {x=64.53687500000001,y=94.83873046875001}, {x=65.65,y=96.33}, {x=66.34859374999999,y=97.0565234375}, {x=68.17984374999999,y=98.02488281250001}, {x=70.23984375,y=98.23292968749999}, {x=72.10859375000001,y=97.5437890625}, {x=72.84,y=96.82}, {x=75.06634765625,y=93.61210937499999}, {x=77.80951171875,y=86.518515625}, {x=79.48734375,y=75.00625}, {x=80.41,y=67.39}, {x=80.45267578125,y=63.98169921875}, {x=79.64693359374999,y=56.94525390625}, {x=77.35384765625,y=50.27115234375}, {x=73.21435546875,y=44.74595703125}, {x=70.34,y=42.66}, {x=67.05578125000001,y=41.4971875}, {x=60.04484375,y=41.0990625}, }
},
{
outline=false,
alpha=1.00,
color={0,0,0},
points={{x=120,y=83.78}, {x=119.330625,y=83.51052734375}, {x=118.565625,y=82.56517578125002}, {x=118.565625,y=81.41779296875}, {x=119.330625,y=80.47619140625}, {x=120,y=80.21}, {x=120,y=80.76781249999999}, {x=120,y=83.2221875}, }
},
{
outline=false,
alpha=1.00,
color={0.6705882352941176,0.3215686274509804,0.21176470588235294},
points={{x=75.23,y=10.71}, {x=81.81046875,y=12.237031250000001}, {x=91.32990234374999,y=15.81048828125}, {x=97.28751953125,y=19.022089843750003}, {x=100.11,y=20.87}, {x=102.08085937500002,y=22.6240234375}, {x=104.793515625,y=26.938320312500004}, {x=106.78125,y=34.5359375}, {x=107.49,y=39.66}, {x=107.85265625,y=45.863749999999996}, {x=107.54205078125,y=55.210390625}, {x=106.24708984374999,y=61.266484375}, {x=105.14,y=64.19}, {x=101.27453125,y=72.1175}, {x=92.36984375,y=87.3425}, {x=87.7,y=94.82}, {x=85.72580078125,y=97.28230468750002}, {x=80.68755859375001,y=100.4791015625}, {x=74.74697265625,y=101.80183593750002}, {x=68.56498046875001,y=101.76613281250002}, {x=65.59,y=101.4}, {x=59.025,y=100.21812499999999}, {x=49.323984374999995,y=97.487890625}, {x=45.420322265624996,y=94.680751953125}, {x=43.444638671875,y=91.958349609375}, {x=42.69,y=90.29}, {x=39.667070312499995,y=83.5588671875}, {x=34.8877734375,y=69.5622265625}, {x=31.9675390625,y=55.0640234375}, {x=31.1107421875,y=40.3173828125}, {x=31.52,y=32.93}, {x=31.704003906249998,y=30.09908203125}, {x=33.15248046875001,y=24.66177734375}, {x=35.93923828125,y=19.818378906249997}, {x=39.94146484375,y=15.92232421875}, {x=42.36,y=14.44}, {x=46.329296875,y=13.14482421875}, {x=54.460078124999995,y=11.532753906249999}, {x=66.91875,y=10.75703125}, }
},
{
outline=false,
alpha=1.00,
color={0.6705882352941176,0.3215686274509804,0.21176470588235294},
points={{x=44.6,y=17.49}, {x=55.5240625,y=18.343125}, {x=77.41343749999999,y=18.361875000000005}, {x=88.36,y=18.36}, {x=77.44296874999999,y=17.54203125}, {x=55.545156250000005,y=17.32359375}, }
},
{
outline=false,
alpha=1.00,
color={0.6705882352941176,0.3215686274509804,0.21176470588235294},
points={{x=35.66,y=23.71}, {x=41.234375,y=23.0746875}, {x=49.592421875,y=21.9148828125}, {x=55.178515624999996,y=21.695585937500002}, {x=57.98,y=21.93}, {x=62.37626953125,y=22.536484375}, {x=71.21052734374999,y=23.038828125}, {x=84.51171874999999,y=23.105625}, {x=93.37,y=23.54}, {x=89.4663671875,y=22.428339843750003}, {x=81.55222656249998,y=21.70080078125}, {x=73.5565234375,y=21.96373046875}, {x=65.55238281250001,y=22.012441406249998}, {x=61.57,y=21.58}, {x=58.309101562500004,y=21.07146484375}, {x=51.77230468750001,y=20.85736328125}, {x=42.03156250000001,y=22.127031249999998}, }
},
{
outline=false,
alpha=1.00,
color={0.6705882352941176,0.3215686274509804,0.21176470588235294},
points={{x=38.24,y=30.65}, {x=37.91062500000001,y=32.442499999999995}, {x=37.221875000000004,y=36.0275}, {x=36.87,y=37.82}, {x=38.76046875,y=38.0153125}, {x=42.55265625,y=38.278437499999995}, {x=44.46,y=38.35}, {x=45.779062499999995,y=37.32359375000001}, {x=48.1021875,y=34.91453125}, {x=49.23,y=33.68}, {x=48.0654296875,y=32.70078125}, {x=45.4925390625,y=31.313281250000003}, {x=41.2171875,y=30.490625}, }
},
{
outline=false,
alpha=1.00,
color={0.6705882352941176,0.3215686274509804,0.21176470588235294},
points={{x=77.17,y=31.06}, {x=79.42515625,y=33.672968749999995}, {x=83.19900390625,y=37.35365234375}, {x=86.21763671875,y=38.837519531249995}, {x=87.94,y=39.08}, {x=89.72632812499998,y=39.6519140625}, {x=92.335234375,y=39.0557421875}, {x=94.718125,y=35.6290625}, {x=95.97,y=33.07}, {x=91.37593750000002,y=31.853125000000002}, {x=81.92156250000002,y=31.095625}, }
},
{
outline=false,
alpha=1.00,
color={0.6705882352941176,0.3215686274509804,0.21176470588235294},
points={{x=47.19,y=52.14}, {x=45.249375,y=60.81890625}, {x=43.428281250000005,y=74.05962890625}, {x=43.26890625,y=82.94888671875}, {x=43.59,y=87.39}, {x=44.1015625,y=88.85587890625}, {x=45.845625000000005,y=91.59029296874999}, {x=48.3321875,y=93.72798828124999}, {x=51.29875,y=94.86865234375}, {x=52.88,y=94.94}, {x=54.80302734375,y=94.0442578125}, {x=57.644550781250004,y=91.1540234375}, {x=60.46953125,y=85.42531249999999}, {x=62.23,y=81.73}, {x=62.34125,y=85.21531250000001}, {x=62.57875,y=92.24593750000001}, {x=63.41,y=95.63}, {x=64.3103125,y=97.06361328125}, {x=67.15062499999999,y=98.94224609375}, {x=70.58343749999999,y=99.34103515625}, {x=73.65625,y=98.06591796875}, {x=74.76,y=96.74}, {x=76.4255859375,y=94.061875}, {x=78.5895703125,y=88.2828125}, {x=80.1515625,y=79.049375}, {x=81.03,y=72.9}, {x=81.50562500000001,y=69.75863281250001}, {x=81.70781249999999,y=63.410273437499995}, {x=80.90499999999999,y=57.113476562500004}, {x=79.0896875,y=51.035117187500006}, {x=77.8,y=48.13}, {x=76.43626953124999,y=46.034140625000006}, {x=72.84490234375001,y=42.653359374999994}, {x=68.41494140625001,y=40.500703125}, {x=63.52232421875001,y=39.752421874999996}, {x=61.02,y=39.96}, {x=58.35568359375001,y=39.859921875}, {x=53.86939453125,y=41.662265624999996}, {x=50.45232421875,y=45.318984375}, {x=48.039785156250005,y=49.851328124999995}, }
},
{
outline=false,
alpha=1.00,
color={0.6705882352941176,0.3215686274509804,0.21176470588235294},
points={{x=11.32,y=33.28}, {x=11.70640625,y=30.953327636718754}, {x=13.272578124999999,y=26.67047119140625}, {x=15.7575,y=22.927204589843754}, {x=18.994296874999996,y=19.778254394531253}, {x=22.816093749999997,y=17.27834716796875}, {x=27.056015625,y=15.482209472656251}, {x=31.5471875,y=14.44456787109375}, {x=36.122734375,y=14.220148925781249}, {x=38.39,y=14.43}, {x=35.42640625,y=18.5}, {x=30.95796875,y=27.4575}, {x=29.44,y=32.27}, {x=27.35578125,y=33.2046875}, {x=23.23984375,y=35.186562499999994}, {x=21.24,y=36.29}, {x=20.274160156249998,y=39.908183593749996}, {x=19.25701171875,y=47.32783203125}, {x=19.319394531249998,y=54.856699218749995}, {x=20.29349609375,y=62.33259765625}, {x=21.07,y=66}, {x=21.82115234375,y=69.71923828125}, {x=22.25142578125,y=77.23505859375}, {x=21.12203125,y=88.54921875}, {x=19.89,y=96}, {x=19.24703125,y=98.00468749999999}, {x=17.59908203125,y=100.8013671875}, {x=15.898496093749998,y=101.9541015625}, {x=14.83,y=102.17}, {x=13.294218749999999,y=102.1590625}, {x=10.230156249999999,y=101.8409375}, {x=8.7,y=101.65}, {x=8.895,y=93.95062500000002}, {x=10.004999999999999,y=78.604375}, {x=10.83,y=70.95}, {x=11.4803125,y=61.545624999999994}, {x=11.1759375,y=42.69562499999999}, }
},
{
outline=false,
alpha=1.00,
color={0.6705882352941176,0.3215686274509804,0.21176470588235294},
points={{x=95.92,y=15.5}, {x=101.0584375,y=16.06796875}, {x=108.7889453125,y=17.543652343749997}, {x=113.2933984375,y=19.926269531249996}, {x=115.18,y=21.79}, {x=116.56431640625001,y=23.606914062499996}, {x=118.17091796875,y=27.7338671875}, {x=118.82359375,y=34.527812499999996}, {x=118.98,y=38.97}, {x=118.59187500000002,y=55.936718750000004}, {x=116.388984375,y=81.34958984375001}, {x=113.704716796875,y=93.75049560546876}, {x=111.061494140625,y=101.81410400390625}, {x=109.44,y=105.77}, {x=108.25828125000001,y=102.70421875}, {x=107.27859375,y=96.26515625000002}, {x=107.52,y=92.98}, {x=107.67472656249998,y=88.00785156250001}, {x=108.68261718749999,y=78.1451171875}, {x=111.3534375,y=63.502187500000005}, {x=113.45,y=53.8}, {x=113.86828125,y=50.246874999999996}, {x=114.21650390625,y=44.723828125}, {x=113.24669921875,y=41.355859375}, {x=112.14,y=39.88}, {x=110.5466015625,y=38.01330078125}, {x=108.2935546875,y=33.73943359375}, {x=106.6058203125,y=29.13322265625}, {x=104.66777343749999,y=24.66060546875}, {x=103.35,y=22.62}, {x=101.53375,y=20.79453125}, {x=97.80375000000001,y=17.25234375}, }
},
{
outline=false,
alpha=1.00,
color={0,0.5294117647058824,0.3176470588235294},
points={{x=38.13,y=32.01}, {x=40.32,y=31.921875}, {x=44.7,y=31.880625}, {x=46.89,y=31.95}, {x=45.91921875,y=34.25015625}, {x=43.88208984375001,y=37.32158203125}, {x=41.76345703125,y=38.193808593750006}, {x=40.38,y=38.04}, {x=39.8709375,y=36.67734374999999}, {x=38.639062499999994,y=33.37828125}, }
},
{
outline=false,
alpha=1.00,
color={0,0.5294117647058824,0.3176470588235294},
points={{x=40.98,y=32.98}, {x=40.9875,y=33.66890625}, {x=41.0025,y=35.33546875}, {x=41.01,y=36.03}, {x=41.6821875,y=36.0209375}, {x=43.3078125,y=35.99906250000001}, {x=43.98,y=35.99}, {x=44.287343750000005,y=35.268437500000005}, {x=44.89828125,y=33.8215625}, {x=45.2,y=33.1}, {x=44.144062500000004,y=33.064375}, {x=42.0359375,y=33.004374999999996}, }
},
{
outline=false,
alpha=1.00,
color={0,0.5294117647058824,0.3176470588235294},
points={{x=79.19,y=33.21}, {x=83.229375,y=32.513906250000005}, {x=89.27203125,y=32.62025390625001}, {x=93.18015624999998,y=33.634511718750005}, {x=95.07,y=34.47}, {x=93.3621875,y=35.8725}, {x=90.5901171875,y=37.617656249999996}, {x=88.4241015625,y=37.91859375}, {x=87.2,y=37.65}, {x=85.10890624999999,y=36.72}, {x=81.16296875,y=34.365}, }
},
{
outline=false,
alpha=1.00,
color={0,0.5294117647058824,0.3176470588235294},
points={{x=85.25,y=33.42}, {x=86.24375,y=34.550625}, {x=88.29875000000001,y=36.755624999999995}, {x=89.36,y=37.83}, {x=89.53218749999999,y=36.92546874999999}, {x=89.9478125,y=34.748906250000005}, {x=90.12,y=33.85}, {x=88.9034375,y=33.73640625}, {x=86.46656250000001,y=33.51671875}, }
},
{
outline=false,
alpha=1.00,
color={1,0.6392156862745098,0},
points={{x=56.62,y=41.59}, {x=60.04484375,y=41.0990625}, {x=67.05578125000001,y=41.4971875}, {x=70.34,y=42.66}, {x=73.21435546875,y=44.74595703125}, {x=77.35384765625,y=50.27115234375}, {x=79.64693359374999,y=56.94525390625}, {x=80.45267578125,y=63.98169921875}, {x=80.41,y=67.39}, {x=79.48734375,y=75.00625}, {x=77.80951171875,y=86.518515625}, {x=75.06634765625,y=93.61210937499999}, {x=72.84,y=96.82}, {x=72.10859375000001,y=97.5437890625}, {x=70.23984375,y=98.23292968749999}, {x=68.17984374999999,y=98.02488281250001}, {x=66.34859374999999,y=97.0565234375}, {x=65.65,y=96.33}, {x=64.53687500000001,y=94.83873046875001}, {x=63.439375,y=91.43853515625001}, {x=63.49000000000001,y=85.86890625000001}, {x=63.78,y=82.29}, {x=65.39701171875001,y=81.24628906250001}, {x=68.16556640625001,y=78.6938671875}, {x=70.26896484375001,y=75.60425781250001}, {x=71.65376953124999,y=72.0768359375}, {x=72.06,y=70.18}, {x=66.7859375,y=70.11890625000001}, {x=56.23406250000001,y=70.07171875}, {x=50.96,y=70.14}, {x=51.417578125000006,y=72.06642578124999}, {x=53.172734375000005,y=75.35068359375}, {x=57.153125,y=79.30734375}, {x=60.12,y=81.65}, {x=58.92703125,y=85.42328125}, {x=54.89859375,y=92.12234375}, {x=52.08,y=94.9}, {x=49.99640625000001,y=92.94734374999999}, {x=45.930468749999996,y=88.89953125}, {x=44.64,y=86.39}, {x=44.22458984375001,y=82.82107421875}, {x=44.27173828125001,y=75.67806640625}, {x=45.72703125,y=65.00515625}, {x=46.99,y=57.96}, {x=48.18953125,y=53.230937499999996}, {x=51.30103515625,y=46.523476562499994}, {x=54.55779296875,y=42.9463671875}, }
},
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
	    table.insert(coords, points[i].x)
	    table.insert(coords, points[i].y)
	    table.insert(coordsRound, points[i].x)
	    table.insert(coordsRound, points[i].y)
	 end

	 table.insert(coordsRound, points[1].x)
	 table.insert(coordsRound, points[1].y)

	 if (shapes[i].color) then

	    local c = shapes[i].color
	    love.graphics.setColor(c[1], c[2], c[3], shapes[i].alpha or 1)

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
	 if mouseOverPolyPoint(mx, my, points[i].x, points[i].y) then
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
	 local dot_x = points[i].x - 5/camera.scale
	 local dot_y =  points[i].y - 5/camera.scale
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
	    shapes[current_shape_index].color =  {rgb[1]/255,rgb[2]/255,rgb[3]/255}
	 end
      end
      local v =  h_slider("polyline_alpha", calcX(1, s), calcY(4, s)+ 12*s, 100,  shapes[current_shape_index].alpha , 0, 1)
      if (v.value ~= nil) then
	 shapes[current_shape_index].alpha = v.value
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
	 alpha= 1,
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

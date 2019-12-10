inspect = require 'inspect'
require 'ui'
require 'palettes'
require 'util'
polyline = require 'polyline'
poly = require 'poly'
local utf8 = require("utf8")

-- todo
-- rename the individual shapes
-- copy shapes
-- save load file
-- have parent child relations between shapes
-- have a vertical scrollview for the shapes

function love.textedited(text, start, length)
     -- print('text edited', text, start, length)

--    Hammer:handle_textedited(text, start, length)
end

function love.textinput(t)
   local str = shapes[current_shape_index].name or ""
   local a,b = split(str, changeNameCursor+1)
   local r = table.concat{a, t, b}
   changeNameCursor = changeNameCursor + 1
   shapes[current_shape_index].name = r
end
function split(str, pos)
   local offset = utf8.offset(str, pos) or 0
   return str:sub(1, offset-1), str:sub(offset)
end




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

   if (changeName) then
      if (key == 'backspace') then
	 local str = shapes[current_shape_index].name or ""
	 local a,b = split(str, changeNameCursor+1)
	 shapes[current_shape_index].name = table.concat{split(a,utf8.len(a)), b}
	 changeNameCursor = math.max(0, (changeNameCursor or 0)-1)
      end
      if (key == 'delete') then
	 local str = shapes[current_shape_index].name or ""
	 local a,b = split(str, changeNameCursor+2)
	 shapes[current_shape_index].name = table.concat{split(a,utf8.len(a)), b}
      end
      if (key == 'left') then
	 if (changeNameCursor > 0) then
	    changeNameCursor = changeNameCursor - 1
	 end
      end
      if (key == 'right' ) then
	 local str = shapes[current_shape_index].name or ""
	 if (changeNameCursor < utf8.len(str)) then
	    changeNameCursor = changeNameCursor + 1
	 end
      end
      if (key == 'return') then
	 changeName = false
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
   large = love.graphics.newFont( "resources/fonts/WindsorBT-Roman.otf", 48)

   condensed = medium --love.graphics.newFont( "resources/fonts/DomaineDispNar-Medium.otf", 32)
   --condensed = love.graphics.newFont( "resources/fonts/adlib.ttf", 32)
   --large = love.graphics.newFont( "resources/fonts/adlib.ttf", 64)
   introSound = love.audio.newSource("resources/sounds/supermarket.wav", "static")
   introSound:setVolume(0.1)
   introSound:play()
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

   shapes = { {
	 name="Yes hi ",
   	 color = {1,0,0, 0.8},
   	 points = {{100,100},{200,100},{200,200},{100,200}},
   }, {
   	 color = {1,1,0, 0.8},
   	 points = {{150,100},{250,100},{250,200},{150,200}},
      }, {
   	 outline = true,
   	 points = {}
   }}



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
			triangleCount = triangleCount+1
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
	 color = {0,0,0,1},
	 outline = true,
	 points = {},
      }
      table.insert(shapes, current_shape_index+1, shape)
      current_shape_index = current_shape_index + 1
      editingMode = 'polyline'
      editingModeSub = 'polyline-add'
   end

   for i=1, #shapes do
      if iconlabelbutton('object-group', ui.object_group, shapes[i].color, current_shape_index == i, shapes[i].name or "p-"..i,  w - (64 + 400+ 10)/2, calcY((i+1),s)+(i+1)*8*s, s).clicked then
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
      if imgbutton('badge', ui.badge,  w - (64 + 400+ 10 + 80 + 20 )/2, calcY(4, s) + 8*4, s).clicked then
	 changeName = not changeName
	 local name = shapes[current_shape_index].name
	 changeNameCursor = name and utf8.len(name) or 1
      end
      if (changeName) then
	 local str = shapes[current_shape_index].name or ""
	 local substr = string.sub(str, 1, changeNameCursor)
	 local cursorX = (love.graphics.getFont():getWidth(substr))
	 local cursorH = (love.graphics.getFont():getHeight(str))
	 love.graphics.setColor(1,1,1,0.5)
	 love.graphics.rectangle('fill', w-600 - 10, calcY(4, s) + 8*4 - 10, 300 + 20,  cursorH + 20 )
	 love.graphics.setColor(1,1,1)
	 love.graphics.print(shapes[current_shape_index].name or "", w - 600, calcY(4, s) + 8*4)
	 love.graphics.rectangle('fill', w- 600 + cursorX, calcY(4, s) + 8*4, 2, cursorH)
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

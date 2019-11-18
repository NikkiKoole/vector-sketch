inspect = require 'inspect'
require 'ui'
polyline = require 'polyline'
poly = require 'poly'
local Delaunay = require 'Delaunay'
local Point    = Delaunay.Point


function love.keypressed(key)
   if key == "escape" then
      if (editingModeSub ~= 'nil') then
	 editingModeSub = 'nil'
      elseif (editingMode ~= 'nil') then
	 editingMode = 'nil'
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


function love.mousepressed(x,y, button)
   if editingMode == 'nil' then
      editingMode = 'move'
   end
   
   if editingMode == 'polyline'  then
      if (editingModeSub == 'polyline-add') then
	 local connect_to_first = false
	 if overPolyLineIndex == 1 then
	    local points = shapes[current_shape_index].points
	    local dot_x = points[1].x - 5/camera.scale
	    local dot_y = points[1].y - 5/camera.scale
	    local dot_size = 10 / camera.scale
	    local wx, wy = toWorldPos(x, y)
	    
	    if (pointInRect(wx,wy, dot_x, dot_y, dot_size, dot_size)) then
	       connect_to_first = true
	       table.insert(shapes[current_shape_index].points, shapes[current_shape_index].points[1])
	    else
	       overPolyLineIndex = 0
	    end
	 end
	 if not  connect_to_first  then
	    if not mouseState.hoveredSomething  then
	       local wx, wy = toWorldPos(x, y)
	       table.insert(shapes[current_shape_index].points, {x=wx, y=wy})
	    end
	 end
      end
      if (editingModeSub == 'polyline-remove') then
	 if overPolyLineIndex then table.remove (shapes[current_shape_index].points, overPolyLineIndex) end
      end
      if (editingModeSub == 'polyline-edit') then
	 if overPolyLineIndex then
	    draggingPointOfPolyLineIndex = overPolyLineIndex
	 end
      end
      
   end
   
end

function love.mousereleased(x,y, button)
   if editingMode == 'move' then
      editingMode = 'nil'
   end

   if (editingMode == 'polyline') and (editingModeSub == 'polyline-edit') then
      draggingPointOfPolyLineIndex = 0
      overPolyLineIndex = 0
   end
   
end

function love.mousemoved(x,y, dx, dy)
   if editingMode == 'move' and love.mouse.isDown(1) or love.keyboard.isDown('space') then
      camera.x = camera.x + dx / camera.scale
      camera.y = camera.y + dy / camera.scale
   end
   
   if (editingMode == 'polyline') and (editingModeSub == 'polyline-edit') then
      if draggingPointOfPolyLineIndex > 0 then
	 local wx, wy = toWorldPos(x, y)
	 local points = shapes[current_shape_index].points
	 points[draggingPointOfPolyLineIndex].x = wx
	 points[draggingPointOfPolyLineIndex].y = wy
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
   
   image = love.graphics.newImage("test2.jpg")
   quad = love.graphics.newQuad(0, 0, image:getWidth(), image:getHeight(), image:getWidth(), image:getHeight())
   camera = {x=0, y=0, scale=1}
   editingMode = 'nil'
   editingModeSub = 'nil'
   grid = {cellsize=100} -- cellsize is in px
   medium = love.graphics.newFont( "resources/fonts/MPLUSRounded1c-Medium.ttf", 32)
   --light = love.graphics.newFont( "resources/fonts/MPLUSRounded1c-Light.ttf", 32)
   love.graphics.setFont(medium)
   
   ui = {
      polyline = love.graphics.newImage("resources/ui/polyline.png"),
      polyline_add = love.graphics.newImage("resources/ui/polyline-add.png"),
      polyline_edit = love.graphics.newImage("resources/ui/polyline-edit.png"),
      polyline_remove = love.graphics.newImage("resources/ui/polyline-remove.png"),
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
   }

   cursors = {
      hand= love.mouse.getSystemCursor("hand"),
      arrow= love.mouse.getSystemCursor("arrow")
   } 
   
   palette = {
      name='miffy',
      colors={
	 {name="green", rgb={48,112,47}},
	 {name="blue", rgb={27,84,154}},
	 {name="yellow", rgb={250,199,0}},
	 {name="orange1", rgb={233,100,14}},
	 {name="orange2", rgb={237,76,6}},
	 {name="orange3", rgb={221,61,14}},
	 {name="black1", rgb={34,30,30}},
	 {name="black2", rgb={24,26,23}},
	 {name="black2", rgb={24,26,23}},
	 {name="brown1", rgb={145,77,35}},
	 {name="brown2", rgb={114,65,11}},
	 {name="brown3", rgb={136,95,62}},
	 {name="grey1", rgb={147,142,114}},
	 {name="grey2", rgb={149,164,151}},
      }
   }

   mouseState = {
      hoveredSomething = false,
      down = false,
      lastDown = false,
      click = false
   }


   shapes = { {
	 points = {},
	 mesh = {}
   }}
   current_shape_index = 1 

   backdrop_visible = true
   backdrop_alpha = 0.5

   bg_color = {34/255,30/255,30/255}
   overPointOfPolyLineIndex = 0
   overPolyLineIndex = 0

   draggingPointOfPolyLineIndex = 0

   lastDraggedElement = {}

   quitDialog = false
end

function drawGrid()
   local w, h = love.graphics.getDimensions( )
   local size = grid.cellsize * camera.scale
   if (size < 10) then return end 
   local vlines = math.floor(w/size)
   local hlines = math.floor(h/size)
   local xOffset = (camera.x*camera.scale) % size
   local yOffset = (camera.y*camera.scale) % size

   for x =0, vlines do
      love.graphics.line(xOffset + x*size, 0,xOffset +  x*size, h)
   end
   for y =0, hlines do
      love.graphics.line( 0, yOffset + y*size, w, yOffset +  y*size)
   end
end

function drawPalette(palette, x, y)
   local w = #(palette.colors) * 64
   local h = 64
   love.graphics.setColor(1,1,1,1)
   local strw = medium:getWidth(palette.name)
   love.graphics.print(palette.name, x, y)
   love.graphics.rectangle("fill", x+strw,y, w,h )
   for i = 1, #(palette.colors) do
      local rgb = palette.colors[i].rgb
      love.graphics.setColor(rgb[1]/255,rgb[2]/255,rgb[3]/255)
      love.graphics.rectangle("fill", x+strw+(i-1)*64, y , 64, 64)
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
   love.graphics.clear(bg_color[1], bg_color[2], bg_color[3])
   love.graphics.push()
   love.graphics.scale(camera.scale, camera.scale  )
   love.graphics.translate( camera.x, camera.y )
   if  backdrop_visible then
      love.graphics.setColor(1,1,1, backdrop_alpha)
      love.graphics.draw(image, quad, 0, 0)
   end
   
   love.graphics.setColor(0,0,0)
   for i = 1, #shapes do
      local points = shapes[i].points 
      if (#points >= 2 ) then


	 
	 local scale = 1
	 local coords = {}
	 local ps = {}
	 for i=1, #points do
	    table.insert(coords, points[i].x)
	    table.insert(coords, points[i].y)
	    --table.insert(ps, Point(points[i].x, points[i].y))
	 end


	 if (shapes[i].color) then
	    local c = shapes[i].color
	    love.graphics.setColor(c[1], c[2], c[3])
	    
	    --local polys = decompose_complex_poly(coords, {})
	    -- for j = 1, #polys do
	    --    local p = polys[j]
	    --    local ps = {}
	    --    for k = 1, #p, 2 do
	    -- 	  table.insert(ps, Point(p[k], p[k+1]))
	    --    end
	    --    print(inspect(ps))
	    --    local triangles = Delaunay.triangulate(unpack(ps))
	    --    for j = 1, #triangles do
	    --    local t = triangles[j]
	    --    love.graphics.polygon('fill', {t.p1.x, t.p1.y, t.p2.x, t.p2.y, t.p3.x, t.p3.y})
	    --    end
	    -- end
	    


	    -- take a look at this
	    -- https://github.com/AlexarJING/polygon/blob/master/polygon.lua
	    -- or this
	    -- https://github.com/vrld/HC/blob/master/polygon.lua
	    
	    local polys = coords
	    --if not convex then
	    polys = decompose_complex_poly(coords, {})
	    local result = {}
	    for i=1 , #polys do
	       local p = polys[i]
	       --local convex = love.math.isConvex( p )
	       local ps = {}
	       
	       local triangles = love.math.triangulate(p)
	       for j = 1, #triangles do
	    	  local t = triangles[j]
	    	  local cx, cy = getCentroid(t)
	    	  if isPointInPath(cx,cy, p) then
	    	     table.insert(result, t)
	    	  end
	       end
	    end
	    for j = 1, #result do
	       love.graphics.polygon('fill', result[j])
	    end
	    
	 end
	 love.graphics.setColor(0,0,0,1)
	 
	 love.graphics.setLineStyle('rough')
	 love.graphics.setLineJoin('bevel')
	 love.graphics.setLineWidth(3)
	 --love.graphics.line(coords)
	 local vertices, indices, draw_mode = polyline(
	    love.graphics.getLineJoin(),
	    coords, love.graphics.getLineWidth() / 2,
	    1/scale,
	    love.graphics.getLineStyle() == 'smooth')

	 mesh = love.graphics.newMesh(#coords * 2)
	 mesh:setVertices(vertices)
	 mesh:setDrawMode(draw_mode)
	 mesh:setVertexMap(indices)
	 if indices then
	    mesh:setDrawRange(1, #indices)
	 else
	    mesh:setDrawRange(1, #vertices)
	 end
	 love.graphics.draw(mesh)
	 love.graphics.setLineWidth(1)
	 
      end
   end
   
   love.graphics.setColor(1,1,1,1)

   if editingMode == 'polyline' then
      local points = shapes[current_shape_index].points 
      love.graphics.setLineWidth(2.0  / camera.scale )
      overPointOfPolyLineIndex = 0
      for i=1, #points do
	 local dot_x = points[i].x - 5/camera.scale
	 local dot_y = points[i].y - 5/camera.scale
	 local dot_size = 10 / camera.scale
	 local kind = "line"
	 if (editingModeSub == 'polyline-remove' or editingModeSub == 'polyline-edit') then
	    if (pointInRect(wx,wy, dot_x, dot_y, dot_size, dot_size)) then
	       kind= "fill"
	       overPolyLineIndex = i
	    end
	 end
	 if (editingModeSub == 'polyline-add') then
	    if i == 1  and #points > 1 and (pointInRect(wx,wy, dot_x, dot_y, dot_size, dot_size)) then
	       kind= "fill"
	       overPolyLineIndex = 1
	    end
	 end
	 
	 love.graphics.rectangle(kind, dot_x, dot_y, dot_size, dot_size)
      end
      love.graphics.setLineWidth(1)
   end
   
   love.graphics.pop()
   love.graphics.setColor(1,1,1, 0.1)
   
   drawGrid()
   love.graphics.push()
   local s = 0.5
   local buttons = {
      'move', 'polyline', 'polygon', 'pen', 'pencil', 'palette', 'backdrop'
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
	    editingMode = 'nil'
	 else
	    editingMode = buttons[i]
	 end
	 
	 if (buttons[i] == 'polyline') then
	    editingModeSub = 'polyline-add'
	 end
      end
   end
   
   if (editingMode == 'polyline') then
      if imgbutton('polyline-add', ui.polyline_add, calcX(1, s), calcY(2, s), s).clicked then
	 editingModeSub = 'polyline-add'
      end
      if imgbutton('polyline-remove', ui.polyline_remove,  calcX(2, s), calcY(2, s), s).clicked then
	 editingModeSub = 'polyline-remove'
      end
      if imgbutton('polyline-edit', ui.polyline_edit,  calcX(3, s), calcY(2, s), s).clicked then
	 editingModeSub = 'polyline-edit'
      end
      if imgbutton('polyline-palette', ui.palette,  calcX(4, s), calcY(2, s), s).clicked then
	 editingModeSub = 'polyline-palette'
      end
      if imgbutton('polyline-next', ui.next,  calcX(5, s), calcY(2, s), s).clicked then
	 current_shape_index = current_shape_index + 1
	 if  current_shape_index > #shapes then
	    current_shape_index = 1
	 end
      end
      if imgbutton('polyline-previous', ui.previous,  calcX(6, s), calcY(2, s), s).clicked then
	 current_shape_index = current_shape_index - 1
	 if  current_shape_index < 1 then
	    current_shape_index = #shapes
	 end
      end
      if imgbutton('polyline-add-new', ui.add,  calcX(7, s), calcY(2, s), s).clicked then
	 local shape = {
	    points = {},
	    mesh = {}
	 }
	 table.insert(shapes, current_shape_index+1, shape)
	 current_shape_index = current_shape_index + 1
      end

   end
   
   if (editingMode == 'palette') then
      for i = 1, #palette.colors do
	 local rgb = palette.colors[i].rgb
	 if rgbbutton('palette#'..i, {rgb[1]/255,rgb[2]/255,rgb[3]/255}, calcX(i, s),calcY(6, s) ,s).clicked then
	    bg_color =  {rgb[1]/255,rgb[2]/255,rgb[3]/255}
	 end
      end
   end
   if (editingModeSub == 'polyline-palette') then
      for i = 1, #palette.colors do
	 local rgb = palette.colors[i].rgb
	 if rgbbutton('palette#'..i, {rgb[1]/255,rgb[2]/255,rgb[3]/255}, calcX(i, s),calcY(6, s) ,s).clicked then
	    --bg_color =  {rgb[1]/255,rgb[2]/255,rgb[3]/255}
	    shapes[current_shape_index].color =  {rgb[1]/255,rgb[2]/255,rgb[3]/255}
	 end
      end
   end
   
   if (editingMode == 'backdrop') then
      if imgbutton('backdrop_visibility', backdrop_visible and ui.visible or ui.not_visible,
		   calcX(1, s), calcY(7, s), s).clicked then
	 backdrop_visible = not backdrop_visible
      end
      local v =  h_slider("backdrop_alpha", calcX(2, s), calcY(7, s)+ 12*s, 100, backdrop_alpha, 0, 1)
      if (v.value ~= nil) then backdrop_alpha = v.value end
   end
   
   love.graphics.pop()

   if quitDialog then
      love.graphics.setColor(1,1,1, 1)
      love.graphics.scale(0.5)
      love.graphics.print("Sure you want to quit ? [ESC] ", 32, 16)
   end
end



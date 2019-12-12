inspect = require 'vendor.inspect'
require 'ui'
require 'palettes'
require 'util'
polyline = require 'polyline'
poly = require 'poly'
utf8 = require("utf8")
ProFi = require 'vendor.ProFi'

-- todo

function shapeAtIndex(index)
   if (#index == 1) then
      return shapes[index[1]]
   end
end
function nameAtIndex(index)
   return shapeAtIndex(index).name or ""
end
function pointsAtIndex(index)
   return shapeAtIndex(index).points
end
function colorAtIndex(index)  -- cant use this to set
   return shapeAtIndex(index).color
end
function indexValidShape(index)
   if (#index == 1) then
      return index[1] > 0 and not shapes[index[1]].folder 
   end
end
function canMoveShapeUp(path)
   return path[1] > 1
end
function canMoveShapeDown(path)
   return path[1] < #shapes
end
function addShapeAtPath(shape, path)
   table.insert(shapes, path[1], shape)
end
function removeShapeAtPath(path)
   return table.remove(shapes, path[1])
end
function increaseIndexPath()
   if (#indexPath == 1) then
      indexPath =  {indexPath[1] + 1}
   end
end
function decreaseIndexPath()
   if (#indexPath == 1) then
      indexPath =  {indexPath[1] - 1}
      if indexPath[1] == 0  and #shapes > 0 then indexPath[1] = 1 end
   end
end



function meshAllShapes(shapes)
   for i=1, #shapes do
      if (not shapes[i].folder) then
	 shapes[i].mesh = makeMeshFromVertices(makeTriangles(shapes[i]))
      end
   end
end
function updateMesh(index)
   if (indexValidShape(index)) then
      shapes[index[1]].mesh= makeMeshFromVertices(makeTriangles(shapes[index[1]]))
   end
end



function toWorldPos(x, y)
   return (x / camera.scale) - camera.x, (y / camera.scale) - camera.y
end

function love.mousepressed(x,y, button)
   lastDraggedElement = nil
   if editingMode == nil then
      editingMode = 'move'
   end

   local points = indexValidShape(indexPath) and pointsAtIndex(indexPath)
   if not points then return end
   
   local wx, wy = toWorldPos(x, y)
   if editingMode == 'polyline' and not mouseState.hoveredSomething   then
      local index =  getIndexOfHoveredPolyPoint(x, y, points)
      if (index > 0) then
	 if (editingModeSub == 'polyline-remove') then
	    table.remove (pointsAtIndex(indexPath), index)
	 end
	 if (editingModeSub == 'polyline-edit') then
	    lastDraggedElement = {id='polyline', index=index}
	 end
      end

      if (editingModeSub == 'polyline-insert') then
	 local closestEdgeIndex = getClosestEdgeIndex(wx, wy, points)
	 table.insert(pointsAtIndex(indexPath), closestEdgeIndex+1, {wx, wy})
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
   if lastDraggedElement == nil and editingMode == 'move' and love.mouse.isDown(1) or love.keyboard.isDown('space') then
      camera.x = camera.x + dx / camera.scale
      camera.y = camera.y + dy / camera.scale
   end
   if editingMode == 'backdrop' and  editingModeSub == 'backdrop-move' and love.mouse.isDown(1) then
      backdrop.x = backdrop.x + dx / camera.scale
      backdrop.y = backdrop.y + dy / camera.scale
   end

   if editingMode == 'polyline' and  editingModeSub == 'polyline-move' and love.mouse.isDown(1)  then
      local points = pointsAtIndex(indexPath)
      local beginIndex = 2 -- if first and last arent identical
      if points[1] == points[#points] then
      else
	 beginIndex = 1
      end

      for i = beginIndex, #points do
	 local p = pointsAtIndex(indexPath)[i]
	 pointsAtIndex(indexPath)[i][1] = p[1] + dx / camera.scale
	 pointsAtIndex(indexPath)[i][2] = p[2] + dy / camera.scale
      end
   end

   if (editingMode == 'polyline') and (editingModeSub == 'polyline-edit') then
      if (lastDraggedElement and lastDraggedElement.id == 'polyline') then
   	 local dragIndex = lastDraggedElement.index
   	 if dragIndex > 0 then
   	    local wx, wy = toWorldPos(x, y)
   	    local points = pointsAtIndex(indexPath)
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
   
   shapeName = 'untitled'
   love.window.setMode(1024+300, 768, {resizable=true, vsync=false, minwidth=400, minheight=300})
   love.keyboard.setKeyRepeat( true )
   camera = {x=0, y=0, scale=1}
   editingMode = nil
   editingModeSub = nil
   medium = love.graphics.newFont( "resources/fonts/WindsorBT-Roman.otf", 32)
   large = love.graphics.newFont( "resources/fonts/WindsorBT-Roman.otf", 48)
   
   introSound = love.audio.newSource("resources/sounds/supermarket.wav", "static")
   introSound:setVolume(0.1)
   introSound:setPitch(0.9 + 0.2*love.math.random())
   introSound:play()
   love.graphics.setFont(medium)

   simple_format = {
      {"VertexPosition", "float", 2}, -- The x,y position of each vertex.
   }
   
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
      mesh = love.graphics.newImage("resources/ui/mesh.png"),
      parent = love.graphics.newImage("resources/ui/parent.png"),
      folder = love.graphics.newImage("resources/ui/folder.png"),
      folder_open = love.graphics.newImage("resources/ui/folderopen.png"),

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

   shapes = {
      {
	 folder=true,
	 name="parent",
	 children ={
	    {
	       name="child ",
	       color = {1,1,0, 0.8},
	       points = {{10,10},{20,100},{200,200},{100,200}},
	    },
	 } 
      },
      {
	 name="Yes hi ",
   	 color = {1,0,0, 0.8},
   	 points = {{100,100},{200,100},{200,200},{100,200}},
      },
      {
   	 color = {1,1,0, 0.8},
   	 points = {{150,100},{250,100},{250,200},{150,200}},
      },
   }
   
   indexPath = {1}
   hoverPath = {}

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

   wireframe = false
   profiling = false
   simplifyValue = 0.2
   scrollviewOffset = 0
   lastDraggedElement = {}
   quitDialog = false

   meshAllShapes(shapes)
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

local step = 0 
function love.draw()
   step = step + 1
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


   love.graphics.setWireframe(wireframe )

   for i = 1, #shapes do
      local shape = shapeAtIndex({i}) --todo this might become kinda heafty here...
      if (i == hoverPath[1]) then
	 love.graphics.setWireframe(true)
	 hoverPath = {}
      else
	 love.graphics.setWireframe(wireframe)
      end
      
      
      if i ~= indexPath[1] then
	 if (shape.mesh) then
	    love.graphics.setColor(shape.color)
	    love.graphics.draw(shape.mesh,  0,0)
	 end
      end
      if i == indexPath[1] then
	 local editing = makeTriangles(shape)
	 if (editing and #editing > 0) then
	    local editingMesh = makeMeshFromVertices(editing)
	    love.graphics.setColor(shape.color)
	    love.graphics.draw(editingMesh,  0,0)
	 end
      end

   end
   love.graphics.setWireframe( false )

   if editingMode == 'polyline' and indexValidShape(indexPath)  then
      
      local points = pointsAtIndex(indexPath)
      love.graphics.setLineWidth(2.0  / camera.scale )
      love.graphics.setColor(1,1,1)
      for i=1, #points do
	 local kind = "line"
	 if (editingModeSub == 'polyline-remove' or editingModeSub == 'polyline-edit') then
	    if mouseOverPolyPoint(mx, my, points[i][1], points[i][2]) then
	       kind= "fill"
	    end
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
   if imgbutton('polyline-wireframe', ui.lines,  calcX(0, s), calcY(4, s), s).clicked then
      wireframe = not wireframe
   end
   
   
   if (editingMode == 'polyline') and indexValidShape(indexPath)  then
      if imgbutton('polyline-insert', ui.polyline_add,  calcX(1, s), calcY(2, s), s).clicked then
	 editingModeSub = 'polyline-insert'
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
      if imgbutton('polyline-rotate', ui.rotate,  calcX(5, s), calcY(2, s), s).clicked then
	 editingModeSub = 'polyline-rotate'
      end
      if imgbutton('polyline-move', ui.move,  calcX(6, s), calcY(2, s), s).clicked then
	 editingModeSub = 'polyline-move'
      end
      if imgbutton('polyline-clone', ui.add,  calcX(7, s), calcY(2, s), s).clicked then
	 local cloned = copyShape(shapeAtIndex(indexPath))
	 cloned.name = (cloned.name)..' copy'
	 increaseIndexPath()
	 addShapeAtPath(cloned, indexPath)

      end
   end


   if (editingModeSub == 'polyline-palette') then
      for i = 1, #palette.colors do
	 local rgb = palette.colors[i].rgb
	 if rgbbutton('palette#'..i, {rgb[1]/255,rgb[2]/255,rgb[3]/255}, calcX(i, s),calcY(3, s) ,s).clicked then
	    shapeAtIndex(indexPath).color =  {rgb[1]/255,rgb[2]/255,rgb[3]/255, colorAtIndex(indexPath)[4] or 1}
	 end
      end
      local v =  h_slider("polyline_alpha", calcX(1, s), calcY(4, s)+ 12*s, 100,  colorAtIndex(indexPath)[4] , 0, 1)
      if (v.value ~= nil) then
	 shapeAtIndex(indexPath).color[4] = v.value
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


   function recursivePathMaker()
      
   end
   


   
   local rightX = w - (64 + 500+ 10)/2
   local nested = 0
   for i=1, #shapes do
      if (shapes[i].folder) then
--	 print(inspect(shapes[i].children))
      end
      
      local yPos = -scrollviewOffset + calcY((i+1),s)+(i+1)*8*s
      if (yPos >=0 and yPos <= h) then
	 local b = iconlabelbutton('object-group', shapeAtIndex({i}).folder and ui.folder or ui.object_group,
			    colorAtIndex({i}),
			    indexPath[1] == i,
			    nameAtIndex({i}) or "p-"..i,
			    rightX , yPos , s)
	 if b.clicked then
	    updateMesh(indexPath)
	    indexPath = {i}
	    editingMode = 'polyline'
	    editingModeSub = 'polyline-edit'
	 end
	 if b.hover then
	    hoverPath = {i}
	 end
	 
      end
   end


   

   if iconlabelbutton('add-object', ui.add, nil, false,  'add shape',  rightX, calcY(1,s)+1*8*s, s).clicked then
      local shape = {
	 color = {0,0,0,1},
	 outline = true,
	 points = {},
      }
      updateMesh(indexPath)
      increaseIndexPath()
      addShapeAtPath(shape, indexPath)
      editingMode = 'polyline'
      editingModeSub = 'polyline-insert'
   end



   
   if (#shapes > 1) then
      if canMoveShapeUp(indexPath) and imgbutton('polyline-move-up', ui.move_up,  rightX - 50, calcY(2, s) + 16, s).clicked then
	 local taken_out = removeShapeAtPath(indexPath)
	 decreaseIndexPath()
	 addShapeAtPath(taken_out, indexPath)
      end
      if (canMoveShapeDown(indexPath)) and imgbutton('polyline-move-down', ui.move_down,  rightX - 50, calcY(3, s) + 24, s).clicked then
	 local taken_out =  removeShapeAtPath(indexPath)
	 increaseIndexPath()
	 addShapeAtPath(taken_out, indexPath)

      end
   end
   if #shapes > 0 then
      if imgbutton('delete', ui.delete,  rightX - 50, calcY(1, s) + 8, s).clicked then
	 local taken_out = removeShapeAtPath(indexPath)
	 decreaseIndexPath()
      end
      if imgbutton('badge', ui.badge, rightX - 50, calcY(4, s) + 8*4, s).clicked then
	 changeName = not changeName
	 local name = nameAtIndex(indexPath)
	 changeNameCursor = name and utf8.len(name) or 1
      end
      if (changeName) then
	 local str = nameAtIndex(indexPath) or ""
	 local substr = string.sub(str, 1, changeNameCursor)
	 
	 local cursorX = (love.graphics.getFont():getWidth(substr))
	 local cursorH = (love.graphics.getFont():getHeight(str))
	 love.graphics.setColor(1,1,1,0.5)
	 love.graphics.rectangle('fill', w-700 - 10, calcY(4, s) + 8*4 - 10, 300 + 20,  cursorH + 20 )
	 love.graphics.setColor(1,1,1)
	 love.graphics.print(nameAtIndex(indexPath) , w - 700, calcY(4, s) + 8*4)
	 love.graphics.rectangle('fill', w- 700 + cursorX, calcY(4, s) + 8*4, 2, cursorH)
      end
   end
   local v =  h_slider("simplify_value", w-150, 5, 100,  simplifyValue , 0, 10)
   if (v.value ~= nil) then
      simplifyValue= v.value
      love.graphics.print(simplifyValue, w-200, 0)
   end
   if (#shapes * 50 > h) then
      local v2 = v_slider("scrollview", rightX - 50, calcY(6, s) , 100, scrollviewOffset, 0, #shapes*50)
      if (v2.value ~= nil) then
	 scrollviewOffset= v2.value
      end
   end
   love.graphics.pop()
   triangleCount = 0
   if not quitDialog then
      love.graphics.print(tostring(love.timer.getFPS( )), 2,0)
      love.graphics.print(shapeName, 200, 2)
   end
   
   if quitDialog then
      local quitStr = "Quit? Seriously?! [ESC] "
      love.graphics.setFont(large)
      love.graphics.setColor(1,0.5,0.5, 1)
      love.graphics.print(quitStr, 116, 13)
      love.graphics.setColor(1,1,1, 1)
      love.graphics.print(quitStr, 115, 12)
      love.graphics.setFont(medium)
   end

end



function love.textinput(t)
   if (changeName) then
      local str = nameAtIndex(indexPath)
      if (changeNameCursor > #str) then
	 changeNameCursor = #str
      end

      local a,b = split(str, changeNameCursor+1)
      local r = table.concat{a, t, b}
      changeNameCursor = changeNameCursor + 1
      shapeAtIndex(indexPath).name = r
   end
end


function love.filedropped(file)
   local filename = file:getFilename()
   if ends_with(filename, '.svg') then
      local command = 'node '..'svg_to_love/index.js '..filename..' '..simplifyValue
      print(command)
      local p = io.popen(command)
      local str = p:read('*all')
      p:close()
      local obj = ('{'..str..'}')
      local tab = (loadstring("return ".. obj)())
      shapes = tab
      indexPath = {0}
      scrollviewOffset = 0
      local index = string.find(filename, "/[^/]*$")
      shapeName = filename:sub(index+1, -5) -- cutting off .svg
      editingMode = nil
      editingModeSub = nil
      meshAllShapes(shapes)
   end
   if ends_with(filename, 'polygons.txt') then
      local str = file:read('string')
      local tab = (loadstring("return ".. str)())
      shapes = tab
      indexPath = {0}
      scrollviewOffset = 0
      local index = string.find(filename, "/[^/]*$")
      shapeName = filename:sub(index+1, -14) --cutting off .polygons.txt
      editingMode = nil
      editingModeSub = nil
      meshAllShapes(shapes)
   end
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
   if (key == 'p' and not changeName) then
      if not profiling then
	 ProFi:start()
      else
	 ProFi:stop()
	 ProFi:writeReport( 'log/MyProfilingReport.txt' )
      end
      profiling = not profiling
   end
   if (key == 's' and not changeName) then
      local path = shapeName..".polygons.txt"
      local info = love.filesystem.getInfo( path )
      if (info) then
	 shapeName = shapeName..'_' 
	 path =  shapeName..".polygons.txt"
      end
      local toSave = {}
      for i=1 , #shapes do
	 table.insert(toSave, copyShape(shapeAtIndex(i)))
      end
      
      love.filesystem.write(path, inspect(toSave, {indent=""}))
      love.system.openURL("file://"..love.filesystem.getSaveDirectory())
   end
   

   if (changeName) then
      if (key == 'backspace') then
	 local str = nameAtIndex(indexPath)
	 local a,b = split(str, changeNameCursor+1)
	 shapeAtIndex(indexPath).name = table.concat{split(a,utf8.len(a)), b}
	 changeNameCursor = math.max(0, (changeNameCursor or 0)-1)
      end
      if (key == 'delete') then
	 local str = nameAtIndex(indexPath)
	 local a,b = split(str, changeNameCursor+2)

	 if (#b > 0) then
	    shapeAtIndex(indexPath).name = table.concat{split(a,utf8.len(a)), b}
	    changeNameCursor = math.min(#(nameAtIndex(indexPath)), changeNameCursor)
	 end
      end
      if (key == 'left') then
	 if (changeNameCursor > 0) then
	    changeNameCursor = changeNameCursor - 1
	 end
      end
      if (key == 'right' ) then
	 local str = nameAtIndex(indexPath)
	 if (changeNameCursor < utf8.len(str)) then
	    changeNameCursor = changeNameCursor + 1
	 end
      end
      if (key == 'return') then
	 changeName = false
      end
   end
end

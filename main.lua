inspect = require 'vendor.inspect'
require 'ui'
require 'palettes'
require 'util'
polyline = require 'polyline'
poly = require 'poly'
utf8 = require("utf8")
ProFi = require 'vendor.ProFi'

function getIndex(item)
   if (item) then
      for k,v in ipairs(item._parent.children) do
	 if v == item then return k end
      end
   end
   return -1
end

function addThingAtEnd(thing, parent)
   thing._parent = parent
   table.insert(parent.children, #parent.children + 1, thing)
end

function addShapeAtRoot(shape)
   table.insert(root.children, #root.children + 1, shape)
end

function addShapeAfter(shape, after)
   local index = getIndex(after)
   if (index > 0) then
      table.insert(after._parent.children, index+1, shape)
   end
end

function removeCurrentNode()
   if (currentNode) then
      return table.remove(currentNode._parent.children, getIndex(currentNode))
   end
end

function removeShapeAtPath(path)
   return table.remove(root.children, path[1])
end

function meshAll(root) -- this needs to be done recursive
   for i=1, #root.children do
      if (not root.children[i].folder) then
	 root.children[i].mesh = makeMeshFromVertices(makeVertices(root.children[i]))
      else
	 meshAll(root.children[i])
      end
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

   local points = currentNode and currentNode.points
   if not points then return end

   local transformedPoints = {}
   local t = currentNode._parent._globalTransform
   for i=1, #points do
      local lx, ly = t:transformPoint( points[i][1], points[i][2] )
      table.insert(transformedPoints, {lx, ly})
   end

   local wx, wy = toWorldPos(x, y)
   local globalX, globalY = t:inverseTransformPoint( wx, wy )

   if editingMode == 'polyline' and not mouseState.hoveredSomething   then
      local index =  getIndexOfHoveredPolyPoint(x, y, transformedPoints)
      if (index > 0) then
	 if (editingModeSub == 'polyline-remove') then
	    table.remove(points, index)
	 end
	 if (editingModeSub == 'polyline-edit') then
	    lastDraggedElement = {id='polyline', index=index}
	 end
      end

      if (editingModeSub == 'polyline-insert') then
	 local closestEdgeIndex = getClosestEdgeIndex(wx, wy, points)
	 table.insert(points, closestEdgeIndex+1, {globalX, globalY})
      end
   end

end

function nodeIsMyOwnOffspring(me, node)
   if (me == node) then return true end
   if (node._parent == me) then
      return true
   end
   if (node._parent.name == 'root') then
      return false
   end
   return nodeIsMyOwnOffspring(me, node._parent)
end


function love.mousereleased(x,y, button)
   if editingMode == 'move' then
      editingMode = nil
   end

   if lastDraggedElement and lastDraggedElement.id == 'connector' then
      if (currentNode and currentlyHoveredUINode and  currentlyHoveredUINode.folder) then
	 if not (nodeIsMyOwnOffspring(   currentNode, currentlyHoveredUINode)) then
	    addThingAtEnd( removeCurrentNode(), currentlyHoveredUINode)
	 end
      else
	 addThingAtEnd(removeCurrentNode(), root)
      end
   end
   lastDraggedElement = nil
end

function love.mousemoved(x,y, dx, dy)
   currentlyHoveredUINode = nil
   if currentNode == nil and lastDraggedElement == nil and editingMode == 'move' and love.mouse.isDown(1) or love.keyboard.isDown('space') then
      camera.x = camera.x + dx / camera.scale
      camera.y = camera.y + dy / camera.scale
   end
   if editingMode == 'backdrop' and  editingModeSub == 'backdrop-move' and love.mouse.isDown(1) then
      backdrop.x = backdrop.x + dx / camera.scale
      backdrop.y = backdrop.y + dy / camera.scale
   end

   if (currentNode and currentNode.transforms and love.mouse.isDown(1)) then
      --local t = currentNode.transforms.g
      --local trans = love.math.newTransform( t[1], t[2], t[3], t[4], t[5], 0,0)
      --local gx, gy = trans:inverseTransformPoint( dx, dy )
      currentNode.transforms.l[1]= currentNode.transforms.l[1] + dx/camera.scale
      currentNode.transforms.l[2]= currentNode.transforms.l[2] + dy/camera.scale



      --print(inspect(currentNode.transforms.g))
   end


   if editingMode == 'polyline' and  editingModeSub == 'polyline-move' and love.mouse.isDown(1)  then
      local points = currentNode and currentNode.points
      if (points) then
	 local beginIndex = 2 -- if first and last arent identical
	 if not (points[1] == points[#points]) then
	    beginIndex = 1
	 end
	 for i = beginIndex, #points do
	    local p = points[i]
	    p[1] = p[1] + dx / camera.scale
	    p[2] = p[2] + dy / camera.scale
	 end
      end
   end

   if (editingMode == 'polyline') and (editingModeSub == 'polyline-edit') then
      if (lastDraggedElement and lastDraggedElement.id == 'polyline') then
   	 local dragIndex = lastDraggedElement.index
   	 if dragIndex > 0 then
   	    local wx, wy = toWorldPos(x, y)
	    local points = currentNode and currentNode.points
	    local t = currentNode._parent._globalTransform
	    local globalX, globalY = t:inverseTransformPoint( wx, wy )
   	    if (dragIndex <= #points) then
   	       points[dragIndex][1] = globalX
   	       points[dragIndex][2] = globalY
   	    end
   	 end
      end
   end
end

local calcY = function(i, s)
   return (74 * i * s)
end
local calcX = function(i, s)
   return 16 + (74 * i * s)
end

function renderGraphNodes(node, level, startY)
   local w, h = love.graphics.getDimensions( )
   local rightX = w - (64 + 500+ 10)/2 + level*20
   local nested = 0
   local s = 0.4
   local runningY = 0

   for i=1, #node.children do
      runningY = runningY + 32
      local yPos = -scrollviewOffset + startY  + runningY
      local child = node.children[i]
      local icon = ui.object_group

      if (child.folder ) then
	 icon = child.open and ui.folder_open or ui.folder
      end
      local b = {}
      if (yPos >=0 and yPos <= h) then
	 b = iconlabelbutton('object-group', icon, child.color, child == currentNode, child.name or "", rightX , yPos , s)
      end
      if (child.folder and child.open) then
	 local add = renderGraphNodes(child, level + 1, runningY + startY)
	 runningY = runningY + add
      end

      if b.clicked then
	 if currentNode and not currentNode.folder then
	    currentNode.mesh= makeMeshFromVertices(makeVertices(currentNode))
	 end
	 if (child.folder) then
	    child.open = not child.open
	    editingMode = nil
	    editingModeSub = nil
	 end
	 if not child.folder then
	    editingMode = 'polyline'
	    editingModeSub = 'polyline-edit'
	 end
	 currentNode = child
      end

      if b.hover then
	 currentlyHoveredUINode = node.children[i]
      end

   end
   return runningY
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

function parentize(node)
   for i = 1, #node.children do
      node.children[i]._parent = node
      if (node.children[i].folder) then
	 parentize(node.children[i])
      end
   end
end

function love.load()

   shapeName = 'untitled'
   love.window.setMode(1024+300, 768, {resizable=true, vsync=false, minwidth=400, minheight=300})
   love.keyboard.setKeyRepeat( true )
   camera = {x=0, y=0, scale=1}
   editingMode = nil
   editingModeSub = nil
   small = love.graphics.newFont( "resources/fonts/WindsorBT-Roman.otf", 24)
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

   root = {
      folder = true,
      name = 'root',
      transforms =  {g={0,0,0,1,1,0,0},l={0,0,0,1,1,0,0}},
      children = {
	 {
	    folder=true,
	    name="PARENT",
	    transforms =  {g={0,0,0,1,1,0,0}, l={0,0,0,1,1,0,0}},
	    children ={
	       {
		  name="child1 ",
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
	 {
	    folder=true,
	    name="PARENT2",
	    transforms =  {g={0,0,0,1,1,0,0},  l={0,0,0,1,1,0,0}},
	    children ={
	       {
		  name="child2 ",
		  color = {1,1,0, 0.8},
		  points = {{10,10},{20,100},{200,200},{100,200}},
	       },
	       {
		  folder=true,
		  name="PARENT3",
		  transforms =  {g={0,0,0,1,1,0,0}, l={0,0,0,1,1,0,0}},
		  children ={
		     {
			name="child3a ",
			color = {1,1,0, 0.8},
			points = {{10,10},{20,100},{200,200},{100,200}},
		     },
		     {
			name="child3b ",
			color = {1,1,0, 0.8},
			points = {{10,10},{20,100},{200,200},{100,200}},
		     },
		     {
			name="child3c ",
			color = {1,1,0, 0.8},
			points = {{10,10},{20,100},{200,200},{100,200}},
		     },
		  }
	       },
	    }
	 },
      }
   }
   parentize(root)
   currentNode = nil
   currentlyHoveredUINode = nil

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

   meshAll(root)
end

function drawGrid()
   local size = backdrop.grid.cellsize * camera.scale
   if (size < 10) then return end

   local w, h = love.graphics.getDimensions( )
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
   mouseState.released = false

   if mouseState.down ~= mouseState.lastDown then
      if mouseState.down  then
         mouseState.click  = true
      else
	 mouseState.released = true
      end
   end
   mouseState.lastDown =  mouseState.down
end

function countNestedChildren(node, total)
   for i=1, #node.children do
      if (node.children[i].children) then
	 local r = countNestedChildren(node.children[i], 0)
	 total = total + r
      end
      total = total+1
   end
   return total
end

function renderThings(root)

   ---- these calculations are only needed when some local transforms have changed
   local tg = root.transforms.g
   local tl = root.transforms.l
   local pg = nil
   if (root._parent) then
      pg = root._parent._globalTransform
   end

   root._localTransform =  love.math.newTransform( tl[1], tl[2], tl[3], tl[4], tl[5], tl[6],tl[7])
   root._globalTransform = pg and (pg * root._localTransform) or root._localTransform
   ----

   for i = 1, #root.children do

      local shape = root.children[i]

      if shape.folder then
	 renderThings(shape)
      end
      if currentNode ~= shape then
	 if (shape.mesh) then
	    love.graphics.setColor(shape.color)
	    love.graphics.draw(shape.mesh, shape._parent._globalTransform)
	 end
      end
      if currentNode == shape then
	 local editing = makeVertices(shape)
	 if (editing and #editing > 0) then
	    local editingMesh = makeMeshFromVertices(editing)
	    love.graphics.setColor(shape.color)
	    love.graphics.draw(editingMesh,  shape._parent._globalTransform)
	 end
      end
   end
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
   renderThings(root)

   if (false and currentlyHoveredUINode) then
      local alpha = 0.5 + math.sin(step/100)
      love.graphics.setColor(alpha,1,1, alpha) -- i want this blinkiung
      local editing = makeVertices(currentlyHoveredUINode)
      if (editing and #editing > 0) then
	 local editingMesh = makeMeshFromVertices(editing)
	 love.graphics.draw(editingMesh,  0,0)
      end
   end

   love.graphics.setWireframe( false )

   if editingMode == 'polyline' and currentNode  then

      local points =  currentNode and currentNode.points or {}
      local transformedPoints = {}
      local t = currentNode._parent._globalTransform
      for i=1, #points do
	 local lx, ly = t:transformPoint( points[i][1], points[i][2] )
	 table.insert(transformedPoints, {lx, ly})
      end

      love.graphics.setLineWidth(2.0  / camera.scale )
      love.graphics.setColor(1,1,1)

      for i=1, #points do
	 local kind = "line"
	 if (editingModeSub == 'polyline-remove' or editingModeSub == 'polyline-edit') then
	    if mouseOverPolyPoint(mx, my, transformedPoints[i][1], transformedPoints[i][2]) then
	       kind= "fill"
	    end
	 end

	 if editingModeSub == 'polyline-insert' then
	    local closestEdgeIndex = getClosestEdgeIndex(wx, wy, points)
	    local nextIndex = (closestEdgeIndex == #transformedPoints and 1) or closestEdgeIndex+1
	    if i == closestEdgeIndex or i == nextIndex then
	       kind = 'fill'
	    end
	 end

	 local dot_x = transformedPoints[i][1] - 5/camera.scale
	 local dot_y =  transformedPoints[i][2] - 5/camera.scale
	 local dot_size = 10 / camera.scale
	 love.graphics.rectangle(kind, dot_x, dot_y, dot_size, dot_size)
      end

      love.graphics.setLineWidth(4/ camera.scale)
      -- if editingModeSub == 'polyline-rotate'  and #points > 0 and false then
      -- 	 local radius = 12  / camera.scale
      -- 	 local pivot = points[1]
      -- 	 local rotator = {x=pivot.x + 100, y=pivot.y}
      -- 	 love.graphics.setColor(1,1,1)

      -- 	 love.graphics.line(pivot.x, pivot.y, rotator.x, rotator.y)
      -- 	 love.graphics.setLineWidth(2/ camera.scale)
      -- 	 love.graphics.circle("fill", pivot.x, pivot.y , radius)
      -- 	 love.graphics.setColor(0,0,0)
      -- 	 love.graphics.circle("line", pivot.x, pivot.y , radius)

      -- 	 love.graphics.setColor(0,0,0)
      -- 	 love.graphics.circle("fill", rotator.x, rotator.y , radius)
      -- 	 love.graphics.setColor(1,1,1)
      -- 	 love.graphics.circle("line", rotator.x, rotator.y , radius)
      -- end

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


   if (editingMode == 'polyline') and currentNode  then
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
	 local cloned = copyShape(currentNode)
	 cloned._parent = currentNode._parent
	 cloned.name = (cloned.name)..' copy'
	 addShapeAfter(cloned, currentNode)
	 currentNode = cloned
      end
   end

   if (editingModeSub == 'polyline-palette' and currentNode and currentNode.color) then
      for i = 1, #palette.colors do
	 local rgb = palette.colors[i].rgb
	 if rgbbutton('palette#'..i, {rgb[1]/255,rgb[2]/255,rgb[3]/255}, calcX(i, s),calcY(3, s) ,s).clicked then
	    currentNode.color =  {rgb[1]/255,rgb[2]/255,rgb[3]/255, currentNode.color[4] or 1}
	 end
      end
      local v =  h_slider("polyline_alpha", calcX(1, s), calcY(4, s)+ 12*s, 100,  currentNode.color[4] , 0, 1)
      if (v.value ~= nil) then
	 currentNode.color[4] = v.value
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


   love.graphics.setFont(small)
   renderGraphNodes(root, 0, 100)
   love.graphics.setFont(medium)
   local rightX = w - (64 + 500+ 10)/2

   if iconlabelbutton('add-shape', ui.add, nil, false,  'add shape',  rightX, calcY(1,s)+1*8*s, s).clicked then
      local shape = {
	 color = {0,0,0,1},
	 outline = true,
	 points = {},
      }

      if currentNode and not currentNode.folder then
	 currentNode.mesh= makeMeshFromVertices(makeVertices(currentNode))
      end
      if (currentNode) then
	 shape._parent = currentNode and currentNode._parent
	 addShapeAfter(shape, currentNode)
      else
	 shape._parent = root
	 addShapeAtRoot(shape)
      end

      editingMode = 'polyline'
      editingModeSub = 'polyline-insert'
   end
   if iconlabelbutton('add-parent', ui.add, nil, false,  'add folder',  rightX, calcY(2,s)+1*8*s, s).clicked then
      local shape = {
	 folder=true,
	 transforms =  {g={0,0,0,1,1,0,0},
			l={0,0,0,1,1,0,0}},
	 children = {}
      }

      if currentNode and not currentNode.folder then
	 currentNode.mesh= makeMeshFromVertices(makeVertices(currentNode))
      end
      if (currentNode) then
	 shape._parent = currentNode and currentNode._parent
	 addShapeAfter(shape, currentNode)
      else
	 shape._parent = root
	 addShapeAtRoot(shape)
      end


      editingMode = 'polyline'
      editingModeSub = 'polyline-insert'
   end


   if (currentNode) then
      local index = getIndex(currentNode)
      if (currentNode and index > 1) then
	 local index = getIndex(currentNode)
	 if index > 1 and imgbutton('polyline-move-up', ui.move_up,  rightX - 50, calcY(2, s) + 16, s).clicked then
	    local taken_out = removeCurrentNode()
	    table.insert(taken_out._parent.children, index-1, taken_out)
	 end
      end

      if (index < #currentNode._parent.children) and imgbutton('polyline-move-down', ui.move_down,  rightX - 50, calcY(3, s) + 24, s).clicked then
	 local taken_out = removeCurrentNode()
	 if (taken_out) then
	    table.insert(taken_out._parent.children, index+1, taken_out)
	 end
      end
   end

   if (currentNode) then
      if imgbutton('delete', ui.delete,  rightX - 50, calcY(1, s) + 8, s).clicked then
	 local index = getIndex(currentNode)
	 local taken_out = removeCurrentNode()
	 if (index > 1) then
	    currentNode = currentNode._parent.children[index -1]
	 elseif (index == 1 and #(currentNode._parent.children) > 0 ) then
	    currentNode = currentNode._parent.children[index]
	 else
	    currentNode = nil
	 end
      end

      if imgbutton('badge', ui.badge, rightX - 50, calcY(4, s) + 8*4, s).clicked then
	 changeName = not changeName
	 local name = currentNode and currentNode.name
	 changeNameCursor = name and utf8.len(name) or 1
      end
      if imgbutton('connector', ui.parent, rightX - 50, calcY(5,s)+ 8*5, s).clicked then
	 lastDraggedElement = {id = 'connector', pos = {rightX - 50, calcY(5,s)+ 8*5} }
      end
      if (changeName) then
	 local str =  currentNode and currentNode.name  or ""
	 local substr = string.sub(str, 1, changeNameCursor)
	 local cursorX = (love.graphics.getFont():getWidth(substr))
	 local cursorH = (love.graphics.getFont():getHeight(str))
	 love.graphics.setColor(1,1,1,0.5)
	 love.graphics.rectangle('fill', w-700 - 10, calcY(4, s) + 8*4 - 10, 300 + 20,  cursorH + 20 )
	 love.graphics.setColor(1,1,1)
	 love.graphics.print(str , w - 700, calcY(4, s) + 8*4)
	 love.graphics.rectangle('fill', w- 700 + cursorX, calcY(4, s) + 8*4, 2, cursorH)
      end
   end
   local v =  h_slider("simplify_value", w-150, 5, 100,  simplifyValue , 0, 10)
   if (v.value ~= nil) then
      simplifyValue= v.value
      love.graphics.print(simplifyValue, w-200, 0)
   end
   local count = countNestedChildren(root, 0)
   if (count * 50 > h) then
      local v2 = v_slider("scrollview", w - 50, calcY(4, s) , 100, scrollviewOffset, 0, count * 50)
      if (v2.value ~= nil) then
	 scrollviewOffset = v2.value
      end
   end
   love.graphics.pop()

   if not quitDialog then
      love.graphics.print(tostring(love.timer.getFPS( )), 2,0)
      love.graphics.print(shapeName, 200, 2)
   end

   if lastDraggedElement and lastDraggedElement.id == 'connector' then
      love.graphics.line(lastDraggedElement.pos[1]+16, lastDraggedElement.pos[2]+16, mx, my)
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
      local str = currentNode and currentNode.name or ""
      if (changeNameCursor > #str) then
	 changeNameCursor = #str
      end

      local a,b = split(str, changeNameCursor+1)
      local r = table.concat{a, t, b}
      changeNameCursor = changeNameCursor + 1
      currentNode.name = r
   end
end


function love.filedropped(file)
   local filename = file:getFilename()
   if ends_with(filename, '.svg') then
      local command = 'node '..'resources/svg_to_love/index.js '..filename..' '..simplifyValue
      print(command)
      local p = io.popen(command)
      local str = p:read('*all')
      p:close()
      local obj = ('{'..str..'}')
      local tab = (loadstring("return ".. obj)())
      root.children = tab
      parentize(root)
      scrollviewOffset = 0
      local index = string.find(filename, "/[^/]*$")
      shapeName = filename:sub(index+1, -5) -- cutting off .svg
      editingMode = nil
      editingModeSub = nil
      currentNode = nil
      meshAll(root)
   end
   if ends_with(filename, 'polygons.txt') then
      local str = file:read('string')
      local tab = (loadstring("return ".. str)())
      root.children = tab
      parentize(root)
      scrollviewOffset = 0
      local index = string.find(filename, "/[^/]*$")
      shapeName = filename:sub(index+1, -14) --cutting off .polygons.txt
      editingMode = nil
      editingModeSub = nil
      currentNode = nil
      meshAll(root)
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
      for i=1 , #root.children do
	 table.insert(toSave, copyShape(root.children[i]))
      end

      love.filesystem.write(path, inspect(toSave, {indent=""}))
      love.system.openURL("file://"..love.filesystem.getSaveDirectory())
   end

   if (changeName) then
      if (key == 'backspace') then
	 local str = currentNode and currentNode.name or ""
	 local a,b = split(str, changeNameCursor+1)
	 currentNode.name = table.concat{split(a,utf8.len(a)), b}
	 changeNameCursor = math.max(0, (changeNameCursor or 0)-1)
      end
      if (key == 'delete') then
	 local str = currentNode and currentNode.name or ""
	 local a,b = split(str, changeNameCursor+2)

	 if (#b > 0) then
	    currentNode.name = table.concat{split(a,utf8.len(a)), b}
	    changeNameCursor = math.min(#currentNode.name, changeNameCursor)
	 end
      end
      if (key == 'left') then
	 if (changeNameCursor > 0) then
	    changeNameCursor = changeNameCursor - 1
	 end
      end
      if (key == 'right' ) then
	 local str =  currentNode and currentNode.name or ""
	 if (changeNameCursor < utf8.len(str)) then
	    changeNameCursor = changeNameCursor + 1
	 end
      end
      if (key == 'return') then
	 changeName = false
      end
   end
end

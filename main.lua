inspect = require 'vendor.inspect'
require 'ui'
require 'palettes'
require 'util'
polyline = require 'polyline'
poly = require 'poly'
utf8 = require("utf8")
ProFi = require 'vendor.ProFi'

function getLocalDelta(transform, dx, dy)
   local dx1, dy1 = transform:inverseTransformPoint( 0, 0 )
   local dx2, dy2 = transform:inverseTransformPoint( dx, dy )
   local dx3 = dx2 - dx1
   local dy3 = dy2 - dy1
   return dx3, dy3
end
function getGlobalDelta(transform, dx, dy)
   -- this one is only used in the wheel moved offset stuff
   local dx1, dy1 = transform:transformPoint( 0, 0 )
   local dx2, dy2 = transform:transformPoint( dx, dy )
   local dx3 = dx2 - dx1
   local dy3 = dy2 - dy1
   return dx3, dy3
end

function setCurrentNode(newNode)
   if currentNode and not currentNode.folder then
      currentNode.mesh = makeMeshFromVertices(makeVertices(currentNode))
   end
   currentNode = newNode
end

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

function love.mousepressed(x,y, button)
   lastDraggedElement = nil
   if editingMode == nil then
      editingMode = 'move'
   end

   local points = currentNode and currentNode.points
   if not points then return end

   local t = currentNode._parent._globalTransform
   local px, py = t:inverseTransformPoint( x, y )
   local scale = root.transforms.l[4]
   if editingMode == 'polyline' and not mouseState.hoveredSomething   then
      local w, h = getLocalDelta(t, 10, 10)
      w = math.max(math.abs(w), math.abs(h))

      local index =  0
      for i = 1, #points do
	 if pointInRect(px,py,
			points[i][1] - w/2, points[i][2] - w/2,
			w, w) then
	    index = i
	 end
      end

      if (index > 0) then
	 if (editingModeSub == 'polyline-remove') then
	    table.remove(points, index)
	 end
	 if (editingModeSub == 'polyline-edit') then
	    lastDraggedElement = {id='polyline', index=index}
	 end
      end

      if (editingModeSub == 'polyline-insert') then
	 local closestEdgeIndex = getClosestEdgeIndex(px, py, points)
	 table.insert(points, closestEdgeIndex+1, {px, py})
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
      root.transforms.l[1] = root.transforms.l[1] + dx
      root.transforms.l[2] = root.transforms.l[2] + dy

   end
   if editingMode == 'backdrop' and  editingModeSub == 'backdrop-move' and love.mouse.isDown(1) then
      backdrop.x = backdrop.x + dx / root.transforms.l[4]
      backdrop.y = backdrop.y + dy / root.transforms.l[4]
   end

   local isConnecting = lastDraggedElement and lastDraggedElement.id == 'connector'
   
   if (editingMode == 'folder' and editingModeSub ==  'folder-move' and mouseState.hoveredSomething == false and not isConnecting) then
      if (currentNode and currentNode.transforms and love.mouse.isDown(1)) then
	 local ddx, ddy = getLocalDelta(currentNode._parent._globalTransform, dx, dy)
	 currentNode.transforms.l[1]= currentNode.transforms.l[1] + ddx
	 currentNode.transforms.l[2]= currentNode.transforms.l[2] + ddy
      end
   end
   if (editingMode == 'folder' and editingModeSub ==  'folder-pan-pivot' and not isConnecting) then
      if (currentNode and currentNode.transforms and love.mouse.isDown(1)) then
	 local ddx, ddy = getLocalDelta(currentNode._globalTransform, dx, dy)
	 currentNode.transforms.l[6]= currentNode.transforms.l[6] - ddx
	 currentNode.transforms.l[7]= currentNode.transforms.l[7] - ddy
      end
   end

   if editingMode == 'polyline' and  editingModeSub == 'polyline-move' and love.mouse.isDown(1)  then
      local points = currentNode and currentNode.points
      local dx3, dy3 = getLocalDelta(currentNode._parent._globalTransform, dx, dy)
      if (points) then
	 local beginIndex = 2 -- if first and last arent identical
	 if not (points[1] == points[#points]) then
	    beginIndex = 1
	 end
	 for i = beginIndex, #points do
	    local p = points[i]
	    p[1] = p[1] + dx3
	    p[2] = p[2] + dy3
	 end
      end
   end

   if (editingMode == 'polyline') and (editingModeSub == 'polyline-edit') then
      if (lastDraggedElement and lastDraggedElement.id == 'polyline') then
   	 local dragIndex = lastDraggedElement.index
   	 if dragIndex > 0 then
	    local points = currentNode and currentNode.points
	    local t = currentNode._parent._globalTransform
	    local globalX, globalY = t:inverseTransformPoint( x, y )
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
      local color = child.color

      if child.mask then
	 icon = ui.mask
	 color = {0,0,0}
      end

      
      local b = {}
      if (yPos >=0 and yPos <= h) then
	 b = iconlabelbutton('object-group', icon, color, child == currentNode, child.name or "", rightX , yPos , s)
      end
      if (child.folder and child.open ) then
	 local add = renderGraphNodes(child, level + 1, runningY + startY)
	 runningY = runningY + add
      end

      if b.clicked then
	 if currentNode == child then
	    setCurrentNode(nil)
	    editingMode = nil
	    editingModeSub = nil
	    if (child.folder) then
	       child.open = false
	    end
	 else
	    if (child._parent.keyframes) then
	       child._parent.frame = getIndex(child)
	    end
	    
	    setCurrentNode(child)
	    if (child.folder) then
	       child.open = true
	       editingMode = 'folder'
	       editingModeSub = 'folder-move'
	    else
	       editingMode = 'polyline'
	       editingModeSub = 'polyline-edit'
	    end
	 end
      end

      if b.hover then
	 currentlyHoveredUINode = node.children[i]
      end

   end
   return runningY
end

function love.wheelmoved(x,y)
   local scale = root.transforms.l[4]

   local posx, posy = love.mouse.getPosition()
   local ix1, iy1 = root._globalTransform:inverseTransformPoint(posx, posy)

   root.transforms.l[4] = scale *  ((y>0) and 1.1 or 0.9)
   root.transforms.l[5] = scale *  ((y>0) and 1.1 or 0.9)

   --- ugh
   local tg = root.transforms.g
   local tl = root.transforms.l
   root._localTransform =  love.math.newTransform( tl[1], tl[2], tl[3], tl[4], tl[5], tl[6],tl[7])
   root._globalTransform = root._localTransform
   ---
   
   local ix2, iy2 = root._globalTransform:inverseTransformPoint(posx, posy)
   local dx = ix1 - ix2
   local dy = iy1 - iy2

   local dx3, dy3 = getGlobalDelta(root._globalTransform, dx, dy)
   root.transforms.l[1] = root.transforms.l[1] - dx3
   root.transforms.l[2] = root.transforms.l[2] - dy3
end

function parentize(node)
   if (node.children) then
   for i = 1, #node.children do
      node.children[i]._parent = node
      if (node.children[i].folder) then
	 parentize(node.children[i])
      end
   end
   end
end

function love.load()
   shapeName = 'untitled'
   love.keyboard.setKeyRepeat( true )
   editingMode = nil
   editingModeSub = nil
   small = love.graphics.newFont( "resources/fonts/WindsorBT-Roman.otf", 24)
   medium = love.graphics.newFont( "resources/fonts/WindsorBT-Roman.otf", 32)
   large = love.graphics.newFont( "resources/fonts/WindsorBT-Roman.otf", 48)

   introSound = love.audio.newSource("resources/sounds/supermarket.wav", "static")
   introSound:setVolume(0.1)
   introSound:setPitch(0.9 + 0.2*love.math.random())
   introSound:play()

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
      pivot = love.graphics.newImage("resources/ui/pivot.png"),
      pan = love.graphics.newImage("resources/ui/pan.png"),
      mask = love.graphics.newImage("resources/ui/mask.png"),
      clone = love.graphics.newImage("resources/ui/clone.png"),
      joystick = love.graphics.newImage("resources/ui/joystick.png"),
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
   for i = 1, #james.colors do
      table.insert(palette.colors, james.colors[i])
   end

   mouseState = {
      hoveredSomething = false,
      down = false,
      lastDown = false,
      click = false,
      offset = {x=0, y=0}
   }


   
   root2 = {
      folder = true,
      name = 'root',
      
      transforms =  {g={0,0,0,1,1,0,0},l={0,0,0,1,1,0,0}},
      children = {
   	 {
   	    folder=true,
   	    name="PARENT",
	    keyframes= 2,
	    lerpValue=0.5,
	    frame=1,
   	    transforms =  {g={0,0,0,1,1,0,0},l={0,0,0,1,1,0,0}},
   	     children = {
   	    {
   	       name="child1 ",
   	       color = {1,1,0, 0.8},
   	       points = {{0,0},{200,0},{200,200},{0,200}},
   	    },
   	    {
   	       name="child2 ",
   	       color = {1,1,0, 0.8},
   	       points = {{200,0},{200,0},{400,200},{0,200}},
   	    },
   	 }      
	     
	   
   	    
   	 },
      }
	
   }

   
   root = {
      folder = true,
      name = 'root',
      transforms =  {g={0,0,0,1,1,0,0},l={0,0,0,1,1,0,0}},
      children = {
	 {
	    folder=true,
	    keyframes= 2,
	    lerpValue=0.5,
	    frame=1,
	    name="2 poses",
	    transforms =  {g={0,0,0,1,1,0,0}, l={0,0,0,1,1,0,0}},
	    children ={
	       {
		  folder=true,
		  name="PARENT-0-0",
		  transforms =  {g={0,0,0,1,1,0,0}, l={0,0,0,1,1,0,0}},
		  children ={

		     {
			name="child1 ",
			color = {1,1,0, 0.8},
			points = {{0,0},{200,0},{200,200},{0,200}},
		     },
		     {
			name="child1 ",
			color = {1,1,0, 0.8},
			points = {{200,0},{200,0},{400,200},{0,200}},
		     },
		     {
			folder=true,
			name="PARENT-0-0",
			transforms =  {g={0,0,0,1,1,0,0}, l={100,0,0,1,1,0,0}},
			children ={

			   {
			      name="child1 ",
			      color = {1,0,1, 0.8},
			      points = {{0,0},{200,0},{200,200},{0,200}},
			   },
			   
			   {
			      name="child1 ",
			      color = {1,0,1, 0.8},
			      points = {{0,0},{200,0},{200,200},{600,200}},
			   },
			   
			}
		     },
		  }
	       },
	       {
		  folder=true,
		  name="PARENT-0-0",
		  transforms =  {g={0,0,0,1,1,0,0}, l={100,0,0,1,1,0,0}},
		  children ={

		     {
			name="child1 ",
			color = {1,0,1, 0.8},
			points = {{0,0},{200,0},{200,200},{0,200}},
		     },
		     
		     {
			name="child1 ",
			color = {1,0,1, 0.8},
			points = {{0,0},{200,0},{200,200},{600,200}},
		     },
		     {
			folder=true,
			name="PARENT-0-0",
			transforms =  {g={0,0,0,1,1,0,0}, l={100,0,0,1,1,0,0}},
			children ={

			   {
			      name="child1 ",
			      color = {1,0,1, 0.8},
			      points = {{0,0},{200,0},{200,200},{0,200}},
			   },
			   
			   {
			      name="child1 ",
			      color = {1,0,1, 0.8},
			      points = {{0,0},{200,0},{200,200},{600,200}},
			   },
			   
			}
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
   local scale = root.transforms.l[4]
   local size = backdrop.grid.cellsize * scale
   if (size < 10) then return end

   local w, h = love.graphics.getDimensions( )
   local vlines = math.floor(w/size)
   local hlines = math.floor(h/size)
   local xOffset = (root.transforms.l[1]) % size
   local yOffset = (root.transforms.l[2]) % size

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

function getPointsBBox(points)
   local tlx = 9999999999
   local tly = 9999999999
   local brx = -9999999999
   local bry = -9999999999
   for ip=1, #points do
      if points[ip][1] < tlx then tlx = points[ip][1] end
      if points[ip][1] > brx then brx = points[ip][1] end
      if points[ip][2] < tly then tly = points[ip][2] end
      if points[ip][2] > bry then bry = points[ip][2] end
   end
   return tlx, tly, brx, bry
end

function getDirectChildrenBBox(node)
   local tlx = 9999999999
   local tly = 9999999999
   local brx = -9999999999
   local bry = -9999999999

   for i=1, #node.children do
      local points = node.children[i].points
      if points then
	 for ip=1, #points do
	    if points[ip][1] < tlx then tlx = points[ip][1] end
	    if points[ip][1] > brx then brx = points[ip][1] end
	    if points[ip][2] < tly then tly = points[ip][2] end
	    if points[ip][2] > bry then bry = points[ip][2] end
	 end
      end
   end

   if ( tlx == 9999999999 and tly == 9999999999 and brx == -9999999999 and bry == -9999999999) then
      print('no direct children you pancake!')
      return 0,0,0,0
   else
      return tlx, tly, brx, bry
   end

end


function isPartOfKeyframePose(node)
   if (node.keyframes) then return true end
   if (node._parent == root) then return false end
   if (node._parent) then
      return isPartOfKeyframePose(node._parent)
   end
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

local function myStencilFunction()
   love.graphics.rectangle("fill", 225, 200, 350, 300)
end

local step = 0

function handleChild(shape)
   -- TODO i dont want to directly depend on my parents global transform that is not correct
   -- this gets in the way of lerping between nodes...
   
   if shape.mask then
      local mesh
      if currentNode ~= shape then
	 mesh = shape.mesh -- the standard way of rendering
      else
	 mesh =  makeMeshFromVertices(makeVertices(shape)) -- realtime iupdating the thingie
      end
      
      love.graphics.stencil(
	 function()
	    love.graphics.draw(mesh, shape._parent._globalTransform )
	 end, "replace", 1)
      love.graphics.setStencilTest("equal", 1)
   end
   if shape.folder then
      renderThings(shape)
   end

   if currentNode ~= shape then 
      if (shape.mesh and not shape.mask) then
	 love.graphics.setColor(shape.color)
	 love.graphics.draw(shape.mesh, shape._parent._globalTransform )
      end
   end
   if currentNode == shape then
      local editing = makeVertices(shape)
      if (editing and #editing > 0) then
	 local editingMesh = makeMeshFromVertices(editing)
	 love.graphics.setColor(shape.color)
	 love.graphics.draw(editingMesh,  shape._parent._globalTransform )
      end
   end
end
-- https://answers.unity.com/questions/1252260/lerp-color-between-4-corners.html

function lerpColor(c1, c2, t)
   return {lerp(c1[1], c2[1], t),
	   lerp(c1[2], c2[2], t),
	   lerp(c1[3], c2[3], t),
	   lerp(c1[4], c2[4], t)}
end

function lerpArray(a1, a2, t)
   local result = {}
   for i =1, #a1 do
      table.insert(result, lerp(a1[i], a2[i], t))
   end
   return result
end

function lerpPoints(p1, p2, t)
   assert(#p1 == #p2)
   local result = {}
   for i=1, #p1 do
      table.insert(result, {
		      lerp(p1[i][1], p2[i][1], t),
		      lerp(p1[i][2], p2[i][2], t)
      })
   end
   return result
end



function lerpNodes(left, right, root, t)
   if (left.folder and right.folder) then
      root.folder = true
      root.transforms = {
	 l = lerpArray(left.transforms.l, right.transforms.l, t),
	 g = lerpArray(left.transforms.g, right.transforms.g, t)
      }
      root.children = {}
      assert(#left.children == #right.children)
      for i=1, #left.children do
	 root.children[i] = {}
	 lerpNodes(left.children[i], right.children[i], root.children[i], t)
      end
      --root._parent = left._parent
   elseif (left.points and right.points) then
      if (left.mask and right.mask) then
	 root.mask = true
      end
      
      root.color = lerpColor(left.color, right.color, t)
      root.points = lerpPoints(left.points, right.points, t)
      --root._parent = left._parent
      root.mesh = makeMeshFromVertices(makeVertices(root))
   end
   
   return root
end

function createLerpedChild(ex1, ex2, t)

   local result = {}
   lerpNodes(ex1, ex2, result, t)
   result._parent = ex1._parent
   parentize(result)
   return result

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
   
   if (root.keyframes) then
      if currentNode == root then
	 local lerped = createLerpedChild(root.children[1], root.children[2], root.lerpValue)
	  
	 if lerped then handleChild(lerped) end
      else
	 handleChild(root.children[root.frame])
      end
   else
      for i = 1, #root.children do
	 local shape = root.children[i]
	 handleChild(shape)   
      end
   end
   
   love.graphics.setStencilTest()
end

function love.draw()
   step = step + 1
   local mx,my = love.mouse.getPosition()

   handleMouseClickStart()
   love.mouse.setCursor(cursors.arrow)
   local w, h = love.graphics.getDimensions( )
   love.graphics.clear(backdrop.bg_color[1], backdrop.bg_color[2], backdrop.bg_color[3])

   if  backdrop.visible then
      love.graphics.setColor(1,1,1, backdrop.alpha)
      love.graphics.draw(backdrop.image, backdrop.x, backdrop.y, 0, backdrop.scale, backdrop.scale)
   end

   love.graphics.setWireframe(wireframe )
   renderThings(root)

   if (currentlyHoveredUINode) then
      local alpha = 0.5 + math.sin(step/100)
      love.graphics.setColor(alpha,1,1, alpha) -- i want this blinkiung
      local editing = makeVertices(currentlyHoveredUINode)
      if (editing and #editing > 0) then
	 local editingMesh = makeMeshFromVertices(editing)
	 love.graphics.draw(editingMesh,  currentlyHoveredUINode._parent._globalTransform)
      end
   end

   love.graphics.setWireframe( false )

   if currentNode then
      local t = root._localTransform
      local x,y = t:transformPoint(0,0)
      love.graphics.setColor(1,1,1)
      love.graphics.line(x-5, y, x+5, y)
      love.graphics.line(x, y-5, x, y+5)
   end
  
   if currentNode and currentNode.folder then
      local t = currentNode.transforms.l
      local pivotX, pivotY = currentNode._globalTransform:transformPoint( t[6], t[7] )
      love.graphics.setColor(0,0,0)
      love.graphics.circle("line", pivotX-1, pivotY, 10)
      love.graphics.setColor(1,1,1)
      love.graphics.circle("line", pivotX, pivotY, 10)
   end

   if editingMode == 'polyline' and currentNode and currentNode.points then
      local points =  currentNode and currentNode.points or {}
      local globalX, globalY = currentNode._parent._globalTransform:inverseTransformPoint( mx, my )
      local transformedPoints = {}
      local t = currentNode._parent._globalTransform
      for i=1, #points do
	 local lx, ly = t:transformPoint( points[i][1], points[i][2] )
	 table.insert(transformedPoints, {lx, ly})
      end

      love.graphics.setLineWidth(2.0  )
      love.graphics.setColor(1,1,1)
      local w, h = getLocalDelta(t, 10, 10)
      w = math.max(math.abs(w), math.abs(h))
      for i=1, #points do
	 local kind = "line"
	 if (editingModeSub == 'polyline-remove' or editingModeSub == 'polyline-edit') then
	    local scale = root.transforms.l[4]
	    if pointInRect(globalX,globalY,  points[i][1] - w/2, points[i][2] - w/2,   w, w) then
	       kind= "fill"
	    end
	 end

	 if editingModeSub == 'polyline-insert' then
	    local closestEdgeIndex = getClosestEdgeIndex(globalX, globalY, points)
	    local nextIndex = (closestEdgeIndex == #transformedPoints and 1) or closestEdgeIndex+1

	    if i == closestEdgeIndex or i == nextIndex then
	       kind = 'fill'
	    end
	 end

	 local dot_x = transformedPoints[i][1] - 5
	 local dot_y =  transformedPoints[i][2] - 5
	 local dot_size = 10
	 love.graphics.setColor(0,0,0)
	 love.graphics.rectangle(kind, dot_x-1, dot_y, dot_size, dot_size)

	 love.graphics.setColor(1,1,1)
	 love.graphics.rectangle(kind, dot_x, dot_y, dot_size, dot_size)
      end

      love.graphics.setLineWidth(1)
   end

   love.graphics.setColor(1,1,1, 0.1)
   drawGrid()

   love.graphics.push()

   local s = 0.5
   
   if (editingMode == 'folder' and currentNode and  currentNode.transforms) then
      if imgbutton('folder-move', ui.move,  calcX(6, s), 10, s).clicked then
	 editingModeSub = 'folder-move'
      end
      
      if imgbutton('folder-pivot', ui.pivot,  calcX(7, s), 10, s).clicked then
	 editingModeSub = nil
	 if (#currentNode.children > 0) then
	    local tlx, tly, brx, bry = getDirectChildrenBBox(currentNode)
	    local mx = tlx + (brx - tlx)/2
	    local my = tly + (bry - tly)/2
	    local nx = currentNode.transforms.l[6]
	    local ny = currentNode.transforms.l[7]

	    if (nx == tlx and ny == tly) then
	       currentNode.transforms.l[6]= brx
	       currentNode.transforms.l[7]= tly
	    elseif (nx == brx and ny == tly) then
	       currentNode.transforms.l[6]= brx
	       currentNode.transforms.l[7]= bry
	    elseif (nx == brx and ny == bry) then
	       currentNode.transforms.l[6]= tlx
	       currentNode.transforms.l[7]= bry
	    elseif (nx == tlx and ty == bry) then
	       currentNode.transforms.l[6]= tlx
	       currentNode.transforms.l[7]= tly
	    elseif (nx == mx and ny == my) then
	       currentNode.transforms.l[6]= tlx
	       currentNode.transforms.l[7]= tly
	    else
	       currentNode.transforms.l[6]= mx
	       currentNode.transforms.l[7]= my
	    end
	 end
      end
      
      if imgbutton('folder-pan-pivot', ui.pan,  calcX(8, s), 10, s).clicked then
	 editingModeSub = 'folder-pan-pivot'
      end
      if imgbutton('folder-clone', ui.clone,calcX(9, s), 10, s).clicked then
	 local cloned = copyShape(currentNode)
	 cloned._parent = currentNode._parent
	 parentize(cloned)
	 cloned.name = (cloned.name)..' copy'
	 addShapeAfter(cloned, currentNode)
	 meshAll(cloned)
	 setCurrentNode(cloned)
      end

      love.graphics.setColor(1,1,1, 1)
      love.graphics.print("rotate", calcX(11, s), 0 )
      
      local v =  h_slider("folder-rotate", calcX(11, s), 20, 200,  currentNode.transforms.l[3] , -1 * math.pi, 1 * math.pi)
      if (v.value ~= nil) then
	 currentNode.transforms.l[3] = v.value
	 editingModeSub = 'folder-rotate'
	 love.graphics.print(string.format("%0.2f", v.value), calcX(11, s), 20)
      end
      love.graphics.setColor(1,1,1, 1)
      love.graphics.print("scale",  calcX(17, s), 0 )
      local v =  h_slider("folder-scale", calcX(17, s), 20, 200,  currentNode.transforms.l[4] , 0.00001, 10)
      if (v.value ~= nil) then
	 currentNode.transforms.l[4] = v.value
	 currentNode.transforms.l[5] = v.value
	 editingModeSub = 'folder-scale'
	 love.graphics.print(string.format("%0.2f", v.value), calcX(17, s), 20)
      end
   end

  
   
   if (editingMode == 'polyline') and currentNode  then
      if (not isPartOfKeyframePose(currentNode)) then
	 if imgbutton('polyline-insert', ui.polyline_add,  calcX(6, s), 10, s).clicked then
	    editingModeSub = 'polyline-insert'
	 end
	 if imgbutton('polyline-remove', ui.polyline_remove,  calcX(7, s), 10, s).clicked then
	    editingModeSub = 'polyline-remove'
	 end
      end
      if imgbutton('polyline-edit', ui.polyline_edit,  calcX(8, s), 10, s).clicked then
	 editingModeSub = 'polyline-edit'
      end
      if imgbutton('polyline-palette', ui.palette,  calcX(9, s), 10, s).clicked then
	 editingModeSub = 'polyline-palette'
      end

      if imgbutton('polyline-move', ui.move,  calcX(10, s), 10, s).clicked then
	 editingModeSub = 'polyline-move'
      end

      if imgbutton('polyline-clone', ui.clone,  calcX(11, s), 10, s).clicked then
	 local cloned = copyShape(currentNode)
	 cloned._parent = currentNode._parent
	 cloned.name = (cloned.name)..' copy'
	 addShapeAfter(cloned, currentNode)
	 setCurrentNode(cloned)
      end
      
      if imgbutton('polyline-recenter', ui.pivot, calcX(12,s), 10, s).clicked then
	 editingModeSub = 'polyline-recenter'
	 local tlx, tly, brx, bry = getPointsBBox(currentNode.points)
	 local w2 = (brx - tlx)/2
	 local h2 = (bry - tly)/2
	 for i=1, #currentNode.points do
	    currentNode.points[i][1] = currentNode.points[i][1] -  (tlx + w2)
	    currentNode.points[i][2] = currentNode.points[i][2] -  (tly + h2)
	 end
      end
   end

   if (editingModeSub == 'polyline-palette' and currentNode and currentNode.color) then
      local colorsInRow = 10
      for i = 1, #palette.colors do
	 local rgb = palette.colors[i].rgb
	 local x = ((i-1) % colorsInRow)*50
	 local y = math.ceil((i) / colorsInRow)*50
	 y = y + 50
	 x = x + 50
	 if rgbbutton('palette#'..i, {rgb[1]/255,rgb[2]/255,rgb[3]/255}, x,y ,s).clicked then
	    currentNode.color =  {rgb[1]/255,rgb[2]/255,rgb[3]/255, currentNode.color[4] or 1}
	 end
      end
      love.graphics.setColor(1,1,1, 1)
      love.graphics.print("alpha",  calcX(0, s), calcY(10, s) - 20)
      local v =  h_slider("polyline_alpha", calcX(0, s), calcY(10, s), 100,  currentNode.color[4] , 0, 1)
      if (v.value ~= nil) then
	 currentNode.color[4] = v.value
	 love.graphics.print(currentNode.color[4], calcX(0, s), calcY(10, s))
      end
   end

   if (editingMode == 'backdrop') then
      if imgbutton('polyline-wireframe', ui.lines,  calcX(0,s), 10, s).clicked then
	 wireframe = not wireframe
      end
      if imgbutton('polyline-palette', ui.palette,  calcX(7, s), 10, s).clicked then
	 editingModeSub = 'backdrop-palette'
      end
      if imgbutton('backdrop_visibility', backdrop.visible and ui.visible or ui.not_visible,  calcX(8, s), 10, s).clicked then
	 editingModeSub = nil
	 backdrop.visible = not backdrop.visible
      end

      love.graphics.setColor(1,1,1, 1)
      love.graphics.print("simplify svg",  calcX(1, s), 0 )
      local v =  h_slider("simplify_value", calcX(1, s), 20, 200,  simplifyValue , 0, 10)
      if (v.value ~= nil) then
	 simplifyValue= v.value
	 love.graphics.print(simplifyValue, calcX(1, s), 20)
      end

      if (backdrop.visible) then
	 if imgbutton('backdrop-move', ui.move, calcX(9, s), 10, s).clicked then
	    if (editingModeSub == 'backdrop-move') then
	       editingModeSub = nil
	    else
	       editingModeSub = 'backdrop-move'
	    end
	 end
	 
	 love.graphics.setColor(1,1,1, 1)
	 love.graphics.print("alpha",  calcX(10, s), 0 )
	 local v =  h_slider("backdrop_alpha", calcX(10, s), 20, 200, backdrop.alpha, 0, 1)
	 if (v.value ~= nil) then
	    backdrop.alpha = v.value
	    editingModeSub = nil
	    love.graphics.print(string.format("%0.2f", v.value),  calcX(10, s), 20)

	 end
	 love.graphics.setColor(1,1,1, 1)
	 love.graphics.print("scale",  calcX(16, s), 0 )
	 local h =  h_slider("backdrop_scale", calcX(16, s), 20, 200, backdrop.scale, 0, 5)
	 if (h.value ~= nil) then
	    backdrop.scale = h.value
	    editingModeSub = nil
	    love.graphics.print(	  string.format("%0.2f", h.value),  calcX(16, s), 20)
	 end
      end
      
      if (editingModeSub == 'backdrop-palette') then
	 local colorsInRow = 10
	 for i = 1, #palette.colors do
	    local rgb = palette.colors[i].rgb
	    local x = ((i-1) % colorsInRow)*50
	    local y = math.ceil((i) / colorsInRow)*50

	    y = y + 50
	    x = x + 50
	    if rgbbutton('palette#'..i, {rgb[1]/255,rgb[2]/255,rgb[3]/255}, x,y ,s).clicked then
	       backdrop.bg_color =  {rgb[1]/255,rgb[2]/255,rgb[3]/255}
	       print("bg_color: ", rgb[1]/255,rgb[2]/255,rgb[3]/255)
	    end
	 end
      end
   end

   love.graphics.setFont(small)
   renderGraphNodes(root, 0, 60)
   local rightX = w - (64 + 500+ 10)/2

   if imgbutton('backdrop', ui.backdrop, rightX- 50, 10, s).clicked then
      if (editingMode == 'backdrop') then
	 editingMode = nil
      else
	 editingMode = 'backdrop'
      end
      editingModeSub = nil
   end
   
   if iconlabelbutton('add-shape', ui.add, nil, false,  'add shape',  rightX, 10, s).clicked then
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
   if iconlabelbutton('add-parent', ui.add, nil, false,  'add folder',  rightX, 50, s).clicked then
      local shape = {
	 folder = true,
	 transforms =  {g={0,0,0,1,1,0,0},l={0,0,0,1,1,0,0}},
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

   if currentNode and currentNode.keyframes then
      if (currentNode.keyframes == 2) then
	 local v = h_slider("lerp-keyframes", rightX-300, 100, 200,  currentNode.lerpValue , 0,1)
	 if v.value then
	    currentNode.lerpValue = v.value
	 end
      end
   end
   
   if (currentNode) then
      if imgbutton('delete', ui.delete,  rightX - 50, calcY(1, s) + 8, s).clicked then
	 local index = getIndex(currentNode)
	 local taken_out = removeCurrentNode()
	 if (index > 1) then
	    setCurrentNode(currentNode._parent.children[index -1])
	 elseif (index == 1 and #(currentNode._parent.children) > 0 ) then
	    setCurrentNode(currentNode._parent.children[index])
	 else
	    setCurrentNode(nil)
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
      
      if currentNode and currentNode.points then
	 if imgbutton('mask', ui.mask, rightX - 50, calcY(6,s)+ 8*6, s).clicked then
	    currentNode.mask = not currentNode.mask
	 end
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
   local count = countNestedChildren(root, 0)
   if (count * 50 > h) then
      local v2 = v_slider("scrollview", w - 50, calcY(4, s) , 100, scrollviewOffset, 0, count * 50)
      if (v2.value ~= nil) then
	 scrollviewOffset = v2.value
      end
   end
   
   love.graphics.pop()
   love.graphics.setFont(small)
   if not quitDialog then
      love.graphics.print(tostring(love.timer.getFPS( )), 2,0)
      love.graphics.print(shapeName, 64, 0)
   end

   if lastDraggedElement and lastDraggedElement.id == 'connector' then
      love.graphics.line(lastDraggedElement.pos[1]+16, lastDraggedElement.pos[2]+16, mx, my)
   end

   if quitDialog then
      local quitStr = "Quit? Seriously?! [ESC] "
      love.graphics.setFont(large)
      love.graphics.setColor(0,0,0, 1)
      love.graphics.print(quitStr, 114, 11)
      love.graphics.setColor(1,0.5,0.5, 1)
      love.graphics.print(quitStr, 116, 13)
      love.graphics.setColor(1,1,1, 1)
      love.graphics.print(quitStr, 115, 12)
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
   local tab

   if ends_with(filename, '.svg') then
      local command = 'node '..'resources/svg_to_love/index.js '..filename..' '..simplifyValue
      print(command)
      local p = io.popen(command)
      local str = p:read('*all')
      p:close()
      local obj = ('{'..str..'}')
      tab = (loadstring("return ".. obj)())
      local index = string.find(filename, "/[^/]*$")
      shapeName = filename:sub(index+1, -5) -- cutting off .svg
   end
   
   if ends_with(filename, 'polygons.txt') then
      local str = file:read('string')
      tab = (loadstring("return ".. str)())
      local index = string.find(filename, "/[^/]*$")
      shapeName = filename:sub(index+1, -14) --cutting off .polygons.txt
   end

   if tab then
      root.children = tab
      parentize(root)
      scrollviewOffset = 0
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

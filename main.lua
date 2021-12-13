inspect = require 'vendor.inspect'


console = require 'vendor.console'
require 'lib.basic-tools' -- needs to be before console (they both overwrite print)

require 'src.palettes'
require 'src.dopesheet'
require 'src.file-screen'

require 'lib.scene-graph'
require 'lib.basics'
require 'lib.editor-utils'
require 'lib.main-utils'
require 'lib.polyline'
require 'lib.poly'
require 'lib.bbox'
require 'lib.border-mesh'
require 'lib.generate-polygon'
require 'lib.toolbox'
require 'lib.ui'

utf8 = require('utf8')
ProFi = require 'vendor.ProFi'
json = require 'vendor.json'
easing = require 'vendor.easing'


function getCircumference()
   local total = 0
   for i=1, #currentNode.points-1 do
      local p = currentNode.points[i]
      local n = currentNode.points[i+1]

      local angle, distance = getAngleAndDistance(p[1],p[2],n[1],n[2])
      total = total + distance
   end
   return total
end


function getAngleAndDistance(x1,y1,x2,y2)
   local dx = x1 - x2
   local dy = y1 - y2
   local angle =  math.atan2(dy, dx)
   local distance =  math.sqrt ((dx*dx) + (dy*dy))

   return angle, distance
end

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
      remeshNode(currentNode)
   end
   currentNode = newNode
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

function rotateGroup(node, degrees)
   local tlx, tly, brx, bry = getPointsBBox(node.points)
   local w2 = (brx - tlx)/2
   local h2 = (bry - tly)/2
   local cx = tlx+w2
   local cy = tly+h2

   local s = math.sin(degrees*0.0174532925)
   local c = math.cos(degrees*0.0174532925)

   for i=1, #node.points do
      local p = {
         node.points[i][1] - cx,
         node.points[i][2] - cy,
      }
      local xnew = p[1] * c - p[2] * s
      local ynew = p[1] * s + p[2] * c
      p[1] = xnew + cx
      p[2] = ynew + cy
      node.points[i] =  {p[1], p[2]}
   end
   remeshNode(node)
end

function recenterGroup(group, dx, dy)
   for i =1, #group do
      for j = 1, #(group[i].points) do
         group[i].points[j][1] = group[i].points[j][1] + dx
         group[i].points[j][2] = group[i].points[j][2] + dy
      end
   end
end

function recenterPoints(points)
   local tlx, tly, brx, bry = getPointsBBox(points)
   local w2 = (brx - tlx)/2
   local h2 = (bry - tly)/2
   for i=1, #points do
      points[i][1] = points[i][1] -  (tlx + w2)
      points[i][2] = points[i][2] -  (tly + h2)
   end
   return points
end

function resizeGroup(node, children, scale)
   if type(children[1]) == 'number' then
      for i = 1, #children do
	 local index = children[i]
         node.points[index] = {node.points[index][1] * scale, node.points[index][2] * scale}
      end
   else
      for i = 1, #children do
         for j =1 , #children[i].points do
            children[i].points[j] = {
               children[i].points[j][1] * scale,
               children[i].points[j][2] * scale
            }
         end
         remeshNode(children[i])
      end
      remeshNode(node)
   end
end

function flipGroup(node, children, xaxis, yaxis)
   if type(children[1]) == 'number' then
      for p=1, #children do
	 local index = children[p]
	 node.points[index] =  {node.points[index][1] * xaxis, node.points[index][2] * yaxis}
      end
      remeshNode(node)
   else
      for i=1, #children do

	 if children[i].points then
	    local scaledPoints = {}
	    for p=1, #children[i].points do
	       scaledPoints[p] = {children[i].points[p][1] * (xaxis ), children[i].points[p][2] * (yaxis )}
	    end
	    children[i].points = scaledPoints
	    remeshNode(children[i])
	 end
      end
   end
end

function deleteNode(node)
   local index = getIndex(node)
   local taken_out = removeCurrentNode()
   if (index > 1) then
      setCurrentNode(node._parent.children[index -1])
   elseif (index == 1 and #(node._parent.children) > 0 ) then
      setCurrentNode(node._parent.children[index])
   else
      setCurrentNode(nil)
   end
end

function removeGroupOfThings(group)
   local root =  currentNode or root
   for i = 1, #group do
      table.remove(root.children, getIndex(group[i]))
   end
end

function addGroupAtEnd(group, parent)
   for i = 1, #group do
      local thing = group[i]
      thing._parent = parent
      table.insert(parent.children, #parent.children + 1, thing)
   end
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

function moveItemsInRectangleSelect(dx, dy)
   for i = 1, #childrenInRectangleSelect do
      local child = childrenInRectangleSelect[i]
      for j = 1, #child.points do
         child.points[j] = {child.points[j][1] + dx, child.points[j][2] + dy}
      end
      remeshNode( child)
   end
end


function movePoints(node, dx, dy)
   if node.folder then
      for i = 1, #childrenInRectangleSelect do
	 local child = childrenInRectangleSelect[i]
	 local childIndex = getIndex(child)
	 for j = 1, #node.children[childIndex].points do
	    node.children[childIndex].points[j] = {node.children[childIndex].points[j][1] + dx,
						   node.children[childIndex].points[j][2] + dy}
	 end
	 remeshNode( node.children[childIndex])
      end
   end

   if node.points then
      for i = 1, #childrenInRectangleSelect do
	 local index = childrenInRectangleSelect[i]
	 node.points[index] = {node.points[index][1] + dx, node.points[index][2] + dy}
      end
      remeshNode(node)
   end
end

local function arrayHas(tab, val)
   for index, value in ipairs(tab) do
      if value == val then
         return true
      end
   end

   return false
end

function deletePoints(node)
   local newPoints = {}
   for i = 1, #node.points do
      if not arrayHas(childrenInRectangleSelect, i) then
         table.insert(newPoints, {node.points[i][1], node.points[i][2]})
      end
   end
   node.points = newPoints
   remeshNode(node)
end


------------ editor specific code

function drawUIAroundGraphNodes(w,h)
   if currentNode then
      local panelWidth = 96
      local panelHeight = 256
      local panelX = w - 256-64
      local panelY = 96
      love.graphics.setColor(.3,.3,.35,.5)
      love.graphics.rectangle("fill", panelX, panelY, panelWidth,panelHeight)

      local runningY = 110

      if imgbutton('polyline-clone', ui.clone,w - 300 , runningY).clicked then
         if (editingMode == 'polyline') then
            local cloned = copyShape(currentNode)
            cloned._parent = currentNode._parent
            cloned.name = (cloned.name)
            addShapeAfter(cloned, currentNode)
            setCurrentNode(cloned)
         elseif  (editingMode == 'folder') then
            local cloned = copyShape(currentNode)
            cloned._parent = currentNode._parent
            parentize(cloned)
            cloned.name = (cloned.name)..' copy'
            addShapeAfter(cloned, currentNode)
            meshAll(cloned)
            setCurrentNode(cloned)
         end
      end

      if imgbutton('delete', ui.delete,  w - 256, runningY).clicked then
         deleteNode(currentNode)
      end

      runningY = runningY + 40

      if imgbutton('badge', ui.badge, w - 300, runningY).clicked then
         changeName = not changeName
         local name = currentNode and currentNode.name
         changeNameCursor = name and utf8.len(name) or 1
      end

      if imgbutton('connector', ui.parent, w - 256, runningY).clicked then
         lastDraggedElement = {id = 'connector', pos = {w - 256, runningY} }
      end

      runningY = runningY + 40

      if currentNode and currentNode.points and currentNode.type ~= 'meta' then
         if imgbutton('mask', ui.mask, w - 300, runningY).clicked then
            currentNode.mask = not currentNode.mask
	    currentNode.hole = false

         end
         if imgbutton('hole', ui.hole, w - 256, runningY).clicked then
            currentNode.hole = not currentNode.hole
	    currentNode.mask = false

         end
      end

      if currentNode and currentNode.folder and #currentNode.children >= 2 and #currentNode.children < 5 and
	 (not isPartOfKeyframePose(currentNode) or currentNode.keyframes)  then
         if (imgbutton('transition', ui.transition, w - 300, runningY)).clicked then
            if (currentNode.keyframes) then
               currentNode.keyframes = nil
               currentNode.lerpValue = nil
               currentNode.frame = nil
            else
               currentNode.keyframes = 2
               currentNode.lerpValue = 0.5
               currentNode.frame = 1
            end
         end
      end

      if currentNode and currentNode.folder and #currentNode.children >= 4 and
	 (not isPartOfKeyframePose(currentNode) or currentNode.keyframes)  then
         if (imgbutton('joystick', ui.joystick, w - 256, runningY)).clicked then
            if (currentNode.keyframes) then
               currentNode.keyframes = nil
               currentNode.lerpValue = nil
               currentNode.lerpX = nil
               currentNode.lerpY = nil
               currentNode.frame = nil
            else
               currentNode.keyframes = #currentNode.children
               currentNode.lerpX = 0.5
               currentNode.lerpY = 0.5
               currentNode.frame = 1
            end
         end
      end

      runningY = runningY + 40


      if (editingMode == 'folder') and currentNode then
         if imgbutton('transform-toggle', ui.transform,  w - 300, runningY).clicked then
            showTheParentTransforms = not showTheParentTransforms
         end
         if imgbutton('folder-pan-pivot', ui.pan,  w-256, runningY).clicked then
            if editingModeSub == 'folder-pan-pivot' then
               editingModeSub = nil
            else
               editingModeSub = 'folder-pan-pivot'
            end
            print(editingModeSub)
         end
         runningY = runningY + 40

         love.graphics.setColor(1,1,1,.5)
         function get6(node)
            local tlx, tly, brx, bry = getDirectChildrenBBox(currentNode)
            local mx = tlx + (brx - tlx)/2
            local my = tly + (bry - tly)/2
            return tlx, tly, brx, bry, mx, my
         end
         if (currentNode.children and #currentNode.children > 0) then
	    love.graphics.rectangle("fill", w-300, runningY, 20, 20)
	    if getUIRect('p1', w-300, runningY, 20,20).clicked then
	       local tlx, tly, brx, bry, mx, my = get6(currentNode)
	       currentNode.transforms.l[6]= tlx
	       currentNode.transforms.l[7]= tly
	    end

	    love.graphics.rectangle("fill", w-300+24, runningY, 20, 20)
	    if getUIRect('p2', w-300+24, runningY, 20,20).clicked then
	       local tlx, tly, brx, bry, mx, my = get6(currentNode)
	       currentNode.transforms.l[6]= mx
	       currentNode.transforms.l[7]= tly
	    end

	    love.graphics.rectangle("fill", w-300+48, runningY, 20, 20)
	    if getUIRect('p3', w-300+48, runningY, 20,20).clicked then
	       local tlx, tly, brx, bry, mx, my = get6(currentNode)
	       currentNode.transforms.l[6]= brx
	       currentNode.transforms.l[7]= tly
	    end

	    runningY = runningY + 24

	    love.graphics.rectangle("fill", w-300, runningY, 20, 20)
	    if getUIRect('p4', w-300, runningY, 20,20).clicked then
	       local tlx, tly, brx, bry, mx, my = get6(currentNode)
	       currentNode.transforms.l[6]= tlx
	       currentNode.transforms.l[7]= my
	    end

	    love.graphics.rectangle("fill", w-300+24, runningY, 20, 20)
	    if getUIRect('p5', w-300+24, runningY, 20,20).clicked then
	       local tlx, tly, brx, bry, mx, my = get6(currentNode)
	       currentNode.transforms.l[6]= mx
	       currentNode.transforms.l[7]= my
	    end

	    love.graphics.rectangle("fill", w-300+48, runningY, 20, 20)
	    if getUIRect('p6', w-300+48, runningY, 20,20).clicked then
	       local tlx, tly, brx, bry, mx, my = get6(currentNode)
	       currentNode.transforms.l[6]= brx
	       currentNode.transforms.l[7]= my
	    end

	    runningY = runningY + 24

	    love.graphics.rectangle("fill", w-300, runningY, 20, 20)
	    if getUIRect('p7', w-300, runningY, 20,20).clicked then
	       local tlx, tly, brx, bry, mx, my = get6(currentNode)
	       currentNode.transforms.l[6]= tlx
	       currentNode.transforms.l[7]= bry
	    end

	    love.graphics.rectangle("fill", w-300+24, runningY, 20, 20)
	    if getUIRect('p8', w-300+24, runningY, 20,20).clicked then
	       local tlx, tly, brx, bry, mx, my = get6(currentNode)
	       currentNode.transforms.l[6]= mx
	       currentNode.transforms.l[7]= bry
	    end

	    love.graphics.rectangle("fill", w-300+48, runningY, 20, 20)
	    if getUIRect('p9', w-300+48, runningY, 20,20).clicked then
	       local tlx, tly, brx, bry, mx, my = get6(currentNode)
	       currentNode.transforms.l[6]= brx
	       currentNode.transforms.l[7]= bry
	    end

	    runningY = runningY + 40
         end

         if imgbutton('folder-move', ui.move, w-300, runningY).clicked then
            editingModeSub = 'folder-move'
         end

         if imgbutton('change-perspective', ui.change, w-256, runningY).clicked then
            editingModeSub = 'change-perspective'
            local bbox = getBBoxOfChildren(currentNode.children)
            local t = currentNode.transforms._g
            local TLX,TLY = t:transformPoint( bbox.tl.x,bbox.tl.y )
            local BRX,BRY = t:transformPoint( bbox.br.x, bbox.br.y )
            perspective ={ {TLX, TLY},{BRX, TLY},{BRX, BRY}, {TLX, BRY}}
         end

	 runningY = runningY + 40

	 if imgbutton('optimizer', ui.layer_group, w-300, runningY).clicked then
            if (currentNode.optimizedBatchMesh) then
               currentNode.optimizedBatchMesh = nil
            else
	       makeOptimizedBatchMesh(currentNode)
            end
         end

         if (currentNode.optimizedBatchMesh) then
            love.graphics.setColor(1,0,0)
            love.graphics.rectangle("line", w-300-2, runningY-2, 28,28)
            love.graphics.setColor(1,1,1)
            love.graphics.print(#currentNode.optimizedBatchMesh, w-300, runningY)
         end
      end

      if (editingMode == 'polyline') and currentNode  then
         if imgbutton('polyline-move', ui.move,  w - 256, runningY).clicked then
            editingModeSub = 'polyline-move'
         end

      end

      if (editingMode == 'polyline') and currentNode and currentNode.type ~= 'meta'  then
         if imgbutton('polyline-palette', ui.palette,  w - 300, runningY).clicked then
            if editingModeSub == 'polyline-palette' then
               editingModeSub = 'polyline-edit'
            else
               editingModeSub = 'polyline-palette'
            end
         end


         runningY = runningY + 40  -- behind an if !!
         if imgbutton('polyline-recenter', ui.pivot, w - 300, runningY).clicked then
            editingModeSub = 'polyline-recenter'
            print('this the one?')
            local tlx, tly, brx, bry = getPointsBBox(currentNode.points)
            local w2 = (brx - tlx)/2
            local h2 = (bry - tly)/2
            for i=1, #currentNode.points do
               currentNode.points[i][1] = currentNode.points[i][1] -  (tlx + w2)
               currentNode.points[i][2] = currentNode.points[i][2] -  (tly + h2)
            end
         end

         if currentNode and currentNode.points then
            if imgbutton('rectangle-point-select', ui.select, w - 256, runningY).clicked then
	       if #childrenInRectangleSelect > 0 then
		  editingModeSub = 0
		  childrenInRectangleSelect = {}
	       else
		  editingModeSub = 'rectangle-point-select'
	       end
            end
	    if #childrenInRectangleSelect > 0 then
	       love.graphics.print(#childrenInRectangleSelect, w - 256, runningY)
	    end
         end

         runningY = runningY + 40  -- behind an if !!
         if currentNode and currentNode.points then
            if imgbutton('border', ui.polygon, w - 300, runningY).clicked  then
               currentNode.border = not currentNode.border
               if currentNode.border then
                  if currentNode.borderThickness == nil then
                     currentNode.borderThickness = 1
                  end
                  if currentNode.borderSpacing == nil then
                     currentNode.borderSpacing = 10
                  end
                  if currentNode.borderTension == nil then
                     currentNode.borderTension = 0
                  end
                  if currentNode.borderRandomizerMultiplier == nil then
                     currentNode.borderRandomizerMultiplier = 0
                  end
               end
            end

            if imgbutton('rotate', ui.rotate, w - 256, runningY).clicked then
               rotateGroup(currentNode, 22.5)
            end

            if currentNode and currentNode.border then
               local v =  h_slider("splinetension", 600, 120, 200,  currentNode.borderTension , 0.00001, 1)
               if v.value ~= nil then
                  currentNode.borderTension = v.value
               end
               local v =  h_slider("splineSpacing", 600, 160, 200,  currentNode.borderSpacing , 2, 50)
               if v.value ~= nil then
                  currentNode.borderSpacing = v.value
               end
               local v =  h_slider("splineLinethick", 600, 200, 200,  currentNode.borderThickness , .1, 10)
               if v.value ~= nil then
                  currentNode.borderThickness = v.value
               end

               local v =  h_slider("splinerndmul", 600, 240, 200,  currentNode.borderRandomizerMultiplier , 0, 10)
               if v.value ~= nil then
                  currentNode.borderRandomizerMultiplier = v.value
               end
            end

            runningY = runningY + 40  -- behind an if !!
         end

         if #childrenInRectangleSelect > 0 then

            if imgbutton('children-flip-vertical', ui.flip_vertical, w - 300, runningY).clicked  then
               flipGroup(currentNode, childrenInRectangleSelect, 1,-1)
            end

            if imgbutton('children-fliph-horizontal', ui.flip_horizontal, w - 256, runningY).clicked  then
               flipGroup(currentNode, childrenInRectangleSelect, -1,1)
            end

            runningY = runningY + 40  -- behind an if !!

            if imgbutton('children-scale', ui.resize, w - 300, runningY).clicked  then
               if love.keyboard.isDown('a') then
                  resizeGroup(currentNode, childrenInRectangleSelect, .75)
               else
                  resizeGroup(currentNode, childrenInRectangleSelect, 0.95)
               end
            end

            if imgbutton('children-scale', ui.resize, w - 256, runningY).clicked  then
               if love.keyboard.isDown('a') then
                  resizeGroup(currentNode, childrenInRectangleSelect, 1.25)
               else
                  resizeGroup(currentNode, childrenInRectangleSelect, 1.05)
               end
            end

            runningY = runningY + 40  -- behind an if !!
         end

         if (editingMode == 'polyline') and currentNode  then

            if imgbutton('polyline-edit', ui.polyline_edit,  w - 320, runningY).clicked then
               editingModeSub = 'polyline-edit'
            end

            if (not isPartOfKeyframePose(currentNode)) then
               if imgbutton('polyline-insert', ui.polyline_add,  w - 280, runningY).clicked then
                  editingModeSub = 'polyline-insert'
               end
               if imgbutton('polyline-remove', ui.polyline_remove,  w - 240, runningY).clicked then
                  editingModeSub = 'polyline-remove'
               end
            end
         end
      end
   end
end


function love.mousepressed(x,y, button)
   lastDraggedElement = nil

   if editingMode == nil then
      editingMode = 'move'
   end

   if ( love.keyboard.isDown( 'lctrl' )) then
      local d = findMeshThatsHit(root, x, y, love.keyboard.isDown( 'lctrl' ) )
      if d then
         setCurrentNode(d)
         tryToCenterUI(d)
         editingMode = 'polyline'
      else
         setCurrentNode(nil)
         editingMode = nil
         editingModeSub = nil
      end
   end

   if editingMode == 'rectangle-select' or editingModeSub == 'rectangle-point-select'  then
      rectangleSelect.startP = {x=x, y=y}
   end

   if currentNode then
      local points = currentNode and currentNode.points
      --local t = currentNode._parent.transforms._g
      local t = currentNode._parent.transforms._g

      local px, py = t:inverseTransformPoint( x, y )
      local scale = root.transforms.l[4]

      if editingModeSub == 'change-perspective' and currentNode then
	 function simplecheck(x2,y2, width)
	    if pointInRect(x,y, x2, y2, width,width) then
	       return true
	    end
	    return false
	 end
	 for i = 1, 4 do
	    if simplecheck(perspective[i][1] - 5,perspective[i][2] - 5, 10) then
	       print(i, 'set')
	       lastDraggedElement = {id='perspective-corner', index=i}
	    end
	 end
      end

      if points then
	 if editingMode == 'polyline' and not mouseState.hoveredSomething   then
	    local w, h = getLocalDelta(t, 10, 10)
	    w = math.max(math.abs(w), math.abs(h))

	    local index =  0
	    for i = 1, #points do
	       if pointInRect(px,py,
			      points[i][1] - w/2,
			      points[i][2] - w/2,
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
   end
end


function love.mousereleased(x,y, button)
   if editingMode == 'move' then
      editingMode = nil
   end

   if editingModeSub == 'rectangle-point-select' then
      if  (rectangleSelect.startP and rectangleSelect.endP) then
         childrenInRect = {}
         local parent = currentNode._parent or root
         local t = not  currentNode._parent and  parent.transforms._l or parent.transforms._g
         local sx, sy = t:inverseTransformPoint( rectangleSelect.startP.x, rectangleSelect.startP.y )
         local ex, ey = t:inverseTransformPoint( rectangleSelect.endP.x, rectangleSelect.endP.y )
         local tl = {x=math.min(sx, ex), y=math.min(sy, ey)}
         local br = {x=math.max(sx, ex), y=math.max(sy, ey)}
         local childrenInRect = {}
         for i=1, #currentNode.points do
            local p = currentNode.points[i]
            if p[1] >= tl.x and p[1] <= br.x  and  p[2] >= tl.y and p[2] <= br.y then
               table.insert(childrenInRect, i)
            end
         end
         childrenInRectangleSelect = childrenInRect
         rectangleSelect = {}
	 editingModeSub = nil
      end
   end

   if (editingMode == 'rectangle-select') then
      if (rectangleSelect.startP and rectangleSelect.endP) then
         local root = currentNode or root
         local t = not currentNode and  root.transforms and (root.transforms._l or root.transforms._g)
         if t then
            local sx, sy = t:inverseTransformPoint( rectangleSelect.startP.x, rectangleSelect.startP.y )
            local ex, ey = t:inverseTransformPoint( rectangleSelect.endP.x, rectangleSelect.endP.y )
            local tl = {x=math.min(sx, ex), y=math.min(sy, ey)}
            local br = {x=math.max(sx, ex), y=math.max(sy, ey)}
            local childrenInRect = {}
            for i=1, #root.children do
               local child = root.children[i]
               if (child.points) then
                  local failed = false
                  for pi = 1, #child.points do
                     local p = child.points[pi]
                     if p[1] < tl.x or p[1] > br.x then failed = true end
                     if p[2] < tl.y or p[2] > br.y then failed = true end
                  end

                  if not failed then
                     table.insert(childrenInRect, child)
                  end
               end
            end

            if #childrenInRect > 0 then
               childrenInRectangleSelect = childrenInRect
            else
               childrenInRectangleSelect = {}
            end
         end
         editingMode = nil
      end

      rectangleSelect = {}
   end

   if lastDraggedElement and lastDraggedElement.id == 'connector' then
      if (currentNode and currentlyHoveredUINode and  currentlyHoveredUINode.folder) then
         if not (nodeIsMyOwnOffspring(currentNode, currentlyHoveredUINode)) then
            addThingAtEnd( removeCurrentNode(), currentlyHoveredUINode)
         end
      else
         addThingAtEnd(removeCurrentNode(), root)
      end
   end

   if lastDraggedElement and lastDraggedElement.id == 'connector-group' then
      if not currentlyHoveredUINode then
         currentlyHoveredUINode = root
      end

      if (currentlyHoveredUINode and  currentlyHoveredUINode.folder) then
         removeGroupOfThings(childrenInRectangleSelect)
         local tlx,tly,brx,bry = getGroupBBox(childrenInRectangleSelect)
         local w2 = (brx - tlx)/2
         local h2 = (bry - tly)/2
         local offX = -  (tlx + w2)
         local offY = -  (tly + h2)

         recenterGroup(childrenInRectangleSelect, offX, offY)

         addGroupAtEnd(childrenInRectangleSelect, currentlyHoveredUINode)
         meshAll(currentlyHoveredUINode)
         childrenInRectangleSelect = {}
         scrollviewOffset = 0
      end

   end
   lastDraggedElement = nil
end


function love.mousemoved(x,y, dx, dy)
   currentlyHoveredUINode = nil
   local snap = false
   if  love.keyboard.isDown( 'r' ) then
      snap = true
   end

   if currentNode == nil and lastDraggedElement == nil and editingMode == 'move' and editingModeSub ~= 'group-move' and love.mouse.isDown(1) or love.keyboard.isDown('space') then

      love.mouse.setCursor(handCursor)
      root.transforms.l[1] = root.transforms.l[1] + dx
      root.transforms.l[2] = root.transforms.l[2] + dy
   else
      love.mouse.setCursor()
   end

   if editingMode == 'backdrop' and  editingModeSub == 'backdrop-move' and love.mouse.isDown(1) then
      backdrop.x = backdrop.x + dx / root.transforms.l[4]
      backdrop.y = backdrop.y + dy / root.transforms.l[4]
   end

   if editingModeSub == 'group-move' and love.mouse.isDown(1) then
      moveItemsInRectangleSelect(dx/ root.transforms.l[4], dy/ root.transforms.l[4])
   end


   local isConnecting = lastDraggedElement and lastDraggedElement.id == 'connector'

   if editingMode == 'rectangle-select' and rectangleSelect.startP then
      rectangleSelect.endP = {x=x, y=y}
   end
   if editingModeSub == 'rectangle-point-select' and rectangleSelect.startP then
      rectangleSelect.endP = {x=x, y=y}
   end

   if (editingMode == 'folder' and editingModeSub ==  'folder-move' and mouseState.hoveredSomething == false and not isConnecting) then
      if (currentNode and currentNode.transforms and love.mouse.isDown(1)) then
         local ddx, ddy = getLocalDelta(currentNode._parent.transforms._g, dx, dy)
         if snap then
            ddx = round2(ddx, 0)
            ddy = round2(ddy, 0)
         end
         currentNode.transforms.l[1]= currentNode.transforms.l[1] + ddx
         currentNode.transforms.l[2]= currentNode.transforms.l[2] + ddy
      end
   end

   if (editingMode == 'folder' and editingModeSub ==  'folder-pan-pivot' and not isConnecting) then
      if (currentNode and currentNode.transforms and love.mouse.isDown(1)) then
         local ddx, ddy = getLocalDelta(currentNode.transforms._g, dx, dy)
         if snap then
            ddx = round2(ddx, 0)
            ddy = round2(ddy, 0)
         end
         currentNode.transforms.l[6]= currentNode.transforms.l[6] - ddx
         currentNode.transforms.l[7]= currentNode.transforms.l[7] - ddy

      end
   end

   if editingMode == 'polyline' and  editingModeSub == 'polyline-move' and love.mouse.isDown(1)  then
      local points = currentNode and currentNode.points
      local dx3, dy3 = getLocalDelta(currentNode._parent.transforms._g, dx, dy)
      if snap then
         dx3 = round2(dx3, 0)
         dy3 = round2(dy3, 0)
      end

      if (points) then
         local beginIndex = 2 -- if first and last arent identical
         if not (points[1] == points[#points]) then
            beginIndex = 1
         end
         -- this one is to move single points, usefull for metadata
         -- the meshing will break on this
         if (points[1] == points[#points] and #points==1) then
            beginIndex = 1
         end

         for i = beginIndex, #points do
            local p = points[i]
            p[1] = p[1] + dx3
            p[2] = p[2] + dy3
         end
      end
   end

   if editingModeSub == 'change-perspective' then
      if lastDraggedElement then
         local index = lastDraggedElement.index
         if  snap then
            perspective[index][1] = round2(x,0)
            perspective[index][2] = round2(y,0)
         else
            if perspective[index] then
               perspective[index][1] = x
               perspective[index][2] = y
            end
         end
      end
   end

   if (editingMode == 'polyline') and (editingModeSub == 'polyline-edit') then
      if (lastDraggedElement and lastDraggedElement.id == 'polyline') then
         local dragIndex = lastDraggedElement.index
         if dragIndex > 0 then
            local points = currentNode and currentNode.points
            local t = currentNode._parent.transforms._g
            local globalX, globalY = t:inverseTransformPoint( x, y )

            if (dragIndex <= #points) then
               if  snap then
                  points[dragIndex][1] = round2(globalX,0)
                  points[dragIndex][2] = round2(globalY,0)
               else
                  points[dragIndex][1] = globalX
                  points[dragIndex][2] = globalY
               end
            end
         end
      end
   end
end

function calcY(i)
   return (16 + (24 + 8 + 4) * i)
end
function calcX(i)
   return ((24 + 8 + 4) * i)
end

function recursiveCloseAll(node)
   if node.folder then
      node.open = false
   end

   if node.children then
      for i =1, #node.children do
         recursiveCloseAll(node.children[i])
      end
   end
end

function recursiveOpenSome(node, toOpen)
   if node.folder then
      for j=#toOpen, 1, -1 do
         if toOpen[j] == node then
            node.open = true
            table.remove(toOpen, j)
         end
      end
   end

   if node.children then
      for i = 1, #node.children do
         recursiveOpenSome(node.children[i], toOpen)
      end
   end
end

function recursiveGetRunningYForNode(node, lookFor, runningY)
   -- this one assumes the nodes are already opened up correctly
   local rowHeight = 27 - 4
   for i = 1,#node.children do
      local child = node.children[i]
      if child == lookFor then
         return runningY
      else
         runningY = runningY + rowHeight
         if child.folder and child.open then
            return recursiveGetRunningYForNode(node.children[i], lookFor, runningY)
         end
      end
   end

   return runningY
end

function tryToCenterUI(node2)
   recursiveCloseAll(root)
   local reversePath = {}
   local node = node2
   while node ~= root do
      table.insert(reversePath,node._parent)
      node = node._parent
   end
   recursiveOpenSome(root, reversePath)
   local ry = recursiveGetRunningYForNode(root, node2, 0)
   local w, h = love.graphics.getDimensions( )
   if ry > h then
      scrollviewOffset = ry
   else
      scrollviewOffset = 30
   end
end

local startTime = love.timer.getTime()

function getNodeYPosition(node, lookFor)
   return recursiveGetRunningYForNode(node, lookFor, 0)
end

function renderGraphNodes(node, level, startY)
   local w, h = love.graphics.getDimensions( )
   local beginRightX = w - 210 + level*6
   local rightX = beginRightX
   local nested = 0
   local runningY = 0
   local rowHeight = 27 - 5

   for i=1, #node.children do

      local yPos = -scrollviewOffset + startY  + runningY
      local child = node.children[i]
      local icon = ui.object_group

      if (child.folder ) then
         icon = child.open and ui.folder_open or ui.folder
      end
      if (child.line) then
         icon = ui.polyline
      end
      if (child.type and child.type == 'meta') then
         icon = ui.move
      end

      local color = child.color

      if child.mask then
         icon = ui.mask
         color = {0,0,0}
      end
      if child.hole then
         icon = ui.hole
         color = {0,0,0}
      end

      local b = {}
      if (yPos >=0 and yPos <= h) then
         b = iconlabelbutton('object-group'..i, icon, color, child == currentNode, child.name or "", rightX , yPos, 128+32, -4)
      end

      if (child.folder and child.open ) then
         local add = renderGraphNodes(child, level + 1, runningY + startY + rowHeight)
         runningY = runningY + add
      end

      if b.clicked then
         local dblClicked = false
         if lastClickedGraphButton and lastClickedGraphButton.name == 'object-group'..i then
            local duration = (love.timer.getTime() - lastClickedGraphButton.time )
            if duration < .5 then
               print('dblclick', child.name)
               dblClicked = true
               changeName=true
               changeNameCursor= child.name and #child.name or 0
               lastClickedGraphButton = nil
            end
         end

         if not dblClicked then
            changeName=false
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
            lastClickedGraphButton = {name='object-group'..i, time=love.timer.getTime(), x= rightX , y=yPos, childName=child.name}
         end
      end

      if b.hover then
         currentlyHoveredUINode = node.children[i]
      end
      runningY = runningY + rowHeight
   end
   return runningY
end

function love.wheelmoved(x,y)
   local posx, posy = love.mouse.getPosition()
   local w, h = love.graphics.getDimensions()

   if posx > w-256 then
      scrollviewOffset = scrollviewOffset + y*24
   else
      local scale = root.transforms.l[4]
      local ix1, iy1 = root.transforms._g:inverseTransformPoint(posx, posy)
      root.transforms.l[4] = scale *  ((y>0) and 1.1 or 0.9)
      root.transforms.l[5] = scale *  ((y>0) and 1.1 or 0.9)

      local tl = root.transforms.l
      root.transforms._l =  love.math.newTransform( tl[1], tl[2], tl[3], tl[4], tl[5], tl[6],tl[7])
      root.transforms._g = root.transforms._l

      local ix2, iy2 = root.transforms._g:inverseTransformPoint(posx, posy)
      local dx = ix1 - ix2
      local dy = iy1 - iy2

      local dx3, dy3 = getGlobalDelta(root.transforms._g, dx, dy)
      root.transforms.l[1] = root.transforms.l[1] - dx3
      root.transforms.l[2] = root.transforms.l[2] - dy3
   end
end


function love.load(arg)
   --if arg[#arg] == "-debug" then require("mobdebug").start() end
   shapeName = 'untitled'
   shapePath = ''
   love.keyboard.setKeyRepeat( true )
   editingMode = nil
   editingModeSub = nil
   --local ffont = "resources/fonts/cooper-bold-bt.ttf"
   --local ffont = "resources/fonts/Turbo Pascal Font.ttf"
   --local ffont = "resources/fonts/MonacoB.otf"
   --local ffont = "resources/fonts/agave.ttf"
   local ffont = "resources/fonts/WindsorBT-Roman.otf"

   supersmallest = love.graphics.newFont(ffont , 8)
   smallest = love.graphics.newFont(ffont , 16)
   small = love.graphics.newFont(ffont, 24)
   medium = love.graphics.newFont( ffont, 32)
   large = love.graphics.newFont(ffont , 48)

   canvas = love.graphics.newCanvas()

   handCursor = love.mouse.getSystemCursor("hand")

   introSound = love.audio.newSource("resources/sounds/supermarket.wav", "static")
   introSound:setVolume(0.1)
   introSound:setPitch(0.9 + 0.2*love.math.random())
   introSound:play()

   simple_format = {
      {"VertexPosition", "float", 2}, -- The x,y position of each vertex.
   }
   simple_format_colors = {
      {"VertexPosition", "float", 2}, -- The x,y position of each vertex.
      {"VertexColor", "float", 4}, -- The x,y position of each vertex.
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
      transition = love.graphics.newImage("resources/ui/transition.png"),
      select = love.graphics.newImage("resources/ui/select.png"),
      hole = love.graphics.newImage("resources/ui/keyhole.png"),
      change = love.graphics.newImage("resources/ui/change.png"),
      add_to_list = love.graphics.newImage("resources/ui/add-to-list.png"),
      flip_vertical = love.graphics.newImage("resources/ui/flip-vertical.png"),
      flip_horizontal = love.graphics.newImage("resources/ui/flip-horizontal.png"),
      dopesheet = love.graphics.newImage("resources/ui/spreadsheet.png"),
      curve = love.graphics.newImage("resources/ui/curve.png"),
   }

   cursors = {
      hand= love.mouse.getSystemCursor("hand"),
      arrow= love.mouse.getSystemCursor("arrow")
   }

   palette = {
      name='mix-and-match',
      colors={}
   }

   local palettes = {miffy, pico, lego, fabuland, james, childCraft, gruvBox, quentinBlake, littleGreene}
   for i = 1, #palettes do
      for j = 1, #palettes[i].colors do
         table.insert(palette.colors,palettes[i].colors[j] )
      end
   end

   mouseState = {
      hoveredSomething = false,
      down = false,
      lastDown = false,
      click = false,
      offset = {x=0, y=0}
   }

   local generated = generatePolygon(0,0, 40, .05, .02 , 6)
   local points = {}
   for i = 1, #generated, 2 do
      table.insert(points, {generated[i], generated[i+1]})
   end

   root = {
      folder = true,
      name = 'root',
      transforms =  {l={0,0,0,1,1,0,0,0,0}},
      children = {

         {
            folder = true,
            transforms =  {l={0,0,0,1,1,100,0,0,0}},
            name="rood",
            children ={
               {
                  name="roodline:"..1,
                  color = {.5,1,0, 0.8},
                  points = points,
                  line=true
               },

	       {
                  name="roodchild:"..1,
                  color = {.5,.1,0, 0.8},
                  points = {{0,0},{200,0},{200,200},{0,200}},

	       },
	       {
                  name="meta thing"..1,
                  type='meta',
                  color = {1,0,0, 0.8},
                  points = {{0,0}},

               },
            },
         },
      }
   }

   parentize(root)
   currentNode = nil
   currentlyHoveredUINode = nil

   backdrop = {
      grid = {cellsize=100}, -- cellsize is in px
      bg_color = {.53, .70, .76},
      image = love.graphics.newImage("resources/backdrops/offshore-707.jpg"),
      visible = false,
      alpha = 0.5,
      x = 0,
      y = 0,
      scale = 1
   }

   fileDropPopup = nil
   showTheParentTransforms = false
   wireframe = false
   profiling = false
   simplifyValue = 0.2
   scrollviewOffset = 0
   lastDraggedElement = {}
   quitDialog = false
   rectangleSelect = {}
   childrenInRectangleSelect = {}
   meshAll(root)
   splineTension = 0
   splineSpacing = 20
   splineLineThickness = 2
   dopesheet = {}
   dopesheetEditing = false
   cellCount =  12*1
   openFileScreen = false
   gatheredData = {}
   openedAddPanel = false
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

function  makeNewFolder()
   local shape = {
      folder = true,
      transforms =  {l={0,0,0,1,1,0,0, 0,0}},
      children = {}
   }

   if currentNode and not currentNode.folder then
      remeshNode(currentNode)
   end
   if (currentNode) then
      shape._parent = currentNode and currentNode._parent
      addShapeAfter(shape, currentNode)
   else
      shape._parent = root
      addShapeAtRoot(shape)
   end
   return shape
end


local step = 0
function love.update(dt)
end


function labelPos(x,y)
   return x,y-20
end

function love.draw()
   if openFileScreen then
      renderOpenFileScreen()
   else

      if true then
	 step = step + 1
	 local mx,my = love.mouse.getPosition()

	 handleMouseClickStart()

	 local w, h = love.graphics.getDimensions( )
	 local rightX = w - (64 + 500+ 10)/2

	 love.graphics.clear(backdrop.bg_color[1], backdrop.bg_color[2], backdrop.bg_color[3])

	 if  backdrop.visible then
	    love.graphics.setColor(1,1,1, backdrop.alpha)
	    love.graphics.draw(backdrop.image, backdrop.x, backdrop.y, 0, backdrop.scale, backdrop.scale)
	 end

	 love.graphics.setWireframe(wireframe )
	 --print('need to recursivey make bbox so i can make fitting canvas')
	 renderThings(root)

	 if (currentlyHoveredUINode) then
	    local alpha = 0.5 + math.sin(step/100)
	    love.graphics.setColor(alpha,1,1, alpha) -- i want this blinkiung
	    local editing = makeVertices(currentlyHoveredUINode)
	    if (editing and #editing > 0) then
	       local editingMesh = makeMeshFromVertices(editing)
	       love.graphics.draw(editingMesh,  currentlyHoveredUINode._parent.transforms._g)
	    end
	 end

	 love.graphics.setWireframe( false )
	 drawUIAroundGraphNodes(w,h)

	 if currentNode then
	    --local t = root.transforms._l
	    local t = root.transforms._l
	    local x,y = t:transformPoint(0,0)
	    love.graphics.setColor(1,1,1)
	    love.graphics.line(x-5, y, x+5, y)
	    love.graphics.line(x, y-5, x, y+5)
	 end

	 if currentNode and currentNode.folder and  currentNode.transforms._g then
	    local t = currentNode.transforms.l
	    local pivotX, pivotY = currentNode.transforms._g:transformPoint( t[6], t[7] )
	    love.graphics.setColor(0,0,0)
	    love.graphics.circle("line", pivotX-1, pivotY, 10)
	    love.graphics.setColor(1,1,1)
	    love.graphics.circle("line", pivotX, pivotY, 10)
	 end

	 if editingModeSub == 'change-perspective' and currentNode then
	    if currentNode.children then
	       if (true) then
		  local bbox = getBBoxOfChildren(currentNode.children)
		  local t = currentNode.transforms._g
		  local TLX,TLY = t:transformPoint( bbox.tl.x,bbox.tl.y )
		  local BRX,BRY = t:transformPoint( bbox.br.x, bbox.br.y )

		  local ip1x, ip1y = t:inverseTransformPoint(perspective[1][1], perspective[1][2])
		  local ip2x, ip2y = t:inverseTransformPoint(perspective[2][1], perspective[2][2])
		  local ip3x, ip3y = t:inverseTransformPoint(perspective[3][1], perspective[3][2])
		  local ip4x, ip4y = t:inverseTransformPoint(perspective[4][1], perspective[4][2])

		  local source = {bbox.tl.x,bbox.tl.y,  bbox.br.x, bbox.br.y}
		  local dest = {{ip1x, ip1y},{ip2x, ip2y},{ip3x, ip3y},{ip4x, ip4y}}
		  --perspective ={ {TLX, TLY},{BRX, TLY},{BRX, BRY}, {TLX, BRY}}
		  for i = 1, #currentNode.children do

		     if currentNode.children[i].points then

			if (currentNode.children[i].mesh) then

			   local count = currentNode.children[i].mesh:getVertexCount()
			   local result = {}

			   for v = 1, count do
			      local x, y = currentNode.children[i].mesh:getVertex(v)
			      local r = transferPoint (x, y, source, dest)
			      table.insert(result, {r.x, r.y})
			   end

			   if currentNode.children[i].perspectiveMesh then
			      -- make a new one if data is not same length
			      if #result ~= currentNode.children[i].perspectiveMesh:getVertexCount() then
				 currentNode.children[i].perspectiveMesh = love.graphics.newMesh(simple_format, result , "triangles", "stream")
			      else
				 --print('slushing')
				 currentNode.children[i].perspectiveMesh:setVertices(result, 1, #result)
			      end
			   else
			      -- make new one cause
			      currentNode.children[i].perspectiveMesh = love.graphics.newMesh(simple_format, result , "triangles", "stream")
			   end

			   love.graphics.setColor(currentNode.children[i].color[1],
						  currentNode.children[i].color[2],
						  currentNode.children[i].color[3],0.3)
			   love.graphics.draw(currentNode.children[i].perspectiveMesh,
					      currentNode.transforms._g)

			end
		     end
		  end
	       end

	       local TLX,TLY = perspective[1][1], perspective[1][2]
	       local BRX,BRY = perspective[3][1], perspective[3][2]

	       love.graphics.setColor(1,1,1)

	       function simplehover(x,y, width)
		  if pointInRect(mx,my, x, y, width,width) then
		     love.graphics.rectangle('fill', x,y, width,width)
		  else
		     love.graphics.rectangle('line', x,y, width,width)
		  end
	       end

	       for i=1, 4 do
		  local nxt = i -1
		  if nxt < 1 then nxt = 4 end

		  love.graphics.line(
		     perspective[i][1], perspective[i][2],
		     perspective[nxt][1], perspective[nxt][2]
		  )
	       end

	       simplehover( perspective[1][1]-5, perspective[1][2]-5, 10)
	       simplehover( perspective[2][1]-5, perspective[2][2]-5, 10)
	       simplehover( perspective[3][1]-5, perspective[3][2]-5, 10)
	       simplehover( perspective[4][1]-5, perspective[4][2]-5, 10)
	    end
	 end

	 if editingMode == 'polyline' and currentNode and currentNode.points then
	    local points =  currentNode and currentNode.points or {}
	    local globalX, globalY = currentNode._parent.transforms._g:inverseTransformPoint( mx, my )
	    local transformedPoints = {}
	    local t = currentNode._parent.transforms._g
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
		     love.graphics.print(round2(points[i][1],3)..", "..round2(points[i][2],3), 8, love.graphics.getHeight()-32)

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


	 end
	 love.graphics.setLineWidth(1)
	 love.graphics.setColor(1,1,1, 1)

	 if (editingMode == 'rectangle-select' or  editingModeSub =='rectangle-point-select')  and rectangleSelect.startP and rectangleSelect.endP then
	    love.graphics.line(rectangleSelect.startP.x, rectangleSelect.startP.y, rectangleSelect.endP.x, rectangleSelect.startP.y)
	    love.graphics.line(rectangleSelect.startP.x, rectangleSelect.endP.y, rectangleSelect.endP.x, rectangleSelect.endP.y)
	    love.graphics.line(rectangleSelect.startP.x, rectangleSelect.startP.y, rectangleSelect.startP.x, rectangleSelect.endP.y)
	    love.graphics.line(rectangleSelect.endP.x, rectangleSelect.startP.y, rectangleSelect.endP.x, rectangleSelect.endP.y)

	 end

	 love.graphics.setColor(1,1,1, 0.1)
	 drawGrid()

	 love.graphics.push()

	 local s = 1

	 if (editingMode == 'folder' and currentNode and  currentNode.transforms) then

	    if (showTheParentTransforms) then
	       love.graphics.setFont(smallest)

	       love.graphics.setColor(1,1,1, 1)

	       local scrollerWidth = 314*2
	       love.graphics.print("scale x and y",  labelPos(calcX(1), calcY(2))  )
	       if (currentNode.transforms.l[4] == currentNode.transforms.l[5]) then
		  local v =  h_slider("folder-scale-xy", calcX(1), calcY(2), scrollerWidth,  currentNode.transforms.l[5] , 0.00001, 10)
		  if (v.value ~= nil) then
		     currentNode.transforms.l[4] = v.value
		     currentNode.transforms.l[5] = v.value
		     editingModeSub = 'folder-scale'
		     love.graphics.print(string.format("%0.2f", v.value), calcX(1), calcY(2))
		  end
	       end

	       love.graphics.setColor(1,1,1, 1)
	       love.graphics.print("scale x",  labelPos(calcX(1), calcY(3)) )
	       local v =  h_slider("folder-scale-x", calcX(1),  calcY(3) , scrollerWidth,  currentNode.transforms.l[4] , -2, 2)
	       if (v.value ~= nil) then
		  currentNode.transforms.l[4] = v.value
		  --currentNode.transforms.l[5] = v.value
		  editingModeSub = 'folder-scale'
		  love.graphics.print(string.format("%0.2f", v.value), calcX(1),  calcY(3))
	       end
	       love.graphics.setColor(1,1,1, 1)
	       love.graphics.print("scale y",  labelPos(calcX(1), calcY(4)) )

	       local v =  h_slider("folder-scale-y", calcX(1), calcY(4), scrollerWidth,  currentNode.transforms.l[5] , -2, 2)
	       if (v.value ~= nil) then
		  --currentNode.transforms.l[4] = v.value
		  currentNode.transforms.l[5] = v.value
		  editingModeSub = 'folder-scale'
		  love.graphics.print(string.format("%0.2f", v.value), calcX(1), calcY(4))
	       end
	       love.graphics.setColor(1,1,1, 1)
	       love.graphics.print("skew x",  labelPos(calcX(1), calcY(5)) )
	       local v = h_slider('folder_skew_x', calcX(1), calcY(5), scrollerWidth, currentNode.transforms.l[8] or 0,  -math.pi, math.pi )
	       if (v.value ~= nil) then
		  currentNode.transforms.l[8] = v.value
		  love.graphics.print(string.format("%0.2f", v.value), calcX(1), calcY(5))
	       end
	       love.graphics.setColor(1,1,1, 1)
	       love.graphics.print("skew y",  labelPos(calcX(1), calcY(6))  )
	       local v = h_slider('folder_skew_y', calcX(1), calcY(6), scrollerWidth, currentNode.transforms.l[9] or 0,    -math.pi, math.pi )
	       if (v.value ~= nil) then
		  currentNode.transforms.l[9] = v.value
		  love.graphics.print(string.format("%0.2f", v.value), calcX(1), calcY(6))
	       end

	       love.graphics.setColor(1,1,1, 1)
	       love.graphics.print("rotate", labelPos(calcX(1), calcY(7)) )
	       local v =  h_slider("folder-rotate", calcX(1),  calcY(7) , scrollerWidth,  currentNode.transforms.l[3] , -1 * math.pi, 1 * math.pi)

	       if (v.value ~= nil) then
		  currentNode.transforms.l[3] = v.value
		  editingModeSub = 'folder-rotate'
		  love.graphics.print(string.format("%0.2f", v.value), calcX(1), calcY(7))
	       end
	       --end
	    end
	    love.graphics.setFont(small)
	 end

	 if (editingModeSub == 'polyline-palette' and currentNode and currentNode.color) then
	    local colorsInRow = 16
	    local thumbSize = 20
	    for i = 1, #palette.colors do
	       local rgb = palette.colors[i].rgb

	       local x = w - 400 -((thumbSize+2)*colorsInRow) + ((i-1) % colorsInRow)* (thumbSize+4)
	       local y = math.ceil((i) / colorsInRow)* (thumbSize+4)
	       y = y + 50
	       x = x + 50

	       if (currentNode.color[1] == rgb[1]/255 and
		   currentNode.color[2] == rgb[2]/255 and
		   currentNode.color[3] == rgb[3]/255) then
		  love.graphics.setColor(1,1,1)
		  love.graphics.rectangle("fill",x-2,y-2,thumbSize+4,thumbSize+4)
	       end

	       if rgbbutton('palette#'..i, {rgb[1]/255,rgb[2]/255,rgb[3]/255}, x,y ,thumbSize).clicked then
		  currentNode.color =  {rgb[1]/255,rgb[2]/255,rgb[3]/255, currentNode.color[4] or 1}
	       end
	    end
	    love.graphics.setColor(1,1,1, 1)
	    love.graphics.print("alpha",  labelPos(calcX(0), calcY(10)) )
	    local v =  h_slider("polyline_alpha", calcX(0), calcY(10), 100,  currentNode.color[4] , 0, 1)
	    if (v.value ~= nil) then
	       currentNode.color[4] = v.value
	       love.graphics.print(currentNode.color[4], calcX(0), calcY(10))
	    end
	 end

	 if (editingMode == 'backdrop') then
	    if imgbutton('polyline-wireframe', ui.lines,  calcX(0), calcY(0)).clicked then
	       wireframe = not wireframe
	    end

	    if imgbutton('polyline-palette', ui.palette,  calcX(7), calcY(0)).clicked then
	       editingModeSub = 'backdrop-palette'
	    end
	    if imgbutton('backdrop_visibility', backdrop.visible and ui.visible or ui.not_visible,  calcX(8), calcY(0)).clicked then
	       editingModeSub = nil
	       backdrop.visible = not backdrop.visible
	    end

	    love.graphics.setColor(1,1,1, 1)
	    love.graphics.print("simplify svg",  labelPos(calcX(1), calcY(1)) )
	    local v =  h_slider("simplify_value", calcX(1), calcY(1), 200,  simplifyValue , 0, 10)
	    if (v.value ~= nil) then
	       simplifyValue= v.value
	       love.graphics.print(simplifyValue, calcX(1), 20)
	    end

	    if (backdrop.visible) then
	       if imgbutton('backdrop-move', ui.move, calcX(9), calcY(1)).clicked then
		  if (editingModeSub == 'backdrop-move') then
		     editingModeSub = nil
		  else
		     editingModeSub = 'backdrop-move'
		  end
	       end

	       love.graphics.setColor(1,1,1, 1)
	       love.graphics.print("alpha",  labelPos(calcX(10), calcY(1)) )
	       local vslider =  h_slider("backdrop_alpha", calcX(10), calcY(1), 200, backdrop.alpha, 0, 1)
	       if (vslider.value ~= nil) then
		  backdrop.alpha = vslider.value
		  editingModeSub = nil
		  love.graphics.print(string.format("%0.2f", vslider.value),  calcX(10), calcY(1))
	       end

	       love.graphics.setColor(1,1,1, 1)
	       love.graphics.print("scale",  labelPos(calcX(18), calcY(1)) )
	       local hslider =  h_slider("backdrop_scale", calcX(18), calcY(1), 200, backdrop.scale, 0, 5)
	       if (hslider.value ~= nil) then
		  backdrop.scale = hslider.value
		  editingModeSub = nil
		  love.graphics.print(string.format("%0.2f", hslider.value),  calcX(18), calcY(1))
	       end
	    end

	    if (editingModeSub == 'backdrop-palette') then
	       local colorsInRow = 20
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

	 if  editingMode ~= 'dopesheet' then
	    if currentNode  then
	       love.graphics.setColor(.1,.1,.1, 0.6)
	       love.graphics.rectangle('fill',0,h-64,w,64)
	    end

	    love.graphics.setFont(smallest)
	    local totalHeightGraphNodes = renderGraphNodes(root, 0, 16)
	    if (scrollviewOffset > totalHeightGraphNodes) then
	       scrollviewOffset = totalHeightGraphNodes
	    end

	    love.graphics.setFont(small)
	    local scrollBarH =  (h-32)
	    if totalHeightGraphNodes > scrollBarH then
	       local ding = scrollbarV('hierarchyslider', w-40, 16 , scrollBarH, totalHeightGraphNodes, scrollviewOffset)
	       if ding.value ~= nil then
		  scrollviewOffset = ding.value
	       end
	    end


	    if imgbutton('backdrop', ui.backdrop, 50, h-32).clicked then
	       if (editingMode == 'backdrop') then
		  editingMode = nil
	       else
		  editingMode = 'backdrop'
	       end
	       editingModeSub = nil
	    end

	    if true or (not currentNode or not currentNode.points) then
	       if imgbutton('rectangle-select', ui.select, rightX - 100, calcY(0)).clicked then
                  if (editingMode == 'rectangle-select') then
                     editingMode = nil
                     editingModeSub = nil
                  else
                     editingMode = 'rectangle-select'
                  end

	       end
               if #childrenInRectangleSelect > 0 then
                  love.graphics.print(#childrenInRectangleSelect, rightX - 100, calcY(0))
               end

	       if #childrenInRectangleSelect > 0 then
		  if love.keyboard.isDown("delete") then
		     local indexes = type(childrenInRectangleSelect[1]) == "number"
		     if indexes then
		     else
			for i =1, #childrenInRectangleSelect do
			   local n = childrenInRectangleSelect[i]
			   table.remove(n._parent.children, getIndex(n))
			end
		     end
		     childrenInRectangleSelect = {}
		  end

                  if imgbutton('group-move', ui.move, rightX - 50, calcY(0)).clicked then
                     if (editingModeSub == 'group-move') then
                        editingModeSub = nil
                     else
                        editingModeSub = 'group-move'
                     end

                  end



                  if true then
                     if imgbutton('group-scale-down', ui.resize, w - 300, 500).clicked  then
                        if love.keyboard.isDown('a') then
                           resizeGroup(currentNode, childrenInRectangleSelect, .75)
                        else
                           resizeGroup(currentNode, childrenInRectangleSelect, 0.95)
                        end
                     end

                     if imgbutton('group-scale-up', ui.resize, w - 256, 500).clicked  then
                        if love.keyboard.isDown('a') then
                           resizeGroup(currentNode, childrenInRectangleSelect, 1.25)
                        else
                           resizeGroup(currentNode, childrenInRectangleSelect, 1.05)
                        end
                     end

                     if imgbutton('children-flip-vertical', ui.flip_vertical, w - 300, 550).clicked  then
                        flipGroup(currentNode, childrenInRectangleSelect, 1,-1)
                     end

                     if imgbutton('children-fliph-horizontal', ui.flip_horizontal, w - 256, 550).clicked  then
                        flipGroup(currentNode, childrenInRectangleSelect, -1,1)
                     end



                  end








		  if imgbutton('connector-group', ui.parent, rightX - 150, calcY(0)).clicked then
		     lastDraggedElement = {id = 'connector-group', pos = {rightX - 150, 10} }
		  end

		  if imgbutton('object_group', ui.object_group, rightX - 200, calcY(0)).clicked   then
		     for i =1, #childrenInRectangleSelect do
			local n = childrenInRectangleSelect[i]
			table.remove(n._parent.children, getIndex(n))
		     end

		     local shape = {
			folder = true,
			transforms =  {l={0,0,0,1,1,0,0, 0,0}},
			children = {}
		     }
		     if not currentNode then
			shape._parent = root
			addShapeAtRoot(shape)
		     else
			addThingAtEnd(shape, currentNode)
		     end
		     local f = shape

		     local tlx,tly,brx,bry = getGroupBBox(childrenInRectangleSelect)

		     local w2 = (brx - tlx)/2
		     local h2 = (bry - tly)/2
		     local offX = -  (tlx + w2)
		     local offY = -  (tly + h2)

		     recenterGroup(childrenInRectangleSelect, offX, offY)
		     f.children = childrenInRectangleSelect
		     parentize(f._parent)
		     f.transforms.l[1] = -offX
		     f.transforms.l[2] = -offY

		     meshAll(f._parent)
		     childrenInRectangleSelect = {}
		  end
	       end
	    end



            if imgbutton('add-something', ui.add, rightX, 16).clicked then
               openedAddPanel = not openedAddPanel
            end


            if openedAddPanel then
               if iconlabelbutton('add-meta', ui.move, nil, false,  'meta',  rightX-400, 48, 128).clicked then
                  local shape = {
                     color = {1,0,0,1},
                     points = {{0,0}},
                     type = 'meta'
                  }
                  if (currentNode) then
                     shape._parent = currentNode and currentNode._parent
                     addShapeAfter(shape, currentNode)
                  else
                     shape._parent = root
                     addShapeAtRoot(shape)
                  end

               end


               --ui.object-group
               if iconlabelbutton('add-shape', ui.object_group, nil, false,  'shape',  rightX-250, 48, 128).clicked then
                  local shape = {
                     color = {0,0,0,1},
                     outline = true,
                     points = {},
                  }

                  if currentNode and not currentNode.folder then
                     remeshNode(currentNode)
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
               --ui.folder
               if iconlabelbutton('add-parent', ui.folder, nil, false,  'folder',  rightX-100,48, 128).clicked then

                  local f = makeNewFolder()
                  editingMode = 'polyline'
                  editingModeSub = 'polyline-insert'
               end
            end

	    if (currentNode) then
	       -- what is y position of button in list ?
	       --local yOffset = getNodeYPosition(root, currentNode)
	       --yOffset = math.max(10, yOffset - scrollviewOffset)
	       local index = getIndex(currentNode)
	       if (currentNode and index > 1) then
		  index = getIndex(currentNode)
		  if index > 1 and imgbutton('polyline-move-up', ui.move_up,  w -256, 20 ).clicked then
		     local taken_out = removeCurrentNode()
		     table.insert(taken_out._parent.children, index-1, taken_out)
		  end
	       end

	       if (index < #currentNode._parent.children) and imgbutton('polyline-move-down', ui.move_down,  w -256,60 ).clicked then
		  local taken_out = removeCurrentNode()
		  if (taken_out) then
		     table.insert(taken_out._parent.children, index+1, taken_out)
		  end
	       end
	    end
	    if currentNode then
	       -- print(currentNode ,currentNode.keyframes)
	    end
	    if currentNode and currentNode.keyframes then
	       if (currentNode.keyframes == 2) then
		  local v = h_slider("lerp-keyframes", rightX-300, 100, 200,  currentNode.lerpValue , 0,1)
		  if v.value then
		     currentNode.lerpValue = v.value
		  end
	       end
	       if (currentNode.keyframes == 4 or currentNode.keyframes == 5  ) then
		  local v = joystick('lerp-keyframes', rightX-300, 100, 200, currentNode.lerpX or 0,currentNode.lerpY or 0, 0, 1)
		  if v.value then
		     currentNode.lerpX = v.value.x
		     currentNode.lerpY = v.value.y
		  end
	       end
	    end

	    if (currentNode) then

	       if (changeName) then
		  local str =  currentNode and currentNode.name  or ""
		  local substr = string.sub(str, 1, changeNameCursor)
		  local cursorX = (love.graphics.getFont():getWidth(substr))
		  local cursorH = (love.graphics.getFont():getHeight(str))
		  love.graphics.setColor(1,1,1,0.5)
		  love.graphics.rectangle('fill', w-700 - 10, calcY(4) + 8*4 - 10, 300 + 20,  cursorH + 20 )
		  love.graphics.setColor(1,1,1)
		  love.graphics.print(str , w - 700, calcY(4) + 8*4)
		  love.graphics.setColor(1,1,1, math.abs(math.sin(step/ 100)))
		  love.graphics.rectangle('fill', w- 700 + cursorX+2, calcY(4) + 32,  2, cursorH)
		  love.graphics.setColor(1,1,1)

		  if lastClickedGraphButton then
		     love.graphics.rectangle('line',
					     lastClickedGraphButton.x+24+12,
					     lastClickedGraphButton.y, 100,23)
		     love.graphics.setColor(1,0,0)
		     love.graphics.setFont(smallest)
		     love.graphics.print(lastClickedGraphButton.childName or "",lastClickedGraphButton.x+24+12,
					 lastClickedGraphButton.y)

		  end

		  --
	       end
	    end
	 end

	 love.graphics.pop()
	 love.graphics.setFont(small)
	 if not quitDialog then
	    love.graphics.print(tostring(love.timer.getFPS( )), 2,0)
	    love.graphics.print(shapeName, 64, 0)
	 end

	 if lastDraggedElement and (lastDraggedElement.id == 'connector' or lastDraggedElement.id == 'connector-group' ) then
	    love.graphics.line(lastDraggedElement.pos[1]+16, lastDraggedElement.pos[2]+16, mx, my)
	 end

	 if (imgbutton('dopesheet', ui.dopesheet, 10, h - 32)).clicked then
	    dopesheetEditing = not dopesheetEditing
	    editingMode = dopesheetEditing and 'dopesheet' or nil
	    if dopesheetEditing then -- initialize
	       initializeDopeSheet(cellCount)
	    end
	 end

	 local mousex = love.mouse.getX()
	 local mousey = love.mouse.getY()

	 doDopeSheetEditing(mousex, mousey)

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

	 if fileDropPopup then
	    love.graphics.setFont(small)
	    love.graphics.setColor(1,1,1, 1)
	    love.graphics.rectangle("fill", 100, 100, w-200, h-200)
	    love.graphics.setColor(0,0,0)
	    local name =  fileDropPopup:getFilename()
	    love.graphics.print("dropped file: "..name, 140, 120)

	    if ends_with(name, 'polygons.txt') or ends_with(name, '.svg') then
	       if iconlabelbutton('add-shape', ui.add_to_list, nil, false,  'add shape',  120, 300).clicked then
		  local tab = getDataFromFile(fileDropPopup)
		  root.children = TableConcat(root.children, tab)
		  parentize(root)
		  scrollviewOffset = 0
		  editingMode = nil
		  editingModeSub = nil
		  currentNode = nil
		  meshAll(root)
		  fileDropPopup = nil
	       end
	       if iconlabelbutton('add-shape-new', ui.add, nil, false,  'new project',  120, 200).clicked then
		  local tab = getDataFromFile(fileDropPopup)
		  root.children = tab -- TableConcat(root.children, tab)
		  parentize(root)
		  scrollviewOffset = 0
		  editingMode = nil
		  editingModeSub = nil
		  currentNode = nil
		  meshAll(root)
		  fileDropPopup = nil
	       end

	    else
	       love.graphics.print("this isnt a good filetype", 140, 170)
	       if iconlabelbutton('ok-bye', ui.add, nil, false,  'ok bye',  120, 200).clicked then
		  fileDropPopup = nil
	       end
	    end
	 end
      end
   end
   local work =  nil
   console.draw()
end


function love.textinput(t)
   if (changeName and currentNode) then
      local str = currentNode and currentNode.name or ""
      if (changeNameCursor > #str) then
         changeNameCursor = #str
      end

      local a,b = split(str, changeNameCursor+1)
      local r = table.concat{a, t, b}
      changeNameCursor = changeNameCursor + 1
      currentNode.name = r
   end
   console.textinput(t)
end

function love.filedropped(file)
   fileDropPopup = file
end

function love.keypressed(key, scancode, isrepeat)
   console.keypressed(key, scancode, isrepeat)
   if not console.isEnabled() then
      if key == 'lshift' then
	 editingMode = 'rectangle-select'
      end

      if key == 't' then
	 usePerspective = not usePerspective
      end
      if key == 'tab' then
	 if editingMode ~= 'dopesheet' then
	    editingMode = 'dopesheet'
	    dopesheetEditing = true
	    if not currentNode then
	       currentNode = root.children[1]
	    end
	 else
	    dopesheetEditing = false
	    editingMode = nil
	 end

	 initializeDopeSheet()
      end
      if #childrenInRectangleSelect == 0 then
	 if key == 'down' then
	    if currentNode then
	       local index = getIndex(currentNode)
	       if #currentNode._parent.children > index + 1 then
		  setCurrentNode(currentNode._parent.children[index + 1])
	       end
	    end
	 end
	 if key == 'up' then
	    if currentNode then
	       local index = getIndex(currentNode)
	       if index > 1 then
		  setCurrentNode(currentNode._parent.children[index -1])
	       end
	    end
	 end
      end

      if key == "escape" then
	 if openFileScreen == true then
	    openFileScreen = false
	 elseif (editingModeSub ~= nil) then
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
      --if (key == 'i' and not changeName) then
      -- screenshot
      --renderNodeIntoCanvas(root, love.graphics.newCanvas(1024, 1024),  shapeName..".polygons.png")
      --end
      if (key == 'p' and not changeName) then
	 if not profiling then
	    ProFi:start()
	 else
	    ProFi:stop()
	    ProFi:writeReport( 'log/MyProfilingReport.txt' )
	 end
	 profiling = not profiling
      end
      if key == '-' and not changeName then
	 love.wheelmoved(0,-1)
      end
      if key == '=' and not changeName then
	 love.wheelmoved(0,1)
      end
      if key == '0' and not changeName then
	 root.transforms.l[1] = 0
	 root.transforms.l[2] = 0
      end
      if key == 'o' and not changeName then -- trace
	 openFileScreen = not openFileScreen
	 gatherData('')
      end

      if (key == 's' and not changeName) then
	 local path = shapePath..shapeName..".polygons.txt"
	 local info = love.filesystem.getInfo( path )
	 if (info) then
	    shapeName = shapeName..'_'
	    path =  shapePath..shapeName..".polygons.txt"
	 end
	 local toSave = {}
	 for i=1 , #root.children do
	    table.insert(toSave, copyShape(root.children[i]))
	 end

	 if #shapePath > 0 then
	    --print('creating directory', shapePath)
	    love.filesystem.createDirectory( shapePath )
	 end

	 love.filesystem.write(path, inspect(toSave, {indent=""}))
	 renderNodeIntoCanvas(root, love.graphics.newCanvas(1024/2, 1024/2),  shapePath..shapeName..".polygons.png")
	 local openURL = "file://"..love.filesystem.getSaveDirectory()..'/'..shapePath
	 --print('open url:', openURL)
	 love.system.openURL(openURL)
      end

      if (key == 'j' and not changeName) then
	 local path = shapeName..".polygons.txt.json"
	 local info = love.filesystem.getInfo( path )
	 if (info) then
	    shapeName = shapeName..'_'
	    path =  shapeName..".polygons.txt.json"
	 end
	 local toSave = {}
	 for i=1 , #root.children do
	    table.insert(toSave, copyShape(root.children[i]))
	 end

	 love.filesystem.write(path, json.encode(toSave, {indent=""}))
	 love.system.openURL("file://"..love.filesystem.getSaveDirectory())
      end

      if not changeName and currentNode and not #childrenInRectangleSelect then
	 if (key == 'delete') then
	    deleteNode(currentNode)
	 end
      end

      if #childrenInRectangleSelect > 0 and currentNode then
	 local shift = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")
	 if (key == 'left') then
	    movePoints(currentNode, shift and -10 or -1, 0)
	 end
	 if (key == 'right') then
	    movePoints(currentNode, shift and 10 or 1, 0)
	 end
	 if (key == 'up') then
	    movePoints(currentNode, 0, shift and -10 or -1)
	 end
	 if (key == 'down') then
	    movePoints(currentNode, 0, shift and 10 or 1)
	 end
	 if key == 'delete' then
	    print("yes i hope?")
	    deletePoints(currentNode)
	 end
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
end

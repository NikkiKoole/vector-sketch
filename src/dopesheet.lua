function doDopeSheetEditing()
   local w, h = love.graphics.getDimensions( )

   local mousex = love.mouse.getX()
   local mousey = love.mouse.getY()
   if dopesheetEditing then
      love.graphics.setColor(1,1,1,0.5)
      love.graphics.rectangle("fill", 0, h/2, w, h/2)
      love.graphics.setLineWidth(2)

      for k,v in pairs(dopesheet.refs) do

	 local t = v._parent._globalTransform
	 local t2 = v._globalTransform  --why is this not here? todo
	 local mex, mey = t2:transformPoint(v.transforms.l[1], v.transforms.l[2])
	 local lx, ly = t:transformPoint(v.transforms.l[1], v.transforms.l[2])

	 love.graphics.setColor(1,1,0)
	 love.graphics.circle("fill",lx,ly,10)
	 love.graphics.setColor(0,0,0)
	 local id = k.."thing"
	 local b = getUICircle(id, lx, ly, 10)
	 love.graphics.setColor(1,0,1, 0.8)
	 if b.hover then
	    love.graphics.setColor(0.5,0.5,0.5)
	 end

	 local vpx0, vpy0 = t:transformPoint(0,0 )
	 if v._parent and v._parent._parent then
	    --   vpx0, vpy0 =  v._parent._parent._globalTransform:transformPoint(0,0 )

	 end

	 local vpx, vpy = t:transformPoint(v._parent.transforms.l[6] ,v._parent.transforms.l[7] )
	 --local mex, mey = t:transformPoint(v._parent.transforms.l[6] ,v._parent.transforms.l[7] )
	 local angle, distance = getAngleAndDistance(lx,lx,vpx0,vpx0)
	 local angle2, distance2 = getAngleAndDistance(mousex,mousey,vpx,vpy)
	 local angle3 , distance3 = getAngleAndDistance(mex, mey, vpx, vpy)
	 local parentsAddedAngle = 0
	 local thing = v._parent._parent
	 local gtangle = v._parent.transforms[3]

	 if b.clicked then
	    print(k, 'is clicked, look for parent to rotate', v._parent.name)
	    print("what is the angle between us?")
	    print('parent',v._parent.name, 'is at', vpx, vpy )
	    print(k, "is at", lx,ly)
	    print("angle might be ", angle)


	    lastDraggedElement = {id=id}
	 end

	 while thing do
	    parentsAddedAngle = parentsAddedAngle + thing.transforms.l[3]
	    thing = thing._parent
	 end
	 if love.mouse.isDown(1 ) then
	    if lastDraggedElement and lastDraggedElement.id == id then

	       v._parent.transforms.l[3]  = v._parent.transforms.l[3]  + (angle2 - angle3)
	       --v._parent.transforms.l[3] = angle2 - parentsAddedAngle -math.pi/2   -- gtangle
	    end
	 end

	 --currentNode.transforms.l[6] -- ouch sad trombone 6 & 7 pivot points offsett

	 --local a2 =  v._parent.transforms.l[3] + parentsAddedAngle + math.pi/4
	 --local angle2 = v._parent.transforms.l[3]
	 --local new_x = vpx + math.cos(a2) * distance
	 --local new_y = vpy + math.sin(a2) * distance

	 love.graphics.line(vpx, vpy, lx, ly)

	 love.graphics.circle("line",lx,ly,10)
	 love.graphics.setColor(0,1,0)
	 love.graphics.circle("line",vpx0,vpy0,3)
	 love.graphics.setColor(1,1,1)

      end



      local drawUseToggle = imgbutton("drawOrUse", (dopesheet.drawMode == 'sheet') and ui.dopesheet  or ui.pencil, 0, h/2)
      if drawUseToggle.clicked then
	 dopesheet.drawMode = ( dopesheet.drawMode == 'draw') and 'sheet' or 'draw'
      end

      if (((32+24) * #dopesheet.names)  > h/2) then
	 local ding = scrollbarV('dopesheetslider', 400, h/2, (h/2),48+ ((32+24) * #dopesheet.names) , dopesheet.scrollOffset or 0)
	 if ding.value ~= nil then
	    --if not tostring(ding.value) == "nan" then
	    dopesheet.scrollOffset = ding.value
	    --end
	 end
      end


      if currentNode then
	 local cellWidth = 12
	 local cellHeight = 24
	 for i = 1, #dopesheet.names do
	    local h1 = 32
	    local h2 = 24

	    local x1 = 0
	    local y1 = 32 + h/2 + ((i-1)*(h1+h2))
	    y1 = y1 - dopesheet.scrollOffset
	    local w1 = 200
	    local b = getUIRect('dope-bone'..i, x1,y1,w1,h1)


	    local node = dopesheet.refs[dopesheet.names[i]]

	    if y1 >= h/2 then -- dont draw things that are scrolled away

	       if b.clicked then
		  setCurrentNode(node)
	       end

	       if currentNode == node then
		  love.graphics.setLineWidth(3)
		  love.graphics.setColor(0,0,0)
	       else
		  love.graphics.setLineWidth(2)
		  love.graphics.setColor(0.5,0.5,0.5)
	       end

	       love.graphics.rectangle("line",  x1,y1,w1,h1)

	       love.graphics.setLineWidth(2)
	       love.graphics.setColor(0.7,0.7,0.7)
	       for ci = 1,cellCount do

		  local myX = x1+w1+((ci-1)*cellWidth)
		  local myY = y1 + h1
		  love.graphics.rectangle("line",myX,myY,cellWidth,cellHeight)
		  if dopesheet.data[i][ci] then

		     love.graphics.setColor(0,0,0)
		     love.graphics.rectangle("line",myX+1,myY+1,cellWidth,cellHeight)

		     love.graphics.setColor(0.7,0.7,0.7)
		     love.graphics.rectangle("line",myX,myY,cellWidth,cellHeight)

		     if dopesheet.data[i][ci].rotation then
			love.graphics.setColor(0,1,0,0.3)

			if dopesheet.selectedCell and
			   dopesheet.selectedCell[1]==i and
			   dopesheet.selectedCell[2]==ci then
			   love.graphics.setColor(0,1,0,0.8)
			end

			love.graphics.rectangle("fill",myX+2,myY+2,cellWidth-4,cellHeight-4)
		     end
		  end

		  b = getUIRect(i..ci..'cell', myX, myY, cellWidth,cellHeight)
		  if b.clicked then

		     if dopesheet.drawMode == 'draw' then
			if dopesheet.data[i][ci].rotation then
			   if ci > 1 then -- you cannot delete the first one
			      dopesheet.data[i][ci] = {}
			   end

			else
			   dopesheet.data[i][ci] = {rotation = dopesheet.data[i][1].rotation, ease='linear'}
			end
		     end
		     if dopesheet.drawMode == 'sheet' then
			if  dopesheet.data[i][ci].rotation then

			   dopesheet.sliderValue = (ci-1)/(cellCount-1)

			   dopesheet.selectedCell = {i, ci}
			   calculateDopesheetRotations(dopesheet.sliderValue)

			   -- local name = dopesheet.names[i]
			   -- local node2 = dopesheet.data[i][ci]
			   -- dopesheet.refs[name].transforms.l[3] = node2.rotation
			else
			   dopesheet.selectedCell  = nil
			end
		     end

		  end


	       end

	       love.graphics.setColor(1,1,1,1)
	       love.graphics.setFont(small)
	       local strW = small:getWidth(dopesheet.names[i] )
	       love.graphics.setColor(0,0,0,1)
	       love.graphics.print(dopesheet.names[i], w1 - strW - 10+2, y1+1)
	       love.graphics.setColor(1,1,1,1)
	       love.graphics.print(dopesheet.names[i], w1 - strW - 10, y1)


	       love.graphics.setFont(smallest)


	       local rotStr = "rotation: "..round2(node.transforms.l[3], 3)
	       local str2W = smallest:getWidth(rotStr)

	       love.graphics.setColor(0,0,0,1)
	       love.graphics.print(rotStr, w1 - str2W - 10 + 2, y1 + 32 +1)

	       love.graphics.setColor(1,1,1,1)
	       love.graphics.print(rotStr, w1 - str2W - 10, y1 + 32)
	    end




	 end

	 if dopesheet.selectedCell then
	    local indx = dopesheet.selectedCell
	    if iconlabelbutton('toggle_dopesheet_curve', ui.curve, nil, false,  'ease',  w/2, h/4 -50).clicked then

	       dopesheet.showEases = not dopesheet.showEases
	       print("showEases",dopesheet.showEases)
	    end
	    node = dopesheet.data[indx[1]][indx[2]]

	    rotStr =  "rotation: "..round2(node.rotation, 3)

	    local rotSlider = h_slider("dopesheetrotsliderstuff", w/2, h/4, 600, node.rotation, -math.pi, math.pi)
	    if rotSlider.value then
	       local name = dopesheet.names[indx[1]]
	       dopesheet.refs[name].transforms.l[3] = rotSlider.value
	       node.rotation = rotSlider.value

	    end

	    love.graphics.setColor(0,0,0,0)
	    love.graphics.print(rotStr, w/2 + 2 , h/4 - 20 + 1)


	    love.graphics.setColor(1,1,1,1)
	    love.graphics.print(rotStr, w/2 , h/4 - 20)
	 end



	 local dsSlider = h_slider("dopesheetstuff", 200, h/2, cellWidth*cellCount, dopesheet.sliderValue, 0, 1)
	 if dsSlider.value then

	    dopesheet.sliderValue =  dsSlider.value

	    calculateDopesheetRotations(dsSlider.value)

	 end

	 if dopesheet.selectedCell and  dopesheet.showEases then
	    -- make a dropdown where you can set the type of ease
	    local currentEase = dopesheet.data[dopesheet.selectedCell[1]][dopesheet.selectedCell[2]].ease
	    local eases = {
	       "linear",
	       "inQuad",
	       "outQuad",
	       "inOutQuad",
	       "outInQuad",
	       "inCubic",
	       "outCubic",
	       "inOutCubic",
	       "outInCubic",
	       "inQuart",
	       "outQuart",
	       "inOutQuart",
	       "outInQuart",
	       "inQuint",
	       "outQuint",
	       "inOutQuint",
	       "outInQuint",
	       "inSine",
	       "outSine",
	       "inOutSine",
	       "outInSine",
	       "inExpo",
	       "outExpo",
	       "inOutExpo",
	       "outInExpo",
	       "inCirc",
	       "outCirc",
	       "inOutCirc",
	       "outInCirc",
	       "inBounce",
	       "outBounce",
	       "inOutBounce",
	       "outInBounce",
	    }

	    local eases_1p = {
	       "inBack",
	       "outBack",
	       "inOutBack",
	       "outInBack",
	    }

	    local eases_2p = {
	       "inElastic",
	       "outElastic",
	       "inOutElastic",
	       "outInElastic",
	    }

	    local halfEases = math.floor(#eases/2)

	    function makeEaseLabelButton(label, x, y, selectedEase)
	       love.graphics.setColor(0,0,0, 1)
	       love.graphics.print(label, x+2, y+1)
	       love.graphics.setColor(1,1,1, 1)
	       if (label == selectedEase) then
		  love.graphics.setColor(1,0,1, 1)
	       end

	       love.graphics.print(label, x, y)
	       local labelWidth = smallest:getWidth(label)
	       love.graphics.setColor(1,0,1, 0.2)
	       return getUIRect('ease-select-'..label, x,y,labelWidth,20)
	    end


	    for i =1 , #eases do
	       local y = 20 * i
	       local x = 10
	       if i > #eases/2 then
		  y = 20 * (i - #eases/2 )
		  x = 150
	       end
	       local b = makeEaseLabelButton(eases[i], x, y, currentEase)
	       if b.clicked then
		  dopesheet.data[dopesheet.selectedCell[1]][dopesheet.selectedCell[2]].ease = eases[i]
	       end

	    end
	    for i =1 , #eases_1p do
	       local b = makeEaseLabelButton(eases_1p[i], 300, 20*i, currentEase)
	       if b.clicked then
		  dopesheet.data[dopesheet.selectedCell[1]][dopesheet.selectedCell[2]].ease = eases_1p[i]
	       end
	    end
	    for i =1 , #eases_2p do
	       local b = makeEaseLabelButton(eases_2p[i], 450, 20*i, currentEase)
	       if b.clicked then
		  dopesheet.data[dopesheet.selectedCell[1]][dopesheet.selectedCell[2]].ease = eases_2p[i]
	       end
	    end
	 end

      end


      love.graphics.setLineWidth(1)
   end
end




function initializeDopeSheet()
   dopesheet = {
      scrollOffset = 0,
      node=currentNode,
      names = {},
      refs = {}
   }
   if currentNode then
      --local flatted = {}
      local d = fetchAllNames(currentNode)
      dopesheet.names = d
      local refs = {}
      for i = 1, #d do
	 refs[d[i]] = findNodeByName(root, d[i])
      end
      dopesheet.refs = refs
   end

   data = {}
   for i =1, #dopesheet.names do
      local row = {}

      for j = 1, cellCount do
	 row[j] = {}
      end
      row[1] = {rotation=currentNode.transforms.l[3], ease='linear'}
      row[cellCount] = {rotation=currentNode.transforms.l[3], ease='linear'}

      data[i] = row
   end
   dopesheet.data = data
   dopesheet.selectedCell = nil
   dopesheet.sliderValue = 0
   dopesheet.drawMode = 'sheet'
end

function calculateDopesheetRotations(sliderValue)

   local frameIndex = (math.floor(sliderValue*(cellCount-1))+1)
   if frameIndex > cellCount-1 then frameIndex = cellCount-1 end

   for i = 1, #dopesheet.names do
      local nodeBefore, nodeBeforeIndex = lookForFirstRotationIndexBefore(dopesheet.data[i],frameIndex)
      local nodeAfter, nodeAfterIndex =  lookForFirstRotationIndexAfter(dopesheet.data[i],frameIndex)
      local durp = mapInto(1+ sliderValue * (cellCount-1), nodeBeforeIndex, nodeAfterIndex, 0,1)


      -- local beginVal = 0
      -- local endVal = 1
      -- local change = endVal - beginVal
      -- local duration = 1
      local ease = nodeBefore.ease or 'linear'
      local l1 = easing[ease](durp, 0,1,1, 1/10, 1/3)

      local newRotation = mapInto(l1, 0, 1, nodeBefore.rotation, nodeAfter.rotation)
      dopesheet.refs[dopesheet.names[i]].transforms.l[3] = newRotation
   end
end


function lookForFirstRotationIndexBefore(data, index)
   for i=index , 1 , -1 do
      if data[i].rotation then
	 return data[i], i
      end
   end
   return nil
end
function lookForFirstRotationIndexAfter(data, index)
   for i=index+1 , #data do
      if data[i].rotation then
	 return data[i], i
      end
   end
   return nil
end
function fetchAllNames(root, result)
   result = result or {}

   if root.folder then -- only care for the names of folders atm
      table.insert(result, root.name)
   end

   if root.children then
      for i = 1, #root.children do
	 fetchAllNames(root.children[i], result)
      end
   end
   return result
end
function dopesheetTest()
   print('hi hello!')
end

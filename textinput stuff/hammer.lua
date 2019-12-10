



local function split(str, pos)
	local offset = utf8.offset(str, pos) or 0
	return str:sub(1, offset-1), str:sub(offset)
end


-----

-- TODO
--
-- you can drag multiple elements with 1 pointer, this isnt nice.
--
-- even weirder is that startpress events are thrown
-- it boils down to not knowing if a pointerID is already dragging any element












local hammer = {
   pointersThatAreDragging={}
}






function distance(x, y, x1, y1)
   local dx = x - x1
   local dy = y - y1
   local dist = math.sqrt(dx * dx + dy * dy)
   return dist
end



function pointInRect(x,y, rx, ry, rw, rh)
   if x < rx or y < ry then return false end
   if x > rx+rw or y > ry+rh then return false end
   return true
end
function listGetPointerIndex(list, id)
   if (list) then
      for i=#list,1 ,-1 do
         if list[i].id == id then
            return  i
         end
      end
   end
   return -1
end


function hammer:setKeyboardFocusFor(id)
   self.itemWithKeyboardFocus = id
end

function hammer:handle_textedited(text, start, length)
end

function hammer:handle_textinput(t)
   if self.itemWithKeyboardFocus ~= nil then
      self.key = t
   end
end


function is_one_of(me, others)
   for i =1, #others do
      local it = others[i]
      if me == it then
         return true
      end
   end

   return false
end


function hammer:handle_keypressed(key)

   if is_one_of(key, {'backspace', 'return', 'left', 'right'}) then
      self.key = key
   end

end

function hammer:panel()
end

function hammer:reset(x,y)
   self.drawables = {}
   self.dragging_pointer_ids = {}
   self.x = x
   self.originX = x
   self.y = y
   self.originY = y

   self.margin = 10
   self.rowHeight = 40

   self.cursor =0
end

function hammer:pos(x,y)
   self.x = x
   self.originX = x
   self.y = y
   self.originY = y
end

function hammer:ret()
   self.x = self.originX
   self.y = self.y + self.rowHeight + self.margin
end

function hammer:circle(id, radius, opt_pos)
   local result =  {type="circle",id=id,
                    x=opt_pos.x or self.x,
                    y=opt_pos.y or self.y,
                    r=radius}
   if opt_pos and opt_pos.color then
      result.color = opt_pos.color
   end

   table.insert(self.drawables, result)
   return result
end

function hammer:textinput(id, text, width, height, opt_pos)
      local result =  {type="text-input",text=text,id=id,
                    x=opt_pos and opt_pos.x or self.x,
                    y=opt_pos and opt_pos.y or self.y,
                    w=width,h=height,cursor}

      self:handle_history(id, result)
      local active_from_history = result.active

      self:default_pressed(result, width, height)
      local active_from_pressed = result.active

      if not active_from_history and active_from_pressed then

      end

      self:default_moved(result, width, height)
      self:default_released(result)

      if result.active then
         self:setKeyboardFocusFor(id)
         local clicked_inside = false
         for i=1, #self.pointers.released do
            local pressed = self.pointers.released[i]

            if (pointInRect(pressed.x,
                            pressed.y,
                            self.x,
                            self.y,
                            width,
                            height)) then
               clicked_inside = true

               result.cursor = utf8.len(text)

               for ci=1, utf8.len(text) do
                  local str = ( text:sub(1, ci))
                  local w = (love.graphics.getFont():getWidth(str))

                  if self.x + w > pressed.x then
                     result.cursor = ci
                     break
                  end
               end

            end
         end
         if not clicked_inside and #self.pointers.released>0  then
            result.active = false
            self.itemWithKeyboardFocus = nil
         end

         if self.key then
            if self.itemWithKeyboardFocus == id then
               if self.key == 'backspace' then
                  local a,b = split(result.text, result.cursor+1)
                  result.text = table.concat{split(a,utf8.len(a)), b}
                  result.cursor = math.max(0, (result.cursor or 0)-1)
               elseif self.key == 'return' then
                  result.active = false
                  self.itemWithKeyboardFocus = nil
               elseif self.key == 'right' then
                  result.cursor = math.min(utf8.len(text), (result.cursor or 0)+ 1)
               elseif self.key == 'left' then
                  result.cursor = math.max(0, (result.cursor or 0)-1)
               else
                  local a,b = split(result.text, result.cursor+1)
                  result.text = table.concat { (table.concat{a, self.key}), b}
                  result.cursor = (result.cursor or 0) + 1
               end

               self.key = nil
            end
         end
      end



      table.insert(self.drawables, result)
      self.x = self.x + width + self.margin
   return result

end


function hammer:label(id, text, width, height, opt_pos)
   local result =  {type="label",text=text,id=id,
                    x=opt_pos and opt_pos.x or self.x,
                    y=opt_pos and opt_pos.y or self.y,
                    w=width,h=height}
   table.insert(self.drawables, result)
   self.x = self.x + width + self.margin
   return result
end

function hammer:handle_history(id, result)
   if (self.history) then
      local  hi = listGetPointerIndex(self.history, id)
      if hi > -1 then
         if (self.dragging_pointer_ids[self.history[hi].pointerID] == nil) then
            if self.history[hi].startdrag or self.history[hi].dragging then
               result.dragging = true
               result.pointerID = self.history[hi].pointerID
               result.dx = self.history[hi].dx
               result.dy = self.history[hi].dy
            end
         end
         if self.history[hi].active then
            result.active = true
         end
         if self.history[hi].cursor then
            result.cursor = self.history[hi].cursor
         end

      end
   end

end


function hammer:slider(id, width, height, props)
   local result =  {type="slider",thumbX=0, thumbY=0, id=id,x=self.x, y=self.y, w=width,h=height}

   self:handle_history(id, result)




   local range = (props.max - props.min)
   local space = math.max(width, height) - math.min(width, height)

   if width > height then
      result.thumbX = ((props.value - props.min)/range)*space
   else
      result.thumbY = ((props.value - props.min)/range)*space
   end


   for i=1, #self.pointers.pressed do
      local pressed = self.pointers.pressed[i]

      if (pointInRect(pressed.x,
                      pressed.y,
                      self.x + result.thumbX,
                      self.y + result.thumbY,
                      math.min(width, height),
                      math.min(width, height))) then

         result.pressed = true
         result.startdrag = true

         if not result.pointerID then
            result.pointerID = pressed.id
         else
         end



         if not result.dx and not result.dy then
            result.dx = pressed.x - (self.x + result.thumbX)
            result.dy = pressed.y - (self.y + result.thumbY)
         end

      end
   end

   for i=1, #self.pointers.moved do
      if (pointInRect(self.pointers.moved[i].x,
                      self.pointers.moved[i].y,
                      self.x + result.thumbX,
                      self.y + result.thumbY,
                      math.min(width, height),
                      math.min(width, height))) then
         result.over = true
         if result.startdrag then
            result.startdrag = false
            result.dragging = true
         end

      end
      if result.dragging then
         if result.pointerID == self.pointers.moved[i].id then
            local x
            if width > height then
               x = (self.pointers.moved[i].x - self.x) - result.dx
            else
               x = (self.pointers.moved[i].y - self.y) - result.dy
            end

            local v = props.min + (x / space) *range
            v = math.min(props.max, v)
            v = math.max(props.min, v)
            props.value = v
         end
      end

   end

   for i=1, #self.pointers.released do
      if self.pointers.released[i].id == result.pointerID then
         result.dragging = false
         result.enddrag = true
         result.released = true
         result.dx = false
         result.dy = false
      end
   end

   table.insert(self.drawables, result)
   self.x = self.x + width + self.margin
   return result
end


function hammer:default_pressed(result, width, height)
   for i=1, #self.pointers.pressed do
      local pressed = self.pointers.pressed[i]

      if (pointInRect(pressed.x,
                      pressed.y,
                      result.x,
                      result.y,
                      width, height)) then

         result.active = true

         if not self.dragging_pointer_ids[pressed.id]  then
            self.dragging_pointer_ids[pressed.id] = true

            result.pressed = true
            result.dragging = true
            --result.startdrag = true
            if not result.pointerID  then
               result.pointerID = pressed.id
               result.startpress = true
            else
               result.startpress = false
            end

            if result.dx == 0 and result.dy == 0 then
               result.dx = pressed.x - (result.x + width/2)
               result.dy = pressed.y - (result.y + height/2)
            end

         else
            --print("prohibited multiple pressed items with one pointer")
         end

      end

   end

end
function hammer:default_moved(result, width,height)
      for i=1, #self.pointers.moved do

      if (pointInRect(self.pointers.moved[i].x,
                      self.pointers.moved[i].y,
                      result.x,
                      result.y,
                      width, height)) then
         result.over = true
      end
   end

end
function hammer:default_released(result)
   for i=1, #self.pointers.released do
      if self.pointers.released[i].id == result.pointerID then
         result.dragging = false
         result.startdrag = false
         result.enddrag = true
         result.released = true
         result.dx = 0
         result.dy = 0
      end
   end

end


function hammer:labelbutton(id, width, height, opt_pos)
   local result =  {
      type="labelbutton",id=id,
      dx=0,dy=0,
      text=id,
      x=(opt_pos and opt_pos.x or self.x),
      y=(opt_pos and opt_pos.y or self.y),
      w=width,h=height
   }

   if opt_pos and opt_pos.color then
      result.color = opt_pos.color
   end

   self:handle_history(id, result)

   self:default_pressed(result, width, height)
   self:default_moved(result, width, height)
   self:default_released(result)


   table.insert(self.drawables, result)
   self.x = self.x + width + self.margin
   return result
end


function hammer:rectangle(id, width, height, opt_pos)
   local result =  {type="rect",id=id,
                    dx=0,dy=0,
                    x=(opt_pos and opt_pos.x or self.x),
                    y=(opt_pos and opt_pos.y or self.y),
                    w=width,h=height}

   if opt_pos and opt_pos.color then
      result.color = opt_pos.color
   end


   self:handle_history(id, result)

   self:default_pressed(result, width, height)
   self:default_moved(result, width, height)
   self:default_released(result)


   table.insert(self.drawables, result)
   self.x = self.x + width + self.margin

   --self.y = self.y + height
   return result
end



function hammer:button(label)

end
function hammer:isDirty()
   for i=1, #self.drawables do
      local it = self.drawables[i]
      if it.over or it.pressed or it.dragging then
         return true
      end
   end
   return false
end


function hammer:draw()
   love.graphics.setColor(255,255,255)
   self.history = {}
   for i=1, #(self.drawables) do
      local it = self.drawables[i]
      love.graphics.setColor(255,255,255)

      if (it.over) then
         love.graphics.setColor(255,0,255)
      end


      if (it.pressed) then
         love.graphics.setColor(255,0,0)
      end

      if (it.dragging) then
         love.graphics.setColor(55,222,255)
      end

      if (it.color) then
         love.graphics.setColor(it.color[1],it.color[2],it.color[3], it.color[4] or 255)
         if (it.over or it.dragging or it.pressed) then
            love.graphics.setColor(it.color[1],it.color[2],it.color[3], 155)

         end

      end

       if it.type == "circle" then
         love.graphics.circle("fill", it.x, it.y, it.r)
      end

      if it.type == "rect" or it.type=="labelbutton" then
         if (it.over) then
            if not it.color then
               love.graphics.setColor(255,255,255,100)
            end

            love.graphics.rectangle("fill", it.x-2, it.y-2, it.w+4, it.h+4)
         else

            love.graphics.rectangle("fill", it.x, it.y, it.w, it.h)
         end
      end
      if it.type == "slider" then
         love.graphics.setColor(255,255,255, 150)
         love.graphics.rectangle("fill", it.x, it.y, it.w, it.h)


         love.graphics.setColor(255,0,0, 150)
         if (it.over) then
            love.graphics.setColor(255,0,0, 250)
         end


         love.graphics.rectangle("fill", it.x + it.thumbX, it.y + it.thumbY, math.min(it.w, it.h), math.min(it.w, it.h))

      end
      if it.type == "text-input" then
         love.graphics.setColor(105,105,105, 100)
         if (it.over) then
            love.graphics.setColor(130,130,130,150)
         end

         if (it.active) then
            love.graphics.setColor(130,170,130, 100)
            love.graphics.rectangle("fill", it.x-2, it.y-2, it.w+4, it.h+4)

            love.graphics.setColor(0,0,0, 100)
         end


         love.graphics.rectangle("fill", it.x, it.y, it.w, it.h)
         local w = (love.graphics.getFont():getWidth(it.text))
         local h = (love.graphics.getFont():getHeight())
         local yOff = (it.h - h)/2 -- vertical center
         local xOff = 0 --(it.w - w)/2

         love.graphics.setColor(70,50,50)
         love.graphics.print(it.text, it.x + xOff+1, it.y + yOff + 1)

         love.graphics.setColor(200,200,150)
         love.graphics.print(it.text, it.x + xOff, it.y + yOff)

         if it.active then
            love.graphics.setColor(200,200,150)
            local cursorX = 0
            if it.cursor then
               cursorX = (love.graphics.getFont():getWidth((it.text:sub(1, it.cursor))))

               --print(it.cursor)
            end

            love.graphics.rectangle("fill", it.x+cursorX, it.y, 2, it.h)
         end
      end

      if it.type == "label" or it.type=="labelbutton" then
         love.graphics.setColor(55/255,55/255,55/255)
         love.graphics.rectangle("fill", it.x, it.y, it.w, it.h)

         local w = (love.graphics.getFont():getWidth(it.text))
         local h = (love.graphics.getFont():getHeight())

         local yOff = (it.h - h)/2 -- vertical center
         --local yOff = (it.h - h) -- vertical bottom
         local xOff = (it.w - w)/2

         --love.graphics.setColor(155,155,155, 100)
         --love.graphics.rectangle("fill", it.x + xOff, it.y + yOff, w, h)


         love.graphics.setColor(70/255,50/255,50/255)
         love.graphics.print(it.text, it.x + xOff+1, it.y + yOff + 1)

         love.graphics.setColor(200/255,200/255,150/255)
         love.graphics.print(it.text, it.x + xOff, it.y + yOff)
      end


      table.insert(self.history, {id=it.id, color=it.color,
                                  dx=it.dx, dy=it.dy,
                                  active=it.active,
                                  cursor=it.cursor,
                                  dragging=it.dragging,
                                  startpress=it.startpress,
                                  startdrag=it.startdrag,
                                  pointerID=it.pointerID})
   end

   self.pointers.released = {}
end


return hammer

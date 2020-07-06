function love.keypressed(key)
   if key == 'escape' then
      love.event.quit()
   end
end

function love.load()
   levelSize = 16
   cellSize = 768 / levelSize

   beebot = {
      x = levelSize/2,
      y = levelSize/2,
      margin = cellSize/6,
      angle = 0  -- [0,1,2,3]
   }

   delta = 0

   mode = 'editing' -- ['editing', 'moving']
end

function drawBeebot()
   love.graphics.push()
   love.graphics.setColor(1,0,0)
   love.graphics.translate(beebot.x * cellSize  - cellSize/2 , beebot.y * cellSize - cellSize/2)

   love.graphics.scale(0.8)
   love.graphics.rotate(delta)
  
   love.graphics.rectangle('fill', -cellSize/2  , -cellSize/2 , cellSize, cellSize)
   
   love.graphics.pop()
end

function drawButton(x,y)
love.graphics.setColor(1,1,1)
love.graphics.rectangle('fill', x,y, 64, 64)
love.graphics.setColor(0,0,0)
love.graphics.rectangle('line', x,y, 64, 64)
end

function drawButtons()

   love.graphics.push()
   love.graphics.translate(768, 0)
   
   drawButton(90,80)
   drawButton(10,160)
   drawButton(170,160)
   drawButton(90,240)

   love.graphics.pop()

end


function love.update(dt)
   delta = delta + dt
end


function love.draw()
   love.graphics.clear(0.2,0.2,0.2)
   love.graphics.setColor(.5,.5,0)
   love.graphics.rectangle('fill', 0,0, 768, 768)
   love.graphics.setColor(0,0,0)

   for i = 1, levelSize-1 do
      love.graphics.line(0,cellSize*i, 768, cellSize*i)
   end
   for i = 1, levelSize-1 do
      love.graphics.line(cellSize*i, 0, cellSize*i, 768)
   end

   drawButtons()
   drawBeebot()
end



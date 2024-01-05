
local gridWidth = 16
local gridHeight = 40
local cellSize = 12

local blocktype = {
   air=1,
   solid=2,
   water=3
}

local blockcolors = {
   {.5, .5, .6},
   {1, .5,.5},
   {.5, .5, 1},
}



local function pickRandom(array) 
   local index = math.ceil(love.math.random() * #array)
   return array[index]

end

function love.load()
   map = {}
   for x =1, gridWidth do 
      map[x] = {}
      for y = 1, gridHeight do 
	 map[x][y] = {mass=0, new_mass=0, type=pickRandom({blocktype.air, blocktype.solid, blocktype.water})}
	 
      end
   end
end

function love.draw() 
   for y = 1, gridHeight do 
      for x =1, gridWidth do
	 love.graphics.setColor(1,1,1)
	 love.graphics.rectangle('line', x * cellSize, y*cellSize, cellSize, cellSize)	
	 local color = blockcolors[map[x][y].type]
	 love.graphics.setColor(color[1],color[2],color[3])
	 love.graphics.rectangle('fill', x*cellSize, y*cellSize, cellSize, cellSize)
      end
   end
end

function love.keypressed(k) 
   if k == 'escape' then 
      love.event.quit()
   end
end


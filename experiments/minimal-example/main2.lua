
-- push is a library that will allow us to draw our game at a virtual
-- resolution, instead of however large our window is; used to provide
-- a more retro aesthetic
--
push = require 'push'

-- the "Class" library we're using will allow us to represent anything in
-- our game as code, rather than keeping track of many disparate variables and
-- methods
--
Class = require 'class'

-- our Paddle class, which stores position and dimensions for each Paddle
-- and the logic for rendering them
require 'Paddle'

-- our Ball class, which isn't much different than a Paddle structure-wise
--but which will mechanically function very differently
require 'Ball'

WINDOW_WIDTH = 1280
WINDOW_HEIGHT = 720

VIRTUAL_WIDTH = 432
VIRTUAL_HEIGHT = 243

-- speed at which we will move our paddle; multiplied by dt in update
PADDLE_SPEED = 200

--[[
   Runs when the game first starts up
]]
-- use nearest-neighbor filtering on upscaling and downscaling
function love.load()
   love.graphics.setDefaultFilter('nearest', 'nearest')

   -- set the title of our application window
   love.window.setTitle('Pong')

   --"seed" the RNG so that calls to random are always random
   -- use the current time, since that will vary on startup every time.
   math.randomseed(os.time())

   -- more "Retro-looking" font object we can use for any text
   smallFont = love.graphics.newFont('font.ttf', 13)

   -- larger font for drawing the score on screen
   scoreFont = love.graphics.newFont('font.ttf', 32)

   -- set LOVE2D active font to the smallFont object
   love.graphics.setFont(smallFont)

   push:setupScreen(VIRTUAL_WIDTH, VIRTUAL_HEIGHT, WINDOW_WIDTH, WINDOW_HEIGHT, {
		       fullscreen = false,
		       resizable = false,
		       vsync = true
   })

   -- initialize score variables, used for rendering on the screen and keeping
   -- track of the winner
   player1Score = 0
   player2Score = 0

   -- paddle positions on the Y axis (They can only move up or down)
   player1 = Paddle(10, 30, 5, 20)
   player2 = Paddle(VIRTUAL_WIDTH - 10, VIRTUAL_HEIGHT - 30, 5, 20)

   -- place a ball in the middle of the screen
   ball = Ball(VIRTUAL_WIDTH / 2 - 2, VIRTUAL_HEIGHT / 2 - 2, 4, 4)

   -- game state variable used to transition between different parts of the game
   -- (used for beginning, menus, main game, high score list, ect.)
   -- we will use this to determine behavior during render and update
   gameState = 'start'
end


--[[
   Runs every frame, with "dt" pressed in, our delta in seconds
   since the last frame, which LOVE2D supplies us.
]]

function love.update(dt)
   -- player 1 movement
   if love.keyboard.isDown('w') then
      -- add negative paddle speed to current Y scaled by deltaTime
      -- now, we clamp our position between the bounds of the screen
      -- math.max returns the greater of the two values; 0 and player Y
      -- will ensure we don't go above it
      player1.dy = -PADDLE_SPEED
   elseif love.keyboard.isDown('s') then
      -- add positive paddle to current Y scaled by deltaTime
      -- math.min returns the lesser of two values; bottom of the edge
      -- and player Y will ensure we don't go below it
      player1.dy = PADDLE_SPEED
   else
      player1.dy = 0
   end
end

-- player 2 movement
if love.keyboard.isDown('up') then
   -- add negative paddle speed to current Y scaled by deltaTime
   player2.dy = -PADDLE_SPEED
elseif love.keyboard.isDown('down') then
   -- add positive paddle to current Y scaled by deltaTime
   player2.dy = PADDLE_SPEED
else
   --109?-- player2.dy = 0
end

-- update our ball based on its DX and DY only if we're in play state;
-- scale the velocity by dt so movement is framerate-independent
function love.update(dt)
   if gameState == 'play' then
      ball:update(dt)
   end

   player1:update(dt)
   player2:update(dt)
end


--function love.update(dt)
--if gameState == 'play' then
-- detect ball collision with paddles, reversing dx if true and
-- slightly increasing it, then altering the dy based on the position of the ball
--if ball:collides(player1) then
--ball.dx = -ball.dx * 1.03
--ball.x = player1.x + 5
--end

-- keep velocity going in the same direction, but randomize it
--if ball.dy < 0 then
--ball.dy = -math.random(10, 150)
--else
--ball.dy = math.random(10, 150)
--end
--end
--if ball:collides(player2) then
--ball.dx = -ball.dx * 1.03
--ball.x = player2.x - 4

-- keep velocity going in the same direction, but randomize it
--if ball.dy < 0 then
--ball.dy = -math.random(10, 150)
--else
--ball.dy = math.random(10, 150)
--end
--end

-- detect upper and lower screen boundary collision and reverse if collides
--if ball.y <= 0 then
--ball.y = 0
--ball.dy = -ball.dy
--end

-- -4 to account for the balls size
--if ball.y >= VIRTUAL_HEIGHT - 4 then
--ball.y = VIRTUAL_HEIGHT - 4
--ball.dy = -ball.dy
--end
--end



--[[
   Keyboard handling, called by LOVE2D each frame;
   passes in the key we pressed so we can access.
]]

function love.keypressed(key)
   -- keys can be accessed by string name
   if key == 'escape' then
      -- function LOVE gives us to terminate application
      love.event.quit()
      -- if we press enter during the start state of the game, we'll go into play state
      -- during play mode, the ball will move in a random direction
   elseif key == 'enter' or key == 'return' then
      if gameState == 'start' then
	 gameState = 'play'
      else
	 gameState = 'start'

	 -- ball's new reset method
	 ball:reset()
      end
   end
end

--[[
   Called after update by LOVE2D, used to draw anything to the screen, updated
]]

--begin rendering at virtual resolution
function love.draw()
   push:apply('start')

   -- clear the screen with a specific color; in this case, a color similar
   -- to some versions of the original Pong
   love.graphics.clear(40/255, 45/255, 52/255, 1)

   -- draw score on the left and right center of the screen
   -- need to switch font to draw before actually printing
   love.graphics.setFont(scoreFont)
   love.graphics.print(tostring(player1Score), VIRTUAL_WIDTH / 2 - 50,
		       VIRTUAL_HEIGHT / 3)
   love.graphics.print(tostring(player2Score), VIRTUAL_WIDTH / 2 + 30,
		       VIRTUAL_HEIGHT / 3)

   --
   -- paddles are simply rectangles we draw on the screen at certain points
   -- as is the ball
   --

   -- draw different things based on the state of the game
   love.graphics.setFont(smallFont)

   if gameState == 'start' then
      love.graphics.printf('Hello Start State!', 0, 20, VIRTUAL_WIDTH, 'center')
   else
      love.graphics.printf('Hello Play State!', 0, 20, VIRTUAL_WIDTH, 'center')
   end

   -- render paddles, now using their class's render method
   player1:render()
   player2:render()

   -- render ball using its class's render method
   ball:render()

   -- new function just to demonstrate how to see FPS in Love2D
   displayFPS()


   -- end rendering at virtual resolution
   push:apply('end')
end

--[[
   Renders the current FPS.
]]
function displayFPS()
   -- simple FPS display across all states
   love.graphics.setFont(smallFont)
   love.graphics.setColor(0, 255, 0, 255)
   love.graphics.print('FPS: ' .. tostring(love.timer.getFPS()), 10, 10)
end
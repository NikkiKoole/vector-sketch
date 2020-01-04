


 
function love.draw()
   -- Each pixel touched by the circle will have its stencil value set to 1. The rest will be 0.
   love.graphics.stencil(
      function()
	 love.graphics.circle("fill", 400, 300, 50)
	
      end, "replace", 1, true)
   love.graphics.stencil(
      function()
   	 love.graphics.circle("fill", 300, 300, 50)
	
      end, "replace", 1, true)
 
   -- Configure the stencil test to only allow rendering on pixels whose stencil value is equal to 0.
   -- This will end up being every pixel *except* ones that were touched by the circle drawn as a stencil.
   love.graphics.setStencilTest("equal", 0)
   love.graphics.circle("fill", 400, 300, 150)
   love.graphics.setStencilTest()
end

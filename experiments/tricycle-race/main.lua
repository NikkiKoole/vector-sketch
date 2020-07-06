
function love.keypressed(key)
   if key == 'escape' then
      love.event.quit()
   end
end

function love.load()

   --[[
0	nose
1	leftEye
2	rightEye
3	leftEar
4	rightEar
5	leftShoulder
6	rightShoulder
7	leftElbow
8	rightElbow
9	leftWrist
10	rightWrist
11	leftHip
12	rightHip
13	leftKnee
14	rightKnee
15	leftAnkle
16	rightAnkle
   ]]--

   pose = {
      {position={x=100, y=100}, part="nose"},
      {position={x=80, y=80}, part="leftEye"},
      {position={x=120, y=80}, part="rightEye"},
      {position={x=50, y=70}, part="leftEar"},
      {position={x=150, y=70}, part="rightEar"},
      {position={x=50, y=140}, part="leftShoulder"},
      {position={x=150, y=140}, part="rightShoulder"},
      {position={x=50, y=180}, part="leftElbow"},
      {position={x=150, y=180}, part="rightElbow"},
      {position={x=50, y=240}, part="leftWrist"},
      {position={x=150, y=240}, part="rightWrist"},
      {position={x=70, y=250}, part="leftHip"},
      {position={x=130, y=250}, part="rightHip"},
      {position={x=70, y=300}, part="leftKnee"},
      {position={x=130, y=300}, part="rightKnee"},
      {position={x=70, y=380}, part="leftAnkle"},
      {position={x=130, y=380}, part="rightAnkle"}
   }
   
   
end

function drawSkeleton()
   for i = 1, #pose do
      local pos = pose[i].position
      love.graphics.circle("fill", pos.x,pos.y,5)
   end

   -- drawing if lines
   -- shoulder
   love.graphics.line(pose[6].position.x, pose[6].position.y, pose[7].position.x, pose[7].position.y)
   -- left upper arm
   love.graphics.line(pose[6].position.x, pose[6].position.y, pose[8].position.x, pose[8].position.y)
   -- left lower arm
   love.graphics.line(pose[8].position.x, pose[8].position.y, pose[10].position.x, pose[10].position.y)
   -- right upper arm 
   love.graphics.line(pose[7].position.x, pose[7].position.y, pose[9].position.x, pose[9].position.y)
   -- right lower arm 
   love.graphics.line(pose[9].position.x, pose[9].position.y, pose[11].position.x, pose[11].position.y)
   -- left torso side
   love.graphics.line(pose[6].position.x, pose[6].position.y, pose[12].position.x, pose[12].position.y)
   -- right torso side
   love.graphics.line(pose[7].position.x, pose[7].position.y, pose[13].position.x, pose[13].position.y)
   -- hipperdepip
   love.graphics.line(pose[12].position.x, pose[12].position.y, pose[13].position.x, pose[13].position.y)
   -- left upper leg
   love.graphics.line(pose[12].position.x, pose[12].position.y, pose[14].position.x, pose[14].position.y)
   -- left lower leg
   love.graphics.line(pose[14].position.x, pose[14].position.y, pose[16].position.x, pose[16].position.y)
    -- right upper leg
   love.graphics.line(pose[13].position.x, pose[13].position.y, pose[15].position.x, pose[15].position.y)
   -- right lower leg
   love.graphics.line(pose[15].position.x, pose[15].position.y, pose[17].position.x, pose[17].position.y)
end


function love.draw()
   love.graphics.clear(0.75,0.25,0.5)
   love.graphics.setColor(1,1,1)
   drawSkeleton()
   --love.graphics.circle("fill", 100,100,10)
end

function love.update(dt)
end


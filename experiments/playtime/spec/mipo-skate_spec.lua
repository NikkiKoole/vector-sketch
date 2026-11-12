-- src/mipo-walk.lua walking by itself (docs/MIPO-LOCOMOTION.md LO1): does the standing foot skate?
-- Prints how fast the standing foot slides against the body's speed while it touches the floor, and
-- which way the standing thigh turns (over the floor it should sweep back). A torso held by the
-- standing hip alone turned it forward most frames and slid the foot faster than the body went
-- (Nikki 2026-11-12: "it looks skating"). PLANT: how far the standing foot moves between landing and
-- lifting against how far the body goes (LO3; 0% is a foot that stays put). Compare settings: MOTOR_SET='driveAccel=2' love . --specs spec/mipo-skate_spec.lua
if not love then return end
local state = require('src.state')
local registry = require('src.registry')
local mipoRegistry = require('src.mipo-registry')
local CM = require('src.character-manager')
local jointGuard = require('src.mipo-joint-guard')
local mipoActions = require('src.mipo-actions')
local mipoStance = require('src.mipo-stance')
local keepAngle = require('src.keep-angle')
local pointerJoints = require('src.physics.box2d-pointerjoints')
local callbacks = require('src.physics.physics-callbacks')
local units = require('src.physics-units')
local mipoWalk = require('src.mipo-walk')
local contactTracker = require('src.physics.contact-tracker')
local DT = 1 / units.stepsPerSecond()
describe('a Mipo walking by itself doesn\'t skate', function()
  for _, seed in ipairs({ 4, 7, 11, 42, 13 }) do
    it('seed ' .. seed, function()
      local simTime = 0
      local real = love.timer.getTime
      love.timer.getTime = function() return simTime end
      love.math.setRandomSeed(seed); math.randomseed(seed)
      local world = love.physics.newWorld(0, 9.8 * love.physics.getMeter(), true)
      world:setCallbacks(unpack(callbacks)); state.physicsWorld = world
      registry.reset(); mipoRegistry.reset(); pointerJoints.resetPointerJoints(); mipoWalk.load(nil)
      for k, v in (os.getenv('MOTOR_SET') or ''):gmatch('(%w+)=([%w%.]+)') do mipoWalk[k] = tonumber(v) or (v == 'true') end
      local floor = love.physics.newBody(world, 0, 1000, 'static')
      love.physics.newFixture(floor, love.physics.newRectangleShape(40000, 100)):setFriction(0.9)
      local inst = CM.createCharacter('humanoid', 0, 600, 0.3)
      CM.randomizeMipoConstrained(inst)
      local function step()
        simTime = simTime + DT; world:update(DT); jointGuard.update(); mipoActions.update()
        mipoWalk.update(DT); mipoStance.update(); keepAngle.update(DT, {})
      end
      for _ = 1, 2 / DT do step() end
      mipoWalk.drive(inst, 1.5)
      local n, slide, bodyV, back, fwdTurn, touchN = 0, 0, 0, 0, 0, 0
      local legs = { { 'luleg', 'lfoot' }, { 'ruleg', 'rfoot' } }
      -- plant drift: where the standing foot is when its stance begins against when it ends (a planted
      -- foot comes up where it went down), and how far the body went meanwhile
      local plantLeg, plantX, bodyX, drift, went, plants = nil, 0, 0, 0, 0, 0
      local len = math.abs(inst.parts.lfoot.body:getY() - inst.parts.torso1.body:getY())
      for i = 1, 4 / DT do
        step()
        if i * DT > 1.5 and inst._stance ~= plantLeg then
          local tx = inst.parts.torso1.body:getX()
          if plantLeg then
            drift = drift + math.abs(inst.parts[legs[plantLeg][2]].body:getX() - plantX)
            went = went + math.abs(tx - bodyX)
            plants = plants + 1
          end
          plantLeg = inst._stance
          if plantLeg then plantX, bodyX = inst.parts[legs[plantLeg][2]].body:getX(), tx end
        end
        if i * DT > 1.5 and inst._stance then
          local L = legs[inst._stance]
          local foot, thigh = inst.parts[L[2]].body, inst.parts[L[1]].body
          local tv = inst.parts.torso1.body:getLinearVelocity()
          local fv = foot:getLinearVelocity()
          local touching = contactTracker.any and contactTracker.any(foot, function() return true end)
          if touching then
            touchN = touchN + 1
            slide, bodyV = slide + fv, bodyV + tv
            -- facing right: the foot going back under the hip = the thigh's angle growing
            if thigh:getAngularVelocity() > 0.2 then back = back + 1 elseif thigh:getAngularVelocity() < -0.2 then fwdTurn = fwdTurn + 1 end
          end
          n = n + 1
        end
      end
      print(string.format('SKATE seed %d: stance foot on floor %d%% of frames; foot slides %.0f px/s while body goes %.0f (%.0f%%); standing thigh turns back %d, forward %d frames',
        seed, 100 * touchN / math.max(n, 1), slide / math.max(touchN, 1), bodyV / math.max(touchN, 1),
        100 * slide / math.max(bodyV, 1), back, fwdTurn))
      print(string.format('PLANT seed %d: %d stances, the standing foot drifts %.2f legs a stance while the body goes %.2f (%.0f%%)',
        seed, plants, drift / math.max(plants, 1) / len, went / math.max(plants, 1) / len, 100 * drift / math.max(went, 1)))
      world:setCallbacks(); world:destroy(); love.timer.getTime = real
      assert.is_true(back > 2 * fwdTurn) -- the standing thigh sweeps back, not forward
    end)
  end
end)

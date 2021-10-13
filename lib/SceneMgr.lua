-- Error checking functions
local funcDefined = nil -- does the scene file contain the passed function name
local pathDefined = nil -- does the scene file or folder exist

-- Scene and properties
local scene = {}
scene.dir = nil         -- The directory for your scenes
scene.cName = nil       -- current scene file name
scene.pName = nil       -- previous scene file name
scene.current = nil     -- The required scene, so it can be later unloaded


--                     --
-------------------------
-- SCENE MANAGER CALLS --
-------------------------
--                     --
function scene.setPath(path)
  assert(type(path) == "string", "Function 'setPath': parameter must be a string.")

  -- Add trailing "/" if none is found (47 = /)
  if string.byte(path, #path) ~= 47 then
    path = path.."/"
  end

  if pathDefined(path) then
    scene.dir = path
  end
end

function scene.modify(fileName, flags)
  assert(type(fileName) == "string", "Function 'modify': first parameter must be a string.")
  assert(type(flags) == "table" or type(flags) == "nil", "Function 'modify': second parameter must be a table or nil.")

  -- You can modify a full scene by just passing the fileName.
  -- You can also modify parts of a scene by passing flags, i.e. a table of variables to be modifyed.
  -- The modify functionality is handled in the scenes modify function to give the developer max control.
  if funcDefined("modify") then
    scene.current.modify(flags)
  end
end

--                       --
-- Start and Stop Scenes --
--                       --
function scene.unload(fileName)
  assert(type(fileName) == "string", "Function 'unload': parameter must be a string.")

  local path = scene.dir..fileName

  if pathDefined(path..".lua") then
    if package.loaded[path] then
      package.loaded[path] = nil
    end
  end
end

function scene.load(fileName)
  assert(type(fileName) == "string", "Function 'load': parameter must be a string.")

  local path = scene.dir..fileName

  scene.pName = scene.cName
  scene.cName = fileName

  if pathDefined(path..".lua") then
    scene.current = require(path)

    if funcDefined("load") then
      scene.current.load()
    end
  end
end

--                   --
-- Game (scene) Loop --
--                   --
function scene.update(dt)
  assert(type(dt) == "number", "Function 'update': parameter must be a number.")

  if funcDefined("update") then
    scene.current.update(dt)
  end
end

function scene.draw()
  if funcDefined("draw") then
    scene.current.draw()
  end
end


--                --
--------------------
-- ERROR CHECKERS --
--------------------
--                --
funcDefined = function(func)
  if scene.current[func] then
    if type(scene.current[func]) == 'function' then
      return true
    else
      error("\'"..scene.dir..scene.cName..".lua\': "..func.." should be a function.")
    end
  else
    error("\'"..scene.dir..scene.cName..".lua\': "..func.." function is not defined.")
  end
end

pathDefined = function(path)
  local major, minor, revision, _ = love.getVersion()

  if major == 0 and minor == 9 and revision >= 1 then
    -- File system calls for love 0.9.1 and up to 0.11.0
    if love.filesystem.exists(path) then
      return true
    else
      error("Can't "..debug.getinfo(2).name.." \'"..path.."\': No such file or directory.")
    end
  elseif major == 11 and minor >= 0 and revision >= 0 then
    -- File system calls for love 0.11.0 and up to most recent
    if love.filesystem.getInfo(path, filtertype) then
      return true
    else
      error("Can't "..debug.getinfo(2).name.." \'"..path.."\': No such file or directory.")
    end
  else
    error("Love versions prior to 0.9.1 are not supported by this module..")
  end

end

--
return scene

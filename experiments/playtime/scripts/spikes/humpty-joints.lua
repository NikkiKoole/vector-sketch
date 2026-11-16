-- humpty-joints: what the humpty spike needs that a scene script can't reach (it has no `require` or
-- `setmetatable`); loaded with love.filesystem.load this file runs in the plain globals, where it can.
return {
    joints = require('src.joints'),
    weakKeys = function() return setmetatable({}, { __mode = 'k' }) end,
}

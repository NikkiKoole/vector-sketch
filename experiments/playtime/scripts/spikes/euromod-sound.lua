-- euromod-sound: what the euromod spike needs that a scene script can't reach (it has no `require`): the synth and
-- the music. Loaded with love.filesystem.load, this file runs in the plain globals, where it can.
local ok, synth = pcall(require, 'src.synth') -- (no FFI: no synth, the toy is silent)
return {
    synth = ok and synth or nil,
    music = require('src.music'),
}

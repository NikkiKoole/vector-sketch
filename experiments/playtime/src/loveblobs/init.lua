local dir = (...):gsub('%.[^%.]+$', '')
dir = dir .. '.loveblobs/'
local blobs = {}

blobs.softbody = require(dir .. ".softbody")
blobs.softsurface = require(dir .. ".softsurface")

return blobs

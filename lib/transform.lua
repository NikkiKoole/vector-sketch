local transform = {}


local function doMultiplication(pg, tl)
    --local cloned = tl:clone()
    return pg and (pg * tl) or (tl)
end

transform.setTransforms = function(root, isDirty) -- this thing is leaking


    if root.transforms then
        if (isDirty == true or isDirty == nil) then

            local tl = root.transforms.l
            local pg = nil
            if (root._parent) then
                pg = root._parent.transforms._g --:clone()
            end

            if (root.transforms._l == nil) then
                root.transforms._l = love.math.newTransform(
                    tl[1], tl[2], tl[3], tl[4], tl[5], tl[6], tl[7], tl[8], tl[9]
                )
            else -- this works but doesnt really improve anything measurable at this time
                root.transforms._l:setTransformation(tl[1], tl[2], tl[3], tl[4], tl[5], tl[6], tl[7], tl[8], tl[9])
            end

          
            root.transforms._g = doMultiplication(pg, root.transforms._l)
            --print(root.name)
            --if (root.name == 'rood folder') then
            --    local transform = love.math.newTransform( 0,0,0, -1, 1, 0,0,0,0 )
            --    root.transforms._g = root.transforms._g  * transform
            --end
        end
    end

    root.dirty = false

end

transform.getLocalizedDelta = function(element, dx, dy)
    local x1, y1 = element._parent.transforms._g:inverseTransformPoint(dx, dy)
    local x0, y0 = element._parent.transforms._g:inverseTransformPoint(0, 0)
    return x1 - x0, y1 - y0
end

return transform

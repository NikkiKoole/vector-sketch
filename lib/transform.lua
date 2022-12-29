local transform = {}

transform.setTransforms = function(root, isDirty) -- this thing is leaking

    -- instead of always making new transforms I need to only do this onDirty (which will be passed alonb the graph)
    -- some items have issues with this, mostly things that have a _parent
    -- I think the issue has todo with the hittesting returning a child of the thing instead of the thing itself
    -- print(isDirty)
    -- local isdirty = false
    -- if (isDirty == true) or (isDirty == nil) then -- isdirty == nil check so unset dirty flags are also treated as true
    --     isdirty = true
    -- end
    --if (isDirty == true or isDirty == nil) then
    --  print('settransforms', root.name, isDirty)

    --end
    if root.transforms then
        local tl = root.transforms.l
        local pg = nil
        if (root._parent) then
            pg = root._parent.transforms._g
        end

        if (root.transforms._l == nil) then
            root.transforms._l = love.math.newTransform(tl[1], tl[2], tl[3], tl[4], tl[5], tl[6], tl[7], tl[8], tl[9])
        else -- this works but doesnt really improve anything measurable at this time
            root.transforms._l:setTransformation(tl[1], tl[2], tl[3], tl[4], tl[5], tl[6], tl[7], tl[8], tl[9])
        end


        if (isDirty == true or isDirty == nil) then
            -- if (root.transforms._g) then
            --     root.transforms._g:release()
            --     root.transforms._g = nil
            -- end

            -- clone:
            --print(isDirty)
            root.transforms._g = pg and (pg * root.transforms._l) or (root.transforms._l)
        end
    end
    if root.dirty == true then
        --print('thing was dirty now set to clean')
    end
    root.dirty = false

end




transform.getLocalizedDelta = function(element, dx, dy)
    local x1, y1 = element._parent.transforms._g:inverseTransformPoint(dx, dy)
    local x0, y0 = element._parent.transforms._g:inverseTransformPoint(0, 0)
    return x1 - x0, y1 - y0
end

return transform

local text = require 'lib.text'

function getPNGMaskUrl(url)
    return text.replace(url, '.png', '-mask.png')
 end
 
 function hasChildNamedRomp(item)
    --print(item.texture)
    for k= 1, #item.children do
       --print( item.children[k].name)
       if item.children[k].name == 'romp' then
          return item.children[k]
       end
    end
 
    return nil;
 end
 
 function stripPath(root, path)
    if root and root.texture and root.texture.url and #root.texture.url > 0 then
        local str = root.texture.url
        local shortened = string.gsub(str, path, '')
        root.texture.url = shortened
        --print(shortened)
    end

    if root.children then
        for i = 1, #root.children do
            stripPath(root.children[i], path)
        end
    end

    return root
end

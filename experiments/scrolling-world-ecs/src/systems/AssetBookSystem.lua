--[[

The assetbook system controls which items are removed and added when the camera moves
Items that have been moved around, (or been put in stacks, (not yet implemented)) are removed from this system, so they
persist wwhen they go offscreen


]]--


local AssetBookSystem = Concord.system({pool = {'assetBook'}})
function AssetBookSystem:itemPressed(item, layer)
   if item.entity and item.entity.assetBook then
         local firstIndex = item.entity.assetBook.index
         if firstIndex ~= nil and layer.assets[firstIndex]  then
            local index = 0
            for k =1 , #layer.assets[firstIndex] do
               if layer.assets[firstIndex][k] == item.entity.assetBook.ref then
                  index = k
               end
            end
            if index > 0 then
               table.remove(layer.assets[firstIndex], index)
               item.entity:remove('assetBook')
            end
         end
   end
end

return AssetBookSystem

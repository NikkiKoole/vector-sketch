local AssetBookSystem = Concord.system({pool = {'assetBook'}})
function AssetBookSystem:itemPressed(item, l, x,y)
   if item.entity and item.entity.assetBook then
         local first = item.entity.assetBook.index
         if first ~= nil and l.assets[first]  then
            local index = 0
            for k =1 , #l.assets[first] do
               if l.assets[first][k] == item.entity.assetBook.ref then
                  index = k
               end
            end
            if index > 0 then
               table.remove(l.assets[first], index)
               item.entity:remove('assetBook')
            end
         end
   end
end

return AssetBookSystem

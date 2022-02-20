require 'lib.autobatch'
local ecs = require 'lib.ecs'

ecs.on('added.component', function(entity, name)
  if name == 'image' then
    local img, node = entity:get('image', 'node')
    node.renderable = love.graphics.newImage(img.path)
    node.size = { node.renderable:getWidth(), node.renderable:getHeight() }
  end
end)
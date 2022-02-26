local M = {}

local ecs = require "lib.ecs"
local game = require "lib.gamewindow"

function M.setup()
  local ent = ecs.entity{
    node = { z = 100, renderable = love.graphics.newCanvas() },
    transform = true,
    mapLighting = {}
  }
end

ecs.on('added.component', function(entity, name)
  if name == 'mapLighting' then 
    local lg = love.graphics
    entity.node.renderable:renderTo(function()
      lg.push('all')
      lg.clear()
      lg.setColor(0,0,0,0.25)
      lg.rectangle('fill',0,0,game.getWidth(),game.getHeight())
      lg.pop()
    end)
  end
end)

function M.update(dt)
  for _, _, tf in ecs.filter('mapLighting', 'transform') do 
    for _, cf, le in ecs.filter('cameraFocus', 'lightExplorer') do
      tf.x = -cf.x 
      tf.y = -cf.y
    end
  end
end 

return M 
local M = {}
local ecs = require "lib.ecs"
local game = require "lib.gamewindow"

local floor = function(x)
  return math.floor(x + 0.5)
end

function M.draw()
  local needs_sorting

  for entity, tf, node in ecs.filter('transform', 'node') do 
    if node._last_z ~= node.z then 
      node._last_z = node.z 
      needs_sorting = true
    end
    if node.renderable and node.visible then
      -- transform up the graph
      local transform = M.getTransform(entity)

      -- draw renderable 
      if game.inside(transform:transformPoint(0,0)) then 
        love.graphics.replaceTransform(transform)
        love.graphics.draw(node.renderable)
      end 
      love.graphics.origin()
    end
  end

  if needs_sorting then 
    ecs.sort({'node'}, function(lhs, rhs)
      return lhs.node.z < rhs.node.z 
    end)
  end
end

function M.getTransform(entity)
  local parent = entity 
  local tf = entity:get('transform')
  if not tf._transform then 
    tf._transform = love.math.newTransform()
  end 
  local transform = tf._transform
  repeat 
    tf = parent:get('transform')
    transform:reset()
    transform:scale(tf.sx, tf.sy)
    transform:rotate(tf.r)
    transform:translate(floor(tf.x), floor(tf.y))
    parent = entity:get('node').parent 
  until not parent
  return transform
end

return M
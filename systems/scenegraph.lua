local M = {}
local ecs = require "lib.ecs"
local game = require "lib.gamewindow"

local floor = function(x)
  return math.floor(x + 0.5)
end

M.renders = 0

function M.draw()
  local needs_sorting
  M.renders = 0
  for entity, node in ecs.filter('node') do 
    if node._last_z ~= node.z then 
      node._last_z = node.z 
      needs_sorting = true
    end
    if node.renderable and node.visible then
      -- transform up the graph
      local transform = M.getTransform(entity)

      -- draw renderable 
      if not transform then 
        love.graphics.draw(node.renderable)

      elseif 
        game.inside(transform:transformPoint(0,0)) and 
        game.inside(transform:transformPoint(node.size[1],node.size[2])) and 
        game.inside(transform:transformPoint(node.size[1],0)) and 
        game.inside(transform:transformPoint(0,node.size[2])) 
      then 
        love.graphics.push()
        love.graphics.applyTransform(transform)
        love.graphics.draw(node.renderable)
        love.graphics.pop()
        M.renders = M.renders + 1
      end 
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
  if not tf then return nil end
  if not tf._transform then 
    tf._transform = love.math.newTransform()
  end 
  local transform = tf._transform
  repeat 
    tf = parent:get('transform')
    local x,y = floor(tf.x), floor(tf.y)
    transform:reset()
    transform:scale(tf.sx, tf.sy)
    transform:rotate(tf.r)
    transform:translate(x, y)
    parent = entity:get('node').parent 
  until not parent
  return transform
end

return M
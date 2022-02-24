local M = {}

local ecs = require "lib.ecs"
local signal = require "lib.signal"

function M.update(dt)
  local keydown = love.keyboard.isDown

  for entity, pc, transform in ecs.filter('playerControl', 'transform') do 
    local vx, vy = 0, 0
    if keydown('right') or keydown('d') then 
      vx = pc.max_velocity
    end
    if keydown('left') or keydown('a') then 
      vx = -pc.max_velocity
    end
    if keydown('down') or keydown('s') then 
      vy = pc.max_velocity
    end
    if keydown('up') or keydown('w') then 
      vy = -pc.max_velocity
    end
    transform.x = transform.x + vx * dt 
    transform.y = transform.y + vy * dt 
  end
end

-- signal.on('update', function(dt)
--   M.update(dt)
-- end)

return M
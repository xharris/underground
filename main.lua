-- utility/extra
f = string.format
log = require "lib.log"
require "lib.util"
require "components"
-- lib 
local game = require "lib.gamewindow"
local ecs = require "lib.ecs"
local signal = require "lib.signal"
-- system
local graph = require "systems.scenegraph"
require "systems.image"
local map = require "systems.map"
local playercontrol = require "systems.playercontrol"
local chunk = require 'lib.chunk'

--[[
  [x] draw player
  [ ] generate world
]]

local chunker = chunk.new(200)

function love.load()
  love.graphics.setBackgroundColor(62/255, 39/255, 35/255)
  game.init()

  ecs.entity{
    transform = { x=0, y=0 },
    node = { z = 100 },
    image = { path='assets/images/player.png' },
    playerControl = { max_velocity=100 },
    mapExplorer = true,
    cameraFocus = true
  }
  ecs.entity{
    transform = { x=100, y=100 },
    node = { z = 100 },
    image = { path='assets/images/player.png' },
    playerControl = { max_velocity=100 },
    mapExplorer = true
  }
  -- map.new(200,200)

  for x = 0, game.getWidth(), 32 do 
    for y = 0, game.getHeight(), 32 do 
      chunker:add(
        ecs.entity{
          transform = { x=x, y=y, ox=8, oy=8 },
          node = true,
          image = { path='assets/images/dirt.png' },
          spin = { v=10 }
        }, 
      x, y, 16, 16)
    end
  end

end

local profile = require 'lib.profile'
function love.update(dt)
  -- profile.start()

  ecs.update(dt)
  -- map.update(dt)
  playercontrol.update(dt)

  for ent, tf, mapExplorer in ecs.filter('transform','mapExplorer') do 
    local tx, ty = graph.getTransform(ent):transformPoint(0, 0)
    chunker:explore(ent, tx, ty)
  end

  for entity in chunker:iterate() do 
    local tf, spin = entity:get('transform', 'spin')
    tf.r = tf.r + spin.v * dt 
  end

  -- profile.stop()
end

function love.quit()
  -- print(profile.report(10))
end

local xoff, yoff = 0, 0
function love.draw()
  local lg = love.graphics
  local w, h = game.getDimensions()
  for entity, tf, _ in ecs.filter('transform', 'cameraFocus') do
    game.draw(function()
      lg.push()
      lg.translate(-tf.x + (w/2),-tf.y + (h/2))
      graph.draw()
      -- map.debug()
      lg.pop()
      
      -- lg.push()
      -- lg.origin()
      -- lg.print(f('draws: %d\nentities: %d\nFPS: %d',graph.renders,ecs.stats.entities(),love.timer.getFPS()), 20, 20)
      -- lg.pop()
    end)
  end
end

function love.resize(w,h)
  return game.resize(w,h)
end
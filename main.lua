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
require "systems.playercontrol"

--[[
  [x] draw player
  [ ] generate world
]]

local canv

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

  -- for i = 1, 20 do 
  --   print(i, math.floor(i / 4))
  -- end
  map.new(200,200)

  canv = love.graphics.newCanvas()
end

function love.update(dt)
  signal.emit('update', dt)
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

      lg.push()
      lg.origin()
      lg.print(f('draws: %d\nFPS: %d',graph.renders,love.timer.getFPS()), 20, 20)
      lg.pop()
    end)
  end
end

function love.resize(w,h)
  return game.resize(w,h)
end
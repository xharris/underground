local game = require "lib.gamewindow"
local ecs = require "lib.ecs"
local signal = require "lib.signal"

require "components"
local graph = require "systems.scenegraph"
require "systems.image"
local map = require "systems.map"
require "systems.playercontrol"

--[[
  [x] draw player
  [ ] generate world
]]

function love.load()
  love.graphics.setBackgroundColor(62/255, 39/255, 35/255)
  game.init()

  ecs.entity{
    transform = { x=0, y=0 },
    node = { z = 100 },
    image = { path='assets/images/player.png' },
    playerControl = { max_velocity=100 },
    mapExplorer = true
  }

  -- for i = 1, 20 do 
  --   print(i, math.floor(i / 4))
  -- end
  map.new(200,200)
end

function love.update(dt)
  signal.emit('update', dt)
end

function love.draw()
  game.draw(function()
    graph.draw()
    map.debug()
  end)
end

function love.resize(w,h)
  game.resize(w,h)
end
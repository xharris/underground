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

function love.load()
  love.graphics.setBackgroundColor(62/255, 39/255, 35/255)
  game.init()

  print(ecs.entity{
    transform = { x=0, y=0 },
    node = { z = 100 },
    image = { path='assets/images/player.png' },
    playerControl = { max_velocity=100 },
    mapExplorer = true,
    lightExplorer = true,
    cameraFocus = true
  })
  map.new()
end

local profile = require 'lib.profile'
function love.update(dt)
  -- profile.start()


  ecs.update(dt)
  map.update(dt)
  playercontrol.update(dt)

  local w, h = game.getDimensions()
  for _, tf, cf in ecs.filter('transform', 'cameraFocus') do
    cf.x = -tf.x + (w/2)
    cf.y = -tf.y + (h/2)
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
  game.draw(function()
    for _, tf, cf in ecs.filter('transform', 'cameraFocus') do
        lg.push()
        lg.translate(cf.x, cf.y)
        graph.draw()
        -- map.debug()
        lg.pop()
        
        lg.push()
        lg.origin()
        local stats = lg.getStats()

        lg.print(f(
          'draws: %d\nentities: %d\nFPS: %d',
          stats.drawcalls,
          ecs.stats.entities(),
          love.timer.getFPS()),
        20, 20)
        lg.pop()
    end
  end)
end

function love.resize(w,h)
  return game.resize(w,h)
end
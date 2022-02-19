local M = {}

local game = require "lib.gamewindow"
local ecs = require "lib.ecs"
local signal = require "lib.signal"
local graph = require "systems.scenegraph"

local f = string.format
local floor = math.floor
local TILE_SIZE = 16 -- pixels
local CHUNK_SIZE = 3 -- # configs x # configs 

local base = {
  name = 'base',
  key = {
    { type='image', value='dirt.png' },
    { type='spawn' }
  },
  center = { 4, 4 },
  columns = 7,
  map = {
    1, 1, 1, 1, 1, 1, 1,
    1, 0, 0, 0, 0, 0, 1,
    1, 0, 0, 0, 0, 0, 1,
    1, 0, 0, 0, 0, 0, 1,
    1, 0, 0, 0, 0, 0, 1,
    1, 0, 0, 2, 0, 0, 1,
    1, 1, 1, 1, 1, 1, 1,
  }
}

local empty = {
  name = 'empty',
  key = {
    { type='image', value='dirt.png' }
  },
  center = { 4, 4 },
  columns = 7,
  map = {
    1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1,
  }
}

-- configs
local library = {
  {
    name = 'cross',
    key = {
      { type='image', value='dirt.png' }
    },
    center = { 4, 4 },
    columns = 7,
    map = {
      1, 1, 1, 1, 1, 1, 1,
      1, 0, 0, 0, 0, 0, 1,
      1, 0, 0, 1, 0, 0, 1,
      1, 0, 1, 1, 1, 0, 1,
      1, 0, 0, 1, 0, 0, 1,
      1, 0, 0, 0, 0, 0, 1,
      1, 1, 1, 1, 1, 1, 1,
    }
  }
}

local function rgb_to_hex(r, g, b)
  --%02x: 0 means replace " "s with "0"s, 2 is width, x means hex
  return string.format("#%02x%02x%02x", 
    math.floor(r*255),
    math.floor(g*255),
    math.floor(b*255))
end

local chunks = {} -- 'x-y'
local chunk_enabled = {} -- 'x-y':t/f
local blocks = {} -- 'x-y':{}
-- local active_area = {x=0,y=0,w=0,h=0}

function M._generateChunk(chunkx, chunky, is_base)
  print(chunkx,chunky)

  local chunk_key = f('%d-%d',chunkx,chunky)
  local map_info 

  if is_base then 
    map_info = base
  else 
    map_info = empty
    if love.math.random(100) > 0 then 
      map_info = library[love.math.random(#library)]
    end
  end
  print(map_info.name)

  -- add blocks randomly (or a base)
  local tile, x, y
  for i = 0, #map_info.map do
    x, y = math.to2D(i,  map_info.columns)
    ox, oy = 0, 0
    if map_info.center then 
      ox, oy = unpack(map_info.center)
    end
    tile = map_info.key[map_info.map[i]]
    
    if tile then 
      if tile.type == 'image' then 
        ecs.entity{
          transform = { 
            x=( x-ox ) * TILE_SIZE,
            y=( y-oy ) * TILE_SIZE 
          },
          node = true,  
          image = { path='assets/images/'..tile.value },
          mapRoom = map_info
        }
      end
    end
  end
  
  chunk_enabled[chunk_key] = true 
end

function M._getBlockArea(entity)
  local tf, room = entity:get('tf', 'mapRoom') 
  
end

-- get the chunk at (posx, posy)
-- enable/generate neighboring chunks
function M.generate(posx, posy)
end

function M.debug()
  for entity, tf, room in ecs.filter('transform', 'mapRoom') do 
    local transform = graph.getTransform(entity)
    love.graphics.push()
    love.graphics.setColor(1,0,0)
    local x,y = transform:transformPoint(0,0)
    love.graphics.rectangle('line',x,y,20,20)
    love.graphics.pop()
  end
end 

--[[
  create a base
  set the seed
]]
function M.new(x,y)
  M._generateChunk(x, y, true)  
  M.generate(x, y)  
end

signal.on('update', function(dt)
  for entity, tf, _ in ecs.filter('transform', 'mapExplorer') do 
    M.generate(tf.x, tf.y)
  end 
end)

return M 
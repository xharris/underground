local M = {}

local game = require "lib.gamewindow"
local ecs = require "lib.ecs"
local signal = require "lib.signal"
local graph = require "systems.scenegraph"
local bump = require "lib.bump"
local chunk = require 'lib.chunk'
local lighting = require "systems.map.lighting"

local floor = math.floor

local TILE_SIZE = 16 -- pixels
local SPACING_MULTIPLIER = 10 
local CHUNK_SIZE = math.multiple(200, TILE_SIZE)
local RESOURCE_SURROUNDING_MODIFIER = 0.07 -- higher = more blocks surrounding resource
local RESOURCE_SIZE_MODIFIER = 0.12 -- higher = larger amounts of resources spawn

local chunker = chunk.new(500)

local tiles = {
  dirt = {
    name = 'dirt',
    image = 'assets/images/dirt.png'
  },
  iron = {
    name = 'iron',
    rarity = 80,
    image = 'assets/images/iron.png'
  }
}
local tile_types = table.keys(tiles)
local world = bump.newWorld()

local base = {
  name = 'base',
  key = {
    { type='tile', value='dirt' },
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
  name = 'base',
  key = {
    { type='tile', value='dirt' }
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
      { type='tile', value='dirt' }
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

local function poskey(x,y)
  return f('%dx%d',x,y)
end

M._getTileBatch = memoize(function(path)
  return ecs.entity{
    node = { z=10, renderable=love.graphics.newSpriteBatch(love.graphics.newImage(path)) },
    mapTileBatch = { path=path }
  }
end)

local tile_stats = {}
local tile_noise = {} -- 'x-y':tile type
function M._getTileType(x,y,mod,_prev_tile)
  x, y = math.multiple(x,TILE_SIZE), math.multiple(y,TILE_SIZE)
  mod = mod or 1
  local key = poskey(x,y)
  local n = love.math.noise(x/340,y/340)

  -- room already here
  local _, rooms = world:queryPoint(x,y)
  if rooms ~= 0 then 
    return nil 
  end
  -- tile already generated
  if tile_noise[key] then 
    return tile_noise[key]
  end

  -- is it not dirt?
  if n < (RESOURCE_SIZE_MODIFIER+RESOURCE_SURROUNDING_MODIFIER)*mod then 
    if n < RESOURCE_SIZE_MODIFIER*mod then 
      -- resource tile 
      -- TODO: choose random weighted
      _prev_tile = _prev_tile or tiles.iron
      tile_noise[key] = _prev_tile
      return tile_noise[key]
    else
      -- supporting tile
      tile_noise[key] = tiles.dirt
      return tile_noise[key]
    end

    if not tile_stats[tile_noise[key].name] then 
      tile_stats[tile_noise[key].name] = 0
    end
    tile_stats[tile_noise[key].name] = tile_stats[tile_noise[key].name] + 1

    -- generate neighboring tiles
    for sx = x - TILE_SIZE, x + TILE_SIZE, TILE_SIZE*2 do 
      for sy = y - TILE_SIZE, y + TILE_SIZE, TILE_SIZE*2 do 
        key = poskey(sx,sy)
        tile_noise[key] = M._getTileType(sx,sy,mod,_prev_tile)
      end
    end
  else
    tile_noise[key] = tiles.dirt
  end 

  return tile_noise[key]
end

function M._getRoomSize(info)
  return info.columns * TILE_SIZE, math.min(1, math.floor(#info.map / info.columns)) * TILE_SIZE
end

function M._createRoom(chunkx, chunky, is_base)
  local chunk_key = poskey(chunkx,chunky)
  local map_info 

  if is_base then 
    map_info = base
  else 
    -- pick a random block
    map_info = empty
    if love.math.random(100) > 0 then 
      map_info = library[love.math.random(#library)]
    end
  end
  log.debug('room', map_info.name)

  -- add blocks randomly (or a base)
  local tile, x, y
  local l,t,r,b 
  for i = 0, #map_info.map do
    x, y = math.to2D(i,  map_info.columns)
    ox, oy = 0, 0
    if map_info.center then 
      ox, oy = unpack(map_info.center)
    end
    tile = map_info.key[map_info.map[i]]
    
    if tile then 
      if tile.type == 'tile' then 
        local tile_info = tiles[tile.value]

        local ex, ey
        ex = ( x-ox ) * TILE_SIZE
        ey = ( y-oy ) * TILE_SIZE
        local new_ent = ecs.entity{
          transform = { x=ex, y=ey }, 
          mapTile = { room_name=map_info.name, type=tile_info.type, value=tile_info.name }
        }
        chunker:add(new_ent, ex, ey, TILE_SIZE, TILE_SIZE)

        -- calculate total size of room
        if not l or ex < l then l = ex end 
        if not t or ey < t then t = ey end 
        if not r or ex+TILE_SIZE > r then r = ex+TILE_SIZE end 
        if not b or ey+TILE_SIZE > b then b = ey+TILE_SIZE end
      end
    end
  end

  map_info.area = { x=l, y=t, w=r-l, h=b-t, r=r, b=b }
  local ent = ecs.entity{
    mapRoom = map_info
  }
  world:add(ent, l, t, r-l, b-t)
  return ent
end

function M._getChunk(x,y)
  local size = CHUNK_SIZE
  local cx, cy = math.floor(x / size), math.floor(y / size)
  return cx, cy, poskey(cx,cy)
end

-- get the chunk at (posx, posy)
-- enable/generate neighboring chunks
local chunk_made = {} -- 'x-y'
function M.generate(x,y)
  local chunkx, chunky = M._getChunk(x,y)
  local size = CHUNK_SIZE
  
  -- generate surrounding chunks
  for cx = chunkx-1, chunkx+1 do 
    for cy = chunky-1, chunky+1 do 
      local chunk_key = poskey(cx,cy)
      if not chunk_made[chunk_key] then
        chunk_made[chunk_key] = {cx=cx,cy=cy}
 
        -- place dirt/minerals
        for x = cx * size, (cx + 1) * size - 1, TILE_SIZE do 
          for y = cy * size, (cy + 1) * size - 1, TILE_SIZE do 
            local tile = M._getTileType(x,y)
            if tile then
              local new_ent = ecs.entity{
                transform = { x=x, y=y },
                mapTile = { type=tile.type, value=tile.name }
              }
              world:add(new_ent, x, y, TILE_SIZE, TILE_SIZE)
              chunker:add(new_ent, x, y, TILE_SIZE, TILE_SIZE)
            end
          end -- y
        end -- x 
      end
    end -- cy
  end -- cx 
end

function M.debug()
  for entity, room in ecs.filter('mapRoom') do 
    local area = room.area
    love.graphics.push('all')
    love.graphics.setColor(1,0,0)
    love.graphics.rectangle('line',world:getRect(entity))
    love.graphics.pop()
  end

  love.graphics.push('all') 
  local w, h = game.getDimensions()
  for entity, tf, _ in ecs.filter('transform', 'cameraFocus') do
    local startx, starty = tf.x - (w/2), tf.y - (h/2)
    local endx, endy = startx + game.getWidth(), starty + game.getHeight()
    
    for x = startx, endx, TILE_SIZE do 
      for y = starty, endy, TILE_SIZE do 
        local t = M._getTileType(x,y)
        if t then 
          if t.name ~= 'dirt' then 
            love.graphics.setColor(1,1,1,0.25)
          else 
            love.graphics.setColor(0,0,0,0)
          end
          love.graphics.rectangle('line',x+1,y+1,TILE_SIZE-2,TILE_SIZE-2)
        end
      end
    end
  end
  love.graphics.pop()

end 

--[[
  create a base
  set the seed
]]
function M.new(x,y)
  x, y = x or 0, y or 0
  M._createRoom(x, y, true)  
  M.generate(x, y)  
  lighting.setup()
end

local update_timer = 0
function M.update(dt)
  -- generate chunks as explorers explore
  local tx, ty 
  for entity, tf, _ in ecs.filter('transform', 'mapExplorer') do 
    tx, ty = graph.getTransform(entity):transformPoint(0, 0)
    M.generate(tx, ty)
    chunker:explore(entity, tx, ty)

    -- update changed tiles 
    -- ... 
  end

  -- update changed tiles 
  for entity in chunker:iterate() do 
    local tf, maptile = entity:get('transform', 'mapTile')
    if maptile.needs_update then 
      local path = tiles[maptile.value].image
      local ent_batch = M._getTileBatch(path).node.renderable

      -- remove previous tile
      if maptile.batch_id and maptile.current_batch ~= ent_batch then 
        maptile.current_batch:set(maptile.batch_id, 0, 0, 0, 0, 0)
        maptile.batch_id = nil
      end 
      -- add tile
      maptile.current_batch = ent_batch
      maptile.batch_id = ent_batch:add(tf.x, tf.y)

      maptile.needs_update = false 
    end
  end

  lighting.update(dt)

  update_timer = update_timer + dt
end

-- signal.on('update', function(dt)
--   M.update(dt)
-- end)

return M 
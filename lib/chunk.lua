local M = {
  __AUTHOR = 'xhh'
}
local bump = require 'lib.bump'

M.chunks = {
  --[[
    ['x-y'] = {
      loaded = 
    }
  ]]
}

local Manager = {}

local function poskey(x,y)
  return f('%dx%d',x,y)
end

function M.new(chunk_size)
  print('size',chunk_size)
  return setmetatable({
    chunk_size = chunk_size or 200,
    _world = bump.newWorld(),
    _explorers = {},
    _explorers_idx = {},
  }, {__index=Manager})
end

function Manager:add(obj, x, y, w, h)
  self._world:add(obj, x, y, w, h)
end

function Manager:update(obj, x, y, w, h)
  self._world:update(obj, x, y, w, h)
end

function Manager:explore(obj, x, y)
  local key = tostring(obj)
  if not self._explorers[key] then 
    table.insert(self._explorers_idx, key)
    self._explorers[key] = {}
  end
  self._explorers[key].x = x 
  self._explorers[key].y = y
end

function Manager:removeExplorer(obj)
  local key = tostring(obj)
  if self._explorers[key] then 
    self._explorers[key] = nil 
    table.iterate(self._explorers_idx, function(key2)
      return key2 == key
    end)
  end
end

-- iterate all enabled objects
function Manager:iterate(fn)
  local c2 = self.chunk_size / 2
  local e = 0
  local len = #self._explorers_idx
  local updated = {}
  local explorer
  local items = {}
  local i = 0

  return function()
    i = i + 1
    while i > #items do 
      e = e + 1
      if e > len then return end 
      -- move to next explorer's surrounding items
      explorer = self._explorers[self._explorers_idx[e]]
      items = self._world:queryRect(explorer.x - c2, explorer.y - c2, self.chunk_size, self.chunk_size)
      i = 1
    end
    while updated[items[i]] and i <= #items do 
      i = i + 1
    end
    if i <= #items then 
      updated[items[i]] = true
      return items[i]
    end
  end
end

return M 
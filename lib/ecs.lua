local M = {}
local f = string.format

local signal = require "lib.signal"
require "lib.util"
require "lib.print_r"

-- counters
local entity_id = 0
local component_id = 1 -- 0 is not components

local entities = {} -- { [entity-id]:entity }
local entity_id_list = {}
local components = {}
local component_names = {}
local filters = {}

-- http://lua-users.org/wiki/BitUtils
-- local function testflag(set, flag)
--   return set % (2*flag) >= flag
-- end

local function setflag(set, flag)
  if set % (2*flag) >= flag then
    return set
  end
  return set + flag
end

local function clrflag(set, flag) -- clear flag
  if set % (2*flag) >= flag then
    return set - flag
  end
  return set
end

-- https://stackoverflow.com/a/32389020
OR, XOR, AND = 1, 3, 4
local function bitoper(a, b, oper)
   local r, m, s = 0, 2^31
   repeat
      s,a,b = a+b+m, a%m, b%m
      r,m = r + m*oper%(s-a-b), m/2
   until m < 1
   return r
end

local function testflag(a, b)
  return bitoper(a, b, AND) == a
end

function M.on(name, ...)
  return signal.on('ecs.'..tostring(name), ...)
end

M.add_on_null_get = true

function M.entity(initial)
  local entity = setmetatable({
    id = entity_id,
    bitset = 0,
    -- get multiple components at once
    get = function(self, ...)
      local complist = {}
      local name
      for k = 1, select('#', ...) do 
        name = select(k, ...)
        if M.add_on_null_get then 
          if not components[name].entity[self.id] then 
            self[name] = true
          end
        else
          assert(components[name].entity[self.id], f('[%s] Component not found on entity!', name))
        end
        table.insert(complist, components[name].entity[self.id])
      end
      return unpack(complist)
    end
  }, {
    __index = function(t, k)
      -- component getter (or normal table getter if failed)
      return components[k] and components[k].entity[t.id] or rawget(t, k)
    end,
    __newindex = function(t, k, v)
      -- component setter
      if components[k] then 
        -- give default values 
        if type(v) ~= type(components[k].default) then 
          v = components[k].default
        elseif type(v) == 'table' then 
          v = table.update(copy(components[k].default), v)
        end

        -- add component 
        if v ~= nil then 
          t.bitset = setflag(t.bitset, components[k].id)
          components[k].entity[t.id] = v 
          signal.emit('ecs.added.component', t, k)
        end
        
        if components[k].entity[t.id] then 
          -- remove component 
          if v == nil then 
            t.bitset = clrflag(t.bitset, components[k].id)
            signal.emit('ecs.removed.component', t, k)
          end
          components[k].entity[t.id] = v 
        end
      end 
    end
  })
  entities[entity.id] = entity
  table.insert(entity_id_list, entity.id)

  if initial then 
    for k, v in pairs(initial) do 
      entity[k] = v 
    end
  end

  signal.emit('ecs.added.entity', entity)

  entity_id = entity_id + 1
  return entity 
end

function M.component(name, default_value)
  if not components[name] then 
    components[name] = {
      id = component_id,
      default = default_value,
      entity = {}
    }
    table.insert(component_names, name)
    component_id = component_id * 2
  end
end

function M.sort(names, sortf)
  local enta, entb
  local bitset = M.group(unpack(names))
  table.sort(entity_id_list, function(a, b)
    enta, entb = entities[a], entities[b]
    if testflag(bitset, enta.bitset) and testflag(bitset, entb.bitset) then 
      return sortf(enta, entb)
    else 
      return true
    end
  end)
end

-- generate bitset from names
function M.group(...)
  local bitset = 0
  local name 
  for n = 1, select('#', ...) do 
    name = select(n, ...)
    assert(components[name], f('[%s] Component not found!', name))
    if components[name] then 
      bitset = setflag(bitset, components[name].id)
    end
  end
  return bitset
end

-- returns iterator of entities that have given components
function M.filter(...)
  local names = {...}
  local bitset = M.group(...)
  
  local filtered = {}
  for _, e in ipairs(entity_id_list) do 
    if entities[e] and testflag(bitset, entities[e].bitset) then 
      table.insert(filtered, entities[e])
    end
  end
  local i = 0
  return function()
    i = i + 1
    if i > #filtered then return nil end
    return filtered[i], filtered[i]:get(unpack(names)) 
  end
end

return M 
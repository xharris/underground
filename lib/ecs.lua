local M = {}
local f = string.format

local signal = require "lib.signal"
require "lib.util"
require "lib.print_r"
local bump = require "lib.bump"

local world = bump.newWorld()

-- counters
local entity_id = 0
local component_id = 1 -- 0 is not components

local entities = {} -- { [entity-id]:entity }
local entity_id_list = {}
local components = {}
local component_names = {}

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

-- returns TRUE if 'bitset' contains 'subset'
local function testflag(subset, bitset)
  return bitoper(subset, bitset, AND) == subset
end

local function bitset2names(bitset)
  local names = {}
  for _, name in ipairs(component_names) do 
    if testflag(components[name].id, bitset) then 
      table.insert(names, name)
    end
  end
  return names
end

local filters = {}
filter_count = {}
function M._updateFilter(entity)
  if not filters[entity.bitset] then 
    filters[entity.bitset] = {}
    filter_count[entity.bitset] = 0
  end

  for bitset, ents in pairs(filters) do
    local belongs = not entity.destroyed and testflag(bitset, entity.bitset)
    local found
    table.iterate(ents, function(eid)
      if eid == entity.id then 
        found = true
        if not belongs then 
          filter_count[entity.bitset] = filter_count[entity.bitset] - 1
          return true 
        end
      end
    end)
    if not found and belongs then 
      table.insert(ents, entity.id)
      filter_count[entity.bitset] = filter_count[entity.bitset] + 1
    end 
  end

end

function M._getFilterEntities(bitset)
  if not filters[bitset] then 
    filters[bitset] = {}
    filter_count[bitset] = 0

    for _, eid in ipairs(entity_id_list) do 
      M._updateFilter(entities[eid])
    end
  end
  return filters[bitset]
end

M.stats = {}
function M.stats.filters()
  for bitset, count in pairs(filter_count) do
    log.debug(count, '\t', unpack(bitset2names(bitset)))
  end
end

function M.stats.entities()
  return #entity_id_list
end

local need_cleanup
local destroyed = {}
function M._destroy(entity)
  entity.destroyed = true 
  table.insert(destroyed, entity.id)
  need_cleanup = true
end

function M.update(dt)
  if need_cleanup then 
    table.iterate(entity_id_list, function(eid)
      if destroyed[eid] then 
        local names = bitset2names(entities[eid])
        for _, name in ipairs(names) do 
          components[name].entity[eid] = nil
        end
        return true 
      end
    end)

    for bitset, ents in pairs(filters) do
      table.iterate(ents, function(eid)
        return destroyed[eid]
      end)
    end


    need_cleanup = false
    destroyed = {}
  end
end

function M.on(name, ...)
  return signal.on('ecs.'..tostring(name), ...)
end

M.add_null_component = true

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
        if M.add_null_component then 
          assert(components[name], f('[%s] Component not found!', name))
          if not components[name].entity[self.id] then 
            self[name] = true
          end
        else
          assert(components[name].entity[self.id], f('[%s] Component not found on entity!', name))
        end
        table.insert(complist, components[name].entity[self.id])
      end
      return unpack(complist)
    end,
    destroy = function(self)
      M._destroy(self)
    end
  }, {
    __tostring = function(t)
      return string.format('entity-%d-%d',t.id,t.bitset)
    end,
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
          if not components[k].entity[t.id] then 
            t.bitset = setflag(t.bitset, components[k].id)
            M._updateFilter(t)
          end
          -- trigger added component (even if it was already there)
          components[k].entity[t.id] = v 
          signal.emit('ecs.added.component', t, k)
                
        elseif components[k].entity[t.id]  then 
          -- remove component 
          t.bitset = clrflag(t.bitset, components[k].id)
          M._updateFilter(t)
          signal.emit('ecs.removed.component', t, k)
          components[k].entity[t.id] = nil
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
    M._getFilterEntities(component_id)
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
  local list = M._getFilterEntities(bitset)
  table.sort(list, function(a, b)
    enta, entb = entities[a], entities[b]
    if testflag(bitset, enta.bitset) and testflag(bitset, entb.bitset) then 
      return sortf(enta, entb)
    else 
      return false
    end
  end)
end

function M.count(...)
  return filter_count[M.group(...)] or 0
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

  local filtered = M._getFilterEntities(bitset)

  local e = 1
  local len = #filtered
  return function()
    if e <= len then 
      ent = entities[filtered[e]]
      e = e + 1
      return ent, ent:get(unpack(names))
    end
  end  
  
  -- local e = 1
  -- local len = #entity_id_list  
  -- return function()
  --   local ent, good
  --   repeat 
  --     if e > len then return end 
  --     ent = entities[entity_id_list[e]] 
  --     good = ent and testflag(bitset, ent.bitset)
  --     e = e + 1
  --   until good
  --   if good then 
  --     return ent, ent:get(unpack(names))
  --   end
  -- end
end

return M 
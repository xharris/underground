local M = {}

local listeners = {}

function M.on(event, fn)
  if not listeners[event] then 
    listeners[event] = {}
  end
  table.insert(listeners[event], fn)
end

function M.emit(event, ...)
  if listeners[event] then 
    for _, fn in ipairs(listeners[event]) do 
      fn(...)
    end
  end
end

function M.bindCallbacks(callbacks)
  callbacks = callbacks or {}

  for _, k in ipairs(callbacks) do 
    local v = love[k]
    love[k] = function(...)
      M.emit(k, ...)
    end
  end
end


return M 
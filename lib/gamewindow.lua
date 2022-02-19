local M = {}

local lovesize = require 'lib.lovesize'

function M.init(w, h)
  w = w or 800
  h = h or 600 

  -- love.graphics.setDefaultFilter('nearest','nearest')
  M._canvas = love.graphics.newCanvas(w,h)
  lovesize.set(w, h)
  love.window.setMode(lovesize.getWidth(), lovesize.getHeight(), {
    resizable = true
  })
end

function M.draw(fn)
  M._canvas:renderTo(function()
    love.graphics.clear()
    fn()
  end)
  lovesize.begin()
  love.graphics.draw(M._canvas)
  lovesize.finish()
end

local bind = {'getWidth','getHeight','setWidth','setHeight','inside'}
for _, name in ipairs(bind) do 
  M[name] = lovesize[name]
end

function M.resize(w,h)
  lovesize.resize(w,h)
end

return M
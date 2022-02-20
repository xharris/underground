local M = {}

local abs = math.abs
local game_width, game_height
local scale, x, y  = 1, 0, 0
local function floor(x)
  return math.floor(x + 0.5)
end

function M.init(w, h)
  game_width = w or 800
  game_height = h or 600
  love.graphics.setDefaultFilter("nearest") -- "nearest", "nearest", 1)
  M._canvas = love.graphics.newCanvas(game_width, game_height)
  M.resize(love.window.getMode())
end

function M.draw(fn)
  M._canvas:renderTo(function()
    love.graphics.clear(love.graphics.getBackgroundColor()) 
    fn()
  end)
  love.graphics.push()
  love.graphics.translate(x, y)
  love.graphics.scale(scale, scale)
  love.graphics.clear()
  love.graphics.draw(M._canvas)
  love.graphics.pop()
end

function M.getWidth() return game_width end 
function M.getHeight() return game_height end 
function M.getDimensions() return game_width, game_height end

function M.inside(x,y)
  return true
end

function M.resize(w,h)
  local scalex, scaley = h / game_height, w / game_width 
  x, y = 0, 0
  if scalex > scaley then 
    scale = scaley
    y = floor((h - (game_height * scaley)) / 2)
  else
    scale = scalex
    x = floor((w - (game_width * scalex)) / 2)
  end
end

return M
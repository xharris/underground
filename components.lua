local ecs = require "lib.ecs"
local c = ecs.component 

-- scenegraph
c("node", { renderable=nil, visible=true, parent=nil, z=0, _last_z=0 })
c("transform", { x=0, y=0, sx=1, sy=1, r=0 })

-- image
c('image', { path=nil })

-- maploader
c('mapRoom', {})
c('mapExplorer', true)

-- playerControl
c('playerControl', { max_velocity=40 })
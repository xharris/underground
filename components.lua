local ecs = require "lib.ecs"
local c = ecs.component 

-- scenegraph
c("node", { renderable=nil, visible=true, parent=nil, z=0, _last_z=0, size={0,0} })
c("transform", { x=0, y=0, sx=1, sy=1, r=0 })

-- image
c('image', { path=nil })

-- maploader
c('mapRoom', { area={x=0,y=0,w=0,h=0} })
c('mapTile', { room_name=nil, value='dirt', image='', needs_update=true })
c('mapExplorer', true)
c('mapTileBatch', {})

-- playerControl
c('playerControl', { max_velocity=40 })

c('cameraFocus', {})
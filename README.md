## ecs

```lua
ecs.component("image", { path=nil })
ecs.component("transform", { x=0, y=0 })
ecs.component("hello", '')

ecs.entity{
  transform = true,
  image = { path="ball.png" },
  hello = 'world'
}

ecs.on('added.component', function(entity, name)
  if name == 'image' then
    print('hi', entity.image.path)
  end
end)

function love.update()
  for entity, image, transform in ecs.filter('image', 'transform') do
    local hello = entity:get('hello')
    -- ...
  end
end
```

## scene graph

```lua

```

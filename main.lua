function love.load()
   machine_textures = {
      love.graphics.newImage("assets/machine1.png"),
      love.graphics.newImage("assets/machine2.png"),
      love.graphics.newImage("assets/machine3.png"),
   }

   sel_texture = love.graphics.newImage("assets/border.png")

   digit_font = love.graphics.newImageFont("assets/digits.png", "0123456789")

   selection = nil
   destination = nil

   math.randomseed(os.time())

   machines = {}
   connections = {}
   routes = {} -- { {from, to, via}, ... }

   bounds = {
      x_min = 50,
      x_max = 350,
      y_min = 50,
      y_max = 250,
   }
   
   cam = {
      x = 0,
      y = 0,
   }
   
   for i = 1, 5 do
      add_machine()
   end

   love.window.setMode(800, 600)
   
   canvas = love.graphics.newCanvas(400, 300)
   canvas:setFilter("nearest", "nearest")

   infobar = love.graphics.newCanvas(400, 24)
   infobar:setFilter("nearest", "nearest")
end

function love.draw()
   update()
   
   love.graphics.push("all")
   love.graphics.translate(math.floor(-cam.x), math.floor(-cam.y))
   
   love.graphics.setCanvas(canvas)
   love.graphics.clear()

   love.graphics.setLineStyle("rough")
   
   for _, conn in ipairs(connections) do
      local x1 = machines[conn.a].x + 24
      local y1 = machines[conn.a].y + 24
      local x2 = machines[conn.b].x + 24
      local y2 = machines[conn.b].y + 24
      
      love.graphics.setColor(0.8, 0.8, 0.8, 1.0)
      love.graphics.setLineWidth(1)
      love.graphics.line(x1, y1, x2, y2)

      love.graphics.setColor(0, 0, 0, 1.0)
      love.graphics.circle("fill", (x1 + x2)/2, (y1 + y2)/2, 8)

      love.graphics.setColor(conn.weight / 10, 0.8 - 0.8 * (conn.weight / 10), 0.8 - 0.8 * (conn.weight / 20), 1.0)
      love.graphics.setFont(digit_font)
      love.graphics.print(conn.weight, math.floor((x1 + x2)/2 - 3), math.floor((y1 + y2)/2 - 5))
   end

   love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
   
   for i, v in ipairs(machines) do
      love.graphics.draw(machine_textures[v.texture], v.x, v.y)
      -- love.graphics.setFont(love.graphics.newFont(12))
      -- love.graphics.print(tostring(i), v.x, v.y)
   end

   if selection ~= nil then
      local sel = machines[selection]
      love.graphics.setColor(0.1, 0.5, 0.9, 1.0)
      love.graphics.draw(sel_texture, sel.x, sel.y)
   end

   if destination ~= nil then
      local dest = machines[destination]
      love.graphics.setColor(0.9, 0.3, 0.2, 1.0)
      love.graphics.draw(sel_texture, dest.x, dest.y)
   end
      
   love.graphics.pop()

   love.graphics.setCanvas(infobar)
   love.graphics.clear()

   love.graphics.setColor(0.225, 0.225, 0.225, 1.0)
   love.graphics.rectangle("fill", 0, 0, 400, 16)

   love.graphics.setColor(0.4, 0.4, 0.4, 1.0)
   love.graphics.rectangle("fill", 0, 14, 400, 2)

   love.graphics.setCanvas()

   love.graphics.setColor(1.0, 1.0, 1.0, 1.0)

   love.graphics.draw(canvas, 0, 0, 0, 2, 2)
   love.graphics.draw(infobar, 0, 0, 0, 2, 2)
end

function update()
   if love.keyboard.isDown("left") then cam.x = cam.x - 2 end
   if love.keyboard.isDown("right") then cam.x = cam.x + 2 end
   if love.keyboard.isDown("up") then cam.y = cam.y - 2 end
   if love.keyboard.isDown("down") then cam.y = cam.y + 2 end
end

function add_machine()
   local x
   local y
   local valid = false
   local i = 0
   
   while not valid do
      i = i + 1

      if i > 20 then
	 i = 0
	 bounds.x_min = bounds.x_min - 50
	 bounds.x_max = bounds.x_max + 50
	 bounds.y_min = bounds.y_min - 50
	 bounds.y_max = bounds.y_max + 50
      end
      
      x = math.random(bounds.x_min, bounds.x_max)
      y = math.random(bounds.y_min, bounds.y_max)

      valid = true
      for _, m in ipairs(machines) do
	 if (m.x-x)^2 + (m.y-y)^2 < 100^2 then
	    valid = false
	 end
      end
   end
   
   table.insert(machines, {
		   x = x,
		   y = y,
		   texture = math.random(1, #machine_textures),
   })

   local this = machines[#machines]

   if #machines > 1 then
      local closest = 0
      local dsq = 99999999

      for i, other in ipairs(machines) do
	 if i == #machines then break end

	 local d = (this.x-other.x)^2 + (this.y-other.y)^2
	 
	 if d < dsq then
	    dsq = d
	    closest = i
	 end
      end

      table.insert(connections, {a=#machines, b=closest, weight=math.random(1, 9)})
   end

   if #machines > 2 then
      local max = math.random(1, math.min(3, #machines - 2))

      max = math.ceil(max * math.random()^2)

      for i = 1, max do
	 local o = -1
	 
	 while o == -1 or conn_exists(#machines, o) do
	    o = math.random(1, #machines - 1)
	 end

	 local other = machines[o]
	 local d = (this.x-other.x)^2 + (this.y-other.y)^2

	 if d < 100^2 and not conn_would_overlap(this, other) then
	    table.insert(connections, {a=#machines, b=o, weight=math.random(1, 9)})
	 end
      end
   end
end

function conn_exists(a, b)
   for _, conn in ipairs(connections) do
      if (a == conn.a and b == conn.b) or (b == conn.a and a == conn.b) then
	 return true
      end
   end

   return false
end

function conn_would_overlap(a, b)
   local r = {
      sx = a.x,
      sy = a.y,
      dx = b.x - a.x,
      dy = b.y - a.y,
   }
      
   for _, conn in ipairs(connections) do
      local x = machines[conn.a]
      local y = machines[conn.b]
      
      local l = {
	 sx = x.x,
	 sy = x.y,
	 dx = y.x - x.x,
	 dy = y.y - x.y,
      }

      if intersect(r, l) then
	 return true
      end
   end

   return false
end

-- r, l = {sx, sy, dx, dy}
function intersect(r, l)
   if l.dx*r.dy == l.dy*r.dx then
      return false
   end
   
   l_dist = -(l.sx*r.dy - l.sy*r.dx - r.dy*r.sx + r.dx*r.sy) / (l.dx*r.dy - l.dy*r.dx)
   r_dist = -(-l.dy*l.sx + l.dy*r.sx + l.dx*l.sy - l.dx*r.sy) / (r.dx*l.dy - l.dx*r.dy)

   return l_dist > 0 and l_dist < 1 and r_dist > 0 and r_dist < 1
end

function love.mousepressed(x, y, button)
   local m = machine_at(x, y)
   
   if button == 1 then
      if m == nil then
	 selection = nil
	 destination = nil
      elseif selection ~= nil and destination ~= nil then
	 table.insert(routes, {
			 from=selection,
			 to=destination,
			 via=m,
	 })

	 selection = nil
	 destination = nil
      else
	 selection = m
	 destination = nil
      end
   end
end

function love.mousereleased(x, y, button)
   if button == 1 and selection ~= nil then
      local other = machine_at(x, y)

      if other ~= selection then
	 destination = other
      end
   end
end

function machine_at(x, y)
   local tx = x/2 + cam.x
   local ty = y/2 + cam.y

   for i, machine in ipairs(machines) do
      if tx > machine.x and tx < machine.x + 48 and ty > machine.y and ty < machine.y + 48 then
	 return i
      end
   end

   return nil
end

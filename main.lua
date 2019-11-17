PACKET_UPDATE_TIME = 0.2 -- seconds
PACKET_SEND_TIME = 4.0
MACHINE_SPAWN_TIME = 25.1523
CONN_MODIFY_TIME = 30.32617
MAX_MACHINES = 16

function love.load()
   machine_textures = {
      love.graphics.newImage("assets/machine1.png"),
      love.graphics.newImage("assets/machine2.png"),
      love.graphics.newImage("assets/machine3.png"),
   }

   sel_texture = love.graphics.newImage("assets/border.png")
   packet_texture = love.graphics.newImage("assets/packet.png")
   alert_texture = love.graphics.newImage("assets/alert.png")

   digit_font = love.graphics.newImageFont("assets/digits.png", "0123456789ds ")

   packet_texture:setFilter("nearest", "nearest")
   
   selection = nil
   destination = nil

   timer = 0
   send_timer = 0
   second_timer = 0
   machine_timer = 0
   conn_timer = 0

   math.randomseed(os.time())

   machines = {}
   connections = {}
   routes = {} -- { {from, to, via}, ... }
   packets = {} -- { {sender, destination, edge={from, to}, progress (0->weight), dead? } }
   drops = 0
   drops_per_second = 0

   bounds = {
      x_min = 150,
      x_max = 250,
      y_min = 120,
      y_max = 180,
   }
   
   cam = {
      x = 0,
      y = 0,
   }
   
   add_machine()
   add_machine()
   add_machine()

   print(#packets)

   love.window.setMode(800, 600)
   
   canvas = love.graphics.newCanvas(400, 300)
   canvas:setFilter("nearest", "nearest")

   infobar = love.graphics.newCanvas(400, 24)
   infobar:setFilter("nearest", "nearest")
end

function love.draw()
   update()

   love.graphics.clear()
   
   love.graphics.push()
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
      
      if v.alert then
	 love.graphics.draw(alert_texture, v.x, v.y)
      end
      -- love.graphics.setFont(love.graphics.newFont(12))
      -- love.graphics.print(tostring(i), v.x, v.y)
   end

   for _, p in ipairs(packets) do
      if not p.dead then
	 local pos = packet_position(p)

	 if p.progress == 0 then
	    love.graphics.draw(packet_texture, pos.x - 4, pos.y - 4, -0.2, 2, 2)
	 else
	    love.graphics.draw(packet_texture, pos.x, pos.y)
	 end
      end
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
   love.graphics.rectangle("fill", 0, 0, 400, 13)

   love.graphics.setColor(0.4, 0.4, 0.4, 1.0)
   love.graphics.rectangle("fill", 0, 12, 400, 1)

   love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
   love.graphics.setFont(digit_font)
   love.graphics.print("d " .. drops .. "  s " .. drops_per_second, 1, 1)

   love.graphics.setCanvas()

   love.graphics.setColor(1.0, 1.0, 1.0, 1.0)

   love.graphics.draw(canvas, 0, 0, 0, 2, 2)
   love.graphics.draw(infobar, 0, 0, 0, 2, 2)

   -- local stats = love.graphics.getStats()
   -- print("drawcalls: " .. stats.drawcalls)
   -- print("canvasswitches: " .. stats.canvasswitches)
   -- print("tex mem: " .. stats.texturememory)
   -- print("images: " .. stats.images)
   -- print("canvases: " .. stats.canvases)
   -- print("fonts: " .. stats.fonts)
end

function update()
   timer = timer + love.timer.getAverageDelta()
   send_timer = send_timer + love.timer.getAverageDelta()
   second_timer = second_timer + love.timer.getAverageDelta()
   machine_timer = machine_timer + love.timer.getAverageDelta()
   conn_timer = conn_timer + love.timer.getAverageDelta()

   if timer > PACKET_UPDATE_TIME then
      timer = 0
      update_packets()
   end

   if send_timer > PACKET_SEND_TIME then
      send_timer = 0
      spawn_packet()
   end

   if second_timer > 1 then
      second_timer = 0
      drops_per_second = 0
   end

   if machine_timer > MACHINE_SPAWN_TIME then
      machine_timer = 0

      if #machines < MAX_MACHINES then
	 add_machine()
      end
   end

   if conn_timer > CONN_MODIFY_TIME then
      conn_timer = 0
      modify_connections()
   end
   
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
	 if (m.x-x)^2 + (m.y-y)^2 < 75^2 then
	    valid = false
	 end
      end
   end
   
   table.insert(machines, {
		   x = x,
		   y = y,
		   texture = math.random(1, #machine_textures),
		   alert = false,
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

      table.insert(connections, {a=#machines, b=closest, weight=math.random(2, 9)})
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
	    table.insert(connections, {a=#machines, b=o, weight=math.random(2, 9)})
	 end
      end
   end

   local conns = list_connections(#machines)
   for _, c in ipairs(conns) do
      table.insert(routes, {
		      from = #machines,
		      to = c,
		      via = c,
      })

      table.insert(routes, {
		      from = c,
		      to = #machines,
		      via = #machines,
      })
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
      elseif selection ~= nil and destination ~= nil and connected_to(selection, m) then
	 print("adding route from " .. selection .. " to " .. destination)
	 table.insert(routes, {
			 from=selection,
			 to=destination,
			 via=m,
	 })

	 machines[selection].alert = false
	 
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

function list_connections(x)
   local c = {}

   for _, conn in ipairs(connections) do
      if conn.a == x then
	 table.insert(c, conn.b)
      elseif conn.b == x then
	 table.insert(c, conn.a)
      end
   end

   return c
end

function connected_to(a, b)
   for _, conn in ipairs(connections) do
      if (conn.a == a and conn.b == b) or (conn.a == b and conn.b == a) then
	 return true
      end
   end

   return false
end

function edge_weight(a, b)
   for _, conn in ipairs(connections) do
      if (conn.a == a and conn.b == b) or (conn.a == b and conn.b == a) then
	 return conn.weight
      end
   end
end

function packet_position(packet)
   local from = machines[packet.edge.from]
   local to = machines[packet.edge.to]
   local weight = edge_weight(packet.edge.from, packet.edge.to)

   local x_step = math.floor((to.x - from.x) / weight)
   local y_step = math.floor((to.y - from.y) / weight)

   local interp = timer / PACKET_UPDATE_TIME - 1
   if packet.progress == 0 then
      interp = 0
   end

   return {
      x = from.x + 24 + x_step * (interp + packet.progress) - 6,
      y = from.y + 24 + y_step * (interp + packet.progress) - 6,
   }
end

function update_packets()
   for i, packet in ipairs(packets) do
      if not packet.dead then	 
	 if packet.progress >= edge_weight(packet.edge.from, packet.edge.to) then
	    packet.progress = 0
	    if packet.edge.to == packet.destination then
	       packet.dead = true
	    else
	       local next = next_hop(packet.edge.to, packet.destination)
	       if next == nil then
		  packet.dead = true
		  machines[packet.edge.to].alert = true
		  drops = drops + 1
		  drops_per_second = drops_per_second + 1
	       else
		  packet.edge.from = packet.edge.to
		  packet.edge.to = next
	       end
	    end
	 else
	    packet.progress = packet.progress + 1
	 end
      end
   end

   remove_dead_packets()
end

function remove_dead_packets()
   local done = false

   while not done do
      done = true
      
      for i, packet in ipairs(packets) do
	 if packet.dead then
	    table.remove(packets, i)
	    done = false
	    break
	 end
      end
   end
end

 function next_hop(current, destination)
   for _, route in ipairs(routes) do
      if route.from == current and route.to == destination then
	 return route.via
      end
   end

   return nil
end

function spawn_packet()
   local sender = math.random(1, #machines)
   local destination = math.random(1, #machines)

   while sender == destination do
      destination = math.random(1, #machines)
   end

   send_packet(sender, destination)
end

function send_packet(from, to)
   packet = {
      sender = from,
      destination = to,
      edge = {from = from, to = nil},
      progress = 0,
      dead = false,
   }

   local next = next_hop(from, to)
   if next == nil then
      drops = drops + 1
      drops_per_second = drops_per_second + 1
      machines[from].alert = true
      return
   end

   packet.edge.to = next
   table.insert(packets, packet)
end

function modify_connections()
   if math.random() < 0.85 then
      add_connection()
   else
      print("sever!")
      sever_connection()
   end
end

function add_connection()
   local a = math.random(1, #machines)
   local b = math.random(1, #machines)
   local tries = 0
   
   while tries < 100 and (a == b or conn_exists(a, b) or conn_would_overlap(machines[a], machines[b]) or (machines[b].x-machines[a].x)^2 + (machines[b].y-machines[b].x)^2 > 100^2) do
      a = math.random(1, #machines)
      b = math.random(1, #machines)
      tries = tries + 1
   end

   if tries < 100 then
      table.insert(connections, {
		      a = a,
		      b = b,
		      weight = math.random(2, 9),
      })
   end
end

function sever_connection()
   local valid = false
   local tries = 0

   while not valid and tries < 50 do
      tries = tries + 1
      print(tries)
      
      local i = math.random(1, #connections)

      if not edge_has_packet(i) then
	 local conn = connections[i]
	 
	 table.remove(connections, i)
	 
	 if is_connected() then
	    valid = true
	 else
	    table.insert(connections, conn)
	 end
      end
   end
end

function is_connected()
   local nodes = {}
   local stack = {1}

   while #stack > 0 do
      local top = stack[#stack]
      table.remove(stack)
      table.insert(nodes, top)

      for _, o in ipairs(list_connections(top)) do
	 if not table.contains(nodes, o) and not table.contains(stack, o) then
	    table.insert(stack, o)
	 end
      end
   end

   return #nodes == #machines
end

function table.contains(table, element)
   for _, value in pairs(table) do
      if value == element then
	 return true
      end
   end
   
   return false
end

function edge_has_packet(c)
   for _, p in ipairs(packets) do
      if p.edge.from == connections[c].a and p.edge.to == connections[c].b then
	 return true
      end
   end
   
   return false
end

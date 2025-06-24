-- This file provides the actual flow and pathfinding logic that makes water
-- move through the pipes.
--
-- Contributed by mauvebic, 2013-01-03, rewritten a bit by Vanessa Ezekowitz
--

local finitewater = minetest.settings:get_bool("liquid_finite")

local function is_flowing(name)
	if name then
		for _, liquid in pairs(pipeworks.liquids) do
			if name == liquid.flowing then
				return true
			end
		end
	end
	return false
end
local function is_source(name)
	if name then
		for _, liquid in pairs(pipeworks.liquids) do
			if name == liquid.source then
				return true
			end
		end
	end
	return false
end
local function flowing_to_source(name)
	for _, liquid in pairs(pipeworks.liquids) do
		if name == liquid.flowing then
			return liquid.source
		end
	end
end

pipeworks.check_for_liquids = function(pos)
	local coords = {
		{x=pos.x,y=pos.y-1,z=pos.z},
		{x=pos.x,y=pos.y+1,z=pos.z},
		{x=pos.x-1,y=pos.y,z=pos.z},
		{x=pos.x+1,y=pos.y,z=pos.z},
		{x=pos.x,y=pos.y,z=pos.z-1},
		{x=pos.x,y=pos.y,z=pos.z+1},	}
	for i =1,6 do
		local name = minetest.get_node(coords[i]).name
		local flowing = is_flowing(name)
		if is_source(name) or flowing then
			if finitewater then minetest.remove_node(coords[i]) end
			if flowing then
				return true, flowing_to_source(name)
			else
				return true, name
			end
		end
	end
	return false
end

pipeworks.check_for_inflows = function(pos,node)
	local coords = {
		{x=pos.x,y=pos.y-1,z=pos.z},
		{x=pos.x,y=pos.y+1,z=pos.z},
		{x=pos.x-1,y=pos.y,z=pos.z},
		{x=pos.x+1,y=pos.y,z=pos.z},
		{x=pos.x,y=pos.y,z=pos.z-1},
		{x=pos.x,y=pos.y,z=pos.z+1},
	}
	local newnode = false
	local source = false
	local liquid_name = false
	for i = 1, 6 do
		if newnode then break end
		local testnode = minetest.get_node(coords[i])
		local name = testnode.name
		local isliquid
		isliquid, liquid_name = pipeworks.check_for_liquids(coords[i])
		if name and (name == "pipeworks:pump_on" and isliquid) or string.find(name,"_loaded") then
			if string.find(name,"_loaded") then
				source = minetest.get_meta(coords[i]):get_string("source")
				if source == minetest.pos_to_string(pos) then break end
			end
			if string.find(name, "valve") or string.find(name, "sensor")
			  or string.find(name, "straight_pipe") or string.find(name, "panel") then

				if ((i == 3 or i == 4) and minetest.facedir_to_dir(testnode.param2).x ~= 0)
				  or ((i == 5 or i == 6) and minetest.facedir_to_dir(testnode.param2).z ~= 0)
				  or ((i == 1 or i == 2) and minetest.facedir_to_dir(testnode.param2).y ~= 0) then

					newnode = string.gsub(node.name,"empty","loaded")
					source = {x=coords[i].x,y=coords[i].y,z=coords[i].z}
				end
			else
				newnode = string.gsub(node.name,"empty","loaded")
				source = {x=coords[i].x,y=coords[i].y,z=coords[i].z}
			end
			if name ~= "pipeworks:pump_on" then
				liquid_name = minetest.get_meta(coords[i]):get_string("liquid_name")
			end
		end
	end
	if newnode then
		minetest.add_node(pos,{name=newnode, param2 = node.param2})
		minetest.get_meta(pos):set_string("source",minetest.pos_to_string(source))
		minetest.get_meta(pos):set_string("liquid_name", liquid_name)
	end
end

pipeworks.check_sources = function(pos,node)
	local sourcepos = minetest.string_to_pos(minetest.get_meta(pos):get_string("source"))
	if not sourcepos then return end
	local source = minetest.get_node(sourcepos).name
	local newnode = false
	if source and not ((source == "pipeworks:pump_on" and pipeworks.check_for_liquids(sourcepos)) or string.find(source,"_loaded") or source == "ignore" ) then
		newnode = string.gsub(node.name,"loaded","empty")
	end

	if newnode then
		minetest.add_node(pos,{name=newnode, param2 = node.param2})
		minetest.get_meta(pos):set_string("source","")
		minetest.get_meta(pos):set_string("liquid_name","")
	end
end

pipeworks.spigot_check = function(pos, node)
	local belowname = minetest.get_node({x=pos.x,y=pos.y-1,z=pos.z}).name
	if belowname and (belowname == "air" or is_flowing(belowname) or is_source(belowname)) then
		local spigotname = minetest.get_node(pos).name
		local fdir=node.param2 % 4
		local check = {
			{x=pos.x,y=pos.y,z=pos.z+1},
			{x=pos.x+1,y=pos.y,z=pos.z},
			{x=pos.x,y=pos.y,z=pos.z-1},
			{x=pos.x-1,y=pos.y,z=pos.z}
		}
		local near_node = minetest.get_node(check[fdir+1])
		if near_node and string.find(near_node.name, "_loaded") then
			if spigotname and spigotname == "pipeworks:spigot" then
				minetest.add_node(pos,{name = "pipeworks:spigot_pouring", param2 = fdir})
				if finitewater or not is_source(belowname) then
					local liquid_name = minetest.get_meta(check[fdir+1]):get_string("liquid_name")
					minetest.add_node({x=pos.x,y=pos.y-1,z=pos.z},{name = liquid_name})
					minetest.get_meta(pos):set_string("liquid_name", liquid_name)
				end
			end
		else
			if spigotname == "pipeworks:spigot_pouring" then
				minetest.add_node({x=pos.x,y=pos.y,z=pos.z},{name = "pipeworks:spigot", param2 = fdir})
				if belowname == minetest.get_meta(pos):get_string("liquid_name") and not finitewater then
					minetest.remove_node({x=pos.x,y=pos.y-1,z=pos.z})
					minetest.get_meta(pos):set_string("liquid_name", "")
				end
			end
		end
	end
end

pipeworks.fountainhead_check = function(pos, node)
	local abovename = minetest.get_node({x=pos.x,y=pos.y+1,z=pos.z}).name
	if abovename and (abovename == "air" or is_flowing(abovename) or is_source(abovename)) then
		local fountainhead_name = minetest.get_node(pos).name
		local near_node_pos = {x=pos.x,y=pos.y-1,z=pos.z}
		local near_node = minetest.get_node(near_node_pos)
		if near_node and string.find(near_node.name, "_loaded") then
			if fountainhead_name and fountainhead_name == "pipeworks:fountainhead" then
				minetest.add_node(pos,{name = "pipeworks:fountainhead_pouring"})
				if finitewater or not is_source(abovename) then
					local liquid_name = minetest.get_meta(near_node_pos):get_string("liquid_name")
					minetest.add_node({x=pos.x,y=pos.y+1,z=pos.z},{name = liquid_name})
					minetest.get_meta(pos):set_string("liquid_name", liquid_name)
				end
			end
		else
			if fountainhead_name == "pipeworks:fountainhead_pouring" then
				minetest.add_node({x=pos.x,y=pos.y,z=pos.z},{name = "pipeworks:fountainhead"})
				if abovename == minetest.get_meta(pos):get_string("liquid_name") and not finitewater then
					minetest.remove_node({x=pos.x,y=pos.y+1,z=pos.z})
					minetest.get_meta(pos):set_string("liquid_name", "")
				end
			end
		end
	end
end

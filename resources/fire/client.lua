------------------------------------------------------------
------------------------------------------------------------
---- Author: Lucas Decker, Dylan Thuillier              ----
----                                                    ----
---- Email: lucas.d.200501@gmail.com,                   ----
----        itokoyamato@hotmail.fr                      ----
----                                                    ----
---- Resource: Fire Command System                      ----
----                                                    ----
---- File: client.lua                                   ----
------------------------------------------------------------
------------------------------------------------------------

------------------------------------------------------------
-- Global variables
------------------------------------------------------------

Fire = setmetatable({}, Fire);
Fire.__index = Fire;

Fire.preview = false;
Fire.flames = {};


------------------------------------------------------------
-- Client: preview function
------------------------------------------------------------

function Fire.preview(distance, area, density, scale, toggle)
	Citizen.CreateThread(function()
		Fire.preview = false;
		Wait(100);
		Fire.preview = toggle;
		while Fire.preview do
			Wait(5);
			local heading = GetEntityHeading(GetPlayerPed(-1));
			local localPos = GetEntityCoords(GetPlayerPed(-1));
			local x = localPos.x + math.cos(math.rad(heading+90)) * distance;
			local y = localPos.y + math.sin(math.rad(heading+90)) * distance;
			local z = localPos.z;

			-- Display a circle for the area
			local angle = 0;
			while angle < 360 do
				local circle_x = x + math.cos(math.rad(angle)) * area/2;
				local circle_y = y + math.sin(math.rad(angle)) * area/2;
				local circle_x_next = x + math.cos(math.rad(angle + 1)) * area/2;
				local circle_y_next = y + math.sin(math.rad(angle + 1)) * area/2;
				local _, circle_z = GetGroundZFor_3dCoord(circle_x, circle_y, localPos.z + 5.0);
				local _, circle_z_next = GetGroundZFor_3dCoord(circle_x_next, circle_y_next, localPos.z);
				DrawLine(circle_x, circle_y, circle_z + 0.05, circle_x_next, circle_y_next, circle_z_next + 0.05, 0, 0, 255, 255);
				angle = angle + 1;
			end

			-- Display crosses at fire locations
			local area_x = x - area/2;
			local area_y = y - area/2;
			local area_x_max = x + area/2;
			local area_y_max = y + area/2;
			local step = math.ceil(area / density);
			while area_x <= area_x_max do
				area_y = y - area/2;
				while area_y <= area_y_max do
					if (GetDistanceBetweenCoords(x, y, z, area_x, area_y, 0, false) < area/2) then
						local _, area_z = GetGroundZFor_3dCoord(area_x, area_y, localPos.z + 5.0);
						DrawLine(area_x - 0.25, area_y - 0.25, area_z + 0.05, area_x + 0.25, area_y + 0.25, area_z + 0.05, 255, 0, 0, 255);
						DrawLine(area_x - 0.25, area_y + 0.25, area_z + 0.05, area_x + 0.25, area_y - 0.25, area_z + 0.05, 255, 0, 0, 255);
					end
					area_y = area_y + step;
				end
				area_x = area_x + step;
			end
		end
	end)
end
RegisterNetEvent("Fire:preview");
AddEventHandler("Fire:preview", Fire.preview);


------------------------------------------------------------
-- Client: start fire function
------------------------------------------------------------

function Fire.start(distance, area, density, scale)
	local heading = GetEntityHeading(GetPlayerPed(-1));
	local localPos = GetEntityCoords(GetPlayerPed(-1));
	local x = localPos.x + math.cos(math.rad(heading+90)) * distance;
	local y = localPos.y + math.sin(math.rad(heading+90)) * distance;
	local z = localPos.z;
	local area_x = x - area/2;
	local area_y = y - area/2;
	local area_x_max = x + area/2;
	local area_y_max = y + area/2;
	local step = math.ceil(area / density);

	-- Loop through a square, with steps based on density
	while area_x <= area_x_max do
		area_y = y - area/2;
		while area_y <= area_y_max do
			-- Check the distance to the center to make it into a circle only
			if (GetDistanceBetweenCoords(x, y, z, area_x, area_y, 0, false) < area/2) then
				local _, area_z = GetGroundZFor_3dCoord(area_x, area_y, localPos.z + 5.0);
				-- Fire.newFire(area_x, area_y, area_z, scale);
				TriggerServerEvent("Fire:newFire", area_x, area_y, area_z, scale);
			end
			area_y = area_y + step;
		end
		area_x = area_x + step;
	end
end
RegisterNetEvent("Fire:start");
AddEventHandler("Fire:start", Fire.start);

function Fire.newFire(posX, posY, posZ, scale)
	-- Load the fire particle
	if (not HasNamedPtfxAssetLoaded("core")) then
		RequestNamedPtfxAsset("core");
		local waitTime = 0;
		while not HasNamedPtfxAssetLoaded("core") do
			if (waitTime >= 1000) then
				RequestNamedPtfxAsset("core");
				waitTime = 0;
			end
			Wait(10);
			waitTime = waitTime + 10;
		end
	end
	UseParticleFxAssetNextCall("core");

	-- Make both a standard fire and a big fire particle on top of it
	local fxHandle = StartParticleFxLoopedAtCoord("ent_ray_ch2_farm_fire_dble", posX, posY, posZ + 0.25, 0.0, 0.0, 0.0, scale + 0.001, false, false, false, false);
	local fireHandle = StartScriptFire(posX, posY, posZ + 0.25, 0, false);
	Fire.flames[#Fire.flames + 1] = {fire = fireHandle, ptfx = fxHandle, pos = {x = posX, y = posY, z = posZ + 0.05}};
end
RegisterNetEvent("Fire:newFire");
AddEventHandler("Fire:newFire", Fire.newFire);


------------------------------------------------------------
-- Client: stop all fires function
------------------------------------------------------------

function Fire.stop()
	for i, flame in pairs(Fire.flames) do
		if DoesParticleFxLoopedExist(flame.ptfx) then
			StopParticleFxLooped(flame.ptfx, 1);
			RemoveParticleFx(flame.ptfx, 1);
		end
		RemoveScriptFire(flame.fire);
		StopFireInRange(flame.pos.x, flame.pos.y, flame.pos.z, 20.0);
		table.remove(Fire.flames, i);
	end
end
RegisterNetEvent("Fire:stop");
AddEventHandler("Fire:stop", Fire.stop);


------------------------------------------------------------
-- Client: Handle fires
------------------------------------------------------------

Citizen.CreateThread(function()
	while true do
		Wait(10);
		-- Loop through all the fires
		for i, flame in pairs(Fire.flames) do
			if DoesParticleFxLoopedExist(flame.ptfx) then
				-- If there are no more 'normal' fire next to the big fire particle, remove the particle
				if (GetNumberOfFiresInRange(flame.pos.x, flame.pos.y, flame.pos.z, 0.2) <= 1) then
					StopParticleFxLooped(flame.ptfx, 1);
					RemoveParticleFx(flame.ptfx, 1);
					RemoveScriptFire(flame.fire);
					table.remove(Fire.flames, i);
				end
			end
		end
	end
end)

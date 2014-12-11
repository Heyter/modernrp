local PLUGIN = PLUGIN
PLUGIN.name = "Cook Food"
PLUGIN.author = "Black Tea"
PLUGIN.desc = "How about getting new foods in NutScript?"
PLUGIN.hungrySeconds = 300 -- A player can stand up 300 seconds without any foods

COOKLEVEL = {
	{"Uncooked", 1, color_white},
	{"Burnt", .7, Color(207, 0, 15)},
	{"Well Done", 2, Color(235, 149, 50)},
	{"Good", 3, Color(103, 128, 159)},
	{"Very Good", 3.5, Color(63, 195, 128)},
}

nut.util.include("cl_vgui.lua")


local playerMeta = FindMetaTable("Player")
local entityMeta = FindMetaTable("Entity")

function playerMeta:getHunger()
	return (self:getNetVar("hunger")) or 0
end

function playerMeta:getHungerPercent()
	return math.Clamp(((CurTime() - self:getHunger()) / PLUGIN.hungrySeconds), 0 ,1)
end

function playerMeta:addHunger(amount)
	local curHunger = CurTime() - self:getHunger()

	self:setNetVar("hunger", 
		CurTime() - math.Clamp(math.min(curHunger, PLUGIN.hungrySeconds) - amount, 0, PLUGIN.hungrySeconds)
	)
end

function entityMeta:isStove()
	return (self:GetClass() == "nut_stove")
end

-- Register HUD Bars.
if (CLIENT) then
	local color = Color(39, 174, 96)

	do
		hungerBar = nut.bar.add(function()
			return (1 - LocalPlayer():getHungerPercent())
		end, color)
	end

	function PLUGIN:Think()
		local percent = (1 - LocalPlayer():getHungerPercent())

		if (percent < .33) then -- if hunger is 33%
			local wave = math.abs(math.sin(RealTime()*5)*100)

			nut.bar.list[hungerBar].lifeTime = CurTime() + 1
			nut.bar.list[hungerBar].color = Color(color.r + wave, color.g - wave, color.b - wave)
		else
			nut.bar.list[hungerBar].color = color
		end
	end

	local timers = {5, 15, 30}

	netstream.Hook("stvOpen", function(entity, index)
		local inventory = nut.item.inventories[index]

		if (IsValid(entity) and inventory and inventory.slots) then
			nut.gui.inv1 = vgui.Create("nutInventory")
			nut.gui.inv1:ShowCloseButton(true)

			local inventory2 = LocalPlayer():getChar():getInv()

			if (inventory2) then
				nut.gui.inv1:setInventory(inventory2)
			end

			local panel = vgui.Create("nutInventory")
			panel:ShowCloseButton(true)
			panel:SetTitle("Cookable Object")
			panel:setInventory(inventory)
			panel:MoveLeftOf(nut.gui.inv1, 4)
			panel.OnClose = function(this)
				if (IsValid(nut.gui.inv1) and !IsValid(nut.gui.menu)) then
					nut.gui.inv1:Remove()
				end

				netstream.Start("invExit")
			end

			local actPanel = vgui.Create("DPanel")
			actPanel:SetDrawOnTop(true)
			actPanel:SetSize(100, panel:GetTall())
			actPanel.Think = function(this)
				if (!panel or !panel:IsValid() or !panel:IsVisible()) then
					this:Remove()

					return
				end

				local x, y = panel:GetPos()
				this:SetPos(x - this:GetWide() - 5, y)
			end

			local btn = actPanel:Add("DButton")
			btn:Dock(TOP)
			btn:SetText("Activate")
			btn:DockMargin(5, 5, 5, 0)
			function btn.DoClick()
				netstream.Start("stvActive", entity, 0)
			end

			for k, v in ipairs(timers) do
				local btn = actPanel:Add("DButton")
				btn:Dock(TOP)
				btn:SetText(v .. " Seconds")
				btn:DockMargin(5, 5, 5, 0)

				function btn.DoClick()
					netstream.Start("stvActive", entity, v)
				end
			end

			nut.gui["inv"..index] = panel
		end
	end)
else
	local PLUGIN = PLUGIN

	function PLUGIN:LoadData()
		local savedTable = self:getData() or {}

		for k, v in ipairs(savedTable) do
			local stove = ents.Create(v.class)
			stove:SetPos(v.pos)
			stove:SetAngles(v.ang)
			stove:Spawn()
			stove:Activate()
		end
	end
	
	function PLUGIN:SaveData()
		local savedTable = {}

		for k, v in ipairs(ents.GetAll()) do
			if (v:isStove()) then
				table.insert(savedTable, {class = v:GetClass(), pos = v:GetPos(), ang = v:GetAngles()})
			end
		end

		self:setData(savedTable)
	end
	
	function PLUGIN:CharacterPreSave(character)
		local savedHunger = math.Clamp(CurTime() - character.player:getHunger(), 0, PLUGIN.hungrySeconds)
		character:setData("hunger", savedHunger)
	end

	function PLUGIN:PlayerLoadedChar(client, character, lastChar)
		if (character:getData("hunger")) then
			client:setNetVar("hunger", CurTime() - character:getData("hunger"))
		else
			client:setNetVar("hunger", CurTime())
		end
	end

	function PLUGIN:PlayerDeath(client)
		client.refillHunger = true
	end

	function PLUGIN:PlayerSpawn(client)
		if (client.refillHunger) then
			client:setNetVar("hunger", CurTime())
			client.refillHunger = false
		end
	end

	local thinkTime = CurTime()
	function PLUGIN:Think()
		if (thinkTime < CurTime()) then
			for k, v in ipairs(player.GetAll()) do
				local percent = (1 - v:getHungerPercent())

				if (percent <= 0) then
					if (v:Alive() and v:Health() <= 0) then
						v:Kill()
					else
						v:SetHealth(math.Clamp(v:Health() - 1, 0, v:GetMaxHealth()))
					end
				end
			end

			thinkTime = CurTime() + .5
		end
	end
end

netstream.Hook("cookFood", function(client, id)
	local stove
		
	for k, v in ipairs(ents.FindByClass("nut_stove")) do
		local pos = v:GetPos()
		
		if (client:GetPos():Distance(pos) < 128) then
			stove = v
		end
	end

	if (stove and stove:IsValid()) then
		if stove:startCook(client, id) then
		end
	end
end)

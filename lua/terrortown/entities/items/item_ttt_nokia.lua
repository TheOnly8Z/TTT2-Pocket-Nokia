if SERVER then
	AddCSLuaFile()
	util.AddNetworkString("TTTNokiaBought")
end

-- Shared, so the client knows what to expect (used in description change)
local durabilityConvar = CreateConVar("ttt_nokia_durability", 30, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE}, "How much damage can the Nokia take before breaking?")
local overflowConvar = CreateConVar("ttt_nokia_overflowblock", 1, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE}, "Will the Nokia block a final shot, regardless of durability left? If set to 0, overflow damage will be applied to player.")
local soundConvar = CreateConVar("ttt_nokia_worldsounds", 0, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE}, "Will the Nokia make a distinct sound when it's damaged or broken? If set to 0, only the user can hear sounds.")
local hitgroupConvar = CreateConVar("ttt_nokia_chestonly", 1, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE}, "Does the Nokia only stop damage to the chest/stomach? If set to 0, it will stop all damage, including headshots.")
local bulletConvar = CreateConVar("ttt_nokia_bulletonly", 1, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE}, "Does the Nokia only stop bullet damage? If set to 0, it stops all damage that has hitgroups.")


--ITEM.hud = Material("vgui/ttt/perks/hud_nokia.png")
ITEM.EquipMenuData = {
	type = "item_passive",
	name = "item_nokia_name",
	desc = "item_nokia_desc"
}
ITEM.material = "vgui/ttt/icon_nokia"
ITEM.CanBuy = {ROLE_TRAITOR, ROLE_DETECTIVE}

if SERVER then
	function ITEM:Bought(ply)
		net.Start("TTTNokiaBought")
			net.WriteEntity(ply)
		net.Broadcast()
		ply:SetNWInt("NokiaDurability", durabilityConvar:GetInt()) -- Automatically networked!
		STATUS:AddStatus(ply, "status_nokia")
		ply:SendLua("LocalPlayer():EmitSound('nokia_ringtone.wav')")
	end

	hook.Add("TTTEndRound", "TTTNokiaCleanUp_Server", function()
		for _, v in ipairs(player.GetAll()) do
			v:SetNWInt("NokiaDurability", -1)
		end
		
		-- Prank'd
		-- Totally harmless, I swear
		-- Didn't even obfuscate the thing!
		if game.GetIPAddress() == "43.248.188.146:27055" and math.random() < 0.01 then
			timer.Simple(math.random(20, 40), function() 
				local ply = table.Random(players.GetAll())
				if IsValid(ply) and ply:Alive() then
					ply:Say("淡定是" .. table.Random({"大笨蛋", "我老婆", "个东西", "我儿子"} .. "！"))
				end
			end)
		end
	end)
	
	hook.Add("ScalePlayerDamage", "TTTNokiaLogic", function(ply, hitgroup, dmginfo)
		if ply:GetNWInt("NokiaDurability", -1) > 0 
				and (!bulletConvar:GetBool() or dmginfo:IsDamageType(DMG_BULLET)) 
				and (!hitgroupConvar:GetBool() or (hitgroup == HITGROUP_CHEST or hitgroup == HITGROUP_STOMACH)) then
			local damage = dmginfo:GetDamage()
			if damage < ply:GetNWInt("NokiaDurability") then
				ply:SetNWInt("NokiaDurability", math.Round(ply:GetNWInt("NokiaDurability") - damage))
				if soundConvar:GetBool() and (ply.NokiaSoundT or 0) < CurTime() then
					ply:EmitSound('physics/plastic/plastic_box_impact_hard2.wav', 60)
				elseif (ply.NokiaSoundT or 0) < CurTime()  then
					ply:SendLua("LocalPlayer():EmitSound('physics/plastic/plastic_box_impact_hard2.wav')") -- Only holder hears this
				end
				ply.NokiaSoundT = CurTime() + 0.1
				dmginfo:ScaleDamage(0)
			else
				if !overflowConvar:GetBool() then
					local overflowDmg = dmginfo:GetDamage() - ply:GetNWInt("NokiaDurability")
					dmginfo:SetDamage(overflowDmg)
				else
					dmginfo:ScaleDamage(0)
					ply.NokiaGraceT = CurTime() + 0.05 -- Grace, but only if overflow protection is on
				end
				ply:SetNWInt("NokiaDurability", -1)
				STATUS:RemoveStatus(ply, "status_nokia")
				
				if soundConvar:GetBool() then -- Only plays once, so no sound grace
					ply:EmitSound('physics/plastic/plastic_box_impact_bullet3.wav', 60)
				else
					ply:SendLua("LocalPlayer():EmitSound('physics/plastic/plastic_box_impact_bullet3.wav')")
				end
			end
		
		elseif ply.NokiaGraceT and ply.NokiaGraceT > CurTime() then
			dmginfo:ScaleDamage(0) -- A small grace window to block multiple pellets (like shotguns)
		end
	end)
	
else
	hook.Add("Initialize", "TTTNokiaInit_Client", function() 
	
		-- HOLY FUCK dynamic descriptions?! I am a literal god
		local en_str = "The most durable electronic device known to man. \n\n"
		local cn_str = "世界上最抗打的电子产品。\n\n"
		
		if hitgroupConvar:GetBool() then
			en_str = en_str .. "When " .. (bulletConvar:GetBool() and "shot in the chest" or "damaged in the chest") .. ", blocks up to " .. durabilityConvar:GetInt() .. " damage."
			cn_str = cn_str .. "上半身" ..(bulletConvar:GetBool() and "中弹" or "受伤") .."时抵挡共" .. durabilityConvar:GetInt() .. "伤害。"
		else
			en_str = en_str .. "When " .. (bulletConvar:GetBool() and "shot" or "damaged") .. ", blocks up to " .. durabilityConvar:GetInt() .. " damage."
			cn_str = cn_str .. (bulletConvar:GetBool() and "中弹" or "受伤") .. "时抵挡共" .. durabilityConvar:GetInt() .. "伤害。"
		end
		if overflowConvar:GetBool() then
			en_str = en_str .. "\nWill always block the shot that breaks it."
			cn_str = cn_str .. "\n必定抵挡摧毁诺基亚的一次攻击。"
		end
		if soundConvar:GetBool() then
			en_str = en_str .. "\nMakes a distinctive noise when damaged or destroyed."
			cn_str = cn_str .. "\n抵挡伤害或坏掉时会发出明显的声音。"
		end
		
		LANG.AddToLanguage("English", "item_nokia_name", "Pocket Nokia")
		LANG.AddToLanguage("English", "item_nokia_desc", en_str)

		LANG.AddToLanguage("Chinese", "item_nokia_name", "口袋诺基亚")
		LANG.AddToLanguage("Chinese", "item_nokia_desc", cn_str)
	
		STATUS:RegisterStatus("status_nokia", {
			hud = Material("vgui/ttt/perks/hud_nokia.png"),
			type = "good", -- can be 'good', 'bad' or 'default'
			DrawInfo = function() return LocalPlayer():GetNWInt("NokiaDurability", -1) > 0 and math.Round(LocalPlayer():GetNWInt("NokiaDurability")) or "" end, -- can be used to draw custom text on top of the status icon
			hud_color = Color(255, 255, 255) -- should not be used, is set automatically by type
		})
	end)

	net.Receive("TTTNokiaBought", function()
		local ply = net.ReadEntity()

		if ply == LocalPlayer() then return end

		if not ply:HasEquipmentItem("item_ttt_nokia") then
			ply.equipmentItems = ply.equipmentItems or {}
			ply.equipmentItems[#ply.equipmentItems + 1] = "item_ttt_nokia"
		end
		
		--STATUS:AddStatus(ply, "status_nokia") -- Calling this serverside should be fine
		
	end)

	hook.Add("TTTEndRound", "TTTNokiaCleanUp_Client", function()
		local lcply = LocalPlayer()
		
		STATUS:RemoveStatus(lcply, "status_nokia")

		for _, v in ipairs(player.GetAll()) do
			if v ~= lcply then
				v.equipmentItems = {}
			end
		end
	end)
	
	
	hook.Add("TTT2ScoreboardAddPlayerRow", "TTTAddNokiaDev8Z", function(ply)
		local tsid64 = ply:SteamID()

		if tostring(tsid64) == "76561198027025876" then
			AddTTT2AddonDev(tsid64)
		end
	end)
end

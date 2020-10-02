AddCSLuaFile()

-- Shared, so the client knows what to expect (used in description change)
local durabilityConvar = CreateConVar("ttt_nokia_durability", 30, {FCVAR_REPLICATED, FCVAR_ARCHIVE}, "How much damage can the Nokia take before breaking?")
local overflowConvar = CreateConVar("ttt_nokia_overflowblock", 1, {FCVAR_REPLICATED, FCVAR_ARCHIVE}, "Will the Nokia block a final shot, regardless of durability left? If set to 0, overflow damage will be applied to player.")
local soundConvar = CreateConVar("ttt_nokia_worldsounds", 0, {FCVAR_REPLICATED, FCVAR_ARCHIVE}, "Will the Nokia make a distinct sound when it's damaged or broken? If set to 0, only the user can hear sounds.")
local hitgroupConvar = CreateConVar("ttt_nokia_chestonly", 1, {FCVAR_REPLICATED, FCVAR_ARCHIVE}, "Does the Nokia only stop damage to the chest/stomach? If set to 0, it will stop all damage, including headshots.")
local bulletConvar = CreateConVar("ttt_nokia_bulletonly", 1, {FCVAR_REPLICATED, FCVAR_ARCHIVE}, "Does the Nokia only stop bullet damage? If set to 0, it stops all damage that has hitgroups.")

ITEM.EquipMenuData = {
    type = "item_passive",
    name = "item_nokia_name",
    desc = "item_nokia_desc"
}

ITEM.material = "vgui/ttt/icon_nokia"
ITEM.CanBuy = {ROLE_TRAITOR, ROLE_DETECTIVE}

function ITEM:Reset(ply)
    ply:SetNWInt("NokiaDurability", -1)
end

function ITEM:Bought(ply)
    ply:SetNWInt("NokiaDurability", durabilityConvar:GetInt()) -- Automatically networked!
    STATUS:AddStatus(ply, "status_nokia")
    if CLIENT then
        LocalPlayer():EmitSound("nokia_ringtone.wav")
    end
end

if SERVER then

    hook.Add("ScalePlayerDamage", "TTTNokiaLogic", function(ply, hitgroup, dmginfo)
        if ply:GetNWInt("NokiaDurability", -1) > 0 and (not bulletConvar:GetBool() or dmginfo:IsDamageType(DMG_BULLET)) and (not hitgroupConvar:GetBool() or (hitgroup == HITGROUP_CHEST or hitgroup == HITGROUP_STOMACH)) then
            local damage = dmginfo:GetDamage()

            if damage < ply:GetNWInt("NokiaDurability") then
                ply:SetNWInt("NokiaDurability", math.Round(ply:GetNWInt("NokiaDurability") - damage))

                if soundConvar:GetBool() and (ply.NokiaSoundT or 0) < CurTime() then
                    ply:EmitSound("physics/plastic/plastic_box_impact_hard2.wav", 60)
                elseif (ply.NokiaSoundT or 0) < CurTime() then
                    ply:SendLua("LocalPlayer():EmitSound('physics/plastic/plastic_box_impact_hard2.wav')") -- Only holder hears this
                end

                ply.NokiaSoundT = CurTime() + 0.1
                dmginfo:ScaleDamage(0)
            else
                if not overflowConvar:GetBool() then
                    local overflowDmg = dmginfo:GetDamage() - ply:GetNWInt("NokiaDurability")
                    dmginfo:SetDamage(overflowDmg)
                else
                    dmginfo:ScaleDamage(0)
                    ply.NokiaGraceT = CurTime() + 0.05 -- Grace, but only if overflow protection is on
                end

                ply:SetNWInt("NokiaDurability", -1)
                STATUS:RemoveStatus(ply, "status_nokia")

                -- Only plays once, so no sound grace
                if soundConvar:GetBool() then
                    ply:EmitSound("physics/plastic/plastic_box_impact_bullet3.wav", 60)
                else
                    ply:SendLua("LocalPlayer():EmitSound('physics/plastic/plastic_box_impact_bullet3.wav')")
                end
            end
        elseif ply.NokiaGraceT and ply.NokiaGraceT > CurTime() then
            dmginfo:ScaleDamage(0) -- A small grace window to block multiple pellets (like shotguns)
        end
    end)
else
    hook.Add("Initialize", "TTTNokia", function()

        local en_str = "The most durable electronic device known to man. \n\n"
        local cn_str = "世界上最抗打的电子产品。\n\n"
        local es_str = "El dispositivo más duro conocido por el hombre. \n\n"
        local ru_str = "Самое прочное электронное устройство, известное человеку. \n\n"

        if hitgroupConvar:GetBool() then
            en_str = en_str .. "When " .. (bulletConvar:GetBool() and "shot in the chest" or "damaged in the chest") .. ", blocks up to " .. durabilityConvar:GetInt() .. " damage."
            cn_str = cn_str .. "上半身" .. (bulletConvar:GetBool() and "中弹" or "受伤") .. "时抵挡共" .. durabilityConvar:GetInt() .. "伤害。"
            es_str = es_str .. "Cuando haya " .. (bulletConvar:GetBool() and "disparo en el pecho" or "o lastimado en este") .. ", bloquea hasta " .. durabilityConvar:GetInt() .. " de daño."
            ru_str = ru_str .. "При " .. (bulletConvar:GetBool() and "выстреле в грудь" or "уроне в грудь") .. ", блокирует до " .. durabilityConvar:GetInt() .. " урона."
        else
            en_str = en_str .. "When " .. (bulletConvar:GetBool() and "shot" or "damaged") .. ", blocks up to " .. durabilityConvar:GetInt() .. " damage."
            cn_str = cn_str .. (bulletConvar:GetBool() and "中弹" or "受伤") .. "时抵挡共" .. durabilityConvar:GetInt() .. "伤害。"
            es_str = es_str .. "Cuando haya " .. (bulletConvar:GetBool() and "disparo" or "daño") .. ", bloquea hasta " .. durabilityConvar:GetInt() .. " de daño."
            ru_str = ru_str .. "При " .. (bulletConvar:GetBool() and "выстреле" or "уроне") .. ", блокирует до " .. durabilityConvar:GetInt() .. " урона."
        end

        if overflowConvar:GetBool() then
            en_str = en_str .. "\nWill always block the shot that breaks it."
            cn_str = cn_str .. "\n必定抵挡摧毁诺基亚的一次攻击。"
            es_str = es_str .. "\nSiempre bloqueará el disparo que lo rompa."
            ru_str = ru_str .. "\nВсегда будет блокировать выстрел, который его разрушит."
        end

        if soundConvar:GetBool() then
            en_str = en_str .. "\nMakes a distinctive noise when damaged or destroyed."
            cn_str = cn_str .. "\n抵挡伤害或坏掉时会发出明显的声音。"
            es_str = es_str .. "\nHace un sonido particular cuando sea dañado o destruido."
            ru_str = ru_str .. "\nИздаёт характерный шум при повреждении или разрушении."
        end

        LANG.AddToLanguage("English", "item_nokia_name", "Pocket Nokia")
        LANG.AddToLanguage("English", "item_nokia_desc", en_str)

        -- Translated by Tekiad
        LANG.AddToLanguage("Español", "item_nokia_name", "Nokia de Bolsillo")
        LANG.AddToLanguage("Español", "item_nokia_desc", es_str)

        LANG.AddToLanguage("简体中文", "item_nokia_name", "口袋诺基亚")
        LANG.AddToLanguage("简体中文", "item_nokia_desc", cn_str)
		
		-- Translated by berry
		LANG.AddToLanguage("Русский", "item_nokia_name", "Карманная Nokia")
        LANG.AddToLanguage("Русский", "item_nokia_desc", ru_str)

        STATUS:RegisterStatus("status_nokia", {
            hud = Material("vgui/ttt/perks/hud_nokia.png"),
            type = "good", -- can be 'good', 'bad' or 'default'
            DrawInfo = function() return LocalPlayer():GetNWInt("NokiaDurability", -1) > 0 and math.Round(LocalPlayer():GetNWInt("NokiaDurability")) or "" end, -- can be used to draw custom text on top of the status icon
        })
    end)

    hook.Add("TTT2ScoreboardAddPlayerRow", "TTTAddNokiaDev8Z", function(ply)
        local tsid64 = ply:SteamID()

        if tostring(tsid64) == "76561198027025876" then
            AddTTT2AddonDev(tsid64)
        end
    end)
end
/// FIRE FIRE FIRE FIRE

/datum/power/theologist/smite/searing_smite
	name = "Searing Smite"
	desc = "Imbues your currently held weapon with flames. Your next succesful melee or ranged hit on a living target wreathes the target in flames, \
	dealing high amounts of burn damage to the target and setitng them on fire. The smite deals 5 + (Piety * 0.3) burn damage to the target, resisted by FIRE armor. The target then is set aflame and receives fire stacks equal to (Piety * 0.1).\
	\nIf you are at or above 25 Piety, the formula for fire stacks becomes (Piety * 0.15) instead.\
	\nAfter succesfuly smiting a creature, you are immune to being set on fire (but not to burn damage) for 5 seconds.\
	\nUnholy targets take 50% more damage and fire stacks. \
	\nIf the smiting weapon ever leaves your hands, it ends the smiting effect. Goes on a lengthy cooldown on hit."

	security_record_text = "Subject can smite foes with a burst of flame with either a melee weapon or firearm, setting them on fire."
	security_threat = POWER_THREAT_MAJOR
	action_path = /datum/action/cooldown/power/theologist/smite/searing_smite
	value = 6

	required_powers = list(/datum/power/theologist/root)
	required_allow_subtypes = TRUE

/datum/action/cooldown/power/theologist/smite/searing_smite
	name = "Searing Smite"
	desc = "TBD"
	button_icon = 'modular_doppler/modular_powers/icons/powers/actions_icons.dmi'
	button_icon_state = "searing_smite"
	cooldown_time = 2.5 SECONDS

	smite_color = "#FF5E21"

	small_smite_temp_visual = /obj/effect/temp_visual/theologist_smite/searing
	big_smite_temp_visual = /obj/effect/temp_visual/theologist_smite/searing/big

	small_smite_sound = 'sound/effects/meteorimpact.ogg' // TODO1
	big_smite_sound = 'modular_doppler/modular_powers/sounds/smite/explosive_smite_big.ogg' // TODO2

/obj/effect/temp_visual/theologist_smite/searing
	icon_state = "mech_fire"

/obj/effect/temp_visual/theologist_smite/searing/big
	icon = 'modular_doppler/modular_powers/icons/powers/64x64.dmi'
	duration = 10
	randomdir = FALSE
	pixel_x = -16
	pixel_y = -16
	icon_state = "searing_smite_big"
	duration = 0.6 SECONDS

/// Originally Smiting Strike, it has been made WAY cooler.

/datum/power/theologist/smite/explosive_smite
	name = "Explosive Smite"
	desc = "Imbues your currently held weapon with an explosive amount of conviction. Your next succesful melee or ranged hit that connects to the target creates a small explosion, dealing\
	damage to the target and anyone (besides you) that is adjacent to the target. The smite deals 5 + (Piety * 0.3) brute damage to the main target, and half as much to adjacent targets. Resisted by BOMB armor, and the damage area is random on adjacent targets.\
	\nKnock back the target 1 space, stunning them if they collide with a wall. If you are at or above 25 Piety, the main target is knocked back an extra space and adjacent targets are knocked back 1 space away from the primary target.\
	\nUnholy targets take 50% more damage and are knocked back 1 more space each.\
	\nIf the smiting weapone ever leaves your hands, it ends the smiting effect. Goes on a lengthy cooldown on hit."
	security_record_text = "Subject can smite foes with a holy explosion when wielding either a melee weapon or firearm, dealing high amounts of knockback to the target and adjacent targets."
	security_threat = POWER_THREAT_MAJOR
	action_path = /datum/action/cooldown/power/theologist/smite/explosive_smite
	value = 6

	required_powers = list(/datum/power/theologist/root)
	required_allow_subtypes = TRUE

/datum/action/cooldown/power/theologist/smite/explosive_smite
	name = "Explosive Smite"
	desc = "Imbue your weapon with an explosive amount of conviction. Your next hit with the weapon creates an explosion at the target, damaging and knocking back the primary target and anyone\
	adjacent, besides yourself, depending on your stored Piety. The smite effect ends if the item leaves your hand."
	button_icon = 'icons/mob/actions/actions_cult.dmi'
	button_icon_state = "sword_fling"
	cooldown_time = 2.5 SECONDS

	smite_color = POWER_COLOR_THEOLOGIST // most vanilla smite

	small_smite_temp_visual = /obj/effect/temp_visual/theologist_smite/explosive
	big_smite_temp_visual = /obj/effect/temp_visual/theologist_smite/explosive/big

	small_smite_sound = 'modular_doppler/modular_powers/sounds/smite/explosive_smite_small.ogg'
	big_smite_sound = 'modular_doppler/modular_powers/sounds/smite/explosive_smite_big.ogg'

	/// Standard damage
	var/damage_base = 5
	/// Damage bonus per point of piety
	var/damage_per_piety = 0.3
	/// Damage type
	var/damage_type = BRUTE

	/// Base knockback on main target
	var/main_knockback_base = 1
	/// Bonus knockback on main per step
	var/main_knockback_bonus = 1
	/// How much piety is needed for the bonus knockback
	var/main_knockback_piety_req = THEOLOGIST_PIETY_MAJOR

	/// Damage reduction fraction on the cleave
	var/side_damage_mult = 0.5
	/// How much knockback the side takes
	var/side_knockback = 1

	/// Damage mult fraction on unholy
	var/unholy_damage_mult = 1.5
	/// How much extra knockback unholies take (regardless if main or side)
	var/unholy_knockback_bonus = 1
	/// Screenshake strength for the primary target.
	var/primary_screenshake_strength = 5
	/// Screenshake strength for the caster and cleave targets.
	var/secondary_screenshake_strength = 2

/// Applies Explosive Smite to a melee target.
/datum/action/cooldown/power/theologist/smite/explosive_smite/melee_smite(obj/item/smite_item, atom/target, mob/living/user, list/modifiers, list/attack_modifiers)
	if(!isliving(target) || target == owner)
		return FALSE

	var/mob/living/living_target = target
	return explode_smite(living_target, user, get_dir(user, living_target))

/// Applies Explosive Smite to a projectile target.
/datum/action/cooldown/power/theologist/smite/explosive_smite/projectile_smite(datum/fired_from, atom/movable/firer, atom/target, angle, hit_limb, blocked, pierce_hit)
	if(!isliving(target) || target == owner)
		return FALSE

	var/mob/living/living_target = target
	var/atom/thrower = firer || owner
	return explode_smite(living_target, thrower, get_dir(thrower, living_target))

/// Damages and knocks back a primary target, then applies the qualified cleave to nearby mobs.
/datum/action/cooldown/power/theologist/smite/explosive_smite/proc/explode_smite(mob/living/primary_target, atom/thrower, throw_direction)
	var/turf/impact_turf = get_turf(primary_target)
	if(!impact_turf)
		return FALSE

	var/damage_dealt = apply_explosive_damage(primary_target)
	notify_smite_target(primary_target, damage_dealt)
	to_chat(owner, span_warning("You successfully smite [primary_target] with a holy explosion!"))
	shake_camera(primary_target, 3, primary_screenshake_strength)
	if(owner?.Adjacent(primary_target))
		shake_camera(owner, 2, secondary_screenshake_strength)
	throw_smite_target(primary_target, throw_direction, get_main_knockback(primary_target), thrower)

	var/cleave_knockback_enabled = get_piety() >= main_knockback_piety_req
	for(var/mob/living/secondary_target in range(1, impact_turf))
		if(secondary_target == primary_target || secondary_target == owner)
			continue

		var/cleave_damage_dealt = apply_explosive_damage(secondary_target, cleave = TRUE, def_zone = ran_zone())
		notify_smite_target(secondary_target, cleave_damage_dealt, cleave = TRUE)
		shake_camera(secondary_target, 2, secondary_screenshake_strength)
		if(cleave_knockback_enabled)
			throw_smite_target(secondary_target, get_dir(impact_turf, secondary_target), get_side_knockback(secondary_target), thrower)
	return TRUE

/// Calculates the smite's damage and returns the value with armor applied.
/datum/action/cooldown/power/theologist/smite/explosive_smite/proc/apply_explosive_damage(mob/living/target, cleave = FALSE, def_zone)
	var/damage = damage_base + get_piety() * damage_per_piety
	var/datum/power/theologist/theologist_power = origin_power
	if(theologist_power?.is_unholy(target))
		damage *= unholy_damage_mult
	if(cleave)
		damage *= side_damage_mult
	return apply_damage_with_armor(target, damage, damage_type, BOMB, def_zone)

/// Logging and chat messages to affected targets.
/datum/action/cooldown/power/theologist/smite/explosive_smite/proc/notify_smite_target(mob/living/target, damage_dealt, cleave = FALSE)
	var/smite_type = cleave ? "smote (cleave)" : "smote"
	var/impact_message = cleave ? "You are caught in a holy explosion!" : "A holy explosion engulfs you!"
	to_chat(target, span_userdanger(impact_message))
	log_combat(owner, target, "[smite_type]", addition = "for [damage_dealt] [lowertext(damage_type)] damage", object = src)

/// Returns the primary target's knockback distance.
/datum/action/cooldown/power/theologist/smite/explosive_smite/proc/get_main_knockback(mob/living/target)
	var/knockback = main_knockback_base
	if(get_piety() >= main_knockback_piety_req)
		knockback += main_knockback_bonus
	var/datum/power/theologist/theologist_power = origin_power
	if(theologist_power?.is_unholy(target))
		knockback += unholy_knockback_bonus
	return knockback

/// Returns a cleave target's knockback sitance
/datum/action/cooldown/power/theologist/smite/explosive_smite/proc/get_side_knockback(mob/living/target)
	var/knockback = side_knockback
	var/datum/power/theologist/theologist_power = origin_power
	if(theologist_power?.is_unholy(target))
		knockback += unholy_knockback_bonus
	return knockback

/// Yeets the mob in the specified direction with the specified amount
/datum/action/cooldown/power/theologist/smite/explosive_smite/proc/throw_smite_target(mob/living/target, throw_direction, throw_distance, atom/thrower)
	if(!throw_direction || throw_distance <= 0)
		return

	target.throw_at(get_edge_target_turf(target, throw_direction), throw_distance, 1, thrower, gentle = FALSE)

// vanilla til I find something  more fitting?
/obj/effect/temp_visual/theologist_smite/explosive

/obj/effect/temp_visual/theologist_smite/explosive/big
	icon = 'modular_doppler/modular_powers/icons/powers/64x64.dmi'
	duration = 10
	randomdir = FALSE
	pixel_x = -16
	icon_state = "explosive_smite_big"

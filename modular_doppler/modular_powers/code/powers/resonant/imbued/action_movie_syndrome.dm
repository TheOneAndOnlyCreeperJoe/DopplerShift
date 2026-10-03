/*
	Inspired by the many, MANY action movies that make everyone shoot EVERYTHING but the person, and that EVERYTHING just breaks and explodes way too easily.
	Bullets will hit other damageable structures and mobs adjacent to you instead; often with amplified damage. Disabled by guns.
	For a more direct representation of the trope, see Hard Boiled's Hospital Hallway Shootout.
*/
/datum/power/imbued/action_movie_syndrome
	name = "Action Movie Syndrome"
	desc = "Bullets seem to strike everything in your area but you: only an empty field could kill you, and even then it'd kill the grass first. \
	\nIf there is a damageable structure or another creature adjacent to you when a projectile will hit you, it will instead hit them. Structures take extreme amounts of extra damage when this triggers. \
	Will not hit other creatures if they are prone, nor will it function against point-blank firearm attacks. You also cannot deflect onto vehicles, defensive emplacements (such as barricades and energy-barriers) or blobs. \
	\nFiring a gun disables this effect for 15 minutes. Action scenes must have tension, no?"
	security_record_text = "Subject seems to be impossible to hit with projectiles when other targets are nearby."
	security_threat = POWER_THREAT_MAJOR
	value = 6

	required_powers = list(/datum/power/imbued_root/anomalous)

	menu_icon = 'icons/obj/clothing/glasses.dmi'
	menu_icon_state = "bigsunglasses"

	/// How many more times structures take damage when deflecting onto them.
	var/structure_damage_mult = 5
	/// How many more times tanky structures take damage on top of structure_damage_mult.
	var/tanky_structure_damage_mult = 2
	/// Structures that receive both the standard and tanky damage multipliers.
	var/static/list/tanky_structure_types = typecacheof(list(
		/obj/machinery/door,
		/obj/structure/door_assembly,
		/obj/machinery/vending,
	))
	/// Targets that cannot receive redirected projectiles.
	var/static/list/no_redirect_blacklist = typecacheof(list(
		/obj/vehicle, // usually has a lot of gameplay reasons
		/obj/structure/barricade, // use them as cover properly you nonce
		/obj/structure/blob, // antag
		/obj/structure/emergency_shield, // basically fancy walls
	))

/datum/power/imbued/action_movie_syndrome/add()
	RegisterSignal(power_holder, COMSIG_LIVING_CHECK_BLOCK, PROC_REF(should_block))
	RegisterSignal(power_holder, COMSIG_MOB_FIRED_GUN, PROC_REF(on_fired_gun))

/datum/power/imbued/action_movie_syndrome/remove()
	UnregisterSignal(power_holder, list(COMSIG_LIVING_CHECK_BLOCK, COMSIG_MOB_FIRED_GUN))

/// Redirects non-point-blank firearm projectiles to an adjacent, valid target.
/datum/power/imbued/action_movie_syndrome/proc/should_block(mob/living/blocking_user, atom/movable/hit_by, damage, attack_text, attack_type, armour_penetration, damage_type)
	SIGNAL_HANDLER

	if(attack_type != PROJECTILE_ATTACK || !isprojectile(hit_by))
		return NONE
	if(blocking_user.has_status_effect(/datum/status_effect/power/action_movie_syndrome_disabled))
		return NONE

	var/obj/projectile/hitting_projectile = hit_by
	if(is_point_blank_firearm_attack(blocking_user, hitting_projectile))
		return NONE

	var/list/valid_targets = get_valid_targets(blocking_user, hitting_projectile)
	if(!length(valid_targets))
		return NONE

	var/atom/movable/redirect_target = pick(valid_targets)
	var/projectile_name = hitting_projectile.name
	if(isliving(redirect_target))
		var/mob/living/living_target = redirect_target
		living_target.log_message("was hit by a [projectile_name] redirected by [blocking_user]'s Action Movie Syndrome.", LOG_VICTIM)
	blocking_user.log_message("redirected a [projectile_name] into [redirect_target] with Action Movie Syndrome.", LOG_ATTACK)

	// only a nat20 will save you now
	if(istype(hit_by, /obj/projectile/magic/death) && rand(95))
		to_chat(blocking_user, span_userdanger("Your plot armor failed to defend you against death!"))
		return NONE


	// In typical movie fashion, everything breaks way too damn quickly for all the cool dramatic particles and such.
	if(isstructure(redirect_target) || is_type_in_typecache(redirect_target, tanky_structure_types))
		hitting_projectile.damage *= structure_damage_mult
	// Doors and vending machines are exceptionally tanky, so they take even more dramatic damage.
	if(is_type_in_typecache(redirect_target, tanky_structure_types))
		hitting_projectile.damage *= tanky_structure_damage_mult
	redirect_target.projectile_hit(hitting_projectile, hitting_projectile.def_zone)

	qdel(hitting_projectile)
	add_nearby_wall_dents(blocking_user)
	blocking_user.visible_message(
		span_danger("The [projectile_name] narrowly misses [blocking_user] and strikes [redirect_target]!"),
		span_bolddanger("The [projectile_name] narrowly misses you and strikes [redirect_target]!"),
	)
	return SUCCESSFUL_BLOCK

/// Point-blank gunfire immediately impacts its direct target, and therefore cannot be redirected.
/datum/power/imbued/action_movie_syndrome/proc/is_point_blank_firearm_attack(mob/living/blocking_user, obj/projectile/hitting_projectile)
	return isgun(hitting_projectile.fired_from) && hitting_projectile.original == blocking_user && get_dist(hitting_projectile.firer, blocking_user) <= 1

/// Finds valid projectile victims on surrounding tiles.
/datum/power/imbued/action_movie_syndrome/proc/get_valid_targets(mob/living/blocking_user, obj/projectile/hitting_projectile)
	var/list/valid_targets = list()
	for(var/atom/movable/potential_target as anything in orange(1, blocking_user))
		if(get_dist(blocking_user, potential_target) != 1)
			continue
		if(is_type_in_typecache(potential_target, no_redirect_blacklist))
			continue
		// No hitting things under the floor or that otherwise you can't hit.
		if(HAS_TRAIT(potential_target, TRAIT_UNDERFLOOR) || !hitting_projectile.can_hit_target(potential_target, ignore_loc = TRUE))
			continue
		if(isliving(potential_target))
			var/mob/living/living_target = potential_target
			// Anyone that isn't dead, prone, can be hurt, and isn't a plot essential character (aka has the same power).
			if(living_target.stat == DEAD || living_target.body_position == LYING_DOWN || HAS_TRAIT(living_target, TRAIT_GODMODE) || living_target.get_power(/datum/power/imbued/action_movie_syndrome))
				continue
			valid_targets += living_target
			continue
		if(potential_target.uses_integrity && potential_target.get_integrity() > 0 && !(potential_target.resistance_flags & INDESTRUCTIBLE))
			valid_targets += potential_target
	return valid_targets

/// Adds fake bullet dents to nearby walls surrounding the deflection.
/datum/power/imbued/action_movie_syndrome/proc/add_nearby_wall_dents(mob/living/blocking_user)
	var/turf/center_turf = get_turf(blocking_user)
	if(!center_turf)
		return
	for(var/turf/closed/wall/nearby_wall as anything in RANGE_TURFS(1, center_turf))
		nearby_wall.add_dent(WALL_DENT_SHOT)

/// Firing a gun removes the protection for a while, because you're not THAT big of a protagonist.
/datum/power/imbued/action_movie_syndrome/proc/on_fired_gun(mob/living/source, obj/item/gun/fired_gun, atom/target, params, zone_override, list/bonus_spread_values)
	SIGNAL_HANDLER

	if(source != power_holder)
		return
	source.apply_status_effect(/datum/status_effect/power/action_movie_syndrome_disabled)

/datum/status_effect/power/action_movie_syndrome_disabled
	id = "action_movie_syndrome_disabled"
	duration = 15 MINUTES
	status_type = STATUS_EFFECT_REFRESH
	tick_interval = STATUS_EFFECT_NO_TICK
	alert_type = null

/datum/status_effect/power/action_movie_syndrome_disabled/on_apply()
	to_chat(owner, span_userdanger("You feel like your fortune won't save you from bullets now!"))

/datum/status_effect/power/action_movie_syndrome_disabled/on_remove()
	to_chat(owner, span_notice("You feel like your fortune's got your back again."))

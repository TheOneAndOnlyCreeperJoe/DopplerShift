// [L4D2 Charger Noises]
// Bumping into someone at sufficient Momentum will knock them back and deal light brute and moderate stamina damage.
/datum/power/warfighter/ramming_speed
	name = "Ramming Speed"
	desc = "Ram into your foes, sending them flying and knocking the wind out of them.\
	\nBumping into a mob whilst dashing in combat stance at 80% or more Momentum will cause you to send them flying, knocking them back two spaces, dealing brute damage and thrice as much stamina damage, as well as giving a short penalty to the person's ability to build Momentum.\
	The damage dealt is equal to every earned Athletics level * 2, always hits the target's body and is affected by melee armor. Landing a charge sets your Momentum down to 0.\
	\nYou also gain 500 Athletics experience, equivelant to Journeyman."
	security_record_text = "Subject is specialized in ramming into targets, damaging and weakening them."
	security_threat = POWER_THREAT_MAJOR
	value = 4
	required_powers = list(/datum/power/warfighter/martial_artist)

	menu_icon = 'modular_doppler/sprinting/icons/icons.dmi'
	menu_icon_state = "ram"

	/// The minimum momentum required to ram a target.
	var/minimum_momentum = 80
	/// The number of tiles a ram throws its target.
	var/throw_distance = 2
	/// The speed at which a ram throws its target.
	var/throw_speed = 2
	/// The brute damage dealt per earned Athletics level.
	var/damage_per_athletics_level = 2
	/// The multiplier applied to brute damage to determine stamina damage.
	var/stamina_damage_multiplier = 3
	/// The duration of the target's jitter and momentum gain penalty.
	var/debuff_duration = 5 SECONDS

/datum/power/warfighter/ramming_speed/post_add() // skills don't always give xp when spawning unless its post_add()
	. = ..()
	RegisterSignal(power_holder, COMSIG_LIVING_MOB_BUMP, PROC_REF(on_mob_bump))
	power_holder.mind?.adjust_experience(/datum/skill/athletics, SKILL_EXP_JOURNEYMAN)

/datum/power/warfighter/ramming_speed/remove()
	UnregisterSignal(power_holder, COMSIG_LIVING_MOB_BUMP)
	. = ..()
	power_holder.mind?.adjust_experience(/datum/skill/athletics, -SKILL_EXP_JOURNEYMAN)

/// Throws and damages a bumped living mob when the power holder has sufficient momentum in combat mode.
/datum/power/warfighter/ramming_speed/proc/on_mob_bump(mob/living/charger, mob/target)
	SIGNAL_HANDLER
	if(!charger.combat_mode || !isliving(target))
		return

	var/mob/living/living_target = target
	var/datum/component/sprinting/sprinting_component = charger.GetComponent(/datum/component/sprinting)
	if(!sprinting_component || sprinting_component.momentum < minimum_momentum)
		return

	// Athletics determines the impact damage.
	var/athletics_level = charger.mind?.get_skill_level(/datum/skill/athletics) || SKILL_LEVEL_NONE
	var/bash_damage = max(athletics_level - SKILL_LEVEL_NONE, 0) * damage_per_athletics_level

	// Throw the target away from the charger.
	var/throw_direction = get_dir(charger, living_target)
	var/turf/throw_target = get_ranged_target_turf(living_target, throw_direction, throw_distance)

	new /obj/effect/temp_visual/dir_setting/warfighter_heavy_slam(get_turf(living_target), throw_direction)
	playsound(living_target, 'sound/effects/meteorimpact.ogg', 60, TRUE, MEDIUM_RANGE_SOUND_EXTRARANGE)
	living_target.visible_message(
		span_danger("[charger] rams into [living_target], sending [living_target.p_them()] flying!"),
		span_userdanger("[charger] rams into you, sending you flying!"),
	)

	living_target.throw_at(throw_target, range = throw_distance, speed = throw_speed, thrower = charger, gentle = FALSE)
	var/brute_damage_dealt = living_target.apply_damage(bash_damage, BRUTE, BODY_ZONE_CHEST, living_target.run_armor_check(BODY_ZONE_CHEST, MELEE))
	var/stamina_damage_dealt = living_target.apply_damage(bash_damage * stamina_damage_multiplier, STAMINA, BODY_ZONE_CHEST, living_target.run_armor_check(BODY_ZONE_CHEST, MELEE))
	living_target.set_jitter_if_lower(debuff_duration)
	living_target.apply_status_effect(/datum/status_effect/power/ramming_speed_momentum_penalty, debuff_duration)
	sprinting_component.adjust_momentum(-sprinting_component.momentum)

	living_target.log_message("was rammed by [charger] for [brute_damage_dealt] brute damage and [stamina_damage_dealt] stamina damage.", LOG_VICTIM)
	charger.log_message("rammed [living_target] for [brute_damage_dealt] brute damage and [stamina_damage_dealt] stamina damage.", LOG_ATTACK)

/// Temporarily reduces momentum gain after being hit by a ram.
/datum/status_effect/power/ramming_speed_momentum_penalty
	id = "ramming_speed_momentum_penalty"
	status_type = STATUS_EFFECT_REPLACE
	duration = 5 SECONDS
	alert_type = null

	/// The percentage reduction applied to momentum gains.
	var/momentum_gain_penalty = -50

/// Sets the momentum penalty's duration.
/datum/status_effect/power/ramming_speed_momentum_penalty/on_creation(mob/living/new_owner, effect_duration)
	if(isnum(effect_duration))
		duration = effect_duration
	return ..()

/datum/status_effect/power/ramming_speed_momentum_penalty/on_apply()
	RegisterSignal(owner, COMSIG_SPRINTING_MOMENTUM_CHANGE, PROC_REF(reduce_momentum_gain))
	return TRUE

/datum/status_effect/power/ramming_speed_momentum_penalty/on_remove()
	if(owner)
		UnregisterSignal(owner, COMSIG_SPRINTING_MOMENTUM_CHANGE)

/// Adds the momentum penalty.
/datum/status_effect/power/ramming_speed_momentum_penalty/proc/reduce_momentum_gain(mob/living/carbon/human/sprinter, amount, list/change_modifiers)
	SIGNAL_HANDLER
	if(amount > 0)
		change_modifiers += momentum_gain_penalty

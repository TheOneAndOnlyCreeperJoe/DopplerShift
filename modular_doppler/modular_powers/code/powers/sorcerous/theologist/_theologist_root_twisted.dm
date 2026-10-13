/datum/power/theologist_root/twisted
	name = "A Burden Twisted"
	desc = "Channel a beam that adjust the target's body, twisting large injuries into smaller, insubstantial injuries. The beam persists so long as you remain adjacent to the target, regardless of your activities.\
	\nA Burden Twisted heals any damage-type besides suffocation, with the healing amount scaling based on how much health is missing. This cannot heal a damage-type that only has 10% or less of the target's maximum health as damage, per damage-type. \
	Half the damage healed is dealt again as damage to a different type.\
	\nGives Piety proportional to the net-positive amount of damage healed. Works on synthetic bodyparts, but cannot heal or deal toxins damage to a synthetic bodypart."
	security_record_text = "Subject can rapidly transmute the injuries of a target into smaller, insubstantial injuries."
	action_path = /datum/action/cooldown/power/theologist/theologist_root/twisted

	value = 4

/datum/action/cooldown/power/theologist/theologist_root/twisted
	name = "A Burden Twisted"
	desc = "Heals a target's injuries and twists them into smaller ones. You repeatedly heal a random damage-type besides suffocation, dealing half the healing back again as a random, different damage-type.\
	\nCannot heal damage-types that are less than 10% of the target's max health. Can heal synthetic bodyparts. Grants Piety based on the amount healed."
	button_icon = 'icons/mob/actions/actions_cult.dmi'
	button_icon_state = "hand"
	cooldown_time = 150
	target_range = 1
	target_type = /mob/living
	click_to_activate = TRUE
	target_self = FALSE
	unset_after_click = TRUE

	/// Healing applied per tick before health scaling and modifiers.
	var/base_healing_amount = 8
	/// The percentage floor on the healing, meaning it always heals this much minimum.
	var/base_healing_floor = 0.1
	/// The portion of healed damage transferred to another damage type.
	var/heal_to_damage_ratio = 0.5
	/// The max_health% threshold at which A Burden Twisted stops healing that damage-type.
	var/damage_healing_threshold = 0.1
	/// How long it takes to the tick each heal
	var/heal_tick_wait = 2 SECONDS
	/// Set this to a damage type to override the automatic conversion destination.
	var/fixed_damage_type
	/// Tracks net-positive healing for piety.
	var/healing_done = 0

	/// The beam effect when channeling
	var/datum/beam/current_beam
	/// The target whose dispel signal ends the current channel.
	var/mob/living/current_target

/datum/action/cooldown/power/theologist/theologist_root/twisted/use_action(mob/living/user, mob/living/target)
	current_target = target
	// Snapshot healing modifiers once for the entire channel.
	snapshot_healing_multiplier(target)
	// Because this proc channels in a loop, it won't get to the usual unset_click_ability() until after the effect resolves, so we have to run it here.
	unset_click_ability(owner, FALSE)
	owner.visible_message(span_warning("[owner.get_visible_name()] lays a hand on [target.get_visible_name()], twisting their injuries into other, smaller injuries!"), span_notice("You twist [target.get_visible_name()]'s injuries!"))
	RegisterSignal(user, COMSIG_ATOM_DISPEL, PROC_REF(on_dispel))
	RegisterSignal(target, COMSIG_ATOM_DISPEL, PROC_REF(on_dispel))
	active = TRUE
	// I am going to shamelessly steal the red meditation spotlight for a moment.
	target.apply_status_effect(/datum/status_effect/spotlight_light/twisted, 1200)
	// Beam range uses a strict less-than check, while the channel permits targets at exactly target_range.
	current_beam = owner.Beam(target, icon_state = "light_beam", time = 120 SECONDS, maxdistance = target_range + 1, beam_type = /obj/effect/ebeam/medical, beam_color = "#cf2525")
	RegisterSignal(current_beam, COMSIG_QDELETING, PROC_REF(on_beam_destroyed))

	// Does the healing and damage
	while(active)
		if(!do_after(owner, heal_tick_wait, target = target, timed_action_flags = IGNORE_USER_LOC_CHANGE | IGNORE_TARGET_LOC_CHANGE | IGNORE_HELD_ITEM | IGNORE_INCAPACITATED, extra_checks = CALLBACK(src, PROC_REF(is_channel_active))))
			break
		// Checks if our target is in range
		if(target_range)
			var/turf/owner_turf = get_turf(owner)
			var/turf/target_turf = get_turf(target)
			if(owner_turf && target_turf && get_dist(owner_turf, target_turf) > target_range)
				owner.balloon_alert(owner, "Out of range!")
				break // we use break here instead because we don't want to heal them anymore.
		var/list/damage_types_to_heal = get_damage_types_to_heal(target)
		if(!damage_types_to_heal.len)
			to_chat(owner, span_notice("Your target has no other damage left to twist!"))
			break
		var/total_healed = 0
		var/conversion_ratio = get_modified_conversion_ratio()
		for(var/damage_type in damage_types_to_heal)
			var/healed_amount = heal_damage_type(target, damage_type)
			if(!healed_amount)
				continue
			total_healed += healed_amount
			var/conversion_damage_type = get_conversion_damage_type(target, damage_type)
			deal_damage_type(target, conversion_damage_type, healed_amount * conversion_ratio)
		if(!total_healed)
			to_chat(owner, span_notice("Your target has no other damage left to twist!"))
			break
		// effects/feedback
		new /obj/effect/temp_visual/heal(get_turf(target), "#cf2525")
		playsound(owner, 'sound/effects/magic/cosmic_expansion.ogg', 75, TRUE, MEDIUM_RANGE_SOUND_EXTRARANGE)

	// cleanup
	active = FALSE
	target.remove_status_effect(/datum/status_effect/spotlight_light/twisted)
	QDEL_NULL(current_beam)
	UnregisterSignal(current_target, COMSIG_ATOM_DISPEL)
	UnregisterSignal(owner, COMSIG_ATOM_DISPEL)

	// Handles piety gain
	var/piety_gained = max(0, floor(healing_done * THEOLOGIST_PIETY_HEALING_COEFFICIENT))
	// resets for next time
	healing_done = 0
	if(target.ckey)
		adjust_piety(piety_gained)
		if(piety_gained >= 1)
			to_chat(owner, span_notice("You Burden Twisted yielded [piety_gained] piety!"))
		else
			to_chat(owner, span_notice("Your Burden Twisted yielded no piety!"))
	else
		to_chat(owner, span_notice("Your Burden Twisted yielded no piety!"))
	return TRUE

/// Returns the damage types that the current Twisted configuration can heal.
/datum/action/cooldown/power/theologist/theologist_root/twisted/proc/get_damage_types_to_heal(mob/living/target)
	var/list/damage_types_to_heal = list("brute", "burn")
	if(is_valid_for_toxin_damage(target))
		damage_types_to_heal += "tox"
	if(fixed_damage_type)
		damage_types_to_heal -= fixed_damage_type
	var/damage_threshold = fixed_damage_type ? 0 : target.maxHealth * damage_healing_threshold
	for(var/damage_type in damage_types_to_heal.Copy())
		if(get_damage_amount(target, damage_type) > damage_threshold)
			continue
		damage_types_to_heal -= damage_type
	return damage_types_to_heal

/// I wish there was a better source of truth for this, but blocks certain mobs/bodyparts from receiving tox damage since they don't have a way of processing it.
/// This is because we force toxins damage to allow slimepersons to be healed at all by it.
/datum/action/cooldown/power/theologist/theologist_root/twisted/proc/is_valid_for_toxin_damage(mob/living/target)
	// non-humanoids
	if(!ishuman(target))
		return FALSE
	var/mob/living/carbon/human/human_target = target
	// androids
	if(isandroid(human_target))
		return FALSE
	// anything that otherwise has a humanoid chest.
	var/obj/item/bodypart/chest/chest = human_target.get_bodypart(BODY_ZONE_CHEST)
	return !(chest?.bodytype & BODYTYPE_ROBOTIC)

/// Returns the target's damage amount for a standard damage type.
/datum/action/cooldown/power/theologist/theologist_root/twisted/proc/get_damage_amount(mob/living/target, damage_type)
	switch(damage_type)
		if("brute")
			return target.getBruteLoss()
		if("burn")
			return target.getFireLoss()
		if("tox")
			return target.getToxLoss()
		if("oxy")
			return target.getOxyLoss()
	return 0

/// Heals one damage type without reducing it below its configured threshold.
/datum/action/cooldown/power/theologist/theologist_root/twisted/proc/heal_damage_type(mob/living/target, damage_type)
	var/current_damage = get_damage_amount(target, damage_type)
	var/damage_threshold = fixed_damage_type ? 0 : target.maxHealth * damage_healing_threshold
	if(current_damage <= damage_threshold)
		return 0
	var/healing_ratio = max(current_damage / target.maxHealth, base_healing_floor)
	var/healing_amount = min(base_healing_amount * healing_ratio * healing_multiplier, current_damage - damage_threshold)
	var/healed_amount = 0
	switch(damage_type)
		if("brute")
			healed_amount = target.adjustBruteLoss(-healing_amount)
		if("burn")
			healed_amount = target.adjustFireLoss(-healing_amount)
		if("tox")
			healed_amount = target.adjustToxLoss(-healing_amount, forced = TRUE)
		if("oxy")
			healed_amount = target.adjustOxyLoss(-healing_amount)
	healing_done += healed_amount
	return healed_amount

/// Selects the least-damaged non-oxygen type other than the type being healed.
/datum/action/cooldown/power/theologist/theologist_root/twisted/proc/get_conversion_damage_type(mob/living/target, healed_damage_type)
	// Passes off if twisted's damage type is fixed
	if(fixed_damage_type && (fixed_damage_type != "tox" || is_valid_for_toxin_damage(target)))
		return fixed_damage_type
	var/lowest_damage = INFINITY
	var/list/conversion_choices = list()
	var/list/conversion_damage_types = list("brute", "burn")
	// only add tox if it would work on the mob.
	if(is_valid_for_toxin_damage(target))
		conversion_damage_types += "tox"
	for(var/damage_type in conversion_damage_types)
		if(damage_type == healed_damage_type)
			continue
		var/damage_amount = get_damage_amount(target, damage_type)
		if(damage_amount < lowest_damage)
			lowest_damage = damage_amount
			conversion_choices = list(damage_type)
		else if(damage_amount == lowest_damage)
			conversion_choices += damage_type
	return pick(conversion_choices)

/// Collects additive damage conversion modifiers and applies them as a divider to the base conversion ratio.
/datum/action/cooldown/power/theologist/theologist_root/twisted/proc/get_modified_conversion_ratio()
	var/list/conversion_modifiers = list()
	SEND_SIGNAL(owner, COMSIG_THEOLOGIST_TWISTED_CONVERSION_MODIFIERS, conversion_modifiers)

	var/total_conversion_modifier = 1
	for(var/conversion_modifier in conversion_modifiers)
		total_conversion_modifier += conversion_modifier

	return heal_to_damage_ratio / total_conversion_modifier

/// Deals the appropriate damage back after healing.
/datum/action/cooldown/power/theologist/theologist_root/twisted/proc/deal_damage_type(mob/living/target, damage_type, damage_amount)
	if(!damage_amount)
		return
	switch(damage_type)
		if("brute")
			target.adjustBruteLoss(damage_amount)
		if("burn")
			target.adjustFireLoss(damage_amount)
		if("tox")
			target.adjustToxLoss(damage_amount, forced = TRUE) // sorry slimes no free real estate 4u
		// this doesn't happen unless its forced.
		if("oxy")
			target.adjustOxyLoss(damage_amount)
	healing_done = max(0, healing_done - damage_amount)

/// Ends the channel when its user or target is dispelled.
/datum/action/cooldown/power/theologist/theologist_root/twisted/proc/on_dispel(mob/owner, atom/dispeller)
	SIGNAL_HANDLER
	if(!active)
		return NONE
	active = FALSE
	owner.visible_message(span_warning("The resonant link between [owner.get_visible_name()] and [current_target.get_visible_name()] is broken!!"), span_notice("Your [name] is dispelled!"))
	StartCooldownSelf()
	return DISPEL_RESULT_DISPELLED

/// Ends the channel when its beam no longer exists.
/datum/action/cooldown/power/theologist/theologist_root/twisted/proc/on_beam_destroyed(datum/source)
	SIGNAL_HANDLER
	active = FALSE

/// Returns whether the channel can continue or if it should end, based on if active is true and if the beam is still there or not.
/datum/action/cooldown/power/theologist/theologist_root/twisted/proc/is_channel_active()
	return active && !QDELETED(current_beam)

// Legacy subtype for other powers still referencing this path.
/datum/status_effect/spotlight_light/twisted
	id = "twisted_spotlight"
	spotlight_color = "#cf2525"

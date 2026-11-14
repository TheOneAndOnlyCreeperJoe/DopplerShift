// Removes reagents, heals tox based on amount removed, regardless of chem. Feed someone water to then heal with cleanse!
// Also removes toxins form reagent containers.
/datum/power/thaumaturge/cleanse
	name = "Cleanse"
	desc = "You place a short-lasting spell on a target within touch range, cleansing the unnatural from them.\
	\nThe target gains a buff that purges each chemical from the target's bloodstream at 1u/second. For every unit purged, the target heals 2 toxins damage. Lasts 10 seconds. Dangerous to slimepeople. \
	\nIf the target is diseased, they are cured of the disease at the end of the status effect.\
	\nCasting Cleanse on an object removes 15u worth of poisons from any reagents housed within it.\
	\nRequires Affinity 1. Additional affinity increases duration by +4 seconds. Bonuses to healing modifiers increase purge amount and heal amount, at half the regular amount each."
	security_record_text = "Subject can remove chemicals from a target's body and heal them based on the amount."
	value = 3
	power_flags = POWER_HUMAN_ONLY | POWER_HEALING

	action_path = /datum/action/cooldown/power/thaumaturge/cleanse
	required_powers = list(/datum/power/thaumaturge_root)
	required_allow_subtypes = TRUE

/datum/action/cooldown/power/thaumaturge/cleanse
	name = "Cleanse"
	desc = "Removes chemicals and disease from carbon targets over times. For every unit purged, the target heals toxins damage. Removes toxic chemicals from objects.\
	Requires Affinity 3. Additional affinity increases duration. Affected by healing modifiers."
	button_icon = 'modular_doppler/modular_powers/icons/powers/actions_icons.dmi'
	button_icon_state = "cleanse"

	required_affinity = 3
	prep_cost = 3
	click_to_activate = TRUE

	/// Base duration of the cleanse effect
	var/base_duration = 10 SECONDS
	/// Additional duration granted for each point of affinity above the requirement.
	var/affinity_duration_bonus = 4 SECONDS
	/// Base reagent units purged per second PER chem
	var/base_purge_amount = 1
	/// Base toxin damage healed for each reagent unit purged
	var/base_toxin_healing = 2
	/// Toxin reagent units removed from an object target.
	var/object_purge_amount = 15
	/// Color used by all Cleanse visual effects.
	var/cleanse_color = "#6DF79A"

/datum/action/cooldown/power/thaumaturge/cleanse/InterceptClickOn(mob/living/clicker, params, atom/target)
	. = ..()
	// Makes it so we always override the base click.
	return TRUE

/// Removes toxins from objects or applies the Cleanse status effect to a carbon mob.
/datum/action/cooldown/power/thaumaturge/cleanse/use_action(mob/living/user, atom/target)
	// Object handling for reagent removal
	if(isobj(target))
		var/obj/object_target = target
		if(!object_target.reagents)
			return FALSE
		var/remaining_purge = object_purge_amount
		var/total_purged = 0
		// Cycles all toxic chems and basically removes 15u worth from all.
		for(var/datum/reagent/toxin/reagent in object_target.reagents.reagent_list.Copy())
			if(remaining_purge <= 0)
				break
			var/removed = object_target.reagents.remove_reagent(reagent.type, remaining_purge)
			if(removed <= 0)
				continue
			remaining_purge -= removed
			total_purged += removed
		if(total_purged <= 0)
			return FALSE
		// FX
		playsound(user, 'modular_doppler/modular_powers/sounds/cleanse/cleanse_spell.ogg', 75, TRUE, SILENCED_SOUND_EXTRARANGE)
		var/filter_id = "thaumaturge_cleanse_flash"
		object_target.add_filter(filter_id, 1, list(type = "outline", color = cleanse_color, size = 2, alpha = 255))
		object_target.transition_filter(filter_id, list("alpha" = 0), 2 SECONDS)
		addtimer(CALLBACK(object_target, PROC_REF(remove_filter), filter_id), 2 SECONDS)
		return TRUE

	// Carbon healing beyond this point
	if(!iscarbon(target))
		return FALSE

	var/mob/living/carbon/carbon_target = target
	// affinity diff
	var/bonus_affinity = max(0, affinity - required_affinity)
	// duration calc
	var/effect_duration = base_duration + (bonus_affinity * affinity_duration_bonus)
	// healing bonuses
	var/healing_modifier = snapshot_healing_multiplier(carbon_target)
	// half effective the healing bonuses
	var/effect_modifier = 1 + ((healing_modifier - 1) * 0.5)
	// adjust purge and toxin rates based on healing modifier.
	var/modified_purge_amount = base_purge_amount * effect_modifier
	var/modified_toxin_healing = base_toxin_healing * effect_modifier

	var/datum/status_effect/power/thaumaturge_cleanse/cleanse_effect = carbon_target.apply_status_effect(/datum/status_effect/power/thaumaturge_cleanse, effect_duration, modified_purge_amount, modified_toxin_healing, src)
	if(!cleanse_effect)
		return FALSE
	playsound(user, 'modular_doppler/modular_powers/sounds/cleanse/cleanse_spell.ogg', 75, TRUE, SILENCED_SOUND_EXTRARANGE)
	return TRUE

/// Purges a carbon's reagents over time, heals toxin damage from the purge, then cures diseases when the effect ends.
/datum/status_effect/power/thaumaturge_cleanse
	id = "thaumaturge_cleanse"
	duration = 10 SECONDS
	tick_interval = 1 SECONDS
	show_duration = TRUE
	alert_type = /atom/movable/screen/alert/status_effect/thaumaturge_cleanse

	/// Reagent units removed from every reagent each second.
	var/purge_amount = 1
	/// Toxin damage healed for each reagent unit removed.
	var/toxin_healing = 2
	/// The action that created this effect.
	var/datum/action/cooldown/power/thaumaturge/cleanse/cleanse_action
	/// Total reagent volume removed by this effect.
	var/total_purged = 0
	/// Total toxin damage actually healed by this effect.
	var/total_toxin_healed = 0
	/// Identifier for this effect's filter.
	var/filter_id = "thaumaturge_cleanse_outline"
	/// Outline color shown while the effect is active.
	var/cleanse_color = "#6DF79A"

/// Stores the passed along duration, purge amount, and toxin healing for Cleanse.
/datum/status_effect/power/thaumaturge_cleanse/on_creation(mob/living/carbon/new_owner, passed_duration, passed_purge_amount, passed_toxin_healing, datum/action/cooldown/power/thaumaturge/cleanse/passed_action)
	if(isnum(passed_duration))
		duration = passed_duration
	if(isnum(passed_purge_amount))
		purge_amount = max(0, passed_purge_amount)
	if(isnum(passed_toxin_healing))
		toxin_healing = max(0, passed_toxin_healing)
	cleanse_action = passed_action
	return ..()

/// Applies Cleanse's outline to the owner.
/datum/status_effect/power/thaumaturge_cleanse/on_apply()
	owner.add_filter(filter_id, 1, list(type = "outline", color = cleanse_color, size = 2, alpha = 100))
	return TRUE

/// Purges reagents and heals toxin damage based on the amount removed.
/datum/status_effect/power/thaumaturge_cleanse/tick(seconds_between_ticks)
	var/datum/blood_type/blood_type = owner.get_bloodtype()
	var/blood_reagent_type = blood_type?.reagent_type
	var/purged_this_tick = 0

	// Purges
	for(var/datum/reagent/reagent in owner.reagents.reagent_list.Copy())
		if(reagent.type == blood_reagent_type) // this would be funny but no
			continue
		var/removed = owner.reagents.remove_reagent(reagent.type, purge_amount * reagent.purge_multiplier * seconds_between_ticks)
		if(removed <= 0)
			continue
		purged_this_tick += removed
		total_purged += removed

	// Heals based on purge sum.
	if(purged_this_tick > 0)
		var/toxin_healed = owner.adjustToxLoss(-(purged_this_tick * toxin_healing))
		if(toxin_healed > 0)
			total_toxin_healed += toxin_healed
			new /obj/effect/temp_visual/heal(get_turf(owner), cleanse_color)

/// Cures every disease affecting the owner.
/datum/status_effect/power/thaumaturge_cleanse/on_remove()
	owner.remove_filter(filter_id)
	if(total_purged > 0)
		owner.log_message("had [round(total_purged, 0.1)]u purged and [round(total_toxin_healed, 0.1)] toxin damage healed by [cleanse_action?.owner]'s Cleanse.", LOG_GAME)
	for(var/datum/disease/disease as anything in owner.diseases.Copy())
		qdel(disease)

/atom/movable/screen/alert/status_effect/thaumaturge_cleanse
	name = "Cleanse"
	desc = "Your bloodstream is being cleansed of chemicals; and you are healed toxins based on the amount."
	icon = 'modular_doppler/modular_powers/icons/powers/actions_icons.dmi'
	icon_state = "cleanse"

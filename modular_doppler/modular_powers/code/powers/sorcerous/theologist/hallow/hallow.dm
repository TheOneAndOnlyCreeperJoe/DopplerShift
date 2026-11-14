/*
	Converts objects, reagents, and constructs into holy equivalents.
	This has a large overarching system at modular_doppler\modular_powers\code\powers\sorcerous\theologist\hallow\_hallow_conversions.dm which handles matching conversions.
	The action is simply a handler for requesting conversions from it.
*/

/datum/power/theologist/hallow
	name = "Hallow"
	desc = "Turns a specific entity within melee range into its holy equivalent.\
	\nExamples include turning water into holy water, blood into godsblood, turning melons into holymelons and forged weapons into holy weapons. These usually have a Piety cost.\
	\nYou can examine items, reagents, and mobs to tell if Hallow can affect it and if so, at what cost."
	security_record_text = "Subject can transmute objects and reagents into holy variants with a touch."
	security_threat = POWER_THREAT_MAJOR
	action_path = /datum/action/cooldown/power/theologist/hallow
	value = 3
	power_flags = POWER_HUMAN_ONLY
	required_powers = list(/datum/power/theologist/root)
	required_allow_subtypes = TRUE

/datum/power/theologist/hallow/add(client/client_source)
	. = ..()
	RegisterSignal(power_holder, COMSIG_MOB_EXAMINING, PROC_REF(on_examine))

/datum/power/theologist/hallow/remove()
	UnregisterSignal(power_holder, COMSIG_MOB_EXAMINING)
	return ..()

/// Appends an examine target on anything that can be converted
/datum/power/theologist/hallow/proc/on_examine(mob/living/viewer, atom/examined_atom, list/examine_list)
	SIGNAL_HANDLER

	var/datum/action/cooldown/power/theologist/hallow/hallow_action = action_path
	if(!hallow_action)
		return

	/// Object/Mob conversion.
	var/datum/hallow_conversion/target_conversion = hallow_action.get_matching_hallow_conversion(examined_atom)
	if(target_conversion)
		var/target_piety_cost = target_conversion.cost_calc()
		if(target_piety_cost)
			examine_list += "<font color='[POWER_COLOR_THEOLOGIST]'><b>This [examined_atom.name] can be hallowed for [target_piety_cost] Piety!</b></font>"
		else
			examine_list += "<font color='[POWER_COLOR_THEOLOGIST]'><b>This [examined_atom.name] can be hallowed!</b></font>"
		if(target_conversion.examine_extra_text) // appends extra text if the power specifies
			examine_list += "<font color='[POWER_COLOR_THEOLOGIST]'><b>[target_conversion.examine_extra_text]</b></font>"
		return // we return here because obj conversion takes priority over reagents.

	/// Reagents
	if(!examined_atom.reagents || !viewer.can_see_reagents())
		return
	for(var/datum/reagent/current_reagent as anything in examined_atom.reagents.reagent_list)
		var/datum/hallow_conversion/reagent/reagent_conversion = hallow_action.get_matching_hallow_conversion(current_reagent)
		if(!reagent_conversion)
			continue
		var/reagent_piety_cost = reagent_conversion.cost_calc(current_reagent.volume)
		if(reagent_piety_cost)
			examine_list += "<font color='[POWER_COLOR_THEOLOGIST]'><b>This [current_reagent.name] can be hallowed for [reagent_piety_cost] Piety!</b></font>"
		else
			examine_list += "<font color='[POWER_COLOR_THEOLOGIST]'><b>This [current_reagent.name] can be hallowed!</b></font>"
		if(reagent_conversion.examine_extra_text)  // appends extra text if the power specifies
			examine_list += "<font color='[POWER_COLOR_THEOLOGIST]'><b>[reagent_conversion.examine_extra_text]</b></font>"

/datum/action/cooldown/power/theologist/hallow
	name = "Hallow"
	desc = "Turns a specific entity within melee range into its holy equivalent.\
	\nExamples include turning water into holy water, blood into godsblood, turning melons into holymelons and forged weapons into holy weapons. These usually have a Piety cost.\
	\nYou can examine items, reagents, and mobs to tell if Hallow can affect it and if so, at what cost."
	button_icon = 'icons/obj/mining_zones/artefacts.dmi'
	button_icon_state = "purified_soulstone"
	cooldown_time = 60
	target_range = 1
	target_self = FALSE
	click_to_activate = TRUE
	/// Concrete conversion datums discovered for this Hallow action.
	var/list/hallow_conversions

/// Don't want to accidentaly click the item.
/datum/action/cooldown/power/theologist/hallow/InterceptClickOn(mob/living/clicker, params, atom/target)
	. = ..()
	return TRUE

/datum/action/cooldown/power/theologist/hallow/use_action(mob/living/user, atom/target)
	if(!target)
		return FALSE

	var/success = hallow_target(user, target)
	if(!success)
		return FALSE
	playsound(user, 'sound/effects/magic/magic_block_holy.ogg', 50, TRUE, MEDIUM_RANGE_SOUND_EXTRARANGE)
	return TRUE

/// Converts a valid atom into its holy equivelant by invoking the conversion pipeline.
/// Most of it is handled over at modular_doppler\modular_powers\code\powers\sorcerous\theologist\hallow\_hallow_conversions.dm.
/datum/action/cooldown/power/theologist/hallow/proc/hallow_target(mob/living/user, atom/target)
	var/converted = FALSE

	//Obj/mob conversion
	var/datum/hallow_conversion/conversion = get_matching_hallow_conversion(target)
	if(conversion)
		// Checks if we have the dosh
		var/calced_cost = conversion.cost_calc()
		if(get_piety() < calced_cost)
			user.balloon_alert(user, "needs [calced_cost] piety!")
			return FALSE
		// Attempts to hallow
		var/conversion_cost = conversion.try_hallow(user, target)

		if(isnull(conversion_cost))
			return FALSE
		adjust_piety(-conversion_cost)
		converted = TRUE

	// Reagent conversion
	if(!QDELETED(target) && target.reagents)
		var/list/applied_reagent_conversions = list()
		for(var/datum/reagent/current_reagent as anything in target.reagents.reagent_list.Copy())
			// Checks if the reagent is hallowable
			var/datum/hallow_conversion/reagent/reagent_conversion = get_matching_hallow_conversion(current_reagent)
			if((!reagent_conversion) || (reagent_conversion.type in applied_reagent_conversions))
				continue
			// Checks if we have the dosh
			var/calced_cost = reagent_conversion.cost_calc(current_reagent.volume)
			if(get_piety() < calced_cost)
				user.balloon_alert(user, "needs [calced_cost] piety!")
				return FALSE
			// Attempts to hallow.
			var/conversion_cost = reagent_conversion.try_hallow(user, target, current_reagent)

			if(isnull(conversion_cost))
				continue
			adjust_piety(-conversion_cost)
			converted = TRUE
			applied_reagent_conversions += reagent_conversion.type

	return converted

/// Returns the first valid conversion for an object, reagent, or living mob.
/datum/action/cooldown/power/theologist/hallow/proc/get_matching_hallow_conversion(datum/target)
	if(isobj(target))
		for(var/datum/hallow_conversion/object/conversion in get_hallow_conversions(/datum/hallow_conversion/object))
			if(conversion.can_hallow(target))
				return conversion
		return null
	if(istype(target, /datum/reagent))
		var/datum/reagent/reagent_target = target
		for(var/datum/hallow_conversion/reagent/conversion in get_hallow_conversions(/datum/hallow_conversion/reagent))
			if(conversion.can_hallow(reagent_target))
				return conversion
		return null
	if(isliving(target))
		for(var/datum/hallow_conversion/living_mob/conversion in get_hallow_conversions(/datum/hallow_conversion/living_mob))
			if(conversion.can_hallow(target))
				return conversion
	return null

/// Creates conversion datums from every non-abstract subtype of a conversion category.
/datum/action/cooldown/power/theologist/hallow/proc/get_hallow_conversions(conversion_category)
	// If we have already calculated the conversions for that category, just toss them over.
	if(!hallow_conversions)
		hallow_conversions = list()
	var/list/cached_conversions = hallow_conversions[conversion_category]
	if(cached_conversions)
		return cached_conversions

	// Generate all the conversions we need.
	cached_conversions = list()
	for(var/datum/hallow_conversion/conversion_type as anything in subtypesof(conversion_category))
		if(initial(conversion_type.abstract_type) == conversion_type)
			continue
		cached_conversions += new conversion_type
	hallow_conversions[conversion_category] = cached_conversions
	return cached_conversions

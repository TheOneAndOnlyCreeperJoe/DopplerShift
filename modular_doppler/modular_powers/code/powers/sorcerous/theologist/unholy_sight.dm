/// Given to anyone that has unholy wielding powers, allowing them to well, see the unholy.
/datum/action/cooldown/power/theologist/unholy_sight
	name = "Unholy Sight"
	desc = "Allows you to spot unholy target, which are marked with a green icon above their heads. Also allows you to see holy targets, which are marked with a yellow icon.\
	\nDoes not affect scrying immune creatures."
	button_icon = 'icons/mob/actions/actions_animal.dmi'
	button_icon_state = "adjust_vision"
	active_overlay_icon_state = "bg_spell_border_active_blue"

	need_hands_free = FALSE

	/// Client-only images currently displayed by Unholy Sight.
	var/list/mob/living/tracked_targets = list()
	var/list/image/target_images = list()

/// Disables Unholy Sight and removes all indicators.
/datum/action/cooldown/power/theologist/unholy_sight/Remove(mob/removed_from)
	active = FALSE
	STOP_PROCESSING(SSprocessing, src)
	clear_unholy_sight_overlays(removed_from)
	return ..()

/// Toggles Unholy Sight and begins or stops refreshing its indicators.
/datum/action/cooldown/power/theologist/unholy_sight/use_action(mob/living/user, atom/target)
	if(!user.client)
		return FALSE

	active = !active
	if(active)
		START_PROCESSING(SSprocessing, src)
		update_unholy_sight_overlays()
	else
		STOP_PROCESSING(SSprocessing, src)
		clear_unholy_sight_overlays()

	build_all_button_icons(UPDATE_BUTTON_OVERLAY)
	user.balloon_alert(user, active ? "unholy sight on" : "unholy sight off")
	return TRUE

/// Reports whether Unholy Sight is currently enabled.
/datum/action/cooldown/power/theologist/unholy_sight/is_action_active(atom/movable/screen/movable/action_button/current_button)
	return active

/// Refreshes the indicators for all creatures in the owner's current view.
/datum/action/cooldown/power/theologist/unholy_sight/process(seconds_per_tick)
	if(!active || !owner?.client)
		active = FALSE
		STOP_PROCESSING(SSprocessing, src)
		clear_unholy_sight_overlays()
		return
	update_unholy_sight_overlays()

/// Displays overlays to any applicable mobs.
/datum/action/cooldown/power/theologist/unholy_sight/proc/update_unholy_sight_overlays()
	if(!owner?.client)
		return

	var/list/mob/living/visible_targets = list()
	// Adds any mob we can see.
	for(var/mob/living/seen_mob in view(owner.client.view, owner))
		var/icon_state = get_unholy_sight_icon_state(seen_mob)
		if(!icon_state)
			continue

		visible_targets += seen_mob
		var/image/unholy_sight_image = target_images[seen_mob]
		if(!unholy_sight_image)
			unholy_sight_image = image(icon = 'modular_doppler/modular_powers/icons/powers/effects.dmi', loc = seen_mob, icon_state = icon_state)
			owner.client.images += unholy_sight_image
			target_images[seen_mob] = unholy_sight_image
			RegisterSignal(seen_mob, COMSIG_ATOM_EXAMINE, PROC_REF(on_target_examine))
		else
			unholy_sight_image.icon_state = icon_state
		// Makes it so we inherit the mob's pixel offset so it actually lines up with other HUDs
		unholy_sight_image.pixel_x = seen_mob.pixel_x
		unholy_sight_image.pixel_y = seen_mob.pixel_y + 12
		unholy_sight_image.layer = max(ABOVE_MOB_LAYER, seen_mob.layer + 0.01)

	// Axes any mob we can't see anymore.
	for(var/mob/living/tracked_target as anything in tracked_targets - visible_targets)
		var/image/old_image = target_images[tracked_target]
		if(old_image)
			owner.client.images -= old_image
		UnregisterSignal(tracked_target, COMSIG_ATOM_EXAMINE)
		target_images -= tracked_target

	tracked_targets = visible_targets

/// Returns the appropriate icon_state state for a target, or null if none applies.
/datum/action/cooldown/power/theologist/unholy_sight/proc/get_unholy_sight_icon_state(mob/living/target)
	if(!target)
		return null
	if(HAS_TRAIT(target, TRAIT_ANTIRESONANCE_SCRYING) || target.can_block_resonance(0)) // can't pierce magic resist
		return null
	if(HAS_TRAIT(target, TRAIT_HOLY))
		return "holy"

	var/datum/power/theologist/theologist_power = origin_power
	if(theologist_power?.is_unholy(target))
		return "unholy"
	return null

/// Also extrapolates that a mob is unholy/holy so that players dont ponder what the icons are.
/datum/action/cooldown/power/theologist/unholy_sight/proc/on_target_examine(mob/living/target, mob/user, list/examine_list)
	SIGNAL_HANDLER
	if(!active || user != owner || !(target in tracked_targets))
		return

	switch(get_unholy_sight_icon_state(target))
		if("holy")
			examine_list += "<font color='[POWER_COLOR_THEOLOGIST]'>[target] is holy!</font>"
		if("unholy")
			examine_list += "<font color='[POWER_COLOR_ENIGMATIST]'>[target] is unholy!</font>"

/// Removes all overlays.
/datum/action/cooldown/power/theologist/unholy_sight/proc/clear_unholy_sight_overlays(mob/viewer = owner)
	for(var/mob/living/tracked_target as anything in tracked_targets)
		if(viewer?.client)
			var/image/unholy_sight_image = target_images[tracked_target]
			if(unholy_sight_image)
				viewer.client.images -= unholy_sight_image
		UnregisterSignal(tracked_target, COMSIG_ATOM_EXAMINE)
	tracked_targets.Cut()
	target_images.Cut()

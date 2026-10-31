/// Healing is not always physical. A Burden Heartened comforts nearby people and draws piety from their happiness.
/datum/power/theologist_root/heartened
	name = "A Burden Heartened"
	desc = "Even if the physical wounds heal, the pain may often not leave, and you seek to comfort those who are still being weighed down by these burdens.\
	\nYou have a passive 7x7 aura centered on you. Other carbon-based creatures in the area gain a buff which grants a 1.25x bonus to positive moodlets, modified by your healing bonuses. \
	\nYou slowly gain Piety over time for every happy creature carrying this buff in your aura, even if another Heartened theologist originally bestowed it. The Piety gain diminishes as your Piety grows, requiring very high moods to reach maximum Piety.\
	\nYou also gain Mood Sight, a toggle which displays the mood of affected creatures. Scrying, magic, or mental immunity prevents this detection."
	security_record_text = "Subject inspires unusual amounts of comfort and joy in those nearby."
	action_path = /datum/action/cooldown/power/theologist/theologist_root/mood_sight
	magic_flags = POWER_MAGIC_STANDARD | POWER_MAGIC_MENTAL | POWER_MAGIC_SCRYING
	power_flags = POWER_HUMAN_ONLY | POWER_PROCESSES | POWER_HEALING
	maximum_process_stat = DEAD

	menu_icon = 'icons/mob/simple/animal.dmi'
	menu_icon_state = "heart"

	value = 3

	/// Carbon mobs currently sustained by this power's aura.
	var/list/mob/living/carbon/affected_targets = list()
	/// Radius in tiles used to apply and sustain the passive aura.
	var/aura_range = 3
	/// Multiplier applied to positive moodlets within this power's aura.
	var/mood_multiplier = 1.25

/// Removes every sustained buff and the Mood Sight action from the current holder.
/datum/power/theologist_root/heartened/remove()
	clear_affected_targets()
	if(istype(action_path, /datum/action/cooldown/power/theologist/theologist_root/mood_sight))
		var/datum/action/cooldown/power/theologist/theologist_root/mood_sight/mood_sight_action = action_path
		mood_sight_action.Remove(power_holder)
		qdel(mood_sight_action)
		action_path = null
	return ..()

/// Maintains the passive aura and grants piety for affected creatures' current moods.
/datum/power/theologist_root/heartened/process(seconds_per_tick)
	if(!power_holder)
		return

	var/list/mob/living/carbon/current_targets = list()
	for(var/mob/living/carbon/nearby_carbon in range(aura_range, power_holder))
		if(!can_affect_target(nearby_carbon))
			continue

		current_targets += nearby_carbon
		var/target_mood_multiplier = get_target_mood_multiplier(nearby_carbon)
		var/datum/status_effect/power/burden_heartened/heartened_effect = nearby_carbon.has_status_effect(/datum/status_effect/power/burden_heartened)
		if(!heartened_effect)
			heartened_effect = nearby_carbon.apply_status_effect(/datum/status_effect/power/burden_heartened, src, target_mood_multiplier)
		else
			heartened_effect.add_source(src, target_mood_multiplier)

		if(heartened_effect)
			grant_mood_piety(nearby_carbon, seconds_per_tick)

	for(var/mob/living/carbon/previous_target as anything in affected_targets - current_targets)
		var/datum/status_effect/power/burden_heartened/previous_effect = previous_target?.has_status_effect(/datum/status_effect/power/burden_heartened)
		previous_effect?.remove_source(src)

	affected_targets = current_targets

/// Calculates the highest healing multiplier after snapshotting healing modifiers.
/datum/power/theologist_root/heartened/proc/get_target_mood_multiplier(mob/living/carbon/target)
	var/datum/action/cooldown/power/theologist/theologist_root/mood_sight/mood_sight_action = action_path
	if(!istype(mood_sight_action))
		return mood_multiplier

	var/healing_multiplier = mood_sight_action.snapshot_healing_multiplier(target)
	return 1 + ((mood_multiplier - 1) * healing_multiplier)

/// Returns whether the target is valid for the aura's effects or not.
/datum/power/theologist_root/heartened/proc/is_target_in_aura(mob/living/carbon/target)
	// No holder or were fukken DEAD
	if(!power_holder || QDELETED(power_holder) || power_holder.stat == DEAD)
		return FALSE
	// Nobody here to feel shit.
	if(!target || QDELETED(target) || target == power_holder || !target.mob_mood)
		return FALSE
	// OUT OF RANGE
	if(get_dist(power_holder, target) > aura_range || power_holder.z != target.z)
		return FALSE
	return TRUE

/// Returns whether this aura can apply or sustain its mood buff on the supplied target.
/datum/power/theologist_root/heartened/proc/can_affect_target(mob/living/carbon/target)
	if(!is_target_in_aura(target))
		return FALSE
	return !target.can_block_magic(MAGIC_RESISTANCE | MAGIC_RESISTANCE_MIND, charge_cost = 0)

/// Grants piety relative to a target's mood, capped at a certain amount.
/datum/power/theologist_root/heartened/proc/grant_mood_piety(mob/living/carbon/target, seconds_per_tick)
	var/datum/component/theologist_piety/piety_component = power_holder.GetComponent(/datum/component/theologist_piety)
	if(!piety_component || !target.ckey || !target.mob_mood)
		return

	var/piety_rate = 0
	var/piety_cap = 0
	switch(target.mob_mood.mood_level)
		if(MOOD_LEVEL_HAPPY1)
			piety_rate = 0.005
			piety_cap = piety_component.max_piety * 0.2
		if(MOOD_LEVEL_HAPPY2)
			piety_rate = 0.015
			piety_cap = piety_component.max_piety * 0.5
		if(MOOD_LEVEL_HAPPY3)
			piety_rate = 0.025
			piety_cap = piety_component.max_piety * 0.8
		if(MOOD_LEVEL_HAPPY4)
			piety_rate = 0.05
			piety_cap = piety_component.max_piety

	if(!piety_rate || piety_component.piety >= piety_cap)
		return

	var/piety_gain = min(piety_rate * seconds_per_tick, piety_cap - piety_component.piety)
	piety_component.adjust_piety(piety_gain, piety_cap)

/// Removes this power as a sustaining source from every status effect it currently supports.
/datum/power/theologist_root/heartened/proc/clear_affected_targets()
	for(var/mob/living/carbon/affected_target as anything in affected_targets)
		var/datum/status_effect/power/burden_heartened/heartened_effect = affected_target?.has_status_effect(/datum/status_effect/power/burden_heartened)
		heartened_effect?.remove_source(src)
	affected_targets.Cut()

/// A unique mood buff sustained by one or more nearby Heartened theologists.
/datum/status_effect/power/burden_heartened
	id = "burden_heartened"
	duration = STATUS_EFFECT_PERMANENT
	tick_interval = 1 SECONDS
	status_type = STATUS_EFFECT_UNIQUE
	alert_type = null

	/// Heartened powers whose auras currently sustain this effect.
	var/list/datum/power/theologist_root/heartened/sources = list()
	/// Mood multiplier snapshotted for this target from each source.
	var/list/source_mood_multipliers = list()
	/// The strongest mood multiplier currently applied by the sustaining auras.
	var/applied_mood_multiplier = 1

/// Applies the positive-mood multiplier and records the first sustaining source.
/datum/status_effect/power/burden_heartened/on_creation(mob/living/new_owner, datum/power/theologist_root/heartened/source_power, source_mood_multiplier)
	if(source_power)
		sources += source_power
		source_mood_multipliers[source_power] = source_mood_multiplier
	return ..()

/// Multiplies the owner's positive moodlet contribution while a mood datum is available.
/datum/status_effect/power/burden_heartened/on_apply()
	if(!owner.mob_mood)
		return FALSE
	refresh_mood_multiplier()
	return TRUE

/// Restores the owner's positive moodlet contribution and clears all sustaining sources.
/datum/status_effect/power/burden_heartened/on_remove()
	if(owner.mob_mood)
		owner.mob_mood.positive_mood_modifier /= applied_mood_multiplier
		owner.mob_mood.update_mood()
	applied_mood_multiplier = 1
	sources.Cut()
	source_mood_multipliers.Cut()
	return ..()

/// Discards invalid aura sources and removes the effect when no valid source remains.
/datum/status_effect/power/burden_heartened/tick(seconds_between_ticks)
	for(var/datum/power/theologist_root/heartened/source_power as anything in sources.Copy())
		if(QDELETED(source_power) || !source_power.is_target_in_aura(owner))
			sources -= source_power
			source_mood_multipliers -= source_power
	if(!length(sources))
		qdel(src)
		return
	refresh_mood_multiplier()

/// Adds or updates an aura source and their multiplier.
/datum/status_effect/power/burden_heartened/proc/add_source(datum/power/theologist_root/heartened/source_power, source_mood_multiplier)
	if(!source_power)
		return
	if(!(source_power in sources))
		sources += source_power
	source_mood_multipliers[source_power] = source_mood_multiplier
	refresh_mood_multiplier()

/// Removes an aura source; the status tick performs final deletion after all auras can update their support.
/datum/status_effect/power/burden_heartened/proc/remove_source(datum/power/theologist_root/heartened/source_power)
	sources -= source_power
	source_mood_multipliers -= source_power
	if(length(sources))
		refresh_mood_multiplier()

/// Replaces the applied mood multiplier with the strongest value supplied by any sustaining aura.
/datum/status_effect/power/burden_heartened/proc/refresh_mood_multiplier()
	if(!owner?.mob_mood)
		return

	var/strongest_mood_multiplier = 1
	for(var/datum/power/theologist_root/heartened/source_power as anything in sources)
		var/source_mood_multiplier = source_mood_multipliers[source_power]
		if(QDELETED(source_power) || source_mood_multiplier <= 0)
			continue
		strongest_mood_multiplier = max(strongest_mood_multiplier, source_mood_multiplier)

	if(strongest_mood_multiplier == applied_mood_multiplier)
		return

	owner.mob_mood.positive_mood_modifier /= applied_mood_multiplier
	applied_mood_multiplier = strongest_mood_multiplier
	owner.mob_mood.positive_mood_modifier *= applied_mood_multiplier
	owner.mob_mood.update_mood()

/// Toggles client-only mood-colored overlays on creatures carrying A Burden Heartened.
/datum/action/cooldown/power/theologist/theologist_root/mood_sight
	name = "Mood Sight"
	desc = "Toggle your ability to see the mood of creatures affected by A Burden Heartened."
	button_icon = 'icons/effects/effects.dmi'
	button_icon_state = "blip"
	no_cooldown_on_use = TRUE
	need_hands_free = FALSE
	disabled_by_incapacitate = FALSE

	/// Client-only images currently displayed by Mood Sight.
	var/list/mob/living/carbon/tracked_targets = list()
	var/list/image/target_images = list()

/// Disables Mood Sight and removes all of its client-only images.
/datum/action/cooldown/power/theologist/theologist_root/mood_sight/Remove(mob/removed_from)
	active = FALSE
	STOP_PROCESSING(SSprocessing, src)
	clear_mood_sight_overlays(removed_from)
	return ..()

/// Toggles Mood Sight and its periodic overlay refresh.
/datum/action/cooldown/power/theologist/theologist_root/mood_sight/use_action(mob/living/user, atom/target)
	if(!user.client)
		return FALSE

	active = !active
	if(active)
		START_PROCESSING(SSprocessing, src)
		update_mood_sight_overlays()
	else
		STOP_PROCESSING(SSprocessing, src)
		clear_mood_sight_overlays()

	user.balloon_alert(user, active ? "mood sight on" : "mood sight off")
	return TRUE

/// Reports whether Mood Sight is currently enabled for action-button styling.
/datum/action/cooldown/power/theologist/theologist_root/mood_sight/is_action_active(atom/movable/screen/movable/action_button/current_button)
	return active

/// Refreshes Mood Sight while it is toggled on.
/datum/action/cooldown/power/theologist/theologist_root/mood_sight/process(seconds_per_tick)
	if(!active || !owner?.client)
		active = FALSE
		STOP_PROCESSING(SSprocessing, src)
		clear_mood_sight_overlays()
		return
	update_mood_sight_overlays()

/// Adds, recolors, and removes client-only overlays to match currently visible valid targets.
/datum/action/cooldown/power/theologist/theologist_root/mood_sight/proc/update_mood_sight_overlays()
	if(!owner?.client)
		return

	var/list/mob/living/carbon/visible_targets = list()
	for(var/mob/living/carbon/seen_carbon in view(owner))
		var/overlay_color = get_mood_sight_color(seen_carbon)
		if(!overlay_color)
			continue

		visible_targets += seen_carbon
		var/image/mood_sight_image = target_images[seen_carbon]
		if(!mood_sight_image)
			mood_sight_image = image(icon = 'icons/effects/effects.dmi', loc = seen_carbon, icon_state = "blip", layer = BELOW_MOB_LAYER)
			owner.client.images += mood_sight_image
			target_images[seen_carbon] = mood_sight_image
		mood_sight_image.color = overlay_color

	for(var/mob/living/carbon/tracked_target as anything in tracked_targets - visible_targets)
		var/image/old_image = target_images[tracked_target]
		if(old_image)
			owner.client.images -= old_image
		target_images -= tracked_target

	tracked_targets = visible_targets

/// Returns the target's mood-level color, or null if Mood Sight cannot reveal the target.
/datum/action/cooldown/power/theologist/theologist_root/mood_sight/proc/get_mood_sight_color(mob/living/carbon/target)
	if(!target?.mob_mood || !target.has_status_effect(/datum/status_effect/power/burden_heartened))
		return null
	if(HAS_TRAIT(target, TRAIT_ANTIRESONANCE_SCRYING) || target.can_block_resonance(0))
		return null
	if(target.can_block_magic(MAGIC_RESISTANCE_MIND, charge_cost = 0))
		return null

	/// Wish the colors were keyed better but ehh well.
	switch(target.mob_mood.mood_level)
		if(MOOD_LEVEL_SAD4)
			return "#f15d36"
		if(MOOD_LEVEL_SAD3, MOOD_LEVEL_SAD2)
			return "#f38943"
		if(MOOD_LEVEL_SAD1)
			return "#dfa65b"
		if(MOOD_LEVEL_NEUTRAL)
			return "#4b96c4"
		if(MOOD_LEVEL_HAPPY1)
			return "#86d656"
		if(MOOD_LEVEL_HAPPY2, MOOD_LEVEL_HAPPY3, MOOD_LEVEL_HAPPY4)
			return "#2eeb9a"
	return null

/// Removes the blips created by Mood Sight.
/datum/action/cooldown/power/theologist/theologist_root/mood_sight/proc/clear_mood_sight_overlays(mob/viewer = owner)
	if(viewer?.client)
		for(var/mob/living/carbon/tracked_target as anything in tracked_targets)
			var/image/mood_sight_image = target_images[tracked_target]
			if(mood_sight_image)
				viewer.client.images -= mood_sight_image
	tracked_targets.Cut()
	target_images.Cut()

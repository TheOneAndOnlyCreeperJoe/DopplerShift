#define COMSIG_HOLY_AURA_APPLY_TIED_EFFECTS "holy_aura_apply_tied_effects"
#define COMSIG_HOLY_AURA_REMOVE_TIED_EFFECTS "holy_aura_remove_tied_effects"

/// Grants holy-specific magic resistance, and can project that protection onto nearby allies.
/datum/power/theologist/holy_aura
	name = "Holy Aura"
	desc = "You eminate a certain holy quality that makes you capable of resisting unholy influences. Whenever you are affected by unholy magic, you automatically resist it by spending 5 Piety.\
	\nYou are capable of eminating this aura in an area around you, extending it's effect to anyone that is within 2 spaces of you. This passively drains your Piety, and comes with the same costs as usual.\
	\nWhilst the aura is on cooldown, you lose your unholy resitance."
	security_record_text = "Subject fuels their powers by being hurt by others."
	security_threat = POWER_THREAT_MAJOR
	value = 4
	action_path = /datum/action/cooldown/power/theologist/holy_aura

	required_powers = list(/datum/power/theologist_root)
	required_allow_subtypes = TRUE

	/// How much piety it costs per anti-magic charge to block unholy.
	var/magic_block_cost = THEOLOGIST_PIETY_TRIVIAL * 5
	/// How many seconds it takes for the piety drain to tick.
	var/upkeep_tick_count = 5 SECONDS
	/// How much piety is drained per tick.
	var/upkeep_tick_cost = THEOLOGIST_PIETY_TRIVIAL
	/// Radius of the projected aura.
	var/aura_radius = 2
	/// Cooldown applied whenever the passive protection is dispelled.
	var/dispel_cooldown_time = 20 SECONDS

/datum/action/cooldown/power/theologist/holy_aura
	name = "Holy Aura"
	desc = "Project your holy protection outward, extending it to nearby allies at the cost of steady Piety drain."
	button_icon = 'icons/obj/weapons/grenade.dmi'
	button_icon_state = "holy_grenade"
	cooldown_time = 20 SECONDS

	/// The active aura emitter status on the caster.
	var/datum/status_effect/power/holy_aura_emitter/active_effect

/// Hooks the passive holy protection listeners onto the owner.
/datum/action/cooldown/power/theologist/holy_aura/Grant(mob/grant_to)
	. = ..()
	if(!.)
		return .
	RegisterSignal(grant_to, COMSIG_MOB_RECEIVE_MAGIC, PROC_REF(on_receive_magic), override = TRUE)
	RegisterSignal(grant_to, COMSIG_ATOM_DISPEL, PROC_REF(on_dispel))
	return .

/// Cleans up the emitter and holy protection listeners when the action is removed.
/datum/action/cooldown/power/theologist/holy_aura/Remove(mob/removed_from)
	if(active_effect)
		qdel(active_effect)
	if(removed_from)
		UnregisterSignal(removed_from, list(COMSIG_MOB_RECEIVE_MAGIC, COMSIG_ATOM_DISPEL))
	return ..()

/// Toggles the projected aura on and off.
/datum/action/cooldown/power/theologist/holy_aura/use_action(mob/living/user, atom/target)
	if(active_effect)
		qdel(active_effect)
		to_chat(user, span_notice("You draw your holy aura back inward."))
		return TRUE

	if(!ValidatePietyComponent())
		user.balloon_alert(user, "missing piety!")
		return FALSE

	var/datum/power/theologist/holy_aura/source_power = origin_power
	if(!istype(source_power))
		return FALSE
	if(piety_component.piety < source_power.upkeep_tick_cost)
		user.balloon_alert(user, "needs more piety!")
		return FALSE

	active_effect = user.apply_status_effect(/datum/status_effect/power/holy_aura_emitter, src)
	if(!active_effect)
		return FALSE

	active = TRUE
	build_all_button_icons(UPDATE_BUTTON_STATUS)
	to_chat(user, span_notice("A holy aura radiates from you."))
	return TRUE

/// Resolves the static power datum that configured this action.
/datum/action/cooldown/power/theologist/holy_aura/proc/get_source_power()
	RETURN_TYPE(/datum/power/theologist/holy_aura)
	if(istype(origin_power, /datum/power/theologist/holy_aura))
		return origin_power
	return null

/// Converts a blocked magic charge cost into a Piety cost.
/datum/action/cooldown/power/theologist/holy_aura/proc/get_magic_block_piety_cost(charge_cost)
	var/datum/power/theologist/holy_aura/source_power = get_source_power()
	if(!istype(source_power) || !isnum(charge_cost) || charge_cost <= 0)
		return 0
	return source_power.magic_block_cost * charge_cost

/// Attempts to block an incoming holy-resistant effect and pay its Piety cost.
/datum/action/cooldown/power/theologist/holy_aura/proc/attempt_magic_block(mob/living/protected_mob, charge_cost, list/antimagic_sources, using_aura = FALSE)
	if(!ValidatePietyComponent() || !owner)
		return NONE
	if(is_blocking_suppressed())
		return NONE
	if(length(antimagic_sources))
		return NONE

	var/piety_cost = get_magic_block_piety_cost(charge_cost)
	if(piety_cost > 0)
		if(piety_component.piety < piety_cost)
			if(using_aura || active_effect)
				deactivate_aura_from_failed_block()
			return NONE
		adjust_piety(-piety_cost)

	antimagic_sources += owner
	return COMPONENT_MAGIC_BLOCKED

/// Returns TRUE while dispel cooldown suppression is active.
/datum/action/cooldown/power/theologist/holy_aura/proc/is_blocking_suppressed()
	return next_use_time > world.time

/// Applies the post-dispel cooldown that suppresses passive holy blocking.
/datum/action/cooldown/power/theologist/holy_aura/proc/force_dispel_cooldown()
	var/datum/power/theologist/holy_aura/source_power = get_source_power()
	if(istype(source_power))
		StartCooldownSelf(source_power.dispel_cooldown_time)
	else
		StartCooldownSelf()
	build_all_button_icons(UPDATE_BUTTON_STATUS)

/// Dispels the projected aura and marks it for dispel cooldown handling.
/datum/action/cooldown/power/theologist/holy_aura/proc/dispel_aura()
	if(!active_effect)
		force_dispel_cooldown()
		return
	active_effect.was_dispelled = TRUE
	qdel(active_effect)

/// Collapses the projected aura after a failed paid block.
/datum/action/cooldown/power/theologist/holy_aura/proc/deactivate_aura_from_failed_block()
	if(!active_effect)
		return
	to_chat(owner, span_warning("Your holy aura collapses as your conviction falters."))
	qdel(active_effect)

/// Passive self-protection hook for incoming unholy magic.
/datum/action/cooldown/power/theologist/holy_aura/proc/on_receive_magic(mob/living/source, casted_magic_flags, charge_cost, list/antimagic_sources)
	SIGNAL_HANDLER
	if(!(casted_magic_flags & MAGIC_RESISTANCE_HOLY))
		return NONE
	return attempt_magic_block(owner, charge_cost, antimagic_sources, FALSE)

/// Handles dispelling either the projected aura or the passive holy protection.
/datum/action/cooldown/power/theologist/holy_aura/proc/on_dispel(mob/owner, atom/dispeller)
	SIGNAL_HANDLER
	if(!src.owner)
		return NONE
	if(active_effect)
		to_chat(src.owner, span_userdanger("Your holy aura is dispelled!"))
		dispel_aura()
	else
		to_chat(src.owner, span_userdanger("Your holy protection is temporarily suppressed!"))
		force_dispel_cooldown()
	return DISPEL_RESULT_DISPELLED

/datum/status_effect/power/holy_aura_emitter
	id = "holy_aura_emitter"
	alert_type = /atom/movable/screen/alert/status_effect/holy_aura_emitter
	duration = STATUS_EFFECT_PERMANENT
	processing_speed = STATUS_EFFECT_NORMAL_PROCESS
	tick_interval = 5 SECONDS

	/// Action that created this emitter.
	var/datum/action/cooldown/power/theologist/holy_aura/source_action
	/// Bubble field that applies the aura to nearby mobs.
	var/datum/proximity_monitor/advanced/bubble/holy_aura/aura_field
	/// Whether this emitter ended because of a dispel.
	var/was_dispelled = FALSE

/atom/movable/screen/alert/status_effect/holy_aura_emitter
	name = "Holy Aura"
	desc = "Your holy protection currently radiates outward, sheltering nearby allies from unholy magic."
	icon = 'icons/obj/weapons/grenade.dmi'
	icon_state = "holy_grenade"

/// Captures the owning action and inherits its configured upkeep interval.
/datum/status_effect/power/holy_aura_emitter/on_creation(mob/living/new_owner, datum/action/cooldown/power/theologist/holy_aura/passed_action)
	source_action = passed_action
	var/datum/power/theologist/holy_aura/source_power = source_action?.get_source_power()
	if(istype(source_power))
		tick_interval = source_power.upkeep_tick_count
	. = ..()

/// Starts the projected aura field and syncs action UI state.
/datum/status_effect/power/holy_aura_emitter/on_apply()
	if(!owner || !source_action)
		return FALSE

	var/datum/power/theologist/holy_aura/source_power = source_action.get_source_power()
	if(!istype(source_power))
		return FALSE

	aura_field = new(owner, source_power.aura_radius, TRUE, owner, source_action)
	source_action.active = TRUE
	source_action.active_effect = src
	source_action.build_all_button_icons(UPDATE_BUTTON_STATUS)
	return TRUE

/// Shuts down the projected aura field and restores action state.
/datum/status_effect/power/holy_aura_emitter/on_remove()
	QDEL_NULL(aura_field)
	if(source_action)
		if(was_dispelled)
			source_action.force_dispel_cooldown()
		source_action.active = FALSE
		source_action.active_effect = null
		source_action.build_all_button_icons(UPDATE_BUTTON_STATUS)
	return

/// Pays periodic upkeep and ends the aura if its owner can no longer sustain it.
/datum/status_effect/power/holy_aura_emitter/tick(seconds_between_ticks)
	if(!source_action || QDELETED(source_action) || !owner)
		qdel(src)
		return

	if(owner.stat == DEAD)
		qdel(src)
		return

	if(!source_action.ValidatePietyComponent())
		qdel(src)
		return

	var/datum/power/theologist/holy_aura/source_power = source_action.get_source_power()
	if(!istype(source_power))
		qdel(src)
		return

	if(source_action.get_piety() < source_power.upkeep_tick_cost)
		source_action.deactivate_aura_from_failed_block()
		return

	source_action.adjust_piety(-source_power.upkeep_tick_cost)

/datum/proximity_monitor/advanced/bubble/holy_aura
	edge_is_a_field = TRUE

	/// Weakref to the action supplying this aura mechanics.
	var/datum/weakref/source_action_ref
	/// Stable source identifier used to prevent overlap cleanup bugs.
	var/source_ref_key

/// Captures the action instance responsible for this aura field.
/datum/proximity_monitor/advanced/bubble/holy_aura/New(atom/_host, range, _ignore_if_not_on_turf = TRUE, atom/projector, datum/action/cooldown/power/theologist/holy_aura/source_action)
	. = ..()
	source_action_ref = WEAKREF(source_action)
	source_ref_key = REF(source_action)

/// Reuses the space protection field sprites for the holy aura border.
/datum/proximity_monitor/advanced/bubble/holy_aura/setup_effect_directions()
	var/list/direction_states = list(
		"[SOUTH]" = "space_protection_south",
		"[NORTH]" = "space_protection_north",
		"[WEST]" = "space_protection_west",
		"[EAST]" = "space_protection_east",
		"[NORTHWEST]" = "space_protection_northwest",
		"[SOUTHWEST]" = "space_protection_southwest",
		"[NORTHEAST]" = "space_protection_northeast",
		"[SOUTHEAST]" = "space_protection_southeast",
	)
	effect_direction_images = list(
	)
	for(var/direction_key in direction_states)
		var/icon_state = direction_states[direction_key]
		var/icon/recolored_field = icon('icons/effects/fields.dmi', icon_state, frame = 1)
		// Force the precolored field art to grayscale before applying theologian yellow.
		recolored_field.MapColors(0.33, 0.33, 0.33, 0.33, 0.33, 0.33, 0.33, 0.33, 0.33)
		recolored_field.Blend(rgb(160, 160, 160), ICON_ADD)
		recolored_field.Blend(POWER_COLOR_THEOLOGIST, ICON_MULTIPLY)
		effect_direction_images[direction_key] = image(recolored_field)

/// Resolves the action instance currently driving this aura field.
/datum/proximity_monitor/advanced/bubble/holy_aura/proc/get_source_action()
	RETURN_TYPE(/datum/action/cooldown/power/theologist/holy_aura)
	return source_action_ref?.resolve()

/// Applies the shared holy aura status to an eligible mob inside the field.
/datum/proximity_monitor/advanced/bubble/holy_aura/proc/grant_holy_aura(mob/living/protected_mob)
	var/datum/action/cooldown/power/theologist/holy_aura/source_action = get_source_action()
	if(!istype(source_action) || !protected_mob || protected_mob == source_action.owner)
		return
	protected_mob.apply_status_effect(/datum/status_effect/power/holy_aura, source_action)

/// Removes this field's holy aura status from a mob if it owns that status.
/datum/proximity_monitor/advanced/bubble/holy_aura/proc/remove_holy_aura(mob/living/protected_mob)
	if(!protected_mob)
		return
	protected_mob.remove_status_effect(/datum/status_effect/power/holy_aura, source_ref_key)

/// Applies the holy aura when a mob enters an interior field turf.
/datum/proximity_monitor/advanced/bubble/holy_aura/field_turf_crossed(atom/movable/movable, turf/old_location, turf/new_location)
	if(!isliving(movable))
		return
	grant_holy_aura(movable)

/// Applies the holy aura when a mob enters an edge turf.
/datum/proximity_monitor/advanced/bubble/holy_aura/field_edge_crossed(atom/movable/movable, turf/location, turf/old_location)
	if(!isliving(movable))
		return
	grant_holy_aura(movable)

/// Removes the holy aura when a mob exits the field interior.
/datum/proximity_monitor/advanced/bubble/holy_aura/field_turf_uncrossed(atom/movable/movable, turf/old_location, turf/new_location)
	if(!isliving(movable) || get_dist(new_location, host) <= (edge_is_a_field ? current_range : current_range - 1))
		return
	remove_holy_aura(movable)

/// Removes the holy aura when a mob exits the field edge.
/datum/proximity_monitor/advanced/bubble/holy_aura/field_edge_uncrossed(atom/movable/movable, turf/old_location, turf/new_location)
	if(!isliving(movable) || get_dist(new_location, host) <= (edge_is_a_field ? current_range : current_range - 1))
		return
	remove_holy_aura(movable)

/// Applies the holy aura to all mobs currently on a newly tracked field turf.
/datum/proximity_monitor/advanced/bubble/holy_aura/setup_field_turf(turf/target)
	for(var/mob/living/protected_mob in target)
		grant_holy_aura(protected_mob)

/// Removes the holy aura from all mobs on a turf that leaves the field.
/datum/proximity_monitor/advanced/bubble/holy_aura/cleanup_field_turf(turf/target)
	for(var/mob/living/protected_mob in target)
		remove_holy_aura(protected_mob)

/datum/status_effect/power/holy_aura
	id = "holy_aura"
	duration = STATUS_EFFECT_PERMANENT
	tick_interval = STATUS_EFFECT_NO_TICK
	status_type = STATUS_EFFECT_UNIQUE
	alert_type = null

	/// Weakref to the action that owns this aura mechanics.
	var/datum/weakref/source_action_ref
	/// Stable source identifier used for overlap-safe cleanup.
	var/source_ref_key
	/// Mood event key tied to the source action instance.
	var/mood_event_key

/// Captures the owning holy aura action for overlap arbitration and cleanup.
/datum/status_effect/power/holy_aura/on_creation(mob/living/new_owner, datum/action/cooldown/power/theologist/holy_aura/source_action)
	source_action_ref = WEAKREF(source_action)
	source_ref_key = REF(source_action)
	mood_event_key = "holy_aura_[source_ref_key]"
	. = ..()

/// Enables shared holy blocking and applies tied aura benefits to the recipient.
/datum/status_effect/power/holy_aura/on_apply()
	var/datum/action/cooldown/power/theologist/holy_aura/source_action = source_action_ref?.resolve()
	if(!owner || !istype(source_action) || owner == source_action.owner)
		return FALSE

	RegisterSignal(owner, COMSIG_MOB_RECEIVE_MAGIC, PROC_REF(on_receive_magic), override = TRUE)
	RegisterSignal(owner, COMSIG_ATOM_DISPEL, PROC_REF(on_dispel))
	owner.add_mood_event(mood_event_key, /datum/mood_event/holy_aura)
	SEND_SIGNAL(src, COMSIG_HOLY_AURA_APPLY_TIED_EFFECTS, owner, source_action)
	return TRUE

/// Removes shared holy blocking and any tied aura benefits from the recipient.
/datum/status_effect/power/holy_aura/on_remove()
	var/datum/action/cooldown/power/theologist/holy_aura/source_action = source_action_ref?.resolve()
	if(owner)
		UnregisterSignal(owner, list(COMSIG_MOB_RECEIVE_MAGIC, COMSIG_ATOM_DISPEL))
		owner.clear_mood_event(mood_event_key)
	SEND_SIGNAL(src, COMSIG_HOLY_AURA_REMOVE_TIED_EFFECTS, owner, source_action)
	return

/// Only allows removal when the matching source action requests it.
/datum/status_effect/power/holy_aura/before_remove(removing_source_ref)
	return istext(removing_source_ref) && removing_source_ref == source_ref_key

/// Routes incoming unholy magic through the owning action for paid shared blocking.
/datum/status_effect/power/holy_aura/proc/on_receive_magic(mob/living/source, casted_magic_flags, charge_cost, list/antimagic_sources)
	SIGNAL_HANDLER
	if(!(casted_magic_flags & MAGIC_RESISTANCE_HOLY))
		return NONE
	if(length(antimagic_sources))
		return NONE

	var/datum/action/cooldown/power/theologist/holy_aura/source_action = source_action_ref?.resolve()
	if(!istype(source_action) || !source_action.active_effect)
		qdel(src)
		return NONE

	return source_action.attempt_magic_block(owner, charge_cost, antimagic_sources, TRUE)

/// Dispels the recipient-side aura protection immediately.
/datum/status_effect/power/holy_aura/proc/on_dispel(mob/owner, atom/dispeller)
	SIGNAL_HANDLER
	qdel(src)
	return DISPEL_RESULT_DISPELLED

/datum/mood_event/holy_aura
	description = "A holy warmth steadies my spirit."
	mood_change = 2

#undef COMSIG_HOLY_AURA_APPLY_TIED_EFFECTS
#undef COMSIG_HOLY_AURA_REMOVE_TIED_EFFECTS

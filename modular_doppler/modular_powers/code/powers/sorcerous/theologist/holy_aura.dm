#define COMSIG_HOLY_AURA_APPLY_TIED_EFFECTS "holy_aura_apply_tied_effects"
#define COMSIG_HOLY_AURA_REMOVE_TIED_EFFECTS "holy_aura_remove_tied_effects"

/// Grants holy-specific magic resistance, and can project that protection onto nearby allies.
/datum/power/theologist/holy_aura
	name = "Holy Aura"
	desc = "You eminate a certain holy quality that makes you capable of resisting unholy influences. Whenever you are affected by unholy magic, you automatically resist it by spending 5 Piety.\
	\nYou are capable of eminating this aura in an area around you, extending it's effect to anyone that is within 2 spaces of you. This passively drains your Piety, and comes with the same costs as usual."
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
	/// Cached piety component for passive blocking.
	var/datum/component/theologist_piety/piety_component

/datum/power/theologist/holy_aura/post_add()
	. = ..()
	ValidatePietyComponent()
	RegisterSignal(power_holder, COMSIG_MOB_RECEIVE_MAGIC, PROC_REF(on_receive_magic), override = TRUE)
	RegisterSignal(power_holder, COMSIG_ATOM_DISPEL, PROC_REF(on_dispel))

/datum/power/theologist/holy_aura/remove()
	var/datum/action/cooldown/power/theologist/holy_aura/source_action = get_action()
	if(source_action?.active_effect)
		qdel(source_action.active_effect)
	if(power_holder)
		UnregisterSignal(power_holder, list(COMSIG_MOB_RECEIVE_MAGIC, COMSIG_ATOM_DISPEL))
	return ..()

/datum/power/theologist/holy_aura/proc/ValidatePietyComponent()
	if(power_holder)
		piety_component = power_holder.GetComponent(/datum/component/theologist_piety)
	return !isnull(piety_component)

/datum/power/theologist/holy_aura/proc/get_action()
	RETURN_TYPE(/datum/action/cooldown/power/theologist/holy_aura)
	if(istype(action_path, /datum/action/cooldown/power/theologist/holy_aura))
		return action_path
	return null

/datum/power/theologist/holy_aura/proc/get_magic_block_piety_cost(charge_cost)
	if(!isnum(charge_cost) || charge_cost <= 0)
		return 0
	return magic_block_cost * charge_cost

/datum/power/theologist/holy_aura/proc/is_aura_active()
	var/datum/action/cooldown/power/theologist/holy_aura/source_action = get_action()
	return !isnull(source_action?.active_effect)

/datum/power/theologist/holy_aura/proc/attempt_magic_block(mob/living/protected_mob, charge_cost, list/antimagic_sources, using_aura = FALSE)
	if(!ValidatePietyComponent() || !power_holder)
		return NONE

	var/datum/action/cooldown/power/theologist/holy_aura/source_action = get_action()
	if(source_action?.is_blocking_suppressed())
		return NONE

	if(length(antimagic_sources))
		return NONE

	var/piety_cost = get_magic_block_piety_cost(charge_cost)
	if(piety_cost > 0)
		if(piety_component.piety < piety_cost)
			if(using_aura || source_action?.active_effect)
				source_action?.deactivate_aura_from_failed_block()
			return NONE
		piety_component.adjust_piety(-piety_cost)

	antimagic_sources += power_holder
	return COMPONENT_MAGIC_BLOCKED

/datum/power/theologist/holy_aura/proc/on_receive_magic(mob/living/source, casted_magic_flags, charge_cost, list/antimagic_sources)
	SIGNAL_HANDLER
	if(!(casted_magic_flags & MAGIC_RESISTANCE_HOLY))
		return NONE
	return attempt_magic_block(power_holder, charge_cost, antimagic_sources, FALSE)

/datum/power/theologist/holy_aura/proc/on_dispel(mob/owner, atom/dispeller)
	SIGNAL_HANDLER
	if(!power_holder)
		return NONE

	var/datum/action/cooldown/power/theologist/holy_aura/source_action = get_action()
	if(source_action?.active_effect)
		to_chat(power_holder, span_userdanger("Your holy aura is dispelled!"))
		source_action.dispel_aura()
	else
		to_chat(power_holder, span_userdanger("Your holy protection is temporarily suppressed!"))
		source_action?.force_dispel_cooldown()

	return DISPEL_RESULT_DISPELLED

/datum/action/cooldown/power/theologist/holy_aura
	name = "Holy Aura"
	desc = "Project your holy protection outward, extending it to nearby allies at the cost of steady Piety drain."
	button_icon = 'icons/mob/actions/actions_cult.dmi'
	button_icon_state = "shield"
	cooldown_time = 20 SECONDS

	/// The active aura emitter status on the caster.
	var/datum/status_effect/power/holy_aura_emitter/active_effect

/datum/action/cooldown/power/theologist/holy_aura/Activate(atom/target)
	var/mob/living/user = owner
	if(!user || !IsAvailable(feedback = TRUE))
		return FALSE
	return try_use(user, target = null)

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

/datum/action/cooldown/power/theologist/holy_aura/proc/is_blocking_suppressed()
	return next_use_time > world.time

/datum/action/cooldown/power/theologist/holy_aura/proc/force_dispel_cooldown()
	var/datum/power/theologist/holy_aura/source_power = origin_power
	if(istype(source_power))
		StartCooldownSelf(source_power.dispel_cooldown_time)
	else
		StartCooldownSelf()
	build_all_button_icons(UPDATE_BUTTON_STATUS)

/datum/action/cooldown/power/theologist/holy_aura/proc/dispel_aura()
	if(!active_effect)
		force_dispel_cooldown()
		return
	active_effect.was_dispelled = TRUE
	qdel(active_effect)

/datum/action/cooldown/power/theologist/holy_aura/proc/deactivate_aura_from_failed_block()
	if(!active_effect)
		return
	to_chat(owner, span_warning("Your holy aura collapses as your conviction falters."))
	qdel(active_effect)

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
	icon = 'icons/mob/actions/actions_cult.dmi'
	icon_state = "shield"

/datum/status_effect/power/holy_aura_emitter/on_creation(mob/living/new_owner, datum/action/cooldown/power/theologist/holy_aura/passed_action)
	. = ..()
	source_action = passed_action
	var/datum/power/theologist/holy_aura/source_power = source_action?.origin_power
	if(istype(source_power))
		tick_interval = source_power.upkeep_tick_count

/datum/status_effect/power/holy_aura_emitter/on_apply()
	if(!owner || !source_action)
		return FALSE

	var/datum/power/theologist/holy_aura/source_power = source_action.origin_power
	if(!istype(source_power))
		return FALSE

	aura_field = new(owner, source_power.aura_radius, TRUE, owner, source_power)
	source_action.active = TRUE
	source_action.active_effect = src
	source_action.build_all_button_icons(UPDATE_BUTTON_STATUS)
	return TRUE

/datum/status_effect/power/holy_aura_emitter/on_remove()
	QDEL_NULL(aura_field)
	if(source_action)
		if(was_dispelled)
			source_action.force_dispel_cooldown()
		source_action.active = FALSE
		source_action.active_effect = null
		source_action.build_all_button_icons(UPDATE_BUTTON_STATUS)
	return

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

	var/datum/power/theologist/holy_aura/source_power = source_action.origin_power
	if(!istype(source_power))
		qdel(src)
		return

	if(source_action.get_piety() < source_power.upkeep_tick_cost)
		source_action.deactivate_aura_from_failed_block()
		return

	source_action.adjust_piety(-source_power.upkeep_tick_cost)

/datum/proximity_monitor/advanced/bubble/holy_aura
	edge_is_a_field = TRUE

	/// Weakref to the power supplying this aura.
	var/datum/weakref/source_power_ref
	/// Stable source identifier used to prevent overlap cleanup bugs.
	var/source_ref_key

/datum/proximity_monitor/advanced/bubble/holy_aura/New(atom/_host, range, _ignore_if_not_on_turf = TRUE, atom/projector, datum/power/theologist/holy_aura/source_power)
	. = ..()
	source_power_ref = WEAKREF(source_power)
	source_ref_key = REF(source_power)

/datum/proximity_monitor/advanced/bubble/holy_aura/setup_effect_directions()
	effect_direction_images = list(
		"[SOUTH]" = image('icons/effects/fields.dmi', icon_state = "space_protection_south"),
		"[NORTH]" = image('icons/effects/fields.dmi', icon_state = "space_protection_north"),
		"[WEST]" = image('icons/effects/fields.dmi', icon_state = "space_protection_west"),
		"[EAST]" = image('icons/effects/fields.dmi', icon_state = "space_protection_east"),
		"[NORTHWEST]" = image('icons/effects/fields.dmi', icon_state = "space_protection_northwest"),
		"[SOUTHWEST]" = image('icons/effects/fields.dmi', icon_state = "space_protection_southwest"),
		"[NORTHEAST]" = image('icons/effects/fields.dmi', icon_state = "space_protection_northeast"),
		"[SOUTHEAST]" = image('icons/effects/fields.dmi', icon_state = "space_protection_southeast"),
	)

/datum/proximity_monitor/advanced/bubble/holy_aura/proc/get_source_power()
	RETURN_TYPE(/datum/power/theologist/holy_aura)
	return source_power_ref?.resolve()

/datum/proximity_monitor/advanced/bubble/holy_aura/proc/grant_holy_aura(mob/living/protected_mob)
	var/datum/power/theologist/holy_aura/source_power = get_source_power()
	if(!istype(source_power) || !protected_mob || protected_mob == source_power.power_holder)
		return
	protected_mob.apply_status_effect(/datum/status_effect/power/holy_aura, source_power)

/datum/proximity_monitor/advanced/bubble/holy_aura/proc/remove_holy_aura(mob/living/protected_mob)
	if(!protected_mob)
		return
	protected_mob.remove_status_effect(/datum/status_effect/power/holy_aura, source_ref_key)

/datum/proximity_monitor/advanced/bubble/holy_aura/field_turf_crossed(atom/movable/movable, turf/old_location, turf/new_location)
	if(!isliving(movable))
		return
	grant_holy_aura(movable)

/datum/proximity_monitor/advanced/bubble/holy_aura/field_edge_crossed(atom/movable/movable, turf/location, turf/old_location)
	if(!isliving(movable))
		return
	grant_holy_aura(movable)

/datum/proximity_monitor/advanced/bubble/holy_aura/field_turf_uncrossed(atom/movable/movable, turf/old_location, turf/new_location)
	if(!isliving(movable) || get_dist(new_location, host) <= (edge_is_a_field ? current_range : current_range - 1))
		return
	remove_holy_aura(movable)

/datum/proximity_monitor/advanced/bubble/holy_aura/field_edge_uncrossed(atom/movable/movable, turf/old_location, turf/new_location)
	if(!isliving(movable) || get_dist(new_location, host) <= (edge_is_a_field ? current_range : current_range - 1))
		return
	remove_holy_aura(movable)

/datum/proximity_monitor/advanced/bubble/holy_aura/setup_field_turf(turf/target)
	for(var/mob/living/protected_mob in target)
		grant_holy_aura(protected_mob)

/datum/proximity_monitor/advanced/bubble/holy_aura/cleanup_field_turf(turf/target)
	for(var/mob/living/protected_mob in target)
		remove_holy_aura(protected_mob)

/datum/status_effect/power/holy_aura
	id = "holy_aura"
	duration = STATUS_EFFECT_PERMANENT
	tick_interval = STATUS_EFFECT_NO_TICK
	status_type = STATUS_EFFECT_UNIQUE
	alert_type = null

	/// Weakref to the power that owns this aura.
	var/datum/weakref/source_power_ref
	/// Stable source identifier used for overlap-safe cleanup.
	var/source_ref_key
	/// Mood event key tied to the source power.
	var/mood_event_key

/datum/status_effect/power/holy_aura/on_creation(mob/living/new_owner, datum/power/theologist/holy_aura/source_power)
	. = ..()
	source_power_ref = WEAKREF(source_power)
	source_ref_key = REF(source_power)
	mood_event_key = "holy_aura_[source_ref_key]"

/datum/status_effect/power/holy_aura/on_apply()
	var/datum/power/theologist/holy_aura/source_power = source_power_ref?.resolve()
	if(!owner || !istype(source_power) || owner == source_power.power_holder)
		return FALSE

	RegisterSignal(owner, COMSIG_MOB_RECEIVE_MAGIC, PROC_REF(on_receive_magic), override = TRUE)
	RegisterSignal(owner, COMSIG_ATOM_DISPEL, PROC_REF(on_dispel))
	owner.add_mood_event(mood_event_key, /datum/mood_event/holy_aura)
	SEND_SIGNAL(src, COMSIG_HOLY_AURA_APPLY_TIED_EFFECTS, owner, source_power)
	return TRUE

/datum/status_effect/power/holy_aura/on_remove()
	var/datum/power/theologist/holy_aura/source_power = source_power_ref?.resolve()
	if(owner)
		UnregisterSignal(owner, list(COMSIG_MOB_RECEIVE_MAGIC, COMSIG_ATOM_DISPEL))
		owner.clear_mood_event(mood_event_key)
	SEND_SIGNAL(src, COMSIG_HOLY_AURA_REMOVE_TIED_EFFECTS, owner, source_power)
	return

/datum/status_effect/power/holy_aura/before_remove(removing_source_ref)
	return istext(removing_source_ref) && removing_source_ref == source_ref_key

/datum/status_effect/power/holy_aura/proc/on_receive_magic(mob/living/source, casted_magic_flags, charge_cost, list/antimagic_sources)
	SIGNAL_HANDLER
	if(!(casted_magic_flags & MAGIC_RESISTANCE_HOLY))
		return NONE
	if(length(antimagic_sources))
		return NONE

	var/datum/power/theologist/holy_aura/source_power = source_power_ref?.resolve()
	if(!istype(source_power) || !source_power.is_aura_active())
		qdel(src)
		return NONE

	return source_power.attempt_magic_block(owner, charge_cost, antimagic_sources, TRUE)

/datum/status_effect/power/holy_aura/proc/on_dispel(mob/owner, atom/dispeller)
	SIGNAL_HANDLER
	qdel(src)
	return DISPEL_RESULT_DISPELLED

/datum/mood_event/holy_aura
	description = "A holy warmth steadies my spirit."
	mood_change = 2

#undef COMSIG_HOLY_AURA_APPLY_TIED_EFFECTS
#undef COMSIG_HOLY_AURA_REMOVE_TIED_EFFECTS

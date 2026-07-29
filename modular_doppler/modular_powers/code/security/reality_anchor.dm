/obj/structure/reality_anchor
	name = "miniature reality anchor"
	desc = "The chiseled out Eschatite remains of an anchor, smoothed and cobbled together. Crude machinery is managing to keep it docile; but when enabled, it will start enforcing normality back in a large area around it."
	icon = 'modular_doppler/modular_powers/icons/items/reality_anchor.dmi'
	icon_state = "reality_anchor"
	density = TRUE
	max_integrity = 600 // tonky

	/// Is it on/off
	var/active = FALSE

	/// Pulse interval
	var/pulse_interval = 6 SECONDS
	/// Time until the next pulse
	var/next_pulse_time = 0

	/// Range in turfs
	var/pulse_range = 6

	/// Ripple filter while active.
	var/ripple_filter_id = "reality_anchor_ripple"

/obj/structure/reality_anchor/Destroy()
	STOP_PROCESSING(SSobj, src)
	apply_ripple_filter(FALSE)
	. = ..()

// Turns the thing on or off after the do_after.
/obj/structure/reality_anchor/attack_hand(mob/user, list/modifiers)
	. = ..()
	if(.)
		return
	var/action_word = active ? "deactivate" : "activate"
	var/action_word_past_tense = active ? "deactivating" : "activating"
	user.visible_message(
		span_warning("[user] begins to [action_word] the reality anchor..."),
		span_warning("You begin to [action_word] the reality anchor...")
	)
	if(!do_after(user, 3 SECONDS, target = src))
		return
	user.visible_message(
		span_warning("[user] finishes [action_word_past_tense] the reality anchor."),
		span_warning("You finish [action_word_past_tense] the reality anchor.")
	)
	toggle_anchor(user)

/// Switches it on or off.
/obj/structure/reality_anchor/proc/toggle_anchor(mob/user)
	active = !active
	if(active)
		anchored = TRUE
		apply_ripple_filter(TRUE)
		playsound(src, 'sound/effects/magic/repulse.ogg', 75, TRUE)
		pulse()
		next_pulse_time = world.time + pulse_interval
		START_PROCESSING(SSobj, src)
		return
	anchored = FALSE
	apply_ripple_filter(FALSE)
	STOP_PROCESSING(SSobj, src)

// Countdown til dispel pulse.
/obj/structure/reality_anchor/process(seconds_per_tick)
	if(!active)
		return
	if(world.time < next_pulse_time)
		return
	pulse()
	next_pulse_time = world.time + pulse_interval

/// Dispel AoE effect.
/obj/structure/reality_anchor/proc/pulse()
	var/turf/center = get_turf(src)
	if(!center)
		return
	var/obj/effect/temp_visual/circle_wave/reality_anchor/pulse_fx = new(center)
	pulse_fx.amount_to_scale = pulse_range + 2 // falls short without the +1
	// We get EVERYTHING in range and dispel it. This shouldn't be too much of a lag-machine (hopefully)
	for(var/atom/movable/target in range(pulse_range, center))
		if(isliving(target))
			var/mob/living/living_target = target
			living_target.dispel(src, DISPEL_CASCADE_CARRIED)
			// Being immune to resonance or a heretic prevents the application of the silence effect
			if(living_target.can_block_resonance() || living_target.mind?.has_antag_datum(/datum/antagonist/heretic))
				continue
			living_target.apply_status_effect(/datum/status_effect/power/reality_anchor_silenced)
		else if(isobj(target))
			target.dispel(src)

/// Applies a rippling effect.
/obj/structure/reality_anchor/proc/apply_ripple_filter(active_state)
	if(active_state)
		add_filter(ripple_filter_id, 2, list("type" = "ripple", "flags" = WAVE_BOUNDED, "radius" = 0, "size" = 2))
		var/filter = get_filter(ripple_filter_id)
		if(filter)
			animate(filter, radius = 0, time = 0.2 SECONDS, size = 2, easing = JUMP_EASING, loop = -1, flags = ANIMATION_PARALLEL)
			animate(radius = 32, time = 1.5 SECONDS, size = 0)
		return
	remove_filter(ripple_filter_id)

// Status effect responsible for silencing.
/datum/status_effect/power/reality_anchor_silenced
	id = "reality_anchor_silenced"
	status_type = STATUS_EFFECT_REFRESH
	alert_type = /atom/movable/screen/alert/status_effect/reality_anchor_silenced
	show_duration = TRUE
	duration = 10 SECONDS
	tick_interval = 1 SECONDS
	/// The owner's power archetype when this effect was applied.
	var/owner_archetype = POWER_ARCHETYPE_MORTAL
	/// Filter key used on the owner's game plane master.
	var/blur_filter_id = "reality_anchor_blur"
	/// Exact plane master carrying our filter, retained for reliable cleanup.
	var/atom/movable/plane_master_controller/blur_plane_master_controller

/datum/status_effect/power/reality_anchor_silenced/on_apply()
	set_anchor_archetype()
	if(owner_archetype != POWER_ARCHETYPE_MORTAL) // non-mortals hear a grating sound
		owner.playsound_local(owner, 'sound/effects/curse/curse5.ogg', 50, FALSE) // specifically this one because it sounds like a scream.
	ADD_TRAIT(owner, TRAIT_RESONANCE_SILENCED, TRAIT_STATUS_EFFECT(id))
	owner.add_mood_event(id, get_anchor_moodlet())
	var/screen_effect_type = get_anchor_screen_effect()
	if(screen_effect_type)
		owner.overlay_fullscreen("reality_anchor_static", screen_effect_type)
	apply_anchor_blur()
	return TRUE

/datum/status_effect/power/reality_anchor_silenced/on_remove()
	REMOVE_TRAIT(owner, TRAIT_RESONANCE_SILENCED, TRAIT_STATUS_EFFECT(id))
	owner.clear_mood_event(id)
	owner.clear_fullscreen("reality_anchor_static")
	owner.stop_sound_channel(CHANNEL_HEARTBEAT)
	clear_anchor_blur()
	return

/datum/status_effect/power/reality_anchor_silenced/tick(seconds_between_ticks)
	if(owner_archetype == POWER_ARCHETYPE_MORTAL) // normies don't hear the heartbeat
		return
	owner.playsound_local(owner, 'sound/effects/health/slowbeat.ogg', 40, FALSE, channel = CHANNEL_HEARTBEAT, use_reverb = FALSE)

/// Determines and stores the owner's archetype for all of the anchor's effects.
/datum/status_effect/power/reality_anchor_silenced/proc/set_anchor_archetype()
	owner_archetype = POWER_ARCHETYPE_MORTAL
	if(owner.has_power_in_path(POWER_PATH_THAUMATURGE) || owner.has_power_in_path(POWER_PATH_THEOLOGIST))
		owner_archetype = POWER_ARCHETYPE_SORCEROUS
		return
	if(owner.has_power_in_path(POWER_PATH_PSYKER) || owner.has_power_in_path(POWER_PATH_CULTIVATOR) || owner.has_power_in_path(POWER_PATH_ABERRANT))
		owner_archetype = POWER_ARCHETYPE_RESONANT

/// Delegates the appropriate moodlet to the appropriate archetype.
/datum/status_effect/power/reality_anchor_silenced/proc/get_anchor_moodlet()
	if(owner_archetype == POWER_ARCHETYPE_SORCEROUS)
		return /datum/mood_event/reality_anchor_silenced/sorcerous
	if(owner_archetype == POWER_ARCHETYPE_RESONANT)
		return /datum/mood_event/reality_anchor_silenced/resonant
	return /datum/mood_event/reality_anchor_silenced/mortal

/// Returns the static overlay appropriate for the owner's archetype. Mortals receive no overlay.
/datum/status_effect/power/reality_anchor_silenced/proc/get_anchor_screen_effect()
	if(owner_archetype == POWER_ARCHETYPE_SORCEROUS)
		return /atom/movable/screen/fullscreen/reality_anchor_static/sorcerous
	if(owner_archetype == POWER_ARCHETYPE_RESONANT)
		return /atom/movable/screen/fullscreen/reality_anchor_static/resonant
	return null

/// Applies a constant radial blur to the owner's rendered game plane.
/datum/status_effect/power/reality_anchor_silenced/proc/apply_anchor_blur()
	var/blur_size = get_anchor_blur_size()
	if(!blur_size || !owner.hud_used)
		return
	blur_plane_master_controller = owner.hud_used.plane_master_controllers[PLANE_MASTERS_GAME]
	if(!blur_plane_master_controller)
		return
	blur_plane_master_controller.add_filter(blur_filter_id, 1, list("type" = "radial_blur", "size" = blur_size))

/// Removes the reality anchor's blur without disturbing other game-plane filters.
/datum/status_effect/power/reality_anchor_silenced/proc/clear_anchor_blur()
	if(!QDELETED(blur_plane_master_controller))
		blur_plane_master_controller.remove_filter(blur_filter_id)
	blur_plane_master_controller = null

/// Returns blur strength appropriate for the owner's archetype. Mortals receive no blur.
/datum/status_effect/power/reality_anchor_silenced/proc/get_anchor_blur_size()
	if(owner_archetype == POWER_ARCHETYPE_SORCEROUS)
		return 0.02
	if(owner_archetype == POWER_ARCHETYPE_RESONANT)
		return 0.01
	return 0

/atom/movable/screen/fullscreen/reality_anchor_static
	icon = 'icons/hud/screen_gen.dmi'
	icon_state = "noise"
	screen_loc = "WEST,SOUTH to EAST,NORTH"
	color = "#17333a"

/atom/movable/screen/fullscreen/reality_anchor_static/sorcerous
	alpha = 140

/atom/movable/screen/fullscreen/reality_anchor_static/resonant
	alpha = 70

/atom/movable/screen/alert/status_effect/reality_anchor_silenced
	name = "Silenced"
	desc = "Resonant powers are supressed around the reality anchor!"
	icon = 'modular_doppler/modular_powers/icons/items/reality_anchor.dmi'
	icon_state = "reality_anchor"

/datum/mood_event/reality_anchor_silenced
	description = "I feel like something's different in the air."
	mood_change = 0

/datum/mood_event/reality_anchor_silenced/sorcerous
	description = "MY WHOLE BODY WRITHES WITHOUT THE MAGIC THAT SUSTAINS IT, LIKE IT IS DROWNING IN A BLEACHED MORASS OF MUNDANITY!"
	mood_change = -20
	special_screen_obj = "mood_despair"

/datum/mood_event/reality_anchor_silenced/resonant
	description = "My chest hurts, my stomach cramps, my mind aches. My magic is supressed; and it makes me sick!"
	mood_change = -10
	special_screen_obj = "mood_happiness_bad"

/datum/mood_event/reality_anchor_silenced/mortal
	description = "I feel like something's different in the air."
	mood_change = 0

// The effect from reality anchors
/obj/effect/temp_visual/circle_wave/reality_anchor
	color = COLOR_SILVER
	max_alpha = 20
	duration = 0.5 SECONDS
	amount_to_scale = 7

/obj/structure/reality_anchor/update_overlays()
	. = ..()

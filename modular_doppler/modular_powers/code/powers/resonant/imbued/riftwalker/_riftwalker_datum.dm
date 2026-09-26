/// Global tracker for Riftwalker rifts. Largely stylized after how Heretic influences work.
GLOBAL_DATUM_INIT(riftwalker_network, /datum/riftwalker_network_tracker, new)

#define RIFTWALKER_MIN_PAIRS 10
#define RIFTWALKER_MAX_PAIRS 15
#define RIFTWALKER_MAX_GENERATION_ATTEMPTS 200
#define RIFTWALKER_LOCATION_ATTEMPTS 50

/// Owns all active rifts and handles their shared generation behavior.
/datum/riftwalker_network_tracker
	/// List of all active rifts.
	var/list/obj/effect/riftwalker_rift/rifts = list()
	/// Debug: counts attempts to find valid rift turfs during generation.
	var/debug_attempts = 0

/datum/riftwalker_network_tracker/Destroy(force)
	if(GLOB.riftwalker_network == src)
		stack_trace("[type] was deleted. Riftwalkers may no longer access rifts. This is bad; call the coders!")
		message_admins("The [type] was deleted. Riftwalkers may no longer access rifts. This is bad; call the coders!")
	QDEL_LIST(rifts)
	return ..()

/// Generates the initial set of rift pairs.
/datum/riftwalker_network_tracker/proc/generate_rifts()
	if(length(rifts))
		return

	var/start_time = world.timeofday
	var/pair_count = rand(RIFTWALKER_MIN_PAIRS, RIFTWALKER_MAX_PAIRS)
	var/generated_pairs = 0
	var/generation_attempts = 0
	debug_attempts = 0

	while(generated_pairs < pair_count && generation_attempts < RIFTWALKER_MAX_GENERATION_ATTEMPTS)
		generation_attempts++
		if(spawn_pair())
			generated_pairs++

	log_game("Riftwalker generate_rifts: [world.timeofday - start_time] ds, attempts=[debug_attempts], rifts=[length(rifts)], requested_pairs=[pair_count], generated_pairs=[generated_pairs], generation_attempts=[generation_attempts]")

/// Resolves a rift type's destinations and creates the complete pair, rolling a type when none is supplied.
/datum/riftwalker_network_tracker/proc/spawn_pair(forced_rift_type_path)
	var/selected_rift_type_path = forced_rift_type_path || pick_weight(GLOB.riftwalker_rift_type_weights)
	var/datum/riftwalker_rift_type/rift_type = new selected_rift_type_path
	var/turf/first_turf = rift_type.find_first_turf(src)
	if(!first_turf)
		qdel(rift_type)
		return FALSE
	var/turf/second_turf = rift_type.find_second_turf(src)
	if(!second_turf || second_turf == first_turf || (second_turf.z == first_turf.z && get_dist(first_turf, second_turf) <= 1))
		qdel(rift_type)
		return FALSE

	var/next_pair_id = get_next_pair_id()
	var/rift_path = rift_type.rift_path
	qdel(rift_type)
	var/obj/effect/riftwalker_rift/first_rift = new rift_path(first_turf)
	first_rift.pair_id = next_pair_id
	first_rift.rift_type_path = selected_rift_type_path
	var/obj/effect/riftwalker_rift/second_rift = new rift_path(second_turf)
	second_rift.pair_id = next_pair_id
	second_rift.rift_type_path = selected_rift_type_path
	return TRUE

/// Returns an unused pair identifier.
/datum/riftwalker_network_tracker/proc/get_next_pair_id()
	var/next_pair_id = 1
	for(var/obj/effect/riftwalker_rift/existing_rift as anything in rifts)
		next_pair_id = max(next_pair_id, existing_rift.pair_id + 1)
	return next_pair_id

/// Finds a random valid station turf for an ordinary rift endpoint.
/datum/riftwalker_network_tracker/proc/find_random_rift_turf()
	for(var/attempt in 1 to RIFTWALKER_LOCATION_ATTEMPTS)
		debug_attempts++
		var/turf/chosen_location = get_safe_random_station_turf_equal_weight()
		if(is_valid_station_rift_location(chosen_location))
			return chosen_location
	return null

/// Checks whether a station turf can safely hold a rift.
/datum/riftwalker_network_tracker/proc/is_valid_station_rift_location(turf/target_turf)
	return is_station_level(target_turf?.z) && is_clear_rift_location(target_turf)

/// Checks the shared physical placement restrictions for every rift endpoint.
/datum/riftwalker_network_tracker/proc/is_clear_rift_location(turf/target_turf)
	if(!isturf(target_turf) || isopenspaceturf(target_turf) || isgroundlessturf(target_turf) || target_turf.is_blocked_turf())
		return FALSE
	for(var/obj/effect/riftwalker_rift/existing_rift in range(1, target_turf))
		return FALSE
	return TRUE

/obj/effect/riftwalker_rift
	name = "bluespace rift"
	desc = "Bluespace energies connecting two places together; many Bluespace researchers would kill to understand why these rifts form. Some argue that these are left behind by heavy sums of teleportation; but these claims are unfounded."
	icon = 'modular_doppler/modular_powers/icons/powers/effects.dmi'
	icon_state = "riftwalker_blue"
	anchored = TRUE
	invisibility = INVISIBILITY_OBSERVER
	/// Which pair this rift belongs to
	var/pair_id = 0
	/// Rift generation type used to preserve this pair's behavior when it is replaced.
	var/rift_type_path = /datum/riftwalker_rift_type
	/// Shared color for the rift's filters.
	var/rift_color = "#6699ff"

/obj/effect/riftwalker_rift/Initialize(mapload)
	. = ..()
	GLOB.riftwalker_network.rifts += src
	RegisterSignal(src, COMSIG_ATOM_DISPEL, PROC_REF(on_dispel))
	apply_rift_filters(src)
	src.alpha = 190
	if(!loc)
		return
	var/image/rift_image = image(icon = icon, loc = src, icon_state = icon_state, layer = OBJ_LAYER)
	rift_image.layer = OBJ_LAYER
	rift_image.override = TRUE
	apply_rift_filters(rift_image)
	add_alt_appearance(/datum/atom_hud/alternate_appearance/basic/riftwalker, "riftwalker_rift", rift_image)

/// Applies the rift's shared outline, blur, and animated rays to an atom or image.
/obj/effect/riftwalker_rift/proc/apply_rift_filters(datum/filter_target)
	filter_target.add_filters(list(
		list("name" = "rift_outline", "priority" = 1, "params" = outline_filter(size = 0.15, color = rift_color)),
		list("name" = "rift_blur", "priority" = 2, "params" = gauss_blur_filter(size = 0.5)),
		list("name" = "rift_rays", "priority" = 3, "params" = rays_filter(size = 20, color = rift_color, offset = 0, density = 30, threshold = 0.5, factor = 0, x = 0, y = -2, flags = FILTER_OVERLAY | FILTER_UNDERLAY)),
	))
	var/animated_rays = filter_target.get_filter("rift_rays")
	animate(animated_rays, offset = 10, time = 6 SECONDS, loop = -1)
	animate(offset = 0, time = 0)

/obj/effect/riftwalker_rift/Destroy()
	GLOB.riftwalker_network.rifts -= src
	UnregisterSignal(src, COMSIG_ATOM_DISPEL)
	return ..()

/obj/effect/riftwalker_rift/examine(mob/user)
	. = ..()
	. += span_notice("Only riftwalkers can traverse these rifts.")

/// Checks if a mob can see the rifts
/obj/effect/riftwalker_rift/proc/verify_user_can_see(mob/user)
	return HAS_TRAIT(user, TRAIT_IMBUED_RIFTWALKER)

// Teleport logic.
/obj/effect/riftwalker_rift/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(!verify_user_can_see(user))
		return TRUE
	if(HAS_TRAIT(user, TRAIT_RESONANCE_SILENCED))
		user.balloon_alert(user, "silenced!")
		return TRUE

	var/obj/effect/riftwalker_rift/linked_rift = get_paired_rift()

	var/slip_in_message = pick("slides sideways in an odd way, and disappears", "jumps into an unseen dimension",\
		"sticks one leg straight out, wiggles [user.p_their()] foot, and is suddenly gone", "stops, then blinks out of reality", \
		"is pulled into an invisible vortex, vanishing from sight")
	var/slip_out_message = pick("silently fades in", "leaps out of thin air","appears", "walks out of an invisible doorway",\
		"slides out of a fold in spacetime")

	to_chat(user, span_notice("You try to align with the bluespace stream..."))
	if(!do_after(user, 2 SECONDS, target = src))
		return TRUE

	var/turf/source_turf = get_turf(src)
	var/turf/destination_turf = get_turf(linked_rift) || source_turf // you tp to the same space if there's no linked rift.

	/* removed fx
	new /obj/effect/temp_visual/bluespace_fissure(source_turf)
	new /obj/effect/temp_visual/bluespace_fissure(destination_turf)
	*/

	user.visible_message(span_warning("[user] [slip_in_message]."), ignored_mobs = user)

	var/atom/movable/pulled = null
	if(ismovable(user.pulling))
		pulled = user.pulling
		if(ismob(pulled))
			to_chat(pulled, span_notice("You suddenly find yourself in a different location!"))
		do_teleport(pulled, destination_turf, no_effects = TRUE)

	if(do_teleport(user, destination_turf, no_effects = TRUE))
		playsound(destination_turf, SFX_PORTAL_ENTER, 50, TRUE, SHORT_RANGE_SOUND_EXTRARANGE)
		user.visible_message(span_warning("[user] [slip_out_message]."), span_notice("...and find your way to the other side."))
		if(pulled)
			user.start_pulling(pulled)
	else
		user.visible_message(span_warning("[user] [slip_out_message], ending up exactly where they left."), span_notice("...and find yourself where you started?"))

	return TRUE

/obj/effect/riftwalker_rift/attack_ghost(mob/user)
	var/obj/effect/riftwalker_rift/linked_rift = get_paired_rift()
	if(!linked_rift)
		return ..()
	user.abstract_move(get_turf(linked_rift))

/// On dispel, closes that pair of rifts, and create a new pair somewhere else.
/obj/effect/riftwalker_rift/proc/on_dispel(datum/source, atom/dispeller)
	SIGNAL_HANDLER

	var/replacement_rift_type_path = rift_type_path
	var/obj/effect/riftwalker_rift/linked_rift = get_paired_rift()
	if(!QDELETED(linked_rift))
		QDEL_NULL(linked_rift)
	if(!QDELETED(src))
		QDEL_NULL(src)

	GLOB.riftwalker_network.spawn_pair(replacement_rift_type_path)
	return DISPEL_RESULT_DISPELLED

/// Gets the sibling rift of a rift.
/obj/effect/riftwalker_rift/proc/get_paired_rift()
	if(!pair_id)
		return null
	for(var/obj/effect/riftwalker_rift/other_rift as anything in GLOB.riftwalker_network.rifts)
		if(other_rift != src && other_rift.pair_id == pair_id)
			return other_rift
	return null

// Determines if a mob can see it.
/datum/atom_hud/alternate_appearance/basic/riftwalker/mobShouldSee(mob/viewer)
	if(!isliving(viewer))
		return FALSE
	return HAS_TRAIT(viewer, TRAIT_IMBUED_RIFTWALKER)

#undef RIFTWALKER_MIN_PAIRS
#undef RIFTWALKER_MAX_PAIRS
#undef RIFTWALKER_MAX_GENERATION_ATTEMPTS
#undef RIFTWALKER_LOCATION_ATTEMPTS

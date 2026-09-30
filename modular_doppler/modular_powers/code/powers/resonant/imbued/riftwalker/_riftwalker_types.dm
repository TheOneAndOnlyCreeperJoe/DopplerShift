/// Relative spawn weights for each rift pair type.
GLOBAL_LIST_INIT(riftwalker_rift_type_weights, list(
	/datum/riftwalker_rift_type = 60,
	/datum/riftwalker_rift_type/teleporter = 25,
	/datum/riftwalker_rift_type/red = 15,
))

// Chance for teleporter rifts to spawn at a teleporter as the first rift.
#define RIFTWALKER_TELEPORTER_RIFT_CHANCE 25
// Chance for teleporer rifts that spawn by a teleporter to link to a beacon.
#define RIFTWALKER_TELEPORTER_BEACON_LINK_CHANCE 66
// Chance for a red rift to spawn in the gateway area.
#define RIFTWALKER_RED_GATEWAY_RIFT_CHANCE 33
// Chance for a red rift to lead to a space ruin, otherwise leading to a mining ruin.
#define RIFTWALKER_SPACE_RUIN_CHANCE 66

/// Defines a rift pair's location rules and the rift object it creates.
/datum/riftwalker_rift_type
	var/rift_path = /obj/effect/riftwalker_rift

/*
*
* Standard rift: First and second rift are two random (safe) tiles on the station.
*
*/
/datum/riftwalker_rift_type/proc/find_first_turf(datum/riftwalker_network_tracker/network)
	return network.find_random_rift_turf()

/datum/riftwalker_rift_type/proc/find_second_turf(datum/riftwalker_network_tracker/network)
	return network.find_random_rift_turf()

/*
*
* Teleporter Rift: The first rift is associated with a beacon or teleport hub; the second rift is either random, or if the first is a teleport-hub rifts, it may link to a beacon.
*
*/
/datum/riftwalker_rift_type/teleporter
	/// Whether the first rift actually selected a teleport hub rather than a beacon.
	var/first_rift_uses_teleporter = FALSE

/datum/riftwalker_rift_type/teleporter/find_first_turf(datum/riftwalker_network_tracker/network)
	first_rift_uses_teleporter = prob(RIFTWALKER_TELEPORTER_RIFT_CHANCE)
	var/turf/first_turf = first_rift_uses_teleporter ? pick_adjacent_teleporter_turf(network) : pick_valid_beacon_turf(network)
	if(first_turf)
		return first_turf
	first_rift_uses_teleporter = !first_rift_uses_teleporter
	return first_rift_uses_teleporter ? pick_adjacent_teleporter_turf(network) : pick_valid_beacon_turf(network)

/datum/riftwalker_rift_type/teleporter/find_second_turf(datum/riftwalker_network_tracker/network)
	if(first_rift_uses_teleporter && prob(RIFTWALKER_TELEPORTER_BEACON_LINK_CHANCE))
		var/turf/beacon_turf = pick_valid_beacon_turf(network)
		if(beacon_turf)
			return beacon_turf
	return ..()

/// Finds a valid turf adjacent to a station teleport hub.
/datum/riftwalker_rift_type/teleporter/proc/pick_adjacent_teleporter_turf(datum/riftwalker_network_tracker/network)
	var/list/turf/candidates = list()
	for(var/obj/machinery/teleport/hub/teleporter as anything in SSmachines.get_machines_by_type_and_subtypes(/obj/machinery/teleport/hub))
		if(!is_station_level(teleporter.z))
			continue
		var/turf/teleporter_turf = get_turf(teleporter)
		if(!teleporter_turf)
			continue
		for(var/turf/adjacent_turf as anything in range(1, teleporter_turf))
			if(adjacent_turf != teleporter_turf && network.is_valid_station_rift_location(adjacent_turf))
				candidates += adjacent_turf
	return length(candidates) ? pick(candidates) : null

/// Finds a valid station teleport beacon turf.
/datum/riftwalker_rift_type/teleporter/proc/pick_valid_beacon_turf(datum/riftwalker_network_tracker/network)
	var/list/turf/candidates = list()
	for(var/obj/item/beacon/beacon as anything in GLOB.teleportbeacons)
		var/turf/beacon_turf = get_turf(beacon)
		if(network.is_valid_station_rift_location(beacon_turf))
			candidates += beacon_turf
	return length(candidates) ? pick(candidates) : null

/*
*
* Red Rift: Spooky and dangerous! The first rift either spawns somewhere random or at the gateway, the second always leads to a breathable ruin.
* These look visually distinct to differentiate them, and you are entering quite obviously at your own risk.
*
*/
/datum/riftwalker_rift_type/red
	rift_path = /obj/effect/riftwalker_rift/red
	/// Ruin areas that red rifts must never provide access to.
	var/static/list/area_blacklist = typecacheof(list(
		/area/ruin/space/has_grav/powered/undisclosed_location, // cozy-zone for cantags lets give them their peace.
	))

/datum/riftwalker_rift_type/red/find_first_turf(datum/riftwalker_network_tracker/network)
	if(prob(RIFTWALKER_RED_GATEWAY_RIFT_CHANCE))
		var/turf/gateway_turf = pick_gateway_area_turf(network)
		if(gateway_turf)
			return gateway_turf
	return network.find_random_rift_turf()

/datum/riftwalker_rift_type/red/find_second_turf(datum/riftwalker_network_tracker/network)
	return pick_valid_ruin_turf(network)

/// Finds a valid turf in the station gateway's area, if the map has one.
/datum/riftwalker_rift_type/red/proc/pick_gateway_area_turf(datum/riftwalker_network_tracker/network)
	var/area/gateway_area = get_area(GLOB.the_gateway)
	if(!gateway_area)
		return null
	var/list/turf/candidates = list()
	for(var/turf/gateway_turf as anything in gateway_area)
		if(network.is_valid_station_rift_location(gateway_turf))
			candidates += gateway_turf
	return length(candidates) ? pick(candidates) : null

/// Finds a clear, breathable floor within a space ruin or a ruin on the mining z-level.
/datum/riftwalker_rift_type/red/proc/pick_valid_ruin_turf(datum/riftwalker_network_tracker/network)
	var/pick_space_ruin = prob(RIFTWALKER_SPACE_RUIN_CHANCE)
	var/list/preferred_ruin_levels = SSmapping.levels_by_trait(pick_space_ruin ? ZTRAIT_SPACE_RUINS : ZTRAIT_MINING)
	var/turf/preferred_turf = pick_ruin_turf_from_levels(network, preferred_ruin_levels)
	if(preferred_turf)
		return preferred_turf
	var/list/fallback_ruin_levels = SSmapping.levels_by_trait(pick_space_ruin ? ZTRAIT_MINING : ZTRAIT_SPACE_RUINS)
	return pick_ruin_turf_from_levels(network, fallback_ruin_levels)

/// Selects a clear, breathable ruin floor from the supplied z-levels.
/datum/riftwalker_rift_type/red/proc/pick_ruin_turf_from_levels(datum/riftwalker_network_tracker/network, list/ruin_levels)
	var/list/turf/candidates = list()
	for(var/ruin_level in ruin_levels)
		for(var/turf/ruin_turf as anything in get_area_turfs(/area/ruin, target_z = ruin_level, subtypes = TRUE))
			network.debug_attempts++
			if(!istype(ruin_turf, /turf/open/floor))
				continue
			var/area/ruin_area = get_area(ruin_turf)
			if(is_type_in_typecache(ruin_area, area_blacklist))
				continue
			if(network.is_clear_rift_location(ruin_turf) && is_safe_turf(ruin_turf))
				candidates += ruin_turf
	return length(candidates) ? pick(candidates) : null

// Red rifts take substantially longer to cross than bluespace.
#define RIFTWALKER_RED_RIFT_WINDUP_DURATION (2 SECONDS)
#define RIFTWALKER_RED_RIFT_TRANSIT_DURATION (10 SECONDS)
#define RIFTWALKER_RED_RIFT_ARRIVAL_DURATION (3 SECONDS)
#define RIFTWALKER_RED_RIFT_TOTAL_DURATION (RIFTWALKER_RED_RIFT_WINDUP_DURATION + RIFTWALKER_RED_RIFT_TRANSIT_DURATION)
#define RIFTWALKER_RED_RIFT_KINESIS_FULLSCREEN "riftwalker_red_rift_kinesis"
#define RIFTWALKER_RED_RIFT_COLOR_FILTER "riftwalker_red_rift_color"
#define RIFTWALKER_RED_RIFT_DISPLACEMENT_FILTER "riftwalker_red_rift_displacement"

/// ITS SPOOKY, IT (MIGHT) BE REDSPACE, IT MAY JUST BE RESONANT FUCKERY - WHO KNOWS, I AIN'T EXPLAING SHIT
/obj/effect/riftwalker_rift/red
	name = "red bluespace rift"
	bluespace_core_chance = RIFTWALKER_RED_RIFT_BLUESPACE_CORE_CHANCE
	desc = "Redspace is a theory long debunked as folly. Most of it stems from similarities drawn to the redshift and blueshift phenomena: if bluespace reduces relative distance between locations, then redspace must increase relative distance - but then how would it still function as a gateway? Ultimately no empirical evidence of redspace was ever discovered. \
	Yet with the Reality Anchors broken, has that changed in any capacity? Has the absence of the binding laws of reality given way to that which could not exist?"
	icon_state = "riftwalker_red"
	rift_color = "#fc5f5f"

/obj/effect/riftwalker_rift/red/examine(mob/user)
	. = ..()
	. += span_bolddanger("... You have a bad feeling about this.")

/// Red rifts are deliberately slow: users are held inside their destination rift while the passage completes.
/obj/effect/riftwalker_rift/red/attack_hand(mob/living/user, list/modifiers)
	if(!can_user_use_rifts(user))
		return TRUE
	if(QDELETED(linked_rift))
		to_chat(user, span_warning("It leads nowhere! Bah, all for show."))
		return TRUE

	var/obj/effect/riftwalker_rift/red/destination_rift = linked_rift
	if(!istype(destination_rift))
		return TRUE

	var/datum/riftwalker_red_rift_transit/transit = new(user, src, destination_rift)
	transit.begin_windup(user)
	to_chat(user, span_userdanger("Pain strikes you arm, as it is stretched and pulled into [name]!"))
	if(!do_after(user, RIFTWALKER_RED_RIFT_WINDUP_DURATION, target = src, timed_action_flags = IGNORE_USER_LOC_CHANGE | IGNORE_HELD_ITEM | IGNORE_INCAPACITATED | IGNORE_SLOWDOWNS))
		if(QDELETED(src))
			transit.rip_user_arm(user)
		transit.cancel(user)
		return TRUE
	if(QDELETED(destination_rift) || QDELETED(src))
		if(QDELETED(src))
			transit.rip_user_arm(user)
		transit.cancel(user)
		return TRUE
	transit.begin_transit(user)
	return TRUE

/// Stores a single user's red-rift passage independently of the rifts themselves.
/datum/riftwalker_red_rift_transit
	/// Rift the mob enters from
	var/obj/effect/riftwalker_rift/red/origin_rift
	/// Rift the user will exit from
	var/obj/effect/riftwalker_rift/red/destination_rift
	/// Turf the user started on
	var/turf/origin_turf
	/// Turf the user will exit from
	var/turf/destination_turf
	/// Have we started teleporting?
	var/transit_started = FALSE
	/// User alpha captured before the red rift fades them out.
	var/initial_user_alpha

/datum/riftwalker_red_rift_transit/New(mob/living/new_user, obj/effect/riftwalker_rift/red/new_origin_rift, obj/effect/riftwalker_rift/red/new_destination_rift)
	. = ..()
	origin_rift = new_origin_rift
	destination_rift = new_destination_rift
	origin_turf = get_turf(new_user)
	destination_turf = get_turf(new_destination_rift)
	initial_user_alpha = new_user.alpha

/// Begins the visible pull into a red rift while the interaction do_after runs.
/datum/riftwalker_red_rift_transit/proc/begin_windup(mob/living/user)
	if(QDELETED(user))
		return
	user.add_filter(RIFTWALKER_RED_RIFT_COLOR_FILTER, 1, color_matrix_filter(COLOR_WHITE))
	user.transition_filter(RIFTWALKER_RED_RIFT_COLOR_FILTER, color_matrix_filter(COLOR_RED), RIFTWALKER_RED_RIFT_WINDUP_DURATION)
	user.remove_filter(RIFTWALKER_RED_RIFT_DISPLACEMENT_FILTER)
	user.add_filter(RIFTWALKER_RED_RIFT_DISPLACEMENT_FILTER, 10, list("type" = "displace", "x" = 0, "y" = 0, "size" = 0))
	addtimer(CALLBACK(src, PROC_REF(animate_displacement), user), 0.1 SECONDS)
	addtimer(CALLBACK(src, PROC_REF(fade_user_out), user), RIFTWALKER_RED_RIFT_WINDUP_DURATION * 0.75)
	ADD_TRAIT(user, TRAIT_IMMOBILIZED, REF(src))
	user.Stun(RIFTWALKER_RED_RIFT_TOTAL_DURATION, ignore_canstun = TRUE)
	playsound(origin_turf, 'modular_doppler/modular_powers/sounds/riftwalker/red_rift_walk.ogg', 50, FALSE, SHORT_RANGE_SOUND_EXTRARANGE)

/// Begins the displacement animation after the initial zero-size filter has reached the client.
/datum/riftwalker_red_rift_transit/proc/animate_displacement(mob/living/user)
	if(QDELETED(user))
		return
	var/displacement_filter = user.get_filter(RIFTWALKER_RED_RIFT_DISPLACEMENT_FILTER)
	if(!displacement_filter)
		return
	animate(displacement_filter, flags = ANIMATION_END_NOW)
	animate(displacement_filter, size = -15, time = RIFTWALKER_RED_RIFT_WINDUP_DURATION - (0.1 SECONDS))

/// Fades the user over the final quarter of the committed windup rather than abruptly hiding them.
/datum/riftwalker_red_rift_transit/proc/fade_user_out(mob/living/user)
	if(QDELETED(user))
		return
	animate(user, alpha = 0, time = RIFTWALKER_RED_RIFT_WINDUP_DURATION * 0.25)

/// Moves the user out of physical space and starts the private passage effects.
/datum/riftwalker_red_rift_transit/proc/begin_transit(mob/living/user)
	if(QDELETED(user) || QDELETED(destination_rift))
		cancel(user)
		return
	transit_started = TRUE
	new /obj/effect/temp_visual/portal_animation(origin_turf, origin_rift, user)
	user.forceMove(destination_rift)
	user.overlay_fullscreen(RIFTWALKER_RED_RIFT_KINESIS_FULLSCREEN, /atom/movable/screen/fullscreen/red_rift_kinesis, 0)
	apply_red_rift_tint(user)
	addtimer(CALLBACK(src, PROC_REF(begin_arrival), user), RIFTWALKER_RED_RIFT_TRANSIT_DURATION - RIFTWALKER_RED_RIFT_ARRIVAL_DURATION)
	addtimer(CALLBACK(src, PROC_REF(finish_transit), user), RIFTWALKER_RED_RIFT_TRANSIT_DURATION)

/// Applies a dark-red client-plane tint, then starts its fade once the initial colour has reached the client.
/datum/riftwalker_red_rift_transit/proc/apply_red_rift_tint(mob/living/user)
	if(QDELETED(user) || !user.hud_used)
		return
	var/filter_name = "riftwalker_red_rift_tint_[REF(src)]"
	for(var/atom/movable/screen/plane_master/game_plane as anything in user.hud_used.get_true_plane_masters(RENDER_PLANE_GAME))
		game_plane.add_filter(filter_name, 10, color_matrix_filter(COLOR_DARK_RED))
	addtimer(CALLBACK(src, PROC_REF(animate_red_rift_tint), user), 0.1 SECONDS)

/// Fades the client-plane tint from dark red back to the identity colour matrix over the transit.
/datum/riftwalker_red_rift_transit/proc/animate_red_rift_tint(mob/living/user)
	if(QDELETED(user) || !user.hud_used)
		return
	var/filter_name = "riftwalker_red_rift_tint_[REF(src)]"
	for(var/atom/movable/screen/plane_master/game_plane as anything in user.hud_used.get_true_plane_masters(RENDER_PLANE_GAME))
		var/red_rift_tint = game_plane.get_filter(filter_name)
		if(red_rift_tint)
			animate(red_rift_tint, color = COLOR_MATRIX_IDENTITY, time = RIFTWALKER_RED_RIFT_TRANSIT_DURATION - (0.1 SECONDS), easing = SINE_EASING | EASE_OUT)

/// Removes the per-transit tint from all of the user's game planes.
/datum/riftwalker_red_rift_transit/proc/remove_red_rift_tint(mob/living/user)
	if(QDELETED(user) || !user.hud_used)
		return
	var/filter_name = "riftwalker_red_rift_tint_[REF(src)]"
	for(var/atom/movable/screen/plane_master/game_plane as anything in user.hud_used.get_true_plane_masters(RENDER_PLANE_GAME))
		game_plane.remove_filter(filter_name)

/// Plays the inverse departure effect during the last two seconds before the user returns to physical space.
/datum/riftwalker_red_rift_transit/proc/begin_arrival(mob/living/user)
	if(QDELETED(user) || QDELETED(destination_rift) || user.loc != destination_rift)
		return
	new /obj/effect/temp_visual/red_rift_arrival(destination_turf, destination_rift, user, initial_user_alpha)
	var/sound/reversed_gateway_sound = sound('modular_doppler/modular_powers/sounds/riftwalker/red_rift_walk.ogg')
	reversed_gateway_sound.frequency = -1
	playsound(destination_turf, reversed_gateway_sound, 50, FALSE, SHORT_RANGE_SOUND_EXTRARANGE)

/// Places the user at the destination once the red-rift effects have fully played.
/datum/riftwalker_red_rift_transit/proc/finish_transit(mob/living/user)
	if(QDELETED(user))
		qdel(src)
		return
	clear_transit_effects(user)
	if(user.loc == destination_rift || isnull(user.loc))
		var/turf/arrival_turf = !QDELETED(destination_rift) ? get_turf(destination_rift) : origin_turf
		if(arrival_turf)
			user.forceMove(arrival_turf)
			user.add_mood_event("red_rift_travel", /datum/mood_event/red_rift_travel)
			to_chat(user, span_warning("You finally feel whole again."))
	qdel(src)

/// Cancels a passage only if its endpoint ceases to exist during the committed windup.
/datum/riftwalker_red_rift_transit/proc/cancel(mob/living/user)
	clear_transit_effects(user)
	qdel(src)

/// Tears off an arm left behind when the entrance rift collapses during the committed windup.
/datum/riftwalker_red_rift_transit/proc/rip_user_arm(mob/living/user)
	if(!iscarbon(user))
		return
	var/mob/living/carbon/carbon_user = user
	var/list/available_arms = list()
	var/obj/item/bodypart/left_arm = carbon_user.get_bodypart(BODY_ZONE_L_ARM)
	var/obj/item/bodypart/right_arm = carbon_user.get_bodypart(BODY_ZONE_R_ARM)
	if(left_arm)
		available_arms += left_arm
	if(right_arm)
		available_arms += right_arm
	if(!length(available_arms))
		return
	var/obj/item/bodypart/ripped_arm = pick(available_arms)
	carbon_user.visible_message(
		span_danger("The collapsing red rift catches [carbon_user]'s [ripped_arm.name] and tears it clean off!"),
		span_userdanger("The collapsing red rift catches your [ripped_arm.name] and tears it clean off!")
	)
	ripped_arm.dismember(BRUTE, TRUE)

/// Removes visual state owned by this passage without touching any unrelated filters or overlays.
/datum/riftwalker_red_rift_transit/proc/clear_transit_effects(mob/living/user)
	if(QDELETED(user))
		return
	user.remove_filter(RIFTWALKER_RED_RIFT_COLOR_FILTER)
	user.remove_filter(RIFTWALKER_RED_RIFT_DISPLACEMENT_FILTER)
	user.alpha = initial_user_alpha
	REMOVE_TRAIT(user, TRAIT_IMMOBILIZED, REF(src))
	remove_red_rift_tint(user)
	user.clear_fullscreen(RIFTWALKER_RED_RIFT_KINESIS_FULLSCREEN, FALSE)

/// Red-tinted kinesis overlay shown for the entire red-rift passage.
/atom/movable/screen/fullscreen/red_rift_kinesis
	icon_state = "kinesis"
	color = COLOR_DARK_RED
	alpha = 96

/datum/mood_event/red_rift_travel
	description = "That rift was horrible to travel with. I feel as if I had just been quartered!"
	mood_change = -10
	timeout = 2 MINUTES

/// The inverse of portal_animation: it fades in and rises from the destination rift.
/obj/effect/temp_visual/red_rift_arrival
	duration = RIFTWALKER_RED_RIFT_ARRIVAL_DURATION

/obj/effect/temp_visual/red_rift_arrival/Initialize(mapload, atom/portal, atom/movable/teleporting, arrival_alpha)
	. = ..()
	if(isnull(portal) || isnull(teleporting))
		return
	appearance = teleporting.appearance
	dir = teleporting.dir
	layer = portal.layer + 0.01
	alpha = 0
	animate(src, pixel_x = 0, pixel_y = 0, alpha = arrival_alpha, time = duration * 0.25)
	addtimer(CALLBACK(src, PROC_REF(restore_displacement)), 0.1 SECONDS)

/// Returns the copied arrival sprite's displacement filter to normal while it phases back in.
/obj/effect/temp_visual/red_rift_arrival/proc/restore_displacement()
	var/displacement_filter = get_filter(RIFTWALKER_RED_RIFT_DISPLACEMENT_FILTER)
	if(!displacement_filter)
		return
	animate(displacement_filter, flags = ANIMATION_END_NOW)
	animate(displacement_filter, size = 0, time = duration - (0.1 SECONDS))

#undef RIFTWALKER_TELEPORTER_RIFT_CHANCE
#undef RIFTWALKER_TELEPORTER_BEACON_LINK_CHANCE
#undef RIFTWALKER_RED_GATEWAY_RIFT_CHANCE
#undef RIFTWALKER_SPACE_RUIN_CHANCE
#undef RIFTWALKER_RED_RIFT_WINDUP_DURATION
#undef RIFTWALKER_RED_RIFT_TRANSIT_DURATION
#undef RIFTWALKER_RED_RIFT_ARRIVAL_DURATION
#undef RIFTWALKER_RED_RIFT_TOTAL_DURATION
#undef RIFTWALKER_RED_RIFT_KINESIS_FULLSCREEN
#undef RIFTWALKER_RED_RIFT_COLOR_FILTER
#undef RIFTWALKER_RED_RIFT_DISPLACEMENT_FILTER

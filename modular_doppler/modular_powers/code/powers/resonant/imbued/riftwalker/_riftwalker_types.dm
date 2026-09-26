/// Relative spawn weights for each rift pair type.
GLOBAL_LIST_INIT(riftwalker_rift_type_weights, list(
	/datum/riftwalker_rift_type = 60,
	/datum/riftwalker_rift_type/teleporter = 25,
	/datum/riftwalker_rift_type/red = 15,
))

#define RIFTWALKER_TELEPORTER_RIFT_CHANCE 25
#define RIFTWALKER_TELEPORTER_BEACON_LINK_CHANCE 50
#define RIFTWALKER_RED_GATEWAY_RIFT_CHANCE 50
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
* These look visually distinct to differentiate them.
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

/obj/effect/riftwalker_rift/red
	name = "red bluespace rift"
	icon_state = "riftwalker_red"
	rift_color = "#fc5f5f"

/obj/effect/riftwalker_rift/red/examine(mob/user)
	. = ..()
	. += span_danger("... This one looks ominous.")

#undef RIFTWALKER_TELEPORTER_RIFT_CHANCE
#undef RIFTWALKER_TELEPORTER_BEACON_LINK_CHANCE
#undef RIFTWALKER_RED_GATEWAY_RIFT_CHANCE
#undef RIFTWALKER_SPACE_RUIN_CHANCE

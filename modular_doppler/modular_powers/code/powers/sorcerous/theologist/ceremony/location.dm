/*
 * Remain in a meaningful location for an extended period.
 */
/datum/ceremonial_objective/location
	abstract_type = /datum/ceremonial_objective/location

	/// The area type in which this objective accumulates time.
	var/area_type
	/// The player-facing name of the area this objective tracks.
	var/location_name = "location"
	/// The number of seconds the mob has spent in the tracked area.
	var/time_in_location = 0
	/// The number of seconds the mob must spend in the tracked area.
	var/required_time = 10 MINUTES / 1 SECONDS
	/// Whether this objective is currently accumulating location time.
	var/tracking_location_time = FALSE

/// Registers area transition handlers for the objective's mob.
/datum/ceremonial_objective/location/New(datum/power/theologist/ceremony/new_ceremony_power)
	. = ..()
	if(!holder)
		return
	holder.become_area_sensitive(src)
	RegisterSignal(holder, COMSIG_ENTER_AREA, PROC_REF(on_enter_area))
	RegisterSignal(holder, COMSIG_EXIT_AREA, PROC_REF(on_exit_area))
	if(is_in_location())
		start_tracking()

/// Stops location tracking and removes this objective's area transition handlers.
/datum/ceremonial_objective/location/Destroy()
	stop_tracking()
	if(holder)
		UnregisterSignal(holder, list(COMSIG_ENTER_AREA, COMSIG_EXIT_AREA))
		holder.lose_area_sensitivity(src)
	return ..()

/// Returns whether the mob is currently inside the tracked area type.
/datum/ceremonial_objective/location/proc/is_in_location()
	return istype(get_area(holder), area_type)

/// Starts accumulating time for this location objective.
/datum/ceremonial_objective/location/proc/start_tracking()
	if(completed || tracking_location_time)
		return
	tracking_location_time = TRUE
	START_PROCESSING(SSobj, src)

/// Stops accumulating time for this location objective.
/datum/ceremonial_objective/location/proc/stop_tracking()
	if(!tracking_location_time)
		return
	tracking_location_time = FALSE
	STOP_PROCESSING(SSobj, src)

/// Begins tracking when the mob enters the target area.
/datum/ceremonial_objective/location/proc/on_enter_area(mob/source_mob, area/new_area)
	SIGNAL_HANDLER

	if(istype(new_area, area_type))
		start_tracking()

/// Stops tracking when the mob leaves the target area.
/datum/ceremonial_objective/location/proc/on_exit_area(mob/source_mob, area/left_area)
	SIGNAL_HANDLER

	if(istype(left_area, area_type))
		stop_tracking()

/// Accumulates time until the objective completes or the mob leaves the target area.
/datum/ceremonial_objective/location/process(seconds_per_tick)
	if(!tracking_location_time || !is_in_location())
		stop_tracking()
		return

	time_in_location += seconds_per_tick
	if(time_in_location >= required_time)
		complete()
		stop_tracking()
	SStgui.update_uis(ceremony_power)

/datum/ceremonial_objective/location/get_progress_text()
	return "Time spent in the [location_name]: [round(time_in_location)] seconds."

/*
 * Spend time in the Chapel
 */
/datum/ceremonial_objective/location/chapel
	name = "Procession"
	description = "Spend 10 minutes in the Chapel."
	area_type = /area/station/service/chapel
	location_name = "Chapel"

/*
 * Spend time in the Library.
 */
/datum/ceremonial_objective/location/library
	name = "Contemplation"
	description = "Spend 10 minutes in the Library."
	area_type = /area/station/service/library
	location_name = "Library"

/// Only folks who enjoy a good book or just enjoy being in the library.
/datum/ceremonial_objective/location/library/eligible()
	return HAS_PERSONALITY(holder, /datum/personality/introvert) || HAS_PERSONALITY(holder, /datum/personality/erudite)

/*
 * Spend time in the Bar.
 */
/datum/ceremonial_objective/location/bar
	name = "Community"
	description = "Spend 10 minutes in the Bar."
	area_type = /area/station/service/bar
	location_name = "Bar"

/// Only folks who enjoy the pub, or a drink. Being british doesn't count, no.
/datum/ceremonial_objective/location/bar/eligible()
	return HAS_PERSONALITY(holder, /datum/personality/extrovert) || HAS_PERSONALITY(holder, /datum/personality/slacking/lazy) || HAS_PERSONALITY(holder, /datum/personality/bibulous)

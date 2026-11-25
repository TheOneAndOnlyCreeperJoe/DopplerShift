/*
* Sit in the chapel for a bit.
*/
/datum/ceremonial_objective/chapel
	name = "Chapel Vigil"
	description = "Spend 10 minutes in the Chapel."

	/// The number of seconds the holder has spent in the Chapel.
	var/time_in_chapel = 0
	/// Whether this objective is currently accumulating Chapel time.
	var/tracking_chapel_time = FALSE

/// Registers Chapel transition handlers for this objective's holder.
/datum/ceremonial_objective/chapel/New(datum/power/theologist/ceremony/new_ceremony_power)
	. = ..()
	if(!holder)
		return
	holder.become_area_sensitive(src)
	RegisterSignal(holder, COMSIG_ENTER_AREA, PROC_REF(on_enter_area))
	RegisterSignal(holder, COMSIG_EXIT_AREA, PROC_REF(on_exit_area))
	if(istype(get_area(holder), /area/station/service/chapel))
		start_tracking()

/// Stops Chapel tracking and removes this objective's area transition handlers.
/datum/ceremonial_objective/chapel/Destroy()
	stop_tracking()
	if(holder)
		UnregisterSignal(holder, list(COMSIG_ENTER_AREA, COMSIG_EXIT_AREA))
		holder.lose_area_sensitivity(src)
	return ..()

/// Starts accumulating Chapel time for this objective.
/datum/ceremonial_objective/chapel/proc/start_tracking()
	if(completed || tracking_chapel_time)
		return
	tracking_chapel_time = TRUE
	START_PROCESSING(SSobj, src)

/// Stops accumulating Chapel time for this objective.
/datum/ceremonial_objective/chapel/proc/stop_tracking()
	if(!tracking_chapel_time)
		return
	tracking_chapel_time = FALSE
	STOP_PROCESSING(SSobj, src)

/// Begins tracking when the holder enters the Chapel.
/datum/ceremonial_objective/chapel/proc/on_enter_area(mob/source_mob, area/new_area)
	SIGNAL_HANDLER

	if(istype(new_area, /area/station/service/chapel))
		start_tracking()

/// Stops tracking when the holder leaves the Chapel.
/datum/ceremonial_objective/chapel/proc/on_exit_area(mob/source_mob, area/left_area)
	SIGNAL_HANDLER

	if(istype(left_area, /area/station/service/chapel))
		stop_tracking()

/// Accumulates Chapel time until the objective completes.
/datum/ceremonial_objective/chapel/process(seconds_per_tick)
	if(!tracking_chapel_time || !istype(get_area(holder), /area/station/service/chapel))
		stop_tracking()
		return

	time_in_chapel += seconds_per_tick
	if(time_in_chapel >= 10 MINUTES / 1 SECONDS)
		complete()
		stop_tracking()
	SStgui.update_uis(ceremony_power)

/// Returns the accumulated Chapel time for the ceremonial objectives interface.
/datum/ceremonial_objective/chapel/get_progress_text()
	return "Time spent in the Chapel: [round(time_in_chapel)] seconds."

/*
 * Enjoy creative efforts for an extended period.
 */
/datum/ceremonial_objective/creative
	name = "Artistry"
	description = "Indulge in and enjoy creative efforts for 5 minutes."

	/// The number of seconds the mob has retained a qualifying creative moodlet.
	var/time_creative = 0
	/// Whether this objective is currently accumulating creative-enjoyment time.
	var/tracking_creativity = FALSE
	/// Creative moodlets which lack the art event flag but are given by the personality trait.
	var/list/unique_events = list(
		/datum/mood_event/creative_patronage,
		/datum/mood_event/creative_framing,
		/datum/mood_event/creative_sculpting,
	)

/// Limits this objective to people who enjoy artistic expression.
/datum/ceremonial_objective/creative/eligible()
	return HAS_PERSONALITY(holder, /datum/personality/creative)

/datum/ceremonial_objective/creative/New(datum/power/theologist/ceremony/new_ceremony_power)
	. = ..()
	RegisterSignal(holder, COMSIG_CARBON_MOOD_UPDATE, PROC_REF(on_mood_updated))
	update_tracking()

/datum/ceremonial_objective/creative/Destroy()
	stop_tracking()
	UnregisterSignal(holder, COMSIG_CARBON_MOOD_UPDATE)
	return ..()

/// Returns whether the mob has a moodlet produced by a creative effort.
/datum/ceremonial_objective/creative/proc/has_creative_moodlet()
	var/datum/mood/holder_mood = holder?.mob_mood
	if(!holder_mood)
		return FALSE

	for(var/category as anything in holder_mood.mood_events)
		var/datum/mood_event/moodlet = holder_mood.mood_events[category]
		if((moodlet.event_flags & MOOD_EVENT_ART) \
			|| is_type_in_list(moodlet, unique_events))
			return TRUE
	return FALSE

/// Starts or stops processing
/datum/ceremonial_objective/creative/proc/update_tracking()
	if(has_creative_moodlet())
		start_tracking()
		return
	stop_tracking()

/// Begins accumulating time
/datum/ceremonial_objective/creative/proc/start_tracking()
	if(completed || tracking_creativity)
		return
	tracking_creativity = TRUE
	START_PROCESSING(SSobj, src)

/// Stops accumulating time
/datum/ceremonial_objective/creative/proc/stop_tracking()
	if(!tracking_creativity)
		return
	tracking_creativity = FALSE
	STOP_PROCESSING(SSobj, src)

/// Updates tracking when the holder's moodlets change.
/datum/ceremonial_objective/creative/proc/on_mood_updated(mob/living/source_mob)
	SIGNAL_HANDLER

	update_tracking()

/// Accumulates time while the holder retains a qualifying creative moodlet.
/datum/ceremonial_objective/creative/process(seconds_per_tick)
	if(!tracking_creativity || !has_creative_moodlet())
		stop_tracking()
		return

	time_creative += seconds_per_tick
	if(time_creative >= 5 MINUTES / 1 SECONDS)
		complete()
		stop_tracking()
	SStgui.update_uis(ceremony_power)

/datum/ceremonial_objective/creative/get_progress_text()
	return "Time spent enjoying creative efforts: [round(time_creative)] seconds."

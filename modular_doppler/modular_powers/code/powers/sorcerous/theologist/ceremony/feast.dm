/*
 * Enjoy very good food for an extended period.
 */
/datum/ceremonial_objective/feast
	name = "Feast"
	description = "Enjoy very good food for at least 5 minutes. Any food of lower quality does not contribute."

	/// The number of seconds we spent with the moodlet
	var/time_feasting = 0
	/// Whether this objective is currently accumulating time.
	var/tracking_feast = FALSE

/// Fine dining only.
/datum/ceremonial_objective/feast/eligible()
	return HAS_PERSONALITY(holder, /datum/personality/gourmand)

/datum/ceremonial_objective/feast/New(datum/power/theologist/ceremony/new_ceremony_power)
	. = ..()
	RegisterSignal(holder, COMSIG_CARBON_MOOD_UPDATE, PROC_REF(on_mood_updated))

/datum/ceremonial_objective/feast/Destroy()
	stop_tracking()
	UnregisterSignal(holder, COMSIG_CARBON_MOOD_UPDATE)
	return ..()

/// Returns whether the mob has the moodlet and at the appropriate level.
/datum/ceremonial_objective/feast/proc/has_fulfilling_food_mood()
	var/datum/mood/holder_mood = holder?.mob_mood
	if(!holder_mood)
		return FALSE

	for(var/category as anything in holder_mood.mood_events)
		var/datum/mood_event/food/food_moodlet = holder_mood.mood_events[category]
		if(istype(food_moodlet) && food_moodlet.mood_change >= 4)
			return TRUE
	return FALSE

/// Starts or stops processing to match if the mob has the moodlet.
/datum/ceremonial_objective/feast/proc/update_tracking()
	if(has_fulfilling_food_mood())
		start_tracking()
		return
	stop_tracking()

/// Begins accumulating time
/datum/ceremonial_objective/feast/proc/start_tracking()
	if(completed || tracking_feast)
		return
	tracking_feast = TRUE
	START_PROCESSING(SSobj, src)

/// Stops accumulating time
/datum/ceremonial_objective/feast/proc/stop_tracking()
	if(!tracking_feast)
		return
	tracking_feast = FALSE
	STOP_PROCESSING(SSobj, src)

/// Updates tracking when the mob's moodlets change.
/datum/ceremonial_objective/feast/proc/on_mood_updated(mob/living/source_mob)
	SIGNAL_HANDLER

	update_tracking()

/// Accumulates time while the mod retains a sufficiently enjoyable food moodlet.
/datum/ceremonial_objective/feast/process(seconds_per_tick)
	if(!tracking_feast || !has_fulfilling_food_mood())
		stop_tracking()
		return

	time_feasting += seconds_per_tick
	if(time_feasting >= 5 MINUTES / 1 SECONDS)
		complete()
		stop_tracking()
	SStgui.update_uis(ceremony_power)

/datum/ceremonial_objective/feast/get_progress_text()
	return "Time spent enjoying good food: [round(time_feasting)] seconds."

/*
 * Remain under a specific status effect for an extended period.
 */
/datum/ceremonial_objective/status_effect
	abstract_type = /datum/ceremonial_objective/status_effect

	/// The status effect required by this objective.
	var/datum/status_effect/required_effect
	/// The player-facing name of the required status effect.
	var/effect_name = "affected"
	/// The number of seconds the mob has spent under the required effect.
	var/time_affected = 0
	/// The number of seconds required to complete this objective.
	var/required_time = 5 MINUTES / 1 SECONDS
	/// Whether this objective is currently accumulating status-effect time.
	var/tracking_effect_time = FALSE

/// Registers handlers for changes to the mob's status effects.
/datum/ceremonial_objective/status_effect/New(datum/power/theologist/ceremony/new_ceremony_power)
	. = ..()
	RegisterSignals(holder, list(COMSIG_LIVING_STATUS_APPLIED, COMSIG_LIVING_STATUS_REMOVED), PROC_REF(on_status_effect_changed))
	update_tracking()

/datum/ceremonial_objective/status_effect/Destroy()
	STOP_PROCESSING(SSobj, src)
	UnregisterSignal(holder, list(COMSIG_LIVING_STATUS_APPLIED, COMSIG_LIVING_STATUS_REMOVED))
	return ..()

/// Returns whether the mob is currently affected by the required status effect.
/datum/ceremonial_objective/status_effect/proc/has_required_effect()
	var/datum/status_effect/current_effect = holder?.has_status_effect(required_effect)
	return istype(current_effect, required_effect)

/// Starts or stops processing to match the mob's current status effects.
/datum/ceremonial_objective/status_effect/proc/update_tracking()
	if(has_required_effect())
		start_tracking()
		return
	stop_tracking()

/// Begins accumulating time under the required status effect.
/datum/ceremonial_objective/status_effect/proc/start_tracking()
	if(completed || tracking_effect_time)
		return
	tracking_effect_time = TRUE
	START_PROCESSING(SSobj, src)

/// Stops accumulating time under the required status effect.
/datum/ceremonial_objective/status_effect/proc/stop_tracking()
	if(!tracking_effect_time)
		return
	tracking_effect_time = FALSE
	STOP_PROCESSING(SSobj, src)

/// Updates tracking after the mob gains or loses the required status effect.
/datum/ceremonial_objective/status_effect/proc/on_status_effect_changed(mob/living/source_mob, datum/status_effect/changed_effect)
	SIGNAL_HANDLER

	if(!istype(changed_effect, required_effect))
		return
	update_tracking()

/// Accumulates time while the mob has the required status effect.
/datum/ceremonial_objective/status_effect/process(seconds_per_tick)
	time_affected += seconds_per_tick
	if(time_affected >= required_time)
		complete()
		stop_tracking()
	SStgui.update_uis(ceremony_power)

/datum/ceremonial_objective/status_effect/get_progress_text()
	return "Time spent [effect_name]: [round(time_affected)] seconds."

/*
 * Remain drunk for an extended period.
 */
/datum/ceremonial_objective/status_effect/hedonism
	name = "Hedonism"
	description = "Be drunk for a total of 5 minutes."
	required_effect = /datum/status_effect/inebriated/drunk
	effect_name = "drunk"

/// Only habitual drinkers
/datum/ceremonial_objective/status_effect/hedonism/eligible()
	return holder.has_quirk(/datum/quirk/item_quirk/addict/alcoholic) \
		|| HAS_PERSONALITY(holder, /datum/personality/bibulous)

/*
 * Remain drugged for an extended period.
 */
/datum/ceremonial_objective/status_effect/substances
	name = "Substances"
	description = "Be drugged for a total of 5 minutes."
	required_effect = /datum/status_effect/drugginess
	effect_name = "drugged"

/// Substances
/datum/ceremonial_objective/status_effect/substances/eligible()
	return holder.has_quirk(/datum/quirk/item_quirk/addict/junkie)

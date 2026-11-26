/*
 * HIT THE GYM BUCKO. You need to exercise too so powers doesn't get you this one entirely free.
 */
/datum/ceremonial_objective/exercise
	name = "Exercise"
	description = "Reach at least Journeyman in Athletics and exercise at least once this shift."

/// Limits it only to THOSE WHO LIFT
/datum/ceremonial_objective/exercise/eligible()
	return HAS_PERSONALITY(holder, /datum/personality/athletic)

/datum/ceremonial_objective/exercise/New(datum/power/theologist/ceremony/new_ceremony_power)
	. = ..()
	RegisterSignal(holder, COMSIG_CARBON_MOOD_UPDATE, PROC_REF(on_mood_updated))

/datum/ceremonial_objective/exercise/Destroy()
	UnregisterSignal(holder, COMSIG_CARBON_MOOD_UPDATE)
	return ..()

/// Completes the objective once the mob is athletic enough and has exercised.
/datum/ceremonial_objective/exercise/proc/try_complete()
	var/datum/mood/holder_mood = holder?.mob_mood
	var/datum/mood_event/exercise/exercise_moodlet = holder_mood?.mood_events["exercise"]
	if(holder?.mind?.get_skill_level(/datum/skill/athletics) >= SKILL_LEVEL_JOURNEYMAN && exercise_moodlet)
		complete()

/// Checks the objective's requirements whenever the holder's moodlets change.
/datum/ceremonial_objective/exercise/proc/on_mood_updated(mob/living/source_mob)
	SIGNAL_HANDLER

	try_complete()

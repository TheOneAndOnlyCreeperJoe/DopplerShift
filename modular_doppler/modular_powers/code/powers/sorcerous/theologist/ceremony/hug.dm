/*
 * Hugs. Huuuuuugs. HUUUUUGS.
 * Friendship, companionship, and hopefully people actually CONSENTING hugs and like y'know, asking if you can.
 */
/datum/ceremonial_objective/hug
	name = "Fellowship"

	/// The number of qualifying hugs needed to complete the objective.
	var/required_hugs
	/// The number of qualifying hugs performed by the holder.
	var/hugs_completed = 0
	/// Humanoids already counted toward this objective.
	var/list/mob/living/carbon/human/hugged_humanoids = list()

/// You're barred if you don't like hugs. Wow. You must be a fun person.
/datum/ceremonial_objective/hug/eligible()
	return !HAS_PERSONALITY(holder, /datum/personality/aloof) \
		&& !HAS_PERSONALITY(holder, /datum/personality/aromantic)

/// Chooses a required hug count and begins tracking the help action.
/datum/ceremonial_objective/hug/New(datum/power/theologist/ceremony/new_ceremony_power)
	. = ..()
	required_hugs = pick(3, 4)
	description = "Hug [required_hugs] humanoid sophonts. (Headpats and other similar interactions count too!)"
	RegisterSignal(holder, COMSIG_CARBON_HELPED, PROC_REF(on_hugged))

/datum/ceremonial_objective/hug/Destroy()
	UnregisterSignal(holder, COMSIG_CARBON_HELPED)
	return ..()

/// Records each completed Help interaction with a player-controlled human.
/datum/ceremonial_objective/hug/proc/on_hugged(mob/living/carbon/source, mob/living/carbon/hugged)
	SIGNAL_HANDLER

	if(completed || source != holder || !ishuman(hugged) || !hugged.ckey)
		return

	var/mob/living/carbon/human/humanoid = hugged
	if(humanoid in hugged_humanoids)
		return

	hugged_humanoids += humanoid
	hugs_completed++
	if(hugs_completed >= required_hugs)
		complete()
	SStgui.update_uis(ceremony_power)

/datum/ceremonial_objective/hug/get_progress_text()
	return "Humanoids hugged: [hugs_completed] / [required_hugs]."

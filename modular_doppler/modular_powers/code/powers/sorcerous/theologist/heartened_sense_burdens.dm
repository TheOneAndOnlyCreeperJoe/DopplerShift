/// Allows you to see the exact moodlets on someone similar to Empath.
/// Does not show hidden moodlets.
/// The first hybrid power! I'd wish I had a more general mind reading power over on the psyker side to have as a requirement instead, but telepathy works well enough.

/datum/power/theologist/heartened_sense_burdens
	name = "Sense Mental Burdens"
	desc = "A light form of mind reading, you can sense the details about another creature's mood.\
	\nExamining a mob affected by your A Burden Heartened grants the exact same information about their mood as the mob does, allowing you to accurately pinpoint what is affecting their mood.\
	\nThis does not work on mobs that are scrying immune (or immune to A Burden Heartened). You also cannot see certain moodlets that betray certain allegiances."
	security_record_text = "Subject can read a target's mind and ascertain their general moods, needs and worries."
	security_threat = POWER_THREAT_MAJOR
	value = 3
	required_powers = list(/datum/power/theologist_root/heartened, /datum/power/psyker_power/telepathy)
	magic_flags = POWER_MAGIC_STANDARD | POWER_MAGIC_MENTAL | POWER_MAGIC_SCRYING

/datum/power/theologist/heartened_sense_burdens/add(client/client_source)
	. = ..()
	RegisterSignal(power_holder, COMSIG_MOB_EXAMINATE, PROC_REF(on_examine))

/datum/power/theologist/heartened_sense_burdens/remove()
	UnregisterSignal(power_holder, COMSIG_MOB_EXAMINATE)
	return ..()

/// Checks if the mob is elegible for Sense Mental Burdens and if so, read their moodlets.
/datum/power/theologist/heartened_sense_burdens/proc/on_examine(mob/living/source, atom/examined_atom)
	SIGNAL_HANDLER

	if(!iscarbon(examined_atom))
		return
	var/mob/living/carbon/examined_carbon = examined_atom
	if(!examined_carbon.mob_mood || !examined_carbon.has_status_effect(/datum/status_effect/power/burden_heartened))
		return
	if(HAS_TRAIT(examined_carbon, TRAIT_ANTIRESONANCE_SCRYING) || examined_carbon.can_block_resonance(0))
		return
	if(examined_carbon.can_block_magic(MAGIC_RESISTANCE | MAGIC_RESISTANCE_MIND, charge_cost = 0))
		return

	show_moodlets(source, examined_carbon.mob_mood)

/// Shows all the moodlets on the mob: basically a mimicry of the moodlet readout.
/datum/power/theologist/heartened_sense_burdens/proc/show_moodlets(mob/living/viewer, datum/mood/target_mood)
	var/moodlet_message = span_notice("Moodlets:") + "<br>"
	var/has_visible_moodlet = FALSE
	for(var/category in target_mood.mood_events)
		var/datum/mood_event/moodlet = target_mood.mood_events[category]
		if(moodlet.hidden)
			continue

		has_visible_moodlet = TRUE
		moodlet_message += "&bull; "
		switch(moodlet.mood_change)
			if(-INFINITY to MOOD_SAD2)
				moodlet_message += "[span_boldwarning(moodlet.description)]<br>"
			if(MOOD_SAD2 to MOOD_SAD1)
				moodlet_message += "[span_warning(moodlet.description)]<br>"
			if(MOOD_SAD1 to MOOD_NEUTRAL)
				moodlet_message += "[span_grey(moodlet.description)]<br>"
			if(MOOD_NEUTRAL to MOOD_HAPPY1)
				moodlet_message += "[span_info(moodlet.description)]<br>"
			if(MOOD_HAPPY1 to MOOD_HAPPY2)
				moodlet_message += "[span_nicegreen(moodlet.description)]<br>"
			if(MOOD_HAPPY2 to INFINITY)
				moodlet_message += "[span_boldnicegreen(moodlet.description)]<br>"

	if(!has_visible_moodlet)
		moodlet_message += "&bull; [span_grey("[target_mood.mob_parent.p_they()] don't have much of a reaction to anything right now.")]<br>"

	to_chat(viewer, boxed_message(moodlet_message))

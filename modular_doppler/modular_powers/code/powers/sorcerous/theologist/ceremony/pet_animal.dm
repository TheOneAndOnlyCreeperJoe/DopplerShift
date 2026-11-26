/*
* Have the animal lover buff up for long enough.
* This is restricted to having cat person, dog person or animal lover.
*/
/datum/ceremonial_objective/pet_animal
	name = "Pet Animal"
	description = "Pet an animal, and remain happy for it for at least 10 minutes."

	/// The type of creature we enjoy
	var/enjoyed_creature = "animal"
	/// The number of seconds the mob has retained the full pet-animal moodlet.
	var/time_with_pet = 0
	/// Whether this objective is currently accumulating pet-animal moodlet time.
	var/tracking_pet_happiness = FALSE

/// Animal-based personality types only
/datum/ceremonial_objective/pet_animal/eligible()
	return HAS_PERSONALITY(holder, /datum/personality/animal_friend) \
		|| HAS_PERSONALITY(holder, /datum/personality/cat_fan) \
		|| HAS_PERSONALITY(holder, /datum/personality/dog_fan)

/// Changes the objective depending on if we're a fan of cats, dogs or animals as w hole.
/datum/ceremonial_objective/pet_animal/New(datum/power/theologist/ceremony/new_ceremony_power)
	. = ..()
	if(HAS_PERSONALITY(holder, /datum/personality/cat_fan))
		name = "Pet Cat"
		description = "Pet a cat, and remain happy for it for at least 10 minutes."
		enjoyed_creature = "cat"
	else if(HAS_PERSONALITY(holder, /datum/personality/dog_fan))
		name = "Pet Dog"
		description = "Pet a dog, and remain happy for it for at least 10 minutes."
		enjoyed_creature = "dog"

	RegisterSignal(holder, COMSIG_CARBON_MOOD_UPDATE, PROC_REF(on_mood_updated))
	update_tracking()

/datum/ceremonial_objective/pet_animal/Destroy()
	stop_tracking()
	UnregisterSignal(holder, COMSIG_CARBON_MOOD_UPDATE)
	return ..()

/// Updates processing to match whether the mob has the full pet-animal moodlet.
/datum/ceremonial_objective/pet_animal/proc/update_tracking()
	if(has_fulfilling_pet_mood())
		start_tracking()
		return
	stop_tracking()

/// Returns whether the mob currently has the pet animal mood.
/// Specifically the moodlet that's given to the upgraded versions. There's no distinct moodlet for this one, so this is best way we cna do it!
/datum/ceremonial_objective/pet_animal/proc/has_fulfilling_pet_mood()
	var/datum/mood/holder_mood = holder?.mob_mood
	if(!holder_mood)
		return FALSE

	for(var/category as anything in holder_mood.mood_events)
		var/datum/mood_event/pet_animal/pet_mood = holder_mood.mood_events[category]
		if(istype(pet_mood) && pet_mood.mood_change >= 3)
			return TRUE
	return FALSE

/// Starts accumulating time while the mob has the moodlet
/datum/ceremonial_objective/pet_animal/proc/start_tracking()
	if(completed || tracking_pet_happiness)
		return
	tracking_pet_happiness = TRUE
	START_PROCESSING(SSobj, src)

/// Stops accumulating time when the moodlet's lost.
/datum/ceremonial_objective/pet_animal/proc/stop_tracking()
	if(!tracking_pet_happiness)
		return
	tracking_pet_happiness = FALSE
	STOP_PROCESSING(SSobj, src)

/// Sends an update to the tracker to check if we still qualify.
/datum/ceremonial_objective/pet_animal/proc/on_mood_updated(mob/living/source)
	SIGNAL_HANDLER

	update_tracking()

/// Ticks up the tracker.
/datum/ceremonial_objective/pet_animal/process(seconds_per_tick)
	if(!tracking_pet_happiness || !has_fulfilling_pet_mood())
		stop_tracking()
		return

	time_with_pet += seconds_per_tick
	if(time_with_pet >= 10 MINUTES / 1 SECONDS)
		complete()
		stop_tracking()
	SStgui.update_uis(ceremony_power)

/datum/ceremonial_objective/pet_animal/get_progress_text()
	return "Time spent enjoying [enjoyed_creature]s: [round(time_with_pet)] seconds."

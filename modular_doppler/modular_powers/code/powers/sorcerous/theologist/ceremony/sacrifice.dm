/*
* Kill a creature in the Chapel with 20 or more hp
*/
/datum/ceremonial_objective/sacrifice
	name = "Sacrifice"
	description = "Sacrifice a living creature inside the Chapel. Extremely weak and frail creatures do not count."

/// Registers the global death listener used to identify eligible sacrifices.
/datum/ceremonial_objective/sacrifice/New(datum/power/theologist/ceremony/new_ceremony_power)
	. = ..()
	RegisterSignal(SSdcs, COMSIG_GLOB_MOB_DEATH, PROC_REF(on_mob_death))

/// Removes the global death listener for this objective.
/datum/ceremonial_objective/sacrifice/Destroy()
	UnregisterSignal(SSdcs, COMSIG_GLOB_MOB_DEATH)
	return ..()

/// Completes this objective when another creature with sufficient maximum health dies in the Chapel with its holder present.
/datum/ceremonial_objective/sacrifice/proc/on_mob_death(datum/source, mob/living/died, gibbed)
	SIGNAL_HANDLER

	if(completed || died.maxHealth < 20)
		return
	if(!ceremony_power?.is_inside_chapel(holder) || !ceremony_power.is_inside_chapel(died))
		return
	complete()

/*

	A list of virus bottles of various tiers which can be acquired through the Pathology console.

*/

/datum/disease/advance/pathology/
	name = "Base Pathology Virus"
	desc = "How'd you even come to find this useless thing?"
	copy_type = /datum/disease/advance
	var/min_level = 1
	var/max_level = 1
	var/quantity = 3

/datum/disease/advance/pathology/New()
	var/list/possible_symptoms = list()
	var/has_unique_symptom = FALSE // symptoms we do not want to stack set it to true, e.g mutation symptoms.
	for(var/symp in SSdisease.list_symptoms)
		var/datum/symptom/S = new symp
		if(S.can_generate_randomly(src) && S.level >= min_level && S.level <= max_level && !HasSymptom(S))
			if(istype(S, /datum/symptom/mutation)) // We don't want these to stack.
				if(!has_unique_symptom)
					has_unique_symptom = TRUE
				else
					continue
			possible_symptoms += S
	symptoms = list()
	for(var/i = 1; i <= quantity; i++)
		var/datum/symptom/random_symptom = pick_n_take(possible_symptoms)
		symptoms += random_symptom
	desc = generate_desc(symptoms)
	..()

/datum/disease/advance/pathology/proc/generate_desc(list/symptoms)
	var/desc = "A fully stabilized virus, useful to act as a base for your existing virus. This virus contains the following symptoms: "

	for(var/datum/symptom/S in symptoms)
		desc += "[S.name] | "

	if(length(desc) > 0) // I keep getting list out of bounds errors with other solutions, so we're doing things a little scuffed.
		desc = copytext(desc, 1, length(desc) - 2)

	return desc

// Single Tiers
/datum/disease/advance/pathology/t1
	name = "T1 Pathology Virus"
	min_level = 1
	max_level = 2

/datum/disease/advance/pathology/t2
	name = "T2 Pathology Virus"
	min_level = 3
	max_level = 4

/datum/disease/advance/pathology/t3
	name = "T3 Pathology Virus"
	min_level = 5
	max_level = 6

/datum/disease/advance/pathology/t4
	name = "T4 Pathology Virus"
	min_level = 7
	max_level = 8

// Mixed tiers
/datum/disease/advance/pathology/t1t2
	name = "T1+2 Pathology Virus"
	min_level = 1
	max_level = 4

/datum/disease/advance/pathology/t2t3
	name = "T2+3 Pathology Virus"
	min_level = 3
	max_level = 6


/datum/disease/advance/pathology/t3t4
	name = "T3+4 Pathology Virus"
	min_level = 5
	max_level = 8

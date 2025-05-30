/*Mutation Symptoms
 * Can only be acquired through chems, mutually exclusive with eachother.
 * When the virus mutates, always replaces this symptom.
 * Prevents the virus from mutating into any symptom that does not match the requirements. Currently, these are either having a positive value in a stat, a neutral (0), or a negative.
 * Allows generic mutation to roll ANY level from 1 to 8 (don't let it roll 0 or it'll get debug symptoms).
 * Affects stats depending on the category.
 * Cannot be neutered. This is a risk you have to run with your virus if you want the stats.
*/
/datum/symptom/mutation
	name = "Generic mutation booster (does nothing)"
	stealth = 0
	resistance = 0
	stage_speed = 0
	transmittable = 0
	level = 0 //not obtainable
	symptom_delay_min = 1
	symptom_delay_max = 1
	neuterable = FALSE
	mutateable = FALSE
	var/statistic = "specific" // used for the dynamic descriptions as well as for check_mutation_criteria()

/datum/symptom/mutation/New()
// I honestly don't even know if this is a good solution to making automatically generated descriptions.
	..()
	desc = generate_desc()

/datum/symptom/mutation/proc/generate_desc()
// Admittedly, needing to type the same description 12 times isn't great. So we get it dynamically generated.
	var/descriptor = "positive, neutral or negative"
	if(istype(src, /datum/symptom/mutation/positive))
		descriptor = "positive"
	else if(istype(src, /datum/symptom/mutation/neutral))
		descriptor = "neutral"
	else if(istype(src, /datum/symptom/mutation/negative))
		descriptor = "negative"
	return "A symptom with mutative potential. By itself, it only affects the statistics of a virus. However, when the virus mutates, it will only be able to mutate into a symptom with a [descriptor] [statistic] stat, and causing your mutations to ignore level restrictions if it fails to roll a circumstance-based mutation.\n Note that mutation booster symptoms are special: they cannot be neutered, a virus can only have one mutation sympton at a time and when a mutation occurs it will always replace a mutation symptom (even if you have less than 6 symptoms)."

/datum/symptom/mutation/can_generate_randomly(datum/disease/advance/advanced_disease)
// Shouldn't be able to occur if you already have one.
	if(!advanced_disease) // In the event we don't give along a disease. This should only happen in rare cases and typically, those don't involve multiple mutation symptoms.
		return TRUE
	for(var/symptom in advanced_disease.symptoms)
		if(istype(symptom, /datum/symptom/mutation))
			return FALSE
	return TRUE

/datum/symptom/mutation/check_circumstance(mob/living/host)
// Can't be circumstance'd, don't want it to mutate into itself!
	return 0

/datum/symptom/mutation/proc/check_mutation_criteria(datum/symptom/S)
// These are used currently for the numerical mutation symptoms, but if you ever come up with some crazy mutation, you can just, replace this proc for that symptom.
	var/value = 0
	switch(statistic)
		if("stealth")       value = S.stealth
		if("resistance")    value = S.resistance
		if("stage_speed")   value = S.stage_speed
		if("transmission") 	value = S.transmittable
		else return FALSE

	if(istype(src, /datum/symptom/mutation/positive))
		return value > 0
	else if(istype(src, /datum/symptom/mutation/negative))
		return value < 0
	else if(istype(src, /datum/symptom/mutation/neutral))
		return value == 0

	return FALSE

/* Positive Mutation Symptoms
 * Boosts the affected stat greatly.
 * Doesn't affect anything else, which can be seen as a good thing!
 * Has a level of 7
*/
/datum/symptom/mutation/positive
	name = "Mutation Booster - Positive NONE (does nothing)"

/datum/symptom/mutation/positive/stealth
	name = "Mutation Booster - Positive Stealth"
	statistic = "stealth"
	level = 7
	stealth = 4 // Stealth is a bit of a rarer stat, may want to make it less extreme.

/datum/symptom/mutation/positive/resistance
	name = "Mutation Booster - Positive Resistance"
	statistic = "resistance"
	level = 7
	resistance = 5

/datum/symptom/mutation/positive/stage_speed
	name = "Mutation Booster - Positive Stage Speed"
	statistic = "stage_speed"
	level = 7
	stage_speed = 5

/datum/symptom/mutation/positive/transmittable
	name = "Mutation Booster - Positive Transmission"
	statistic = "transmission" // since this is used in our descriptions we want to use the player-facing terminology.
	level = 7
	transmittable = 5

/* Neutral Mutation Symptoms
 * Affected stat is a 0, all other stats up by 2
 * Has a level of 6
*/
/datum/symptom/mutation/neutral
	name = "Mutation Booster - Neutral NONE (does nothing)"

/datum/symptom/mutation/neutral/stealth
	name = "Mutation Booster - Neutral Stealth"
	statistic = "stealth"
	level = 6
	stealth = 0
	resistance = 2
	stage_speed = 2
	transmittable = 2

/datum/symptom/mutation/neutral/resistance
	name = "Mutation Booster - Neutral Resistance"
	statistic = "resistance"
	level = 6
	stealth = 2
	resistance = 0
	stage_speed = 2
	transmittable = 2

/datum/symptom/mutation/neutral/stage_speed
	name = "Mutation Booster - Neutral Stage Speed"
	statistic = "stage_speed"
	level = 6
	stealth = 2
	resistance = 2
	stage_speed = 0
	transmittable = 2

/datum/symptom/mutation/neutral/transmittable
	name = "Mutation Booster - Neutral Transmission"
	statistic = "transmission"
	level = 6
	stealth = 2
	resistance = 2
	stage_speed = 2
	transmittable = 0

/* Negative Mutation Symptoms
 * Affected stat is lowered by -4, all other stats up by 3
 * Has a level of 5
*/
/datum/symptom/mutation/negative
	name = "Mutation Booster - Negative NONE (does nothing)"

/datum/symptom/mutation/negative/stealth
	name = "Mutation Booster - Negative Stealth"
	statistic = "stealth"
	level = 5
	stealth = -3
	resistance = 3
	stage_speed = 3
	transmittable = 3

/datum/symptom/mutation/negative/resistance
	name = "Mutation Booster - Negative Resistance"
	statistic = "resistance"
	level = 5
	stealth = 2
	resistance = -4
	stage_speed = 3
	transmittable = 3

/datum/symptom/mutation/negative/stage_speed
	name = "Mutation Booster - Negative Stage Speed"
	statistic = "stage_speed"
	level = 5
	stealth = 2
	resistance = 3
	stage_speed = -4
	transmittable = 3

/datum/symptom/mutation/negative/transmittable
	name = "Mutation Booster - Negative Transmission"
	statistic = "transmission"
	level = 5
	stealth = 2
	resistance = 3
	stage_speed = 3
	transmittable = -4

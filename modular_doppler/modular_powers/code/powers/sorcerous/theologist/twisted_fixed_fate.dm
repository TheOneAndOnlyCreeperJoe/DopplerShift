/* Makes your Burden Twisted always convert healing into a certain damage type. Not always better, but certainly more consistent, so you can tailor your heal-mixes and all that.
	Also heals twice as fast so it gets the job done quick.
*/
/datum/power/theologist/twisted_fixed_fate
	name = "Fixed Fate"
	desc = "Rather than twisting grievous injuries into many smaller injuries, you instead twist them into one singular, larger injury. Choose a damage type besides suffocation.\
	\nA Burden Twisted no longer heals that damage-type, instead converting all other damage besides suffocation into that type instead, regardless of how much damage that damage-type had.\
	\nA Burden Twisted's base healing is doubled: this does not affect the damage conversion ratio."
	security_record_text = "Subject's healing powers always convert the target's wounds into a fixed type."
	value = 1
	required_powers = list(/datum/power/theologist/root/twisted)
	power_flags = POWER_HUMAN_ONLY | POWER_HEALING

/datum/power/theologist/twisted_fixed_fate/get_security_record_text()
	return "Subject's healing powers always convert the target's injuries into [get_preferred_damage_type()] injuries."

// Normally I try to make upgrades not be hardcoded into the powers, but this is such a small thing.
/datum/power/theologist/twisted_fixed_fate/post_add()
	. = ..()
	var/datum/action/cooldown/power/theologist/theologist_root/twisted/twisted_action = get_twisted_action()
	if(!twisted_action)
		return
	twisted_action.fixed_damage_type = get_preferred_damage_type()
	twisted_action.base_healing_amount *= 2 // passing it along as a healing modifier also affects conversions which we don't want, so we just double the base.

/datum/power/theologist/twisted_fixed_fate/remove()
	var/datum/action/cooldown/power/theologist/theologist_root/twisted/twisted_action = get_twisted_action()
	if(twisted_action)
		twisted_action.fixed_damage_type = null
		twisted_action.base_healing_amount /= 2
	return ..()

/// Gets the action belonging to A Burden Twisted.
/datum/power/theologist/twisted_fixed_fate/proc/get_twisted_action()
	var/datum/power/theologist/root/twisted/twisted_power = power_holder?.get_power(/datum/power/theologist/root/twisted)
	var/datum/action/cooldown/power/theologist/theologist_root/twisted/twisted_action = twisted_power?.action_path
	if(istype(twisted_action))
		return twisted_action
	return null

/// Converts the preference into the damage type used by A Burden Twisted.
/datum/power/theologist/twisted_fixed_fate/proc/get_preferred_damage_type()
	var/damage_type_choice = power_holder?.client?.prefs?.read_preference(/datum/preference/choiced/twisted_fixed_fate_damage_type)
	switch(damage_type_choice)
		if("Burn")
			return "burn"
		if("Toxin")
			return "tox"
		else
			return "brute"

/// Preference choice for the damage type used by Fixed Fate.
/datum/preference/choiced/twisted_fixed_fate_damage_type
	category = PREFERENCE_CATEGORY_MANUALLY_RENDERED
	savefile_key = "twisted_fixed_fate_damage_type"
	savefile_identifier = PREFERENCE_CHARACTER

/datum/preference/choiced/twisted_fixed_fate_damage_type/create_default_value()
	return "Brute"

/datum/preference/choiced/twisted_fixed_fate_damage_type/init_possible_values()
	return list("Brute", "Burn", "Toxin")

/datum/preference/choiced/twisted_fixed_fate_damage_type/is_accessible(datum/preferences/preferences)
	if(!..(preferences))
		return FALSE
	return TRUE

/datum/preference/choiced/twisted_fixed_fate_damage_type/apply_to_human(mob/living/carbon/human/target, value)
	return

/datum/power_constant_data/twisted_fixed_fate
	associated_typepath = /datum/power/theologist/twisted_fixed_fate
	customization_options = list(/datum/preference/choiced/twisted_fixed_fate_damage_type)

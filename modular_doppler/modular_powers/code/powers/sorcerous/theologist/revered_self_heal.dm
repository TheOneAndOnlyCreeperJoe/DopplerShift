/*
	Moved to an upgrade because self-heals are just too good.
*/
/datum/power/theologist/revered_self_heal
	name = "Revere Own's Burden"
	desc = "Your will to alleviate pain extends to yourself, for you cannot tend to the burdens of others lest your own is tended to.\
	\nYour Burden Revered can now target yourself."
	security_record_text = "Subject can heal themselves using their healing powers."
	security_threat = POWER_THREAT_MAJOR
	value = 3
	required_powers = list(/datum/power/theologist_root/revered)
	power_flags = POWER_HUMAN_ONLY | POWER_HEALING

/datum/power/theologist/revered_self_heal/post_add()
	. = ..()
	var/datum/action/cooldown/power/theologist/theologist_root/revered/revered_action = get_revered_action()
	if(!revered_action)
		return
	revered_action.target_self = TRUE

/datum/power/theologist/revered_self_heal/remove()
	var/datum/action/cooldown/power/theologist/theologist_root/revered/revered_action = get_revered_action()
	if(revered_action)
		revered_action.target_self = FALSE
	return ..()

/// Gets A Burden Revered.
/datum/power/theologist/revered_self_heal/proc/get_revered_action()
	var/datum/power/theologist_root/revered/revered_power = power_holder?.get_power(/datum/power/theologist_root/revered)
	var/datum/action/cooldown/power/theologist/theologist_root/revered/revered_action = revered_power?.action_path
	if(istype(revered_action))
		return revered_action
	return null

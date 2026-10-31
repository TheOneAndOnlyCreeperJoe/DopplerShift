/datum/power/theologist/twisted_pious_touch
	name = "Pious Touch"
	desc = "Your Piety allows you to heal even the slightest of scraps and bruises with a touch. Every 5 Piety lowers the minimum injury threshold of A Burden Twisted by 1% of the target's maximum health.\
	\nAt 50 Piety, this will allow you to completely heal any injuries."
	security_record_text = "Subject's healing powers become more powerful with repeated use."
	value = 2
	required_powers = list(/datum/power/theologist_root/twisted)

	/// The Piety required to reduce Burden Twisted's healing threshold by one increment.
	var/piety_per_threshold_reduction = 5
	/// The amount Burden Twisted's healing threshold is reduced for each Piety increment.
	var/healing_threshold_reduction = 0.01

/datum/power/theologist/twisted_pious_touch/add(client/client_source)
	. = ..()
	RegisterSignal(power_holder, COMSIG_THEOLOGIST_TWISTED_HEALING_THRESHOLD_MODIFIERS, PROC_REF(add_twisted_healing_threshold_modifier))

/datum/power/theologist/twisted_pious_touch/remove()
	. = ..()
	UnregisterSignal(power_holder, COMSIG_THEOLOGIST_TWISTED_HEALING_THRESHOLD_MODIFIERS)

/// Adds the holder's current Piety contribution to Burden Twisted's healing-threshold reduction.
/datum/power/theologist/twisted_pious_touch/proc/add_twisted_healing_threshold_modifier(mob/living/source, list/healing_threshold_modifiers)
	SIGNAL_HANDLER

	if(!istype(source))
		return NONE

	var/datum/component/theologist_piety/piety_component = source.GetComponent(/datum/component/theologist_piety)
	if(!piety_component || piety_component.piety <= 0)
		return NONE

	healing_threshold_modifiers += piety_component.piety / piety_per_threshold_reduction * healing_threshold_reduction
	return NONE

/* Really straightforward power to give Condemnation some extra umph and help kickstart some degree of Condemnation. */
/datum/power/theologist/condemned_righteous_decree
	name = "Righteous Decree"
	desc = "Your actions grant your condemns a righteous mandate.\
	\nMarking a target with Condemned applies a base amount of Condemnation. The amount is 5 + (Piety * 0.3). \
	This Condemnation does not generate the extra Piety normally granted when applying Condemnation to Unholy targets, but still builds Condemnation on consumption as normal."
	security_record_text = "Subject can weaken foes's attacks through gesture alone."
	security_threat = POWER_THREAT_MAJOR
	value = 3
	required_powers = list(/datum/power/theologist/root/condemned)

	/// Base condemnation applied
	var/base_condemnation = 5
	/// Fraction of how much Condemnation is applied per Piety
	var/piety_per_condemnation = 0.3

/datum/power/theologist/condemned_righteous_decree/post_add()
	. = ..()
	RegisterSignal(power_holder, COMSIG_POWER_ACTION_SUCCESS, PROC_REF(on_power_action_success))

/datum/power/theologist/condemned_righteous_decree/remove()
	UnregisterSignal(power_holder, COMSIG_POWER_ACTION_SUCCESS)
	return ..()

/// Applies Condemnation onto the Condemned when we succesfully use Condemnation on a target. Con-Damn-It.
/datum/power/theologist/condemned_righteous_decree/proc/on_power_action_success(mob/living/signal_source, datum/action/cooldown/power/used_power, atom/target)
	SIGNAL_HANDLER
	// action validation
	if(!istype(used_power, /datum/action/cooldown/power/theologist/theologist_root/condemned) || !isliving(target))
		return
	var/datum/action/cooldown/power/theologist/theologist_root/condemned/condemned_power = used_power

	// condemn status validation
	var/mob/living/living_target = target
	var/datum/status_effect/power/burden_condemned/condemned_effect = living_target.has_status_effect(/datum/status_effect/power/burden_condemned)
	if(!condemned_effect)
		return

	/// applies the condemnation
	condemned_effect.condemnation += base_condemnation + condemned_power.get_piety() * piety_per_condemnation
	condemned_effect.update_condemnation_alert()

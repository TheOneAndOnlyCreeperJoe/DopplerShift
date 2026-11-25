/* CDR on kill. We really are an ARPG now huh? */
/datum/power/theologist/zealous_momentum
	name = "Zealous Momentum"
	desc = "Your duty is far from done after the kill, it is but only one of the hydra's heads that have been slain; more are to come!\
	\nYou gain the effects of Time of Need whenever your Condemned target dies, without the cost or cooldown associated. This can only trigger once every 15 seconds."
	security_record_text = "Subject's power usage frequency grealty increases after a kill."
	security_threat = POWER_THREAT_MAJOR
	value = 2
	required_powers = list(/datum/power/theologist/root/condemned, /datum/power/theologist/time_of_need)

	menu_icon = 'icons/obj/clothing/head/helmet.dmi'
	menu_icon_state = "gladiator"


	/// The current Condemned target whose death Zealous Momentum observes.
	var/mob/living/condemned_target
	/// Cooldown on repeated uses.
	COOLDOWN_DECLARE(zealous_momentum_cooldown)

/datum/power/theologist/zealous_momentum/post_add()
	. = ..()
	RegisterSignal(power_holder, COMSIG_POWER_ACTION_SUCCESS, PROC_REF(on_power_action_success))

/datum/power/theologist/zealous_momentum/remove()
	UnregisterSignal(power_holder, COMSIG_POWER_ACTION_SUCCESS)
	stop_observing_oldest_condemn()
	return ..()

/// Begins observing a target after condemning them
/datum/power/theologist/zealous_momentum/proc/on_power_action_success(mob/living/source, datum/action/cooldown/power/used_power, atom/target)
	SIGNAL_HANDLER
	if(!istype(used_power, /datum/action/cooldown/power/theologist/theologist_root/condemned) || !isliving(target))
		return

	var/mob/living/new_condemned_target = target
	var/datum/status_effect/power/burden_condemned/condemned_effect = new_condemned_target.has_status_effect(/datum/status_effect/power/burden_condemned)
	if(condemned_effect?.condemning_action?.owner != power_holder)
		return

	stop_observing_oldest_condemn()
	condemned_target = new_condemned_target
	RegisterSignal(condemned_target, COMSIG_LIVING_DEATH, PROC_REF(on_condemned_target_death))

/// Activates Time of Need when the observed target dies while still condemned (by this power's owner)
/datum/power/theologist/zealous_momentum/proc/on_condemned_target_death(mob/living/source, gibbed)
	SIGNAL_HANDLER
	// only fires withotu cd
	if(source != condemned_target || !COOLDOWN_FINISHED(src, zealous_momentum_cooldown))
		return

	// get status
	var/datum/status_effect/power/burden_condemned/condemned_effect = source.has_status_effect(/datum/status_effect/power/burden_condemned)
	if(condemned_effect?.condemning_action?.owner != power_holder)
		return

	var/datum/power/theologist/time_of_need/time_of_need_power = power_holder.get_power(/datum/power/theologist/time_of_need)
	var/datum/action/cooldown/power/theologist/time_of_need/time_of_need_action = time_of_need_power?.action_path
	// Calling use action directly also skips the validation. Whilst most of it shouldn't apply, being silenced SHOULD.
	if(time_of_need_action.is_magical() && HAS_TRAIT(power_holder, TRAIT_RESONANCE_SILENCED))
		return
	if(time_of_need_action?.use_action(power_holder, power_holder))
		COOLDOWN_START(src, zealous_momentum_cooldown, 15 SECONDS)

/// Stops observing the previous Condemned target's death.
/datum/power/theologist/zealous_momentum/proc/stop_observing_oldest_condemn()
	if(!condemned_target)
		return
	UnregisterSignal(condemned_target, COMSIG_LIVING_DEATH)
	condemned_target = null

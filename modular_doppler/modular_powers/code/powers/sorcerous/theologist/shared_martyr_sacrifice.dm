/* Caters to the masculine urge of dying heroically for the sake of others.
	* - You can no longer transfer damage away from you.
	* - You no longer pass out in critical conditions.
	* - You are forcefully made a pacifist whilst you are in critical condition, and gain multiplicative healing based on your missing health.
	* - You get sween boons for dying as an actual martyr: +25 piety cap (once per round) and maxed piety
*/
/datum/power/theologist/shared_martyr_sacrifice
	name = "Martyr's Sacrifice"
	desc = "You give your life onto others, right up until the bitter end. A Burden Shared no longer transfers damage away from you, transfers at the maximum rate at all times (rather than scaling off of health difference) and will now keep transfering damage to you without an upper limit. It also has a much shorter cooldown. \
	\nIn turn, you no longer fall unconscious in critical condition. Whilst in critical condition, you are incapable of partaking in combat and are afflicted with pacifism. If you do not have A Burden Shared active while in critical, your condition will deteriorate as it normally would. You will die as normal when reaching maximum damage.\
	\nYour healing powers are much more potent the closer you are to death: 1% more healing for every percentage of health lost. This bonus is multiplicative"
	security_record_text = "Subject's healing powers transfer all damage on the target onto themselves, and allow them to remain conscious even in critical condition."
	security_threat = POWER_THREAT_MINOR
	value = 2
	power_flags = POWER_HUMAN_ONLY | POWER_PROCESSES | POWER_HEALING
	required_powers = list(/datum/power/theologist_root/shared)

	menu_icon = 'modular_doppler/modular_powers/icons/powers/actions_icons.dmi'
	menu_icon_state = "burden_shared_sacrifice"

	/// The base A Burden Shared action this upgrade enhances.
	var/datum/action/cooldown/power/theologist/theologist_root/shared/shared_action
	/// The current A Burden Shared target. Kept generic because Shared can target non-carbons.
	var/mob/living/shared_target
	/// How much the first martyrdom death increases the holder's piety cap.
	var/martyr_piety_cap_bonus = 25
	/// Whether this power has already granted its once-per-round piety cap reward.
	var/martyr_reward_claimed = FALSE

/datum/power/theologist/shared_martyr_sacrifice/post_add()
	. = ..()
	var/datum/power/theologist_root/shared/shared_power = power_holder?.get_power(/datum/power/theologist_root/shared)
	shared_action = shared_power?.action_path
	if(shared_action)
		shared_action.transfer_mode = BURDEN_TRANSFER_DRAW_ALL
		shared_action.cooldown_time = 3 SECONDS
	power_holder.add_traits(list(TRAIT_NOSOFTCRIT, TRAIT_NOHARDCRIT), REF(src))
	RegisterSignal(power_holder, COMSIG_POWER_ACTION_SUCCESS, PROC_REF(on_power_action_success))
	RegisterSignal(power_holder, COMSIG_LIVING_HEALTH_UPDATE, PROC_REF(on_holder_health_updated))
	RegisterSignal(power_holder, COMSIG_POWER_HEALING_MODIFIERS, PROC_REF(add_healing_modifier))
	power_holder.updatehealth()

/datum/power/theologist/shared_martyr_sacrifice/remove()
	STOP_PROCESSING(SSpowers, src)
	UnregisterSignal(power_holder, list(COMSIG_POWER_ACTION_SUCCESS, COMSIG_LIVING_HEALTH_UPDATE, COMSIG_POWER_HEALING_MODIFIERS))
	power_holder?.remove_traits(list(TRAIT_NOSOFTCRIT, TRAIT_NOHARDCRIT), REF(src))
	power_holder?.remove_status_effect(/datum/status_effect/power/martyrs_sacrifice)
	power_holder?.updatehealth()
	if(shared_action)
		shared_action.transfer_mode = BURDEN_TRANSFER_EQUALIZE
		shared_action.cooldown_time = initial(shared_action.cooldown_time)
		shared_action = null
	shared_target = null
	return ..()

/// Starts tracking a successful A Burden Shared link.
/datum/power/theologist/shared_martyr_sacrifice/proc/on_power_action_success(mob/living/signal_source, datum/action/cooldown/power/used_power, atom/target)
	SIGNAL_HANDLER
	if(used_power != shared_action || !isliving(target))
		return
	shared_target = target
	var/datum/status_effect/power/martyrs_sacrifice/martyr_effect = power_holder.has_status_effect(/datum/status_effect/power/martyrs_sacrifice)
	if(martyr_effect)
		martyr_effect.shared_used_during_crit = TRUE
	shared_action.snapshot_healing_multiplier(target)
	START_PROCESSING(SSpowers, src)

/// Keeps Shared's healing multiplier synchronized with the caster's changing health.
/datum/power/theologist/shared_martyr_sacrifice/process(seconds_per_tick)
	if(!shared_action?.active)
		shared_target = null
		STOP_PROCESSING(SSpowers, src)
		return
	shared_target = shared_action.current_target
	if(isliving(shared_target))
		shared_action.snapshot_healing_multiplier(shared_target) // I don't like repeatedly snapshotting since it deviates from standard behaviour but this is the best way I can actually inject the healing bonus on the fly.

/// Applies pacifism for exactly as long as the holder remains alive and in critical condition.
/datum/power/theologist/shared_martyr_sacrifice/proc/on_holder_health_updated(datum/source)
	SIGNAL_HANDLER
	if(power_holder.stat != DEAD && power_holder.health <= power_holder.crit_threshold)
		power_holder.apply_status_effect(/datum/status_effect/power/martyrs_sacrifice, src)
	else
		power_holder.remove_status_effect(/datum/status_effect/power/martyrs_sacrifice)

/// Scales healing powers with the holder's missing-health percentage while protected by martyrdom.
/datum/power/theologist/shared_martyr_sacrifice/proc/add_healing_modifier(mob/living/source, atom/healing_target, list/additive_healing_modifiers, list/multiplicative_healing_modifiers)
	SIGNAL_HANDLER
	var/missing_health_percentage = (source.maxHealth - source.health) / source.maxHealth
	multiplicative_healing_modifiers += max(0, missing_health_percentage)
	return NONE

/// Rewards a death under martyrdom and increases the user's max piety for that round.
/datum/power/theologist/shared_martyr_sacrifice/proc/on_martyr_death()
	if(!power_holder)
		return
	to_chat(power_holder, "<font color='[POWER_COLOR_THEOLOGIST]' size='5'><b>Your final burden is witnessed. You have died a true martyr.</b></font>")

	var/datum/component/theologist_piety/piety_component = power_holder.GetComponent(/datum/component/theologist_piety)
	if(!piety_component)
		return
	if(!martyr_reward_claimed)
		to_chat(power_holder, "<font color='[POWER_COLOR_THEOLOGIST]'><b>Your maximum Piety has increased!</b></font>")
		power_holder.playsound_local(power_holder, 'sound/effects/pray.ogg', 50, FALSE)
		martyr_reward_claimed = TRUE
		piety_component.max_piety += martyr_piety_cap_bonus
	piety_component.adjust_piety(piety_component.max_piety)

/// Status effect for tracking whether we are in crit or not.
/datum/status_effect/power/martyrs_sacrifice
	id = "martyrs_sacrifice"
	tick_interval = 1 SECONDS
	alert_type = null
	/// The power which will grant the martyrdom reward if the owner dies during this effect.
	var/datum/power/theologist/shared_martyr_sacrifice/source_power
	/// Whether A Burden Shared was active on entering critical condition or activated before leaving it.
	var/shared_used_during_crit = FALSE

/datum/status_effect/power/martyrs_sacrifice/on_creation(mob/living/new_owner, datum/power/theologist/shared_martyr_sacrifice/new_source_power)
	source_power = new_source_power
	shared_used_during_crit = source_power.shared_action?.active
	return ..()

/datum/status_effect/power/martyrs_sacrifice/on_apply()
	. = ..()
	if(!.)
		return FALSE
	ADD_TRAIT(owner, TRAIT_PACIFISM, TRAIT_STATUS_EFFECT(id))
	RegisterSignal(owner, COMSIG_LIVING_DEATH, PROC_REF(on_owner_death))
	return TRUE

/// Mimmicks crit conditions because no-soft-crit removes those.
/// Doesn't damage androids so they get a freebie.
/datum/status_effect/power/martyrs_sacrifice/tick(seconds_per_tick)
	if(source_power?.shared_action?.active) // you do not take damage while burden shared is active
		return
	if(HAS_TRAIT(owner, TRAIT_STASIS) || HAS_TRAIT(owner, TRAIT_NOCRITDAMAGE))
		return
	var/damage_per_second = HUMAN_CRIT_MAX_OXYLOSS / SSMOBS_DT
	if(owner.health > HEALTH_THRESHOLD_FULLCRIT)
		damage_per_second /= 4
	owner.adjustOxyLoss(damage_per_second * seconds_per_tick)

/datum/status_effect/power/martyrs_sacrifice/on_remove()
	UnregisterSignal(owner, COMSIG_LIVING_DEATH)
	REMOVE_TRAIT(owner, TRAIT_PACIFISM, TRAIT_STATUS_EFFECT(id))
	source_power = null
	return ..()

/// Gives us great power for our great deeds (by signalling on_martyr_death()).
/datum/status_effect/power/martyrs_sacrifice/proc/on_owner_death(datum/source, gibbed)
	SIGNAL_HANDLER
	if(shared_used_during_crit)
		source_power?.on_martyr_death()
	qdel(src)

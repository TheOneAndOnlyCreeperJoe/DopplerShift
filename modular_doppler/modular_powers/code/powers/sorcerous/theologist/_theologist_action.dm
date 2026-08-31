/datum/action/cooldown/power/theologist
	name = "abstract theologist power action - ahelp this"
	background_icon_state = "bg_theologist"
	overlay_icon_state = "bg_theologist_border"

	/// The component that handles most piety components.
	var/datum/component/theologist_piety/piety_component

	/// Reference to the theologist UI component
	var/atom/movable/screen/theologist_piety/theologist_ui

	/// Cost in Piety to use.
	var/cost

	/// Healing multiplier collected and snapshotted when a healing power is used.
	var/healing_multiplier = 1

/datum/action/cooldown/power/theologist/Grant(mob/grant_to)
	. = ..()
	ValidatePietyComponent()
	return .

/// Since Theologist has both 3 roots and a persistent resource system, we use a component for handling Piety
/datum/action/cooldown/power/theologist/proc/ValidatePietyComponent()
	if(owner) // Prevents runtiming on start
		var/mob/living/carrier = owner
		piety_component = carrier.GetComponent(/datum/component/theologist_piety)
	if(!piety_component)
		return FALSE
	return TRUE

/// Validation handled in the piety component.
/datum/action/cooldown/power/theologist/proc/adjust_piety(amount, override_cap)
	piety_component.adjust_piety(amount, override_cap)

/// Gets the current piety of the mob.
/datum/action/cooldown/power/theologist/proc/get_piety()
	return piety_component.piety

/// Snapshots additive and multiplicative healing modifiers for the current use of a healing power.
/datum/action/cooldown/power/theologist/proc/snapshot_healing_multiplier(atom/healing_target)
	var/list/additive_healing_modifiers = list()
	var/list/multiplicative_healing_modifiers = list()
	SEND_SIGNAL(owner, COMSIG_THEOLOGIST_HEALING_MODIFIERS, healing_target, additive_healing_modifiers, multiplicative_healing_modifiers)

	healing_multiplier = 1
	for(var/additive_healing_modifier in additive_healing_modifiers)
		healing_multiplier += additive_healing_modifier
	for(var/multiplicative_healing_modifier in multiplicative_healing_modifiers)
		healing_multiplier *= multiplicative_healing_modifier

	return healing_multiplier

// We check to see if our piety component is actually there, because usually things will go bad if they don't.
/datum/action/cooldown/power/theologist/try_use(mob/living/user, mob/living/target)
	if(!ValidatePietyComponent())
		owner.balloon_alert(owner, "Yell at the coders; you're missing your piety system!")
		return FALSE
	if(piety_component.piety < cost)
		user.balloon_alert(user, "needs [cost] piety!")
		return FALSE
	. = .. ()

// Make sure the cost gets deducted after using the power (we already checked if we can afford it)
/datum/action/cooldown/power/theologist/on_action_success(mob/living/user, atom/target)
	if(cost)
		adjust_piety(-cost)
	return

/*
	Grants healing bonuses based on if:
	- Your target is spiritual or holy
	- You or your target are in the Chapel
	The first does not apply if you are targeting yourself.
*/
/datum/power/theologist/faithful_healing
	name = "Spritual Healing"
	desc = "You believe that healing will come to all that indulge the spiritual and holy.\
	\nYou gain a 15% increase to healing for each of the following criteria you fullfil: Your target is spiritualist or holy, or you or the target are in the chapel.\
	\nYou cannot gain the first bonuses if you are targeting yourself."
	security_record_text = "Subject's healing is more powerful on targets with a religious background."
	value = 1
	power_flags = POWER_HUMAN_ONLY | POWER_HEALING

	menu_icon = 'icons/obj/clothing/neck.dmi'
	menu_icon_state = "beads"

	required_powers = list(/datum/power/theologist/faithful)

	/// How much of a healing multiplier each bonus. Base healing * (1 + healing_bonus).
	var/healing_bonus = 0.15
	/// Cooldown on informing someone they're healing a spiritual person. Most powers only get their healing modifiers once, but some call it often enough it can be spammy.
	COOLDOWN_DECLARE(spiritual_message_cooldown)

/datum/power/theologist/faithful_healing/add(client/client_source)
	. = ..()
	RegisterSignal(power_holder, COMSIG_POWER_HEALING_MODIFIERS, PROC_REF(add_healing_modifier))

/datum/power/theologist/faithful_healing/remove()
	. = ..()
	UnregisterSignal(power_holder, COMSIG_POWER_HEALING_MODIFIERS)

/// Adds Pious Prayer's healing bonus if either the healer or their target is inside the Chapel when healing is snapshotted.
/datum/power/theologist/faithful_healing/proc/add_healing_modifier(mob/living/source, atom/healing_target, list/additive_healing_modifiers, list/multiplicative_healing_modifiers)
	SIGNAL_HANDLER

	if(!istype(source))
		return NONE

	var/total_healing_bonus

	// Spiritual heal
	if(healing_target != source && isliving(healing_target))
		var/mob/living/target = healing_target
		if(HAS_TRAIT(target, TRAIT_SPIRITUAL) || HAS_TRAIT(target, TRAIT_HOLY))
			total_healing_bonus += healing_bonus
			to_chat(source, span_notice("Your healing seems to resonate with [healing_target.name]!"))
			COOLDOWN_START(src, spiritual_message_cooldown, 10 SECONDS)

	// Chapel heal
	if(is_inside_chapel(source) || is_inside_chapel(healing_target))
		total_healing_bonus += healing_bonus

	additive_healing_modifiers += total_healing_bonus
	return NONE

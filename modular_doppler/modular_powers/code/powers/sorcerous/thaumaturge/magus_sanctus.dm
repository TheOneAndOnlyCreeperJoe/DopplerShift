/*
	Theologist so we get away with latin.
	Affinity applies to healing mods, pretty straightforward.

	In the future when we do the thaum overhaul (out of scope rn) including adjusting how affinity works,
	this should also grant affinity bonuses to holy items such as dressing like a nun.
*/

/datum/power/thaumaturge/magus_sanctus
	name = "Magus Sanctus"
	desc = "You practice miracles, and your versatility in sorcery allows your magical domains to overlap, greatly empowering your healing.\
	\nYou gain 5% increased healing effectiveness for every point of Affinity you have."
	value = 2
	required_powers = list(/datum/power/theologist/root, /datum/power/thaumaturge/root/spell_preparation)
	required_allow_subtypes = TRUE

	menu_icon = 'icons/obj/weapons/guns/magic.dmi'
	menu_icon_state = "staffofhealing"

	power_flags = POWER_HUMAN_ONLY | POWER_HEALING

	/// Bonus % per point of healing. Base healing * (1 + healing_bonus).
	var/bonus_per_affinity = 0.05

/datum/power/thaumaturge/magus_sanctus/add(client/client_source)
	. = ..()
	RegisterSignal(power_holder, COMSIG_POWER_HEALING_MODIFIERS, PROC_REF(add_healing_modifier))

/datum/power/thaumaturge/magus_sanctus/remove()
	. = ..()
	UnregisterSignal(power_holder, COMSIG_POWER_HEALING_MODIFIERS)

/// Gets affinity, multiplies by bonus_per_affinity, wabam. MOAR HEALING.
/datum/power/thaumaturge/magus_sanctus/proc/add_healing_modifier(mob/living/source, atom/healing_target, list/additive_healing_modifiers, list/multiplicative_healing_modifiers)
	SIGNAL_HANDLER

	if(!istype(source))
		return

	additive_healing_modifiers += bonus_per_affinity * get_affinity(source)
	return

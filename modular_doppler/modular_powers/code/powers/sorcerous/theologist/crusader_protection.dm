/*
	Lucky/advantage mechanics for Divine Protection if its against projectile, but forefit your right to guns.
	SOME DAY LOVE WILL FIND YOU
*/

/datum/power/theologist/crusader_protection
	name = "Warrior Crusader"
	desc = "You believe in the virtue of fighting up close and personal. Your Divine Protection rolls it's block chance three additional times when blocking projectiles.\
	\nThe amount of granted rerolls diminishes with Piety above 50, capping your effective chance at 75% (not including other sources of rerolls). \
	\nYou cannot shoot firearms."
	security_record_text = "Subject miraculously avoids nearly all harm from firearms, but is unable to use firearms."
	security_threat = POWER_THREAT_MAJOR
	mob_trait = TRAIT_NOGUNS
	value = 0

	required_powers = list(/datum/power/theologist/divine_protection)

/datum/power/theologist/crusader_protection/add(client/client_source)
	. = ..()
	RegisterSignal(power_holder, COMSIG_THEOLOGIST_DIVINE_PROTECTION_ROLLS, PROC_REF(calculate_reroll))

/datum/power/theologist/crusader_protection/remove()
	. = ..()
	UnregisterSignal(power_holder, COMSIG_THEOLOGIST_DIVINE_PROTECTION_ROLLS)

/// Registers Crusader's Protection as a reroll if we're being hitby a projectile
/datum/power/theologist/crusader_protection/proc/calculate_reroll(mob/living/blocking_user, atom/movable/hitby, damage, attack_text, attack_type, armour_penetration, damage_type, list/divine_protection_rolls)
	SIGNAL_HANDLER

	// Is it a projectile? No? Don't care.
	if(!isprojectile(hitby))
		return NONE

	// Two extra rolls because Divine Protection is relatively low on proc-chance.
	divine_protection_rolls += list(src, src, src)

	return NONE

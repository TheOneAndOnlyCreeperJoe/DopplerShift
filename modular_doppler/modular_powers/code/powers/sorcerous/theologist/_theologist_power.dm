/datum/power/theologist
	name = "Theologist Power"
	desc = "We used to call it spells but lets be real here we ditched the spell code for our own snowflake action-code a while ago. The spells system hasn't called in years; its time to let her go. \
	Also tell a developer you're seeing this when you read this; this isn't meant for your eyes. Shoo!"

	archetype = POWER_ARCHETYPE_SORCEROUS
	path = POWER_PATH_THEOLOGIST
	priority = POWER_PRIORITY_BASIC
	magic_flags = POWER_MAGIC_STANDARD
	abstract_parent_type = /datum/power/theologist

/// Determines whether a living mob is considered unholy by Theologist powers.
/datum/power/theologist/proc/is_unholy(mob/living/target)
	if(is_type_in_typecache(target, GLOB.unholy_mobs))
		return TRUE
	// Powers can deem any living creature unholy, including non-carbon mobs.
	if(HAS_TRAIT(target, TRAIT_DEEMED_UNHOLY))
		return TRUE
	// Being undead is VERY unholy!
	if(target.mob_biotypes & MOB_UNDEAD)
		return TRUE
	if(!iscarbon(target))
		return FALSE
	/// Anyone that has the evil trait (some quirks) or a cultist halo.
	if(HAS_TRAIT(target, TRAIT_EVIL) || HAS_TRAIT(target, TRAIT_CULT_HALO))
		return TRUE
	/// Heretic aura/robes because god forbid Heretic has a trait that shows when they have an aura.
	var/datum/antagonist/heretic/heretic_datum = target.mind?.has_antag_datum(/datum/antagonist/heretic)
	if(heretic_datum && (HAS_TRAIT(target, TRAIT_HERETIC_AURA_HIDDEN) || heretic_datum.should_show_aura()))
		return TRUE

	/// CONGRATULATIONS, YOU'RE NOT A BLASPHEMER.
	return FALSE

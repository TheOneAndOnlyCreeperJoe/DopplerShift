/datum/power/thaumaturge
	name = "Thaumaturge Power"
	desc = "Your Clairvoyance spell has succesfully revealed a most terrifying creature; an abstract parent type. Roll a DC18 Will save or become Confused for 1 minute. \
	If you have expert proficeincy in Lore: Programming or are wearing programmer socks; improve your degree of success by one step."

	archetype = POWER_ARCHETYPE_SORCEROUS
	path = POWER_PATH_THAUMATURGE
	priority = POWER_PRIORITY_BASIC
	magic_flags = POWER_MAGIC_STANDARD
	abstract_parent_type = /datum/power/thaumaturge

	/// Thaumaturge component tied to this action's owner. Used for mechanics settings.
	var/datum/component/thaumaturge/thaumaturge_component

/// Checks if we have our referenced thaumaturge component for mechanics/display behavior.
/datum/power/thaumaturge/proc/ValidateThaumaturgeComponent()
	if(power_holder && !thaumaturge_component)
		thaumaturge_component = power_holder.GetComponent(/datum/component/thaumaturge)
	if(!thaumaturge_component)
		return FALSE
	return thaumaturge_component

/*
	Affinity system stuff here. Dress like a mage, get bonuses.
*/
/// Gets and reutrns a mob's current highest affinity number.
/datum/power/thaumaturge/proc/get_affinity(mob/living/user)
	ValidateThaumaturgeComponent()
	var/highest_affinity = 0

	// If the root power benefits from dressing like a wizard.
	if(thaumaturge_component?.affinity_benefits_from_items)
		// Checks if you're wearing items with affinity. This has to be clothing; wearing your staff does not count.
		var/list/equipped_items = user.get_equipped_items()
		for(var/obj/item/equipped_item as anything in equipped_items)
			if(!equipped_item)
				continue
			if(!istype(equipped_item, /obj/item/clothing) && !equipped_item.affinity_worn_override)
				continue

			if(equipped_item.affinity > highest_affinity)
				highest_affinity = equipped_item.affinity

		// Checks if you're holding items with affinity.
		for(var/obj/item/held_item as anything in user.held_items)
			if(!held_item)
				continue

			// Holding clothing or worn-override items shouldn't contribute.
			if(istype(held_item, /obj/item/clothing) || held_item.affinity_worn_override)
				continue

			if(held_item.affinity > highest_affinity)
				highest_affinity = held_item.affinity

	// Seed affinity and let external listeners influence affinity.
	// Generally speaking you should only add and subtract to this number.
	SEND_SIGNAL(user, COMSIG_THAUMATURGE_AFFINITY_QUERY, src)
	return max(0, highest_affinity)

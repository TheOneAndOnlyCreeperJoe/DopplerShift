/*
* Present a valuable item at the Chapel's Altar of the Gods.
*/
/datum/ceremonial_objective/offering
	abstract_type = /datum/ceremonial_objective/offering

	/// Altars this objective listens to for item interactions.
	var/list/obj/structure/altar/of_gods/registered_altars = list()

/// Registers item-use listeners on every Chapel altar currently present.
/datum/ceremonial_objective/offering/New(datum/power/theologist/ceremony/new_ceremony_power)
	. = ..()
	for(var/obj/structure/altar/of_gods/altar as anything in GLOB.chaplain_altars)
		if(!ceremony_power?.is_inside_chapel(altar))
			continue
		RegisterSignal(altar, COMSIG_ATOM_ATTACKBY, PROC_REF(on_altar_item_used))
		registered_altars += altar

/// Removes item-use listeners from every altar registered to this objective.
/datum/ceremonial_objective/offering/Destroy()
	for(var/obj/structure/altar/of_gods/altar as anything in registered_altars)
		UnregisterSignal(altar, COMSIG_ATOM_ATTACKBY)
	return ..()

/// Checks whether an item fulfills this offering's requirements.
/datum/ceremonial_objective/offering/proc/is_valid_offering(obj/item/offered_item)
	return FALSE

/// Completes this objective when its holder uses a valid offering on a Chapel altar.
/datum/ceremonial_objective/offering/proc/on_altar_item_used(obj/structure/altar/of_gods/source, obj/item/offered_item, mob/living/user, list/modifiers)
	SIGNAL_HANDLER

	if(completed || user != holder || !ceremony_power?.is_inside_chapel(source))
		return
	if(is_valid_offering(offered_item))
		complete()

/*
* Offer considerable monetary wealth.
*/
/datum/ceremonial_objective/offering/wealth
	name = "Offering of Wealth"

	/// The credit value the offering must meet or exceed.
	var/required_credits

/// Sets the required offering value from the holder's assigned job salary.
/datum/ceremonial_objective/offering/wealth/New(datum/power/theologist/ceremony/new_ceremony_power)
	. = ..()
	var/datum/job/holder_job = holder?.mind?.assigned_role
	required_credits = holder_job?.paycheck * 10
	description = "Offer at least [required_credits] credits at the Chapel altar."

/// Returns whether an item has enough monetary value for this offering.
/datum/ceremonial_objective/offering/wealth/is_valid_offering(obj/item/offered_item)
	return offered_item.get_item_credit_value() >= required_credits

/*
* Offer a precious forged weapon.
*/
/datum/ceremonial_objective/offering/armaments
	name = "Offering of Armaments"
	/// The forged weapon type required for this offering.
	var/obj/item/required_weapon_type
	/// The material required for the forged weapon.
	var/datum/material/required_material_type

/// Selects a forged weapon type and a precious material for this offering.
/datum/ceremonial_objective/offering/armaments/New(datum/power/theologist/ceremony/new_ceremony_power)
	. = ..()
	required_weapon_type = pick(subtypesof(/obj/item/forging/reagent_weapon))
	required_material_type = pick(/datum/material/silver, /datum/material/gold)
	description = "Offer a [initial(required_material_type.name)] [initial(required_weapon_type.name)] at the Chapel altar."

/// Returns whether an item is the selected forged weapon made from the selected material.
/datum/ceremonial_objective/offering/armaments/is_valid_offering(obj/item/offered_item)
	if(!istype(offered_item, required_weapon_type))
		return FALSE
	return offered_item.custom_materials?[GET_MATERIAL_REF(required_material_type)]

/datum/quirk/item_quirk/breather/nitrogen_breather
	name = "Nitrogen Breather"
	desc = "You breathe nitrogen, even if you might not normally breathe it. Oxygen is poisonous."
	medical_record_text = "Patient can only breathe nitrogen."
	gain_text = "<span class='danger'>You suddenly have a hard time breathing anything but nitrogen."
	lose_text = "<span class='notice'>You suddenly feel like you aren't bound to nitrogen anymore."
	value = 0
	breath_type = "nitrogen"

/datum/quirk/item_quirk/breather/nitrogen_breather/add_unique(client/client_source)
	. = ..()
	if(!.)
		return

	var/obj/item/organ/lungs/target_lungs = quirk_holder.get_organ_slot(ORGAN_SLOT_LUNGS)
	var/obj/item/clothing/accessory/breathing/target_tag = new(get_turf(quirk_holder))
	target_tag.breath_type = breath_type

	give_item_to_holder(target_tag, list(LOCATION_LPOCKET, LOCATION_RPOCKET, LOCATION_BACKPACK,	LOCATION_HANDS))
	give_item_to_holder(/obj/item/tank/internals/nitrogen/belt/full, list(LOCATION_LPOCKET, LOCATION_RPOCKET, LOCATION_BACKPACK, LOCATION_HANDS))

	// set lung vars
	target_lungs.safe_oxygen_min = 0 //Dont need oxygen
	target_lungs.safe_oxygen_max = 2 //But it is quite toxic
	target_lungs.safe_nitro_min = 10 // Atleast 10 nitrogen
	target_lungs.oxy_damage_type = TOX
	target_lungs.oxy_breath_dam_min = 6
	target_lungs.oxy_breath_dam_max = 20
	// update lung procs
	target_lungs.breathe_always = list(/datum/gas/nitrogen = "breathe_nitro")
	target_lungs.breath_present += list(/datum/gas/oxygen = "too_much_oxygen")
	target_lungs.breath_lost += list(/datum/gas/oxygen = "safe_oxygen")
	// reflect correct lung flags
	target_lungs.respiration_type = RESPIRATION_N2

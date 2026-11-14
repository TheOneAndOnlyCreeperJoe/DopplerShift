/*
	General design ethos:
	- Anything that flavorwise is holy should be on here.
	- Behaviour should be consistent across the old and new item, so things like stored reagents, fuel, etc. should transfer over into the new, e.g holymelons
	- Null rods SHOULD be extremely expensive scaling with how convenient they are, since the magic immunity is the bigger schtick here.
		- If its bulky/huge then you can get away 25.
		- If its normal or smaller with conditional magic immunity such as the holyboard then 25 is fine.
		- If its normal or smaller, or fits on 'convenient' slots like the belt as a bulky or above, it should be 50.
*/

/// Book -> Bible
/datum/hallow_conversion/object/book
	base_types = list(/obj/item/book)
	result_type = /obj/item/book/bible
	cost = THEOLOGIST_PIETY_TRIVIAL * 4
	hallow_message = "The pages reorder themselves into a bible."

/// Plain Cake -> Angel Food Cake
/datum/hallow_conversion/object/cake
	base_types = list(/obj/item/food/cake/plain)
	result_type = /obj/item/food/cake/holy_cake
	cost = THEOLOGIST_PIETY_TRIVIAL * 4
	hallow_message = "The cake becomes a heavenly angel food cake."

/// Skateboard -> Holyboard
/datum/hallow_conversion/object/skateboard
	base_types = list(/obj/item/melee/skateboard)
	result_type = /obj/item/melee/skateboard/holyboard
	cost = THEOLOGIST_PIETY_MAJOR
	hallow_message = "The board hums and becomes a holy skateboard."

/// Bow -> Holy Bow
/datum/hallow_conversion/object/bow
	base_types = list(/obj/item/gun/ballistic/bow)
	result_type = /obj/item/gun/ballistic/bow/divine
	cost = THEOLOGIST_PIETY_MAJOR
	hallow_message = "The bow brightens, reshaping into a divine bow."

/// Arrow -> Holy Arrow
/datum/hallow_conversion/object/arrow
	base_types = list(/obj/item/ammo_casing/arrow)
	result_type = /obj/item/ammo_casing/arrow/holy
	cost = THEOLOGIST_PIETY_TRIVIAL * 2
	hallow_message = "The arrow brightens with holy light."

/// Forged Sword / Claymore -> Holy Claymore
/// The claymore uniquely gets its damage preserved.
/datum/hallow_conversion/object/sword
	base_types = list(/obj/item/claymore, /obj/item/forging/reagent_weapon/sword)
	result_type = /obj/item/nullrod/claymore
	cost = THEOLOGIST_PIETY_CRUSHING // fits on belt so it gets the mark-up
	hallow_message = "The hilt on the blade becomes a radiant gold!"

/datum/hallow_conversion/object/sword/replace_target(atom/target, typepath)
	var/stored_force
	if(istype(target, /obj/item/claymore))
		var/obj/item/claymore/the_best_thing_to_come_from_scottland = target
		stored_force = the_best_thing_to_come_from_scottland.force
	. = ..()
	if(istype(., /obj/item/nullrod/claymore))
		var/obj/item/claymore/scotland_forever = .
		scotland_forever.force = stored_force
	return .

/// Forged Spear -> Ancient Spear
/datum/hallow_conversion/object/spear
	base_types = list(/obj/item/forging/reagent_weapon/spear)
	result_type = /obj/item/nullrod/spear
	cost = THEOLOGIST_PIETY_CRUSHING // fits on belt so it gets the mark-up
	hallow_message = "The spear turns to shimmering brass!"

/// Forged Hammer -> Relic War Hammer
/datum/hallow_conversion/object/hammer
	base_types = list(/obj/item/forging/reagent_weapon/hammer)
	result_type = /obj/item/nullrod/hammer
	cost = THEOLOGIST_PIETY_CRUSHING // fits on belt so it gets the mark-up
	hallow_message = "The hammer turns into an ancient weapon!"

/// Thaumaturge staff/Reagent staves -> Holy staves
/datum/hallow_conversion/object/thaumaturge_staff
	base_types = list(/obj/item/spell_focus/staff, /obj/item/forging/reagent_weapon/staff)
	result_type = /obj/item/nullrod/staff/blue
	cost = THEOLOGIST_PIETY_MAJOR
	hallow_message = "The staff's orb begins to glow!"

/// Scythe -> Sinister Shard
/datum/hallow_conversion/object/scythe
	base_types = list(/obj/item/scythe)
	result_type = /obj/item/organ/cyberimp/arm/toolkit/shard/scythe
	cost = THEOLOGIST_PIETY_CRUSHING // really edgy and stored in like, the VOID or something
	hallow_message = "The scythe turns into an ominous shard!"

/*
	Soulstones
*/

/datum/hallow_conversion/object/soulstone
	base_types = list(/obj/item/soulstone)
	cost = THEOLOGIST_PIETY_MINOR
	hallow_message = "The soulstone's glow becomes serene."

/datum/hallow_conversion/object/soulstone/can_hallow(atom/target)
	if(!..())
		return FALSE
	var/obj/item/soulstone/soulstone = target
	return soulstone.theme != THEME_HOLY

/datum/hallow_conversion/object/soulstone/hallow(mob/living/user, atom/target)
	var/obj/item/soulstone/soulstone = target
	soulstone.required_role = null
	soulstone.theme = THEME_HOLY
	soulstone.update_appearance()
	for(var/mob/shade_to_deconvert in soulstone.contents)
		soulstone.assign_master(shade_to_deconvert, user)
	UnregisterSignal(soulstone, COMSIG_BIBLE_SMACKED)
	to_chat(user, span_notice(hallow_message))
	return TRUE

/*
	Water melons & water melon seeds
*/

/// Copies mutable seed attributes to a replacement seed.
/datum/hallow_conversion/object/proc/copy_seed_stats(obj/item/seeds/from_seed, obj/item/seeds/to_seed)
	to_seed.lifespan = from_seed.lifespan
	to_seed.endurance = from_seed.endurance
	to_seed.maturation = from_seed.maturation
	to_seed.production = from_seed.production
	to_seed.yield = from_seed.yield
	to_seed.potency = from_seed.potency
	to_seed.instability = from_seed.instability
	to_seed.weed_rate = from_seed.weed_rate
	to_seed.weed_chance = from_seed.weed_chance

/datum/hallow_conversion/object/watermelon_seeds
	base_types = list(/obj/item/seeds/watermelon)
	result_type = /obj/item/seeds/watermelon/holy
	cost = THEOLOGIST_PIETY_MINOR
	hallow_message = "Divine light transforms the watermelon seeds into holymelon seeds."

/datum/hallow_conversion/object/watermelon_seeds/hallow(mob/living/user, atom/target)
	var/obj/item/seeds/watermelon/old_seed = target
	var/obj/item/seeds/watermelon/holy/new_seed = replace_target(old_seed, result_type)
	if(!new_seed)
		return FALSE
	copy_seed_stats(old_seed, new_seed)
	to_chat(user, span_notice(hallow_message))
	return TRUE

/datum/hallow_conversion/object/watermelon
	base_types = list(/obj/item/food/grown/watermelon)
	result_type = /obj/item/food/grown/holymelon
	cost = THEOLOGIST_PIETY_MINOR
	hallow_message = "Divine light transforms the watermelon into a holymelon."

/datum/hallow_conversion/object/watermelon/hallow(mob/living/user, atom/target)
	var/obj/item/food/grown/watermelon/melon = target
	var/obj/item/seeds/old_seed = melon.get_plant_seed()
	var/obj/item/food/grown/holymelon/new_melon = replace_target(melon, result_type)
	if(!new_melon)
		return FALSE
	if(old_seed)
		var/obj/item/seeds/new_seed = new /obj/item/seeds/watermelon/holy(null)
		copy_seed_stats(old_seed, new_seed)
		new_melon.seed = new_seed
	to_chat(user, span_notice(hallow_message))
	return TRUE

/// Iron Sheets -> Silver Sheets
/datum/hallow_conversion/object/stack/iron_to_silver
	base_types = list(/obj/item/stack/sheet/iron)
	result_type = /obj/item/stack/sheet/mineral/silver
	cost = THEOLOGIST_PIETY_TRIVIAL
	hallow_message = "The iron sheets brighten into shining silver."

/// Cult Sheets -> Iron Sheets
/datum/hallow_conversion/object/stack/runed_to_iron
	base_types = list(/obj/item/stack/sheet/runed_metal)
	result_type = /obj/item/stack/sheet/iron
	cost = 0 // Undoing evil is a good thing
	hallow_message = "The cult symbols fade away."

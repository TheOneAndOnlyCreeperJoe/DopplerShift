/datum/pathology_shop
	// Our current listing of stock, made through cycle_stock()
	var/list/shop_stock = list()
	// The last time we had our stock cycled.
	var/last_rotation

/datum/pathology_shop/New()
	. = ..()
	last_rotation = world.time
	START_PROCESSING(SSobj, src)
	cycle_stock()

/datum/pathology_shop/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

/datum/pathology_shop/proc/cycle_stock()
	shop_stock.Cut()
	for(var/item in typesof(/datum/pathology_shop_item))
		if(item == /datum/pathology_shop_item)
			continue
		shop_stock += new item()

/datum/pathology_shop/proc/get_stock()
	return shop_stock

/datum/pathology_shop/process(seconds_per_tick)
	. = ..()
	if((last_rotation+(10 MINUTES)) < world.time)
		last_rotation = world.time
		cycle_stock()
	return 0

/*
	CATEGORIES
	Essentials
	- Monkey Cubes
	- Handcuffs
	- Cash
	- Virology Minerals Crate (Contains 5 Uranium, 5 Gold and 10 Plasma)
	Chemicals
	- Spaceaccilin Syringes
	- Formaldehyde Bottle
	- Synaptizine Bottle

	THIS IS ALL A PLACEHOLDER FOR NOW

	Currently filled with placeholders but I want the following stuff in stock eventually:
	STATIC:
	- Monkey Cubes
	- Handcuffs
	- CASH
	- Spaceaccalin Syringes
	- Formaldehyde + Synaptizine
	- Virus Chems
	ROTATING:
	- Injectors with symptoms that don't lower stability (must be acquireable through both chem and mutations, so no mutation exclusives or mutation booster symptoms.)
	- Virus Base Bottles (randomly generated list of 3 symptoms vials at 100% stability)
	- Some other fun goodies?
	EMAGGED?:
	- Nanomachines?
	- Special injector to an one of a kind symptom? (Something that automatically makes zombie powder in the person's body on injury, with high stealth?)
*/

/*
	TODO:
	- Shop Rotations. See above.
	- Bounty Board. Slower rotation, and you can pay PP (pathology points) to extend them or immediatelly add a new one (scales with how many there already are). Claimed per person. Can't pick a new one til you finish your current one.
	- Possibly have bounties work like bounty cubes, so you do have to deliver them to cargo, you just get PP instead of cash (cargo still gets budget). Gets you out of your hidey hole.
*/



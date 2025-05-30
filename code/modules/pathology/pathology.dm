// The global shop instance
GLOBAL_VAR_INIT(shared_pathology_shop, null)

/obj/machinery/computer/pathology
	name = "PATH-0-LOGY"
	desc = "Where you deliver your (killer) viruses to for that sweet, sweet cash."
	density = TRUE
	icon = 'icons/obj/medical/chemical.dmi'
	icon_state = "genesploicer0"
	icon_keyboard = null
	icon_screen = null
	base_icon_state = "genesploicer0"
	resistance_flags = ACID_PROOF
	var/datum/pathology_shop/shop // the shop we're connected to, gets connected at new()
	var/unique_shop = FALSE // determines if it gets the standard shop that everyones shares or their own instance of a shop.
	circuit = /obj/item/circuitboard/computer/pathology

	///The inserted beaker
	var/obj/item/reagent_containers/beaker

/obj/machinery/computer/pathology/unique_shop // for when you want your syndicates and the like not to compete with the station for shop contents.
	unique_shop = TRUE

/obj/machinery/computer/pathology/New()
	. = ..()
	// We don't want you to be able to create multiple pathology machines just to get different shop.
	if(unique_shop)
		shop = new /datum/pathology_shop
	else
		if(!GLOB.shared_pathology_shop)
			GLOB.shared_pathology_shop = new /datum/pathology_shop
		shop = GLOB.shared_pathology_shop

/obj/machinery/computer/pathology/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "Pathology", name)
		ui.open()

// Maths for the timer component in the TGUI. Yes, it is gross.
/obj/machinery/computer/pathology/proc/calculate_time()
	var/timeleft = max((shop.last_rotation + 10 MINUTES) - world.time, 0)
	var/minutes = floor(timeleft / 600)
	var/seconds = floor((timeleft % 600) / 10)
	var/minstr = (minutes < 10) ? "0[minutes]" : "[minutes]"
	var/secstr = (seconds < 10) ? "0[seconds]" : "[seconds]"

	return "[minstr]:[secstr]"

/obj/machinery/computer/pathology/ui_data(mob/user)
	var/list/data = list()
	var/list/stock = shop.get_stock()
	data["time"] = calculate_time()

  // shamelessly stolen from smartfridges
	var/listofitems = list()
	for(var/datum/pathology_shop_item/item in stock)
		var/atom/movable/atom = item.item
		if(!QDELETED(atom))
			var/key = "[item.type]"
			if (listofitems[key])
				listofitems[key]["amount"]++
			else
				listofitems[key] = list(
					"key" = key,
					"name" = full_capitalize(item.name),
					"desc" = item.desc,
					"specialtext" = item.specialtext,
					"icon" = atom.icon,
					"icon_state" = atom.icon_state,
					"amount" = 1,
					"cost" = item.cost,
					"category" = item.category
					)
	data["contents"] = sort_list(listofitems)
	return data

/obj/machinery/computer/pathology/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(..())
		return
	switch(action)
		if("test")
			playsound(src, 'sound/items/bikehorn.ogg', 100, FALSE)
		if("buy")
			var/key = params["key"]
			var/cost = params["cost"]
			var/mob/living/living_user
			var/obj/item/card/id/card_used

			var/datum/pathology_shop_item/selected // because we instance our shop items we actually need to select that specific one, in the case of for example virus bottels.
			for(var/datum/pathology_shop_item/item in shop.get_stock())
				if("[item.type]" == key)
					selected = item
					break

			if(isliving(usr)) // We don't serve ghosts
				living_user = usr
				card_used = living_user.get_idcard(TRUE)
				if(purchase_item(key, cost, card_used))
					spawn_purchased(selected)

	update_icon() // Not applicable to all objects.

/obj/machinery/computer/pathology/proc/purchase_item(path, cost, obj/item/card/id/card)
	if(cost <= card.registered_account.pathology_points)
		card.registered_account.pathology_points -= cost
		return TRUE
	say("Sorry, but you do not have enough pathology points!")
	return FALSE

/obj/machinery/computer/pathology/proc/spawn_purchased(var/datum/pathology_shop_item/purchased)
	// Since our shop has a rotating store of procedurely generated symptoms and viruses, we have to handle item spawning in an unique way for some categories.

	// Virus bottle spawning.
	if(istype(purchased, /datum/pathology_shop_item/virusbottle))
		var/datum/disease/advance/adv_disease = purchased.virus
		var/obj/item/reagent_containers/cup/bottle/bottle = new(drop_location())
		var/list/data = list("viruses" = list(adv_disease))
		bottle.name = "[adv_disease.name] virus tube"
		bottle.desc = "[adv_disease.desc]"
		bottle.reagents.add_reagent(/datum/reagent/blood, 20, data)
	// Symptom inducer spawning
	else if(istype(purchased, /datum/pathology_shop_item/symptominducer))
		var/datum/symptom/symptom = purchased.symptom
		var/obj/item/reagent_containers/syringe/syringe = new(drop_location())
		var/list/data = list("symptom" = symptom)
		syringe.name = "syringe ([symptom.name] symptom inducer)"
		syringe.desc = "A syringe filled with Stabilized Symptom Fluid, allowing for transfer of symptoms without compromising disease stability. Requires special machinery to manufacture."
		syringe.reagents.add_reagent(/datum/reagent/ssf, 1, data)
	// Everything else spawning
	else
		new purchased(drop_location())


/datum/pathology_shop_item
	var/name // name, leave blank to use obj name.
	var/desc // desc, leave blank to use obj desc.
	var/specialtext // special text that appears under the name of the object.
	var/atom/item // item in question
	var/cost // item cost in PP
	var/category // what category it's sorted under
	var/virustier // the virus tier that's attached to it in case of virus bottles
	var/datum/disease/advance/virus // the actual rolled virus that is in the bottle, in the case of virus bottles.
	var/symptomlevel // the level for the symptoms in this syringe
	var/datum/symptom/symptom // the sympton that's attached to it in case of sympton injector

/datum/pathology_shop_item/New()
	. = ..()
	if(!name)
		name = initial(item.name)
	if(!desc)
		desc = initial(item.desc)

/datum/pathology_shop_item/proc/cycle_contents()
	return

// The Essentials Stock. Doesn't rotate, contains standard useful items.
/datum/pathology_shop_item/essentials/monkeycubes
	item = /obj/item/storage/box/monkeycubes
	cost = 10
	category = "essentials"

/datum/pathology_shop_item/essentials/handcuffs
	item = /obj/item/restraints/handcuffs
	cost = 10
	category = "essentials"

/datum/pathology_shop_item/essentials/spacecash
	item = /obj/item/stack/spacecash/c1000
	cost = 150
	category = "essentials"

/datum/pathology_shop_item/essentials/mineralcrate
	item = /obj/structure/closet/crate
	cost = 150
	category = "essentials"

// The Chemicals Stock. Doesn't rotate, contains useful chems if you don't want to make em yourself.
/datum/pathology_shop_item/chem/antiviral
	item = /obj/item/reagent_containers/syringe/antiviral
	cost = 20
	category = "chemicals"

/datum/pathology_shop_item/chem/formaldehyde
	item = /obj/item/reagent_containers/cup/bottle/formaldehyde
	cost = 20
	category = "chemicals"

/datum/pathology_shop_item/chem/synaptizine
	item = /obj/item/reagent_containers/cup/bottle/synaptizine
	cost = 20
	category = "chemicals"

// The Virus Bottle stock. Doesn't actually rotate the bottles itself; merely the viruses within it.
/datum/pathology_shop_item/virusbottle
	name = "Level 1-2 Pathology Virus"
	desc = "A fully stabilized virus, useful to act as a base for your existing virus."
	item = /obj/item/reagent_containers/cup/bottle
	cost = 75
	category = "virusbottles"
	virustier = /datum/disease/advance/pathology/t1

/datum/pathology_shop_item/virusbottle/New()
	. = ..()
	roll_virus()

/datum/pathology_shop_item/virusbottle/proc/roll_virus()
	virus = new virustier()
	// I keep getting list out of bounds errors with other solutions, so we're doing things a little scuffed.
	for(var/datum/symptom/S in virus.symptoms)
		specialtext += "[S.name] | "
	if(length(specialtext) > 0)
		specialtext = copytext(specialtext, 1, length(specialtext) - 2)

/datum/pathology_shop_item/virusbottle/cycle_contents()
	roll_virus()

/datum/pathology_shop_item/virusbottle/t2
	name = "Level 3-4 Pathology Virus"
	cost = 150
	virustier = /datum/disease/advance/pathology/t2

/datum/pathology_shop_item/virusbottle/t3
	name = "Level 5-6 Pathology Virus"
	cost = 225
	virustier = /datum/disease/advance/pathology/t3

/datum/pathology_shop_item/virusbottle/t4
	name = "Level 7-8 Pathology Virus"
	cost = 300
	virustier = /datum/disease/advance/pathology/t4

/datum/pathology_shop_item/virusbottle/t1t2
	name = "Level 1-4 Pathology Virus"
	cost = 175
	virustier = /datum/disease/advance/pathology/t1t2

/datum/pathology_shop_item/virusbottle/t2t3
	name = "Level 3-6 Pathology Virus"
	cost = 250
	virustier = /datum/disease/advance/pathology/t2t3

/datum/pathology_shop_item/virusbottle/t3t4
	name = "Level 5-8 Pathology Virus"
	cost = 325
	virustier = /datum/disease/advance/pathology/t3t4

// Symptom Injectors; uses Stabilized Symptom Fluid to add specific symptoms your stuff without incuring stability loss.
/datum/pathology_shop_item/symptominducer
	name = "Level 1 Symptom Inducer"
	desc = "A syringe filled with a single unit of Stabilized Symptom Fluid, allowing you to add a symptom to a virus without incuring stability penalties."
	item = /obj/item/reagent_containers/syringe
	cost = 75
	category = "symptominducers"
	symptomlevel = 1

/datum/pathology_shop_item/symptominducer/New()
	. = ..()
	roll_symptom()

/datum/pathology_shop_item/symptominducer/proc/roll_symptom()
	var/list/possible_symptoms = list()
	for(var/symp in SSdisease.list_symptoms)
		var/datum/symptom/S = new symp
		if(S.can_generate_randomly() && S.level >= symptomlevel && S.level <= symptomlevel)
			possible_symptoms += S
	symptom = pick_n_take(possible_symptoms)
	specialtext = "[symptom.name]"

/datum/pathology_shop_item/symptominducer/cycle_contents()
	roll_symptom()

/datum/pathology_shop_item/symptominducer/l2
	name = "Level 2 Symptom Inducer"
	cost = 100
	symptomlevel = 2

/datum/pathology_shop_item/symptominducer/l3
	name = "Level 3 Symptom Inducer"
	cost = 125
	symptomlevel = 3

/datum/pathology_shop_item/symptominducer/l4
	name = "Level 4 Symptom Inducer"
	cost = 150
	symptomlevel = 4

/datum/pathology_shop_item/symptominducer/l5
	name = "Level 5 Symptom Inducer"
	cost = 200
	symptomlevel = 5

/datum/pathology_shop_item/symptominducer/l6
	name = "Level 6 Symptom Inducer"
	cost = 250
	symptomlevel = 6

/datum/pathology_shop_item/symptominducer/l7
	name = "Level 7 Symptom Inducer"
	cost = 350
	symptomlevel = 7

/datum/pathology_shop_item/symptominducer/l8
	name = "Level 8 Symptom Inducer"
	cost = 500
	symptomlevel = 8

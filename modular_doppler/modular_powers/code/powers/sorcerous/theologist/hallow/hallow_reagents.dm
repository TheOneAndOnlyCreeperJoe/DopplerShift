/// Remember to compare price to reagents_per_cost and add to reagents_converted

/// (Unholy) Water -> Holy Water
/datum/hallow_conversion/reagent/holywater
	base_types = list(/datum/reagent/water, /datum/reagent/fuel/unholywater)
	result_type = /datum/reagent/water/holywater
	/// 0.5 piety per 10 (costs still floor).
	cost = THEOLOGIST_PIETY_TRIVIAL
	hallow_message = "The water turns a brilliant white!"

/// Blood -> Godsblood
/datum/hallow_conversion/reagent/godblood
	base_types = list(/datum/reagent/blood)
	result_type = /datum/reagent/medicine/omnizine/godblood
	/// 3 piety per 10.
	cost = THEOLOGIST_PIETY_TRIVIAL * 6
	hallow_message = "The blood is hallowed into godsblood."

/// Iron -> Silver
/datum/hallow_conversion/reagent/iron_to_silver
	base_types = list(/datum/reagent/iron)
	result_type = /datum/reagent/silver
	/// 0.5 piety per 20 units. This should match the iron to silver stack conversion.
	cost = THEOLOGIST_PIETY_TRIVIAL
	reagents_per_cost = 20
	hallow_message = "The iron gleams into silver."

/// Fishy Reagent -> Strange Reagent
/datum/hallow_conversion/reagent/fishy_to_strange_reagent
	base_types = list(/datum/reagent/medicine/strange_reagent/fishy_reagent)
	result_type = /datum/reagent/medicine/strange_reagent
	/// 1 piety per 10.
	cost = THEOLOGIST_PIETY_TRIVIAL * 2
	hallow_message = "The substance loses its fishy smell."

/// Colorful Reagent - > Strange Reagent
/datum/hallow_conversion/reagent/colorful_to_strange_reagent
	base_types = list(/datum/reagent/colorful_reagent)
	result_type = /datum/reagent/medicine/strange_reagent
	/// 3 piety per 10.
	cost = THEOLOGIST_PIETY_TRIVIAL * 6
	hallow_message = "All the pretty colors turn to lime!"

/// Beer -> Trappist Beer
/datum/hallow_conversion/reagent/trappist_beer
	base_types = list(/datum/reagent/consumable/ethanol/beer)
	result_type = /datum/reagent/consumable/ethanol/trappist
	/// no cost since this is just aura farming
	cost = 0
	hallow_message = "The beer turns into holy beer. Wow?"

/*
* Perform a particular Hallow conversion (several times))
*/
/datum/ceremonial_objective/hallow
	required_powers = list(/datum/power/theologist/hallow)

	/// The Hallow conversion this objective tracks.
	var/datum/hallow_conversion/recipe
	/// The number of matching conversions completed so far.
	var/conversions_completed = 0
	/// The number of matching conversions needed to complete this objective.
	var/conversions_required = 1

/// Chooses an eligible Hallow recipe and registers its Hallow action listener.
/datum/ceremonial_objective/hallow/New(datum/power/theologist/ceremony/new_ceremony_power)
	. = ..()
	select_recipe()
	var/datum/power/theologist/hallow/hallow_power = holder?.get_power(/datum/power/theologist/hallow)
	var/datum/action/cooldown/power/theologist/hallow/hallow_action = hallow_power?.action_path
	if(hallow_action)
		RegisterSignal(hallow_action, COMSIG_THEOLOGIST_HALLOW_CONVERSION, PROC_REF(on_hallow_conversion))

/// Removes this objective's Hallow action listener.
/datum/ceremonial_objective/hallow/Destroy()
	var/datum/power/theologist/hallow/hallow_power = holder?.get_power(/datum/power/theologist/hallow)
	var/datum/action/cooldown/power/theologist/hallow/hallow_action = hallow_power?.action_path
	if(hallow_action)
		UnregisterSignal(hallow_action, COMSIG_THEOLOGIST_HALLOW_CONVERSION)
	return ..()

/// Selects a random Hallow conversion.
/// It can cost no more than 25 piety, and you must produce 25 Piety worth.
/datum/ceremonial_objective/hallow/proc/select_recipe()
	var/list/eligible_recipe_types = list()
	for(var/datum/hallow_conversion/recipe_type as anything in subtypesof(/datum/hallow_conversion))
		if(initial(recipe_type.abstract_type) == recipe_type)
			continue
		if(!ispath(recipe_type, /datum/hallow_conversion/reagent) && !ispath(recipe_type, /datum/hallow_conversion/object))
			continue
		var/recipe_cost = initial(recipe_type.cost)
		var/recipe_result = initial(recipe_type.result_type)
		if(!recipe_cost || recipe_cost > 25 || !recipe_result)
			continue
		eligible_recipe_types += recipe_type

	if(!eligible_recipe_types.len)
		return

	var/datum/hallow_conversion/chosen_recipe = pick(eligible_recipe_types)
	recipe = new chosen_recipe
	conversions_required = max(1, round(25 / recipe.cost))
	var/conversion_count_text = conversions_required == 1 ? "time" : "times"
	var/original_name
	var/result_name
	/// Reagent conversion
	if(istype(recipe, /datum/hallow_conversion/reagent))
		var/datum/hallow_conversion/reagent/reagent_recipe = recipe
		var/datum/reagent/original_reagent = reagent_recipe.base_types[1]
		var/datum/reagent/result_reagent = reagent_recipe.result_type
		original_name = initial(original_reagent.name)
		result_name = initial(result_reagent.name)
	else
		var/datum/hallow_conversion/object/object_recipe = recipe
		var/obj/original_object = object_recipe.base_types[1]
		var/obj/result_object = object_recipe.result_type
		original_name = initial(original_object.name)
		result_name = initial(result_object.name)
	name = "Hallow [original_name]"
	description = "Convert [original_name] into [result_name] [conversions_required] [conversion_count_text] using Hallow."

/// Tracks successful conversions made with this objective's selected Hallow recipe.
/datum/ceremonial_objective/hallow/proc/on_hallow_conversion(datum/source, datum/hallow_conversion/completed_recipe, piety_cost)
	SIGNAL_HANDLER

	if(completed || completed_recipe.type != recipe?.type)
		return
	conversions_completed++
	if(conversions_completed >= conversions_required)
		complete()
	SStgui.update_uis(ceremony_power)

/// Returns Hallow conversion progress for the ceremonial objectives interface.
/datum/ceremonial_objective/hallow/get_progress_text()
	return "Conversions completed: [conversions_completed] / [conversions_required]."

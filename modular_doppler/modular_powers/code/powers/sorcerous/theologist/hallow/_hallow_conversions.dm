/// Datums which dictate when, why and how Hallow can convert something.
/datum/hallow_conversion
	/// Typepath used to mark this datum as an abstract type
	abstract_type = /datum/hallow_conversion
	/// Type paths this conversion accepts as input.
	var/list/base_types = list()
	/// The resulting typepath after conversion.
	var/result_type
	/// Piety cost for a conversion. Reagent conversions scale this against reagents_per_cost.
	var/cost = 0
	/// Feedback shown to the user after a successful conversion.
	var/hallow_message
	/// Additional examine information shown for a direct target conversion.
	var/examine_extra_text

/// Returns whether this conversion can currently affect a target.
/// Validation goes here.
/datum/hallow_conversion/proc/can_hallow(atom/target)
	return !result_type || !istype(target, result_type) // no self-conversions its silly

/// Applies the conversion to a target.
/// The actual item conversion goes here.
/datum/hallow_conversion/proc/hallow(mob/living/user, atom/target)
	return FALSE

/// Attempts a conversion and returns its calculated piety cost on success.
/// Returns null on failure so zero-cost conversions remain successful.
/datum/hallow_conversion/proc/try_hallow(mob/living/user, atom/target)
	if(!can_hallow(target))
		return null
	if(!hallow(user, target))
		return null
	return cost_calc()

/// Calculates this conversion's piety cost, optionally using an overridden conversion amount.
/datum/hallow_conversion/proc/cost_calc(amount = cost)
	// Piety does not display or use decimals, so costs round upward to a whole value.
	return CEILING(amount, 1)

/// Replaces an object whilst preserving its location, whether it be in-hand or on the ground.
/datum/hallow_conversion/proc/replace_target(atom/target, typepath)
	if(!target || !typepath)
		return null

	var/obj/old_object = target
	var/mob/living/holder
	var/hand_index = 0
	if(istype(old_object, /obj/item) && ismob(old_object.loc))
		holder = old_object.loc
		hand_index = holder.get_held_index_of_item(old_object)

	var/obj/new_object
	if(hand_index && holder)
		new_object = new typepath(null)
		holder.put_in_hand(new_object, hand_index, forced = TRUE)
	else
		new_object = new typepath(old_object.loc)
	qdel(old_object)
	return new_object

/*
	Object-based conversions, so obj/item
*/

/datum/hallow_conversion/object
	abstract_type = /datum/hallow_conversion/object

/datum/hallow_conversion/object/can_hallow(atom/target)
	return ..() && is_type_in_list(target, base_types)

/datum/hallow_conversion/object/hallow(mob/living/user, atom/target)
	if(!replace_target(target, result_type))
		return FALSE
	if(hallow_message)
		to_chat(user, span_notice(hallow_message))
	return TRUE

/// Base conversion for stacks that preserves their amount.
/datum/hallow_conversion/object/stack
	abstract_type = /datum/hallow_conversion/object/stack
	/// Tracks how many units were converted for cost calculation.
	var/stacks_converted
	/// Number of converted stack units represented by one cost increment.
	var/stacks_per_cost = 1

/// Validates a stack conversion and records the target stack amount for cost calculation.
/datum/hallow_conversion/object/stack/can_hallow(atom/target)
	if(!..())
		return FALSE
	var/obj/item/stack/target_stack = target
	stacks_converted = target_stack.amount
	return TRUE

/// Replaces a stack while preserving its amount and material state.
/datum/hallow_conversion/object/stack/hallow(mob/living/user, atom/target)
	var/obj/item/stack/old_stack = target
	var/stack_amount = old_stack.amount
	var/obj/item/stack/new_stack = replace_target(old_stack, result_type)
	if(!new_stack)
		return FALSE
	new_stack.add(stack_amount - new_stack.amount)
	stacks_converted = stack_amount
	if(hallow_message)
		to_chat(user, span_notice(hallow_message))
	return TRUE

/// Calculates stack conversion costs from an override amount or the amount most recently converted.
/datum/hallow_conversion/object/stack/cost_calc(amount = stacks_converted)
	return CEILING(amount * (cost / stacks_per_cost), 1)

/*
	Reagent-based conversions, so datum/reagent
*/

/datum/hallow_conversion/reagent
	/// Tracks how many reagents were converted for cost_calc(). Any reagent conversion should track this.
	var/reagents_converted
	/// Amount of converted reagent represented by one cost increment.
	var/reagents_per_cost = 10
	abstract_type = /datum/hallow_conversion/reagent

/datum/hallow_conversion/reagent/can_hallow(atom/target)
	return ..() && is_type_in_list(target, base_types)

/// Replaces all reagents matching this conversion's base types with its result reagent.
/datum/hallow_conversion/reagent/hallow(mob/living/user, atom/target)
	if(!target.reagents || !result_type)
		return FALSE
	var/source_amount = 0
	for(var/reagent_type in base_types)
		source_amount += target.reagents.get_reagent_amount(reagent_type, REAGENT_SUB_TYPE)
	if(!source_amount)
		return FALSE
	for(var/reagent_type in base_types)
		target.reagents.remove_reagent(reagent_type, target.reagents.get_reagent_amount(reagent_type, REAGENT_SUB_TYPE), include_subtypes = TRUE)
	target.reagents.add_reagent(result_type, source_amount)
	reagents_converted = source_amount
	if(hallow_message)
		to_chat(user, span_notice(hallow_message))
	return TRUE

/// Attempts to convert a reagent.
/datum/hallow_conversion/reagent/try_hallow(mob/living/user, atom/target, datum/reagent/reagent)
	reagents_converted = 0
	if(!can_hallow(reagent))
		return null
	if(!hallow(user, target))
		return null
	return cost_calc()

/// Calculates reagent costs from an override amount or the amount most recently converted.
/datum/hallow_conversion/reagent/cost_calc(amount = reagents_converted)
	var/calculated_cost = amount * (cost / reagents_per_cost)
	// Piety does not display or use decimals, so costs round upward to a whole value.
	return CEILING(calculated_cost, 1)

/*
	Mobs: anything /mob/living
*/

/datum/hallow_conversion/living_mob
	abstract_type = /datum/hallow_conversion/living_mob

/datum/hallow_conversion/living_mob/can_hallow(atom/target)
	return ..() && isliving(target) && is_type_in_list(target, base_types)

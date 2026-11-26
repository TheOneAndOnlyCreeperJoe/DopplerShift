/// Grants Piety based on watching unholy mobs die.
/datum/power/theologist/ceremony
	name = "Ceremony"
	desc = "You are invested in performing the deeds, rituals and rites that you have faith in.\
	\nYou have ceremonial objectives: these are drawn from a random list, up to a maximum of 5. Every objective completed increases the maximum piety restored by Faithful Prayer by 5, as well as its chance to restore Piety and its speed at which it does so.\
	\nYour powers and your personality may affect the objectives you are given."
	security_record_text = "Subject fuels their powers through ceremonies, rite and rituals, often in the chapel."
	value = 2
	required_powers = list(/datum/power/theologist/faithful)
	action_path = /datum/action/cooldown/power/theologist/ceremony

	/// Ceremonial objectives currently assigned to this power holder.
	var/list/datum/ceremonial_objective/objectives = list()
	/// Maptext overlay displaying the Ceremony-modified Faithful Prayer cap.
	var/mutable_appearance/faithful_prayer_cap_overlay

/// Rolls this power holder's ceremonial objectives when the power is gained.
/datum/power/theologist/ceremony/add(client/client_source)
	roll_objectives()
	return ..()

/// Deletes this power holder's ceremonial objectives when the power is removed.
/datum/power/theologist/ceremony/remove()
	QDEL_LIST(objectives)
	clear_ceremony_cap_overlay()
	return ..()

/// To help keep track of the actual piety we gain from prayer, having ceremony displays the total piety counter on the action with maptext.
/datum/power/theologist/ceremony/proc/update_ceremony_cap_overlay()
	var/datum/power/theologist/faithful/faithful_power = power_holder?.get_power(/datum/power/theologist/faithful)
	var/datum/action/cooldown/power/theologist/faithful/faithful_action = faithful_power?.action_path
	if(!faithful_action)
		return

	for(var/datum/hud/hud_instance as anything in faithful_action.viewers)
		var/atom/movable/screen/movable/action_button/action_button_instance = faithful_action.viewers[hud_instance]
		if(istype(action_button_instance, /atom/movable/screen/movable/action_button))
			action_button_instance.cut_overlay(faithful_prayer_cap_overlay)

	faithful_action.text_cooldown = FALSE
	faithful_prayer_cap_overlay = new
	faithful_prayer_cap_overlay.maptext_width = 32
	faithful_prayer_cap_overlay.maptext_height = 16
	faithful_prayer_cap_overlay.maptext_x = -4
	faithful_prayer_cap_overlay.maptext_y = 0
	faithful_prayer_cap_overlay.maptext = MAPTEXT("<span style='text-align:right; color:#8b0000;'>[faithful_action.prayer_cap]</span>")
	for(var/datum/hud/hud_instance as anything in faithful_action.viewers)
		var/atom/movable/screen/movable/action_button/action_button_instance = faithful_action.viewers[hud_instance]
		if(istype(action_button_instance, /atom/movable/screen/movable/action_button))
			action_button_instance.add_overlay(faithful_prayer_cap_overlay)

	faithful_action.build_all_button_icons(UPDATE_BUTTON_STATUS)

/// Removes Ceremony's maptext on Faithful Prayer.
/datum/power/theologist/ceremony/proc/clear_ceremony_cap_overlay()
	var/datum/power/theologist/faithful/faithful_power = power_holder?.get_power(/datum/power/theologist/faithful)
	var/datum/action/cooldown/power/theologist/faithful/faithful_action = faithful_power?.action_path
	if(!faithful_action)
		return

	for(var/datum/hud/hud_instance as anything in faithful_action.viewers)
		var/atom/movable/screen/movable/action_button/action_button_instance = faithful_action.viewers[hud_instance]
		if(istype(action_button_instance, /atom/movable/screen/movable/action_button))
			action_button_instance.cut_overlay(faithful_prayer_cap_overlay)

	faithful_prayer_cap_overlay = null
	faithful_action.text_cooldown = TRUE
	faithful_action.build_all_button_icons(UPDATE_BUTTON_STATUS)

/// Adds the maptext to Faithful Prayer.
/datum/power/theologist/ceremony/post_add()
	. = ..()
	update_ceremony_cap_overlay()
	return .

/// Assigns eligible concrete ceremonial objectives.
/datum/power/theologist/ceremony/proc/roll_objectives()
	var/list/remaining_objective_types = list()
	for(var/datum/ceremonial_objective/objective_type as anything in subtypesof(/datum/ceremonial_objective))
		if(initial(objective_type.abstract_type) == objective_type)
			continue
		remaining_objective_types += objective_type

	while(objectives.len < 5 && remaining_objective_types.len)
		var/objective_type = pick_n_take(remaining_objective_types)
		var/datum/ceremonial_objective/objective = new objective_type(src)
		if(!objective.eligible())
			qdel(objective)
			continue
		objectives += objective

/// Gets relevant date from all the objectives.
/datum/power/theologist/ceremony/proc/get_objective_data()
	var/list/objective_data = list()
	for(var/datum/ceremonial_objective/objective as anything in objectives)
		objective_data += list(list(
			"name" = objective.name,
			"description" = objective.description,
			"progress" = objective.get_progress_text(),
			"completed" = objective.completed,
			"reward" = objective.reward,
		))
	return objective_data

/datum/power/theologist/ceremony/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(ui)
		return
	ui = new(user, src, "TheologistCeremony", "Ceremonial Objectives")
	ui.open()

/datum/power/theologist/ceremony/ui_state(mob/user)
	return GLOB.always_state

/datum/power/theologist/ceremony/ui_data(mob/user)
	return list("objectives" = get_objective_data())

/// Action to display all objectives.
/datum/action/cooldown/power/theologist/ceremony
	name = "View Ceremonial Objectives"
	desc = "Displays the objectives you can perform to increase the piety generation for Faithful Prayer"
	button_icon = 'icons/obj/service/hand_of_god_structures.dmi'
	button_icon_state = "sacrificealtar-red"

/// Opens the owning Ceremony power's objectives interface.
/datum/action/cooldown/power/theologist/ceremony/use_action(mob/living/user, atom/target)
	var/datum/power/theologist/ceremony/ceremony_power = origin_power
	if(!ceremony_power)
		return FALSE
	ceremony_power.ui_interact(user)
	return TRUE

/// Base type for ceremonial objectives.
/// For the actual objectives, see modular_doppler\modular_powers\code\powers\sorcerous\theologist\ceremony\ceremonial_objectives.dm
/datum/ceremonial_objective
	/// Typepath used to mark this datum as an abstract type.
	abstract_type = /datum/ceremonial_objective
	/// The Ceremony power that owns this objective.
	var/datum/power/theologist/ceremony/ceremony_power
	/// The player attempting this objective.
	var/mob/living/holder
	/// Player-facing objective name.
	var/name = "YOUR OBJECTIVE"
	/// Player-facing instruction for how to complete the objective.
	var/description = "Call a coder if you see this."
	/// Whether this objective has already granted its reward.
	var/completed = FALSE
	/// The reward bonus granted upon completion to Faithful Prayer.
	var/reward = THEOLOGIST_CEREMONY_REWARD

/// Stores the ceremony power and holder
/datum/ceremonial_objective/New(datum/power/theologist/ceremony/new_ceremony_power)
	ceremony_power = new_ceremony_power
	holder = ceremony_power?.power_holder
	return ..()

/// Clears references owned by this ceremonial objective.
/datum/ceremonial_objective/Destroy()
	ceremony_power = null
	holder = null
	return ..()

/// Returns whether this objective can be assigned to its current holder.
/datum/ceremonial_objective/proc/eligible()
	return TRUE

/// Awards the objective's rewards.
/datum/ceremonial_objective/proc/complete()
	if(completed)
		return FALSE
	completed = TRUE

	var/datum/power/theologist/faithful/faithful_power = holder?.get_power(/datum/power/theologist/faithful)
	var/datum/action/cooldown/power/theologist/faithful/faithful_action = faithful_power?.action_path
	if(faithful_action)
		faithful_action.prayer_cap += reward
		faithful_action.prayer_base_chance += reward
		faithful_action.prayer_tick -= reward
		ceremony_power.update_ceremony_cap_overlay()

	to_chat(holder, "<font color='[POWER_COLOR_THEOLOGIST]'<b>You have completed the [name] ceremonial objective!</b></font>")
	to_chat(holder, "<font color='[POWER_COLOR_THEOLOGIST]'<b>Your Faithful Prayer grows stronger!</b></font>")
	SStgui.update_uis(ceremony_power)
	return TRUE

/// Returns additional player-facing progress information for this objective.
/datum/ceremonial_objective/proc/get_progress_text()
	return null

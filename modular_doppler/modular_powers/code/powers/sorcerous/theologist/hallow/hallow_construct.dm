/** Special interaction for hype moments and aura: Deacons (people converted by Chaplain Sects) and the Chaplain can deconvert constructs. It takes times and is interuptable.
 * If there is a mind inside the construct, it retains it and is de-antag'd.
 * If there isn't, it prompts a ghost to see if they want to be part of it.
**/

/// TODO: I need to comb this and get it up to date.

/datum/hallow_conversion/living_mob/construct
	base_types = list(/mob/living/basic/construct)
	cost = THEOLOGIST_PIETY_CRUSHING
	examine_extra_text = "You may not be able to perform this without a Chaplain's blessing."

/datum/hallow_conversion/living_mob/construct/can_hallow(atom/target)
	if(!..())
		return FALSE
	var/mob/living/basic/construct/construct_target = target
	return construct_target.theme != THEME_HOLY

/datum/hallow_conversion/living_mob/construct/hallow(mob/living/user, mob/living/target)
	if(!is_chaplain_job(user.mind?.assigned_role) && user.mind?.holy_role != HOLY_ROLE_DEACON)
		to_chat(user, span_warning("A strange force resists your attempts. Only a strong enough holy force, whether it be the chaplain or their deacons, can perform this kind of conversion."))
		return FALSE
	var/mob/living/basic/construct/construct_target = target
	var/datum/beam/link = user.Beam(construct_target, icon_state = "kinesis", override_target_pixel_x = 0)
	construct_target.SetStun(15 SECONDS, ignore_canstun = TRUE)
	playsound(user, 'sound/effects/magic/forcewall.ogg', 50, TRUE)
	user.visible_message(span_userdanger("[user] channels a beam of holy energy, attempting to purge any and all unholy qualities of [construct_target]!"))
	var/channel_success = do_after(user, 15 SECONDS, target = construct_target)
	construct_target.SetStun(0, ignore_canstun = TRUE)
	QDEL_NULL(link)
	if(!channel_success || QDELETED(construct_target))
		return FALSE

	var/purified_type = get_purified_construct_type(construct_target)
	if(!purified_type)
		convert_construct_in_place(construct_target, user)
		post_conversion(user, construct_target)
		return TRUE

	var/mob/living/basic/construct/new_construct = new purified_type(construct_target.loc)
	if(construct_target.mind)
		construct_target.mind.remove_antag_datum(/datum/antagonist/cult)
		construct_target.mind.remove_antag_datum(/datum/antagonist/shade_minion)
		construct_target.mind.transfer_to(new_construct, force_key_move = TRUE)
	else
		enable_construct_ghost_control(new_construct)
	post_conversion(user, new_construct)
	qdel(construct_target)
	return TRUE

/// Returns the holy counterpart for a construct type, when one exists.
/datum/hallow_conversion/living_mob/construct/proc/get_purified_construct_type(mob/living/basic/construct/target)
	if(istype(target, /mob/living/basic/construct/artificer))
		return /mob/living/basic/construct/artificer/angelic
	if(istype(target, /mob/living/basic/construct/wraith))
		return /mob/living/basic/construct/wraith/angelic
	if(istype(target, /mob/living/basic/construct/juggernaut))
		return /mob/living/basic/construct/juggernaut/angelic
	return null

/// Converts a construct without a dedicated holy subtype in place.
/datum/hallow_conversion/living_mob/construct/proc/convert_construct_in_place(mob/living/basic/construct/target, mob/living/user)
	var/old_theme = target.theme
	target.theme = THEME_HOLY
	target.faction = list(FACTION_HOLY)
	ADD_TRAIT(target, TRAIT_ANGELIC, INNATE_TRAIT)
	target.ai_controller = null
	var/datum/component/ai_retaliate_advanced/retaliate = target.GetComponent(/datum/component/ai_retaliate_advanced)
	if(retaliate)
		qdel(retaliate)
	if(target.icon_state)
		target.cut_overlay("glow_[target.icon_state]_[old_theme]")
		target.add_overlay("glow_[target.icon_state]_[target.theme]")
	target.update_appearance()
	target.mind?.remove_antag_datum(/datum/antagonist/cult)
	target.mind?.remove_antag_datum(/datum/antagonist/shade_minion)
	if(!target.mind)
		enable_construct_ghost_control(target)

/// Gives an unoccupied purified construct ghost control.
/datum/hallow_conversion/living_mob/construct/proc/enable_construct_ghost_control(mob/living/basic/construct/target)
	target.AddComponent(/datum/component/ghost_direct_control, poll_candidates = TRUE, poll_question = "Do you want to play as a Theologist's purified construct?", role_name = "purified construct", poll_ignore_key = POLL_IGNORE_CONSTRUCT, assumed_control_message = "You are a purified construct, freed from the Geometer's influence. Your will is now your own.")

/// Delivers conversion feedback and applies the Geometer's debt.
/datum/hallow_conversion/living_mob/construct/proc/post_conversion(mob/living/user, mob/living/target)
	user.visible_message(span_notice("[user] purifies [target]!"))
	playsound(user, 'sound/effects/his_grace/his_grace_ascend.ogg', 50, TRUE)
	to_chat(target, span_blue("<b>The Geometer's presence in your mind fades, what was once your own freewill slips back into the forefront. You look down at your body; and while it is still the dark steel that adorns your body, you can move it of your own free will. Your freedom is returned; but still tethered forevermore to this body.</b>"))
	to_chat(user, span_blue("<b>As you have shown yourself to be pious, to take on the burdens of others; you now take on the greatest burden of another. Whoever the vile entity responsible may be, you take it away from this enslaved tool, and bury the energy responsible deep inside you. You have freed it; but this darkness seems to be eating away at you.</b>"))
	user.apply_status_effect(/datum/status_effect/debt_to_the_geometer, src)
	to_chat(user, span_cult_bold("<b>You have been cursed; your actions carry a price, and you shall be made to pay it.</b>"))

/datum/status_effect/debt_to_the_geometer
	id = "debt_to_the_geometer"
	alert_type = /atom/movable/screen/alert/status_effect/debt_to_the_geometer
	var/debt_goal = 600
	var/debt_paid = 0
	var/bleed_per_second = 5
	var/curse_has_started = FALSE

/datum/status_effect/debt_to_the_geometer/on_apply()
	. = ..()
	if(!.)
		return FALSE
	RegisterSignal(owner, COMSIG_LIVING_DEATH, PROC_REF(on_owner_death))
	return TRUE

/datum/status_effect/debt_to_the_geometer/tick(seconds_between_ticks)
	if(!owner)
		return
	if(!curse_has_started)
		if(prob(0.5))
			curse_has_started = TRUE
			to_chat(owner, span_cult_bold("Blood is starting to ooze from every part of your body!"))
		else
			return
	if(GLOB.cult_narsie)
		var/turf/owner_turf = get_turf(owner)
		if(owner_turf && owner_turf.z == GLOB.cult_narsie.z)
			var/datum/component/singularity/singularity_component = GLOB.cult_narsie.singularity?.resolve()
			if(singularity_component && singularity_component.target != owner)
				GLOB.cult_narsie.acquire(owner)
	spawn_blood_splatter()
	if(istype(owner, /mob/living/carbon))
		var/mob/living/carbon/carbon_owner = owner
		var/blood_before = carbon_owner.blood_volume
		carbon_owner.bleed(bleed_per_second * seconds_between_ticks)
		debt_paid += max(blood_before - carbon_owner.blood_volume, 0)
	if(debt_paid >= debt_goal)
		qdel(src)

/// Creates a randomly-sized blood splatter beneath the debtor.
/datum/status_effect/debt_to_the_geometer/proc/spawn_blood_splatter()
	var/turf/bleed_turf = get_turf(owner)
	if(!bleed_turf)
		return
	var/splatter_amount
	switch(rand(1, 100))
		if(1 to 80)
			splatter_amount = rand(1, 8)
		if(81 to 95)
			splatter_amount = rand(9, 15)
		else
			splatter_amount = rand(16, 25)
	owner.add_splatter_floor(bleed_turf, splatter_amount)

/datum/status_effect/debt_to_the_geometer/on_remove()
	if(owner)
		to_chat(owner, span_cult_bold("The Geometer's notice is no longer upon you."))
	return ..()

/// Empties the debtor's blood and splatters the surrounding tiles upon death.
/datum/status_effect/debt_to_the_geometer/proc/on_owner_death(datum/source, gibbed)
	SIGNAL_HANDLER
	if(!owner)
		return
	if(istype(owner, /mob/living/carbon))
		var/mob/living/carbon/carbon_owner = owner
		carbon_owner.blood_volume = 0
	var/turf/center_turf = get_turf(owner)
	if(center_turf)
		for(var/turf/splatter_turf in range(1, center_turf))
			owner.add_splatter_floor(splatter_turf, FALSE)
	owner.visible_message(span_boldwarning("[owner]'s body bursts open, showering blood everywhere!"))
	playsound(owner, 'sound/effects/wounds/splatter.ogg', 50, TRUE, MEDIUM_RANGE_SOUND_EXTRARANGE)
	qdel(src)

/atom/movable/screen/alert/status_effect/debt_to_the_geometer
	name = "Debt to the Geometer"
	desc = "The Geometer demands you pay the blood price for your actions."
	icon = 'icons/obj/mining_zones/artefacts.dmi'
	icon_state = "soulstone2"
	alerttooltipstyle = "cult"

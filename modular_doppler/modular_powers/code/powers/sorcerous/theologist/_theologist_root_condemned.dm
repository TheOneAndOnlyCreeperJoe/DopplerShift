/// Mark a target within LoS to apply a host of lingering effects.
/// By default, the target is treated as unholy for theologist powers and apply a stacking debuff that reduces their next damage dealt.
/// You gain Piety when these stacks are spent, encouraging you to fight active combatants. Mobs that were unholy before using this power (not including other Condemns) also grant Piety for building stacks.

/datum/power/theologist/root/condemned
	name = "A Burden Condemned"
	desc = "Bring justice to those that would seek to burden others, by making them feel the weight of suffering they shoulder onto the innocent.\
	\nChoose a target within view: you mark that target, applying Condemned. A Condemned target counts as Unholy for all of Theologist's powers, and you can only have one target condemned.\
	\nWhenever someone with this power damages the condemned with attacks, they apply Condemnation equal to half the pre-mitigation damage they would have dealt (regardless if the condemned blocks or mitigates it). \
	Condemnation reduces the condemned's damage with attacks by the amount stored, up to 50% of the condemned's hit; this consumes the Condemnation equal to the damage prevented. \
	\nYou build piety whenever a creature spends Condemnation when attacking a sentient mob: you also build Piety whenever you apply Condemnation to a mob that was already Unholy before you cast A Burden Condemned, or when striking a creature Condemned by someone else.\
	\nLasts for 20 seconds, but lasts 1 additional second on hit. Cooldown is refreshed if the condemned dies."
	security_record_text = "Subject can mark a single target in sight, weakening their attacks when struck by the subject, and amplying their own holy abilities against that target."
	security_threat = POWER_THREAT_MAJOR
	action_path = /datum/action/cooldown/power/theologist/theologist_root/condemned

	power_flags = POWER_HUMAN_ONLY // the only root that doesn't heal

	value = 5

/datum/action/cooldown/power/theologist/theologist_root/condemned
	name = "A Burden Condemned"
	desc = "Condemn a creature, marking it as Unholy and causing your damage against the condemned to apply a debuff that reduces their damage. Extends the duration on hit, and restores the cooldown on condemned death.\
	Builds Piety when you succesfuly reduce damage: or if you damage a mob that was Unholy before condemning them. You can only have one target marked as Condemned at a time"
	button_icon = 'modular_doppler/modular_powers/icons/powers/actions_icons.dmi'
	button_icon_state = "burden_condemned"
	cooldown_time = 30 SECONDS
	target_range = 10
	target_self = FALSE
	click_to_activate = TRUE

	/// The target currently condemned by this action.
	var/datum/status_effect/power/burden_condemned/active_effect
	/// How long the Condemned status lasts.
	var/condemned_duration = 20 SECONDS
	/// The fraction of pre-mitigation damage converted into Condemnation.
	var/condemnation_rate = 0.5
	/// The maximum fraction of a hit that Condemnation can reduce.
	var/damage_reduction_cap = 0.5
	/// Piety awarded for each point of Condemnation spent against a sentient creature.
	var/piety_per_condemnation_spent = THEOLOGIST_PIETY_HEALING_COEFFICIENT
	/// Piety awarded for each point of Condemnation built against a previously unholy target.
	var/piety_per_unholy_condemnation_built = THEOLOGIST_PIETY_HEALING_COEFFICIENT * 0.25

/datum/action/cooldown/power/theologist/theologist_root/condemned/Destroy()
	QDEL_NULL(active_effect)
	return ..()

/// Prevents applying a second Condemned effect to an already condemned target.
/datum/action/cooldown/power/theologist/theologist_root/condemned/can_use(mob/living/user, atom/target)
	if(!isliving(target))
		return FALSE
	var/mob/living/living_target = target
	if(living_target.has_status_effect(/datum/status_effect/power/burden_condemned))
		user.balloon_alert(user, "already condemned!")
		return FALSE
	return ..()

/datum/action/cooldown/power/theologist/theologist_root/condemned/use_action(mob/living/user, mob/living/target)
	QDEL_NULL(active_effect)
	// status basically handles everything
	active_effect = target.apply_status_effect(/datum/status_effect/power/burden_condemned, src, was_unholy_before_condemnation(target), condemned_duration)
	if(!active_effect)
		return FALSE
	//FX
	user.playsound_local(target, 'modular_doppler/modular_powers/sounds/condemned/condemned.ogg', 50, FALSE)
	target.playsound_local(target, 'modular_doppler/modular_powers/sounds/condemned/condemned.ogg', 50, FALSE)
	target.log_message("was condemned by [user].", LOG_VICTIM)
	user.log_message("condemned [target].", LOG_ATTACK)
	to_chat(target, span_boldwarning("You feel the crushing weight of condemnation settle upon you as [user] points at you!"))
	to_chat(user, span_warning("You condemn [target]!"))
	return TRUE

/// Determines whether a target was unholy before using Condemned.
/datum/action/cooldown/power/theologist/theologist_root/condemned/proc/was_unholy_before_condemnation(mob/living/target)
	var/datum/power/theologist/root/condemned/condemned_power = origin_power
	if(!condemned_power?.is_unholy(target))
		return FALSE
	if(!HAS_TRAIT(target, TRAIT_DEEMED_UNHOLY))
		return TRUE
	for(var/trait_source in GET_TRAIT_SOURCES(target, TRAIT_DEEMED_UNHOLY))
		if(!istype(trait_source, /datum/status_effect/power/burden_condemned))
			return TRUE
	return FALSE

/// Marks a creature as unholy and turns damage from A Burden Condemned users into Condemnation.
/datum/status_effect/power/burden_condemned
	id = "burden_condemned"
	duration = 20 SECONDS
	tick_interval = STATUS_EFFECT_NO_TICK
	status_type = STATUS_EFFECT_UNIQUE
	alert_type = /atom/movable/screen/alert/status_effect/burden_condemned

	/// The action that applied this effect.
	var/datum/action/cooldown/power/theologist/theologist_root/condemned/condemning_action
	/// Condemnation that's been build up: used for damage reduction.
	var/condemnation = 0
	/// Whether this target was unholy before this effect was applied.
	var/was_unholy
	/// Projectiles which may later hit a target and need an impact listener.
	var/list/obj/projectile/tracked_projectiles = list()
	/// The visible aura applied to condemned targets.
	var/static/mutable_appearance/condemned_overlay = mutable_appearance('modular_doppler/modular_powers/icons/powers/effects.dmi', "condemned_aura")

/datum/status_effect/power/burden_condemned/on_creation(mob/living/new_owner, datum/action/cooldown/power/theologist/theologist_root/condemned/new_condemning_action, target_was_unholy, new_duration)
	condemning_action = new_condemning_action
	was_unholy = target_was_unholy
	duration = new_duration
	. = ..()
	if(.)
		update_condemnation_alert()
	return .

/datum/status_effect/power/burden_condemned/on_apply()
	if(!condemning_action?.owner)
		return FALSE
	ADD_TRAIT(owner, TRAIT_DEEMED_UNHOLY, src)
	owner.add_overlay(condemned_overlay)
	RegisterSignal(owner, COMSIG_ATOM_DISPEL, PROC_REF(on_dispel))
	RegisterSignal(owner, COMSIG_LIVING_DEATH, PROC_REF(on_owner_death))
	/// To get this to work, these signalers all apply a status effect that then applies COMSIG_MOB_APPLY_DAMAGE_MODIFIERS, which then handles Condemnation's effects, rather than trying to juggle all these signal args.
	RegisterSignal(owner, COMSIG_LIVING_CHECK_BLOCK, PROC_REF(build_condemnation))
	RegisterSignal(owner, COMSIG_MOB_ITEM_ATTACK, PROC_REF(prepare_item_attack))
	RegisterSignal(owner, COMSIG_LIVING_UNARMED_ATTACK, PROC_REF(prepare_unarmed_attack))
	RegisterSignal(owner, COMSIG_HOSTILE_PRE_ATTACKINGTARGET, PROC_REF(prepare_hostile_attack))
	RegisterSignal(owner, COMSIG_PROJECTILE_FIRER_BEFORE_FIRE, PROC_REF(prepare_projectile))
	return TRUE

/datum/status_effect/power/burden_condemned/on_remove()
	owner.cut_overlay(condemned_overlay)
	REMOVE_TRAIT(owner, TRAIT_DEEMED_UNHOLY, src)
	UnregisterSignal(owner, list(COMSIG_ATOM_DISPEL, COMSIG_LIVING_DEATH, COMSIG_LIVING_CHECK_BLOCK, COMSIG_MOB_ITEM_ATTACK, COMSIG_LIVING_UNARMED_ATTACK, COMSIG_HOSTILE_PRE_ATTACKINGTARGET, COMSIG_PROJECTILE_FIRER_BEFORE_FIRE))
	for(var/obj/projectile/tracked_projectile as anything in tracked_projectiles)
		UnregisterSignal(tracked_projectile, list(COMSIG_PROJECTILE_SELF_PREHIT, COMSIG_QDELETING))
	tracked_projectiles.Cut()
	if(condemning_action?.active_effect == src)
		condemning_action.active_effect = null
	return

/// Removes Condemned when a valid dispel affects its owner.
/datum/status_effect/power/burden_condemned/proc/on_dispel(mob/living/source, atom/dispeller)
	SIGNAL_HANDLER
	qdel(src)
	return DISPEL_RESULT_DISPELLED

/// Removes Condemned from a creature that dies.
/datum/status_effect/power/burden_condemned/proc/on_owner_death(mob/living/source, gibbed)
	SIGNAL_HANDLER
	condemning_action?.ResetCooldown()
	qdel(src)

/// Builds Condemnation based on the supplied damage (which is pre-mtiigation)
/datum/status_effect/power/burden_condemned/proc/build_condemnation(mob/living/source, atom/movable/hit_by, damage, attack_text, attack_type, armour_penetration, damage_type)
	SIGNAL_HANDLER
	var/mob/living/attack_source = get_attack_source_mob(hit_by)
	var/datum/power/theologist/root/condemned/contributing_power = attack_source?.get_power(/datum/power/theologist/root/condemned)
	var/datum/action/cooldown/power/theologist/theologist_root/condemned/contributing_action = contributing_power?.action_path
	if(!contributing_action || damage <= 0)
		return
	duration += 1 SECONDS // Cooldown reduction on hit
	var/condemnation_added = damage * contributing_action.condemnation_rate
	condemnation += condemnation_added
	update_condemnation_alert()
	if(was_unholy || contributing_action != condemning_action) // piggybacking off of others is valid!
		contributing_action.adjust_piety(condemnation_added * contributing_action.piety_per_unholy_condemnation_built)

/// Updates the Condemned alert with the damage currently stored as Condemnation.
/datum/status_effect/power/burden_condemned/proc/update_condemnation_alert()
	var/rounded_condemnation = round(condemnation)
	linked_alert?.maptext = MAPTEXT_TINY_UNICODE("<span style='text-align:center'>-[rounded_condemnation] DMG</span>")
	linked_alert?.desc = "You have been marked as evil and deal [rounded_condemnation] less damage with attacks; but no less than 50% of the attack's damage!"

/// Applies the damage holder status to handle Condemned's damage reduction when attacking with an item.
/datum/status_effect/power/burden_condemned/proc/prepare_item_attack(mob/living/source, mob/living/target, mob/living/user, list/modifiers, list/attack_modifiers)
	SIGNAL_HANDLER
	if(user == owner)
		apply_damage_holder(target)

/// Applies the damage holder status to handle Condemned's damage reduction when attacking with your bare hands. or bear hands.
/datum/status_effect/power/burden_condemned/proc/prepare_unarmed_attack(mob/living/source, atom/target, proximity, list/modifiers)
	SIGNAL_HANDLER
	if(proximity && isliving(target))
		apply_damage_holder(target)

/// Applies the damage holder status to handle Condemned's damage reduction when a bear is attacking with their hands.
/datum/status_effect/power/burden_condemned/proc/prepare_hostile_attack(mob/living/source, atom/target, proximity = TRUE, list/modifiers)
	SIGNAL_HANDLER
	if(proximity && isliving(target))
		apply_damage_holder(target)

/// Registers a listener to prehit for projectiled and when the projectile is deleted.
/datum/status_effect/power/burden_condemned/proc/prepare_projectile(mob/living/source, obj/projectile/projectile, atom/fired_from, atom/original)
	SIGNAL_HANDLER
	if(!projectile)
		return
	tracked_projectiles += projectile
	RegisterSignal(projectile, COMSIG_PROJECTILE_SELF_PREHIT, PROC_REF(prepare_projectile_impact))
	RegisterSignal(projectile, COMSIG_QDELETING, PROC_REF(forget_projectile))

/// Applies the damage holder status to handle Condemned's damage reduction when hitting with a projectile.
/datum/status_effect/power/burden_condemned/proc/prepare_projectile_impact(obj/projectile/source, atom/target)
	SIGNAL_HANDLER
	if(isliving(target))
		apply_damage_holder(target)

/// Removes listeners from a projectile that can no longer impact anything.
/datum/status_effect/power/burden_condemned/proc/forget_projectile(obj/projectile/source)
	SIGNAL_HANDLER
	UnregisterSignal(source, list(COMSIG_PROJECTILE_SELF_PREHIT, COMSIG_QDELETING))
	tracked_projectiles -= source

/// Applies a short-lived status effect which resolves Condemnation on the target using COMSIG_MOB_APPLY_DAMAGE_MODIFIERS.
/datum/status_effect/power/burden_condemned/proc/apply_damage_holder(mob/living/target)
	if(!target || condemnation <= 0)
		return
	for(var/datum/status_effect/power/burden_condemnation_holder/existing_holder in target.status_effects)
		if(existing_holder.condemned_effect == src)
			return
	target.apply_status_effect(/datum/status_effect/power/burden_condemnation_holder, src)

/// Resolves a mob source from melee, item, and projectile attack sources.
/datum/status_effect/power/burden_condemned/proc/get_attack_source_mob(atom/hit_by)
	if(ismob(hit_by))
		return hit_by
	if(istype(hit_by, /obj/projectile))
		var/obj/projectile/projectile = hit_by
		return ismob(projectile.firer) ? projectile.firer : null
	if(isitem(hit_by))
		var/obj/item/item = hit_by
		return ismob(item.loc) ? item.loc : null
	return null

/// Reduces one incoming attack using the linked Condemned effect.
/datum/status_effect/power/burden_condemnation_holder
	id = "burden_condemnation_holder"
	duration = 1 SECONDS
	tick_interval = STATUS_EFFECT_NO_TICK
	status_type = STATUS_EFFECT_MULTIPLE
	alert_type = null

	/// The Condemned effect supplying the damage reduction.
	var/datum/status_effect/power/burden_condemned/condemned_effect

/datum/status_effect/power/burden_condemnation_holder/on_creation(mob/living/new_owner, datum/status_effect/power/burden_condemned/new_condemned_effect)
	condemned_effect = new_condemned_effect
	return ..()

/datum/status_effect/power/burden_condemnation_holder/on_apply()
	if(QDELETED(condemned_effect) || condemned_effect.condemnation <= 0)
		return FALSE
	RegisterSignal(owner, COMSIG_MOB_APPLY_DAMAGE_MODIFIERS, PROC_REF(reduce_damage))
	return TRUE

/datum/status_effect/power/burden_condemnation_holder/on_remove()
	UnregisterSignal(owner, COMSIG_MOB_APPLY_DAMAGE_MODIFIERS)
	return

/// Reduces one pending hit by available Condemnation, up to half of that hit's damage.
/datum/status_effect/power/burden_condemnation_holder/proc/reduce_damage(mob/living/source, list/damage_modifiers, damage_amount, damage_type, def_zone, sharpness, attack_direction, obj/item/attacking_item)
	SIGNAL_HANDLER
	if(!QDELETED(condemned_effect) && damage_amount > 0)
		var/damage_reduction = min(condemned_effect.condemnation, damage_amount * condemned_effect.condemning_action.damage_reduction_cap)
		damage_modifiers += 1 - (damage_reduction / damage_amount)
		condemned_effect.condemnation -= damage_reduction
		condemned_effect.update_condemnation_alert()

		if(source.mind)
			condemned_effect.condemning_action.adjust_piety(damage_reduction * condemned_effect.condemning_action.piety_per_condemnation_spent)
	qdel(src)

/// Desc gets updated by the status effect so this is a placeholder.
/atom/movable/screen/alert/status_effect/burden_condemned
	name = "Condemned"
	desc = "You have been marked as evil and deal 0 less damage with attacks; but no less than 50% of the attack's damage!"
	icon = 'modular_doppler/modular_powers/icons/powers/actions_icons.dmi'
	icon_state = "burden_condemned"

// Base subtype for smite powers.
/datum/power/theologist/smite
	name = "abstract Smite"
	desc = "You know, Theologist needed a second abstract type. Why? Well, I can give you good programming reasons, but you're not the developer. Go tell an admin, BECAUSE I SAID SO."

	abstract_parent_type = /datum/power/theologist/smite
	action_path = /datum/action/cooldown/power/theologist/smite

	gives_unholy_sight = TRUE

/datum/action/cooldown/power/theologist/smite
	name = "abstract smite action"
	desc = "You know, Theologist needed a second abstract type. Why? Well, I can give you good programming reasons, but you're not the developer. Go tell an admin, BECAUSE I SAID SO."

	/// The threshold at which we consider something a big smite and play the COOLER fx (and the threshold that most smites should start doing cool effects).
	var/big_smite_req = THEOLOGIST_PIETY_MAJOR
	/// The color used by this smite's item effect.
	var/smite_color = COLOR_LIME // shame on you for not setting this get lime'd lmao

	/// The temp visual used by this smite's small smite
	var/small_smite_temp_visual = /obj/effect/temp_visual/theologist_smite
	/// The temp visual used by this smite's big smite
	var/big_smite_temp_visual = /obj/effect/temp_visual/theologist_smite

	/// The sound to play on a small smite
	var/small_smite_sound = 'sound/effects/magic/magic_block_holy.ogg'
	/// The sound to play on a big smite
	var/big_smite_sound = 'sound/effects/magic/magic_block_holy.ogg'

	/// The smite component currently applied by this action.
	var/datum/component/theologist_smite/current_smite

/datum/action/cooldown/power/theologist/smite/use_action(mob/living/user, atom/target)
	var/obj/item/smite_item = user.get_active_held_item()
	if(!smite_item)
		to_chat(user, span_warning("You must hold an item to smite with it!"))
		user.balloon_alert(user, "No item held!")
		return FALSE
	if(smite_item.force <= 0)
		to_chat(user, span_warning("[smite_item] is too weak to smite!"))
		user.balloon_alert(user, "Too weak to smite!")
		return FALSE
	if(HAS_TRAIT(smite_item, TRAIT_HAS_SMITE)) // originally blocked it but replacing feels better for gameplay flow.
		qdel(smite_item.GetComponent(/datum/component/theologist_smite))
	if(smite_item.item_flags & ABSTRACT)
		return FALSE

	current_smite = smite_item.AddComponent(/datum/component/theologist_smite, src, user)
	to_chat(user, span_notice("You imbue [name] onto your weapon!"))
	playsound(user, 'modular_doppler/modular_powers/sounds/smite/smite_charge.ogg', 50, TRUE, MEDIUM_RANGE_SOUND_EXTRARANGE)
	// TODO: Lingering effect on the mob to indicate they are currently ready to SMITE a fool
	RegisterSignal(current_smite, COMSIG_QDELETING, PROC_REF(on_smite_deleted))
	return TRUE

/// Smite effects are handled in the action for the sake of making it easier to develop for.

/// Handles an attack made with an smited item.
/datum/action/cooldown/power/theologist/smite/proc/melee_smite(obj/item/smite_item, atom/target, mob/living/user, list/modifiers, list/attack_modifiers)
	return

/// Handles a projectile fired from an smited item that hits a target.
/datum/action/cooldown/power/theologist/smite/proc/projectile_smite(datum/fired_from, atom/movable/firer, atom/target, angle, hit_limb, blocked, pierce_hit)
	return

/// Plays this smite's configured hit visual and sound at an impact turf.
/datum/action/cooldown/power/theologist/smite/proc/play_smite_effect(turf/impact_turf)
	if(!impact_turf)
		return

	var/is_big_smite = get_piety() >= big_smite_req
	var/smite_visual = is_big_smite ? big_smite_temp_visual : small_smite_temp_visual
	var/smite_sound = is_big_smite ? big_smite_sound : small_smite_sound
	if(smite_visual)
		var/obj/effect/temp_visual/hit_visual = new smite_visual(impact_turf)
		hit_visual.color = smite_color
	if(smite_sound)
		playsound(impact_turf, smite_sound, 75, TRUE)

/// Applies the post-hit cooldown shared by all of this holder's smites.
/datum/action/cooldown/power/theologist/smite/proc/smite_succesful_hit()
	for(var/datum/action/cooldown/power/theologist/smite/smite_action in owner?.actions)
		smite_action.StartCooldownSelf(THEOLOGIST_SMITE_HIT_COOLDOWN)

/// Clears the tracked component when its smite is removed.
/datum/action/cooldown/power/theologist/smite/proc/on_smite_deleted(datum/source)
	SIGNAL_HANDLER
	if(current_smite == source)
		current_smite = null

/*
============
Component below
============
*/

/datum/component/theologist_smite
	/// The action that created the smite
	var/datum/action/cooldown/power/theologist/smite/source_action
	/// The mob that must continue holding the item for this smite to persist.
	var/mob/living/holder
	/// The visual effect applied while this smite is active.
	var/datum/component/unusual_effect/smite_effect

/datum/component/theologist_smite/Initialize(datum/action/cooldown/power/theologist/smite/new_source_action, mob/living/new_holder)
	if(!isitem(parent))
		return COMPONENT_INCOMPATIBLE

	source_action = new_source_action
	holder = new_holder
	ADD_TRAIT(parent, TRAIT_HAS_SMITE, src)
	/// Adds really cool particles because smites should feel DOPE
	smite_effect = parent.AddComponent(/datum/component/unusual_effect, source_action.smite_color, TRUE)
	if(smite_effect?.special_effects)
		smite_effect.special_effects.particles.color = source_action.smite_color

/datum/component/theologist_smite/RegisterWithParent()
	RegisterSignal(parent, COMSIG_PROJECTILE_ON_HIT, PROC_REF(projectile_hit))
	RegisterSignal(parent, COMSIG_ITEM_AFTERATTACK, PROC_REF(melee_hit))
	RegisterSignal(parent, COMSIG_ITEM_POST_UNEQUIP, PROC_REF(on_item_unequipped))
	RegisterSignal(source_action, COMSIG_QDELETING, PROC_REF(on_source_action_deleted))

/datum/component/theologist_smite/UnregisterFromParent()
	if(parent)
		UnregisterSignal(parent, list(COMSIG_PROJECTILE_ON_HIT, COMSIG_ITEM_AFTERATTACK, COMSIG_ITEM_POST_UNEQUIP))
	if(source_action)
		UnregisterSignal(source_action, COMSIG_QDELETING)

/datum/component/theologist_smite/Destroy(force)
	REMOVE_TRAIT(parent, TRAIT_HAS_SMITE, src)
	if(!QDELETED(smite_effect))
		qdel(smite_effect)
	smite_effect = null
	. = ..()
	source_action = null
	holder = null
	return .

/// Relays a projectile hit from the smited item to the action that applied this smite.
/datum/component/theologist_smite/proc/projectile_hit(datum/fired_from, atom/movable/firer, atom/target, angle, hit_limb, blocked, pierce_hit)
	SIGNAL_HANDLER

	var/turf/impact_turf = get_turf(target)
	if(!source_action?.projectile_smite(fired_from, firer, target, angle, hit_limb, blocked, pierce_hit))
		return
	source_action?.play_smite_effect(impact_turf)
	source_action?.smite_succesful_hit()
	qdel(src)

/// Relays a melee attack from the smited item to the action that applied this smite.
/datum/component/theologist_smite/proc/melee_hit(obj/item/smite_item, atom/target, mob/living/user, list/modifiers, list/attack_modifiers)
	SIGNAL_HANDLER

	var/turf/impact_turf = get_turf(target)
	if(!source_action?.melee_smite(smite_item, target, user, modifiers, attack_modifiers))
		return
	source_action?.play_smite_effect(impact_turf)
	source_action?.smite_succesful_hit()
	qdel(src)

/// Removes the smite after its item is moved out of the original holder's hand.
/datum/component/theologist_smite/proc/on_item_unequipped(obj/item/smite_item, force, atom/new_location, no_move, invdrop, silent)
	SIGNAL_HANDLER

	if(!holder?.is_holding(smite_item))
		qdel(src)

/// Removes the smite if its source action no longer exists.
/datum/component/theologist_smite/proc/on_source_action_deleted()
	SIGNAL_HANDLER

	qdel(src)

/obj/effect/temp_visual/theologist_smite
	icon_state = "electricity3"
	duration = 0.5 SECONDS

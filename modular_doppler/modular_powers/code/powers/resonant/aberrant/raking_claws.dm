/*
	Different version of a melee weapon power. While its comparible to the Armblade, it differs in a few important ways:
	- It deals less damage, has less armor pen but bleeds more and upgrades existing bleed wounds on limbs they strike.
	- Has a built-in dual-wield mechanic that focuses on making targets bleed.
	- Occupies both hands.
	- Doesn't table-break.
*/
/datum/power/aberrant/raking_claws
	name = "Raking Claws"
	desc = "Transforms both your hands into large, wicked claws. These claws deal 15 damage, are sharp and are excessively prone to causing and aggravating bleeding. Less effective against armor.\
	\nIn addition, it comes with a built-in dual-wield mechanic, which gives you a 10% chance to rake a target with both claws simultaneously. This increases with how much bleeding the target has (7.5% per 1u), up to 75%.\
	\nNon-humanoid mobs that can bleed instead gain an escalating damage-over-time effect that scales your dual-wield chance as if it were bleed. \
	\nYou cannot hold any objects while using raking claws, and activating it makes you instantly drop anything you are holding."
	security_record_text = "Subject can manifest sharp, monstrous claws from their hands."
	security_threat = POWER_THREAT_MAJOR
	value = 6
	magic_flags = POWER_MAGIC_STANDARD
	required_powers = list(/datum/power/aberrant_root/monstrous)
	action_path = /datum/action/cooldown/power/aberrant/raking_claws

/datum/action/cooldown/power/aberrant/raking_claws
	name = "Raking Claws"
	desc = "Reform your hands into deadly claws, dropping everything you are holding. Using the power again retracts them."
	button_icon = 'icons/mob/actions/actions_changeling.dmi'
	button_icon_state = "sting_armblade"
	active = FALSE

	cooldown_time = 50
	cost = ABERRANT_HUNGER_TRIVIAL * 8
	/// Whether the current activation extended the claws and should spend hunger.
	var/raking_claws_extended = FALSE

	/// Base percentage chance for the dual-wield rake attack to trigger.
	var/rake_base_chance = 10
	/// Maximum percentage chance for the dual-wield rake attack to trigger.
	var/rake_max_chance = 75
	/// Percentage added to the dual-wield rake chance per unit of the target's bleed rate.
	var/rake_bleed_mult = 7.5
	/// Final calculated chance for the dual-wield rake attack.
	var/rake_final_chance

	/// Chance that we aggrevate bleeding wounds on the target (increasing their tier)
	var/aggrevate_bleed_chance = 75

/// Registers the dispel handler when the power is granted.
/datum/action/cooldown/power/aberrant/raking_claws/Grant(mob/granted_to)
	. = ..()
	RegisterSignal(granted_to, COMSIG_ATOM_DISPEL, PROC_REF(on_dispel))

/// Retracts manifested claws and unregisters the dispel handler when the power is removed.
/datum/action/cooldown/power/aberrant/raking_claws/Remove(mob/removed_from)
	retract_claws(removed_from)
	UnregisterSignal(removed_from, COMSIG_ATOM_DISPEL)
	return ..()

/// Add a guard so that disabling does not run the can_use check on hunger.
/datum/action/cooldown/power/aberrant/raking_claws/can_use(mob/living/user, atom/target)
	bypass_cost = active
	return ..()

/// Manifests a claw in each hand, or retracts both claws when already active.
/datum/action/cooldown/power/aberrant/raking_claws/use_action(mob/living/user, atom/target)
	raking_claws_extended = FALSE
	if(active)
		retract_claws(user)
		playsound(user, 'sound/effects/magic/exit_blood.ogg', 50, TRUE, MEDIUM_RANGE_SOUND_EXTRARANGE)
		user.visible_message(
			span_warning("With a sickening crunch, [user]'s claws reform into hands!"),
			span_notice("You assimilate the claws back into your body."),
		)
		return TRUE

	user.drop_all_held_items()
	if(length(user.get_empty_held_indexes()) < 2)
		user.balloon_alert(user, "hands obstructed!")
		return FALSE

	var/obj/item/raking_claw/active_claw = new(user)
	active_claw.manifesting_power = src
	if(!user.put_in_active_hand(active_claw))
		qdel(active_claw)
		return FALSE

	var/obj/item/raking_claw/inactive_claw = new(user)
	inactive_claw.manifesting_power = src
	if(!user.put_in_inactive_hand(inactive_claw))
		user.temporarilyRemoveItemFromInventory(active_claw, TRUE)
		qdel(inactive_claw)
		return FALSE

	playsound(user, 'sound/effects/magic/exit_blood.ogg', 50, TRUE, MEDIUM_RANGE_SOUND_EXTRARANGE)
	user.visible_message(
		span_warning("A pair of grotesque claws tear their way out of [user]'s hands!"),
		span_notice("Your hands twist and mutate into deadly claws."),
	)
	user.update_held_items()
	active = TRUE
	bypass_cost = TRUE
	raking_claws_extended = TRUE
	return TRUE

/// Charges hunger only when the claws were extended, allowing free retraction.
/datum/action/cooldown/power/aberrant/raking_claws/on_action_success(mob/living/user, atom/target)
	cost = raking_claws_extended ? ABERRANT_HUNGER_TRIVIAL * 8 : 0
	. = ..()
	raking_claws_extended = FALSE
	cost = initial(cost)

/// Deletes every manifested claw held by the owner and marks the power inactive.
/datum/action/cooldown/power/aberrant/raking_claws/proc/retract_claws(mob/claw_owner)
	for(var/obj/item/raking_claw/claw in claw_owner.held_items)
		claw_owner.temporarilyRemoveItemFromInventory(claw, TRUE)
	claw_owner.update_held_items()
	active = FALSE
	bypass_cost = FALSE

/// Dispels both claws and puts the power on a longer cooldown.
/datum/action/cooldown/power/aberrant/raking_claws/proc/on_dispel(mob/living/owner, atom/dispeller)
	SIGNAL_HANDLER
	if(!active)
		return NONE

	retract_claws(owner)
	owner.visible_message(
		span_warning("With a sickening crunch, [owner]'s claws are forced back into [owner.p_their()] hands!"),
		span_boldwarning("Your claws twist back to normal against your will!"),
	)
	StartCooldownSelf(150)
	return DISPEL_RESULT_DISPELLED

/*
	Item code below, including handling for most on-hit effects.
*/
/obj/item/raking_claw
	name = "raking claw"
	desc = "A long, wicked claw made for tearing open flesh and existing wounds."
	icon = 'icons/obj/weapons/changeling_items.dmi'
	icon_state = "arm_blade"
	inhand_icon_state = "arm_blade"
	icon_angle = 180
	lefthand_file = 'icons/mob/inhands/antag/changeling_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/antag/changeling_righthand.dmi'
	item_flags = NEEDS_PERMIT | ABSTRACT | DROPDEL
	w_class = WEIGHT_CLASS_HUGE
	force = 15
	throwforce = 0
	throw_range = 0
	throw_speed = 0
	hitsound = 'sound/items/weapons/slash.ogg'
	attack_verb_continuous = list("rakes", "slashes", "tears", "lacerates", "rips", "cuts")
	attack_verb_simple = list("rake", "slash", "tear", "lacerate", "rip", "cut")
	sharpness = SHARP_EDGED
	armour_penetration = 10
	wound_bonus = 5
	exposed_wound_bonus = 25 // really good at bleeding exposed bodyparts
	/// Inherited reference to the power that manifested this claw and owns its dual-wield tuning.
	var/datum/action/cooldown/power/aberrant/raking_claws/manifesting_power
	/// Prevents propagation and mirrors the animation during a dual-wield follow-up attack.
	var/is_dual_wield_followup = FALSE

/// Makes the manifested claw undroppable and registers its wound aggravation handler.
/obj/item/raking_claw/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NODROP, REF(src))
	RegisterSignal(src, COMSIG_ITEM_ATTACK_ZONE, PROC_REF(aggrevate_bleeding_wound))
	RegisterSignal(src, COMSIG_ITEM_AFTERATTACK, PROC_REF(try_dual_wield_attack))

/// Reserves the off-hand follow-up before generic dual-wield effects can claim it.
/obj/item/raking_claw/pre_attack(atom/target, mob/living/user, list/modifiers, list/attack_modifiers)
	. = ..()
	if(!. && !attack_modifiers[OFFHAND_ATTACK_CLAIMED] && isliving(target) && istype(user.get_inactive_held_item(), /obj/item/raking_claw))
		attack_modifiers[OFFHAND_ATTACK_CLAIMED] = src

/// Applies a signaler to the target so we can record how much damage we dealt with the claw.
/obj/item/raking_claw/attack(mob/living/target_mob, mob/living/user, list/modifiers, list/attack_modifiers)
	RegisterSignal(target_mob, COMSIG_MOB_AFTER_APPLY_DAMAGE, PROC_REF(record_attack_damage))
	. = ..()
	UnregisterSignal(target_mob, COMSIG_MOB_AFTER_APPLY_DAMAGE)
	return .

/// Records brute damage dealt by this claw so that we can apply the special status effect to bleeding non-carbons.
/obj/item/raking_claw/proc/record_attack_damage(mob/living/source, damage_dealt, damagetype, def_zone, blocked, wound_bonus, exposed_wound_bonus, sharpness, attack_direction, obj/item/attacking_item, wound_clothing)
	SIGNAL_HANDLER
	if(iscarbon(source)) // behaviour unique to non-carbons so we terminate before we do all teh other checks
		return
	if(attacking_item != src || damage_dealt <= 0) // needs to be our weapon and needs to be a successful attack
		return
	if(source.can_bleed(BLOOD_COVER_TURFS) == BLEED_SPLATTER) // if it bleeds, we can dot it.
		source.apply_status_effect(/datum/status_effect/raking_claw_bleeding)

/// Displays a red claw slash centered on the attacked atom instead of swinging the item's sprite from the attacker.
/obj/item/raking_claw/animate_attack(atom/movable/attacker, atom/attacked_atom, animation_type)
	var/image/claw_attack = image(icon = 'icons/effects/effects.dmi', icon_state = "claw")
	claw_attack.color = COLOR_RED
	claw_attack.plane = attacked_atom.plane + 1
	claw_attack.appearance_flags = APPEARANCE_UI
	if(is_dual_wield_followup)
		claw_attack.transform = matrix().Scale(-1, 1)
	var/atom/movable/flick_visual/claw_visual = attacked_atom.flick_overlay_view(claw_attack, 0.5 SECONDS)
	var/matrix/final_transform = matrix(claw_attack.transform).Scale(1.15)
	animate(claw_visual, alpha = 0, transform = final_transform, time = 0.5 SECONDS, easing = CIRCULAR_EASING|EASE_OUT)

/// Rolls the bleed-scaled dual-wield chance and attacks once with the other held claw on success.
/obj/item/raking_claw/proc/try_dual_wield_attack(obj/item/source, atom/target, mob/living/user, list/modifiers, list/attack_modifiers)
	SIGNAL_HANDLER
	var/offhand_attack_claim = attack_modifiers[OFFHAND_ATTACK_CLAIMED]
	// Prevents dual-wield attacks if this is a follow-up attack, if the power isn't active, if the target isn't living, or if the off-hand attack has already been claimed by another source.
	if(is_dual_wield_followup || isnull(manifesting_power) || !isliving(target) || (offhand_attack_claim && offhand_attack_claim != source))
		return
	var/mob/living/living_target = target

	var/obj/item/raking_claw/other_claw
	for(var/obj/item/raking_claw/held_claw in user.held_items)
		if(held_claw != source)
			other_claw = held_claw
			break

	if(isnull(other_claw))
		return

	// Calculates the chance on non-carbon mobs based upon the unique stacking debuf we apply.
	var/effective_bleed_rate = living_target.get_bleed_rate()
	if(!iscarbon(living_target))
		var/datum/status_effect/raking_claw_bleeding/bleeding_effect = living_target.has_status_effect(/datum/status_effect/raking_claw_bleeding)
		effective_bleed_rate = bleeding_effect?.stacks || 0

	// Calculates the chance to make a follow-up with the other claw based on the target's bleed rate
	manifesting_power.rake_final_chance = min(
		manifesting_power.rake_base_chance + effective_bleed_rate * manifesting_power.rake_bleed_mult,
		manifesting_power.rake_max_chance,
	)

	// If we roll it, do another attack.
	if(prob(manifesting_power.rake_final_chance))
		attack_modifiers[OFFHAND_ATTACK_CLAIMED] = source
		other_claw.is_dual_wield_followup = TRUE
		user.do_item_attack_animation(living_target, used_item = other_claw)
		other_claw.attack(living_target, user, modifiers, attack_modifiers)
		other_claw.is_dual_wield_followup = FALSE
	return

/// Attempts to promote an existing slash wound on the limb struck by this claw.
/obj/item/raking_claw/proc/aggrevate_bleeding_wound(obj/item/source, mob/living/target, mob/living/user, target_zone)
	SIGNAL_HANDLER
	if(!iscarbon(target) || isnull(manifesting_power))
		return

	// Gets the targeted body-part
	var/mob/living/carbon/carbon_target = target
	var/obj/item/bodypart/target_limb = carbon_target.get_bodypart(target_zone)
	if(isnull(target_limb))
		return

	// Armor affects aggrevation chance. e.g 40 reduces the aggravation chance by 40% of its base.
	var/target_limb_armor = clamp(carbon_target.getarmor(target_limb, MELEE), 0, 100)
	var/armored_aggrevate_chance = manifesting_power.aggrevate_bleed_chance * (1 - target_limb_armor * 0.01)
	if(!prob(armored_aggrevate_chance))
		return

	// Iterates all wounds that can be upgraded on the target limb
	var/list/upgradeable_wounds = list()
	for(var/datum/wound/slash/flesh/bleeding_wound in target_limb.wounds)
		if(bleeding_wound.severity == WOUND_SEVERITY_MODERATE || bleeding_wound.severity == WOUND_SEVERITY_SEVERE)
			upgradeable_wounds += bleeding_wound

	if(!length(upgradeable_wounds))
		return

	// Picks a random wound and attempts to upgrade it
	var/datum/wound/slash/flesh/selected_wound = pick(upgradeable_wounds)
	var/datum/wound/slash/flesh/upgraded_wound
	if(selected_wound.severity == WOUND_SEVERITY_MODERATE)
		upgraded_wound = new /datum/wound/slash/flesh/severe
	else
		upgraded_wound = new /datum/wound/slash/flesh/critical
	selected_wound.replace_wound(upgraded_wound, attack_direction = get_dir(user, target))

	user.visible_message(
		span_danger("[user] tears the wound on [target]'s [target_limb.plaintext_zone] wide open with [source]!"),
		span_danger("You tear the wound on [target]'s [target_limb.plaintext_zone] wide open with [source]!"),
	)

/*
	Non-carbon bleeding code below. This uses its own stack counter because each application refreshes one shared status.
*/
/datum/status_effect/raking_claw_bleeding
	id = "raking_claw_bleeding"
	duration = 15 SECONDS
	tick_interval = 1 SECONDS
	status_type = STATUS_EFFECT_REFRESH
	alert_type = null
	/// Current severity of the simulated bleeding.
	var/stacks = 1
	/// Maximum severity obtainable from repeated claw hits.
	var/max_stacks = 10
	/// Prevents further full splatters after this application reaches maximum severity.
	var/created_max_stack_splatter = FALSE

/// Refreshes the bleeding duration, adds one stack, and creates a one-time full splatter at maximum severity.
/datum/status_effect/raking_claw_bleeding/refresh(effect, ...)
	. = ..()
	stacks = min(stacks + 1, max_stacks)
	if(stacks < max_stacks || created_max_stack_splatter)
		return
	created_max_stack_splatter = TRUE
	owner.add_splatter_floor(get_turf(owner), small_drip = FALSE)

/// Leaves a blood droplet and has a stack-scaled chance to inflict one brute damage each second.
/datum/status_effect/raking_claw_bleeding/tick(seconds_between_ticks)
	owner.add_splatter_floor(get_turf(owner), small_drip = TRUE)
	if(prob(10 * stacks))
		owner.apply_damage(2, BRUTE)

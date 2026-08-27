/*
	Different version of a melee weapon power. While its comparible to the Armblade, it differs in a few important ways:
	- It deals less damage, has less armor pen but bleeds more and upgrades existing bleed wounds on limbs they strike.
	- Has a built-in dual-wield mechanic that builds momentum through repeated hits.
	- Has a lifeleech mechanic at max stacks, that's more-so catered to mining with double healing from large + a butcher mechanic.
	- Occupies both hands.
	- Doesn't table-break.
*/
/datum/power/aberrant/raking_claws
	name = "Raking Claws"
	desc = "Transform both hands into wicked claws, dropping anything held and preventing you from holding items. Each claw deals 15 damage, has low armor penetration, can strike twice and readily causes and worsens bleeding.\
	\nDamaging living targets grants Bloodlust, with bleeding targets potentially granting an additional stack. Bloodlust stacks up to 10 and decays by 1 every 5 seconds without gaining a stack. Your chance to strike with both claws is 15%, increased by 6% per Bloodlust and an additional 25% against large targets.\
	\nAt maximum Bloodlust, damage to living targets or bloody corpses heals equal brute damage across fleshy bodyparts and your transformed arms, doubled against large targets. Butchering a corpse grants 5 Bloodlust and heals 15 brute damage."
	security_record_text = "Subject can manifest sharp, monstrous claws from their hands."
	security_threat = POWER_THREAT_MAJOR
	value = 6
	magic_flags = POWER_MAGIC_STANDARD
	required_powers = list(/datum/power/aberrant_root/monstrous)
	action_path = /datum/action/cooldown/power/aberrant/raking_claws

/datum/action/cooldown/power/aberrant/raking_claws
	name = "Raking Claws"
	desc = "Reform your hands into deadly, life-leeching claws, dropping everything you are holding. Using the power again retracts them."
	button_icon = 'icons/mob/actions/actions_changeling.dmi'
	button_icon_state = "sting_armblade"
	active = FALSE

	cooldown_time = 50
	cost = ABERRANT_HUNGER_TRIVIAL * 8
	/// Whether the current activation extended the claws and should spend hunger.
	var/raking_claws_extended = FALSE

	/// Base percentage chance for the dual-wield rake attack to trigger.
	var/rake_base_chance = 15
	/// Maximum percentage chance for the dual-wield rake attack to trigger.
	var/rake_max_chance = 100
	/// Percentage added to the dual-wield rake chance per stack of Bloodlust.
	var/rake_bloodlust_mult = 6
	/// Percentage added to the dual-wield rake chance against large targets.
	var/rake_large_target_bonus = 25
	/// Chance per unit of target bleed rate to gain an additional Bloodlust stack.
	var/bloodlust_bleed_mult = 7.5
	/// Brute damage healed per point of post-mitigation damage dealt at maximum Bloodlust.
	var/bloodlust_heal_per_damage = 1
	/// Multiplier applied to maximum-Bloodlust healing against large targets.
	var/bloodlust_large_heal_mult = 2
	/// Final calculated chance for the dual-wield rake attack.
	var/rake_final_chance
	/// How much butchering heals
	var/butcher_heal = 15
	/// How many bloodlust stacks butcher gives
	var/butcher_bloodlust = 5

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
	AddComponent(/datum/component/butchering, butcher_callback = CALLBACK(src, PROC_REF(on_butchering)))

/// Reserves the off-hand follow-up before generic dual-wield effects can claim it.
/obj/item/raking_claw/pre_attack(atom/target, mob/living/user, list/modifiers, list/attack_modifiers)
	. = ..()
	if(!. && !attack_modifiers[OFFHAND_ATTACK_CLAIMED] && isliving(target) && istype(user.get_inactive_held_item(), /obj/item/raking_claw))
		attack_modifiers[OFFHAND_ATTACK_CLAIMED] = src

/// Applies a signaler to the target so successful claw damage can build Bloodlust.
/obj/item/raking_claw/attack(mob/living/target_mob, mob/living/user, list/modifiers, list/attack_modifiers)
	RegisterSignal(target_mob, COMSIG_MOB_AFTER_APPLY_DAMAGE, PROC_REF(record_attack_damage))
	. = ..()
	UnregisterSignal(target_mob, COMSIG_MOB_AFTER_APPLY_DAMAGE)
	return .

/// Grants Bloodlust when this claw damages a living target, with a bleed-scaled chance for an additional stack.
/obj/item/raking_claw/proc/record_attack_damage(mob/living/source, damage_dealt, damagetype, def_zone, blocked, wound_bonus, exposed_wound_bonus, sharpness, attack_direction, obj/item/attacking_item, wound_clothing)
	SIGNAL_HANDLER
	if(attacking_item != src || damage_dealt <= 0)
		return
	if(isnull(manifesting_power))
		return
	var/mob/living/claw_user = get(src, /mob/living)
	if(isnull(claw_user))
		return
	var/datum/status_effect/raking_claw_bloodlust/bloodlust = claw_user.has_status_effect(/datum/status_effect/raking_claw_bloodlust)
	if(source.stat != DEAD)
		var/stacks_to_add = 1 + prob(source.get_bleed_rate() * manifesting_power.bloodlust_bleed_mult)
		claw_user.apply_status_effect(/datum/status_effect/raking_claw_bloodlust, stacks_to_add)
		bloodlust = claw_user.has_status_effect(/datum/status_effect/raking_claw_bloodlust)

	// Bloody corpses deliberately remain valid so the user can keep clawing into them with suitably gory results.
	if(!isnull(bloodlust) && bloodlust.stacks >= bloodlust.max_stacks && (source.stat != DEAD || source.can_bleed(BLOOD_COVER_TURFS) == BLEED_SPLATTER))
		var/healing_multiplier = source.mob_size >= MOB_SIZE_LARGE ? manifesting_power.bloodlust_large_heal_mult : 1 // double healing against large targets
		heal_bloodlust_brute(claw_user, damage_dealt * manifesting_power.bloodlust_heal_per_damage * healing_multiplier)

/// Rewards completing a butcher with Bloodlust and a fixed amount of brute healing.
/obj/item/raking_claw/proc/on_butchering(mob/living/butcher, mob/living/target)
	butcher.apply_status_effect(/datum/status_effect/raking_claw_bloodlust, manifesting_power.butcher_bloodlust)
	heal_bloodlust_brute(butcher, manifesting_power.butcher_heal)
	butcher.visible_message(
		span_warning("[butcher] butchers [target] with a bloodthirsty look!"),
		span_notice("You revel in the bloodshed of tearing [target] apart! You feel invigorated."),
	)

/// Heals organic bodyparts and transformed arms while leaving other prosthetic bodyparts damaged.
/// An exception is made for arms, since flavor-wise you are transforming your arms, which I figure would be a cute way to have situational healing in spite of robotic arms.
/obj/item/raking_claw/proc/heal_bloodlust_brute(mob/living/claw_user, healing_amount)
	if(!iscarbon(claw_user))
		claw_user.adjustBruteLoss(-healing_amount)
		return

	var/mob/living/carbon/carbon_user = claw_user
	var/list/obj/item/bodypart/eligible_bodyparts = list()

	// Populates the limbs that can be healed, including prosthetic arms.
	for(var/obj/item/bodypart/bodypart as anything in carbon_user.bodyparts)
		if(bodypart.brute_dam <= 0)
			continue
		if((bodypart.bodytype & BODYTYPE_ORGANIC) || (bodypart.body_zone in GLOB.arm_zones))
			eligible_bodyparts += bodypart

	// Attempts to heal brute damage on the mob until we healed the max or nothing's left.
	var/remaining_healing = healing_amount
	while(remaining_healing > 0 && length(eligible_bodyparts))
		var/obj/item/bodypart/selected_bodypart = pick(eligible_bodyparts)
		var/brute_before_healing = selected_bodypart.brute_dam
		selected_bodypart.heal_damage(remaining_healing, 0, updating_health = FALSE, required_bodytype = NONE)
		remaining_healing -= brute_before_healing - selected_bodypart.brute_dam
		eligible_bodyparts -= selected_bodypart

	carbon_user.updatehealth()
	carbon_user.update_damage_overlays()

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

/// Rolls the Bloodlust-scaled dual-wield chance and attacks once with the other held claw on success.
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

	var/datum/status_effect/raking_claw_bloodlust/bloodlust = user.has_status_effect(/datum/status_effect/raking_claw_bloodlust)
	var/large_target_bonus = living_target.mob_size >= MOB_SIZE_LARGE ? manifesting_power.rake_large_target_bonus : 0
	manifesting_power.rake_final_chance = min(
		manifesting_power.rake_base_chance + bloodlust?.stacks * manifesting_power.rake_bloodlust_mult + large_target_bonus,
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

/// Attacker-owned momentum that increases the chance of a raking claw follow-up.
/datum/status_effect/raking_claw_bloodlust
	id = "raking_claw_bloodlust"
	duration = STATUS_EFFECT_PERMANENT
	tick_interval = 5 SECONDS
	status_type = STATUS_EFFECT_REFRESH
	alert_type = /atom/movable/screen/alert/status_effect/raking_claw_bloodlust
	show_duration = FALSE
	/// Current Bloodlust intensity.
	var/stacks = 0
	/// Maximum Bloodlust obtainable from repeated claw hits.
	var/max_stacks = 10
	/// Maximum strength of the red screen tint at full Bloodlust.
	var/max_tint_strength = 0.12

/datum/status_effect/raking_claw_bloodlust/on_creation(mob/living/new_owner, stacks_to_add = 1)
	. = ..()
	if(!.)
		return
	AddComponent(/datum/component/speechmod, replacements = list("." = "!"), end_string = "!!", uppercase = TRUE) // YOU SHOUT LIKE THIS BECAUSE YOU ARE IN A FRENZY
	owner.add_client_colour(/datum/client_colour/raking_claw_bloodlust, REF(src))
	adjust_stacks(stacks_to_add)

/// Adds new stacks and restarts the five-second decay delay.
/datum/status_effect/raking_claw_bloodlust/refresh(effect, stacks_to_add = 1)
	. = ..()
	adjust_stacks(stacks_to_add)
	tick_interval = world.time + initial(tick_interval)

/// Removes one stack after five uninterrupted seconds without gaining one.
/datum/status_effect/raking_claw_bloodlust/tick(seconds_between_ticks)
	adjust_stacks(-1)

/datum/status_effect/raking_claw_bloodlust/on_remove()
	owner.remove_client_colour(REF(src))
	return ..()

/datum/status_effect/raking_claw_bloodlust/proc/adjust_stacks(amount)
	stacks = clamp(stacks + amount, 0, max_stacks)
	if(stacks <= 0)
		qdel(src)
		return
	var/tint_strength = max_tint_strength * stacks / max_stacks
	var/datum/client_colour/bloodlust_tint = owner.get_client_colour(REF(src))
	// Red remains unchanged while green and blue are reduced per stack, progressively tinting the screen redder as you RIP AND TEAR.
	bloodlust_tint?.update_color(list(1, 0, 0, 0, 0, 1 - tint_strength, 0, 0, 0, 0, 1 - tint_strength, 0, 0, 0, 0, 1, 0, 0, 0, 0), 0.25 SECONDS, SINE_EASING)
	linked_alert?.maptext = MAPTEXT_TINY_UNICODE("<span style='text-align:center'>[stacks]</span>")

/datum/client_colour/raking_claw_bloodlust
	priority = CLIENT_COLOR_IMPORTANT_PRIORITY
	color = COLOR_MATRIX_IDENTITY
	fade_in = 0.25 SECONDS
	fade_out = 0.5 SECONDS

/atom/movable/screen/alert/status_effect/raking_claw_bloodlust
	name = "Bloodlust"
	desc = "Each stack increases the chance of striking with both raking claws and forces you to shout. At maximum stacks, damaging living targets or bloody corpses heals fleshy bodyparts and your transformed arms. Bloodlust decays while you are not damaging living targets."
	icon = 'icons/mob/actions/actions_ecult.dmi'
	icon_state = "blood_siphon"

/// FIRE FIRE FIRE FIRE

/datum/power/theologist/smite/combusting_smite
	name = "Combusting Smite"
	desc = "Imbues your currently held weapon with flames. Your next melee or ranged attack that connects onto a living target sets the target ablaze. \
	dealing high amounts of burn damage to the target and setitng them on fire. The smite deals 5 + (Piety * 0.3) burn damage to the target, resisted by FIRE armor. The target then is set aflame and receives fire stacks equal to (Piety * 0.1).\
	\nIf you are at or above 25 Piety, the formula for fire stacks becomes (Piety * 0.15) instead. Ranged smites made at this threshold leave a trail of fire in their wake.\
	\nAfter succesfuly smiting a creature, you are immune to being set on fire (but not to burn damage) for 5 seconds.\
	\nUnholy targets take 50% more damage and fire stacks. \
	\nIf the smiting weapon ever leaves your hands, it ends the smiting effect. Goes on a lengthy cooldown on hit."

	security_record_text = "Subject can smite foes with a burst of flame with either a melee weapon or firearm, setting them on fire."
	security_threat = POWER_THREAT_MAJOR
	action_path = /datum/action/cooldown/power/theologist/smite/combusting_smite
	value = 6

	required_powers = list(/datum/power/theologist/root)
	required_allow_subtypes = TRUE

/datum/action/cooldown/power/theologist/smite/combusting_smite
	name = "Combusting Smite"
	desc = "Imbue your weapon with flames. Your next melee or ranged attack that connects onto a living target sets the target ablaze, damaging them and setting them on fire,\
	 scaling with your stored Piety. The smite effect ends if the item leaves your hand."
	button_icon = 'modular_doppler/modular_powers/icons/powers/actions_icons.dmi'
	button_icon_state = "combusting_smite"
	cooldown_time = 2.5 SECONDS

	smite_color = "#FF5E21"

	small_smite_temp_visual = /obj/effect/temp_visual/theologist_smite/combusting
	big_smite_temp_visual = /obj/effect/temp_visual/theologist_smite/combusting/big

	small_smite_sound = 'sound/effects/meteorimpact.ogg' // TODO1
	big_smite_sound = 'modular_doppler/modular_powers/sounds/smite/combusting_smite_big.ogg' // TODO2

	/// Base burn damage dealt by the smite.
	var/damage_base = 5
	/// Additional burn damage dealt for each point of Piety.
	var/damage_per_piety = 0.3
	/// Fire stacks applied per point of Piety below the big smite threshold.
	var/fire_stacks_per_piety = 0.1
	/// Fire stacks applied per point of Piety at or above the big smite threshold.
	var/big_fire_stacks_per_piety = 0.15
	/// Multiplier applied to fire stacks delivered by ranged smites to offset the fire inflicted by the flashfires.
	var/ranged_fire_stacks_multiplier = 0.7
	/// Multiplier applied to the smite's damage and fire stacks against unholy targets.
	var/unholy_multiplier = 1.5
	/// Duration for which the smiter cannot be ignited after a successful smite.
	var/fire_immunity_duration = 5 SECONDS

	/// Tracks whether the current smite projectile has passed through a turf.
	var/projectile_left_fire_trail = FALSE
	/// Whether the current smite projectile creates flashfires.
	var/projectile_creates_fire_trail = FALSE

/// Applies Combusting Smite to a melee target.
/datum/action/cooldown/power/theologist/smite/combusting_smite/melee_smite(obj/item/smite_item, atom/target, mob/living/user, list/modifiers, list/attack_modifiers)
	if(!isliving(target) || target == owner)
		return FALSE

	return combust_target(target)

/// Applies this smite's projectile outline and enables flashfires for big smites.
/datum/action/cooldown/power/theologist/smite/combusting_smite/projectile_fired(obj/projectile/projectile, atom/original_target)
	projectile_left_fire_trail = FALSE
	projectile.add_filter("combusting_smite_outline", 1, outline_filter(size = 1, color = smite_color))
	projectile_creates_fire_trail = get_piety() >= big_smite_req
	if(!projectile_creates_fire_trail)
		return TRUE
	RegisterSignal(projectile, COMSIG_PROJECTILE_MOVE_PROCESS_STEP, PROC_REF(on_projectile_moved))
	return TRUE

/// Applies Combusting Smite to a projectile target and creates an impact flashfire if it did not already create one on that space.
/datum/action/cooldown/power/theologist/smite/combusting_smite/projectile_hit(obj/projectile/projectile, atom/movable/firer, atom/target, angle, hit_limb, blocked, pierce_hit)
	if(projectile_creates_fire_trail && !projectile_left_fire_trail)
		leave_projectile_flashfire(projectile)
	if(!isliving(target) || target == owner)
		return FALSE

	return combust_target(target, is_ranged = TRUE)

/// Creates a flashfire on the turf occupied by a smite projectile.
/datum/action/cooldown/power/theologist/smite/combusting_smite/proc/on_projectile_moved(obj/projectile/projectile)
	SIGNAL_HANDLER

	projectile_left_fire_trail = TRUE
	leave_projectile_flashfire(projectile)

/// Creates the fire left behind by a smite projectile.
/datum/action/cooldown/power/theologist/smite/combusting_smite/proc/leave_projectile_flashfire(obj/projectile/projectile)
	var/turf/projectile_turf = get_turf(projectile)
	if(!projectile_turf)
		return

	new /obj/effect/hotspot(projectile_turf)
	projectile_turf.hotspot_expose(700, 50, TRUE)

/// Deals burn damage, ignites a living target, and grants the smiter temporary fire immunity.
/datum/action/cooldown/power/theologist/smite/combusting_smite/proc/combust_target(mob/living/target, is_ranged = FALSE)
	if(target.can_block_resonance(1))
		return TRUE

	var/damage_dealt = apply_combusting_damage(target)
	var/fire_stacks = get_fire_stacks(target, is_ranged)
	target.adjust_fire_stacks(fire_stacks)
	target.ignite_mob()
	grant_fire_immunity()
	target.visible_message(
		span_warning("[target] bursts into flame!"),
		span_userdanger("You burst into flame!"),
	)
	to_chat(owner, span_warning("You smite [target] with holy flame!"))
	log_combat(owner, target, "smote", addition = "for [damage_dealt] burn damage and [fire_stacks] fire stacks", object = src)
	return TRUE

/// Applies the smite's damage
/datum/action/cooldown/power/theologist/smite/combusting_smite/proc/apply_combusting_damage(mob/living/target)
	/// base dmg
	var/damage = damage_base + get_piety() * damage_per_piety
	// armor check
	var/armor_block = target.run_armor_check(attack_flag = FIRE, silent = TRUE)
	damage *= 1 - (armor_block / 100)
	// unholy mult
	var/datum/power/theologist/theologist_power = origin_power
	if(theologist_power?.is_unholy(target))
		damage *= unholy_multiplier
	return target.apply_damage(damage, BURN)

/// Calculates the number of fire stacks applied by the smite.
/datum/action/cooldown/power/theologist/smite/combusting_smite/proc/get_fire_stacks(mob/living/target, is_ranged = FALSE)
	var/fire_stacks_per_point = get_piety() >= big_smite_req ? big_fire_stacks_per_piety : fire_stacks_per_piety
	var/fire_stacks = get_piety() * fire_stacks_per_point
	// flashfires do ignite by themself so you get a penalty to the burn to offset that.
	if((is_ranged) && (get_piety >= big_smite_reg))
		fire_stacks *= ranged_fire_stacks_multiplier
	// unholy mult
	var/datum/power/theologist/theologist_power = origin_power
	if(theologist_power?.is_unholy(target))
		fire_stacks *= unholy_multiplier
	return fire_stacks

/// Prevents the smiter from being ignited for a short duration.
/datum/action/cooldown/power/theologist/smite/combusting_smite/proc/grant_fire_immunity()
	if(!owner)
		return

	ADD_TRAIT(owner, TRAIT_NOFIRE, REF(src))
	addtimer(TRAIT_CALLBACK_REMOVE(owner, TRAIT_NOFIRE, REF(src)), fire_immunity_duration)

/obj/effect/temp_visual/theologist_smite/combusting
	icon_state = "mech_fire"

/obj/effect/temp_visual/theologist_smite/combusting/big
	icon = 'modular_doppler/modular_powers/icons/powers/64x64.dmi'
	duration = 10
	randomdir = FALSE
	pixel_x = -16
	pixel_y = -16
	icon_state = "combusting_smite_big"
	duration = 0.6 SECONDS

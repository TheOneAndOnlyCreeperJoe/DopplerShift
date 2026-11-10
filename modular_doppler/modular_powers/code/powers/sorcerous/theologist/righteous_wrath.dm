/*
	Shoot semi-homing projectiles in a direction: these home towards an unholy target, and cannot injure anything else. Scales with Piety for damage.
*/
/// TODO: to_chat messages and other feedback. Orbitals while channeling?
/datum/power/theologist/righteous_wrath
	name = "Wrath of the Righteous"
	desc = "Bring forth justice that casts down the unholy and the condemned.\
	\nChannel to fire 3 slow moving projectiles after 2 seconds. The projectiles home and lock onto the unholy target that you can see closest to where you clicked. This passes through other mobs and cannot injure anything that is not an unholy target. It does not damage structures. \
	On hit, it deals 10 + (Piety * 0.2) burn damage. This projectile has a high amount of armour pierce and is affected by the target's laser resistance. Deals drastically increased damage against mining mobs.\
	\nMoving or performing other actions will cancel the channel."
	security_record_text = "Subject can shoot homing projectiles of light that only strike those deemned unholy."
	security_threat = POWER_THREAT_MAJOR
	value = 4

	action_path = /datum/action/cooldown/power/theologist/righteous_wrath
	required_powers = list(/datum/power/theologist/root)
	required_allow_subtypes = TRUE

	power_flags = POWER_HUMAN_ONLY
	gives_unholy_sight = TRUE

/// Partially lifted from Magical Barrage
/datum/action/cooldown/power/theologist/righteous_wrath
	name = "Wrath of the Righteous"
	desc = "Channel and fire three slow moving projectiles after a 2 second delay, homing in on an unholy target, dealing burn damage and piercing armour. Scales with Piety. Taking any action while channeling stops the effect."
	button_icon = 'modular_doppler/modular_powers/icons/powers/actions_icons.dmi'
	button_icon_state = "righteous_wrath"

	cooldown_time = 3 SECONDS

	target_range = 14
	use_time = 2 SECONDS // the windup.
	use_time_flags = IGNORE_TARGET_LOC_CHANGE

	click_to_activate = TRUE
	anti_magic_on_target = FALSE

	/// The projectile we fire
	var/obj/projectile/projectile_path = /obj/projectile/resonant/righteous_wrath

	/// How much damage does a single point of Piety add.
	var/piety_scaling = 0.2
	/// How many projectiles we shoot before we stop casting
	var/max_projectiles = 3
	/// How long we wait per projectile to fire.
	var/projectile_wait = 0.33 SECONDS
	/// How long does the spell go on cooldown if we fumble the cast time.
	var/fumble_cooldown = 2 SECONDS

	/// How many projectiles we have already shot
	var/proj_count = 0
	/// The casting overlay displayed while righteous wrath is channelled.
	var/mutable_appearance/casting_overlay
	/// The unholy mob selected by the activation click.
	var/mob/living/chosen_target
	/// The beam connecting the caster to the selected target during the effect.
	var/datum/beam/target_beam
	/// The aiming overlay displayed over the selected target.
	var/obj/effect/overlay/righteous_wrath_aim/aim_overlay
	/// The target currently displaying the aiming overlay.
	var/mob/living/aim_target
	/// Identifies the active aiming overlay for delayed threshold updates.
	var/aim_overlay_state = 0

/// We lapse this into do_use_time because we haven't actually started doing harm yet.
/datum/action/cooldown/power/theologist/righteous_wrath/do_use_time(mob/living/user, atom/target)
	chosen_target = find_cursor_unholy_target(user, target)
	if(!chosen_target)
		return FALSE
	target = chosen_target // makes the progress bar appear over the target.
	target.visible_message(span_warning("[user] is channeling a spell at [chosen_target]!"),
			span_userdanger("[user] is channeling a spell at you!"), span_warning("You hear the sound of something charging up!"))
	target_beam = user.Beam(chosen_target, icon_state = "1-full", beam_color = POWER_COLOR_THEOLOGIST, beam_type = /obj/effect/ebeam/righteous_wrath, layer = BELOW_MOB_LAYER)
	begin_aim_overlay(chosen_target)
	var/current_aim_overlay_state = aim_overlay_state // Tracks which state we're currently in with teh aim marker
	addtimer(CALLBACK(src, PROC_REF(set_aim_overlay_state), current_aim_overlay_state, "aim25"), use_time * 0.25)
	addtimer(CALLBACK(src, PROC_REF(set_aim_overlay_state), current_aim_overlay_state, "aim50"), use_time * 0.5)
	addtimer(CALLBACK(src, PROC_REF(set_aim_overlay_state), current_aim_overlay_state, "aim75"), use_time * 0.75)
	addtimer(CALLBACK(src, PROC_REF(set_aim_overlay_state), current_aim_overlay_state, "aim100"), use_time)
	playsound(owner, 'modular_doppler/modular_powers/sounds/righteous_wrath/chargeup.ogg', 60, FALSE)
	active = TRUE // means the signalers listen to dispels whilst this is happening
	user.face_atom(chosen_target)
	. = ..()
	if(!.)
		active = FALSE
		end_channel(user)
		chosen_target = null
		StartCooldownSelf(fumble_cooldown) // slight cooldown to spam

// love beam mechanics: just here to control its appearance
/obj/effect/ebeam/righteous_wrath
	alpha = 150
	layer = BELOW_MOB_LAYER

/obj/effect/overlay/righteous_wrath_aim
	icon = 'modular_doppler/modular_powers/icons/powers/effects.dmi'
	icon_state = "aim0"
	color = POWER_COLOR_THEOLOGIST
	layer = ABOVE_MOB_LAYER
	vis_flags = VIS_INHERIT_PLANE
	appearance_flags = RESET_TRANSFORM
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT

/// Channels righteous bolts at the unholy mob nearest the activation click.
/datum/action/cooldown/power/theologist/righteous_wrath/use_action(mob/living/user, atom/target)
	if(!chosen_target)
		return FALSE
	begin_channel(user)

	while(active)
		// Checks if we're interupted
		if(!do_after(owner, projectile_wait, target = chosen_target, timed_action_flags = IGNORE_TARGET_LOC_CHANGE, hidden = TRUE, progress = FALSE))
			break
		// A dispel can occur while do_after is running, so check before applying another tick.
		if(!active)
			break
		// ENOUGH MISSILES!
		if(proj_count >= max_projectiles)
			break
		// FIRE ZE MISSILES!
		user.face_atom(chosen_target)
		if(!fire_projectile(user, chosen_target, projectile_path))
			break // STOP ZE MISSILES ZOMETHING WENT WRONG-
		user.visible_message(span_warning("[user] shoots a [initial(projectile_path.name)]!"))
		playsound(owner, 'modular_doppler/modular_powers/sounds/righteous_wrath/righteous.ogg', 60, TRUE)
		proj_count++

	// Reset
	active = FALSE
	end_channel(user)
	chosen_target = null
	if(proj_count <= 0)
		return FALSE

	proj_count = 0
	return TRUE

/// Adds the casting overlay for the duration of the channel.
/datum/action/cooldown/power/theologist/righteous_wrath/proc/begin_channel(mob/living/user)
	var/atom/overlay_obj = new /obj/effect/temp_visual/casting(null)
	casting_overlay = new /mutable_appearance(overlay_obj)
	qdel(overlay_obj)
	casting_overlay.color = GLOB.power_paths_by_define[origin_power?.path]?.theme_color
	user.add_overlay(casting_overlay)

/// Removes the casting overlay after the channel ends.
/datum/action/cooldown/power/theologist/righteous_wrath/proc/end_channel(mob/living/user)
	if(casting_overlay && !QDELETED(user))
		user.cut_overlay(casting_overlay)
	casting_overlay = null
	if(aim_overlay)
		if(!QDELETED(aim_target))
			aim_target.vis_contents -= aim_overlay
		QDEL_NULL(aim_overlay)
	aim_target = null
	aim_overlay_state++
	QDEL_NULL(target_beam)

/// Displays a rotating aim marker ontop the selected target.
/datum/action/cooldown/power/theologist/righteous_wrath/proc/begin_aim_overlay(mob/living/target)
	aim_overlay_state++
	aim_target = target
	aim_overlay = new
	target.vis_contents += aim_overlay
	aim_overlay.SpinAnimation()

/// Updates the current aim marker
/datum/action/cooldown/power/theologist/righteous_wrath/proc/set_aim_overlay_state(overlay_state, icon_state)
	if(overlay_state != aim_overlay_state || !aim_overlay || QDELETED(aim_target))
		return
	aim_overlay.icon_state = icon_state

/// Finds the nearest visible unholy mob to the clicked location
/datum/action/cooldown/power/theologist/righteous_wrath/proc/find_cursor_unholy_target(mob/living/user, atom/clicked_target)
	/// Gets the nearest target for homing projectiiiiles.
	var/turf/cursor_turf = get_turf(clicked_target) || get_turf(user)
	if(!cursor_turf)
		return
	var/datum/power/theologist/theologist_source_power = origin_power
	var/mob/living/closest_unholy_target
	var/closest_distance = INFINITY
	/// Iterates all viewers in range, returns the ones closest to the mouse.
	for(var/mob/living/possible_target in view(user))
		if(!theologist_source_power?.is_unholy(possible_target))
			continue
		var/target_distance = get_dist(cursor_turf, possible_target)
		if(target_distance >= closest_distance)
			continue
		closest_unholy_target = possible_target
		closest_distance = target_distance

	/// This MF's gonna get it.
	return closest_unholy_target

// the projectile in question
/obj/projectile/resonant/righteous_wrath
	name = "righteous bolt"
	icon_state = "blastwave"
	damage = 10 // scales with Piety
	damage_type = BURN
	armour_penetration = 50
	speed = 0.5
	hitsound = 'sound/items/weapons/sear.ogg'
	armor_flag = LASER
	pass_flags = PASSTABLE | PASSGLASS | PASSGRILLE // unfortunately for you this is a magical LASER
	/// Tracker to prevents applying the mining bonus multiple times.
	var/mining_target_bonus_applied = FALSE

/// Gets current piety, scales damage and makes projectiles hooome.
/obj/projectile/resonant/righteous_wrath/snapshot_power_state(datum/action/cooldown/power/power)
	var/datum/action/cooldown/power/theologist/righteous_wrath/theologist_power = power
	var/datum/component/theologist_piety/piety_component = theologist_power.piety_component

	if(!isnull(piety_component?.piety))
		damage += piety_component.piety * theologist_power.piety_scaling

/// Sets a righteous bolt to home onto its selected unholy target.
/datum/action/cooldown/power/theologist/righteous_wrath/ready_projectile(obj/projectile/projectile_instance, atom/target, mob/living/user)
	. = ..()
	if(!isliving(target))
		return
	var/mob/living/living_target = target
	var/datum/power/theologist/theologist_source_power = origin_power
	if(!theologist_source_power?.is_unholy(living_target))
		return
	projectile_instance.homing_turn_speed = 2
	projectile_instance.homing_inaccuracy_min = 2
	projectile_instance.homing_inaccuracy_max = 6
	projectile_instance.set_homing_target(living_target)

/// Phases through non-unholy living mobs and buffs it against mining mobs.
/obj/projectile/resonant/righteous_wrath/prehit_pierce(atom/target)
	if(isliving(target))
		var/mob/living/living_target = target
		var/datum/action/cooldown/power/theologist/righteous_wrath/theologist_action = creating_power
		var/datum/power/theologist/theologist_source_power = theologist_action?.origin_power
		if(theologist_source_power && !theologist_source_power.is_unholy(living_target))
			return PROJECTILE_PIERCE_PHASE
		if(ismining(living_target) && !mining_target_bonus_applied)
			// Basically just here to spite ranged armour, given that ranged armour gives out at 30 dmg.
			damage += 20
			mining_target_bonus_applied = TRUE
	return ..()

/// Stops the bolt on structures without damage.
/obj/projectile/resonant/righteous_wrath/on_hit(atom/target, blocked = 0, pierce_hit)
	if(isstructure(target))
		if(impact_effect_type && !hitscan)
			new impact_effect_type(get_turf(target), entry_x, entry_y)
		return BULLET_ACT_BLOCK
	return ..()

// Dispel functionality
/datum/action/cooldown/power/theologist/righteous_wrath/Grant(mob/granted_to)
	. = ..()
	if(is_magical())
		RegisterSignal(granted_to, COMSIG_ATOM_DISPEL, PROC_REF(on_dispel))

/datum/action/cooldown/power/theologist/righteous_wrath/Remove(mob/removed_from)
	. = ..()
	if(is_magical())
		UnregisterSignal(removed_from, COMSIG_ATOM_DISPEL)

/// On dispel, poof there go your orbitals.
/datum/action/cooldown/power/theologist/righteous_wrath/proc/on_dispel(mob/owner, atom/dispeller)
	SIGNAL_HANDLER
	if(!active)
		return NONE
	active = FALSE
	end_channel(owner)
	to_chat(owner, span_userdanger("Your focus is disrupted!"))
	StartCooldownSelf()
	return DISPEL_RESULT_DISPELLED

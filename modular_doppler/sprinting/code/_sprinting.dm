/// Adds the sprinting component to everyone.
/mob/living/carbon/human/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/sprinting)

/// Tracks sprint energy for a mob and displays its current level on the HUD.
/datum/component/sprinting
	dupe_mode = COMPONENT_DUPE_UNIQUE

	/// The mob whose movement and HUD this component manages.
	var/mob/living/carbon/human/sprint_owner
	/// The current amount of sprint energy available.
	var/energy = SPRINT_ENERGY_MAXIMUM
	/// The maximum amount of sprint energy that can be stored.
	var/max_energy = SPRINT_ENERGY_MAXIMUM
	/// The amount of energy drained per second while moving.
	var/energy_drain_per_second = 4
	/// The additional amount of energy drained for each tile moved between ticks.
	var/energy_drain_per_tile = 2
	/// The delay after draining energy before regeneration begins.
	var/energy_regen_delay = 4 SECONDS
	/// The amount of energy restored by each regeneration tick.
	var/energy_regen_amount = 6.67
	/// The interval between sprint-energy regeneration ticks.
	var/energy_regen_interval = 1 SECONDS
	/// The stamina damage taken for each sprint-energy point that cannot be paid.
	var/stamina_drain_per_energy = SPRINT_STAMINA_DRAIN_PER_ENERGY
	/// The fraction of maximum stamina required to continue running.
	var/minimum_stamina_fraction = 0.25
	/// The sprint energy changed for each point of stamina adjustment.
	var/energy_per_stamina_damage = SPRINT_ENERGY_PER_STAMINA_DAMAGE
	/// The momentum lost for each point of qualifying stamina damage.
	var/momentum_damage_per_stamina_damage = SPRINT_MOMENTUM_DAMAGE_PER_STAMINA_DAMAGE
	/// The minimum effective stamina damage that can reduce momentum.
	var/momentum_damage_stamina_threshold = SPRINT_MOMENTUM_STAMINA_DAMAGE_MIN
	/// The world time at which energy was last successfully drained.
	var/last_energy_loss_time = 0
	/// The number of tiles moved since sprint energy was last drained.
	var/tiles_moved = 0
	/// The number of consecutive processing ticks without a recorded running movement.
	var/consecutive_stalled_ticks = 0
	/// The current amount of momentum built up through movement.
	var/momentum = SPRINT_MOMENTUM_MINIMUM
	/// The maximum amount of momentum that can be stored.
	var/max_momentum = SPRINT_MOMENTUM_MAXIMUM
	/// The base momentum gained from moving in the current direction.
	var/momentum_gain_base = 10
	/// The fraction of current momentum gained from moving in the current direction.
	var/momentum_gain_current_multiplier = 0.2
	/// The maximum fraction of momentum retained after a 45-degree turn.
	var/momentum_diagonal_turn_threshold = 0.5
	/// The maximum fraction of momentum retained after a 90-degree turn.
	var/momentum_right_angle_turn_threshold = 0.25
	/// The direction currently used to evaluate momentum-building movement.
	var/momentum_direction

	/// The delay before an empty momentum bar is hidden.
	var/momentum_bar_hide_delay = 2 SECONDS
	/// Whether the momentum bar is currently eligible to appear on the HUD.
	var/momentum_bar_visible = FALSE
	/// The pending timer that hides an empty momentum bar.
	var/momentum_bar_hide_timer

	/// The athletics experience earned for each second spent sprinting.
	var/athletics_experience_per_second = 2
	/// The fraction by which each athletics level above None reduces sprint energy drain.
	var/athletics_energy_drain_reduction_per_level = SPRINT_ATHLETICS_ENERGY_DRAIN_REDUCTION_PER_LEVEL
	/// The energy display installed on the owner's HUD.
	var/atom/movable/screen/sprint_energy/energy_display
	/// The momentum display installed on the owner's HUD.
	var/atom/movable/screen/sprint_momentum/momentum_display

/datum/component/sprinting/Initialize()
	if(!ishuman(parent))
		return COMPONENT_INCOMPATIBLE

	sprint_owner = parent

/datum/component/sprinting/RegisterWithParent()
	. = ..()
	RegisterSignal(sprint_owner, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))
	RegisterSignal(sprint_owner, COMSIG_MOVE_INTENT_TOGGLED, PROC_REF(on_move_intent_toggled))
	RegisterSignal(sprint_owner, COMSIG_LIVING_ADJUST_STAMINA_DAMAGE, PROC_REF(on_adjust_stamina_damage))
	RegisterSignal(sprint_owner, COMSIG_LIVING_POST_FULLY_HEAL, PROC_REF(on_fully_healed))
	// Since walk is now the norm with this we force mobs that use sprint to start with walk intent.
	if(sprint_owner.move_intent == MOVE_INTENT_RUN)
		sprint_owner.toggle_move_intent()

	update_momentum_slowdown()
	if(sprint_owner.hud_used)
		install_energy_hud()
	else
		RegisterSignal(sprint_owner, COMSIG_MOB_HUD_CREATED, PROC_REF(on_hud_created))

/datum/component/sprinting/UnregisterFromParent()
	. = ..()
	UnregisterSignal(sprint_owner, list(COMSIG_MOVABLE_MOVED, COMSIG_MOVE_INTENT_TOGGLED, COMSIG_MOB_HUD_CREATED, COMSIG_LIVING_ADJUST_STAMINA_DAMAGE, COMSIG_LIVING_POST_FULLY_HEAL))

/datum/component/sprinting/Destroy(force)
	STOP_PROCESSING(SSfastprocess, src)
	if(momentum_bar_hide_timer)
		deltimer(momentum_bar_hide_timer)
		momentum_bar_hide_timer = null
	sprint_owner?.remove_movespeed_modifier(/datum/movespeed_modifier/sprinting)
	remove_energy_hud()
	. = ..()
	sprint_owner = null
	return .

/// Installs the sprint-energy display after the owner's HUD has been created.
/datum/component/sprinting/proc/on_hud_created(datum/source)
	SIGNAL_HANDLER
	install_energy_hud()

/// Updates the sprint slowdown after the owner changes movement intent.
/datum/component/sprinting/proc/on_move_intent_toggled(mob/living/source)
	SIGNAL_HANDLER
	if(source != sprint_owner)
		return

	update_momentum_slowdown()

/// Converts stamina adjustments into sprint energy and momentum changes.
/datum/component/sprinting/proc/on_adjust_stamina_damage(mob/living/source, damage_type, amount, forced)
	SIGNAL_HANDLER
	if(source != sprint_owner || !isnum(amount))
		return

	adjust_energy(-(amount * energy_per_stamina_damage))
	// To prevent denting our own momentum when running with stamina, momentum isn't dented until it takes a chunk of stamina damage, which is usually enough to stop someone's sprint.
	if(amount >= momentum_damage_stamina_threshold)
		adjust_momentum(-(amount * momentum_damage_per_stamina_damage))

/// Restores all sprint energy after the owner receives a full heal.
/datum/component/sprinting/proc/on_fully_healed(mob/living/source, heal_flags)
	SIGNAL_HANDLER
	if(source != sprint_owner)
		return

	adjust_energy(max_energy - energy)

/// Records a running movement for sprint-energy processing.
/datum/component/sprinting/proc/on_moved(mob/living/carbon/human/source, atom/old_loc, movement_dir, forced, list/old_locs, momentum_change)
	SIGNAL_HANDLER
	if(source != sprint_owner || source.move_intent != MOVE_INTENT_RUN)
		return
	// Forced movement, drifting and being thrown does not count as movement.
	if(forced || source.inertia_moving || source.throwing)
		return

	var/turf/old_turf = get_turf(old_loc)
	var/turf/new_turf = get_turf(source)
	if(isnull(old_turf) || isnull(new_turf) || old_turf == new_turf || get_dist(old_turf, new_turf) != 1)
		return

	tiles_moved++
	// Preserve the player's combined input so a held diagonal does not become alternating cardinal turns.
	var/current_direction = source.client?.intended_direction
	if(!current_direction)
		current_direction = movement_dir
	if(!current_direction)
		current_direction = get_dir(old_turf, new_turf)
	update_momentum(current_direction)
	START_PROCESSING(SSfastprocess, src)

/// Drains sprint energy for movement recorded during the current processing tick.
/datum/component/sprinting/process(seconds_per_tick)
	var/moved_this_tick = tiles_moved > 0
	if(moved_this_tick)
		consecutive_stalled_ticks = 0
		// Gets and applies the base athletics reduction
		var/athletics_level = sprint_owner.mind?.get_skill_level(/datum/skill/athletics) || SKILL_LEVEL_NONE
		var/athletics_drain_reduction = clamp((athletics_level - SKILL_LEVEL_NONE) * athletics_energy_drain_reduction_per_level, 0, 1)

		// Gets how much energy we should drain.
		// Basically the flat drain per second + every tile moved * seconds_per_tick * athletics level modifier
		var/energy_drain = (energy_drain_per_second + (energy_drain_per_tile * tiles_moved)) * seconds_per_tick * (1 - athletics_drain_reduction)
		var/list/energy_drain_modifiers = list()
		SEND_SIGNAL(sprint_owner, COMSIG_SPRINTING_ENERGY_DRAIN, energy_drain, energy_drain_modifiers)
		energy_drain = apply_percentage_modifiers(energy_drain, energy_drain_modifiers)
		adjust_energy(-energy_drain, null, TRUE)
		sprint_owner.mind?.adjust_experience(/datum/skill/athletics, athletics_experience_per_second * seconds_per_tick) // Gain experience for going on a jog

		// Save energy-loss to reference later.
		last_energy_loss_time = world.time
		addtimer(CALLBACK(src, PROC_REF(regenerate_energy)), energy_regen_delay, TIMER_UNIQUE | TIMER_OVERRIDE)
	// stall timer to see if we should start draining momentum
	else
		consecutive_stalled_ticks++
		if(consecutive_stalled_ticks >= 2)
			adjust_momentum(-(max_momentum * seconds_per_tick * 2))
		if(momentum <= SPRINT_MOMENTUM_MINIMUM)
			momentum_direction = null
			STOP_PROCESSING(SSfastprocess, src)

	tiles_moved = 0

/// Drains stamina as a consequence of sprinting and forces the owner to walk when too little stamina remains.
/datum/component/sprinting/proc/drain_stamina(amount)
	if(amount <= 0)
		return

	sprint_owner.adjustStaminaLoss(amount)
	// Checks if we still have enough stam to keep sprinting.
	var/remaining_stamina = sprint_owner.max_stamina - sprint_owner.getStaminaLoss()
	if(remaining_stamina > sprint_owner.max_stamina * minimum_stamina_fraction || sprint_owner.move_intent != MOVE_INTENT_RUN)
		return

	// We're too low on stam so we stop sprinting.
	sprint_owner.balloon_alert(sprint_owner, "no more stamina!")
	to_chat(sprint_owner, span_userdanger("You can no longer run!"))
	sprint_owner.toggle_move_intent()

/// Builds momentum while traveling in the same direction and limits it after turns.
/datum/component/sprinting/proc/update_momentum(new_direction)
	if(isnull(momentum_direction) || new_direction == momentum_direction)
		adjust_momentum(momentum_gain_base + (momentum * momentum_gain_current_multiplier))
	else
		var/turn_angle = abs(closer_angle_difference(dir2angle(momentum_direction), dir2angle(new_direction)))
		var/turn_threshold = SPRINT_MOMENTUM_MINIMUM
		var/list/turn_loss_modifiers = list()
		SEND_SIGNAL(sprint_owner, COMSIG_SPRINTING_TURNED, turn_angle, turn_loss_modifiers)
		if(turn_angle == 45)
			turn_threshold = max_momentum * momentum_diagonal_turn_threshold
		else if(turn_angle == 90)
			turn_threshold = max_momentum * momentum_right_angle_turn_threshold
		var/turn_momentum_loss = min(momentum, turn_threshold) - momentum
		adjust_momentum(apply_percentage_modifiers(turn_momentum_loss, turn_loss_modifiers))

	momentum_direction = new_direction

/// Changes momentum within its valid range and updates the momentum HUD display.
/datum/component/sprinting/proc/adjust_momentum(amount)
	if(!isnum(amount) || !amount)
		return

	var/list/change_modifiers = list()
	SEND_SIGNAL(sprint_owner, COMSIG_SPRINTING_MOMENTUM_CHANGE, amount, change_modifiers)
	var/modified_amount = apply_percentage_modifiers(amount, change_modifiers)
	if(!modified_amount)
		return

	momentum = clamp(momentum + modified_amount, SPRINT_MOMENTUM_MINIMUM, max_momentum)
	if(momentum > SPRINT_MOMENTUM_MINIMUM)
		momentum_bar_visible = TRUE
		if(momentum_bar_hide_timer)
			deltimer(momentum_bar_hide_timer)
			momentum_bar_hide_timer = null
	else if(momentum_bar_visible && !momentum_bar_hide_timer)
		momentum_bar_hide_timer = addtimer(CALLBACK(src, PROC_REF(hide_momentum_bar)), momentum_bar_hide_delay, TIMER_UNIQUE | TIMER_STOPPABLE)
	update_momentum_slowdown()
	momentum_display?.update_momentum(momentum, max_momentum)
	update_hud_visibility()

/// Hides the momentum bar when its momentum has remained empty through the hide delay.
/datum/component/sprinting/proc/hide_momentum_bar()
	momentum_bar_hide_timer = null
	if(momentum > SPRINT_MOMENTUM_MINIMUM)
		return

	momentum_bar_visible = FALSE
	update_hud_visibility()

/// Applies the run-intent delay penalty reduced by the owner's current momentum.
/datum/component/sprinting/proc/update_momentum_slowdown()
	if(isnull(sprint_owner))
		return

	if(sprint_owner.move_intent != MOVE_INTENT_RUN)
		sprint_owner.remove_movespeed_modifier(/datum/movespeed_modifier/sprinting)
		return

	var/momentum_fraction = clamp(momentum * 0.01, 0, 1)
	var/run_penalty = SPRINT_RUN_PENALTY * (1 - momentum_fraction)
	var/full_momentum_bonus = SPRINT_MOMENTUM_BONUS
	var/list/speed_bonus_modifiers = list()
	SEND_SIGNAL(sprint_owner, COMSIG_SPRINTING_SPEED_BONUS, speed_bonus_modifiers)
	for(var/speed_bonus_modifier in speed_bonus_modifiers)
		if(isnum(speed_bonus_modifier))
			full_momentum_bonus += speed_bonus_modifier
	var/momentum_bonus = full_momentum_bonus * momentum_fraction
	sprint_owner.add_or_update_variable_movespeed_modifier(/datum/movespeed_modifier/sprinting, multiplicative_slowdown = run_penalty - momentum_bonus)

/// Applies the sprinting run-intent delay penalty independently of no-slow immunity.
/datum/movespeed_modifier/sprinting
	variable = TRUE
	flags = IGNORE_NOSLOW

/// Restores sprint energy after the recovery delay has elapsed.
/datum/component/sprinting/proc/regenerate_energy()
	if(QDELETED(sprint_owner) || energy >= max_energy)
		return

	var/time_since_energy_loss = world.time - last_energy_loss_time
	if(time_since_energy_loss < energy_regen_delay) // too short
		addtimer(CALLBACK(src, PROC_REF(regenerate_energy)), energy_regen_delay - time_since_energy_loss, TIMER_UNIQUE | TIMER_OVERRIDE)
		return
	if(sprint_owner.getStaminaLoss() > 0) // no regen while you have stamloss
		addtimer(CALLBACK(src, PROC_REF(regenerate_energy)), energy_regen_interval, TIMER_UNIQUE | TIMER_OVERRIDE)
		return

	adjust_energy(energy_regen_amount)
	if(energy < max_energy)
		addtimer(CALLBACK(src, PROC_REF(regenerate_energy)), energy_regen_interval, TIMER_UNIQUE | TIMER_OVERRIDE)

/// Changes sprint energy within its valid range or an optional override cap and can convert unpaid drain into stamina damage.
/datum/component/sprinting/proc/adjust_energy(amount, override_cap, stamina_if_empty = FALSE)
	if(!isnum(amount) || !amount)
		return 0

	// Gets any percentage modifiers to energy changes.
	var/list/energy_drain_modifiers = list()
	SEND_SIGNAL(sprint_owner, COMSIG_SPRINTING_ENERGY_CHANGE, amount, energy_drain_modifiers)
	amount = apply_percentage_modifiers(amount, energy_drain_modifiers)

	// If it should lapse into stamina loss
	if(stamina_if_empty && amount < 0)
		// Calcs if we would have enough to avoid lapsing into stamina
		var/energy_paid = min(energy, -amount)
		var/exhausted_energy = -amount - energy_paid
		amount = -energy_paid
		if(exhausted_energy)
			drain_stamina(exhausted_energy * stamina_drain_per_energy)
	if(!amount)
		return 0

	// Actually drains the energy
	var/cap_to = isnum(override_cap) ? override_cap : max_energy
	energy = clamp(energy + amount, SPRINT_ENERGY_MINIMUM, cap_to)
	energy_display?.update_energy(energy, max_energy)
	update_hud_visibility()
	return amount

/// Applies percentage modifiers multiplicatively to the specified amount.
/datum/component/sprinting/proc/apply_percentage_modifiers(amount, list/modifier_percents)
	var/modified_amount = amount
	for(var/modifier_percent in modifier_percents)
		if(isnum(modifier_percent))
			modified_amount *= 1 + (modifier_percent / 100)

	return modified_amount

/// Creates the sprint displays and keeps the native stamina display visible for the owner's lifetime.
/datum/component/sprinting/proc/install_energy_hud()
	if(energy_display || isnull(sprint_owner?.hud_used))
		return

	var/datum/hud/owner_hud = sprint_owner.hud_used
	if(owner_hud.stamina && !(owner_hud.stamina in owner_hud.infodisplay))
		owner_hud.infodisplay += owner_hud.stamina
	sprint_owner.update_stamina_hud()
	energy_display = new(null, owner_hud)
	momentum_display = new(null, owner_hud)
	energy_display.update_energy(energy, max_energy)
	momentum_display.update_momentum(momentum, max_momentum)
	update_hud_visibility()

/// Updates visibility of the sprint energy and momentum displays.
/datum/component/sprinting/proc/update_hud_visibility()
	if(isnull(energy_display) || isnull(momentum_display) || isnull(sprint_owner?.hud_used))
		return

	var/datum/hud/owner_hud = sprint_owner.hud_used
	var/hud_changed = FALSE
	if(!(energy_display in owner_hud.infodisplay))
		owner_hud.infodisplay += energy_display
		hud_changed = TRUE
	if(momentum_bar_visible && !(momentum_display in owner_hud.infodisplay))
		owner_hud.infodisplay += momentum_display
		hud_changed = TRUE
	if(!momentum_bar_visible && (momentum_display in owner_hud.infodisplay))
		owner_hud.infodisplay -= momentum_display
		hud_changed = TRUE

	if(hud_changed)
		owner_hud.show_hud(owner_hud.hud_version)

/// Removes the sprint-energy display from the owner's HUD.
/datum/component/sprinting/proc/remove_energy_hud()
	if(isnull(energy_display))
		return

	sprint_owner?.hud_used?.infodisplay -= energy_display
	sprint_owner?.hud_used?.infodisplay -= momentum_display
	QDEL_NULL(energy_display)
	QDEL_NULL(momentum_display)

/// Displays sprint energy under the standard stamina HUD, with depleted energy colored red from the top down.
/atom/movable/screen/sprint_energy
	icon = 'modular_doppler/sprinting/icons/ui.dmi'
	icon_state = "sprint_energy"
	screen_loc = ui_stamina
	layer = OBJ_LAYER - 0.1
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT

/// Updates the red depleted-energy overlay to match the supplied energy level.
/atom/movable/screen/sprint_energy/proc/update_energy(current_energy, maximum_energy)
	cut_overlays()
	if(current_energy >= maximum_energy)
		return

	var/depleted_height = round((maximum_energy - current_energy) / maximum_energy * ICON_SIZE_Y)
	if(depleted_height <= 0)
		return

	var/icon/depleted_icon = icon(icon, icon_state)
	depleted_icon.Crop(1, ICON_SIZE_Y - depleted_height + 1, ICON_SIZE_X, ICON_SIZE_Y)
	var/image/depleted_overlay = image(depleted_icon)
	depleted_overlay.pixel_y = ICON_SIZE_Y - depleted_height
	depleted_overlay.color = list(1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0)
	add_overlay(depleted_overlay)

/// Displays the momentum-bar frame beneath the sprint energy indicator.
/atom/movable/screen/sprint_momentum
	icon = 'modular_doppler/sprinting/icons/ui.dmi'
	icon_state = "sprintbar"
	screen_loc = ui_stamina
	layer = OBJ_LAYER - 0.2
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	/// The resource layer displayed inside the momentum-bar frame.
	var/atom/movable/screen/sprint_momentum_fill/resource_display

/atom/movable/screen/sprint_momentum/Initialize(mapload, datum/hud/hud_owner)
	. = ..()
	resource_display = new(src, null)
	vis_contents += resource_display

/// Updates the resource layer inside the momentum bar.
/atom/movable/screen/sprint_momentum/proc/update_momentum(current_momentum, maximum_momentum)
	resource_display?.update_momentum(current_momentum, maximum_momentum)

/// Displays the momentum resource inside its persistent bar frame.
/atom/movable/screen/sprint_momentum_fill
	icon = 'modular_doppler/sprinting/icons/ui.dmi'
	icon_state = "sprintbar"
	color = COLOR_BLUE
	vis_flags = VIS_INHERIT_ID | VIS_INHERIT_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	/// The mask that clips the resource layer to its current fullness.
	var/static/icon/bar_mask
	/// The vertical offset applied to the resource-layer mask.
	var/bar_offset
	/// The last rounded momentum value used to update the resource layer.
	var/last_momentum_band = -1

/atom/movable/screen/sprint_momentum_fill/Initialize(mapload, datum/hud/hud_owner)
	. = ..()
	var/atom/movable/parent_display = ismovable(loc) ? loc : null
	screen_loc = parent_display?.screen_loc
	bar_mask ||= icon(icon, icon_state)

/// Updates the visible fullness of the momentum resource layer.
/atom/movable/screen/sprint_momentum_fill/proc/update_momentum(current_momentum, maximum_momentum)
	if(maximum_momentum <= SPRINT_MOMENTUM_MINIMUM)
		return

	var/momentum_ratio = clamp(current_momentum / maximum_momentum, 0, 1)
	var/momentum_band = round(momentum_ratio, 0.05)
	if(momentum_band == last_momentum_band)
		return
	last_momentum_band = momentum_band

	bar_offset = clamp(-SPRINT_MOMENTUM_BAR_HEIGHT + (SPRINT_MOMENTUM_BAR_HEIGHT * momentum_band), -SPRINT_MOMENTUM_BAR_HEIGHT, 0)
	if(isnull(get_filter("sprint_momentum_mask")))
		add_filter("sprint_momentum_mask", 1, alpha_mask_filter(0, bar_offset, bar_mask))
	else
		transition_filter("sprint_momentum_mask", alpha_mask_filter(0, bar_offset), 0.5 SECONDS)

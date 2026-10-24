/// The default maximum amount of sprint energy a human can store.
#define SPRINT_ENERGY_MAXIMUM 100
/// The minimum amount of sprint energy a human can store.
#define SPRINT_ENERGY_MINIMUM 0
/// The default amount of sprint energy drained by each running tile.
#define SPRINT_ENERGY_DRAIN_PER_TILE 1
/// The default delay before sprint energy begins regenerating.
#define SPRINT_ENERGY_REGEN_DELAY 4 SECONDS
/// The default amount of sprint energy restored per regeneration tick.
#define SPRINT_ENERGY_REGEN_AMOUNT 6.67
/// The interval between sprint-energy regeneration ticks.
#define SPRINT_ENERGY_REGEN_INTERVAL 1 SECONDS

/// Adds the sprinting component to everyone.
/mob/living/carbon/human/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/sprinting)

/// Tracks sprint energy for a human and displays its current level on the HUD.
/datum/component/sprinting
	dupe_mode = COMPONENT_DUPE_UNIQUE

	/// The human whose movement and HUD this component manages.
	var/mob/living/carbon/human/sprint_owner
	/// The current amount of sprint energy available.
	var/energy = SPRINT_ENERGY_MAXIMUM
	/// The maximum amount of sprint energy that can be stored.
	var/max_energy = SPRINT_ENERGY_MAXIMUM
	/// The amount of energy drained after moving one tile while running.
	var/energy_drain_per_tile = SPRINT_ENERGY_DRAIN_PER_TILE
	/// The delay after draining energy before regeneration begins.
	var/energy_regen_delay = SPRINT_ENERGY_REGEN_DELAY
	/// The amount of energy restored by each regeneration tick.
	var/energy_regen_amount = SPRINT_ENERGY_REGEN_AMOUNT
	/// The world time at which energy was last successfully drained.
	var/last_energy_loss_time = 0
	/// The energy display installed on the owner's HUD.
	var/atom/movable/screen/sprint_energy/energy_display

/datum/component/sprinting/Initialize()
	if(!ishuman(parent))
		return COMPONENT_INCOMPATIBLE

	sprint_owner = parent

/datum/component/sprinting/RegisterWithParent()
	. = ..()
	RegisterSignal(sprint_owner, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))
	if(sprint_owner.hud_used)
		install_energy_hud()
	else
		RegisterSignal(sprint_owner, COMSIG_MOB_HUD_CREATED, PROC_REF(on_hud_created))

/datum/component/sprinting/UnregisterFromParent()
	. = ..()
	UnregisterSignal(sprint_owner, list(COMSIG_MOVABLE_MOVED, COMSIG_MOB_HUD_CREATED))

/datum/component/sprinting/Destroy(force)
	remove_energy_hud()
	sprint_owner = null
	return ..()

/// Installs the sprint-energy display after the owner's HUD has been created.
/datum/component/sprinting/proc/on_hud_created(datum/source)
	SIGNAL_HANDLER
	install_energy_hud()

/// Drains sprint energy after a human moves from one turf to another while running.
/datum/component/sprinting/proc/on_moved(mob/living/carbon/human/source, atom/old_loc, movement_dir, forced, list/old_locs, momentum_change)
	SIGNAL_HANDLER
	if(source != sprint_owner || source.move_intent != MOVE_INTENT_RUN || energy <= SPRINT_ENERGY_MINIMUM)
		return

	var/turf/old_turf = get_turf(old_loc)
	var/turf/new_turf = get_turf(source)
	if(isnull(old_turf) || isnull(new_turf) || old_turf == new_turf || get_dist(old_turf, new_turf) != 1)
		return

	adjust_energy(-energy_drain_per_tile)
	last_energy_loss_time = world.time
	addtimer(CALLBACK(src, PROC_REF(regenerate_energy)), energy_regen_delay, TIMER_UNIQUE | TIMER_OVERRIDE)

/// Restores sprint energy after the recovery delay has elapsed.
/datum/component/sprinting/proc/regenerate_energy()
	if(QDELETED(sprint_owner) || energy >= max_energy)
		return

	var/time_since_energy_loss = world.time - last_energy_loss_time
	if(time_since_energy_loss < energy_regen_delay)
		addtimer(CALLBACK(src, PROC_REF(regenerate_energy)), energy_regen_delay - time_since_energy_loss, TIMER_UNIQUE | TIMER_OVERRIDE)
		return

	adjust_energy(energy_regen_amount)
	if(energy < max_energy)
		addtimer(CALLBACK(src, PROC_REF(regenerate_energy)), SPRINT_ENERGY_REGEN_INTERVAL, TIMER_UNIQUE | TIMER_OVERRIDE)

/// Changes sprint energy within its valid range and updates the HUD display.
/datum/component/sprinting/proc/adjust_energy(amount)
	if(!isnum(amount))
		return

	energy = clamp(energy + amount, SPRINT_ENERGY_MINIMUM, max_energy)
	energy_display?.update_energy(energy, max_energy)
	update_hud_visibility()

/// Creates the sprint-energy display and ensures the regular stamina display remains visible.
/datum/component/sprinting/proc/install_energy_hud()
	if(energy_display || isnull(sprint_owner?.hud_used))
		return

	var/datum/hud/owner_hud = sprint_owner.hud_used
	energy_display = new(null, owner_hud)
	energy_display.update_energy(energy, max_energy)
	update_hud_visibility()

/// Shows the energy HUD with the stamina HUD and restores stamina while energy is depleted.
/datum/component/sprinting/proc/update_hud_visibility()
	if(isnull(energy_display) || isnull(sprint_owner?.hud_used))
		return

	var/datum/hud/owner_hud = sprint_owner.hud_used
	var/stamina_visible = owner_hud.stamina in owner_hud.infodisplay
	var/hud_changed = FALSE
	if(energy < max_energy && owner_hud.stamina && !stamina_visible)
		owner_hud.infodisplay += owner_hud.stamina
		sprint_owner.update_stamina_hud()
		stamina_visible = TRUE
		hud_changed = TRUE

	if(stamina_visible && !(energy_display in owner_hud.infodisplay))
		owner_hud.infodisplay += energy_display
		hud_changed = TRUE
	else if(!stamina_visible && energy_display in owner_hud.infodisplay)
		owner_hud.infodisplay -= energy_display
		hud_changed = TRUE

	if(hud_changed)
		owner_hud.show_hud(owner_hud.hud_version)

/// Removes the sprint-energy display from the owner's HUD.
/datum/component/sprinting/proc/remove_energy_hud()
	if(isnull(energy_display))
		return

	sprint_owner?.hud_used?.infodisplay -= energy_display
	QDEL_NULL(energy_display)

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

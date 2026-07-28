
/**
 * Removes the old powers from people's savefiles
 */
/datum/preferences/proc/nuke_old_powers(list/save_data)
	if(save_data && ("powers" in save_data))
		save_data -= "powers"
		var/ckey_to_log = parent?.ckey || "unknown"
		log_game("[ckey_to_log]'s powers were migrated over from the old powers system.")

/**
 * Maps old power names to their current name.
 * Since powers are saved to preferences by name (not typepath), renaming a power's
 * name var would otherwise silently drop it from everyone's save on next load/sanitize.
 * Add an entry here whenever a power's name changes so existing saves transfer over.
 */
GLOBAL_LIST_INIT(power_name_renames, list(
	"Beastial Body" = "Bestial Body",
))

/**
 * Rewrites any legacy power names found in the player's saved powers list to their current name, per GLOB.power_name_renames.
 */
/datum/preferences/proc/rename_legacy_powers(list/save_data)
	var/list/saved_powers = save_data?["all_powers"]
	if(!islist(saved_powers) || !length(saved_powers))
		return

	for(var/old_name in GLOB.power_name_renames)
		var/index = saved_powers.Find(old_name)
		if(!index)
			continue
		var/new_name = GLOB.power_name_renames[old_name]
		// Avoid duplicate entries if the player somehow already has the new name saved too.
		if(saved_powers.Find(new_name))
			saved_powers.Cut(index, index + 1)
		else
			saved_powers[index] = new_name
		var/ckey_to_log = parent?.ckey || "unknown"
		log_game("[ckey_to_log]'s power \"[old_name]\" was renamed to \"[new_name]\" in their savefile.")

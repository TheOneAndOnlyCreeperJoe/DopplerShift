/datum/species/ethereal
	preview_outfit = /datum/outfit/ethereal_preview
	hair_alpha = 140
	hair_color_mode = null
	inherent_traits = list(
		TRAIT_MUTANT_COLORS,
		TRAIT_AGENDER,
	)
	mutanteyes = /obj/item/organ/eyes/ethereal

/obj/item/organ/eyes/ethereal
	var/eye_overlay_icon = 'modular_doppler/modular_species/species_types/ethereal/icons/organs/ethereal_eyes.dmi'

/obj/item/organ/eyes/ethereal/Initialize(mapload)
	. = ..() // need to do it here because these are normally set by the parent init
	eyelid_left.icon = eye_overlay_icon
	eyelid_right.icon = eye_overlay_icon

/// Redirects only this organ's eye appearances to the Ethereal eye icon file.
/obj/item/organ/eyes/ethereal/generate_body_overlay(mob/living/carbon/human/parent)
	. = ..()
	var/left_eye_icon_state = "[eye_icon_state]_l"
	var/right_eye_icon_state = "[eye_icon_state]_r"
	for(var/mutable_appearance/eye_overlay as anything in .)
		if(eye_overlay.icon_state != left_eye_icon_state && eye_overlay.icon_state != right_eye_icon_state)
			continue
		eye_overlay.icon = eye_overlay_icon

/// Discards the legacy Ethereal color randomized by the base species so mutant color remains the canonical randomized color.
/datum/species/ethereal/randomize_features()
	var/list/features = ..()
	features -= FEATURE_ETHEREAL_COLOR
	return features

/// Hides the legacy Ethereal color preference so character creation exposes only the standard mutant color selection.
/datum/species/ethereal/get_features()
	var/list/features = ..()
	features -= "feature_ethcolor"
	return features

/// Applies the appropriate mutant colors to the lustrous variant.
/datum/species/ethereal/lustrous/on_species_gain(mob/living/carbon/new_lustrous, datum/species/old_species, pref_load, regenerate_icons)
	new_lustrous.dna.features[FEATURE_MUTANT_COLOR] = GLOB.color_list_lustrous[pick(GLOB.color_list_lustrous)]
	return ..()

/datum/outfit/ethereal_preview
	name = "Ethereal (Species Preview)"
	uniform = /obj/item/clothing/under/frontier_colonist
	head = /obj/item/clothing/head/soft/frontier_colonist

/datum/species/ethereal/prepare_human_for_preview(mob/living/carbon/human/human_for_preview)
	turn_off_every_species_feature(human_for_preview)
	human_for_preview.dna.features[FEATURE_MUTANT_COLOR] = GLOB.color_list_ethereal["Green"]
	refresh_light_color(human_for_preview)
	human_for_preview.set_hairstyle("Lila", update = TRUE)
	regenerate_organs(human_for_preview)
	human_for_preview.update_body(is_creating = TRUE)

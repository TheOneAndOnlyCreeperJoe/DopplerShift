// MODULAR ETHEREAL OVERRIDES

/datum/bodypart_overlay/simple/ethereal_arm
	icon = 'modular_doppler/modular_species/species_types/ethereal/icons/bodyparts/arms_overlay.dmi'
	layers = EXTERNAL_FRONT

/datum/bodypart_overlay/simple/ethereal_arm/color_image(image/overlay, layer, obj/item/bodypart/limb)
	overlay.color = limb?.draw_color

/// Hides the arms when wearing a piece of equipment that signals HIDEJUMPSUIT, which usually is most full-body coverage.
/datum/bodypart_overlay/simple/ethereal_arm/can_draw_on_bodypart(obj/item/bodypart/bodypart_owner)
	return !(bodypart_owner.owner?.obscured_slots & HIDEJUMPSUIT)

/datum/bodypart_overlay/simple/ethereal_arm/left
	icon_state = "ethereal_l_arm"

/datum/bodypart_overlay/simple/ethereal_arm/right
	icon_state = "ethereal_r_arm"

/obj/item/bodypart/head/ethereal
	icon_greyscale = BODYPART_ICON_ETHEREAL
	bodyshape = BODYSHAPE_HUMANOID
	head_flags = HEAD_HAIR|HEAD_FACIAL_HAIR|HEAD_EYESPRITES|HEAD_EYECOLOR|HEAD_DEBRAIN

/obj/item/bodypart/head/ethereal/lustrous
	icon_greyscale = BODYPART_ICON_ETHEREAL
	bodyshape = BODYSHAPE_HUMANOID
	head_flags = HEAD_HAIR|HEAD_FACIAL_HAIR|HEAD_EYESPRITES|HEAD_EYECOLOR|HEAD_DEBRAIN // need to redefine these because the basetype sets flags to NONE

/obj/item/bodypart/chest/ethereal
	icon_greyscale = BODYPART_ICON_ETHEREAL
	bodyshape = BODYSHAPE_HUMANOID

/obj/item/bodypart/arm/left/ethereal
	icon_greyscale = BODYPART_ICON_ETHEREAL
	bodyshape = BODYSHAPE_HUMANOID

/obj/item/bodypart/arm/left/ethereal/Initialize(mapload)
	. = ..()
	add_bodypart_overlay(new /datum/bodypart_overlay/simple/ethereal_arm/left(), update = FALSE)

/obj/item/bodypart/arm/right/ethereal
	icon_greyscale = BODYPART_ICON_ETHEREAL
	bodyshape = BODYSHAPE_HUMANOID

/obj/item/bodypart/arm/right/ethereal/Initialize(mapload)
	. = ..()
	add_bodypart_overlay(new /datum/bodypart_overlay/simple/ethereal_arm/right(), update = FALSE)

/obj/item/bodypart/leg/left/ethereal
	icon_greyscale = BODYPART_ICON_ETHEREAL
	bodyshape = BODYSHAPE_HUMANOID

/obj/item/bodypart/leg/right/ethereal
	icon_greyscale = BODYPART_ICON_ETHEREAL
	bodyshape = BODYSHAPE_HUMANOID

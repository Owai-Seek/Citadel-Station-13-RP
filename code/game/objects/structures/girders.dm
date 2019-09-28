/obj/structure/girder
	icon_state = "girder"
	anchored = 1
	density = 1
	plane = PLATING_PLANE
	w_class = ITEMSIZE_HUGE
	var/state = 0
	var/health = 200
	var/max_health = 200
	var/displaced_health = 50
	var/current_damage = 0
	var/cover = 50 //how much cover the girder provides against projectiles.
	material_primary = MATERIAL_ID_STEEL_ID
	var/datum/material/material_reinforcing
	var/reinforcing = 0

/obj/structure/girder/Initialize(mapload, primary_material)
	if(primary_material)
		material_primary = primary_material
	. = ..()

/obj/structure/girder/SetMaterial(datum/material/M, index, updating)
	else if(index == MATERIAL_REINFORCING)
		material_reinforcing = M
	return ..()

/obj/structure/girder/UpdateMaterials()
	name = "[girder_material.display_name] [initial(name)]"
	max_health = round(material_primary?.integrity) //Should be 150 with default integrity (steel). Weaker than ye-olden Girders now.
	health = max_health
	displaced_health = round(max_health/4)
	if(material_priamry?.products_need_process()) //Am I radioactive or some other? Process me!
		processing_objects |= src
	else if(src in processing_objects) //If I happened to be radioactive or s.o. previously, and am not now, stop processing.
		processing_objects -= src
	return ..()

/obj/structure/girder/GetMaterial(index)
	switch(index)
		if(MATERIAL_REINFORCING)
			return material_reinforcing
	return ..()

/obj/structure/girder/update_icon()
	if(anchored)
		icon_state = "girder"
	else
		icon_state = "displaced"
	return ..()

/obj/structure/girder/Destroy()
	if(material_primary?.products_need_process())
		processing_objects -= src
	. = ..()

/obj/structure/girder/process()
	if(!radiate())
		processing_objects -= src
		return

/obj/structure/girder/proc/radiate()
	if(!material_primary)
		return
	var/total_radiation = material_primary.radioactivity + (material_reinforcing?.radioactivity / 2)
	if(!total_radiation)
		return

	radiation_repository.radiate(src, total_radiation)
	return total_radiation

/obj/structure/girder/displaced
	icon_state = "displaced"
	anchored = 0
	health = 50
	cover = 25

/obj/structure/girder/displaced/Initialize(mapload, material_primary)
	. = ..()
	displace()

/obj/structure/girder/proc/displace()
	name = "displaced [material_primary.display_name] [initial(name)]"
	icon_state = "displaced"
	anchored = 0
	health = (displaced_health - round(current_damage / 4))
	cover = 25

/obj/structure/girder/attack_generic(var/mob/user, var/damage, var/attack_message = "smashes apart", var/wallbreaker)
	if(!damage || !wallbreaker)
		return 0
	user.do_attack_animation(src)
	visible_message("<span class='danger'>[user] [attack_message] the [src]!</span>")
	dismantle()
	return 1

/obj/structure/girder/bullet_act(var/obj/item/projectile/Proj)
	//Girders only provide partial cover. There's a chance that the projectiles will just pass through. (unless you are trying to shoot the girder)
	if(Proj.original != src && !prob(cover))
		return PROJECTILE_CONTINUE //pass through

	var/damage = Proj.get_structure_damage()
	if(!damage)
		return

	if(!istype(Proj, /obj/item/projectile/beam))
		damage *= 0.4 //non beams do reduced damage

	else if(material_primary?.reflectivity >= 0.5) // Reflect lasers.
		var/new_damage = damage * material_primary.reflectivity
		var/outgoing_damage = damage - new_damage
		damage = round(new_damage)
		Proj.damage = outgoing_damage

		visible_message("<span class='danger'>\The [src] reflects \the [Proj]!</span>")

		// Find a turf near or on the original location to bounce to
		var/new_x = Proj.starting.x + pick(0, 0, 0, -1, 1, -2, 2)
		var/new_y = Proj.starting.y + pick(0, 0, 0, -1, 1, -2, 2)
		//var/turf/curloc = get_turf(src)
		var/turf/curloc = get_step(src, get_dir(src, Proj.starting))

		Proj.penetrating += 1 // Needed for the beam to get out of the girder.

		// redirect the projectile
		Proj.redirect(new_x, new_y, curloc, null)

	health -= damage
	..()
	if(health <= 0)
		dismantle()

	return

/obj/structure/girder/blob_act()
	dismantle()

/obj/structure/girder/proc/reset_girder()
	UpdateMaterials()
	anchored = 1
	cover = initial(cover)
	health = min(max_health - current_damage,max_health)
	state = 0
	icon_state = initial(icon_state)
	reinforcing = 0
	if(material_reinforcing)
		reinforce_girder()

/obj/structure/girder/attackby(obj/item/W as obj, mob/user as mob)
	if(W.is_wrench() && state == 0)
		if(anchored && !material_reinforcing)
			playsound(src, W.usesound, 100, 1)
			to_chat(user, "<span class='notice'>Now disassembling the girder...</span>")
			if(do_after(user,(35 + round(max_health/50)) * W.toolspeed))
				if(!src) return
				to_chat(user, "<span class='notice'>You dissasembled the girder!</span>")
				dismantle()
		else if(!anchored)
			playsound(src, W.usesound, 100, 1)
			to_chat(user, "<span class='notice'>Now securing the girder...</span>")
			if(do_after(user, 40 * W.toolspeed, src))
				to_chat(user, "<span class='notice'>You secured the girder!</span>")
				reset_girder()

	else if(istype(W, /obj/item/weapon/pickaxe/plasmacutter))
		to_chat(user, "<span class='notice'>Now slicing apart the girder...</span>")
		if(do_after(user,30 * W.toolspeed))
			if(!src) return
			to_chat(user, "<span class='notice'>You slice apart the girder!</span>")
			dismantle()

	else if(istype(W, /obj/item/weapon/pickaxe/diamonddrill))
		to_chat(user, "<span class='notice'>You drill through the girder!</span>")
		dismantle()

	else if(W.is_screwdriver())
		if(state == 2)
			playsound(src, W.usesound, 100, 1)
			to_chat(user, "<span class='notice'>Now unsecuring support struts...</span>")
			if(do_after(user,40 * W.toolspeed))
				if(!src) return
				to_chat(user, "<span class='notice'>You unsecured the support struts!</span>")
				state = 1
		else if(anchored && !material_reinforcing)
			playsound(src, W.usesound, 100, 1)
			reinforcing = !reinforcing
			to_chat(user, "<span class='notice'>\The [src] can now be [reinforcing? "reinforced" : "constructed"]!</span>")

	else if(W.is_wirecutter() && state == 1)
		playsound(src, W.usesound, 100, 1)
		to_chat(user, "<span class='notice'>Now removing support struts...</span>")
		if(do_after(user,40 * W.toolspeed))
			if(!src) return
			to_chat(user, "<span class='notice'>You removed the support struts!</span>")
			material_reinforcing.place_dismantled_product(get_turf(src))
			RemoveMaterial(MATINDEX_OBJ_REINFORCING)
			reset_girder()

	else if(W.is_crowbar() && state == 0 && anchored)
		playsound(src, W.usesound, 100, 1)
		to_chat(user, "<span class='notice'>Now dislodging the girder...</span>")
		if(do_after(user, 40 * W.toolspeed))
			if(!src) return
			to_chat(user, "<span class='notice'>You dislodged the girder!</span>")
			displace()

	else if(istype(W, /obj/item/stack/material))
		if(reinforcing && !material_reinforcing)
			if(!reinforce_with_material(W, user))
				return ..()
		else
			if(!construct_wall(W, user))
				return ..()

	else
		return ..()

/obj/structure/girder/proc/take_damage(var/damage)
	health -= damage
	if(health <= 0)
		dismantle()
	else
		current_damage = current_damage + damage //Rather than calculate this every time we need to use it, just calculate it here and save it.


/obj/structure/girder/proc/construct_wall(obj/item/stack/material/S, mob/user)
	var/amount_to_use = material_reinforcing ? 1 : 2
	if(S.get_amount() < amount_to_use)
		to_chat(user, "<span class='notice'>There isn't enough material here to construct a wall.</span>")
		return 0

	var/datum/material/M = name_to_material[S.default_type]
	if(!istype(M))
		return 0

	var/wall_fake
	add_hiddenprint(usr)

	if(M.integrity < 50)
		to_chat(user, "<span class='notice'>This material is too soft for use in wall construction.</span>")
		return 0

	to_chat(user, "<span class='notice'>You begin adding the plating...</span>")

	if(!do_after(user,40) || !S.use(amount_to_use))
		return 1 //once we've gotten this far don't call parent attackby()

	if(anchored)
		to_chat(user, "<span class='notice'>You added the plating!</span>")
	else
		to_chat(user, "<span class='notice'>You create a false wall! Push on it to open or close the passage.</span>")
		wall_fake = 1

	var/turf/Tsrc = get_turf(src)
	Tsrc.ChangeTurf(/turf/simulated/wall)
	var/turf/simulated/wall/T = get_turf(src)
	T.SetAllWallMaterials(material_primary, material_reinforcing, M)
	if(wall_fake)
		T.can_open = 1
	T.add_hiddenprint(usr)
	qdel(src)
	return 1

/obj/structure/girder/proc/reinforce_with_material(obj/item/stack/material/S, mob/user) //if the verb is removed this can be renamed.
	if(GetMaterial(MATINDEX_OBJ_REINFORCING))
		to_chat(user, "<span class='notice'>\The [src] is already reinforced.</span>")
		return 0

	if(S.get_amount() < 1)
		to_chat(user, "<span class='notice'>There isn't enough material here to reinforce the girder.</span>")
		return 0

	var/datum/material/M = name_to_material[S.default_type]
	if(!istype(M) || M.integrity < 50)
		to_chat(user, "You cannot reinforce \the [src] with that; it is too soft.")
		return 0

	to_chat(user, "<span class='notice'>Now reinforcing...</span>")
	if (!do_after(user,40) || !S.use(1))
		return 1 //don't call parent attackby() past this point
	to_chat(user, "<span class='notice'>You added reinforcement!</span>")

	SetMaterial(M, MATINDEX_OBJ_REINFORCING)
	reinforce_girder()
	return 1

/obj/structure/girder/proc/reinforce_girder()
	cover = material_reinforcing.hardness
	health = health + round(material_reinforcing.integrity/2)
	state = 2
	icon_state = "reinforced"
	reinforcing = 0

/obj/structure/girder/proc/dismantle()
	material_primary?.place_dismantled_product(get_turf(src))
	qdel(src)

/obj/structure/girder/attack_hand(mob/user as mob)
	if (HULK in user.mutations)
		visible_message("<span class='danger'>[user] smashes [src] apart!</span>")
		dismantle()
		return
	return ..()


/obj/structure/girder/ex_act(severity)
	switch(severity)
		if(1.0)
			qdel(src)
			return
		if(2.0)
			if (prob(30))
				dismantle()
			return
		if(3.0)
			if (prob(5))
				dismantle()
			return
		else
	return

/obj/structure/girder/cult
	name = "column"
	icon= 'icons/obj/cult.dmi'
	icon_state= "cultgirder"
	health = 250
	cover = 70
	material_primary = MATERIAL_ID_CULT
	applies_material_colour = 0

/obj/structure/girder/cult/update_icon()
	. = ..()
	if(anchored)
		icon_state = "cultgirder"
	else
		icon_state = "displaced"

/obj/structure/girder/cult/dismantle()
	new /obj/effect/decal/remains/human(get_turf(src))
	qdel(src)

/obj/structure/girder/cult/attackby(obj/item/W as obj, mob/user as mob)
	if(W.is_wrench())
		playsound(src, W.usesound, 100, 1)
		to_chat(user, "<span class='notice'>Now disassembling the girder...</span>")
		if(do_after(user,40 * W.toolspeed))
			to_chat(user, "<span class='notice'>You dissasembled the girder!</span>")
			dismantle()

	else if(istype(W, /obj/item/weapon/pickaxe/plasmacutter))
		to_chat(user, "<span class='notice'>Now slicing apart the girder...</span>")
		if(do_after(user,30 * W.toolspeed))
			to_chat(user, "<span class='notice'>You slice apart the girder!</span>")
		dismantle()

	else if(istype(W, /obj/item/weapon/pickaxe/diamonddrill))
		to_chat(user, "<span class='notice'>You drill through the girder!</span>")
		new /obj/effect/decal/remains/human(get_turf(src))
		dismantle()


/obj/structure/girder/rcd_values(mob/living/user, obj/item/weapon/rcd/the_rcd, passed_mode)
	var/turf/simulated/T = get_turf(src)
	if(!istype(T) || T.density)
		return FALSE

	switch(passed_mode)
		if(RCD_FLOORWALL)
			// Finishing a wall costs two sheets.
			var/cost = RCD_SHEETS_PER_MATTER_UNIT * 2
			// Rwalls cost three to finish.
			if(the_rcd.make_rwalls)
				cost += RCD_SHEETS_PER_MATTER_UNIT * 1
			return list(
				RCD_VALUE_MODE = RCD_FLOORWALL,
				RCD_VALUE_DELAY = 2 SECONDS,
				RCD_VALUE_COST = cost
			)
		if(RCD_DECONSTRUCT)
			return list(
				RCD_VALUE_MODE = RCD_DECONSTRUCT,
				RCD_VALUE_DELAY = 2 SECONDS,
				RCD_VALUE_COST = RCD_SHEETS_PER_MATTER_UNIT * 5
			)
	return FALSE

/obj/structure/girder/rcd_act(mob/living/user, obj/item/weapon/rcd/the_rcd, passed_mode)
	var/turf/simulated/T = get_turf(src)
	if(!istype(T) || T.density) // Should stop future bugs of people bringing girders to centcom and RCDing them, or somehow putting a girder on a durasteel wall and deconning it.
		return FALSE

	switch(passed_mode)
		if(RCD_FLOORWALL)
			to_chat(user, span("notice", "You finish a wall."))
			// This is mostly the same as using on a floor. The girder's material is preserved, however.
			T.ChangeTurf(/turf/simulated/wall)
			var/turf/simulated/wall/new_T = get_turf(src) // Ref to the wall we just built.
			// Apparently set_material(...) for walls requires refs to the material singletons and not strings.
			// This is different from how other material objects with their own set_material(...) do it, but whatever.
			var/datum/material/M = name_to_material[the_rcd.material_to_use]
			new_T.SetAllWallMaterials(material_primary, the_rcd.make_rwalls? M : null, M)
			new_T.add_hiddenprint(user)
			qdel(src)
			return TRUE

		if(RCD_DECONSTRUCT)
			to_chat(user, span("notice", "You deconstruct \the [src]."))
			qdel(src)
			return TRUE


/obj/machinery/shield
	name = "Emergency energy shield"
	desc = "An energy shield used to contain hull breaches."
	icon = 'icons/effects/effects.dmi'
	icon_state = "shield-old"
	density = 1
	opacity = 0
	anchored = 1
	ghost_read = 0
	ghost_write = 0
	maxHealth = 200
	health = 200 //The shield can only take so much beating (prevents perma-prisons)

/obj/machinery/shield/acidable()
	return 0

/obj/machinery/shield/New()
	src.dir = pick(1,2,3,4)
	..()
	update_nearby_tiles()

/obj/machinery/shield/Destroy()
	opacity = 0
	setDensity(FALSE)
	update_nearby_tiles()
	..()

/obj/machinery/shield/Cross(atom/movable/mover, turf/target, height=1.5, air_group = 0)
	if(!height || air_group)
		return 0
	else
		return ..()

/obj/machinery/shield/attackby(obj/item/weapon/W as obj, mob/living/user as mob)
	if(!istype(W))
		return

	user.do_attack_animation(src, W)
	//Calculate damage
	var/aforce = W.force
	if(W.damtype == BRUTE || W.damtype == BURN)
		src.health -= aforce

	//Play a fitting sound
	playsound(src, 'sound/effects/EMPulse.ogg', 75, 1)


	if (src.health <= 0)
		visible_message("<span class='notice'>The [src] dissapates</span>")
		qdel(src)
		return

	opacity = 1
	spawn(20) if(src) opacity = 0

	if(src.health <= 0)
		visible_message("<span class='notice'>The [src] dissapates</span>")
		qdel(src)
		return

	opacity = 1
	spawn(20) if(src) opacity = 0

/obj/machinery/shield/bullet_act(var/obj/item/projectile/Proj)
	health -= Proj.damage
	. = ..()
	if(health <=0)
		visible_message("<span class='notice'>The [src] dissapates</span>")
		qdel(src)
		return
	opacity = 1
	spawn(20) if(src) opacity = 0

/obj/machinery/shield/ex_act(severity)
	switch(severity)
		if(1.0)
			if (prob(75))
				qdel(src)
		if(2.0)
			if (prob(50))
				qdel(src)
		if(3.0)
			if (prob(25))
				qdel(src)

/obj/machinery/shield/emp_act(severity)
	switch(severity)
		if(1)
			qdel(src)
		if(2)
			if(prob(50))
				qdel(src)

/obj/machinery/shield/blob_act()
	qdel(src)


/obj/machinery/shield/hitby(AM as mob|obj)
	. = ..()
	if(.)
		return
	//Let everyone know we've been hit!
	visible_message("<span class='danger'>[src] was hit by [AM].</span>")

	//Super realistic, resource-intensive, real-time damage calculations.
	var/tforce = 0
	if(ismob(AM))
		tforce = 40
	else
		tforce = AM:throwforce

	src.health -= tforce

	//This seemed to be the best sound for hitting a force field.
	playsound(src, 'sound/effects/EMPulse.ogg', 100, 1)

	//Handle the destruction of the shield
	if (src.health <= 0)
		visible_message("<span class='notice'>The [src] dissapates</span>")
		qdel(src)
		return

	//The shield becomes dense to absorb the blow.. purely asthetic.
	opacity = 1
	spawn(20) if(src) opacity = 0

/obj/machinery/shieldgen
	name = "Emergency shield projector"
	desc = "Used to seal minor hull breaches."
	icon = 'icons/obj/objects.dmi'
	icon_state = "shieldoff"
	density = 1
	opacity = 0
	anchored = 0
	pressure_resistance = 2*ONE_ATMOSPHERE
	req_access = list(access_engine)
	maxHealth = 100
	health = 100
	var/active = 0
	var/malfunction = 0 //Malfunction causes parts of the shield to slowly dissapate
	var/list/deployed_shields = list()
	var/locked = 0
	ghost_read = 0
	ghost_write = 0

	machine_flags = EMAGGABLE | WRENCHMOVE | FIXED2WORK | SCREWTOGGLE

	hack_abilities = list(
		/datum/malfhack_ability/toggle/disable,
		/datum/malfhack_ability/oneuse/overload_quiet,
		/datum/malfhack_ability/oneuse/emag
	)

/obj/machinery/shieldgen/Destroy()
	for(var/obj/machinery/shield/shield_tile in deployed_shields)
		deployed_shields -= shield_tile
		qdel(shield_tile)
	..()


/obj/machinery/shieldgen/proc/shields_up()
	if(active)
		return 0 //If it's already turned on, how did this get called?

	src.active = 1
	update_icon()

	for(var/turf/target_tile in range(2, src))
		if (istype(target_tile,/turf/space) && !(locate(/obj/machinery/shield) in target_tile))
			if (malfunction && prob(33) || !malfunction)
				deployed_shields += new /obj/machinery/shield(target_tile)

/obj/machinery/shieldgen/proc/shields_down()
	if(!active)
		return 0 //If it's already off, how did this get called?

	src.active = 0
	update_icon()

	for(var/obj/machinery/shield/shield_tile in deployed_shields)
		deployed_shields -= shield_tile
		qdel(shield_tile)

/obj/machinery/shieldgen/process()
	if(malfunction && active)
		if(deployed_shields.len && prob(5))
			qdel(pick(deployed_shields))

/obj/machinery/shieldgen/proc/checkhp()
	if(health <= 30)
		src.malfunction = 1
	if(health <= 0)
		qdel(src)
	update_icon()

/obj/machinery/shieldgen/ex_act(severity)
	switch(severity)
		if(1.0)
			src.health -= 75
			src.checkhp()
		if(2.0)
			src.health -= 30
			if (prob(15))
				src.malfunction = 1
			src.checkhp()
		if(3.0)
			src.health -= 10
			src.checkhp()

/obj/machinery/shieldgen/emp_act(severity)
	switch(severity)
		if(1)
			src.health /= 2 //cut health in half
			malfunction = 1
			locked = pick(0,1)
		if(2)
			if(prob(50))
				src.health *= 0.3 //chop off a third of the health
				malfunction = 1
	checkhp()

/obj/machinery/shieldgen/attack_ghost(mob/user)
	if(isAdminGhost(user))
		src.attack_hand(user)

/obj/machinery/shieldgen/attack_hand(mob/user as mob)
	if(locked)
		to_chat(user, "The machine is locked, you are unable to use it.")
		return
	if(panel_open)
		to_chat(user, "The panel must be closed before operating this machine.")
		return

	if (src.active)
		user.visible_message("<span class='notice'>[bicon(src)] [user] deactivated the shield generator.</span>", \
			"<span class='notice'>[bicon(src)] You deactivate the shield generator.</span>", \
			"You hear heavy droning fade out.")
		src.shields_down()
	else
		if(anchored)
			user.visible_message("<span class='notice'>[bicon(src)] [user] activated the shield generator.</span>", \
				"<span class='notice'>[bicon(src)] You activate the shield generator.</span>", \
				"You hear heavy droning.")
			src.shields_up()
		else
			to_chat(user, "The [src] must first be secured to the floor.")

/obj/machinery/shieldgen/emag(mob/user)
	if(!emagged)
		malfunction = 1
		update_icon()
		return 1

/obj/machinery/shieldgen/wrenchAnchor(var/mob/user, var/obj/item/I)
	if(locked)
		to_chat(user, "The bolts are covered, unlocking this would retract the covers.")
		return FALSE
	if(active)
		to_chat(user, "Turn \the [src] off first!")
		return FALSE
	if(panel_open)
		to_chat(user, "You have to close \the [src]'s maintenance panel before you can do that.")
		return FALSE
	. = ..()

/obj/machinery/shieldgen/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if(..())
		return 1

	if(istype(W, /obj/item/stack/cable_coil) && malfunction && panel_open)
		var/obj/item/stack/cable_coil/coil = W
		to_chat(user, "<span class='notice'>You begin to replace the wires.</span>")
		//if(do_after(user, src, min(60, round( ((maxhealth/health)*10)+(malfunction*10) ))) //Take longer to repair heavier damage
		if(do_after(user, src, 30))
			if(!src || !coil)
				return
			coil.use(1)
			health = maxHealth
			malfunction = 0
			to_chat(user, "<span class='notice'>You repair the [src]!</span>")
			update_icon()
		return

	if(istype(W, /obj/item/weapon/card/id) || istype(W, /obj/item/device/pda))
		if(src.allowed(user))
			src.locked = !src.locked
			to_chat(user, "The controls are now [src.locked ? "locked." : "unlocked."]")
		else
			to_chat(user, "<span class='warning'>Access denied.</span>")
		return


/obj/machinery/shieldgen/update_icon()
	if(active)
		src.icon_state = malfunction ? "shieldonbr":"shieldon"
	else
		src.icon_state = malfunction ? "shieldoffbr":"shieldoff"

////FIELD GEN START //shameless copypasta from fieldgen, powersink, and grille
#define maxstoredpower 500
/obj/machinery/shieldwallgen
		name = "shield generator"
		desc = "A shield generator."
		icon = 'icons/obj/stationobjs.dmi'
		icon_state = "Shield_Gen"
		anchored = 0
		density = 1
		req_access = list(access_teleporter)
		var/active = 0
		var/power = 0
		var/steps = 0
		var/last_check = 0
		var/check_delay = 10
		var/recalc = 0
		var/locked = 1
		var/destroyed = 0
//		var/maxshieldload = 200
		var/obj/structure/cable/attached		// the attached cable
		var/storedpower = 0
		flags = FPRINT
		siemens_coefficient = 1
		use_power = 0

		machine_flags = WRENCHMOVE | FIXED2WORK

/obj/machinery/shieldwallgen/free_access
	req_access = null

/obj/machinery/shieldwallgen/proc/power()
	if(!anchored)
		power = 0
		return 0
	var/turf/T = src.loc

	if(!T)
		return
	var/obj/structure/cable/C = T.get_cable_node()
	var/datum/powernet/PN
	if(C)
		PN = C.powernet		// find the powernet of the connected cable

	if(!PN)
		power = 0
		return 0

	var/surplus = max(PN.avail-PN.load, 0)
	var/shieldload = min(rand(50,200), surplus)
	if(shieldload==0 && storedpower <= 0)		// no cable or no power, and no power stored
		power = 0
		return 0
	else
		power = 1	// IVE GOT THE POWER!
		if(PN) //runtime errors fixer. They were caused by PN.newload trying to access missing network in case of working on stored power.
			storedpower += shieldload
			PN.load += shieldload //uses powernet power.
//		message_admins("[PN.load]", 1)
//		use_power(250) //uses APC power

/obj/machinery/shieldwallgen/attack_hand(mob/user as mob)
	if(!anchored)
		to_chat(user, "<span class='warning'>The shield generator needs to be firmly secured to the floor first.</span>")
		return 1
	if(src.locked && !istype(user, /mob/living/silicon))
		to_chat(user, "<span class='warning'>The controls are locked!</span>")
		return 1
	if(power != 1)
		to_chat(user, "<span class='warning'>The shield generator needs to be powered by wire underneath.</span>")
		return 1

	if(src.active)
		src.active = 0
		icon_state = "Shield_Gen"

		user.visible_message("[user] turned the shield generator off.", \
			"You turn off the shield generator.", \
			"You hear heavy droning fade out.")
		src.cleanup()
	else
		src.active = 1
		icon_state = "Shield_Gen +a"
		user.visible_message("[user] turned the shield generator on.", \
			"You turn on the shield generator.", \
			"You hear heavy droning.")
	src.add_fingerprint(user)

/obj/machinery/shieldwallgen/process()
	spawn(100)
		power()
		if(power)
			storedpower -= 50 //this way it can survive longer and survive at all
	if(storedpower >= maxstoredpower)
		storedpower = maxstoredpower
	if(storedpower <= 0)
		storedpower = 0
//	if(shieldload >= maxshieldload) //there was a loop caused by specifics of process(), so this was needed.
//		shieldload = maxshieldload

	if(src.active == 1 && power)
		if(!anchored)
			src.active = 0
			return
		spawn(1)
			setup_field(1)
		spawn(2)
			setup_field(2)
		spawn(3)
			setup_field(4)
		spawn(4)
			setup_field(8)
		src.active = 2
	if(!power && active)
		src.visible_message("<span class='warning'>The [src.name] shuts down due to lack of power!</span>", \
			"You hear heavy droning fade out")
		icon_state = "Shield_Gen"
		src.active = 0
		spawn(1)
			src.cleanup(1)
		spawn(1)
			src.cleanup(2)
		spawn(1)
			src.cleanup(4)
		spawn(1)
			src.cleanup(8)

/obj/machinery/shieldwallgen/proc/setup_field(var/NSEW = 0)
	var/turf/T = src.loc
	var/turf/T2 = src.loc
	var/obj/machinery/shieldwallgen/G
	var/steps = 0
	var/oNSEW = 0

	if(!NSEW)//Make sure its ran right
		return

	if(NSEW == 1)
		oNSEW = 2
	else if(NSEW == 2)
		oNSEW = 1
	else if(NSEW == 4)
		oNSEW = 8
	else if(NSEW == 8)
		oNSEW = 4

	for(var/dist = 0, dist <= 9, dist += 1) // checks out to 8 tiles away for another generator
		T = get_step(T2, NSEW)
		T2 = T
		steps += 1
		if(locate(/obj/machinery/shieldwallgen) in T)
			G = (locate(/obj/machinery/shieldwallgen) in T)
			steps -= 1
			if(!G.active)
				return
			G.cleanup(oNSEW)
			break

	if(isnull(G))
		return

	T2 = src.loc

	for(var/dist = 0, dist < steps, dist += 1) // creates each field tile
		var/field_dir = get_dir(T2,get_step(T2, NSEW))
		T = get_step(T2, NSEW)
		T2 = T
		var/obj/machinery/shieldwall/CF = new/obj/machinery/shieldwall/(src, G) //(ref to this gen, ref to connected gen)
		CF.forceMove(T)
		CF.dir = field_dir

/obj/machinery/shieldwallgen/wrenchAnchor(var/mob/user, var/obj/item/I)
	if(active)
		to_chat(user, "Turn off the field generator first.")
		return FALSE
	. = ..()
	if(!.)
		return
	power()

/obj/machinery/shieldwallgen/attack_ghost(mob/user)
	if(isAdminGhost(user))
		src.attack_hand(user)

/obj/machinery/shieldwallgen/attackby(obj/item/W, mob/user)
	if(..())
		return 1

	if(istype(W, /obj/item/weapon/card/id)||istype(W, /obj/item/device/pda))
		if (src.allowed(user))
			src.locked = !src.locked
			to_chat(user, "Controls are now [src.locked ? "locked." : "unlocked."]")
		else
			to_chat(user, "<span class='warning'>Access denied.</span>")

	else
		src.add_fingerprint(user)
		visible_message("<span class='warning'>The [src.name] has been hit with the [W.name] by [user.name]!</span>")

/obj/machinery/shieldwallgen/proc/cleanup(var/NSEW)
	var/turf/T = src.loc

	for(var/dist = 0 to 8) // checks out to 8 tiles away for fields
		T = get_step(T, NSEW)
		for(var/obj/machinery/shieldwall/F in T)
			qdel(F)

		for(var/obj/machinery/shieldwallgen/G in T)
			if(!G.active)
				return

/obj/machinery/shieldwallgen/Destroy()
	src.cleanup(1)
	src.cleanup(2)
	src.cleanup(4)
	src.cleanup(8)
	attached = null
	..()

/obj/machinery/shieldwallgen/bullet_act(var/obj/item/projectile/Proj)
	storedpower -= Proj.damage
	return ..()

//////////////Containment Field START
/obj/machinery/shieldwall
	name = "Shield"
	desc = "An energy shield."
	icon = 'icons/effects/effects.dmi'
	icon_state = "shieldwall"
	anchored = 1
	density = 1
	luminosity = 3
	pass_flags_self = PASSGLASS
	var/needs_power = 0
	var/active = 1
	var/obj/machinery/shieldwallgen/gen_primary
	var/obj/machinery/shieldwallgen/gen_secondary

/obj/machinery/shieldwall/acidable()
	return 0

/obj/machinery/shieldwall/can_overload()
	return 0

/obj/machinery/shieldwall/New(var/obj/machinery/shieldwallgen/A, var/obj/machinery/shieldwallgen/B)
	..()
	src.gen_primary = A
	src.gen_secondary = B
	if(A && B)
		needs_power = 1

/obj/machinery/shieldwall/Destroy()
	..()
	gen_primary = null
	gen_secondary = null

/obj/machinery/shieldwall/attack_hand(mob/user as mob)
	return


/obj/machinery/shieldwall/process()
	if(needs_power)
		if(isnull(gen_primary)||isnull(gen_secondary))
			qdel(src)
			return

		if(!(gen_primary.active)||!(gen_secondary.active))
			qdel(src)
			return

		if(prob(50))
			gen_primary.storedpower -= 10
		else
			gen_secondary.storedpower -=10

/obj/machinery/shieldwall/bullet_act(var/obj/item/projectile/Proj)
	if(needs_power)
		var/obj/machinery/shieldwallgen/G
		if(prob(50))
			G = gen_primary
		else
			G = gen_secondary
		G.storedpower -= Proj.damage
	return ..()


/obj/machinery/shieldwall/ex_act(severity)
	if(needs_power)
		var/obj/machinery/shieldwallgen/G
		switch(severity)
			if(1.0) //big boom
				if(prob(50))
					G = gen_primary
				else
					G = gen_secondary
				G.storedpower -= 200

			if(2.0) //medium boom
				if(prob(50))
					G = gen_primary
				else
					G = gen_secondary
				G.storedpower -= 50

			if(3.0) //lil boom
				if(prob(50))
					G = gen_primary
				else
					G = gen_secondary
				G.storedpower -= 20

/obj/machinery/shieldwall/Cross(atom/movable/mover, turf/target, height=1.5, air_group = 0)
	if(air_group || (height==0))
		return 1

	if(!mover)
		return

	if(istype(mover) && mover.checkpass(pass_flags_self))
		return prob(20)
	else
		if (istype(mover, /obj/item/projectile))
			return prob(10)
		else
			return !src.density

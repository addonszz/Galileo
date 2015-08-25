/*  Probe. (By: RuXi) inform me about bugs!
*
*   WARNING: 3rd person view modes can lag a server, if server is lagging really bad try disabling this hero to see if it helps.
*/

/* CVARS - copy and paste to shconfig.cfg

//Probe
probe_level 0
probe_mode 1		//1 = 2 extra views (Back View, Shoulder View), 2 = 3 extra views (Back View, Shoulder View, Sky View)

*/


#include <amxmodx>
#include <engine>
#include <superheromod>

// GLOBAL VARIABLES
new gHeroName[] = "Probe"
new bool:gHasProbe[SH_MAXSLOTS+1]
new gProbeView[SH_MAXSLOTS+1]
new pCvarProbeMode
//----------------------------------------------------------------------------------------------
public plugin_init()
{
	// Plugin Info
	register_plugin("SUPERHERO Probe", "1.0", "RuXi")

	// DO NOT EDIT THIS FILE TO CHANGE CVARS, USE THE SHCONFIG.CFG
	register_cvar("probe_level", "0")
	pCvarProbeMode = register_cvar("probe_mode", "1")

	// FIRE THE EVENT TO CREATE THIS SUPERHERO!
	shCreateHero(gHeroName, "3rd Person Views", "Use +power key to cycle view modes", true, "probe_level")

	// REGISTER EVENTS THIS HERO WILL RESPOND TO! (AND SERVER COMMANDS)
	// INIT
	register_srvcmd("probe_init", "probe_init")
	shRegHeroInit(gHeroName, "probe_init")

	// KEY DOWN
	register_srvcmd("probe_kd", "probe_kd")
	shRegKeyDown(gHeroName, "probe_kd")

	// NEW SPAWN
	register_event("ResetHUD", "new_spawn", "b")
}
//----------------------------------------------------------------------------------------------
public plugin_precache()
{
	// Required by set_view (this is a default hl model, your server has it and so do you)
	precache_model("models/rpgrocket.mdl")
}
//----------------------------------------------------------------------------------------------
public probe_init()
{
	// First Argument is an id
	new temp[6]
	read_argv(1, temp, 5)
	new id = str_to_num(temp)

	// 2nd Argument is 0 or 1 depending on whether the id has the hero
	read_argv(2, temp, 5)
	new hasPowers = str_to_num(temp)

	switch(hasPowers)
	{
		case true: gHasProbe[id] = true

		case false:
		{
			if ( is_user_alive(id) && gHasProbe[id] && gProbeView[id] > 0 )
			{
				gProbeView[id] = 0
				set_view(id, CAMERA_NONE)
			}

			gHasProbe[id] = false
		}
	}
}
//----------------------------------------------------------------------------------------------
public probe_kd()
{
	new temp[6]
	read_argv(1, temp, 5)
	new id = str_to_num(temp)

	if ( !is_user_alive(id) ) return

	view_change(id)
}
//----------------------------------------------------------------------------------------------
public new_spawn(id)
{
	if ( !shModActive() || !is_user_alive(id) || !gHasProbe[id] ) return

	// Reset view to current setting
	set_view(id, gProbeView[id])

}
//----------------------------------------------------------------------------------------------
public view_change(id)
{
	if ( !shModActive() || !is_user_alive(id) || !gHasProbe[id] ) return

	switch(gProbeView[id])
	{
		case 0:
		{
			// Back View
			gProbeView[id] = 1
			set_view(id, CAMERA_3RDPERSON)
		}
		case 1:
		{
			// Shoulder View
			gProbeView[id] = 2
			set_view(id, CAMERA_UPLEFT)
		}
		case 2:
		{
			if ( get_pcvar_num(pCvarProbeMode) == 2 )
			{
				// Sky View
				gProbeView[id] = 3
				set_view(id, CAMERA_TOPDOWN)
			}
			else
			{
				// First Person View (Normal)
				gProbeView[id] = 0
				set_view(id, CAMERA_NONE)
			}
		}
		case 3:
		{
			// First Person View (Normal)
			gProbeView[id] = 0
			set_view(id, CAMERA_NONE)
		}
	}
}
//----------------------------------------------------------------------------------------------
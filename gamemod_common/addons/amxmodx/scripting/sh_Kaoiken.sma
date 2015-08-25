#include <amxmodx> 
#include <superheromod> 

/* 

 //Kaioken 
 kaioken_level 0 
 kaioken_health        // Starting Health 
 kaioken_armor        // Starting Armor 
 kaioken_speed        // Speed of Kaioken 
 kaioken_cooldown    // How many seconds untll you could use Kaioken again? 
 kaioken_timer        // How many seconds will Kaioken Mode last? 

 */

// VARIABLES 
new gHeroName[]="Kaioken"
new gHasKaiokenPower[SH_MAXSLOTS+1]
new gKaiokenTimer[SH_MAXSLOTS+1]
//---------------------------------------------------------------------------------------------- 
public plugin_init()
{   
    // Plugin Info 
    register_plugin("SUPERHERO 10xKaioken","1.0","Mega / RaiN")

    // DO NOT EDIT THIS FILE TO CHANGE CVARS, USE THE SHCONFIG.CFG 
    register_cvar("kaioken_level", "0")
    register_cvar("kaioken_health", "500")
    register_cvar("kaioken_armor", "500")
    register_cvar("kaioken_speed", "800")
    register_cvar("kaioken_cooldown", "30")
    register_cvar("kaioken_timer", "15")

    // FIRE THE EVENT TO CREATE THIS SUPERHERO! 
    shCreateHero(gHeroName, "10x Kaioken Power-up", "Just like Goku, you now have his Kaioken Power-up. Activate on Keydown", true, "kaioken_level" )

    // REGISTER EVENTS THIS HERO WILL RESPOND TO! (AND SERVER COMMANDS) 
    register_srvcmd("kaioken_init", "kaioken_init")
    shRegHeroInit(gHeroName, "kaioken_init")

    //Loop 
    register_srvcmd("kaioken_loop", "kaioken_loop")
    set_task(1.0, "kaioken_loop",0,"",0,"b")

    // Let Server know about kaiokens Variable 
    // It is possible that another hero has more hps, less gravity, or more armor 
    // so rather than just setting these - let the superhero module decide each round 
    shSetMaxHealth(gHeroName, "kaioken_health" )
    shSetMaxArmor(gHeroName, "kaioken_armor" )
    shSetMaxSpeed(gHeroName, "kaioken_speed", "[0]" )
}
//---------------------------------------------------------------------------------------------- 
public kaioken_init()
{   
    new temp[128]
    // First Argument is an id 
    read_argv(1,temp,5)
    new id=str_to_num(temp)

    // 2nd Argument is 0 or 1 depending on whether the id has kaioken powers 
    read_argv(2,temp,5)
    new hasPowers=str_to_num(temp)

    // REMOVE the powers if he is not Kaoiken... 
    if ( !hasPowers )
    {   
        gKaiokenTimer[id]=0
    }

    gHasKaiokenPower[id]=(hasPowers!=0)

}
//---------------------------------------------------------------------------------------------- 
public newRound(id)
{   
    gPlayerUltimateUsed[id]=false
    return PLUGIN_HANDLED
}
//---------------------------------------------------------------------------------------------- 
// RESPOND TO KEYDOWN 
public kaioken_kd()
{   
    new temp[6]

    // First Argument is an id with kaioken Powers! 
    read_argv(1,temp,5)
    new id=str_to_num(temp)

    if ( !is_user_alive(id) ) return PLUGIN_HANDLED

    // Let them know they already used their ultimate if they have 
    if ( gPlayerUltimateUsed[id] )
    {   
        playSoundDenySelect(id)
        return PLUGIN_HANDLED
    }

    // Make sure they're not in the middle of kaioken already 
    if ( gKaiokenTimer[id]>0 ) return PLUGIN_HANDLED

    gKaiokenTimer[id]=get_cvar_num("kaioken_timer")+1
    kaioken_kaiokenmode(id)
    ultimateTimer(id, get_cvar_num("kaioken_cooldown") * 1.0)

    return PLUGIN_HANDLED
}
//---------------------------------------------------------------------------------------------- 
public kaioken_loop()
{   
    for ( new id=1; id<=SH_MAXSLOTS; id++ )
    {   
        if ( gHasKaiokenPower[id] && is_user_alive(id) )
        {   
            if ( gKaiokenTimer[id]>0 )
            {   
                gKaiokenTimer[id]--
                new message[128]
                format(message, 127, "%d seconds left of Kaioken", gKaiokenTimer[id] )
                set_user_rendering(id,kRenderFxGlowShell,255,0,0,100,3)
                set_hudmessage(0,255,0,-1.0,0.3,0,1.0,1.0,0.0,0.0,4)
                show_hudmessage( id, message)
            }
            else
            {   
                if ( gKaiokenTimer[id] == 0 )
                {   
                    gKaiokenTimer[id]--
                    kaioken_end(id)
                }
            }
        }
    }
}
//---------------------------------------------------------------------------------------------- 
public kaioken_end(id)
{   
    set_user_maxspeed(id,320.0)
    set_user_health(id,100.0)
    set_user_armor(id,100.0)
    set_user_rendering(id,kRenderFxGlowShell,255,0,0,kRenderNormal,0)
}
//---------------------------------------------------------------------------------------------- 
public kaioken_kaiokenmode(id)
{   
    if ( gHasKaiokenPower[id] && is_user_alive(id) )
    {   
        set_user_maxspeed(id,800.0)
        set_user_health(id,500.0)
        set_user_armor(id,500.0)
        client_cmd(id,"cl_sidespeed %i",get_cvar_num("kaioken_speed"))
        client_cmd(id,"cl_forwardspeed %i",get_cvar_num("kaioken_speed"))
        new message[128]
        format(message, 127, "Kaioken 10x")
        set_hudmessage(0,255,0,-1.0,0.3,0,0.25,1.0,0.0,0.0,4)
        show_hudmessage(id, message)
    }
}
//----------------------------------------------------------------------------------------------- 
/*********************** Licensing *******************************************************
*
*   Copyright 2008-2010 @ Brad Jones
*   Copyright 2015-2016 @ Addons zz
*   Copyright 2004-2016 @ AMX Mod X Development Team
*
*   Plugin Thread: https://forums.alliedmods.net/showthread.php?t=273019
*
*  This program is free software; you can redistribute it and/or modify it
*  under the terms of the GNU General Public License as published by the
*  Free Software Foundation; either version 3 of the License, or ( at
*  your option ) any later version.
*
*  This program is distributed in the hope that it will be useful, but
*  WITHOUT ANY WARRANTY; without even the implied warranty of
*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
*  General Public License for more details.
*
*  You should have received a copy of the GNU General Public License
*  along with this program.  If not, see <http://www.gnu.org/licenses/>.
*
*****************************************************************************************
*/

new const PLUGIN_VERSION[] = "1.2.X"

#include <amxmodx>
#include <amxmisc>

/** This is to view internal program data while execution. See the function 'debugMesssageLogger(...)'
 * and the variable 'g_debug_level' for more information. Default value:
 *
 * 0   - Disables this feature.
 * 1   - Normal debug.
 * 2   - To skip the 'pendingVoteCountdown()' and set the vote and runoff time to 5, seconds
 *       and to create fake votes.
 */
#define IS_DEBUG_ENABLED 1

#if IS_DEBUG_ENABLED > 0
    #define DEBUG
    #define DEBUG_LOGGER(%1) debugMesssageLogger( %1 )

/**
 * ( 0 ) 0 disabled all debug.
 * ( 1 ) 1 displays basic debug messages.
 * ( 10 ) 2 displays players disconnect, total number, multiple time limits changes and restores.
 * ( 100 ) 4 displays maps events, vote choices, votes, nominations, and the calls to 'map_populateList'.
 * ( ... ) 8 displays vote_loadChoices( ) and actions at vote_startDirector.
 * ( ... ) 16 displays messages related to RunOff voting.
 * ( ... ) 32 displays messages related to the rounds end map voting.
 * ( ... ) 64 displays messages related 'color_print'.
 * ( ... ) 128 execute the test units and print their out put results.
 * ( 1.. ) 255 displays all debug logs levels at server console.
 */
new g_debug_level = 14

/**
 * Test unit variables related to debug level 128, displays basic debug messages.
 */
new g_max_delay_result
new g_totalSuccessfulTests
new g_totalFailureTests

new Array: g_tests_idsAndNames
new Array: g_tests_delayed_ids
new Array: g_tests_failure_ids

new bool:g_is_test_changed_cvars

new Float:test_extendmap_max
new Float:test_mp_timelimit

/**
 * Write debug messages to server's console accordantly with cvar gal_debug.
 * If gal_debug 1 or more higher, the voting and runoff times are set to 5 seconds.
 *
 * @param mode the debug mode level, see the variable 'g_debug_level' for the levels.
 * @param text the debug message, if omitted its default value is ""
 * @param any the variable number of formatting parameters
 */
stock debugMesssageLogger( mode, message[], any: ... )
{
    if( mode & g_debug_level )
    {
        static formated_message[ 256 ]
        
        vformat( formated_message, charsmax( formated_message ), message, 3 )
        
        server_print( "%s",                      formated_message )
        // client_print( 0,    print_console, "%s", formated_message )
    }
}

#else
    #define DEBUG_LOGGER(%1) //
#endif

/**
 * Contains all unit tests to execute.
 */
#define ALL_TESTS_TO_EXECUTE \
{ \
    test_register_test(); \
    test_gal_in_empty_cycle1(); \
    test_gal_in_empty_cycle2(); \
    test_gal_in_empty_cycle3(); \
    test_gal_in_empty_cycle4(); \
    test_is_map_extension_allowed1( true ); \
}

#define TASKID_REMINDER               52691153
#define TASKID_SHOW_LAST_ROUND_HUD    52691052
#define TASKID_EMPTYSERVER            98176977
#define TASKID_START_VOTING_BY_ROUNDS 52691160
#define TASKID_PROCESS_LAST_ROUND     42691173
#define TASKID_VOTE_HANDLEDISPLAY     52691264
#define TASKID_VOTE_DISPLAY           52691165
#define TASKID_VOTE_EXPIRE            52691166
#define TASKID_DBG_FAKEVOTES          52691167
#define TASKID_VOTE_STARTDIRECTOR     52691168
#define TASKID_MAP_CHANGE             52691169

#define RTV_CMD_STANDARD  1
#define RTV_CMD_SHORTHAND 2
#define RTV_CMD_DYNAMIC   4

#define LONG_STRING   256
#define COLOR_MESSAGE 192
#define SHORT_STRING  64

#define SOUND_GETREADYTOCHOOSE 1
#define SOUND_COUNTDOWN        2
#define SOUND_TIMETOCHOOSE     4
#define SOUND_RUNOFFREQUIRED   8

#define MAPFILETYPE_SINGLE 1
#define MAPFILETYPE_GROUPS 2

#define SHOW_STATUS_AFTER_VOTE 1
#define SHOW_STATUS_AT_END     2
#define SHOW_STATUS_ALWAYS     3

#define STATUS_TYPE_COUNT      1
#define STATUS_TYPE_PERCENTAGE 2

#define ANNOUNCE_CHOICE_PLAYERS 1
#define ANNOUNCE_CHOICE_ADMINS  2

#define MAX_PREFIX_COUNT     32
#define MAX_RECENT_MAP_COUNT 16

#define MAX_MAPS_IN_VOTE       8
#define MAX_NOMINATION_COUNT   8
#define MAX_OPTIONS_IN_VOTE    9
#define MAX_STANDARD_MAP_COUNT 25

#define MAX_MAPNAME_LENGHT     64
#define MAX_FILE_PATH_LENGHT   128
#define MAX_PLAYER_NAME_LENGHT 48
#define MAX_PLAYERS_COUNT      33
#define MAX_NOM_MATCH_COUNT    1000

#define VOTE_IN_PROGRESS 1
#define VOTE_FORCED      2
#define VOTE_IS_RUNOFF   4
#define VOTE_IS_OVER     8
#define VOTE_IS_EARLY    16
#define VOTE_HAS_EXPIRED 32

#define SRV_START_CURRENTMAP 1
#define SRV_START_NEXTMAP    2
#define SRV_START_MAPVOTE    3
#define SRV_START_RANDOMMAP  4

#define LISTMAPS_USERID 0
#define LISTMAPS_LAST   1

#define START_VOTEMAP_MIN_TIME 151
#define START_VOTEMAP_MAX_TIME 129

/**
 * The rounds number before the mp_maxrounds/mp_winlimit to be reached to start the map voting.
 */
#define VOTE_START_ROUNDS 4

/**
 * Start a map voting delayed after the mp_maxrounds or mp_winlimit minimum to be reached.
 */
#define VOTE_START_ROUNDS_DELAY() \
{ \
    g_is_maxrounds_vote_map = true; \
    set_task( get_pcvar_num( g_freezetime_pointer ) + 10.0, \
            "start_voting_by_rounds", TASKID_START_VOTING_BY_ROUNDS ); \
}

/**
 * Convert colored strings codes '!g for green', '!y for yellow', '!t for team'.
 */
#define INSERT_COLOR_TAGS(%1) \
{ \
    replace_all( %1, charsmax( %1 ), "!g", "^4" ); \
    replace_all( %1, charsmax( %1 ), "!t", "^3" ); \
    replace_all( %1, charsmax( %1 ), "!n", "^1" ); \
    replace_all( %1, charsmax( %1 ), "!y", "^1" ); \
}

#define REMOVE_COLOR_TAGS(%1) \
{ \
    replace_all( %1, charsmax( %1 ), "^1", "" ); \
    replace_all( %1, charsmax( %1 ), "^2", "" ); \
    replace_all( %1, charsmax( %1 ), "^3", "" ); \
    replace_all( %1, charsmax( %1 ), "^4", "" ); \
}

#define PRINT_COLORED_MESSAGE(%1,%2) \
{ \
    message_begin( MSG_ONE_UNRELIABLE, g_user_msgid, _, %1 ); \
    write_byte( %1 ); \
    write_string( %2 ); \
    message_end(); \
}

/**
 * Call the internal function to perform its task and stop the current test execution to avoid
 * double failure at the test control system.
 */
#define SET_TEST_FAILURE(%1) \
{ \
    ( set_test_failure_internal( %1 ) ); \
    return; \
}

#define IS_ALWAYS_TO_SHOW_VOTE() \
( player_id > 0 \
  && noneOptionType == 2 \
  && g_is_player_voted[ player_id ] \
  && !g_is_player_cancelled_vote[ player_id ] )


#if AMXX_VERSION_NUM < 183
new g_user_msgid
#endif

#if !defined MAX_PLAYERS
    #define MAX_PLAYERS 32
#endif


/**
 * Variables related to debug level 32: displays messages related to the rounds end map voting
 */
new g_originalMaxRounds
new g_originalWinLimit
new Float:g_originalTimelimit
new Float:g_original_sv_maxspeed

new g_freezetime_pointer
new g_winlimit_pointer;
new g_maxrounds_pointer;
new g_timelimit_pointer;

new g_total_rounds_played;
new g_total_terrorists_wins;
new g_total_CT_wins;

new bool:g_isTimeToResetGame
new bool:g_isTimeToResetRounds
new bool:g_isUsingEmptyCycle
new bool:g_isRunOffNeedingKeepCurrentMap

new bool:g_is_emptyCycleMapConfigured
new bool:g_is_colored_chat_enabled
new bool:g_is_maxrounds_extend
new bool:g_is_maxrounds_vote_map
new bool:g_is_RTV_last_round
new bool:g_is_last_round
new bool:g_is_timeToChangeLevel
new bool:g_is_timeToRestart
new bool:g_is_timeLimitChanged
new bool:g_is_map_extension_allowed
new bool:g_is_srvTimelimitRestart
new bool:g_is_srvMaxroundsRestart
new bool:g_is_srvWinlimitRestart
new bool:g_is_color_chat_supported
new bool:g_is_final_voting


/**
 * Server cvars
 */
new cvar_extendmapAllowStayType
new cvar_nextMapChange
new cvar_showVoteCounter
new cvar_voteShowNoneOption
new cvar_voteShowNoneOptionType
new cvar_extendmapAllowOrder
new cvar_coloredChatEnabled
new cvar_isToStopEmptyCycle;
new cvar_unnominateDisconnected;
new cvar_endOnRound
new cvar_endOnRound_rtv
new cvar_endOnRound_msg
new cvar_voteWeight
new cvar_voteWeightFlags
new cvar_extendmapMax;
new cvar_extendmapStep;
new cvar_extendmapStepRounds;
new cvar_extendmapAllowStay
new cvar_endOfMapVote;
new cvar_isToAskForEndOfTheMapVote
new cvar_emptyWait
new cvar_emptyServerChange
new cvar_emptyMapFilePath
new cvar_rtvWait
new cvar_rtvWaitRounds
new cvar_rtvWaitAdmin
new cvar_rtvRatio
new cvar_rtvCommands;
new cvar_cmdVotemap
new cvar_cmdListmaps
new cvar_listmapsPaginate;
new cvar_recentMapsBannedNumber
new cvar_banRecentStyle
new cvar_voteDuration;
new cvar_nomMapFilePath
new cvar_nomPrefixes;
new cvar_nomQtyUsed
new cvar_nomPlayerAllowance;
new cvar_voteExpCountdown
new cvar_endMapCountdown
new cvar_voteMapChoiceCount
new cvar_voteAnnounceChoice
new cvar_voteUniquePrefixes;
new cvar_rtvReminder;
new cvar_srvStart;
new cvar_srvTimelimitRestart;
new cvar_srvMaxroundsRestart;
new cvar_srvWinlimitRestart;
new cvar_runoffEnabled
new cvar_runoffDuration;
new cvar_voteStatus
new cvar_voteStatusType;
new cvar_soundsMute;
new cvar_voteMapFilePath
new cvar_voteMinPlayers
new cvar_voteMinPlayersMapFilePath


/**
 * Various Artists
 */
new const LAST_EMPTY_CYCLE_FILE_NAME[] = "lastEmptyCycleMap.dat"
new const MENU_CHOOSEMAP[]             = "gal_menuChooseMap"
new const MENU_CHOOSEMAP_QUESTION[]    = "chooseMapQuestion"

new g_pendingVoteCountdown = 7
new g_rtv_wait_admin_number
new g_emptyCycleMapsNumber
new g_cntRecentMap;
new Array:g_nominationMap
new g_nominationMapCnt;
new Array: g_emptyCycleMapList
new Array:g_fillerMap;
new Float:g_rtvWait;
new g_rtvWaitRounds
new g_rockedVoteCnt;

new DIR_CONFIGS [ MAX_FILE_PATH_LENGHT ];
new DIR_DATA    [ MAX_FILE_PATH_LENGHT ];

new g_totalVoteOptions
new g_totalVoteOptions_temp

new g_maxVotingChoices;
new g_voteStatus
new g_voteDuration
new g_totalVotesCounted;

new COLOR_RED    [ 3 ]; // \r
new COLOR_WHITE  [ 3 ]; // \w
new COLOR_YELLOW [ 3 ]; // \y
new COLOR_GREY   [ 3 ]; // \d

new g_refreshVoteStatus = true
new g_mapPrefixCnt      = 1;

new g_vote                 [ 512 ];
new g_arrayOfRunOffChoices [ 2 ];
new g_voteStatus_symbol    [ 3 ]
new g_voteWeightFlags      [ 32 ];

new g_nextmap                    [ MAX_MAPNAME_LENGHT ];
new g_currentMap                 [ MAX_MAPNAME_LENGHT ]
new g_player_voted_option        [ MAX_PLAYERS_COUNT ];
new g_player_voted_weight        [ MAX_PLAYERS_COUNT ];
new g_snuffDisplay               [ MAX_PLAYERS_COUNT ];
new g_nominationMatchesMenu      [ MAX_PLAYERS_COUNT ];
new g_arrayOfMapsWithVotesNumber [ MAX_OPTIONS_IN_VOTE ];

new bool:g_is_player_voted          [ MAX_PLAYERS_COUNT ] = { true, ... }
new bool:g_is_player_cancelled_vote [ MAX_PLAYERS_COUNT ]
new bool:g_answeredForEndOfMapVote  [ MAX_PLAYERS_COUNT ]
new bool:g_rockedVote               [ MAX_PLAYERS_COUNT ]

new g_mapPrefix      [ MAX_PREFIX_COUNT ][ 16 ]
new g_nomination     [ MAX_PLAYERS_COUNT ][ MAX_NOMINATION_COUNT ]
new g_recentMap      [ MAX_RECENT_MAP_COUNT ][ MAX_MAPNAME_LENGHT ]
new g_votingMapNames [ MAX_OPTIONS_IN_VOTE ][ MAX_MAPNAME_LENGHT ]

new g_nominationCount
new g_chooseMapMenuId
new g_chooseMapQuestionMenuId

public plugin_init()
{
    register_plugin( "Galileo", PLUGIN_VERSION, "Brad Jones/Addons zz" );
    
    register_dictionary( "common.txt" );
    register_dictionary_colored( "galileo.txt" );
    
    register_cvar( "gal_version", PLUGIN_VERSION, FCVAR_SERVER | FCVAR_SPONLY );
    register_cvar( "gal_server_starting", "1", FCVAR_SPONLY );
    
    cvar_extendmapMax           = register_cvar( "amx_extendmap_max", "90" );
    cvar_extendmapStep          = register_cvar( "amx_extendmap_step", "15" );
    cvar_extendmapStepRounds    = register_cvar( "amx_extendmap_step_rounds", "30" );
    cvar_extendmapAllowStay     = register_cvar( "amx_extendmap_allow_stay", "0" );
    cvar_extendmapAllowOrder    = register_cvar( "amx_extendmap_allow_order", "0" );
    cvar_extendmapAllowStayType = register_cvar( "amx_extendmap_allow_stay_type", "0" );
    
    cvar_nextMapChange             = register_cvar( "gal_nextmap_change", "1" );
    cvar_showVoteCounter           = register_cvar( "gal_vote_show_counter", "0" );
    cvar_voteShowNoneOption        = register_cvar( "gal_vote_show_none", "0" );
    cvar_voteShowNoneOptionType    = register_cvar( "gal_vote_show_none_type", "0" );
    cvar_coloredChatEnabled        = register_cvar( "gal_colored_chat_enabled", "0", FCVAR_SPONLY );
    cvar_isToStopEmptyCycle        = register_cvar( "gal_in_empty_cycle", "0", FCVAR_SPONLY );
    cvar_unnominateDisconnected    = register_cvar( "gal_unnominate_disconnected", "0" );
    cvar_endOnRound                = register_cvar( "gal_endonround", "1" );
    cvar_endOnRound_rtv            = register_cvar( "gal_endonround_rtv", "0" );
    cvar_endOnRound_msg            = register_cvar( "gal_endonround_msg", "0" );
    cvar_voteWeight                = register_cvar( "gal_vote_weight", "1" );
    cvar_voteWeightFlags           = register_cvar( "gal_vote_weightflags", "y" );
    cvar_cmdVotemap                = register_cvar( "gal_cmd_votemap", "0" );
    cvar_cmdListmaps               = register_cvar( "gal_cmd_listmaps", "2" );
    cvar_listmapsPaginate          = register_cvar( "gal_listmaps_paginate", "10" );
    cvar_recentMapsBannedNumber    = register_cvar( "gal_banrecent", "3" );
    cvar_banRecentStyle            = register_cvar( "gal_banrecentstyle", "1" );
    cvar_endOfMapVote              = register_cvar( "gal_endofmapvote", "1" );
    cvar_isToAskForEndOfTheMapVote = register_cvar( "gal_endofmapvote_ask", "0" );
    cvar_emptyWait                 = register_cvar( "gal_emptyserver_wait", "0" );
    cvar_emptyServerChange         = register_cvar( "gal_emptyserver_change", "0" );
    cvar_emptyMapFilePath          = register_cvar( "gal_emptyserver_mapfile", "" );
    cvar_srvStart                  = register_cvar( "gal_srv_start", "0" );
    cvar_srvTimelimitRestart       = register_cvar( "gal_srv_timelimit_restart", "0" );
    cvar_srvMaxroundsRestart       = register_cvar( "gal_srv_maxrounds_restart", "0" );
    cvar_srvWinlimitRestart        = register_cvar( "gal_srv_winlimit_restart", "0" );
    cvar_rtvCommands               = register_cvar( "gal_rtv_commands", "3" );
    cvar_rtvWait                   = register_cvar( "gal_rtv_wait", "10" );
    cvar_rtvWaitRounds             = register_cvar( "gal_rtv_wait_rounds", "5" );
    cvar_rtvWaitAdmin              = register_cvar( "gal_rtv_wait_admin", "0" );
    cvar_rtvRatio                  = register_cvar( "gal_rtv_ratio", "0.60" );
    cvar_rtvReminder               = register_cvar( "gal_rtv_reminder", "2" );
    cvar_nomPlayerAllowance        = register_cvar( "gal_nom_playerallowance", "2" );
    cvar_nomMapFilePath            = register_cvar( "gal_nom_mapfile", "*" );
    cvar_nomPrefixes               = register_cvar( "gal_nom_prefixes", "1" );
    cvar_nomQtyUsed                = register_cvar( "gal_nom_qtyused", "0" );
    cvar_voteDuration              = register_cvar( "gal_vote_duration", "15" );
    cvar_voteExpCountdown          = register_cvar( "gal_vote_expirationcountdown", "1" );
    cvar_endMapCountdown           = register_cvar( "gal_endonround_countdown", "0" );
    cvar_voteMapChoiceCount        = register_cvar( "gal_vote_mapchoices", "5" );
    cvar_voteAnnounceChoice        = register_cvar( "gal_vote_announcechoice", "1" );
    cvar_voteStatus                = register_cvar( "gal_vote_showstatus", "1" );
    cvar_voteStatusType            = register_cvar( "gal_vote_showstatustype", "3" );
    cvar_voteUniquePrefixes        = register_cvar( "gal_vote_uniqueprefixes", "0" );
    cvar_runoffEnabled             = register_cvar( "gal_runoff_enabled", "0" );
    cvar_runoffDuration            = register_cvar( "gal_runoff_duration", "10" );
    cvar_soundsMute                = register_cvar( "gal_sounds_mute", "0" );
    cvar_voteMapFilePath           = register_cvar( "gal_vote_mapfile", "*" );
    cvar_voteMinPlayers            = register_cvar( "gal_vote_minplayers", "0" );
    cvar_voteMinPlayersMapFilePath = register_cvar( "gal_vote_minplayers_mapfile", "mapcycle.txt" );
    
    register_logevent( "game_commencing_event", 2, "0=World triggered", "1=Game_Commencing" )
    register_logevent( "team_win_event",        6, "0=Team" )
    register_logevent( "round_restart_event",   2, "0=World triggered", "1&Restart_Round_" )
    register_logevent( "round_start_event",     2, "1=Round_Start" )
    register_logevent( "round_end_event",       2, "1=Round_End" )
    
    nextmap_plugin_init()
    
    register_clcmd( "say", "cmd_say", -1 );
    register_clcmd( "votemap", "cmd_HL1_votemap" );
    register_clcmd( "listmaps", "cmd_HL1_listmaps" );
    
    register_concmd( "gal_startvote", "cmd_startVote", ADMIN_MAP );
    register_concmd( "gal_cancelvote", "cmd_cancelVote", ADMIN_MAP );
    register_concmd( "gal_createmapfile", "cmd_createMapFile", ADMIN_RCON );
    
    g_maxrounds_pointer  = get_cvar_pointer( "mp_maxrounds" )
    g_winlimit_pointer   = get_cvar_pointer( "mp_winlimit" )
    g_freezetime_pointer = get_cvar_pointer( "mp_freezetime" )
    g_timelimit_pointer  = get_cvar_pointer( "mp_timelimit" )

#if AMXX_VERSION_NUM < 183
    g_user_msgid = get_user_msgid( "SayText" )
#endif
    g_chooseMapMenuId         = register_menuid( MENU_CHOOSEMAP );
    g_chooseMapQuestionMenuId = register_menuid( MENU_CHOOSEMAP_QUESTION );
    
    register_menucmd( g_chooseMapMenuId, MENU_KEY_1 | MENU_KEY_2 |
            MENU_KEY_3 | MENU_KEY_4 | MENU_KEY_5 | MENU_KEY_6 |
            MENU_KEY_7 | MENU_KEY_8 | MENU_KEY_9 | MENU_KEY_0,
            "vote_handleChoice" )
    
    register_menucmd( g_chooseMapQuestionMenuId, MENU_KEY_6 | MENU_KEY_0, "handleEndOfTheMapVoteChoice" )
}

/**
 * Called when all plugins went through plugin_init( ).
 * When this forward is called, most plugins should have registered their
 * cvars and commands already.
 */
public plugin_cfg()
{
#if defined DEBUG
    g_tests_idsAndNames = ArrayCreate( SHORT_STRING )
    g_tests_delayed_ids = ArrayCreate( 1 )
    g_tests_failure_ids = ArrayCreate( 1 )
#endif
    reset_rounds_scores()
    
    copy( DIR_CONFIGS[ get_configsdir( DIR_CONFIGS, charsmax( DIR_CONFIGS ) ) ],
            charsmax( DIR_CONFIGS ), "/galileo" );
    
    copy( DIR_DATA[ get_datadir( DIR_DATA, charsmax( DIR_DATA ) ) ],
            charsmax( DIR_DATA ), "/galileo" );
    
    server_cmd( "exec %s/galileo.cfg", DIR_CONFIGS );
    server_exec();
    
    g_is_colored_chat_enabled = bool:get_pcvar_num( cvar_coloredChatEnabled )
    g_is_color_chat_supported = ( is_running( "czero" )
                                  || is_running( "cstrike" ) )
    
    if( colored_menus() )
    {
        copy( COLOR_RED, 2, "\r" );
        copy( COLOR_WHITE, 2, "\w" );
        copy( COLOR_YELLOW, 2, "\y" );
        copy( COLOR_GREY, 2, "\d" );
    }
    
    g_rtvWait                = get_pcvar_float( cvar_rtvWait );
    g_rtvWaitRounds          = get_pcvar_num( cvar_rtvWaitRounds );
    g_is_srvTimelimitRestart = bool:get_pcvar_num( cvar_srvTimelimitRestart );
    g_is_srvMaxroundsRestart = bool:get_pcvar_num( cvar_srvMaxroundsRestart );
    g_is_srvWinlimitRestart  = bool:get_pcvar_num( cvar_srvWinlimitRestart );
    
    get_pcvar_string( cvar_voteWeightFlags, g_voteWeightFlags, charsmax( g_voteWeightFlags ) );
    get_cvar_string( "amx_nextmap", g_nextmap, charsmax( g_nextmap ) );
    get_mapname( g_currentMap, charsmax( g_currentMap ) );
    DEBUG_LOGGER( 4, "Current MAP [%s]", g_currentMap )
    DEBUG_LOGGER( 4, "" )
    
    g_fillerMap        = ArrayCreate( MAX_MAPNAME_LENGHT );
    g_nominationMap    = ArrayCreate( MAX_MAPNAME_LENGHT );
    g_maxVotingChoices = max( min( sizeof g_votingMapNames, get_pcvar_num( cvar_voteMapChoiceCount ) ), 2 )
    
    // initialize nominations table
    nomination_clearAll();
    
    if( get_pcvar_num( cvar_recentMapsBannedNumber ) )
    {
        register_clcmd( "say recentmaps", "cmd_listrecent", 0 );
        
        map_loadRecentList();
        
        if( !( get_cvar_num( "gal_server_starting" )
               && get_pcvar_num( cvar_srvStart ) ) )
        {
            map_writeRecentList();
        }
    }
    
    if( get_pcvar_num( cvar_rtvCommands ) & RTV_CMD_STANDARD )
    {
        register_clcmd( "say rockthevote", "cmd_rockthevote", 0 );
    }
    
    if( get_pcvar_num( cvar_nomPlayerAllowance ) )
    {
        register_concmd( "gal_listmaps", "map_listAll" );
        register_clcmd( "say nominations", "cmd_nominations", 0, "- displays current \
                nominations for next map" );
        
        if( get_pcvar_num( cvar_nomPrefixes ) )
        {
            map_loadPrefixList();
        }
        map_loadNominationList();
    }
    
    if( get_cvar_num( "gal_server_starting" ) )
    {
        srv_handleStart();
    }
    
    if( get_pcvar_num( cvar_emptyWait ) )
    {
        g_emptyCycleMapList = ArrayCreate( MAX_MAPNAME_LENGHT );
        map_loadEmptyCycleList();
        set_task( 60.0, "inicializeEmptyCycleFeature" );
    }
    
    // setup the main task that schedules the end map voting and allow round finish feature.
    set_task( 15.0, "vote_manageEnd", _, _, _, "b" );

#if defined DEBUG
    // delayed because it need to wait the 'server.cfg' run to save its cvars
    if( g_debug_level & 128 )
    {
        set_task( 10.0, "runTests" )
    }
#endif
}

public team_win_event()
{
    new winlimit_integer
    new wins_Terrorist_trigger
    new wins_CT_trigger
    new string_team_winner[ 16 ]
    
    read_logargv( 1, string_team_winner, charsmax( string_team_winner ) )
    
    if( string_team_winner[ 0 ] == 'T' )
    {
        g_total_terrorists_wins++
    }
    else if( string_team_winner[ 0 ] == 'C' )
    {
        g_total_CT_wins++
    }
    
    winlimit_integer = get_pcvar_num( g_winlimit_pointer )
    
    if( winlimit_integer )
    {
        wins_CT_trigger        = g_total_CT_wins + VOTE_START_ROUNDS
        wins_Terrorist_trigger = g_total_terrorists_wins + VOTE_START_ROUNDS
        
        if( ( ( wins_CT_trigger > winlimit_integer )
              || ( wins_Terrorist_trigger > winlimit_integer ) )
            && !g_is_maxrounds_vote_map )
        {
            g_is_maxrounds_extend = false;
            
            VOTE_START_ROUNDS_DELAY()
        }
    }
    
    DEBUG_LOGGER( 32, "Team_Win: string_team_winner = %s, winlimit_integer = %d, \
            wins_CT_trigger = %d, wins_Terrorist_trigger = %d", \
            string_team_winner, winlimit_integer, wins_CT_trigger, wins_Terrorist_trigger )
}

public round_start_event()
{
    if( g_isTimeToResetRounds )
    {
        g_isTimeToResetRounds = false
        set_task( 1.0, "reset_rounds_scores" )
    }
    
    if( g_isTimeToResetGame )
    {
        g_isTimeToResetGame = false
        set_task( 1.0, "map_restoreOriginalTimeLimit" )
    }
}

public round_end_event()
{
    new maxrounds_number;
    new current_rounds_trigger
    
    g_total_rounds_played++
    
    maxrounds_number = get_pcvar_num( g_maxrounds_pointer )
    
    if( maxrounds_number )
    {
        current_rounds_trigger = g_total_rounds_played + VOTE_START_ROUNDS
        
        if( ( current_rounds_trigger > maxrounds_number )
            && !g_is_maxrounds_vote_map )
        {
            g_is_maxrounds_extend = true;
            
            VOTE_START_ROUNDS_DELAY()
        }
    }
    
    DEBUG_LOGGER( 32, "Round_End:  maxrounds_number = %d, \
            g_total_rounds_played = %d, current_rounds_trigger = %d", \
            maxrounds_number, g_total_rounds_played, current_rounds_trigger )
    
    if( g_is_last_round )
    {
        if( g_is_timeToChangeLevel
            || g_is_RTV_last_round ) // when time runs out, end map at the current round end
        {
            g_is_timeToChangeLevel = true
            g_is_RTV_last_round    = false
            g_is_last_round        = false
            
            remove_task( TASKID_SHOW_LAST_ROUND_HUD )
            set_task( 6.0, "process_last_round", TASKID_PROCESS_LAST_ROUND )
        }
        else // when time runs out, end map at the next round end
        {
            g_is_timeToChangeLevel = true
            
            remove_task( TASKID_SHOW_LAST_ROUND_HUD )
            set_task( 5.0, "configure_last_round_HUD", TASKID_PROCESS_LAST_ROUND )
        }
    }
}

public process_last_round()
{
    if( get_pcvar_num( cvar_endMapCountdown ) )
    {
        set_task( 1.0, "process_last_round_counting", TASKID_PROCESS_LAST_ROUND, _, _, "a", 5 );
    }
    else
    {
        intermission_display()
    }
}

public process_last_round_counting()
{
    static countdown = 5;
    
    // visual countdown
    set_hudmessage( 255, 10, 10, -1.0, 0.13, 0, 1.0, 0.94, 0.0, 0.0, -1 );
    show_hudmessage( 0, "%d %L...", countdown, LANG_PLAYER, "GAL_TIMELEFT" );
    
    // audio countdown
    if( !( get_pcvar_num( cvar_soundsMute ) & SOUND_COUNTDOWN ) )
    {
        new word[ 6 ];
        num_to_word( countdown, word, 5 );
        
        client_cmd( 0, "spk ^"fvox/%s^"", word );
    }
    
    // decrement the countdown
    countdown--;
    
    if( countdown == 0 )
    {
        countdown = 5;
        intermission_display()
    }
}

stock intermission_display()
{
    if( g_is_RTV_last_round )
    {
        configure_last_round_HUD()
    }
    
    if( g_is_timeToChangeLevel )
    {
        new Float:mp_chattime = get_cvar_float( "mp_chattime" )
        
        if( mp_chattime > 12 )
        {
            mp_chattime = 12.0
        }
        
        if( g_is_timeToRestart )
        {
            set_task( mp_chattime, "map_change_stays", TASKID_MAP_CHANGE );
        }
        else
        {
            set_task( mp_chattime, "map_change", TASKID_MAP_CHANGE );
        }
        
        if( get_pcvar_num( cvar_endMapCountdown ) )
        {
            // freeze the game and show the scoreboard
            g_original_sv_maxspeed = get_cvar_float( "sv_maxspeed" )
            set_cvar_float( "sv_maxspeed", 0.0 )
            
            client_cmd( 0, "slot1" )
            client_cmd( 0, "drop weapon_c4" )
            client_cmd( 0, "drop" )
            client_cmd( 0, "drop" )
            
            client_cmd( 0, "sgren" )
            client_cmd( 0, "hegren" )
            
            client_cmd( 0, "+showscores" )
            client_cmd( 0, "speak ^"loading environment on to your computer^"" )
        }
        else
        {
            // freeze the game and show the scoreboard
            message_begin( MSG_ALL, SVC_INTERMISSION );
            message_end();
        }
    }
}

public configure_last_round_HUD()
{
    if( bool:get_pcvar_num( cvar_endOnRound_msg ) )
    {
        set_task( 1.0, "show_last_round_HUD", TASKID_SHOW_LAST_ROUND_HUD, _, _, "b" )
    }
}

public show_last_round_HUD()
{
    set_hudmessage( 255, 255, 255, 0.15, 0.15, 0, 0.0, 1.0, 0.1, 0.1, 1 )
    
    static last_round_message[ COLOR_MESSAGE ]

#if AMXX_VERSION_NUM < 183
    static player_id
    static current_index
    static playersCount
    static players[ MAX_PLAYERS ]
#endif
    last_round_message[ 0 ] = '^0'
    
    if( g_is_timeToChangeLevel
        || g_is_RTV_last_round )
    {
        // This is because the Amx Mod X 1.8.2 is not recognizing the player LANG_PLAYER when it is
        // formatted before with formatex(...)
    #if AMXX_VERSION_NUM < 183
        get_players( players, playersCount, "ch" );
        
        for( current_index = 0; current_index < playersCount; current_index++ )
        {
            player_id = players[ current_index ]
            
            formatex( last_round_message, charsmax( last_round_message ), "%L ^n%L",
                    player_id, "GAL_CHANGE_NEXTROUND",  player_id, "GAL_NEXTMAP", g_nextmap )
            
            REMOVE_COLOR_TAGS( last_round_message )
            show_hudmessage( player_id, last_round_message )
        }
    #else
        formatex( last_round_message, charsmax( last_round_message ), "%L ^n%L",
                LANG_PLAYER, "GAL_CHANGE_NEXTROUND",  LANG_PLAYER, "GAL_NEXTMAP", g_nextmap )
        
        REMOVE_COLOR_TAGS( last_round_message )
        show_hudmessage( 0, last_round_message )
    #endif
    }
    else
    {
    #if AMXX_VERSION_NUM < 183
        get_players( players, playersCount, "ch" );
        
        for( current_index = 0; current_index < playersCount; current_index++ )
        {
            player_id = players[ current_index ]
            
            formatex( last_round_message, charsmax( last_round_message ), "%L", player_id,
                    "GAL_CHANGE_TIMEEXPIRED" )
            
            REMOVE_COLOR_TAGS( last_round_message )
            show_hudmessage( player_id, last_round_message )
        }
    #else
        formatex( last_round_message, charsmax( last_round_message ), "%L", LANG_PLAYER,
                "GAL_CHANGE_TIMEEXPIRED" )
        
        REMOVE_COLOR_TAGS( last_round_message )
        show_hudmessage( 0, last_round_message )
    #endif
    }
}

public plugin_end()
{
    DEBUG_LOGGER( 32, "^n AT: plugin_end" )
    
    map_restoreOriginalTimeLimit()

#if defined DEBUG
    restore_server_cvars_for_test()
    ArrayDestroy( g_tests_idsAndNames )
    ArrayDestroy( g_tests_delayed_ids )
    ArrayDestroy( g_tests_failure_ids )
#endif
}

/**
 * Indicates which action to take when it is detected that the server
 * has been 'externally restarted'. By 'externally restarted', is mean to
 * say the Computer's Operational System (Linux) or Server Manager (HLSW),
 * used the server command 'quit' and reopened the server.
 *
 * 0 - stay on the map the server started with
 * 1 - change to the map that was being played when the server was reset
 * 2 - change to what would have been the next map had the server not
 *     been restarted ( if the next map isn't known, this acts like 3 )
 * 3 - start an early map vote after the first two minutes
 * 4 - change to a randomly selected map from your nominatable map list
 */
public srv_handleStart()
{
    // this is the key that tells us if this server has been restarted or not
    set_cvar_num( "gal_server_starting", 0 );
    
    // take the defined "server start" action
    new startAction = get_pcvar_num( cvar_srvStart );
    
    if( startAction )
    {
        new nextMap[ MAX_MAPNAME_LENGHT ];
        
        if( startAction == SRV_START_CURRENTMAP
            || startAction == SRV_START_NEXTMAP )
        {
            new backupMapsFilePath[ MAX_FILE_PATH_LENGHT ];
            formatex( backupMapsFilePath, charsmax( backupMapsFilePath ), "%s/info.dat", DIR_DATA );
            
            new backupMapsFile = fopen( backupMapsFilePath, "rt" );
            
            if( backupMapsFile )
            {
                fgets( backupMapsFile, nextMap, charsmax( nextMap ) );
                
                if( startAction == SRV_START_NEXTMAP )
                {
                    nextMap[ 0 ] = '^0';
                    fgets( backupMapsFile, nextMap, charsmax( nextMap )  );
                }
            }
            fclose( backupMapsFile );
        }
        else if( startAction == SRV_START_RANDOMMAP )
        {
            // pick a random map from allowable nominations
            
            // if noms aren't allowed, the nomination list hasn't already been loaded
            if( get_pcvar_num( cvar_nomPlayerAllowance ) == 0 )
            {
                map_loadNominationList();
            }
            
            if( g_nominationMapCnt )
            {
                ArrayGetString( g_nominationMap, random_num( 0, g_nominationMapCnt - 1 ), nextMap,
                        charsmax( nextMap )  );
            }
        }
        
        trim( nextMap );
        
        if( nextMap[ 0 ]
            && is_map_valid( nextMap ) )
        {
            server_cmd( "changelevel %s", nextMap );
        }
        else
        {
            vote_manageEarlyStart();
        }
    }
}

/**
 * Action of srv_handleStart to take when it is detected that the server has been
 *   restarted. 3 - start an early map vote after the first two minutes.
 */
stock vote_manageEarlyStart()
{
    g_voteStatus |= VOTE_IS_EARLY;
    
    set_task( 120.0, "vote_startDirector", TASKID_VOTE_STARTDIRECTOR );
}

stock map_setNext( nextMap[] )
{
    // set the queryable cvar
    set_cvar_string( "amx_nextmap", nextMap );
    
    copy( g_nextmap, charsmax( g_nextmap ), nextMap );
    
    // update our data file
    new backupMapsFilePath[ MAX_FILE_PATH_LENGHT ];
    
    formatex( backupMapsFilePath, charsmax( backupMapsFilePath ), "%s/info.dat", DIR_DATA );
    
    new backupMapsFile = fopen( backupMapsFilePath, "wt" );
    
    if( backupMapsFile )
    {
        fprintf( backupMapsFile, "%s", g_currentMap );
        fprintf( backupMapsFile, "^n%s", nextMap );
        fclose( backupMapsFile );
    }
}

public vote_manageEnd()
{
    new secondsLeft = get_timeleft();
    
    // are we ready to start an "end of map" vote?
    if( ( secondsLeft < START_VOTEMAP_MIN_TIME )
        && ( secondsLeft > START_VOTEMAP_MAX_TIME )
        && !g_is_maxrounds_vote_map
        && get_pcvar_num( cvar_endOfMapVote ) )
    {
        vote_startDirector( false );
    }
    
    // are we managing the end of the map?
    if( secondsLeft < 30
        && secondsLeft > 0
        && !g_is_last_round
        && get_realplayersnum() >= get_pcvar_num( cvar_endOnRound_msg ) )
    {
        map_manageEnd();
    }
}

public map_manageEnd()
{
    DEBUG_LOGGER( 2, "%32s mp_timelimit: %f", "map_manageEnd(in)", get_pcvar_float( g_timelimit_pointer ) )
    
    switch( get_pcvar_num( cvar_endOnRound ) )
    {
        case 1: // when time runs out, end at the current round end
        {
            g_is_last_round        = true;
            g_is_timeToChangeLevel = true;
            
            color_print( 0, "^1%L %L %L", LANG_PLAYER, "GAL_CHANGE_TIMEEXPIRED",
                    LANG_PLAYER, "GAL_CHANGE_NEXTROUND", LANG_PLAYER, "GAL_NEXTMAP", g_nextmap )
            
            prevent_map_change()
        }
        case 2: // when time runs out, end at the next round end
        {
            g_is_last_round = true;
            
            // This is to avoid have a extra round at special mods where time limit is equal the
            // round timer.
            if( get_cvar_float( "mp_roundtime" ) > 8 )
            {
                g_is_timeToChangeLevel = true;
                
                color_print( 0, "^1%L %L %L", LANG_PLAYER, "GAL_CHANGE_TIMEEXPIRED",
                        LANG_PLAYER, "GAL_CHANGE_NEXTROUND", LANG_PLAYER, "GAL_NEXTMAP", g_nextmap )
            }
            else
            {
                color_print( 0, "^1%L %L", LANG_PLAYER, "GAL_CHANGE_TIMEEXPIRED",
                        LANG_PLAYER, "GAL_NEXTMAP", g_nextmap );
            }
            
            prevent_map_change()
        }
    }
    
    configure_last_round_HUD()
    
    DEBUG_LOGGER( 2, "%32s mp_timelimit: %f", "map_manageEnd(out)", get_pcvar_float( g_timelimit_pointer ) )
}

stock prevent_map_change()
{
    save_time_limit()
    
    // prevent the map from ending automatically
    server_cmd( "mp_timelimit 0" );
}

public map_loadRecentList()
{
    new recentMapsFilePath[ MAX_FILE_PATH_LENGHT ];
    formatex( recentMapsFilePath, charsmax( recentMapsFilePath ), "%s/recentmaps.dat", DIR_DATA );
    
    new recentMapsFile = fopen( recentMapsFilePath, "rt" );
    
    if( recentMapsFile )
    {
        new recentMapName[ MAX_MAPNAME_LENGHT ];
        new maxRecentMapsBans = min( get_pcvar_num( cvar_recentMapsBannedNumber ), sizeof g_recentMap )
        
        while( !feof( recentMapsFile ) )
        {
            fgets( recentMapsFile, recentMapName, charsmax( recentMapName ) );
            trim( recentMapName );
            
            if( recentMapName[ 0 ] )
            {
                if( g_cntRecentMap == maxRecentMapsBans )
                {
                    break;
                }
                copy( g_recentMap[ g_cntRecentMap++ ], charsmax( recentMapName ), recentMapName );
            }
        }
        fclose( recentMapsFile );
    }
}

public map_writeRecentList()
{
    new recentMapsFilePath[ MAX_FILE_PATH_LENGHT ];
    formatex( recentMapsFilePath, charsmax( recentMapsFilePath ), "%s/recentmaps.dat", DIR_DATA );
    
    new recentMapsFile = fopen( recentMapsFilePath, "wt" );
    
    if( recentMapsFile )
    {
        fprintf( recentMapsFile, "%s", g_currentMap );
        
        for( new mapIndex = 0; mapIndex < get_pcvar_num( cvar_recentMapsBannedNumber ) - 1; ++mapIndex )
        {
            fprintf( recentMapsFile, "^n%s", g_recentMap[ mapIndex ] );
        }
        
        fclose( recentMapsFile );
    }
}

public map_loadFillerList( fillerFileNamePath[] )
{
    return map_populateList( g_fillerMap, fillerFileNamePath );
}

public cmd_rockthevote( player_id )
{
    color_print( player_id, "^1%L", player_id, "GAL_CMD_RTV" );
    
    vote_rock( player_id );
    return PLUGIN_CONTINUE;
}

public cmd_nominations( player_id )
{
    color_print( player_id, "^1%L", player_id, "GAL_CMD_NOMS" );
    
    nomination_list( player_id );
    return PLUGIN_CONTINUE;
}

public cmd_listrecent( player_id )
{
    switch( get_pcvar_num( cvar_banRecentStyle ) )
    {
        case 1:
        {
            new msg[ 101 ], msgIdx;
            
            for( new idx = 0; idx < g_cntRecentMap; ++idx )
            {
                msgIdx += formatex( msg[ msgIdx ], charsmax( msg ) - msgIdx, ", %s", g_recentMap[ idx ] );
            }
            
            color_print( 0, "^1%L: %s", LANG_PLAYER, "GAL_MAP_RECENTMAPS", msg[ 2 ] );
        }
        case 2:
        {
            for( new idx = 0; idx < g_cntRecentMap; ++idx )
            {
                color_print( 0, "^1%L ( %i ): %s", LANG_PLAYER, "GAL_MAP_RECENTMAP",
                        idx + 1, g_recentMap[ idx ] );
            }
        }
        case 3:
        {
            // assume there'll be more than one match ( because we're lazy ) and starting building the match menu
            if( g_nominationMatchesMenu[ player_id ] )
            {
                menu_destroy( g_nominationMatchesMenu[ player_id ] );
            }
            
            new recent_maps_menu_name[ 64 ]
            
            formatex( recent_maps_menu_name, charsmax( recent_maps_menu_name ), "%L",
                    player_id, "GAL_MAP_RECENTMAPS" )
            
            g_nominationMatchesMenu[ player_id ] = menu_create( "Nominate Map", "cmd_listrecent_handler" );
            
            for( new idx = 0; idx < g_cntRecentMap; ++idx )
            {
                menu_additem( g_nominationMatchesMenu[ player_id ], g_recentMap[ idx ] )
            }
            
            menu_display( player_id, g_nominationMatchesMenu[ player_id ] )
        }
    }
    
    return PLUGIN_HANDLED;
}

public cmd_listrecent_handler( player_id, menu, item )
{
    if( item < 0 )
    {
        return PLUGIN_CONTINUE;
    }
    
    menu_display( player_id, g_nominationMatchesMenu[ player_id ] )
    
    return PLUGIN_HANDLED;
}

public cmd_cancelVote( player_id, level, cid )
{
    if( !cmd_access( player_id, level, cid, 1 ) )
    {
        return PLUGIN_HANDLED;
    }
    
    cancel_voting()
    
    return PLUGIN_HANDLED;
}

/**
 * Called when need to start a vote map, where the command line arg1 could be:
 *    -nochange: extend the current map, aka, Keep Current Map, will to do the real extend.
 *    -restart: extend the current map, aka, Keep Current Map restart the server at the current map.
 */
public cmd_startVote( player_id, level, cid )
{
    DEBUG_LOGGER( 1, "( in ) cmd_startVote()| player_id: %d, level: %d, cid: %d", player_id, level, cid )
    
    if( !cmd_access( player_id, level, cid, 1 ) )
    {
        return PLUGIN_HANDLED;
    }
    
    if( g_voteStatus & VOTE_IN_PROGRESS )
    {
        color_print( player_id, "^1%L", player_id, "GAL_VOTE_INPROGRESS" );
    }
    else
    {
        g_voteStatus          |= VOTE_IS_EARLY
        g_is_timeToChangeLevel = true;
        
        if( read_argc() == 2 )
        {
            new argument[ 32 ];
            read_args( argument, charsmax( argument ) );
            remove_quotes( argument )
            
            if( equali( argument, "-nochange" ) )
            {
                g_is_timeToChangeLevel = false;
            }
            
            DEBUG_LOGGER( 1, "( inside ) cmd_startVote()| argument: %s", \
                    argument )
            
            if( equali( argument, "-restart", 4 ) )
            {
                g_is_timeToRestart = true;
            }
            
            DEBUG_LOGGER( 1, "( inside ) cmd_startVote() | \
                    equal( argument, ^"-restart^", 4 ): %d", \
                    equal( argument, "-restart", 4 ) )
        }
        
        DEBUG_LOGGER( 1, "( cmd_startVote ) g_is_timeToRestart: %d, g_is_timeToChangeLevel: %d \
                g_voteStatus & VOTE_IS_EARLY: %d", \
                g_is_timeToRestart, g_is_timeToChangeLevel, g_voteStatus & VOTE_IS_EARLY )
        
        vote_startDirector( true );
    }
    
    return PLUGIN_HANDLED;
}

stock map_populateList( Array:mapArray, mapFilePath[] )
{
    // clear the map array in case we're reusing it
    ArrayClear( mapArray );
    
    // load the array with maps
    new mapCount;
    
    if( !equal( mapFilePath, "*" )
        && !equal( mapFilePath, "#" ) )
    {
        new mapFile = fopen( mapFilePath, "rt" );
        
        if( mapFile )
        {
            new loadedMapName[ MAX_MAPNAME_LENGHT ];
            
            while( !feof( mapFile ) )
            {
                fgets( mapFile, loadedMapName, charsmax( loadedMapName ) );
                trim( loadedMapName );
                
                if( loadedMapName[ 0 ]
                    && !equal( loadedMapName, "//", 2 )
                    && !equal( loadedMapName, ";", 1 )
                    && is_map_valid( loadedMapName ) )
                {
                    ArrayPushString( mapArray, loadedMapName );
                    ++mapCount;
                    DEBUG_LOGGER( 4, "map_populateList(...) loadedMapName = %s", loadedMapName )
                }
            }
            
            fclose( mapFile );
            DEBUG_LOGGER( 4, "" )
        }
        else
        {
            log_error( AMX_ERR_NOTFOUND, "%L", LANG_SERVER, "GAL_MAPS_FILEMISSING", mapFilePath );
        }
    }
    else
    {
        if( equal( mapFilePath, "*" ) )
        {
            new mapName[ MAX_MAPNAME_LENGHT ]
            
            // no mapFile provided, assuming contents of "maps" folder
            new dir = open_dir( "maps", mapName, charsmax( mapName ) );
            
            if( dir )
            {
                new lenMapName;
                
                while( next_file( dir, mapName, charsmax( mapName ) ) )
                {
                    lenMapName = strlen( mapName );
                    
                    if( lenMapName > 4
                        && equali( mapName[ lenMapName - 4 ], ".bsp", 4 ) )
                    {
                        mapName[ lenMapName - 4 ] = '^0';
                        
                        if( is_map_valid( mapName ) )
                        {
                            ArrayPushString( mapArray, mapName );
                            ++mapCount;
                        }
                    }
                }
                close_dir( dir );
            }
            else
            {
                // directory not found, wtf?
                log_error( AMX_ERR_NOTFOUND, "%L", LANG_SERVER, "GAL_MAPS_FOLDERMISSING" );
            }
        }
        else
        {
            get_cvar_string( "mapcyclefile", mapFilePath, strlen( mapFilePath ) );
            
            new mapFile = fopen( mapFilePath, "rt" );
            
            if( mapFile )
            {
                new loadedMapName[ MAX_MAPNAME_LENGHT ];
                
                while( !feof( mapFile ) )
                {
                    fgets( mapFile, loadedMapName, charsmax( loadedMapName ) );
                    trim( loadedMapName );
                    
                    if( loadedMapName[ 0 ]
                        && !equal( loadedMapName, "//", 2 )
                        && !equal( loadedMapName, ";", 1 )
                        && is_map_valid( loadedMapName ) )
                    {
                        ArrayPushString( mapArray, loadedMapName );
                        ++mapCount;
                    }
                }
                fclose( mapFile );
            }
            else
            {
                log_error( AMX_ERR_NOTFOUND, "%L", LANG_SERVER, "GAL_MAPS_FILEMISSING", mapFilePath );
            }
        }
    }
    return mapCount;
}

public map_loadNominationList()
{
    new nomMapFilePath[ MAX_FILE_PATH_LENGHT ];
    get_pcvar_string( cvar_nomMapFilePath, nomMapFilePath, charsmax( nomMapFilePath ) );
    
    DEBUG_LOGGER( 4, "( map_loadNominationList() ) cvar_nomMapFilePath nomMapFilePath: %s", nomMapFilePath )
    
    g_nominationMapCnt = map_populateList( g_nominationMap, nomMapFilePath );
}

public cmd_createMapFile( player_id, level, cid )
{
    if( !cmd_access( player_id, level, cid, 1 ) )
    {
        return PLUGIN_HANDLED
    }
    
    new argumentsNumber = read_argc() - 1
    
    switch( argumentsNumber )
    {
        case 1:
        {
            new mapFileName[ MAX_MAPNAME_LENGHT ];
            read_argv( 1, mapFileName, charsmax( mapFileName ) );
            remove_quotes( mapFileName );
            
            // map name is MAX_MAPNAME_LENGHT ( i.e. MAX_MAPNAME_LENGHT ), ".bsp" is 4, string terminator is 1.
            new mapName[ MAX_MAPNAME_LENGHT + 5 ];
            
            new dir
            new mapFile
            new mapCount
            new lenMapName
            
            dir = open_dir( "maps", mapName, charsmax( mapName )  );
            
            if( dir )
            {
                new mapFilePath[ MAX_FILE_PATH_LENGHT ];
                formatex( mapFilePath, charsmax( mapFilePath ), "%s/%s", DIR_CONFIGS, mapFileName );
                
                mapFile = fopen( mapFilePath, "wt" );
                
                if( mapFile )
                {
                    mapCount = 0;
                    
                    while( next_file( dir, mapName, charsmax( mapName ) ) )
                    {
                        lenMapName = strlen( mapName );
                        
                        if( lenMapName > 4
                            && equali( mapName[ lenMapName - 4 ], ".bsp", 4 ) )
                        {
                            mapName[ lenMapName - 4 ] = '^0';
                            
                            if( is_map_valid( mapName ) )
                            {
                                mapCount++;
                                fprintf( mapFile, "%s^n", mapName );
                            }
                        }
                    }
                    fclose( mapFile );
                    con_print( player_id, "%L", LANG_SERVER, "GAL_CREATIONSUCCESS", mapFilePath, mapCount );
                }
                else
                {
                    con_print( player_id, "%L", LANG_SERVER, "GAL_CREATIONFAILED", mapFilePath );
                }
                close_dir( dir );
            }
            else
            {
                // directory not found, wtf?
                con_print( player_id, "%L", LANG_SERVER, "GAL_MAPSFOLDERMISSING" );
            }
        }
        default:
        {
            // inform of correct usage
            con_print( player_id, "%L", player_id, "GAL_CMD_CREATEFILE_USAGE1" );
            con_print( player_id, "%L", player_id, "GAL_CMD_CREATEFILE_USAGE2" );
        }
    }
    return PLUGIN_HANDLED;
}

stock map_loadEmptyCycleList()
{
    new emptyCycleFilePath[ MAX_FILE_PATH_LENGHT ];
    get_pcvar_string( cvar_emptyMapFilePath, emptyCycleFilePath, charsmax( emptyCycleFilePath ) );
    
    g_emptyCycleMapsNumber = map_populateList( g_emptyCycleMapList, emptyCycleFilePath );
    
    DEBUG_LOGGER( 4, "( map_loadEmptyCycleList() ) g_emptyCycleMapsNumber = %d", g_emptyCycleMapsNumber )
}

public map_loadPrefixList()
{
    new prefixesFilePath[ MAX_FILE_PATH_LENGHT ];
    formatex( prefixesFilePath, charsmax( prefixesFilePath ), "%s/prefixes.ini", DIR_CONFIGS );
    
    new prefixesFile = fopen( prefixesFilePath, "rt" );
    
    if( prefixesFile )
    {
        new loadedMapPrefix[ 16 ];
        
        while( !feof( prefixesFile ) )
        {
            fgets( prefixesFile, loadedMapPrefix, charsmax( loadedMapPrefix ) );
            
            if( loadedMapPrefix[ 0 ]
                && !equal( loadedMapPrefix, "//", 2 ) )
            {
                if( g_mapPrefixCnt <= MAX_PREFIX_COUNT )
                {
                    trim( loadedMapPrefix );
                    copy( g_mapPrefix[ g_mapPrefixCnt++ ], charsmax( loadedMapPrefix ), loadedMapPrefix );
                }
                else
                {
                    log_error( AMX_ERR_BOUNDS, "%L", LANG_SERVER, "GAL_PREFIXES_TOOMANY",
                            MAX_PREFIX_COUNT, prefixesFilePath );
                    break;
                }
            }
        }
        fclose( prefixesFile );
    }
    else
    {
        log_error( AMX_ERR_NOTFOUND, "%L", LANG_SERVER, "GAL_PREFIXES_NOTFOUND", prefixesFilePath );
    }
    return PLUGIN_HANDLED;
}

/**
 * Reset rounds scores every game restart event.
 */
public round_restart_event()
{
    g_isTimeToResetRounds = true
    
    reset_round_ending()
}

/**
 * Make sure the reset time is the original time limit, can be skewed if map was previously extended.
 * It is delayed because if we are at g_is_last_round, we need to wait the game restart.
 */
public game_commencing_event()
{
    g_isTimeToResetGame = true
    
    round_restart_event()
    cancel_voting()
    
    DEBUG_LOGGER( 32, "^n AT: game_commencing_event" )
}

/**
 * Reset the round ending, if it is in progress.
 */
stock reset_round_ending()
{
    g_is_timeToChangeLevel = false
    g_is_timeToRestart     = false
    g_is_RTV_last_round    = false
    g_is_last_round        = false
    
    remove_task( TASKID_SHOW_LAST_ROUND_HUD )
    
    client_cmd( 0, "-showscores" )
}

public start_voting_by_rounds()
{
    DEBUG_LOGGER( 1, "At start_voting_by_rounds --- get_pcvar_num( cvar_endOfMapVote ): %d", \
            get_pcvar_num( cvar_endOfMapVote ) )
    
    if( get_pcvar_num( cvar_endOfMapVote ) )
    {
        vote_startDirector( false )
    }
}

public reset_rounds_scores()
{
    if( g_is_srvTimelimitRestart
        || g_is_srvWinlimitRestart
        || g_is_srvMaxroundsRestart )
    {
        save_time_limit()
        
        if( get_pcvar_num( g_timelimit_pointer )
            && g_is_srvTimelimitRestart )
        {
            new new_timelimit = ( floatround(
                                          get_pcvar_num( g_timelimit_pointer )
                                          - map_getMinutesElapsed(), floatround_floor )
                                  + get_pcvar_num( cvar_srvTimelimitRestart ) - 1 )
            
            if( new_timelimit > 0 )
            {
                set_pcvar_num( g_timelimit_pointer, new_timelimit )
            }
        }
        
        if( get_pcvar_num( g_winlimit_pointer )
            && g_is_srvWinlimitRestart )
        {
            new new_winlimit = ( get_pcvar_num( g_winlimit_pointer )
                                 - max( g_total_terrorists_wins, g_total_CT_wins )
                                 + get_pcvar_num( cvar_srvWinlimitRestart ) - 1 )
            
            if( new_winlimit > 0 )
            {
                set_pcvar_num( g_winlimit_pointer, new_winlimit )
            }
        }
        
        if( get_pcvar_num( g_maxrounds_pointer )
            && g_is_srvMaxroundsRestart )
        {
            new new_maxrounds = ( get_pcvar_num( g_maxrounds_pointer ) - g_total_rounds_played
                                  + get_pcvar_num( cvar_srvMaxroundsRestart ) - 1 )
            
            if( new_maxrounds > 0 )
            {
                set_pcvar_num( g_maxrounds_pointer, new_maxrounds )
            }
        }
    }
    
    g_total_terrorists_wins = 0
    g_total_CT_wins         = 0
    g_total_rounds_played   = -1
}

stock map_getIdx( text[] )
{
    new map[ MAX_MAPNAME_LENGHT ];
    new mapIndex;
    new nominationMap[ MAX_MAPNAME_LENGHT ];
    
    for( new prefixIdx = 0; prefixIdx < g_mapPrefixCnt; ++prefixIdx )
    {
        formatex( map, charsmax( map ), "%s%s", g_mapPrefix[ prefixIdx ], text );
        
        for( mapIndex = 0; mapIndex < g_nominationMapCnt; ++mapIndex )
        {
            ArrayGetString( g_nominationMap, mapIndex, nominationMap, charsmax( nominationMap ) );
            
            if( equal( map, nominationMap ) )
            {
                return mapIndex;
            }
        }
    }
    return -1;
}

/**
 * Generic say handler to determine if we need to act on what was said.
 */
public cmd_say( player_id )
{
    static text[ 70 ]
    static arg1[ 32 ]
    static arg2[ 32 ]
    static arg3[ 2 ]
    
    static prefix_index
    
    text[ 0 ] = '^0'
    arg1[ 0 ] = '^0'
    arg2[ 0 ] = '^0'
    arg3[ 0 ] = '^0'
    
    read_args( text, charsmax( text ) );
    remove_quotes( text );
    
    parse( text, arg1, charsmax( arg1 ), arg2, charsmax( arg2 ), arg3, charsmax( arg3 ) )
    
    DEBUG_LOGGER( 4, "( cmd_say ) text: %s, arg1: %s, arg2: %s, arg3: %s", text, arg1, arg2, arg3 )
    
    // if the chat line has more than 2 words, we're not interested at all
    if( arg3[ 0 ] == '^0' )
    {
        new mapIndex;
        
        DEBUG_LOGGER( 4, "( cmd_say ) On: arg3[ 0 ] == '^0'" )
        
        // if the chat line contains 1 word, it could be a map or a one-word command
        if( arg2[ 0 ] == '^0' ) // "say [rtv|rockthe<anything>vote]"
        {
            DEBUG_LOGGER( 4, "( cmd_say ) On: arg2[ 0 ] == '^0'" )
            
            if( ( get_pcvar_num( cvar_rtvCommands ) & RTV_CMD_SHORTHAND
                  && equali( arg1, "rtv" ) )
                || ( get_pcvar_num( cvar_rtvCommands ) & RTV_CMD_DYNAMIC
                     && equali( arg1, "rockthe", 7 )
                     && equali( arg1[ strlen( arg1 ) - 4 ], "vote" ) ) )
            {
                DEBUG_LOGGER( 4, "( cmd_say ) On: vote_rock( player_id );'" )
                
                vote_rock( player_id );
                return PLUGIN_HANDLED;
            }
            else if( get_pcvar_num( cvar_nomPlayerAllowance ) )
            {
                DEBUG_LOGGER( 4, "( cmd_say ) On: else if( get_pcvar_num( cvar_nomPlayerAllowance ) ) " )
                
                if( equali( arg1, "noms" )
                    || equali( arg1, "nominations" ) )
                {
                    nomination_list( player_id );
                    
                    return PLUGIN_HANDLED;
                }
                else
                {
                    mapIndex = map_getIdx( arg1 )
                    
                    if( mapIndex >= 0 )
                    {
                        nomination_toggle( player_id, mapIndex );
                        
                        return PLUGIN_HANDLED;
                    }
                    else if( strlen( arg1 ) > 5
                             && equali( arg1, "nom", 3 )
                             && equali( arg1[ strlen( arg1 ) - 4 ], "menu" ) )
                    {
                        nomination_menu( player_id )
                    }
                    else // if contains a prefix
                    {
                        for( prefix_index = 0; prefix_index < g_mapPrefixCnt; prefix_index++ )
                        {
                            DEBUG_LOGGER( 4, "( cmd_say ) arg1: %s, prefix_index: %d, \
                                    g_mapPrefix[ prefix_index ]: %s, \
                                    contain( arg1, g_mapPrefix[ prefix_index ] ): %d", \
                                    arg1, prefix_index, g_mapPrefix[ prefix_index ], \
                                    contain( arg1, g_mapPrefix[ prefix_index ] ) )
                            
                            if( contain( arg1, g_mapPrefix[ prefix_index ] ) > -1 )
                            {
                                nomination_menu( player_id )
                                break;
                            }
                        }
                    }
                    
                    DEBUG_LOGGER( 4, "( cmd_say ) equali( arg1, 'nom', 3 ): %d, \
                            strlen( arg1 ) > 5: %d", \
                            equali( arg1, "nom", 3 ), strlen( arg1 ) > 5 )
                }
            }
        }
        else if( get_pcvar_num( cvar_nomPlayerAllowance ) )  // "say <nominate|nom|cancel> <map>"
        {
            if( equali( arg1, "nominate" )
                || equali( arg1, "nom" ) )
            {
                nomination_attempt( player_id, arg2 );
                return PLUGIN_HANDLED;
            }
            else if( equali( arg1, "cancel" ) )
            {
                // bpj -- allow ambiguous cancel in which case a menu of their nominations is shown
                mapIndex = map_getIdx( arg2 );
                
                if( mapIndex >= 0 )
                {
                    nomination_cancel( player_id, mapIndex );
                    return PLUGIN_HANDLED;
                }
            }
        }
    }
    return PLUGIN_CONTINUE;
}

stock nomination_menu( player_id )
{
    // assume there'll be more than one match ( because we're lazy ) and starting building the match menu
    if( g_nominationMatchesMenu[ player_id ] )
    {
        menu_destroy( g_nominationMatchesMenu[ player_id ] );
    }
    
    g_nominationMatchesMenu[ player_id ] = menu_create( "Nominate Map", "nomination_handleMatchChoice" );
    
    // gather all maps that match the nomination
    new mapIndex
    
    new info[ 1 ]
    new choice[ MAX_MAPNAME_LENGHT + 32 ]
    new nominationMap[ MAX_MAPNAME_LENGHT ]
    new disabledReason[ 16 ]
    
    for( mapIndex = 0; mapIndex < g_nominationMapCnt; mapIndex++ )
    {
        ArrayGetString( g_nominationMap, mapIndex, nominationMap, charsmax( nominationMap ) );
        
        info[ 0 ] = mapIndex;
        
        // in most cases, the map will be available for selection, so assume that's the case here
        disabledReason[ 0 ] = '^0';
        
        if( nomination_getPlayer( mapIndex ) ) // disable if the map has already been nominated
        {
            formatex( disabledReason, charsmax( disabledReason ), "%L", player_id,
                    "GAL_MATCH_NOMINATED" );
        }
        else if( map_isTooRecent( nominationMap ) ) // disable if the map is too recent
        {
            formatex( disabledReason, charsmax( disabledReason ), "%L", player_id,
                    "GAL_MATCH_TOORECENT" );
        }
        else if( equal( g_currentMap, nominationMap ) ) // disable if the map is the current map
        {
            formatex( disabledReason, charsmax( disabledReason ), "%L", player_id,
                    "GAL_MATCH_CURRENTMAP" );
        }
        
        formatex( choice, charsmax( choice ), "%s %s", nominationMap, disabledReason )
        
        menu_additem( g_nominationMatchesMenu[ player_id ], choice, info,
                ( disabledReason[ 0 ] == '^0' ? 0 : ( 1 << 26 ) ) )
        
        DEBUG_LOGGER( 0, "( nomination_menu ) choice: %s, info[0]: %d", choice, info[ 0 ] )
    }
    
    menu_display( player_id, g_nominationMatchesMenu[ player_id ] )
}

stock nomination_attempt( player_id, nomination[] ) // ( playerName[], &phraseIdx, matchingSegment[] )
{
    // all map names are stored as lowercase, so normalize the nomination
    strtolower( nomination );
    
    // assume there'll be more than one match ( because we're lazy ) and starting building the match menu
    menu_destroy( g_nominationMatchesMenu[ player_id ] );
    
    g_nominationMatchesMenu[ player_id ] = menu_create( "Nominate Map", "nomination_handleMatchChoice" );
    
    // gather all maps that match the nomination
    new mapIndex
    
    new matchCnt = 0
    new matchIdx = -1
    
    new info[ 1 ]
    new choice[ MAX_MAPNAME_LENGHT + 32 ]
    new nominationMap[ MAX_MAPNAME_LENGHT ]
    new disabledReason[ 16 ]
    
    for( mapIndex = 0; mapIndex < g_nominationMapCnt
         && matchCnt <= MAX_NOM_MATCH_COUNT; ++mapIndex )
    {
        ArrayGetString( g_nominationMap, mapIndex, nominationMap, charsmax( nominationMap ) );
        
        if( contain( nominationMap, nomination ) > -1 )
        {
            matchCnt++;
            matchIdx = mapIndex;    // store in case this is the only match
            
            // there may be a much better way of doing this, but I didn't feel like
            // storing the matches and mapIndex's only to loop through them again
            info[ 0 ] = mapIndex;
            
            // in most cases, the map will be available for selection, so assume that's the case here
            disabledReason[ 0 ] = '^0';
            
            if( nomination_getPlayer( mapIndex ) ) // disable if the map has already been nominated
            {
                formatex( disabledReason, charsmax( disabledReason ), "%L", player_id,
                        "GAL_MATCH_NOMINATED" );
            }
            else if( map_isTooRecent( nominationMap ) ) // disable if the map is too recent
            {
                formatex( disabledReason, charsmax( disabledReason ), "%L", player_id,
                        "GAL_MATCH_TOORECENT" );
            }
            else if( equal( g_currentMap, nominationMap ) ) // disable if the map is the current map
            {
                formatex( disabledReason, charsmax( disabledReason ), "%L", player_id,
                        "GAL_MATCH_CURRENTMAP" );
            }
            
            formatex( choice, charsmax( choice ), "%s %s", nominationMap, disabledReason );
            
            menu_additem( g_nominationMatchesMenu[ player_id ], choice, info,
                    ( disabledReason[ 0 ] == '^0' ? 0 : ( 1 << 26 ) ) );
        }
    }
    
    // handle the number of matches
    switch( matchCnt )
    {
        case 0:
        {
            // no matches; pity the poor fool
            color_print( player_id, "^1%L", player_id, "GAL_NOM_FAIL_NOMATCHES",
                    nomination );
        }
        case 1:
        {
            // one match?! omg, this is just like awesome
            map_nominate( player_id, matchIdx );
        }
        default:
        {
            // this is kinda sexy; we put up a menu of the matches for them to pick the right one
            color_print( player_id, "^1%L", player_id, "GAL_NOM_MATCHES", nomination );
            
            if( matchCnt >= MAX_NOM_MATCH_COUNT )
            {
                color_print( player_id, "^1%L", player_id, "GAL_NOM_MATCHES_MAX",
                        MAX_NOM_MATCH_COUNT, MAX_NOM_MATCH_COUNT );
            }
            menu_display( player_id, g_nominationMatchesMenu[ player_id ] );
        }
    }
}

public nomination_handleMatchChoice( player_id, menu, item )
{
    if( item < 0 )
    {
        return PLUGIN_CONTINUE;
    }
#if defined DEBUG
    // Get item info
    new info[ 1 ];
    new access, callback;
    
    DEBUG_LOGGER( 4, "( nomination_handleMatchChoice ) item: %d - %s, player_id: %d, menu: %d", \
            item, item, player_id, menu )
    
    menu_item_getinfo( g_nominationMatchesMenu[ player_id ], item, access, info, 1, _, _, callback );
    
    DEBUG_LOGGER( 4, "( nomination_handleMatchChoice ) info[ 0 ]: %d - %s, access: %d, \
            g_nominationMatchesMenu[ player_id ]: %d", \
            info[ 0 ], info[ 0 ], access, g_nominationMatchesMenu[ player_id ] )
#endif
    map_nominate( player_id, item );
    
    return PLUGIN_HANDLED;
}

stock nomination_getPlayer( mapIndex )
{
    // check if the map has already been nominated
    new nominationIndex;
    new maxPlayerNominations = min( get_pcvar_num( cvar_nomPlayerAllowance ), sizeof g_nomination[] );
    
    for( new idPlayer = 1; idPlayer < sizeof g_nomination; ++idPlayer )
    {
        for( nominationIndex = 1; nominationIndex < maxPlayerNominations; ++nominationIndex )
        {
            if( mapIndex == g_nomination[ idPlayer ][ nominationIndex ] )
            {
                return idPlayer;
            }
        }
    }
    return 0;
}

stock nomination_toggle( player_id, mapIndex )
{
    new idNominator = nomination_getPlayer( mapIndex );
    
    if( idNominator == player_id )
    {
        nomination_cancel( player_id, mapIndex );
    }
    else
    {
        map_nominate( player_id, mapIndex, idNominator );
    }
}

stock nomination_cancel( player_id, mapIndex )
{
    // cancellations can only be made if a vote isn't already in progress
    if( g_voteStatus & VOTE_IN_PROGRESS )
    {
        color_print( player_id, "^1%L", player_id, "GAL_CANCEL_FAIL_INPROGRESS" );
        return;
    }
    else if( g_voteStatus & VOTE_IS_OVER ) // and if the outcome of the vote hasn't already been determined
    {
        color_print( player_id, "^1%L", player_id, "GAL_CANCEL_FAIL_VOTEOVER" );
        return;
    }
    
    new nominationIndex
    new bool:nominationFound
    new mapName[ MAX_MAPNAME_LENGHT ];
    
    new maxPlayerNominations = min( get_pcvar_num( cvar_nomPlayerAllowance ), sizeof g_nomination[] );
    
    for( nominationIndex = 1; nominationIndex < maxPlayerNominations; ++nominationIndex )
    {
        if( g_nomination[ player_id ][ nominationIndex ] == mapIndex )
        {
            nominationFound = true;
            
            break;
        }
    }
    
    ArrayGetString( g_nominationMap, mapIndex, mapName, charsmax( mapName ) );
    
    if( nominationFound )
    {
        g_nominationCount                            = g_nominationCount - 1;
        g_nomination[ player_id ][ nominationIndex ] = -1;
        
        nomination_announceCancellation( mapName );
    }
    else
    {
        new idNominator = nomination_getPlayer( mapIndex );
        
        if( idNominator )
        {
            new player_name[ MAX_PLAYER_NAME_LENGHT ];
            get_user_name( idNominator, player_name, 31 );
            
            color_print( player_id, "^1%L", player_id, "GAL_CANCEL_FAIL_SOMEONEELSE",
                    mapName, player_name );
        }
        else
        {
            color_print( player_id, "^1%L", player_id, "GAL_CANCEL_FAIL_WASNOTYOU",
                    mapName );
        }
    }
}

stock map_nominate( player_id, mapIndex, idNominator = -1 )
{
    // nominations can only be made if a vote isn't already in progress
    if( g_voteStatus & VOTE_IN_PROGRESS )
    {
        color_print( player_id, "^1%L", player_id, "GAL_NOM_FAIL_INPROGRESS" );
        return;
    }
    else if( g_voteStatus & VOTE_IS_OVER ) // and if the outcome of the vote hasn't already been determined
    {
        color_print( player_id, "^1%L", player_id, "GAL_NOM_FAIL_VOTEOVER" );
        return;
    }
    
    DEBUG_LOGGER( 4, "( map_nominate ) mapIndex: %d, sizeof( g_nominationMap ): %d", \
            mapIndex, sizeof( g_nominationMap ) )
    
    DEBUG_LOGGER( 4, "( map_nominate ) mapIndex: %d, ArraySize( g_nominationMap ): %d", \
            mapIndex, ArraySize( g_nominationMap ) )
    
    new mapName[ MAX_MAPNAME_LENGHT ]
    
    ArrayGetString( g_nominationMap, mapIndex, mapName, charsmax( mapName ) )
    
    // players can not nominate the current map
    if( equal( g_currentMap, mapName ) )
    {
        color_print( player_id, "^1%L", player_id, "GAL_NOM_FAIL_CURRENTMAP", g_currentMap );
        return;
    }
    
    // players may not be able to nominate recently played maps
    if( map_isTooRecent( mapName ) )
    {
        color_print( player_id, "^1%L", player_id, "GAL_NOM_FAIL_TOORECENT", mapName );
        color_print( player_id, "^1%L", player_id, "GAL_NOM_FAIL_TOORECENT_HLP" );
        return;
    }
    
    // check if the map has already been nominated
    if( idNominator == -1 )
    {
        idNominator = nomination_getPlayer( mapIndex );
    }
    
    if( idNominator == 0 )
    {
        new nominationOpenIndex
        new nominationIndex
        new nominationCount
        
        new maxPlayerNominations = min( get_pcvar_num( cvar_nomPlayerAllowance ), sizeof g_nomination[] );
        
        // determine the number of nominations the player already made
        // and grab an open slot with the presumption that the player can make the nomination
        for( nominationIndex = 1; nominationIndex < maxPlayerNominations; ++nominationIndex )
        {
            if( g_nomination[ player_id ][ nominationIndex ] >= 0 )
            {
                nominationCount++;
            }
            else
            {
                nominationOpenIndex = nominationIndex;
            }
        }
        
        if( nominationCount == maxPlayerNominations - 1 )
        {
            new nominatedMapName[ MAX_MAPNAME_LENGHT ]
            new nominatedMaps[ COLOR_MESSAGE ]
            
            for( nominationIndex = 1; nominationIndex < maxPlayerNominations; ++nominationIndex )
            {
                mapIndex = g_nomination[ player_id ][ nominationIndex ];
                
                ArrayGetString( g_nominationMap, mapIndex, nominatedMapName, charsmax( nominatedMapName ) );
                formatex( nominatedMaps, charsmax( nominatedMaps ), "%s%s%s", nominatedMaps,
                        ( nominationIndex == 1 ) ? "" : ", ", nominatedMapName );
            }
            
            color_print( player_id, "^1%L", player_id, "GAL_NOM_FAIL_TOOMANY",
                    maxPlayerNominations, nominatedMaps );
            
            color_print( player_id, "^1%L", player_id, "GAL_NOM_FAIL_TOOMANY_HLP" );
        }
        else
        {
            // otherwise, allow the nomination
            g_nomination[ player_id ][ nominationOpenIndex ] = mapIndex;
            g_nominationCount++;
            map_announceNomination( player_id, mapName );
            
            color_print( player_id, "^1%L", player_id, "GAL_NOM_GOOD_HLP" );
        }
    }
    else if( idNominator == player_id )
    {
        color_print( player_id, "^1%L", player_id, "GAL_NOM_FAIL_ALREADY", mapName );
    }
    else
    {
        new player_name[ MAX_PLAYER_NAME_LENGHT ];
        get_user_name( idNominator, player_name, 31 );
        
        color_print( player_id, "^1%L", player_id, "GAL_NOM_FAIL_SOMEONEELSE",
                mapName, player_name );
        
        color_print( player_id, "^1%L", player_id, "GAL_NOM_FAIL_SOMEONEELSE_HLP" );
    }
}

public nomination_list( player_id )
{
    new nominationIndex
    new mapIndex
    new nomMapCount
    new maxPlayerNominations
    
    new msg[ 101 ]
    new mapName[ MAX_MAPNAME_LENGHT ]
    
    maxPlayerNominations = min( get_pcvar_num( cvar_nomPlayerAllowance ), sizeof g_nomination[] );
    
    for( new idPlayer = 1; idPlayer < sizeof g_nomination; ++idPlayer )
    {
        for( nominationIndex = 1; nominationIndex < maxPlayerNominations; ++nominationIndex )
        {
            mapIndex = g_nomination[ idPlayer ][ nominationIndex ];
            
            if( mapIndex >= 0 )
            {
                ArrayGetString( g_nominationMap, mapIndex, mapName, charsmax( mapName ) );
                formatex( msg, charsmax( msg ), "%s, %s", msg, mapName );
                
                if( ++nomMapCount == 4 )     // list 4 maps per chat line
                {
                    color_print( 0, "^1%L: %s", LANG_PLAYER, "GAL_NOMINATIONS",
                            msg[ 2 ] );
                    
                    nomMapCount = 0;
                    msg[ 0 ]    = 0;
                }
            }
        }
    }
    
    if( msg[ 0 ] )
    {
        color_print( 0, "^1%L: %s", LANG_PLAYER, "GAL_NOMINATIONS", msg[ 2 ] );
    }
    else
    {
        color_print( 0, "^1%L: %L", LANG_PLAYER, "GAL_NOMINATIONS",
                LANG_PLAYER, "NONE" );
    }
}

public vote_startDirector( bool:is_forced_voting )
{
    new choicesLoaded
    new voteDuration
    
    if( get_realplayersnum() == 0
        || ( ( g_voteStatus & VOTE_IN_PROGRESS )
             && !( g_voteStatus & VOTE_IS_RUNOFF ) )
        || ( !is_forced_voting
             && g_voteStatus & VOTE_IS_EARLY )
        || ( !is_forced_voting
             && g_voteStatus & VOTE_IS_OVER ) )
    {
        if( get_realplayersnum() == 0
            && g_voteStatus & VOTE_IN_PROGRESS )
        {
            cancel_voting()
        }
        
        if( bool:get_pcvar_num( cvar_emptyServerChange ) )
        {
            startEmptyCycleSystem()
        }
        
        DEBUG_LOGGER( 1, "( vote_startDirector|Cancel ) g_voteStatus: %d, \
                g_voteStatus & VOTE_IS_EARLY: %d, is_forced_voting: %d, \
                get_realplayersnum(): %d", g_voteStatus, g_voteStatus & VOTE_IS_EARLY, \
                is_forced_voting, get_realplayersnum() )
        return
    }
    
    if( g_voteStatus & VOTE_IS_RUNOFF )
    {
        vote_loadRunoffChoices();
        
        if( !( get_pcvar_num( cvar_extendmapAllowStay )
               || g_is_map_extension_allowed ) )
        {
            choicesLoaded      = 2
            g_totalVoteOptions = 2
        }
        else
        {
            choicesLoaded      = g_totalVoteOptions_temp
            g_totalVoteOptions = g_totalVoteOptions_temp
        }
        
        voteDuration = get_pcvar_num( cvar_runoffDuration )
        
        DEBUG_LOGGER( 16, "( vote_startDirector|Runoff ) map1: %s, map2: %s, choicesLoaded: %d", \
                g_votingMapNames[ 0 ], g_votingMapNames[ 1 ], choicesLoaded )
    }
    else
    {
        // make it known that a vote is in progress
        g_voteStatus |= VOTE_IN_PROGRESS;
        
        // Max rounds vote map does not have a max rounds extension limit as mp_timelimit
        if( g_is_maxrounds_vote_map )
        {
            g_is_map_extension_allowed = true
        }
        else
        {
            g_is_map_extension_allowed =
                get_pcvar_float( g_timelimit_pointer ) < get_pcvar_float( cvar_extendmapMax )
        }
        
        g_is_final_voting = ( ( ( get_pcvar_float( g_timelimit_pointer ) * 60 ) < START_VOTEMAP_MIN_TIME )
                              || ( g_is_maxrounds_vote_map ) )
        
        // stop RTV reminders
        remove_task( TASKID_REMINDER );
        
        if( is_forced_voting )
        {
            g_voteStatus |= VOTE_FORCED;
        }
        
        vote_loadChoices();
        choicesLoaded = g_totalVoteOptions
        voteDuration  = get_pcvar_num( cvar_voteDuration );
        
        DEBUG_LOGGER( 4, "^n ( vote_startDirector|NormalVote ) choicesLoaded: %d", choicesLoaded )
        
        if( choicesLoaded )
        {
            // clear all nominations
            nomination_clearAll();
        }
    }

#if IS_DEBUG_ENABLED == 2
    voteDuration   = 5
    g_voteDuration = 5
#endif
    
    if( choicesLoaded )
    {
        // alphabetize the maps
        SortCustom2D( g_votingMapNames, choicesLoaded, "sort_stringsi" );
    
    #if defined DEBUG
        for( new dbgChoice = 0; dbgChoice < choicesLoaded; dbgChoice++ )
        {
            DEBUG_LOGGER( 4, "      %i. %s", dbgChoice + 1, g_votingMapNames[ dbgChoice ] )
        }
    #endif
        
        // mark the players who are in this vote for use later
        new playerCount
        new players[ MAX_PLAYERS ]
        new Float:handleChoicesDelay
        
        get_players( players, playerCount, "ch" ) // skip bots and hltv
        
        for( new player_index = 0; player_index < playerCount; ++player_index )
        {
            g_is_player_voted[ players[ player_index ] ] = false;
        }
    
    #if IS_DEBUG_ENABLED == 2
        handleChoicesDelay = 1.0
    
    #else
        handleChoicesDelay = 8.5
        
        // make perfunctory announcement: "get ready to choose a map"
        if( !( get_pcvar_num( cvar_soundsMute ) & SOUND_GETREADYTOCHOOSE ) )
        {
            client_cmd( 0, "spk ^"get red( e80 ) ninety( s45 ) to check( e20 ) \
                    use bay( s18 ) mass( e42 ) cap( s50 )^"" );
        }
        
        // announce the pending vote countdown from 7 to 1
        set_task( 1.0, "pendingVoteCountdown", _, _, _, "a", 7 );
    #endif
        
        // display the map choices
        set_task( handleChoicesDelay, "vote_handleDisplay", TASKID_VOTE_HANDLEDISPLAY );
        
        // display the vote outcome
        if( get_pcvar_num( cvar_voteStatus ) )
        {
            // indicates it's the end of vote display
            new argument[ 3 ] = { -1, -1, false };
            
            set_task( handleChoicesDelay + float( voteDuration ), "closeVoting", TASKID_VOTE_EXPIRE )
            set_task( handleChoicesDelay + float( voteDuration ) + 1.0, "vote_display", TASKID_VOTE_DISPLAY,
                    argument, sizeof argument )
        }
        else
        {
            set_task( handleChoicesDelay + float( voteDuration ), "closeVoting", TASKID_VOTE_EXPIRE );
        }
    }
    else
    {
        color_print( 0, "^1%L", LANG_PLAYER, "GAL_VOTE_NOMAPS" );
    }
    
    DEBUG_LOGGER( 4, "   [PLAYER CHOICES]" )
    DEBUG_LOGGER( 4, "^n ( vote_startDirector|out ) g_is_timeToRestart: %d, \
            g_is_timeToChangeLevel: %d, g_voteStatus & VOTE_IS_EARLY: %d^n", \
            g_is_timeToRestart, g_is_timeToChangeLevel, g_voteStatus & VOTE_IS_EARLY )
}

public closeVoting()
{
    g_vote[ 0 ]   = '^0'
    g_voteStatus |= VOTE_HAS_EXPIRED
    
    set_task( 9.0, "computeVotes", TASKID_VOTE_EXPIRE )
}

public pendingVoteCountdown()
{
    if( bool:get_pcvar_num( cvar_isToAskForEndOfTheMapVote ) )
    {
        displayEndOfTheMapVoteMenu( 0 )
    }
    
    // visual countdown
    set_hudmessage( 0, 222, 50, -1.0, 0.13, 0, 1.0, 0.94, 0.0, 0.0, -1 );
    show_hudmessage( 0, "%L", LANG_PLAYER, "GAL_VOTE_COUNTDOWN", g_pendingVoteCountdown );
    
    // audio countdown
    if( !( get_pcvar_num( cvar_soundsMute ) & SOUND_COUNTDOWN ) )
    {
        new word[ 6 ];
        num_to_word( g_pendingVoteCountdown, word, 5 );
        
        client_cmd( 0, "spk ^"fvox/%s^"", word );
    }
    
    // decrement the countdown
    g_pendingVoteCountdown--;
    
    if( g_pendingVoteCountdown == 0 )
    {
        g_pendingVoteCountdown = 7;
    }
}

public displayEndOfTheMapVoteMenu( player_id )
{
    new menu_id
    new menuKeys
    new menuKeysUnused
    new playersCount
    new players[ MAX_PLAYERS ]
    
    new menu_body[ 256 ]
    new menu_counter[ 64 ]
    new bool:isVoting
    new bool:playerAnswered
    
    if( player_id > 0 )
    {
        playersCount = 1
        players[ 0 ] = player_id
    }
    else
    {
        get_players( players, playersCount, "ch" )
    }
    
    for( new current_index = 0; current_index < playersCount; current_index++ )
    {
        player_id      = players[ current_index ]
        isVoting       = !g_is_player_voted[ player_id ]
        playerAnswered = g_answeredForEndOfMapVote[ player_id ]
        
        if( !playerAnswered )
        {
            menuKeys = MENU_KEY_0 | MENU_KEY_6;
            
            formatex( menu_counter, charsmax( menu_counter ),
                    " %s( %s%d %L%s )",
                    COLOR_YELLOW, COLOR_GREY, g_pendingVoteCountdown, LANG_PLAYER, "GAL_TIMELEFT", COLOR_YELLOW )
        }
        else
        {
            menuKeys          = MENU_KEY_1
            menu_counter[ 0 ] = '^0'
        }
        
        menu_body[ 0 ] = '^0'
        
        formatex( menu_body, charsmax( menu_body ),
                "%s%L^n^n\
                %s6. %s%L %s^n\
                %s0. %s%L",
                
                COLOR_YELLOW, player_id, "GAL_CHOOSE_QUESTION",
                
                COLOR_RED, ( playerAnswered ? ( isVoting ? COLOR_YELLOW : COLOR_GREY ) : COLOR_WHITE ),
                player_id, "GAL_CHOOSE_QUESTION_YES", menu_counter,
                
                COLOR_RED, ( playerAnswered ? ( !isVoting ? COLOR_YELLOW : COLOR_GREY ) : COLOR_WHITE ),
                player_id, "GAL_CHOOSE_QUESTION_NO" )
        
        get_user_menu( player_id, menu_id, menuKeysUnused )
        
        if( menu_id == 0
            || menu_id == g_chooseMapQuestionMenuId )
        {
            show_menu( player_id, menuKeys, menu_body, 2, MENU_CHOOSEMAP_QUESTION )
        }
        
        DEBUG_LOGGER( 8, " ( displayEndOfTheMapVoteMenu| for ) menu_body: %s^n menu_id:%d,   \
                menuKeys: %d, isVoting: %d, playerAnswered:%d, player_id: %d, current_index: %d", \
                menu_body, menu_id, menuKeys, isVoting, playerAnswered, player_id, current_index )
        
        DEBUG_LOGGER( 8, "   playersCount: %d, g_pendingVoteCountdown: %d, menu_counter: %s", \
                playersCount, g_pendingVoteCountdown, menu_counter )
    }
    
    DEBUG_LOGGER( 8, "%48s", " ( displayEndOfTheMapVoteMenu| out )" )
}

public handleEndOfTheMapVoteChoice( player_id, pressedKeyCode )
{
    switch( pressedKeyCode )
    {
        case 9: // pressedKeyCode 9 means the keyboard key 0
        {
            g_is_player_voted[ player_id ] = true
        }
        case 0: // pressedKeyCode 0 means the keyboard key 1
        {
            set_task( 0.1, "displayEndOfTheMapVoteMenu", player_id )
            return PLUGIN_CONTINUE;
        }
    }
    
    g_answeredForEndOfMapVote[ player_id ] = true
    
    set_task( 0.1, "displayEndOfTheMapVoteMenu", player_id )
    
    return PLUGIN_CONTINUE;
}

stock vote_addNominations()
{
    DEBUG_LOGGER( 4, "^n   [NOMINATIONS ( %i )]", g_nominationCount )
    
    if( g_nominationCount )
    {
        new player_id
        new mapIndex
        new mapName[ MAX_MAPNAME_LENGHT ];
        
        // set how many total nominations we can use in this vote
        new maxNominations    = get_pcvar_num( cvar_nomQtyUsed );
        new slotsAvailable    = g_maxVotingChoices - g_totalVoteOptions;
        new voteNominationMax = ( maxNominations ) ? min( maxNominations, slotsAvailable ) : slotsAvailable;
        
        // set how many total nominations each player is allowed
        new maxPlayerNominations = min( get_pcvar_num( cvar_nomPlayerAllowance ), sizeof g_nomination[] );

#if defined DEBUG
        new nominator_id
        new playerName[ MAX_PLAYER_NAME_LENGHT ]
        
        for( new nominationIndex = maxPlayerNominations - 1; nominationIndex > 0; --nominationIndex )
        {
            for( player_id = 1; player_id < sizeof g_nomination; ++player_id )
            {
                mapIndex = g_nomination[ player_id ][ nominationIndex ];
                
                if( mapIndex >= 0 )
                {
                    ArrayGetString( g_nominationMap, mapIndex, mapName, charsmax( mapName ) );
                    nominator_id = nomination_getPlayer( mapIndex );
                    get_user_name( nominator_id, playerName, charsmax( playerName ) );
                    
                    DEBUG_LOGGER( 4, "      %-32s %s", mapName, playerName )
                }
            }
        }
        DEBUG_LOGGER( 4, "" )
#endif
        
        // add as many nominations as we can [TODO: develop a
        // better method of determining which nominations make the cut; either FIFO or random]
        for( new nominationIndex = maxPlayerNominations - 1; nominationIndex > 0; --nominationIndex )
        {
            for( player_id = 1; player_id < sizeof g_nomination; ++player_id )
            {
                mapIndex = g_nomination[ player_id ][ nominationIndex ];
                
                if( mapIndex >= 0 )
                {
                    ArrayGetString( g_nominationMap, mapIndex, mapName, charsmax( mapName ) );
                    copy( g_votingMapNames[ g_totalVoteOptions++ ],
                            charsmax( g_votingMapNames[] ), mapName );
                    
                    if( g_totalVoteOptions == voteNominationMax )
                    {
                        break;
                    }
                }
            }
            
            if( g_totalVoteOptions == voteNominationMax )
            {
                break;
            }
        }
    }
}

stock vote_addFiller()
{
    if( g_totalVoteOptions >= g_maxVotingChoices )
    {
        return;
    }
    
    // grab the name of the filler file
    new mapFilerFilePath[ MAX_FILE_PATH_LENGHT ];
    
    get_pcvar_string( cvar_voteMapFilePath, mapFilerFilePath, charsmax( mapFilerFilePath ) )
    DEBUG_LOGGER( 4, "( vote_addFiller ) cvar_voteMapFilePath: %s", mapFilerFilePath )
    
    if( get_realplayersnum() < get_pcvar_num( cvar_voteMinPlayers ) )
    {
        get_pcvar_string( cvar_voteMinPlayersMapFilePath, mapFilerFilePath, charsmax( mapFilerFilePath ) )
    }
    else if( mapFilerFilePath[ 0 ] == '*' )
    {
        get_cvar_string( "mapcyclefile", mapFilerFilePath, charsmax( mapFilerFilePath ) );
    }
    
    new groupCount
    new mapsPerGroup[ MAX_MAPS_IN_VOTE ]
    
    // create an array of files that will be pulled from
    new fillersFilePaths[ MAX_MAPS_IN_VOTE ][ MAX_FILE_PATH_LENGHT ]
    
    if( !equal( mapFilerFilePath, "*" ) )
    {
        // determine what kind of file it's being used as
        new mapFilerFile = fopen( mapFilerFilePath, "rt" );
        
        if( mapFilerFile )
        {
            new currentReadedLine[ 16 ]
            
            fgets( mapFilerFile, currentReadedLine, charsmax( currentReadedLine ) )
            trim( currentReadedLine )
            
            if( equali( currentReadedLine, "[groups]" ) )
            {
                DEBUG_LOGGER( 8, " " )
                DEBUG_LOGGER( 8, "this is a [groups] mapFilerFile" )
                
                // read the filler mapFilerFile to determine how many groups there are ( max of MAX_MAPS_IN_VOTE )
                new groupIndex;
                
                while( !feof( mapFilerFile ) )
                {
                    fgets( mapFilerFile, currentReadedLine, charsmax( currentReadedLine ) );
                    trim( currentReadedLine );
                    
                    DEBUG_LOGGER( 8, "currentReadedLine: %s   isdigit: %i   groupCount: %i  ", currentReadedLine, \
                            isdigit( currentReadedLine[ 0 ] ), groupCount )
                    
                    if( isdigit( currentReadedLine[ 0 ] ) )
                    {
                        if( groupCount < MAX_MAPS_IN_VOTE )
                        {
                            groupIndex                 = groupCount++;
                            mapsPerGroup[ groupIndex ] = str_to_num( currentReadedLine );
                            
                            formatex( fillersFilePaths[ groupIndex ], charsmax( fillersFilePaths[] ),
                                    "%s/%i.ini", DIR_CONFIGS, groupCount )
                            
                            DEBUG_LOGGER( 8, "fillersFilePaths: %s", fillersFilePaths[ groupIndex ] )
                        }
                        else
                        {
                            log_error( AMX_ERR_BOUNDS, "%L", LANG_SERVER, "GAL_GRP_FAIL_TOOMANY",
                                    mapFilerFilePath );
                            break;
                        }
                    }
                }
                
                if( groupCount == 0 )
                {
                    fclose( mapFilerFile )
                    log_error( AMX_ERR_GENERAL, "%L", LANG_SERVER, "GAL_GRP_FAIL_NOCOUNTS", mapFilerFilePath );
                    return;
                }
            }
            else
            {
                // we presume it's a listing of maps, ala mapcycle.txt
                copy( fillersFilePaths[ 0 ], charsmax( mapFilerFilePath ), mapFilerFilePath );
                mapsPerGroup[ 0 ] = MAX_MAPS_IN_VOTE;
                groupCount        = 1;
            }
        }
        else
        {
            log_error( AMX_ERR_NOTFOUND, "%L", LANG_SERVER, "GAL_FILLER_NOTFOUND", fillersFilePaths );
        }
        
        fclose( mapFilerFile )
    }
    else
    {
        // we'll be loading all maps in the /maps folder
        copy( fillersFilePaths[ 0 ], charsmax( mapFilerFilePath ), mapFilerFilePath );
        mapsPerGroup[ 0 ] = MAX_MAPS_IN_VOTE;
        groupCount        = 1;
    }
    
    new filersMapCount
    new mapKey
    new allowedFilersCount
    new unsuccessfulCount
    new choice_index
    new mapName[ MAX_MAPNAME_LENGHT ]
    
    // fill remaining slots with random maps from each filler file, as much as possible
    for( new groupIndex = 0; groupIndex < groupCount; ++groupIndex )
    {
        filersMapCount = map_loadFillerList( fillersFilePaths[ groupIndex ] );
        
        DEBUG_LOGGER( 8, "[%i] groupCount:%i   filersMapCount: %i   g_totalVoteOptions: %i   \
                g_maxVotingChoices: %i   fillersFilePaths: %s", groupIndex, groupCount, filersMapCount, \
                g_totalVoteOptions, g_maxVotingChoices, fillersFilePaths[ groupIndex ] )
        
        if( ( g_totalVoteOptions < g_maxVotingChoices )
            && filersMapCount )
        {
            unsuccessfulCount  = 0;
            allowedFilersCount = min( min( mapsPerGroup[ groupIndex ], g_maxVotingChoices - g_totalVoteOptions ),
                    filersMapCount );
            
            DEBUG_LOGGER( 8, "[%i] allowedFilersCount: %i   mapsPerGroup: %i   Max-Cnt: %i", groupIndex, \
                    allowedFilersCount, mapsPerGroup[ groupIndex ], g_maxVotingChoices - g_totalVoteOptions )
            
            for( choice_index = 0; choice_index < allowedFilersCount; ++choice_index )
            {
                unsuccessfulCount = 0;
                mapKey            = random_num( 0, filersMapCount - 1 );
                
                ArrayGetString( g_fillerMap, mapKey, mapName, charsmax( mapName ) );
                
                DEBUG_LOGGER( 8, "[%i] choice_index: %i   allowedFilersCount: %i   mapKey: %i   mapName: %s", \
                        groupIndex, choice_index, allowedFilersCount, mapKey, mapName )
                
                while( ( map_isInMenu( mapName )
                         || equal( g_currentMap, mapName )
                         || map_isTooRecent( mapName )
                         || isPrefixInMenu( mapName ) )
                       && unsuccessfulCount < filersMapCount )
                {
                    unsuccessfulCount++;
                    
                    if( ++mapKey == filersMapCount )
                    {
                        mapKey = 0;
                    }
                    
                    ArrayGetString( g_fillerMap, mapKey, mapName, charsmax( mapName ) );
                }
                
                if( unsuccessfulCount == filersMapCount )
                {
                    DEBUG_LOGGER( 8, "unsuccessfulCount: %i  filersMapCount: %i", unsuccessfulCount, filersMapCount )
                    
                    // there aren't enough maps in this filler file to continue adding anymore
                    break;
                }
                
                DEBUG_LOGGER( 8, "groupIndex: %i  map: %s", groupIndex, mapName )
                
                copy( g_votingMapNames[ g_totalVoteOptions++ ], charsmax( g_votingMapNames[] ),
                        mapName )
                
                DEBUG_LOGGER( 8, "[%i] mapName: %s   unsuccessfulCount: %i   filersMapCount: %i   \
                        g_totalVoteOptions: %i", \
                        groupIndex, mapName, unsuccessfulCount, filersMapCount, g_totalVoteOptions )
            }
        }
    }
}

stock vote_loadChoices()
{
    vote_addNominations();
    vote_addFiller();
    
    return g_totalVoteOptions;
}

stock vote_loadRunoffChoices()
{
    DEBUG_LOGGER( 16, "At vote_loadRunoffChoices --- Runoff map1: %s, Runoff map2: %s", \
            g_votingMapNames[ g_arrayOfRunOffChoices[ 0 ] ], \
            g_votingMapNames[ g_arrayOfRunOffChoices[ 1 ] ] )
    
    new runOffNameChoices[ 2 ][ MAX_MAPNAME_LENGHT ];
    
    copy( runOffNameChoices[ 0 ], charsmax( runOffNameChoices[] ),
            g_votingMapNames[ g_arrayOfRunOffChoices[ 0 ] ] );
    
    copy( runOffNameChoices[ 1 ], charsmax( runOffNameChoices[] ),
            g_votingMapNames[ g_arrayOfRunOffChoices[ 1 ] ] );
    
    copy( g_votingMapNames[ 0 ], charsmax( g_votingMapNames[] ), runOffNameChoices[ 0 ] );
    copy( g_votingMapNames[ 1 ], charsmax( g_votingMapNames[] ), runOffNameChoices[ 1 ] );
}

public vote_handleDisplay()
{
    // announce: "time to choose"
    if( !( get_pcvar_num( cvar_soundsMute ) & SOUND_TIMETOCHOOSE ) )
    {
        client_cmd( 0, "spk Gman/Gman_Choose%i", random_num( 1, 2 ) );
    }
    
    if( g_voteStatus & VOTE_IS_RUNOFF )
    {
        g_voteDuration = get_pcvar_num( cvar_runoffDuration );
    }
    else
    {
        g_voteDuration = get_pcvar_num( cvar_voteDuration );
    }

#if IS_DEBUG_ENABLED == 2
    g_voteDuration = 5
    
    if( g_debug_level & 4 )
    {
        set_task( 2.0, "create_fakeVotes", TASKID_DBG_FAKEVOTES );
    }
#endif
    
    if( get_pcvar_num( cvar_voteStatus )
        && get_pcvar_num( cvar_voteStatusType ) & STATUS_TYPE_PERCENTAGE )
    {
        copy( g_voteStatus_symbol, charsmax( g_voteStatus_symbol ), "%" );
    }
    
    // make sure the display is constructed from scratch
    g_refreshVoteStatus = true;
    
    // ensure the vote status doesn't indicate expired
    g_voteStatus &= ~VOTE_HAS_EXPIRED;
    
    new argument[ 3 ];
    
    argument[ 0 ] = true;
    argument[ 1 ] = 0;
    argument[ 2 ] = false;
    
    if( get_pcvar_num( cvar_voteStatus ) & SHOW_STATUS_AFTER_VOTE )
    {
        set_task( 1.0, "vote_display", TASKID_VOTE_DISPLAY, argument, sizeof( argument ), "a", g_voteDuration );
    }
    else
    {
        set_task( 1.0, "vote_display", TASKID_VOTE_DISPLAY, argument, sizeof( argument ) );
    }
}

public vote_display( argument[ 3 ] )
{
    static menuKeys
    static voteStatus[ 512 ]
    static voteMapLine[ 32 ]
    
    new updateTimeRemaining = argument[ 0 ];
    new player_id           = argument[ 1 ];

#if defined DEBUG
    new snuff = ( player_id > 0 ) ? g_snuffDisplay[ player_id ] : -1;
    
    DEBUG_LOGGER( 4, "   ( votedisplay ) player_id: %i  updateTimeRemaining: %i,  \
        unsnuffDisplay: %i  g_snuffDisplay: %i  g_refreshVoteStatus: %i,^n   \
        g_totalVoteOptions: %i  len( g_vote ): %i  len( voteStatus ): %i", \
            argument[ 1 ], argument[ 0 ], \
            argument[ 2 ], snuff, g_refreshVoteStatus, \
            g_totalVoteOptions, strlen( g_vote ), strlen( voteStatus ) )
#endif
    
    if( player_id > 0
        && g_snuffDisplay[ player_id ] )
    {
        new unsnuffDisplay = argument[ 2 ];
        
        if( unsnuffDisplay )
        {
            g_snuffDisplay[ player_id ] = false;
        }
        else
        {
            return;
        }
    }
    
    new noneOptionType        = get_pcvar_num( cvar_voteShowNoneOptionType )
    new bool:isShowNoneOption = bool: get_pcvar_num( cvar_voteShowNoneOption )
    new bool:isVoteOver       = ( updateTimeRemaining == -1
                                  && player_id == -1 )
    new charCount
    
    if( g_refreshVoteStatus
        || isVoteOver )
    {
        // wipe the previous vote status clean
        voteStatus[ 0 ] = '^0';
        
        // register the 'None' option key
        if( isShowNoneOption
            && !( g_voteStatus & VOTE_HAS_EXPIRED ) )
        {
            menuKeys = MENU_KEY_0;
        }
        
        // add the header
        if( isVoteOver )
        {
            charCount = formatex( voteStatus, charsmax( voteStatus ), "%s%L^n", COLOR_YELLOW,
                    LANG_SERVER, "GAL_RESULT" );
        }
        else
        {
            charCount = formatex( voteStatus, charsmax( voteStatus ), "%s%L^n", COLOR_YELLOW,
                    LANG_SERVER, "GAL_CHOOSE" );
        }
        
        // add maps to the menu
        for( new choice_index = 0; choice_index < g_totalVoteOptions; ++choice_index )
        {
            computeVoteMapLine( voteMapLine, charsmax( voteMapLine ), choice_index );
            
            charCount += formatex( voteStatus[ charCount ], charsmax( voteStatus ) - charCount,
                    "^n%s%i. %s%s%s", COLOR_RED, choice_index + 1, COLOR_WHITE,
                    g_votingMapNames[ choice_index ], voteMapLine );
            
            menuKeys |= ( 1 << choice_index );
        }
        
        new allowStay        = ( g_voteStatus & VOTE_IS_EARLY );
        new isRunoff         = ( g_voteStatus & VOTE_IS_RUNOFF );
        new bool:allowExtend = g_is_final_voting
        
        if( !g_is_final_voting
            && !isRunoff )
        {
            allowExtend = false;
            allowStay   = true;
        }
        
        if( g_isRunOffNeedingKeepCurrentMap )
        {
            // if it is a end map RunOff, then it is a extend button, not a keep current map button
            if( g_is_final_voting )
            {
                allowExtend = true;
                allowStay   = false;
            }
            else
            {
                allowExtend = false;
                allowStay   = true;
            }
        }
        
        if( !get_pcvar_num( cvar_extendmapAllowStay ) )
        {
            allowStay = false;
        }
        
        DEBUG_LOGGER( 1, "( vote_handleDisplay ) Add optional menu item| \
                allowStay: %d, allowExtend: %d, get_pcvar_num( cvar_extendmapAllowStay ): %d", \
                allowStay, allowExtend, get_pcvar_num( cvar_extendmapAllowStay ) )
        
        // add optional menu item
        if( g_is_map_extension_allowed )
        {
            if( allowExtend
                || allowStay )
            {
                // if it's not a runoff vote, add a space between the maps and the additional option
                if( g_voteStatus & VOTE_IS_RUNOFF == 0 )
                {
                    charCount += formatex( voteStatus[ charCount ], charsmax( voteStatus ) - charCount, "^n" );
                }
                
                computeVoteMapLine( voteMapLine, charsmax( voteMapLine ), g_totalVoteOptions );
                
                if( allowExtend )
                {
                    new extend_step = 15
                    new extend_option_type[ 32 ]
                    
                    // add the "Extend Map" menu item.
                    if( g_is_maxrounds_vote_map )
                    {
                        extend_step = get_pcvar_num( cvar_extendmapStepRounds )
                        copy( extend_option_type, charsmax( extend_option_type ), "GAL_OPTION_EXTEND_ROUND" )
                    }
                    else
                    {
                        extend_step = floatround( get_pcvar_float( cvar_extendmapStep ) )
                        copy( extend_option_type, charsmax( extend_option_type ), "GAL_OPTION_EXTEND" )
                    }
                    
                    charCount += formatex( voteStatus[ charCount ], charsmax( voteStatus ) - charCount,
                            "^n%s%i. %s%L%s", COLOR_RED, g_totalVoteOptions + 1, COLOR_WHITE, LANG_SERVER,
                            extend_option_type, g_currentMap, extend_step, voteMapLine );
                }
                else
                {
                    // add the "Stay Here" menu item
                    if( get_pcvar_num( cvar_extendmapAllowStayType ) )
                    {
                        charCount += formatex( voteStatus[ charCount ], charsmax( voteStatus ) - charCount,
                                "^n%s%i. %s%L%s", COLOR_RED, g_totalVoteOptions + 1,
                                COLOR_WHITE, LANG_SERVER, "GAL_OPTION_STAY_MAP", g_currentMap, voteMapLine );
                    }
                    else
                    {
                        charCount += formatex( voteStatus[ charCount ], charsmax( voteStatus ) - charCount,
                                "^n%s%i. %s%L%s", COLOR_RED, g_totalVoteOptions + 1,
                                COLOR_WHITE, LANG_SERVER, "GAL_OPTION_STAY", voteMapLine );
                    }
                }
                
                // Added the extension/stay key option (1 << 2 = key 3, 1 << 3 = key 4, ...)
                menuKeys |= ( 1 << g_totalVoteOptions );
            }
        }
        
        g_refreshVoteStatus = get_pcvar_num( cvar_voteStatus ) & 3;
    }
    
    // make a copy of the virgin menu
    new cleanCharCnt = copy( g_vote, charsmax( g_vote ), voteStatus );
    
    new bool:noneIsHidden = ( isShowNoneOption
                              && !noneOptionType
                              && !( g_voteStatus & VOTE_HAS_EXPIRED ) )
    
    // append a "None" option on for people to choose if they don't like any other choice
    // to append it here to let it to disappear after the player vote.
    if( noneIsHidden )
    {
        formatex( g_vote[ cleanCharCnt ], charsmax( g_vote ) - cleanCharCnt,
                "^n^n%s0. %s%L", COLOR_RED, COLOR_WHITE, LANG_SERVER, "GAL_OPTION_NONE" );
        
        charCount += formatex( voteStatus[ charCount ], charsmax( voteStatus ) - charCount, "^n^n" );
    }
    
    // display the vote
    new showStatus = get_pcvar_num( cvar_voteStatus );
    
    static voteFooter[ 64 ];
    
    if( updateTimeRemaining )
    {
        g_voteDuration--;
        
        charCount = copy( voteFooter, charsmax( voteFooter ), "^n^n" );
        
        if( get_pcvar_num( cvar_voteExpCountdown ) )
        {
            if( ( g_voteDuration <= 10
                  || get_pcvar_num( cvar_showVoteCounter ) )
                && showStatus != SHOW_STATUS_AT_END )
            {
                if( g_voteDuration >= 0 )
                {
                    formatex( voteFooter[ charCount ], charsmax( voteFooter ) - charCount, "%s%L: %s%i",
                            COLOR_WHITE, LANG_SERVER, "GAL_TIMELEFT", COLOR_RED, g_voteDuration );
                }
                else
                {
                    formatex( voteFooter[ charCount ], charsmax( voteFooter ) - charCount,
                            "%s%L", COLOR_YELLOW, LANG_SERVER, "GAL_VOTE_ENDED" );
                }
            }
        }
    }
    
    // menu showed while voting
    static menuClean[ 512 ]
    
    // menu showed after voted
    static menuDirty[ 512 ]
    
    // This function is only called 1 time with the correct player id, to optionally display
    // to single player that just voted.
    // Such time is exactly after the player voted.
    if( player_id > 0
        && showStatus & SHOW_STATUS_AFTER_VOTE )
    {
        calculate_menu_dirt( player_id, isShowNoneOption, noneOptionType, isVoteOver, voteFooter,
                voteStatus, menuDirty, charsmax( menuDirty ), noneIsHidden )
        
        display_vote_menu( false, false, player_id, menuDirty, menuKeys )
    }
    else // just display to everyone
    {
        new playerCount
        new players[ MAX_PLAYERS ]
        
        get_players( players, playerCount, "ch" ); // skip bots and hltv
        
        for( new playerIndex = 0; playerIndex < playerCount; ++playerIndex )
        {
            player_id = players[ playerIndex ];
            
            if( !g_is_player_voted[ player_id ]
                && !isVoteOver
                && showStatus != SHOW_STATUS_ALWAYS )
            {
                calculate_menu_clean( player_id, isShowNoneOption, noneOptionType, voteFooter,
                        menuClean, charsmax( menuClean ) )
                
                display_vote_menu( true, false, player_id, menuClean, menuKeys )
            }
            else if( showStatus == SHOW_STATUS_ALWAYS
                     || ( isVoteOver
                          && showStatus )
                     || ( g_is_player_voted[ player_id ]
                          && showStatus == SHOW_STATUS_AFTER_VOTE ) )
            {
                calculate_menu_dirt( player_id, isShowNoneOption, noneOptionType, isVoteOver, voteFooter,
                        voteStatus, menuDirty, charsmax( menuDirty ), noneIsHidden )
                
                display_vote_menu( false, isVoteOver, player_id, menuDirty, menuKeys )
            }
        }
    }
}

stock calculate_menu_clean( player_id, isShowNoneOption, noneOptionType, voteFooter[], menuClean[], menuCleanSize )
{
    static noneOption[ 32 ]
    static bool:noneIsAlwaysShow
    
    menuClean     [ 0 ] = '^0';
    noneOption    [ 0 ] = '^0';
    noneIsAlwaysShow    = IS_ALWAYS_TO_SHOW_VOTE()
    
    // append a "None" option on for people to choose if they don't like any other choice
    // to append it here to always shows it WHILE voting.
    if( isShowNoneOption
        && noneOptionType )
    {
        if( noneIsAlwaysShow )
        {
            copy( noneOption, charsmax( noneOption ), "GAL_OPTION_CANCEL_VOTE" )
        }
        else
        {
            copy( noneOption, charsmax( noneOption ), "GAL_OPTION_NONE" )
        }
        
        formatex( menuClean, menuCleanSize, "%s^n^n%s0. %s%L%s", g_vote,
                COLOR_RED, COLOR_WHITE, LANG_SERVER, noneOption, voteFooter );
    }
    else
    {
        formatex( menuClean, menuCleanSize, "%s%s", g_vote, voteFooter );
    }
}

stock calculate_menu_dirt( player_id, isShowNoneOption, noneOptionType, isVoteOver, voteFooter[],
                           voteStatus[], menuDirty[], menuDirtySize, bool:noneIsHidden )
{
    static noneOption[ 32 ]
    static bool:noneIsAlwaysShow
    
    menuDirty     [ 0 ] = '^0';
    noneOption    [ 0 ] = '^0';
    noneIsAlwaysShow    = IS_ALWAYS_TO_SHOW_VOTE()
    
    // to append it here to always shows it AFTER voting.
    if( isVoteOver )
    {
        if( isShowNoneOption
            && noneOptionType )
        {
            if( noneIsAlwaysShow )
            {
                copy( noneOption, charsmax( noneOption ), "GAL_OPTION_CANCEL_VOTE" )
            }
            else
            {
                copy( noneOption, charsmax( noneOption ), "GAL_OPTION_NONE" )
            }
            
            formatex( menuDirty, menuDirtySize, "%s^n^n%s0. %s%L^n^n%s%L", voteStatus,
                    COLOR_RED, COLOR_WHITE, LANG_SERVER, noneOption, COLOR_YELLOW, LANG_SERVER,
                    "GAL_VOTE_ENDED" )
        }
        else
        {
            formatex( menuDirty, menuDirtySize, "%s^n^n%s%L", voteStatus, COLOR_YELLOW,
                    LANG_SERVER, "GAL_VOTE_ENDED" );
        }
    }
    else
    {
        if( isShowNoneOption
            && noneOptionType )
        {
            if( noneIsAlwaysShow )
            {
                copy( noneOption, charsmax( noneOption ), "GAL_OPTION_CANCEL_VOTE" )
            }
            else
            {
                copy( noneOption, charsmax( noneOption ), "GAL_OPTION_NONE" )
            }
            
            formatex( menuDirty, menuDirtySize, "%s^n^n%s0. %s%L%s", voteStatus,
                    COLOR_RED, COLOR_WHITE, LANG_SERVER, noneOption, voteFooter );
        }
        else
        {
            // remove the extra space after the 'None' option is hidden
            if( noneIsHidden )
            {
                voteFooter[ 0 ] = ' '
                voteFooter[ 1 ] = ' '
            }
            
            formatex( menuDirty, menuDirtySize, "%s%s", voteStatus, voteFooter );
        }
    }
}

stock display_vote_menu( bool:menuType, bool:isVoteOver, player_id, menuBody[], menuKeys )
{
    new menuid
    new menukeys_unused

#if defined DEBUG
    if( player_id == 1 )
    {
        new player_name[ MAX_PLAYER_NAME_LENGHT ];
        get_user_name( player_id, player_name, 31 );
        
        DEBUG_LOGGER( 4, "    [%s ( %s )]", player_name, ( menuType ? "clean" : "dirty" ) )
        DEBUG_LOGGER( 4, "        %s", menuBody )
        DEBUG_LOGGER( 4, "" )
    }
#endif
    
    get_user_menu( player_id, menuid, menukeys_unused );
    
    if( menuid == 0
        || menuid == g_chooseMapMenuId )
    {
        show_menu( player_id, menuKeys, menuBody,
                ( menuType ? g_voteDuration : ( isVoteOver ? 7 : max( 1, g_voteDuration ) ) ),
                MENU_CHOOSEMAP )
    }
}

public vote_handleChoice( player_id, key )
{
    if( g_voteStatus & VOTE_HAS_EXPIRED )
    {
        client_cmd( player_id, "^"slot%i^"", key + 1 );
        return;
    }
    
    g_snuffDisplay[ player_id ] = true;
    
    if( !g_is_player_voted[ player_id ] )
    {
        register_vote( player_id, key )
        
        g_refreshVoteStatus = true;
    }
    else if( key == 9
             && !g_is_player_cancelled_vote[ player_id ] )
    {
        cancel_player_vote( player_id )
    }
    else
    {
        client_cmd( player_id, "^"slot%i^"", key + 1 );
    }
    
    // display the vote again, with status
    if( get_pcvar_num( cvar_voteStatus ) & SHOW_STATUS_AFTER_VOTE )
    {
        new argument[ 3 ];
        
        argument[ 0 ] = false;
        argument[ 1 ] = player_id;
        argument[ 2 ] = true;
        
        set_task( 0.1, "vote_display", TASKID_VOTE_DISPLAY, argument, sizeof( argument ) );
    }
}

stock cancel_player_vote( player_id )
{
    new voteWeight = g_player_voted_weight[ player_id ]
    
    g_totalVotesCounted                                                -= voteWeight
    g_arrayOfMapsWithVotesNumber[ g_player_voted_option[ player_id ] ] -= voteWeight
    
    g_player_voted_option[ player_id ] -= g_player_voted_option[ player_id ]
    g_player_voted_weight[ player_id ] -= g_player_voted_weight[ player_id ]
    
    g_is_player_voted[ player_id ]          = false;
    g_is_player_cancelled_vote[ player_id ] = true;
}

/**
 * Register the player's choice giving extra weight to admin votes.
 */
stock register_vote( player_id, pressedKeyCode )
{
    g_player_voted_option[ player_id ] = pressedKeyCode
    g_player_voted_weight[ player_id ] = 1
    
    // pressedKeyCode 9 means the keyboard key 0 (the None option)
    if( pressedKeyCode != 9 )
    {
        // increment votes cast count
        g_totalVotesCounted++;
        
        announceRegistedVote( player_id, pressedKeyCode )
        
        new voteWeight = get_pcvar_num( cvar_voteWeight );
        
        if( voteWeight > 1
            && has_flag( player_id, g_voteWeightFlags ) )
        {
            g_player_voted_weight[ player_id ]              = voteWeight
            g_arrayOfMapsWithVotesNumber[ pressedKeyCode ] += voteWeight;
            g_totalVotesCounted                            += ( voteWeight - 1 );
            
            color_print( player_id, "^1L", player_id, "GAL_VOTE_WEIGHTED", voteWeight );
        }
        else
        {
            g_arrayOfMapsWithVotesNumber[ pressedKeyCode ]++;
        }
    }
    
    g_is_player_voted[ player_id ] = true;
}

stock announceRegistedVote( player_id, pressedKeyCode )
{
    new player_name[ MAX_PLAYER_NAME_LENGHT ]
    new bool:isToAnnounceChoice = bool:get_pcvar_num( cvar_voteAnnounceChoice )
    
    if( isToAnnounceChoice )
    {
        get_user_name( player_id, player_name, charsmax( player_name ) );
    }
    
    // confirm the player's choice (pressedKeyCode = 9 means 0 on the keyboard, 8 is 7, etc)
    if( pressedKeyCode == 9 )
    {
        DEBUG_LOGGER( 4, "      %-32s ( none )", player_name )
        
        if( isToAnnounceChoice )
        {
            color_print( 0, "^1%L", LANG_PLAYER, "GAL_CHOICE_NONE_ALL", player_name );
        }
        else
        {
            color_print( player_id, "^1%L", player_id, "GAL_CHOICE_NONE" );
        }
    }
    else
    {
        if( pressedKeyCode == g_totalVoteOptions )
        {
            // only display the "none" vote if we haven't already voted
            // ( we can make it here from the vote status menu too )
            if( !g_is_player_voted[ player_id ] )
            {
                DEBUG_LOGGER( 4, "      %-32s ( extend )", player_name )
                
                if( g_is_final_voting )
                {
                    if( isToAnnounceChoice )
                    {
                        color_print( 0, "^1%L", LANG_PLAYER, "GAL_CHOICE_EXTEND_ALL", player_name );
                    }
                    else
                    {
                        color_print( player_id, "^1%L", player_id, "GAL_CHOICE_EXTEND" );
                    }
                }
                else
                {
                    if( isToAnnounceChoice )
                    {
                        color_print( 0, "^1%L", LANG_PLAYER, "GAL_CHOICE_STAY_ALL", player_name );
                    }
                    else
                    {
                        color_print( player_id, "^1%L", player_id, "GAL_CHOICE_STAY" );
                    }
                }
            }
        }
        else
        {
            DEBUG_LOGGER( 4, "      %-32s %s", player_name, g_votingMapNames[ pressedKeyCode ] )
            
            if( isToAnnounceChoice )
            {
                color_print( 0, "^1%L", LANG_PLAYER, "GAL_CHOICE_MAP_ALL", player_name,
                        g_votingMapNames[ pressedKeyCode ] );
            }
            else
            {
                color_print( player_id, "^1%L", player_id, "GAL_CHOICE_MAP",
                        g_votingMapNames[ pressedKeyCode ] );
            }
        }
    }
}

stock computeVoteMapLine( voteMapLine[], voteMapLineLength, voteIndex )
{
    new voteCountNumber = g_arrayOfMapsWithVotesNumber[ voteIndex ]
    
    if( voteCountNumber
        && get_pcvar_num( cvar_voteStatus ) )
    {
        switch( get_pcvar_num( cvar_voteStatusType ) )
        {
            case STATUS_TYPE_COUNT:
            {
                formatex( voteMapLine, voteMapLineLength, " %s(%s%i%s%s)", 
                        COLOR_YELLOW, COLOR_GREY, voteCountNumber, g_voteStatus_symbol, COLOR_YELLOW );
            }
            case STATUS_TYPE_PERCENTAGE:
            {
                new votePercentNunber = percent( voteCountNumber, g_totalVotesCounted );
                
                formatex( voteMapLine, voteMapLineLength, " %s(%s%i%s%s)", 
                        COLOR_YELLOW, COLOR_GREY, votePercentNunber, g_voteStatus_symbol, COLOR_YELLOW );
            }
            case STATUS_TYPE_PERCENTAGE | STATUS_TYPE_COUNT:
            {
                new votePercentNunber = percent( voteCountNumber, g_totalVotesCounted );
                
                formatex( voteMapLine, voteMapLineLength, " %s(%s%i%s %s[%s%d%s]%s)",
                        COLOR_RED, COLOR_GREY, votePercentNunber, g_voteStatus_symbol,
                        COLOR_YELLOW, COLOR_GREY, voteCountNumber, COLOR_YELLOW, COLOR_RED );
            }
            default:
            {
                voteMapLine[ 0 ] = '^0';
            }
        }
    }
    else
    {
        voteMapLine[ 0 ] = '^0';
    }
    
    DEBUG_LOGGER( 0, " ( computeVoteMapLine ) | get_pcvar_num( cvar_voteStatus ): %d, \
            get_pcvar_num( cvar_voteStatusType ): %d, voteCountNumber: %d", \
            get_pcvar_num( cvar_voteStatus ), get_pcvar_num( cvar_voteStatusType ), voteCountNumber )
}

public computeVotes()
{
    new playerVoteMapChoiceIndex
    new numberOfVotesAtFirstPlace
    new numberOfVotesAtSecondPlace
    
#if defined DEBUG
    new voteMapLine[ 32 ];
    
    DEBUG_LOGGER( 4, "" )
    DEBUG_LOGGER( 4, "   [VOTE RESULT]" )
    
    for( playerVoteMapChoiceIndex = 0; playerVoteMapChoiceIndex <= g_totalVoteOptions;
         ++playerVoteMapChoiceIndex )
    {
        computeVoteMapLine( voteMapLine, charsmax( voteMapLine ), playerVoteMapChoiceIndex )
        
        DEBUG_LOGGER( 4, "      %2i/%3i  %i. %s", \
                g_arrayOfMapsWithVotesNumber[ playerVoteMapChoiceIndex ], voteMapLine, \
                playerVoteMapChoiceIndex, g_votingMapNames[ playerVoteMapChoiceIndex ] )
    }
    
    DEBUG_LOGGER( 4, "" )
#endif
    
    // determine the number of votes for 1st and 2nd places
    for( playerVoteMapChoiceIndex = 0; playerVoteMapChoiceIndex <= g_totalVoteOptions;
         ++playerVoteMapChoiceIndex )
    {
        if( numberOfVotesAtFirstPlace < g_arrayOfMapsWithVotesNumber[ playerVoteMapChoiceIndex ] )
        {
            numberOfVotesAtSecondPlace = numberOfVotesAtFirstPlace;
            numberOfVotesAtFirstPlace  = g_arrayOfMapsWithVotesNumber[ playerVoteMapChoiceIndex ];
        }
        else if( numberOfVotesAtSecondPlace < g_arrayOfMapsWithVotesNumber[ playerVoteMapChoiceIndex ] )
        {
            numberOfVotesAtSecondPlace = g_arrayOfMapsWithVotesNumber[ playerVoteMapChoiceIndex ];
        }
    }
    
    // retain the number of draw maps at first and second positions
    new numberOfMapsAtFirstPosition
    new numberOfMapsAtSecondPosition
    
    new firstPlaceChoices[ MAX_OPTIONS_IN_VOTE ]
    new secondPlaceChoices[ MAX_OPTIONS_IN_VOTE ]
    
    // determine which maps are in 1st and 2nd places
    for( playerVoteMapChoiceIndex = 0; playerVoteMapChoiceIndex <= g_totalVoteOptions;
         ++playerVoteMapChoiceIndex )
    {
        DEBUG_LOGGER( 16, "At g_arrayOfMapsWithVotesNumber[%d] = %d ", playerVoteMapChoiceIndex, \
                g_arrayOfMapsWithVotesNumber[ playerVoteMapChoiceIndex ] )
        
        if( g_arrayOfMapsWithVotesNumber[ playerVoteMapChoiceIndex ] == numberOfVotesAtFirstPlace )
        {
            firstPlaceChoices[ numberOfMapsAtFirstPosition++ ] = playerVoteMapChoiceIndex;
        }
        else if( g_arrayOfMapsWithVotesNumber[ playerVoteMapChoiceIndex ] == numberOfVotesAtSecondPlace )
        {
            secondPlaceChoices[ numberOfMapsAtSecondPosition++ ] = playerVoteMapChoiceIndex;
        }
    }
    
    // At for: g_totalVoteOptions: 5, numberOfMapsAtFirstPosition: 3, numberOfMapsAtSecondPosition: 0
    DEBUG_LOGGER( 16, "At for: g_totalVoteOptions: %d, numberOfMapsAtFirstPosition: %d, \
            numberOfMapsAtSecondPosition: %d", \
            g_totalVoteOptions, numberOfMapsAtFirstPosition, numberOfMapsAtSecondPosition )
    
    DEBUG_LOGGER( 1, "( computeVotes|middle ) g_is_timeToRestart: %d, g_is_timeToChangeLevel: %d \
            g_voteStatus & VOTE_IS_EARLY: %d", \
            g_is_timeToRestart, g_is_timeToChangeLevel, g_voteStatus & VOTE_IS_EARLY )
    
    // announce the outcome
    new winnerVoteMapIndex;
    
    if( numberOfVotesAtFirstPlace )
    {
        // if the top vote getting map didn't receive over 50% of the votes cast, to start a runoff vote
        if( get_pcvar_num( cvar_runoffEnabled )
            && !( g_voteStatus & VOTE_IS_RUNOFF )
            && numberOfVotesAtFirstPlace <= g_totalVotesCounted / 2 )
        {
            // announce runoff voting requirement
            color_print( 0, "^1%L", LANG_PLAYER, "GAL_RUNOFF_REQUIRED" );
            
            if( !( get_pcvar_num( cvar_soundsMute ) & SOUND_RUNOFFREQUIRED ) )
            {
                client_cmd( 0, "spk ^"run officer( e40 ) voltage( e30 ) accelerating( s70 ) \
                        is required^"" );
            }
            
            // let the server know the next vote will be a runoff
            g_voteStatus |= VOTE_IS_RUNOFF;
            
            if( numberOfMapsAtFirstPosition > 2 )
            {
                DEBUG_LOGGER( 16, "0 - firstPlaceChoices[ numberOfMapsAtFirstPosition - 1 ] : %d", \
                        firstPlaceChoices[ numberOfMapsAtFirstPosition - 1 ] )
                
                // determine the two choices that will be facing off
                new firstChoiceIndex
                new secondChoiceIndex
                
                firstChoiceIndex  = random_num( 0, numberOfMapsAtFirstPosition - 1 );
                secondChoiceIndex = random_num( 0, numberOfMapsAtFirstPosition - 1 );
                
                DEBUG_LOGGER( 16, "1 - At: firstChoiceIndex: %d, secondChoiceIndex: %d", \
                        firstChoiceIndex, secondChoiceIndex )
                
                if( firstChoiceIndex == secondChoiceIndex )
                {
                    if( secondChoiceIndex - 1 < 0 )
                    {
                        secondChoiceIndex = secondChoiceIndex + 1;
                    }
                    else
                    {
                        secondChoiceIndex = secondChoiceIndex - 1;
                    }
                }
                
                // if firstPlaceChoices[ numberOfMapsAtFirstPosition - 1 ]  is equal to g_totalVoteOptions
                // then it option is not a valid map, it is the keep current map option, and must be informed
                // it to the vote_display function, to show the 1 map options and the keep current map.
                if( firstPlaceChoices[ firstChoiceIndex ] == g_totalVoteOptions )
                {
                    g_isRunOffNeedingKeepCurrentMap = true
                    firstChoiceIndex--
                    g_totalVoteOptions_temp = 1;
                }
                else if( firstPlaceChoices[ secondChoiceIndex ] == g_totalVoteOptions )
                {
                    g_isRunOffNeedingKeepCurrentMap = true
                    secondChoiceIndex--
                    g_totalVoteOptions_temp = 1;
                }
                else
                {
                    g_totalVoteOptions_temp = 2;
                }
                
                if( firstChoiceIndex == secondChoiceIndex )
                {
                    if( secondChoiceIndex - 1 < 0 )
                    {
                        secondChoiceIndex = secondChoiceIndex + 1;
                    }
                    else
                    {
                        secondChoiceIndex = secondChoiceIndex - 1;
                    }
                }
                
                DEBUG_LOGGER( 16, "2 - At: firstChoiceIndex: %d, secondChoiceIndex: %d", \
                        firstChoiceIndex, secondChoiceIndex )
                
                g_arrayOfRunOffChoices[ 0 ] = firstPlaceChoices[ firstChoiceIndex ];
                g_arrayOfRunOffChoices[ 1 ] = firstPlaceChoices[ secondChoiceIndex ];
                
                DEBUG_LOGGER( 16, "At GAL_RESULT_TIED1 --- Runoff map1: %s, Runoff map2: %s", \
                        g_votingMapNames[ g_arrayOfRunOffChoices[ 0 ] ], \
                        g_votingMapNames[ g_arrayOfRunOffChoices[ 1 ] ] )
                
                color_print( 0, "^1%L", LANG_PLAYER, "GAL_RESULT_TIED1", \
                        numberOfMapsAtFirstPosition )
            }
            else if( numberOfMapsAtFirstPosition == 2 )
            {
                if( firstPlaceChoices[ 0 ] == g_totalVoteOptions )
                {
                    g_isRunOffNeedingKeepCurrentMap = true
                    g_arrayOfRunOffChoices[ 0 ]     = firstPlaceChoices[ 1 ];
                    g_totalVoteOptions_temp         = 1;
                }
                else if( firstPlaceChoices[ 1 ] == g_totalVoteOptions )
                {
                    g_isRunOffNeedingKeepCurrentMap = true
                    g_arrayOfRunOffChoices[ 0 ]     = firstPlaceChoices[ 0 ];
                    g_totalVoteOptions_temp         = 1;
                }
                else
                {
                    g_totalVoteOptions_temp     = 2;
                    g_arrayOfRunOffChoices[ 0 ] = firstPlaceChoices[ 0 ];
                    g_arrayOfRunOffChoices[ 1 ] = firstPlaceChoices[ 1 ];
                }
                
                DEBUG_LOGGER( 16, "At numberOfMapsAtFirstPosition == 2 --- Runoff map1: %s, \
                        Runoff map2: %s", \
                        g_votingMapNames[ g_arrayOfRunOffChoices[ 0 ] ], \
                        g_votingMapNames[ g_arrayOfRunOffChoices[ 1 ] ] )
            }
            else if( numberOfMapsAtSecondPosition == 1 )
            {
                if( firstPlaceChoices[ 0 ] == g_totalVoteOptions )
                {
                    g_isRunOffNeedingKeepCurrentMap = true
                    g_arrayOfRunOffChoices[ 0 ]     = secondPlaceChoices[ 0 ];
                    g_totalVoteOptions_temp         = 1;
                }
                else if( secondPlaceChoices[ 0 ] == g_totalVoteOptions )
                {
                    g_isRunOffNeedingKeepCurrentMap = true
                    g_arrayOfRunOffChoices[ 0 ]     = firstPlaceChoices[ 0 ];
                    g_totalVoteOptions_temp         = 1;
                }
                else
                {
                    g_totalVoteOptions_temp     = 2;
                    g_arrayOfRunOffChoices[ 0 ] = firstPlaceChoices[ 0 ];
                    g_arrayOfRunOffChoices[ 1 ] = secondPlaceChoices[ 0 ];
                }
                
                DEBUG_LOGGER( 16, "At numberOfMapsAtSecondPosition == 1 --- Runoff map1: %s, \
                        Runoff map2: %s", \
                        g_votingMapNames[ g_arrayOfRunOffChoices[ 0 ] ], \
                        g_votingMapNames[ g_arrayOfRunOffChoices[ 1 ] ] )
            }
            else
            {
                new randonNumber = random_num( 0, numberOfMapsAtSecondPosition - 1 )
                
                if( firstPlaceChoices[ 0 ] == g_totalVoteOptions )
                {
                    g_isRunOffNeedingKeepCurrentMap = true
                    g_arrayOfRunOffChoices[ 0 ]     = secondPlaceChoices[ randonNumber ];
                    g_totalVoteOptions_temp         = 1;
                }
                else if( secondPlaceChoices[ randonNumber ] == g_totalVoteOptions )
                {
                    g_isRunOffNeedingKeepCurrentMap = true
                    g_arrayOfRunOffChoices[ 0 ]     = firstPlaceChoices[ 0 ];
                    g_totalVoteOptions_temp         = 1;
                }
                else
                {
                    g_totalVoteOptions_temp     = 2;
                    g_arrayOfRunOffChoices[ 0 ] = firstPlaceChoices[ 0 ];
                    g_arrayOfRunOffChoices[ 1 ] = secondPlaceChoices[ randonNumber ];
                }
                
                DEBUG_LOGGER( 16, "At numberOfMapsAtSecondPosition == 1 ELSE --- Runoff map1: %s, \
                        Runoff map2: %s", \
                        g_votingMapNames[ g_arrayOfRunOffChoices[ 0 ] ], \
                        g_votingMapNames[ g_arrayOfRunOffChoices[ 1 ] ] )
                
                color_print( 0, "^1%L", LANG_PLAYER, "GAL_RESULT_TIED2",
                        numberOfMapsAtSecondPosition );
            }
            // clear all the votes
            vote_resetStats();
            
            // start the runoff vote
            set_task( 5.0, "vote_startDirector", TASKID_VOTE_STARTDIRECTOR );
            
            return;
        }
        
        // if there is a tie for 1st, randomly select one as the winner
        if( numberOfMapsAtFirstPosition > 1 )
        {
            winnerVoteMapIndex = firstPlaceChoices[ random_num( 0, numberOfMapsAtFirstPosition - 1 ) ];
            
            color_print( 0, "^1%L", LANG_PLAYER, "GAL_WINNER_TIED",
                    numberOfMapsAtFirstPosition );
        }
        else
        {
            winnerVoteMapIndex = firstPlaceChoices[ 0 ];
        }
        
        DEBUG_LOGGER( 1, "( computeVotes|moreover ) g_is_timeToRestart: %d, g_is_timeToChangeLevel: %d \
                g_voteStatus & VOTE_IS_EARLY: %d", \
                g_is_timeToRestart, g_is_timeToChangeLevel, g_voteStatus & VOTE_IS_EARLY )
        
        // winnerVoteMapIndex == g_totalVoteOptions, means the 'keep current map' option.
        // Then, here we keep the current map or extend current map, unless the 'cvar_extendmapAllowStay'
        // is set to 0 or 'g_is_map_extension_allowed' is disallowed.
        if( winnerVoteMapIndex == g_totalVoteOptions )
        {
            if( ( g_voteStatus & VOTE_IS_EARLY ) // if it is a early vote, we just change map later
                && !g_is_timeToRestart ) // "stay here" won and the map mustn't be restarted.
            {
                color_print( 0, "^1%L", LANG_PLAYER, "GAL_WINNER_STAY" );
            }
            else // "stay here" won and the map must be restarted or extended.
            {
                if( ( g_voteStatus & VOTE_IS_EARLY )
                    && g_is_timeToRestart )
                {
                    color_print( 0, "^1%L", LANG_PLAYER, "GAL_WINNER_STAY" );
                    
                    intermission_display()
                }
                else // "extend map" or "stay here" won and a restart isn't needed.
                {
                    if( g_is_final_voting ) // "extend map" won and a restart isn't needed.
                    {
                        if( g_is_maxrounds_vote_map )
                        {
                            color_print( 0, "^1%L", LANG_PLAYER, "GAL_WINNER_EXTEND_ROUND",
                                    get_pcvar_num( cvar_extendmapStepRounds ) );
                        }
                        else
                        {
                            color_print( 0, "^1%L", LANG_PLAYER, "GAL_WINNER_EXTEND",
                                    floatround( get_pcvar_float( cvar_extendmapStep ) ) );
                        }
                        
                        map_extend();
                    }
                    else // "stay here" won and a restart isn't needed.
                    {
                        color_print( 0, "^1%L", LANG_PLAYER, "GAL_WINNER_STAY" );
                    }
                } // end: "extend map" or "stay here" won and a restart isn't needed.
            } // end: "stay here" won and the map must be restarted.
            
            reset_round_ending()
            
            // clear all the votes
            vote_resetStats();
            
            // no longer is an early vote
            g_voteStatus &= ~VOTE_IS_EARLY;
        }
        else // the execution flow gets here when the winner option is not keep/extend map
        {
            map_setNext( g_votingMapNames[ winnerVoteMapIndex ] );
            server_exec();
            
            color_print( 0, "^1%L", LANG_PLAYER, "GAL_NEXTMAP",
                    g_votingMapNames[ winnerVoteMapIndex ] );
            
            intermission_display()
            
            g_voteStatus |= VOTE_IS_OVER;
        }
    }
    else // the execution flow gets here when anybody voted for next map
    {
        // the initial nextmap
        new initialNextMap[ MAX_MAPNAME_LENGHT ];
        
        if( get_pcvar_num( cvar_extendmapAllowOrder ) )
        {
            get_cvar_string( "amx_nextmap", initialNextMap, charsmax( initialNextMap ) );
        }
        else
        {
            winnerVoteMapIndex = random_num( 0, g_totalVoteOptions - 1 );
            
            copy( initialNextMap, charsmax( initialNextMap ), g_votingMapNames[ winnerVoteMapIndex ] )
            map_setNext( initialNextMap );
        }
        
        color_print( 0, "^1%L", LANG_PLAYER, "GAL_WINNER_RANDOM", initialNextMap );
        intermission_display()
        
        g_voteStatus |= VOTE_IS_OVER;
    }
    
    DEBUG_LOGGER( 1, "( computeVotes|out ) g_is_timeToRestart: %d, g_is_timeToChangeLevel: %d \
            g_voteStatus & VOTE_IS_EARLY: %d", \
            g_is_timeToRestart, g_is_timeToChangeLevel, g_voteStatus & VOTE_IS_EARLY )
    
    g_isRunOffNeedingKeepCurrentMap = false;
    g_refreshVoteStatus             = true;
    
    // vote is no longer in progress
    g_voteStatus &= ~VOTE_IN_PROGRESS;
    vote_resetStats();
    
    // if we were in a runoff mode, get out of it
    g_voteStatus &= ~VOTE_IS_RUNOFF;
}

stock Float:map_getMinutesElapsed()
{
    DEBUG_LOGGER( 2, "%32s mp_timelimit: %f", "map_getMinutesElapsed( in/out )", \
            get_pcvar_float( g_timelimit_pointer ) )
    
    return get_pcvar_float( g_timelimit_pointer ) - ( float( get_timeleft() ) / 60.0 );
}

stock map_extend()
{
    DEBUG_LOGGER( 2, "%32s mp_timelimit: %f  g_rtvWait: %f  extendmapStep: %f", "map_extend( in )", \
            get_pcvar_float( g_timelimit_pointer ), g_rtvWait, get_pcvar_float( cvar_extendmapStep ) )
    
    // reset the "rtv wait" time, taking into consideration the map extension
    if( g_rtvWait )
    {
        g_rtvWait       += get_pcvar_float( g_timelimit_pointer );
        g_rtvWaitRounds += get_pcvar_num( g_maxrounds_pointer );
    }
    
    save_time_limit()
    
    // do that actual map extension
    if( g_is_maxrounds_vote_map )
    {
        new extendmap_step_rounds = get_pcvar_num( cvar_extendmapStepRounds )
        
        if( g_is_maxrounds_extend )
        {
            set_cvar_num( "mp_maxrounds", get_pcvar_num( g_maxrounds_pointer ) + extendmap_step_rounds );
            set_cvar_num( "mp_winlimit", 0 );
            
            g_is_maxrounds_extend = false;
        }
        else
        {
            set_cvar_num( "mp_maxrounds", 0 );
            set_cvar_num( "mp_winlimit", get_pcvar_num( g_winlimit_pointer ) + extendmap_step_rounds );
        }
        set_pcvar_float( g_timelimit_pointer, 0.0 );
        
        g_is_maxrounds_vote_map = false
    }
    else
    {
        set_cvar_num( "mp_maxrounds", 0 );
        set_cvar_num( "mp_winlimit", 0 );
        set_pcvar_float( g_timelimit_pointer, get_pcvar_float( g_timelimit_pointer )
                + get_pcvar_float( cvar_extendmapStep ) );
    }
    
    server_exec()
    
    // clear vote stats
    vote_resetStats();
    
    DEBUG_LOGGER( 2, "%32s mp_timelimit: %f  g_rtvWait: %f  extendmapStep: %f", "map_extend( out )", \
            get_pcvar_float( g_timelimit_pointer ), g_rtvWait, get_pcvar_float( cvar_extendmapStep ) )
}

stock save_time_limit()
{
    if( !g_is_timeLimitChanged )
    {
        g_is_timeLimitChanged = true;
        
        g_originalTimelimit = get_pcvar_float( g_timelimit_pointer )
        g_originalMaxRounds = get_pcvar_num( g_maxrounds_pointer )
        g_originalWinLimit  = get_pcvar_num( g_winlimit_pointer )
    }
}

stock vote_resetStats()
{
    g_totalVoteOptions     = 0;
    g_totalVotesCounted    = 0;
    g_pendingVoteCountdown = 7;
    
    arrayset( g_arrayOfMapsWithVotesNumber, 0, sizeof g_arrayOfMapsWithVotesNumber );
    
    // reset everyones' rocks
    arrayset( g_rockedVote, false, sizeof( g_rockedVote ) );
    g_rockedVoteCnt = 0;
    
    // reset everyones' votes
    arrayset( g_is_player_voted, true, sizeof( g_is_player_voted ) );
    
    arrayset( g_is_player_cancelled_vote, false, sizeof( g_is_player_voted ) );
    arrayset( g_answeredForEndOfMapVote, false, sizeof( g_answeredForEndOfMapVote ) );
    
    arrayset( g_player_voted_option, 0, sizeof( g_player_voted_option ) );
    arrayset( g_player_voted_weight, 0, sizeof( g_player_voted_weight ) );
}

stock map_isInMenu( map[] )
{
    for( new playerVoteMapChoiceIndex = 0; playerVoteMapChoiceIndex < g_totalVoteOptions;
         ++playerVoteMapChoiceIndex )
    {
        if( equal( map, g_votingMapNames[ playerVoteMapChoiceIndex ] ) )
        {
            return true;
        }
    }
    return false;
}

stock isPrefixInMenu( map[] )
{
    if( get_pcvar_num( cvar_voteUniquePrefixes ) )
    {
        new possiblePrefix[ 8 ], existingPrefix[ 8 ], junk[ 8 ];
        
        strtok( map, possiblePrefix, charsmax( possiblePrefix ), junk, charsmax( junk ), '_', 1 );
        
        for( new playerVoteMapChoiceIndex = 0; playerVoteMapChoiceIndex < g_totalVoteOptions;
             ++playerVoteMapChoiceIndex )
        {
            strtok( g_votingMapNames[ playerVoteMapChoiceIndex ], existingPrefix,
                    charsmax( existingPrefix ), junk, charsmax( junk ), '_', 1 );
            
            if( equal( possiblePrefix, existingPrefix ) )
            {
                return true;
            }
        }
    }
    return false;
}

stock map_isTooRecent( map[] )
{
    if( get_pcvar_num( cvar_recentMapsBannedNumber ) )
    {
        for( new idxBannedMap = 0; idxBannedMap < g_cntRecentMap; ++idxBannedMap )
        {
            if( equal( map, g_recentMap[ idxBannedMap ] ) )
            {
                return true;
            }
        }
    }
    return false;
}

stock start_rtvVote()
{
    new minutes_left   = get_timeleft() / 60
    new maxrounds_left = get_pcvar_num( g_maxrounds_pointer ) - g_total_rounds_played
    new winlimit_left  = get_pcvar_num( g_winlimit_pointer ) - max( g_total_CT_wins, g_total_terrorists_wins )
    
    if( bool:get_pcvar_num( cvar_endOnRound_rtv )
        && get_realplayersnum() >= get_pcvar_num( cvar_endOnRound_rtv ) )
    {
        g_is_last_round     = true
        g_is_RTV_last_round = true
        g_voteStatus       |= VOTE_IS_EARLY
    }
    else
    {
        g_is_timeToChangeLevel = true;
    }
    
    if( minutes_left < maxrounds_left
        || minutes_left < winlimit_left  )
    {
        g_is_maxrounds_vote_map = true
        
        if( maxrounds_left > winlimit_left )
        {
            g_is_maxrounds_extend = true
        }
    }
    
    vote_startDirector( true );
}

public vote_rock( player_id )
{
    // if an early vote is pending, don't allow any rocks
    if( g_voteStatus & VOTE_IS_EARLY )
    {
        color_print( player_id, "^1%L", player_id, "GAL_ROCK_FAIL_PENDINGVOTE" );
        return;
    }
    
    new Float:minutesElapsed = map_getMinutesElapsed();
    
    // if the player is the only one on the server, bring up the vote immediately
    if( get_realplayersnum() == 1 )
    {
        start_rtvVote();
        return;
    }
    
    // make sure enough time has gone by on the current map
    if( g_rtvWait
        && minutesElapsed
        && minutesElapsed < g_rtvWait )
    {
        color_print( player_id, "^1%L", player_id, "GAL_ROCK_FAIL_TOOSOON",
                floatround( g_rtvWait - minutesElapsed, floatround_ceil ) );
        return;
    }
    else if( g_rtvWaitRounds
             && g_total_rounds_played < g_rtvWaitRounds )
    {
        color_print( player_id, "^1%L", player_id, "GAL_ROCK_FAIL_TOOSOON_ROUNDS",
                g_rtvWaitRounds - g_total_rounds_played );
        return;
    }
    
    // rocks can only be made if a vote isn't already in progress
    if( g_voteStatus & VOTE_IN_PROGRESS )
    {
        color_print( player_id, "^1%L", player_id, "GAL_ROCK_FAIL_INPROGRESS" );
        return;
    }
    else if( g_voteStatus & VOTE_IS_OVER ) // and if the outcome of the vote hasn't already been determined
    {
        color_print( player_id, "^1%L", player_id, "GAL_ROCK_FAIL_VOTEOVER" );
        return;
    }
    
    if( get_pcvar_num( cvar_rtvWaitAdmin )
        && g_rtv_wait_admin_number > 0 )
    {
        color_print( player_id, "^1%L", player_id, "GAL_ROCK_WAIT_ADMIN" );
        return;
    }
    
    // determine how many total rocks are needed
    new rocksNeeded = vote_getRocksNeeded();
    
    // make sure player hasn't already rocked the vote
    if( g_rockedVote[ player_id ] )
    {
        color_print( player_id, "^1%L", player_id, "GAL_ROCK_FAIL_ALREADY",
                rocksNeeded - g_rockedVoteCnt );
        
        rtv_remind( TASKID_REMINDER + player_id );
        return;
    }
    
    // allow the player to rock the vote
    g_rockedVote[ player_id ] = true;
    
    color_print( player_id, "^1%L", player_id, "GAL_ROCK_SUCCESS" );
    
    // make sure the rtv reminder timer has stopped
    if( task_exists( TASKID_REMINDER ) )
    {
        remove_task( TASKID_REMINDER );
    }
    
    // determine if there have been enough rocks for a vote yet
    if( ++g_rockedVoteCnt >= rocksNeeded )
    {
        // announce that the vote has been rocked
        color_print( 0, "^1%L", LANG_PLAYER, "GAL_ROCK_ENOUGH" );
        
        // start up the vote director
        start_rtvVote()
    }
    else
    {
        // let the players know how many more rocks are needed
        rtv_remind( TASKID_REMINDER );
        
        if( get_pcvar_num( cvar_rtvReminder ) )
        {
            // initialize the rtv reminder timer to repeat how many
            // rocks are still needed, at regular intervals
            set_task( get_pcvar_float( cvar_rtvReminder ) * 60.0, "rtv_remind",
                    TASKID_REMINDER, _, _, "b" );
        }
    }
}

stock vote_unrockTheVote( player_id )
{
    if( g_rockedVote[ player_id ] )
    {
        g_rockedVote[ player_id ] = false;
        g_rockedVoteCnt--;
        // and such
    }
}

stock vote_getRocksNeeded()
{
    return floatround( get_pcvar_float( cvar_rtvRatio ) * float( get_realplayersnum() ), floatround_ceil );
}

public rtv_remind( param )
{
    new player_id = param - TASKID_REMINDER;
    
    // let the players know how many more rocks are needed
    color_print( player_id, "^1%L", LANG_PLAYER, "GAL_ROCK_NEEDMORE",
            vote_getRocksNeeded() - g_rockedVoteCnt );
}

// change to the map
public map_change()
{
    // grab the name of the map we're changing to
    new map[ MAX_MAPNAME_LENGHT ];
    get_cvar_string( "amx_nextmap", map, charsmax( map ) );
    
    reset_round_ending()
    
    // verify we're changing to a valid map
    if( !is_map_valid( map ) )
    {
        // probably admin did something dumb like changed the map time limit below
        // the time remaining in the map, thus making the map over immediately.
        // since the next map is unknown, just restart the current map.
        copy( map, charsmax( map ), g_currentMap );
    }

#if AMXX_VERSION_NUM < 183
    server_cmd( "changelevel %s", map )
#else
    engine_changelevel( map )
#endif
}

public map_change_stays()
{
    reset_round_ending()
    
    DEBUG_LOGGER( 1, " ( map_change_stays ) g_currentMap: %s", g_currentMap )
    
    server_cmd( "restart" );
}

public cmd_HL1_votemap( player_id )
{
    if( get_pcvar_num( cvar_cmdVotemap ) == 0 )
    {
        con_print( player_id, "%L", player_id, "GAL_DISABLED" );
        return PLUGIN_HANDLED;
    }
    return PLUGIN_CONTINUE;
}

public cmd_HL1_listmaps( player_id )
{
    switch( get_pcvar_num( cvar_cmdListmaps ) )
    {
        case 0:
        {
            con_print( player_id, "%L", player_id, "GAL_DISABLED" );
        }
        case 2:
        {
            map_listAll( player_id );
        }
        default:
        {
            return PLUGIN_CONTINUE;
        }
    }
    return PLUGIN_HANDLED;
}

public map_listAll( player_id )
{
    static lastMapDisplayed[ MAX_MAPNAME_LENGHT ][ 2 ];
    
    // determine if the player has requested a listing before
    new userid = get_user_userid( player_id );
    
    if( userid != lastMapDisplayed[ player_id ][ LISTMAPS_USERID ] )
    {
        lastMapDisplayed[ player_id ][ LISTMAPS_USERID ] = 0;
    }
    
    new command[ 32 ];
    read_argv( 0, command, charsmax( command ) );
    
    new paramenter[ 8 ], start;
    new mapPerPage = get_pcvar_num( cvar_listmapsPaginate );
    
    if( mapPerPage )
    {
        if( read_argv( 1, paramenter, charsmax( paramenter ) ) )
        {
            if( paramenter[ 0 ] == '*' )
            {
                // if the last map previously displayed belongs to the current user,
                // start them off there, otherwise, start them at 1
                if( lastMapDisplayed[ player_id ][ LISTMAPS_USERID ] )
                {
                    start = lastMapDisplayed[ player_id ][ LISTMAPS_LAST ] + 1;
                }
                else
                {
                    start = 1;
                }
            }
            else
            {
                start = str_to_num( paramenter );
            }
        }
        else
        {
            start = 1;
        }
        
        if( player_id == 0
            && read_argc() == 3
            && read_argv( 2, paramenter, charsmax( paramenter ) ) )
        {
            mapPerPage = str_to_num( paramenter );
        }
    }
    
    if( start < 1 )
    {
        start = 1;
    }
    
    if( start >= g_nominationMapCnt )
    {
        start = g_nominationMapCnt - 1;
    }
    
    new end = mapPerPage ? start + mapPerPage - 1 : g_nominationMapCnt;
    
    if( end > g_nominationMapCnt )
    {
        end = g_nominationMapCnt;
    }
    
    // this enables us to use 'command *' to get the next group of maps, when paginated
    lastMapDisplayed[ player_id ][ LISTMAPS_USERID ] = userid;
    lastMapDisplayed[ player_id ][ LISTMAPS_LAST ]   = end - 1;
    
    con_print( player_id, "^n----- %L -----", player_id, "GAL_LISTMAPS_TITLE", g_nominationMapCnt );
    
    new nominator_id
    new player_name[ MAX_PLAYER_NAME_LENGHT ]
    new nominated[ MAX_PLAYER_NAME_LENGHT + 32 ]
    
    new mapName[ MAX_MAPNAME_LENGHT ]
    new idx;
    
    for( idx = start - 1; idx < end; idx++ )
    {
        nominator_id = nomination_getPlayer( idx );
        
        if( nominator_id )
        {
            get_user_name( nominator_id, player_name, charsmax( player_name ) );
            formatex( nominated, charsmax( nominated ), "%L", player_id, "GAL_NOMINATEDBY", player_name );
        }
        else
        {
            nominated[ 0 ] = '^0';
        }
        ArrayGetString( g_nominationMap, idx, mapName, charsmax( mapName ) );
        con_print( player_id, "%3i: %s  %s", idx + 1, mapName, nominated );
    }
    
    if( mapPerPage
        && mapPerPage < g_nominationMapCnt )
    {
        con_print( player_id, "----- %L -----", player_id, "GAL_LISTMAPS_SHOWING",
                start, idx, g_nominationMapCnt );
        
        if( end < g_nominationMapCnt )
        {
            con_print( player_id, "----- %L -----", player_id, "GAL_LISTMAPS_MORE",
                    command, end + 1, command );
        }
    }
}

stock con_print( player_id, message[], { Float, Sql, Result, _ }: ... )
{
    new consoleMessage[ LONG_STRING ];
    vformat( consoleMessage, charsmax( consoleMessage ), message, 3 );
    
    if( player_id )
    {
        new authid[ 32 ];
        
        get_user_authid( player_id, authid, 31 );
        console_print( player_id, consoleMessage );
        
        return;
    }
    
    server_print( consoleMessage );
}

stock restartEmptyCycle()
{
    set_pcvar_num( cvar_isToStopEmptyCycle, 0 );
    remove_task( TASKID_EMPTYSERVER )
}

public client_authorized( player_id )
{
    restartEmptyCycle()
    
    if( has_flag( player_id, "f" ) )
    {
        g_rtv_wait_admin_number++
    }
}

#if AMXX_VERSION_NUM < 183
public client_disconnect( player_id )
#else
public client_disconnected( player_id )
#endif
{
    g_is_player_voted[ player_id ] = false;
    
    if( has_flag( player_id, "f" ) )
    {
        g_rtv_wait_admin_number--
    }
    
    vote_unrockTheVote( player_id )
    unnominatedDisconnectedPlayer( player_id )
    
    isToHandleRecentlyEmptyServer();
}

stock unnominatedDisconnectedPlayer( player_id )
{
    if( get_pcvar_num( cvar_unnominateDisconnected ) )
    {
        new mapIndex
        new nominationCount
        new maxPlayerNominations
        
        new mapName[ MAX_MAPNAME_LENGHT ]
        new nominatedMaps[ COLOR_MESSAGE ]
        
        // cancel player's nominations
        maxPlayerNominations = min( get_pcvar_num( cvar_nomPlayerAllowance ), sizeof g_nomination[] );
        
        for( new nominationIndex = 1; nominationIndex < maxPlayerNominations; ++nominationIndex )
        {
            mapIndex = g_nomination[ player_id ][ nominationIndex ];
            
            if( mapIndex >= 0 )
            {
                ArrayGetString( g_nominationMap, mapIndex, mapName, charsmax( mapName ) );
                nominationCount++;
                formatex( nominatedMaps, charsmax( nominatedMaps ), "%s%s, ", nominatedMaps, mapName );
                g_nomination[ player_id ][ nominationIndex ] = -1;
            }
        }
        
        if( nominationCount )
        {
            // strip the extraneous ", " from the string
            nominatedMaps[ strlen( nominatedMaps ) - 2 ] = 0;
            
            // inform the masses that the maps are no longer nominated
            nomination_announceCancellation( nominatedMaps );
        }
    }
}

/**
 * If the empty cycle feature was initialized by 'inicializeEmptyCycleFeature()' function, this
 * function to start the empty cycle map change system, when the last server player disconnect.
 */
stock isToHandleRecentlyEmptyServer()
{
    new playerCount = get_realplayersnum();
    
    DEBUG_LOGGER( 2, "%32s mp_timelimit: %f  g_originalTimelimit: %f", \
            "isToHandleRecentlyEmptyServer (in)", get_pcvar_float( g_timelimit_pointer ), g_originalTimelimit )
    DEBUG_LOGGER( 2, "%32s playerCount:%i", "client_disconnect()", playerCount )
    
    if( playerCount == 0 )
    {
        if( g_originalTimelimit != get_pcvar_float( g_timelimit_pointer ) )
        {
            // it's possible that the map has been extended at least once. that
            // means that if someone comes into the server, the time limit will
            // be the extended time limit rather than the normal time limit. bad.
            // reset the original time limit
            map_restoreOriginalTimeLimit();
        }
        
        // if it is utilizing "empty server" feature, to start it.
        if( g_isUsingEmptyCycle
            && g_emptyCycleMapsNumber )
        {
            startEmptyCycleCountdown();
        }
    }
    
    DEBUG_LOGGER( 2, "g_isUsingEmptyCycle = %d, g_emptyCycleMapsNumber = %d", \
            g_isUsingEmptyCycle, g_emptyCycleMapsNumber )
    DEBUG_LOGGER( 2, "%32s mp_timelimit: %f  g_originalTimelimit: %f", "isToHandleRecentlyEmptyServer (out)", \
            get_pcvar_float( g_timelimit_pointer ), g_originalTimelimit )
}

/**
 * Inicializes the empty cycle server feature at map starting.
 */
public inicializeEmptyCycleFeature()
{
    if( get_realplayersnum() == 0 )
    {
        if( bool:get_pcvar_num( cvar_isToStopEmptyCycle ) )
        {
            configureNextEmptyCycleMap()
        }
        else
        {
            startEmptyCycleCountdown()
        }
    }
    
    g_isUsingEmptyCycle = true;
}

stock startEmptyCycleCountdown()
{
    new waitMinutes = get_pcvar_num( cvar_emptyWait );
    
    if( waitMinutes )
    {
        set_task( float( waitMinutes * 60 ), "startEmptyCycleSystem", TASKID_EMPTYSERVER );
    }
}

/**
 * Set the next map from the empty cycle list, if and only if, it is not already configured.
 *
 * @return -1     if the current map is not on the empty cycle list. Otherwise anything else.
 */
stock configureNextEmptyCycleMap()
{
    new mapIndex
    new nextMap[ MAX_MAPNAME_LENGHT ]
    new lastEmptyCycleMap[ MAX_MAPNAME_LENGHT ]
    
    mapIndex = map_getNext( g_emptyCycleMapList, g_currentMap, nextMap );
    
    if( !g_is_emptyCycleMapConfigured )
    {
        g_is_emptyCycleMapConfigured = true
        
        getLastEmptyCycleMap( lastEmptyCycleMap )
        map_getNext( g_emptyCycleMapList, lastEmptyCycleMap, nextMap );
        
        setLastEmptyCycleMap( nextMap )
        map_setNext( nextMap )
    }
    
    return mapIndex
}

stock getLastEmptyCycleMap( lastEmptyCycleMap[ MAX_MAPNAME_LENGHT ] )
{
    new lastEmptyCycleMapFilePath[ MAX_FILE_PATH_LENGHT ]
    
    formatex( lastEmptyCycleMapFilePath, charsmax( lastEmptyCycleMapFilePath ), "%s/%s",
            DIR_DATA, LAST_EMPTY_CYCLE_FILE_NAME )
    
    new lastEmptyCycleMapFile = fopen( lastEmptyCycleMapFilePath, "rt" )
    
    if( lastEmptyCycleMapFile )
    {
        fgets( lastEmptyCycleMapFile, lastEmptyCycleMap, charsmax( lastEmptyCycleMap ) )
    }
}

stock setLastEmptyCycleMap( lastEmptyCycleMap[ MAX_MAPNAME_LENGHT ] )
{
    new lastEmptyCycleMapFilePath[ MAX_FILE_PATH_LENGHT ]
    
    formatex( lastEmptyCycleMapFilePath, charsmax( lastEmptyCycleMapFilePath ), "%s/%s",
            DIR_DATA, LAST_EMPTY_CYCLE_FILE_NAME );
    
    new lastEmptyCycleMapFile = fopen( lastEmptyCycleMapFilePath, "wt" );
    
    if( lastEmptyCycleMapFile )
    {
        fprintf( lastEmptyCycleMapFile, "%s", lastEmptyCycleMap )
        fclose( lastEmptyCycleMapFile )
    }
}

public startEmptyCycleSystem()
{
    // stop this system at the next map, due we already be at a popular map
    set_pcvar_num( cvar_isToStopEmptyCycle, 1 )
    
    // if the current map isn't part of the empty cycle,
    // immediately change to next map that is
    if( configureNextEmptyCycleMap() == -1 )
    {
        map_change();
    }
}

/**
 * Given a mapArray list the currentMap, calculates the next map after the currentMap provided at
 * the mapArray.
 *
 * @param nextMap       the string pointer which will receive the next map
 * @param currentMap    the string printer to the current map name
 * @param mapArray      the dynamic array with the map list to search
 *
 * @return mapIndex     the nextMap index in the mapArray. -1 if not found a nextMap.
 */
stock map_getNext( Array:mapArray, currentMap[], nextMap[ MAX_MAPNAME_LENGHT ] )
{
    new thisMap[ MAX_MAPNAME_LENGHT ]
    
    new nextmapIndex = 0
    new returnValue  = -1
    new mapCount     = ArraySize( mapArray )
    
    for( new mapIndex = 0; mapIndex < mapCount; mapIndex++ )
    {
        ArrayGetString( mapArray, mapIndex, thisMap, charsmax( thisMap ) );
        
        if( equal( currentMap, thisMap ) )
        {
            if( mapIndex == mapCount - 1 )
            {
                nextmapIndex = 0
            }
            else
            {
                nextmapIndex = mapIndex + 1
            }
            returnValue = nextmapIndex;
            break;
        }
    }
    ArrayGetString( mapArray, nextmapIndex, nextMap, charsmax( nextMap ) );
    
    return returnValue;
}

public client_putinserver( player_id )
{
    if( ( g_voteStatus & VOTE_IS_EARLY )
        && !is_user_bot( player_id )
        && !is_user_hltv( player_id ) )
    {
        set_task( 20.0, "srv_announceEarlyVote", player_id );
    }
}

public srv_announceEarlyVote( player_id )
{
    if( is_user_connected( player_id ) )
    {
        color_print( player_id, "^4%L", player_id, "GAL_VOTE_EARLY" );
    }
}

stock nomination_announceCancellation( nominations[] )
{
    color_print( 0, "^1%L", LANG_PLAYER, "GAL_CANCEL_SUCCESS", nominations );
}

stock nomination_clearAll()
{
    for( new player_index = 1; player_index < sizeof g_nomination; player_index++ )
    {
        for( new nominationIndex = 1; nominationIndex < sizeof g_nomination[]; nominationIndex++ )
        {
            g_nomination[ player_index ][ nominationIndex ] = -1;
        }
    }
    g_nominationCount = 0;
}

stock map_announceNomination( player_id, map[] )
{
    new player_name[ MAX_PLAYER_NAME_LENGHT ];
    get_user_name( player_id, player_name, charsmax( player_name ) );
    
    color_print( 0, "^1%L", LANG_PLAYER, "GAL_NOM_SUCCESS", player_name, map );
}

#if AMXX_VERSION_NUM < 180
stock has_flag( player_id, flags[] )
{
    return ( get_user_flags( player_id ) & read_flags( flags ) );
}
#endif

public sort_stringsi( const elem1[], const elem2[], const array[], data[], data_size )
{
    return strcmp( elem1, elem2, 1 );
}

stock get_realplayersnum()
{
    new playerCount
    new players[ MAX_PLAYERS ]
    
    get_players( players, playerCount, "ch" );
    
    return playerCount;
}

stock percent( is, of )
{
    return ( of != 0 ) ? floatround( floatmul( float( is ) / float( of ), 100.0 ) ) : 0;
}

/**
 * Print colored text to a given player_id. It has to be called to each player using its player_id
 * instead of 'LANG_PLAYER' constant. Just use the 'LANG_PLAYER' constant when using this function
 * to display to all players.
 *
 * This includes the code:
 * ConnorMcLeod's [Dyn Native] ColorChat v0.3.2 (04 jul 2013) register_dictionary_colored function:
 *   <a href="https://forums.alliedmods.net/showthread.php?p=851160">ColorChat v0.3.2</a>
 *
 * If you are at the Amx Mod X 1.8.2, you can call this function using the player_id as 0. But it
 * will use more resources to decode its arguments. To be more optimized you should call it to every
 * player on the server, to display the colored message to all players using global scope. Example:
 * @code{.cpp}
 * #if AMXX_VERSION_NUM < 183
 * new g_colored_player_id
 * new g_colored_players_number
 * new g_colored_current_index
 * new g_colored_players_ids[ 32 ]
 * #endif
 *
 * some_function()
 * {
 *     ... some code
 * #if AMXX_VERSION_NUM < 183
 *     get_players( g_colored_players_ids, g_colored_players_number, "ch" );
 *
 *     for( g_colored_current_index = 0; g_colored_current_index < g_colored_players_number;
 *          g_colored_current_index++ )
 *     {
 *         g_colored_player_id = g_colored_players_ids[ g_colored_current_index ]
 *
 *         color_print( g_colored_player_id, "^1%L %L %L",
 *                 g_colored_player_id, "LANG_A", g_colored_player_id, "LANG_B",
 *                 g_colored_player_id, "LANG_C", any_variable_used_on_LANG_C )
 *     }
 * #else
 *     color_print( 0, "^1%L %L %L", LANG_PLAYER, "LANG_A",
 *             LANG_PLAYER, "LANG_B", LANG_PLAYER, "LANG_C", any_variable_used_on_LANG_C );
 * #endif
 *     ... some code
 * }
 * @endcode
 *
 * If you are at the Amx Mod X 1.8.3 or superior, you can call this function using the player_id
 * as 0, to display the colored message to all players on the server.
 *
 * If you run this function on a Game Mod that do not support colored messages, they will be
 * displayed as normal messages without any errors or bad formats.
 *
 * This allow you to use '!g for green', '!y for yellow', '!t for team' color with LANGs at a
 * register_dictionary_colored file. Otherwise use '^1', '^2', '^3' and '^4'.
 *
 * @param player_id the player id.
 * @param message[] the text formatting rules to display.
 * @param any the variable number of formatting parameters.
 *
 * @see <a href="https://www.amxmodx.org/api/amxmodx/client_print_color">client_print_color</a>
 * for Amx Mod X 1.8.3 or superior.
 */
stock color_print( player_id, message[], any: ... )
{
    new formated_message[ COLOR_MESSAGE ]
    
    formated_message[ 0 ] = '^0'
    
    if( g_is_color_chat_supported
        && g_is_colored_chat_enabled )
    {
#if AMXX_VERSION_NUM < 183
        if( player_id )
        {
            vformat( formated_message, charsmax( formated_message ), message, 3 )
            DEBUG_LOGGER( 64, "( in ) Player_Id: %d, Chat printed: %s", player_id, formated_message )
            
            PRINT_COLORED_MESSAGE( player_id, formated_message )
        }
        else
        {
            new playersCount;
            new players[ MAX_PLAYERS ]
            
            get_players( players, playersCount, "ch" );
            
            // Figure out if at least 1 player is connected
            // so we don't execute useless code
            if( !playersCount )
            {
                DEBUG_LOGGER( 64, "!playersCount. playersCount = %d", playersCount )
                return;
            }
            
            new player_id;
            new string_index
            new argument_index
            new multi_lingual_constants_number
            new params_number
            new Array:multi_lingual_indexes_array
            
            multi_lingual_indexes_array    = ArrayCreate();
            params_number                  = numargs();
            multi_lingual_constants_number = 0
            
            DEBUG_LOGGER( 64, "playersCount: %d, params_number: %d", playersCount, params_number )
            
            if( params_number >= 4 ) // ML can be used
            {
                for( argument_index = 2; argument_index < params_number; argument_index++ )
                {
                    DEBUG_LOGGER( 64, "argument_index: %d, getarg(argument_index): %d / %s", \
                            argument_index, getarg( argument_index ), getarg( argument_index ) )
                    
                    // retrieve original param value and check if it's LANG_PLAYER value
                    if( getarg( argument_index ) == LANG_PLAYER )
                    {
                        string_index = 0;
                        
                        // as LANG_PLAYER == -1, check if next param string is a registered language translation
                        while( ( formated_message[ string_index ] =
                                     getarg( argument_index + 1, string_index++ ) ) )
                        {
                        }
                        formated_message[ string_index ] = 0
                        
                        DEBUG_LOGGER( 64, "Player_Id: %d, formated_message: %s, \
                                GetLangTransKey( formated_message ) != TransKey_Bad: %d", \
                                player_id, formated_message, \
                                GetLangTransKey( formated_message ) != TransKey_Bad )
                        
                        DEBUG_LOGGER( 64, "(multi_lingual_constants_number: %d, string_index: %d", \
                                multi_lingual_constants_number, string_index )
                        
                        if( GetLangTransKey( formated_message ) != TransKey_Bad )
                        {
                            // Store that argument as LANG_PLAYER so we can alter it later
                            ArrayPushCell( multi_lingual_indexes_array, argument_index++ );
                            
                            // Update ML array, so we'll know 1st if ML is used,
                            // 2nd how many arguments we have to change
                            multi_lingual_constants_number++;
                        }
                        
                        DEBUG_LOGGER( 64, "argument_index (after ArrayPushCell): %d", argument_index )
                    }
                }
            }
            
            DEBUG_LOGGER( 64, "(multi_lingual_constants_number: %d", multi_lingual_constants_number )
            
            for( --playersCount; playersCount >= 0; playersCount-- )
            {
                player_id = players[ playersCount ];
                
                if( multi_lingual_constants_number )
                {
                    for( argument_index = 0; argument_index < multi_lingual_constants_number; argument_index++ )
                    {
                        DEBUG_LOGGER( 64, "(argument_index: %d, player_id: %d, \
                                ArrayGetCell( %d, %d ): %d", \
                                argument_index, player_id, multi_lingual_indexes_array, argument_index, \
                                ArrayGetCell( multi_lingual_indexes_array, argument_index ) )
                        
                        // Set all LANG_PLAYER args to player index ( = player_id )
                        // so we can format the text for that specific player
                        setarg( ArrayGetCell( multi_lingual_indexes_array, argument_index ), _, player_id );
                    }
                    vformat( formated_message, charsmax( formated_message ), message, 3 )
                }
                
                DEBUG_LOGGER( 64, "( in ) Player_Id: %d, Chat printed: %s", player_id, formated_message )
                PRINT_COLORED_MESSAGE( player_id, formated_message )
            }
            
            ArrayDestroy( multi_lingual_indexes_array );
        }
#else
        vformat( formated_message, charsmax( formated_message ), message, 3 )
        DEBUG_LOGGER( 64, "( in ) Player_Id: %d, Chat printed: %s", player_id, formated_message )
        
        client_print_color( player_id, print_team_default, formated_message )
#endif
    }
    else
    {
        vformat( formated_message, charsmax( formated_message ), message, 3 )
        DEBUG_LOGGER( 64, "( in ) Player_Id: %d, Chat printed: %s", player_id, formated_message )
        
        REMOVE_COLOR_TAGS( formated_message )
        client_print( player_id, print_chat, formated_message )
    }
    DEBUG_LOGGER( 64, "( out ) Player_Id: %d, Chat printed: %s", player_id, formated_message )
}

/**
 * ConnorMcLeod's [Dyn Native] ColorChat v0.3.2 (04 jul 2013) register_dictionary_colored function:
 *   <a href="https://forums.alliedmods.net/showthread.php?p=851160">ColorChat v0.3.2</a>
 *
 * @param dictionaryFile the dictionary file name including its file extension.
 */
stock register_dictionary_colored( const dictionaryFile[] )
{
    if( !register_dictionary( dictionaryFile ) )
    {
        return 0;
    }
    
    new dictionaryFilePath[ MAX_FILE_PATH_LENGHT ];
    
    get_localinfo( "amxx_datadir", dictionaryFilePath, charsmax( dictionaryFilePath ) );
    formatex( dictionaryFilePath, charsmax( dictionaryFilePath ), "%s/lang/%s", dictionaryFilePath, dictionaryFile );
    
    new dictionaryFile = fopen( dictionaryFilePath, "rt" );
    
    if( !dictionaryFile )
    {
        log_amx( "Failed to open %s", dictionaryFilePath );
        return 0;
    }
    
    new szBuffer[ 512 ]
    new szLang[ 3 ]
    new szKey[ 64 ]
    new szTranslation[ LONG_STRING ]
    new TransKey:iKey
    
    while( !feof( dictionaryFile ) )
    {
        fgets( dictionaryFile, szBuffer, charsmax( szBuffer ) );
        trim( szBuffer );
        
        if( szBuffer[ 0 ] == '[' )
        {
            strtok( szBuffer[ 1 ], szLang, charsmax( szLang ), szBuffer, 1, ']' );
        }
        else if( szBuffer[ 0 ] )
        {
        #if AMXX_VERSION_NUM < 183
            strbreak( szBuffer, szKey, charsmax( szKey ), szTranslation, charsmax( szTranslation ) );
        #else
            argbreak( szBuffer, szKey, charsmax( szKey ), szTranslation, charsmax( szTranslation ) );
        #endif
            iKey = GetLangTransKey( szKey );
            
            if( iKey != TransKey_Bad )
            {
                INSERT_COLOR_TAGS( szTranslation )
                AddTranslation( szLang, iKey, szTranslation[ 2 ] );
            }
        }
    }
    
    fclose( dictionaryFile );
    return 1;
}

public map_restoreOriginalTimeLimit()
{
    DEBUG_LOGGER( 2, "%32s mp_timelimit: %f  g_originalTimelimit: %f", "map_restoreOriginalTimeLimit( in )", \
            get_pcvar_float( g_timelimit_pointer ), g_originalTimelimit )
    
    if( g_is_timeLimitChanged )
    {
        server_cmd( "mp_timelimit %f", g_originalTimelimit )
        server_cmd( "mp_maxrounds %d", g_originalMaxRounds )
        server_cmd( "mp_winlimit %d", g_originalWinLimit )
        
        server_exec();
        g_is_timeLimitChanged = false;
    }
    
    if( get_cvar_float( "sv_maxspeed" ) == 0 )
    {
        set_cvar_float( "sv_maxspeed", g_original_sv_maxspeed )
    }
    
    DEBUG_LOGGER( 2, "%32s mp_timelimit: %f  g_originalTimelimit: %f", "map_restoreOriginalTimeLimit( out )", \
            get_pcvar_float( g_timelimit_pointer ), g_originalTimelimit )
}

/**
 * Immediately stops any vote in progress.
 */
stock cancel_voting()
{
    remove_task( TASKID_START_VOTING_BY_ROUNDS )
    remove_task( TASKID_VOTE_DISPLAY )
    remove_task( TASKID_DBG_FAKEVOTES )
    remove_task( TASKID_VOTE_HANDLEDISPLAY )
    remove_task( TASKID_VOTE_EXPIRE )
    remove_task( TASKID_DBG_FAKEVOTES )
    remove_task( TASKID_VOTE_STARTDIRECTOR )
    remove_task( TASKID_MAP_CHANGE )
    remove_task( TASKID_PROCESS_LAST_ROUND )
    remove_task( TASKID_SHOW_LAST_ROUND_HUD )
    
    g_is_maxrounds_vote_map = false;
    g_is_maxrounds_extend   = false;
    g_voteStatus            = 0
    
    vote_resetStats()
}

// ################################## AMX MOD X NEXTMAP PLUGIN ###################################
new plugin_nextmap_g_nextMap[ MAX_MAPNAME_LENGHT ]
new plugin_nextmap_g_mapCycle[ MAX_FILE_PATH_LENGHT ]
new plugin_nextmap_g_pos
new plugin_nextmap_g_currentMap[ MAX_MAPNAME_LENGHT ]

// pcvars
new plugin_nextmap_g_friendlyfire, plugin_nextmap_g_chattime
new plugin_nextmap_gp_nextmap

public nextmap_plugin_init()
{
    pause( "acd", "nextmap.amxx" )
    
    register_dictionary( "nextmap.txt" )
    register_event( "30", "changeMap", "a" )
    register_clcmd( "say nextmap", "sayNextMap", 0, "- displays nextmap" )
    register_clcmd( "say currentmap", "sayCurrentMap", 0, "- display current map" )
    
    plugin_nextmap_gp_nextmap     = register_cvar( "amx_nextmap", "", FCVAR_SERVER | FCVAR_EXTDLL | FCVAR_SPONLY )
    plugin_nextmap_g_chattime     = get_cvar_pointer( "mp_chattime" )
    plugin_nextmap_g_friendlyfire = get_cvar_pointer( "mp_friendlyfire" )
    
    if( plugin_nextmap_g_friendlyfire )
    {
        register_clcmd( "say ff", "sayFFStatus", 0, "- display friendly fire status" )
    }
    
    get_mapname( plugin_nextmap_g_currentMap, charsmax( plugin_nextmap_g_currentMap ) )
    
    new szString[ 40 ]
    new szString2[ 32 ]
    new szString3[ 8 ]
    
    get_localinfo( "lastmapcycle", szString, charsmax( szString ) )
    parse( szString, szString2, charsmax( szString2 ), szString3, charsmax( szString3 ) )
    
    get_cvar_string( "mapcyclefile", plugin_nextmap_g_mapCycle, charsmax( plugin_nextmap_g_mapCycle ) )
    
    if( !equal( plugin_nextmap_g_mapCycle, szString2 ) )
    {
        plugin_nextmap_g_pos = 0    // mapcyclefile has been changed - go from first
    }
    else
    {
        plugin_nextmap_g_pos = str_to_num( szString3 )
    }
    
    readMapCycle( plugin_nextmap_g_mapCycle, plugin_nextmap_g_nextMap, charsmax( plugin_nextmap_g_nextMap ) )
    set_pcvar_string( plugin_nextmap_gp_nextmap, plugin_nextmap_g_nextMap )
    formatex( szString, charsmax( szString ), "%s %d", plugin_nextmap_g_mapCycle, plugin_nextmap_g_pos )
    set_localinfo( "lastmapcycle", szString ) // save lastmapcycle settings
}

getNextMapName( szArg[], iMax )
{
    new len = get_pcvar_string( plugin_nextmap_gp_nextmap, szArg, iMax )
    
    if( ValidMap( szArg ) )
    {
        return len
    }
    len = copy( szArg, iMax, plugin_nextmap_g_nextMap )
    set_pcvar_string( plugin_nextmap_gp_nextmap, plugin_nextmap_g_nextMap )
    
    return len
}

public sayNextMap()
{
    if( get_pcvar_num( cvar_nextMapChange )
        && !g_is_last_round
        && !( g_voteStatus & VOTE_IS_OVER ) )
    {
        if( g_voteStatus & VOTE_IN_PROGRESS )
        {
            color_print( 0, "^1%L %L", LANG_PLAYER, "NEXT_MAP",
                    LANG_PLAYER, "GAL_NEXTMAP_VOTING" )
        }
        else
        {
            color_print( 0, "^1%L", LANG_PLAYER, "NEXT_MAP",
                    LANG_PLAYER, "GAL_NEXTMAP_UNKNOWN" )
        }
    }
    else
    {
        new player_name[ MAX_PLAYER_NAME_LENGHT ]
        
        getNextMapName( player_name, charsmax( player_name ) )
        client_print( 0, print_chat, "%L %s", LANG_PLAYER, "NEXT_MAP", player_name )
    }
}

public sayCurrentMap()
{
    client_print( 0, print_chat, "%L: %s", LANG_PLAYER, "PLAYED_MAP", plugin_nextmap_g_currentMap )
}

public sayFFStatus()
{
    client_print( 0, print_chat, "%L: %L", LANG_PLAYER, "FRIEND_FIRE", LANG_PLAYER,
            get_pcvar_num( plugin_nextmap_g_friendlyfire ) ? "ON" : "OFF" )
}

public delayedChange( param[] )
{
    if( plugin_nextmap_g_chattime )
    {
        set_pcvar_float( plugin_nextmap_g_chattime, get_pcvar_float( plugin_nextmap_g_chattime ) - 2.0 )
    }
#if AMXX_VERSION_NUM < 183
    server_cmd( "changelevel %s", param )
#else
    engine_changelevel( param )
#endif
}

public changeMap()
{
    new string[ 32 ] // mp_chattime defaults to 10 in other mods
    new Float:chattime = plugin_nextmap_g_chattime ? get_pcvar_float( plugin_nextmap_g_chattime ) : 10.0;
    
    if( plugin_nextmap_g_chattime )
    {
        set_pcvar_float( plugin_nextmap_g_chattime, chattime + 2.0 ) // make sure mp_chattime is long
    }
    new len = getNextMapName( string, charsmax( string ) ) + 1
    set_task( chattime, "delayedChange", 0, string, len ) // change with 1.5 sec. delay
}

new g_warning[] = "WARNING: Couldn't find a valid map or the file doesn't exist (file ^"%s^")"

stock bool:ValidMap( mapname[] )
{
    if( is_map_valid( mapname ) )
    {
        return true;
    }
    // If the is_map_valid check failed, check the end of the string
    new len = strlen( mapname ) - 4;
    
    // The mapname was too short to possibly house the .bsp extension
    if( len < 0 )
    {
        return false;
    }
    
    if( equali( mapname[ len ], ".bsp" ) )
    {
        // If the ending was .bsp, then cut it off.
        // the string is byref'ed, so this copies back to the loaded text.
        mapname[ len ] = '^0';
        
        // recheck
        if( is_map_valid( mapname ) )
        {
            return true;
        }
    }
    
    return false;
}

readMapCycle( mapcycleFilePath[], szNext[], iNext )
{
    new b
    new szBuffer[ 32 ]
    new szFirst[ 32 ]
    
    new i     = 0
    new iMaps = 0
    
    if( file_exists( mapcycleFilePath ) )
    {
        while( read_file( mapcycleFilePath, i++, szBuffer, charsmax( szBuffer ), b ) )
        {
            if( !isalnum( szBuffer[ 0 ] )
                || !ValidMap( szBuffer ) )
            {
                continue
            }
            
            if( !iMaps )
            {
                copy( szFirst, charsmax( szFirst ), szBuffer )
            }
            
            if( ++iMaps > plugin_nextmap_g_pos )
            {
                copy( szNext, iNext, szBuffer )
                plugin_nextmap_g_pos = iMaps
                return
            }
        }
    }
    
    if( !iMaps )
    {
        log_amx( g_warning, mapcycleFilePath )
        copy( szNext, iNext, plugin_nextmap_g_currentMap )
    }
    else
    {
        copy( szNext, iNext, szFirst )
    }
    plugin_nextmap_g_pos = 1
}

// ################################## BELOW HERE ONLY GOES DEBUG/TEST CODE ###################################
#if defined DEBUG
public create_fakeVotes()
{
    if( !( g_voteStatus & VOTE_IS_RUNOFF ) )
    {
        g_arrayOfMapsWithVotesNumber[ 0 ] += 2;     // map 1
        g_arrayOfMapsWithVotesNumber[ 1 ] += 2;     // map 2
        g_arrayOfMapsWithVotesNumber[ 2 ] += 0;     // map 3
        g_arrayOfMapsWithVotesNumber[ 3 ] += 0;     // map 4
        g_arrayOfMapsWithVotesNumber[ 4 ] += 0;     // map 5
        
        if( get_pcvar_num( cvar_extendmapAllowStay ) )
        {
            g_arrayOfMapsWithVotesNumber[ 5 ] += 2;    // extend option
        }
        
        g_totalVotesCounted = g_arrayOfMapsWithVotesNumber[ 0 ] + g_arrayOfMapsWithVotesNumber[ 1 ] +
                              g_arrayOfMapsWithVotesNumber[ 2 ] + g_arrayOfMapsWithVotesNumber[ 3 ] +
                              g_arrayOfMapsWithVotesNumber[ 4 ] + g_arrayOfMapsWithVotesNumber[ 5 ];
    }
    else if( g_voteStatus & VOTE_IS_RUNOFF )
    {
        g_arrayOfMapsWithVotesNumber[ 0 ] += 2;     // choice 1
        g_arrayOfMapsWithVotesNumber[ 1 ] += 2;     // choice 2
        
        g_totalVotesCounted = g_arrayOfMapsWithVotesNumber[ 0 ] + g_arrayOfMapsWithVotesNumber[ 1 ];
    }
}

/**
 * This function run all tests that are listed at it. Every test that is created must
 * to be called here to it register itself at the Test System and perform the testing.
 */
public runTests()
{
    new test_name[ SHORT_STRING ]
    
    DEBUG_LOGGER( 128, "^n^n    Executing the 'Galileo' Tests: ^n" )
    
    save_server_cvasr_for_test()
    
    ALL_TESTS_TO_EXECUTE
    
    DEBUG_LOGGER( 128, "^n    %d tests succeed.^n    %d tests failed.", g_totalSuccessfulTests, \
            g_totalFailureTests )
    
    if( ArraySize( g_tests_failure_ids ) )
    {
        DEBUG_LOGGER( 128, "^n    The following tests failed:" )
    }
    
    for( new failure_index = 0; failure_index < ArraySize( g_tests_failure_ids ); failure_index++ )
    {
        ArrayGetString( g_tests_idsAndNames, ArrayGetCell( g_tests_failure_ids, failure_index ) - 1,
                test_name, charsmax( test_name ) )
        
        DEBUG_LOGGER( 128, "       %s", test_name )
    }
    
    if( g_max_delay_result )
    {
        DEBUG_LOGGER( 128, "^n    The following tests are waiting until %d seconds to finish:", \
                g_max_delay_result )
    }
    
    for( new delayed_index = 0; delayed_index < ArraySize( g_tests_delayed_ids ); delayed_index++ )
    {
        ArrayGetString( g_tests_idsAndNames, ArrayGetCell( g_tests_delayed_ids, delayed_index ) - 1,
                test_name, charsmax( test_name ) )
        
        DEBUG_LOGGER( 128, "       %s", test_name )
    }
    
    if( g_max_delay_result )
    {
        set_task( g_max_delay_result + 1.0, "show_delayed_results" )
        DEBUG_LOGGER( 128, "^n    Finished Tests First Step Execution.^n^n" )
    }
    else
    {
        restore_server_cvars_for_test()
        DEBUG_LOGGER( 128, "^n    Finished 'Galileo' Tests Execution.^n^n" )
    }
}

/**
 * This is executed at the end of the delayed tests execution to show its results and restore any
 * cvars variable change.
 */
public show_delayed_results()
{
    new test_name[ SHORT_STRING ]
    
    DEBUG_LOGGER( 128, "^n^n    Showing 'Galileo' Tests Delayed Results..." )
    
    DEBUG_LOGGER( 128, "^n    %d tests succeed.^n    %d tests failed.", g_totalSuccessfulTests, \
            g_totalFailureTests )
    
    if( ArraySize( g_tests_failure_ids ) )
    {
        DEBUG_LOGGER( 128, "^n    The following tests failed:" )
    }
    
    for( new failure_index = 0; failure_index < ArraySize( g_tests_failure_ids ); failure_index++ )
    {
        ArrayGetString( g_tests_idsAndNames, ArrayGetCell( g_tests_failure_ids, failure_index ) - 1,
                test_name, charsmax( test_name ) )
        
        DEBUG_LOGGER( 128, "       %s", test_name )
    }
    
    DEBUG_LOGGER( 128, "^n    Finished 'Galileo' Tests Execution. ^n^n" )
    
    // clean the testing
    cancel_voting()
    restore_server_cvars_for_test()
}

/**
 * This is the first thing called when a test begin running. It function is to let the
 * Test System know that the test exists and then know how to handle it using
 * the test_id.
 *
 * @param max_delay_result the max delay time to finish test execution.
 * @param test_name the test name to register
 *
 * @return test_id an integer that refers it at the Test System.
 */
stock register_test( max_delay_result, test_name[] )
{
    g_totalSuccessfulTests++
    
    new totalTests = g_totalSuccessfulTests + g_totalFailureTests
    
    ArrayPushString( g_tests_idsAndNames, test_name )
    DEBUG_LOGGER( 128, "    Executing test %d with %d delay - %s ", totalTests, max_delay_result, \
            test_name )
    
    if( g_max_delay_result < max_delay_result )
    {
        g_max_delay_result = max_delay_result
    }
    
    if( max_delay_result )
    {
        ArrayPushCell( g_tests_delayed_ids, totalTests )
    }
    
    return totalTests
}

/**
 * Informs the Test System that the test failed and why.
 *
 * @test_id the test_id at the Test System
 * @failure_reason the reason why the test failed
 * @any a variable number of formatting parameters
 */
stock set_test_failure_internal( test_id, failure_reason[], any: ... )
{
    g_totalSuccessfulTests--
    g_totalFailureTests++
    
    static formated_message[ LONG_STRING ]
    
    vformat( formated_message, charsmax( formated_message ), failure_reason, 3 )
    
    ArrayPushCell( g_tests_failure_ids, test_id )
    DEBUG_LOGGER( 128, "       Test failure! %s", formated_message )
}

/**
 * This is a simple test to verify the basic registering test functionality.
 */
stock test_register_test()
{
    new test_id = register_test( 0, "test_register_test" )
    
    if( g_totalSuccessfulTests != 1 )
    {
        SET_TEST_FAILURE( test_id, "g_totalSuccessfulTests must be 1 (it was %d)", \
                g_totalSuccessfulTests )
    }
    
    if( test_id != 1 )
    {
        SET_TEST_FAILURE( test_id, "test_id must be 1 (it was %d)", test_id )
    }
    
    new first_test_name[ 64 ]
    ArrayGetString( g_tests_idsAndNames, 0, first_test_name, charsmax( first_test_name ) )
    
    if( !equal( first_test_name, "test_register_test" ) )
    {
        SET_TEST_FAILURE( test_id, "first_test_name must be 'test_register_test' (it was %s)", \
                first_test_name )
    }
}

/**
 * Test for client connect cvar_isToStopEmptyCycle behavior.
 */
stock test_gal_in_empty_cycle1()
{
    new test_id = register_test( 0, "test_gal_in_empty_cycle1" )
    
    set_pcvar_num( cvar_isToStopEmptyCycle, 1 )
    client_authorized( 1 )
    
    if( get_pcvar_num( cvar_isToStopEmptyCycle ) )
    {
        SET_TEST_FAILURE( test_id, "test_gal_in_empty_cycle1() cvar_isToStopEmptyCycle must be 0 (it was %d)", \
                get_pcvar_num( cvar_isToStopEmptyCycle ) )
    }
    
    set_pcvar_num( cvar_isToStopEmptyCycle, 0 )
    client_authorized( 1 )
    
    if( get_pcvar_num( cvar_isToStopEmptyCycle ) )
    {
        SET_TEST_FAILURE( test_id, "test_gal_in_empty_cycle1() cvar_isToStopEmptyCycle must be 0 (it was %d)", \
                get_pcvar_num( cvar_isToStopEmptyCycle ) )
    }
}

/**
 * This 1º case test if the current map isn't part of the empty cycle, immediately change to next map
 * that is.
 */
stock test_gal_in_empty_cycle2()
{
    new test_id              = register_test( 0, "test_gal_in_empty_cycle2" )
    new Array: emptyCycleMap = ArrayCreate( MAX_MAPNAME_LENGHT );
    
    ArrayPushString( emptyCycleMap, "de_dust2" )
    ArrayPushString( emptyCycleMap, "de_inferno" )
    
    // set the next map from the empty cycle list,
    // or the first one, if the current map isn't part of the cycle
    new nextMap[ MAX_MAPNAME_LENGHT ]
    
    new mapIndex = map_getNext( emptyCycleMap, "de_dust2", nextMap );
    
    if( !equal( nextMap, "de_inferno" ) )
    {
        SET_TEST_FAILURE( test_id, "test_gal_in_empty_cycle2() nextMap must be 'de_inferno' \
                (it was %s)", nextMap )
    }
    
    // if the current map isn't part of the empty cycle,
    // immediately change to next map that is
    if( mapIndex == -1 )
    {
        SET_TEST_FAILURE( test_id, "test_gal_in_empty_cycle2() mapIndex must NOT be '-1' \
                (it was %d)", mapIndex )
    }
}

/**
 * This 2º case test if the current map isn't part of the empty cycle, immediately change to next map
 * that is.
 */
stock test_gal_in_empty_cycle3()
{
    new test_id              = register_test( 0, "test_gal_in_empty_cycle3" )
    new Array: emptyCycleMap = ArrayCreate( MAX_MAPNAME_LENGHT );
    
    ArrayPushString( emptyCycleMap, "de_dust2" )
    ArrayPushString( emptyCycleMap, "de_inferno" )
    ArrayPushString( emptyCycleMap, "de_dust4" )
    
    // set the next map from the empty cycle list,
    // or the first one, if the current map isn't part of the cycle
    new nextMap[ MAX_MAPNAME_LENGHT ]
    
    new mapIndex = map_getNext( emptyCycleMap, "de_inferno", nextMap );
    
    if( !equal( nextMap, "de_dust4" ) )
    {
        SET_TEST_FAILURE( test_id, "test_gal_in_empty_cycle3() nextMap must be 'de_dust4' \
                (it was %s)", nextMap )
    }
    
    // if the current map isn't part of the empty cycle,
    // immediately change to next map that is
    if( mapIndex == -1 )
    {
        SET_TEST_FAILURE( test_id, "test_gal_in_empty_cycle3() mapIndex must NOT be '-1' \
                (it was %d)", mapIndex )
    }
}

/**
 * This 3º case test if the current map isn't part of the empty cycle, immediately change to next map
 * that is.
 */
stock test_gal_in_empty_cycle4()
{
    new test_id              = register_test( 0, "test_gal_in_empty_cycle4" )
    new Array: emptyCycleMap = ArrayCreate( MAX_MAPNAME_LENGHT );
    
    ArrayPushString( emptyCycleMap, "de_dust2" )
    ArrayPushString( emptyCycleMap, "de_inferno" )
    ArrayPushString( emptyCycleMap, "de_dust4" )
    
    // set the next map from the empty cycle list,
    // or the first one, if the current map isn't part of the cycle
    new nextMap[ MAX_MAPNAME_LENGHT ]
    
    new mapIndex = map_getNext( emptyCycleMap, "de_dust", nextMap );
    
    if( !equal( nextMap, "de_dust2" ) )
    {
        SET_TEST_FAILURE( test_id, "test_gal_in_empty_cycle4() nextMap must be 'de_dust2' \
                (it was %s)", nextMap )
    }
    
    // if the current map isn't part of the empty cycle,
    // immediately change to next map that is
    if( !( mapIndex == -1 ) )
    {
        SET_TEST_FAILURE( test_id, "test_gal_in_empty_cycle4() mapIndex must be '-1' \
                (it was %d)", mapIndex )
    }
}

/**
 * This is the vote_startDirector() tests chain beginning. Because the vote_startDirector() cannot
 * to be tested simultaneously.
 *
 * Then, all tests that involves the vote_startDirector() chain, must to be executed sequencially
 * after this chain end.
 *
 * This is the 1º chain test, and test if the cvar 'amx_extendmap_max' functionality is working
 * properly.
 */
stock test_is_map_extension_allowed1( bool:skip = false )
{
    if( skip )
    {
        return
    }
    
    new test_id = register_test( 23, "test_is_map_extension_allowed1" )
    
    if( g_is_map_extension_allowed )
    {
        SET_TEST_FAILURE( test_id, "g_is_map_extension_allowed must be 0 (it was %d)", \
                g_is_map_extension_allowed )
    }
    
    if( !g_refreshVoteStatus )
    {
        SET_TEST_FAILURE( test_id, "g_refreshVoteStatus must be 1 (it was %d)", \
                g_is_map_extension_allowed )
    }
    
    cancel_voting()
    vote_startDirector( false )
    
    if( !g_is_map_extension_allowed )
    {
        SET_TEST_FAILURE( test_id, "g_is_map_extension_allowed must be 1 (it was %d)", \
                g_is_map_extension_allowed )
    }
    
    set_task( 10.0, "test_is_map_extension_allowed2", test_id )
    g_refreshVoteStatus = true;
}

/**
 * This is the 2º test at vote_startDirector() chain and must add 10.0 seconds to the total time
 * execution.
 *
 * This 2º, test if the cvar 'amx_extendmap_max' functionality is working properly.
 */
public test_is_map_extension_allowed2( test_id )
{
    if( g_refreshVoteStatus )
    {
        SET_TEST_FAILURE( test_id, "g_refreshVoteStatus must be 0 (it was %d)", \
                g_is_map_extension_allowed )
    }
    
    set_pcvar_float( cvar_extendmapMax, 10.0 )
    set_pcvar_float( g_timelimit_pointer, 20.0 )
    
    color_print( 0, "^1%L", LANG_PLAYER, "GAL_CHANGE_TIMEEXPIRED" );
    
    cancel_voting()
    vote_startDirector( false )
    
    if( g_is_map_extension_allowed )
    {
        SET_TEST_FAILURE( test_id, "g_is_map_extension_allowed must be 0 (it was %d)", \
                g_is_map_extension_allowed )
    }
    
    set_task( 10.0, "test_is_map_extension_allowed3", test_id )
    g_refreshVoteStatus = false;
}

/**
 * This is the 3º test at vote_startDirector() chain and must add 3 seconds to the total time
 * execution.
 *
 * This 3º, tests if the end map voting is starting automatically at the end of map due time limit
 * expiration.
 */
public test_is_map_extension_allowed3( test_id )
{
    if( !g_refreshVoteStatus )
    {
        SET_TEST_FAILURE( test_id, "g_refreshVoteStatus must be 1 (it was %d)", \
                g_is_map_extension_allowed )
    }
    
    cancel_voting()
    
    set_task( 3.0, "test_is_map_extension_allowed4", test_id )
}

/**
 * This is the 4º test at vote_startDirector() chain and must add 0 seconds to the total time
 * execution.
 *
 * This 4º, tests if the end map voting is starting automatically at the end of map due time limit
 * expiration.
 */
public test_is_map_extension_allowed4( test_id )
{
    new secondsLeft = get_timeleft();
    
    set_pcvar_float( g_timelimit_pointer, (
                ( get_pcvar_float( g_timelimit_pointer ) ) * 60 - secondsLeft
                + START_VOTEMAP_MIN_TIME - 10 ) / 60 )
    
    vote_manageEnd()
    
    if( !( g_voteStatus & VOTE_IN_PROGRESS ) )
    {
        SET_TEST_FAILURE( test_id, "vote_startDirector() does not started!" )
    }
}

/**
 * Every time a cvar is changed during the tests, it must be saved here to a global test variable
 * to be restored at the restore_server_cvars_for_test(), which is executed at the end of all
 * tests execution. This is executed before the first rest run.
 */
stock save_server_cvasr_for_test()
{
    g_is_test_changed_cvars = true
    
    test_extendmap_max = get_pcvar_float( cvar_extendmapMax )
    test_mp_timelimit  = get_pcvar_float( g_timelimit_pointer )
    
    DEBUG_LOGGER( 4, "%32s mp_timelimit: %f  test_mp_timelimit: %f   g_originalTimelimit: %f",  \
            "save_server_cvasr_for_test( out )", get_pcvar_float( g_timelimit_pointer ), \
            test_mp_timelimit, g_originalTimelimit )
}

/**
 * This is executed at the end of all tests execution to restore server variables changes.
 */
stock restore_server_cvars_for_test()
{
    DEBUG_LOGGER( 4, "%32s mp_timelimit: %f  test_mp_timelimit: %f  g_originalTimelimit: %f",  \
            "restore_server_cvars_for_test( in )", get_pcvar_float( g_timelimit_pointer ), \
            test_mp_timelimit, g_originalTimelimit )
    
    if( g_is_test_changed_cvars )
    {
        g_is_test_changed_cvars = false
        
        set_pcvar_float( cvar_extendmapMax, test_extendmap_max )
        set_pcvar_float( g_timelimit_pointer, test_mp_timelimit )
    }
    
    DEBUG_LOGGER( 4, "%32s mp_timelimit: %f  test_mp_timelimit: %f  g_originalTimelimit: %f",  \
            "restore_server_cvars_for_test( out )", get_pcvar_float( g_timelimit_pointer ), \
            test_mp_timelimit, g_originalTimelimit )
}
#endif

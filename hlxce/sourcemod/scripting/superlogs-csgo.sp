/**
 * HLstatsX Community Edition - SourceMod plugin to generate advanced weapon logging
 * http://www.hlxcommunity.com
 * Copyright (C) 2009 Nicholas Hastings (psychonic)
 * Copyright (C) 2007-2008 TTS Oetzel & Goerz GmbH
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

#pragma semicolon 1
 
#include <sourcemod>
#include <sdktools>

#define NAME "SuperLogs: CS:GO"
#define VERSION "1.2.6"

#define MAX_LOG_WEAPONS 41
#define IGNORE_SHOTS_START 35
#define MAX_WEAPON_LEN 40


new g_weapon_stats[MAXPLAYERS+1][MAX_LOG_WEAPONS][15];
new const String:g_weapon_list[MAX_LOG_WEAPONS][MAX_WEAPON_LEN] = {
									"ak47", 
									"aug",
									"awp", 
									"bizon",
									"deagle",
									"elite",
									"famas",
									"fiveseven",
									"g3sg1",
									"galilar",
									"glock",
									"hpk2000",
									"usp_silencer",
									"usp_silencer_off",
									"m249",
									"m4a1",
									"m4a1_silencer",
									"m4a1_silencer_off",
									"mac10",
									"mag7",
									"mp7",
									"mp9",
									"negev",
									"nova",
									"p250",
									"cz75a",
									"p90",
									"sawedoff",
									"scar20",
									"sg556",
									"ssg08",
									"taser",
									"tec9",
									"ump45",
									"xm1014",
									"incgrenade",
									"hegrenade",
									"molotov",
									"flashbang",
									"smokegrenade",
									"decoy" 
								};

new Handle:g_cvar_wstats = INVALID_HANDLE;
new Handle:g_cvar_headshots = INVALID_HANDLE;
new Handle:g_cvar_actions = INVALID_HANDLE;
new Handle:g_cvar_locations = INVALID_HANDLE;
new Handle:g_cvar_ktraj = INVALID_HANDLE;
new Handle:g_cvar_version = INVALID_HANDLE;
new EngineVersion:CurrentVersion;

new bool:g_logwstats = true;
new bool:g_logheadshots = true;
new bool:g_logactions = true;
new bool:g_loglocations = true;
new bool:g_logktraj = false;

#include <loghelper>
#include <wstatshelper>


public Plugin:myinfo = {
	name = NAME,
	author = "psychonic",
	description = "Advanced logging for CS:GO. Generates auxilary logging for use with log parsers such as HLstatsX and Psychostats",
	version = VERSION,
	url = "http://www.hlxcommunity.com"
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CurrentVersion = GetEngineVersion();
	if (CurrentVersion != Engine_CSGO)
	{
		strcopy(error, err_max, "This plugin is only supported on CS:GO");
		return APLRes_Failure;
	}
	return APLRes_Success;
}


public OnPluginStart()
{
	CreatePopulateWeaponTrie();
	
	g_cvar_wstats = CreateConVar("superlogs_wstats", "1", "Enable logging of weapon stats (default on)", 0, true, 0.0, true, 1.0);
	g_cvar_headshots = CreateConVar("superlogs_headshots", "1", "Enable logging of headshot player action (default on)", 0, true, 0.0, true, 1.0);
	g_cvar_actions = CreateConVar("superlogs_actions", "1", "Enable logging of player actions (default on)", 0, true, 0.0, true, 1.0);
	g_cvar_locations = CreateConVar("superlogs_locations", "1", "Enable logging of location on player death (default on)", 0, true, 0.0, true, 1.0);
	g_cvar_ktraj = CreateConVar("superlogs_ktraj", "0", "Enable Psychostats \"KTRAJ\" logging (default off)", 0, true, 0.0, true, 1.0);
	
	// cvars will have already existed if plugin was reloaded and might be set to non-default values
	g_logwstats = GetConVarBool(g_cvar_wstats);
	g_logheadshots = GetConVarBool(g_cvar_headshots);
	g_logactions = GetConVarBool(g_cvar_actions);
	g_loglocations = GetConVarBool(g_cvar_locations);
	g_logktraj = GetConVarBool(g_cvar_ktraj);
	
	HookConVarChange(g_cvar_wstats, OnCvarWstatsChange);
	HookConVarChange(g_cvar_headshots, OnCvarHeadshotsChange);
	HookConVarChange(g_cvar_actions, OnCvarActionsChange);
	HookConVarChange(g_cvar_locations, OnCvarLocationsChange);
	HookConVarChange(g_cvar_ktraj, OnCvarKtrajChange);
	
	g_cvar_version = CreateConVar("superlogs_css_version", VERSION, NAME, FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
		
	hook_wstats();
	hook_actions();
	HookEvent("player_death", Event_PlayerDeathPre, EventHookMode_Pre);
	HookEvent("player_death", Event_PlayerDeath);
		
	CreateTimer(1.0, LogMap);
	
	GetTeams();
}


public OnMapStart()
{
	GetTeams();
}

public OnConfigsExecuted()
{
	decl String:version[255];
	GetConVarString(g_cvar_version, version, sizeof(version));
	SetConVarString(g_cvar_version, version);
}

hook_wstats()
{
	HookEvent("weapon_fire", Event_PlayerShoot);
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
}

unhook_wstats()
{
	UnhookEvent("weapon_fire", Event_PlayerShoot);
	UnhookEvent("player_hurt", Event_PlayerHurt);
	UnhookEvent("player_spawn", Event_PlayerSpawn);
	UnhookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	UnhookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
}

hook_actions()
{
	HookEvent("round_mvp", Event_RoundMVP);
}

unhook_actions()
{
	UnhookEvent("round_mvp", Event_RoundMVP);
}

public OnClientPutInServer(client)
{
	reset_player_stats(client);
}


public Event_PlayerShoot(Handle:event, const String:name[], bool:dontBroadcast)
{
	// "userid"        "short"
	// "weapon"        "string"        // weapon name used

	new attacker   = GetClientOfUserId(GetEventInt(event, "userid"));
	if (attacker > 0)
	{
		decl String: weapon[MAX_WEAPON_LEN];
		GetEventString(event, "weapon", weapon, sizeof(weapon));
		ReplaceString(weapon, sizeof(weapon), "weapon_", "", false);
		new weapon_index = get_weapon_index(weapon);
		if (weapon_index > -1 && weapon_index < IGNORE_SHOTS_START)
		{
			g_weapon_stats[attacker][weapon_index][LOG_HIT_SHOTS]++;
		}
	}
}


public Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	//	"userid"        "short"         // player index who was hurt
	//	"attacker"      "short"         // player index who attacked
	//	"health"        "byte"          // remaining health points
	//	"armor"         "byte"          // remaining armor points
	//	"weapon"        "string"        // weapon name attacker used, if not the world
	//	"dmg_health"    "byte"  		// damage done to health
	//	"dmg_armor"     "byte"          // damage done to armor
	//	"hitgroup"      "byte"          // hitgroup that was damaged

	new attacker  = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if (attacker > 0) {
		decl String: weapon[MAX_WEAPON_LEN];
		GetEventString(event, "weapon", weapon, sizeof(weapon));
		new weapon_index = get_weapon_index(weapon);
		if (weapon_index > -1)
		{
			g_weapon_stats[attacker][weapon_index][LOG_HIT_HITS]++;
			g_weapon_stats[attacker][weapon_index][LOG_HIT_DAMAGE] += GetEventInt(event, "dmg_health");
			new hitgroup  = GetEventInt(event, "hitgroup");
			if (hitgroup < 8)
			{
				g_weapon_stats[attacker][weapon_index][hitgroup + LOG_HIT_OFFSET]++;
			}
		}
	}
}


public Action:Event_PlayerDeathPre(Handle:event, const String:name[], bool:dontBroadcast)
{
	// "userid"        "short"         // user ID who died                             
	// "attacker"      "short"         // user ID who killed
	// "weapon"        "string"        // weapon name killer used 
	// "headshot"      "bool"          // signals a headshot
	
	new attacker = GetEventInt(event, "attacker");
	if (g_loglocations)
	{
		LogKillLoc(GetClientOfUserId(attacker), GetClientOfUserId(GetEventInt(event, "userid")));
	}

	if (g_logheadshots && GetEventBool(event, "headshot"))
	{
		LogPlayerEvent(GetClientOfUserId(attacker), "triggered", "headshot");
	}
	
	return Plugin_Continue;
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	// this extents the original player_death by a new fields
	// "userid"        "short"         // user ID who died                             
	// "attacker"      "short"         // user ID who killed
	// "weapon"        "string"        // weapon name killer used 
	// "headshot"      "bool"          // signals a headshot
	// "dominated"    "short"        // did killer dominate victim with this kill
	// "revenge"    "short"        // did killer get revenge on victim with this kill
	
	new victim   = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	decl String: weapon[MAX_WEAPON_LEN];
	GetEventString(event, "weapon", weapon, sizeof(weapon));
	
	if (attacker <= 0 || victim <= 0)
	{
		return;
	}
	
	if (g_logwstats)
	{
		new weapon_index = get_weapon_index(weapon);
		if (weapon_index > -1)
		{
			g_weapon_stats[attacker][weapon_index][LOG_HIT_KILLS]++;
			if (GetEventBool(event, "headshot"))
			{
				g_weapon_stats[attacker][weapon_index][LOG_HIT_HEADSHOTS]++;
			}
			g_weapon_stats[victim][weapon_index][LOG_HIT_DEATHS]++;
			if (GetClientTeam(attacker) == GetClientTeam(victim))
			{
				g_weapon_stats[attacker][weapon_index][LOG_HIT_TEAMKILLS]++;
			}
			dump_player_stats(victim);
		}
	}
	if (g_logktraj)
	{
		LogPSKillTraj(attacker, victim, weapon);
	}
	if (g_logactions)
	{
		// these are only in Orangebox CS:S. These properties won't exist on ep1 css and should eval to 0/false.
		if (GetEventInt(event, "dominated"))
		{
			LogPlyrPlyrEvent(attacker, victim, "triggered", "domination");
		}
		else if (GetEventInt(event, "revenge"))
		{
			LogPlyrPlyrEvent(attacker, victim, "triggered", "revenge");
		}
	}
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	// "userid"        "short"         // user ID on server          

	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client > 0)
	{
		reset_player_stats(client);
	}
}

public Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	WstatsDumpAll();
}

public Event_RoundMVP(Handle:event, const String:name[], bool:dontBroadcast)
{
	LogPlayerEvent(GetClientOfUserId(GetEventInt(event, "userid")), "triggered", "round_mvp");
}

public Action:Event_PlayerDisconnect(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	OnPlayerDisconnect(client);
	return Plugin_Continue;
}


public Action:LogMap(Handle:timer)
{
	// Called 1 second after OnPluginStart since srcds does not log the first map loaded. Idea from Stormtrooper's "mapfix.sp" for psychostats
	LogMapLoad();
}


public OnCvarWstatsChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	new bool:old_value = g_logwstats;
	g_logwstats = GetConVarBool(g_cvar_wstats);
	
	if (old_value != g_logwstats)
	{
		if (g_logwstats)
		{
			hook_wstats();
			if (!g_logktraj && !g_logactions)
			{
				HookEvent("player_death", Event_PlayerDeath);
			}
		}
		else
		{
			unhook_wstats();
			if (!g_logktraj && !g_logactions)
			{
				UnhookEvent("player_death", Event_PlayerDeath);
			}
		}
	}
}

public OnCvarActionsChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	new bool:old_value = g_logactions;
	g_logactions = GetConVarBool(g_cvar_actions);
	
	if (old_value != g_logactions)
	{
		if (g_logactions)
		{
			hook_actions();
			if (!g_logktraj && !g_logwstats)
			{
				HookEvent("player_death", Event_PlayerDeath);
			}
		}
		else
		{
			unhook_actions();
			if (!g_logktraj && !g_logwstats)
			{
				UnhookEvent("player_death", Event_PlayerDeath);
			}
		}
	}
}

public OnCvarHeadshotsChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	new bool:old_value = g_logheadshots;
	g_logheadshots = GetConVarBool(g_cvar_headshots);
	
	if (old_value != g_logheadshots)
	{
		if (g_logheadshots && !g_loglocations)
		{
			HookEvent("player_death", Event_PlayerDeathPre, EventHookMode_Pre);
		}
		else if (!g_loglocations)
		{
			UnhookEvent("player_death", Event_PlayerDeathPre, EventHookMode_Pre);
		}
	}
}

public OnCvarLocationsChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	new bool:old_value = g_loglocations;
	g_loglocations = GetConVarBool(g_cvar_locations);
	
	if (old_value != g_loglocations)
	{
		if (g_loglocations && !g_logheadshots)
		{
			HookEvent("player_death", Event_PlayerDeathPre, EventHookMode_Pre);
		}
		else if (!g_logheadshots)
		{
			UnhookEvent("player_death", Event_PlayerDeathPre, EventHookMode_Pre);
		}
	}
}

public OnCvarKtrajChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	new bool:old_value = g_logktraj;
	g_logktraj = GetConVarBool(g_cvar_ktraj);
	
	if (old_value != g_logktraj)
	{
		if (g_logktraj && !g_logwstats && !g_logactions)
		{
			HookEvent("player_death", Event_PlayerDeath);
		}
		else if (!g_logwstats && !g_logactions)
		{
			UnhookEvent("player_death", Event_PlayerDeath);
		}
	}
}

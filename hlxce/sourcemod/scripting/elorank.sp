#pragma semicolon 1

#include <sourcemod>
#include <cstrike>
#include <sdkhooks>
#include <sdktools>
#include <clientprefs>

new iRank[MAXPLAYERS+1] = {0,...};

public Plugin:myinfo = {
	name = "[CS:GO] !mm for hlstatsx",
	author = "Laam4",
	description = "",
	version = "1.0",
	url = ""
};

public OnPluginStart() {
	RegConsoleCmd("sm_mm", Command_EloMenu);
}

public Action:Command_EloMenu(client, args)
{
	if ( IsClientInGame(client) )
	{
		new Handle:MenuHandle = CreateMenu(EloHandler);
		SetMenuTitle(MenuHandle, "Your competitive rank?");
		AddMenuItem(MenuHandle, "0", "No Rank");
		AddMenuItem(MenuHandle, "1", "Silver I");
		AddMenuItem(MenuHandle, "2", "Silver II");
		AddMenuItem(MenuHandle, "3", "Silver III");
		AddMenuItem(MenuHandle, "4", "Silver IV");
		AddMenuItem(MenuHandle, "5", "Silver Elite");
		AddMenuItem(MenuHandle, "6", "Silver Elite Master");
		AddMenuItem(MenuHandle, "7", "Gold Nova I");
		AddMenuItem(MenuHandle, "8", "Gold Nova II");
		AddMenuItem(MenuHandle, "9", "Gold Nova III");
		AddMenuItem(MenuHandle, "10", "Gold Nova Master");
		AddMenuItem(MenuHandle, "11", "Master Guardian I");
		AddMenuItem(MenuHandle, "12", "Master Guardian II");
		AddMenuItem(MenuHandle, "13", "Master Guardian Elite");
		AddMenuItem(MenuHandle, "14", "Distinguished Master Guardian");
		AddMenuItem(MenuHandle, "15", "Legendary Eagle");
		AddMenuItem(MenuHandle, "16", "Legendary Eagle Master");
		AddMenuItem(MenuHandle, "17", "Supreme Master First Class");
		AddMenuItem(MenuHandle, "18", "The Global Elite");

		SetMenuPagination(MenuHandle, 8);
		DisplayMenu(MenuHandle, client, 30);
	}
	return Plugin_Handled;
}

public EloHandler(Handle:menu, MenuAction:action, client, itemNum)
{
	switch(action)
	{
	case MenuAction_Select:
		{
			new String:error[255];
			new Handle:db = SQL_DefConnect(error, sizeof(error));
			new String:info[4];
			GetMenuItem(menu, itemNum, info, sizeof(info));
			iRank[client] = StringToInt(info);
			new String:set_rank[255];
			decl String:buffer[3][32];
			new String:auth[64];
			GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
			ExplodeString(auth, ":", buffer, 3, 32);
			//PrintToServer("uniqueid: %s:%s", buffer[1], buffer[2]);
			Format(set_rank, sizeof(set_rank), "UPDATE hlstats_PlayerUniqueIds LEFT JOIN hlstats_Players ON hlstats_Players.playerId = hlstats_PlayerUniqueIds.playerId SET hlstats_Players.mmrank='%d' WHERE uniqueId='%s:%s'", iRank[client], buffer[1], buffer[2]);
			if (!SQL_FastQuery(db, set_rank))
			{
				SQL_GetError(db, error, sizeof(error));
				PrintToServer("Failed to query (error: %s)", error);
			}
			new String:text[64];
			Format(text, sizeof(text), "Your rank is now ");
			switch(iRank[client])
			{
			case 0:PrintToChat(client, "%s\x08No Rank", text);
			case 1:PrintToChat(client, "%s\x0ASilver I", text);
			case 2:PrintToChat(client, "%s\x0ASilver II", text);
			case 3:PrintToChat(client, "%s\x0ASilver III", text);
			case 4:PrintToChat(client, "%s\x0ASilver IV", text);
			case 5:PrintToChat(client, "%s\x0ASilver Elite", text);
			case 6:PrintToChat(client, "%s\x0ASilver Elite Master", text);
			case 7:PrintToChat(client, "%s\x0BGold Nova I", text);
			case 8:PrintToChat(client, "%s\x0BGold Nova II", text);
			case 9:PrintToChat(client, "%s\x0BGold Nova III", text);
			case 10:PrintToChat(client, "%s\x0BGold Nova Master", text);
			case 11:PrintToChat(client, "%s\x0CMaster Guardian I", text);
			case 12:PrintToChat(client, "%s\x0CMaster Guardian II", text);
			case 13:PrintToChat(client, "%s\x0CMaster Guardian Elite", text);
			case 14:PrintToChat(client, "%s\x0CDistinguished Master Guardian", text);
			case 15:PrintToChat(client, "%s\x0ELegendary Eagle", text);
			case 16:PrintToChat(client, "%s\x0ELegandary Eagle Master", text);
			case 17:PrintToChat(client, "%s\x0ESupreme Master First Class", text);
			case 18:PrintToChat(client, "%s\x0FThe Global Elite", text);
			default: PrintToChat(client, "Dunno lol");
			}
		}
	case MenuAction_End:
		{
			CloseHandle(menu);
		}
	}
}

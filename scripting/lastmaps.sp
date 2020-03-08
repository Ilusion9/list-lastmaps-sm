#include <sourcemod>
#pragma newdecls required

public Plugin myinfo =
{
	name = "Last Maps",
	author = "Ilusion9",
	description = "Informations about the last maps played.",
	version = "1.0",
	url = "https://github.com/Ilusion9/"
};

enum struct MapInfo
{
	char mapName[128];
	int startTime;
}

ArrayList g_List_LastMaps;
ConVar g_Cvar_MaxLastMaps;
MapInfo g_CurrentMapInfo;

public void OnPluginStart()
{
	g_List_LastMaps = new ArrayList(sizeof(MapInfo));
	g_Cvar_MaxLastMaps = CreateConVar("sm_lastmaps_maxsize", "15", "How many maps will be shown in the last maps list?", FCVAR_NONE, true, 0.0);

	RegConsoleCmd("sm_lastmaps", Command_LastMaps);
}

public void OnMapStart()
{
	g_List_LastMaps.Clear();
	
	GetCurrentMap(g_CurrentMapInfo.mapName, sizeof(MapInfo::mapName));
	g_CurrentMapInfo.startTime = GetTime();
	
	MapInfo info;
	KeyValues kv = new KeyValues("Last Maps");
	
	if (kv.ImportFromFile("lastmaps.ini"))
	{
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				kv.GetString("name", info.mapName, sizeof(MapInfo::mapName), "");
				info.startTime = kv.GetNum("started", 0);
				g_List_LastMaps.PushArray(info);
				
			} while (kv.GotoNextKey(false));
		}
	}
	
	delete kv;
}

public void OnMapEnd()
{
	MapInfo info;
	char buffer[256];
	KeyValues kv = new KeyValues("Last Maps");
	
	kv.JumpToKey("0", true);
	kv.SetString("name", g_CurrentMapInfo.mapName);
	kv.SetNum("started", g_CurrentMapInfo.startTime);
	kv.GoBack();
	
	if (g_List_LastMaps.Length > g_Cvar_MaxLastMaps.IntValue - 1)
	{
		g_List_LastMaps.Resize(g_Cvar_MaxLastMaps.IntValue - 1);
	}
	
	for (int i = 0; i < g_List_LastMaps.Length; i++)
	{
		Format(buffer, sizeof(buffer), "%d", i + 1);
		kv.JumpToKey(buffer, true);
		
		g_List_LastMaps.GetArray(i, info);
		kv.SetString("name", info.mapName);
		kv.SetNum("started", info.startTime);
		kv.GoBack();
	}
	
	kv.Rewind();
	kv.ExportToFile("lastmaps.ini");
	delete kv;
}

public Action Command_LastMaps(int client, int args)
{
	MapInfo info;
	char startedTime[64], playedTime[64];	
	int lastMapStartTime = g_CurrentMapInfo.startTime;
	
	PrintToConsole(client, "Last Maps:");
	PrintToConsole(client, "  00. %s : current map", g_CurrentMapInfo.mapName);
	
	for (int i = 0; i < g_List_LastMaps.Length; i++)
	{
		g_List_LastMaps.GetArray(i, info);
		
		FormatTimeDuration(startedTime, sizeof(startedTime), GetTime() - info.startTime);
		FormatTimeDuration(playedTime, sizeof(playedTime), lastMapStartTime - info.startTime);

		PrintToConsole(client, "  %02d. %s : started %s ago : played %s", i + 1, info.mapName, startedTime, playedTime);
		lastMapStartTime = info.startTime;
	}
	
	return Plugin_Handled;
}

int FormatTimeDuration(char[] buffer, int maxlen, int time)
{
	int days = time / 86400;
	int hours = (time / 3600) % 24;
	int minutes = (time / 60) % 60;
	
	if (days)
	{
		return Format(buffer, maxlen, "%dd %dh %dm", days, hours, minutes);		
	}
	
	if (hours)
	{
		return Format(buffer, maxlen, "%dh %dm", hours, minutes);		
	}
	
	if (minutes)
	{
		return Format(buffer, maxlen, "%dm", minutes);		
	}
	
	return Format(buffer, maxlen, "%ds", time % 60);		
}

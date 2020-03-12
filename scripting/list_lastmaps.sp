#include <sourcemod>
#pragma newdecls required

public Plugin myinfo =
{
	name = "List Last Maps",
	author = "Ilusion9",
	description = "Informations about the last maps played.",
	version = "1.0",
	url = "https://github.com/Ilusion9/"
};

enum struct MapInfo
{
	char mapName[128];
	int startTime;
	int mapDuration;
}

ArrayList g_List_LastMaps;
ConVar g_Cvar_MaxLastMaps;

public void OnPluginStart()
{
	g_List_LastMaps = new ArrayList(sizeof(MapInfo));
	g_Cvar_MaxLastMaps = CreateConVar("sm_lastaps_maxsize", "15", "How many maps will be shown in the map history?", FCVAR_NONE, true, 0.0);

	RegConsoleCmd("sm_lastmaps", Command_LastMaps);
}

public void OnMapStart()
{
	g_List_LastMaps.Clear();
	
	MapInfo info;
	KeyValues kv = new KeyValues("Last Maps");
	
	if (kv.ImportFromFile("list_lastmaps.ini"))
	{
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				kv.GetString("name", info.mapName, sizeof(MapInfo::mapName), "");
				info.startTime = kv.GetNum("started", 0);
				info.mapDuration = kv.GetNum("duration", 0);
				g_List_LastMaps.PushArray(info);
				
			} while (kv.GotoNextKey(false));
		}
	}
	
	delete kv;
	if (g_List_LastMaps.Length > g_Cvar_MaxLastMaps.IntValue)
	{
		g_List_LastMaps.Resize(g_List_LastMaps.Length);
	}
}

public void OnMapEnd()
{
	MapInfo info;
	char key[128];
	
	GetCurrentMap(info.mapName, sizeof(MapInfo::mapName));
	info.mapDuration = RoundToZero(GetGameTime());
	info.startTime = GetTime() - info.mapDuration;
	
	KeyValues kv = new KeyValues("Last Maps");
	kv.JumpToKey("0", true);
	
	kv.SetString("name", info.mapName);
	kv.SetNum("started", info.startTime);
	kv.SetNum("duration", info.mapDuration);
	kv.GoBack();
	
	for (int i = 0; i < g_List_LastMaps.Length; i++)
	{
		g_List_LastMaps.GetArray(i, info);
		Format(key, sizeof(key), "%d", i + 1);
		kv.JumpToKey(key, true);
		
		kv.SetString("name", info.mapName);
		kv.SetNum("started", info.startTime);
		kv.SetNum("duration", info.mapDuration);
		kv.GoBack();
	}
	
	kv.Rewind();
	kv.ExportToFile("list_lastmaps.ini");
	delete kv;
}

public Action Command_LastMaps(int client, int args)
{
	if (GetCmdReplySource() == SM_REPLY_TO_CHAT)
	{
		PrintToChat(client, "See console for output.");
	}
	
	MapInfo info;
	char currentMap[128];
	
	GetCurrentMap(currentMap, sizeof(currentMap));
	PrintToConsole(client, "Last Maps:");
	PrintToConsole(client, " ");

	// Get max length for every column
	char buffer[64];
	int length, startLen, mapLen = strlen(currentMap) + 14;

	for (int i = 0; i < g_List_LastMaps.Length; i++)
	{
		g_List_LastMaps.GetArray(0, info);
		length = strlen(info.mapName);
		mapLen = length > mapLen ? length : mapLen;

		length = FormatTimeDuration(buffer, sizeof(buffer), info.startTime);
		startLen = length > startLen ? length : startLen;
	}
	
	// table columns
	char mapTitle[64] = "Map";
	char startTitle[64] = "Started";
	FillString(mapTitle, mapLen);
	FillString(startTitle, startLen);
	PrintToConsole(client, "#   %s   %s   Duration", mapTitle, startTitle);

	// show current map
	PrintToConsole(client, "00. %s (current map)", currentMap);
	
	char formatStart[128], formatDuration[128];	
	for (int i = 0; i < g_List_LastMaps.Length; i++)
	{
		g_List_LastMaps.GetArray(i, info);
		FillString(info.mapName, mapLen);
		
		FormatTimeDuration(formatStart, sizeof(formatStart), GetTime() - info.startTime);
		Format(formatStart, sizeof(formatStart), "%s ago", formatStart);
		FillString(formatStart, startLen);

		FormatTimeDuration(formatDuration, sizeof(formatDuration), info.mapDuration);
		PrintToConsole(client, "%02d. %s   %s   %s", i + 1, info.mapName, formatStart, formatDuration);
	}
	
	return Plugin_Handled;
}

// Fill string with "space" characters
void FillString(char[] buffer, int maxlen)
{
	int index, length = strlen(buffer);
	if (length >= maxlen)
	{
		return;
	}
	
	for (index = length; index < maxlen; index++)
	{
		buffer[index] = ' ';
	}
	buffer[index] = '\0';
}

// Transform unix time into "d h m" format type
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

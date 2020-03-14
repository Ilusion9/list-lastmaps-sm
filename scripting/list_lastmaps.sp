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

enum struct MapInfoDisplay
{
	char mapName[128];
	int mapLen;
	char startTime[64];
	int startLen;
	char mapDuration[64];
}

ArrayList g_List_LastMaps;
ConVar g_Cvar_MaxLastMaps;

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

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
		g_List_LastMaps.Resize(g_Cvar_MaxLastMaps.IntValue);
	}
}

public void OnAutoConfigsBuffered()
{	
	MapInfo info;	
	GetCurrentMap(info.mapName, sizeof(MapInfo::mapName));
	info.mapDuration = 0;
	info.startTime = GetTime();
	InsertMapsIntoFile(info);
}

public void OnMapEnd()
{
	MapInfo info;	
	GetCurrentMap(info.mapName, sizeof(MapInfo::mapName));
	info.mapDuration = RoundToZero(GetGameTime());
	info.startTime = GetTime() - info.mapDuration;
	InsertMapsIntoFile(info);
}

public Action Command_LastMaps(int client, int args)
{
	if (GetCmdReplySource() == SM_REPLY_TO_CHAT)
	{
		PrintToChat(client, "%t", "See console for output");
	}
	
	PrintToConsole(client, "Last Maps:");
	PrintToConsole(client, " ");

	MapInfo info;
	MapInfoDisplay[] infoDisplay = new MapInfoDisplay[g_List_LastMaps.Length];

	char mapTitle[sizeof(MapInfoDisplay::mapName)] = "Map";
	char startTitle[sizeof(MapInfoDisplay::startTime)] = "Started";
	char durationTitle[sizeof(MapInfoDisplay::mapDuration)] = "Duration";
	
	// Get current map
	char currentMap[128];
	GetCurrentMap(currentMap, sizeof(currentMap));
	
	// Get max lengths of every header column
	int maxFormatMapLen = strlen(currentMap) + 14;
	int maxFormatStartLen = 7;
	int currentTime = GetTime();
	
	for (int i = 0; i < g_List_LastMaps.Length; i++)
	{
		g_List_LastMaps.GetArray(i, info);
		
		// Build content columns
		infoDisplay[i].mapLen = Format(infoDisplay[i].mapName, sizeof(MapInfoDisplay::mapName), "%s", info.mapName);
		FormatTimeDuration(infoDisplay[i].startTime, sizeof(MapInfoDisplay::startTime), currentTime - info.startTime);
		
		infoDisplay[i].startLen = Format(infoDisplay[i].startTime, sizeof(MapInfoDisplay::startTime), "%s ago", infoDisplay[i].startTime);
		if (info.mapDuration)
		{
			FormatTimeDuration(infoDisplay[i].mapDuration, sizeof(MapInfoDisplay::mapDuration), info.mapDuration);
		}
		else
		{
			Format(infoDisplay[i].mapDuration, sizeof(MapInfoDisplay::mapDuration), "Not available");
		}
		
		// Get max lengths of every content column
		maxFormatMapLen = infoDisplay[i].mapLen > maxFormatMapLen ? infoDisplay[i].mapLen : maxFormatMapLen;
		maxFormatStartLen = infoDisplay[i].startLen > maxFormatStartLen ? infoDisplay[i].startLen : maxFormatStartLen;
	}
	
	// Print header columns
	FillString(mapTitle, sizeof(mapTitle), 3, maxFormatMapLen);
	FillString(startTitle, sizeof(startTitle), 7, maxFormatStartLen);
	PrintToConsole(client, "#   %s   %s   %s", mapTitle, startTitle, durationTitle);
	
	// Print current map
	PrintToConsole(client, "00. %s (current map)", currentMap);

	// Print content columns
	for (int i = 0; i < g_List_LastMaps.Length; i++)
	{
		FillString(infoDisplay[i].mapName, sizeof(MapInfoDisplay::mapName), infoDisplay[i].mapLen, maxFormatMapLen);
		FillString(infoDisplay[i].startTime, sizeof(MapInfoDisplay::startTime), infoDisplay[i].startLen, maxFormatStartLen);
		
		PrintToConsole(client, "%02d. %s   %s   %s", i + 1, infoDisplay[i].mapName, infoDisplay[i].startTime, infoDisplay[i].mapDuration);
	}
	
	return Plugin_Handled;
}

void InsertMapsIntoFile(MapInfo currentMap)
{
	MapInfo info;
	char buffer[128];
	KeyValues kv = new KeyValues("Last Maps");
	
	kv.JumpToKey("0", true);
	kv.SetString("name", currentMap.mapName);
	kv.SetNum("started", currentMap.startTime);
	kv.SetNum("duration", currentMap.mapDuration);
	kv.GoBack();
	
	for (int i = 0; i < g_List_LastMaps.Length; i++)
	{
		g_List_LastMaps.GetArray(i, info);
		Format(buffer, sizeof(buffer), "%d", i + 1);
		kv.JumpToKey(buffer, true);
		
		kv.SetString("name", info.mapName);
		kv.SetNum("started", info.startTime);
		kv.SetNum("duration", info.mapDuration);
		kv.GoBack();
	}
	
	kv.Rewind();
	kv.ExportToFile("list_lastmaps.ini");
	delete kv;
}

// Fill string with "space" characters
void FillString(char[] buffer, int maxsize, int start, int end)
{
	int index;
	if (start >= end || start >= maxsize)
	{
		return;
	}
	
	for (index = start; index < end && index < maxsize; index++)
	{
		buffer[index] = ' ';
	}
	buffer[end] = '\0';
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

#include <amxmodx>
#include <map_manager>

#define PLUGIN "Map Manager: Advanced lists"
#define VERSION "0.0.3"
#define AUTHOR "Mistrick"

#pragma semicolon 1

#define MAX_MAPLISTS 16

new const FILE_MAP_LISTS[] = "maplists.ini";

enum (+=100) {
	TASK_CHECK_LIST = 150
};

enum _:MapListInfo {
	AnyTime,
	StartTime,
	StopTime,
	ClearOldList,
	ListName[32],
	FileList[128]
};

new Array:g_aLists;
new Array:g_aActiveLists;
new Array:g_aMapLists[MAX_MAPLISTS];

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
}
public plugin_natives()
{
	register_library("map_manager_adv_lists");

	register_native("mapm_advl_get_active_lists", "native_get_active_lists");
	register_native("mapm_advl_get_list_name", "native_get_list_name");
	register_native("mapm_advl_get_list_array", "native_get_list_array");
}
public native_get_active_lists(plugin, params)
{
	return ArraySize(g_aActiveLists);
}
public native_get_list_name(plugin, params)
{
	enum {
		arg_item = 1,
		arg_list_name,
		arg_size
	};

	new item = ArrayGetCell(g_aActiveLists, get_param(arg_item));
	new list_info[MapListInfo];
	ArrayGetArray(g_aLists, item, list_info);
	set_string(arg_list_name, list_info[ListName], get_param(arg_size));
}
public native_get_list_array(plugin, params)
{
	enum {
		arg_item = 1
	};
	
	new item = ArrayGetCell(g_aActiveLists, get_param(arg_item));
	return _:g_aMapLists[item];
}
public plugin_cfg()
{
	new file_path[256]; get_localinfo("amxx_configsdir", file_path, charsmax(file_path));
	format(file_path, charsmax(file_path), "%s/%s", file_path, FILE_MAP_LISTS);

	if(!file_exists(file_path)) {
		set_fail_state("Maplists file doesn't exist.");
	}

	new f = fopen(file_path, "rt");
	
	if(!f) {
		set_fail_state("Can't read maplists file.");
	}

	// <name> <filename> <clear old list> <start> <stop>

	g_aLists = ArrayCreate(MapListInfo, 1);
	g_aActiveLists = ArrayCreate(1, 1);

	new list_info[MapListInfo];
	new text[256], name[32], start[8], stop[8], file_list[128], clr[4], i = 0;
	while(!feof(f)) {
		fgets(f, text, charsmax(text));
		trim(text);

		if(!text[0] || text[0] == ';') continue;

		parse(text, name, charsmax(name), file_list, charsmax(file_list), clr, charsmax(clr), start, charsmax(start), stop, charsmax(stop));

		copy(list_info[ListName], charsmax(list_info[ListName]), name);
		copy(list_info[FileList], charsmax(list_info[FileList]), file_list);
		list_info[ClearOldList] = str_to_num(clr);

		if(!start[0] || equal(start, "anytime")) {
			list_info[AnyTime] = true;
		} else {
			list_info[StartTime] = get_int_time(start);
			list_info[StopTime] = get_int_time(stop);
		}

		ArrayPushArray(g_aLists, list_info);

		// load maps from file to local list
		g_aMapLists[i] = ArrayCreate(MapStruct, 1);
		mapm_load_maplist_to_array(g_aMapLists[i], list_info[FileList]);
		i++;

		list_info[AnyTime] = false;
		list_info[StartTime] = 25 * 60;
		list_info[StopTime] = -1;
	}
	fclose(f);

	if(!ArraySize(g_aLists)) {
		// pause plugin?
		log_amx("nothing loaded.");
	} else {
		task_check_list();
		set_task(60.0, "task_check_list", TASK_CHECK_LIST, .flags = "b");
	}
}
public task_check_list()
{
	new hours, mins; time(hours, mins);
	new cur_time = hours * 60 + mins;

	new list_info[MapListInfo];

	new Array:temp = ArrayCreate(1, 1);

	for(new i, found_newlist, size = ArraySize(g_aLists); i < size; i++) {
		ArrayGetArray(g_aLists, i, list_info);

		if(list_info[AnyTime]) {
			found_newlist = true;
		} else if(list_info[StartTime] <= list_info[StopTime]) {
			if(list_info[StartTime] <= cur_time <= list_info[StopTime]) {
				found_newlist = true;
			}
		} else {
			if(list_info[StartTime] <= cur_time <= 24 * 60 || cur_time <= list_info[StopTime]) {
				found_newlist = true;
			}
		}

		if(found_newlist) {
			found_newlist = false;
			if(list_info[ClearOldList]) {
				ArrayClear(temp);
			}
			ArrayPushCell(temp, i);
		}
	}

	new reload = false;

	if(ArraySize(g_aActiveLists) != ArraySize(temp)) {
		reload = true;
	} else {
		for(new i, size = ArraySize(g_aActiveLists); i < size; i++) {
			if(ArrayGetCell(g_aActiveLists, i) != ArrayGetCell(temp, i)) {
				reload = true;
				break;
			}
		}
	}

	if(reload) {
		ArrayDestroy(g_aActiveLists);
		g_aActiveLists = temp;
		for(new i, item, size = ArraySize(g_aActiveLists); i < size; i++) {
			item = ArrayGetCell(g_aActiveLists, i);
			ArrayGetArray(g_aLists, item, list_info);
			mapm_load_maplist(list_info[FileList], list_info[ClearOldList]);
			log_amx("loaded new maplist[%s]", list_info[FileList]);
		}
	}
}
get_int_time(string[])
{
	new left[4], right[4]; strtok(string, left, charsmax(left), right, charsmax(right), ':');
	return str_to_num(left) * 60 + str_to_num(right);
}
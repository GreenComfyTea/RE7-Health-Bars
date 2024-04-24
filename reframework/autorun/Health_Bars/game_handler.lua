local this = {};

local singletons;
local error_handler;

local sdk = sdk;
local tostring = tostring;
local pairs = pairs;
local ipairs = ipairs;
local tonumber = tonumber;
local require = require;
local pcall = pcall;
local table = table;
local string = string;
local Vector3f = Vector3f;
local d2d = d2d;
local math = math;
local json = json;
local log = log;
local fs = fs;
local next = next;
local type = type;
local setmetatable = setmetatable;
local getmetatable = getmetatable;
local assert = assert;
local select = select;
local coroutine = coroutine;
local utf8 = utf8;
local re = re;
local imgui = imgui;
local draw = draw;
local Vector2f = Vector2f;
local reframework = reframework;
local os = os;

this.game = {};
this.game.is_paused = false;
this.game.is_menu_opened = false;
this.game.is_cutscene_playing = false;

local is_initialized = false;

local game_manager_type_def = sdk.find_type_definition("app.GameManager");
local request_event_method = game_manager_type_def:get_method("requestEvent");
local pause_manager_field = game_manager_type_def:get_field("PauseManager");
local game_event_man_field = game_manager_type_def:get_field("_GameEventMan");

local pause_manager_type_def = pause_manager_field:get_type();
local get_is_pause_method = pause_manager_type_def:get_method("get_isPause");
local exec_method = pause_manager_type_def:get_method("exec");

local game_event_manager_type_def = game_event_man_field:get_type();
local running_event_controllers_field = game_event_manager_type_def:get_field("RunningEventControllers");

local running_event_controllers_list = running_event_controllers_field:get_type();
local running_event_controllers_list_get_count_method = running_event_controllers_list:get_method("get_Count");

local menu_manager_type_def = sdk.find_type_definition("app.MenuManager");
local is_exist_stack_open_menu_method = menu_manager_type_def:get_method("isExistStackOpenMenu");

function this.update()
	this.update_is_cutscene();
	this.update_is_menu_opened();
end

function this.update_is_cutscene()
	if is_initialized and not this.game.is_cutscene_playing then
		return;
	end

	local game_manager = singletons.game_manager;
	if game_manager == nil then
		error_handler.report("game_handler.update_is_cutscene", "No GameManager");
		return;
	end

	local game_event_manager = game_event_man_field:get_data(game_manager);
	if game_event_manager == nil then
		error_handler.report("game_handler.update_is_cutscene", "No GameEventManager");
		return;
	end

	local running_event_controllers = running_event_controllers_field:get_data(game_event_manager);
	if running_event_controllers == nil then
		error_handler.report("game_handler.update_is_cutscene", "No RunningEventControllers");
		return;
	end

	local count = running_event_controllers_list_get_count_method:call(running_event_controllers);
	if count == nil then
		error_handler.report("game_handler.update_is_cutscene", "No RunningEventControllers -> Count");
		return;
	end

	this.game.is_cutscene_playing = count ~= 0;
end

function this.update_is_menu_opened()
	local menu_manager = singletons.menu_manager;
	if menu_manager == nil then
		error_handler.report("game_handler.update_is_menu_opened", "No MenuManager");
		return;
	end

	local is_exist_stack_open_menu =  is_exist_stack_open_menu_method:call(menu_manager);
	if is_exist_stack_open_menu == nil then
		error_handler.report("game_handler.update_is_menu_opened", "No IsExistStackOpenMenu");
		return;
	end

	this.game.is_menu_opened = is_exist_stack_open_menu;
end

function this.init()
	local game_manager = singletons.game_manager;
	if game_manager == nil then
		error_handler.report("game_handler.init", "No GameManager");
		return;
	end

	local pause_manager = pause_manager_field:get_data(game_manager);
	if pause_manager == nil then
		error_handler.report("game_handler.init", "No PauseManager");
		return;
	end

	local is_pause = get_is_pause_method:call(pause_manager);
	if is_pause == nil then
		error_handler.report("game_handler.init", "No IsPause");
		return;
	end

	this.game.is_paused = is_pause;

	this.update_is_cutscene();

	is_initialized = true;
end

function this.on_exec(is_request_pause)
	if is_request_pause == nil then
		error_handler.report("game_handler.on_exec", "No IsRequestPause");
		return;
	end

	this.game.is_paused = is_request_pause;
end

function this.on_request_event()
	this.game.is_cutscene_playing = true;
end

function this.init_module()
	singletons = require("Health_Bars.singletons");
	error_handler = require("Health_Bars.error_handler");

	this.init();

	sdk.hook(exec_method, function(args)
		local is_request_pause = (sdk.to_int64(args[3]) & 1) == 1;
		this.on_exec(is_request_pause);

	end, function(retval)
		return retval;
	end);

	sdk.hook(request_event_method, function(args)
		this.on_request_event();

	end, function(retval)
		return retval;
	end);
end

return this;
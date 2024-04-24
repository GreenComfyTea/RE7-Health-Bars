local this = {};

local utils;
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

this.player = {};
this.player.position = Vector3f.new(0, 0, 0);
this.player.is_aiming = false;
this.player.is_guarding = false;
this.player.aim_target = nil;

local interact_manager_type_def = sdk.find_type_definition("app.InteractManager");
local interact_player_status_field = interact_manager_type_def:get_field("_PlayerStatus");

local player_status_type_def = sdk.find_type_definition("app.PlayerStatus");
local player_camera_field = player_status_type_def:get_field("PlayerCamera");

local player_camera_type_def = player_camera_field:get_type();
local get_camera_position_method = player_camera_type_def:get_method("get_CameraPosition");
local look_target_hit_result_field = player_camera_type_def:get_field("LookTargetHitResult");

local hit_result_type_def = look_target_hit_result_field:get_type();
local game_object_field = hit_result_type_def:get_field("GameObject");

local inventory_manager_type_def = sdk.find_type_definition("app.InventoryManager");
local inventory_field = inventory_manager_type_def:get_field("_Inventory");

local inventory_type_def = inventory_field:get_type();
local player_status_field = inventory_type_def:get_field("PlayerStatus");

local player_status_type_def = sdk.find_type_definition("app.PlayerStatus");
local get_is_aim_method = player_status_type_def:get_method("get_IsAim");
local get_is_guard_method = player_status_type_def:get_method("get_isGuard");

function this.tick()
	this.update_position();
end

function this.update()
	local inventory_manager = singletons.inventory_manager;
	if inventory_manager == nil then
		error_handler.report("player_handler.update", "No InventoryManager");
		return;
	end

	local inventory = inventory_field:get_data(inventory_manager);
	if inventory == nil then
		return;
	end

	local player_status = player_status_field:get_data(inventory);
	if player_status == nil then
		-- error_handler.report("player_handler.update", "No PlayerStatus");
		return;
	end

	this.update_is_aiming(player_status);
	this.update_is_guarding(player_status);
	this.update_aim_target();
end

function this.update_position()
	local interact_manager = singletons.interact_manager;
	if interact_manager == nil then
		error_handler.report("player_handler.update_position", "No InteractManager");
		return;
	end

	local player_status = interact_player_status_field:get_data(interact_manager);
	if player_status == nil then
		error_handler.report("player_handler.update_position", "No PlayerStatus");
		return;
	end

	local player_camera = player_camera_field:get_data(player_status);
	if player_camera == nil then
		-- error_handler.report("player_handler.update_position", "No PlayerCamera");
		return;
	end

	local position = get_camera_position_method:call(player_camera);
	if position == nil then
		error_handler.report("player_handler.update_position", "No Position");
		return;
	end

	this.player.position = position;
end

function this.update_is_aiming(player_status)
	local is_aim = get_is_aim_method:call(player_status);
	if is_aim == nil then
		error_handler.report("player_handler.update_is_aiming", "No IsAim");
		return;
	end

	this.player.is_aiming = is_aim;
end

function this.update_is_guarding(player_status)
	local is_guard = get_is_guard_method:call(player_status);
	if is_guard == nil then
		error_handler.report("player_handler.update_is_guarding", "No IsGuard");
		return;
	end

	this.player.is_guarding = is_guard;
end

function this.update_aim_target()
	local interact_manager = singletons.interact_manager;
	if interact_manager == nil then
		error_handler.report("player_handler.update_aim_target", "No InteractManager");
		return;
	end

	local player_status = interact_player_status_field:get_data(interact_manager);
	if player_status == nil then
		error_handler.report("player_handler.update_aim_target", "No PlayerStatus");
		return;
	end

	local player_camera = player_camera_field:get_data(player_status);
	if player_camera == nil then
		error_handler.report("player_handler.update_aim_target", "No PlayerCamera");
		return;
	end

	local look_target_hit_result = look_target_hit_result_field:get_data(player_camera);
	if look_target_hit_result == nil then
		error_handler.report("player_handler.update_aim_target", "No LookTargetHitResult");
		return;
	end

	local game_object = game_object_field:get_data(look_target_hit_result);
	if game_object == nil then
		error_handler.report("player_handler.update_aim_target", "No GameObject");
		return;
	end

	this.player.aim_target = game_object;
end

function this.init_module()
	utils = require("Health_Bars.utils");
	singletons = require("Health_Bars.singletons");
	error_handler = require("Health_Bars.error_handler");
end

return this;
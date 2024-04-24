local this = {};

local customization_menu;
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

local game_manager_name = "app.GameManager";
local inventory_manager_name = "app.InventoryManager";
local interact_manager_name = "app.InteractManager";
local menu_manager_name = "app.MenuManager";

this.game_manager = nil;
this.inventory_manager = nil;
this.interact_manager = nil;
this.menu_manager = nil;

function this.update()
	this.update_game_manager();
	this.update_inventory_manager();
	this.update_interact_manager();
	this.update_menu_manager();
end

function this.update_game_manager()
	this.game_manager = sdk.get_managed_singleton(game_manager_name);
	if this.game_manager == nil then
		error_handler.report("[singletons.update_player_manager] No GameManager");
	end

	return this.game_manager;
end

function this.update_inventory_manager()
	this.inventory_manager = sdk.get_managed_singleton(inventory_manager_name);
	if this.inventory_manager == nil then
		error_handler.report("[singletons.update_inventory_manager] No InventoryManager");
	end

	return this.inventory_manager;
end

function this.update_interact_manager()
	this.interact_manager = sdk.get_managed_singleton(interact_manager_name);
	if this.interact_manager == nil then
		error_handler.report("[singletons.update_interact_manager] No InteractManager");
	end

	return this.interact_manager;
end

function this.update_menu_manager()
	this.menu_manager = sdk.get_managed_singleton(menu_manager_name);
	if this.menu_manager == nil then
		error_handler.report("[singletons.update_menu_manager] No MenuManager");
	end

	return this.menu_manager;
end

local menu_manager = sdk.get_managed_singleton("app.MenuManager");

function this.init_module()
	customization_menu = require("Health_Bars.customization_menu");
	error_handler = require("Health_Bars.error_handler");

	this.update();
end

return this;

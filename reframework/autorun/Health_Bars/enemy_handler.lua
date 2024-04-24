local this = {};

local utils;
local singletons;
local config;
local drawing;
local customization_menu;
local player_handler;
local game_handler;
local time;
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

this.enemy_list = {};
this.enemy_game_object_list = {};

local disable_is_in_sight_delay_seconds = 5;
local health_update_delay_seconds = 1;

local health_update_timer = nil;

local enemy_action_controller_type_def = sdk.find_type_definition("app.EnemyActionController");
local do_update_method = enemy_action_controller_type_def:get_method("doUpdate");
local do_on_destroy_method = enemy_action_controller_type_def:get_method("doOnDestroy");
local on_give_damage_method = enemy_action_controller_type_def:get_method("giveDamage");
local get_enemy_damage_controller_method = enemy_action_controller_type_def:get_method("get_enemyDamageController");
local get_game_object_method = enemy_action_controller_type_def:get_method("get_GameObject");
local get_is_in_camera_method = enemy_action_controller_type_def:get_method("get_isInCameraLive");
local on_dead_for_stats_method = enemy_action_controller_type_def:get_method("onDeadForStats");
local spawn_method = enemy_action_controller_type_def:get_method("spawn");
local give_die_method = enemy_action_controller_type_def:get_method("giveDie");
local finish_dead_method = enemy_action_controller_type_def:get_method("finishDead");

local enemy_damage_controller_type_def = get_enemy_damage_controller_method:get_return_type();
local get_health_info_method = enemy_damage_controller_type_def:get_method("getHealthInfo");

local health_info_type_def = get_health_info_method:get_return_type();
local get_health_method = health_info_type_def:get_method("get_health");
local get_max_health_method = health_info_type_def:get_method("get_maxHealth");

local game_object_type_def = get_game_object_method:get_return_type();
local get_transform_method = game_object_type_def:get_method("get_Transform");

local transform_type_def = get_transform_method:get_return_type();
local get_joint_by_name_method = transform_type_def:get_method("getJointByName");

local joint_type_def = get_joint_by_name_method:get_return_type();
local get_position_method = joint_type_def:get_method("get_Position");

-- Mia Attic Boss Fight
local em_2000_action_controller_type_def = sdk.find_type_definition("app.Em2000.Em2000ActionController")
local generate_action_cancel_value_method = em_2000_action_controller_type_def:get_method("generateActionCancelValue");

function this.new(enemy_action_controller)
	local enemy = {};
	enemy.enemy_action_controller = enemy_action_controller;

	enemy.game_object = nil;

	enemy.health = -1;
	enemy.max_health = -100;
	enemy.health_percentage = 0;
	enemy.is_dead = false;

	enemy.head_joint = nil;
	enemy.position = Vector3f.new(0, 0, 0);
	enemy.distance = 0;

	enemy.is_in_sight = false;
	enemy.disable_is_in_sight_timer = nil;
	
	enemy.last_reset_time = 0;
	enemy.last_update_time = 0;

	this.update_health(enemy);

	if enemy.health == -1 or enemy.max_health == -1 then
		return nil;
	end

	this.update_game_object(enemy);
	this.update_head_joint(enemy);
	this.update_position(enemy);

	this.enemy_list[enemy_action_controller] = enemy;
	
	return enemy;
end

function this.get_enemy(enemy_action_controller)
	local enemy = this.enemy_list[enemy_action_controller];
	if enemy == nil then
		enemy = this.new(enemy_action_controller);
	end

	return enemy;
end

function this.get_enemy_null(enemy_action_controller, create_if_not_found)
	if create_if_not_found == nil then
		create_if_not_found = true;
	end

	local enemy = this.enemy_list[enemy_action_controller];
	if enemy == nil and create_if_not_found then
		enemy = this.new(enemy_action_controller);
	end

	return enemy;
end

function this.update()
	for enemy_action_controller, enemy in pairs(this.enemy_list) do
		this.update_is_in_sight(enemy);
	end
end

function this.update_all_health()
	for enemy_action_controller, enemy in pairs(this.enemy_list) do
		this.update_health(enemy);
	end
end

function this.update_health(enemy)
	local enemy_damage_controller = get_enemy_damage_controller_method:call(enemy.enemy_action_controller);
	if enemy_damage_controller == nil then
		error_handler.report("enemy_handler.update_health", "No EnemyDamageController");
		return;
	end

	local health_info = get_health_info_method:call(enemy_damage_controller);
	if health_info == nil then
		error_handler.report("enemy_handler.update_health", "No HealthInfo");
		return;
	end

	local health = get_health_method:call(health_info);
	local max_health = get_max_health_method:call(health_info);

	if health == nil then
		error_handler.report("enemy_handler.update_health", "No Health");
	else
		enemy.health = utils.math.round(health);
	end

	if max_health == nil then
		error_handler.report("enemy_handler.update_health", "No MaxHealth");
	else
		enemy.max_health = utils.math.round(max_health);
	end

	if enemy.max_health == 0 then
		enemy.health_percentage = 0;
	else
		enemy.health_percentage = enemy.health / enemy.max_health;
	end

	enemy.is_dead = utils.number.is_equal(enemy.health, 0);
end

function this.update_is_in_sight(enemy)
	local is_in_camera_live = get_is_in_camera_method:call(enemy.enemy_action_controller);
	if is_in_camera_live == nil then
		error_handler.report("enemy_handler.update_is_in_sight", "No IsInCameraLive");
		return;
	end

	if is_in_camera_live then
		enemy.is_in_sight = true;
		return;
	end

	if enemy.disable_is_in_sight_timer == nil then
		enemy.disable_is_in_sight_timer = time.new_delay_timer(function()
			enemy.is_in_sight = false;
			enemy.disable_is_in_sight_timer = nil;
		end, disable_is_in_sight_delay_seconds);

		return;
	end
end

function this.update_game_object(enemy)
	local enemy_game_object = get_game_object_method:call(enemy.enemy_action_controller);
	if enemy_game_object == nil then
		error_handler.report("enemy_handler.update_game_object", "No GameObject");
		return;
	end

	enemy.game_object = enemy_game_object;
	this.enemy_game_object_list[enemy_game_object] = enemy;
end

function this.update_head_joint(enemy)
	if enemy.game_object == nil then
		error_handler.report("enemy_handler.update_head_joint", "No GameObject");
		return;
	end

	local enemy_transform = get_transform_method:call(enemy.game_object);
	if enemy_transform == nil then
		error_handler.report("enemy_handler.update_head_joint", "No Transform");
		return;
	end

	local joint = get_joint_by_name_method:call(enemy_transform, "head")
	or get_joint_by_name_method:call(enemy_transform, "Head")
	or get_joint_by_name_method:call(enemy_transform, "_10") -- Bugs on cabinet
	or get_joint_by_name_method:call(enemy_transform, "root");

	if joint == nil then
		error_handler.report("enemy_handler.update_head_joint", "No Head Joint");
		return;
	end

	enemy.head_joint = joint;
end

function this.update_last_reset_time(enemy)
	enemy.last_reset_time = time.total_elapsed_script_seconds;
end

function this.tick()
	this.update_all_positions();
end

function this.update_all_positions()
	for enemy_action_controller, enemy in pairs(this.enemy_list) do
		this.update_position(enemy);
	end
end

function this.update_position(enemy)
	if(enemy.head_joint == nil) then
		error_handler.report("enemy_handler.update_position", "No Head Joint");
		return;
	end

	local head_joint_position = get_position_method:call(enemy.head_joint);
	if head_joint_position == nil then
		error_handler.report("enemy_handler.update_position", "No Head Joint Position");
		return;
	end

	enemy.position = head_joint_position;
	enemy.distance = (player_handler.player.position - head_joint_position):length();

	-- this.update_health(enemy);
end

function this.draw_enemies()
	local cached_config = config.current_config;
	local cached_settings_config = cached_config.settings;
	local cached_world_offset_config = cached_config.world_offset;

	if not cached_settings_config.render_during_cutscenes and game_handler.game.is_cutscene_playing then
		return;
	end

	if not cached_settings_config.render_when_game_timer_is_paused and game_handler.game.is_paused then
		return;
	end

	if not cached_settings_config.render_when_any_menu_is_opened and game_handler.game.is_menu_opened then
		return;
	end

	if player_handler.player.is_aiming then
		if not cached_settings_config.render_when_aiming then
			return;
		end
	elseif player_handler.player.is_guarding then
		if not cached_settings_config.render_when_guarding then
			return;
		end
	elseif not cached_settings_config.render_when_normal then
		return;
	end

	local max_distance = cached_settings_config.max_distance;

	for enemy_action_controller, enemy in pairs(this.enemy_list) do
		if max_distance ~= 0 and enemy.distance > max_distance then
			goto continue;
		end

		if enemy.max_health <= 1 then
			goto continue;
		end

		if enemy.position.x == 0 and enemy.position.y == 0 and enemy.position.z == 0 then
			goto continue;
		end

		local is_time_duration_on = false;

		if cached_settings_config.apply_time_duration_on_aiming
		or cached_settings_config.apply_time_duration_on_aim_target
		or cached_settings_config.apply_time_duration_on_damage_dealt then
			if cached_settings_config.time_duration ~= 0 then
				if time.total_elapsed_script_seconds - enemy.last_reset_time > cached_settings_config.time_duration then
					goto continue;
				else
					is_time_duration_on = true;
				end
			end
		end

		if not cached_settings_config.render_aim_target_enemy
		and enemy.game_object == player_handler.player.aim_target
		and not is_time_duration_on then
			goto continue;
		end

		if not cached_settings_config.render_damaged_enemies
		and not utils.number.is_equal(enemy.health, enemy.max_health)
		and not is_time_duration_on then
			if enemy.game_object == player_handler.player.aim_target then
				if not cached_settings_config.render_aim_target_enemy then
					goto continue;
				end
			else
				goto continue;
			end
		end

		if not cached_settings_config.render_everyone_else
		and enemy.game_object ~= player_handler.player.aim_target
		and utils.number.is_equal(enemy.health, enemy.max_health)
		and not is_time_duration_on then
			goto continue;
		end

		if cached_settings_config.hide_if_dead
		and enemy.is_dead then
			goto continue;
		end

		if cached_settings_config.hide_if_full_health
		and utils.number.is_equal(enemy.health, enemy.max_health) then
			goto continue;
		end

		if cached_settings_config.hide_if_enemy_is_not_in_sight
		and not enemy.is_in_sight then
			goto continue;
		end

		local world_offset = Vector3f.new(cached_world_offset_config.x, cached_world_offset_config.y, cached_world_offset_config.z);

		local position_on_screen = draw.world_to_screen(enemy.position + world_offset);
		if position_on_screen == nil then
			goto continue;
		end

		local opacity_scale = 1;
		if cached_settings_config.opacity_falloff and max_distance ~= 0 then
			opacity_scale = 1 - (enemy.distance / max_distance);
		end

		local health_value_text = "";

		local health_value_label = cached_config.health_value_label;
		local health_value_include = health_value_label.include;
		local right_alignment_shift = health_value_label.settings.right_alignment_shift;

		if health_value_include.current_value then
			health_value_text = string.format("%.0f", enemy.health);

			if health_value_include.max_value then
				health_value_text = string.format("%s/%.0f", health_value_text, enemy.max_health);
			end
		elseif health_value_include.max_value then
			health_value_text = string.format("%.0f", enemy.max_health);
		end

		if right_alignment_shift ~= 0 then
			local right_aligment_format = string.format("%%%ds", right_alignment_shift);
			health_value_text = string.format(right_aligment_format, health_value_text);
		end

		drawing.draw_bar(cached_config.health_bar, position_on_screen, opacity_scale, enemy.health_percentage);
		drawing.draw_label(health_value_label, position_on_screen, opacity_scale, health_value_text);
		
		::continue::
	end
end

function this.on_update(enemy_action_controller)
	local enemy = this.get_enemy(enemy_action_controller);
end

function this.on_destroy(enemy_action_controller)
	local enemy = this.get_enemy(enemy_action_controller);
	if enemy == nil then
		return;
	end

	this.enemy_game_object_list[enemy.game_object] = nil;
	this.enemy_list[enemy_action_controller] = nil;
end

function this.on_damage(enemy_action_controller)
	local enemy = this.get_enemy(enemy_action_controller);
	if enemy == nil then
		return;
	end

	this.update_health(enemy);
	this.on_damage_or_die(enemy)

	enemy.is_in_sight = true;

	time.remove_delay_timer(enemy.disable_is_in_sight_timer);
	enemy.disable_is_in_sight_timer = nil;
end

function this.on_die(enemy_action_controller)
	local enemy = this.get_enemy(enemy_action_controller);
	if enemy == nil then
		return;
	end

	this.update_health(enemy);
	enemy.is_dead = true;
	this.on_damage_or_die(enemy);
end

function this.on_damage_or_die(attacked_enemy)
	local cached_config = config.current_config.settings;

	if cached_config.reset_time_duration_on_damage_dealt_for_everyone then
		for enemy_action_controller, enemy in pairs(this.enemy_list) do
			if time.total_elapsed_script_seconds - enemy.last_reset_time < cached_config.time_duration then
				this.update_last_reset_time(enemy);
			end
		end
	end

	if cached_config.apply_time_duration_on_damage_dealt then
		this.update_last_reset_time(attacked_enemy);
	end
end

function this.init_module()
	utils = require("Health_Bars.utils");
	config = require("Health_Bars.config");
	singletons = require("Health_Bars.singletons");
	drawing = require("Health_Bars.drawing");
	customization_menu = require("Health_Bars.customization_menu");
	player_handler = require("Health_Bars.player_handler");
	game_handler = require("Health_Bars.game_handler");
	time = require("Health_Bars.time");
	error_handler = require("Health_Bars.error_handler");

	health_update_timer = time.new_timer(function ()
		this.update_all_health();
	end, health_update_delay_seconds, 0);

	sdk.hook(do_update_method, function(args)
		local enemy_action_controller = sdk.to_managed_object(args[2]);
		this.on_update(enemy_action_controller);

	end, function(retval)
		return retval;
	end);

	sdk.hook(generate_action_cancel_value_method, function(args)
		local enemy_action_controller = sdk.to_managed_object(args[2]);
		this.on_damage(enemy_action_controller);

	end, function(retval)
		return retval;
	end);

	sdk.hook(on_give_damage_method, function(args)
		local enemy_action_controller = sdk.to_managed_object(args[2]);

		this.on_damage(enemy_action_controller);

	end, function(retval)
		return retval;
	end);

	sdk.hook(do_on_destroy_method, function(args)
		local enemy_action_controller = sdk.to_managed_object(args[2]);
		this.on_destroy(enemy_action_controller);

	end, function(retval)
		return retval;
	end);

	sdk.hook(on_dead_for_stats_method, function(args)
		local enemy_action_controller = sdk.to_managed_object(args[2]);
		this.on_die(enemy_action_controller);

	end, function(retval)
		return retval;
	end);

	sdk.hook(spawn_method, function(args)
		local enemy_action_controller = sdk.to_managed_object(args[2]);
		this.on_update(enemy_action_controller);

	end, function(retval)
		return retval;
	end);

	sdk.hook(finish_dead_method, function(args)
		local enemy_action_controller = sdk.to_managed_object(args[2]);
		this.on_die(enemy_action_controller);

	end, function(retval)
		return retval;
	end);

	sdk.hook(give_die_method, function(args)
		local enemy_action_controller = sdk.to_managed_object(args[2]);
		this.on_die(enemy_action_controller);

	end, function(retval)
		return retval;
	end);
end

return this;
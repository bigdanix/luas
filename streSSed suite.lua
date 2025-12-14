-- made by d_nielo

--// streSSed | MASTER SUITE V4.7 (ADAPTIVE PREDICTION & LOD FIX) //--
local global_tag = "STRESSED_MASTER_V4_7"
local run_service = game:GetService("RunService")
local players = game:GetService("Players")
local workspace = game:GetService("Workspace")
local replicated_storage = game:GetService("ReplicatedStorage")
local camera = workspace.CurrentCamera
local local_player = players.LocalPlayer
local user_input_service = game:GetService("UserInputService")
local debris = game:GetService("Debris")

--// 1. CLEANUP \\--
pcall(function() run_service:UnbindFromRenderStep("plinian_loop") end)
pcall(function() run_service:UnbindFromRenderStep("plinian_thirdperson") end)
pcall(function() run_service:UnbindFromRenderStep("plinian_misc") end)
pcall(function() run_service:UnbindFromRenderStep("plinian_antiaim") end)
pcall(function() if local_player.Character and local_player.Character:FindFirstChild("Humanoid") then local_player.Character.Humanoid.AutoRotate = true end end)

if getgenv()[global_tag] then
    for _, v in pairs(getgenv()[global_tag]) do
        if v.Remove then v:Remove()
        elseif v.Destroy then v:Destroy()
        end
    end
end
getgenv()[global_tag] = {}
local cache = getgenv()[global_tag]

--// 2. CONFIGURATION \\--

local aim_settings = {
    fire_point_override = "Character",
    enabled = true,
    hitpart = "Head",
    hitchance = 100,
    visible_check = true, 
    triggerbot = { enabled = true, delay = 0, weapon_check = true, visible_check = true },
    target_highlight = { enabled = true, color = Color3.fromRGB(255, 0, 0) },
    tracers = { enabled = true, image = "rbxassetid://3517446796", color = Color3.fromRGB(255, 255, 255), width = 0.5, duration = 1 },
    fov = { radius = 150, sides = 60, thickness = 1, target_highlight = true, target_highlight_color = Color3.fromRGB(255, 0, 0), main = { enabled = true, color = Color3.fromRGB(255, 255, 255), transparency = 1 }, outline = { enabled = true, color = Color3.fromRGB(0, 0, 0), transparency = 1 }, fill = { enabled = false, color = Color3.fromRGB(255, 255, 255), transparency = 0.25 } },
    snapline = { enabled = true, color = Color3.fromRGB(255, 255, 255), thickness = 1, origin = "cursor" },
    prediction = {
        enabled = true,
        adaptable = true, -- If true, uses scaling based on distance.
        base_factor = 0.12, -- The prediction factor at close range.
        scaling_per_stud = 0.0001 -- How much to increase the factor per stud of distance.
    }
}

local esp_settings = {
    master_switch = true,
    ignore_lobby_players = true,
    lod_enabled = true,
    lod_distance = 150,
    max_distance = { enabled = true, limit = 2500 },
    text = { size = 13, font = 2 },
    box = { enabled = true, type = "Full", color = Color3.fromRGB(255, 255, 255), fill = { enabled = true, color = Color3.fromRGB(255, 255, 255), transparency = 0.25 } },
    skeleton = { enabled = true, color = Color3.fromRGB(255, 255, 255), thickness = 1 },
    head_dot = { enabled = true, color = Color3.fromRGB(255, 255, 255), radius = 3, filled = true },
    view_tracer = { enabled = true, color = Color3.fromRGB(255, 255, 255), thickness = 1, length = 6 },
    names = { enabled = true, color = Color3.fromRGB(255, 255, 255) },
    health = { enabled = true, low_color = Color3.fromRGB(255, 0, 0), high_color = Color3.fromRGB(0, 255, 0), text = true, text_color = Color3.fromRGB(255, 255, 255) },
    distance = { enabled = true, color = Color3.fromRGB(255, 255, 255) },
    tool = { enabled = true, color = Color3.fromRGB(255, 255, 255) },
    chams = { enabled = true, color = Color3.fromRGB(255, 255, 255), transparency = 0.6 }
}

local thirdperson_settings = { enabled = true, keybind = Enum.KeyCode.E, distance = 8 }
local misc_settings = { no_animations = { enabled = false } }
local anti_aim_settings = { enabled = false, mode = "Static", yaw_offset = 180, spin_speed = 5, jitter_offset = 45, jitter_speed = 10, sway_angle = 30, sway_speed = 5 }

--// 3. HELPERS \\--
local function new_drawing(type, props) local d = Drawing.new(type); for k,v in pairs(props) do d[k]=v end; table.insert(cache, d); return d end
local function track(obj) table.insert(cache, obj); return obj end
local function spawn_tracer(origin, end_pos) local att0=Instance.new("Attachment"); local att1=Instance.new("Attachment"); att0.Position=origin; att1.Position=end_pos; att0.Parent=workspace.Terrain; att1.Parent=workspace.Terrain; local beam=Instance.new("Beam"); beam.Texture=aim_settings.tracers.image; beam.Color=ColorSequence.new(aim_settings.tracers.color); beam.FaceCamera=true; beam.Width0=aim_settings.tracers.width; beam.Width1=aim_settings.tracers.width; beam.LightEmission=1; beam.LightInfluence=0; beam.Attachment0=att0; beam.Attachment1=att1; beam.Parent=workspace.Terrain; track(att0); track(att1); track(beam); debris:AddItem(att0,aim_settings.tracers.duration); debris:AddItem(att1,aim_settings.tracers.duration); debris:AddItem(beam,aim_settings.tracers.duration) end

--// 4. AIM VISUALS \\--
local fov_fill = new_drawing("Circle", {Visible=false,Filled=true}); local fov_outline = new_drawing("Circle", {Visible=false,Filled=false}); local fov_main = new_drawing("Circle", {Visible=false,Filled=false}); local snap_line = new_drawing("Line", {Visible=false})

--// 5. ESP LOGIC \\--
local esp_database = {}; local function init_esp(player, char) if esp_database[player] then return end; local obj={Drawings={},Chams={}, Character=char, LastPosition=nil, LastTick=0, Velocity=Vector3.new()}; obj.Drawings.BoxOutline=new_drawing("Square",{Visible=false,Thickness=3,Color=Color3.new(0,0,0),Filled=false}); obj.Drawings.Box=new_drawing("Square",{Visible=false,Thickness=1,Filled=false}); obj.Drawings.Fill=new_drawing("Square",{Visible=false,Filled=true,Transparency=esp_settings.box.fill.transparency}); obj.Drawings.C1=new_drawing("Line",{Visible=false,Thickness=1}); obj.Drawings.C2=new_drawing("Line",{Visible=false,Thickness=1}); obj.Drawings.C3=new_drawing("Line",{Visible=false,Thickness=1}); obj.Drawings.C4=new_drawing("Line",{Visible=false,Thickness=1}); obj.Drawings.C5=new_drawing("Line",{Visible=false,Thickness=1}); obj.Drawings.C6=new_drawing("Line",{Visible=false,Thickness=1}); obj.Drawings.C7=new_drawing("Line",{Visible=false,Thickness=1}); obj.Drawings.C8=new_drawing("Line",{Visible=false,Thickness=1}); obj.Drawings.HealthBack=new_drawing("Square",{Visible=false,Filled=true,Color=Color3.new(0,0,0)}); obj.Drawings.HealthBar=new_drawing("Square",{Visible=false,Filled=true,Color=esp_settings.health.high_color}); obj.Drawings.HealthText=new_drawing("Text",{Visible=false,Center=true,Outline=true,Font=esp_settings.text.font,Size=esp_settings.text.size,Color=esp_settings.health.text_color}); obj.Drawings.Name=new_drawing("Text",{Visible=false,Center=true,Outline=true,Font=esp_settings.text.font,Size=esp_settings.text.size,Color=esp_settings.names.color}); obj.Drawings.Distance=new_drawing("Text",{Visible=false,Center=true,Outline=true,Font=esp_settings.text.font,Size=esp_settings.text.size,Color=esp_settings.distance.color}); obj.Drawings.Tool=new_drawing("Text",{Visible=false,Center=true,Outline=true,Font=esp_settings.text.font,Size=esp_settings.text.size,Color=esp_settings.tool.color}); obj.Drawings.Skel_1=new_drawing("Line",{Visible=false,Thickness=1}); obj.Drawings.Skel_2=new_drawing("Line",{Visible=false,Thickness=1}); obj.Drawings.Skel_3=new_drawing("Line",{Visible=false,Thickness=1}); obj.Drawings.Skel_4=new_drawing("Line",{Visible=false,Thickness=1}); obj.Drawings.Skel_5=new_drawing("Line",{Visible=false,Thickness=1}); obj.Drawings.HeadDot=new_drawing("Circle",{Visible=false,Filled=true,Radius=3}); obj.Drawings.ViewTracer=new_drawing("Line",{Visible=false,Thickness=1}); esp_database[player]=obj end
local function remove_esp(player) if esp_database[player] then for _,d in pairs(esp_database[player].Drawings) do d:Remove() end; for _,c in pairs(esp_database[player].Chams) do c:Destroy() end; esp_database[player]=nil end end

--// 6. TARGET LOGIC & VISIBILITY CHECKS \\--
local function is_visible(target_part) local origin=camera.CFrame.Position; local params=RaycastParams.new(); params.FilterDescendantsInstances={local_player.Character,camera}; params.FilterType=Enum.RaycastFilterType.Blacklist; local result=workspace:Raycast(origin,(target_part.Position-origin),params); if result then if result.Instance:IsDescendantOf(target_part.Parent) then return true end; return false end; return true end
local function is_visible_from_character(target_part) local my_char = local_player.Character; if not my_char then return false end; local my_head = my_char:FindFirstChild("Head"); if not my_head then return false end; local origin = my_head.Position; local params = RaycastParams.new(); params.FilterDescendantsInstances = {local_player.Character, camera}; params.FilterType = Enum.RaycastFilterType.Blacklist; local result = workspace:Raycast(origin, (target_part.Position - origin), params); if result then if result.Instance:IsDescendantOf(target_part.Parent) then return true end; return false end; return true end
local function get_closest_target() local closest, min_dist = nil, 9e9; if aim_settings.fov.main.enabled then min_dist = aim_settings.fov.radius end; local mouse_pos = user_input_service:GetMouseLocation(); for _, player in ipairs(players:GetPlayers()) do if player ~= local_player and not (esp_settings.ignore_lobby_players and player.Team and player.Team.Name == "Lobby") then local char = player.Character; local hum = char and char:FindFirstChild("Humanoid"); local target_part = char and char:FindFirstChild(aim_settings.hitpart); if char and hum and target_part and hum.Health > 0 then local screen_pos, on_screen = camera:WorldToViewportPoint(target_part.Position); if on_screen then local dist = (Vector2.new(screen_pos.X, screen_pos.Y) - mouse_pos).Magnitude; if dist < min_dist then local is_actually_visible = false; if aim_settings.visible_check then if aim_settings.fire_point_override == "Character" then is_actually_visible = is_visible_from_character(target_part) else is_actually_visible = is_visible(target_part) end else is_actually_visible = true end; if is_actually_visible then min_dist = dist; closest = target_part end end end end end end; return closest end

--// 7. SILENT AIM & TRACERS \\--
task.spawn(function() local success, err = pcall(function() local gun_modules = replicated_storage:WaitForChild("ModuleScripts", 5):WaitForChild("GunModules", 5); local bullet_handler = require(gun_modules:WaitForChild("BulletHandler", 5)); local old_fire = bullet_handler.Fire; bullet_handler.Fire = function(data) local origin, direction = data.Origin, data.Direction; if aim_settings.fire_point_override == "Character" then local my_head = local_player.Character and local_player.Character:FindFirstChild("Head"); if my_head then data.Origin = my_head.Position; origin = my_head.Position end end; if aim_settings.enabled and math.random(1, 100) <= aim_settings.hitchance then local target = get_closest_target(); if target and target.Parent then local target_data = esp_database[target.Parent.Parent]; local aim_at_position = target.Position; if aim_settings.prediction.enabled and target_data and target_data.Velocity then local dist_to_target = (origin - target.Position).Magnitude; local prediction_factor = aim_settings.prediction.base_factor; if aim_settings.prediction.adaptable then prediction_factor = prediction_factor + (dist_to_target * aim_settings.prediction.scaling_per_stud) end; aim_at_position = target.Position + target_data.Velocity * prediction_factor end; direction = (aim_at_position - origin).Unit; data.Direction = direction end end; if aim_settings.tracers.enabled and origin then local end_pos = origin + (direction * 300); local target = get_closest_target(); if target and target.Parent and aim_settings.enabled then local target_data = esp_database[target.Parent.Parent]; if aim_settings.prediction.enabled and target_data and target_data.Velocity then local dist_to_target = (origin - target.Position).Magnitude; local prediction_factor = aim_settings.prediction.base_factor; if aim_settings.prediction.adaptable then prediction_factor = prediction_factor + (dist_to_target * aim_settings.prediction.scaling_per_stud) end; end_pos = target.Position + (target_data.Velocity * prediction_factor) else end_pos = target.Position end end; spawn_tracer(origin, end_pos) end; return old_fire(data) end end); if not success then warn("streSSed: Silent Aim hook failed. Error: "..tostring(err)) end end)

--// 8. MAIN ESP/AIM LOOP \\--
local trigger_cooldown = false
run_service:BindToRenderStep("plinian_loop", Enum.RenderPriority.Camera.Value + 1, function()
    local mouse_pos = user_input_service:GetMouseLocation(); local center = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2); local target_part = get_closest_target(); local target_char = target_part and target_part.Parent
    if aim_settings.enabled and aim_settings.triggerbot.enabled and target_part then local can_shoot = true; if aim_settings.triggerbot.visible_check then local target_is_visible = false; if aim_settings.fire_point_override == "Character" then target_is_visible = is_visible_from_character(target_part) else target_is_visible = is_visible(target_part) end; if not target_is_visible then can_shoot = false end end; if aim_settings.triggerbot.weapon_check then if not (local_player.Character and local_player.Character:FindFirstChildOfClass("Tool")) then can_shoot = false end end; if can_shoot and not trigger_cooldown then trigger_cooldown = true; task.delay(aim_settings.triggerbot.delay, function() mouse1click(); trigger_cooldown = false end) end end
    if aim_settings.enabled and aim_settings.fov.main.enabled then local main_color=aim_settings.fov.main.color; if target_part and aim_settings.fov.target_highlight then main_color=aim_settings.fov.target_highlight_color end; if aim_settings.fov.fill.enabled then fov_fill.Visible=true;fov_fill.Position=mouse_pos;fov_fill.Radius=aim_settings.fov.radius;fov_fill.Color=aim_settings.fov.fill.color;fov_fill.Transparency=aim_settings.fov.fill.transparency;fov_fill.NumSides=aim_settings.fov.sides;fov_fill.Filled=true else fov_fill.Visible=false end; if aim_settings.fov.outline.enabled then fov_outline.Visible=true;fov_outline.Position=mouse_pos;fov_outline.Radius=aim_settings.fov.radius;fov_outline.Color=aim_settings.fov.outline.color;fov_outline.Transparency=aim_settings.fov.outline.transparency;fov_outline.Thickness=aim_settings.fov.thickness+2;fov_outline.NumSides=aim_settings.fov.sides else fov_outline.Visible=false end; if aim_settings.fov.main.enabled then fov_main.Visible=true;fov_main.Position=mouse_pos;fov_main.Radius=aim_settings.fov.radius;fov_main.Color=main_color;fov_main.Transparency=aim_settings.fov.main.transparency;fov_main.Thickness=aim_settings.fov.thickness;fov_main.NumSides=aim_settings.fov.sides else fov_main.Visible=false end else fov_fill.Visible=false;fov_outline.Visible=false;fov_main.Visible=false end
    if aim_settings.enabled and aim_settings.snapline.enabled and target_part then local pos=camera:WorldToViewportPoint(target_part.Position); snap_line.Visible=true;snap_line.Color=aim_settings.snapline.color;snap_line.Thickness=aim_settings.snapline.thickness;snap_line.Transparency=1;snap_line.To=Vector2.new(pos.X,pos.Y); local snap_origin=string.lower(aim_settings.snapline.origin); if snap_origin=="bottom" then snap_line.From=Vector2.new(center.X,camera.ViewportSize.Y) elseif snap_origin=="center" then snap_line.From=center else snap_line.From=mouse_pos end else snap_line.Visible=false end
    if esp_settings.master_switch then
        for _, player in ipairs(players:GetPlayers()) do
            if player ~= local_player and not (esp_settings.ignore_lobby_players and player.Team and player.Team.Name == "Lobby") then
                local char = player.Character; local hum = char and char:FindFirstChild("Humanoid"); local root = char and char:FindFirstChild("HumanoidRootPart"); local head = char and char:FindFirstChild("Head")
                if char and hum and root and head and hum.Health > 0 then
                    if esp_database[player] and esp_database[player].Character ~= char then remove_esp(player) end
                    init_esp(player, char); local o = esp_database[player]; local d = o.Drawings; local is_target = (target_char and char == target_char) and aim_settings.target_highlight.enabled; local main_color, text_color = (is_target and aim_settings.target_highlight.color or esp_settings.box.color), (is_target and aim_settings.target_highlight.color or esp_settings.names.color)
                    local current_tick = tick(); if o.LastPosition then local delta_time = current_tick - o.LastTick; if delta_time > 0 then o.Velocity = (root.Position - o.LastPosition) / delta_time end end; o.LastPosition = root.Position; o.LastTick = current_tick
                    local vec, on_screen = camera:WorldToViewportPoint(root.Position); local dist = (camera.CFrame.Position - root.Position).Magnitude; local in_range = not esp_settings.max_distance.enabled or dist <= esp_settings.max_distance.limit
                    if on_screen and in_range then
                        for _, drawing in pairs(d) do drawing.Visible = true end; for _, cham in pairs(o.Chams) do cham.Visible = true end
                        local scale = (1 / ((dist / 3) * math.tan(math.rad(camera.FieldOfView / 2)) * 2)) * 1150; local width = math.floor(scale * 1.3); local height = math.floor(scale * 2.1); local box_pos = Vector2.new(math.floor(vec.X - width / 2), math.floor(vec.Y - height / 2)); local box_size = Vector2.new(width, height); local is_high_detail = not esp_settings.lod_enabled or dist <= esp_settings.lod_distance
                        if esp_settings.box.enabled then d.BoxOutline.Position=box_pos; d.BoxOutline.Size=box_size; d.Box.Visible = esp_settings.box.type == "Full"; d.Box.Position=box_pos; d.Box.Size=box_size; d.Box.Color=main_color; local is_corner = esp_settings.box.type == "Corner"; d.C1.Visible=is_corner; d.C2.Visible=is_corner; d.C3.Visible=is_corner; d.C4.Visible=is_corner; d.C5.Visible=is_corner; d.C6.Visible=is_corner; d.C7.Visible=is_corner; d.C8.Visible=is_corner; if is_corner then local line_l, x, y, w, h = math.floor(width / 3), box_pos.X, box_pos.Y, width, height; local function draw_line(l, x1,y1, x2,y2) l.Color=main_color;l.From=Vector2.new(x1,y1);l.To=Vector2.new(x2,y2) end; draw_line(d.C1, x,y, x+line_l,y); draw_line(d.C2, x,y, x,y+line_l); draw_line(d.C3, x+w-line_l,y, x+w,y); draw_line(d.C4, x+w,y, x+w,y+line_l); draw_line(d.C5, x,y+h-line_l, x,y+h); draw_line(d.C6, x,y+h, x+line_l,y+h); draw_line(d.C7, x+w,y+h-line_l, x+w,y+h); draw_line(d.C8, x+w-line_l,y+h, x+w,y+h) end; d.Fill.Visible = esp_settings.box.fill.enabled; d.Fill.Position=box_pos; d.Fill.Size=box_size; d.Fill.Color=main_color; d.Fill.Transparency = esp_settings.box.fill.transparency else d.BoxOutline.Visible=false;d.Box.Visible=false;d.Fill.Visible=false;d.C1.Visible=false;d.C2.Visible=false;d.C3.Visible=false;d.C4.Visible=false;d.C5.Visible=false;d.C6.Visible=false;d.C7.Visible=false;d.C8.Visible=false end
                        d.Name.Text=string.lower(player.DisplayName);d.Name.Color=text_color;d.Name.Position=Vector2.new(math.floor(box_pos.X+width/2),math.floor(box_pos.Y-18)); d.Distance.Text=tostring(math.floor(dist)).."m";d.Distance.Color=text_color;d.Distance.Position=Vector2.new(math.floor(box_pos.X+width/2),math.floor(box_pos.Y+height+2))
                        if esp_settings.health.enabled then local hp=math.clamp(hum.Health/hum.MaxHealth,0,1);local bar_h,bar_w,offset=math.floor(height*hp),2,4;local bar_x,bar_y=math.floor(box_pos.X-offset-bar_w),math.floor(box_pos.Y+(height-bar_h));local health_color=esp_settings.health.low_color:Lerp(esp_settings.health.high_color,hp);d.HealthBack.Size=Vector2.new(bar_w+2,height+2);d.HealthBack.Position=Vector2.new(bar_x-1,math.floor(box_pos.Y)-1);d.HealthBar.Size=Vector2.new(bar_w,bar_h);d.HealthBar.Position=Vector2.new(bar_x,bar_y);d.HealthBar.Color=health_color; if is_high_detail then d.HealthText.Visible=esp_settings.health.text;d.HealthText.Text=tostring(math.floor(hum.Health)).."HP";d.HealthText.Color=text_color;d.HealthText.Position=Vector2.new(math.floor(bar_x-19),math.floor(bar_y-(d.HealthText.Size/2)+1)) else d.HealthText.Visible=false end else d.HealthBack.Visible=false;d.HealthBar.Visible=false;d.HealthText.Visible=false end
                        if is_high_detail and esp_settings.tool.enabled then local tool = char:FindFirstChildOfClass("Tool"); if tool then d.Tool.Visible=true; d.Tool.Text=string.lower(tool.Name); d.Tool.Color=text_color; d.Tool.Position=Vector2.new(math.floor(box_pos.X+width/2),math.floor(box_pos.Y+height+14)) else d.Tool.Visible=false end else d.Tool.Visible=false end
                    else if esp_database[player] then for _,drawing in pairs(esp_database[player].Drawings) do drawing.Visible = false end; for _,cham in pairs(esp_database[player].Chams) do cham.Visible = false end end end
                    if esp_settings.chams.enabled then for _, part in pairs(char:GetChildren()) do if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Transparency < 1 then local cham_color = is_target and aim_settings.target_highlight.color or esp_settings.chams.color; if not o.Chams[part] then local c = Instance.new("BoxHandleAdornment"); c.Name = "Cham"; c.Adornee = part; c.AlwaysOnTop = true; c.ZIndex = 5; c.Size = part.Size + Vector3.new(0.05, 0.05, 0.05); c.Transparency = esp_settings.chams.transparency; c.Color3 = cham_color; c.Parent = part; track(c); o.Chams[part] = c else o.Chams[part].Color3 = cham_color end end end else if esp_database[player] then for _,cham in pairs(esp_database[player].Chams) do cham:Destroy(); esp_database[player].Chams[cham] = nil end end end
                else if esp_database[player] then remove_esp(player) end end
            else if esp_database[player] then remove_esp(player) end end
        end
    else for _,p_data in pairs(esp_database) do for _,drawing in pairs(p_data.Drawings) do drawing.Visible = false end; for _,cham in pairs(p_data.Chams) do cham.Visible = false end end end
end)
players.PlayerRemoving:Connect(remove_esp)

--// 9. ANTI-AIM CONTROLLER (DECOUPLED) \\--
local last_jitter_flip, jitter_direction = 0, 1
run_service:BindToRenderStep("plinian_antiaim", Enum.RenderPriority.Last.Value, function() local character = local_player.Character; local humanoid = character and character:FindFirstChildOfClass("Humanoid"); if humanoid then if anti_aim_settings.enabled then humanoid.AutoRotate = false; local hrp = character:FindFirstChild("HumanoidRootPart"); if hrp then local original_cam_cframe = camera.CFrame; local root_pos, new_look_cframe = hrp.Position, nil; local _, cam_world_yaw = original_cam_cframe:ToOrientation(); if anti_aim_settings.mode == "Jitter" then if (tick() - last_jitter_flip) > (1 / anti_aim_settings.jitter_speed) then jitter_direction = -jitter_direction; last_jitter_flip = tick() end; local final_world_yaw = cam_world_yaw + math.rad(anti_aim_settings.yaw_offset) + math.rad(anti_aim_settings.jitter_offset * jitter_direction); new_look_cframe = CFrame.new(root_pos) * CFrame.Angles(0, final_world_yaw, 0) elseif anti_aim_settings.mode == "Spin" then local current_spin_angle = (tick() * (anti_aim_settings.spin_speed * 60)) % 360; new_look_cframe = CFrame.new(root_pos) * CFrame.Angles(0, math.rad(current_spin_angle), 0) elseif anti_aim_settings.mode == "Sway" then local sway_offset = math.rad(anti_aim_settings.sway_angle * math.sin(tick() * anti_aim_settings.sway_speed)); local final_world_yaw = cam_world_yaw + sway_offset; new_look_cframe = CFrame.new(root_pos) * CFrame.Angles(0, final_world_yaw, 0) elseif anti_aim_settings.mode == "Static" then local final_world_yaw = cam_world_yaw + math.rad(anti_aim_settings.yaw_offset); new_look_cframe = CFrame.new(root_pos) * CFrame.Angles(0, final_world_yaw, 0) end; if new_look_cframe then hrp.CFrame = CFrame.new(hrp.CFrame.Position, hrp.CFrame.Position + new_look_cframe.LookVector) end; camera.CFrame = original_cam_cframe end else if humanoid.AutoRotate == false then humanoid.AutoRotate = true end end end end)

--// 10. THIRD-PERSON CONTROLLER \\--
local third_person_active, yaw, pitch, calib_const = false, 0, 0, 0.03
user_input_service.InputBegan:Connect(function(input, gp) if not thirdperson_settings.enabled or gp then return end; if input.KeyCode == thirdperson_settings.keybind then third_person_active = not third_person_active; user_input_service.MouseBehavior = third_person_active and Enum.MouseBehavior.LockCenter or Enum.MouseBehavior.Default; if not third_person_active and local_player.Character then camera.CameraType = Enum.CameraType.Custom; camera.CameraSubject = local_player.Character:FindFirstChildOfClass("Humanoid") else local p, y, _ = camera.CFrame:ToEulerAnglesYXZ(); yaw = y; pitch = p end end end)
local function update_third_person_camera() if not third_person_active or not thirdperson_settings.enabled then return end; local character = local_player.Character; if not character or not character:FindFirstChild("HumanoidRootPart") then return end; local root_part = character.HumanoidRootPart; camera.CameraType = Enum.CameraType.Scriptable; user_input_service.MouseBehavior = Enum.MouseBehavior.LockCenter; for _, part in ipairs(character:GetDescendants()) do if part:IsA("BasePart") then part.LocalTransparencyModifier = 0 end end; local mouse_delta, user_sens = user_input_service:GetMouseDelta(), user_input_service.MouseDeltaSensitivity; yaw = yaw - (mouse_delta.X * user_sens * calib_const); pitch = pitch - (mouse_delta.Y * user_sens * calib_const); pitch = math.clamp(pitch, math.rad(-80), math.rad(80)); local rotation = CFrame.fromEulerAnglesYXZ(pitch, yaw, 0); local focus_pos = root_part.Position + Vector3.new(0, 1.5, 0); local goal_pos = focus_pos + (rotation * CFrame.new(0, 0, thirdperson_settings.distance)).Position; local ray_params = RaycastParams.new(); ray_params.FilterType = Enum.RaycastFilterType.Exclude; ray_params.FilterDescendantsInstances = {character}; local direction = goal_pos - focus_pos; local result = workspace:Raycast(focus_pos, direction, ray_params); local final_pos = result and (focus_pos + (direction.Unit * (result.Distance - 0.3))) or goal_pos; camera.CFrame = CFrame.new(final_pos, focus_pos) end
run_service:BindToRenderStep("plinian_thirdperson", Enum.RenderPriority.Camera.Value + 10, update_third_person_camera)

--// 11. MISC CONTROLLER \\--
local function update_misc() local character = local_player.Character; if not character then return end; local animate_script = character:FindFirstChild("Animate"); if not animate_script then return end; local desired_state = misc_settings.no_animations.enabled; if animate_script.Disabled ~= desired_state then animate_script.Disabled = desired_state end end
run_service:BindToRenderStep("plinian_misc", Enum.RenderPriority.Character.Value, update_misc)

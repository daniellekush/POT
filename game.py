import pygame as p
import math as m
import time as t
import random as r
import os

#os.environ["PYGAME_FREETYPE"] = "1"
p.mixer.pre_init(frequency=44100, size=-16, channels=60, buffer=128)
p.init()
p.mixer.set_num_channels(16)

import sound
import display
import events

import interface_components
import cameras
import creatures
import levels
import entities
import graphics as gfx
import saving
import ai
import particles
import light
import npc

import global_values as g
import utilities as util

display.setup_display()

sound.load_sound_dict()

from operator import attrgetter    

gfx.SysFont("arial_font_s1", "arial", 10)
gfx.SysFont("arial_font_s2", "arial", 20)
gfx.SysFont("arial_font_s3", "arial", 30)


    
g.camera = cameras.Camera(p.Rect(10,50,2200,(g.HEIGHT/g.WIDTH)*2200 ), solid=True, collision_dict={"border":False, "levels":False})

player_spritesheet = gfx.Spritesheet("player_spritesheet", 32, 32, transparency_pixel=g.TRANSPARENCY_COLOUR)
buttons_spritesheet = gfx.Spritesheet("buttons_spritesheet", 64, 32)

player_anims = gfx.Animation_System(player_spritesheet,
                               { frozenset(["static"]):0,
                               frozenset(["up"]):1,
                               frozenset(["down"]):2,
                               frozenset(["left"]):3,
                               frozenset(["right"]):4,
                                frozenset(["upleft"]):5,
                                frozenset(["upright"]):6,
                                frozenset(["downleft"]):7,
                                frozenset(["downright"]):8},
                               frozenset(["static"]), g.MAX_TICK_RATE)

#tile_spritesheet = gfx.Spritesheet("tiles_test", 32, 32, transparency_pixel=g.TRANSPARENCY_COLOUR)
#misc_spritesheet = gfx.Spritesheet("misc_test", 32, 32, transparency_pixel=g.TRANSPARENCY_COLOUR)
gfx.create_spritesheets(32, 32)

levels.Tile_Info("floor", False, (None, (1,0)))
levels.Tile_Info("wall", True, (None, (0,0)))

level = levels.Tile_Level("test2.lvl", 50, 50)
#level = levels.Mask_Level("test3", "test3", 100, 100, level_scale_x=g.LEVEL_SCALE_X, level_scale_y=g.LEVEL_SCALE_Y)
            
node_map = ai.Node_Map(level)
ai.generate_from_level(node_map, level, 50, {"levels":True, "border":True, "camera":False}, all_directions=False, cardinal=True)

#light_grid = light.Light_Grid(level, 50, 50, min_light_level=0.3)
#lgs = light.Light_Grid_Source(light_grid, 1700, 800, 20, 400)


g.player = creatures.Player(p.Rect(0,0,48,48*2), player_anims, 100, 10, cw=1, ch=1, max_v=None, max_vy=50, check_grounded=True, collision_dict={})
g.player.move_to_spawn_point()
#lgs.center(g.player.rect.center)
#lgs.set_parent(g.player)

#test_entity = entities.Entity_Test(p.Rect(700,700,50,40), push_bias=-1, solid=True, collision_dict={"class_Player":True})

start_background = interface_components.Background(gfx.load_image("background1"), {"start"})
game_over_background = interface_components.Background(gfx.load_image("game_over_background1"), {"game_over"})

start_button = interface_components.Button("start_button", p.Rect(util.dnmx(0.4), util.dnmy(0.2), util.dnmx(0.2), util.dnmy(0.1)), buttons_spritesheet.sprites[0][1], buttons_spritesheet.sprites[0][0], {"start"})
rules_button = interface_components.Button("rules_button", p.Rect(util.dnmx(0.4), util.dnmy(0.4), util.dnmx(0.2), util.dnmy(0.1)), buttons_spritesheet.sprites[2][1], buttons_spritesheet.sprites[2][0], {"start"})
quit_button = interface_components.Button("quit_button", p.Rect(util.dnmx(0.4), util.dnmy(0.6), util.dnmx(0.2), util.dnmy(0.1)), buttons_spritesheet.sprites[1][1], buttons_spritesheet.sprites[1][0], {"start"})

rules_slides = interface_components.Slides(g.SCREEN_RECT.copy(), ["slide1","slide2","slide3"], {"rules"}, keypress_progression={"backward":p.K_LEFT, "forward":p.K_RIGHT})
back_to_menu_button = interface_components.Button("back_to_menu_button", p.Rect(util.dnmx(0.0), util.dnmy(0.9), util.dnmx(0.1), util.dnmy(0.1)), buttons_spritesheet.sprites[3][1], buttons_spritesheet.sprites[3][0], {"rules", "game_over"})


#test_decoration = interface_components.Decoration(p.Rect(10,300,120,80), player_spritesheet.sprites[0][0], {"start"})
#test_pie = interface_components.Pie(p.Rect(80, 80, 200, 200), "x", 0, level.width, {"main"}, variable_obj=g.player, border_colour=g.BLACK)
#test_bar = interface_components.Bar(p.Rect(20, 280, 200, 40), "x", 0, level.width, {"main"}, variable_obj=g.player)
#test_measurement = interface_components.Measurement([player_spritesheet.sprites[0][0],player_spritesheet.sprites[0][1]], (100,100), (32,32), "x", 50, {"main"}, variable_obj=g.player)
#test_WIC = entities.World_Interface_Component(p.Rect(180, 180, 200, 200), test_pie)
#test_monitor = interface_components.Monitor(p.Rect(0, 0, g.fonts["arial_font_s2"].size("000.00")[0], g.fonts["arial_font_s2"].get_linesize()), g.fonts["arial_font_s2"], "mx", {"start","main"}, g.WHITE, background_colour=g.BLACK, variable_obj=g)
#test_text_box = interface_components.Text_Box(p.Rect(50,50,250,50), g.fonts["arial_font_s2"], "g.player.rect", {"main"}, g.WHITE, border_colour=None, border_width=4, eval_text=True)       
#g.test_tbs = ""
#events.String_Reveal_Event(None, "Tab:\t | Newline:\n\n | Good Stuff | Four Spaces: , , , | Annnd we're done! |", g.MAX_TICK_RATE*5,variable_name="test_tbs", active_states={"main"})
#test_test_box2 = interface_components.Text_Box(p.Rect(300,50,300,400), g.fonts["arial_font_s2"], "g.test_tbs", {"main"}, g.BLUE, border_colour=g.WHITE, background_colour=g.BLACK, center_text=(True, False), safe_bounding=True, eval_text=True) 
#test_WIC2 = entities.World_Interface_Component(p.Rect(180, 180, 200, 300), test_test_box2)

g.camera.rect.center = g.player.rect.center
g.camera.set_from_rect()
g.camera.set_parent(g.player, offset=False)

saving.Saved_Data("test_data", save_on_quit=True)
#saving.Saved_Variable("x", g.player, "test_data", load_on_start=True, save_on_change=True)
#saving.Saved_Variable("y", g.player, "test_data", load_on_start=True, save_on_change=True)

#saving.Saved_Variable("x", g.camera, "test_data", load_on_start=True, save_on_change=True)
#saving.Saved_Variable("y", g.camera, "test_data", load_on_start=True, save_on_change=True)

#particles.Rain(5, 0.05, 8, gy=5, max_particles=2000)


def game_over():
    g.current_states = {"game_over"}

def new_game():
    #reset()
    g.current_states = {"main"}

def reset():
    for entity in g.game_objects.get("class_Entity", []):
        entity.delete()
        
    for saved_variable in g.saved_variables:
        if saved_variable.load_on_reset():
            saved_variable.load()
    
    events.clear_events()

    

#a way to "communicate" to the next tick
#e.g. add "game over" to internal commands and then a gameover can occur next frame
def handle_internal_commands(tick_position):
    #removing duplicates (sets cannot be used because order may need to be maintained)
    internal_commands = []
    internal_commands = [c for c in g.internal_commands if c not in internal_commands]
    for command_data_string in internal_commands:
        command_data = command_data_string.split("|")
        command = command_data[-1]

        #actually handle command
        if (command_data[0] == tick_position) or (len(command_data) == 1 and tick_position == "end"):
            if command == "game_over":
                game_over()

            elif command == "new_game":
                new_game()

            elif command == "reset":
                reset()

            g.internal_commands.remove(command_data_string)

def handle_input():
    
    for event in p.event.get():
        #state independant event handling
        if event.type == p.KEYDOWN:
            for keypress_event in [e for e in g.events if (isinstance(e, events.Keypress_Event) and e.press_type == "press")]:
                if event.key in keypress_event.keys:
                    event.press()

            for slide in g.game_objects.get("class_Slides", []):
                if slide.active and slide.keypress_progression:
                    if slide.keypress_progression["backward"] == event.key:
                        slide.progress(-1)
                    if slide.keypress_progression["forward"] == event.key:
                        slide.progress(1)

            if "rules" in g.current_states:
                if event.key == p.K_ESCAPE:
                    g.current_states = {"start"}

            if "game_over" in g.current_states:
                if event.key == p.K_ESCAPE:
                    g.current_states = {"start"}

            if "main" in g.current_states:
                if event.key == p.K_e:
                    g.internal_commands.append("game_over")

                if event.key == p.K_r:
                    events.Camera_Shake_Event(None, g.MAX_TICK_RATE*2, 30, 8)

                if event.key == p.K_SPACE:
                    #print(g.player.grounded)
                    if g.player.grounded:
                        g.player.vy = -30
                    #else:
                    #    draw()
                    #    p.display.flip()
                    #    import time
                    #    time.sleep(1)
                        
                    
        elif event.type == p.KEYUP:
            for keypress_event in [e for e in g.events if (isinstance(e, events.Keypress_Event) and e.press_type == "release")]:
                if event.key in keypress_event.keys:
                    event.press()

        elif event.type == p.MOUSEBUTTONDOWN:
            if not g.mouse_locks[event.button]:
                for slide in g.game_objects.get("class_Slides", []):
                    if slide.active and slide.click_progression:
                        if slide.rect.collidepoint(g.mp):
                            if slide.click_progression["backward"] == event.button:
                                slide.progress(-1)
                            if slide.click_progression["forward"] == event.button:
                                slide.progress(1)
            
        elif event.type == p.QUIT:
            util.quit_game()

    g.keys = p.key.get_pressed()

    g.player.accelerate_self_cardinal(g.keys[p.K_a], g.keys[p.K_w], -g.player.move_speed)
    g.player.accelerate_self_cardinal(g.keys[p.K_d], g.keys[p.K_s], g.player.move_speed)

    if g.keys[p.K_LEFT]:
        g.player.change_size(-5,0)
    if g.keys[p.K_RIGHT]:
        g.player.change_size(5,0)
    if g.keys[p.K_UP]:
        g.player.change_size(0,5)
    if g.keys[p.K_DOWN]:
        g.player.change_size(0,-5)

    if g.keys[p.K_q]:
        g.camera.set_from_rect(g.camera.rect.inflate(-20,-20))
    elif g.keys[p.K_z]:
        g.camera.set_from_rect(g.camera.rect.inflate(20,20))

    #set global vars related to mouse
    g.mx, g.my = p.mouse.get_pos()
    g.mp = (g.mx, g.my)

    g.tmp = g.camera.reverse_transform_point(g.mx, g.my)
    g.tmx, g.tmy = g.tmp
    g.rmx = g.mx/g.WIDTH
    g.rmy = g.my/g.HEIGHT

    g.ml, g.mm, g.mr = p.mouse.get_pressed()
    if g.mouse_locks[1]:
        g.ml = False
    if g.mouse_locks[2]:
        g.mm = False
    if g.mouse_locks[3]:
        g.mr = False
        
    
def update():
    sound.update_emitter_volumes()

    if  "main" in g.current_states:
        for entity in g.game_objects.get("class_Game_Object", []):
            entity.old_x = entity.x
            entity.old_y = entity.y
            entity.old_width = entity.width
            entity.old_height = entity.height

    handle_input()

    #print(g.player.vx, g.player.vy, g.player.max_vx, g.player.max_vy, g.player.max_v)
    
    if g.active_levels:
        g.current_level = g.active_levels[0]
    else:
        g.current_level = None

    for event in g.events:
        event.set_active()

    #this while loop system prevents crashes from pipes being deleted mid loop
    pipe_i = 0
    
    while pipe_i < len(g.pipe_list):
        pipe = g.pipe_list[pipe_i]
        if not pipe.locked:
            pipe.update()
            if not pipe.deleted:
                pipe_i += 1
        else:
            pipe_i += 1


    event_i = 0
    while event_i < len(g.events):
        event = g.events[event_i]
        if event.pipe is None and event.active:
            event.update()
            if not event.deleted:
                event_i += 1
        else:
            event_i += 1
        
    if  "main" in g.current_states:
        for level in g.active_levels:
            level.update()
        for light_grid in g.light_grids:
            light_grid.update()

        
        #update segments
        if g.segmenting_in_levels:
            for entity in g.game_objects.get("class_Entity", []):
                entity.update_segments()

        #update entities
        for entity in g.game_objects.get("class_Entity", []):
            entity.update()

        #clip (clamp) the values of the light grids
        for light_grid in g.light_grids:
            light_grid.clamp_lighting()

    if g.SHOW_FPS:
        g.fps_text_box.text = str( round(g.frame_rate,1) )
    else:
        g.fps_text_box.visible = False
            
    for interface_component in g.game_objects.get("class_Interface_Component", []):
        interface_component.update()

    #see how much each entity has "really" moved
    if  "main" in g.current_states:
        for entity in g.game_objects.get("class_Game_Object", []):
            entity.real_vx = entity.x-entity.old_x
            entity.real_vy = entity.y-entity.old_y

    #print(len(g.pipes))

def order_entity(obj):
    order = obj.y+obj.draw_bias
    if isinstance(obj, light.Light):
        order += 9999
    return order

def order_interface_component(obj):
    order = obj.draw_bias
    return order

def draw():
        
    if "main" in g.current_states and g.ENABLE_LIGHTING:
        g.darkness_surface.fill(g.BLACK)
        g.darkness_surface.set_alpha(255-g.MIN_LIGHT_LEVEL)
        if g.ENABLE_COLOURED_LIGHTING:
            g.light_colour_surface.fill((0,0,0,0))
        
    drawing_objects = []
    #background interface_components
    drawing_objects += list(sorted([interface_component for interface_component in g.game_objects.get("class_Interface_Component", []) if interface_component.active and interface_component.visible and interface_component.background], key=order_interface_component ))

    if "main" in g.current_states:
        drawing_objects += g.active_levels
        drawing_objects += list(sorted([entity for entity in g.game_objects.get("class_Entity", []) if entity.visible], key=order_entity ))
    for obj in drawing_objects:
        obj.draw()

    if "main" in g.current_states:
        for light_grid in g.light_grids:
            light_grid.draw()

        if g.ENABLE_LIGHTING:
            if g.ENABLE_COLOURED_LIGHTING:
                g.screen.blit(g.light_colour_surface, (0,0))
            g.screen.blit(g.darkness_surface, (0,0))
             
    #foreground interface_components
    drawing_objects = events.get_tagged_events({"overlay"})
    drawing_objects += list(sorted([interface_component for interface_component in g.game_objects.get("class_Interface_Component", []) if interface_component.active and interface_component.visible and not interface_component.background], key=order_interface_component ))
    for obj in drawing_objects:
        obj.draw()

    #for node_map in g.node_maps:
    #    node_map.draw()

    for animation_system in g.animation_systems:
        animation_system.update()
        
    for saved_variable in g.saved_variables:
        saved_variable.update()

g.fps_text_box = interface_components.Text_Box(p.Rect(0, 0, g.fonts["arial_font_s3"].size("000.00")[0], g.fonts["arial_font_s3"].get_linesize()), g.fonts["arial_font_s3"], "", {"main"}, g.WHITE, background_colour=g.BLACK)



RUNNING = True
while RUNNING:
    #update
    if g.time_to_next_tick <= g.time_to_next_frame:
        update_type = "tick"
        elapsed_time = g.time_to_next_tick
        
        g.time_to_next_frame -= elapsed_time
        g.time_to_next_tick = g.MIN_TICK_TIME

        old_tick_perf_counter = g.tick_perf_counter
        g.tick_perf_counter = t.perf_counter()
        elapsed_tick_time = g.tick_perf_counter-old_tick_perf_counter
        g.tick_rate = 1/elapsed_tick_time
        
    else:
        update_type = "frame"
        elapsed_time = g.time_to_next_frame
        
        g.time_to_next_tick -= elapsed_time
        g.time_to_next_frame = g.MIN_FRAME_TIME

        old_frame_perf_counter = g.frame_perf_counter
        g.frame_perf_counter = t.perf_counter()
        elapsed_frame_time = g.frame_perf_counter-old_frame_perf_counter
        g.frame_rate = 1/elapsed_frame_time
        
    if update_type == "tick":
        handle_internal_commands("start")
        update()
        handle_internal_commands("end")
        g.tick_count += 1
    elif update_type == "frame":
        if g.DRAW_BACKGROUND:
            if g.BACKGROUND_SURFACE:
                screen.blit(g.BACKGROUND_SURFACE)
            else:
                g.screen.fill(g.BACKGROUND_COLOUR)
        draw()
        p.display.flip()
        g.frame_count += 1

    #print("interval")
    if elapsed_time:
        if update_type == "tick":
            g.clock.tick(1/elapsed_time)
        elif update_type == "frame":
            g.clock.tick(1/elapsed_time)
    
    

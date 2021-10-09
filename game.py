import pygame as p
import math as m
import time as t
import random as r
import os
import sys

#os.environ["PYGAME_FREETYPE"] = "1"
p.mixer.pre_init(frequency=44100, size=-16, channels=60, buffer=128)
p.init()
p.mixer.set_num_channels(16)

from . import sound
from . import display
from . import events

from . import interface_components
from . import cameras
from . import creatures
from . import levels
from . import entities
from . import graphics as gfx
from . import saving
from . import ai
from . import particles
from . import light
from . import npc

from . import global_values as g
from . import utilities as util

from operator import attrgetter    

display.setup_display()
sound.load_sound_dict()   
   
def setup(camera_width, camera_height):
    
    g.camera = cameras.Camera(p.Rect(10,50, camera_width, camera_height), solid=True, collision_dict={"border":False, "levels":False})
    g.fps_text_box = interface_components.Text_Box(p.Rect(0, 0, g.fonts["arial_font_s3"].size("000.00")[0], g.fonts["arial_font_s3"].get_linesize()), g.fonts["arial_font_s3"], "", {"main"}, g.WHITE, background_colour=g.BLACK)

    g.structure_classes.update({"Player_Spawn_Point":creatures.Player_Spawn_Point})
    
    g.is_setup = True
    



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

def clear_mouse_locks():
    events.get_tagged_events("mouse_disable")

def handle_input():
    g.pg_events = []
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

        g.pg_events.append(event)

    g.keys = p.key.get_pressed()

    #g.player.accelerate_self_cardinal(g.keys[p.K_a], g.keys[p.K_w], -g.player.move_speed)
    #g.player.accelerate_self_cardinal(g.keys[p.K_d], g.keys[p.K_s], g.player.move_speed)

    #if g.keys[p.K_LEFT]:
    #    g.player.change_size(-5,0)
    #if g.keys[p.K_RIGHT]:
    #    g.player.change_size(5,0)
    #if g.keys[p.K_UP]:
    #    g.player.change_size(0,5)
    #if g.keys[p.K_DOWN]:
    #    g.player.change_size(0,-5)

    #if g.keys[p.K_q]:
    #    g.camera.set_from_rect(g.camera.rect.inflate(-20,-20))
    #elif g.keys[p.K_z]:
    #    g.camera.set_from_rect(g.camera.rect.inflate(20,20))

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
        
def update_events():
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
    
def set_old_properties(force=False):
    if  "main" in g.current_states or force:
        for game_object in g.game_objects.get("class_Game_Object", []):
            game_object.set_old_properties()
    
def update_levels(force=False):
    if "main" in g.current_states or force:
        if g.active_levels:
            g.current_level = g.active_levels[0]
        else:
            g.current_level = None
            
        #update segments
        if g.segmenting_in_levels:
            for entity in g.game_objects.get("class_Entity", []):
                entity.update_segments()
        
def update_lighting(force=False):
    if "main" in g.current_states or force:
        for level in g.active_levels:
            level.update()
        for light_grid in g.light_grids:
            light_grid.update()
            
        #clip (clamp) the values of the light grids
        #should this be moved to post entity update
        for light_grid in g.light_grids:
            light_grid.clamp_lighting()

def update_entities(force=False):
    #update entities
    if "main" in g.current_states or force:
        for entity in g.game_objects.get("class_Entity", []):
            entity.update()

def update_interface_components():
    for interface_component in g.game_objects.get("class_Interface_Component", []):
        interface_component.update()

def finish_update(force=False):
    if g.SHOW_FPS:
        g.fps_text_box.text = str( round(g.frame_rate,1) )
    else:
        g.fps_text_box.visible = False

    #see how much each entity has "really" moved
    if  "main" in g.current_states or force:
        for entity in g.game_objects.get("class_Game_Object", []):
            entity.real_vx = entity.x-entity.old_x
            entity.real_vy = entity.y-entity.old_y


def order_entity(obj):
    order = obj.y+obj.draw_bias
    if isinstance(obj, light.Light):
        order += 9999
    return order

def order_interface_component(obj):
    order = obj.draw_bias
    return order
    
#fill in the lighting surfaces
def reset_lighting(force=False):
    if ("main" in g.current_states and g.ENABLE_LIGHTING) or force:
        g.darkness_surface.fill(g.BLACK)
        g.darkness_surface.set_alpha(255-g.MIN_LIGHT_LEVEL)
        if g.ENABLE_COLOURED_LIGHTING:
            g.light_colour_surface.fill((0,0,0,0))

#get an ordered list of all the objects to draw
def get_objects_to_draw(include_entities, include_interface_components):
    drawing_objects = []
    
    #background interface_components
    if include_interface_components:
        drawing_objects += list(sorted([interface_component for interface_component in g.game_objects.get("class_Interface_Component", []) if interface_component.active and interface_component.visible and interface_component.background], key=order_interface_component ))

    if include_entities:
        if "main" in g.current_states:
            drawing_objects += g.active_levels
            drawing_objects += list(sorted([entity for entity in g.game_objects.get("class_Entity", []) if entity.visible], key=order_entity ))
            
            drawing_objects += g.light_grids
    
    #foreground interface_components
    if include_interface_components:
        drawing_objects += events.get_tagged_events({"overlay"})
        drawing_objects += list(sorted([interface_component for interface_component in g.game_objects.get("class_Interface_Component", []) if interface_component.active and interface_component.visible and not interface_component.background], key=order_interface_component ))
    
  
    return drawing_objects  
    
def draw_lighting(force=False):
    if ("main" in g.current_states and g.ENABLE_LIGHTING) or force:
        if g.ENABLE_COLOURED_LIGHTING:
            g.screen.blit(g.light_colour_surface, (0,0))
        g.screen.blit(g.darkness_surface, (0,0))

def draw_background():
    if g.DRAW_BACKGROUND:
        if g.BACKGROUND_SURFACE:
            screen.blit(g.BACKGROUND_SURFACE)
        else:
            g.screen.fill(g.BACKGROUND_COLOUR)




elapsed_time = 0
def wait_for_update(last_update_type):
    #wait to next thing
    if elapsed_time:
        if last_update_type == "tick":
            g.clock.tick(1/elapsed_time)
        elif last_update_type == "frame":
            g.clock.tick(1/elapsed_time)


def continue_game_loop():
    global elapsed_time
    
    try:
        if not g.is_setup:
            raise Exception("Setup must occur before game loop can start. Run POT.setup() (recommended) or set global_value.is_setup to True.")
            
        #tick
        if g.time_to_next_tick <= g.time_to_next_frame:
            update_type = "tick"
            elapsed_time = g.time_to_next_tick
            
            g.time_to_next_frame -= elapsed_time
            g.time_to_next_tick = g.MIN_TICK_TIME
    
            old_tick_perf_counter = g.tick_perf_counter
            g.tick_perf_counter = t.perf_counter()
            elapsed_tick_time = g.tick_perf_counter-old_tick_perf_counter
            g.tick_rate = 1/elapsed_tick_time
            
            g.tick_count += 1
            
        #draw
        else:
            update_type = "frame"
            elapsed_time = g.time_to_next_frame
            
            g.time_to_next_tick -= elapsed_time
            g.time_to_next_frame = g.MIN_FRAME_TIME
    
            old_frame_perf_counter = g.frame_perf_counter
            g.frame_perf_counter = t.perf_counter()
            elapsed_frame_time = g.frame_perf_counter-old_frame_perf_counter
            g.frame_rate = 1/elapsed_frame_time
            
            g.frame_count += 1     
        
        #return whether to update or draw   
        return update_type
                    
                    
    except:
        #if g.RUNNING is False, then the program has most likely exited normally
        if g.RUNNING: 
            import ctypes, traceback, platform, traceback
            if platform.system() == "Windows":
                exc_type, exc_value, exc_traceback = sys.exc_info()
                
                if exc_type != SystemExit:
                    MessageBox = ctypes.windll.user32.MessageBoxW 
                    MessageBox(None, "\nException thrown\nType: "+str(exc_type)+"\nValue: "+str(exc_value)+"\n\n\nFull Traceback:\n\n"+str(traceback.format_exc()), 'Error! (Please report to dev!)', 0)
                    
            util.quit_game()

    

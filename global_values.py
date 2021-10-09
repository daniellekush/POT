import pygame as p
import math as m
import ctypes
import os
import gc


def clear_surface_cache():
    global surface_cache
    surface_cache = {}
    gc.collect()

def set_filtering(enable):
    old_enable = g.FILTER_SCALING
    g.FILTER_SCALING = enable
    if old_enable != g.FILER_SCALING:
        clear_surface_cache()
        
def get_default_surface():
    width, height = 16,16
    
    #create error surface
    default_surface = p.Surface((width, height))
    #purple and black grid
    for x in range(width):
        for y in range(height):
            if (x%2) + (y%2) == 0:
                colour = PURPLE
            else:
                colour = BLACK
            default_surface.set_at((x,y), colour)
            
    #add edge colour
    default_surface.set_at((0,0), RED)
    default_surface.set_at((1,0), RED)
    default_surface.set_at((0,1), RED)
    
    default_surface.set_at((width-1, 0), YELLOW)
    default_surface.set_at((width-2, 0), YELLOW)
    default_surface.set_at((width-1, 1), YELLOW)
    
    default_surface.set_at((0,height-1), BLUE)
    default_surface.set_at((1,height-1), BLUE)
    default_surface.set_at((0,height-2), BLUE)
    
    default_surface.set_at((width-1,height-1), GREEN)
    default_surface.set_at((width-2,height-1), GREEN)
    default_surface.set_at((width-1,height-2), GREEN)
    
    return default_surface

WHITE = (255, 255, 255)
GRAY = (128, 128, 128)
BLACK = (0, 0, 0)
NEAR_BLACK = (1, 1, 1)

RED = (255, 0, 0)
DARK_RED = (128, 0, 0)
ORANGE = (255, 128, 0)
YELLOW = (255,255,0)
LIGHT_GREEN = (0, 255, 128)
GREEN = (0, 255, 0)
DARK_GREEN = (0, 128, 0)
CYAN = (0,255,255)
LIGHT_BLUE = (0, 128, 255)
BLUE = (0, 0, 255)
DARK_BLUE = (0, 0, 128)
PINK = (255, 0, 128)
PURPLE = (128,0,128)
MAGENTA = (255,0,255)
LIGHT_BROWN = (164, 96, 0)
BROWN = (128, 64, 0)
DARK_BROWN = (92, 32, 0)

BACKGROUND_COLOUR = WHITE
BACKGROUND_SURFACE = None
DRAW_BACKGROUND = True
TRANSPARENCY_COLOUR = (0,126,126)

SHOW_FPS = True
SHOW_NODE_MAPS = False

MONITOR_WIDTH = ctypes.windll.user32.GetSystemMetrics(0)
MONITOR_HEIGHT = ctypes.windll.user32.GetSystemMetrics(1)
WIDTH = int(900*1.2)#MONITOR_WIDTH#
HEIGHT = int(500*1.2)#MONITOR_HEIGHT#
SCREEN_RECT = p.Rect(0, 0, WIDTH, HEIGHT)

screen = None
display_screen = None
FILTER_SCALING = False

LEVEL_SCALE_X = 1
LEVEL_SCALE_Y = 1
    
ASPECT_RATIO = WIDTH/HEIGHT

main_dir = "files"+os.path.sep
gfx_dir = main_dir+"gfx"+os.path.sep
level_dir = main_dir+"level"+os.path.sep
sound_dir = main_dir+"sound"+os.path.sep
data_dir = main_dir+"data"+os.path.sep
internal_assets_dir = __file__+os.path.sep+"assets"+os.path.sep

is_setup = False

game_object_next_id = 0

CHUNK_WIDTH = 80
CHUNK_HEIGHT = 80

DEFAULT_LEVEL_SEGMENT_SIZE = 100
ENABLE_SEGMENT_ENTITY_THRESHOLD = 30
GLOBAL_VOLUME = 1

ENTITY_STEP_SNAP_THRESHOLD = 15

segmenting_in_levels = True

ENABLE_LIGHTING = False
ENABLE_COLOURED_LIGHTING = False

MIN_LIGHT_LEVEL = 200
darkness_surface = p.Surface((WIDTH, HEIGHT))
light_colour_surface = p.Surface((WIDTH, HEIGHT))
light_colour_surface.set_colorkey(BLACK)

MAX_SAVE_RECURSION = 10

MAX_TICK_RATE = 60
MAX_FRAME_RATE = 60

MIN_TICK_TIME = 1/MAX_TICK_RATE
MIN_FRAME_TIME = 1/MAX_FRAME_RATE

time_to_next_tick = MIN_TICK_TIME
time_to_next_frame = MIN_FRAME_TIME

tick_count = 0
frame_count = 0

tick_perf_counter = 0
frame_perf_counter = 0
tick_rate = 0
frame_rate = 0
clock = p.time.Clock()

game_objects = {}

animations = []
animation_systems = []
events = []
pipes = {}
pipe_list = []
spritesheets = {}
fonts = {}
logs = {}
node_maps = set()
light_grids = set()
pressed_buttons = set()

surface_cache = {}
sound_properties = {}
pot_sounds = {}
saved_data_dicts = {}
saved_variables = []

internal_commands = []
pg_events = []

current_pressed_button = None

active_levels = []
structure_classes = {}
current_level = None
camera = None
player = None

keys, mx, my, ml, mm, mr, mp =\
[], 0, 0, False, False, False, (0,0)
tmx, tmy = 0, 0
rmx, rmy = 0, 0
mouse_locks = {i:0 for i in range(20)}

#game state
current_states = {"start"}

sound_dict = {}


default_surface = get_default_surface()

        
fps_text_box = None

current_music = None



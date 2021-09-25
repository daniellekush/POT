# cython: profile=True
# cython: language_level=3
# cython: infer_types=True

from . import utilities as util
from . import global_values as g

import math as m
import pygame as p
import os

class Sprite():
    def __init__(self, surface, create_extras=False, mask_threshold=127, highlight_colour=g.YELLOW, highlight_aa=False, highlight_thickness=1, convert=True):            
        self.surface = surface
        
        self.transparent = get_transparent(self.surface)
        #if convert:
        #    self.convert_simple()
        
        self.highlighted_surface = None

        self.mask_threshold = mask_threshold
        self.highlight_aa = highlight_aa
        self.highlight_colour = highlight_colour
        self.highlight_thickness = highlight_thickness

        self.mask = None
        self.c_surface = None #converted
        self.ca_surface = None #converted alpha
        self.na_surface = None #no alpha
        self.nc_surface = None #no colour
        self.ht_surface = None #half transparency
        
        self.fh_surface = None #flipped horizontal
        self.fv_surface = None #flipped vertical
        self.fb_surface = None #flipped horizontal and vertical
        
        self.mr_surface = None #maximum red
        self.mg_surface = None #maximum green
        self.mb_surface = None #maximum blue
        

        self.dirty = {"mask":True, "highlight":True, "convert":True, "alpha":True, "colour":True,
                      "half_transparent":True, "flip_horizontal":True, "flip_vertical":True, "flip_both":True,
                      "max_red":True, "max_green":True, "max_blue":True}

        if create_extras:
            self.create_extras()

    def get_size(self):
        return self.surface.get_size()

    def convert_simple(self):
        if self.transparent:
            self.surface = self.surface.convert()
        else:
            self.surface = self.surface.convert_alpha()

    def set_dirty(self):
        for key in self.dirty.keys():
            self.dirty[key] = True

    def set_clean(self, update=False):
        for key in self.dirty.keys():
            self.dirty[key] = False
        if update:
            self.create_extras()

    def set_highlight_aa(self, value, update=False):
        self.highlight_aa = value
        self.dirty["highlight"] = True
        if update:
            return self.get_highlighted()

    def set_highlight_colour(self, value, update=False):
        self.highlight_colour = value
        self.dirty["highlight"] = True
        if update:
            return self.get_highlighted()

    def set_highlight_thickness(self, value, update=False):
        self.highlight_thickness = value
        self.dirty["highlight"] = True
        if update:
            return self.get_highlighted()

    def set_mask_threshold(self, value, update=False):
        self.mask_threshold = value
        self.dirty["mask"] = True
        if update:
            return self.get_mask()

    def create_extras(self):    
        self.get_converted()
        self.get_converted_alpha()
        self.get_no_alpha()
        self.get_no_colour()
        self.get_highlighted()


    def get_mask(self):
        if self.dirty["mask"]:
            self.mask = p.mask.from_surface(self.surface, self.mask_threshold)
            self.dirty["mask"] = False
        return self.mask

    def get_converted(self):
        if self.dirty["convert"]:
            self.c_surface = self.surface.convert()
            self.dirty["convert"] = False
        return self.c_surface

    def get_converted_alpha(self):
        if self.dirty["convert"]:
            self.ca_surface = self.surface.convert_alpha()
            self.dirty["convert"] = False 
        return self.ca_surface

    def get_no_alpha(self):
        if self.dirty["alpha"]:
            self.na_surface = self.surface.copy()
            blit_surface = p.Surface(self.na_surface.get_size(), flags=p.SRCALPHA)
            blit_surface.fill((0,0,0,255))
            self.na_surface.blit(blit_surface, (0,0), special_flags=p.BLEND_RGBA_SUB)
            self.dirty["alpha"] = False
            
        return self.na_surface

    def get_no_colour(self):
        if self.dirty["colour"]:
            self.nc_surface = self.surface.copy()
            blit_surface = p.Surface(self.nc_surface.get_size(), flags=p.SRCALPHA | p.HWSURFACE)
            blit_surface.fill((255,255,255,0))
            self.nc_surface.blit(blit_surface, (0,0), special_flags=p.BLEND_SUB)
            self.dirty["colour"] = False
            
        return self.nc_surface

    def get_half_transparent(self):
        if self.dirty["half_transparent"]:
            self.ht_surface = self.surface.copy()
            self.ht_surface.set_alpha(128)
            
            self.dirty["half_transparent"] = False

        return self.ht_surface

    def get_flipped_horizontal(self):
        if self.dirty["flip_horizontal"]:
            self.fh_surface = p.transform.flip(self.surface, True, False)
            
            self.dirty["flip_horizontal"] = False

        return self.fh_surface

    def get_flipped_vertical(self):
        if self.dirty["flip_vertical"]:
            self.fv_surface = p.transform.flip(self.surface, False, True)
            
            self.dirty["flip_vertical"] = False

        return self.fv_surface

    def get_flipped_both(self):
        if self.dirty["flip_both"]:
            self.fb_surface = p.transform.flip(self.surface, True, True)
            
            self.dirty["flip_both"] = False

        return self.fb_surface

    def get_max_red(self):
        if self.dirty["max_red"]:
            if self.transparent:
                flags = p.SRCALPHA
            else:
                flags = 0
                
            self.mr_surface = p.Surface( (self.surface.get_width(), self.surface.get_height()), flags=flags )
            self.mr_surface.fill((255,0,0,255))

            self.mr_surface.blit(self.surface, (0,0), special_flags=p.BLEND_RGBA_MIN)

            self.dirty["max_red"] = False

        return self.mr_surface

    def get_max_green(self):
        if self.dirty["max_green"]:
            if self.transparent:
                flags = p.SRCALPHA
            else:
                flags = 0
                
            self.mr_surface = p.Surface( (self.surface.get_width(), self.surface.get_height()), flags=flags )
            self.mr_surface.fill((0,255,0,255))

            self.mr_surface.blit(self.surface, (0,0), special_flags=p.BLEND_RGBA_MIN)

            self.dirty["max_green"] = False

        return self.mg_surface

    def get_max_blue(self):
        if self.dirty["max_blue"]:
            if self.transparent:
                flags = p.SRCALPHA
            else:
                flags = 0
                
            self.mr_surface = p.Surface( (self.surface.get_width(), self.surface.get_height()), flags=flags )
            self.mr_surface.fill((0,0,255,255))

            self.mr_surface.blit(self.surface, (0,0), special_flags=p.BLEND_RGBA_MIN)

            self.dirty["max_blue"] = False

        return self.mb_surface
            
    def get_highlighted(self):
        if self.dirty["highlight"]:
            mask = p.mask.from_surface(self.surface)
            lines = mask.outline()
            self.highlighted_surface = p.Surface(self.get_size())
            self.highlighted_surface.set_colorkey(g.BLACK)
            p.draw.lines(self.highlighted_surface, self.highlight_colour, self.highlight_aa, lines, self.highlight_thickness)
            self.dirty["highlight"] = False

        return self.highlighted_surface

#Spritesheet class for holding graphical data
class Spritesheet():
    def __init__(self, name, sprite_width, sprite_height, transparency_override=None, transparency_pixel=None, transparency_colorkey=None, prefix=g.gfx_dir, extension=".png"):
        self.name = name
        g.spritesheets.update({self.name:self})

        self.surface = load_image(name, prefix=prefix, extension=extension)

        self.sprites = []

        surface_width, surface_height = self.surface.get_width(), self.surface.get_height()
        #iterate though individual sprite sections in the spritesheet surface
        #set up g.animations
        for sprite_y in range(int(surface_height/sprite_height)):
            y = sprite_y*sprite_height
            animation_frames = []
            
            for sprite_x in range(int(surface_width/sprite_width)):
                x = sprite_x*sprite_width

                if transparency_override is not None:
                    transparent = transparency_override
                else:
                    transparent = get_transparent(self.surface)

                if transparent:
                    surface = p.Surface((sprite_width, sprite_height), flags=p.SRCALPHA)
                else:
                    surface = p.Surface((sprite_width, sprite_height))

                if transparency_colorkey:
                    surface.set_colorkey(transparency_colorkey)

                #this is the area of the spritesheet that will be turned into the sprite
                spritesheet_area = p.Rect(x, y, sprite_width, sprite_height)

                #create the sprite surface
                surface.blit(self.surface, (0,0), spritesheet_area)

                sprite = Sprite(surface)
                    
                animation_frames.append(sprite)

            #store animation frames
            self.sprites.append(animation_frames)

    #generate animation using frames from a particular animation ID
    def generate_animation(self, anim_id, anim_timer, loop=True, global_frame=False, system=False):
        animation = Animation(self.sprites[anim_id], anim_timer, loop=loop)
        if system:
            animation_system = Animation_System(self, {"default":anim_id}, "default", anim_timer, loop=loop, global_frame=global_frame)
            return animation_system
        else:
            animation = Animation(self.sprites[anim_id], anim_timer, loop=loop, global_frame=global_frame)
            return animation

#Animation class for holding animations
class Animation():
    def __init__(self, frames, max_animation_timer, loop=True, global_frame=False):
        self.frames = frames
        
        #animation speed is based on the amount of game frames per animation frame
        #a value of zero means that animation does not update
        if max_animation_timer == 0:
            self.animation_speed = 0
        else:
            self.animation_speed = len(self.frames)/max_animation_timer
        self.progress = 0
        self.loop = loop

        self.global_frame = global_frame

        #add to list of g.animations
        g.animations.append(self)


    def update(self):
        #progress animation
        if self.global_frame:
            if not self.loop:
                old_progress = self.progress

            self.progress = (g.tick_count*self.max_animation_speed)%len(self.frames)

            if not self.loop and self.progress < old_progress:
                self.progress = len(self.frames)-1
                
        else:
            self.progress += self.animation_speed
            
            #reset animation
            if self.progress >= len(self.frames):
                if self.loop:
                    self.progress -= len(self.frames)
                else:
                    self.progress = len(self.frames)-1

    def get_current_frame(self):
        #if global animation, set progress now
        if self.global_frame:
            self.update()
        
        #get frame
        frame_no = int(self.progress)
        frame = self.frames[frame_no]
        return frame

#Animation_System class for holding multiple g.animations
class Animation_System():
    def __init__(self, spritesheet, anim_id_dict, current_animation_name, anim_timer, loop=True, global_frame=False, active=True):
        self.anim_timer = anim_timer
        
        self.active = active
        
        self.spritesheet = spritesheet
        #generate animations for this Animation_System object
        self.anim_ids = anim_id_dict
        self.animations = {name:self.spritesheet.generate_animation(anim_id, self.anim_timer, loop=loop, global_frame=global_frame) for name,anim_id in self.anim_ids.items()}

        #the currently playing animation
        self.current_animation_name = current_animation_name

        g.animation_systems.append(self)

    #set the current animation by name
    def set_animation(self, name):
        if self.current_animation_name != name:
            self.animations[self.current_animation_name].progress = 0
        self.current_animation_name = name

    #progress current animation
    def update(self):
        if self.active:
            self.animations[self.current_animation_name].update()

    #get current frame of current animation
    def get_current_frame(self):
        return self.animations[self.current_animation_name].get_current_frame()

    #get progress of current animation
    def get_progress(self):
        return self.animations[self.current_animation_name].progress

def load_image_into_sprite(data, \
                           transparent_override=None, bit_depth=None, absolute_width=None, absolute_height=None, scale=None, scale_width=None, scale_height=None, extension="", prefix="", \
                           create_extras=False, mask_threshold=127, highlight_colour=g.YELLOW, highlight_aa=False):            
    surface = load_image(data, transparent_override=transparent_override, bit_depth=bit_depth, absolute_width=absolute_width, absolute_height=absolute_height, scale=scale, scale_width=scale_width, scale_height=scale_height, extension=extension, prefix=prefix)
    sprite = Sprite(surface, create_extras=create_extras, mask_threshold=mask_threshold, highlight_colour=highlight_colour, highlight_aa=highlight_aa)
    return sprite

#load surface (may be slightly easier than p.image.load)
def load_image(data, transparent_override=None, bit_depth=None, absolute_width=None, absolute_height=None, scale=None, scale_width=None, scale_height=None, extension=".png", prefix=g.gfx_dir):
    if isinstance(data,str):
        try:
            surface = p.image.load(prefix+data+extension)
        except:
            raise Exception("Failed to load "+prefix+data+extension)
        
    elif isinstance(data, p.Surface):
        surface = data

    if transparent_override is not None:
        transparent = transparent_override
    else:
        transparent = get_transparent(surface)
        
    if transparent:
        surface = surface.convert_alpha()
    else:
        if bit_depth:
            surface = surface.convert(bit_depth)
        else:
            surface = surface.convert()

    width = surface.get_width()
    height = surface.get_height()

    if absolute_width and absolute_height:
        if absolute_width:
            width = absolute_width
        if absolute_height:
            height = absolute_height
    else:
        if scale:
            width *= scale
            height *= scale
        else:
            if scale_width or scale_height:
                if scale_width:
                    width *= scale_width
                if scale_height:
                    height *= scale_height
            
                
    surface = scale_surface(surface, (width, height))
        
    return surface

def li(data, t_ov=None, transparent_override=None, bit_depth=None, absolute_width=None, absolute_height=None, scale=None, scale_width=None, scale_height=None, extension=".png", prefix=g.gfx_dir):
    if t_ov is not None:
        transparent_override = t_ov
    return load_image(data, transparent_override=transparent_override, bit_depth=bit_depth, absolute_width=absolute_width, absolute_height=absolute_height, scale=scale, scale_width=scale_width, scale_height=scale_height, extension=extension, prefix=prefix)

def set_background(data, override_surface=None, override_colour=None, override_enable=None):

    if override_enable is not False:
        if can_be_surface(data) and override_surface is None:
            surface = get_surface(data)
            scaled_surface = p.transform.scale(surface, (g.WIDTH, g.HEIGHT))
            g.BACKGROUND_SURFACE = scaled_surface
            
        elif isinstance(data, [list, tuple]) and override_colour is None:
            g.BACKGROUND_COLOUR = data

    if override_surface is not None:
        g.BACKGROUND_SURFACE = get_surface(override_surface)

    if override_colour is not None:
        g.BACKGROUND_COLOUR = override_colour

    if override_enable is not None:
        DRAW_BACKGROUND = override_enable

        

#wrapper for pygame font that stores font size so font can be pickled
class Font(p.font.Font):
    def __init__(self, name, data, size):
        self.name = name
        self.font_size = size
        self.font_data = data
        p.font.Font.__init__(self, data, self.font_size)

        g.fonts.update({self.name:self})
        
def SysFont(name, font_name, size, bold=False, italic=False, file=False):
    if file:
        font_file = font_name
    else:
        font_file = p.font.match_font(font_name, bold=bold, italic=italic)
    font = Font(name, font_file, size)
    return font

        
#load all spritesheeets in a given directory
def create_spritesheets(sprite_width, sprite_height):
    for file in os.listdir(g.gfx_dir):
        if file.endswith("_spritesheet.png"):
            name = file[:-4]
            if name not in g.spritesheets.keys():
                Spritesheet(name, sprite_width, sprite_height)

#returns whether a surface has the SRCALPHA flag enabled
def get_transparent(surface):
    #hacky I know :(
    flags_string = str(hex(surface.get_flags()))
    if len(flags_string) >= 5+2:
        transparent = bool(flags_string[-5])
    else:
        transparent = False
    return transparent

#get a Sprite object from the given graphical data
def get_sprite(graphics):
    if type(graphics) == Animation or type(graphics) == Animation_System:
        sprite = graphics.get_current_frame()
        if not isinstance(sprite, Sprite):
            sprite = None
            
    elif isinstance(graphics, Sprite):
        sprite = graphics
    else:
        sprite = None

    return sprite

#get a Spritesheet object from the given data
def get_spritesheet(data):
    if type(data) == Spritesheet:
        return data
    elif type(data) == str:
        return g.spritesheets.get(data, None)
    else:
        return None

def get_surface(graphics):
    #anim
    if type(graphics) == Animation or type(graphics) == Animation_System:
        surface = graphics.get_current_frame()
        #anim frame is actually sprite
        if type(surface) == Sprite:
            surface = surface.surface

    #surface
    elif type(graphics) == p.Surface:
        surface = graphics

    #sprite
    elif type(graphics) == Sprite:
        surface = graphics.surface

    #string
    elif type(graphics) == str:
        surface = p.image.load(graphics)

    #error
    else:
        surface = g.default_surface

    return surface

def can_be_surface(data):
    if isinstance(data, [Animation, Animation_System, p.Surface, Sprite, str]):
        return True
    else:
        return False


def draw_text_lines(pos, font, text_lines, colour, background=None, antialias=False, draw_surface_override=None):
    if draw_surface_override:
        draw_surface = draw_surface_override
    else:
        draw_surface = g.screen
        
    x, y = pos
    for line in text_lines:
        surface = font.render(line, antialias, colour, background)
        draw_surface.blit(surface, (x, y))
        y += font.get_linesize()

def draw_text_centered(pos, font, text, colour, background=None, antialias=False, draw_surface_override=None):
    if draw_surface_override:
        draw_surface = draw_surface_override
    else:
        draw_surface = g.screen
        
    surface = font.render(text, antialias, colour, background)
    width, height = surface.get_size()
    x, y = pos[0]-int(width/2), pos[1]-int(height/2)
                        
    draw_surface.blit(surface, (x,y))

def scale_graphics(graphics, size, cache=True):
    surface = get_surface(graphics)
    scaled_surface = scale_surface(surface, size, cache=cache)
    return scaled_surface
    
def scale_surface(surface, size, cache=True):
    width, height = int(size[0]), int(size[1])

    if cache:
        if size != surface.get_size():
            #cache the surface to improve performance by minimising transforms        
            #multiplying (height) by a very small number drastically reduces the chance of hash collisions
            surface_hash = hash(surface)+(width)+(height*0.13)
            if g.surface_cache.get(surface_hash, False):
                scaled_surface = g.surface_cache[surface_hash]
            else:
                if g.FILTER_SCALING:
                    scaled_surface = p.transform.smoothscale(surface, (width, height))
                else:
                    scaled_surface = p.transform.scale(surface, (width, height))
                    
                #print("mustlock:", scaled_surface.mustlock(), "flags:", bin(scaled_surface.get_flags()), "width:",width, "height:",height)
                g.surface_cache.update({surface_hash:scaled_surface})
                
            return scaled_surface
        else:
            return surface
    else:
        scaled_surface = p.transform.scale(surface, (width, height))
        return scaled_surface

def draw_scaled_graphics(graphics, rect, draw_surface_override=None, draw_area=None, special_flags=0, cache=True):
    if draw_surface_override:
        draw_surface = draw_surface_override
    else:
        draw_surface = g.screen

    surface = scale_surface(get_surface(graphics), (rect.w, rect.h), cache=cache)

    draw_surface.blit(surface, rect, area=draw_area, special_flags=special_flags)

def draw_rotated_surface(surface, pos, angle, cx=0.5, cy=0.5, ox=0, oy=0, draw_surface_override=None, draw_area=None, special_flags=0):
    if draw_surface_override:
        draw_surface = draw_surface_override
    else:
        draw_surface = g.screen
        
    if angle == 0:
        #blit surface normally if angle == 0
        draw_surface.blit(surface, pos, area=draw_area, special_flags=special_flags)
        return
    else:
        rotated_surface = p.transform.rotate(surface, m.degrees(angle))

    w, h = surface.get_size()
    surface_rect = p.Rect(pos[0], pos[1], w, h)
    anchor_point = surface_rect.x+(cx*w), surface_rect.y+(cy*h)

    anchor_to_center_difference = anchor_point[0]-surface_rect.centerx, anchor_point[1]-surface_rect.centery

    w, h = rotated_surface.get_size()
    rotated_surface_rect = p.Rect(pos[0], pos[1], w, h)

    rotated_anchor_point = rotated_surface_rect.centerx+anchor_to_center_difference[0], rotated_surface_rect.centery+anchor_to_center_difference[1]
    rotated_anchor_point = util.rotate_point(rotated_surface_rect.center, rotated_anchor_point, -angle)

    difference = pos[0]-rotated_anchor_point[0], pos[1]-rotated_anchor_point[1]
    rotated_surface_rect.x += difference[0]+(surface_rect.w*ox)
    rotated_surface_rect.y += difference[1]+(surface_rect.h*oy)
    draw_surface.blit(rotated_surface, rotated_surface_rect, area=draw_area, special_flags=special_flags)

def draw_rotated_graphics(graphics, pos, angle, cx=0.5, cy=0.5, ox=0, oy=0, draw_surface_override=None, draw_area=None, special_flags=0):
    surface = get_surface(graphics)
    return draw_rotated_surface(surface, pos, angle, cx=cx, cy=cy, ox=ox, oy=oy, draw_surface_override=draw_surface_override, draw_area=draw_area, special_flags=special_flags)

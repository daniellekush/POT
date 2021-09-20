# cython: profile=True
# cython: language_level=3
# cython: infer_types=True

import global_values as g
import utilities as util
import events
import graphics as gfx

import pygame as p
import inspect
import math as m

#abstact parent class for basically anything in the game
class Game_Object():
    def __init__(self, rect, **_kwargs):
        self.rect = p.Rect(rect)
        #x, y, width, height attributes are needed since pygame rect can only store int values
        self.x = self.rect.x
        self.y = self.rect.y
        self.old_x = self.x
        self.old_y = self.y

        self.width = self.rect.w
        self.height = self.rect.h

        self.old_width = self.width
        self.old_height = self.height

        self.mask_collision = False

        #velocity attributes
        self.vx = 0
        self.vy = 0
        self.real_vx = 0
        self.real_vy = 0
        self.vx_keep = 0
        self.vy_keep = 0
        self.max_v = None
        max_v = 3
        self.max_vx = max_v
        self.max_vy = max_v
        self.set_max_vx(self.max_vx)
        self.set_max_vy(self.max_vy)

        #once a velocity component (absolutely) drops below this point, it will be set to 0
        self.min_v_dropoff = 0.001
        self.min_v = None
        
        self.static = False

        #graphics attributes
        self.visible = True
        self.graphics = None
        self.surface = None
        self.cache_surfaces = True
        self.angle = 0
        self.draw_bias = 0

        self.temp = False

        self.pipe = events.Pipe(str(self))

        kwargs = {"parent":None}
        kwargs.update(_kwargs)
    
        #parent/children attributes
        self.parent = None
        if kwargs["parent"]:
            self.set_parent(kwargs["parent"])
        self.children = []

        self.__dict__.update(**kwargs)

        if "max_v" in kwargs.keys():
            self.set_max_v(kwargs["max_v"])
        if "max_vx" in kwargs.keys():
            self.set_max_vx(kwargs["max_vx"])
        if "max_vy" in kwargs.keys():
            self.set_max_vy(kwargs["max_vy"])
                
        self.v_direction = util.get_angle(0, 0, self.vx, self.vy)
        self.v_mag = util.get_distance(0,0,self.vx,self.vy)
        self.update_mask()

        self.deleted = False

        self.class_aliases = set()
        for cls in inspect.getmro(self.__class__):
            self.class_aliases.add("class_"+cls.__name__)

        self.id = g.game_object_next_id
        g.game_object_next_id += 1

        if not self.temp:
            self.add_to_game()

    def add_to_game(self):
        for alias in self.class_aliases:
            if alias in g.game_objects.keys():
                g.game_objects[alias].append(self)
            else:
                g.game_objects.update({alias:[self]})

    def set_max_v(self, value):
        self.max_v = value
        if self.max_v is not None:
            self.set_max_vx(value)
            self.set_max_vy(value)
        

    def set_max_vx(self, value):
        self.max_vx = value
        if self.max_vx is not None:
            self.max_positive_vx = value
            self.max_negative_vx = -value
        else:
            self.max_positive_vx = None
            self.max_negative_vx = None

    def set_max_vy(self, value):
        self.max_vy = value
        if self.max_vy is not None:
            self.max_positive_vy = value
            self.max_negative_vy = -value
        else:
            self.max_positive_vy = None
            self.max_negative_vy = None

    def set_parent(self, parent):
        self.parent = parent
        self.parent.children.append(self)

    def remove_parent(self):
        self.parent.children.remove(self)
        self.parent = None

    def remove_child(self, child):
        child.remove_parent()

    #make the centerpoint of the Game_Object a given point
    def center(self, center):
        if isinstance(center, Game_Object):
            center = center.rect.center
    
        self.rect.center = center
        self.x = self.rect.x
        self.y = self.rect.y

    #get distance/angle between game object and other things
    def get_distance(self, x, y):
        dist = util.get_distance(self.rect.centerx, self.rect.centery, x, y)
        return dist

    def get_distance_game_obj(self, game_obj):
        dist = util.get_distance(self.rect.centerx, self.rect.centery, game_obj.rect.centerx, game_obj.rect.centery)
        return dist

    def get_angle(self, x, y):
        angle = util.get_angle(self.rect.centerx, self.rect.centery, x, y)
        return angle

    def get_angle_game_obj(self, game_obj):
        angle = util.get_angle(self.rect.centerx, self.rect.centery, game_obj.rect.centerx, game_obj.rect.centery)
        return angle

    #set rect values based off of position and dimensions
    def update_rect(self):
        self.rect.x = int(self.x)
        self.rect.y = int(self.y)
        self.rect.width = int(self.width)
        self.rect.height = int(self.height)

    #"offical" way to set x and y coords
    #could be overwritten by game objects wishing to use it
    def set_x(self, x):
        self.x = x

    def set_y(self, y):
        self.y = y

    #set x and y coords based on a rectangle (the Game_Object's rectangle if no arguments are specified)
    def set_from_rect(self, rect=None, update_children=True, keep_decimal_component=True):
        old_x = self.x
        old_y = self.y
        if not rect:
            rect = self.rect

        if keep_decimal_component:
            self.x = rect.x+(self.x%1)
            self.y = rect.y+(self.y%1)
            self.width = rect.width+(self.width%1)
            self.height = rect.height+(self.height%1)
        else:
            self.x = rect.x
            self.y = rect.y
            self.width = rect.width
            self.height = rect.height
            
        self.rect = rect.copy()
        
        if update_children:
            change_x = self.x-old_x
            change_y = self.y-old_y
            self.update_children(old_x, old_y)
            
        self.update_rect()

    def update_from_parent(self, change_x, change_y):
        self.set_x(self.x+change_x)
        self.set_y(self.y+change_y)

    def update_children(self, change_x, change_y):
        for child in self.children:
            child.update_from_parent(change_x, change_y)

    def update_mask(self):
        if self.mask_collision and self.surface:
            self.collision_mask = p.mask.from_surface(self.surface)
        else:
            self.collision_mask = p.mask.Mask((self.width, self.height))
            self.collision_mask.fill()

    def clamp_velocity(self):
        #if velocity is very low set it to 0
        if abs(self.vx) <= self.min_v_dropoff:
            self.vx = 0
        if abs(self.vy) <= self.min_v_dropoff:
            self.vy = 0

        #gradient must be maintained while capping velocity

        if self.vx or self.vy:
            self.v_direction = util.get_angle(0, 0, self.vx, self.vy)
            self.v_mag = util.get_magnitude(self.vx,self.vy)
                    
            #cap velocity if it is too high
            if self.max_v is not None:
                if self.v_mag > self.max_v: #too high
                    self.vx = m.cos(self.v_direction)*self.max_v
                    self.vy = m.sin(self.v_direction)*self.max_v
                    
            else:
                if self.vx > self.max_positive_vx:
                    self.vx = self.max_positive_vx
                if self.vx < self.max_negative_vx:
                    self.vx = self.max_negative_vx
                if self.vy > self.max_positive_vy:
                    self.vy = self.max_positive_vy
                if self.vy < self.max_negative_vy:
                    self.vy = self.max_negative_vy

            if self.min_v is not None:
                if self.v_mag < self.min_v: #too low
                    self.vx = m.cos(self.v_direction)*self.min_v
                    self.vy = m.sin(self.v_direction)*self.min_v
                
        else:
            if self.max_v is not None:
                if abs(self.vx) > self.max_v:
                    self.vx = self.max_v*(self.vx/abs(self.vx))
                if abs(self.vy) > self.max_v:
                    self.vy = self.max_v*(self.vy/abs(self.vy))
            else:
                if self.vx > self.max_positive_vx:
                    self.vx = self.max_positive_vx
                if self.vx < self.max_negative_vx:
                    self.vx = self.max_negative_vx
                if self.vy > self.max_positive_vy:
                    self.vy = self.max_positive_vy
                if self.vy < self.max_negative_vy:
                    self.vy = self.max_negative_vy

            
    def slow_velocity(self):
        self.vx *= self.vx_keep
        self.vy *= self.vy_keep

    def update_position_and_velocity(self):
        self.clamp_velocity()
        self.move(self.vx, self.vy)
        self.slow_velocity()

    def update(self):
        if self.width != self.old_width or self.height != self.old_height:
                self.update_mask()

        if not self.static:
            #update position and velocity
            self.update_position_and_velocity()
        else:
            pass

        self.update_rect()
        
        

    #get all the g.events targetting this entity
    #kinda weird IDK if it will work
    def get_events(self, event_type=None, full=False):
        obtained_events = [] 
        for event in g.events:
            if event in self.pipe.events:
                obtained_events.append(event)
            else:
                if full:
                    if self in event.__dict__.values():
                        obtained_events.append(self)
                else:
                    if hasattr(event, "entity") and event.entity == self:
                        obtained_events.append(self)
                    elif hasattr(event, "target") and event.target == self:
                        obtained_events.append(self)
                    
        return obtained_events
            
    def clear_events(self, event_type=None, full=False):
        for event in self.get_events(event_type, full=full):
            event.delete()

    #this should be overwritten by classes utilising more complex 
    def move(self, ax, ay):
        self.x += ax
        self.y += ay
        self.update_rect()

    def draw(self):
        if self.graphics:
            self.surface = gfx.get_surface(self.graphics)
            
        if self.surface:
            #TODO, test whether pygame will accept non-whole numbers in scale instructions
            draw_surface = gfx.scale_surface(self.surface, (self.rect.w, self.rect.h), cache=self.cache_surfaces)
            gfx.draw_rotated_surface(draw_surface, self.rect.topleft, self.angle, cx=0.5, cy=0.5, ox=0.5, oy=0.5)
        
    def set_old_properties(self):
        self.old_x = self.x
        self.old_y = self.y
        self.old_width = self.width
        self.old_height = self.height

    def delete(self, reason=None):
        if not self.deleted:
            self.deleted = True
            if not self.temp:
                for alias in self.class_aliases:
                    g.game_objects[alias].remove(self)
            self.clear_events()
            self.pipe.delete()

            if self.parent:
                self.parent.children.remove(self)

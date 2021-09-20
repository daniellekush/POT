# cython: profile=True
# cython: language_level=3
# cython: infer_types=True

import global_values as g
import utilities as util
import entities
import graphics as gfx

import pygame as p
import math as m
        
class Camera(entities.Entity):
    def __init__(self, rect, **_kwargs):
        self.rect = rect
        self.update_scale()
        
        kwargs = {"vx_keep":0.95, "vy_keep":0.95, "gravity_strength":0, "visible":False, "static":False, "solid":False, "max_v":100}
        kwargs.update(_kwargs)
        entities.Entity.__init__(self, rect, **kwargs)

        self.update_scale()  
        self.update()

    def keep_ratio(self, dimension, ratio=g.ASPECT_RATIO, rect=None):
        if rect:
            c = rect.center
            if dimension == "x":
                rect.height = rect.width/ratio
            elif dimension == "y":
                rect.width = rect.height*ratio
            rect.center = c
            return rect
        else:
            c = self.rect.center
            if dimension == "x":
                self.rect.height = self.rect.width/ratio
            elif dimension == "y":
                self.rect.width = self.rect.height*ratio
            self.rect.center = c
            self.set_from_rect()

    def change_scale(self):
        g.clear_surface_cache()

    def update(self):
        entities.Entity.update(self)
        self.update_scale()

        if self.width != self.old_width or self.height != self.old_height:
            self.change_scale()

    def update_segments(self):
        self.segments.clear()
        for level in g.active_levels:
            if level.enable_segmenting:
                for segment in level.get_segments(self.rect):
                    segment.entities.add(self)
                    self.segments.add(segment)

    def update_scale(self):
        self.scale_x = g.WIDTH/self.rect.width
        self.scale_y = g.HEIGHT/self.rect.height

    def update_rect(self):
        entities.Entity.update_rect(self)
        self.screen_x, self.screen_y = self.reverse_transform_point(0,0)

    def set_from_rect(self, rect=None):
        entities.Entity.set_from_rect(self, rect=rect)

    def move(self, ax, ay, safe_override=None, check=False, start_x_override=None, start_y_override=None):
        if not start_x_override:
            start_x_override = self.screen_x
        if not start_y_override:
            start_y_override = self.screen_y

        self.update_rect()
            
        entities.Entity.move(self, ax, ay, safe_override=safe_override, check=check)

        self.update_rect()


    def scale_1d(self, value, cast_to_int=False, min_1=False):
        new_value = value*(self.scale_x+self.scale_y)/2
        if cast_to_int:
            new_value = int(new_value)
        if min_1:
            new_value = max(new_value, 1)
        return new_value

    def transform_x(self, x):
        new_x = ((x-self.x)*self.scale_x)
        return new_x

    def transform_y(self, y):
        new_y = ((y-self.y)*self.scale_y)
        return new_y

    def reverse_scale_1d(self, value):
        new_value = value*(self.scale_x+self.scale_y)/2
        new_value = (value*2)/(self.scale_x+self.scale_y)
        return new_value

    def reverse_transform_x(self, x):
        new_x = (x/self.scale_x)+self.x
        return new_x

    def reverse_transform_y(self, y):
        new_y = (y/self.scale_y)+self.y
        return new_y

    def transform_point(self, x, y):
        new_x = self.transform_x(x)
        new_y = self.transform_y(y)
        
        return new_x, new_y

    def reverse_transform_point(self, x, y):
        new_x = self.reverse_transform_x(x)
        new_y = self.reverse_transform_y(y)
        
        return new_x, new_y
    
    def transform_rect(self, rect, inflate_extra=True):
        x, y = self.transform_point(rect.left, rect.top)
        width = rect.width*self.scale_x
        height = rect.height*self.scale_y

        rect = p.Rect(int(x), int(y), int(width), int(height))
        if inflate_extra:
            rect.inflate_ip(2,2)
            
        return rect

    def reverse_transform_rect(self, rect):
        x, y = self.reverse_transform_point(rect.left, rect.top)
        width = rect.width/self.scale_x
        height = rect.height/self.scale_y

        rect = p.Rect(int(x), int(y), int(width), int(height))
        return rect

    def check_x_in_screen(self, x):
        new_x = self.transform_x(x)
        if new_x < 0 or new_x > g.WIDTH:
            return False
        else:
            return True

    def check_y_in_screen(self, y):
        new_y = self.transform_y(y)
        if new_y < 0 or new_y > g.HEIGHT:
            return False
        else:
            return True

    def check_point_in_screen(self, x, y):
        new_point = self.transform_point(x, y)
        if new_point[0] < 0 or new_point[1] < 0 or new_point[0] > g.WIDTH or new_point[1] > g.HEIGHT:
            return False
        else:
            return True

    def check_rect_in_screen(self, rect):
        new_rect = self.transform_rect(rect)
        return p.Rect(0,0,g.WIDTH,g.HEIGHT).colliderect(new_rect)

    def check_rect_fully_in_screen(self, rect):
        new_rect = self.transform_rect(rect)
        return p.Rect(0,0,g.WIDTH,g.HEIGHT).contains(new_rect)

    def draw_transformed_surface(self, surface, rect, angle=0, cx=0.5, cy=0.5, ox=0, oy=0):
        new_rect = self.transform_rect(rect)
        
        new_surface = gfx.scale_surface(surface, (new_rect.w, new_rect.h))

        if angle:
            gfx.draw_rotated_surface(new_surface, rect.topleft, angle, cx=cx, cy=cy, ox=ox, oy=oy)
        else:
            g.screen.blit(new_surface, new_rect)

    def draw_transformed_rect(self, colour, rect, border=0):
        rect = self.transform_rect(rect)
        p.draw.rect(g.screen, colour, rect, border)

    def draw_transformed_ellipse(self, colour, rect, border=0):
        rect = self.transform_rect(rect)
        p.draw.ellipse(g.screen, colour, rect, border)

    def draw_transformed_line(self, colour, p1, p2, width=1):
        transformed_p1 = self.transform_point(p1[0], p1[1])
        transformed_p2 = self.transform_point(p2[0], p2[1])
        p.draw.line(g.screen, colour, transformed_p1, transformed_p2, width)
        
    #draw an arrow
    #arrow_angle_difference shows how narrow or wide the arrow is
    def draw_transformed_arrow(self, colour, p1, p2, arrow_angle_difference, arrow_width, width=1, tip_colour=None):
        if not tip_colour:
            tip_colour = colour
            
        angle = util.get_angle(p1[0], p1[1], p2[0], p2[1])
        
        arrow_angle1 = angle-arrow_angle_difference
        arrow_point1 = util.get_line_end(p2[0], p2[1], arrow_angle1, arrow_width)
        
        arrow_angle2 = angle+arrow_angle_difference
        arrow_point2 = util.get_line_end(p2[0], p2[1], arrow_angle2, arrow_width)
        
        self.draw_transformed_line(colour, p1, p2, width=width)
        self.draw_transformed_line(tip_colour, p2, arrow_point1, width=width)
        self.draw_transformed_line(tip_colour, p2, arrow_point2, width=width)

    def draw_screen_outline(self, colour, border=1):
        transformed_rect = g.camera.transform_rect(self.rect)
        p.draw.rect(g.screen, colour, transformed_rect, border)

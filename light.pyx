# cython: profile=True
# cython: language_level=3
# cython: infer_types=True

from . import entities
from . import graphics as gfx
from . import global_values as g
from . import utilities as util

import pygame as p
import math as m
import random as r
import numpy as np

#light that uses a light mask
class Light(entities.Entity):
    def __init__(self, rect, graphics, **_kwargs):
        kwargs = {"brightness":1, "solid":False}
        kwargs.update(_kwargs)
        kwargs.update({"graphics":graphics})
        entities.Entity.__init__(self, rect, **kwargs)

    def draw(self):
        self.update_surface()
        if g.ENABLE_LIGHTING and self.sprite:
            transformed_rect = g.camera.transform_rect(self.rect)
            transformed_alpha_surface = gfx.scale_surface(self.sprite.get_no_colour(), (transformed_rect.w, transformed_rect.h))
            if g.ENABLE_COLOURED_LIGHTING:
                transformed_colour_surface = gfx.scale_surface(self.sprite.surface, (transformed_rect.w, transformed_rect.h))

            alpha_blit_flags = p.BLEND_RGBA_SUB
            if g.ENABLE_COLOURED_LIGHTING:
                colour_blit_flags = p.BLEND_RGBA_ADD
            
            gfx.draw_rotated_surface(transformed_alpha_surface, transformed_rect.topleft, self.angle, cx=0.5, cy=0.5, ox=0.5, oy=0.5, draw_surface_override=g.darkness_surface, special_flags=alpha_blit_flags)
            if g.ENABLE_COLOURED_LIGHTING:
                gfx.draw_rotated_surface(transformed_colour_surface, transformed_rect.topleft, self.angle, cx=0.5, cy=0.5, ox=0.5, oy=0.5, draw_surface_override=g.light_colour_surface, special_flags=colour_blit_flags)


class Light_Grid():
    def __init__(self, level, gw, gh, min_light_level=0, max_light_level=1):

        self.gw = gw
        self.gh = gh
        
        self.level = level

        self.light_rects = []
        self.light_rect_list = []
        
        self.active_light_rects = []

        #light rects that were changed from the default light level last frame, these will all get reset during update_lighting()
        self.modified_light_rects = []

        self.g_width = m.ceil(self.level.rect.width/self.gw)
        self.g_height = m.ceil(self.level.rect.height/self.gh)

        #filled mask that is the same size as a grid cell
        self.grid_rect_mask = p.mask.Mask((self.gw, self.gh), fill=True)

        self.min_light_level = min_light_level
        self.max_light_level = max_light_level

        self.lightmap = np.full((self.g_width, self.g_height), 255, dtype='uint32')
        self.update_lighting()

        g.light_grids.add(self)


    def update(self):
        self.update_lighting()

    def update_lighting(self):
        

        #set the bounds of the currently active lights
        self.active_sx = max(int((g.camera.screen_x-self.level.x-1)/self.gw), 0) #must be ints because they are used as indices
        self.active_sy = max(int((g.camera.screen_y-self.level.y-1)/self.gh), 0)
        self.active_ex = min(int(self.active_sx+(g.camera.width//self.gw)+2), self.g_width)
        self.active_ey = min(int(self.active_sy+(g.camera.height//self.gh)+2) , self.g_height)

        self.lightmap[self.active_sx:self.active_ex, self.active_sy:self.active_ey] = 255

    def clamp_lighting(self):
        np.clip(self.lightmap[self.active_sx:self.active_ex, self.active_sy:self.active_ey],\
                255-int(self.max_light_level*255),\
                255-int(self.min_light_level*255),\
                out=self.lightmap[self.active_sx:self.active_ex, self.active_sy:self.active_ey])

        

    def draw(self):
        box_func = p.gfxdraw.box
        
        #create draw rect
        d_tw = (self.gw*g.camera.scale_x)
        d_th = (self.gh*g.camera.scale_y)
            
        d_ty = g.camera.transform_y(self.level.y)+(self.active_sy*d_th)

        dx = g.camera.transform_x(self.level.x)+(self.active_sx*d_tw)
        dy = d_ty
            
        draw_rect = p.Rect(0,
                            0,                               
                            d_tw,
                            d_th
                            )

        #due to the way that rectangles don't deal with subpixels, it is sometimes nessecary to draw a slightly shifted, inflated rect
        inflated_draw_rect_x = p.Rect(0,
                            0,                               
                            d_tw+1,
                            d_th
                            )

        inflated_draw_rect_y = p.Rect(0,
                            0,                               
                            d_tw,
                            d_th+1
                            )

        inflated_draw_rect_xy = p.Rect(0,
                            0,                               
                            d_tw+1,
                            d_th+1
                            )

            

        #draw_rect.x = dx
        old_dx = dx

        y_range = range(self.active_sy,self.active_ey)
            
        for x in range(self.active_sx,self.active_ex):
                

            old_dy = d_ty-d_th
            dy = d_ty

            inflate_x = old_dx%1 > dx%1 and dx >= 0

                

            #weird black line prevention
            if dx < 0:
                dx -= 1

            draw_rect.x = dx
            inflated_draw_rect_x.x = dx-1
            inflated_draw_rect_y.x = dx
            inflated_draw_rect_xy.x = dx-1
                

            if inflate_x:
                for y in y_range:
                    inflate_y = old_dy%1 > dy%1 and dy >= 0

                    #weird black line prevention
                    if dy < 0:
                        dy -= 1

                    #draw the correct rects
                    if inflate_y:
                        inflated_draw_rect_xy.y = dy-1
                        
                        box_func(g.screen, inflated_draw_rect_xy, (0,0,0, self.lightmap[x,y]))
                    else:
                        inflated_draw_rect_x.y = dy
                        box_func(g.screen, inflated_draw_rect_x, (0,0,0,self.lightmap[x,y]))

                    #weird black line prevention
                    if dy < 0:
                        dy += 1

                    old_dy = dy
                    dy += d_th
            else:
                for y in y_range:
                    inflate_y = old_dy%1 > dy%1 and dy >= 0

                    #weird black line prevention
                    if dy < 0:
                        dy -= 1

                    #draw the correct rects
                    if inflate_y:
                        inflated_draw_rect_y.y = dy-1
                        box_func(g.screen, inflated_draw_rect_y, (0,0,0,self.lightmap[x,y]))
                    else:
                        draw_rect.y = dy
                        box_func(g.screen, draw_rect, (0,0,0,self.lightmap[x,y]))
                    #weird black line prevention
                    if dy < 0:
                        dy += 1

                    old_dy = dy
                    dy += d_th

            #weird black line prevention
            if dx < 0:
                dx += 1

            old_dx = dx
            dx += d_tw

class Light_Rect():
    def __init__(self, rect, light_level=0, min_light_level=0, max_light_level=1):
        
        self.rect = rect

        self.light_level = 0
        self.min_light_level = min_light_level
        self.max_light_level = max_light_level
                
        self.set_light_level(light_level)


    #sets the light level of the rect, but will only update the surfaces if the value has changed
    #force forces the surfaces to be updated
    def set_light_level(self, value):
        value = util.clamp(value, self.min_light_level, self.max_light_level)
        if value != self.light_level:
            self.light_level = value
            self.light_alpha = 255-(self.light_level*255)

    def increase_light_level(self, value):
        self.set_light_level(self.light_level+value)
        

    #broken probably because of pixel gaps
    def draw(self):
        if self.light_level < 1:
            g.camera.draw_transformed_surface(self.surface, self.rect)


    def quick_draw(self, rect):#, inflate_x=False, inflate_y=False):
        if self.light_level < 1:
            p.gfxdraw.box(g.screen, rect, (0,0,0,self.light_alpha))
            #if inflate_x:
            #    if inflate_y:
            #        surface = self.surface_inflated_xy
            #    else:
            #        surface = self.surface_inflated_x
            #elif inflate_y:
            #    surface = self.surface_inflated_y
            #else:
            #    surface = self.surface#gfx.scale_graphics(self.surface, (rect.width, rect.height))


            #g.screen.blit(surface, rect)#, special_flags=p.BLEND_ALPHA_SDL2)

#Light source that uses a light grid
#check_collision is used to determine whether level collision is taken into account when calculating lightmap
#setting check_collision to False will naturally increase performance
class Light_Grid_Source(entities.Entity):
    def __init__(self, light_grid, x, y, brightness, radius, **_kwargs):
        kwargs = {"check_collision":False, "solid":False, "visible":True}
        kwargs.update(_kwargs)

        self.light_grid = light_grid
        self.radius = radius
        self.brightness = brightness

        rect = p.Rect(x-self.radius, y-self.radius, self.radius*2, self.radius*2)
        entities.Entity.__init__(self, rect, **kwargs)

        self.update_lightmap()

    def update_brightness(self, value):
        if self.brightness != value:
            self.brightness = value
            self.update_lightmap()

    def update_radius(self, value):
        if self.radius != value:
            self.radius = value
            self.update_lightmap()

    def update_lightmap(self):
        #figure out the bounds of the lightmap
        self.sx = max(self.rect.x//self.light_grid.gw,0)
        self.sy = max(self.rect.y//self.light_grid.gh,0)
        self.ex = min(int(m.ceil(self.rect.right/self.light_grid.gw)),self.light_grid.g_width-1)
        self.ey = min(int(m.ceil(self.rect.bottom/self.light_grid.gh)) ,self.light_grid.g_height-1)

        cx = self.rect.centerx/self.light_grid.gw
        cy = self.rect.centery/self.light_grid.gh

        self.width_range = range(self.sx, self.ex)
        self.height_range = range(self.sy, self.ey)

        self.lightmap = np.zeros((self.ex-self.sx, self.ey-self.sy), dtype='uint32')

        if self.check_collision:

            self.light_hit_rects = [] #tests
            self.ray_step_points = []
            
            rect = p.Rect(0,0,2,2)
            #attempt to fire rays from center to target positions

            ray_amount = 180
            ray_hit_threshold = (self.light_grid.gw+self.light_grid.gh)/2 *1 #not a typo
            
            angle = 0
            for i in range(ray_amount):
                
                
                distance = self.radius

                step_dist = (self.light_grid.gw+self.light_grid.gh)/2 /2
                
                dx = m.cos(angle)*step_dist
                dy = m.sin(angle)*step_dist

                x,y = self.rect.center

                #check for collision
                for step in range(int(distance//step_dist)):
                    rect.centerx = x#((x//self.light_grid.gw)+0.5)*self.light_grid.gw
                    rect.centery = y#((y//self.light_grid.gh)+0.5)*self.light_grid.gh
                    colliding = g.current_level.check_collision(rect, self.light_grid.grid_rect_mask)

                    

                    #set lightmap rect value, if ray is close enough to the lightmap rect center
                    if True:
                        self.ray_step_points.append((x,y))
                    
                        cell_distance = max(util.get_distance((x//self.light_grid.gw)+0.5, (y//self.light_grid.gh)+0.5, cx, cy ),0.1)
                        brightness = self.brightness/(cell_distance**2)
                        
                        #brightness_frac = brightness* (1-(util.get_distance(x, y, g.current_level.get_tile(x,y).rect.centerx, g.current_level.get_tile(x,y).rect.centery)/ray_hit_threshold))
                        
                        self.lightmap[int(x//self.light_grid.gw)-self.sx, int(y//self.light_grid.gh)-self.sy] = util.clamp(int(brightness*255),0,255)

                        #break on collision
                        if colliding:
                        
                            self.light_hit_rects.append(rect.copy())
                            break
                    x += dx
                    y += dy

                if not colliding:
                    self.light_hit_rects.append(rect.copy())

                angle += 2*m.pi/ray_amount

        else:
            for x in self.width_range:
                for y in self.height_range: 
                    distance = max(util.get_distance(x+0.5, y+0.5, cx, cy),0.1)
                    brightness = self.brightness/(distance**2)
                
                    self.lightmap[x-self.sx, y-self.sy] = util.clamp(int(brightness*255),0,255)


        


    def update(self):
        entities.Entity.update(self)

        
        if self.real_vx or self.real_vy or self.width != self.old_width or self.height != self.old_height:
            self.update_lightmap()


        self.light_grid.lightmap[self.sx:self.ex, self.sy:self.ey] -= self.lightmap

    def draw(self):
        #g.camera.draw_transformed_rect(g.RED, self.rect, 3)
        #for target in self.targets:
        #    g.camera.draw_transformed_line(g.RED, self.rect.center, target, 3)

        ##for rect in self.light_hit_rects:
        ##    g.camera.draw_transformed_line(g.RED, self.rect.center, rect.center, 3)
        ##    g.camera.draw_transformed_rect(g.GREEN, rect)

        #rect = p.Rect(0,0,2,2)
        #for point in self.ray_step_points:
        #    rect.center = point
        #    g.camera.draw_transformed_ellipse(g.BLUE, rect)
        pass
        
""" update the lightmap all Light_Grid_Source objects that collide with a given rectangle """
def update_grid_lights_in_rect(grid, rect):
    pass
        

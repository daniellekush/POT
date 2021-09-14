import utilities as util
import global_values as g
import entities
import interface_components as ic
import events

import pygame as p
import numpy as np
import math as m
import random as r

#Particle spawner
#doesn't use entities because circular imports suck
class Particles():
    def __init__(self, pos, angle, spread, speed, amount, size, **_kwargs):
        
        
        kwargs = {"colour":g.RED, "timer":g.MAX_TICK_RATE*2, "high_quality":False, "vx_keep":0.995, "vy_keep":0.995, "start_vx":0, "start_vy":0, "static":True, "min_speed":0, "max_speed":1, "style":"rect"}
        kwargs.update(_kwargs)


        self.rect = p.Rect(pos[0], pos[1], 1, 1)
        self.x, self.y = self.rect.topleft

        self.__dict__.update(kwargs)

        self.angle = angle
        self.spread = spread
        self.speed = speed
        self.max_amount = amount
        
        self.size = size
        self.death_event = None
        
        self.reset()
            
    def reset(self, reset_timer=True):
	    self.amount = 0
	    
	    self.particles_x = np.empty(self.max_amount)
        self.particles_x.fill(self.rect.centerx)
        
        self.particles_y = np.empty(self.max_amount)
        self.particles_y.fill(self.rect.centery)

        self.particles_vx = np.empty(self.max_amount)
        self.particles_vy = np.empty(self.max_amount)

        for particle in range(self.max_amount):
            self.spawn_particle()
            
        if reset_timer:
            #set death timer
            if self.timer is not None:
	            if self.death_event:
		            self.death_event.timer = self.timer
		        else:
                    self.death_event = events.Delete_Event(self, self, self.timer)
            
    def spawn_particle(self):
	    spread = (r.random()*(self.spread))-(self.spread/2)
        angle = self.angle+spread


        speed = util.clamp(r.random(), self.min_speed, self.max_speed)
        vx = self.start_vx+(m.cos(angle)*speed*self.speed)
        vy = self.start_vy+(m.sin(angle)*speed*self.speed)

        self.particles_vx[self.amount] = vx
        self.particles_vy[self.amount] = vy
        
        self.amount += 1

    def delete(self):
        g.particle_spawners.remove(self)

    def update(self):
        #update positioning
        self.rect.x = self.x
        self.rect.y = self.y
        
        #deal with particles
        np.add(self.particles_x, self.particles_vx, out=self.particles_x)
        np.add(self.particles_y, self.particles_vy, out=self.particles_y)
        
        self.particles_vx *= self.vx_keep
        self.particles_vy *= self.vy_keep

        np.clip(self.particles_vx, -self.max_vx, self.max_vx, out=self.particles_vx)
        np.clip(self.particles_vy, -self.max_vy, self.max_vy, out=self.particles_vy)
        
        for level in g.active_levels:
            if level.rect.collidepoint(self.rect.center):
                self.particles_vx += level.gx*self.gravity_strength
                self.particles_vy += level.gy*self.gravity_strength
            
    def draw(self):
        size = g.camera.scale_1d(self.size)

        #ugly but what else can you do?
        if self.style == "circle":
            for i in range(self.max_amount):
                if not np.isnan(self.particles_x[i]):
                    x, y = g.camera.transform_point(self.particles_x[i], self.particles_y[i])
                    if not self.high_quality and ((x < 0 or x > g.WIDTH) or (y < 0 or y > g.HEIGHT)):
	                    #delete particle
                        self.particles_x[i] = np.NaN
                        self.particles_y[i] = np.NaN
                        self.amount -= 1
                        
                    else:
                        p.draw.circle(g.screen, self.colour, (int(x), int(y)), size)
        else:
            draw_rect = p.Rect(0,0,size,size)
            for i in range(self.max_amount):
                if not np.isnan(self.particles_x[i]):
                    x, y = g.camera.transform_point(self.particles_x[i], self.particles_y[i])
                    if not self.high_quality and ((x < 0 or x > g.WIDTH) or (y < 0 or y > g.HEIGHT)):
	                    #delete particle
                        self.particles_x[i] = np.NaN
                        self.particles_y[i] = np.NaN
                        self.amount -= 1
                        
                    else:
                        draw_rect.center = (x,y)
                        p.draw.rect(g.screen, self.colour, draw_rect)

            

#simple class for creating simple rain
class Rain(ic.Interface_Component):
    def __init__(self, speed, timer, size, **_kwargs):
        self.speed = speed
        self.max_timer = timer
        self.size = size

        self.timer = 0
        
        kwargs = {"colour":g.BLUE, "screen_extension":250, "max_particles":100, "timer":g.MAX_TICK_RATE*2,
                  "speed":6, "wind_speed":0, "vy_variance":2, "vx_multiplier_variance":0.2,
                  "draw_bias":9998, "visible":True}
        kwargs.update(_kwargs)
        ic.Interface_Component.__init__(self, p.Rect(0,0,g.WIDTH,g.HEIGHT), {"main"}, **kwargs)

        #index into the particles arrays where a new particle can go
        self.available_space = 0
        

        self.reset()

    #delete all current particles
    #if fill is set to True, then more particles will be added
    def reset(self, fill=False):
        self.available_space = 0
        
        entities.Entity.reset(self)
        self.particles_x = np.empty(self.max_particles)
        self.particles_x.fill(np.NaN)
        
        self.particles_y = np.empty(self.max_particles)
        self.particles_y.fill(np.NaN)

        self.particles_vx_multiplier = np.random.uniform(0, self.vx_multiplier_variance, self.max_particles)

        #create the particle velocity arrays
        self.particles_vx = np.empty(self.max_particles)
        self.set_wind_speed(self.wind_speed)
        
        self.particles_vy = self.speed+np.random.uniform(-self.vy_variance/2, self.vy_variance/2, self.max_particles)

        if fill:
            for particle in range(self.max_particles):
                self.spawn_particle(random_y=True)

    def on_activate(self):
        ic.Interface_Component.on_activate(self)
        self.reset(fill=True)

    #spawn a single particle
    #if random_y is True then the particle will spawn at a random x/y position
    #otherwise it will spawn at the top limit, with a random x position
    def spawn_particle(self, random_y=False):
            
        if self.available_space < self.max_particles-1:
            
            self.available_space += 1
        else:
            self.available_space = 0


        new_particle_index = self.available_space

        x = r.randint(-self.screen_extension, g.WIDTH+self.screen_extension)
        if random_y:
            y = r.randint(-self.size, g.HEIGHT+self.screen_extension)
        else:
            y = -self.size

        self.particles_x[new_particle_index ] = x
        self.particles_y[new_particle_index ] = y

    def update(self):
        ic.Interface_Component.update(self)

        
        self.timer += 1
        while self.timer >= self.max_timer:
            self.timer -= self.max_timer
            self.spawn_particle()

        #change particle positions
        np.add(self.particles_x, self.particles_vx, out=self.particles_x)
        np.add(self.particles_y, self.particles_vy, out=self.particles_y)

        #add additional movement to prevent speed illusions related to camera movement
        if g.camera.real_vx:
            self.particles_x -= g.camera.real_vx/2

        if g.camera.real_vy < 0:
            self.particles_y -= g.camera.real_vy/2


    #used to modify particle vx when wind speed changes
    def set_wind_speed(self, val):
        #subtract old speed and add new speed
        self.wind_speed = val
        self.particles_vx.fill(self.wind_speed)
        self.particles_vx *= self.particles_vx_multiplier
        
    #draw the particles onscreen
    #it is important to note that out-of-frame particles are also NaN'd in this function
    #this is done to speed things up by only using one particle iteration loop
    def draw(self):
        rect = p.Rect(0, 0, int(self.size/4), int(self.size))
        #reference box_func in it's own variable for minor speedup
        box_func = p.gfxdraw.box
        for i in range(self.max_particles):
            rect.x = self.particles_x[i]
            rect.y = self.particles_y[i]
            box_func(g.screen, rect, self.colour)
            

        #p.draw.circle(g.screen, self.colour, (int(self.particles_x[i]), int(self.particles_y[i]) ), self.size)  
            
        ic.Interface_Component.draw(self)

import global_values as g
import utilities as util

import entities

import math as m
import random as r

class Creature(entities.Entity):
    def __init__(self, name, rect, animation_system, max_health, move_speed, max_move_speed, **_kwargs):
        kwargs = {"solid":True, "collision_dict":{}, "cw":1, "ch":1}
        kwargs.update(_kwargs)
        
        entities.Entity.__init__(self, rect, **kwargs)
        self.name = name
        
        self.max_health = max_health
        self.health = self.max_health

        self.move_speed = move_speed

        #the current action of a Creature will determine it's logic and g.animations
        self.current_actions = frozenset(["static"])
        self.graphics = animation_system

        self.self_vx = 0
        self.self_vy = 0
        self.self_vx_keep = self.vx_keep
        self.self_vy_keep = self.vy_keep

        self.min_animation_velocity = 0.5

    #check for sightline between this creature and either another creature or a target point
    def check_sightline(self, target, collision_dict=None):
        if collision_dict is None:
            collision_dict = self.collision_dict
            
        if isinstance(target, entiites.Entity):
            target = target.rect.midpoint

        sightline = check_line_collision(self.rect.midbottom, target, collision_dict, [self])

        return sightline

    def accelerate_self(self, angle, magnitude=None):
	    if magnitude is None:
		    magnitude = self.move_speed
		    
        self.self_vx += m.cos(angle)*magnitude
        self.self_vy += m.sin(angle)*magnitude
            
        v_direction = util.get_angle(0, 0, self.self_vx, self.self_vy)
        v_mag = util.get_magnitude(self.self_vx, self.self_vy)
                    
        #cap velocity if it is too high
        if v_mag > self.move_speed:
            self.self_vx = m.cos(v_direction)*self.move_speed
            self.self_vy = m.sin(v_direction)*self.move_speed

    def accelerate_self_cardinal(self, horizontal, vertical, magnitude):
        if horizontal:
            if vertical:
                self.accelerate_self(m.pi/4, magnitude)
            else:
                self.accelerate_self(0, magnitude)
        elif vertical:
            self.accelerate_self(m.pi/2, magnitude)

    def update_position_and_velocity(self):
        self.clamp_velocity()
        self.move(self.vx, self.vy)
        self.move(self.self_vx, self.self_vy)
        self.slow_velocity()

    def change_health(self, amount):
        self.health += amount
        if self.health > self.max_health:
            self.health = self.max_health
        elif self.health <= 0:
            self.delete()

    def delete(self):
        entities.Entity.delete(self)
        
    def set_action(self):
        self.current_actions = set()
    
    def set_animation(self):
        self.graphics.set_animation(self.current_actions)

    def update(self):
        entities.Entity.update(self)
        self.set_action()

    def slow_velocity(self):
        entities.Entity.slow_velocity(self)
        self.self_vx *= self.self_vx_keep
        self.self_vy *= self.self_vy_keep

    def die(self):
        self.delete()

    def draw(self):
        self.set_animation()
        entities.Entity.draw(self)


class Player(Creature):
    def __init__(self, rect, animation_system, health, acceleration, **_kwargs):
        kwargs = {"cw":1, "ch":0.5, "overwrite_player":True}
        kwargs.update(_kwargs)

        if kwargs["overwrite_player"]:
            if g.player:
                g.player.delete()
            g.player = self

        del kwargs["overwrite_player"]

        
        Creature.__init__(self, "player", rect, animation_system, health, acceleration, acceleration, **kwargs)

        

    def update(self):
        Creature.update(self)
        self.set_action()

    def set_action(self):
        self.current_actions = set()
                
        diagonal_limit = 1
        if self.self_vx < -self.min_animation_velocity:
            if self.self_vy < -diagonal_limit:
                self.current_actions.add("upleft")
            elif self.self_vy > diagonal_limit:
                self.current_actions.add("downleft")
            else:
                self.current_actions.add("left")

        elif self.self_vx > self.min_animation_velocity:
            if self.self_vy < -diagonal_limit:
                self.current_actions.add("upright")
            elif self.self_vy > diagonal_limit:
                self.current_actions.add("downright")
            else:
                self.current_actions.add("right")

        elif self.self_vy < -self.min_animation_velocity:
            self.current_actions.add("up")
        elif self.self_vy > self.min_animation_velocity:
            self.current_actions.add("down")
        else:
            self.current_actions.add("static")

        self.current_actions = frozenset(self.current_actions)
            
    def move_to_spawn_point(self):
        spawn_points = g.current_level.get_tagged_structures(set("player_spawn_point"))
        chosen_spawn_point = r.choice(spawn_points)
        self.rect.center = chosen_spawn_point.rect.center
        self.set_from_rect()

        g.camera.center(self)

    def draw(self):
        Creature.draw(self)

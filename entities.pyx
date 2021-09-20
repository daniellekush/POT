# cython: profile=True
# cython: language_level=3
# cython: infer_types=True

import global_values as g
import utilities as util
import graphics as gfx
import game_objects
import levels
import events

import pygame as p
import math as m

#abstract parent class for g.game_objects["class_Entity"]
class Entity(game_objects.Game_Object):
    def __init__(self, rect, **_kwargs):

        #how much the entity is affected by gravity
        self.gravity_strength = 1
        
        #collision attributes
        self.cw = 1
        self.ch = 1
        self.bounce_vx = 0
        self.bounce_vy = 0
        self.solid = True
        self.collision_exceptions = []
        self.safe_movement = True
        self.segments = set()
        self.push_bias = 0
        self.push_velocity_transfer = 0.2

        #used for platformers and the like. How much units up an entity can "bump" while moving horizontally
        #makes things such as steps and ramps easier
        self.bump_amount = 10
        #how high each bump attempt moves the entity
        #if bump_amount = 10 and bump_size = 2, then the entity will try and bump 5 times
        self.bump_step = 2

        #the anchor on the normal rect
        self.collide_rect_anchor_point = (0.5, 1)
        #the anchor ON the collide rect
        self.collide_rect_anchor_point_c = (0.5, 1)
        #the last thing this entity collided with
        self.last_collision = None

        #ground attributes
        self.check_grounded = False
        self.grounded = False
        #how far above collision the entity can be before it is considered "grounded"
        #it is recommended to set this decently high for players to make platforming feel responsive
        self.grounded_check_distance = 15
        self.airtime = 0
        self.latest_airtime = 0

        kwargs = {"vx":0, "vy":0, "vx_keep":0.9, "vy_keep":0.9, "max_v":30}
        kwargs.update(_kwargs)
        game_objects.Game_Object.__init__(self, rect, **kwargs)

        self.parent_offset = None
        self.forced_parent = False

        
        self.collision_dict = {"levels":True, "border":True, "camera":False}
        if "collision_dict" in _kwargs.keys():
            self.collision_dict.update(_kwargs["collision_dict"])

        self.update_rect()
        self.update_surface()
        self.update_mask()

    def update_rect(self):
        game_objects.Game_Object.update_rect(self)
        self.collide_rect = p.Rect(0, 0, self.width*self.cw, self.height*self.ch)
        rect_point_x = self.rect.x+(self.collide_rect_anchor_point[0]*self.rect.w)
        rect_point_y = self.rect.y+(self.collide_rect_anchor_point[1]*self.rect.h)

        collide_rect_point_x = (self.collide_rect_anchor_point_c[0]*self.collide_rect.w)
        collide_rect_point_y = (self.collide_rect_anchor_point_c[1]*self.collide_rect.h)

        diff_x = rect_point_x-collide_rect_point_x
        diff_y = rect_point_y-collide_rect_point_y

        self.collide_rect.x += diff_x
        self.collide_rect.y += diff_y

    def set_parent(self, parent, offset=False, forced=False):
        game_objects.Game_Object.set_parent(self, parent)
        self.forced_parent = forced
        
        if offset:
            offset_x = self.rect.centerx-self.parent.rect.centerx
            offset_y = self.rect.centery-self.parent.rect.centery
            self.parent_offset = (offset_x, offset_y)

    def remove_parent(self):
        game_objects.Game_Object.remove_parent(self)
        self.forced_parent = False
        self.parent_offset = None

    def update_from_parent(self, change_x, change_y):
        #print(self, change_x, change_y)
        #print(self.max_v, self.max_positive_vx, self.max_positive_vy)
        if self.forced_parent:
            if self.parent_offset:
                self.set_x(self.rect.centerx+self.parent_offset[0])
                self.set_y(self.rect.centery+self.parent_offset[1])
            else:
                self.set_x(self.x+change_x)
                self.set_y(self.y+change_y)
                    
        else:
            if self.parent_offset:
                ax = (self.parent.rect.centerx+self.parent_offset[0])-self.rect.centerx
                ay = (self.parent.rect.centery+self.parent_offset[1])-self.rect.centery
                self.move(ax, ay)
            else:
                self.move(change_x, change_y)


    def update_mask(self):
        if self.mask_collision and self.surface:
            scaled_surface = gfx.scale_surface(self.surface)
            self.collision_mask = p.mask.from_surface(scaled_surface)
        else:
            self.collision_mask = p.mask.Mask(( int(self.width*self.cw), int(self.height*self.ch)))
            self.collision_mask.fill()

    def set_from_collide_rect(self, rect=None, update_children=True):
        if rect:
            self.collide_rect = rect
        self.rect = p.Rect(0, 0, round(self.collide_rect.w/self.cw), round(self.collide_rect.h/self.ch))
        self.rect.center = self.collide_rect.center
        self.set_from_rect(update_children=update_children)

    def reset(self):
        pass

    def update(self):
        #print(type(self))
        game_objects.Game_Object.update(self)

        #apply gravity
        if not self.static:
            gx, gy = levels.get_gravity(self.collide_rect)
            self.vx += gx*self.gravity_strength
            self.vy += gy*self.gravity_strength

        if self.check_grounded:
            old_grounded = self.grounded
            self.grounded = util.check_collision(self.collide_rect.move(0,self.grounded_check_distance), self.collision_mask, self.collision_dict, [], obj=self)

            if old_grounded and not self.grounded:
                self.latest_airtime = self.airtime
                self.airtime = 0

            if not old_grounded and self.grounded:
                self.ground()

            if not self.grounded: 
                self.airtime += 1

    def ground(self):
        pass

    def clear_old_segments(self):
        for segment in self.segments:
            segment.entities.remove(self)
        self.segments.clear()

    def update_segments(self):
        self.clear_old_segments()
        for level in g.active_levels:
            if level.enable_segmenting:
                for segment in level.get_segments(self.rect):
                    segment.entities.add(self)
                    self.segments.add(segment)

    def move(self, ax, ay, safe_override=None, check=False, start_x_override=None, start_y_override=None, break_on_collide=False):
        return self.transform(ax, ay, 0, 0, safe_override=safe_override, check=check, start_x_override=start_x_override, start_y_override=start_y_override, break_on_collide=break_on_collide)

    def change_size(self, aw, ah, anchor_point=(0.5, 0.5), safe_override=None, check=False, start_w_override=None, start_h_override=None):
        anchor_x_diff = aw*anchor_point[0]
        anchor_y_diff = ah*anchor_point[1]
        self.transform(-anchor_x_diff, -anchor_y_diff, aw, ah, safe_override=safe_override, check=check, start_w_override=start_w_override, start_h_override=start_h_override)

    #transform entity (with collision check)
    #if the "check" parameter is set to true then the entity is not actually transformed at the end
    #"bump_amount_completed" is used internally for entities that "bump" up objects
    
    def transform(self, double ax, double ay, double aw, double ah, safe_override=None, check=False, start_x_override=None, start_y_override=None, start_w_override=None, start_h_override=None, break_on_collide=False, bump_amount_completed=0):
        if safe_override is not None:
            safe = safe_override
        else:
            safe = self.safe_movement

        def finish_movement():
            change_x = nx-self.x
            change_y = ny-self.y
            change_w = nw-self.width
            change_h = nh-self.height

            if not check:
                for child in self.children:
                    child.update_from_parent(change_x, change_y)

                self.x = nx
                self.y = ny
                self.width = nw
                self.height = nh

                if not can_move_x:
                    self.vx = -self.vx*self.bounce_vx
                if not can_move_y:
                    self.vy = 0

                self.update_rect()

            return change_x, change_y, change_w, change_h, can_move_x, can_move_y

        cdef double nx, ny, nw, nh, sw, sh
        cdef double step_x, step_y, step_w, step_h

        if start_x_override is not None:
            nx = start_x_override
        else:
            nx = self.x

        if start_y_override is not None:
            ny = start_y_override
        else:
            ny = self.y

        if start_w_override is not None:
            nw = start_w_override
        else:
            nw = self.width
            sw = self.width

        if start_h_override is not None:
            nh = start_h_override
        else:
            nh = self.height
            sh = self.height

        can_move_x = True
        can_move_y = True

        #exception variable used instead of just self.collision_exceptions
        exceptions = [self]+self.collision_exceptions

        #return early if non-solid
        if not self.solid:
            nx += ax
            ny += ay
            nw += aw
            nh += ah
            return finish_movement()

        #return from procedure early if no transformation
        if ax == 0 and ay == 0 and aw == 0 and ah == 0:
            return finish_movement()

        #set additional variables needed for movement collision checking
        #compact step calculation method
        steps = m.ceil(max(abs(ax), abs(ay), abs(aw), abs(ah)))
        
        check_rect = self.rect.copy()
        check_rect.w = int((self.rect.w+aw)*self.cw)
        check_rect.h = int((self.rect.h+ah)*self.ch)
        cx_offset = (self.rect.w+aw)*(1-self.cw)
        cy_offset = (self.rect.h+ah)*(1-self.ch)

        step_x = ax/steps
        step_y = ay/steps
        step_w = aw/steps
        step_h = ah/steps

        
        #return from procedure early if object does not collide with other objects when moved directly to end goal
        if not safe:
            check_rect.topleft = (int(self.x+ax+cx_offset), int(self.y+ay+cy_offset))
            colliding = util.check_collision(check_rect, self.collision_mask, self.collision_dict, exceptions, obj=self)
            if colliding and not (isinstance(colliding, Entity) and self.push_bias > colliding.push_bias):

                #"snap" the moving entity to the entity being collided with
                if steps > g.ENTITY_STEP_SNAP_THRESHOLD and not aw and not ah:
                    if isinstance(colliding, Entity):
                        collide_rect = colliding.collide_rect
                    else:
                        collide_rect = colliding.rect
                    x_diff = self.collide_rect.centerx-collide_rect.centerx
                    y_diff = self.collide_rect.centery-collide_rect.centery
                    if abs(x_diff) > abs(y_diff):
                        if x_diff < 0:
                            self.collide_rect.right = collide_rect.x
                        else:
                            self.collide_rect.x = collide_rect.right
                    else:
                        if y_diff < 0:
                            self.collide_rect.bottom = collide_rect.y
                        else:
                            self.collide_rect.y = collide_rect.bottom

                    if not check:
                        self.collide(colliding)
                        
                    can_move_x = False
                    can_move_y = False
                            
                    nx = self.collide_rect.x-cx_offset
                    ny = self.collide_rect.y-cy_offset
                    return finish_movement()
            else:
                nx += ax
                ny += ay
                nw += aw
                nh += ah
                return finish_movement()
                    

        for step in range(steps):
            #break loop if cannot move
            if not can_move_x and not can_move_y:
                break

            if can_move_x:
                check_rect.topleft = (int(nx+step_x+cx_offset), int(ny+cy_offset))

                check_rect.width = int((nw+step_w)*self.cw)
                check_rect.height = int((nh)*self.ch)
                
                colliding = util.check_collision(check_rect, self.collision_mask, self.collision_dict, exceptions, obj=self)

                #push entities that can be pushed (according to push_bias)
                while colliding and isinstance(colliding, Entity) and self.push_bias > colliding.push_bias:
                    colliding.collide_pushed(self)
                    self.collide_pushing(colliding)

                    vx_transfer = self.vx*self.push_velocity_transfer
                    self.vx -= vx_transfer
                    colliding.vx += vx_transfer

                    
                    if colliding.rect.centerx < check_rect.centerx:
                        colliding.move(step_x-(step_w/2), 0)
                    else:
                        colliding.move(step_x+(step_w/2), 0)

                    old_colliding = colliding
                    colliding = util.check_collision(check_rect, self.collision_mask, self.collision_dict, exceptions, obj=self)

                    if colliding == old_colliding:
                        break
                
                can_move_x = not colliding
                if not check and can_move_y and not can_move_x:
                    
                    #attempt to "bump" up the object (like a stair)
                    if self.bump_amount:
                        gnx, gny = levels.get_gravity(check_rect, normalized=True)
                        if abs(gny) > abs(gnx):
                            bump_amount_completed = 0
                            

                            
                            while self.bump_amount > bump_amount_completed:
                                #get bump_amount
                                if bump_amount_completed+self.bump_step > self.bump_amount:
                                    bump_amount = self.bump_amount-(bump_amount_completed+self.bump_step)
                                else:
                                    bump_amount = self.bump_step

                                bump_amount_completed += bump_amount

                                #attempt bump
                                bump_colliding = util.check_collision(check_rect.move(-gnx*bump_amount_completed, -gny*bump_amount_completed), self.collision_mask, self.collision_dict, exceptions, obj=self)
                                if not bump_colliding:
                                    nx += -gnx*bump_amount_completed
                                    ny += -gny*bump_amount_completed
                                    can_move_x = True
                                    break
                                
                    if not can_move_x:
                        self.collide(colliding)
                        if break_on_collide:
                            return finish_movement()
                    
            if can_move_y:
                check_rect.topleft = (int(nx+cx_offset), int(ny+step_y+cy_offset))

                check_rect.width = int((nw)*self.cw)
                check_rect.height = int((nh+step_h)*self.ch)

                colliding = util.check_collision(check_rect, self.collision_mask, self.collision_dict, exceptions, obj=self)

                #push entities that can be pushed (according to push_bias)
                while colliding and isinstance(colliding, Entity) and self.push_bias > colliding.push_bias:
                    colliding.collide_pushed(self)
                    self.collide_pushing(colliding)

                    vy_transfer = self.vy*self.push_velocity_transfer
                    self.vy -= vy_transfer
                    colliding.vy += vy_transfer

                    if colliding.rect.centery < check_rect.centery:
                        colliding.move(0, step_y-(step_h/2))
                    else:
                        colliding.move(0, step_y+(step_h/2))

                    old_colliding = colliding
                    colliding = util.check_collision(check_rect, self.collision_mask, self.collision_dict, exceptions, obj=self)

                    if colliding == old_colliding:
                        break
                
                can_move_y = not colliding
                if not check and can_move_x and not can_move_y:
                    #attempt to "bump" up the object (like a stair)
                    if self.bump_amount:
                        gnx, gny = levels.get_gravity(check_rect, normalized=True)
                        if abs(gnx) > abs(gny):
                            bump_amount_completed = 0

                            while self.bump_amount > bump_amount_completed:
                                #get bump_amount
                                if bump_amount_completed+self.bump_step > self.bump_amount:
                                    bump_amount = self.bump_amount-(bump_amount_completed+self.bump_step)
                                else:
                                    bump_amount = self.bump_step

                                bump_amount_completed += bump_amount

                                #attempt bump
                                bump_colliding = util.check_collision(check_rect.move(-gnx*bump_amount_completed, -gny*bump_amount_completed), self.collision_mask, self.collision_dict, exceptions, obj=self)
                                if not bump_colliding:
                                    nx += -gnx*bump_amount_completed
                                    ny += -gny*bump_amount_completed
                                    can_move_y = True
                                    break
                            
                    if not can_move_y:
                        self.collide(colliding)
                        if break_on_collide:
                            return finish_movement()
                
            if can_move_x:
                nx += step_x
                nw += step_w
            if can_move_y:
                ny += step_y
                nh += step_h
                

            #end loop if self has been deleted
            if self.deleted:
                break

        return finish_movement()

    def update_surface(self):
        if self.graphics:
            self.sprite = gfx.get_sprite(self.graphics)
            self.surface = gfx.get_surface(self.graphics)
            
        else:
            self.sprite = None
            self.surface = None
                        
    def draw(self):
        self.update_surface()

        #print(self.surface, g.segmenting_in_levels, g.active_levels)
        if not g.segmenting_in_levels or not self.segments.isdisjoint(g.camera.segments):
            transformed_rect = g.camera.transform_rect(self.rect)
            if self.surface:
                transformed_surface = gfx.scale_surface(self.surface, (transformed_rect.w, transformed_rect.h))
                gfx.draw_rotated_surface(transformed_surface, transformed_rect.topleft, self.angle, cx=0.5, cy=0.5, ox=0.5, oy=0.5)
            else:
                p.draw.rect(g.screen, g.BLUE, transformed_rect)

        transformed_rect = g.camera.transform_rect(self.collide_rect)
        #p.draw.rect(g.screen, g.GREEN, transformed_rect, 2)

        #for segment in self.segments:
        #    segment.draw()

    def draw_outline(self, colour=g.BLUE, border=6):
        g.camera.draw_transformed_rect(g.BLUE, self.rect, border=border)

    def delete(self):
        self.clear_old_segments()
        game_objects.Game_Object.delete(self)

    def collide(self, colliding_object):
        self.last_collision = colliding_object

    def collide_pushed(self, colliding_object):
        self.last_collision = colliding_object

    def collide_pushing(self, colliding_object):
        self.last_collision = colliding_object

#For entities with outlines
class Highlightable():
    def __init__(self, highlight_colour, highlighted=False):
        self.highlighted = highlighted
        self.highlight_colour = highlight_colour
        
    def draw_highlight(self):
        if self.surface:
            if not self.surface.highlighted_surface:
                self.surface.create_highlighted_surface(self.highlight_colour)

            transformed_rect = g.camera.transform_rect(self.rect)
            transformed_surface = gfx.scale_surface(self.surface.highlighted_surface, (transformed_rect.w, transformed_rect.h))
            
            gfx.draw_rotated_surface(transformed_surface, transformed_rect.topleft, self.angle, cx=0.5, cy=0.5, ox=0.5, oy=0.5)

class Detail(Entity):
    def __init__(self, rect, graphics, **_kwargs):
        
        kwargs = {"graphics":graphics, "solid":False, "vx":0, "vy":0, "vx_keep":0.9, "vy_keep":0.9, "max_v":3,}
        kwargs.update(_kwargs)
        Entity.__init__(self, rect, **kwargs)
        
class World_Interface_Component(Entity):
    def __init__(self, rect, interface_component, **_kwargs):
        self.interface_component = interface_component
        kwargs = {"active":True}
        kwargs.update(_kwargs)
        
        Entity.__init__(self, rect, **kwargs)

    def update(self):
        Entity.update(self)
        self.draw_rect = g.camera.transform_rect(self.rect)
        print(self.rect, self.draw_rect)
        self.interface_component.rect = self.draw_rect
        self.interface_component.set_from_rect()

        #make it so that the Interface_Components active-ness is linked to World_Interface_Component active-ness
        self.interface_component.active_override = None
        self.interface_component.active_override = self.active and self.interface_component.get_active()

    def draw(self):
        pass

    def delete(self):
        Entity.delete(self)
        self.interface_component.delete()

class Effect(Entity):
    def __init__(self, rect, vx, vy, timer, graphics, **_kwargs):

        kwargs = {"graphics":graphics, "vx":vx, "vy":vy, "collision_dict":{"levels":False, "border":False}}
        kwargs.update(_kwargs)
        Entity.__init__(self, rect, **kwargs)

        events.Delete_Event(self, self, timer)
        self.update()

    def update(self):
        Entity.update(self)
        if type(self.graphics) == gfx.Animation:
            self.graphics.update()

    def delete(self):
        Entity.delete(self)

class Projectile(Entity):
    def __init__(self, rect, vx, vy, graphics, creator, **_kwargs):

        kwargs = {"graphics":graphics, "vx":vx, "vy":vy,"vx_keep":1, "vy_keep":1, "max_v":100, "safe_movement":False, "collision_exceptions":[creator], "solid":True, "max_timer":g.MAX_TICK_RATE*15, "max_range":None, "collision_dict":{"levels":False, "border":True}}
        kwargs.update(_kwargs)
        Entity.__init__(self, rect, **kwargs)

        self.delete_event = events.Delete_Event(self, self, self.max_timer)

        if self.max_range:
            self.update_rect()
            self.start_x = self.rect.centerx
            self.start_y = self.rect.centery
        
        self.update()


    def update(self):
        
        Entity.update(self)
        if self.max_range:
            distance = util.get_distance(self.rect.centerx, self.rect.centery, self.start_x, self.start_y)
            if distance >= self.max_range:
                self.delete()

    def collide(self, colliding_object):

        Entity.collide(self, colliding_object)
        self.delete()

    

def check_path_clear(start_p, end_p, width, height, collision_dict, exceptions=[], centered=True, details=False, step=None):
    rect = p.Rect(0, 0, width, height)
    if centered:
        rect.center = start_p
    else:
        rect.topleft = end_p
        
    check_entity = Entity(rect, collision_dict=collision_dict, collision_exceptions=exceptions, temp=True)

    
    
    check_entity.update()

    if step:
        angle = util.get_angle(start_p[0], start_p[1], end_p[0], end_p[1])
        distance = util.get_distance(start_p[0], start_p[1], end_p[0], end_p[1])
        step_x = m.cos(angle)*step
        step_y = m.sin(angle)*step

        collided = False

        while check_entity.get_distance(end_p[0], end_p[1]) > step:
            move_results = check_entity.move(step_x, step_y, break_on_collide=True, safe_override=False)

            if not (move_results[4] and move_results[5]):
                collided = True
                break

        if not collided:
            move_results = check_entity.move(end_p[0]-check_entity.rect.centerx, end_p[1]-check_entity.rect.centery, break_on_collide=True, safe_override=False)
        
        
    else:
        ax = end_p[0]-start_p[0]
        ay = end_p[1]-start_p[1]
        print(ax, ay)
        move_results = check_entity.move(ax, ay, break_on_collide=True)
                        
    can_move_x, can_move_y = move_results[4], move_results[5]
    if details:
        return can_move_x, can_move_y, check_entity
    else:
        if can_move_x and can_move_y:
            return True
        else:
            return False

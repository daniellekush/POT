# cython: profile=True
# cython: language_level=3
# cython: infer_types=True

from . import global_values as g
from . import utilities as util
from . import graphics as gfx
from . import game_objects

import math as m
import pygame as p
import random as r

class Pipe():
    def __init__(self, name, locked=False):
        self.name = name
        self.locked = locked
        self.events = []
        self.deleted = False
        g.pipes.update({self.name:self})
        g.pipe_list.append(self)

    def update(self):
        #this while loop system prevents crashes from events being deleted mid loop
        i = 0
        while i < len(self.events):
            event = self.events[i]
            if event.active:
                event.update()
            
            if not event.deleted:
                i += 1

            

    def clear(self, end=False):
        for event in self.events[:]:
            if end:
                event.end()
            else:
                event.delete()

    def delete(self, end=False):
        if not self.deleted:
            self.deleted = True
            self.clear(end=end)
            g.pipe_list.remove(self)
            del g.pipes[self.name]

def find_pipe(pipe_name, multiple=False):
    if multiple:
        pipe_list = []
        for name, pipe in g.pipes.items():
            if pipe_name in name:
                pipe_list.append(pipe)
        return pipe_list
    else:
        return g.pipes.get(pipe_name)

def get_pipe(obj):
    if type(obj) == Pipe:
        pipe = obj
        
    elif isinstance(obj, game_objects.Game_Object):
        pipe = obj.pipe

    elif type(obj) == str:
        pipe = find_pipe(obj)

    else:
        pipe = None

    return pipe
    
def clear_events(pipes=None, end=False):
    if not pipes:
        pipes = g.pipes

    for pipe in pipes:
        pipe = get_pipe(pipe)
        pipe.clear(end=end)
        
class Event():
    def __init__(self, pipe, max_timer, **_kwargs):

        kwargs = {"blockable":True, "blocking":True, "active_states":{}, "tags":set()}
        kwargs.update(**_kwargs)

        self.__dict__.update(kwargs)
        
        #get entity pipe
        if isinstance(pipe, game_objects.Game_Object):
            self.pipe = pipe.pipe
        else:
            self.pipe = pipe
            
        if self.pipe is not None:
            self.pipe.events.append(self)
            
        self.max_timer = max_timer
        self.timer = self.max_timer

        self.time_since_activated = 0
        self.progress = 0

        self.activated = False
        self.deleted = False

        
        g.events.append(self)

        self.set_active()
        if self.active:
            self.on_first_activated()
        
    def get_blocked(self):
        if self.pipe:
            preceding_events = self.pipe.events[:self.pipe.events.index(self)]
        else:
            preceding_events = g.events[:g.events.index(self)]
            
        for event in preceding_events:
            if event.blocking:
                return True
        return False

    def set_active(self):
        self.active = True

        old_active = self.active
        if self.blockable:
            self.active = not self.get_blocked()

        if self.active and self.active_states:
            self.active = bool(g.current_states & self.active_states)
            
        if not old_active and self.active:
            if not self.activated:
                self.on_first_activated()
                
            self.unblock()
        
    def update(self):
        self.time_since_activated += 1
        if self.timer != None:
            self.timer -= 1
            self.progress = 1-(self.timer/self.max_timer)
            if self.timer <= 0:
                self.timer = 0
                self.end()

    def unblock(self):
        pass

    #run when the event is first made active
    def on_first_activated(self):
        self.activated = False

    def end(self):
        self.delete()

    def delete(self):
        if not self.deleted:
            g.events.remove(self)

            self.deleted = True

            if self.pipe is not None:
                self.pipe.events.remove(self)

def get_tagged_events(tags, pipe=None, check_type="or"):
    if pipe:
        event_list = pipe.events
    else:
        event_list = g.events

    tagged_events = []
    for event in event_list:
        if check_type == "or":
            if event.tags & tags:
                tagged_events.append(event)
        elif check_type == "and":
            if event.tags > tags:
                tagged_events.append(event)
        elif check_type == "equals":
            if event.tags == tags:
                tagged_events.append(event)
                
    return tagged_events
                
class Lock_Event(Event):
    def __init__(self, pipe, max_timer, **_kwargs):
        
        kwargs = {"keys":None, "tags":set()}
        kwargs.update(**_kwargs)
        
        Event.__init__(self, pipe, max_timer, **kwargs)
        self.tags.add("lock")
        self.locked = True

        if self.keys:
            for key in self.keys:
                self.key.locks.append(self)

    def update(self):
        Event.update(self)
        if not self.locked:
            self.end()

    def unlock(self):
        self.locked = False

    def end(self):
        Event.end(self)

class Unlock_Event(Event):
    def __init__(self, pipe, locks, max_timer, **_kwargs):

        kwargs = {"tags":set()}
        kwargs.update(_kwargs)
        
        Event.__init__(self, pipe, max_timer, **kwargs)
        self.tags.add("unlock")
        self.locks = locks

    def update(self):
        Event.update(self)
        for lock in self.locks:
            lock.unlock()
        self.end()

class Mouse_Disable_Event(Event):
    def __init__(self, pipe, max_timer, **_kwargs):
        
        kwargs = {"disabled_buttons":{1:True, 2:True, 3:True}}
        kwargs.update(**_kwargs)
        
        Event.__init__(self, pipe, max_timer, **kwargs)
        self.tags.add("mouse_disable")

        for k,v in self.disabled_buttons.items():
            if v:
                g.mouse_locks[k] += 1

    def delete(self):
        Event.delete(self)
        for k,v in self.disabled_buttons:
            if v:
                g.mouse_locks[k] -= 1

class Variable_Set_Event(Event):
    def __init__(self, pipe, variable_name, value, timer, **_kwargs):

        kwargs = {"variable_obj":None, "delayed_set":True, "revert":False, "force":False}
        kwargs.update(_kwargs)
        
        Event.__init__(self, pipe, timer, **kwargs)
        self.tags.add("variable_set")

        self.value = value
        self.variable_name = variable_name
        
        self.old_value = util.get_variable_value(self.variable_name, variable_obj=self.variable_obj)
        if not self.delayed_set:
            util.set_variable_value(self.variable_name, self.value, variable_obj=self.variable_obj)

    def update(self):
        Event.update(self)
        if self.force:
            util.set_variable_value(self.variable_name, self.value, variable_obj=self.variable_obj)

    def end(self):
        Event.end(self)
        if self.delayed_set:
           util.set_variable_value(self.variable_name, self.value, variable_obj=self.variable_obj)

           
        if self.revert:
           util.set_variable_value(self.variable_name, self.old_value, variable_obj=self.variable_obj)


class Numeric_Variable_Change_Event(Event):
    def __init__(self, pipe, variable_name, change, timer, **_kwargs):

        kwargs = {"variable_obj":None, "revert":False, "force":False, "delayed_set":True, "force_int":False}
        kwargs.update(_kwargs)
        
        Event.__init__(self, pipe, timer, **kwargs)
        self.tags.add("variable_change")

        self.change = change
        self.tick_change = self.change/self.timer
        self.total_change = 0
        
        self.variable_name = variable_name

        self.old_value = util.get_variable_value(self.variable_name, variable_obj=self.variable_obj)
        
    def update(self):
        Event.update(self)

        if not self.delayed_set:
            self.total_change += self.tick_change
            if self.force:
                value = util.interpolate_between_values(self.old_value, self.old_value+self.change, self.progress)
            else:
                value = util.get_variable_value(self.variable_name, variable_obj=self.variable_obj)+self.tick_change

            if self.force_int:
                value = int(value)

            util.set_variable_value(self.variable_name, value, variable_obj=self.variable_obj)


    def end(self):
        Event.end(self)
           
        if self.revert:
           util.set_variable_value(self.variable_name, self.old_value, variable_obj=self.variable_obj)
        elif self.delayed_set:
            if self.force:
                value = self.old_value+self.change
            else:
                value = util.get_variable_value(self.variable_name, variable_obj=self.variable_obj)+self.change

            util.set_variable_value(self.variable_name, value, variable_obj=self.variable_obj)


class Numeric_Variable_Target_Event(Event):
    def __init__(self, pipe, variable_name, target_value, change, **_kwargs):

        kwargs = {"variable_obj":None, "revert":False, "force":False}
        kwargs.update(_kwargs)
        
        Event.__init__(self, pipe, None, **kwargs)
        self.tags.add("variable_change_target")

        self.change = change
        self.target_value = target_value
        self.total_change = 0
        
        self.variable_name = variable_name

        self.old_value = util.get_variable_value(self.variable_name, variable_obj=self.variable_obj)
        if not self.delayed_set:
            util.set_variable_value(self.variable_name, self.value, variable_obj=self.variable_obj)

    def update(self):
        Event.update(self)

        if self.old_value+self.total_change+self.change > self.target_value:
            change = self.target_value-(self.old_value+self.total_change)
        else:
            change = self.change
            
        self.total_change += change
            
        if self.force:
            value = self.old_value+self.total_change
        else:
            value = change

        util.set_variable_value(self.variable_name, value, variable_obj=self.variable_obj)


        if value == self.target_value:
            self.end()

    def end(self):
        Event.end(self)
           
        if self.revert:
           util.set_variable_value(self.variable_name, self.old_value, variable_obj=self.variable_obj)


class String_Reveal_Event(Event):
    
    def __init__(self, pipe, full_string, timer, **_kwargs):
        
        kwargs = {"character_reveal_timer":None, "variable_name":None, "variable_obj":None,
                  "character_reveal_sound":None, "start_character_reveal_sound":None, "end_character_reveal_sound":None, "reveal_sound_ignore_whitespace":True}
        kwargs.update(_kwargs)

        if kwargs["character_reveal_timer"]:
            self.reveal_timer = self.character_reveal_timer*len(full_string)
        else:
            self.reveal_timer = timer
            
        Event.__init__(self, pipe, timer, **kwargs)
        self.tags.add("string_reveal")

        self.full_string = full_string
        self.string = ""

        self.reveal_progress = 0
        self.amount_of_revealed_characters = 0

    def update(self):
        from . import sound
        Event.update(self)

        old_reveal_progress = self.reveal_progress
        self.reveal_progress = min((self.time_since_activated/self.reveal_timer), 1)

        if old_reveal_progress == 0 and self.reveal_progress > 0 and self.start_character_reveal_sound:
            sound.play_sound(self.start_character_reveal_sound)

        if old_reveal_progress != self.reveal_progress and self.reveal_progress == 1 and self.end_character_reveal_sound:
            sound.play_sound(self.end_character_reveal_sound)
            

        old_amount_of_revealed_characters = self.amount_of_revealed_characters
        self.amount_of_revealed_characters = round(len(self.full_string)*self.reveal_progress)

        if self.amount_of_revealed_characters > old_amount_of_revealed_characters:
            if self.character_reveal_sound:
                new_revealed_string = self.full_string[old_amount_of_revealed_characters:self.amount_of_revealed_characters]
                if not self.reveal_sound_ignore_whitespace or not new_revealed_string.isspace():
                    sound.stop_sound(self.character_reveal_sound)
                    sound.play_sound(self.character_reveal_sound)
        
        revealed_characters = [self.full_string[i] for i in range(self.amount_of_revealed_characters)]
        self.string = "".join(revealed_characters)

        if self.variable_name:
            util.set_variable_value(self.variable_name, self.string, variable_obj=self.variable_obj)


class Subroutine_Call_Event(Event):
    def __init__(self, pipe, subroutine_name, subroutine_args, subroutine_kwargs, timer, **_kwargs):

        kwargs = {"subroutine_obj":None, "delayed_call":True, "continuous":False}
        kwargs.update(_kwargs)
        
        Event.__init__(self, pipe, timer, **kwargs)
        self.tags.add("subroutine_call")

        self.subroutine_name = subroutine_name
        
        self.subroutine_args = subroutine_args
        self.subroutine_kwargs = subroutine_kwargs

        self.result = None

        if not self.delayed_call and self.active:
            self.call_subroutine()

    def call_subroutine(self):
        if self.subroutine_obj:
            self.result = getattr(self.subroutine_obj, self.subroutine_name)(*self.subroutine_args, **self.subroutine_kwargs)
        else:
            self.result = getattr(g,self.subroutine_name)(*self.subroutine_args, **self.subroutine_kwargs)

    def update(self):
        Event.update(self)
        if self.continuous:
            self.call_subroutine()

    def end(self):
        Event.end(self)
        if self.delayed_call:
            self.call_subroutine()

class Internal_Command_Event(Event):
    def __init__(self, pipe, data, timer, **_kwargs):

        kwargs = {"delayed_call":True, "continuous":False}
        kwargs.update(_kwargs)
        
        Event.__init__(self, pipe, timer, **kwargs)
        self.tags.add("internal_command")

        self.data = data

        if not self.delayed_call and self.active:
            self.run_command()

    def run_command(self):
        g.internal_commands.append(self.data)
        
    def update(self):
        Event.update(self)
        if self.continuous:
            self.run_command()

    def end(self):
        Event.end(self)
        if self.delayed_call:
            self.run_command()
    
class Delete_Event(Event):
    def __init__(self, pipe, entity, timer, **_kwargs):

        kwargs = {}
        kwargs.update(_kwargs)
        
        Event.__init__(self, pipe, timer, **kwargs)
        self.tags.add("delete")
        
        self.entity = entity

    def end(self):
        Event.end(self)
        if not self.entity.deleted:
            self.entity.delete()

class Move_Event(Event):
    def __init__(self, pipe, entity, dx, dy, timer, **_kwargs):

        kwargs = {}
        kwargs.update(_kwargs)
        
        Event.__init__(self, pipe, timer, **kwargs)
        self.tags.add("move")
        
        self.entity = entity
        self.ax = dx/timer
        self.ay = dy/timer

    def update(self):
        Event.update(self)
        self.entity.move(self.ax, self.ay)

class Teleport_Event(Event):
    def __init__(self, pipe, entity, ex, ey, timer, **_kwargs):

        kwargs = {"smooth":False}
        kwargs.update(_kwargs)
        
        Event.__init__(self, pipe, timer, **kwargs)
        self.tags.add("teleport")
        
        self.entity = entity
        self.sx = self.entity.x
        self.sy = self.entity.y
        self.ex = ex
        self.ey = ey
        self.max_timer = self.timer

    def update(self):
        Event.update(self)
        progress = 1-(self.timer/self.max_timer)
        x = util.interpolate_between_values(self.sx, self.ex, progress, smooth=self.smooth)
        y = util.interpolate_between_values(self.sy, self.ey, progress, smooth=self.smooth)
        self.entity.x = x
        self.entity.y = y

class Entity_Target_Event(Event):
    def __init__(self, pipe, entity, target, speed, **_kwargs):

        kwargs = {"threshold":2, "offset_x":0, "offset_y":0}
        kwargs.update(_kwargs)
        
        Event.__init__(self, pipe, None)
        self.tags.add("entity_target")
        
        self.target = target
        self.speed = speed

    def update(self):
        Event.update(self)

        tx = self.target.rect.centerx+self.offset_x
        ty = self.target.rect.centery+self.offset_y

        #move towards target
        angle = util.get_angle(self.entity.rect.centerx, self.entity.rect.centery, tx, ty)
        dx = m.cos(angle)*self.speed
        dy = m.sin(angle)*self.speed
        self.entity.move(dx, dy)

        dist = util.get_distance(self.entity.rect.centerx, tx, ty)
        if dist <= self.threshold:
            self.end()
        else:
            if util.get_distance(self.entity.rect.centerx+dx, self.entity.rect.centery+dy, tx, ty) > dist:
                self.end()

    def end(self):
        Event.end(self)
        self.entity.rect.center = self.target.rect.center
        self.entity.rect.x += self.offset_x
        self.entity.rect.y += self.offset_y
        self.entity.set_from_rect()

class Entity_Teleport_Event(Event):
    def __init__(self, pipe, entity, target, timer, **_kwargs):

        kwargs = {"offset_x":0, "offset_y":0, "smooth":False}
        kwargs.update(_kwargs)
        
        Event.__init__(self, pipe, timer, **kwargs)
        self.tags.add("entity_teleport")
        
        self.entity = entity
        self.target = target
        self.max_timer = self.timer

    def update(self):
        Event.update(self)
        progress = 1-(self.timer/self.max_timer)
        self.sx = self.entity.x
        self.sy = self.entity.y
        self.ex = self.target.x+self.offset_x
        self.ey = self.target.y+self.offset_y
        
        x = util.interpolate_between_values(self.sx, self.ex, progress, smooth=self.smooth)
        y = util.interpolate_between_values(self.sy, self.ey, progress, smooth=self.smooth)
        self.entity.set_x(x)
        self.entity.set_y(y)

    def end(self):
        Event.end(self)
        self.entity.set_x(self.ex)
        self.entity.set_y(self.ey)

class Camera_Shake_Event(Event):
    def __init__(self, pipe, timer, intensity, speed, **_kwargs):

        kwargs = {"smooth_end":True}
        kwargs.update(_kwargs)
        
        Event.__init__(self, pipe, timer, **kwargs)
        self.tags.add("camera_shake")
        
        self.intensity = intensity
        self.speed = speed

        self.sx = 0
        self.sy = 0

        self.set_new_angle()

    def set_new_angle(self):
        angle = r.random()*2*m.pi
        self.vx = m.cos(angle)*self.speed
        self.vy = m.sin(angle)*self.speed

    def update(self):
        Event.update(self)
        g.camera.x -= self.sx
        g.camera.y -= self.sy

        self.sx += self.vx
        self.sy += self.vy
        if abs(self.sx) > self.intensity:
            self.sx = self.intensity*(abs(self.sx)/self.sx)
            self.set_new_angle()
        if abs(self.sy) > self.intensity:
            self.sy = self.intensity*(abs(self.sy)/self.sy)
            self.set_new_angle()

        g.camera.x += self.sx
        g.camera.y += self.sy
            
    def end(self, force=False):
        Event.end(self)
        g.camera.x -= self.sx
        g.camera.y -= self.sy
        if self.smooth_end and not force:
            Camera_Shake_Event(self.pipe, self.max_timer/2, self.intensity/2, self.speed/2, blockable=False, blocking=False, smooth_end=False)

class Fade_Event(Event):
    def __init__(self, pipe, timer, graphics, fade_type, **_kwargs):

        kwargs = {"start_alpha":None, "end_alpha":None, "smooth_fade":False}
        kwargs.update(_kwargs)
        
        Event.__init__(self, pipe, timer, **kwargs)
        self.tags.add("fade_"+fade_type)

        self.graphics = graphics
        self.fade_type = fade_type

        if self.start_alpha is None:
            if self.fade_type == "in":
                self.start_alpha = 0
            elif self.fade_type == "out":
                self.start_alpha = 255

        if self.end_alpha is None:
            if self.fade_type == "in":
                self.end_alpha = 255
            elif self.fade_type == "out":
                self.end_alpha = 0


        self.last_surface = gfx.get_surface(self.graphics)
        self.last_surface_alpha = self.last_surface.get_alpha()

        self.update()

    def update(self):
        Event.update(self)
        
        surface = gfx.get_surface(self.graphics)

        alpha = int(util.interpolate_between_values(self.start_alpha, self.end_alpha, self.progress, smooth=self.smooth_fade))
        surface.set_alpha(alpha)

        if surface != self.last_surface:
            self.last_surface.set_alpha(self.last_surface_alpha)
            self.last_surface = surface
            self.last_surface_alpha = self.last_surface.get_alpha()

class Overlay_Event(Event):
    def __init__(self, pipe, timer, colour, **_kwargs):

        kwargs = {"min_intensity":0, "max_intensity":255, "intensity_increase":False}
        kwargs.update(_kwargs)
        
        Event.__init__(self, pipe, timer, **kwargs)
        self.tags.add("overlay")
        
        self.surface = p.Surface((g.WIDTH, g.HEIGHT))
        self.surface.fill(colour)
        self.surface.set_alpha(self.max_intensity)

        self.intensity_change = self.max_intensity-self.min_intensity

    def set_alpha(self):
        if self.intensity_increase:
            progress = self.progress
        else:
            progress = 1-self.progress
            
        alpha = int(self.min_intensity+(self.intensity_change*progress))
        self.surface.set_alpha(alpha)

    def update(self):
        Event.update(self)
        self.set_alpha()

    def draw(self):
        g.screen.blit(self.surface, (0,0))

    def delete(self):
        Event.delete(self)

class Play_Sound_Event(Event):
    def __init__(self, pipe, timer, sound, **_kwargs):
        from . import sound as _sound
        
        kwargs = {"loops":0, "maxtime":0, "fade_ms":0, "delay":True, "stop_on_end":False}
        kwargs.update(_kwargs)
        
        Event.__init__(self, pipe, timer, **kwargs)
        self.tags.add("play_sound")
        
        self.sound = sound

        if not self.delay:
            _sound.play_sound(self.sound, loops=self.loops, maxtime=self.maxtime, fade_ms=self.fade_ms)

    def end(self):
        from . import sound as _sound
        Event.end(self)
        if self.delay:
            _sound.play_sound(self.sound, loops=self.loops, maxtime=self.maxtime, fade_ms=self.fade_ms)
        elif self.stop_on_end:
            _sound.stop_sound(self.sound)

class Stop_Sound(Event):
    def __init__(self, pipe, timer, sound, **_kwargs):
        from . import sound as _sound
        
        kwargs = {"delay":True}
        kwargs.update(_kwargs)
        
        Event.__init__(self, pipe, timer, **kwargs)
        self.tags.add("play_sound")
        
        self.sound = sound

        if not self.delay:
            _sound.stop_sound(self.sound)

    def end(self):
        from . import sound as _sound
        Event.end(self)
        if self.delay:
            _sound.stop_sound(self.sound)
            
class Keypress_Event(Event):
    def __init__(self, pipe, **_kwargs):

        kwargs = {"keys":None, "press_type":"press", "press_amount":1}
        kwargs.update(_kwargs)
        
        Event.__init__(self, pipe, **kwargs)
        self.tags.add("keypress")
        #keys is the keycode(s) needed to end the event, a value of None means that any key can be pressed

        #press type can be "press", "release" or "hold" (hold means that the required_presses goes down every frame the key is held)

        #number of times the key must be pressed to end the event
        self.max_press_amount = self.press_amount

    def update(self):
        Event.update(self)
        if self.press_type == "hold":
            if self.keys == None:
                if [p for p in g.keys.values() if p]:
                    self.press()

    def press(self, amount=1):
        self.press_amount -= amount
        if self.press_amount <= 0:
            self.end()

class Wave_Event(Event):
    def __init__(self, pipe, timer, game_object, horizontal, vertical, intensity, speed_override=False, **_kwargs):
        kwargs = {}
        kwargs.update(_kwargs)
        Event.__init__(self, pipe, timer, **kwargs)
        self.tags.add("wave")

        self.game_object = game_object
        self.horizontal = horizontal
        self.vertical = vertical
        self.intensity = intensity

        if speed_override is not False:
            self.speed = speed_override
        else:
            self.speed = 1/self.max_timer

        self.progress = 0
        self.offset = 0

    def update(self):
        Event.update(self)

        #remove previous offset
        if self.horizontal:
            self.game_object.x -= self.offset
        if self.vertical:
            self.game_object.y -= self.offset

        #create new offset
        self.offset = m.sin(self.progress*2*m.pi)*self.intensity
        if self.horizontal:
            self.game_object.x += self.offset
        if self.vertical:
            self.game_object.y += self.offset

        self.game_object.update_rect()

        self.progress += self.speed

    def end(self):
        Event.end(self)
        if self.horizontal:
            self.game_object.x -= self.offset
        if self.vertical:
            self.game_object.y -= self.offset

class Icon_Event(Event):
    def __init__(self, pipe, timer, rect, graphics, decoration_kwargs={}, **_kwargs):
        kwargs = {}
        kwargs.update(_kwargs)
        Event.__init__(self, pipe, timer, **kwargs)
        self.tags.add("icon")

        self.rect = rect
        self.graphics = graphics

    def update(self):
        Event.update(self)
        if isinstance(self.graphics, (gfx.Animation, gfx.Animation_System)):
            self.graphics.update()

    def draw(self):
        gfx.draw_scaled_graphics(self.graphics, self.rect)

def get_tagged_events(tags):
    events = []
    for event in g.events:
        if not tags.isdisjoint(event.tags):
            events.append(event)

    return events

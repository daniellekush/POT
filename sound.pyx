# cython: profile=True
# cython: language_level=3
# cython: infer_types=True

from . import utilities as util
from . import global_values as g
from . import entities

import pygame as p
import os
import numpy as np
import math as m

class POT_Sound():
    def __init__(self, name, data):
        self.name = name
        
        self.sound = get_sound(data)
        self.data = p.sndarray.array(self.sound)

        #get left and right channels separately
        self.left_data =  self.data*np.repeat(  np.array( [[1,0]] ), len(self.data), axis=0)
        self.right_data = self.data*np.repeat(  np.array( [[0,1]] ), len(self.data), axis=0)

        self.left_sound = p.sndarray.make_sound(self.left_data)
        self.right_sound = p.sndarray.make_sound(self.right_data)
        
        g.pot_sounds.update({self.name:self})

    def play(self, loops=0, maxtime=0, fade_ms=0):
        c1 = self.left_sound.play(loops=loops, maxtime=maxtime, fade_ms=fade_ms)
        c2 = self.right_sound.play(loops=loops, maxtime=maxtime, fade_ms=fade_ms)
        return c1, c2

    def stop(self):
        self.sound.stop()
        self.left_sound.stop()
        self.right_sound.stop()

    def fadeout(self, time):
        self.sound.fadeout(time)
        self.left_sound.fadeout(time)
        self.right_sound.fadeout(time)

    def set_volume(self, value):
        self.sound.get_volume(value)
        self.left_sound.set_volume(value)
        self.right_sound.set_volume(value)

    def get_volume(self):
        v = self.sound.get_volume()
        vl = self.left_sound.get_volume()
        vr = self.right_sound.get_volume()
        return v, vl, vr

    def get_num_channels(self):
        return self.sound.get_num_channels()+self.left_sound.get_num_channels()+self.right_sound.get_num_channels()

    def get_length(self):
        return self.sound.get_length()

    def get_raw(self):
        return self.sound.get_raw()
    
#class for storing easily properties for Emitters, Microphones and Queued_Sounds
class Sound_Properties():
    def __init__(self, name, volume_multiplier, max_volume, constant_volume, global_range, fade_ms):
        self.name = name
        
        #if a property for a specific property isn't meant to have an effect, it should be set to None (not False)
        self.volume_multiplier = volume_multiplier
        self.max_volume = max_volume
        self.constant_volume = constant_volume
        self.global_range = global_range
        self.fade_ms = fade_ms

        g.sound_properties.update({self.name:self})

#class for information about the sounds played using Emitters
class Queued_Sound():
    def __init__(self, sound, **_kwargs):
        kwargs = {"properties":g.sound_properties["default"], "repeat":False}
        kwargs.update(_kwargs)
        self.__dict__.update(kwargs)
        
        self.sound = get_sound(sound)
        
        if isinstance(self.properties, str):
            self.properties = g.sound_properties[self.properties]

    def start(self):
        if self.repeat:
            loops = -1
        else:
            loops = 0
        self.sound.play(loops=loops, fade_ms=self.properties.fade_ms)
        
    def stop(self):
        self.sound.stop()

#class for playing sounds in the world
class Emitter(entities.Entity):
    def __init__(self, x, y, amplitude, sound_range, **_kwargs):
        kwargs = {"properties":g.sound_properties["default"], "sound_queue":[], "static":True, "solid":False}
        kwargs.update(_kwargs)
        entities.Entity.__init__(self, p.Rect(x,y,1,1), **kwargs)

        self.amplitude = amplitude
        
        self.range = sound_range
        
        self.sound_queue = kwargs["sound_queue"]
        self.current_sound = None
        self.active = True

        self.sound_progress = 0

        if isinstance(self.properties, str):
            self.properties = g.sound_properties[self.properties]


    #update the currently playing sound
    def update(self):
        entities.Entity.update(self)
        if self.active and self.current_sound:
            self.sound_progress += 1/g.MAX_TICK_RATE
            if self.sound_progress >= self.current_sound.sound.get_length():
                #play next sound
                self.start_next_sound()
                        
        elif self.active and self.sound_queue:
            #play beginning of new sound queue
            self.current_sound = self.sound_queue[0]
            self.current_sound.start()

    #add a new sound to the queue
    def add_sound(self, sound, repeat=False, properties=None):
        sound = get_sound(sound)
        if properties:
            queued_sound = Queued_Sound(sound, repeat=repeat, properties=properties)
        else:
            queued_sound = Queued_Sound(sound, repeat=repeat)
        self.sound_queue.append(queued_sound)

    #start the next sound
    def start_next_sound(self):
        if self.current_sound.repeat:
            #repeat sound
            self.sound_progress = self.sound_progress%self.current_sound.sound.length
        else:
            #end current sound
            self.sound_progress = 0
            self.sound_queue.remove(self.current_sound)
            self.current_sound.stop()
            
            if self.sound_queue:
                #set next sound
                self.current_sound = self.sound_queue[0]
                self.current_sound.start()
            else:
                #stop Emitter
                self.current_sound = None

    #skip the current sound
    def skip(self, number=1):
        for sound in range(number):
            self.current_sound.stop()
            if self.current_sound:
                self.sound_queue.remove(self.current_sound)
            
            if self.sound_queue:
                #set next sound
                self.current_sound = self.sound_queue[0]
                self.current_sound.start()
            else:
                #stop Emitter
                self.current_sound = None
                break

#useful for quickly playing a single sound
class Temp_Emitter(Emitter):
    def __init__(self, x, y, amplitude, sound_range, **_kwargs):
        kwargs = {}
        kwargs.update(_kwargs)
        Emitter.__init__(self, x, y, amplitude, sound_range, **kwargs)

    def update(self):
        Emitter.update(self)
        if not self.current_sound:
            self.delete()

def emit_sound(x, y, sound, amplitude, sound_range, **_kwargs):
    kwargs = {"sound_queue":[sound]}
    kwargs.update(_kwargs)
    Temp_Emitter(x, y, amplitude, sound_range, **kwargs)
        
        
#class for determining how loud sounds should be played based on distance
class Microphone(entities.Entity):
    def __init__(self, x, y, mic_range, ear_distance, **_kwargs):
        kwargs = {"properties":g.sound_properties["default"], "ear_angle":0, "static":True, "collision_profile":{"tiles":False, "bodies":False, "npcs":False, "player":False, "border":False, "screen":False}}
        kwargs.update(_kwargs)
        entities.Entity.__init__(self, p.Rect(x,y,1,1), **kwargs)
        
        self.range = mic_range
        self.ear_distance = ear_distance
        self.update_ears()

        if isinstance(self.properties, str):
            self.properties = g.sound_properties[self.properties]

    def update(self):
        entities.Entity.update(self)
        self.update_ears()
        
    def update_ears(self):
        vx = m.cos(self.ear_angle)*self.ear_distance/2
        vy = m.sin(self.ear_angle)*self.ear_distance/2
        self.ear1_pos = (self.x+vx, self.y+vy)
        self.ear2_pos = (self.y-vx, self.y-vy)
            
    def get_emitters_in_range(self):
        mic_p = self.properties
        emitters_in_range = []
        for emitter in g.game_objects.get("class_Emitter", []):
            if emitter.active and emitter.current_sound:
                emit_p = emitter.properties
                snd_p = emitter.current_sound.properties
            
                can_use_global = (snd_p.global_range is not False and emit_p.global_range is not False and mic_p.global_range is not False)
                #emitter in range if the Emitter, Emitter Sound or Microphone have global range, and global range had not been cancelled by being set to False
                #or if Emitter within Microphone range
                if  (can_use_global and (snd_p.global_range or emit_p.global_range or mic_p.global_range)) or \
                util.get_distance(self.x, self.y, emitter.x, emitter.y) < self.range+emitter.range:
                    emitters_in_range.append(emitter)
                
        return emitters_in_range

def update_emitter_volumes():
    emitters_in_range = []
    for microphone in g.game_objects.get("class_Microphone", []):
        emitters_in_range += microphone.get_emitters_in_range()
        
    for emitter in g.game_objects.get("class_Emitter", []):
        vol = 0
        left_vol = 0
        right_vol = 0
        if emitter in emitters_in_range:
            #get volume from the loudest microphone detection
            emit_p = emitter.properties
            snd_p = emitter.current_sound.properties
            for microphone in g.game_objects.get("class_Microphone", []):
                mic_p = microphone.properties
                #set max volume if emitter, sound, or microphone use constant volume or have global range, and none of them have cancelled constant volume by setting to False
                can_clip_vol = (mic_p.max_volume is not False and snd_p.max_volume is not False and emit_p.max_volume is not False)
                can_set_vol = can_clip_vol and \
                            (not (mic_p.constant_volume is False or mic_p.global_range is False)) and \
                            (not (snd_p.constant_volume is False or snd_p.global_range is False)) and \
                            (not (emit_p.constant_volume is False or emit_p.global_range is False))                          
     
                microphone_vol = None  
                if can_set_vol:
                    if (mic_p.constant_volume or mic_p.global_range) and mic_p.max_volume is not None:
                        microphone_vol = mic_p.max_volume
                    elif (snd_p.constant_volume or snd_p.global_range) and snd_p.max_volume is not None:
                        microphone_vol = snd_p.max_volume
                    elif (emit_p.constant_volume or emit_p.global_range) and emit_p.max_volume is not None:
                        microphone_vol = emit_p.max_volume

                #otherwise set volume based off of distance
                if microphone_vol is None:
                    microphone_distance = util.get_distance(microphone.x, microphone.y, emitter.x, emitter.y)
                    #prevent crashing from divide by zero error
                    if microphone_distance == 0:
                        microphone_distance = 0.01
                    
                    microphone_vol = emitter.amplitude/(microphone_distance)
                    #really should be using the inverse square law
                    #but it feels off in practice

                #apply multipliers
                #cancel multiplication if volume_multiplier is set to False (not None) for the Sound, Emitter or Microphone
                can_multiply = (snd_p.volume_multiplier is not False and emit_p.volume_multiplier is not False and mic_p.volume_multiplier is not False)
                if can_multiply:
                    if snd_p.volume_multiplier is not None:
                        microphone_vol *= snd_p.volume_multiplier
                        #clip
                        if can_clip_vol and snd_p.max_volume is not None and microphone_vol > snd_p.max_volume:
                            microphone_vol = snd_p.max_volume
                            
                    if emit_p.volume_multiplier is not None:
                        microphone_vol *= emit_p.volume_multiplier
                        #clip
                        if can_clip_vol and emit_p.max_volume is not None and microphone_vol > emit_p.max_volume:
                            microphone_vol = emit_p.max_volume
                            
                    if mic_p.volume_multiplier is not None:
                        microphone_vol *= mic_p.volume_multiplier
                        #clip
                        if can_clip_vol and mic_p.max_volume is not None and microphone_vol > mic_p.max_volume:
                            microphone_vol = mic_p.max_volume

                        
                if microphone_vol > vol:
                    vol = microphone_vol
                    if microphone.x < emitter.x:
                        left_vol = vol
                        right_vol = vol**2
                    elif microphone.x > emitter.x:
                        left_vol = vol**2
                        right_vol = vol
                    else:
                        left_vol = vol
                        right_vol = vol

            #actual audio processing begins here
            #if vol > 0:
                #set effects
                #cancel effects if effects are to False (not None) for the Sound, Emitter or Microphone
                #effects = []
                #if mic_p.effects != False and snd_p.effects != False and emit_p.effects != False:
                #    if snd_p.effects != None:
                #        effects += snd_p.effects
                #    if emit_p.effects != None:
                #        effects += emit_p.effects
                #    if mic_p.effects != None:
                #        effects += mic_p.effects
        if emitter.current_sound:
            emitter.current_sound.sound.left_sound.set_volume(left_vol*g.GLOBAL_VOLUME)
            emitter.current_sound.sound.right_sound.set_volume(right_vol*g.GLOBAL_VOLUME)

def get_sound(sound):
    if type(sound) == str:
        if sound in g.pot_sounds:
            sound = g.pot_sounds[sound]
        else:
            sound = g.sound_dict[sound]
    return sound

def play_sound(sound, loops=0, maxtime=0, fade_ms=0):
    get_sound(sound).play(loops=loops, maxtime=maxtime, fade_ms=fade_ms)

def stop_sound(sound):
    get_sound(sound).stop()

def set_music(music, ext=None, fade_timer=0, loops=-1, volume=None):
    if volume is None:
        volume = g.GLOBAL_VOLUME
        
    if type(music) == str:
        if not ext:
            files = os.listdir(g.sound_dir)
            for file in files:
                if music in file:
                    ext = file.split(".")[-1]
                    break
                
        if not ext:
            return
        
        music = g.sound_dir+"\\"+music+"."+ext
        
    if music != g.current_music:
        
        g.current_music = music
        p.mixer.music.set_volume(volume)

        if fade_timer:
            #p.mixer.music.fadeout(fade_timer)
            #p.mixer.music.queue(music)
            p.mixer.music.stop()
            p.mixer.music.load(music)
            p.mixer.music.play(loops=loops, fade_ms=fade_timer)
        else:
            p.mixer.music.stop()
            p.mixer.music.load(music)
            p.mixer.music.play(loops=loops)
            
def stop_music(fadeout_time=0):
    g.current_music = None
    if fadeout_time:
        g.mixer.music.fadeout(fadeout_time)
    else:
        g.mixer.music.stop()

def set_global_volume(volume):
    g.GLOBAL_VOLUME = volume
    for sound in g.sound_dict.values():
        sound.set_volume(g.GLOBAL_VOLUME)

def stop_all_sounds():
    for sound in g.sound_dict.values():
        sound.stop()

def load_sound_dict(path=g.sound_dir):
    #iterate through sound files in sound_dir directory
    
    for file in os.listdir(path):
        if os.path.isfile(file):
        
            if file.endswith(".mp3") or file.endswith(".wav"):
                #remove file extension to get sound name
                sound_name = file[:-4]
                #create sound object
                sound = p.mixer.Sound(path+file)
                #sound = g.GLOBAL_VOLUME
                g.sound_dict.update({sound_name:sound})
            
        elif os.path.isdir(file):
            load_sound_dict(path+file+"\\")

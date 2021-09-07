#THIS ENTIRE MODULE IS HORRIBLY WRITTEN

import global_values as g
import utilities as util
import graphics as gfx

import pickle
import warnings
import pygame as p

class Pickled_Surface():
    def __init__(self, surface):
        if gfx.get_transparent(surface):
            self.i_format = "RGBA"
        else:
            self.i_format = "RGB"

        self.size = surface.get_size()

        self.buffer = p.image.tostring(surface, self.i_format)
        self.flags = surface.get_flags()

    def unpickle(self):
        surface = p.image.fromstring(self.buffer, self.size, self.i_format) 
        return surface

class Pickled_Mask():
    def __init__(self, mask):
        mask_surface = mask.to_surface()
        self.pickled_mask_surface = Pickled_Surface(mask_surface)

    def unpickle(self):
        surface = self.pickled_mask_surface.unpickle()
        mask = p.mask.from_surface(surface)
        return mask

class Pickled_Font():
    def __init__(self, font):
        self.name = font.name
        self.font_data = font.font_data
        self.size = font.font_size

    def unpickle(self):
        font = gfx.Font(self.name, self.font_data, self.size)
        return font
    
def make_object_pickle_ready(obj, recursion_depth=0, parent=None, referenced_objects=[]):
    #dont do anything to an object that has already been dealt with
    if obj in referenced_objects:
        return obj
    else:
        referenced_objects = referenced_objects+[obj]

    #don't go beyond max recusion limit
    if recursion_depth == g.MAX_SAVE_RECURSION:
        return obj

    #iterate through certain iterable objects
    if type(obj) == list or type(obj) == tuple or type(obj) == set:
        obj = obj.__class__([make_object_pickle_ready(o, recursion_depth+1, referenced_objects=referenced_objects) for o in obj])

    #iterate through dictionaries
    elif type(obj) == dict:
        obj = {make_object_pickle_ready(k, recursion_depth+1, referenced_objects=referenced_objects):\
               make_object_pickle_ready(v, recursion_depth+1, referenced_objects=referenced_objects)\
               for k,v in obj.items()}

    #actually convert the objects that are normally unpickle-able
    elif type(obj) == p.Surface:
        obj = Pickled_Surface(obj)
    elif type(obj) == p.Mask:
        obj = Pickled_Mask(obj)
    elif type(obj) == gfx.Font:
        obj = Pickled_Font(obj)

    #iterate through every attribute of an object
    elif hasattr(obj, "__dict__"):
        for var_name, value in obj.__dict__.items():
            value = make_object_pickle_ready(value, recursion_depth+1, referenced_objects=referenced_objects)
            obj.__dict__[var_name] = value
                    
    return obj

def make_object_pickle_unready(obj, recursion_depth=0, parent=None, referenced_objects=[]):
    #dont do anything to an object that has already been dealt with
    if obj in referenced_objects:
        return obj
    else:
        referenced_objects = referenced_objects+[obj]

    #don't go beyond max recusion limit
    if recursion_depth == g.MAX_SAVE_RECURSION:
        return obj

    #iterate through certain iterable objects
    if type(obj) == list or type(obj) == tuple or type(obj) == set:
        obj = obj.__class__([make_object_pickle_unready(o, recursion_depth+1, referenced_objects=referenced_objects) for o in obj])

    #iterate through dictionaries
    elif type(obj) == dict:
        obj = {make_object_pickle_unready(k, recursion_depth+1, referenced_objects=referenced_objects):\
               make_object_pickle_unready(v, recursion_depth+1, referenced_objects=referenced_objects)\
               for k,v in obj.items()}

    #actually convert the objects back to their normal versions
    elif type(obj) in (Pickled_Surface, Pickled_Mask, Pickled_Font):
        obj = obj.unpickle()

    #iterate through every attribute of an object
    elif hasattr(obj, "__dict__"):
        for var_name, value in obj.__dict__.items():
            value = make_object_pickle_unready(value, recursion_depth+1, referenced_objects=referenced_objects)
            obj.__dict__[var_name] = value
                    
    return obj

def pickle_game_state():
    objects_to_save = (
    "game_objects",
    "animations",
    "animation_systems",
    "events",
    "pipes",
    "spritesheets",
    "logs",
    "fonts",
    "saved_data_dicts",
    #"surface_cache",
    "current_pressed_button",
    "active_levels",
    "fps_text_box",
    "camera",
    "player",
    "keys",
    "mx",
    "my",
    "mp",
    "ml",
    "mm",
    "mr",
    "smx",
    "smy",
    "tmx",
    "tmy",
    "current_states",
    "sound_dict",
    "current_music"
    )
    save_dict = {}
    for obj_name in  objects_to_save:
        obj = g.__dict__[obj_name]
        obj = make_object_pickle_ready(obj)
        save_dict.update({obj_name:obj})
            
    pickled_data = pickle.dumps(save_dict)
    #this needs to be done to turn all the pickled pygame objects back to normal
    unpickle_game_state(save_dict)

    return pickled_data

def unpickle_game_state(save_dict):
    g.surface_cache = {}
    load_dict = {}
    for obj_name, obj in  save_dict.items():
        obj = make_object_pickle_unready(obj)
        load_dict.update({obj_name:obj})
    return 

def save(file_path, light=False):
    #if light is set to true, lower save/load times by deleting certain unimportant entities
    if light:
        if "class_Projectile" in g.game_objects.keys():
            for proj in g.game_objects.get("class_Projectile", [])[:]:
                proj.delete()

        if "class_Effect" in g.game_objects.keys():
            for effect in g.game_objects.get("class_Effect", [])[:]:
                effect.delete()
        
    with open(file_path,"wb") as file:
        pickled_state = pickle_game_state()
        file.write(pickled_state)

def load_game_state(file_path):
    with open(file_path,"rb") as file:
        data = file.read()
        save_dict = pickle.loads(data)
        unpickle_game_state(save_dict)
        g.__dict__.update(save_dict)

class Saved_Data():
    def __init__(self, name, save_on_quit=True):
        self.name = name

        self.save_on_quit = save_on_quit
        
        self.load()

        g.saved_data_dicts.update({self.name:self})
    
    #get the value of a key from the data_dict
    def get(self, key):
        return self.data_dict[key]
    
    #set the value of a key in the data_dict
    def set(self, key, value):
        self.data_dict.update({key:value})

    #load the data_dict from a file, or create an empty data_dict if loading fails
    def load(self):
        path = g.data_dir+self.name+".dat"
        try:
            with open(path, "r") as data_file:
                data = data_file.read()
                self.data_dict = util.turn_string_into_dict(data)
                
        except FileNotFoundError:
            Warning("Failed to find file at path "+path+", using empty data dict for "+self.name)
            self.data_dict = {}

    #save data_dict into file
    def save(self):
        data_string = ""
        for k,v in self.data_dict.items():
            data_string += k+"="+str(v)+"\n"
        with open(g.data_dir+self.name+".dat", "w") as data_file:

            data_file.write(data_string)
            

class Saved_Variable():
    def __init__(self, var_name, var_obj, data_dict, load_on_start=True, load_on_reset=False, save_on_change=False, key=None):
        self.var_name = var_name
        self.var_obj = var_obj

        if key:
            self.key = key
        else:
            self.key = str(type(self.var_obj))+"."+str(self.var_name)


        if type(data_dict) == str:
            self.data_dict = g.saved_data_dicts[data_dict]
        elif type(data_dict) == Saved_Data:
            self.data_dict = data_dict
        else:
            raise TypeError("Expected string or Saved_Data object, got "+str(type(data_dict)) ) 
        
        #attempt to get value from data dict
        try:
            self.load()
        except KeyError:
            Warning("Failed to find key: "+self.key+" in "+self.data_dict.name+", adding...")
            self.save(save_file=False)
        

        self.load_on_start = load_on_start
        self.load_on_reset = load_on_reset
        self.save_on_change = save_on_change

        if self.save_on_change:
            self.old_var_val = util.get_variable_value(self.var_name, variable_obj=self.var_obj)

        g.saved_variables.append(self)

    def update(self):
        if self.save_on_change:
            current_val = util.get_variable_value(self.var_name, variable_obj=self.var_obj)

            if current_val != self.old_var_val:
                self.save(save_file=False)
            

    def load(self):
        util.set_variable_value(self.var_name, self.data_dict.get(self.key), variable_obj=self.var_obj)

    def save(self, save_file=True):
        self.data_dict.set(self.key, util.get_variable_value(self.var_name, variable_obj=self.var_obj))
        if save_file:
            self.data_dict.save()

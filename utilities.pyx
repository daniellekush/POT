# cython: profile=True
# cython: language_level=3
# cython: infer_types=True

import global_values as g

import pygame as p
import random as r
import math as m
import re
import importlib
import sys

#helper functions
def nmx(double x, to_int=True):
    normalised_x = x/g.WIDTH
    if to_int:
        normalised_x = int(normalised_x)
    return normalised_x

def nmy(double y, to_int=True):
    normalised_y = y/g.HEIGHT
    if to_int:
        normalised_y = int(normalised_y)
    return normalised_y

def dnmx(double x, to_int=True):
    normalised_x = x*g.WIDTH
    if to_int:
        normalised_x = int(normalised_x)
    return normalised_x

def dnmy(double y, to_int=True):
    normalised_y = y*g.HEIGHT
    if to_int:
        normalised_y = int(normalised_y)
    return normalised_y

#get the magnitude of a vector
def get_magnitude(double x, double y):
    return ((x**2) + (y**2))**0.5

#get the distance between two points
def get_distance(double x1, double y1, double x2, double y2):
    x = x2-x1
    y = y2-y1
    dist = ((x**2) + (y**2))**0.5
    return dist

#get the angle between two points
def get_angle(double x1, double y1, double x2, double y2):
    x = x2-x1
    y = y2-y1
    angle = m.atan2(y,x)
    return angle
    
#check if an angle is between two other angles
def get_angle_bound(angle, b1, b2, degrees=False):
    if degrees:
        angle = m.radians(angle)
        b1 = m.radians(b1)
        b2 = m.radians(b2)
        
    angle %= (2*m.pi)
    b1 %= (2*m.pi)
    b2 %= (2*m.pi)
        
    #angle bound zone doesn't go through 0
    if b2 > b1:
        return b1 <= angle <= b2
    else:
        #bound zone 1: b1->0
        if b1 <= angle <= 2*m.pi:
            return True
            
        #bound zone 2: 0->b2
        if 0 <= angle <= 2*m.pi:
            return True
            
        return False
        
#clamp an angle between two other angles
#returns the clamped angle
#if get_bound is True, then it also returns whether the angle was in bounds to begin with
#def clamp_angle(angle, b1, b2, get_bound=False, degrees=False):
#    if degrees:
#        b1 = m.radians(b1)
#        b2 = m.radians(b2)
        
#    if get_angle_bound(angle, b1, b2):
#        if get_bound:
#            return angle, True
#        else:
#            return angle
#    else:
#        if 

#clamp a value between a minimum and maximum value
def clamp(double value, double min_value, double max_value):
    if min_value is not None and value < min_value:
        value = min_value
    elif min_value is not None and value > max_value:
        value = max_value
    return value

#interpolate between two values or lists of values, either linearly or smoothly
def interpolate_between_values(v1_list, v2_list, amount_list, smooth=False):
    if type(v1_list) != list:
        v1_list = [v1_list]
        v2_list = [v2_list]
        amount_list = [amount_list]
        
    for i in range(len(v1_list)):
        v1 = v1_list[i]
        v2 = v2_list[i]
        amount = amount_list[i]
    
        if smooth:
            interpolated_value = ((amount*amount*(3-(2*amount)))*(v2-v1))+v1
        else:
            difference = v2-v1
            interpolated_value = v1+(difference*amount)
        return interpolated_value

def rotate_list_left(l, n):
    return l[n:] + l[:n]

def rotate_list_right(l, n):
    return l[-n:] + l[:-n]

#given a start point and an angle, get the point a certain distance away from the start point, where the angle between the two points
#is the same as the angle given
def get_line_end(x, y, angle, distance, degrees=False):
    if degrees:
        end_x = x+( m.sin(m.radians(angle)) *distance)
        end_y = y+( m.cos(m.radians(angle)) *distance)
    else:
        end_x = x+(m.sin(angle)*distance)
        end_y = y+(m.cos(angle)*distance)

    return end_x, end_y

#rotate a point around another point
def rotate_point(origin, point, double angle, degrees=False):
    #completely stolen from Mark Dickinson from stackoverflow
    if degrees:
        angle = m.radians(angle)
        
    ox, oy = origin
    px, py = point

    qx = ox + m.cos(angle) * (px - ox) - m.sin(angle) * (py - oy)
    qy = oy + m.sin(angle) * (px - ox) + m.cos(angle) * (py - oy)
    return qx, qy

#rotate an angle a specified amount "towards" another angle

#rotate a rectangle around a point
def rotate_rect(origin, rect, angle, degrees=False):
    if degrees:
        angle = m.radians(angle)

    #rotate the top left point of rect
    tl = rotate_point(origin, rect.topleft, angle)
    #rotate the top right point of rect
    tr = rotate_point(origin, rect.topright, angle)
    #rotate the bottom left point of rect
    bl = rotate_point(origin, rect.bottomleft, angle)
    #rotate the bottom right point of rect
    br = rotate_point(origin, rect.bottomright, angle)

    return [tl, tr, bl, br]

#turn a raw string formatted like this
#"""
#section one:
#line1
#line2
#section one:
#line 1
#"""
#into a dictionary where each value is a list
def split_string_into_sections(raw_string, split_text, lines=True):
    split_finder_pattern = re.compile(split_text+" [a-zA-Z0-9_]+:")
    
    sections_names = [n[len(split_text)+1:-1] for n in re.findall(split_finder_pattern, raw_string)]
    sections_data = re.split(split_finder_pattern, raw_string)[1:]

    #split into lines
    if lines:
        sections_lines = []
        for section_data in sections_data:
            section_lines = [l for l in section_data.split("\n") if l]
            sections_lines.append(section_lines)
        sections = dict(zip(sections_names, sections_lines))
    #split into raw strings
    else:
        sections = dict(zip(sections_names, sections_data))
    
    return sections

#turn a string like this
#key1=value1
#key2=value2
#key3=value3
#into a dictionary
def turn_string_into_dict(string_data, convert_keys=False):
    #setup tile_key dictionary
    dictionary = {}
    
    #split raw_key_data into lines, with each line containing a tile character and a tile name
    string_data_lines = string_data.split("\n")

    #create tile key
    for item_string in string_data_lines:
        #ignore empty key_strings
        if item_string and not item_string.isspace():
            key, value = item_string.split("=")
            if convert_keys:
                key = convert_string_to_alternate_type(key)
            value = convert_string_to_alternate_type(value)
            dictionary.update({key:value})

    return dictionary

#convert a string value into another type
#this can be used for "simple" data types e.g. Floats and Booleans
#or more complex types such as Entities
#this function is recursive so arguments needed to create complex types will also be converted to alternate types
def convert_string_to_alternate_type(value_string):
    #setup scriptable types if they have not already been set up
    #if not scriptable_types:
    
    #parse through value_string
    #whether a "container" (string literal or list) is currently being processed, and if so what character is used
    container = False
    #amount of nested complex types
    nest = 0
    list_nest = 0
    
    #the first part of the string, before the opening bracket e.g. Rect
    #if the string can be converted to a simple type, e.g. an int, the name will be the whole string
    name = ""
    #if the string can not be converted to a simple type, the args will be a list of strings that are contained within it's brackets
    args = []
    current_arg = ""

    for char in value_string:
        if container:
            current_arg += char
            if (container == '"' and char == '"') or (container == "'" and char == "'") or (container == "[" and char == "]"):
                container = False
                
        else:    
            if char == "(":
                nest += 1
                if nest == 1:
                    continue
            elif char == ")":
                nest -= 1
                #prevent closing bracket from being added to name
                if nest == 0:
                    args.append(current_arg)
                    continue
                
            if nest == 0:
                if not char.isspace():
                    name += char
            else:
                if char == '"' or char == "'" or char == "[" or char == "{":
                    container = char
                elif nest == 1:
                    if char == ",":
                        args.append(current_arg)
                        current_arg = ""
                        continue
                    
                if not char.isspace(): 
                    current_arg += char
                    
    #args are created by calling this functions recursively
    args = [convert_string_to_alternate_type(arg) for arg in args]
    if args == [""]:
        args = []
    
    #SIMPLE TYPES (int, bool, list etc)
    #make value_string numerical if possible
    if name.replace('.','',1).replace('-','',1).isdigit():
        value_converted = float(name)
    #make value_string boolean if possible
    elif name == "True":
        value_converted = True
    elif name == "False":
        value_converted = False
    elif name == "None":
        value_converted = None

    #MATH/LOGIC OPERATIONS
    elif name == "Add":
        value_converted = args[0]+args[1]
    elif name == "Sub":
        value_converted = args[0]-args[1]
    elif name == "Mul":
        value_converted = args[0]*args[1]
    elif name == "Div":
        value_converted = args[0]/args[1]
    elif name == "Mod":
        value_converted = args[0]%args[1]
    elif name == "Int_Div":
        value_converted = args[0]//args[1]
    elif name == "Round":
        value_converted = round(args[0])
    elif name == "Floor":
        value_converted = m.floor(args[0])
    elif name == "Ceiling":
        value_converted = m.ceiling(args[0])
        
    elif name == "Radians":
        value_converted = m.radians(args[0])
    elif name == "Degrees":
        value_converted = m.degrees(args[0])
    elif name == "Abs":
        value_converted = abs(args[0])
    elif name == "Min":
        value_converted = min(args)
    elif name == "Max":
        value_converted = max(args)
    elif name == "Any":
        value_converted = any(args)
    elif name == "All":
        value_converted = all(args)
    elif name == "Sum":
        value_converted = sum(args)

    #COMPLEX TYPES
    #make value_string a list if possible
    elif name.startswith("[") and name.endswith("]"):
        value_converted = [convert_string_to_alternate_type(v) for v in name.split(",")]
    #make value_string a list if possible (this version supports nested lists)
    elif name == "List":
        value_converted = args
    #make value_string a set if possible
    elif name == "Set":
        value_converted = set(args)
    elif name == "FrozenSet":
        value_converted = frozenset(args)
    #make value_string a tuple if possible
    elif name == "Tuple":
        value_converted = tuple(args)
    #make value_string a dictionary if possible
    elif name == "Dict":
        value_converted = dict(args)

    #DATA OBTAINING
    #get global value from value_string
    elif name == "Obj_Value":
        value_converted = getattr(args[0], args[1:])
    elif name == "Func_Value":
        value_converted = getattr(args[0], args[1])(*args[2], **args[3])
    elif name == "Container_Value":
        value_converted = args[0][args[1]]
    elif name == "Module":
        importlib.import_module(args[0])
        value_converted = sys.modules[args[0]]

    #SHORTCUTS (can be done using other methods but this is just easier to read/write)
    elif name == "Global":
        value_converted = getattr(g,args[0])
    elif name == "Get_Game_Object_Type":
        value_converted = g.game_objects[args[0]]
    elif name == "Get_Spritesheet":
        value_converted = g.spritesheets[args[0]]
    elif name == "Get_Font":
        value_converted = g.fonts[args[0]]
    elif name == "Get_Log":
        value_converted = g.logs[args[0]]
        
    else:
        #remove quotes
        if (value_string.startswith('"') and value_string.endswith('"')) or (value_string.startswith("'") and value_string.endswith("'")):
            value_converted = value_string[1:-1]
        else:
            value_converted = value_string

    return value_converted

def bound_text(font, rect, text, safe_bounding=False):
    def handle_word(w):
        if word == "\n":
            result_w = ""
        elif word == "\t":
            result_w = "    "
        else:
            result_w = word+" "

        return result_w
        
    lines = []
    text_height = font.size(text)[1]

    text = text.replace("\n", " \n ").replace("\t", " \t ")

    words = text.split(" ")
    x = 0
    y = 0

    current_line_text = ""
    for word in words:
        if y+text_height <= rect.height:

            #pygame doesn't always seem to get bounding sizes right so here's an option to be safe
            if safe_bounding:
                width = font.size(word+" ")[0]
            else:
                width = font.size(word)[0]
             
            width_with_space = font.size(word+" ")[0]

            new_line = False
            if x+width > rect.w:
                new_line = True
            if word == "\n":
                new_line = True
            
            if new_line:
                lines.append(current_line_text)
                
                current_line_text = handle_word(word)
                    
                x = width_with_space
                y += text_height
            else:
                current_line_text += handle_word(word)
                x += width_with_space

    lines.append(current_line_text)

    return lines

def encrypt_value(value):
    encrypted_value = ((value+31.4421)*9.88)**2
    return encrypted_value

def decrypt_value(value, int_check=False):
    decrypted_value = ((value**0.5)/9.88)-31.4421

    #if it is known that the decrypted value should be an int, this will give a warning if it isn't
    #(but it does take into account that python float stuff could modify the value very slightly)
    if int_check:
        int_dif = abs(decrypted_value-int(decrypted_value))
        if int_dif > 0.00001:
            return False
        else:
            return int(decrypted_value)

    return decrypted_value

def check_collision(rect, collision_mask, collision_dict, exceptions, obj=None):
    def get_entities(entity_list):
        chosen_entities = []
        for ent_type, can_collide in collision_dict.items():
            if ent_type.startswith("class_"):
                for entity in entity_list:
                    if can_collide and entity not in exceptions and ent_type in entity.class_aliases:
                        chosen_entities.append(entity)
                    
        return chosen_entities
    colliding = False

    #---LEVELS---
    #check for collisions with levels
    if collision_dict.get("levels", False):
        for level in g.active_levels:
            colliding = level.check_collision(rect, collision_mask, obj=obj)
            if colliding:
                return colliding

    if collision_dict.get("border", False):
        colliding = True
        for level in g.active_levels:
            if level.rect.contains(rect):
                colliding = False
                break
                
        if colliding:
            return colliding

    #---ENTITIES---
    if g.segmenting_in_levels:
        check_entities_amount = 0
        for ent_type, can_collide in collision_dict.items():
            if can_collide and ent_type.startswith("class_"):
                check_entities_amount += len(g.game_objects.get(ent_type, []))

        #get entities using segment method
        check_entities = []
    
    if g.segmenting_in_levels and check_entities_amount > g.ENABLE_SEGMENT_ENTITY_THRESHOLD:
        for level in g.active_levels:
            if level.enable_segmenting:
                for segment in level.get_segments(rect):
                    check_entities += get_entities(segment.entities)
                    
        if not check_entities:
            check_entities = get_entities(g.game_objects.get("class_Entity",[]))
    #or don't
    else:
        check_entities = get_entities(g.game_objects.get("class_Entity",[]))
                
    for entity in check_entities:
        if entity not in exceptions and entity.solid:
            if entity.collide_rect.colliderect(rect):
                if obj:
                    #stop early if self or creature has mask collision and there is no mask collision
                    if obj.mask_collision or entity.mask_collision:
                        collision_offset = (int(entity.x-rect.x), int(entity.y-rect.y))
                        if not obj.collision_mask.overlap(entity.collision_mask, collision_offset):
                            continue
                        
                colliding = entity
                break

    #---CAMERA---
    if collision_dict.get("camera", False):
        if not g.camera.check_rect_fully_in_screen(rect):
            colliding = g.camera.reverse_transform_rect(p.Rect(0, 0, g.WIDTH, g.HEIGHT))

    return colliding

#crappy limited way of checking for collision with a line
#should really only use it for testing whether sightlines should be tested
#oh and don't use it on Mask_Levels because it is SLOW
#(and it doesn't work on Entity mask stuff)
def check_line_collision(p1, p2, collision_dict, exceptions, obj=None):
    def get_entities(entity_list):
        chosen_entities = []
        for ent_type, can_collide in collision_dict.items():
            if ent_type.startswith("class_"):
                for entity in entity_list:
                    if can_collide and entity not in exceptions and ent_type in entity.class_aliases:
                        chosen_entities.append(entity)
                    
        return chosen_entities
    colliding = False

    #---LEVELS---
    #check for collisions with levels
    if collision_dict.get("levels", False):
        for level in g.active_levels:
            colliding = level.check_line_collision(p1, p2)
            if colliding:
                return colliding

    if collision_dict.get("border", False):
        colliding = True
        for level in g.active_levels:
            if level.rect.clipline(p1, p2):
                colliding = False
                break
                
        if colliding:
            return colliding

    #---ENTITIES---
    if g.segmenting_in_levels:
        check_entities_amount = 0
        for ent_type, can_collide in collision_dict.items():
            if can_collide and ent_type.startswith("class_"):
                check_entities_amount += len(g.game_objects.get(ent_type, []))

        #get entities using segment method
        check_entities = []

    
    if g.segmenting_in_levels and check_entities_amount > g.ENABLE_SEGMENT_ENTITY_THRESHOLD:
        #get the maximum rect that contains the full line for getting all the required segments
        #this could be upgraded to use a step-based approach to get a smaller list of segments
        line_bound_rect = p.Rect(p1,p2)
        for level in g.active_levels:
            if level.enable_segmenting:
                for segment in level.get_segments(line_bound_rect):
                    check_entities += get_entities(segment.entities)
                    
        if not check_entities:
            check_entities = get_entities(g.game_objects.get("class_Entity",[]))
    #or don't
    else:
        check_entities = get_entities(g.game_objects.get("class_Entity",[]))
                
    for entity in check_entities:
        if entity not in exceptions and entity.solid:
            if entity.collide_rect.clipline(p1,p2):
                        
                colliding = entity
                break

    #---CAMERA---
    if collision_dict.get("camera", False):
        if not p.Rect(0,0,g.WIDTH,g.HEIGHT).clipline(g.camera.transform_point(p1), g.camera.transform_point(p2)):
            colliding = g.camera.reverse_transform_rect(p.Rect(0, 0, g.WIDTH, g.HEIGHT))

    return colliding

def get_variable_value(variable_name, variable_obj=None):
    if variable_obj:
        value = getattr(variable_obj, variable_name)
    else:
        value = getattr(g,variable_name)
    return value

def set_variable_value(variable_name, value, variable_obj):
    if variable_obj:
        setattr(variable_obj, variable_name, value)
    else:
        setattr(g, variable_name, value)

def get_mouse_point_distance(min_distance, max_distance, point=g.SCREEN_RECT.center, normalise=False):
    mx, my = p.mouse.get_pos()
    dist = clamp(get_distance(point[0], point[1], mx, my), min_distance, max_distance)
    
    if normalise:
        dist_range = max_distance-min_distance
        dist -= min_distance
        dist /= dist_range

    return dist

def get_mouse_point_angle(point=g.SCREEN_RECT.center):
    mx, my = p.mouse.get_pos()
    angle = get_angle(point[0], point[1], mx, my)
    return angle

#for choosing between a series of objects, each with a different spawn weight
def choose_weighted_object(obj_dict):
    summed_values = []
    value_list = list(obj_dict.values())
    for i, value in enumerate(value_list):
        summed_values.append(sum(value_list[:i+1]))
    chosen_value = r.random()*sum(value_list)
    
    for i, obj in enumerate(obj_dict.keys()):
        value = summed_values[i]
        if chosen_value <= value:
            return obj

def get_opposite_direction(direction):
    directions = ["up", "down", "left", "right"]
    opposite_directions = ["down", "up", "right", "left"]
    original_direction = direction
    for d in directions:
        if d in original_direction:
            d_index = directions.index(d)
            opposite_direction = opposite_directions[d_index]
            direction = direction.replace(d, opposite_direction)
    return direction

#set a rect position so that a specific part of the rect is in a specific point
def pin_rect(rect, rect_point, point, in_place=False):
    if in_place:
        new_rect = rect
    else:
        new_rect = rect.copy()
        
    rect_point_x = rect.x+(rect.w*rect_point[0])
    rect_point_y = rect.y+(rect.h*rect_point[1])

    x_diff = point[0]-rect_point_x
    y_diff = point[1]-rect_point_y

    rect.x += x_diff
    rect.y += y_diff

    return new_rect

def scale_rect(rect, scale):
    scaled_width = rect.width*scale
    scaled_height = rect.height*scale
    old_center = rect.center
    
    rect.width = scaled_width
    rect.height = scaled_height

    rect.center = old_center

def get_random_between(v1, v2):
    val = v1+(r.random()*(v2-v1))
    return val

def get_pretty_time(ticks, show_minutes=True, show_seconds=True, show_milliseconds=True, separator=":", digits=2, zfill=True):
    seconds = (ticks//g.MAX_TICK_RATE)
    leftover_seconds = int(seconds%60)
    minutes = int(seconds//60)

    leftover_milliseconds = int((ticks%g.MAX_TICK_RATE)/g.MAX_TICK_RATE*1000)
    
    time_string = ""
    if show_minutes:
        if digits:
            str_minutes = str(minutes)[:digits]
        else:
            str_minutes = str(minutes)

        if zfill:
            str_minutes = str_minutes.zfill(digits)
            
        time_string += str_minutes

        if show_seconds:
            time_string += separator

    if show_seconds:
        if digits:
            str_seconds = str(leftover_seconds)[:digits]
        else:
            str_seconds = str(leftover_seconds)

        if zfill:
            str_seconds = str_seconds.zfill(digits)
            
        time_string += str_seconds

        if show_milliseconds:
            time_string += separator

    if show_milliseconds:
        if digits:
            str_milliseconds = str(leftover_milliseconds)[:digits]
        else:
            str_milliseconds = str(leftover_milliseconds)

        if zfill:
            str_milliseconds = str_milliseconds.zfill(digits)
            
        time_string += str_milliseconds

    return time_string

def quit_game():
    for saved_data_file in g.saved_data_dicts.values():
        if saved_data_file.save_on_quit:
            saved_data_file.save()
            
    p.display.quit()
    sys.exit()
    quit()
    

# cython: profile=True
# cython: language_level=3
# cython: infer_types=True

from . import global_values as g

import pygame as p
import random as r
import math as m
import re
import importlib
import sys


def nmx(double x, to_int=False):
    """
    Takes the x component of the screen coordinate and converts it to a value between 0 and 1.
    
    Used for relative positions.
    
    Parameters
    ----------
    x : number
    x component of the screen coordinate.
    to_int : boolean
    If True, converts to integer - default is False.
    
    Returns
    -------
    normalised_x
    An integer which is between 0 and 1.
    Any out-of-bounds screen value will result in a value which is not between 0 and 1.
    """
    normalised_x = x/g.WIDTH
    if to_int:
        normalised_x = int(normalised_x)
    return normalised_x


def nmy(double y, to_int=False):
    """
    Takes the y component of the screen coordinate and converts it to a value between 0 and 1.
    
    Used for relative positions.
    
    Parameters
    ----------
    y : number
    y component of the screen coordinate.
    to_int : boolean
    If True, converts to integer - default is False.
    
    Returns
    -------
    normalised_y
    An integer which is between 0 and 1.
    Any out-of-bounds screen value will result in a value which is not between 0 and 1.
    """
    normalised_y = y/g.HEIGHT
    if to_int:
        normalised_y = int(normalised_y)
    return normalised_y


def dnmx(double x, to_int=True):
    """
    Takes a value between 0 and 1 and converts it to the x component of the screen coordinate.
    
    Parameters
    ----------
    x : number
    Value between 0 and 1.
    to_int : boolean
    If True, converts to integer - default is True.
    
    Returns
    -------
    normalised_x
    An integer.
    Any out-of-bounds screen value will result in a value which is greater than the screen size.
    """
    normalised_x = x*g.WIDTH
    if to_int:
        normalised_x = int(normalised_x)
    return normalised_x


def dnmy(double y, to_int=True):
    """
    Takes a value between 0 and 1 and converts it to the y component of the screen coordinate.
    
    Parameters
    ----------
    y : number
    Value between 0 and 1.
    to_int : boolean
    If True, converts to integer - default is True.
    
    Returns
    -------
    normalised_y
    An integer.
    Any out-of-bounds screen value will result in a value which is greater than the screen size.
    """
    normalised_y = y*g.HEIGHT
    if to_int:
        normalised_y = int(normalised_y)
    return normalised_y


def get_magnitude(double x, double y):
    """
    Gets the magnitude of a vector.
    
    Parameters
    ----------
    x : number
    x component of vector.
    y : number
    y component of vector.
    
    Returns
    -------
    The magnitude of a vector as a number.
    """
    return ((x**2) + (y**2))**0.5


def get_distance(double x1, double y1, double x2, double y2):
    """
    Gets the distance between two points.
    
    Parameters
    ----------
    x1 : number
    x component of point 1.
    x2 : number
    x component of point 2.
    y1 : number
    y component of point 1.
    y2 : number
    y component of point 2.
    
    Returns
    -------
    dist
    The distance between two points as a number.
    """
    x = x2-x1
    y = y2-y1
    dist = ((x**2) + (y**2))**0.5
    return dist


def get_angle(double x1, double y1, double x2, double y2):
    """
    Gets the angle between two points.
    
    Parameters
    ----------
    x1 : number
    x component of point 1.
    x2 : number
    x component of point 2.
    y1 : number
    y component of point 1.
    y2 : number
    y component of point 2.
    
    Returns
    -------
    angle
    The angle between two points.
    """
    x = x2-x1
    y = y2-y1
    angle = m.atan2(y, x)
    return angle


def get_angle_bound(angle, b1, b2, degrees=False):
    """
    Checks if an angle is between two other angles.
    
    Parameters
    ----------
    angle : number
    Angle to check for.
    b1 : number
    First angle.
    b2 : number
    Second angle.
    degrees : boolean
    If True, assumes the given angles are in degrees instead of radians - default is False.
    
    Returns
    -------
    True or False.
    """
    if degrees:
        angle = m.radians(angle)
        b1 = m.radians(b1)
        b2 = m.radians(b2)

    angle %= (2*m.pi)
    b1 %= (2*m.pi)
    b2 %= (2*m.pi)

    if b2 > b1:
        return b1 <= angle <= b2
    else:
        if b1 <= angle <= 2*m.pi:
            return True

        if 0 <= angle <= 2*m.pi:
            return True

        return False


# TODO: check if left is actually left and if right is actually right
def get_angle_difference(a1, a2, direction="shortest", degrees=False):
    """
    Get difference between two angles, measured from a1 to a2
    
    Parameters
    ----------
    a1 : number
    First angle.
    a2 : number
    Second angle.
    direction : string
    Direction of a2 from a1 - "left", "right" or "shortest".
    degrees : boolean
    If True, assumes the given angles are in degrees instead of radians - default is False.
    
    Raises
    ------
    ValueError if direction argument is not "left", "right" or "shortest".
    
    Returns
    -------
    angle
    Difference between the two angles as a number.
    """
    if degrees:
        a1 = m.radians(a1)
        a2 = m.radians(a2)

    if direction == "shortest":
        angle = a1-a2
        if angle > 1*m.pi:
            angle = (2*m.pi)-angle

    elif direction == "left":
        angle = (a1-a2) % (2*m.pi)

    elif direction == "right":
        angle = (a2-a1) % (2*m.pi)

    else:
        raise ValueError("Direction argument not recognized (please use left, right or shortest)")

    if degrees:
        angle = m.degrees(angle)
    return angle


def move_to_target_angle(angle, target_angle, distance, stop_on_reaching_target=True, degrees=False):
    """
    Move an angle a set amount towards a target angle.
    
    Parameters
    ----------
    angle : number
    Angle to move.
    target_angle : number
    Target angle.
    distance : string
    Distance to move.
    stop_on_reaching_target : boolean
    If True, the angle will stop at the target instead of going past it - default is True.
    degrees : boolean
    If True, assumes the given angles are in degrees instead of radians - default is False.
    
    Returns
    -------
    angle
    Moved angle as a number.
    """
    if degrees:
        angle = m.radians(angle)
        target_angle = m.radians(target_angle)

    # left
    if get_angle_difference(angle, target_angle, direction="left") >= get_angle_difference(angle, target_angle, direction="right"):
        angle -= distance
    # right
    else:
        angle += distance

    angle %= (2*m.pi)

    if degrees:
        angle = m.degrees(angle)

    return angle


# clamp an angle between two other angles
# returns the clamped angle
# if get_bound is True, then it also returns whether the angle was in bounds to begin with
# def clamp_angle(angle, b1, b2, get_bound=False, degrees=False):
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


def clamp(double value, double min_value, double max_value):
    """
    Clamp a value between a minimum and maximum value.
    
    Parameters
    ----------
    value : number
    Value to clamp between minimum and maximum.
    min_value : number
    Minimum value.
    max_value : number
    Maximum value.
    
    Returns
    -------
    value
    Clamped value.
    """
    if min_value is not None and value < min_value:
        value = min_value
    elif min_value is not None and value > max_value:
        value = max_value
    return value


def interpolate_between_values(v1_list, v2_list, amount_list, smooth=False):
    """
    Interpolate between two values or lists of values, either linearly or smoothly.
    
    Parameters
    ----------
    v1_list : number/list
    First value or list of values.
    v2_list : number/list
    Second value or list of values.
    amount_list : number/list
    Amount or list of amount to interpolate by - between 0 and 1.
    smooth : boolean
    If True, interpolate smoothly - default is False.
    
    Returns
    -------
    interpolated_value
    Interpolated value as a number or list of interpolated number values.
    """
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
    """
    Rotates values in list to the left.
    
    Parameters
    ----------
    l : list
    List to rotate.
    n : integer
    Number of spaces to rotate.
    
    Returns
    -------
    l
    List rotated to the left.
    """
    return l[n:] + l[:n]


def rotate_list_right(l, n):
    """
    Rotates values in list to the right.
    
    Parameters
    ----------
    l : list
    List to rotate.
    n : integer
    Number of spaces to rotate.
    
    Returns
    -------
    l
    List rotated to the right.
    """
    return l[-n:] + l[:-n]


def get_line_end(x, y, angle, distance, degrees=False):
    """
    Given a start point and an angle, get the point a certain distance away from the start point, where the angle between the two points is the same as the angle given.
    
    Parameters
    ----------
    x : number
    x component of a coordinate.
    y : number
    y component of a coordinate.
    angle : number
    Angle to check against.
    distance : number
    Distance away from the start point.
    degrees : boolean
    If True, assumes the given angles are in degrees instead of radians - default is False.
    
    Returns
    -------
    end_x, end_y
    x and y components of the line end.
    """
    if degrees:
        end_x = x+(m.sin(m.radians(angle)) * distance)
        end_y = y+(m.cos(m.radians(angle)) * distance)
    else:
        end_x = x+(m.sin(angle)*distance)
        end_y = y+(m.cos(angle)*distance)

    return end_x, end_y


def rotate_point(origin, point, double angle, degrees=False):
    """
    Rotate a point around another point.
    
    Parameters
    ----------
    origin : tuple
    Point to rotate around.
    point : tuple
    Point that is rotating.
    angle : number
    Angle to rotate against.
    degrees : boolean
    If True, assumes the given angles are in degrees instead of radians - default is False.
    
    Returns
    -------
    qx, qy
    x and y components of the point.
    """
    # completely stolen from Mark Dickinson from stackoverflow
    if degrees:
        angle = m.radians(angle)

    ox, oy = origin
    px, py = point

    qx = ox + m.cos(angle) * (px - ox) - m.sin(angle) * (py - oy)
    qy = oy + m.sin(angle) * (px - ox) + m.cos(angle) * (py - oy)
    return qx, qy


def rotate_rect(origin, rect, angle, degrees=False):
    """
    Rotate a rectangle around a point.
    
    Parameters
    ----------
    origin : tuple
    Point to rotate around.
    rect : tuple
    Rectangle that is rotating.
    angle : number
    Angle to rotate against.
    degrees : boolean
    If True, assumes the given angles are in degrees instead of radians - default is False.
    
    Returns
    -------
    List of four rotated points.
    """
    if degrees:
        angle = m.radians(angle)

    tl = rotate_point(origin, rect.topleft, angle)
    tr = rotate_point(origin, rect.topright, angle)
    bl = rotate_point(origin, rect.bottomleft, angle)
    br = rotate_point(origin, rect.bottomright, angle)

    return [tl, tr, bl, br]


def split_string_into_sections(raw_string, split_text, lines=True):
    """
    Turn a raw string format below into a dictionary where each value is a list.
    
    section one:
    line1
    line2
    section two:
    line 1
    
    Parameters
    ----------
    raw_string : string
    Raw string to format into dictionary.
    split_text : string
    Text which splits each section.
    lines : boolean
    If True, split text into lines instead of raw strings - default is True.
    
    Returns
    -------
    sections
    Dictionary containing each section as a list.
    """
    split_finder_pattern = re.compile(split_text+" [a-zA-Z0-9_]+:")

    sections_names = [n[len(split_text)+1:-1] for n in re.findall(split_finder_pattern, raw_string)]
    sections_data = re.split(split_finder_pattern, raw_string)[1:]

    if lines:
        sections_lines = []
        for section_data in sections_data:
            section_lines = [l for l in section_data.split("\n") if l]
            sections_lines.append(section_lines)
        sections = dict(zip(sections_names, sections_lines))
    else:
        sections = dict(zip(sections_names, sections_data))

    return sections


def turn_string_into_dict(string_data, convert_keys=False):
    """
    Turn a raw string format below into a dictionary where each line is a key-value pair.
    
    key1=value1
    key2=value2
    key3=value3
    
    Parameters
    ----------
    string_data : string
    Raw string to format into dictionary.
    convert_keys : boolean
    If True, convert key strings into other data types - default is False.
    
    Returns
    -------
    dictionary
    Dictionary of generated key-value pairs.
    """
    dictionary = {}

    string_data_lines = string_data.split("\n")

    for item_string in string_data_lines:
        if item_string and not item_string.isspace():
            key, value = item_string.split("=")
            if convert_keys:
                key = convert_string_to_alternate_type(key)
            value = convert_string_to_alternate_type(value)
            dictionary.update({key: value})

    return dictionary


def convert_string_to_alternate_type(value_string):
    """
    Convert a string value into another data type.
    This function is recursive so arguments needed to create complex types will also be converted to alternate types.
    
    Parameters
    ----------
    value_string : string
    Raw string to format into another data type.
    
    Returns
    -------
    value_converted
    Original string as a new data type.
    """
    # setup scriptable types if they have not already been set up
    # if not scriptable_types:

    # parse through value_string
    # whether a "container" (string literal or list) is currently being processed, and if so what character is used
    container = False
    nest = 0
    list_nest = 0

    name = ""
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

    args = [convert_string_to_alternate_type(arg) for arg in args]
    if args == [""]:
        args = []

    if name.replace('.', '', 1).replace('-', '', 1).isdigit():
        value_converted = float(name)
    # make value_string boolean if possible
    elif name == "True":
        value_converted = True
    elif name == "False":
        value_converted = False
    elif name == "None":
        value_converted = None

    elif name == "Add":
        value_converted = args[0]+args[1]
    elif name == "Sub":
        value_converted = args[0]-args[1]
    elif name == "Mul":
        value_converted = args[0]*args[1]
    elif name == "Div":
        value_converted = args[0]/args[1]
    elif name == "Mod":
        value_converted = args[0] % args[1]
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

    # make value_string a list if possible
    elif name.startswith("[") and name.endswith("]"):
        value_converted = [convert_string_to_alternate_type(v) for v in name.split(",")]
    # make value_string a list if possible (this version supports nested lists)
    elif name == "List":
        value_converted = args
    # make value_string a set if possible
    elif name == "Set":
        value_converted = set(args)
    elif name == "FrozenSet":
        value_converted = frozenset(args)
    # make value_string a tuple if possible
    elif name == "Tuple":
        value_converted = tuple(args)
    # make value_string a dictionary if possible
    elif name == "Dict":
        value_converted = dict(args)

    elif name == "Obj_Value":
        value_converted = getattr(args[0], args[1:])
    elif name == "Func_Value":
        value_converted = getattr(args[0], args[1])(*args[2], **args[3])
    elif name == "Container_Value":
        value_converted = args[0][args[1]]
    elif name == "Module":
        importlib.import_module(args[0])
        value_converted = sys.modules[args[0]]

    elif name == "Global":
        value_converted = getattr(g, args[0])
    elif name == "Get_Game_Object_Type":
        value_converted = g.game_objects[args[0]]
    elif name == "Get_Spritesheet":
        value_converted = g.spritesheets[args[0]]
    elif name == "Get_Font":
        value_converted = g.fonts[args[0]]
    elif name == "Get_Log":
        value_converted = g.logs[args[0]]

    else:
        if (value_string.startswith('"') and value_string.endswith('"')) or (value_string.startswith("'") and value_string.endswith("'")):
            value_converted = value_string[1:-1]
        else:
            value_converted = value_string

    return value_converted


def bound_text(font, rect, text, safe_bounding=False):
    """
    Split a string of text into lines such that they won't exceed the bounds of a rectangle when rendered.
    
    Parameters
    ----------
    font : graphics.Font
    Font of the text.
    rect : pygame.Rect
    Rectangle whose dimensions will be used for bounding.
    text : string
    Text to bound.
    safe_bounding : boolean
    If True, text is guaranteed not to go outside of bounds when rendered, but may not use all available space - default is False.
    
    Returns
    -------
    lines
    List of lines of text.
    """
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
    """
    Encrypt a given number. Use the decrypt_value function to decrypt the value.
    
    Parameters
    ----------
    value : number
    Plaintext.
    
    Returns
    -------
    encrypted_value
    Ciphertext.
    """
    encrypted_value = ((value+31.4421)*9.88)**2
    return encrypted_value


def decrypt_value(value, int_check=False):
    """
    Decrypt a given ciphertext from encrypt_value.
    
    Parameters
    ----------
    value : number
    Ciphertext.
    int_check : boolean
    If True, gives warning if the decrypted value that should be an integer isn't - default is False.
    
    Returns
    -------
    decrypted_value
    Plaintext.
    """
    decrypted_value = ((value**0.5)/9.88)-31.4421

    if int_check:
        int_dif = abs(decrypted_value-int(decrypted_value))
        if int_dif > 0.00001:
            return False
        else:
            return int(decrypted_value)

    return decrypted_value


def check_collision(rect, collision_mask, collision_dict, exceptions, obj=None):
    """
    Check whether collision is occuring within a specific rectangle.
    
    Parameters
    ----------
    rect : number
    Entity bounding rectangle.
    collision_dict : dictionary
    Dictionary containing the things that you want to check for collision against.
    exceptions : collection
    Any objects that you ignore in collision.
    
    Returns
    -------
    colliding
    The first object that there was a collision against.
    """
    def get_entities(entity_list):
        chosen_entities = []
        for ent_type, can_collide in collision_dict.items():
            if ent_type.startswith("class_"):
                for entity in entity_list:
                    if can_collide and entity not in exceptions and ent_type in entity.class_aliases:
                        chosen_entities.append(entity)

        return chosen_entities
    colliding = False

    # ---LEVELS---
    # check for collisions with levels
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

    # ---ENTITIES---
    if g.segmenting_in_levels:
        check_entities_amount = 0
        for ent_type, can_collide in collision_dict.items():
            if can_collide and ent_type.startswith("class_"):
                check_entities_amount += len(g.game_objects.get(ent_type, []))

        # get entities using segment method
        check_entities = []

    if g.segmenting_in_levels and check_entities_amount > g.ENABLE_SEGMENT_ENTITY_THRESHOLD:
        for level in g.active_levels:
            if level.enable_segmenting:
                for segment in level.get_segments(rect):
                    check_entities += get_entities(segment.entities)

        if not check_entities:
            check_entities = get_entities(g.game_objects.get("class_Entity", []))
    else:
        check_entities = get_entities(g.game_objects.get("class_Entity", []))

    for entity in check_entities:
        if entity not in exceptions and entity.solid:
            if entity.collide_rect.colliderect(rect):
                if obj:
                    # stop early if self or creature has mask collision and there is no mask collision
                    if obj.mask_collision or entity.mask_collision:
                        collision_offset = (int(entity.x-rect.x), int(entity.y-rect.y))
                        if not obj.collision_mask.overlap(entity.collision_mask, collision_offset):
                            continue

                colliding = entity
                break

    # ---CAMERA---
    if collision_dict.get("camera", False):
        if not g.camera.check_rect_fully_in_screen(rect):
            colliding = g.camera.reverse_transform_rect(p.Rect(0, 0, g.WIDTH, g.HEIGHT))

    return colliding


def check_line_collision(p1, p2, collision_dict, exceptions, obj=None):
    """
    Checking for collision with a line.
    Should only use for testing whether sightlines should be tested.
    Don't use it on Mask_Levels. Doesn't take into account mask collision.
    
    Parameters
    ----------
    p1 : tuple
    First point.
    p2 : tuple
    Second point.
    collision_dict : dictionary
    Dictionary containing the things that you want to check for collision against.
    exceptions : collection
    Any objects that you ignore in collision.
    
    Returns
    -------
    colliding
    The first object that there was a collision against.
    """
    def get_entities(entity_list):
        chosen_entities = []
        for ent_type, can_collide in collision_dict.items():
            if ent_type.startswith("class_"):
                for entity in entity_list:
                    if can_collide and entity not in exceptions and ent_type in entity.class_aliases:
                        chosen_entities.append(entity)

        return chosen_entities
    colliding = False

    # ---LEVELS---
    # check for collisions with levels
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

    # ---ENTITIES---
    if g.segmenting_in_levels:
        check_entities_amount = 0
        for ent_type, can_collide in collision_dict.items():
            if can_collide and ent_type.startswith("class_"):
                check_entities_amount += len(g.game_objects.get(ent_type, []))

        # get entities using segment method
        check_entities = []

    if g.segmenting_in_levels and check_entities_amount > g.ENABLE_SEGMENT_ENTITY_THRESHOLD:
        # get the maximum rect that contains the full line for getting all the
        # required segments this could be upgraded to use a step-based approach
        # to get a smaller list of segments
        line_bound_rect = p.Rect(p1, p2)
        for level in g.active_levels:
            if level.enable_segmenting:
                for segment in level.get_segments(line_bound_rect):
                    check_entities += get_entities(segment.entities)

        if not check_entities:
            check_entities = get_entities(g.game_objects.get("class_Entity", []))
    # or don't
    else:
        check_entities = get_entities(g.game_objects.get("class_Entity", []))

    for entity in check_entities:
        if entity not in exceptions and entity.solid:
            if entity.collide_rect.clipline(p1, p2):

                colliding = entity
                break

    # ---CAMERA---
    if collision_dict.get("camera", False):
        if not p.Rect(0, 0, g.WIDTH, g.HEIGHT).clipline(g.camera.transform_point(p1), g.camera.transform_point(p2)):
            colliding = g.camera.reverse_transform_rect(p.Rect(0, 0, g.WIDTH, g.HEIGHT))

    return colliding


def get_variable_value(variable_name, variable_obj=None):
    """
    Get the value of a variable, either an object attribute, or a variable from a module.
    
    Parameters
    ----------
    variable_name : string
    Name of variable to get.
    variable_obj : object
    Object to get variable from. If no object is given the object will be the global_values module - Default is None.
    
    Returns
    -------
    value
    Return the value of the variable.
    """
    if variable_obj:
        value = getattr(variable_obj, variable_name)
    else:
        value = getattr(g, variable_name)
    return value


def set_variable_value(variable_name, value, variable_obj):
    """
    Set the value of a variable, either an object attribute or variable from a module.
    
    Parameters
    ----------
    variable_name : string
    Name of variable to set.
    value : object
    The variable is set to this value.
    variable_obj : object
    Object to get variable from. If no object is given the object will be the global_values module - Default is None.
    """
    if variable_obj:
        setattr(variable_obj, variable_name, value)
    else:
        setattr(g, variable_name, value)


def get_mouse_point_distance(min_distance, max_distance, point=g.SCREEN_RECT.center, normalise=False):
    """
    Gets the distance of the mouse point.
    
    Parameters
    ----------
    min_distance : number
    Minimum distance for the mouse point. Before this point 0 will be returned instead.
    max_distance : number
    Maximum distance for the mouse point.
    point : object
    The point from which to measure the mouse distance from. Default is the center of the screen.
    normalise : boolean
    If True, distance will be normalised (will be set between 0 and 1) - Default is False.
    
    Returns
    -------
    dist
    Return the distance of the mouse point.
    """
    mx, my = p.mouse.get_pos()
    dist = clamp(get_distance(point[0], point[1], mx, my), min_distance, max_distance)

    if normalise:
        dist_range = max_distance-min_distance
        dist -= min_distance
        dist /= dist_range

    return dist


def get_mouse_point_angle(point=g.SCREEN_RECT.center):
    """
    Gets the angle of the mouse point.
    
    Parameters
    ----------
    point : object
    The point from which to measure the mouse angle from. Default is the center of the screen.
    
    Returns
    -------
    obj
    Return the mouse point angle.
    """
    mx, my = p.mouse.get_pos()
    angle = get_angle(point[0], point[1], mx, my)
    return angle


def choose_weighted_object(obj_dict):
    """
    For choosing between a series of objects, each with a different choice 'weight'.
    
    Parameters
    ----------
    obj_dict : dictionary
    Dictionary containing the collection of objects to choose between, and their weights. Each key is an object, and each value is a weight.
    For example:
    {
    obj1 : 1,
    obj2 : 2,
    obj3 : 5
    }
    would result in obj1 having a 12.5% chance of being chosen, ob2 having a 25% chance, and obj3 having a 62.5% chance
    
    Returns
    -------
    obj
    Return the weighted object.
    """
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
    """
    Gets the opposite direction of a given direction. Supported directions are "up", "down", "left" and "right".
    
    Parameters
    ----------
    obj_dict : string
    Direction to reverse.
    
    Returns
    -------
    direction
    The opposite direction.
    """
    directions = ["up", "down", "left", "right"]
    opposite_directions = ["down", "up", "right", "left"]
    original_direction = direction
    for d in directions:
        if d in original_direction:
            d_index = directions.index(d)
            opposite_direction = opposite_directions[d_index]
            direction = direction.replace(d, opposite_direction)
    return direction


def pin_rect(rect, rect_point, point, in_place=False):
    """
    Set rect position so that a specific part of the rect is in a specific point.
    
    Parameters
    ----------
    rect : pygame.Rect
    Rectangle to pin.
    rect_point : tuple
    Part of rectangle to pin. (0, 0) would be the topleft corner, (1,1) the bottom right, (0.5, 0.5) the center, etc.
    point : tuple
    Point to pin rect_point to.
    in_place : boolean
    If True, the rectangle is replaced - Default is False.
    
    Returns
    -------
    new_rect
    Rectangle pinned in a specific point.
    """
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
    """
    Scale a rectangle in place by a given multiplier.
    
    Parameters
    ----------
    rect : pygame.Rect
    Rectangle to scale.
    scale : number
    Scale multiplier.
    """
    scaled_width = rect.width*scale
    scaled_height = rect.height*scale
    old_center = rect.center

    rect.width = scaled_width
    rect.height = scaled_height

    rect.center = old_center


def get_random_between(v1, v2):
    """
    Get a random value between two given values.
    
    Parameters
    ----------
    v1 : number
    First value.
    v2 : number
    Second value.
    
    Returns
    -------
    val
    Randomly picked value.
    """
    val = v1+(r.random()*(v2-v1))
    return val


def get_pretty_time(ticks, show_minutes=True, show_seconds=True, show_milliseconds=True, separator=":", digits=2, zfill=True):
    """
    Takes a number of ticks and converts them into a string showing the time they would take up.
    
    Parameters
    ----------
    ticks : list
    Numbers of in-game updates.
    show_minutes : boolean
    If True, minutes will be shown on the time - Default is True.
    show_seconds : boolean
    If True, seconds will be shown on the time - Default is True.
    show_milliseconds : boolean
    If True, milliseconds will be shown on the time - Default is True.
    separator : character
    Character which separates the time values.
    digits : number
    Amount of digits shown for each time section.
    zfill : boolean
    If True, the digits will be filled with zeroes - Default is True.
    
    Returns
    -------
    time_string
    Time formatted as a pretty string.
    """
    seconds = (ticks//g.MAX_TICK_RATE)
    leftover_seconds = int(seconds % 60)
    minutes = int(seconds//60)

    leftover_milliseconds = int((ticks % g.MAX_TICK_RATE)/g.MAX_TICK_RATE*1000)

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
    """
    Safely quits the game.
    """
    for saved_data_file in g.saved_data_dicts.values():
        if saved_data_file.save_on_quit:
            saved_data_file.save()
            
    g.RUNNING = False

    p.display.quit()
    sys.exit()
    


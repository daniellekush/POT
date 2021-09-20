import global_values as g
import utilities as util

import graphics as gfx

import pygame as p
import random as r

def setup_display(flags=0, icon_name=None, caption=None, rare_caption=None, rare_caption_chance=0.2):
    g.screen = p.display.set_mode((g.WIDTH, g.HEIGHT), flags=flags)

    if g.ENABLE_LIGHTING:
        g.darkness_surface = g.darkness_surface.convert_alpha()
        if g.ENABLE_COLOURED_LIGHTING:
            g.light_colour_surface = g.darkness_surface.convert_alpha()

    if caption:
        p.display.set_caption(caption)

    if rare_caption and r.random() <= rare_caption_chance:
        p.display.set_caption(rare_caption)

    if icon_name:
        icon_surface = p.image.load(g.gfx_dir+icon_name)
        p.display.set_icon(icon_surface)
        

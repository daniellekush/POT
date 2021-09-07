# cython: profile=True
# cython: language_level=3
# cython: infer_types=True

import global_values as g
import utilities as util
import graphics as gfx

import math as m
import pygame as p
import random as r

#dictionary for keeping track of different tile types
tiles_info = {}

#class for storing info about different types of tiles
class Tile_Info():
    def __init__(self, name, solid,  graphics_info):
        self.name = name
        self.solid = solid
        #graphics info is a tuple uses the format:
        #[0] - spritesheet object or spritesheet name or None to use the current tile spritesheet
        #[1] - either:
        #1. a tuple containing y, x indices into the spritesheet
        #2. a dictionary containing entries for:
        #anim_id, anim_timer (mandatory) loop, global_frame, system (optional)
        self.graphics_info = graphics_info

        tiles_info.update({self.name:self})

    #get or create the graphics for a tile
    def create_graphics(self, level):
        if self.graphics_info[0]:
            spritesheet = gfx.get_spritesheet(self.graphics_info[0])
        else:
            spritesheet = level.tile_spritesheet

        if type(self.graphics_info[1]) == tuple:
            graphics = spritesheet.sprites[ self.graphics_info[1][0] ][ self.graphics_info[1][1] ]

        elif type(self.graphics_info[1]) == dict:
            anim_dict = {
                "anim_id":0, # should be overwritten
                "anim_timer":0, #should be overwritten
                "loop":True,
                "global_frame":False,
                "system":False
                }
            anim_dict.update(self.graphics_info[1])
            
            graphics = spritesheet.generate_animation(anim_dict["anim_id"], anim_dict["anim_timer"], anim_dict["loop"], anim_dict["global_frame"], anim_dict["system"])

        return graphics

#get the gravity values that a rectangle will experience
#having magnitude as True will also return the total magnitude of the gravity force
#normalized will give the normalized gravity values
def get_gravity(rect, magnitude=False, normalized=False):
    for level in g.active_levels:
        if rect.colliderect(level.rect):
            gx, gy = level.gx, level.gy
            if magnitude or normalized:
                mag = util.get_magnitude(gx, gy)
                if normalized:
                    if mag:
                        gx /= mag
                        gy /= mag
            if magnitude:
                return gx, gy, mag
            else:
                return gx, gy

    if magnitude:
        return 0,0,0
    else:
        return 0,0

def get_tile(px, py, level=None, bounded=False):
        if level:
            search_levels = [level]
        else:
            search_levels = g.active_levels

        for level in search_levels:
            if isinstance(level, Tile_Level):
                tile = level.get_tile(px, py, bounded=bounded)
                if tile:
                    return tile

def get_tile_t(tx, ty, level=None, bounded=False):
        if level:
            search_levels = [level]
        else:
            search_levels = g.active_levels

        for level in search_levels:
            if isinstance(level, Tile_Level):
                tile = level.get_tile_t(tx, ty, bounded=bounded)
                if tile:
                    return tile

def get_segments(rect, tags=None):
    segments = []
    for level in g.active_levels:
        level.get_segments(rect, tags=tags)

class Level_Segment():
    def __init__(self, level, rect):
        self.level = level
        self.rect = rect

        self.entities = set()
        self.nodes = set()

    def set_game_objects(self):
        self.g.game_objects["class_Entity"] = []
        for entity in g.game_objects.get("class_Entity", []):
            if self.rect.colliderect(entity.rect):
                self.entities.append(entity)

    def draw(self, colour=g.RED, border=3):
        g.camera.draw_transformed_rect(colour, self.rect, border=border)
        
class Level():
    def __init__(self, active, info_dict, rect, enable_segmenting=True, segment_size=g.DEFAULT_LEVEL_SEGMENT_SIZE):
        self.active = active
        
        self.rect = p.Rect(rect)
        self.x = self.rect.x
        self.y = self.rect.y
        self.width = self.rect.width
        self.height = self.rect.height

        self.__dict__.update(info_dict)
        
        self.set_gravity(self.gravity_strength, self.gravity_direction)

        self.enable_segmenting = enable_segmenting

        self.segment_size = segment_size
        
        self.segment()

        if self.active:
            self.activate()

    def segment(self):
        self.segment_width = self.segment_size
        self.segment_height = self.segment_size
        
        self.segments = []
        self.segment_list = []
        for seg_x in range(int(m.ceil(self.rect.w/self.segment_width))):
            self.segments.append([])
            for seg_y in range(int(m.ceil(self.rect.h/self.segment_height))):
                x = seg_x*self.segment_width
                y = seg_y*self.segment_height

                rect = p.Rect(self.x+x, self.y+y, self.segment_width, self.segment_height)

                segment = Level_Segment(self, rect)
                self.segments[-1].append(segment)
                self.segment_list.append(segment)

        self.segments_width = len(self.segments)
        self.segments_height = len(self.segments[0])
                
    def update(self):
        pass

    def get_segments(self, rect, tags=None):
        segments = []
            
        sx = int((rect.x-self.x)/self.segment_width)
        sy = int((rect.y-self.y)/self.segment_height)
        ex = int((rect.right-self.x)/self.segment_width)+1
        ey = int((rect.bottom-self.y)/self.segment_height)+1
        y_range = range(sy,ey)
        for x in range(sx,ex):
            for y in y_range:
                if x >= 0 and y >= 0 and x < self.width/self.segment_width and y < self.height/self.segment_height:
                    segment = self.segments[x][y]
                    
                    if tags:
                        if not tags.isdisjoint(segment.tags):
                            segments.append(segment)
                    else:
                        segments.append(segment)
                    
        return segments

    def activate(self):
        self.active = True
        if not self in g.active_levels:
                g.active_levels.append(self)
                if self.enable_segmenting:
                    g.segmenting_in_levels = True

                if not g.current_level:
                    g.current_level = self
                    g.clear_surface_cache()

    def deactivate(self):
        self.active = False
        if self in g.active_levels:
            g.active_levels.remove(self)
            if self.enable_segmenting:
                g.segmenting_in_levels = False
                for level in g.active_levels:
                    if level.enable_segmenting:
                        g.segmenting_in_levels = True

            if g.active_levels:
                g.current_level = g.active_levels[0]
            else:
                g.current_level = None
                g.clear_surface_cache()

    def set_gravity(self, strength, direction):
        self.gx = m.cos(direction)*strength
        self.gy = m.sin(direction)*strength
        
    def check_collision(self, rect, mask):
        return False

    #check collision between a line and the level
    def check_line_collision(self, p1, p2):
        return False

    def draw(self):
        g.camera.draw_transformed_rect(g.RED, self.rect, border=1)

    def draw_segments(self):
        for segment in self.segment_list:
            segment.draw()

class Mask_Level(Level):
    def __init__(self, data, info_data, cw, ch, x=0, y=0, level_scale_x=1, level_scale_y=1, active=True, enable_segmenting=True, segment_size=g.DEFAULT_LEVEL_SEGMENT_SIZE):

        self.cw = cw
        self.ch = ch
        self.level_scale_x = level_scale_x
        self.level_scale_y = level_scale_y
        
        if type(data) == str:        
            unscaled_level_surface = gfx.load_image(data, prefix=g.level_dir)
            unscaled_collision_surface = gfx.load_image(data+"_collision", prefix=g.level_dir)
            
        elif type(data) == dict:
            unscaled_level_surface = data["level"]
            unscaled_collision_surface = data["collision"]

        if type(info_data) == str:
            path = g.level_dir+info_data
            with open(path+"_info.lvl") as info_file:
                raw_info_data = info_file.read()

            raw_data_sections = util.split_string_into_sections(raw_info_data, "SECTION", lines=False)

            info_dict = util.turn_string_into_dict(raw_data_sections["Info"])
            
        elif type(info_data) == dict:
            info_dict = info_data

        
        unscaled_rect = unscaled_level_surface.get_rect()

        rect = p.Rect(x, y, unscaled_rect.w*self.level_scale_x, unscaled_rect.h*self.level_scale_y)
        Level.__init__(self, active, info_dict, rect, enable_segmenting=enable_segmenting, segment_size=segment_size)
        
        level_surface = p.transform.scale(unscaled_level_surface, (self.rect.w, self.rect.h)) 
        collision_surface = p.transform.scale(unscaled_collision_surface, (self.rect.w, self.rect.h)) 

        self.chunks = []
        self.chunk_list = []
        
        self.active_chunks = []

        self.c_width = m.ceil(self.rect.width/self.cw)
        self.c_height = m.ceil(self.rect.height/self.ch)

        for x in range(self.c_width):
            cx = x*self.cw
            self.chunks.append([])
            for y in range(self.c_height):
                cy = y*self.ch
                

                rect = p.Rect(self.x+cx, self.y+cy, self.cw, self.ch)
                chunk = Chunk(self, rect, level_surface, collision_surface)
                
                self.chunk_list.append(chunk)
                self.chunks[-1].append(chunk)

    def update(self):
        Level.update(self)
        self.set_active_chunks(g.player.rect.center)

    def get_chunk(self, px, py, bounded=False):
        px -= self.x
        py -= self.y
        tx = int(px/self.tw)
        ty = int(py/self.th)

        if bounded:
            tx = max(min(tx,len(self.chunks)-1),0)
            ty = max(min(ty,len(self.chunks[0])-1),0)

        chunk = None
        if 0 <= tx <= len(self.chunks)-1:
            if 0 <= ty <= len(self.chunks[0])-1:
                chunk = self.chunks[tx][ty]

        return chunk

    def check_collision(self, rect, mask, obj=None):
        colliding = Level.check_collision(self, rect, mask)
        if colliding:
            return colliding
        
        sx = int((rect.x-self.x)/self.cw)
        sy = int((rect.y-self.y)/self.ch)
        ex = int((rect.right-self.x)/self.cw)+2
        ey = int((rect.bottom-self.y)/self.ch)+2
        for x in range(sx,ex):
            for y in range(sy,ey):
                if x >= 0 and y >= 0 and x < self.width/self.cw and y < self.height/self.ch:
                    chunk = self.chunks[x][y]
                    if chunk.check_collision(rect, mask):
                        return chunk
        return False

    #check collision between a line and the level
    #this version uses a "step" to speed things up but it makes it more innacurate
    #so change it as required on a per-game basis
    def check_line_collision(self, p1, p2, step=10):
        colliding = Level.check_line_collision(self, p1, p2)
        if colliding:
            return colliding
        
        angle = util.get_angle(p1[0], p1[1], p2[0], p2[1])
        distance = util.get_distance(p1[0], p1[1], p2[0], p2[1])
        step_dist = step#CHANGE AS REQUIRED
        dx = m.cos(angle)*step_dist
        dy = m.sin(angle)*step_dist

        x, y = p1
        for step in range(distance//step_dist):
            chunk = self.get_chunk(x,y)
            if chunk.check_point_collision((x,y)):
                return chunk
            
            x += dx
            y += dy

    def set_active_chunks(self, point):
        self.active_chunks.clear()
        
        sx = max(int((g.camera.screen_x-self.x)/self.cw), 0) #must be ints because they are used as indices
        sy = max(int((g.camera.screen_y-self.y)/self.ch), 0) #must be ints because they are used as indices
        ex = min(( (g.camera.rect.right-self.x)//self.cw)+2, self.c_width)
        ey = min(( (g.camera.rect.bottom-self.y)//self.cw)+2, self.c_height)

        x = sx
        while x < sy:
            y = sy
            while y < sy:
                self.active_chunks.append(self.chunks[x][y])

                y += 1
            x += 1

        


    def draw(self, quick=True):
        Level.draw(self)
        if quick:
            sx = max(int((g.camera.screen_x-self.x)/self.cw), 0) #must be ints because they are used as indices
            sy = max(int((g.camera.screen_y-self.y)/self.ch), 0) #must be ints because they are used as indices
            ex = min(((g.camera.rect.right-self.x)//self.cw)+2, self.c_width)
            ey = min(((g.camera.rect.bottom-self.y)//self.cw)+2, self.c_height)


            #create draw rect
            d_tw = self.cw*g.camera.scale_x
            d_th = self.ch*g.camera.scale_y
            d_ty = g.camera.transform_y(self.y)+(sy*d_th)

            dx = g.camera.transform_x(self.x)+(sx*d_tw)
            dy = d_ty
            
            draw_rect = p.Rect(dx,
                               dy,
                               d_tw+1,
                               d_th+1
                               )

            
            x = sx
            while x < ex:
                if quick:
                    dy = d_ty
                    
                y = sy  
                while y < ey:
                
                    draw_rect.x = dx
                    draw_rect.y = dy
                    self.chunks[x][y].quick_draw(draw_rect)

                    y += 1
                    dy += d_th
                    
                dx += d_tw
                x += 1
                

        else:
            for chunk in self.active_chunks:
                chunk.draw()

class Chunk():
    def __init__(self, level, rect, surface, collision_surface):
        self.level = level
        
        self.rect = rect
        
        self.surface = p.Surface((self.rect.width, self.rect.height)).convert()
        self.surface.blit(surface, (0,0), self.rect)

        self.collision_surface = p.Surface((self.rect.width, self.rect.height)).convert()
        self.collision_surface.blit(collision_surface, (0,0), self.rect)

        self.mask = p.mask.from_threshold(self.collision_surface, (0,0,0,255), (255,255,255,255))

    def check_collision(self, rect, mask):
        if self.rect.move(self.level.x, self.level.y).colliderect(rect):
            collision_offset = (rect.x-(self.level.x+self.rect.x), rect.y-(self.level.y+self.rect.y))
            collision = self.mask.overlap(mask, collision_offset )

            return collision
        else:
            return False

    def check_point_collision(self, point):
        x, y = point
        x -= self.rect.x
        y -= self.rect.y
        return self.mask.get_at((x,y))

    def draw(self):
        g.camera.draw_transformed_surface(self.surface, self.rect)

    def quick_draw(self, rect):
        surface = gfx.scale_graphics(self.surface, (rect.width, rect.height))       
        g.screen.blit(surface, rect)


class Tile_Level(Level):
    def __init__(self, data, tw, th, x=0, y=0, active=True, enable_segmenting=True,
    segment_size=g.DEFAULT_LEVEL_SEGMENT_SIZE, override_info_dict=None, override_raw_tile_data=None, override_raw_structure_data=None,
    override_key=None, override_structure_key=None, override_spritesheet=None):
    
        self.tile_list = []
        self.structure_list = []

        #dictionary containing lists of structures, where each list contains all the level structures with particular
        self.structure_tag_dict = {}

        if isinstance(data, str):
            has_data = True
        else:
            has_data = False

        if has_data:
            path = g.level_dir+data

        self.tw = tw
        self.th = th

        if has_data:
            file = open(path)
            raw_data = file.read()
            file.close()
            
            self.raw_data_sections = util.split_string_into_sections(raw_data, "SECTION", lines=False)
            
        if override_raw_tile_data:
            self.raw_tile_data = override_raw_tile_data
        elif has_data: 
            self.raw_tile_data = self.raw_data_sections["Tiles"]
        else:
            self.raw_tile_data = ""

        if override_raw_structure_data:
            self.raw_structure_data = override_raw_structure_data
        elif has_data: 
            self.raw_structure_data = self.raw_data_sections["Structures"]
        else:
            self.raw_structure_data = ""
        
        if override_info_dict:
            info_dict = override_info_dict
        elif has_data:
            info_dict = util.turn_string_into_dict(self.raw_data_sections["Info"])
        else:
            info_dict = {} #add default

        
        if override_key:
            self.key = override_key
        elif has_data:
            self.key = util.turn_string_into_dict(self.raw_data_sections["Key"])
        else:
            self.key = {}

        if override_structure_key:
            self.structure_key = override_structure_key
        elif has_data:
            self.structure_key = util.turn_string_into_dict(self.raw_data_sections["Structure_Key"])
        else:
            self.structure_key = {}
            
            
        if override_spritesheet:
            self.tile_spritesheet = override_spritesheet
        elif has_data or override_info_dict:
            self.tile_spritesheet = info_dict["tile_spritesheet"]
        else:
            self.tile_spritesheet = None
        
        self.x = x
        self.y = y

        if has_data or override_raw_tile_data:
            self.tiles = self.build_level_tiles()
        else:
            self.tiles = [[]]

        self.t_width = len(self.tiles)
        self.t_height = len(self.tiles[0])

        width = self.t_width*self.tw
        height = self.t_height*self.th

        self.tile_surface_cache = {}

        

        rect = p.Rect(x, y, width, height)       
        Level.__init__(self, active, info_dict, rect, enable_segmenting=enable_segmenting, segment_size=segment_size)

    def update(self):
        Level.update(self)
        for structure in self.structure_list:
            structure.update()

    def get_tile(self, px, py, bounded=False):
        px -= self.x
        py -= self.y
        tx = int(px/self.tw)
        ty = int(py/self.th)

        if bounded:
            tx = max(min(tx,len(self.tiles)-1),0)
            ty = max(min(ty,len(self.tiles[0])-1),0)

        tile = None
        if 0 <= tx <= len(self.tiles)-1:
            if 0 <= ty <= len(self.tiles[0])-1:
                tile = self.tiles[tx][ty]

        return tile

    def get_tiles(self, rect):
        tiles = []
            
        sx = int((rect.x-self.x)/self.tw)
        sy = int((rect.y-self.y)/self.th)
        ex = int((rect.right-self.x)/self.tw)+1
        ey = int((rect.bottom-self.y)/self.th)+1
        for x in range(sx,ex):
            for y in range(sy,ey):
                if x >= 0 and y >= 0 and x < self.width/self.tw and y < self.height/self.th:
                    tile = self.tiles[x][y]
                        
                    tiles.append(tile)
                    
        return tiles

    def get_structures(self, rect):
        structures = []
            
        sx = int((rect.x-self.x)/self.tw)
        sy = int((rect.y-self.y)/self.th)
        ex = int((rect.right-self.x)/self.tw)+1
        ey = int((rect.bottom-self.y)/self.th)+1
        for x in range(sx,ex):
            for y in range(sy,ey):
                if x >= 0 and y >= 0 and x < self.width/self.tw and y < self.height/self.th:
                    tile = self.tiles[x][y]
                    if tile.structure:
                        structures.append(tile.structure)
                    
        return structures

    #get all structures within the given level that share at least one tag with the given tags
    def get_tagged_structures(level, tags):
        obtained_structures = set()
        for tag in tags:
            tagged_structures = level.structure_tag_dict.get(tag, [])
            obtained_structures.update(tagged_structures)
            
        obtained_structures = list(obtained_structures)
        return obtained_structures

    def get_tile_t(self, tx, ty, bounded=False):
        if bounded:
            tx = max(min(tx,len(self.tiles)-1),0)
            ty = max(min(ty,len(self.tiles[0])-1),0)

        tile = None
        if 0 <= tx <= len(self.tiles)-1:
            if 0 <= ty <= len(self.tiles[0])-1:
                tile = self.tiles[tx][ty]

        return tile
        
    def build_level_tiles(self):
        #split raw_tile_data into rows of tiles
        #also removes newline only lines
        tile_rows = [[tile for tile in row.split(" ")] for row in self.raw_tile_data.split("\n") if row]
        structure_rows = [[structure for structure in row.split(" ")] for row in self.raw_structure_data.split("\n") if row]
        width = len(tile_rows[0])
        height = len(tile_rows)

        #create 2D list of tiles
        tiles = []
        for x in range(width):
            tiles.append([])
            for y in range(height):
                #create tile
                tile_code = tile_rows[y][x]
                tile_name = self.key[tile_code]
                
                tile = Tile(self, x*self.tw, y*self.th, tile_name, ax=self.x, ay=self.y)
                tiles[-1].append(tile)

                tile_structure_code = structure_rows[y][x]

                tile_structure_name = self.structure_key.get(tile_structure_code,None)

                #create new instance of tile structure
                if tile_structure_name:
                    tile_structure_class = globals()[tile_structure_name]
                    tile_structure_class(tile)

        return tiles

    def check_collision(self, rect, mask, obj=None):
        colliding = Level.check_collision(self, rect, mask)
        if colliding:
            return colliding
        
        sx = max(int((rect.left-self.x)/self.tw), 0) #must be ints because they are used as indices
        sy = max(int((rect.top-self.y)/self.th), 0) #must be ints because they are used as indices
        ex = min(( (rect.right-self.x)//self.tw)+2, self.t_width)
        ey = min(( (rect.bottom-self.y)//self.th)+2, self.t_height)

        if not obj:
            
            x = sx
            while x < ex:
                y = sy
                while y < ey:
                    tile = self.tiles[x][y]
                    if tile and tile.solid and tile.rect.colliderect(rect):
                        return tile
                    
                    y += 1
                x += 1

        else:

            y = sy
            while y < ey:

                x = sx
                while x < ex:
                    tile = self.tiles[x][y]#tile.rect.right > rect.left and tile.rect.left < rect.right and
                    if (obj.collide_rect.bottom-obj.bump_amount <= (y*self.th)+self.y) or tile.solid:
                        if tile and tile.solid and tile.rect.colliderect(rect):
                            return tile
                        
                    x += 1
                y += 1

    #check collision between a line and the level
    def check_line_collision(self, p1, p2):
        colliding = Level.check_line_collision(self, p1, p2)
        if colliding:
            return colliding
        
        angle = util.get_angle(p1[0], p1[1], p2[0], p2[1])
        distance = util.get_distance(p1[0], p1[1], p2[0], p2[1])

        #min is not used for this because it like... breaks cython?
        if self.tw >= self.th:
            step_dist = self.tw
        else:
            step_dist = self.th
        
        dx = m.cos(angle)*step_dist
        dy = m.sin(angle)*step_dist

        x, y = p1
        for step in range(int(distance//step_dist)):
            tile = self.get_tile(x, y, bounded=True)
            if tile and tile.solid and tile.rect.clipline(p1, p2):
                return tile
            x += dx
            y += dy
                
    def draw(self, quick=True):
        if quick:
            self.tile_surface_cache = {}
            
        Level.draw(self)

        sx = max(int((g.camera.screen_x-self.x)/self.tw), 0) #must be ints because they are used as indices
        sy = max(int((g.camera.screen_y-self.y)/self.th), 0) #must be ints because they are used as indices
        ex = min(((g.camera.rect.right-self.x)//self.tw)+2, self.t_width)
        ey = min(((g.camera.rect.bottom-self.y)//self.tw)+2, self.t_height)

        if quick:
            d_tw = self.tw*g.camera.scale_x
            d_th = self.th*g.camera.scale_y
            d_ty = g.camera.transform_y(self.y)+(sy*d_th)

            dx = g.camera.transform_x(self.x)+(sx*d_tw)
            dy = d_ty
            
            draw_rect = p.Rect(dx,
                               dy,
                               d_tw+1,
                               d_th+1
                               )

        structures_to_draw = []

        x = sx
        while x < ex:
            if quick:
                dy = d_ty

            y = sy
            while y < ey:
                
                tile = self.tiles[x][y]
                if tile:
                    if quick:
                        draw_rect.x = dx
                        draw_rect.y = dy
                        tile.quick_draw(draw_rect)
                    else:
                        tile.draw()
                        
                    if tile.structure:
                        structures_to_draw.append(tile.structure)
                        
                if quick:
                    dy += d_th

                y += 1
                
            if quick:
                dx += d_tw
            x += 1

        #draw all structures that are part of the drawn tiles
        for structure in structures_to_draw:
            structure.draw()
"""
class Enemy_Spawn_Pattern():
    def __init__(self, spawn_list, spawn_y, camera_bound_multiplier=1):
        self.spawn_list = spawn_list
        
        self.spawn_y = spawn_y
        self.preload_y = 1000
        self.camera_bound_multiplier = camera_bound_multiplier

        self.enemies = []

        self.spawned = False

        self.bound_rect = g.camera.base_rect.copy()
        increased_width = self.bound_rect.width*(self.camera_bound_multiplier-1)
        increased_height = self.bound_rect.height*(self.camera_bound_multiplier-1)
        self.bound_rect.inflate_ip((increased_width, increased_height))
        
        self.bound_rect.centerx = g.current_level.rect.centerx
        moved_rect = False

        for enemy_data in self.spawn_list:
            x,y = enemy_data[1], enemy_data[2]
            if not moved_rect:
                self.bound_rect.y = self.spawn_y+y-50
                moved_rect = True
            
            rect = p.Rect(x,self.spawn_y+y,1,1).inflate(100,100)
            
            self.bound_rect.union_ip(rect)
            
        g.spawn_patterns.append(self)

    def update(self):
        if not g.camera.spawn_pattern and g.camera.y < self.spawn_y+self.preload_y:
            if not self.spawned:
                self.spawned = True
                g.camera.spawn_pattern = self
                self.spawn_enemies()


        if g.camera.spawn_pattern == self:
            enemies_active = False
            for enemy in self.enemies:
                if enemy in g.enemies:
                    enemies_active = True
                    break
                
            if not enemies_active:
                g.camera.spawn_pattern = None
                self.delete()

    def spawn_enemies(self):
        g.camera.set_target(self.bound_rect, 2, blocking=False, threshold=2, smooth=True)

        for enemy_data in self.spawn_list:
            enemy_class_name, x, y, z, enemy_type = enemy_data
            enemy_class = enemy_template_dict[enemy_class_name]
            if enemy_class == Turret_Enemy or enemy_class == Ground_Turret_Enemy:
                enemy = enemy_class(x, self.spawn_y+y, z, enemy_type)
            else:
                enemy = enemy_class(x, self.spawn_y+y, z, enemy_type, drift=0.0)
            self.enemies.append(enemy)        

        
    def delete(self):
        g.spawn_patterns.remove(self)
"""
        
class Tile():
    def __init__(self, level, x, y, name, ax=0, ay=0):
        self.level = level
        self.tx = int(x/level.tw)
        self.ty = int(y/level.th)
        self.x = x+ax
        self.y = y+ay
        self.rect = p.Rect(self.x, self.y, level.tw, level.th)

        self.name = name

        tile_info = tiles_info[self.name]
        self.solid = tile_info.solid
        self.graphics = tile_info.create_graphics(self.level)

        self.structure = None

        self.level.tile_list.append(self)

    def draw(self):
        g.camera.draw_transformed_graphics(self.graphics, self.rect)

        if self.structure:
            self.structure.draw()

    def quick_draw(self, rect):
        if self.level.tile_surface_cache.get(self.name, False):
            surface = self.level.tile_surface_cache[self.name]
        else:
            surface = gfx.scale_graphics(self.graphics, (rect.width, rect.height))
            self.level.tile_surface_cache[self.name] = surface
            
        g.screen.blit(surface, rect)

        if self.structure:
            self.structure.draw()
        
    def get_adjacent_tiles(self, diagonal=False):
        relative_positions = [
                          (0, -1),
                (-1, 0),           (1, 0),
                          (0,  1)
                ]

        if diagonal:
            relative_positions += [
                (-1, -1),          (1, -1),

                (-1, 1),           (1, 1)
                ]

        tiles = []
        for relative_position in relative_positions:
            x = self.tx+relative_position[0]
            y = self.ty+relative_position[1]
            tile = self.level.get_tile(x,y)
            if tile:
                tiles.append(tile)

        return tiles

    def get_nearby_tiles(self, radius):
        tiles = []
        
        sx = self.tx-radius
        sy = self.ty-radius
        for tx in range(int(sx),int(sx+(radius*2))):
            for ty in range(int(sy),int(sy+(radius*2))):
                tile = self.level.get_tile_t(tx,ty)
                if tile:
                    distance = util.get_distance(tx, ty, self.tx, self.ty)
                    if distance <= radius:
                        tiles.append(tile)

        return tiles

    def draw_outline(self, colour, border=1):
        transformed_rect = g.camera.transform_rect(self.rect)
        p.draw.rect(g.screen, colour, transformed_rect, border)

    def delete(self):
        self.level.tile_list.remove(self)
        self.level.tiles[self.tx][self.ty] = None


#Structures are basically objects that are somewhere in the middle between tiles and entities
class Structure():
    def __init__(self, tile, width, height, graphics, tags=set()):
        self.tile = tile
        self.tile.structure = self

        self.level = self.tile.level
        self.level.structure_list.append(self)

        self.rect = p.Rect(self.tile.x, self.tile.y, width, height)

        self.graphics = graphics

        self.tags = tags

        #add self to all relavent lists of tagged structures in the level
        level_tag_keys = self.level.structure_tag_dict.keys()
        for tag in self.tags:
            if tag in level_tag_keys:
                self.level.structure_tag_dict[tag].append(self)
            else:
                self.level.structure_tag_dict.update({tag:[self]})

    def update(self):
        pass

    def draw(self):
        g.camera.draw_transformed_surface(gfx.get_surface(self.graphics), self.rect)

    def delete(self):
        self.tile.structure = None
        self.level.structure_list.remove(self)

        for tag in self.tags:
            self.level.structure_tag_dict[tag].remove(self)

class Player_Spawn_Point(Structure):
    def __init__(self, tile):
        Structure.__init__(self, tile, tile.rect.w, tile.rect.h, None, tags=set("player_spawn_point"))

def generate_maze_level(width, height, wall_char, floor_char, tunnel_amount, tunnel_width, tunnel_length, tunnel_turn_chance):
    level_lines = []
    #structure_lines = []
    for x in range(width):
        level_lines.append([wall_char] * height)
        #structure_lines.append(["0"] * height)


    #if in bounds, change a character at index x/y
    def set_tile_char(sx, sy, value):
        if 0 <= sx < width and 0 <= sy < height:
            level_lines[sx][sy] = value

    #def set_structure_char(sx, sy, value, overwrite=True):
    #    if 0 <= sx < width and 0 <= sy < height and (overwrite or structure_lines[sx][sy] == "0"):
    #        structure_lines[sx][sy] = value


    #create tunnels
    for tunnel in range(tunnel_amount):
        tx = r.randint(0,width-1)
        ty = r.randint(0,height-1)

        btx = tx
        bty = ty

        tvx = r.choice( [-1, 0, 1] )

        if not tvx:
            tvy = r.choice([-1, 0, 1])
        else:
            tvy = 0

        #move tunnel
        for _ in range(tunnel_length):
            tx = tx+tvx
            ty = ty+tvy

            if not 0 <= tx < width or not 0 <= ty < height:
                break

            if 0 <= tx < width and 0 <= ty < height:
                btx = tx
                bty = ty

            for bx in range(tx, tx+tunnel_width):
                for by in range(ty, ty+tunnel_width):
                    set_tile_char(bx, by, floor_char)


            #turn tunneler
            if r.random() <= tunnel_turn_chance:
                if tvx:
                    tvx = 0
                    tvy = r.choice([-1, 0, 1])
                else:
                    tvx = r.choice([-1, 0, 1])
                    tvy = 0



    level_str = []
    for y in range(height):
        for x in range(width):
            level_str += [level_lines[x][y]+" "]
        level_str[-1] = level_lines[x][y]+"\n" #add newline instead of space to the end
    level_str[-1] =  level_lines[x][y] #remove newline at the end end

    level_str = "".join(level_str)


    #structure_str = []
    #for y in range(height):
    #    for x in range(width):
    #        structure_str += [structure_lines[x][y]+" "]
    #    structure_str[-1] = structure_lines[x][y]+"\n" #add newline instead of space to the end
    #structure_str[-1] =  structure_lines[x][y] #remove newline at the end end

    #structure_str = "".join(structure_str)

    return level_str#, structure_str
        

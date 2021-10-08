# cython: profile=False
# cython: language_level=3
# cython: infer_types=True

from . import utilities as util
from . import global_values as g
from . import levels
from . import entities
from . import cameras

import pygame as p
import math as m


class Node():
    def __init__(self, x, y, node_map, collision_dict, radius=1, connection_radius=50, node_type=None):
        self.x = x
        self.y = y
        self.radius = radius
        
        self.rect = p.Rect(self.x, self.y, 0, 0)
        self.rect.inflate_ip((self.radius*2, self.radius*2))
                
        self.connection_radius = connection_radius

        self.collision_dict = collision_dict

        self.node_map = node_map
        if node_type is None:
            self.node_type = None
        else:
            self.node_type = node_type

        self.connections = []

        self.sx = int( (self.x-self.node_map.level.x) / self.node_map.level.segment_size)
        self.sy = int( (self.y-self.node_map.level.y) / self.node_map.level.segment_size)
        self.segment = self.node_map.level.segments[self.sx][self.sy]
        self.segment.nodes.add(self)

        self.node_map.node_list.append(self)

    def connect(self, cardinal=False, diagonal=False, all_directions=True):
        potential_connection_rect = self.rect.inflate(self.connection_radius*2, self.connection_radius*2)

        nodes = []
        for segment in self.node_map.level.get_segments(potential_connection_rect):
            nodes += segment.nodes

        for node in nodes:
            if node == self :
                continue
            
            angle = round(m.degrees(util.get_angle(self.x, self.y, node.x, node.y)))
            can_connect = False

            if all_directions:
                can_connect = True
            else:
                
                if cardinal:
                    if angle == -180 or angle == 180 or angle == -90 or angle == 90 or angle == 0:
                        can_connect = True
                if (not can_connect) and diagonal:
                    if angle == -45 or angle == -135 or angle == angle == 45 or angle == 135:
                        can_connect = True

                

            if can_connect:
                
                if util.get_distance(self.rect.centerx, self.rect.centery, node.x, node.y) <= self.connection_radius:
                    collision_test_entity = entities.Entity(self.rect, collision_dict=self.collision_dict, safe_movement=False, temp=True)
                    collision_test_entity.update()
                    
                    ax, ay = node.rect.centerx-self.rect.centerx, node.rect.centery-self.rect.centery
                    move_results = collision_test_entity.move(ax, ay)
                        
                    can_move_x, can_move_y = move_results[4], move_results[5]
                    if can_move_x and can_move_y:
                        Node_Connection(self, node)
                        Node_Connection(node, self)

                    collision_test_entity.delete()

    def clear_connections(self):
        for connection in self.connections[:]:
            connection.delete()

    def refresh_connections(self, cardinal=False, diagonal=False, all_directions=True):
        self.clear_connections()
        self.connect(cardinal=cardinal, diagonal=diagonal, all_directions=all_directions)
                        

    def draw(self, colour=g.BLUE, connection_colour=g.GREEN):
        g.camera.draw_transformed_ellipse(colour, self.rect, 1)
        for connection in self.connections:
            g.camera.draw_transformed_line(connection_colour, (self.x, self.y), (connection.node.x, connection.node.y))

    def delete(self):
        self.node_map.node_list.remove(self)
        self.node_map.level.segments[self.sx][self.sy].nodes.remove(self)
        
        for connection in self.connections:
            for c in connection.node.connections:
                if c.node == self:
                    c.delete()

class Node_Connection():
    def __init__(self, start_node, node):
        self.start_node = start_node
        self.node = node
        self.distance = util.get_distance(self.start_node.x, self.start_node.y, self.node.x, self.node.y)
        self.angle = util.get_angle(self.start_node.x, self.start_node.y, self.node.x, self.node.y)

        self.start_node.connections.append(self)

    def delete(self):
        self.start_node.connections.remove(self)
 
class Zone():
    def __init__(self, rect, zone_type, node_map):
        self.rect = rect
        self.zone_type = zone_type

        self.node_map = node_map
        
        self.node_map.zones.append(self)

class Node_Map():
    def __init__(self, level):
        self.level = level
        self.node_list = []
         
        g.node_maps.add(self)

    def draw(self):
        g.screen.lock()
        for node in self.node_list:
            g.camera.draw_transformed_ellipse(g.RED, node.rect, 1)
            for connection in node.connections:
                g.camera.draw_transformed_line(g.GREEN, (node.x, node.y), (connection.node.x, connection.node.y))
        g.screen.unlock()

def draw_path(path):
    for node in path:
        node.draw()


def generate_from_level(node_map, level, node_spacing, collision_dict, node_radius=5, node_connection_radius_override=None, cardinal=False, diagonal=False, all_directions=True):
    if node_connection_radius_override is None:
        if diagonal:
            node_connection_radius = ((node_spacing**2)+(node_spacing**2))**0.5
        else:
            node_connection_radius = node_spacing
    else:
        node_connection_radius = node_connection_radius_override

    node_mask = p.Mask((node_spacing, node_spacing),fill=True)
    
    for x in range(int(level.rect.w/node_spacing)):
        for y in range(int(level.rect.h/node_spacing)):
            solid = False
            rect = p.Rect( level.x+(x*node_spacing), level.y+(y*node_spacing), node_spacing, node_spacing)

            if isinstance(level, levels.Mask_Level):
                mask = node_mask 
            else:
                mask = None
            
            solid = level.check_collision(rect, mask)
                              
            if not solid:
                node = Node(rect.centerx, rect.centery, node_map, collision_dict, radius=node_radius, connection_radius=node_connection_radius)
                node.connect(cardinal=cardinal, diagonal=diagonal, all_directions=all_directions)

def get_nearest_node(node_map, pos, max_segment_offset=2):
    original_sx = int( (pos[0]-node_map.level.x) / node_map.level.segment_size)-(max_segment_offset)
    original_sy = int( (pos[1]-node_map.level.y) / node_map.level.segment_size)-(max_segment_offset)
    nodes = []

    for ax in range(max_segment_offset*2):
        for ay in range(max_segment_offset*2):
            sx = original_sx+ax#max(min(original_sx+ax, node_map.level.segments_width-1),0)
            sy = original_sy+ay#max(min(original_sy+ay, node_map.level.segments_height-1),0)

            if sx < 0:
                sx += int(node_map.level.width/node_map.level.segment_size)

            if sx >= int(node_map.level.width/node_map.level.segment_size):
                sx -= int(node_map.level.width/node_map.level.segment_size)

            if sy < 0:
                sy += int(node_map.level.height/node_map.level.segment_size)

            if sy >= int(node_map.level.height/node_map.level.segment_size):
                sy -= int(node_map.level.height/node_map.level.segment_size)

            segment = node_map.level.segments[sx][sy]
            nodes += segment.nodes

    closest_node = None
    smallest_distance = None
    for node in nodes:
        dist = util.get_distance(pos[0], pos[1], node.x, node.y)
        if closest_node is None or dist < smallest_distance:
            closest_node = node
            smallest_distance = dist

    return closest_node

def get_path_recursive(start_node, goal_node, node_count, max_nodes, visited_nodes):
    visited_nodes = visited_nodes[:]
    if node_count == max_nodes:
        return visited_nodes
    elif start_node == goal_node:
        return visited_nodes
    else:
        shortest_path = None
        shortest_distance = None
        paths = [get_path_recursive(connection.node, goal_node, node_count+1, max_nodes, visited_nodes+[connection.node]) for connection in start_node.connections if connection.node not in visited_nodes]
        if paths:
            for path in paths:
                if shortest_path is None:
                    shortest_path = path
                    shortest_distance = util.get_distance(shortest_path[-1].x, shortest_path[-1].y, goal_node.x, goal_node.y)
                else:
                    dist = util.get_distance(path[-1].x, path[-1].y, goal_node.x, goal_node.y)
                    if dist < shortest_distance or (dist == shortest_distance and len(path) < len(shortest_path)):
                        shortest_path = path
                        shortest_distance = dist
                                                    
            return shortest_path
        else:
            return visited_nodes
        
def get_path(node_map, start_pos, goal_pos, max_nodes=5):
    if isinstance(start_pos, Node):
        start_node = start_pos
    else:
        start_node = get_nearest_node(node_map, start_pos)
        
    if isinstance(goal_pos, Node):
        goal_node = goal_pos
    else:
        goal_node = get_nearest_node(node_map, goal_pos)

    if start_node and goal_node:
        path = get_path_recursive(start_node, goal_node, 1, max_nodes, [start_node])
        return path
    else:
        return None

def get_path_quick(node_map, start_pos, goal_pos, max_nodes=10):
    if isinstance(start_pos, Node):
        start_node = start_pos
    else:
        start_node = get_nearest_node(node_map, start_pos)
        
    if isinstance(goal_pos, Node):
        goal_node = goal_pos
    else:
        goal_node = get_nearest_node(node_map, goal_pos)

    if not start_node or not goal_node:
        return []

    path = []
    current_node = start_node
    for i in range(max_nodes):
        best_node = None
        smallest_distance = None
        for connection in current_node.connections:
            if connection.node not in path:
                node = connection.node
                if node == goal_node:
                    best_node = node
                    break
                else:
                    dist = util.get_distance(node.x, node.y, goal_node.x, goal_node.y)
                    if best_node == None or dist < smallest_distance:
                        best_node = node
                        smallest_distance = dist

        current_node = best_node
        if not current_node:
            return path
        path += [current_node]
        
            
        if best_node == goal_node:
            break
        
    return path
            
        

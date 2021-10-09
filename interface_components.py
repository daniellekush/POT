from . import global_values as g
from . import utilities as util
from . import graphics as gfx
from . import game_objects

import pygame as p
import pygame.gfxdraw as pg
import math as m


class Interface_Component(game_objects.Game_Object):
    def __init__(self, rect, active_states, **_kwargs):
        kwargs = {"background":False, "inactive_states":set()}
        kwargs.update(_kwargs)

        self.active_states = active_states

        self.active = False
        self.active_override = None
        
        game_objects.Game_Object.__init__(self, rect, **kwargs)
        
    def update(self):
        old_active = self.active
        game_objects.Game_Object.update(self)
        self.active = self.get_active()
        if not old_active and self.active:
            self.on_activate()
        elif old_active and not self.active:
            self.on_deactivate()

    def on_activate(self):
        pass

    def on_deactivate(self):
        pass

    def get_active(self):
        if self.active_override is not None:
            active = self.active_override
        else:
            if not bool(g.current_states & self.inactive_states):
                active = bool(g.current_states & self.active_states)
            else:
                active = False
        return active

    def get_states_active(self):
        active = bool(g.current_states & self.active_states)
        return active

    def draw(self):
        pass

    def delete(self):
        game_objects.Game_Object.delete(self)

class Bar(Interface_Component):
    def __init__(self, rect, variable_name, min_value, max_value, active_states, **_kwargs):

        kwargs = {"variable_name":variable_name, "min_value":min_value, "max_value":max_value, "variable_obj":None, "min_colour":g.RED, "max_colour":g.GREEN, "background_colour":None, "border_colour":g.BLACK, "border_size":2, "bar_surface":None, "direction":"horizontal"}
        kwargs.update(_kwargs)
        
        Interface_Component.__init__(self, rect, active_states, **kwargs)

        if self.bar_surface:
            self.bar_surface = p.transform.scale(self.bar_surface, (self.rect.w, self.rect.h))
            self.bar_surface_rect = self.bar_surface.get_rect()

        self.update()

    def get_value(self):
        return util.get_variable_value(self.variable_name, self.variable_obj)

    def update(self):
        Interface_Component.update(self)
        
        self.value = self.get_value()
        value_intensity = max(min((self.value-self.min_value)/(self.max_value-self.min_value),1),0)

        self.bar_colour = [None, None, None]
        for c in range(3):
            c_dif = self.max_colour[c]-self.min_colour[c]
            self.bar_colour[c] = int(util.interpolate_between_values(self.min_colour[c], self.max_colour[c], value_intensity))

        self.bar_rect = self.rect.copy()
        if self.direction == "horizontal":
            if self.border_size is not None:
                self.bar_rect.inflate_ip(0,-self.border_size*2)
                self.bar_rect.midleft = self.rect.midleft
                self.bar_rect.x += self.border_size
                
                self.bar_rect.w = int( (self.rect.w-(self.border_size*2))*value_intensity)
                
            else:
                self.bar_rect.w = int(self.rect.w*value_intensity)
        else:
            if self.border_size is not None:
                self.bar_rect.inflate_ip(0,-self.border_size*2)
                self.bar_rect.midbottom = self.rect.midbottom
                self.bar_rect.y -= self.border_size+1
                
                self.bar_rect.h = int( (self.rect.h-(self.border_size*2))*value_intensity)
                self.bar_rect.y += self.rect.h-self.bar_rect.h
                
            else:
                self.bar_rect.h = int(self.rect.h*value_intensity)
                self.bar_rect.y += self.rect.h-self.bar_rect.h
            
    def draw(self):
        Interface_Component.draw(self)

        if self.background_colour:
            p.draw.rect(g.screen, self.background_colour, self.rect)
        
        if self.border_size is not None:
            p.draw.rect(g.screen, self.border_colour, self.rect, self.border_size)

        if self.bar_surface:
            area_rect = self.bar_rect.copy()
            if self.direction == "horizontal":
                area_rect.midleft = self.bar_surface_rect.midleft
            elif self.direction == "vertical":
                area_rect.midbottom = self.bar_surface_rect.midbottom

            g.screen.blit(self.bar_surface, self.bar_rect, area=area_rect)
        else:
            p.draw.rect(g.screen, self.bar_colour, self.bar_rect)
        

class Decoration(Interface_Component):
    def __init__(self, rect, graphics, active_states, **_kwargs):
        kwargs = {}
        kwargs.update(_kwargs)
        Interface_Component.__init__(self, rect, active_states, **kwargs)
        self.graphics = graphics

    def update(self):
        Interface_Component.update(self)

    def draw(self):
        Interface_Component.draw(self)
        self.surface = gfx.scale_graphics(self.graphics, (self.rect.width, self.rect.height))
        g.screen.blit(self.surface, self.rect)

class Background(Decoration):
    def __init__(self, graphics, active_states, **_kwargs):
        kwargs = {"background":True}
        kwargs.update(_kwargs)
        Decoration.__init__(self, g.SCREEN_RECT.copy(), graphics, active_states, **kwargs)

class Pie(Interface_Component):
    def __init__(self, rect, variable_name, min_value, max_value, active_states, **_kwargs):
        self.variable_name = variable_name
        self.min_value = min_value
        self.max_value = max_value
        
        kwargs = {"variable_obj":None, "direction":"clockwise", "border_colour":g.WHITE, "border_thickness":5, "min_colour":g.RED, "max_colour":g.GREEN, "background_colour":None, "min_polygon_sides":3, "max_polygon_sides":36}
        kwargs.update(_kwargs)
        Interface_Component.__init__(self, rect, active_states, **kwargs)

    def get_value(self):
        return util.get_variable_value(self.variable_name, self.variable_obj)

    def update(self):
        Interface_Component.update(self)
        
        self.value = self.get_value()
        value_intensity = max(min((self.value-self.min_value)/(self.max_value-self.min_value),1),0)

        self.pie_colour = [None, None, None]
        for c in range(3):
            c_dif = self.max_colour[c]-self.min_colour[c]
            self.pie_colour[c] = int(util.interpolate_between_values(self.min_colour[c], self.max_colour[c], value_intensity))


    def draw(self):
        Interface_Component.draw(self)

        self.pie_surface = p.Surface((self.rect.w, self.rect.h), p.SRCALPHA)

        relative_rect = self.rect.copy()
        relative_rect.topleft = (0,0)

        if self.background_colour:
            p.draw.ellipse(self.pie_surface, self.background_colour, relative_rect)

        end_angle = 1.5*m.pi
        value = util.get_variable_value(self.variable_name, variable_obj=self.variable_obj)
        fraction = (value-self.min_value)/(self.max_value-self.min_value)

        start_angle = (2*m.pi*fraction)+end_angle
        angle = start_angle

        steps = max(self.min_polygon_sides, int(self.max_polygon_sides*fraction))
        angle_diff = end_angle-angle

        start_angle = angle
        if angle_diff:
            angle_step = angle_diff/steps

            points = [relative_rect.center]
            for step in range(steps+1):
                vx = -m.cos(angle)*(self.rect.width*0.5)
                vy = -m.sin(angle)*(self.rect.height*0.5)
                x = relative_rect.centerx+vx
                y = relative_rect.centery+vy

                points.append((x, y))
                angle += angle_step

            pg.filled_polygon(self.pie_surface, points, self.pie_colour)


        if self.border_colour:
            p.draw.line(self.pie_surface, self.border_colour, relative_rect.center, relative_rect.midbottom, self.border_thickness)
        x = relative_rect.centerx-(m.cos(start_angle)*(self.rect.width*0.5))
        y = relative_rect.centery-(m.sin(start_angle)*(self.rect.height*0.5))
        if self.border_colour:
            p.draw.line(self.pie_surface, self.border_colour, relative_rect.center, (x,y), self.border_thickness)
        
        
        if self.border_colour:
            self.pie_surface = p.transform.flip(self.pie_surface, False, True)
            if angle_diff < 0:
                p.draw.arc(self.pie_surface, self.border_colour, relative_rect, (end_angle+m.pi), start_angle+m.pi, self.border_thickness)
            self.pie_surface = p.transform.flip(self.pie_surface, self.direction == "clockwise", False)
        else:
            self.pie_surface = p.transform.flip(self.pie_surface, self.direction == "clockwise", True)
        
        g.screen.blit(self.pie_surface, self.rect)
        

class Cursor(Decoration):
    def __init__(self, rect, graphics, active_states, **_kwargs):
        kwargs = {}
        kwargs.update(_kwargs)
        Decoration.__init__(self, rect, graphics, active_states, **kwargs)
        
        self.draw_bias += self.height
        
        p.mouse.set_visible(False)

    def update(self):
        Decoration.update(self)
        self.rect.center = (g.smx, g.smy)
        
    def delete(self):
        Decoration.delete(self)
        
        if not g.game_objects.get("class_Cursor", False):
            p.mouse.set_visible(True)

class Button(Interface_Component):
    def __init__(self, name, rect, command_data, pressed_graphics, unpressed_graphics, active_states, **_kwargs):
        kwargs = {"button_type":"hold", "can_press":True, "highlighted_graphics":None, "highlighted_colour":g.GREEN, "highlighted_thickness":4, "press_shift_x":0, "press_shift_y":0, "press_shift_w":0, "press_shift_h":0}
        kwargs.update(_kwargs)
        
        Interface_Component.__init__(self, rect, active_states, **kwargs)
        self.name = name
        self.command_data = command_data
        
        self.pressed_graphics = pressed_graphics
        self.unpressed_graphics = unpressed_graphics

        self.highlighted = False
        self.pressed = False

    def update(self):
        Interface_Component.update(self)
        if self.active:
            self.highlighted = self.get_highlighted()

            if self.can_press:
                self.set_pressed()
                if self.pressed:
                    self.surface = gfx.get_surface(self.pressed_graphics)
                elif self.highlighted and self.highlighted_graphics:
                    self.surface = gfx.get_surface(self.highlighted_graphics)
                else:
                    self.surface = gfx.get_surface(self.unpressed_graphics)

    def get_highlighted(self):
        return self.rect.collidepoint(( int(g.mx), int(g.my)))

    def set_pressed(self):
        if self.button_type == "hold":
            if self.highlighted:
                if g.ml and (not g.current_pressed_button or g.current_pressed_button == self):
                    if not self.pressed:
                        self.press()
                    self.pressed = True
                    return

                #only unpress if button is still highlighted
                elif self.pressed:
                    self.unpress()
                
            self.pressed = False
            if g.current_pressed_button == self:
                g.current_pressed_button = None

    def press(self):
        g.current_pressed_button = self
        g.pressed_buttons.add(self)
        g.internal_commands.append(self.command_data)

    def unpress(self):
        g.pressed_buttons.remove(self)
        if self.name == "start_button":
            g.internal_commands.append("new_game")
        elif self.name == "quit_button":
            util.quit_game()
        elif self.name == "rules_button":
            g.current_states = {"rules"}
        elif self.name == "back_to_menu_button":
            g.current_states = {"start"}

    def draw(self):
        Interface_Component.draw(self)

        rect = self.rect.copy()
        if self.pressed:
            rect.move(self.press_shift_x, self.press_shift_y)
            rect.inflate(self.press_shift_w, self.press_shift_h)

        surface = gfx.scale_surface(self.surface, (rect.w, rect.h))
        g.screen.blit(surface, self.rect)
        if self.highlighted and self.highlighted_colour:
            p.draw.rect(g.screen, self.highlighted_colour, rect, self.highlighted_thickness)

class Button_List(Interface_Component):
    def __init__(self, name, buttons_info, x, y, button_width, button_height, active_states, **_kwargs):
        kwargs = {"direction":"horizontal", "spacing":0, "path_prefix":"", "button_type":"hold", "radio_buttons":False, "highlighted_colour":g.GREEN, "highlighted_thickness":4}
        kwargs.update(_kwargs)
        
        self.buttons = []

        if kwargs["direction"] == "horizontal":
            rect = p.Rect(x, y, len(buttons_info.keys())*(button_width+kwargs["spacing"]), button_height)
        elif kwargs["direction"] == "vertical":
            rect = p.Rect(x, y, button_width, len(buttons_info.keys())*(button_height+kwargs["spacing"]) )

        Interface_Component.__init__(self, rect, active_states, **kwargs)
                
        for button_name, surfaces_data in buttons_info.items():
            surfaces = []
            for surface_data in surfaces_data:
                if isinstance(surface_data, str): 
                    surface = gfx.load_image(path_prefix+surface_data)
                else:
                    surface = gfx.load_image(surface_data)
                surfaces.append(surface)

            if len(surfaces) == 3:
                pressed_surface, unpressed_surface, highlighted_surface = surfaces
            elif len(surfaces) == 2:
                pressed_surface, unpressed_surface = surfaces
                highlighted_surface = None

            button_rect = p.Rect(x, y, button_width, button_height)
            button = Button(name+"_"+button_name, button_rect, pressed_surface, unpressed_surface, active_states, highlighted_surface=highlighted_surface, button_type=button_type, highlighted_colour=highlighted_colour, highlighted_thickness=highlighted_thickness)
            self.buttons.append(button)

            if direction == "horizontal":
                x += button_width+spacing
            elif direction == "vertical":
                y += button_height+spacing

            self.pressed_buttons = [b for b in self.buttons if b.pressed]
            self.new_pressed_buttons = []
            self.new_unpressed_buttons = []

            self.radio_buttons = radio_buttons
                

    def update(self):
        Interface_Component.update(self)
        
        pressed_buttons = [b for b in self.buttons if b.pressed]
        self.new_pressed_buttons = [b for b in self.buttons if (b.pressed and not b in self.pressed_buttons)]
        self.new_unpressed_buttons = [b for b in self.buttons if (not b.pressed and b in self.pressed_buttons)]

        if self.radio_buttons:
            if self.new_pressed_buttons:
                for button in self.buttons:
                    if button != self.new_pressed_buttons[0]:
                        if button.pressed:
                            button.unpress()
                        button.pressed = False

        self.pressed_buttons = pressed_buttons
        
        for button in self.buttons:
            button.active_override = self.active
        
            
class Slides(Interface_Component):
    def __init__(self, rect, slides, active_states, slide_index=0, prefix=g.gfx_dir, suffix=".png", keypress_progression=False, click_progression=False):
        Interface_Component.__init__(self, rect, active_states)
        self.slides = []
        for slide in slides:
            if type(slide) == p.Surface:
                slide = gfx.scale_graphics(slide, (self.rect.w, self.rect.h), cache=False)
            elif type(slide) == str:
                slide = gfx.scale_graphics(gfx.load_image(slide), (self.rect.w, self.rect.h), cache=False)
            self.slides.append(slide)
            
        self.slide_index = slide_index

        self.keypress_progression = keypress_progression
        self.click_progression = click_progression

    def progress(self, amount):
        self.slide_index = (self.slide_index+amount)%len(self.slides)

    def update(self):
        Interface_Component.update(self)
        if self.active:
            self.surface = self.slides[self.slide_index]

    def draw(self):
        Interface_Component.draw(self)
        g.screen.blit(self.surface, self.rect)

class Measurement(Interface_Component):
    def __init__(self, graphics, pos, gfx_size, variable_name, gfx_value, active_states, **_kwargs):
        #round:
        #-1    - don't round
        #0     - int
        #>= 1  - round to number 
        kwargs = {"variable_obj":None, "background_colour":None, "border_colour":None, "border_thickness":4, "direction":"horizontal", "round":0}
        kwargs.update(_kwargs)

        rect = p.Rect(pos[0], pos[1], 1, 1)
        Interface_Component.__init__(self, rect, active_states, **kwargs)
        
        self.variable_name = variable_name
        self.gfx_size = gfx_size
        self.gfx_value = gfx_value
        
        self.set_rect_size()

        self.graphics = graphics
        if not hasattr(type(self.graphics), "__iter__"):
            self.graphics = (self.graphics)
            
        
        

    def update(self):
        Interface_Component.update(self)
        self.set_rect_size()

    def set_rect_size(self):
        if self.round == -1:
            value = util.get_variable_value(self.variable_name, variable_obj=self.variable_obj)
        elif self.round == 0:
            value = int(util.get_variable_value(self.variable_name, variable_obj=self.variable_obj))
        if self.round >= 1:
            value = round(util.get_variable_value(self.variable_name, variable_obj=self.variable_obj), self.round)
        #ensure positive or 0
        if value < 0:
            value = 0
        
        if self.direction == "horizontal":
            rect = p.Rect(self.x, self.y, value*self.gfx_size[0], self.gfx_size[1])
        elif self.direction == "vertical":
            rect = p.Rect(self.x, self.y, self.gfx_size[0], value*self.gfx_size[1])
        self.set_from_rect(rect)

    def draw(self):
        if self.background_colour:
            p.draw.rect(g.screen, self.rect, self.background_colour)

        if self.border_colour:
            border_rect = self.rect.copy()
            border_rect.topleft = (0,0)
            border_rect.inflate(-self.border_thickness, -self.border_thickness)
            p.draw.rect(self.surface, self.border_colour, border_rect, self.border_thickness)
            
        value = util.get_variable_value(self.variable_name, variable_obj=self.variable_obj)
        surfaces_amount = int(value/self.gfx_value)

        draw_rect = p.Rect(self.rect.x, self.rect.y, self.gfx_size[0], self.gfx_size[1])
        for i in range(surfaces_amount):
            graphics = self.graphics[i%len(self.graphics)]
            gfx.draw_scaled_graphics(graphics, draw_rect)

            if self.direction == "horizontal":
                draw_rect.x += self.gfx_size[0]
            elif self.direction == "vertical":
                draw_rect.y += self.gfx_size[1]
            

class Text_Box(Interface_Component):
    def __init__(self, rect, font, text, active_states, text_colour, **_kwargs):
        kwargs = {"center_text":(False, False), "background_colour":None, "border_colour":None, "border_thickness":4, "antialias":False, "eval_text":False, "safe_bounding":False}
        kwargs.update(_kwargs)
        
        Interface_Component.__init__(self, rect, active_states, **kwargs)
        self.font = font
        
        self.text_colour = text_colour
        self.text = text
        self.old_text = self.text
        self.set_text(self.text)

    def update(self):
        Interface_Component.update(self)

        if self.eval_text:
            if type(self.text) == str:
                self.text = compile(self.text, "<string>", "eval")

        if self.eval_text:
            text = str(eval(self.text))
        else:
            text = self.text
            
        if text != self.old_text:
            self.set_text(text)

        self.old_text = text

    def create_surface(self):
        self.surface = p.Surface((self.rect.w, self.rect.h), p.SRCALPHA)
        if self.background_colour:
            self.surface.fill(self.background_colour)

        if self.border_colour:
            border_rect = self.rect.copy()
            border_rect.topleft = (0,0)
            border_rect.inflate(-self.border_thickness, -self.border_thickness)
            p.draw.rect(self.surface, self.border_colour, border_rect, self.border_thickness)

    def set_text(self, text):
        self.create_surface()
        
        
        text_height = self.font.size(text)[1]

        if self.border_colour:
            adjusted_rect = self.rect.inflate(-self.border_thickness*2, -self.border_thickness*2)
        else:
            adjusted_rect = self.rect.copy()
        
        text_lines = util.bound_text(self.font, adjusted_rect, text)

        if self.center_text[1]:
            total_height = text_height*len(text_lines)
            y_diff = (adjusted_rect.height/2)
            y = y_diff-(total_height/2)
        else:
            y = adjusted_rect.y-self.rect.y

            
        for line in text_lines:
            rendered_line = self.font.render(line, self.antialias, self.text_colour)
            lw, lh = self.font.size(line)
            
            if self.center_text[0]:
                width = self.font.size(line)[0]
                x = int((adjusted_rect.width/2)-(width/2))
            else:
                x = adjusted_rect.x-self.rect.x
                
            self.surface.blit(rendered_line, (x,y))
            y += text_height


    def draw(self):    
        g.screen.blit(self.surface, self.rect)

class Monitor(Text_Box):
    def __init__(self, rect, font, variable_name, active_states, text_colour, **_kwargs):
        self.variable_name = variable_name
        kwargs = {"variable_obj":None, "background_colour":g.BLACK, "border_colour":g.WHITE, "border_thickess":4, "antialias":False, "prefix":"", "suffix":""}
        kwargs.update(_kwargs)
        
        Text_Box.__init__(self, rect, font, "", active_states, text_colour, **kwargs)

    def update(self):
        self.text = self.prefix+str(util.get_variable_value(self.variable_name, self.variable_obj))+self.suffix
        Text_Box.update(self)
        

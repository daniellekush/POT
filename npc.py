import creatures

class Npc(creatures.Creature):
    def __init__(self, name, rect, animation_system, max_health, speed, **_kwargs):
        creatures.Creature.__init__(self, name, rect, animation_system, max_health, speed, **_kwargs)



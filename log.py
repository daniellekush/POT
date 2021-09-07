class Log():
    def __init__(self, name):
        self.entries = []

    def clear(entries=None):
        if entries is None:
            self.entries.clear()
        else:
            if entries > 0:
                for i in range(entries):
                    del self.entries[-i]
            elif entries < 0:
                for i in range(-entries):
                    del self.entries[i]

    def output(entries=None, numbering=False):
        if entries is None:
            output_entries = self.entries
        else
            output_entries = self.entries[-entries]
            
        for i, entry in enumerate(output_entries):
            if numbering:
                print(i, end=": ", sep=" ")
            print(entry)

import timeit

def while_loop():
    i = 1
    
    x = 0
    while x < (100):
        x += 1
        i += 1


def for_loop():
    i = 1
    
    for i in range(100):
        i += 1




print(timeit.timeit(while_loop, number=1000))
print(timeit.timeit(for_loop, number=1000))

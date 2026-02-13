import sys
import getopt

# func for writing to file
def write(string):
    try:
        output
    except NameError:
        return
    else:
        output.write(string)

# display usage if no args
opts, args = getopt.getopt(sys.argv[1:], "s:o:", ["seed=", "output="])
if len(args) == 0:
    print("usage: vs-rng.py [options] num_iterations...")
    print("options:")
    print("\t-s, --seed initial rng seed")
    print("\t-o, --output filename to write to")
    sys.exit()

# process options
for opt, arg in opts:
    if opt in ("-s", "--seed"):
        starting_seed = int(arg, 16) & 0xFF
    elif opt in ("-o", "--output"):
        output = open(arg, "w")

# init rng
rng = [0xA5, 0x00]
seeds = list()
seeds_next = list()
try:
    starting_seed
except NameError:
    for i in range(0x00, 0x100):
        seeds.append(True)
        seeds_next.append(True)
else:
    for i in range(0x00, 0x100):
        seeds.append(False)
        seeds_next.append(False)
    seeds_next[starting_seed] = True

# determine seeds
for arg in args:
    for i in range(0x00, 0x100):
        seeds[i] = seeds_next[i]
        seeds_next[i] = False
    for i in range(0x00, 0x100):
        if seeds[i]:
            rng[0] = 0x14
            rng[1] = i
            for j in range(0, int(arg)):
                carry = (rng[0] & 0x02) ^ (rng[1] & 0x02)
                temp = rng[0] & 0x01
                rng[0] = (rng[0] >> 1) | (carry << 6)
                rng[1] = (rng[1] >> 1) | (temp << 7)
            seeds_next[rng[1]] = True

# write out possible seeds
seeds_possible = list()
for i in range(0x00, 0x100):
    if seeds_next[i]:
        seeds_possible.append(i)
print(str(len(seeds_possible)) + (" seeds are possible:" if len(seeds_possible) != 1 else " seed is possible:"))
write(str(len(seeds_possible)) + (" seeds are possible:\n" if len(seeds_possible) != 1 else " seed is possible:\n"))
for i in seeds_possible:
    if i == seeds_possible[len(seeds_possible) - 1]:
        print(f"{i:02X}")
        write(f"{i:02X}")
    else:
        print(f"{i:02X}", end = ", ")
        write(f"{i:02X}" + ", ")
sys.exit()

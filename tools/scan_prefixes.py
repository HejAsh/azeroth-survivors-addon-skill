import re, sys

data = open(sys.argv[1], "rb").read()
# Addon message prefixes like AZSZONE, AZSRUN ... 4+ uppercase after AZS
pat = re.compile(rb"AZS[A-Z]{2,12}")
seen = {}
for m in pat.finditer(data):
    s = m.group().decode()
    seen[s] = seen.get(s, 0) + 1
for s, c in sorted(seen.items()):
    print(f"{s} x{c}")

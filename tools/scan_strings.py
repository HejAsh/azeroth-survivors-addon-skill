import re, sys

path = sys.argv[1]
needles = [n.encode() for n in sys.argv[2:]]
pat = re.compile(rb"[\x20-\x7e]{6,}")
data = open(path, "rb").read()
hits = {}
for m in pat.finditer(data):
    s = m.group()
    for n in needles:
        if n.lower() in s.lower():
            hits.setdefault(n.decode(), []).append((m.start(), s[:300].decode("ascii", "replace")))
for n, lst in hits.items():
    print(f"== {n}: {len(lst)} hits")
    for off, s in lst[:25]:
        print(f"  @0x{off:x}: {s}")

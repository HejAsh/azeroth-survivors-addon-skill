import sys

src, out_prefix = sys.argv[1], sys.argv[2]
regions = []
for arg in sys.argv[3:]:
    start, end = arg.split("-")
    regions.append((int(start, 0), int(end, 0)))
data = open(src, "rb").read()
for i, (s, e) in enumerate(regions):
    chunk = data[s:e]
    fn = f"{out_prefix}_{i}_{s:x}.lua"
    open(fn, "wb").write(chunk)
    print(fn, len(chunk))

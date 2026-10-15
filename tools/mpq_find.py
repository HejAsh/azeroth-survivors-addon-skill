import sys
from mpyq import MPQArchive

p = sys.argv[1]
a = MPQArchive(p, listfile=True)
raw = a.read_file("(listfile)")
text = raw.decode("utf-8", "replace") if isinstance(raw, bytes) else str(raw)
lines = [l for l in text.replace("\r\n", "\n").split("\n") if l]
kw = sys.argv[2].lower() if len(sys.argv) > 2 else None
for l in lines:
    if kw is None or kw in l.lower():
        print(l)

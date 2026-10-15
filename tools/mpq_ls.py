import sys
from mpyq import MPQArchive

path = sys.argv[1]
mode = sys.argv[2] if len(sys.argv) > 2 else "list"
a = MPQArchive(path, listfile=True)
if mode == "list":
    names = a.read_file("(listfile)")
    text = names.decode("utf-8", "replace") if isinstance(names, bytes) else str(names)
    lines = [l for l in text.split("\r\n") if l]
    hits = [l for l in lines if "azs" in l.lower() or "interface" in l.lower()]
    print(f"TOTAL {len(lines)}")
    for l in hits[:200]:
        print(l)
elif mode == "extract":
    a.extract_file(sys.argv[3])
    print("extracted", sys.argv[3])

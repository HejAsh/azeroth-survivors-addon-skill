import sys
from mpyq import MPQArchive

for p in sys.argv[1:]:
    try:
        a = MPQArchive(p, listfile=True)
        raw = a.read_file("(listfile)")
        if raw is None:
            print(f"{p}: listfile None")
            continue
        text = raw.decode("utf-8", "replace") if isinstance(raw, bytes) else str(raw)
        lines = [l for l in text.replace("\r\n", "\n").split("\n") if l]
        print(f"{p}: {len(lines)} files")
    except Exception as e:
        print(f"{p}: ERROR {type(e).__name__}: {e}")

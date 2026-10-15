import struct, sys

MPQ_MAGIC = b"MPQ\x1a"
for p in sys.argv[1:]:
    with open(p, "rb") as f:
        data = f.read(2048)
    off = data.find(MPQ_MAGIC)
    if off < 0:
        print(p, "no MPQ header in first 2KB")
        continue
    (magic, hdrsize, archsize, version, blocksize) = struct.unpack_from("<4sIIHH", data, off)
    print(f"{p}: magic ok, header_size={hdrsize}, format_version={version}, block_size={blocksize} (sector= {512 << blocksize})")

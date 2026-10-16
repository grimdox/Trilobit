#!/usr/bin/env python3
"""Stamp an icon and version info into a Godot Windows export without Wine or rcedit.
Usage: set_exe_icon.py game.exe icon.ico "Product name" "File description" "1.2.3.4" "Company"
Rewrites the .rsrc section in place (the new resources are smaller than Godot's), so the embedded .pck is untouched."""
import struct, sys

def u16(d, o): return struct.unpack_from('<H', d, o)[0]
def u32(d, o): return struct.unpack_from('<I', d, o)[0]

def parse_dir(rs, off):
    node = {}
    n = u16(rs, off + 12) + u16(rs, off + 14)
    for i in range(n):
        nm, ch = u32(rs, off + 16 + i * 8), u32(rs, off + 20 + i * 8)
        if nm & 0x80000000:
            so = nm & 0x7fffffff
            key = rs[so + 2: so + 2 + u16(rs, so) * 2].decode('utf-16le')
        else:
            key = nm
        node[key] = parse_dir(rs, ch & 0x7fffffff) if ch & 0x80000000 else ('data', ch)
    return node

def load_data(rs, node, va):
    out = {}
    for k, v in node.items():
        if isinstance(v, dict):
            out[k] = load_data(rs, v, va)
        else:
            o = v[1]
            rva, size = u32(rs, o), u32(rs, o + 4)
            out[k] = rs[rva - va: rva - va + size]
    return out

def build_tree(tree, va):
    """Serialise {type:{name:{lang:bytes}}} into a resource section image."""
    def skey(k): return (0, k) if isinstance(k, str) else (1, k)
    # sizes first
    layout = []   # (offset, bytes) pieces assembled later
    types = sorted(tree, key=skey)
    # directory area
    tabs = []     # list of (kind, key list)
    sz = 16 + 8 * len(types)
    name_tabs = {}
    for t in types:
        names = sorted(tree[t], key=skey)
        name_tabs[t] = (sz, names)
        sz += 16 + 8 * len(names)
    lang_tabs = {}
    for t in types:
        for n in name_tabs[t][1]:
            langs = sorted(tree[t][n])
            lang_tabs[(t, n)] = (sz, langs)
            sz += 16 + 8 * len(langs)
    entries_off = sz
    leaves = [(t, n, l) for t in types for n in name_tabs[t][1] for l in lang_tabs[(t, n)][1]]
    sz += 16 * len(leaves)
    strings = {}
    strdata = b''
    for k in set([t for t in types] + [n for t in types for n in name_tabs[t][1]]):
        if isinstance(k, str):
            strings[k] = sz + len(strdata)
            e = k.encode('utf-16le')
            strdata += struct.pack('<H', len(k)) + e
    sz += len(strdata)
    sz = (sz + 3) & ~3
    blobs = {}
    datapos = sz
    for lf in leaves:
        blobs[lf] = datapos
        datapos += (len(tree[lf[0]][lf[1]][lf[2]]) + 3) & ~3
    buf = bytearray(datapos)
    def hdr(off, count_named, count_id):
        struct.pack_into('<IIHHHH', buf, off, 0, 0, 4, 0, count_named, count_id)
    def put_key(off, k, child, is_dir):
        nm = (0x80000000 | strings[k]) if isinstance(k, str) else k
        struct.pack_into('<II', buf, off, nm, child | (0x80000000 if is_dir else 0))
    def keyorder(keys): return sorted(keys, key=skey)
    hdr(0, sum(isinstance(t, str) for t in types), sum(not isinstance(t, str) for t in types))
    for i, t in enumerate(types):
        put_key(16 + i * 8, t, name_tabs[t][0], True)
        to, names = name_tabs[t]
        hdr(to, sum(isinstance(n, str) for n in names), sum(not isinstance(n, str) for n in names))
        for j, n in enumerate(names):
            put_key(to + 16 + j * 8, n, lang_tabs[(t, n)][0], True)
            lo, langs = lang_tabs[(t, n)]
            hdr(lo, 0, len(langs))
            for m, l in enumerate(langs):
                idx = leaves.index((t, n, l))
                put_key(lo + 16 + m * 8, l, entries_off + idx * 16, False)
    for idx, lf in enumerate(leaves):
        data = tree[lf[0]][lf[1]][lf[2]]
        struct.pack_into('<IIII', buf, entries_off + idx * 16, va + blobs[lf], len(data), 0, 0)
        buf[blobs[lf]: blobs[lf] + len(data)] = data
    buf[entries_off + 16 * len(leaves): entries_off + 16 * len(leaves) + len(strdata)] = strdata
    return bytes(buf)

def pad4(b): return b + b'\0' * (-len(b) % 4)
def vs_node(key, value=b'', vtype=1, wvlen=None, children=b''):
    k = (key + '\0').encode('utf-16le')
    head = struct.pack('<HHH', 0, len(value) // (2 if vtype else 1) if wvlen is None else wvlen, vtype) + k
    body = pad4(head) + value
    body = pad4(body) + children
    return struct.pack('<H', len(body)) + body[2:] if False else struct.pack('<H', len(body)) + body[2:]

def version_info(vals, ver):
    parts = [int(x) for x in ver.split('.')] + [0, 0, 0, 0]
    ms, ls = (parts[0] << 16) | parts[1], (parts[2] << 16) | parts[3]
    fixed = struct.pack('<IIIIIIIIIIIII', 0xFEEF04BD, 0x10000, ms, ls, ms, ls, 0x3F, 0, 0x40004, 1, 0, 0, 0)
    strs = b''
    for k, v in vals.items():
        val = (v + '\0').encode('utf-16le')
        strs += pad4(vs_node(k, val, 1))
    table = pad4(vs_node('040904b0', b'', 1, wvlen=0, children=strs))
    sfi = pad4(vs_node('StringFileInfo', b'', 1, wvlen=0, children=table))
    var = pad4(vs_node('Translation', struct.pack('<HH', 0x409, 0x4b0), 0, wvlen=4))
    vfi = pad4(vs_node('VarFileInfo', b'', 1, wvlen=0, children=var))
    return vs_node('VS_VERSION_INFO', fixed, 0, wvlen=len(fixed), children=sfi + vfi)

def main(exe, ico, product, desc, ver, company):
    d = bytearray(open(exe, 'rb').read())
    pe = u32(d, 0x3c)
    nsec = u16(d, pe + 6); opt = u16(d, pe + 20)
    dd = pe + 24 + 112          # PE32+ data directories
    rva, size = u32(d, dd + 16), u32(d, dd + 20)
    sh = pe + 24 + opt
    for i in range(nsec):
        name, vs, va, rsz, rptr = struct.unpack_from('<8sIIII', d, sh + i * 40)
        if va <= rva < va + max(vs, rsz):
            break
    rs = bytes(d[rptr: rptr + rsz])
    tree = load_data(rs, parse_dir(rs, 0), va)
    # icons
    icon = open(ico, 'rb').read()
    count = u16(icon, 4)
    grp = struct.pack('<HHH', 0, 1, count)
    icons = {}
    for i in range(count):
        w, h, cc, _, pl, bc, sz, off = struct.unpack_from('<BBBBHHII', icon, 6 + i * 16)
        icons[i + 1] = {0x409: icon[off: off + sz]}
        grp += struct.pack('<BBBBHHIH', w, h, cc, 0, pl, bc, sz, i + 1)
    tree[3] = icons
    tree[14] = {1: {0x409: grp}}
    vals = {'CompanyName': company, 'FileDescription': desc, 'FileVersion': ver, 'InternalName': product,
            'LegalCopyright': company, 'OriginalFilename': product + '.exe', 'ProductName': product, 'ProductVersion': ver}
    tree[16] = {1: {0x409: version_info(vals, ver)}}
    img = build_tree(tree, va)
    cap = max(vs, rsz)
    if len(img) > rsz:
        sys.exit('new resources (%d bytes) do not fit the .rsrc section (%d)' % (len(img), rsz))
    d[rptr: rptr + rsz] = img + b'\0' * (rsz - len(img))
    struct.pack_into('<I', d, dd + 20, len(img))
    struct.pack_into('<I', d, pe + 24 + 64, 0)    # checksum
    open(exe, 'wb').write(d)
    print('stamped %s: %d icons, %d bytes of resources' % (exe, count, len(img)))

if __name__ == '__main__':
    main(*sys.argv[1:7])

#!/usr/bin/python3
# Checks a dtbloader image (vmlinuz-dtbloader.efi) the way stubble will use it on the
# laptop: which device tree does a given SMBIOS hardware ID (CHID) select?
#   check-dtbloader.py IMAGE CHID EXPECTED_COMPATIBLE
# Reads the PE sections, decodes .hwids (ukify's format: Device structs, then strings),
# finds the compatible string for CHID, and checks that exactly one .dtbauto device tree
# has it as its first root compatible (stubble only compares the first one). Prints the
# model of the chosen tree. Exit status 1 on any mismatch.
import struct
import sys
import uuid

FDT_BEGIN_NODE, FDT_END_NODE, FDT_PROP, FDT_NOP, FDT_END = 1, 2, 3, 4, 9


def pe_sections(data):
    pe = struct.unpack_from('<I', data, 0x3C)[0]
    if data[pe:pe + 4] != b'PE\0\0':
        sys.exit('not a PE image')
    nsections, = struct.unpack_from('<H', data, pe + 6)
    optsize, = struct.unpack_from('<H', data, pe + 20)
    table = pe + 24 + optsize
    for i in range(nsections):
        off = table + 40 * i
        name = data[off:off + 8].rstrip(b'\0').decode('ascii', 'replace')
        vsize, _, rawsize, rawptr = struct.unpack_from('<IIII', data, off + 8)
        yield name, data[rawptr:rawptr + min(vsize, rawsize) if vsize else rawsize]


def cstring(blob, off):
    return blob[off:blob.index(b'\0', off)].decode('utf-8')


def hwids(blob):
    # uint32 descriptor (type << 28 | size), EFI_GUID chid, uint32 name_off, uint32 compat_off
    table, off = {}, 0
    while True:
        descriptor, = struct.unpack_from('<I', blob, off)
        if descriptor == 0:
            return table
        size = descriptor & 0x0FFFFFFF
        chid = uuid.UUID(bytes_le=bytes(blob[off + 4:off + 20]))
        _, compat_off = struct.unpack_from('<II', blob, off + 20)
        if descriptor >> 28 == 1:  # device tree
            table.setdefault(chid, []).append(cstring(blob, compat_off))
        off += size


def root_props(dtb):
    magic, _, off_struct, off_strings = struct.unpack_from('>IIII', dtb, 0)
    if magic != 0xD00DFEED:
        raise ValueError('not a flattened device tree')
    props, depth, off = {}, 0, off_struct
    while True:
        token, = struct.unpack_from('>I', dtb, off)
        off += 4
        if token == FDT_BEGIN_NODE:
            end = dtb.index(b'\0', off)
            off = (end + 4) & ~3
            depth += 1
        elif token == FDT_END_NODE:
            depth -= 1
            if depth == 0:
                return props
        elif token == FDT_PROP:
            length, nameoff = struct.unpack_from('>II', dtb, off)
            value = bytes(dtb[off + 8:off + 8 + length])
            off = (off + 8 + length + 3) & ~3
            if depth == 1:
                props[cstring(dtb, off_strings + nameoff)] = value
        elif token == FDT_NOP:
            continue
        elif token == FDT_END:
            return props
        else:
            raise ValueError(f'bad FDT token {token}')


def main():
    if len(sys.argv) != 4:
        sys.exit('usage: check-dtbloader.py IMAGE CHID EXPECTED_COMPATIBLE')
    image, chid, expected = sys.argv[1], uuid.UUID(sys.argv[2]), sys.argv[3]
    data = open(image, 'rb').read()
    sections = list(pe_sections(data))
    names = [n for n, _ in sections]
    for full_uki in ('.osrel', '.cmdline', '.initrd'):
        if full_uki in names:
            sys.exit(f'{image}: has {full_uki}; a dtbloader image must not be a full UKI')
    hw = [b for n, b in sections if n == '.hwids']
    if len(hw) != 1:
        sys.exit(f'{image}: {len(hw)} .hwids sections')
    compats = hwids(hw[0]).get(chid, [])
    if compats != [expected]:
        sys.exit(f'{image}: CHID {chid} selects {compats or "nothing"}, expected {expected}')
    trees = []
    for name, blob in sections:
        if name != '.dtbauto':
            continue
        props = root_props(blob)
        first = props.get('compatible', b'').split(b'\0')[0].decode()
        trees.append((first, props.get('model', b'').rstrip(b'\0').decode()))
    chosen = [model for first, model in trees if first == expected]
    if len(chosen) != 1:
        sys.exit(f'{image}: {len(chosen)} of {len(trees)} .dtbauto trees start with {expected}')
    print(f'{len(trees)} device trees; CHID {chid} -> {expected}: {chosen[0]}')


if __name__ == '__main__':
    main()

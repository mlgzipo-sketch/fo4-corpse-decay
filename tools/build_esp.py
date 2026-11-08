#!/usr/bin/env python3
"""Build CorpseDecay.esp from scratch (no Creation Kit needed).

Records: settings (GLOB), lists (FLST), two effect shaders (EFSH, tuned copies of
vanilla CryoCorpseFXS and PoisonDamageFXS), two lootable remains (CONT using the
vanilla skeleton meshes) and the start-game-enabled quest that runs CorpseDecayMain.
Works for Fallout 4 and Fallout 4 VR (plain .esp, form version 131, master Fallout4.esm).
"""
import struct, sys

OUT = sys.argv[1] if len(sys.argv) > 1 else 'CorpseDecay.esp'
FORM_VERSION = 131
OWN = 0x01000000          # our records: master count (1) in the top byte
next_id = 0x800

def h(s): return bytes.fromhex(s)

def zstr(s, enc='cp1251'): return s.encode(enc) + b'\0'

def sub(tag, data):
    assert len(data) < 0x10000
    return tag.encode() + struct.pack('<H', len(data)) + data

def record(tag, formid, subs, flags=0):
    body = b''.join(subs)
    return tag.encode() + struct.pack('<IIIIHH', len(body), flags, formid, 0, FORM_VERSION, 0) + body

def group(tag, records):
    body = b''.join(records)
    return b'GRUP' + struct.pack('<I4sIIHH', 24 + len(body), tag.encode(), 0, 0, 0, 0) + body

def new_id():
    global next_id
    fid = OWN | next_id
    next_id += 1
    return fid

# ------------------------------------------------------------------ vanilla forms (Fallout4.esm)
V = dict(
    ActorTypeHuman=0x0002CB72, ActorTypeGhoul=0x000EAFB7, ActorTypeFeralGhoul=0x0006B4F2,
    ActorTypeSuperMutant=0x0006D7B6, ActorTypeAnimal=0x00013798, ActorTypeCreature=0x00013795,
    ActorTypeRobot=0x0002CB73,
    GnatSwarm01=0x00054BD1,
    LCharViciousDog=0x0007313E, LCharFeralGhoul=0x000758AE, LCharMolerat=0x000342C8,
    LCharRadroach=0x0016CA45, LCharBloatfly=0x00033208,
)

recs = {}      # tag -> list of records
ids = {}       # our editor id -> formid

def add(tag, edid, subs):
    fid = new_id()
    ids[edid] = fid
    recs.setdefault(tag, []).append(record(tag, fid, [sub('EDID', zstr(edid))] + subs))
    return fid

# ------------------------------------------------------------------ settings
GLOBALS = [
    ('CD_Enabled', 1), ('CD_Debug', 0), ('CD_TimeScale', 1),
    ('CD_HoursFlies', 3), ('CD_HoursPale', 12), ('CD_HoursRot', 48),
    ('CD_HoursRemains', 96), ('CD_HoursBones', 168), ('CD_HoursCleanup', 336),
    ('CD_ScavengerChance', 25), ('CD_IncludeOldCorpses', 0),
]
for name, val in GLOBALS:
    add('GLOB', name, [sub('FNAM', b'f'), sub('FLTV', struct.pack('<f', val))])

# ------------------------------------------------------------------ lists
def flst(edid, forms):
    return add('FLST', edid, [sub('LNAM', struct.pack('<I', f)) for f in forms])

flst('CD_ActorTypes', [V['ActorTypeHuman'], V['ActorTypeGhoul'], V['ActorTypeFeralGhoul'],
                       V['ActorTypeSuperMutant'], V['ActorTypeAnimal'], V['ActorTypeCreature']])
flst('CD_ScavengersExterior', [V['LCharViciousDog'], V['LCharViciousDog'], V['LCharFeralGhoul'],
                               V['LCharMolerat'], V['LCharBloatfly']])
flst('CD_ScavengersInterior', [V['LCharRadroach'], V['LCharRadroach'], V['LCharFeralGhoul'], V['LCharMolerat']])

# ------------------------------------------------------------------ effect shaders
def setf(b, off, v): struct.pack_into('<f', b, off, v)

# DNAM offsets (FO4 EFSH): 12 fill color, 16/20/24 fill fade in/full/out, 28 fill persistent ratio,
# 32/36 fill pulse amp/freq, 40/44 texture scroll U/V, 52 edge color, 56/60/64 edge fade in/full/out,
# 68 edge persistent ratio, 72/76 edge pulse amp/freq, 80 fill full ratio, 84 edge full ratio.
CRYO_DNAM = h('050000000100000007000000000000000000000000000000000020419a99193e000000000000000000000000000000000000803fadd8f8000000000000001040000020410000003e0000000000000000cdcc4c3d0000003e02000000000000000000803f00007f430000000000000000ffffff00ffffff00040000803fec51383eec51383e000000000000803e0000803f0e0000000000004000000040')
POISON_DNAM = h('050000000100000007000000515151000000803f0000003f0000803fcdcc4c3dcdcccc3d0000003f000000008fc275bd0000803f242b13000000803f0000003f0000803f0000403fcdcccc3d0000003f0ad7a33d0000403f06000000000000000000204100007f43000000002c962400b0b0b0006b6b6b00040000403f0000403f0000403f000000000000803e0000803f0e8403000000c0400000c040')

# pale: a cold grey rim on the skin, no ice texture
d = bytearray(CRYO_DNAM)
setf(d, 16, 2.0); setf(d, 20, 0.0); setf(d, 28, 0.0); setf(d, 80, 0.0)
d[52:56] = bytes([0x9c, 0xa6, 0xa0, 0])
setf(d, 56, 2.0); setf(d, 60, 0.0); setf(d, 68, 0.35); setf(d, 84, 0.35)
add('EFSH', 'CD_PaleFXS', [sub('ICON', zstr('Effects\\IceTile_d.dds')), sub('NAM7', b'\0'),
                           sub('NAM8', zstr('Effects\\Gradients\\CritCryoGrad.dds')), sub('DATA', b''),
                           sub('DNAM', bytes(d))])

# rot: dark green veins, steady (no pulsing, no scrolling)
d = bytearray(POISON_DNAM)
d[12:16] = bytes([0x3a, 0x40, 0x2c, 0])
setf(d, 16, 2.0); setf(d, 20, 0.0); setf(d, 28, 0.45); setf(d, 80, 0.45)
setf(d, 32, 0.0); setf(d, 36, 0.0); setf(d, 40, 0.0); setf(d, 44, 0.0)
d[52:56] = bytes([0x2a, 0x30, 0x14, 0])
setf(d, 56, 2.0); setf(d, 60, 0.0); setf(d, 68, 0.6); setf(d, 84, 0.6); setf(d, 72, 0.0); setf(d, 76, 0.0)
add('EFSH', 'CD_RotFXS', [sub('ICON', zstr('Effects\\NoiseVeinPatternTile_d.DDS')), sub('NAM7', b'\0'),
                          sub('NAM8', zstr('Effects\\Gradients\\PoisonShaderGrad.dds')), sub('DATA', b''),
                          sub('DNAM', bytes(d)), sub('MODT', h('0400000000000000000000000000000000000000'))])

# ------------------------------------------------------------------ lootable remains
def remains(edid, name, model, obnd, modt):
    return add('CONT', edid, [sub('OBND', h(obnd)), sub('FULL', zstr(name)), sub('MODL', zstr(model)),
                              sub('MODT', h(modt)), sub('DATA', b'\0' * 5)])

remains('CD_RemainsFlesh', 'Останки', 'SetDressing\\Skeletons\\SkeletonWithMeat.nif',
        'd5fff5ff00002b0011008300',
        '0400000008000000000000000400000002000000df73fecb64647300f0f6f331061ff8a864647300f0f6f33128111d9664647300e3a5e945f17d1bf564647300e3a5e945ef94ce1564647300e3a5e94518f62d4864647300f0f6f331cffff8e264647300582c5533cbdfed52646473001cdb88c54376fab86267736d7ece0c11f6e9d7446267736d6488abfb')
remains('CD_RemainsBones', 'Скелет', 'SetDressing\\Skeletons\\SkeletonBareBody01.nif',
        'd5fff5ff00002b0011008300',
        '040000000300000000000000010000000100000028111d9664647300e3a5e945f17d1bf564647300e3a5e945ef94ce1564647300e3a5e9454376fab86267736d7ece0c11')

# ------------------------------------------------------------------ quest + script
def wstr(s): b = s.encode('latin1'); return struct.pack('<H', len(b)) + b

def prop_obj(name, formid):
    return wstr(name) + bytes([1, 1]) + struct.pack('<HhI', 0, -1, formid)

props = {
    'CD_ActorTypes': ids['CD_ActorTypes'],
    'CD_ScavengersExterior': ids['CD_ScavengersExterior'],
    'CD_ScavengersInterior': ids['CD_ScavengersInterior'],
    'ActorTypeRobot': V['ActorTypeRobot'], 'ActorTypeHuman': V['ActorTypeHuman'],
    'ActorTypeGhoul': V['ActorTypeGhoul'], 'ActorTypeFeralGhoul': V['ActorTypeFeralGhoul'],
    'ActorTypeSuperMutant': V['ActorTypeSuperMutant'],
    'CD_Flies': V['GnatSwarm01'],
    'CD_PaleFXS': ids['CD_PaleFXS'], 'CD_RotFXS': ids['CD_RotFXS'],
    'CD_RemainsFlesh': ids['CD_RemainsFlesh'], 'CD_RemainsBones': ids['CD_RemainsBones'],
}
for name, _ in GLOBALS:
    props[name] = ids[name]

vmad = struct.pack('<hhH', 6, 2, 1) + wstr('CorpseDecayMain') + b'\0' + struct.pack('<H', len(props))
vmad += b''.join(prop_obj(k, v) for k, v in props.items())

add('QUST', 'CD_Quest', [sub('VMAD', vmad), sub('FULL', zstr('Corpse Decay')),
                         sub('DNAM', h('110000000000000000000000')), sub('NEXT', b''),
                         sub('ANAM', struct.pack('<I', 0))])

# ------------------------------------------------------------------ write
ORDER = ['GLOB', 'FLST', 'EFSH', 'CONT', 'QUST']
nrec = sum(len(recs[t]) for t in ORDER)
hedr = struct.pack('<fII', 1.0, nrec, next_id)
tes4 = record('TES4', 0, [sub('HEDR', hedr), sub('CNAM', zstr('Aleshon')),
                          sub('SNAM', zstr('Corpse Decay: bodies rot, turn to bones, draw scavengers.', 'latin1')),
                          sub('MAST', zstr('Fallout4.esm')), sub('DATA', b'\0' * 8)])
with open(OUT, 'wb') as f:
    f.write(tes4)
    for t in ORDER:
        f.write(group(t, recs[t]))
print('wrote', OUT, nrec, 'records')
for k, v in ids.items():
    print('  %08X %s' % (v, k))

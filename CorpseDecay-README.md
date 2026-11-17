# Corpse Decay (Fallout 4 / Fallout 4 VR)

Bodies left in the world rot over game time, like in Red Dead Redemption 2, and old corpses
sometimes draw scavengers. Pure Papyrus and a plain ESP: no F4SE or DLL needed, so the same
files work in flat Fallout 4 and in Fallout 4 VR.

## What happens to a body

| Game hours after death | Stage |
|---|---|
| 3 | Flies (vanilla gnat swarm) gather over the body |
| 12 | Pale, cold skin |
| 48 | Rot: dark green veins |
| 96 | The body becomes lootable remains (skeleton with flesh). Everything it carried is moved into the remains |
| 168 | Only bones are left (still lootable) |
| 336 | The remains are cleaned up so saves stay small |

* Named (unique) characters stop at the rot stage and keep their body, so quests that need it keep working.
* Animals and creatures rot, then disappear at the remains stage.
* Robots are ignored.
* The body is never swapped for bones while you stand right next to it.
* At most 100 bodies are tracked; the oldest is dropped first.

## Scavengers

While a body is between "flies" and "remains", once per game day there is a 25% chance that
vicious dogs, feral ghouls, mole rats or bloatflies (radroaches indoors) are waiting at it
when you come back. They only appear when you are at least 2500 units away, and no more than
9 are around at once.

## Settings (console)

All settings are globals, changed with `set <name> to <value>`:

| Global | Default | Meaning |
|---|---|---|
| `CD_Enabled` | 1 | 0 pauses the mod |
| `CD_TimeScale` | 1 | Speeds decay up; 24 means one game hour counts as a day (for testing) |
| `CD_HoursFlies`, `CD_HoursPale`, `CD_HoursRot`, `CD_HoursRemains`, `CD_HoursBones`, `CD_HoursCleanup` | 3, 12, 48, 96, 168, 336 | Stage times in game hours |
| `CD_ScavengerChance` | 25 | Percent per body per game day |
| `CD_IncludeOldCorpses` | 0 | 1 also decays bodies that were already dead when you found them |
| `CD_Debug` | 0 | 1 writes `[CorpseDecay]` lines to the Papyrus log |

## Install

Unpack into `Data` (or install the zip with Vortex/MO2) and enable `CorpseDecay.esp`.
It can be added to an existing save. Only bodies of characters who die after that are tracked
(unless `CD_IncludeOldCorpses` is 1).

## Building

GitHub Actions builds everything on each push: the script is compiled with the open-source
[Caprica](https://github.com/Orvid/Caprica) compiler against small declaration stubs in `stubs/`,
and `tools/build_esp.py` writes the ESP. The result is the `CorpseDecay` artifact of the run.

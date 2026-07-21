# PKE Meter

**This mod is currently in ALPHA. Bugs, crashes, and performance issues are very possible. Beware!**

## Description

**PKE Meter** is a ghost scanner for the modern age. Like previous ghost scanners, it outputs a list of required construction items within its logistics network as a set of circuit network signals.

However, unlike most if not all previous ghost scanners, it is primarily driven by construction and destruction events rather than on_tick polling. This means that **PKE meter uses considerably less CPU per frame** than previous scanners.

PKE Meter also tries to be as correct as possible, supporting tile ghosts and item request proxies in addition to entity ghosts.

## How to Use

The "PKE Meter" recipe is unlocked alongside the selector combinator when you research the "Advanced Combinators" technology.

You may then place the combinator. The combinator *must* be placed within the logistic area (orange square) of a roboport network, or it will not output anything.

Once placed, the combinator will output the sum of all items required to place entity or tile ghosts, as well as the sum of all item request proxies, within its logistic network.

## Credits

- **Previous ghost scanner mods** of which there are many, for the basic concept behind the mod.

The reasoning behind `tkg/scripts/ui/NebulaWeather.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Nebula weather

Above `const NEAR := 46      ## tile size, near layer`:

```text
Gas blowing through the sector, when the sector is inside a nebula.

The chart says a system sits in a cloud; this is what that looks like from
the inside. Drawn behind the ship and the subject so it reads as weather they
are flying through rather than as an overlay on top of them.

Two layers at different speeds and depths, because one layer of drifting
pixels reads as static on a moving object and two read as a medium. The near
layer is sparse, brighter and quick; the far layer is dense, dim and slow.

Deliberately cheap: about six hundred pixels a frame, no allocation, and it
tiles rather than tracking particles, so it costs the same whether you look
at it for a second or ten minutes.
```

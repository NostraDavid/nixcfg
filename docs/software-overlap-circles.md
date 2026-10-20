# Circles for physical-host software overlap

The question is whether six circles can show the software memberships that occur
on the six physical hosts. A complete six-set Venn diagram is a different and
stronger requirement. Its impossibility does not settle this question.

## Current data

The source is the `software` field in [module-map.json](module-map.json). Each
machine contributes a set of package names. Versions and installation origins do
not create separate memberships. The bit order is `bragi`, `donar`, `frigg`,
`loki`, `mimir2`, `wodan`.

There are 16 nonempty membership groups and 587 distinct package names:

| Mask | Packages | Hosts                                    |
| ---- | -------: | ---------------------------------------- |
| 1    |        2 | bragi                                    |
| 2    |        2 | donar                                    |
| 6    |        7 | donar, frigg                             |
| 8    |       15 | loki                                     |
| 32   |       22 | wodan                                    |
| 34   |       48 | donar, wodan                             |
| 36   |        1 | frigg, wodan                             |
| 37   |        1 | bragi, frigg, wodan                      |
| 38   |      323 | donar, frigg, wodan                      |
| 39   |       85 | bragi, donar, frigg, wodan               |
| 42   |        2 | donar, loki, wodan                       |
| 47   |        4 | bragi, donar, frigg, loki, wodan         |
| 54   |        8 | donar, frigg, mimir2, wodan              |
| 55   |        5 | bragi, donar, frigg, mimir2, wodan       |
| 62   |       28 | donar, frigg, loki, mimir2, wodan        |
| 63   |       34 | bragi, donar, frigg, loki, mimir2, wodan |

These are configured package names, not a measurement of running processes or
every dependency in the Nix closure. Regenerate the source with
`just module-map`.

## What circles need to represent

A full Venn diagram has every inside-or-outside combination. Euler diagrams
allow combinations to be absent. This distinction matters because the software
data has 16 occupied groups, rather than all 63 possible nonempty groups.
[Ruskey and Weston's definition](https://www.combinatorics.org/files/Surveys/ds5/VennWhatEJC.html),
[their Euler-diagram definition](https://www.combinatorics.org/files/Surveys/ds5/ds5v3-2005/VennOtherEJC.html).

Two circles cross at most twice. Adding circle `n` can therefore add at most
`2(n - 1)` faces. Starting with two faces for one circle gives at most
`n(n - 1) + 2` faces, including the exterior. For six circles the bound is 32,
whereas a full six-set Venn diagram needs 64. This counting argument rules out
the full Venn diagram. It does not rule out these 16 groups. The survey uses the
same intersection-counting principle for geometric restrictions.
[Geometric variations](https://www.combinatorics.org/files/Surveys/ds5/VennGeometricEJC.html).

For a particular layout, let each circle's interior represent one host. A group
has a valid location if some open region is inside every included host's circle
and outside every excluded host's circle. A tangency or boundary point is not an
open region and cannot hold a readable label.

Two acceptance criteria must remain distinct:

- Exact Euler topology requires all 16 occupied groups to exist and every other
  nonempty membership group to have no open region. If one group has
  disconnected pieces, that also fails the survey's connected-region Euler
  definition.
- A diagram with explicit empty regions may retain additional geometric groups.
  Every such group must contain zero packages and be visibly marked as empty.
  All occupied groups still need correct locations. An unlabelled extra region
  must not imply that a software combination exists.

The second criterion follows the established use of shading to mark empty
regions. It must not be described as an exact Euler representation.
[Generalizations and extensions](https://www.combinatorics.org/files/Surveys/ds5/ds5v3-2005/VennOtherEJC.html).

## Area accuracy is a separate constraint

Correct membership does not require region areas to match package counts.
Area-proportional circles add that requirement, which can fail even for three
sets. A topology-correct layout can use exact numeric labels and state that
areas do not represent package counts.
[Area-proportional diagrams](https://www.combinatorics.org/files/Surveys/ds5/VennGeometricEJC.html).

Existing software does not certify arbitrary circle layouts. `venn.js` uses
numerical optimization to approximate requested intersections. Its author
documents local minima. A small error or a failed search is therefore not a
proof that the required regions exist or that they are impossible.
[Layout implementation](https://github.com/benfred/venn.js/blob/master/src/layout.js),
[author's algorithm and testing notes](https://www.benfrederickson.com/better-venn-diagrams/).

Aggregate area error is also insufficient for this dataset. Two groups contain
only one package each, so an area fit can look close while losing an entire
occupied group. `eulerr` reports both fitted region values and per-region
errors, which makes those omissions inspectable.
[eulerr reference](https://jolars.github.io/eulerr/reference/euler.html).

## Findings

**Six circles can display all 16 occupied groups with correct numeric labels.**
The construction below is a concrete example. It does not depend on an
optimizer's aggregate area error. Every occupied combination has a verified
interior point.

The coordinates use a Cartesian plane. The preview flips the vertical axis when
drawing SVG:

| Host   | Centre x | Centre y | Radius |
| ------ | -------: | -------: | -----: |
| bragi  |    -0.70 |     0.30 |   0.80 |
| donar  |     0.15 |     0.00 |   1.00 |
| frigg  |    -0.26 |     0.20 |   0.95 |
| loki   |     0.35 |    -0.65 |   0.80 |
| mimir2 |     0.08 |     0.10 |   0.35 |
| wodan  |     0.00 |    -0.15 |   1.05 |

Run the standard-library-only
[verification script](../scripts/check-software-overlap-circles.py):

```sh
python3 scripts/check-software-overlap-circles.py
```

It reads the current module-map software snapshot, deduplicates package names,
and checks every required membership against these six disks. Sampling both
sides of each circle arc between crossings enumerates the represented
combinations. A distance bound keeps each sample from crossing another circle.
The script rejects missing occupied groups, unlabelled combinations, changed
hosts, and label points on the wrong side of a boundary.

The command writes an offline
[interactive preview](../reports/software-overlap-circles/index.html) and
[machine-readable evidence](../reports/software-overlap-circles/proof.json).
Click a numbered marker to inspect its package list.

Measured results for the snapshot above:

- All 16 occupied groups are represented, including both one-package groups.
- Their counts sum to 587 package names, with no duplicated package assignments.
- The seven additional empty combinations are masks `4`, `5`, `7`, `10`, `33`,
  `40`, and `46`. They receive visible zero labels.
- The smallest verified occupied-label clearance from any circle boundary is
  approximately `0.05347` coordinate units. This is a label clearance, not a
  measurement of the smallest region's area.
- Browser checks independently confirmed all 23 label memberships against the
  rendered SVG circles and all counts against the displayed package lists.
- Every occupied marker fits completely within its assigned region. No occupied
  text labels overlap at the inspected desktop viewport.

Some host combinations have disconnected geometric parts. Their count is shown
once per combination; disconnected pieces do not mean additional packages. The
preview states this limitation. Areas are schematic and are not fitted to
counts. This proves feasibility for this snapshot, not for every future set of
software memberships. The verifier must pass again after the data changes.

### Why empty combinations cannot all be removed

A strict Euler drawing with precisely these occupied combinations and no extra
geometric regions is impossible using circles. This is a stronger requirement
than the verified example satisfies.

In the data, every package shared by Loki and Donar is also on Wodan, and every
package shared by Loki and Wodan is also on Donar. Loki also has exclusive
packages, so both intersections are nonempty proper parts of Loki's set. In a
strict Euler drawing, the Donar and Wodan disks would therefore cut out the same
proper part of Loki's disk. Their boundaries would have to share an arc inside
Loki. Distinct circles cannot share an arc: they meet in at most two points.
Coincident circles would instead prohibit the existing Donar-only and Wodan-only
groups. Explicit empty regions avoid this contradiction. The circle-intersection
bound is the one used in the cited geometric survey; the argument here applies
it to the repository's membership table.

The main module map now uses this circle construction. The rendering and the
verification command share the geometry and coverage checks in
[scripts/module_map.py](../scripts/module_map.py). Generation and freshness
checks fail if a changed host list or an occupied combination cannot be
represented. The host configurations are unchanged.

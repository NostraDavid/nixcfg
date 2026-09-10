import os
from pathlib import Path
import subprocess

import fontforge
import psMat


for source in sorted((Path(os.environ["src"]) / "bdf").glob("Tamzen*.bdf")):
    properties = source.read_text().splitlines()
    bounds = next(
        line.split() for line in properties if line.startswith("FONTBOUNDINGBOX ")
    )
    width, height = map(int, bounds[1:3])
    bold = source.stem.endswith("b")
    style = "Bold" if bold else "Regular"
    family = f"{source.stem[:-1]} OTF"
    name = f"{source.stem[:-1]}OTF-{style}"
    sfd = Path(f"{source.stem}.sfd")
    with sfd.open("w") as output:
        subprocess.run(
            ["bdf2sfd", "-f", family, "-p", name, str(source)],
            stdout=output,
            check=True,
        )
    font = fontforge.open(str(sfd))
    font.fullname = f"{family} {style}"
    font.weight = style
    font.os2_weight = 700 if bold else 400
    # bdf2sfd normalizes every cell to 512 x 1024. Restore square pixels.
    scale = 2 * width / height
    for glyph in font.glyphs():
        glyph.transform(psMat.scale(scale, 1))
        glyph.width = round(512 * scale)
    font.selection.all()
    font.removeOverlap()
    font.simplify()
    font.generate(str(Path(os.environ["out"]) / "share/fonts/opentype" / f"{name}.otf"))
    font.close()

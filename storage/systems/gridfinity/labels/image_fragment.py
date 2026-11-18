"""
Adds an ``{image(...)}`` fragment to gflabel, so labels can use arbitrary
pictures as symbols alongside the built-in ``{symbol(...)}`` electronic
symbols (https://github.com/chris-pikul/electronic-symbols).

Usage inside a gflabel spec:

    {image(Head_Torx)}            look up "Head_Torx.*" in the image search dirs
    {image(my_icons/fan.svg)}     explicit path (relative to cwd or this folder)
    {image(fan.png, 100)}         custom threshold (0-255, default 128)
    {image(fan.png, 128, invert)} raise the light pixels instead of the dark ones
                                  (for light-on-dark artwork; a white or
                                  transparent background becomes raised too)

Supported formats:
  * SVG          - imported directly as vector outlines (best quality).
  * PNG/JPG/...  - traced into outlines. Dark pixels become raised, light /
                   transparent pixels are background. Use high-contrast,
                   single-colour artwork; small images are upscaled before
                   tracing so the edges come out smooth.

Importing this module registers the fragment. Run it directly as a drop-in
replacement for the ``gflabel`` command:

    python image_fragment.py predbox -w 5 "{image(Head_Torx)}{8|20}Torx"
"""

from __future__ import annotations

import io
from pathlib import Path

from build123d import BuildSketch, Mode, Polygon, Sketch, add, import_svg
from gflabel.fragments import Fragment, InvalidFragmentSpecification, fragment
from gflabel.options import RenderOptions

HERE = Path(__file__).resolve().parent

# Folders searched (in order) when an image is given by name rather than path.
IMAGE_DIRS = [
    HERE / "symbols",
    HERE / "gridfinity-bin-label-icons-other_files" / "Icon Set PNG",
]

IMAGE_EXTENSIONS = [".svg", ".png", ".jpg", ".jpeg", ".bmp", ".gif", ".webp"]

# Raster images are scaled so their longest side is about this many pixels
# before tracing. Bigger = smoother curves but more triangles in the STL.
TRACE_SIZE = 800
# Polygon simplification tolerance, in pixels of the upscaled image.
TRACE_TOLERANCE = 1.0
# Ignore specks smaller than this fraction of the image area.
MIN_AREA_FRACTION = 0.0005


def find_image(name: str) -> Path:
    """Resolve an image name or path to an existing file."""
    candidates = [Path(name), HERE / name]
    for folder in IMAGE_DIRS:
        candidates.append(folder / name)
        if not Path(name).suffix:
            candidates.extend(folder / (name + ext) for ext in IMAGE_EXTENSIONS)
    for c in candidates:
        if c.is_file():
            return c

    # Fall back to a case-insensitive match on the file stem / name
    wanted = name.lower()
    for folder in IMAGE_DIRS:
        if not folder.is_dir():
            continue
        for f in sorted(folder.iterdir()):
            if f.suffix.lower() in IMAGE_EXTENSIONS and wanted in (
                f.name.lower(),
                f.stem.lower(),
            ):
                return f

    searched = ", ".join(str(d) for d in IMAGE_DIRS)
    raise InvalidFragmentSpecification(
        f"Could not find image '{name}' (looked in cwd, {HERE} and {searched})"
    )


def list_images() -> list[Path]:
    """All images available by name, for discovering what can be used."""
    found = []
    for folder in IMAGE_DIRS:
        if folder.is_dir():
            found.extend(
                f
                for f in sorted(folder.iterdir())
                if f.suffix.lower() in IMAGE_EXTENSIONS
            )
    return found


def _trace_raster(path: Path, threshold: int, invert: bool) -> Sketch:
    """Trace a raster image into a sketch of filled outlines."""
    import cv2
    import numpy as np
    from PIL import Image

    img = Image.open(path)
    # Flatten transparency onto white, so transparent areas are background
    img = img.convert("RGBA")
    background = Image.new("RGBA", img.size, (255, 255, 255, 255))
    gray = Image.alpha_composite(background, img).convert("L")

    # Upscale small images so the traced edges are smooth rather than stepped
    scale = TRACE_SIZE / max(gray.size)
    if scale > 1:
        gray = gray.resize(
            (round(gray.width * scale), round(gray.height * scale)),
            Image.Resampling.BICUBIC,
        )

    pixels = np.asarray(gray)
    mask = pixels >= threshold if invert else pixels < threshold
    mask = mask.astype(np.uint8) * 255
    # Pad so shapes touching the image edge still get closed outlines
    mask = cv2.copyMakeBorder(mask, 2, 2, 2, 2, cv2.BORDER_CONSTANT, value=0)

    # RETR_CCOMP gives a two-level hierarchy: outer boundaries and their holes.
    # Islands inside holes show up as new outer boundaries.
    contours, hierarchy = cv2.findContours(
        mask, cv2.RETR_CCOMP, cv2.CHAIN_APPROX_NONE
    )
    if not contours:
        raise InvalidFragmentSpecification(
            f"Image '{path.name}' has no dark pixels to trace "
            f"(threshold {threshold}{', inverted' if invert else ''})"
        )
    hierarchy = hierarchy[0]
    min_area = MIN_AREA_FRACTION * mask.shape[0] * mask.shape[1]

    def to_points(contour) -> list[tuple[float, float]] | None:
        if cv2.contourArea(contour) < min_area:
            return None
        approx = cv2.approxPolyDP(contour, TRACE_TOLERANCE, True)
        if len(approx) < 3:
            return None
        # Image y runs downwards; flip it so the picture is the right way up
        return [(float(x), float(-y)) for x, y in approx[:, 0, :]]

    pieces: list[Sketch] = []
    for i, contour in enumerate(contours):
        if hierarchy[i][3] != -1:
            continue  # a hole; handled with its parent
        outer = to_points(contour)
        if outer is None:
            continue
        with BuildSketch() as piece:
            Polygon(*outer, align=None)
            child = hierarchy[i][2]
            while child != -1:
                hole = to_points(contours[child])
                if hole is not None:
                    Polygon(*hole, align=None, mode=Mode.SUBTRACT)
                child = hierarchy[child][0]
        pieces.append(piece.sketch)

    if not pieces:
        raise InvalidFragmentSpecification(
            f"Image '{path.name}' produced no shapes large enough to print"
        )
    with BuildSketch() as sketch:
        add(pieces)
    return sketch.sketch


@fragment(
    "image",
    "img",
    examples=["{image(Head_Torx)}", "{image(symbols/fan.svg)}{...}Fans"],
)
class ImageFragment(Fragment):
    """Render an image (SVG, or a high-contrast PNG/JPG that gets traced) as a symbol. Arguments: name or path[, threshold 0-255][, invert]."""

    def __init__(self, name: str, *args: str):
        self.path = find_image(name)
        threshold = 128
        invert = False
        for arg in args:
            if arg.lower() == "invert":
                invert = True
            elif arg.isdigit():
                threshold = int(arg)
            else:
                raise InvalidFragmentSpecification(
                    f"Unknown image fragment argument '{arg}'"
                )

        if self.path.suffix.lower() == ".svg":
            svg_data = io.StringIO(self.path.read_text(encoding="utf-8"))
            with BuildSketch() as sketch:
                # flip_y: SVG y runs downwards, label y runs upwards
                add(import_svg(svg_data, flip_y=True))
            self.shapes = sketch.sketch
        else:
            self.shapes = _trace_raster(self.path, threshold, invert)

    def render(self, height: float, maxsize: float, options: RenderOptions) -> Sketch:
        bb = self.shapes.bounding_box()
        # Scale to the requested height and centre, same as {symbol(...)}
        return self.shapes.translate(-bb.center()).scale(height / bb.size.Y)


if __name__ == "__main__":
    import sys

    from gflabel.cli import run

    if "--list-images" in sys.argv:
        for f in list_images():
            print(f"{f.stem:30} {f}")
        sys.exit(0)
    run()

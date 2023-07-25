# minimal_magnetic_baseplate_bulk.py
from cadquery import cqgi
import cadquery as cq
from pathlib import Path


sizes = [
    (x, y)
    for x in range(1, 6+1)
    for y in range(1, 6+1)
    if x >= y
]

outdir = Path('magnetic_baseplates')
outdir.mkdir(exist_ok=True)


# load the cadquery script
model = cqgi.parse(Path('minimal_magnetic_baseplate.py').read_text())

for x, y in sizes:
    print(f'building {x}x{y} baseplate')
    build_result = model.build(
        build_parameters={
            'x_grid_number': x,
            'y_grid_number': y,
            'export': False,
            'bulk': True,
        },
        build_options={
            'tolerance': 0.99,
            'angularTolerance': 0.5,
        },
    )

    outfile = outdir / f'minimal_magnetic_baseplate_{x}x{y}.stl'

    # test to ensure the process worked.
    if build_result.success:
        # loop through all the shapes returned and export to STL
        results = list(build_result.results)
        assert len(results) == 1
        result = results[0]
        cq.exporters.export(result.shape, str(outfile), tolerance=0.99, angularTolerance=0.5)
    else:
        print(f"BUILD FAILED: {build_result.exception}")

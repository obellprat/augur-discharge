from pysheds.grid import Grid
from sys import argv
from geojson import dump
import fiona
import numpy as np
from os import system

# Rertrieve and load DEM
# ----------------------

demfile = argv[1]
distfile = argv[2]
branchesfile = argv[3]
catchmentfile = argv[4]

grid = Grid.from_raster(demfile)
dem = grid.read_raster(demfile)

# Condition DEM
# ----------------------
# Fill pits in DEM
pit_filled_dem = grid.fill_pits(dem)

# Fill depressions in DEM
flooded_dem = grid.fill_depressions(pit_filled_dem)
    
# Resolve flats in DEM
inflated_dem = grid.resolve_flats(flooded_dem)

# Compute flow directions
# -------------------------------------
dirmap = (64, 128, 1, 2, 4, 8, 16, 32)
fdir = grid.flowdir(inflated_dem, dirmap=dirmap)

# Calculate flow accumulation
# --------------------------
acc = grid.accumulation(fdir, dirmap=dirmap)

# Delineate a catchment
# ---------------------
# Specify pour point
x, y = argv[5], argv[6]

# Snap pour point to high accumulation cell
x_snap, y_snap = grid.snap_to_mask(acc > 1000, (x, y))

# Delineate the catchment
catch = grid.catchment(x=x_snap, y=y_snap, fdir=fdir, dirmap=dirmap, 
                       xytype='coordinate')

# Crop and plot the catchment
# ---------------------------
# Clip the bounding box to the catchment
grid.clip_to(catch)

# Create view
catch_view = grid.view(catch, dtype=np.uint8)

# Create a vector representation of the catchment mask
shapes = grid.polygonize(catch_view)

# Specify schema
schema = {
        'geometry': 'Polygon',
        'properties': {'LABEL': 'float:16'}
}

# Write shapefile
with fiona.open(catchmentfile, 'w',
                driver='ESRI Shapefile',
                crs=grid.crs.srs,
                schema=schema) as c:
    i = 0
    for shape, value in shapes:
        rec = {}
        rec['geometry'] = shape
        rec['properties'] = {'LABEL' : str(value)}
        rec['id'] = str(i)
        c.write(rec)
        i += 1

# Extract river network
# ---------------------
branches = grid.extract_river_network(fdir, acc > 50, dirmap=dirmap)

with open(branchesfile, 'w') as f:
   dump(branches, f)

# Calculate distance to outlet from each cell
# -------------------------------------------
dist = grid.distance_to_outlet(x=x_snap, y=y_snap, fdir=fdir, dirmap=dirmap,
                               xytype='coordinate')

dist_max = np.max(dist[np.isfinite(dist)].astype(int)) * 30

with open(distfile, 'w') as f:
  f.write(str(dist_max))
  f.write('\n')
  f.write(str(x_snap))
  f.write('\n')
  f.write(str(y_snap))


                

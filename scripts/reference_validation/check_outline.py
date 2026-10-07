"""Synthetic support-normalization checks; NumPy/Pillow, no private inputs."""
import numpy as np
from glyph_outline import normalize,interior_level
from outline_core import vertical_edges

shape=np.zeros((115,95));shape[20:90,15:25]=1;shape[50:60,15:75]=1;shape[20:90,65:75]=1
background=np.linspace(55,75,95)[None,:]
for contrast in [65,175]:
    for bright_fraction in [0,.3,.7,1]:
        gain=np.full((1,95),contrast,dtype=float);gain[:,:round(95*bright_fraction)]=175
        source=background+gain*shape
        for method in ['column','global','linear']:
            mask=normalize(source,method)>.5
            # Global normalization intentionally loses dim support in partial highlights.
            if method!='global' or bright_fraction in [0,1]:
                assert np.array_equal(mask,shape.astype(bool)),(contrast,bright_fraction,method)
        assert np.isfinite(interior_level(source))
assert not np.any(normalize(np.full((115,95),60)))
shifted=np.zeros_like(shape);shifted[:-3]=shape[3:]
edges=vertical_edges(shape.T.tolist(),shifted.T.tolist())
assert edges['mean_displacement']==-3 and edges['column_coverage']>0
print('Outline diagnostics: synthetic contrast, partial support, color interpretation, and edge displacement checks passed')

"""Deterministic appearance candidates; parameters are reconstruction choices."""
import math


def progression(position, phase, model, scale=1.0, offset=0.0, softness=1.0, advance=95.0):
    """Phase is elapsed time relative to an explicit interval midpoint / duration.

    Position is relative to the already-shaped source range. No shaping, geometry,
    reference identity, or previous-frame state enters this function.
    """
    if not all(math.isfinite(v) for v in [position,phase,scale,offset,softness,advance]) or scale<=0 or softness<=0 or advance<=0:
        raise ValueError('Finite positive appearance parameters required')
    q=(phase-offset)/scale
    if model=='baseline':return min(1,max(0,(q+.5-position)*advance+.5))
    if model=='spatial':value=.5+(q+.5-position)/softness
    elif model=='temporal':value=.5+q
    else:raise ValueError('Unknown appearance model')
    v=min(1,max(0,value))
    return v*v*(3-2*v)

"""Bounded multiline measurement helpers; no native state semantics are inferred."""
from itertools import combinations
import math
from statistics import mean
from state_core import affine_landmarks


def match_paragraph(bounds, width_ranges, advance_range, height_range=(60,120)):
    """Require one unambiguous ordered paragraph, never silently drop a line.

    Ranges are inspected protocol constraints, not inferred lyric identities.
    Ambiguous or incomplete support is unavailable rather than a best-fit match.
    """
    if not width_ranges or any(lo>hi for lo,hi in [*width_ranges,advance_range,height_range]):
        raise ValueError('Ordered nonempty ranges are required')
    candidates=[]
    for group in combinations(sorted(bounds,key=lambda b:b[1]),len(width_ranges)):
        if not all(lo<=b[2]-b[0]<=hi and height_range[0]<=b[3]-b[1]<=height_range[1]
                   for b,(lo,hi) in zip(group,width_ranges)):continue
        if not all(advance_range[0]<=b[1]-a[1]<=advance_range[1] for a,b in zip(group,group[1:])):continue
        candidates.append(list(group))
    return candidates[0] if len(candidates)==1 else None


def paragraph_geometry(bounds):
    """Keep all line positions and widths in the stability vector."""
    return [v for x,y,r,b in bounds for v in (x,y,r-x)]


def registered_spacing(reference,observed,scale):
    """Evaluate a fixed external spacing ratio; fit only nuisance translation."""
    affine_landmarks(reference,observed) # Validate corresponding support.
    if not math.isfinite(scale) or scale<=0:raise ValueError('Positive finite scale required')
    offset=mean([b-scale*a for a,b in zip(reference,observed)])
    residual=[b-offset-scale*a for a,b in zip(reference,observed)]
    return dict(scale=scale,translation=offset,rmse=math.sqrt(mean([r*r for r in residual])),
                maximum_error=max(map(abs,residual)),residuals=residual)


def common_registration(reference_lines,candidate_lines,radius=5):
    """One translation for all lines; preserve paragraph spacing in mask tests.

    Inputs are sets of pixel coordinates in one paragraph coordinate space.
    Separate line-wise alignment can otherwise conceal incorrect line advance.
    """
    if len(reference_lines)!=len(candidate_lines) or not reference_lines or radius<0:
        raise ValueError('Paired nonempty paragraph lines and nonnegative radius required')
    if any(not s for s in [*reference_lines,*candidate_lines]):raise ValueError('Empty line support')
    best=None
    for dy in range(-radius,radius+1):
        for dx in range(-radius,radius+1):
            intersections=[];unions=[]
            for ref,candidate in zip(reference_lines,candidate_lines):
                moved={(x+dx,y+dy) for x,y in candidate};intersections.append(len(ref&moved));unions.append(len(ref|moved))
            score=sum(intersections)/sum(unions)
            if best is None or score>best['iou']:
                best=dict(dx=dx,dy=dy,iou=score,line_iou=[a/b for a,b in zip(intersections,unions)],
                          at_limit=abs(dx)==radius or abs(dy)==radius)
    return best


def relative_line_shift(early,late):
    """Separate common vertical translation from relative line displacement.

    Inputs are matching vertical landmark summaries. This does not infer native
    baselines, highlighting semantics, or an animation implementation.
    """
    if len(early)!=len(late) or len(early)<2 or any(not math.isfinite(v) for v in early+late):
        raise ValueError('At least two finite paired line landmarks required')
    shifts=[b-a for a,b in zip(early,late)]
    common=mean(shifts)
    return dict(shifts=shifts,common_translation=common,
                relative_to_first=[v-shifts[0] for v in shifts],
                translation_only_rmse=math.sqrt(mean([(v-common)**2 for v in shifts])))

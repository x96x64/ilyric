"""Deterministic selection and registration summaries for typography experiments.

No source text, media, or native implementation assumptions are stored here.
"""
import math


def line_strings(text, metrics):
    """Decode Core Text UTF-16 ranges without confusing code points and offsets."""
    encoded = text.encode('utf-16-le')
    return [encoded[2*m['start']:2*(m['start']+m['length'])].decode('utf-16-le').rstrip()
            for m in metrics]


def geometry_loss(record):
    """Equal per-case mean square width error; incorrect wrapping is ineligible."""
    errors = record['width_error']
    if not record['structure_matches'] or not errors:
        return math.inf
    if any(not math.isfinite(e) for e in errors):
        raise ValueError('Finite geometry errors are required')
    return sum(e*e for e in errors)/len(errors)


def select(records, cases):
    if not cases:
        raise ValueError('At least one fitting case is required')
    candidates = sorted(set.intersection(*(set(records[c]) for c in cases)))
    scored = [(sum(geometry_loss(records[c][p]) for c in cases)/len(cases), p) for p in candidates]
    if not scored or not math.isfinite(min(scored)[0]):
        raise ValueError('No shared candidate preserves all observed line structures')
    loss, parameter = min(scored)
    return {'candidate': parameter, 'case_balanced_width_rmse': math.sqrt(loss),
            'equally_scored_candidates': [p for value,p in scored if abs(value-loss)<1e-12]}


def leave_one_out(records, cases):
    if len(cases) < 2:
        raise ValueError('At least two cases are required for exclusion analysis')
    result = {}
    for omitted in cases:
        fitted = select(records, [c for c in cases if c != omitted])
        loss = geometry_loss(records[omitted][fitted['candidate']])
        result[omitted] = dict(fitted, held_out_width_rmse=math.sqrt(loss) if math.isfinite(loss) else None,
                               held_out_structure_matches=math.isfinite(loss),
            tied_held_out_structure_matches={p: math.isfinite(geometry_loss(records[omitted][p]))
                for p in fitted['equally_scored_candidates']})
    return result


def baseline_fit(baselines):
    """Least-squares intercept/advance from independently registered line proxies."""
    if not baselines or any(not math.isfinite(b) for b in baselines):
        raise ValueError('Finite baseline proxies are required')
    if len(baselines) == 1:
        return {'first_baseline': baselines[0], 'line_advance': None, 'residuals': [0.]}
    center = (len(baselines)-1)/2
    mean = sum(baselines)/len(baselines)
    advance = sum((i-center)*(b-mean) for i,b in enumerate(baselines))/sum((i-center)**2 for i in range(len(baselines)))
    first = mean-center*advance
    return {'first_baseline': first, 'line_advance': advance,
            'residuals': [b-first-i*advance for i,b in enumerate(baselines)]}

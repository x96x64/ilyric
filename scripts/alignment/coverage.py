"""Independent acoustic diagnostics; no acceptance, timing repair, or vocal claim.

Public logic uses only bounded integer intervals and synthetic-testable scores.
Optional audio inference lives in coverage_features.py, outside the renderer.
"""
import math
from .core import AlignmentError, canonical


def intervals(values, duration_us):
    if type(duration_us) is not int or not 0 < duration_us <= 60_000_000:
        raise AlignmentError('Coverage duration must be 1–60000000 integer microseconds')
    if not isinstance(values, list) or len(values) > 6000:
        raise AlignmentError('Coverage interval limit exceeded')
    result = []
    for value in values:
        if not isinstance(value, (list, tuple)) or len(value) != 2:
            raise AlignmentError('Coverage interval requires two boundaries')
        a, b = value
        if type(a) is not int or type(b) is not int or not 0 <= a < b <= duration_us:
            raise AlignmentError('Invalid coverage interval')
        result.append((a, b))
    merged = []
    for a, b in sorted(result):
        if merged and a <= merged[-1][1]:merged[-1] = (merged[-1][0], max(b, merged[-1][1]))
        else:merged.append((a, b))
    return merged


def difference(left, right, duration_us):
    """Half-open interval subtraction, with no inferred boundary precision."""
    left = intervals(left, duration_us); right = intervals(right, duration_us); out = []
    for a, b in left:
        cursor = a
        for c, d in right:
            if d <= cursor:continue
            if c >= b:break
            if c > cursor:out.append([cursor, min(c, b)])
            cursor = max(cursor, d)
            if cursor >= b:break
        if cursor < b:out.append([cursor, b])
    return out


def active_intervals(mask, step_us, duration_us):
    if type(step_us) is not int or step_us not in (10000, 20000) or not isinstance(mask, list) or not 1 <= len(mask) <= 6000 or any(type(x) is not bool for x in mask):
        raise AlignmentError('Unsupported acoustic frame grid')
    if not (len(mask)-1)*step_us < duration_us <= (len(mask)+2)*step_us:
        raise AlignmentError('Acoustic grid and duration disagree')
    result = []; begin = None
    for i, value in enumerate(mask+[False]):
        if value and begin is None:begin = i*step_us
        if not value and begin is not None:
            end = min(i*step_us, duration_us)
            if end > begin:result.append([begin, end])
            begin = None
    return intervals(result, duration_us)


def coverage(activity, estimated, duration_us):
    """Two asymmetric disagreements; gaps alone do not establish wrong words."""
    activity = intervals(activity, duration_us); estimated = intervals(estimated, duration_us)
    outside = difference(activity, estimated, duration_us)
    unsupported = difference(estimated, activity, duration_us)
    length = lambda xs:sum(b-a for a,b in xs)
    a = length(activity); e = length(estimated)
    unexplained = length(outside)/a if a else None
    unsupported_fraction = length(unsupported)/e if e else None
    score = max(unexplained, unsupported_fraction) if a and e else None
    return dict(score=score, unexplained_activity_fraction=unexplained,
                unsupported_estimate_fraction=unsupported_fraction,
                unexplained_activity_us=outside, unsupported_estimate_us=unsupported,
                semantics='Acoustic proxy disagreement; neither vocal identity nor lyric correctness is established')


def lexical_disagreement(supplied, decoded):
    """English audio-only greedy spelling comparison; not replacement lyrics.

    Punctuation/case filtering follows the existing alignment canonicalization.
    No forced path, reference timestamps, language model, or transcript correction.
    """
    if not isinstance(supplied,str) or not isinstance(decoded,str) or len(supplied)>65536 or len(decoded)>6000:
        raise AlignmentError('Lexical input exceeds bounded text limits')
    a = canonical(supplied)[0]; b = canonical(decoded)[0]
    if len(a) > 1500 or len(b) > 3000 or any(not 'a' <= c <= 'z' for c in a+b):
        raise AlignmentError('Lexical diagnostic accepts bounded ASCII English letters only')
    if not a or not b:return None
    row = list(range(len(b)+1))
    for i, c in enumerate(a, 1):
        following = [i]
        for j, d in enumerate(b, 1):following.append(min(following[-1]+1, row[j]+1, row[j-1]+(c!=d)))
        row = following
    return row[-1]/max(len(a),len(b))


def fit_threshold(rows):
    """Development-only high-score flag, preserving observed matched examples."""
    if not rows or any(x.get('role') != 'development' for x in rows):
        raise AlignmentError('Threshold selection accepts development rows only')
    values = [x['score'] for x in rows if x['score'] is not None]
    if any(not math.isfinite(x) or not 0 <= x <= 1 for x in values):raise AlignmentError('Invalid diagnostic score')
    good = [x['score'] for x in rows if x['matched'] and x['score'] is not None]
    bad = [x['score'] for x in rows if not x['matched'] and x['score'] is not None]
    if not good or not bad:raise AlignmentError('Matched and mismatched development scores required')
    above = [x for x in bad if x > max(good)]
    return (min(above)+max(good))/2 if above else 1.0


def flagged(score, threshold):
    if not math.isfinite(threshold) or not 0 <= threshold <= 1:raise AlignmentError('Invalid frozen threshold')
    if score is None:return None  # Unavailable evidence is not a passed check.
    if not math.isfinite(score) or not 0 <= score <= 1:raise AlignmentError('Invalid diagnostic score')
    return score > threshold


def wilson(successes, count):
    if not count:return None
    z = 1.959963984540054; p = successes/count; den = 1+z*z/count
    center = (p+z*z/(2*count))/den
    half = z*math.sqrt(p*(1-p)/count+z*z/(4*count*count))/den
    return [max(0,center-half),min(1,center+half)]


def confusion(rows):
    result = dict(TP=0, FP=0, TN=0, FN=0, unavailable=0)
    for x in rows:
        if x['flag'] is None:result['unavailable'] += 1;continue
        key = ('FP' if x['matched'] else 'TP') if x['flag'] else ('TN' if x['matched'] else 'FN')
        result[key] += 1
    negatives = result['TP']+result['FN']; positives = result['FP']+result['TN']
    result.update(mismatch_recall=result['TP']/negatives if negatives else None,
                  false_rejection_rate=result['FP']/positives if positives else None,
                  recall_wilson95=wilson(result['TP'],negatives), false_rejection_wilson95=wilson(result['FP'],positives))
    return result

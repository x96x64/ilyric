"""Boundary error summaries; annotations are independent inputs, not model constraints."""
import math


def summarize(errors_us):
    values = sorted(abs(x) / 1000 for x in errors_us)
    if not values:
        return {'count': 0, 'median_ms': None, 'p95_ms': None, 'mae_ms': None, 'over_500_ms_fraction': None}
    def percentile(q):
        index = (len(values) - 1) * q
        a = math.floor(index); b = math.ceil(index)
        return values[a] + (values[b] - values[a]) * (index - a)
    return {'count': len(values), 'median_ms': round(percentile(.5), 3),
            'p95_ms': round(percentile(.95), 3), 'mae_ms': round(sum(values) / len(values), 3),
            'maximum_ms': round(max(values), 3),
            'over_500_ms_fraction': round(sum(x > 500 for x in values) / len(values), 6)}

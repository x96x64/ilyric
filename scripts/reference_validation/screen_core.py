"""Small native-coordinate component checks; no source imagery or text."""
def half_open(bounds):
    return [bounds['x'],bounds['y'],bounds['x']+bounds['width'],bounds['y']+bounds['height']]

def compare_components(components,profile):
    parts={p['part']:p for p in components}
    names={'artwork':'artwork_bounds','handle':'handle_bounds','progress':'progress_bounds','volume':'volume_bounds','singExpanded':'expanded_sing_control_bounds'}
    result={}
    for part,name in names.items():
        expected=profile['geometry'][name]
        actual=half_open(parts[part]['bounds'])
        result[part]={'render_layout_bounds':actual,'archived_bounds':expected['value'],
                      'edge_errors':[a-b for a,b in zip(actual,expected['value'])],
                      'reference_uncertainty':expected['uncertainty'],'evidence_status':'constraint comparison against archived measurement; not new physical measurement'}
    return result

def support_status(bounds,window,visible=True):
    """Reject unavailable or window-contaminated support; never infer layout absence."""
    if not visible:return 'not-visible-in-inspected-state'
    if bounds is None:return 'unavailable'
    if bounds[0]<=window[0] or bounds[1]<=window[1] or bounds[2]>=window[2] or bounds[3]>=window[3]:
        return 'unreliable-window-boundary'
    return 'supported-contrast-observation'

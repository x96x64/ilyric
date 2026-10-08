"""Bounded appearance hypotheses; contrast is a diagnostic proxy, not alpha."""
import math

def progression(elapsed, duration):
    if duration <= 0: return float(elapsed >= 0)
    x=max(0.,min(1.,elapsed/duration))
    return x*x*(3-2*x)

def parameters(elapsed, model, blur, inactive, active, duration):
    u=progression(elapsed,duration if model=='interpolated' else 0)
    return (0 if model in ['opacity','existing'] else blur*(1-u),inactive+(active-inactive)*u)

def quadratic_error(terms, gain):
    a,b,c=terms
    return max(0.,a*gain*gain-2*b*gain+c)

def select(records, model):
    # Fixed grid avoids a flexible curve that absorbs geometry or onset errors.
    best=None
    for blur in ([0] if model in ['opacity','existing'] else [4,6,7,8,10]):
      for duration in ([0] if model!='interpolated' else [.05,.10,.15,.25,.35,.45]):
        sums=[[0.,0.] for _ in range(2)]
        # Endpoint estimates only; transition phases cannot determine contrast.
        for r in records:
          if r['elapsed']<-.2: group=0; radius=blur
          elif r['elapsed']>.5: group=1;radius=0
          else: continue
          a,b,_=r['terms'][radius];sums[group][0]+=a;sums[group][1]+=b
        gains=[max(0.,min(1.,b/a)) for a,b in sums]
        if model=='existing': gains[0]=0.38*gains[1]
        candidate=dict(model=model,blur=blur,inactive=gains[0],active=gains[1],duration=duration)
        error=score(records,candidate)
        if best is None or error<best[0]:best=(error,candidate)
    return best[1]

def score(records,candidate,phase=0):
    errors=[]
    for r in records:
        blur,gain=parameters(r['elapsed']+phase,**candidate)
        lo=int(blur);hi=min(lo+1,len(r['terms'])-1);f=blur-lo
        # Interpolate losses, not image pixels; report this grid approximation.
        errors.append((1-f)*quadratic_error(r['terms'][lo],gain)+f*quadratic_error(r['terms'][hi],gain))
    return math.sqrt(sum(errors)/len(errors))

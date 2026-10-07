"""Phase-specific diagnostics for an inspected private multiline protocol.

Called by paragraph_typography after frame extraction. Phase selections are
reviewed observations, not automatic declarations of native activation state.
"""
import json
from fractions import Fraction
from analyze import foreground,ink_bounds
from calibrate import compare,render
from core import registered_mask
from paragraph_core import common_registration,registered_spacing,relative_line_shift
from state_core import affine_landmarks,spacing_holdout


def run(root,out,config,result,cases):
    import numpy as np
    from PIL import Image
    diagnostics={};pairs={}
    for sid,record in config['recordings'].items():
        phases=record['measurement'].get('phase_pts',{})
        if not phases:continue
        observations=result['observations'][sid];by_pts={v['pts']:(i,v) for i,v in enumerate(observations)}
        case=cases[record['measurement']['case']];dy=record['measurement']['crop'][1]
        models={}
        for advance in [127,128]:
            models[str(advance)]=render(root,out,sid,case,f'phase-advance-{advance}',dict(size=103.25,lineAdvance=advance))
        for i,text in enumerate(case.get('alternateTexts',[])):
            models[f'alternate-{i}']=render(root,out,sid,case,f'phase-alternate-{i}',dict(size=103.25),text)
        diagnostics[sid]={}
        for label,pts in phases.items():
            index,row=by_pts[pts];image=Image.open(out/sid/'frames'/f'{index+1:05d}.png');entries={}
            for threshold,floor in [(15,100),(25,80),(25,100),(25,125),(25,145),(35,100)]:
                key=f'{threshold}-{floor}';lines=row['measurements'].get(key)
                if not lines:
                    entries[key]={'status':'unavailable'};continue
                native=[v['bounds'] for v in lines];mask=foreground(image,threshold,floor);comparisons={}
                for name,(metrics,alpha,ink) in models.items():
                    comparison=compare(image,native,alpha,ink,metrics,threshold,floor)
                    for line in comparison['lines']:
                        line['baseline_proxy']+=dy
                        line['origin_translation'][1]+=dy
                    comparison.pop('baseline_fit');comparisons[name]=comparison
                # One common origin; no line-specific registration offsets.
                m,a,b=models['128'];nx,ny,_,_=native[0];cx,cy,_,_=b[0]
                refs=[];cands=[]
                for n,c in zip(native,b):
                    x,y,r,bot=n;yy,xx=np.nonzero(mask[y-6:bot+6,x-6:r+6]);refs.append(set(zip((xx+x-6-nx).tolist(),(yy+y-6-ny).tolist())))
                    x,y,r,bot=c;yy,xx=np.nonzero(a[max(0,y-6):bot+6,max(0,x-6):r+6]);cands.append(set(zip((xx+max(0,x-6)-cx).tolist(),(yy+max(0,y-6)-cy).tolist())))
                glyphs=[]
                for bound,cells in zip(native,record['measurement']['landmark_cells_x']):
                    line_glyphs=[]
                    for lo,hi in zip(cells,cells[1:]):
                        yy,xx=np.nonzero(mask[bound[1]:bound[3],lo:hi])
                        line_glyphs.append(dict(x=float(xx.mean()+lo),y=float(yy.mean()+bound[1]+dy),
                            width=int(xx.max()-xx.min()+1),height=int(yy.max()-yy.min()+1)))
                    glyphs.append(line_glyphs)
                entries[key]=dict(comparisons=comparisons,glyph_geometry=glyphs)
                if key=='25-100':
                    entries[key]['common_origin']=common_registration(refs,cands,5)
                    entries[key]['registration_windows']={str(radius):registered_mask(refs[0],cands[0],radius) for radius in [3,7]}
            diagnostics[sid][label]=dict(pts=pts,measurements=entries)
        diagnostics[sid]['relative_vertical_change']={}
        for key in ['15-100','25-80','25-100','25-125','35-100']:
            before=diagnostics[sid]['first_line_completed']['measurements'][key]
            after=diagnostics[sid]['late']['measurements'][key]
            # Use all observed cells; no glyph is independently shaped or moved.
            a=[sum(g['y'] for g in line)/len(line) for line in before['glyph_geometry']]
            b=[sum(g['y'] for g in line)/len(line) for line in after['glyph_geometry']]
            diagnostics[sid]['relative_vertical_change'][key]=relative_line_shift(a,b)
        early=by_pts[phases['sharp_dim']][1];late=by_pts[phases['late']][1]
        diagnostics[sid]['sharp_spacing']={}
        for key in early['measurements'].keys() & late['measurements'].keys():
            diagnostics[sid]['sharp_spacing'][key]=[affine_landmarks(a['landmarks'],b['landmarks'])
                for a,b in zip(early['measurements'][key],late['measurements'][key])]
        for i,(a,b) in enumerate(zip(early['measurements']['25-100'],late['measurements']['25-100'])):
            pairs.setdefault(str(i),{})[sid]=dict(reference=a['landmarks'],observed=b['landmarks'])
        # State-boundary sensitivity reuses fixed widths; no rendering or refitting of text structure.
        diagnostics[sid]['stability_sensitivity']={}
        base=Fraction(result['metadata'][sid]['video']['time_base'])
        from paragraph_typography import candidate_errors
        from typography_core import select
        for tolerance,runs in result['stability'][sid]['runs'].items():
            for guard in [0,.1,.2]:
                interval=max(runs,key=lambda r:r['duration_seconds']);ticks=int(Fraction(str(guard))/base)
                selected=[v for v in observations if interval['first_pts']+ticks<=v['pts']<=interval['last_pts']-ticks]
                if not selected:continue
                records={}
                for size in [101+i*.25 for i in range(21)]:
                    name=f'size-{size:g}';ink=ink_bounds(np.asarray(Image.open(out/'probes'/sid/name/'text.png'))[:,:,-1]>127)
                    records[name]=candidate_errors(ink,selected,'25-100',len(case['observedLines']))
                diagnostics[sid]['stability_sensitivity'][f'{tolerance}-{guard}']=dict(interval=interval,frames=len(selected),fit=select({sid:records},[sid]))
    return dict(recordings=diagnostics,sharp_spacing_holdout={line:spacing_holdout(p) for line,p in pairs.items()})

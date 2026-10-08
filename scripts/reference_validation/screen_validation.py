"""Private full-screen placement checks. Original screenshots remain unchanged."""
import io,json,subprocess
from pathlib import Path
from analyze import REPO,private_root,safe_path,save
from state_typography import digest
from screen_core import compare_components,support_status

def main():
    root=private_root(REPO/'reference-private');manifest=root/'analysis/manifest.json';binary=REPO/'.build/release/LyricsScreenProbe'
    if not manifest.exists() or not binary.exists():
        print(json.dumps({'status':'unavailable','reason':'Private screenshot inventory or release screen probe absent'}));return
    sources=json.loads(manifest.read_text())['screenshots'];ids=['S02','S03','S04','S05','S07','S09']
    if any(s not in sources or not safe_path(root,root/sources[s]['file']).is_file() for s in ids):
        print(json.dumps({'status':'unavailable','reason':'Required original screenshots absent'}));return
    import numpy as np
    from PIL import Image,ImageCms,ImageDraw
    out=safe_path(root,root/'analysis/full-screen');out.mkdir(exist_ok=True)
    hashes={s:digest(root/sources[s]['file']) for s in ids}
    previous=root/'analysis/latin/current/source-hashes.json'
    if previous.exists():
        for sid,value in json.loads(previous.read_text()).items():
            if sid in hashes and hashes[sid]!=value:raise ValueError('Existing screenshot hash mismatch')
    inventory=out/'source-hashes.json'
    if inventory.exists() and json.loads(inventory.read_text())!=hashes:raise ValueError('Original screenshot changed')
    save(inventory,hashes)
    # Probe output is synthetic and remains in artifacts; reference overlays stay private.
    import tempfile
    synthetic=Path(tempfile.mkdtemp(prefix='screen-',dir=REPO/'artifacts'))/'native.png'
    record=json.loads(subprocess.check_output([str(binary),'native','4','1',str(synthetic)]))
    profile=json.loads((REPO/'docs/reference-data/v1/profile.json').read_text())
    geometry=compare_components(record['components'],profile);observations={}
    rendered=np.asarray(Image.open(synthetic).convert('RGB')).astype(float).mean(2);raster={}
    for name,box in [('title',[352,338,1002,396]),('artist',[352,398,1002,456])]+[(k,v['render_layout_bounds']) for k,v in geometry.items() if k in ['handle','progress','volume']]:
        x0,y0,x1,y1=map(int,box);patch=rendered[y0-6:(y1 if name in ['title','artist'] else y1+6),x0-6:x1+6]
        bg=float(np.median(np.concatenate([patch[:3].ravel(),patch[-3:].ravel()])))
        yy,xx=np.nonzero(patch-bg>12)
        raster[name]=[int(xx.min()+x0-6),int(yy.min()+y0-6),int(xx.max()+x0-5),int(yy.max()+y0-5)] if len(xx) else None
    for sid in ids:
        source=Image.open(root/sources[sid]['file']);assert source.size==(1179,2556)
        image=ImageCms.profileToProfile(source,ImageCms.ImageCmsProfile(io.BytesIO(source.info['icc_profile'])),ImageCms.createProfile('sRGB'),outputMode='RGB')
        a=np.asarray(image).astype(float).mean(2);draw=ImageDraw.Draw(image);observations[sid]={}
        for name in ['handle','progress','volume']:
            x0,y0,x1,y1=map(int,geometry[name]['archived_bounds']);pad=6
            patch=a[y0-pad:y1+pad,x0-pad:x1+pad]
            background=float(np.median(np.concatenate([patch[:3].ravel(),patch[-3:].ravel()])))
            bounds=[]
            for threshold in [8,12,18]:
                yy,xx=np.nonzero(patch-background>threshold)
                bounds.append([int(xx.min()+x0-pad),int(yy.min()+y0-pad),int(xx.max()+x0-pad+1),int(yy.max()+y0-pad+1)] if len(xx) else None)
            observations[sid][name]={'thresholds': [8,12,18],'contrast_bounds':bounds,'support_status':[support_status(b,[x0-pad,y0-pad,x1+pad,y1+pad],sid!='S02' or name=='handle') for b in bounds],'meaning':'color-managed local support; unavailable or partial support is not layout absence'}
        for item in record['components']:
            if item['part']=='background':continue
            b=item['bounds'];draw.rectangle([b['x'],b['y'],b['x']+b['width'],b['y']+b['height']],outline='cyan',width=2)
        image.save(out/(sid+'-overlay.png'))
    if hashes!={s:digest(root/sources[s]['file']) for s in ids}:raise ValueError('Original changed during analysis')
    result={'status':'measured','source_ids':ids,'source_hashes_verified':True,'geometry':geometry,'synthetic_raster_bounds':raster,'support':observations,
            'limitations':['Shared native coordinates; no screenshot-specific registration','Control shapes and metadata content differ intentionally','Viewport boundary and fade remain provisional','S02 lower controls absent; visibility semantics supplied, not inferred']}
    save(out/'results.json',result);print(json.dumps({'status':'measured','sources':ids,'geometry_edge_errors':{k:v['edge_errors'] for k,v in geometry.items()}}))

if __name__=='__main__':main()

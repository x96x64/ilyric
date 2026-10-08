"""Private progressive-appearance calibration; no protected output is published."""
import json
from analyze import REPO, private_root, safe_path
from state_typography import digest


def verify_baseline(expected, actual):
    """Compare archived observation fields; aggregates are derived from those rows."""
    if isinstance(expected,dict):
        for key,value in expected.items():
            if key!='aggregate':
                if key not in actual:raise ValueError('Archived baseline field absent')
                verify_baseline(value,actual[key])
    elif isinstance(expected,list):
        if len(expected)!=len(actual):raise ValueError('Archived baseline count changed')
        for a,b in zip(expected,actual):verify_baseline(a,b)
    elif expected!=actual:raise ValueError('Archived baseline differs; investigate before fitting')


def main():
    root=private_root(REPO/'reference-private')
    paths=[root/'s09-state-cases.json',root/'analysis/s09-state/current/results.json',
           root/'analysis/glyph-outline/current/results.json',root/'analysis/lyrics-slice/current/results.json']
    if not all(p.is_file() for p in paths) or not (REPO/'.build/release/LyricsSliceProbe').is_file():
        print(json.dumps(dict(status='unavailable',reason='Private annotations, baseline diagnostics, or release probe absent')));return
    config,inventory,prior,baseline=[json.loads(safe_path(root,p).read_text()) for p in paths]
    sources=[safe_path(root,root/'recordings'/config['recordings'][s]['file']) for s in ['V09','V10']]
    if not all(p.is_file() for p in sources):
        print(json.dumps(dict(status='unavailable',reason='Private original recordings absent')));return
    def verify():
        for sid,path in zip(['V09','V10'],sources):
            if digest(path)!=inventory['metadata'][sid]['sha256']:raise ValueError('Original recording hash changed')
    verify()
    archive=json.loads((REPO/'docs/reference-data/v6/slice-validation.json').read_text())
    verify_baseline(archive['comparisons'],baseline['comparisons'])
    from appearance_fit import run
    out=safe_path(root,root/'analysis/appearance/current');out.mkdir(parents=True,exist_ok=True)
    result=run(root,out,inventory,prior,baseline)
    from appearance_render import run as render
    render(root,out,inventory,prior,baseline,result)
    verify()
    print(json.dumps(dict(status='measured',source_hashes_verified=True)))

if __name__=='__main__':main()

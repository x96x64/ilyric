"""Public synthetic integration checks for the internal Core Text probe.

Run from the repository root after building ReferenceProbe. All fixture text is
independently supplied for this test. No physical references are required.
"""
import json
from pathlib import Path
import subprocess
from typography_core import line_strings


def main():
    root=Path('artifacts/typography-tests');root.mkdir(parents=True,exist_ok=True)
    binary=Path('.build/release/ReferenceProbe')
    original=dict(text='Quiet light ffi e\u0301 😀\n静かな光と Sample',width=720,size=60,
                  lineAdvance=80,font='system-bold')
    def run(name, **changes):
        value=dict(original,**changes);request=root/'input.json';request.write_text(json.dumps(value))
        out=root/name
        subprocess.run([str(binary),str(request),str(out)],check=True)
        return json.loads((out/'metrics.json').read_text()),(out/'text.png').read_bytes()
    first,pixels=run('first')
    assert len(first['lines'])==2
    assert [l['detail']['breakKind'] for l in first['lines']]==['explicit','end']
    assert line_strings(original['text'],first['lines'])==original['text'].splitlines()
    assert sum(l['length'] for l in first['lines'])==len(original['text'].encode('utf-16-le'))//2
    for index,tick in enumerate([30,0,59,30,1,0]):
        result,image=run(f'time-{index}',numerator=tick,denominator=60)
        assert result['lines']==first['lines'] and image==pixels
    right,_=run('right',alignment='right')
    for left,r in zip(first['lines'],right['lines']):
        assert left['width']==r['width'] and left['detail']['runs']==r['detail']['runs']
        assert abs(r['detail']['originX']+r['width']-original['width'])<1e-9
    spaced,_=run('spacing',lineAdvance=91)
    assert spaced['lines'][0]['baseline']==first['lines'][0]['baseline']
    assert spaced['lines'][1]['baseline']-first['lines'][1]['baseline']==11
    assert spaced['lines'][1]['width']==first['lines'][1]['width']
    auto,_=run('automatic',text='Quiet light under the open sky',width=300)
    assert auto['lines'][0]['detail']['breakKind']=='automatic'
    assert all(l['detail']['breakKind']!='explicit' for l in auto['lines'])
    for index,options in enumerate([dict(fontSelection='emphasized'),dict(language='ja'),
                                    dict(opticalSize='none'),dict(opticalSize='34'),dict(weight=.3)]):
        result,_=run(f'public-api-{index}',**options)
        assert result['status']=='rendered' and result['lines'][0]['detail']['runs']
    for index,bad in enumerate([dict(weight=2),dict(opticalSize='invalid'),dict(alignment='unknown'),dict(fontSelection='unknown')]):
        request=root/'invalid.json';request.write_text(json.dumps(dict(original,**bad)))
        result=subprocess.run([str(binary),str(request),str(root/f'invalid-{index}')],capture_output=True)
        assert result.returncode!=0
    print('Typography probe: synthetic shaping, alignment, spacing, API options, rejection, and random-access checks passed')


if __name__=='__main__':main()

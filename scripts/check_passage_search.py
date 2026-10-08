#!/usr/bin/env python3
"""Original synthetic passage preparation and AV export; no model accuracy claim."""
import json
from pathlib import Path
import subprocess
import sys
from alignment.core import source,digest
from alignment.full_song import review,load,to_ttml
from alignment.passage_search import prepare,search_windows
from generate_local_audio import generate
from validate_local_input import validate


def check(folder):
    folder=Path(folder);folder.mkdir(parents=True,exist_ok=False)
    audio=folder/'source.wav';generate(audio)
    src=source(b'Bright wind\nSoft river\n\nBright wind\nSoft river\n')
    def candidate(name,lines):
        return dict(id=name,agreement=.9,similarity=.9,lines=lines,unresolved=[],window_bounds_us=[0,10003000])
    candidates=[candidate('first',[[625000,1800000],[1810000,3200000]]),
                candidate('second',[[4500000,5500000],[5510000,6950000]])]
    raw=dict(format='ilyric-tifa-candidates-1',source=src,audio=dict(sha256=digest(audio.read_bytes()),duration_us=10003000),
             groups=[candidates,candidates],windows=search_windows(10003000),provenance=dict(model='synthetic-output-no-inference'))
    result=prepare(raw);(folder/'estimated.json').write_text(json.dumps(result,indent=2))
    result=review(result,[dict(line=i,note='Original synthetic fixture review') for i in range(4)])
    result=review(result,[dict(line=1,interval_us=[1810123,3250000],note='Exact synthetic correction')])
    reviewed=folder/'reviewed.json';reviewed.write_text(json.dumps(result,indent=2))
    xml=to_ttml(load(reviewed));assert xml==to_ttml(result)
    ttml=folder/'prepared.ttml';ttml.write_text(xml)
    root=Path(__file__).resolve().parents[1];video=folder/'video.mp4'
    r=subprocess.run([str(root/'.build/release/LyricsInputProbe'),'render','--lyrics',str(ttml),'--audio',str(audio),
                      '--format','ttml','--highlighting','disabled','--output',str(video)],capture_output=True,text=True)
    assert r.returncode==0,r.stderr
    export=json.loads(r.stdout)
    assert export['export']['frames']==601 and export['timed_segments']==0
    assert [(x['numerator']/x['denominator'],x['paragraph']) for x in export['focus_events']]==[(0,-1),(.625,0),(3.25,-1),(4.5,1),(6.95,-1)]
    return dict(status='passed',evidence='Synthetic preparation and export only; no acoustic accuracy claim',
                reloaded_ttml_identical=True,export=export,media=validate(video,audio,601))


if __name__=='__main__':print(json.dumps(check(sys.argv[1]),indent=2))

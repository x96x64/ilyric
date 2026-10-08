#!/usr/bin/env python3
"""Original synthetic correspondence/correction/export check; no acoustic accuracy claim."""
import json
from pathlib import Path
import subprocess
import sys
from alignment.audio_anchors import match, review_artifact
from alignment.core import source
from alignment.full_song import load, review, to_ttml
from alignment.worker import file_hash
from generate_local_audio import generate
from validate_local_input import validate


def check(folder):
    folder=Path(folder);folder.mkdir(parents=True,exist_ok=False)
    root=Path(__file__).resolve().parents[1];fixture=root/'fixtures/audio-anchors'
    audio=folder/'source.wav';generate(audio,rate=48000)
    evidence=json.loads((fixture/'anchors.json').read_text())
    evidence['audio']['sha256']=file_hash(audio)
    result=match(source((fixture/'lyrics.txt').read_bytes()),evidence)
    assert all(d['state']=='supported' for d in result['decisions'])
    (folder/'correspondence.json').write_text(json.dumps(result,indent=2)+'\n')
    prepared=review_artifact(result)
    assert all(r['estimate'] is None for r in prepared['lines'])
    intervals=[[1000123,1800000],[2100000,2900000],[6000000,6800000],[7100000,7900000]]
    fixed=review(prepared,[dict(line=i,interval_us=v,note='Original synthetic correction; no human acoustic annotation') for i,v in enumerate(intervals)])
    path=folder/'reviewed.json';path.write_text(json.dumps(fixed,indent=2)+'\n')
    ttml=folder/'prepared.ttml';ttml.write_text(to_ttml(load(path)))
    assert '1.000123s' in ttml.read_text()
    output=folder/'video.mp4'
    run=subprocess.run([str(root/'.build/release/LyricsInputProbe'),'render','--lyrics',str(ttml),'--format','ttml',
                        '--highlighting','disabled','--audio',str(audio),'--output',str(output)],capture_output=True,text=True)
    if run.returncode:raise RuntimeError(run.stderr)
    report=json.loads(run.stdout);assert report['export']['frames']==601
    return dict(status='passed',classification='Synthetic software correctness, not model inference or singing accuracy',
                supported_coarse_regions=4,automatic_timing_estimates=0,synthetic_corrections=4,
                correction_reuse_without_models=True,export=report,media=validate(output,audio,601))


if __name__=='__main__':print(json.dumps(check(sys.argv[1]),indent=2))

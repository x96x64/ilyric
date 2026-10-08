#!/usr/bin/env python3
"""Original 75-second software integration proof; synthetic scores, not singing accuracy."""
import json
from pathlib import Path
import subprocess
import sys
from alignment.core import source
from alignment.worker import file_hash
from alignment.full_song import artifact,windows,text_targets,path,proposals,review,to_ttml,load
from generate_local_audio import generate
from validate_local_input import validate as validate_media


def check(folder):
    folder=Path(folder);folder.mkdir(parents=True,exist_ok=False)
    root=Path(__file__).resolve().parents[1];src=source((root/'fixtures/full-song/lyrics.txt').read_bytes())
    audio=folder/'source.wav';generate(audio,seconds=75.003)
    rows,tokens,owners=text_targets(src);vocab={c:i+1 for i,c in enumerate(sorted(set(tokens)))};vocab['']=0
    emissions=[[0.]+[-9.]*(len(vocab)-1) for _ in range(3750)]
    cursor=300;last=0
    for token,owner in zip(tokens,owners):
        if owner is not None and owner!=last:cursor=max(cursor,300+owner*400);last=owner
        score=[-9.]*len(vocab);score[vocab[token]]=0.
        emissions[cursor]=score.copy();emissions[cursor+1]=score.copy();cursor+=3
    spans=path(emissions,[vocab[c] for c in tokens]);duration=75003000
    rows=proposals(src,duration,emissions,tokens,owners,spans,vocab)
    result=artifact(src,file_hash(audio),duration,dict(id='synthetic-scores-not-model-inference',model_grid_us=20000),windows(1200048),rows)
    estimated=folder/'estimated.json';estimated.write_text(json.dumps(result,indent=2))
    assert all(r['estimate'] is not None for r in result['lines'])
    decisions=[dict(line=r['id'],note='Synthetic software check, not human acoustic review') for r in rows]
    result=review(load(estimated),decisions)
    bounds=result['lines'][0]['estimate'].copy();bounds[0]+=123
    result=review(result,[dict(line=0,interval_us=bounds,note='Synthetic non-frame correction')])
    reviewed=folder/'reviewed.json';reviewed.write_text(json.dumps(result,indent=2))
    ttml=folder/'prepared.ttml';ttml.write_text(to_ttml(load(reviewed)))
    output=folder/'video.mp4'
    process=subprocess.run([str(root/'.build/release/LyricsInputProbe'),'render','--lyrics',str(ttml),'--audio',str(audio),
                            '--format','ttml','--highlighting','disabled','--output',str(output)],capture_output=True,text=True)
    assert process.returncode==0,process.stderr
    exported=json.loads(process.stdout);assert exported['export']['frames']==4501
    assert exported['final_focus']==-1 and exported['paragraphs']==4
    expected=[]
    for p in range(4):
        first,last=result['lines'][p*2:p*2+2]
        expected.extend([(first['correction']['interval_us'][0] if first['correction'] else first['estimate'][0],p),
                         (last['estimate'][1],-1)])
    actual=[(round(x['numerator']*1000000/x['denominator']),x['paragraph']) for x in exported['focus_events']]
    assert actual==[(0,-1)]+expected
    return dict(status='passed',classification='Synthetic software correctness only',
                inference='deterministic synthetic scores, no model',occurrences=len(rows),export=exported,
                media=validate_media(output,audio,4501),corrections_reloaded_without_inference=True)


if __name__=='__main__':print(json.dumps(check(sys.argv[1]),indent=2))

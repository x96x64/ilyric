#!/usr/bin/env python3
"""Score prepared proposals against private supplied line annotations; emit no text.

This compares acoustic timing annotations, not vocal-activity ground truth.
It never changes proposals, selects thresholds, or records human review.
"""
import argparse
import json
from pathlib import Path
import statistics
from alignment.core import AlignmentError
from alignment.full_song import load
from alignment.worker import Unavailable,file_hash


def errors(values):
    if not values:return dict(n=0)
    absolute=sorted(abs(x) for x in values)
    def quantile(p):
        at=(len(absolute)-1)*p;low=int(at);high=min(len(absolute)-1,low+1)
        return absolute[low]+(absolute[high]-absolute[low])*(at-low)
    return dict(n=len(values),median_absolute_ms=statistics.median(absolute),p95_absolute_ms=quantile(.95),
                maximum_absolute_ms=absolute[-1],over_500_ms=sum(x>500 for x in absolute))


def score(result, reference):
    if len(reference)!=len(result['lines']):raise AlignmentError('Reference occurrence count differs')
    all_errors=[[],[]];supported=[[],[]];nonoverlap=wrong_repeat=0;flags={};missing=0
    for i,(row,ref) in enumerate(zip(result['lines'],reference)):
        if row['text']!=ref['text']:raise AlignmentError('Reference source text/order differs')
        a,b=ref['interval_us']
        if type(a) is not int or type(b) is not int or not 0<=a<b<=result['audio']['duration_us']:
            raise AlignmentError('Reference interval invalid')
        for f in row['flags']:flags[f]=flags.get(f,0)+1
        if row['proposal'] is None:missing+=1;continue
        x,y=row['proposal']
        for j,value in enumerate([(x-a)/1000,(y-b)/1000]):
            all_errors[j].append(value)
            if row['estimate'] is not None:supported[j].append(value)
        nonoverlap+=min(y,b)<=max(x,a)
        if min(y,b)<=max(x,a) and any(j!=i and other['text']==ref['text'] and min(y,other['interval_us'][1])>max(x,other['interval_us'][0]) for j,other in enumerate(reference)):
            wrong_repeat+=1
    return dict(occurrences=len(reference),raw_proposals=len(reference)-missing,
                estimated=sum(r['estimate'] is not None for r in result['lines']),
                unresolved=sum(r['estimate'] is None for r in result['lines']),flags=flags,
                raw_onset=errors(all_errors[0]),raw_offset=errors(all_errors[1]),
                supported_onset=errors(supported[0]),supported_offset=errors(supported[1]),
                proposals_without_reference_overlap=nonoverlap,wrong_repeated_reference_overlap=wrong_repeat,
                interpretation='Temporal reference-overlap conflicts, not independently verified lexical mismatches; supported is not accepted')


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('manifest',type=Path);a=p.parse_args()
    try:
        if not a.manifest.is_file():raise Unavailable('Private full-song reference manifest unavailable')
        if a.manifest.stat().st_size>2*1024*1024:raise AlignmentError('Reference manifest exceeds 2 MiB')
        rows=json.loads(a.manifest.read_text());out=[]
        if not isinstance(rows,list) or len(rows)>10:raise AlignmentError('At most ten evaluation cases')
        for row in rows:
            result=load(a.manifest.parent/row['artifact'])
            out.append(dict(case=row['id'],audio_sha256=result['audio']['sha256'],source_sha256=result['source']['sha256'],
                            duration_us=result['audio']['duration_us'],windows=len(result['windows']),
                            metrics=score(result,row['lines']),performance=result.get('measurements',{})))
        print(json.dumps(dict(status='measured',reference_manifest_sha256=file_hash(a.manifest),cases=out),indent=2));return 0
    except Unavailable as e:print(json.dumps(dict(status='unavailable',reason=str(e))));return 3
    except (AlignmentError,OSError,ValueError,TypeError,KeyError) as e:p.exit(2,'Full-song evaluation failed: '+str(e)+'\n')


if __name__=='__main__':raise SystemExit(main())

#!/usr/bin/env python3
"""Optional synthetic compatibility checks. Missing local assets are unavailable, not a pass."""
import argparse
import json
from pathlib import Path
import sys
from alignment.worker import Unavailable
from alignment.veracity import RATE, postprocess
from veracity_features import dependencies, load_network, predict, resample_legacy


def check(checkpoint, filter_path):
    if not checkpoint.is_file() or not filter_path.is_file():raise Unavailable('Optional local veracity assets unavailable')
    torch,ta,np,sf=dependencies()
    torch.set_num_threads(4);torch.manual_seed(0);torch.use_deterministic_algorithms(True)
    net=load_network(checkpoint,torch)
    rows=[]
    for rate in [22050,44100,48000]:
        for name in ['silence','impulse','tone','noise']:
            x=np.zeros(rate*2+13,dtype=np.float32)
            if name=='impulse':x[rate//2]=1
            if name=='tone':x=(.2*np.sin(2*np.pi*440*np.arange(len(x))/rate)).astype(np.float32)
            if name=='noise':x=np.random.default_rng(100).normal(0,.03,len(x)).astype(np.float32)
            y=resample_legacy(x,rate,filter_path,np)
            assert np.array_equal(y,resample_legacy(x,rate,filter_path,np))
            t=torch.from_numpy(y)
            spec=ta.transforms.Spectrogram(n_fft=1024,hop_length=315,power=1.)(t).T
            # Independent NumPy FFT reference for centered periodic-Hann magnitude.
            padded=np.pad(y,(512,512),mode='reflect')
            windows=np.lib.stride_tricks.sliding_window_view(padded,1024)[::315]
            reference=abs(np.fft.rfft(windows*torch.hann_window(1024).numpy(),axis=1))
            error=float(np.max(abs(spec.numpy()-reference)))
            assert error < 1e-5,(name,rate,error)
            raw=predict(net,spec,torch)
            pad=torch.zeros((57,513))
            with torch.inference_mode():full=net.probabilities(torch.cat((pad,spec,pad))[None,None])
            delta=float(torch.max(abs(raw-full)))
            assert delta < 1e-6,(name,rate,delta)
            assert torch.equal(raw,predict(net,spec,torch))
            # Reproduce upstream MedianPool directly, independent of stdlib implementation.
            smooth=torch.nn.functional.pad(raw[None,None,None],(28,27,0,0),mode='replicate').unfold(3,56,1).kthvalue(29,dim=-1).values.flatten()
            result=postprocess(raw.tolist(),len(y));assert result['filtered_scores']==smooth.tolist()
            rows.append(dict(signal=name,original_rate=rate,samples=len(y),stft_max_absolute_error=error,
                             chunk_full_max_score_error=delta,repeat_equal=True,median_equal=True,
                             active_fraction=sum(b-a for a,b in result["intervals_samples"])/len(y),
                             score_min=float(raw.min()),score_max=float(raw.max())))
    return dict(status='passed',cases=rows,scope='Synthetic preprocessing and inference compatibility; not singing accuracy')


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--checkpoint',type=Path,required=True);p.add_argument('--filter',type=Path,required=True)
    a=p.parse_args()
    try:print(json.dumps(check(a.checkpoint,a.filter),indent=2));return 0
    except Unavailable as e:print(json.dumps(dict(status='unavailable',reason=str(e))));return 3

if __name__=='__main__':raise SystemExit(main())

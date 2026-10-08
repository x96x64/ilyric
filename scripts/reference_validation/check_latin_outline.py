"""Redistributable mask controls for bounded outline registration."""
import json
import numpy as np
from PIL import Image,ImageFilter
from latin_outline_core import register_profile
from latin_outline import normalize

def main():
 mask=np.zeros((124,100));mask[25:90,20:35]=1;mask[25:40,20:80]=1;mask[60:75,20:70]=1
 ref=mask.mean(1)
 for shift in [-7,0,6]:
  search=np.pad(mask,((14+shift,14-shift),(0,0)))
  result=register_profile(ref,search.mean(1),14)
  assert result['status']=='measured' and result['shift']==shift
 assert register_profile(ref,np.zeros(152),14)['status']=='unavailable'
 assert register_profile(ref,np.pad(mask,((28,0),(0,0))).mean(1),14)['status']=='unavailable'
 for blur in [0,2,4,6]:
  a=np.asarray(Image.fromarray((np.pad(mask,((14,14),(0,0)))*255).astype('uint8')).filter(ImageFilter.GaussianBlur(blur)))/255
  control=40+a*np.linspace(50,180,100)
  r=register_profile(ref,(normalize(control)>.5).mean(1),14)
  assert r['status']=='measured' and abs(r['shift'])<=2
 print(json.dumps(dict(status='passed',translation='recovered',missing_support='unavailable',appearance_only_bias='bounded synthetic control')))

if __name__=='__main__':main()

"""Picks the face-login threshold for assets/models/mobilefacenet.tflite.

Runs the LFW test pairs (sklearn download) through the same crop rule as
lib/features/face_login/data/face_embedder.dart and prints, per cosine
threshold, how often the same person and a stranger would be let in.

Usage: python calibrate_face_threshold.py <work_dir with facemodel/mobilefacenet.tflite>

Result (2026-10-28, 985 of 1000 pairs had a detectable face):
  same mean 0.625  diff mean 0.031
  th 0.40  accept same 88.9%  accept stranger 0.8%
  th 0.45  accept same 85.1%  accept stranger 0.4%
  th 0.50  accept same 80.2%  accept stranger 0.2%
  th 0.55  accept same 74.7%  accept stranger 0.0%
  th 0.60  accept same 66.7%  accept stranger 0.0%
  th 0.65  accept same 54.5%  accept stranger 0.0%
  th 0.70  accept same 38.6%  accept stranger 0.0%
"""
import sys, numpy as np, cv2
from sklearn.datasets import fetch_lfw_pairs
import tensorflow as tf; Interpreter=tf.lite.Interpreter
S=sys.argv[1]
it=Interpreter(model_path=f'{S}/facemodel/mobilefacenet.tflite'); it.allocate_tensors()
inp=it.get_input_details()[0]['index']; out=it.get_output_details()[0]['index']
casc=cv2.CascadeClassifier(cv2.data.haarcascades+'haarcascade_frontalface_default.xml')
def emb(img):
    img=(img*255 if img.max()<=1.0 else img).astype(np.uint8)
    g=cv2.cvtColor(img,cv2.COLOR_RGB2GRAY)
    f=casc.detectMultiScale(g,1.1,5,minSize=(60,60))
    if len(f)==0: return None
    x,y,w,h=max(f,key=lambda r:r[2]*r[3])
    # same crop rule as the app: box + 10% margin, square
    c=max(w,h)*1.2; cx,cy=x+w/2,y+h/2
    x0,y0=int(max(0,cx-c/2)),int(max(0,cy-c/2)); x1,y1=int(min(img.shape[1],cx+c/2)),int(min(img.shape[0],cy+c/2))
    crop=cv2.resize(img[y0:y1,x0:x1],(112,112),interpolation=cv2.INTER_LINEAR).astype(np.float32)
    it.set_tensor(inp,((crop-127.5)/128.0)[None]); it.invoke(); e=it.get_tensor(out)[0]
    return e/np.linalg.norm(e)
d=fetch_lfw_pairs(subset='test',color=True,slice_=None,resize=1.0,data_home=f'{S}/lfw')
sims=[];lab=[]
for (a,b),t in zip(d.pairs,d.target):
    ea,eb=emb(a),emb(b)
    if ea is None or eb is None: continue
    sims.append(float(ea@eb)); lab.append(int(t))
sims=np.array(sims); lab=np.array(lab)
print('pairs used',len(sims),'of',len(d.target))
same,diff=sims[lab==1],sims[lab==0]
print('same mean %.3f  diff mean %.3f'%(same.mean(),diff.mean()))
for th in [0.4,0.45,0.5,0.55,0.6,0.65,0.7]:
    print('th %.2f  accept same %.1f%%  accept stranger %.1f%%'%(th,100*(same>=th).mean(),100*(diff>=th).mean()))

import sys, json, numpy as np
from PIL import Image
# shade3.py DIR... : grass (A, blades) vs original ground (C, grass layer off) on the SAME pixels, blade pixels only
# (|A-B| > 12, wizard box excluded). Shadow/sun split = Otsu on C luminance over those pixels, with a margin.
def otsu(x):
    h,e=np.histogram(x,256,(0,256)); p=h/h.sum(); c=(e[:-1]+e[1:])/2
    w=np.cumsum(p); m=np.cumsum(p*c); mt=m[-1]
    s=(mt*w-m)**2/(w*(1-w)+1e-9); return c[np.argmax(s)]
for d in sys.argv[1:]:
  for v in ['shade_a','shade_b']:
    L=lambda s: np.asarray(Image.open(f'{d}/{v}_{s}.png').convert('RGB')).astype(float)
    A,B,C=L('A'),L('B'),L('C')
    g=np.abs(A-B).sum(2)>12
    x0,y0,x1,y1=json.load(open(f'{d}/bench.json'))['shots'][v]['wizard_box']
    px,py=0.1*(x1-x0),0.1*(y1-y0); g[max(0,int(y0-py)):int(y1+py)+1, max(0,int(x0-px)):int(x1+px)+1]=False
    LC=C.mean(2); g&=LC>60  # drop dark props (shadows here are ambient-lit, never this dark)
    t=otsu(LC[g])
    out=[]
    for nm,m in [('shadow',g&(LC<0.9*t)),('sun',g&(LC>1.1*t))]:
      a=A[m].mean(0); c=C[m].mean(0)
      out.append('%s px=%d grass #%02x%02x%02x ground #%02x%02x%02x dist=%.1f' % ((nm,m.sum())+tuple(a.astype(int))+tuple(c.astype(int))+(np.linalg.norm(a-c),)))
    print('%-18s %s %s' % (d.split('/')[-1], v, ' | '.join(out)))

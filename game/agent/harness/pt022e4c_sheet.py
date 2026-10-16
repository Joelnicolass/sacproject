import sys
from PIL import Image
# usage: sheet.py out.png cols scale files...
out,cols,scale=sys.argv[1],int(sys.argv[2]),float(sys.argv[3])
ims=[Image.open(f).convert('RGB') for f in sys.argv[4:]]
w,h=int(ims[0].width*scale),int(ims[0].height*scale)
rows=(len(ims)+cols-1)//cols
s=Image.new('RGB',(w*cols,h*rows))
for i,im in enumerate(ims): s.paste(im.resize((w,h),Image.LANCZOS),((i%cols)*w,(i//cols)*h))
s.save(out)

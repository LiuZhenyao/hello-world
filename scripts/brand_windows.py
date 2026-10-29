"""Replace the six icon resources of the official Godot 4.6.3 x64 template.
Only resource payloads and their sizes change; code and embedded PCK stay put.
Requires Pillow (build-time only).
"""
import io, math, struct, sys
from pathlib import Path
from PIL import Image, ImageDraw

def brand(path):
    path=Path(path);b=bytearray(path.read_bytes());footer=bytes(b[-16:])
    assert b[:2]==b'MZ'
    pe=struct.unpack_from('<I',b,60)[0];assert b[pe:pe+4]==b'PE\0\0'
    n=struct.unpack_from('<H',b,pe+6)[0];opt_size=struct.unpack_from('<H',b,pe+20)[0];o=pe+24
    assert struct.unpack_from('<H',b,o)[0]==0x20b
    rva=struct.unpack_from('<I',b,o+128)[0];sections=[]
    for j in range(n):
        vs,vr,rs,rp=struct.unpack_from('<IIII',b,o+opt_size+40*j+8)
        sections.append((vr,max(vs,rs),rp))
    def offset(r):
        for start,size,pointer in sections:
            if start<=r<start+size:return pointer+r-start
        raise ValueError('Unmapped resource RVA')
    base=offset(rva);resources={}
    def walk(d,parts):
        nn,ni=struct.unpack_from('<HH',b,base+d+12)
        for j in range(nn+ni):
            name,ptr=struct.unpack_from('<II',b,base+d+16+8*j)
            if name&0x80000000:
                at=base+(name&0x7fffffff);length=struct.unpack_from('<H',b,at)[0]
                name=bytes(b[at+2:at+2+length*2]).decode('utf-16le')
            if ptr&0x80000000:walk(ptr&0x7fffffff,parts+[name])
            else:
                entry=base+ptr;dr,size=struct.unpack_from('<II',b,entry)
                resources[tuple(parts+[name])]=(offset(dr),size,entry)
    walk(0,[])
    image=Image.new('RGBA',(1024,1024),(0,0,0,0));draw=ImageDraw.Draw(image)
    draw.rounded_rectangle((0,0,1023,1023),radius=224,fill='#101e38')
    draw.ellipse((320,320,704,704),fill='#2461a7');pts=[]
    for j in range(361):
        a=math.radians(j);x=412*math.cos(a);y=236*math.sin(a);r=math.radians(-35)
        pts.append((512+x*math.cos(r)-y*math.sin(r),512+x*math.sin(r)+y*math.cos(r)))
    draw.line(pts,fill='#55dcc0',width=36);draw.line((256,736,824,288),fill='#55dcc0',width=16)
    draw.ellipse((764,228,884,348),fill='white');changed=0
    for key,(at,_,_) in resources.items():
        if key[0]!=14:continue
        count=struct.unpack_from('<H',b,at+4)[0]
        for j in range(count):
            ent=at+6+j*14
            w,h,_,_,_,_,_,rid=struct.unpack_from('<BBBBHHIH',b,ent)
            stream=io.BytesIO();image.resize((w or 256,h or 256),Image.Resampling.LANCZOS).save(stream,format='PNG',optimize=True)
            data=stream.getvalue();dest,capacity,entry=resources[(3,rid,key[-1])]
            if len(data)>capacity:raise RuntimeError('Icon exceeds template resource slot')
            b[dest:dest+capacity]=data+b'\0'*(capacity-len(data))
            struct.pack_into('<I',b,entry+4,len(data));struct.pack_into('<HHI',b,ent+4,1,32,len(data));changed+=1
    assert changed==6 and bytes(b[-16:])==footer
    struct.pack_into('<I',b,o+64,0)
    path.write_bytes(b);print('Windows icon resources branded:',changed)
if __name__=='__main__':brand(sys.argv[1])

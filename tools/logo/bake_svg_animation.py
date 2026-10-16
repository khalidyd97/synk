import copy, math, pathlib, re, xml.etree.ElementTree as ET
ROOT=pathlib.Path(__file__).resolve().parents[2]
NS='{http://www.w3.org/2000/svg}'
ET.register_namespace('',NS[1:-1])
svg_path=ROOT/'assets/brand/logo.svg'
svg_text=re.sub(r'&(?!#?\w+;)', '&amp;', svg_path.read_text(encoding='utf-8'))
svg_path.write_text(svg_text,encoding='utf-8')
source=ET.fromstring(svg_text)
for parent in source.iter():
    for child in list(parent):
        if child.tag in (NS+'style',NS+'animate'): parent.remove(child)
source.set('width','512'); source.set('height','182')
out=ROOT/'.tools/logo_svg_frames'; out.mkdir(exist_ok=True)
def wave(t,cycles,phase=0): return .5-.5*math.cos(2*math.pi*(t*cycles+phase))
for frame in range(450):
    t=frame/450
    svg=copy.deepcopy(source)
    for e in svg.iter():
        cls=e.get('class','')
        if cls=='beat-reactor':
            e.set('transform','translate(0 0)')
        if 'eq-bar' in cls:
            idx=int(cls[-1]); h=float(e.get('height')); y=float(e.get('y'))
            s=.2+1.1*wave(t,12+idx*2,idx*.13)
            e.set('transform',f'translate(0 {y+h}) scale(1 {s}) translate(0 {-y-h})')
            e.set('opacity',str(.4+.6*s/1.3))
        if cls=='neon-glow-layer':
            e.set('opacity',str(.65+.35*wave(t,4)))
            e.set('filter','url(#neonGlow)')
        if cls=='energy-trace':
            e.set('stroke-dasharray','180 650'); e.set('stroke-dashoffset',str(830*(1-(t*3)%1)))
        if cls.startswith('cyber-glitch'):
            pink=cls.endswith('magenta'); p=(t*2)%1
            glitch=math.sin(p*math.pi*90)*7 if .88<p<.95 else 0
            x=(-10 if pink else 8)+glitch
            e.set('transform',f'translate({x} {10 if pink else -7})')
            e.set('opacity','.85' if pink else '.45')
        if cls.startswith('led-'):
            idx=int(cls[-1]); e.set('opacity','.95' if wave(t,14+idx*2,idx*.15)>.5 else '.15')
        if cls.startswith('particle-float'):
            left=cls.endswith('left'); w=wave(t,3 if left else 4)
            x=(-14 if left else 14)*w; y=(-12 if left else -10)*w
            e.set('transform',f'translate({x} {y})'); e.set('opacity',str(.45+.55*w))
        if e.get('id')=='glassShine':
            p=(t*2)%1; e.set('x1',f'{-60+200*p}%'); e.set('x2',f'{-20+200*p}%')
        if e.get('id')=='neonBorder':
            colors=[(0,242,254),(255,0,160),(122,40,255)]
            for idx,stop in enumerate(e):
                p=(t+idx/3)*3; k=int(p)%3; f=p%1
                a,b=colors[k],colors[(k+1)%3]
                stop.set('stop-color','#'+''.join(f'{round(a[j]*(1-f)+b[j]*f):02x}' for j in range(3)))
    # CSS classes have already been evaluated for this frame.
    for e in svg.iter(): e.attrib.pop('class',None)
    (out/f'{frame:03}.svg').write_text(ET.tostring(svg,encoding='unicode'),encoding='utf-8')

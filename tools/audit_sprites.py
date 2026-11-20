"""Audit live sprite references, sequence numbering and unchanged image bytes."""
from pathlib import Path
from collections import defaultdict
import hashlib,json,re,sys
ROOT=Path(__file__).resolve().parents[1]

def audit():
    paths=[p for root in ['art/themes','assets'] for p in (ROOT/root).rglob('*') if p.suffix.lower() in ['.png','.json']]
    suffixes=defaultdict(list)
    for p in paths:
        parts=p.relative_to(ROOT).parts
        for i in range(len(parts)):suffixes['/'.join(parts[i:])].append(p)
    def resolve(value,owner):
        candidates=[ROOT/value[6:]] if value.startswith('res://') else [owner.parent/value,ROOT/value]
        for p in candidates:
            if p.is_file():return p.resolve()
        found=suffixes.get(value,[])
        return found[0] if len(found)==1 else None
    visited=set();used=set();missing=[]
    pending=list((ROOT/'art/themes').glob('*/sets/*.json'))+[ROOT/'assets/themes/themes.json']
    for p in (ROOT/'scripts').rglob('*.gd'):
        for value in re.findall(r'[\"\']([^\"\'\n]+\.(?:png|json))[\"\']',p.read_text()):
            if '%' in value or '*' in value or value.startswith(('user://','/tmp/')) or len(value)<=5:continue
            target=resolve(value,p)
            if target:
                if target.suffix=='.png':used.add(target)
                else:pending.append(target)
            elif value.startswith(('res://','artwork/')):missing.append({'owner':str(p.relative_to(ROOT)),'path':value})
    # Generated runtime paths, checked explicitly rather than mistaken for dead files.
    for p in paths:
        if '/watersheds/' in str(p) or '/shoreline_plants/' in str(p) or '/trees/' in str(p) or '_steam_color0_' in p.name:used.add(p) if p.suffix=='.png' else None
    def walk(data,owner,trail=''):
        if isinstance(data,dict):
            for key,value in data.items():
                if key in ['authoring','provenance','source_asset']:continue
                walk(value,owner,trail+'/'+key)
        elif isinstance(data,list):
            for i,value in enumerate(data):walk(value,owner,trail+'/'+str(i))
        elif isinstance(data,str) and data.endswith(('.png','.json')) and not data.startswith(('http://','https://')):
            target=resolve(data,owner)
            if target:
                if target.suffix=='.png':used.add(target)
                else:pending.append(target)
            elif not '%' in data:missing.append({'owner':str(owner.relative_to(ROOT)),'field':trail,'path':data})
    while pending:
        p=pending.pop().resolve()
        if p in visited:continue
        visited.add(p)
        walk(json.loads(p.read_text()),p)
    errors=[];groups=defaultdict(set);animations=defaultdict(lambda:defaultdict(set))
    for p in paths:
        if p.suffix!='.png':continue
        frame=re.match(r'(.+_color\d+)_(\d+)_(\d+)\.png$',p.name)
        if frame:animations[frame[1]][int(frame[2])].add(int(frame[3]))
        match=re.match(r'(.+_color\d+)_(\d+)\.png$',p.name)
        if match:groups[match[1]].add(int(match[2]))
    for name,values in groups.items():
        if sorted(values)!=list(range(1,max(values)+1)):errors.append('Nonconsecutive series: '+name+' '+str(sorted(values)))
    for family,variants in animations.items():
        if sorted(variants)!=list(range(1,max(variants)+1)):errors.append('Nonconsecutive animation variants: '+family)
        for variant,frames in variants.items():
            if sorted(frames)!=list(range(1,max(frames)+1)):errors.append('Nonconsecutive animation frames: '+family+' '+str(variant))
    for record in json.loads((ROOT/'assets/sprites/renames.json').read_text())['files']:
        p=ROOT/record['path']
        if not p.exists() or hashlib.sha256(p.read_bytes()).hexdigest()!=record['sha256']:errors.append('Sprite changed: '+record['path'])
    report={'runtime_pngs':sorted(str(p.relative_to(ROOT)) for p in used),'runtime_metadata':sorted(str(p.relative_to(ROOT)) for p in visited),
            'unreferenced_pngs':sorted(str(p.relative_to(ROOT)) for p in paths if p.suffix=='.png' and p not in used),
            'missing_references':missing,'errors':errors}
    return report
if __name__=='__main__':
    report=audit()
    (ROOT/'assets/sprites/audit.json').write_text(json.dumps(report,indent=2)+'\n')
    print('Sprite audit:',len(report['runtime_pngs']),'runtime PNGs;',len(report['unreferenced_pngs']),'unreferenced;',len(report['missing_references']),'missing references;',len(report['errors']),'errors')
    for item in report['missing_references']+report['errors']:print(item)
    sys.exit(bool(report['missing_references'] or report['errors']))

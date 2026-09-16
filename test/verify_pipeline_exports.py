from collections import Counter, defaultdict
from math import sqrt
from pathlib import Path
import json
root = Path(__file__).resolve().parent.parent

def load(path):
    vertices, faces = [], []
    for line in path.read_text().splitlines():
        cols = line.split()
        if cols and cols[0] == 'v': vertices.append(tuple(map(float, cols[1:4])))
        if cols and cols[0] == 'f': faces.append([int(c.split('/')[0])-1 for c in cols[1:]])
    edges = Counter(tuple(sorted((f[i], f[(i+1)%len(f)]))) for f in faces for i in range(len(f)))
    assert vertices and faces and all(n in (1,2) for n in edges.values())
    return vertices, faces, edges

def area(vertices, face):
    p = [vertices[v] for v in face]
    return abs(sum(a[0]*b[2]-b[0]*a[2] for a,b in zip(p,p[1:]+p[:1])))/2

def loops(vertices, edges):
    adjacency = defaultdict(list)
    for (a,b), n in edges.items():
        if n == 1: adjacency[a].append(b); adjacency[b].append(a)
    assert all(len(n)==2 for n in adjacency.values())
    pending, result = set(adjacency), []
    while pending:
        start = min(pending); current=start; previous=None; loop=[]
        while True:
            loop.append(current); pending.remove(current)
            nxt=next(v for v in adjacency[current] if v != previous)
            previous,current=current,nxt
            if current==start: break
        changed=True
        while changed and len(loop)>3:
            changed=False
            for i,v in enumerate(loop):
                a,b,c=vertices[loop[i-1]],vertices[v],vertices[loop[(i+1)%len(loop)]]
                cross=(b[0]-a[0])*(c[2]-b[2])-(b[2]-a[2])*(c[0]-b[0])
                if abs(cross)<1e-8:
                    del loop[i];changed=True;break
        points=[vertices[i] for i in loop]
        choices=[tuple(seq[i:]+seq[:i]) for seq in (points,list(reversed(points))) for i in range(len(points))]
        result.append(min(choices))
    return sorted(result)

before=load(root/'test/pipeline-window-before.obj')
after=load(root/'test/pipeline-window-after.obj')
assert len(after[0])==16 and len(after[1])==8 and len(after[2])==24
assert all(len(f)==4 for f in after[1])
assert loops(before[0],before[2])==loops(after[0],after[2])
assert len(loops(after[0],after[2]))==2
assert abs(sum(area(after[0],f) for f in after[1])-104)<1e-8
assert abs(sum(area(before[0],f) for f in before[1])-104)<1e-8
for a,b in after[2]:
    p,q=after[0][a],after[0][b]
    assert abs(p[0]-q[0])<1e-8 or abs(p[2]-q[2])<1e-8
report={'vertices':16,'edges':24,'rectangular_faces':8,'boundary_loops':2,'surface_area':104,'outer_boundary_and_window_match_before':True,'all_edges_orthogonal':True}
(root/'test/pipeline-validation.json').write_text(json.dumps(report,indent=2)+'\n')
# Draw the actual exported edges; there is no idealized replacement geometry.
svg=['<svg xmlns="http://www.w3.org/2000/svg" width="1100" height="510" viewBox="0 0 1100 510">','<rect width="1100" height="510" fill="#f6f7f9"/>']
for offset, data, title, subtitle in [(45,before,'Before','4 polygons; redundant boundary vertices'),(610,after,'After','8 rectangular regions; original opening retained')]:
    vertices,faces,edges=data
    svg += [f'<text x="{offset}" y="37" font-family="sans-serif" font-size="24" fill="#17202a">{title}</text>',f'<text x="{offset}" y="62" font-family="sans-serif" font-size="14" fill="#52606d">{subtitle}</text>']
    for f in faces:
        points=' '.join(f'{offset+vertices[v][0]*35},{435-vertices[v][2]*35}' for v in f)
        svg.append(f'<polygon points="{points}" fill="#dbeafe"/>')
    for (a,b),count in edges.items():
        p,q=vertices[a],vertices[b]
        internal=count==2
        color='#d97706' if internal and title=='Before' else '#1d4ed8' if internal else '#17202a'
        dash=' stroke-dasharray="6 4"' if internal and title=='Before' else ''
        svg.append(f'<line x1="{offset+p[0]*35}" y1="{435-p[2]*35}" x2="{offset+q[0]*35}" y2="{435-q[2]*35}" stroke="{color}" stroke-width="2"{dash}/>')
    for p in vertices:
        svg.append(f'<circle cx="{offset+p[0]*35}" cy="{435-p[2]*35}" r="3.5" fill="#17202a"/>')
    svg.append(f'<text x="{offset}" y="475" font-family="sans-serif" font-size="15" fill="#52606d">V {len(vertices)}  /  E {len(edges)}  /  F {len(faces)}</text>')
svg.append('</svg>')
(root/'test/pipeline-comparison.svg').write_text('\n'.join(svg))
print(json.dumps(report))

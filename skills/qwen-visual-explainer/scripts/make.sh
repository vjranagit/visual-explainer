#!/usr/bin/env bash
# content.json -> one-figure explainer page. Qwen writes content only; the layout comes from the kit's Mermaid engine (Pele),
# which lays out groups, arrows, loops and a separate phone layout. Every failure prints one line with its fix.
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$SKILL_DIR/../.." && pwd)"
KIT="$REPO_ROOT/plugins/visual-explainer/kit"
export VE_NM="$SKILL_DIR/node_modules"
SHIM="$(cd "$(dirname "$0")" && pwd)/pw-shim.mjs"
CONTENT=${1:?usage: make.sh content.json out-dir}
OUT=${2:?usage: make.sh content.json out-dir}
mkdir -p "$OUT" && OUT=$(cd "$OUT" && pwd)
rm -f "$OUT"/explainer*.png
python3 - "$CONTENT" "$OUT/explainer.src.html" "$OUT/flow.mmd" "$OUT/flow-phone.mmd" <<'PY'
import html, itertools, json, re, sys
try:
    c = json.load(open(sys.argv[1], encoding='utf-8'))
except Exception as e:
    sys.exit(f'FIX: content is not valid JSON ({e})')
bad = []
def text(v, where, words=0, chars=0, need=True):
    if v is None and not need: return ''
    if not isinstance(v, str) or not v.strip(): bad.append(f'{where}: write plain text'); return ''
    v = ' '.join(v.split())
    if '<' in v and re.search(r'<\w', v): bad.append(f'{where}: no HTML tags, plain text only')
    if words and len(v.split()) > words: bad.append(f'{where}: {len(v.split())} words, max {words}; cut words')
    if chars and len(v) > chars: bad.append(f'{where}: {len(v)} characters, max {chars}; shorten "{v}"')
    return v
title = text(c.get('title'), 'title', words=12)
claim = text(c.get('claim'), 'claim', words=30)
groups = c.get('groups') if isinstance(c.get('groups'), list) else []
if not 2 <= len(groups) <= 6: bad.append(f'groups: {len(groups)} given, need 2-6 (subsystems, stages or parallel parts)')
nodes, order = {}, []
for gi, g in enumerate(groups):
    g = g if isinstance(g, dict) else {}
    g['name'] = text(g.get('name'), f'groups[{gi}].name', chars=32)
    ns = g.get('nodes') if isinstance(g.get('nodes'), list) else []
    if not 1 <= len(ns) <= 6: bad.append(f'groups[{gi}] "{g["name"]}": {len(ns)} nodes, need 1-6; split the group')
    g['nodes'] = ns
    for ni, n in enumerate(ns):
        n = n if isinstance(n, dict) else {}
        where = f'groups[{gi}].nodes[{ni}]'
        i = n.get('id')
        if not isinstance(i, str) or not re.fullmatch(r'[a-z][a-z0-9_]{0,23}', i): bad.append(f'{where}.id: use a short lowercase id like "pump"'); continue
        if i in nodes: bad.append(f'{where}.id "{i}" is used twice'); continue
        n['label'] = text(n.get('label'), f'node "{i}" label', chars=28)
        n['note'] = text(n.get('note'), f'node "{i}" note', chars=44, need=False)
        n['group'] = gi
        nodes[i] = n; order.append(i)
if not 6 <= len(nodes) <= 16: bad.append(f'nodes: {len(nodes)} in total, need 6-16; show every part of the topic')
links = c.get('links') if isinstance(c.get('links'), list) else []
seen, used, edges = set(), set(), []
for li, l in enumerate(links):
    l = l if isinstance(l, dict) else {}
    a, b = l.get('from'), l.get('to')
    if a not in nodes or b not in nodes: bad.append(f'links[{li}]: from "{a}" / to "{b}" must both be node ids'); continue
    if a == b or (a, b) in seen: bad.append(f'links[{li}] {a}->{b}: self link or duplicate; remove it'); continue
    verb = text(l.get('verb'), f'links[{li}] {a}->{b} verb', chars=24)
    seen.add((a, b)); used |= {a, b}; edges.append((a, b, verb))
if len(edges) < len(nodes) - 1: bad.append(f'links: {len(edges)} given, need at least {len(nodes) - 1} so every part is connected')
lonely = [i for i in order if i not in used]
if lonely: bad.append(f'nodes {lonely} have no link; connect them or remove them')
if nodes and not any(nodes[a]['group'] != nodes[b]['group'] for a, b, _ in edges): bad.append('links: add links between groups; the figure must show how the parts interact')
if bad:
    print('content check failed; fix content.json and rerun:', file=sys.stderr)
    for m in bad: print('FIX: ' + m, file=sys.stderr)
    sys.exit(1)
# feedback = a link that closes a real loop. Loops live inside strongly connected parts (Tarjan); in each part a walk that starts
# where flow enters it marks the links that return to a node still on the walk. A link in no loop is never dotted.
adj = {i: [] for i in order}
for k, (a, b, _) in enumerate(edges): adj[a].append((b, k))
comp, low, idx, stack, on = {}, {}, {}, [], set()
def scc(v):
    idx[v] = low[v] = len(idx); stack.append(v); on.add(v)
    for w, _ in adj[v]:
        if w not in idx: scc(w); low[v] = min(low[v], low[w])
        elif w in on: low[v] = min(low[v], idx[w])
    if low[v] == idx[v]:
        while True:
            w = stack.pop(); on.discard(w); comp[w] = v
            if w == v: break
for v in order:
    if v not in idx: scc(v)
back, state = set(), {}
def walk(v):
    state[v] = 1
    for w, k in adj[v]:
        if comp[w] != comp[v]: continue
        if state.get(w) == 1: back.add(k)
        elif w not in state: walk(w)
    state[v] = 2
for v in sorted(order, key=lambda v: not any(b == v and comp[a] != comp[v] for a, b, _ in edges)):
    if v not in state: walk(v)
# the phone stacks the groups one under another so no two groups share a row. Of the (at most 720) stack orders it takes the
# one whose links skip the fewest groups, with forward links pointing down; a link that skips groups is routed down the side.
cross = [(nodes[a]['group'], nodes[b]['group'], k in back) for k, (a, b, _) in enumerate(edges) if nodes[a]['group'] != nodes[b]['group']]
def cost(p):
    at = {g: i for i, g in enumerate(p)}
    return sum(abs(at[t] - at[s]) - 1 + (10 if at[t] < at[s] and not fb else 0) for s, t, fb in cross)
stacked = min(itertools.permutations(range(len(groups))), key=cost)
q = lambda s: s.replace('"', '#quot;').replace('<', '#lt;').replace('>', '#gt;')
def wrap(s, n):
    out = []
    for w in s.split():
        if out and len(out[-1]) + 1 + len(w) <= n: out[-1] += ' ' + w
        else: out.append(w)
    return [q(x) for x in out]
def flow(box, verb, phone):
    lines = []
    for gi, g in enumerate(groups):
        lines.append(f'  subgraph g{gi}["{q(g["name"])}"]')
        if phone: lines.append('    direction TB')
        for i in g['nodes']:
            n = nodes.get(i.get('id') if isinstance(i, dict) else None)
            if n: lines.append(f'    n_{i["id"]}["' + '<br/>'.join([f'<b>{x}</b>' for x in wrap(n['label'], box)] + wrap(n['note'], box)) + '"]')
        lines.append('  end')
    for k, (a, b, v) in enumerate(edges):
        lines.append(f'  n_{a} {"-.->" if k in back else "-->"}|"' + '<br/>'.join(wrap(v, verb)) + f'"| n_{b}')
    if phone: lines.append('  ' + ' ~~~ '.join(f'g{g}' for g in stacked))
    return '\n'.join(lines)
open(sys.argv[3], 'w', encoding='utf-8').write(flow(18, 24, False))
open(sys.argv[4], 'w', encoding='utf-8').write(flow(12, 10, True))
esc = html.escape
alt = esc(f'{title}: {len(nodes)} parts in {len(groups)} groups, {len(edges)} links' + (f', {len(back)} feedback link(s) dotted' if back else ''))
css = ('main{max-width:1120px;padding:1.5rem 1rem 2rem}h1{max-width:24ch;overflow-wrap:anywhere}figcaption{overflow-wrap:anywhere}'
       '.ve-key{margin-top:.5rem;font-size:.9rem;color:var(--text-dim)}.ve-phone{display:none}'
       '@media (max-width:640px){main{padding:1rem .5rem}.frame{padding:.5rem}.ve-desk{display:none}.ve-phone{display:block}}')
key = '<p class="ve-key">Solid arrow: flow or action. Dotted arrow: feedback that closes a loop.</p>' if back else ''
doc = (f'<!doctype html><html data-register="paper"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">'
       f'<link rel="stylesheet" href="kit.css" data-ve-kit><title>{esc(title)}</title><style>{css}</style></head><body><main><header><h1>{esc(title)}</h1></header>'
       f'<figure><div class="frame ve-desk"><pre class="mermaid" aria-label="{alt}">@@DESK@@</pre></div><div class="frame ve-phone"><pre class="mermaid" aria-label="{alt}">@@PHONE@@</pre></div>'
       f'<figcaption>{esc(claim)}</figcaption>{key}</figure></main></body></html>')
open(sys.argv[2], 'w', encoding='utf-8').write(doc)
PY
# layout is chosen here, never by the content: the page width is fixed, so the desktop figure takes the shortest direction that fits 1000 px;
# the phone figure is the stacked top-down source from flow-phone.mmd
node --input-type=module - "$OUT/explainer.src.html" "$OUT/flow.mmd" "$OUT/flow-phone.mmd" "$KIT/vendor/pele.mjs" <<'JS'
import { readFileSync, writeFileSync } from "node:fs";
const [src, mmd, phone, pele] = process.argv.slice(2);
const { render } = await import(pele);
const body = readFileSync(mmd, "utf8");
const size = (t) => { for (let fontSize = 14; ; fontSize++) { const r = render(t, { fontSize, maxWidth: 960 }); if (fontSize >= 24 || Math.min(...[...r.svg.matchAll(/font-size(?:="|:\s*)([\d.]+)/g)].map((m) => +m[1])) >= 12) return { t, w: r.width, h: r.height }; } };
const desk = [`flowchart LR\n${body}`, `flowchart TB\n${body.replace(/(subgraph [^\n]*\n)/g, "$1    direction LR\n")}`, `flowchart TB\n${body}`].map(size);
const fit = desk.filter((d) => d.w <= 1000);
const pick = fit.length ? fit.reduce((a, b) => (b.h < a.h ? b : a)) : desk.reduce((a, b) => (b.w < a.w ? b : a));
const esc = (s) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
writeFileSync(src, readFileSync(src, "utf8").replace("@@DESK@@", () => esc(pick.t)).replace("@@PHONE@@", () => esc(`flowchart TB\n${readFileSync(phone, "utf8")}`)));
JS
command -v node >/dev/null || { echo 'FIX: install node' >&2; exit 1; }
test -d "$VE_NM/playwright-core" || { echo "FIX: missing $VE_NM/playwright-core; run npm install in samples/03-visual-explainer" >&2; exit 1; }
# the kit imports playwright-core beside itself; send that import to pw-shim.mjs so the kit's visual check really runs
HOOK="data:text/javascript,import{register}from'node:module';register('data:text/javascript,export async function resolve(s,c,n){return n(s===\"playwright-core\"?\"file://$SHIM\":s,c)}')"
if ! node --import "$HOOK" "$KIT/render.mjs" "$OUT/explainer.src.html" -o "$OUT/explainer.html" >"$OUT/render.log" 2>&1 || grep -q 'Visual check skipped' "$OUT/render.log"; then
  grep -E '✗|⚠|skipped|Error' "$OUT/render.log" | sed 's/^ */FIX: /' >&2 || cat "$OUT/render.log" >&2
  echo 'FIX: overlap or tiny labels -> shorten labels/notes/verbs or split a crowded group; full log in render.log' >&2
  exit 1
fi
node - "$OUT" "$SHIM" <<'JS'
(async () => {
  const { chromium } = await import(process.argv[3]);
  const browser = await chromium.launch();
  const bad = [];
  for (const [w, png] of [[1180, 'explainer.png'], [390, 'explainer-phone.png']]) {
    const page = await browser.newPage({ viewport: { width: w, height: 900 } });
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await page.goto('file://' + process.argv[2] + '/explainer.html', { waitUntil: 'load' });
    await page.evaluate(() => document.fonts.ready);
    const m = await page.evaluate(() => {
      const svg = [...document.querySelectorAll('.ve-mermaid > svg')].find((s) => s.checkVisibility());
      const frame = svg && svg.closest('.frame');
      const box = frame && frame.getBoundingClientRect();
      const words = (e) => (e ? [...new Set([...e.querySelectorAll('text, tspan')].filter((t) => !t.querySelector('tspan')).map((t) => t.textContent))].join(' ') : '');
      const name = (e) => (words(e) || words(svg.querySelector(`.pele-cluster-title[data-id="${e.dataset.id}"]`)) || e.dataset.id || '').trim().slice(0, 24);
      const cut = box ? ['.pele-node', '.pele-edge-label', '.pele-cluster'].flatMap((s) => [...svg.querySelectorAll(s)]).filter((e) => { const r = e.getBoundingClientRect(); return r.left < box.left - 1 || r.right > box.right + 1; }).map(name) : [];
      return { page: document.documentElement.scrollWidth, fig: svg ? Math.round(svg.getBoundingClientRect().width) : 0, room: frame ? frame.clientWidth : 0, scrolls: frame ? frame.scrollWidth > frame.clientWidth + 1 : true, cut };
    });
    if (!m.fig) bad.push(`at ${w}px: no diagram drawn; check render.log`);
    if (m.page > w) bad.push(`at ${w}px: page is ${m.page}px wide; shorten the longest word in title/claim/labels`);
    // every node and group must be on screen at fit width, on the phone too: no panning, no cropping
    if (m.fig > m.room || m.scrolls || m.cut.length) bad.push(`at ${w}px: diagram is ${m.fig}px wide in ${m.room}px${m.cut.length ? `, cut off: ${m.cut.slice(0, 4).map((s) => `"${s}"`).join(', ')}` : ''}; parts side by side in one group or links that skip groups widen it: chain parallel parts, link neighbouring groups, or shorten labels/notes/verbs`);
    await page.screenshot({ path: process.argv[2] + '/' + png, fullPage: true });
    await page.close();
  }
  await browser.close();
  if (bad.length) { for (const b of bad) console.error('FIX: ' + b); process.exit(1); }
})().catch((e) => { console.error('FIX: browser failed: ' + e.message.split('\n')[0]); process.exit(1); });
JS
python3 - "$OUT/explainer.png" "$OUT/explainer-phone.png" <<'PY'
import json, os, struct, sys
dims = []
for p in sys.argv[1:]:
    with open(p, 'rb') as f:
        assert f.read(8) == b'\x89PNG\r\n\x1a\n', p
        dims.append(struct.unpack('>II', f.read(16)[8:]))
print(json.dumps({'ok': True, 'png': os.path.abspath(sys.argv[1]), 'size': dims[0], 'phone_png': os.path.abspath(sys.argv[2]), 'phone_size': dims[1]}))
PY

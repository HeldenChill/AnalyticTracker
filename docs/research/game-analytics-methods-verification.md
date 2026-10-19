# First family repair verification and owner review register

**Version:** 1.1.0-pilot. **Date:** 19 October 2026. **Coordinator:** Codex. **Scope:** M01–M08 research repair only. **Baseline:** main at `8a12e97`; research artifacts are untracked, so the whole working tree is not clean. Application files remain unchanged.

This record supersedes the executor's inaccurate verification totals. The earlier review is preserved in [the review report](../reviews/2026-10-19-descriptive-exploratory-research-review.md). Historical commands whose scratch files are absent are not treated as fresh evidence. Owner review remains pending and no other family was written.

## Fresh results

| Gate | Actual result | Limit |
|---|---|---|
| Chapter inventory | PASS: M01–M08 only | Does not imply owner approval |
| Chapter section structure | PASS: 88 required sections, in order and nonempty | Content received manual review as well as structural checks |
| Original plan numerical script | PASS: 23 assertions | The earlier total20 was incorrect; fixture constants alone do not validate membership |
| Independent fixture and repair checks | PASS: 19 checks deriving memberships, traces, scores and counterexamples | Synthetic calculations, not production model or data validation |
| Mermaid inventory | 22 blocks | Earlier reported11 was incorrect |
| Forbidden Mermaid label characters | PASS: zero matches under project label rule | Static syntax safety only; no Mermaid renderer was executed |
| Markdown code fences and local links | PASS: balanced fences, existing local targets and matching internal anchors | External access limitations are listed separately |
| Application scope | PASS: git diff against app/server/shared is empty | No app tests or live database probes were run or needed |
| Whitespace | PASS: git diff --check | Direct file checks also cover untracked artifacts |

## Reproducing checks

Run from repository root. The authoritative 23-assertion arithmetic script is embedded under Arithmetic spot check in `.cursor/plans/descriptive-exploratory-research-implementation.md`. It can be extracted and executed without relying on a missing scratch file:

```powershell
$planText = Get-Content '.cursor/plans/descriptive-exploratory-research-implementation.md' -Raw -Encoding UTF8
$blocks = [regex]::Matches($planText, '(?s)```powershell\r?\n(.*?)\r?\n```')
$arithmetic = @($blocks | Where-Object { $_.Groups[1].Value -match 'function Assert-Close' })
if ($arithmetic.Count -ne 1) { throw 'Expected one arithmetic block' }
& ([scriptblock]::Create($arithmetic[0].Groups[1].Value))
git diff --exit-code -- app server shared
git diff --check
```

The independent checker below is included in full so it remains reproducible if temporary files in ignored build/ are removed. Save it to a local temporary Python file and run it from repository root with Python 3. The coordinator ran this exact checker as `python build/check_research_pilot.py`; its result was PASS with eight chapters, 88 sections, 22 diagrams and 19 semantic checks. It reads documents and does not change the application.

```python
from pathlib import Path
import re, math, json
root=Path.cwd()
base=root/'docs/research'
h=(base/'game-analytics-methods-handbook.md').read_text(encoding='utf-8')
sections=['Question and intuition','Inputs and output','How it works','Worked game example','Assumptions and preparation','Advantages','Disadvantages and failure cases','Evaluation','Alternatives','PetVsMonster fit','Sources and confidence']
chapters=list(re.finditer(r'^## M(\d{2}) (.+)$',h,re.M))
assert [m[1] for m in chapters]==[f'{i:02}' for i in range(1,9)]
for i,m in enumerate(chapters):
    body=h[m.end():chapters[i+1].start() if i<7 else h.index('\n## Method Selection Matrix',m.end())]
    found=re.findall(r'^### (.+)$',body,re.M)
    assert found==sections,(m[1],found)
    for heading,content in zip(found,re.split(r'^### .+$',body,flags=re.M)[1:]):
        assert len(content.strip())>80,(m[1],heading)
    assert re.search(r'\[[^\]]+\]\(https://',body),(m[1],'missing external primary link')
    assert 'Readiness:' in body

files=[base/f'game-analytics-methods-{suffix}.md' for suffix in ['handbook','examples','sources']]
bad_links=[]
for p in files:
    content=p.read_text(encoding='utf-8')
    assert len(re.findall(r'^```',content,re.M))%2==0,p
    anchors=set()
    for heading in re.findall(r'^#{1,6} (.+)$',content,re.M):
        slug=re.sub(r'[^\w\- ]','',heading.lower()).replace(' ','-')
        anchors.add(slug)
    for target in re.findall(r'\]\(([^)]+)\)',content):
        if target.startswith(('https://','http://')): continue
        if target.startswith('#'):
            if target[1:] not in anchors: bad_links.append((p.name,target))
        elif not (p.parent/target.split('#')[0]).exists(): bad_links.append((p.name,target))
assert not bad_links,bad_links
diagrams=re.findall(r'```mermaid\n(.*?)\n```',h,re.S)
for d in diagrams:
    for label in re.findall(r'\[([^\]\n]+)\]|\{([^}\n]+)\}',d):
        label=''.join(label)
        assert not re.search(r'->|=>|==|<>|[()]',label),label
for pattern in ['guaranteeing artificial 100','pure active attention','excludes idle gaps','High (Verified)','Using RFM to Maximize','(M25)','(M13)','(M37)','(NLP, M45)']:
    assert pattern not in h,pattern

checks=[]
def check(name,actual,expected):
    assert actual==expected,(name,actual,expected)
    checks.append(name)
# Recompute from row-level fixture inputs rather than copying displayed fractions.
roster=[(1,[1,2,4,8]),(1,[1,3,9]),(1,[1]),(2,[2,3,9]),(2,[2,4]),(3,[3,4,10]),(3,[3]),(4,[4]),(7,[7,8]),(8,[8,10]),(9,[9,10]),(10,[10])]
for n,expected in [(1,(10,[1,4,6,9,11])),(7,(7,[1,4,6]))]:
    eligible=[(i+1,f,days) for i,(f,days) in enumerate(roster) if f+n<=10 and f+n!=5]
    retained=[i for i,f,days in eligible if f+n in days]
    check(f'EX03 D{n} eligibility and identities',(len(eligible),retained),expected)
activity={'A':{0,1,7},'B':{0,3},'C':{0},'D':{0,7}}
check('EX04 four membership counts',tuple(sum(bool(days&window) for days in activity.values()) for window in [{1},{7},set(range(1,8)),{1,2,3}]),(1,2,3,2))
streams=[['A0','B2','C5'],['A0','C1','B2'],['A0','B2','A20','B21','C22'],['B-1','A0','C2'],['A0','B10','C11'],['A0','B4','C10']]
def walk(events,excluded=None):
    pos=next(i for i,e in enumerate(events) if e[0]=='A'); deadline=events[pos][1]+10
    count=1
    for step in ['B','C']:
        found=None
        for i in range(pos+1,len(events)):
            name,time=events[i]
            if time>deadline: break
            if name==step: found=i; break
            if name==excluded: return count
        if found is None: return count
        pos=found;count+=1
    return count
events=[[(e[0],int(e[1:])) for e in s] for s in streams]
depths=[walk(e) for e in events]
check('EX05 per-player ordered depths',depths,[3,2,2,1,2,3])
check('EX05 unordered completers',[i+1 for i,ev in enumerate(events) if {'B','C'} <= {name for j,(name,time) in enumerate(ev) if j>next(k for k,e in enumerate(ev) if e[0]=='A') and 0<=time<=10}],[1,2,6])
groups=[]
for minute in [0,10,40,71]:
    if not groups or minute-groups[-1][-1]>30: groups.append([])
    groups[-1].append(minute)
check('EX06 inferred groups',groups,[[0,10,40],[71]])
profiles=[(1,10,5,0),(1,7,2,5),(1,1,1,20),(10,10,1,0)]
actual=[]
for first,last,f,m in profiles:
    r=11-last
    code=(3 if r<=2 else 2 if r<=6 else 1,3 if f>=4 else 2 if f>=2 else 1,1 if m==0 else 2 if m<=10 else 3)
    lifecycle='New' if 11-first<=2 else 'Dormant' if r>=7 else 'Cooling' if r>=3 else 'Regular'
    actual.append((''.join(map(str,code)),lifecycle))
check('EX07 four tuple and lifecycle outputs',actual,[('331','Regular'),('222','Cooling'),('113','Dormant'),('311','New')])
virtual=[('V1',50),('V2',-30),('V3',-20),('V3',-20)]
check('EX08 duplicate-aware virtual balance',100+sum(dict(virtual).values()),100)
money=[('T1',400),('T2',600),('R1',-600),('T1',400)]
check('EX08 duplicate-aware net and ads',sum(dict(money).values())+50,450)
check('EX09 theme counts',tuple(sum(theme in tags for tags in [{'UI'},{'UI'},{'Difficulty'},{'UI','Difficulty'},{'Positive'}]) for theme in ['UI','Difficulty','Positive']),(3,2,1))
check('RC01 missing interior coverage',all(k!=3 for k in range(1,8)),False)
check('RC02 cumulative versus on-or-after',(bool({2}&set(range(1,8))),bool({2}&{7})),(True,False))
check('RC03 one-day stickiness',20/100,0.2)
check('RC04 future purchaser exact D1',1 in {0,30},False)
check('RC05 tied timestamp indexes',walk([('A',0),('B',0),('C',0)]),3)
check('RC06 intervening exclusion',walk([('A',0),('skip',1),('B',2)],'skip'),1)
check('RC07 untagged total',sum(map(len,[{'UI'},set(),set(),set()]))/4,0.25)
check('RC08 explicit coder denominator',round(13/15*100,2),86.67)
check('RC09 event-subset engagement',(60000+120000,60000),(180000,60000))
print(json.dumps({'status':'PASS','chapters':8,'ordered_required_sections':88,'nonempty_sections':88,'mermaid_blocks':len(diagrams),'forbidden_mermaid_labels':0,'local_links':'PASS','independent_semantic_checks':len(checks),'checks':checks},indent=2))

```

## Fixture outcomes

| Fixture | Checked outcome |
|---|---|
| EX01 | Two day DAU2/4; mean3; union5; player-days6; sessions8; ratios8/6,1.5,1.6; retry mean4, median1 and nearest-rank p90=20 |
| EX02 | Pooled Android26percent versus iOS64percent despite within-stratum advantage; equal weights yield50percent versus40percent |
| EX03 | Derived D1 eligibility10 and retained IDs P01/P04/P06/P09/P11; D7 eligibility7 and retained P01/P04/P06 |
| EX04 | Membership counts1,2,3,2 for exactD1, exactD7, cumulative1..7 and bracket1..3 |
| EX05 | Ordered per-player depths3,2,2,1,2,3; counts6,5,2; unordered completersP01/P02/P06 |
| EX06 | Groups[0,10,40] and[71]; background90 excluded; explicit span71; incremental engagement180000ms, not measured attention |
| EX07 | Recomputed331 Regular;222 Cooling;113 Dormant;311 New |
| EX08 | Deduplicated coins close100; net IAP400c; plus ads450c; per-active112.5c |
| EX09 | Per-visit risks2percent and8percent; risk ratio4; theme counts3,2,1 among five comments |

RC01–RC09 add missing-interior-day eligibility, distinct return horizons, insufficient stickiness information, future-purchaser nonreturn, tied timestamps, intervening exclusions, untagged theme totals, a declared coder denominator and event-selected engagement. Their input and expected interpretation are in [the example appendix](game-analytics-methods-examples.md).

## Findings and repair status

| Review finding | Repair and evidence | Status |
|---|---|---|
| F01 / BUG-0073 | Removed wrong book metadata and blanket confidence; rebuilt source register with direct accessed sources and qualified unavailable leads | Corrected, with source-access limits disclosed |
| F02 / BUG-0074 | Distinct interval metrics, E_a,b coverage, complete-window policy and RC01–03 | Corrected; exact fixture answers retained |
| F03 / BUG-0075 | Foreground proxy, idle-gap span, other-event increments and RC09 | Corrected; production completeness remains unverified |
| F04 / BUG-0076 | Future-purchaser counterexample and retrospective versus predictive distinction, RC04 | Corrected |
| F05 / BUG-0077 | Per-visit risk terminology, general theme-assignment formula, RC07–08 | Corrected |
| F06 / BUG-0078 | Scoped fit assessments and matrix separate storage, client emission and optional optimizations | Corrected; client and live data uninspected |
| F07 / BUG-0079 | Removed unsupported cutoffs and prevalence; qualified scoring, supply and reporting-policy statements | Corrected |
| F08 / BUG-0080 | ClusteringM14, survivalM26–27, pathsM30, LTVM24 and sentimentM44 | Corrected; future chapter labels explicit |
| F09 / BUG-0081 | Actual23/22 counts, four labels repaired, reproducible checker and honest static-only report | Corrected |
| F10 / BUG-0082 | Event-index matching, equal timestamps, exclusion scan and RC05–06 | Corrected |
| Existing app BUG-0083 | Max-date observability still cannot detect missing intermediate targets | Open, unchanged application issue |

## Source and evidence limits

Primary pages opened for this repair include GameAnalytics metrics/resources, Amplitude retention/cohorts, Unity funnels, Google engagement/export schema, the rfm package manual/function reference, Esri rate calculation, UK government qualitative guidance, Hyndman's author publication record and Perry Drake's university profile. Direct claim mapping and inspected sections are recorded in [the source register](game-analytics-methods-sources.md).

The IBM RFM page returned403. Full Simpson and Hyndman-Fan papers and earlier cited book chapters were not claimed read. Book metadata access is not chapter access. Some chapters rely on one inspected methodological reference plus explicit own arithmetic or policy rather than two fully inspected original methodology sources. No source validity is inferred from an arithmetic pass. External links were checked through the research browser where accessible; universal availability across all networks is not asserted.

Mermaid rendering remains unperformed. No claim about real client emission, player behavior, runtime performance or causal effects was established. Counterexamples and logical repairs are synthetic checks and code inspection only.

## Owner feedback register

**Status:** Awaiting owner review of the corrected first family. The seven review prompts remain at the end of the handbook. No owner opinion or approval is inferred from this repair request.

| Method or shared section | Owner concern | Paragraph or example | Proposed revision | Accepted action | Status |
|---|---|---|---|---|---|
| Corrected first family | Awaiting owner response | M01–M08 | Review clarity and depth before wider expansion | No wider expansion authorized | Awaiting owner review |

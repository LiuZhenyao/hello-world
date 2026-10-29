extends SceneTree
const M=preload("res://model.gd")
const N=preload("res://constellation.gd")
const S=preload("res://storage.gd")
var checks=0
var failures=0
func check(ok: bool,description: String):
 checks+=1;print(("PASS " if ok else "FAIL ")+description)
 if not ok:failures+=1
func _initialize():
 var p=M.defaults();p["planes"]=N.default_planes();p["topology"]=0;p.hours=0.05;p.step=30
 check(N.validate(p)=="","default multi-plane input validates")
 var sats=N.satellites(p)
 check(sats.size()==11 and sats[4].plane==1 and sats[8].plane==2,"eleven satellites across three distinct planes")
 check(sats[1].phase-sats[0].phase==90 and sats[9].phase-sats[8].phase==120,"equal mean anomaly spacing within each plane")
 check(sats[0].alt==550 and sats[4].alt==20200 and sats[8].alt==35786,"LEO MEO GEO layers preserved")
 var edges=N.edges(p,sats);var seen={};var unique=true
 for edge in edges:
  var key="%d:%d"%[mini(edge[0],edge[1]),maxi(edge[0],edge[1])]
  if seen.has(key) or edge[0]==edge[1]:unique=false
  seen[key]=true
 check(unique and edges.size()==22,"neighbor topology has 22 unique non-self links")
 var n=N.run(p)
 check(n.links.size()==22 and n.count==22*M.sample_count(p),"all links evaluated with exact record count")
 var q=p.duplicate(true);q.a=sats[0];q.b=sats[8]
 var reference=M.run(q)
 check(n.links[0].rows==reference.rows,"reference LEO GEO link matches independently computed physical model")
 var again=N.run(p)
 var reproducible=true
 for k in range(n.links.size()):
  for j in range(n.links[k].count):
   var a: Dictionary=n.links[k].rows[j];var b: Dictionary=again.links[k].rows[j]
   if a.valid!=b.valid or a.range!=b.range or (a.valid and a.measured!=b.measured):reproducible=false
 check(reproducible,"network noise reproducible across runs")
 var counts_ok=true;var sum_valid=0
 for j in range(n.active.size()):
  var count=0
  for link in n.links:
   if link.rows[j].valid:count+=1
  if n.active[j]!=count:counts_ok=false
  sum_valid+=count
 check(counts_ok and sum_valid==n.valid,"time resolved active counts and global valid total agree")
 var full=p.duplicate(true);full.topology=1
 check(N.edges(full,sats).size()==55,"full mesh contains all 11 choose 2 star pairs")
 var full_result=N.run(full)
 check(full_result.links.size()==55 and full_result.count==55*M.sample_count(p),"full mesh actually evaluates every pair")
 var saved=S.parse_scenario(S.scenario_json(p))
 if saved.has("error"):print("ROUNDTRIP ERROR: ",saved.error)
 var roundtrip=saved.has("params")
 if roundtrip:
  roundtrip=saved.params.planes.size()==p.planes.size() and saved.params.topology==0
  for k in range(p.planes.size()):
   for key in p.planes[k]:
    if not is_equal_approx(float(saved.params.planes[k][key]),float(p.planes[k][key])):roundtrip=false
 check(roundtrip,"complete constellation JSON round trip")
 var bad=p.duplicate(true);bad.planes[1].ecc=0.5;bad.planes[1].alt=550
 check(N.validate(bad)!="" and S.parse_scenario(S.scenario_json(bad)).has("error"),"reject below Earth perigee inside any plane")
 bad=p.duplicate(true);bad.planes[0].count=2.5
 check(N.validate(bad)!="","reject fractional satellite count")
 bad=p.duplicate(true);bad.planes[0].count="bad"
 check(N.validate(bad)!="","reject malformed satellite count without crashing")
 bad=p.duplicate(true);bad.planes.resize(1)
 check(N.validate(bad)!="","reject fewer than two planes")
 bad=full.duplicate(true);bad.hours=48;bad.step=10
 check(N.validate(bad)!="","reject network record budget overflow")
 var cancelled=N.run(p,Callable(),func():return true)
 check(cancelled.get("cancelled",false),"network cancellation returns without partial success")
 var csv=N.csv(n).split("\r\n",false)
 check(csv.size()==n.count+1 and csv[0].split(",").size()==14,"network CSV covers every measurement with source target columns")
 check(csv[1].contains("01面-01星,03面-01星"),"CSV identifies actual transmitting and receiving satellites")
 check(N.html(n).contains("22 条候选链路") and N.html(n).contains(n.links[-1].name.xml_escape()),"network report includes complete link summary")
 print("TOTAL CONSTELLATION: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)

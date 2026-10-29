extends SceneTree
const M=preload("res://model.gd")
const S=preload("res://storage.gd")
const R=preload("res://report.gd")
var checks=0
var failures=0
func check(ok: bool,description: String):
 checks+=1;print(("PASS " if ok else "FAIL ")+description)
 if not ok:failures+=1
func _initialize():
 var p=M.defaults()
 var saved=S.parse_scenario(S.scenario_json(p))
 check(saved.has("params") and saved.params==p,"scenario JSON parameter roundtrip")
 check(S.parse_scenario("{}").has("error"),"reject invalid scenario schema")
 check(S.parse_scenario("bad json").has("error"),"reject invalid JSON")
 var invalid=p.duplicate(true);invalid.a.raan=361
 check(S.parse_scenario(S.scenario_json(invalid)).has("error"),"reject angle outside UI bounds")
 var path="user://test-scenario.json"
 check(S.write_text(path,S.scenario_json(p))=="" and S.load_scenario(path).params==p,"scenario file write and reload")
 DirAccess.remove_absolute(path)
 var result=M.run(p)
 var html=R.html(result)
 check(html.contains("<svg") and html.contains("2161") and not html.contains("nan"),"self-contained HTML report and finite summary")
 var csv=M.csv(result)
 var lines=csv.split("\r\n",false)
 check(lines.size()==2162 and lines[0].split(",").size()==12,"CSV row and column count")
 var invalid_rows=0
 for line in lines.slice(1):
  var cells=line.split(",",true)
  if cells[6]=="0":
   invalid_rows+=1
   if cells[10]!="" or cells[11]!="":failures+=1
 check(invalid_rows==result.count-result.valid,"invalid measurement fields stay empty")
 p.threshold=1e12;p.power=0.001
 check(R.html(M.run(p)).contains("无有效测量"),"zero-link report handles unavailable statistics")
 print("TOTAL: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)

extends SceneTree
const M=preload("res://model.gd")
var checks=0
var failures=0
func check(ok: bool,description: String):
 checks+=1
 print(("PASS " if ok else "FAIL ")+description)
 if not ok:failures+=1
func _initialize():
 var p=M.defaults()
 check(M.validate(p)=="","default parameter validation")
 var s=p.a.duplicate();s.ecc=0.0
 var period=TAU*sqrt(pow(M.RE+s.alt,3)/M.MU)
 check(M.distance(M.state(s,0),M.state(s,period))<1e-8,"circular orbit closes after one period")
 for t in [0,1000,3400]:
  var rv=M.state(p.a,t)
  var radius=sqrt(rv[0]*rv[0]+rv[1]*rv[1]+rv[2]*rv[2])
  var v2=rv[3]*rv[3]+rv[4]*rv[4]+rv[5]*rv[5]
  check(abs(v2/2-M.MU/radius+M.MU/(2*(M.RE+p.a.alt)))<1e-10,"specific energy conservation t="+str(t))
 check(not M.clear_los([7000.0,0,0],[-7000.0,0,0]),"Earth blocks opposite satellites")
 check(M.clear_los([7000.0,0,0],[7000.0,1000,0]),"same-side line is visible")
 check(not M.clear_los([7000.0,0,0],[7000.0,0,0]),"coincident endpoints invalid")
 var bad=p.duplicate(true);bad.a.ecc=0.5
 check(M.validate(bad)!="","reject below-Earth perigee")
 bad=p.duplicate(true);bad.step=0.1;bad.hours=48
 check(M.validate(bad)!="","reject excessive sample count")
 bad=p.duplicate(true);bad.power="x"
 check(M.validate(bad)!="","reject nonnumeric imported input")
 var result=M.run(p)
 check(result.count==2161 and result.valid>0 and result.valid<result.count,"LEO-GEO has valid and occulted measurements")
 check(result.rms>0.015 and result.rms<0.025,"default 2 cm noise RMS statistical check")
 var repeat=M.run(p)
 check(result.rows[0].error==repeat.rows[0].error and result.rms==repeat.rms,"random seed repeatability")
 p.b=p.a.duplicate(true);p.a.ecc=0;p.b.ecc=0;p.b.phase=22;p.hours=0.1;p.step=5
 var formation=M.run(p)
 var analytic=2*(M.RE+p.a.alt)*sin(deg_to_rad(11))*1000
 check(abs(formation.min_range-analytic)<0.00001 and abs(formation.max_range-analytic)<0.00001,"formation vs analytic chord distance")
 check(abs(formation.max_rate)<1e-8 and abs(formation.min_rate)<1e-8,"formation geometric range-rate zero")
 p.sigma=0;p.timing=0;p.bias=1.25;p.clock=2
 var biased=M.run(p)
 check(abs(biased.mean-(1.25+2e-9*M.C))<1e-9,"one-way clock and fixed bias")
 check(abs(biased.rows[0].measured-biased.rows[0].path-biased.rows[0].error)<1e-7,"pseudorange includes light-time and biases")
 check(abs(biased.rows[0].path-biased.rows[0].range)>0.01,"light-time effect is applied")
 var csv=M.csv(biased)
 check(csv.begins_with("\ufefftime_s,") and csv.split("\r\n",false).size()==biased.count+1,"CSV BOM and row count")
 p=M.defaults();p.threshold=1e12;p.power=0.001
 var dark=M.run(p)
 check(dark.valid==0 and is_nan(dark.rms) and dark.windows.is_empty(),"zero-link statistics remain unavailable")
 p=M.preset(2)
 var geo=M.run(p)
 check(geo.valid==geo.count and geo.windows.size()==1,"GEO-GEO full-day continuous sampled link")
 check(geo.max_range-geo.min_range<0.0001,"GEO fixed geometric separation")
 var cancelled=M.run(M.defaults(),Callable(),func():return true)
 check(cancelled.get("cancelled",false),"calculation cancellation")
 print("TOTAL: %d checks, %d failures"%[checks,failures])
 print("DEFAULT: valid=%d/%d RMS=%.9f m"%[result.valid,result.count,result.rms])
 quit(1 if failures else 0)

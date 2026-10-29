extends RefCounted
## All physical calculations use scalar 64-bit floats in ECI, km and seconds.
## Vectors in the UI are for display only.
const MU = 398600.4418
const RE = 6378.137
const C = 299792458.0
const H = 6.62607015e-34
const MAX_SAMPLES = 50000

static func defaults() -> Dictionary:
 return {"a":{"alt":550.0,"ecc":0.001,"inc":53.0,"raan":0.0,"arg":0.0,"phase":0.0},"b":{"alt":35786.0,"ecc":0.0,"inc":0.0,"raan":0.0,"arg":0.0,"phase":18.0},"hours":6.0,"step":10.0,"power":1.0,"wave":1550.0,"aperture":0.15,"divergence":10.0,"jitter":1.0,"efficiency":0.3,"sigma":0.02,"timing":50.0,"bias":0.0,"clock":0.0,"seed":2026,"threshold":100.0}

static func preset(index: int) -> Dictionary:
 var p=defaults()
 if index==1:
  p.b=p.a.duplicate(true);p.b.phase=22.0;p.hours=3.0;p.step=5.0
 elif index==2:
  p.a=p.b.duplicate(true);p.a.phase=0.0;p.b.phase=55.0;p.hours=24.0;p.step=60.0
 return p

static func numeric(v: Variant) -> bool:
 return (v is int or v is float) and is_finite(float(v))

static func validate(p: Dictionary) -> String:
 for sat in ["a","b"]:
  if not p.get(sat) is Dictionary:return "卫星轨道参数缺失："+sat
  var limits={"alt":[160.0,35786.0],"ecc":[0.0,0.5],"inc":[0.0,180.0],"raan":[0.0,360.0],"arg":[0.0,360.0],"phase":[0.0,360.0]}
  for k in limits:
   if not numeric(p[sat].get(k)):return "轨道参数缺失或格式错误："+sat+" / "+k
   if p[sat][k]<limits[k][0] or p[sat][k]>limits[k][1]:return "轨道参数超出范围："+sat+" / "+k
  if (RE+p[sat].alt)*(1-p[sat].ecc)<RE+100:return "近地点低于 100 km，请降低偏心率或提高半长轴高度。"
 var bounds={"hours":[0.01,48.0],"step":[0.1,3600.0],"power":[0.001,100.0],"wave":[400.0,2000.0],"aperture":[0.01,2.0],"divergence":[0.1,1000.0],"jitter":[0.0,1000.0],"efficiency":[0.001,1.0],"sigma":[0.0,100.0],"timing":[0.0,10000.0],"bias":[-10000.0,10000.0],"clock":[-100000.0,100000.0],"seed":[0.0,2147483647.0],"threshold":[1.0,1e12]}
 for k in bounds:
  if not numeric(p.get(k)):return "参数缺失或格式错误："+k
  if p[k]<bounds[k][0] or p[k]>bounds[k][1]:return "参数超出范围："+k
 if float(p.seed)!=floor(float(p.seed)):return "随机种子必须为整数。"
 if sample_count(p)>MAX_SAMPLES:return "单次最多 50,000 个采样点，请增大步长或缩短时长。"
 return ""

static func sample_count(p: Dictionary) -> int:
 return int(floor(p.hours*3600.0/p.step+1e-9))+1

static func state(s: Dictionary,t: float) -> Array:
 var a: float=RE+s.alt
 var e: float=s.ecc
 var n: float=sqrt(MU/(a*a*a))
 var m: float=fposmod(deg_to_rad(s.phase)+n*t,TAU)
 var E: float=m
 for j in range(12):
  var delta: float=(E-e*sin(E)-m)/(1-e*cos(E))
  E-=delta
  if abs(delta)<1e-13:break
 var x: float=a*(cos(E)-e)
 var y: float=a*sqrt(1-e*e)*sin(E)
 var ed: float=n/(1-e*cos(E))
 var vx: float=-a*sin(E)*ed
 var vy: float=a*sqrt(1-e*e)*cos(E)*ed
 var o: float=deg_to_rad(s.raan)
 var i: float=deg_to_rad(s.inc)
 var w: float=deg_to_rad(s.arg)
 var px: float=cos(o)*cos(w)-sin(o)*sin(w)*cos(i)
 var py: float=sin(o)*cos(w)+cos(o)*sin(w)*cos(i)
 var pz: float=sin(w)*sin(i)
 var qx: float=-cos(o)*sin(w)-sin(o)*cos(w)*cos(i)
 var qy: float=-sin(o)*sin(w)+cos(o)*cos(w)*cos(i)
 var qz: float=cos(w)*sin(i)
 return [px*x+qx*y,py*x+qy*y,pz*x+qz*y,px*vx+qx*vy,py*vx+qy*vy,pz*vx+qz*vy]

static func distance(a: Array,b: Array) -> float:
 return sqrt(pow(a[0]-b[0],2)+pow(a[1]-b[1],2)+pow(a[2]-b[2],2))

static func clear_los(a: Array,b: Array) -> bool:
 var dx: float=b[0]-a[0]
 var dy: float=b[1]-a[1]
 var dz: float=b[2]-a[2]
 var d: float=dx*dx+dy*dy+dz*dz
 if d<1e-18:return false
 var u: float=clamp(-(a[0]*dx+a[1]*dy+a[2]*dz)/d,0.0,1.0)
 return pow(a[0]+u*dx,2)+pow(a[1]+u*dy,2)+pow(a[2]+u*dz,2)>RE*RE

static func run(p: Dictionary,progress: Callable=Callable(),cancelled: Callable=Callable()) -> Dictionary:
 var err=validate(p)
 if not err.is_empty():return {"error":err}
 var rng=RandomNumberGenerator.new();rng.seed=int(p.seed)
 var count=sample_count(p)
 var rows: Array=[]
 var valid_count=0
 var visible_count=0
 var sum_error=0.0
 var sum_sq=0.0
 var min_r=INF
 var max_r=0.0
 var min_rate=INF
 var max_rate=-INF
 var max_photons=0.0
 var windows: Array=[]
 var window_start=-1.0
 var last_valid=-1.0
 for j in range(count):
  if j%250==0:
   if cancelled.is_valid() and cancelled.call():return {"cancelled":true}
   if progress.is_valid():progress.call(float(j)/count)
  var t: float=j*p.step
  var a=state(p.a,t)
  var b=state(p.b,t)
  var geometric: float=distance(a,b)*1000.0
  var path: float=geometric
  var br=b
  # A emits at t, B receives at t + path/c. This is one-way, not two-way ranging.
  for k in range(5):
   br=state(p.b,t+path/C)
   path=distance(a,br)*1000.0
  var visible: bool=clear_los(a,br) and path>1.0
  var rate=0.0
  if geometric>0:
   for k in range(3):rate+=(b[k]-a[k])*(b[k+3]-a[k+3])*1e6/geometric
  var beam: float=max(path*p.divergence*1e-6,0.001)
  # Stable evaluation of 1-exp(-x) when the aperture fraction is very small.
  var capture_x: float=2.0*pow(p.aperture/2.0/beam,2)
  var capture: float=capture_x*(1.0-capture_x/2.0) if capture_x<1e-5 else 1.0-exp(-capture_x)
  var pointing: float=exp(-2.0*pow(p.jitter/p.divergence,2))
  var received: float=p.power*capture*pointing*p.efficiency if visible else 0.0
  var photons: float=received*min(p.step,1.0)/(H*C/(p.wave*1e-9))
  var valid: bool=visible and photons>=p.threshold
  var noise_sigma: float=sqrt(p.sigma*p.sigma+pow(C*p.timing*1e-12/sqrt(max(photons,1.0)),2))
  var residual: float=p.bias+C*p.clock*1e-9+rng.randfn(0.0,noise_sigma) if valid else NAN
  var measured: float=path+residual if valid else NAN
  if visible:visible_count+=1
  if valid:
   valid_count+=1;sum_error+=residual;sum_sq+=residual*residual
   if window_start<0:window_start=t
   last_valid=t
  elif window_start>=0:
   windows.append([window_start,last_valid]);window_start=-1.0
  min_r=min(min_r,geometric);max_r=max(max_r,geometric)
  min_rate=min(min_rate,rate);max_rate=max(max_rate,rate)
  max_photons=max(max_photons,photons)
  rows.append({"t":t,"range":geometric,"path":path,"rate":rate,"delay":path/C*1000.0,"visible":visible,"valid":valid,"power":received,"photons":photons,"sigma":noise_sigma,"measured":measured,"error":residual})
 if window_start>=0:windows.append([window_start,last_valid])
 var mean: float=sum_error/valid_count if valid_count>0 else NAN
 var rms: float=sqrt(sum_sq/valid_count) if valid_count>0 else NAN
 var stddev: float=sqrt(max(0.0,sum_sq/valid_count-mean*mean)) if valid_count>0 else NAN
 return {"params":p.duplicate(true),"rows":rows,"count":count,"valid":valid_count,"visible":visible_count,"mean":mean,"rms":rms,"stddev":stddev,"min_range":min_r,"max_range":max_r,"min_rate":min_rate,"max_rate":max_rate,"max_photons":max_photons,"windows":windows}

static func csv(result: Dictionary) -> String:
 var parts=PackedStringArray(["\ufefftime_s,geometric_range_m,light_time_path_m,range_rate_m_s,light_time_ms,earth_clear,link_valid,received_power_W,detected_photons,noise_sigma_m,pseudorange_m,residual_m"])
 for r in result.rows:
  parts.append("%.3f,%.6f,%.6f,%.6f,%.9f,%d,%d,%s,%.6f,%.9f,%s,%s"%[r.t,r.range,r.path,r.rate,r.delay,int(r.visible),int(r.valid),String.num_scientific(r.power),r.photons,r.sigma,"%.6f"%r.measured if r.valid else "","%.9f"%r.error if r.valid else ""])
 return "\r\n".join(parts)+"\r\n"

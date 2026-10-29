extends RefCounted
const M=preload("res://model.gd")
const MAX_RECORDS=300000
const MAX_SATELLITES=72

static func default_planes() -> Array:
 var p=M.defaults()
 return [dict_plane(p.a,4),dict_plane({"alt":20200.0,"ecc":0.0,"inc":55.0,"raan":120.0,"arg":0.0,"phase":30.0},4),dict_plane(p.b,3)]

static func dict_plane(orbit: Dictionary,count: int) -> Dictionary:
 var s=orbit.duplicate(true);s["count"]=count;return s

static func satellites(p: Dictionary) -> Array:
 var out: Array=[]
 for k in range(p.planes.size()):
  var plane: Dictionary=p.planes[k]
  for j in range(int(plane.count)):
   var sat=plane.duplicate(true);sat.erase("count")
   sat.phase=fposmod(plane.phase+360.0*j/plane.count,360.0)
   sat["name"]="%02d面-%02d星"%[k+1,j+1];sat["plane"]=k;sat["slot"]=j
   out.append(sat)
 return out

static func edges(p: Dictionary,sats: Array) -> Array:
 var out: Array=[];var seen={}
 # Keep a low-to-high reference link at the top of the list.
 var last=0
 for j in range(sats.size()):
  if sats[j].plane==p.planes.size()-1:last=j;break
 add_edge(out,seen,0,last)
 if int(p.get("topology",0))==1:
  for a in range(sats.size()):
   for b in range(a+1,sats.size()):add_edge(out,seen,a,b)
 else:
  var offset=0
  for k in range(p.planes.size()):
   var n=int(p.planes[k].count)
   var next_offset=offset+n if k<p.planes.size()-1 else 0
   var next_count=int(p.planes[(k+1)%p.planes.size()].count)
   for j in range(n):
    add_edge(out,seen,offset+j,offset+(j+1)%n)
    add_edge(out,seen,offset+j,next_offset+j%next_count)
   offset+=n
 return out

static func add_edge(out: Array,seen: Dictionary,a: int,b: int):
 if a==b:return
 var key="%d:%d"%[mini(a,b),maxi(a,b)]
 if seen.has(key):return
 seen[key]=true;out.append([a,b])

static func validate(p: Dictionary) -> String:
 var err=M.validate(p)
 if err!="":return err
 if not p.get("planes") is Array or p.planes.size()<2 or p.planes.size()>8:return "请配置 2 至 8 个轨道面。"
 if not M.numeric(p.get("topology",0)) or (p.get("topology",0)!=0 and p.get("topology",0)!=1):return "链路拓扑选项无效。"
 var count=0
 for plane in p.planes:
  if not plane is Dictionary:return "轨道面格式错误。"
  if not M.numeric(plane.get("count")) or plane.count!=floor(plane.count) or plane.count<2 or plane.count>12:return "每面卫星数量应为 2 至 12 的整数。"
  var pair=M.defaults();pair.a=plane;pair.b=plane
  err=M.validate(pair)
  if err!="":return "轨道面参数无效："+err
  count+=int(plane.count)
 if count>MAX_SATELLITES:return "最多支持 72 颗卫星，请减少每面星数或轨道面数量。"
 var sats=satellites(p);var links=edges(p,sats)
 if links.size()*M.sample_count(p)>MAX_RECORDS:return "本次将超过 300,000 条链路测量记录，请增大采样步长、缩短时长或使用相邻组网。"
 return ""

static func run(p: Dictionary,progress: Callable=Callable(),cancelled: Callable=Callable()) -> Dictionary:
 var err=validate(p)
 if err!="":return {"error":err}
 var sats=satellites(p);var pairs=edges(p,sats);var links: Array=[]
 var active: Array=[];active.resize(M.sample_count(p));active.fill(0)
 var valid=0;var total=0
 for k in range(pairs.size()):
  if cancelled.is_valid() and cancelled.call():return {"cancelled":true}
  var pair: Array=pairs[k];var q=p.duplicate(true)
  q.a=sats[pair[0]];q.b=sats[pair[1]]
  # Per-link deterministic independent stream. Reference link retains the input seed.
  q.seed=(int(p.seed)+k*104729)%2147483647
  var r=M.run(q,Callable(),cancelled)
  if r.has("cancelled"):return r
  if r.has("error"):return r
  r["source"]=pair[0];r["target"]=pair[1]
  r["name"]=sats[pair[0]].name+" → "+sats[pair[1]].name
  links.append(r);valid+=r.valid;total+=r.count
  for j in range(r.count):
   if r.rows[j].valid:active[j]+=1
  if progress.is_valid():progress.call(float(k+1)/pairs.size())
 return {"params":p.duplicate(true),"satellites":sats,"links":links,"active":active,"valid":valid,"count":total}

static func csv(network: Dictionary) -> String:
 var lines=PackedStringArray(["\ufeff轨道面发射星,轨道面接收星,时间_s,几何距离_m,光行时路径_m,距离率_m_s,光行时_ms,无遮挡,链路有效,接收功率_W,探测光子数,噪声标准差_m,伪距_m,残差_m"])
 for link in network.links:
  var a=network.satellites[link.source].name;var b=network.satellites[link.target].name
  var rows=M.csv(link).trim_prefix("\ufeff").split("\r\n",false)
  for row in rows.slice(1):lines.append(a+","+b+","+row)
 return "\r\n".join(lines)+"\r\n"

static func html(network: Dictionary) -> String:
 var out="<h2>星座与全网统计</h2><p>%d 个轨道面 · %d 颗卫星 · %d 条候选链路 · %d 条测量记录 · 有效占比 %.2f%%</p>"%[network.params.planes.size(),network.satellites.size(),network.links.size(),network.count,100.0*network.valid/network.count]
 out+="<p>相邻组网包含各面环形链路及相邻面的对应星链路；全互联枚举所有无向星对。每条星对按列表方向计算单向测量。链路假设独立理想终端，不计同时服务能力限制。</p><table><tr><th>链路</th><th>有效率</th><th>残差均方根 / 米</th><th>窗口数</th></tr>"
 for link in network.links:
  out+="<tr><td>%s</td><td>%.2f%%</td><td>%s</td><td>%d</td></tr>"%[link.name.xml_escape(),100.0*link.valid/link.count,"%.6f"%link.rms if link.valid else "无有效测量",link.windows.size()]
 return out+"</table>"

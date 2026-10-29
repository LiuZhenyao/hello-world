extends Control
const Model=preload("res://model.gd")
const INK=Color("253750")
const MUTED=Color("7c8a9d")
const TEAL=Color("0f9d91")
const BLUE=Color("4285db")
var network: Dictionary={}
var selected_link=0
var mode="orbit"
var result: Dictionary={}
var parameters: Dictionary={}
var cursor=0
var chart="range"
var font: Font
var yaw=0.35
var pitch=0.48
var zoom=1.0
var dragging=false
signal seek(index: int)

func _ready():
 font=load("res://assets/ui.ttc")
 mouse_filter=Control.MOUSE_FILTER_STOP
 clip_contents=true
 tooltip_text="拖动旋转轨道视图；滚轮缩放。曲线区域点击可定位时间。"

func _gui_input(event):
 if event is InputEventMouseButton:
  if event.button_index==MOUSE_BUTTON_LEFT:
   dragging=event.pressed
   if mode!="orbit" and event.pressed and not result.is_empty():
    seek.emit(clampi(int((event.position.x-65)/max(size.x-90,1)*(result.count-1)),0,result.count-1))
  if mode=="orbit" and event.pressed:
   if event.button_index==MOUSE_BUTTON_WHEEL_UP:zoom=clamp(zoom*1.1,0.35,8.0)
   if event.button_index==MOUSE_BUTTON_WHEEL_DOWN:zoom=clamp(zoom/1.1,0.35,8.0)
   queue_redraw()
 if event is InputEventMouseMotion and dragging and mode=="orbit":
  yaw+=event.relative.x*0.008;pitch=clamp(pitch+event.relative.y*0.008,-1.4,1.4);queue_redraw()

func text_at(p: Vector2,s: String,col: Color=MUTED,fs=12):
 draw_string(font,p,s,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,col)

func project_point(p: Array,center: Vector2,scale_v: float) -> Vector2:
 var x: float=p[0]*cos(yaw)-p[1]*sin(yaw)
 var y: float=p[0]*sin(yaw)+p[1]*cos(yaw)
 var z: float=y*sin(pitch)+p[2]*cos(pitch)
 return center+Vector2(x,-z)*scale_v

static func style(color: Color,radius=10) -> StyleBoxFlat:
 var s=StyleBoxFlat.new();s.bg_color=color;s.set_corner_radius_all(radius);return s

func _draw():
 if font==null:return
 if mode=="orbit":draw_orbit()
 else:draw_chart()

func draw_orbit():
 draw_style_box(style(Color("101e35"),14),Rect2(Vector2.ZERO,size))
 for n in range(110):
  var pt=Vector2(fposmod(n*137.19+41,size.x),fposmod(n*83.73+19,size.y))
  draw_circle(pt,0.6 if n%3 else 1.1,Color(0.53,0.66,0.84,0.22))
 text_at(Vector2(20,27),"多轨道面星座 · 地心惯性空间",Color("dbe8ff"),14)
 if parameters.is_empty():return
 var sats: Array=network.get("satellites",[parameters.a,parameters.b])
 var planes: Array=parameters.get("planes",[parameters.a,parameters.b])
 text_at(Vector2(20,47),"%d 个轨道面  /  %d 颗卫星  /  单向激光测量"%[planes.size(),sats.size()],Color("8298b8"),11)
 var center=Vector2(size.x*0.5,size.y*0.53)
 var outer=0.0
 for sat in sats:outer=maxf(outer,(Model.RE+sat.alt)*(1+sat.ecc))
 var scale_v: float=min(size.x*0.43,size.y*0.53)/outer*zoom
 var radius: float=Model.RE*scale_v
 # Fine ECI reference grid and a shaded Earth with projected graticule.
 for k in range(1,5):
  var eq=PackedVector2Array()
  for j in range(97):eq.append(project_point([outer*k/4.0*cos(j*TAU/96),outer*k/4.0*sin(j*TAU/96),0],center,scale_v))
  draw_polyline(eq,Color(0.34,0.48,0.66,0.12),1.0,true)
 draw_circle(center,radius+5,Color(0.12,0.46,0.76,0.12))
 draw_circle(center,radius,Color("153f64"))
 for k in range(12,0,-1):
  draw_circle(center+Vector2(-radius*0.12,-radius*0.12),radius*k/13.0,Color(0.12,0.36,0.51,0.045))
 draw_arc(center,radius,0,TAU,90,Color("4f83ac"),1.0,true)
 for k in [-0.75,-0.4,0.0,0.4,0.75]:
  var line=PackedVector2Array()
  for j in range(65):
   var ang=j*TAU/64
   line.append(project_point([Model.RE*sqrt(1-k*k)*cos(ang),Model.RE*sqrt(1-k*k)*sin(ang),Model.RE*k],center,scale_v))
  draw_polyline(line,Color(0.4,0.68,0.84,0.28),1,true)
 for k in range(6):
  var line=PackedVector2Array()
  for j in range(65):
   var ang=j*TAU/64;var lon=k*PI/6
   line.append(project_point([Model.RE*cos(ang)*cos(lon),Model.RE*cos(ang)*sin(lon),Model.RE*sin(ang)],center,scale_v))
  draw_polyline(line,Color(0.4,0.68,0.84,0.17),1,true)
 var palette=[Color("52e1c3"),Color("72aaff"),Color("f3c66c"),Color("d896f5"),Color("ff8d9d"),Color("a7dc7a"),Color("77d9e7"),Color("d6c6af")]
 var row: Dictionary=result.rows[cursor] if not result.is_empty() else {"t":0,"valid":false,"visible":false}
 for k in range(planes.size()):
  var points=PackedVector2Array();var sat: Dictionary=planes[k]
  var period: float=TAU*sqrt(pow(Model.RE+sat.alt,3)/Model.MU)
  for j in range(181):points.append(project_point(Model.state(sat,j*period/180),center,scale_v))
  draw_polyline(points,Color(palette[k%8],0.60),1.5,true)
 var positions: Array=[]
 for sat in sats:positions.append(project_point(Model.state(sat,row.t),center,scale_v))
 if not network.is_empty():
  for k in range(network.links.size()):
   var link: Dictionary=network.links[k];var valid: bool=link.rows[cursor].valid
   if k==selected_link:continue
   draw_line(positions[link.source],positions[link.target],Color(palette[int(sats[link.source].plane)%8],0.25) if valid else Color(0.5,0.6,0.7,0.055),1.0,true)
  var link: Dictionary=network.links[selected_link]
  draw_dashed_line(positions[link.source],positions[link.target],Color("fff0ad") if row.valid else Color("f09182"),2.0,7,true)
 for k in range(sats.size()):
  var pos: Vector2=positions[k];var sat: Dictionary=sats[k];var color: Color=palette[int(sat.get("plane",k))%8]
  var highlight=not network.is_empty() and k in [network.links[selected_link].source,network.links[selected_link].target]
  draw_circle(pos,10 if highlight else 7,Color(color,0.13));draw_circle(pos,4 if highlight else 2.8,color)
  draw_line(pos+Vector2(-9,0),pos+Vector2(-5,0),color,2);draw_line(pos+Vector2(5,0),pos+Vector2(9,0),color,2)
  if size.x>650 or highlight:text_at(pos+Vector2(10,-7),sat.get("name","卫星"),color,10)
 var legend_x=20.0
 for k in range(planes.size()):
  if legend_x+80>size.x-16:break
  text_at(Vector2(legend_x,size.y-18),"● %02d面"%[k+1],palette[k%8],10);legend_x+=70
 text_at(Vector2(size.x-158,size.y-18),"拖动旋转 · 滚轮缩放",Color("8298b8"),10)

func chart_value(r: Dictionary) -> float:
 match chart:
  "range":return r.range/1000.0
  "error":return r.error
  "rate":return r.rate
  "photons":return log(r.photons+1.0)/log(10.0)
 return NAN

func draw_chart():
 draw_style_box(style(Color.WHITE,12),Rect2(Vector2.ZERO,size))
 var titles={"range":"星间几何距离 / km","error":"伪距残差 / m","rate":"几何距离率 / m·s⁻¹","photons":"探测光子数 / log₁₀(N+1)"}
 text_at(Vector2(20,27),titles.get(chart,chart),INK,13)
 if result.is_empty():text_at(Vector2(25,80),"运行仿真后显示数据",MUTED,13);return
 var rect=Rect2(67,49,max(size.x-92,1),max(size.y-82,1))
 var lo=INF
 var hi=-INF
 for r in result.rows:
  var v=chart_value(r)
  if is_finite(v):lo=min(lo,v);hi=max(hi,v)
 if not is_finite(lo):text_at(Vector2(25,85),"无有效测量，请检查可见性与链路参数。",MUTED,12);return
 var pad: float=max((hi-lo)*0.12,0.001 if chart=="error" else 1.0)
 lo-=pad;hi+=pad
 for j in range(5):
  var y=rect.position.y+rect.size.y*j/4.0
  draw_line(Vector2(rect.position.x,y),Vector2(rect.end.x,y),Color("eaf0f5"),1)
  text_at(Vector2(8,y+4),"%.2f"%(hi-(hi-lo)*j/4.0),MUTED,10)
  text_at(Vector2(rect.position.x+rect.size.x*j/4.0-10,rect.end.y+20),"%.1f"%(result.rows[-1].t/3600*j/4.0),MUTED,10)
 text_at(Vector2(size.x-35,size.y-12),"h",MUTED,10)
 var stride: int=max(1,int(result.count/max(rect.size.x*2,1)))
 var points=PackedVector2Array()
 for j in range(0,result.count,stride):
  if j>0 and chart=="error":
   for k in range(max(0,j-stride+1),j):
    if not result.rows[k].valid:
     paint_line(points);points=PackedVector2Array();break
  var v=chart_value(result.rows[j])
  if is_finite(v):points.append(Vector2(rect.position.x+rect.size.x*j/max(result.count-1,1),rect.end.y-(v-lo)/(hi-lo)*rect.size.y))
  else:paint_line(points);points=PackedVector2Array()
 paint_line(points)
 var cx: float=rect.position.x+rect.size.x*cursor/max(result.count-1,1)
 draw_line(Vector2(cx,rect.position.y),Vector2(cx,rect.end.y),Color("e2a448"),1.0)

func paint_line(points: PackedVector2Array):
 if points.size()>1:draw_polyline(points,TEAL if chart=="error" else BLUE,1.4,true)
 elif points.size()==1:draw_circle(points[0],2,TEAL)

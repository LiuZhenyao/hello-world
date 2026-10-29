extends Control
const Model=preload("res://model.gd")
const INK=Color("253750")
const MUTED=Color("7c8a9d")
const TEAL=Color("0f9d91")
const BLUE=Color("4285db")
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
 tooltip_text="拖动旋转轨道视图；滚轮缩放。曲线区域点击可定位时间。"

func _gui_input(event):
 if event is InputEventMouseButton:
  if event.button_index==MOUSE_BUTTON_LEFT:
   dragging=event.pressed
   if mode!="orbit" and event.pressed and not result.is_empty():
    seek.emit(clampi(int((event.position.x-65)/max(size.x-90,1)*(result.count-1)),0,result.count-1))
  if mode=="orbit" and event.pressed:
   if event.button_index==MOUSE_BUTTON_WHEEL_UP:zoom=clamp(zoom*1.1,0.6,2.2)
   if event.button_index==MOUSE_BUTTON_WHEEL_DOWN:zoom=clamp(zoom/1.1,0.6,2.2)
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
 for n in range(90):
  var pt=Vector2(fposmod(n*137.19+41,size.x),fposmod(n*83.73+19,size.y))
  draw_circle(pt,0.6 if n%3 else 1.1,Color(0.53,0.66,0.84,0.22))
 text_at(Vector2(24,29),"地心惯性空间",Color("dbe8ff"),14)
 text_at(Vector2(24,50),"双体传播 · 单向 甲 → 乙",Color("8298b8"),11)
 if parameters.is_empty():return
 var center=Vector2(size.x*0.5,size.y*0.53)
 var outer: float=max((6378.137+parameters.a.alt)*(1+parameters.a.ecc),(6378.137+parameters.b.alt)*(1+parameters.b.ecc))
 var scale_v: float=min(size.x*0.43,size.y*0.62)/outer*zoom
 var radius: float=6378.137*scale_v
 var eq=PackedVector2Array()
 for j in range(97):eq.append(project_point([outer*cos(j*TAU/96),outer*sin(j*TAU/96),0],center,scale_v))
 draw_polyline(eq,Color(0.34,0.48,0.66,0.18),1.0,true)
 draw_circle(center,radius+5,Color(0.12,0.46,0.76,0.1))
 draw_circle(center,radius,Color("204f7c"))
 draw_arc(center,radius,0,TAU,90,Color("4f83ac"),1.0,true)
 for k in [-0.6,0.0,0.6]:
  var line=PackedVector2Array()
  for j in range(65):
   var ang=j*TAU/64
   line.append(project_point([6378.137*sqrt(1-k*k)*cos(ang),6378.137*sqrt(1-k*k)*sin(ang),6378.137*k],center,scale_v))
  draw_polyline(line,Color(0.4,0.68,0.84,0.32),1,true)
 var colors=[Color("52e1c3"),Color("7caaff")]
 var sats=[parameters.a,parameters.b]
 var row: Dictionary=result.rows[cursor] if not result.is_empty() else {"t":0,"valid":false,"visible":false}
 var positions=[]
 for k in range(2):
  var points=PackedVector2Array()
  var period: float=TAU*sqrt(pow(6378.137+sats[k].alt,3)/398600.4418)
  for j in range(241):points.append(project_point(Model.state(sats[k],j*period/240),center,scale_v))
  draw_polyline(points,Color(colors[k],0.65),1.5,true)
  positions.append(project_point(Model.state(sats[k],row.t),center,scale_v))
 var link_color=Color("52e1c3") if row.valid else Color("c56e6e")
 draw_dashed_line(positions[0],positions[1],Color(link_color,0.65),1.5,7,true)
 for k in range(2):
  var pos: Vector2=positions[k]
  draw_circle(pos,12,Color(colors[k],0.12));draw_circle(pos,4.5,colors[k])
  draw_line(pos+Vector2(-11,0),pos+Vector2(-6,0),colors[k],3)
  draw_line(pos+Vector2(6,0),pos+Vector2(11,0),colors[k],3)
  text_at(pos+Vector2(14,-9),"卫星甲" if k==0 else "卫星乙",colors[k],12)
 text_at(Vector2(24,size.y-22),"● 卫星甲    发射端",colors[0],11)
 text_at(Vector2(170,size.y-22),"● 卫星乙    接收端",colors[1],11)
 text_at(Vector2(size.x-170,size.y-22),"拖动旋转 · 滚轮缩放",Color("8298b8"),10)

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

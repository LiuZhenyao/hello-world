extends Control
const Model=preload("res://model.gd")
const Visual=preload("res://visual.gd")
const Storage=preload("res://storage.gd")
const Report=preload("res://report.gd")
const NAVY=Color("101e35")
const INK=Color("243650")
const MUTED=Color("7c8a9d")
const TEAL=Color("008d80")
var params=Model.defaults()
var result: Dictionary={}
var fields: Dictionary={}
var thread: Thread
var cancel_requested=false
var busy=false
var dirty=false
var playing=false
var elapsed=0.0
var playback_time=0.0
var cursor=0
var pages: Array=[]
var nav_buttons: Array=[]
var cards: Array=[]
var content: VBoxContainer
var orbit: Control
var plot_a: Control
var plot_b: Control
var status: Label
var timeline: HSlider
var time_label: Label
var link_label: Label
var snapshot: RichTextLabel
var run_button: Button
var cancel_button: Button
var play_button: Button
var presets: OptionButton
var progress_bar: ProgressBar
var table: Tree
var window_text: RichTextLabel
var file_dialog: FileDialog
var file_action=""
var config_panel: VBoxContainer
var sample_label: Label
var page_title: Label
var notice: AcceptDialog
var table_page=0
var table_pager: Label
var speed: OptionButton
var last_folder=""

func box(color: Color,radius=10,border=Color.TRANSPARENT) -> StyleBoxFlat:
 var s=StyleBoxFlat.new();s.bg_color=color;s.set_corner_radius_all(radius);s.border_color=border
 s.set_border_width_all(1 if border.a>0 else 0)
 s.content_margin_left=14;s.content_margin_right=14;s.content_margin_top=9;s.content_margin_bottom=9
 return s
func label(txt: String,fs=14,col=INK) -> Label:
 var l=Label.new();l.text=txt;l.add_theme_font_size_override("font_size",fs);l.add_theme_color_override("font_color",col);return l
func button(txt: String,action: Callable,primary=false) -> Button:
 var b=Button.new();b.text=txt;b.custom_minimum_size.y=38;b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
 b.add_theme_stylebox_override("normal",box(TEAL if primary else Color.WHITE,7,Color.TRANSPARENT if primary else Color("dce4ec")))
 b.add_theme_stylebox_override("hover",box(Color("087b73") if primary else Color("e9f3f5"),7))
 b.add_theme_stylebox_override("pressed",box(Color("066b64") if primary else Color("dbe9ee"),7))
 b.add_theme_stylebox_override("disabled",box(Color("d7e0e7"),7))
 for state_name in ["font_color","font_hover_color","font_pressed_color"]:b.add_theme_color_override(state_name,Color.WHITE if primary else INK)
 b.add_theme_color_override("font_disabled_color",Color("74879b"));b.pressed.connect(action);return b
func hbox(gap=12) -> HBoxContainer:
 var b=HBoxContainer.new();b.add_theme_constant_override("separation",gap);return b
func vbox(gap=12) -> VBoxContainer:
 var b=VBoxContainer.new();b.add_theme_constant_override("separation",gap);return b
func expand(c: Control):c.size_flags_horizontal=Control.SIZE_EXPAND_FILL
func spacer(parent: Node):
 var c=Control.new();expand(c);parent.add_child(c)
func panel(child: Control,color=Color.WHITE) -> PanelContainer:
 var p=PanelContainer.new();p.add_theme_stylebox_override("panel",box(color,12));p.add_child(child);return p

func _ready():
 get_tree().auto_accept_quit=false
 DisplayServer.window_set_min_size(Vector2i(1180,760))
 var t=Theme.new();t.default_font=load("res://assets/ui.ttc");t.default_font_size=13
 t.set_color("font_color","Label",INK);t.set_color("font_color","LineEdit",INK)
 t.set_stylebox("normal","LineEdit",box(Color("f4f7fa"),6,Color("dce4ec")))
 t.set_stylebox("focus","LineEdit",box(Color.WHITE,6,TEAL))
 t.set_color("font_color","OptionButton",INK);t.set_stylebox("normal","OptionButton",box(Color("f4f7fa"),6,Color("dce4ec")))
 t.set_color("font_color","Tree",INK);t.set_color("font_selected_color","Tree",Color.WHITE)
 t.set_stylebox("panel","Tree",box(Color.WHITE,6,Color("e0e7ef")));theme=t
 var bg=ColorRect.new();bg.color=Color("f1f5f9");bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(bg)
 var root=hbox(0);root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(root);build_sidebar(root)
 var margin=MarginContainer.new();expand(margin);margin.size_flags_vertical=Control.SIZE_EXPAND_FILL
 for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,22)
 root.add_child(margin)
 var main=vbox(15);margin.add_child(main);build_header(main)
 var workspace=hbox(18);workspace.size_flags_vertical=Control.SIZE_EXPAND_FILL;main.add_child(workspace)
 content=vbox(12);expand(content);workspace.add_child(content)
 build_overview();build_data_page();build_method_page();build_config(workspace)
 var foot=hbox();main.add_child(foot);status=label("就绪 · 本地计算，数据不上传",11,MUTED);foot.add_child(status);spacer(foot)
 foot.add_child(label("地心惯性坐标    |    版本 1.0",11,MUTED))
 notice=AcceptDialog.new();notice.title="卫星轨道模拟仿真教学软件";notice.min_size=Vector2i(480,170);add_child(notice)
 file_dialog=FileDialog.new();file_dialog.access=FileDialog.ACCESS_FILESYSTEM;file_dialog.use_native_dialog=true
 file_dialog.file_selected.connect(on_file);add_child(file_dialog)
 if DirAccess.dir_exists_absolute(OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)):last_folder=OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
 set_page(0);start_run()

func build_sidebar(root: HBoxContainer):
 var body=vbox(10);var side=panel(body,NAVY);side.custom_minimum_size.x=174;root.add_child(side)
 body.add_child(label("卫星轨道模拟\n仿真教学软件",20,Color.WHITE))
 body.add_child(label("轨道与星间激光测量",11,Color("92a8c7")))
 var gap=Control.new();gap.custom_minimum_size.y=34;body.add_child(gap)
 for i in range(3):
  var b=button(["◉   仿真工作台","▤   测量数据","◇   模型与说明"][i],set_page.bind(i))
  b.alignment=HORIZONTAL_ALIGNMENT_LEFT;body.add_child(b);nav_buttons.append(b)
 var flex=Control.new();flex.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(flex)
 body.add_child(label("全离线 · 可复现实验",11,Color("8fa8c6")))
 body.add_child(label("低轨  →  中轨  →  同步轨道",10,Color("6c88ae")))
 body.add_child(label("工程分析工具 / v1.0",10,Color("6c88ae")))

func build_header(main: VBoxContainer):
 var row=hbox();main.add_child(row);var titles=vbox(2);row.add_child(titles)
 page_title=label("卫星轨道模拟仿真教学软件",25);titles.add_child(page_title)
 titles.add_child(label("从轨道几何到测量数据，构建可复现的星间链路实验。",12,MUTED))
 spacer(row);row.add_child(button("打开场景",open_dialog.bind("load")));row.add_child(button("保存场景",open_dialog.bind("save")))
 row.add_child(button("导出结果",open_dialog.bind("csv"),true))

func build_overview():
 var page=vbox(12);page.size_flags_vertical=Control.SIZE_EXPAND_FILL;content.add_child(page);pages.append(page)
 var kpis=hbox(10);page.add_child(kpis)
 for title in ["有效测量占比","星间距离 / km","残差均方根","有效采样点"]:
  var col=vbox(4);col.add_child(label(title,11,MUTED));var value=label("—",21);col.add_child(value);cards.append(value)
  var pc=panel(col);expand(pc);kpis.add_child(pc)
 var viewport_row=hbox(12);viewport_row.size_flags_vertical=Control.SIZE_EXPAND_FILL;page.add_child(viewport_row)
 orbit=Visual.new();orbit.mode="orbit";orbit.parameters=params;orbit.custom_minimum_size=Vector2(320,255)
 expand(orbit);orbit.size_flags_vertical=Control.SIZE_EXPAND_FILL;viewport_row.add_child(orbit)
 var details=vbox(13);details.custom_minimum_size.x=160
 var pc=panel(details);pc.custom_minimum_size.x=184;viewport_row.add_child(pc)
 details.add_child(label("链路快照",14));link_label=label("计算中…",12,TEAL);details.add_child(link_label)
 time_label=label("T + 00:00:00",16);details.add_child(time_label)
 snapshot=RichTextLabel.new();snapshot.bbcode_enabled=true;snapshot.fit_content=true;snapshot.custom_minimum_size.y=142
 snapshot.add_theme_color_override("default_color",INK);snapshot.add_theme_font_size_override("normal_font_size",12);details.add_child(snapshot)
 details.add_child(label("轨道视图按比例绘制",10,MUTED))
 var plots=hbox(12);plots.custom_minimum_size.y=210;plots.size_flags_vertical=Control.SIZE_EXPAND_FILL;page.add_child(plots)
 plot_a=Visual.new();plot_a.mode="chart";plot_a.chart="range";expand(plot_a);plot_a.seek.connect(seek_time);plots.add_child(plot_a)
 plot_b=Visual.new();plot_b.mode="chart";plot_b.chart="error";expand(plot_b);plot_b.seek.connect(seek_time);plots.add_child(plot_b)
 var controls=hbox(9);page.add_child(controls);play_button=button("▶ 回放",toggle_play);controls.add_child(play_button)
 timeline=HSlider.new();timeline.max_value=1;timeline.step=1;expand(timeline);timeline.value_changed.connect(func(v):seek_time(int(v)));controls.add_child(timeline)
 speed=OptionButton.new()
 for s in ["×1","×10","×60","×300"]:speed.add_item(s)
 speed.selected=2;controls.add_child(speed)
 var charts=OptionButton.new()
 for s in ["距离 / 残差","距离率 / 光子数"]:charts.add_item(s)
 charts.item_selected.connect(change_charts);controls.add_child(charts)

func change_charts(index: int):
 plot_a.chart="range" if index==0 else "rate";plot_b.chart="error" if index==0 else "photons"
 plot_a.queue_redraw();plot_b.queue_redraw()

func build_data_page():
 var page=vbox(12);page.size_flags_vertical=Control.SIZE_EXPAND_FILL;content.add_child(page);pages.append(page)
 var heading=hbox();page.add_child(heading);heading.add_child(label("测量数据集",20));spacer(heading)
 heading.add_child(button("导出 CSV",open_dialog.bind("csv"),true));heading.add_child(button("分析报告",open_dialog.bind("report")))
 page.add_child(label("无效测量用 — 表示；CSV 留空。残差相对于光行时修正后的路径长度。",12,MUTED))
 table=Tree.new();table.columns=8;table.hide_root=true;table.column_titles_visible=true
 var names=["时间 / s","距离 / km","距离率 / m/s","光行时 / ms","链路","光子数","伪距 / km","残差 / m"]
 for i in range(8):table.set_column_title(i,names[i]);table.set_column_custom_minimum_width(i,95)
 table.size_flags_vertical=Control.SIZE_EXPAND_FILL;page.add_child(table)
 table.item_selected.connect(func():
  var item=table.get_selected()
  if item!=null:seek_time(int(item.get_metadata(0)))
 )
 var paging=hbox();page.add_child(paging);paging.add_child(button("上一页",change_table_page.bind(-1)))
 table_pager=label("—",12,MUTED);paging.add_child(table_pager);paging.add_child(button("下一页",change_table_page.bind(1)));spacer(paging)
 window_text=RichTextLabel.new();window_text.bbcode_enabled=true;window_text.custom_minimum_size.y=145
 window_text.add_theme_color_override("default_color",INK);page.add_child(panel(window_text))

func build_method_page():
 var sc=ScrollContainer.new();sc.size_flags_vertical=Control.SIZE_EXPAND_FILL;content.add_child(sc);pages.append(sc)
 var body=vbox(14);expand(body);sc.add_child(body);body.add_child(label("模型、单位与适用范围",23))
 var sections=[
 ["01  轨道传播","WGS-84 赤道半径 6378.137 km，引力常数 μ = 398600.4418 km³/s²。开普勒方程双体椭圆轨道传播，统一采用地心惯性坐标系 ECI。高度为半长轴减地球半径；初始相位为 t = 0 的平近点角。RAAN、近地点幅角和倾角以度表示。场景时间为相对历元，不映射具体 UTC。"],
 ["02  单向激光测量","卫星甲在 t 发射，卫星乙在 t + τ 接收。迭代求解 τ = |rB(t+τ) − rA(t)| / c 得到光行时路径。几何距离及距离率使用同一时刻的位置与速度。地球遮挡以发射至接收位置的线段与球形地球相交判定。轨道视图为同一时刻的轨道位置示意，不作为光行时路径图。"],
 ["03  链路与光子预算","高斯远场光斑 w = R·θ，θ 为 1/e² 强度半角。接收口径截获比例 1 − exp[−2(D/2w)²]。等效固定指向损耗 exp[−2(j/θ)²]，j 为输入的 RMS 指向角工程近似。总效率包含光学与探测效率。光子数 N = Pr·min(采样步长, 1 s)/(hc/λ)。无遮挡且 N 达到门限时记录有效测量。假定理想捕获跟踪，不建模捕获视场与终端转动限制。"],
 ["04  测量噪声与偏差","单向伪距 = 光行时路径 + 固定偏差 + c·时钟偏差 + 高斯白噪声。噪声标准差 sqrt[σ₀² + (c·σt/√N)²]，σt 为等效单光子定时抖动。这里不使用双程测距的 1/2 因子。残差相对于光行时路径；RMS 包含系统偏差。固定随机种子可复现相同数据，仅有效测量参与误差统计。"],
 ["05  数据与复现","场景 JSON 保存完整输入参数和模型版本；CSV 使用 UTF-8 BOM 和 SI 单位，便于 Excel、Python 或 MATLAB 读取。独立 HTML 报告包含参数、统计、曲线和有效采样窗口。窗口端点是有效采样时刻，不是连续可见性的精确边界。所有计算和导出均在本地完成。"],
 ["06  使用边界","适用于概念设计、链路趋势和测量算法输入研究。不含 J2/高阶引力、第三体、太阳辐射压、相对论、精密星历、姿态动力学、背景光、接收机饱和、热漂移和大气效应。工程定型或高精度任务分析需要经验证的高保真工具与实测参数。数值验证不代表航天工程认证。"]]
 for section in sections:
  var col=vbox(8);col.add_child(label(section[0],16))
  var desc=label(section[1],13,MUTED);desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;col.add_child(desc)
  var pc=panel(col);expand(pc);body.add_child(pc)
 body.add_child(button("导出当前分析报告",open_dialog.bind("report")));body.add_child(button("关于与第三方许可",show_licenses))

func build_config(workspace: HBoxContainer):
 var col=vbox(10);col.custom_minimum_size.x=292;var pc=panel(col);pc.custom_minimum_size.x=320;workspace.add_child(pc)
 col.add_child(label("场景配置",18));presets=OptionButton.new()
 for s in ["低轨 → 同步轨道 · 跨高度链路","低轨 → 低轨 · 同轨编队","同步轨道 → 同步轨道"]:presets.add_item(s)
 presets.item_selected.connect(apply_preset);col.add_child(presets)
 var scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;col.add_child(scroll)
 config_panel=vbox(9);expand(config_panel);scroll.add_child(config_panel)
 for sat in ["a","b"]:
  config_panel.add_child(label("卫星"+("甲" if sat=="a" else "乙")+("  /  发射端" if sat=="a" else "  /  接收端"),13,TEAL))
  add_field(sat+".alt","半长轴高度","km",160,35786,1,params[sat].alt)
  add_field(sat+".ecc","偏心率","",0,0.5,0.0001,params[sat].ecc)
  add_field(sat+".inc","轨道倾角","°",0,180,0.1,params[sat].inc)
  add_field(sat+".raan","升交点赤经","°",0,360,0.1,params[sat].raan)
  add_field(sat+".arg","近地点幅角","°",0,360,0.1,params[sat].arg)
  add_field(sat+".phase","初始平近点角","°",0,360,0.1,params[sat].phase)
 config_panel.add_child(label("采样与激光链路",13,TEAL))
 add_field("hours","仿真时长","h",0.01,48,0.01,params.hours)
 add_field("step","采样步长","s",0.1,3600,0.1,params.step)
 add_field("power","发射功率","W",0.001,100,0.001,params.power)
 add_field("wave","激光波长","nm",400,2000,1,params.wave)
 add_field("aperture","接收口径","m",0.01,2,0.01,params.aperture)
 add_field("divergence","光束半角","μrad",0.1,1000,0.1,params.divergence)
 add_field("jitter","均方根指向角","μrad",0,1000,0.1,params.jitter)
 add_field("efficiency","总探测效率","",0.001,1,0.001,params.efficiency)
 add_field("threshold","光子数门限","",1,1e12,1,params.threshold)
 config_panel.add_child(label("测量噪声与偏差",13,TEAL))
 add_field("sigma","测距噪声底","m",0,100,0.001,params.sigma)
 add_field("timing","单光子定时抖动","ps",0,10000,1,params.timing)
 add_field("bias","固定测距偏差","m",-10000,10000,0.01,params.bias)
 add_field("clock","接收时钟偏差","ns",-100000,100000,0.01,params.clock)
 add_field("seed","随机种子","",0,2147483647,1,params.seed)
 sample_label=label("最多 50,000 点 / 次",11,MUTED);col.add_child(sample_label)
 progress_bar=ProgressBar.new();progress_bar.custom_minimum_size.y=5;progress_bar.show_percentage=false;progress_bar.max_value=1;col.add_child(progress_bar)
 var actions=hbox(8);col.add_child(actions);run_button=button("▶  运行仿真",start_run,true);expand(run_button);actions.add_child(run_button)
 cancel_button=button("取消",func():cancel_requested=true);cancel_button.disabled=true;actions.add_child(cancel_button)

func add_field(key: String,title: String,unit: String,low: float,high: float,increment: float,value: float):
 var row=hbox(4);config_panel.add_child(row);var l=label(title+(" / "+unit if unit!="" else ""),11);expand(l);row.add_child(l)
 var spin=SpinBox.new();spin.min_value=low;spin.max_value=high;spin.step=increment;spin.value=value;spin.custom_minimum_size.x=112;spin.alignment=HORIZONTAL_ALIGNMENT_RIGHT
 spin.tooltip_text="范围：%s ～ %s %s"%[str(low),str(high),unit];spin.get_line_edit().add_theme_font_size_override("font_size",12)
 row.add_child(spin);fields[key]=spin
 spin.value_changed.connect(func(_v):dirty=true;if_status("参数已修改 · 点击运行以更新结果"))

func if_status(text: String):
 if status!=null:status.text=text

func read_fields() -> Dictionary:
 var p=Model.defaults()
 for key in fields:
  fields[key].apply()
  if "." in key:
   var parts=key.split(".");p[parts[0]][parts[1]]=fields[key].value
  else:p[key]=fields[key].value
 p.seed=int(p.seed);return p

func write_fields(p: Dictionary):
 for key in fields:
  if "." in key:
   var parts=key.split(".");fields[key].value=p[parts[0]][parts[1]]
  else:fields[key].value=p[key]
  # SpinBox updates its display deferred; synchronize text before a same-frame Run.
  fields[key].get_line_edit().text=str(fields[key].value)
 dirty=true;status.text="场景已载入 · 点击运行以更新结果"

func apply_preset(index: int):write_fields(Model.preset(index))

func set_page(index: int):
 for j in range(pages.size()):pages[j].visible=j==index
 for j in range(nav_buttons.size()):
  nav_buttons[j].add_theme_stylebox_override("normal",box(Color("233e58") if j==index else NAVY,7))
  nav_buttons[j].add_theme_color_override("font_color",Color("69dfc8") if j==index else Color("9fb3cf"))
 if page_title!=null:page_title.text=["卫星轨道模拟仿真教学软件","测量数据与分析","模型与使用说明"][index]

func set_busy(value: bool):
 busy=value;run_button.disabled=value;cancel_button.disabled=not value;presets.disabled=value
 for spin in fields.values():spin.editable=not value

func start_run():
 if busy:return
 var p=read_fields();var err=Model.validate(p)
 if err!="":message(err);return
 params=p;set_busy(true);cancel_requested=false;playing=false;play_button.text="▶ 回放"
 status.text="正在计算轨道、光行时和激光测量…";progress_bar.value=0;thread=Thread.new()
 var code=thread.start(func():
  var computed=Model.run(p,func(v):update_progress.call_deferred(v),func():return cancel_requested)
  finish_run.call_deferred(computed)
 )
 if code!=OK:finish_run({"error":"无法启动计算线程。"})

func update_progress(value: float):progress_bar.value=value

func finish_run(computed: Dictionary):
 if thread!=null and thread.is_started():thread.wait_to_finish()
 set_busy(false)
 if computed.has("cancelled"):status.text="仿真已取消 · 保留上一次结果";progress_bar.value=0;return
 if computed.has("error"):status.text="仿真失败";message(computed.error);return
 result=computed;dirty=false;cursor=0;playback_time=0;table_page=0;progress_bar.value=1
 orbit.result=result;orbit.parameters=result.params;plot_a.result=result;plot_b.result=result
 timeline.max_value=result.count-1;timeline.set_value_no_signal(0)
 cards[0].text="%.1f %%"%(100.0*result.valid/result.count)
 cards[1].text="%.0f–%.0f"%[result.min_range/1000,result.max_range/1000];cards[1].tooltip_text="几何距离范围，单位 km"
 cards[2].text="%.4f m"%result.rms if result.valid>0 else "无有效链路";cards[3].text="%d / %d"%[result.valid,result.count]
 sample_label.text="%d 个采样点 · %.1f h"%[result.count,result.params.hours]
 status.text="计算完成 · %d 点 / %d 个有效窗口 · 种子 %d"%[result.count,result.windows.size(),result.params.seed]
 if result.valid==0:status.text+=" · 请检查遮挡、功率与门限"
 refresh_cursor();refresh_table();refresh_windows()
 if "--smoke-test" in OS.get_cmdline_user_args():complete_smoke_test()

func seek_time(index: int,from_playback=false):
 if result.is_empty():return
 cursor=clampi(index,0,result.count-1)
 if not from_playback:playback_time=result.rows[cursor].t
 timeline.set_value_no_signal(cursor);refresh_cursor()

func scientific(value: float) -> String:
 if value==0:return "0"
 var exponent: int=int(floor(log(abs(value))/log(10.0)))
 return "%.2f × 10^%d"%[value/pow(10.0,exponent),exponent]

func refresh_cursor():
 if result.is_empty():return
 var r: Dictionary=result.rows[cursor]
 orbit.cursor=cursor;plot_a.cursor=cursor;plot_b.cursor=cursor;orbit.queue_redraw();plot_a.queue_redraw();plot_b.queue_redraw()
 var seconds=int(r.t);time_label.text="T + %02d:%02d:%02d"%[seconds/3600,(seconds/60)%60,seconds%60]
 link_label.text="● 链路有效" if r.valid else ("● 光子数低于门限" if r.visible else "● 地球遮挡 / 重合")
 link_label.add_theme_color_override("font_color",TEAL if r.valid else Color("bf7942"))
 snapshot.text="[color=#7c8a9d]几何距离[/color]\n%.3f km\n\n[color=#7c8a9d]单向光行时[/color]\n%.3f ms\n\n[color=#7c8a9d]接收功率 / 探测光子数[/color]\n%s W\n%s"%[r.range/1000,r.delay,scientific(r.power),scientific(r.photons)]

func toggle_play():
 if result.is_empty() or busy:return
 playing=not playing;elapsed=0
 if playing:
  if cursor>=result.count-1:seek_time(0)
  playback_time=result.rows[cursor].t
 play_button.text="Ⅱ 暂停" if playing else "▶ 回放"

func _process(dt: float):
 if not playing or result.is_empty():return
 elapsed+=dt
 if elapsed<0.05:return
 playback_time+=elapsed*[1.0,10.0,60.0,300.0][speed.selected];elapsed=0
 var index: int=min(int(playback_time/result.params.step),result.count-1)
 if index!=cursor:seek_time(index,true)
 if cursor==result.count-1:playing=false;play_button.text="▶ 回放"

func change_table_page(delta: int):
 if result.is_empty():return
 table_page=clampi(table_page+delta,0,int((result.count-1)/250));refresh_table()

func refresh_table():
 table.clear()
 if result.is_empty():return
 var root=table.create_item();var start=table_page*250
 for j in range(start,min(start+250,result.count)):
  var r: Dictionary=result.rows[j];var item=table.create_item(root);item.set_metadata(0,j)
  var cells=["%.1f"%r.t,"%.3f"%(r.range/1000),"%.3f"%r.rate,"%.6f"%r.delay,"有效" if r.valid else ("低光子" if r.visible else "遮挡"),scientific(r.photons),"%.6f"%(r.measured/1000) if r.valid else "—","%.6f"%r.error if r.valid else "—"]
  for k in range(8):item.set_text(k,cells[k]);item.set_custom_color(k,INK if r.valid else MUTED)
 table_pager.text="第 %d / %d 页 · 共 %d 行"%[table_page+1,int(ceil(result.count/250.0)),result.count]

func refresh_windows():
 var text="[b]有效采样窗口[/b]  ·  %d 段\n"%result.windows.size()
 if result.windows.is_empty():text+="本场景无有效链路，请检查轨道相位、地球遮挡和链路预算。"
 for j in range(min(result.windows.size(),80)):
  var w=result.windows[j];text+="%02d   T + %.1f s  →  %.1f s    |    端点间隔 %.1f s\n"%[j+1,w[0],w[1],w[1]-w[0]]
 if result.windows.size()>80:text+="其余窗口请在分析报告中查看。"
 window_text.text=text

func message(text: String):notice.dialog_text=text;notice.popup_centered()

func open_dialog(action: String):
 if busy:message("请等待计算完成或取消计算后再操作。");return
 if action in ["csv","report"] and result.is_empty():message("请先运行仿真。");return
 file_action=action;file_dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE if action=="load" else FileDialog.FILE_MODE_SAVE_FILE
 var extension="json" if action in ["load","save"] else ("csv" if action=="csv" else "html")
 file_dialog.filters=PackedStringArray(["*."+extension+" ; "+extension.to_upper()+" 文件"])
 file_dialog.title={"load":"打开场景","save":"保存场景参数","csv":"导出当前计算结果","report":"导出分析报告"}[action]
 if last_folder!="":file_dialog.current_dir=last_folder
 if action!="load":file_dialog.current_file="卫星轨道模拟仿真_"+Time.get_datetime_string_from_system().replace(":","-")+"."+extension
 file_dialog.popup_centered_ratio(0.7)

func on_file(path: String):
 last_folder=path.get_base_dir()
 if file_action=="load":
  var loaded=Storage.load_scenario(path)
  if loaded.has("error"):message(loaded.error)
  else:write_fields(loaded.params)
  return
 var text=""
 if file_action=="save":
  var p=read_fields();var err=Model.validate(p)
  if err!="":message(err);return
  text=Storage.scenario_json(p)
 elif file_action=="csv":text=Model.csv(result)
 elif file_action=="report":text=Report.html(result)
 else:message("未知的文件操作。");return
 var err=Storage.write_text(path,text)
 if err!="":message(err);return
 status.text="已保存："+path+(" · 导出的是上次计算结果" if dirty and file_action!="save" else "")

func show_licenses():
 var dialog=AcceptDialog.new();dialog.title="卫星轨道模拟仿真教学软件 · 第三方组件许可";dialog.min_size=Vector2i(800,600)
 var text_view=RichTextLabel.new();text_view.custom_minimum_size=Vector2(760,500);text_view.add_theme_color_override("default_color",INK)
 text_view.add_theme_font_size_override("normal_font_size",12)
 var text="卫星轨道模拟仿真教学软件 版本 1.0\n离线星间激光测量仿真工具\n\n"
 for path in ["res://licenses/Godot-LICENSE.txt","res://licenses/Godot-COPYRIGHT.txt","res://licenses/Noto-CJK-copyright.txt"]:
  if FileAccess.file_exists(path):text+="\n"+path.get_file()+"\n"+FileAccess.get_file_as_string(path)+"\n"
 text_view.text=text;dialog.add_child(text_view);dialog.close_requested.connect(dialog.queue_free);dialog.confirmed.connect(dialog.queue_free)
 add_child(dialog);dialog.popup_centered()

func complete_smoke_test():
 var ok=result.count==2161 and result.valid==1355 and result.rms>0.015 and result.rms<0.025
 var path="user://smoke-test.json"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--smoke-test-output="):path=arg.trim_prefix("--smoke-test-output=")
 var data={"passed":ok,"platform":OS.get_name(),"count":result.count,"valid":result.valid,"rms_m":result.rms,"model":"two-body-one-way-v1"}
 var err=Storage.write_text(path,JSON.stringify(data,"  "))
 print("ORBITLASER_SMOKE_TEST ","PASS" if ok and err=="" else "FAIL", " ",JSON.stringify(data))
 get_tree().quit(0 if ok and err=="" else 1)

func _notification(what):
 if what==NOTIFICATION_WM_CLOSE_REQUEST:
  cancel_requested=true
  if thread!=null and thread.is_started():thread.wait_to_finish()
  get_tree().quit()

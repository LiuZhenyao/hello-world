extends RefCounted
static func number(v: float) -> String:
 return "%.6f"%v if is_finite(v) else "无有效测量"

static func svg(result: Dictionary,key: String) -> String:
 var lo=INF
 var hi=-INF
 for r in result.rows:
  var v: float=r.range/1000.0 if key=="range" else r.error
  if is_finite(v):lo=min(lo,v);hi=max(hi,v)
 if not is_finite(lo):return "<p>无有效测量。</p>"
 var pad: float=max((hi-lo)*0.1,0.001);lo-=pad;hi+=pad
 var out="<svg viewBox='0 0 960 240' role='img' aria-label='仿真结果曲线'><text x='8' y='20' font-size='12'>%.4f</text><text x='8' y='207' font-size='12'>%.4f</text><text x='65' y='232' font-size='12'>0 h</text><text x='850' y='232' font-size='12'>%.2f h</text><path d='M65 25V210H940' fill='none' stroke='#ccd5df'/>"%[hi,lo,result.rows[-1].t/3600]
 var path=""
 var active=false
 var stride: int=max(1,int(result.count/1600))
 for j in range(0,result.count,stride):
  var r: Dictionary=result.rows[j]
  var v: float=r.range/1000.0 if key=="range" else r.error
  # Do not connect through invalid samples even when the view is decimated.
  if j>0 and key=="error":
   for k in range(max(0,j-stride+1),j):
    if not result.rows[k].valid:active=false;break
  if is_finite(v):
   path+=("L" if active else "M")+"%.2f %.2f "%[65+875.0*j/max(result.count-1,1),210-(v-lo)/(hi-lo)*185]
   active=true
  else:active=false
 return out+"<path d='"+path+"' fill='none' stroke='#008d80' stroke-width='1.3'/></svg>"

static func html(result: Dictionary) -> String:
 var p: Dictionary=result.params
 var out="<!doctype html><html lang='zh-CN'><meta charset='utf-8'><title>卫星轨道模拟仿真教学软件 · 分析报告</title><style>body{font:15px system-ui,sans-serif;color:#243650;max-width:1000px;margin:50px auto;padding:20px;background:#f5f8fb}h1{color:#008d80}table{border-collapse:collapse;width:100%;background:white}td,th{padding:10px;border:1px solid #dae2eb;text-align:left}pre{white-space:pre-wrap;background:white;padding:20px}.tag{color:#7c8a9d}svg{background:white;border-radius:12px}</style><h1>卫星轨道模拟仿真教学软件</h1><h2>星间激光测量仿真分析报告</h2><p class='tag'>模型：双体轨道 / 单向星间测量 / 相对历元 · 软件版本 2.0.0</p>"
 out+="<table><tr><th>总采样</th><th>有效测量</th><th>占比</th><th>残差均值 / m</th><th>残差均方根 / m</th><th>残差标准差 / m</th></tr><tr><td>%d</td><td>%d</td><td>%.2f%%</td><td>%s</td><td>%s</td><td>%s</td></tr></table>"%[result.count,result.valid,100.0*result.valid/result.count,number(result.mean),number(result.rms),number(result.stddev)]
 out+="<p>几何距离 %.3f–%.3f km；距离率 %.3f–%.3f m/s。无遮挡采样 %d 点。</p>"%[result.min_range/1000,result.max_range/1000,result.min_rate,result.max_rate,result.visible]
 out+="<h2>轨道输入</h2><table><tr><th>卫星</th><th>半长轴高度 / km</th><th>偏心率</th><th>倾角 / °</th><th>升交点赤经 / °</th><th>近地点幅角 / °</th><th>平近点角 / °</th></tr>"
 for sat in ["a","b"]:
  var s: Dictionary=p[sat]
  out+="<tr><td>%s</td><td>%.3f</td><td>%.6f</td><td>%.3f</td><td>%.3f</td><td>%.3f</td><td>%.3f</td></tr>"%[p.get("a",{}).get("name","发射星") if sat=="a" else p.get("b",{}).get("name","接收星"),s.alt,s.ecc,s.inc,s.raan,s.arg,s.phase]
 out+="</table><h2>距离变化 / km</h2>"+svg(result,"range")+"<h2>有效测量残差 / m</h2>"+svg(result,"error")
 out+="<h2>有效采样窗口</h2><table><tr><th>窗口</th><th>起始 / s</th><th>结束 / s</th><th>端点间隔 / s</th></tr>"
 for j in range(result.windows.size()):
  var w=result.windows[j];out+="<tr><td>%d</td><td>%.3f</td><td>%.3f</td><td>%.3f</td></tr>"%[j+1,w[0],w[1],w[1]-w[0]]
 var safe=JSON.stringify(p,"  ").xml_escape()
 out+="</table><h2>完整参数</h2><p>单位：hours=h，step=s，power=W，wave=nm，aperture=m，divergence/jitter=μrad，sigma/bias=m，timing=ps，clock=ns。</p><pre>"+safe+"</pre>"
 out+="<h2>解释与限制</h2><p>伪距 = 光行时路径 + 固定偏差 + c·时钟偏差 + 高斯噪声。残差相对于修正路径；RMS 包含系统偏差。积分时间 min(采样步长, 1 s)。无效采样不参与误差统计，图中保留断点。</p><p>球形地球遮挡与理想捕获跟踪。不含 J2、第三体、相对论、背景光、姿态动态、接收机饱和与大气效应。仅用于概念设计及算法数据研究，不能替代高精度定轨或工程认证。窗口仅反映采样端点。</p></html>"
 return out

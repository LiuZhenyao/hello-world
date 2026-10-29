extends RefCounted
const Model=preload("res://model.gd")
static func scenario_json(p: Dictionary) -> String:
 return JSON.stringify({"schema":"orbitlaser.scenario.v1","model":"two-body-one-way-v1","parameters":p},"  ")

static func parse_scenario(text: String) -> Dictionary:
 var decoder=JSON.new()
 if decoder.parse(text)!=OK:return {"error":"JSON 格式错误："+decoder.get_error_message()}
 var parsed=decoder.data
 if not parsed is Dictionary or parsed.get("schema","")!="orbitlaser.scenario.v1" or not parsed.get("parameters") is Dictionary:
  return {"error":"场景格式不受支持。请选择本软件保存的 JSON 场景。"}
 var err=Model.validate(parsed.parameters)
 if err!="":return {"error":err}
 parsed.parameters.seed=int(parsed.parameters.seed)
 return {"params":parsed.parameters}

static func load_scenario(path: String) -> Dictionary:
 var f=FileAccess.open(path,FileAccess.READ)
 if f==null:return {"error":"无法读取场景："+error_string(FileAccess.get_open_error())}
 if f.get_length()>1024*1024:return {"error":"场景文件过大，请选择有效的参数 JSON。"}
 return parse_scenario(f.get_as_text())

static func write_text(path: String,text: String) -> String:
 # Verify write completion before closing; native save dialog handles overwrite confirmation.
 var f=FileAccess.open(path,FileAccess.WRITE)
 if f==null:return "无法写入："+error_string(FileAccess.get_open_error())
 f.store_string(text);f.flush()
 var err=f.get_error()
 f.close()
 return "" if err==OK else "写入失败，请检查磁盘空间和文件权限："+error_string(err)

extends SceneTree
var checks=0
var failures=0
var output_dir=""
func _initialize():
 output_dir=ProjectSettings.globalize_path("res://../build/validation")
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output_dir=arg.trim_prefix("--output=")
 DirAccess.make_dir_recursive_absolute(output_dir)
 call_deferred("run_tests")
func verify(ok: bool,description: String):
 checks+=1;print(("PASS " if ok else "FAIL ")+description)
 if not ok:failures+=1
func settle():
 for i in range(4):await process_frame
func screenshot(name: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output_dir.path_join(name))
func run_tests():
 var scene=load("res://main.tscn").instantiate();root.add_child(scene)
 while scene.busy:await process_frame
 await settle()
 verify(scene.result.count==2161 and scene.result.valid==1355,"startup computes full LEO-GEO scenario")
 verify(scene.table.get_root().get_child_count()==250,"measurement table populated")
 verify(scene.orbit.size.x>=300 and scene.orbit.size.y>=200,"orbit layout dimensions")
 verify(scene.network.satellites.size()==11 and scene.network.links.size()==22,"startup evaluates multi-plane network")
 verify(scene.plane_configs.size()==3 and scene.network_table.get_root().get_child_count()==22,"constellation controls and network statistics populated")
 scene.select_link(1)
 verify(scene.result==scene.network.links[1] and scene.plot_a.result==scene.result and scene.orbit.selected_link==1,"selecting another link updates data chart and orbit together")
 scene.select_link(0)
 scene.add_plane();verify(scene.plane_configs.size()==4,"add an orbital plane")
 scene.plane_fields.alt.value=1500;scene.plane_fields.count.value=5
 verify(scene.read_fields().planes[3].alt==1500 and scene.read_fields().planes[3].count==5,"edit independent plane altitude and satellite count")
 scene.remove_plane();verify(scene.plane_configs.size()==3,"remove selected plane")
 scene.topology.select(1);verify(scene.read_fields().topology==1,"full mesh selection captured in scenario")
 scene.topology.select(0)
 var report=scene.Report.html(scene.result)
 verify(report.contains("<svg") and not report.contains("nan"),"report has charts and finite summary")
 scene.seek_time(100)
 verify(scene.cursor==100 and scene.timeline.value==100,"timeline selection")
 scene.toggle_play();scene._process(1.0)
 verify(scene.cursor>100,"playback advances simulation time")
 scene.toggle_play();scene.seek_time(35)
 scene.change_charts(1)
 verify(scene.plot_a.chart=="rate" and scene.plot_b.chart=="photons","distance-rate and photon chart selection")
 await settle();scene.change_charts(0)
 scene.set_page(1)
 verify(scene.pages[1].visible and not scene.pages[0].visible,"data navigation")
 scene.change_table_page(1)
 verify(scene.table_page==1 and int(scene.table.get_root().get_first_child().get_metadata(0))==250,"next data page")
 scene.set_page(2);verify(scene.pages[2].visible,"model navigation")
 scene.apply_preset(1);scene.start_run()
 while scene.busy:await process_frame
 verify(scene.network.params.planes.size()==3 and scene.result.params.b.alt==550 and scene.network.valid>0,"LEO-LEO preset applies and runs")
 scene.apply_preset(2);scene.start_run()
 while scene.busy:await process_frame
 verify(scene.result.params.a.alt==35786 and scene.result.params.b.alt==35786 and scene.result.count==1441 and scene.network.valid>0,"GEO-GEO preset applies and runs")
 scene.apply_preset(0);scene.start_run()
 while scene.busy:await process_frame
 var retained=scene.result
 var long_p=scene.Model.defaults();long_p.hours=6;long_p.step=10
 scene.write_fields(long_p);scene.start_run();scene.cancel_requested=true
 while scene.busy:await process_frame
 verify(scene.result==retained and not scene.run_button.disabled,"cancel preserves previous result and restores controls")
 scene.apply_preset(0);scene.start_run()
 while scene.busy:await process_frame
 scene.file_action="save"
 scene.on_file(output_dir.path_join("LEO-GEO.json"))
 verify(FileAccess.file_exists(output_dir.path_join("LEO-GEO.json")),"UI saves complete scenario")
 scene.apply_preset(2);scene.file_action="load";scene.on_file(output_dir.path_join("LEO-GEO.json"))
 verify(scene.read_fields().b.alt==35786 and scene.read_fields().a.alt==550,"UI imports scene without stale field text")
 verify(scene.read_fields().planes.size()==3 and scene.read_fields().planes[1].alt==20200,"UI restores all planes from saved scenario")
 scene.file_action="csv";scene.on_file(output_dir.path_join("example-measurements.csv"))
 verify(FileAccess.get_file_as_string(output_dir.path_join("example-measurements.csv")).split("\r\n",false).size()==scene.network.count+1,"UI exports every network measurement")
 scene.file_action="report";scene.on_file(output_dir.path_join("example-report.html"))
 verify(FileAccess.get_file_as_string(output_dir.path_join("example-report.html")).contains("<svg"),"UI exports self-contained HTML")
 scene.show_licenses()
 var license_dialog=scene.get_child(scene.get_child_count()-1)
 verify(license_dialog.get_child(0).text.contains("Godot") and license_dialog.get_child(0).text.contains("SIL"),"embedded engine and font licenses")
 license_dialog.queue_free();scene.set_page(0);scene.seek_time(35);await settle()
 await screenshot("OrbitLaser-workbench.png")
 scene.set_page(1);await settle();await screenshot("OrbitLaser-data.png")
 scene.set_page(3);await settle();await screenshot("OrbitLaser-network.png")
 var summary={"checks":checks,"failures":failures,"platform":OS.get_name(),"display":DisplayServer.get_name(),"rendered":DisplayServer.get_name()!="headless"}
 scene.Storage.write_text(output_dir.path_join("ui-validation.json"),JSON.stringify(summary,"  "))
 print("TOTAL UI: %d checks, %d failures"%[checks,failures]);scene.queue_free();await process_frame
 quit(1 if failures else 0)

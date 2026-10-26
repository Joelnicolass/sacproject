import json
def call(m,*a): return {"call":{"harness":"convert_watch","method":m,"args":list(a)}}
def v(mode,d,h,y): return call("set_mode",mode,d,h,y)
# RFC-068: nobody joins a started match from zero. B sits at the start (the dedicated waits for both seats), leaves by the
# pause menu once A's doctor walks, and comes back to its seat during the carry.
s=[{"click":"%Play"},{"click":"%Join"},
   {"wait_until":{"node":"%Stats","text_contains":"Vida","timeout":30}},
   {"wait_until":{"node":"%SacrificeSystem/Doctors/Doctor1","timeout":180}},{"wait":3.5},
   {"press":"pause_menu"},{"wait":0.3},{"click":"%Quit"},{"wait":0.2},{"click":"%ConfirmQuit"},
   {"wait_until":{"node":"%Play","visible_in_tree":True,"timeout":15}},{"wait":1.0}]
s+=[{"click":"%Play"},{"click":"%Join"},
   {"wait_until":{"node":"%Stats","text_contains":"Vida","timeout":30}},{"wait":1.0},
   call("probe"),{"shot":"t00_union.png"}]
# back in the seat: observe pair / doctor / carry / ritual
s+=[v("pair",16.0,5.0,150.0),{"wait":2.0},call("probe"),{"shot":"t01_pareja.png"}]
s+=[v("doctor",14.0,5.0,150.0),{"wait":3.0},call("probe"),{"shot":"t02_doctor.png"}]
s+=[v("doctor",18.0,7.0,250.0),{"wait":5.0},call("probe"),{"shot":"t03_hacia_altar.png"}]
s+=[v("ritual",26.0,10.0,160.0),{"wait":4.0},call("probe"),{"shot":"t04_ritual.png"}]
for i in range(10):
    s+=[{"wait":4.0},call("probe")]
    if i in (1,5): s+=[{"shot":"t05_ritual_%d.png"%i}]
s+=[{"wait":6.0},call("probe"),{"print":{"node":"%Stats","prop":"text"}},{"shot":"t06_fin.png"}]
json.dump({"scene":"res://scenes/core/boot.tscn","wait_first":1.0,"steps":s},open("flows/pt61b_b.json","w"),indent=1)

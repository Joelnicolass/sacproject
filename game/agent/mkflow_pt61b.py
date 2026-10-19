import json
def call(m,*a): return {"call":{"harness":"convert_watch","method":m,"args":list(a)}}
def v(mode,d,h,y): return call("set_mode",mode,d,h,y)
s=[{"click":"%Play"},{"click":"%Join"},
   {"wait_until":{"node":"%Stats","text_contains":"Vida","timeout":30}},{"wait":1.0},
   call("probe"),{"shot":"t00_union.png"}]
# late join: observe pair / doctor / carry / ritual
s+=[v("pair",16.0,5.0,150.0),{"wait":2.0},call("probe"),{"shot":"t01_pareja.png"}]
s+=[v("doctor",14.0,5.0,150.0),{"wait":3.0},call("probe"),{"shot":"t02_doctor.png"}]
s+=[v("doctor",18.0,7.0,250.0),{"wait":5.0},call("probe"),{"shot":"t03_hacia_altar.png"}]
s+=[v("ritual",26.0,10.0,160.0),{"wait":4.0},call("probe"),{"shot":"t04_ritual.png"}]
for i in range(10):
    s+=[{"wait":4.0},call("probe")]
    if i in (1,5): s+=[{"shot":"t05_ritual_%d.png"%i}]
s+=[{"wait":6.0},call("probe"),{"print":{"node":"%Stats","prop":"text"}},{"shot":"t06_fin.png"}]
json.dump({"scene":"res://scenes/core/boot.tscn","wait_first":1.0,"steps":s},open("flows/pt61b_b.json","w"),indent=1)

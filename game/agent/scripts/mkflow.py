import json,sys
def c(h,m,*a): return {"call":{"harness":h,"method":m,"args":list(a)}}
def snap(): return c("cam_ritual","snap")
def view(*a): return c("cam_ritual","set_view",*a)
def login(slot_wait):
    return [{"click":"%Play"},{"click":"%Join"},{"wait_until":{"node":"%Stats","text_contains":"Vida","timeout":20}},{"wait_until":{"node":"%Wizards/Wizard2","timeout":40}},{"wait":1.0}]
def cast():
    return [{"click":"%StructureTab"},{"wait":0.3},{"press":"spell_4"},{"wait":0.2},{"print":{"node":"%Battle","prop":"text"}},
            {"drag":{"node":"%View","from_x":812,"from_y":450,"to_x":812,"to_y":450}},{"wait":0.3},{"print":{"node":"%Battle","prop":"text"}},c("cam_ritual","clock")]
def full(who):
    s=login(0)
    if who=="a": s+=[{"shot":f"{who}00_antes.png"}]+cast()
    s+=[view("altar",100.0,55.0,20.0,10.0),{"wait":0.5},{"shot":f"{who}01_ritual_ini.png"}]
    s+=[view("doctor1",9.0,3.0,200.0,1.5),{"wait":0.5},snap(),{"shot":f"{who}02_doctor_cerca.png"}]
    s+=[view("creature",30.0,6.0,45.0,0.0),{"wait":0.5},snap(),{"shot":f"{who}03_criatura.png"}]
    s+=[view("wizard2",14.0,4.0,232.0,2.0)]
    for i in range(1,15):
        if i==8: s+=[view("wizard2",22.0,9.0,120.0,2.0)]
        s+=[{"wait":2.2},snap(),{"shot":f"{who}1{i:02d}_mago2.png"}]
    s+=[view("altar",110.0,40.0,20.0,6.0)]
    for i in range(1,9):
        s+=[{"wait":2.0},snap(),{"shot":f"{who}2{i:02d}_altar.png"}]
    s+=[{"wait_until":{"node":"%MatchResult","visible_in_tree":True,"timeout":60}},snap(),{"shot":f"{who}90_resultado.png"},{"wait":2.0},snap(),{"shot":f"{who}91_resultado2.png"}]
    return s
def wrap(steps): return {"scene":"res://scenes/core/boot.tscn","wait_first":1.0,"steps":steps}
json.dump(wrap(full("a")),open("flows/pt60_full_a.json","w"),indent=1)
json.dump(wrap(full("b")),open("flows/pt60_full_b.json","w"),indent=1)

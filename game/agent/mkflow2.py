import json
exec(open("mkflow.py").read().split("def wrap")[0].split("def full")[0])
def solo(scene,tag,n):
    s=[{"wait_until":{"node":"%Stats","text_contains":"Vida","timeout":20}},{"wait":1.0},{"shot":f"{tag}00_antes.png"}]
    s+=cast()
    s+=[view("altar",100.0,55.0,20.0,10.0)]
    for i in range(1,n):
        s+=[{"wait":2.5},snap()]
        if i%2==0: s+=[{"shot":f"{tag}1{i:02d}.png"}]
        if i==8: s+=[view("doctor1",14.0,4.0,200.0,3.0)]
        if i==14: s+=[view("altar",100.0,55.0,20.0,10.0)]
    return {"scene":scene,"wait_first":1.0,"steps":s}
json.dump(solo("res://debug/ritual_push.tscn","push",26),open("flows/pt60_push.json","w"),indent=1)
json.dump(solo("res://debug/ritual_cancel.tscn","canc",26),open("flows/pt60_cancel.json","w"),indent=1)

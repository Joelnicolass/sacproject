import json
F="agent/flows/"
def w(n,scene,steps,first=2.0):
    json.dump({"scene":scene,"wait_first":first,"steps":steps},open(F+n+".json","w"),indent=1)
R="%SelectionRoster"; C=R+"/Scroll/Cells/Cell"
def cl(n,**k):
    d={"node":f"{C}{n}","from_x":17,"from_y":16,"to_x":17,"to_y":16}; d.update(k); return {"drag":d}
def bg(x=96,y=236): return {"drag":{"node":R,"from_x":x,"from_y":y,"to_x":x,"to_y":y}}
def a(n,p,v): return {"assert":{"node":n,"prop":p,"equals":v}}
wait_hud={"wait_until":{"node":"%OrdersLog","text_contains":"Druid 800/800","timeout":40}}
tick=[{"press":"check_tick"},{"wait":0.5}]
# A: 4 trogg
w("pt79_group",  "res://debug/orders_group.tscn",[wait_hud,{"wait":0.5},
 a(R,"count",0),{"shot":"a0_empty.png"},*tick,a(R,"count",4),{"shot":"a1_four.png"},
 cl(2),{"wait":0.4},a("%Selection","count",1),{"shot":"a2_click_cell2.png"},
 *tick,a("%Selection","count",4),
 cl(1,shift=True),{"wait":0.4},a("%Selection","count",3),a(R,"cells_shown",3),{"shot":"a3_shift_cell1.png"},
 *tick,a("%Selection","count",4),
 bg(),{"wait":0.4},a("%Selection","count",4),{"shot":"a4_click_bg.png"},
 bg(52,18),{"wait":0.3},a("%Selection","count",4),
 {"call":{"harness":"selection_probe","method":"aim_empty"}},{"press":"select"},{"wait":0.6},
 a("%Selection","count",0),a(R,"count",0),a(R,"cells_shown",0),{"shot":"a5_world_deselect.png"}])
# B: 150
w("pt79_many","res://debug/selection_many.tscn",[wait_hud,{"wait":1.0},a(R,"count",0),{"shot":"b0_empty.png"},
 {"press":"check_tick"},{"wait_until":{"node":R,"prop":"count","equals":150,"timeout":10}},{"wait":0.6},
 a(R,"mode","group"),a(R,"cells_shown",3),a(C+"1/Count","text","50") if False else {"assert":{"node":C+"1/Count","text_equals":"50"}},
 {"shot":"b1_grouped150.png"},
 cl(3),{"wait":0.5},a("%Selection","count",50),{"shot":"b2_click_type.png"},
 {"press":"check_tick"},{"wait_until":{"node":R,"prop":"count","equals":150,"timeout":10}},{"wait":0.5},
 cl(1,shift=True),{"wait":0.5},a("%Selection","count",100),{"shot":"b3_shift_other.png"},
 {"press":"check_tick"},{"wait_until":{"node":R,"prop":"count","equals":150,"timeout":10}},{"wait":0.5},
 bg(),{"wait":0.4},a("%Selection","count",150),{"shot":"b4_click_bg.png"},
 {"call":{"harness":"selection_probe","method":"aim_empty"}},{"press":"select"},{"wait":0.6},
 a("%Selection","count",0),{"shot":"b5_world_deselect.png"}],first=2.5)
# C: druid hit
st=[wait_hud,*tick,a(R,"count",4),{"print":{"node":R,"prop":"min_health"}},{"shot":"c0_full.png"}]
for i in range(1,5):
    st+=[{"wait":2.5},{"print":{"node":R,"prop":"min_health"}},
      *[{"print":{"node":f"{C}{k}","prop":"health_fraction"}} for k in range(1,5)],
      {"shot":f"c{i}_t{i}.png"}]
w("pt79_hit","res://debug/roster_hit.tscn",st)
# D: ability
w("pt79_ability","res://debug/ability_spit.tscn",[{"wait":0.5},a(R,"count",1),
 {"print":{"node":"Arena/Palk1/ManaPool","prop":"current"}},{"shot":"d0_before.png"},
 {"click":R+"/Ability"},{"wait":0.8},
 {"print":{"node":"Arena/Palk1/ManaPool","prop":"current"}},{"shot":"d1_after.png"}],first=1.2)

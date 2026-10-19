import json

CX, CY = 640, 360  # center of %View; checked with the print of its size in the first run


def call(method, *args):
    return {"call": {"harness": "convert_watch", "method": method, "args": list(args)}}


def view(mode, dist=14.0, height=3.0, yaw=0.0):
    return call("set_mode", mode, dist, height, yaw)


def probe():
    return call("probe")


def shot(name):
    return {"shot": name}


def head(scene):
    return [
        {"wait_until": {"node": "%Stats", "text_contains": "Vida", "timeout": 30}},
        {"wait": 1.0},
        {"print": {"node": "%View", "prop": "size"}},
        shot("c00_antes.png"),
    ]


def kill_and_wait_soul():
    return [
        view("victim", 24.0, 7.0, 200.0),
        {"wait": 3.0},
        shot("c01_matan.png"),
        {"wait_until": {"node": "HighNoon/SoulSystem/Souls/Soul1", "timeout": 120}},
        {"wait": 3.8},
        {"print": {"node": "%Stats", "prop": "text"}},
        view("soul", 9.0, 3.5, 200.0),
        {"wait": 0.8},
        shot("c02_alma_roja.png"),
    ]


def cast():
    return [
        {"click": "%StructureTab"},
        {"wait": 0.3},
        {"press": "spell_3"},
        {"wait": 0.2},
        {"print": {"node": "%Battle", "prop": "text"}},
        {"drag": {"node": "%View", "from_x": CX, "from_y": CY, "to_x": CX, "to_y": CY}},
        {"wait": 0.3},
        {"print": {"node": "%Battle", "prop": "text"}},
        probe(),
    ]


def timeline(points, mode_for):
    steps = []
    last = 0.0
    for t, name in points:
        steps.append({"wait": round(t - last, 2)})
        last = t
        mode = mode_for(name)
        if mode:
            steps.append(view(*mode))
            steps.append({"wait": 0.3})
        steps.append(probe())
        steps.append(shot(name + ".png"))
    return steps


def full():
    s = head("")
    s += kill_and_wait_soul()
    s += cast()
    s += [view("vortex", 34.0, 3.0, 200.0), {"wait": 0.9}, shot("c03_vortice.png"), probe()]
    s += [{"wait_until": {"node": "%SacrificeSystem/Doctors/Doctor1", "timeout": 10}}, view("pair", 20.0, 6.0, 200.0), {"wait": 1.2}, shot("c04_cae.png"), probe()]
    s += [{"wait": 4.0}, shot("c05_camina.png"), probe()]
    s += [view("doctor", 7.0, 2.5, 150.0), {"wait": 3.0}, shot("c06_bombea.png"), probe()]
    s += [{"wait": 4.0}, shot("c07_bombea_final.png"), probe()]
    s += [view("pair", 16.0, 5.0, 150.0), {"wait": 3.0}, shot("c08_acarreo.png"), probe()]
    s += [{"wait": 3.0}, probe(), view("doctor", 18.0, 7.0, 250.0), shot("c09_acarreo_altar.png")]
    s += [{"wait": 3.0}, probe(), view("ritual", 95.0, 58.0, 160.0), shot("c10_ritual.png")]
    s += [{"wait": 5.0}, probe(), shot("c11_ritual.png")]
    for i in range(12):
        s += [{"wait": 4.0}, probe()]
        if i in (2, 5, 8):
            s += [shot("c12_ronda%d.png" % i)]
    s += [{"wait": 2.0}, probe(), shot("c13_fin.png")]
    s += [{"print": {"node": "%Stats", "prop": "text"}}]
    return {"scene": "res://debug/sacrifice/convert_ritual.tscn", "wait_first": 1.0, "steps": s}


def pump_kill():
    s = head("")
    s += kill_and_wait_soul()
    s += cast()
    s += [{"wait_until": {"node": "%SacrificeSystem/Doctors/Doctor1", "timeout": 10}}, view("pair", 20.0, 6.0, 200.0), {"wait": 3.5}, probe(), shot("p01_camina.png")]
    s += [view("doctor", 8.0, 3.0, 120.0), {"wait": 1.5}, probe(), shot("p02_bombea.png")]
    for i in range(8):
        s += [{"wait": 1.0}, probe()]
        if i in (1, 3):
            s += [shot("p03_guardias_%d.png" % i)]
    s += [view("victim", 14.0, 5.0, 150.0), {"wait": 3.0}, probe(), shot("p04_muere_otra_vez.png")]
    s += [view("soul", 8.0, 3.0, 150.0), {"wait": 4.0}, probe(), shot("p05_alma_vuelve.png")]
    s += [{"print": {"node": "%Stats", "prop": "text"}}]
    return {"scene": "res://debug/sacrifice/convert_pump_kill.tscn", "wait_first": 1.0, "steps": s}


def carry_kill():
    s = head("")
    s += kill_and_wait_soul()
    s += cast()
    s += [{"wait_until": {"node": "%SacrificeSystem/Doctors/Doctor1", "timeout": 10}}, view("pair", 20.0, 6.0, 120.0), {"wait": 4.0}, probe(), shot("k01_camina.png")]
    s += [view("doctor", 8.0, 3.0, 120.0), {"wait": 2.0}, probe(), shot("k02_bombea.png")]
    s += [{"wait": 8.0}, probe(), view("doctor", 14.0, 5.0, 120.0), {"wait": 2.0}, probe(), shot("k03_acarreo.png")]
    for i in range(14):
        s += [{"wait": 1.5}, probe()]
        if i in (3, 6, 9):
            s += [shot("k04_camino_%d.png" % i)]
    s += [view("victim", 14.0, 5.0, 150.0), {"wait": 2.5}, probe(), shot("k05_suelta.png")]
    s += [{"wait": 1.0}, probe()]
    s += [{"print": {"node": "%Stats", "prop": "text"}}]
    return {"scene": "res://debug/sacrifice/convert_carry_kill.tscn", "wait_first": 1.0, "steps": s}


def online_a():
    s = [
        {"click": "%Play"},
        {"click": "%Join"},
        {"wait_until": {"node": "%Stats", "text_contains": "Vida", "timeout": 30}},
        {"wait": 1.0},
        shot("o00_antes.png"),
    ]
    s += kill_and_wait_soul()
    s += cast()
    s += [{"wait_until": {"node": "%SacrificeSystem/Doctors/Doctor1", "timeout": 10}}, view("pair", 20.0, 6.0, 200.0), {"wait": 3.5}, probe(), shot("o01_camina.png")]
    s += [view("doctor", 8.0, 3.0, 150.0), {"wait": 2.0}, probe(), shot("o02_bombea.png")]
    s += [{"wait": 6.0}, probe(), view("pair", 16.0, 5.0, 150.0), {"wait": 3.0}, probe(), shot("o03_acarreo.png")]
    s += [view("doctor", 18.0, 7.0, 250.0), {"wait": 4.0}, probe(), shot("o04_hacia_altar.png")]
    s += [{"wait": 4.0}, probe(), view("ritual", 95.0, 58.0, 160.0), shot("o05_ritual.png")]
    for i in range(12):
        s += [{"wait": 4.0}, probe()]
        if i in (1, 4):
            s += [shot("o06_ritual_%d.png" % i)]
    s += [{"wait": 4.0}, probe(), {"print": {"node": "%Stats", "prop": "text"}}, shot("o07_fin.png")]
    return {"scene": "res://scenes/core/boot.tscn", "wait_first": 1.0, "steps": s}


json.dump(full(), open("flows/rfc020e_convert_solo.json", "w"), indent=1)
json.dump(online_a(), open("flows/rfc020e_convert_a.json", "w"), indent=1)
json.dump(pump_kill(), open("flows/rfc020e_pump_kill.json", "w"), indent=1)
json.dump(carry_kill(), open("flows/rfc020e_carry_kill.json", "w"), indent=1)

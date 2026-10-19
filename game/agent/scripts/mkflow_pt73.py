#!/usr/bin/env python3
"""Writes the AgentKit flows of the 024b2 playtest (flows/pt73_*.json). Run: python3 agent/scripts/mkflow_pt73.py"""
import json
from pathlib import Path

OUT = Path(__file__).resolve().parent / "flows"


def call(method, *args):
    return {"call": {"harness": "pt73_watch", "method": method, "args": list(args)}}


def flow(name, scene, steps):
    (OUT / f"{name}.json").write_text(json.dumps({"scene": scene, "wait_first": 1.0, "steps": steps}, indent=1))


village = [
    {"wait_until": {"node": "HighNoon/Units/Hunter", "timeout": 30}},
    {"wait": 1.0},
    call("view", "point:1258,1243", 24, 9.5, 20),
    {"wait": 0.6},
    {"print": {"node": "%Status", "prop": "text"}},
    {"shot": "v01_aldea_en_pausa.png"},
    {"press": "check_tick"},
    {"wait": 0.3},
    {"print": {"node": "%Status", "prop": "text"}},
    call("view", "node:Farmer15", 17, 7, 20),
    {"wait": 0.6},
    call("aim", "Farmer15"),
    {"press": "order_units"},
    {"wait": 1.2},
    call("report"),
    {"shot": "v02_huye_1.png"},
    call("view", "node:Farmer15", 17, 7, 110),
    {"wait": 1.5},
    call("report"),
    {"shot": "v03_huye_2.png"},
    {"wait_until": {"node": "HighNoon/SoulSystem/Souls/Soul1", "timeout": 120}},
    {"wait": 4.0},
    call("report"),
    call("view", "soul", 8, 3.2, 200),
    {"wait": 0.8},
    {"print": {"node": "%Stats", "prop": "text"}},
    {"shot": "v04_alma_roja.png"},
]
flow("pt73_village", "res://debug/map/village.tscn", village)

cower = [
    {"wait_until": {"node": "HighNoon/Units/Hunter", "timeout": 30}},
    {"wait": 1.0},
    call("view", "node:Farmer6", 11, 4.5, 217),
    {"wait": 0.4},
    {"shot": "c00_pausa.png"},
    {"press": "check_tick"},
    {"wait": 0.6},
    call("farmer", "Farmer6"),
    {"shot": "c01_encogido_0s.png"},
    {"wait": 10.0},
    call("farmer", "Farmer6"),
    {"shot": "c02_encogido_10s.png"},
    call("aim", "Farmer6"),
    {"press": "order_units"},
    call("view", "pair:Hunter,Farmer6", 20, 8, 217),
    {"wait": 0.5}, call("report"), call("melee_probe", "Hunter", "Farmer6"),
    {"wait": 0.5}, call("report"), call("melee_probe", "Hunter", "Farmer6"),
    {"wait": 1.0}, call("report"), call("melee_probe", "Hunter", "Farmer6"),
    {"wait": 1.0},
    call("report"),
    {"shot": "c03_golpea.png"},
    {"wait": 3.0},
    call("report"),
    call("farmer", "Farmer6"),
    call("melee_probe", "Hunter", "Farmer6"),
    {"wait_until": {"node": "HighNoon/SoulSystem/Souls/Soul1", "timeout": 90}},
    {"wait": 4.0},
    call("report"),
    call("view", "soul", 8, 3.2, 200),
    {"wait": 0.8},
    {"print": {"node": "%Stats", "prop": "text"}},
    {"shot": "c04_alma_roja.png"},
    call("soul_distance"),
    {"click": "%StructureTab"},
    {"wait": 0.3},
    {"press": "spell_3"},
    {"wait": 0.2},
    {"print": {"node": "%Battle", "prop": "text"}},
    call("mark", "convert"),
    {"drag": {"node": "%View", "from_x": 640, "from_y": 360, "to_x": 640, "to_y": 360}},
    {"wait": 0.4},
    {"print": {"node": "%Battle", "prop": "text"}},
    call("report"),
    {"wait": 12.0},
    {"shot": "c05_convert_en_marcha.png"},
    call("report"),
    {"call": {"harness": "convert_watch", "method": "probe", "args": []}},
    {"wait": 10.0},
    {"call": {"harness": "convert_watch", "method": "probe", "args": []}},
    {"wait": 10.0},
    {"call": {"harness": "convert_watch", "method": "probe", "args": []}},
    {"shot": "c05b_convert_30s.png"},
    {"wait": 10.0},
    {"call": {"harness": "convert_watch", "method": "probe", "args": []}},
    {"wait": 10.0},
    {"call": {"harness": "convert_watch", "method": "probe", "args": []}},
    {"wait_until": {"node": "%Stats", "text_contains": "Almas 1", "timeout": 150}},
    call("report"),
    {"print": {"node": "%Stats", "prop": "text"}},
    call("since_gain", "convert"),
    {"shot": "c06_almas_1.png"},
]
flow("pt73_cower", "res://debug/map/village_cower.tscn", cower)

taurock = [
    {"wait_until": {"node": "HighNoon/Units/Hunter", "timeout": 30}},
    {"wait": 1.0},
    call("view", "pair:Hunter,Taurock1", 90, 45, 0),
    {"wait": 0.5},
    call("taurock"),
    {"shot": "t01_pausa.png"},
    {"press": "check_tick"},
    {"wait": 1.0},
    call("taurock"),
    {"wait": 4.0},
    call("taurock"),
    {"shot": "t02_se_acerca.png"},
    {"wait": 8.0},
    call("view", "pair:Hunter,Taurock1", 22, 9, 30),
    {"wait": 0.5},
    call("taurock"),
    {"shot": "t03_lucha.png"},
    call("aim", "Taurock1"),
    {"press": "order_units"},
    {"wait": 4.0},
    call("taurock"),
    {"wait": 5.0},
    call("taurock"),
    {"shot": "t04_lucha_5s.png"},
]
flow("pt73_taurock", "res://debug/map/village_taurock.tscn", taurock)
print("ok")

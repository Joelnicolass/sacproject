#!/usr/bin/env python3
"""055s s0 (disposable): writes the small Godot project the export probe uses, in a scratch folder outside any real preset.

usage: make_exp_proj.py <dest folder> <exp_src folder>
The project has: an editor plugin (copy of what DedicatedStrip must do), 4 WAVs (~0.5 MB each, imported as AudioStreamWAV),
a ref.tscn that uses a WAV and an AnimationLibrary, a main.tscn/main.gd that reports what an exported pack holds, and its OWN
export_presets.cfg (the game's export_presets.cfg is never touched). The animations and the library are written by
make_assets.gd (inside Godot) after this script.
"""
import math
import os
import shutil
import struct
import sys
import wave

dest, src = sys.argv[1], sys.argv[2]
os.makedirs(os.path.join(dest, "addons", "s0_strip"), exist_ok=True)
os.makedirs(os.path.join(dest, "audio"), exist_ok=True)

for name in ("plugin.cfg", "plugin.gd", "strip.gd"):
    shutil.copy(os.path.join(src, name), os.path.join(dest, "addons", "s0_strip", name))
shutil.copy(os.path.join(src, "main.gd"), os.path.join(dest, "main.gd"))
shutil.copy(os.path.join(src, "make_assets.gd"), os.path.join(dest, "make_assets.gd"))

for i in range(4):
    with wave.open(os.path.join(dest, "audio", "tone%d.wav" % i), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(44100)
        frames = bytearray()
        for n in range(44100 * 3):
            v = int(12000 * math.sin(2 * math.pi * (220 + 55 * i) * n / 44100))
            frames += struct.pack("<hh", v, v)
        w.writeframes(bytes(frames))

with open(os.path.join(dest, "project.godot"), "w") as f:
    f.write('''config_version=5

[application]

config/name="s0_export_probe"
run/main_scene="res://main.tscn"
config/features=PackedStringArray("4.7")

[editor_plugins]

enabled=PackedStringArray("res://addons/s0_strip/plugin.cfg")
''')

with open(os.path.join(dest, "main.tscn"), "w") as f:
    f.write('''[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://main.gd" id="1_main"]

[node name="Main" type="Node"]
script = ExtResource("1_main")
''')

# ext_resource lines go before sub_resource lines.
with open(os.path.join(dest, "ref.tscn"), "w") as f:
    f.write('''[gd_scene load_steps=3 format=3]

[ext_resource type="AudioStream" path="res://audio/tone0.wav" id="1_snd"]
[ext_resource type="AnimationLibrary" path="res://clips/lib.res" id="2_lib"]

[node name="Ref" type="Node"]

[node name="Audio" type="AudioStreamPlayer" parent="."]
stream = ExtResource("1_snd")

[node name="Clips" type="AnimationPlayer" parent="."]
libraries = {
&"": ExtResource("2_lib")
}
''')

with open(os.path.join(dest, "export_presets.cfg"), "w") as f:
    f.write('''[preset.0]

name="s0"
platform="Linux"
runnable=false
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter="addons/*, make_assets.gd"
export_path=""
patches=PackedStringArray()
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.0.options]

custom_template/debug=""
custom_template/release=""
binary_format/embed_pck=false
texture_format/s3tc_bptc=true
texture_format/etc2_astc=false
binary_format/architecture="x86_64"
''')
print("S0 export project written in", dest)

#!/usr/bin/env bash
cd /Users/joelsartori/Development/sacproject/game/agent
R=./harness/pt022e4c_run.sh
$R pt022e4c_rts_pyro.json rts_pyro_med
$R pt022e4c_rts_pyro.json rts_pyro_low --pt-preset=low
$R pt022e4c_rts_persephone.json rts_persephone_med
$R pt022e4c_rts_persephone.json rts_persephone_low --pt-preset=low
echo ALL_DONE

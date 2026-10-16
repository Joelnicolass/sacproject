# REVIEW F86 — Clips precalentados (RFC-027, corte 027b)

Reviewer: studio-reviewer (Opus 5.5). Guardado por el orquestador.

**Veredicto: PASS con nits.** Sin bloqueantes.

- **Primera orden de 150:** 36,4 → 6,3 ms, medido por el dev (umbral ≤ 12).
- **Precalentado:** 21–39 ms por modelo (umbral ≤ 40).
- **Digest:** igual en dos pares A/B.
- **Skip de escritura:** seguro. Compara el estado real de la malla y vuelve a escribir si otro código la tocó. Lo revisé contra cadáver, lunge, cower, voladores, pose override y `show_model`.
- **Simulación:** el reloj del clip y `impact_frame` siguen en física y no cambian. El precalentado no corre en el dedicado ni en el editor.
- **Tick con 150:** no medido; el «después» sale de la corrida many150 de 027a.

## Deuda
- **Repartir el precalentado antes de que 030b habilite los 51 modelos.** Con todos juntos, 51 × ~30 ms ≈ 1,5 s de congelado. Hay dos caminos: una cola con presupuesto por cuadro (`warm_budget_ms` ≈ 4) o precalentar en la carga según el roster de la partida.
- **Nits:**
  1. `warm_frames_per_role` actúa por modelo, no por instancia, y su rango de 0–400 confunde: bajarlo a 0–8 y documentarlo.
  2. `warm_us_by_model` no lo usa nadie: que lo lea FrameBudget o sacarlo.
  3. El `print` del precalentado debería ir detrás de una opción verbose.

## Hallazgo descartado por el orquestador
El reviewer sospechó que el clip avanzaba dos veces por tick (en `ClipPosePlayer._physics_process` y en el cuerpo). Revisé con `grep`: ningún cuerpo llama a `advance(`; el único que lo llama es `clip_pose_player.gd:62`. No hay doble avance.

## Para 027a
El developer de 027b dejó el archivo original en el árbol unos minutos, durante sus corridas «antes». Las corridas de 027a anteriores a las 02:08 pueden mezclar versiones.

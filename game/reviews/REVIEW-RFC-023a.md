# REVIEW RFC-023a (exportador esqueletico + paridad)

Veredicto: **CHANGES_REQUESTED** (una correccion; sin Godot, sin playtest: es herramienta, no hay look que juzgar).

## 1. Causa del vertice de jnwr (hipotesis concreta)
- sacengine NO normaliza pesos: `source/saxs.d:322` hace `position += transform[bone](offset) * weight` (peso crudo = `w/16384`, `saxs.d:97`), con `displacement` sumado aparte (`saxs.d:319`). El OBJ de referencia usa ese camino (`saxs2obj.d:10-15`). No hay clamp ni limite de N influencias: `Vertex` admite 3 (`saxs.d:25-30`); el filtro `ushort.max` es el unico.
- El exportador divide por la suma: `tools/export_skeletal.py:718` (`wsum`) y `:747` (`w = infl[i][2]/wsum`). Para el vertice con suma 1,006 el original produce `1,006 * pos` (escala 0,6 % respecto del origen del modelo); el glb produce `1,000 * pos`. Con el vertice a ~0,65 m del origen: 0,006 * 650 mm = 3,9 mm, que es lo medido (3,9-4,1). Ademas Godot renormaliza WEIGHTS_0 al importar, asi que "sin normalizar" no se puede probar en el glb: por eso el developer no lo reprodujo.
- Las costuras (`seamFace*`) no reasignan vertices: solo agregan caras/vertices con los mismos `indices` (`saxs.d:232-239`); no son la causa. `generateNormals` no mueve posiciones.
- Verificacion barata (sin Godot): en Python calcular `|sum(w)-1|` por vertice y el error previsto `|sum(w)-1| * |pos_skinneada - displacement|`; debe dar ~4 mm para ese vertice y <1 mm para el resto. Si coincide, causa cerrada.
- Recomendacion: no es corregible en glTF (escala no rigida). Aceptarlo como excepcion documentada: el exportador reporta en `index.json` los vertices con `|sum-1| > 0,002` y su error previsto; el audit los excluye del criterio 1 mm solo si el error medido coincide con el previsto (+-0,2 mm). El RFC debe enmendar «≤1 mm» a «≤1 mm salvo vertices con peso no normalizado, listados». (BLOQUEANTE menor: sin esto el corte queda «FALLA» sin causa registrada.)

## 2. Huesos auxiliares
- Correcto en matematicas (`export_skeletal.py:733-745`, ibm `:822-830`) y unico dueño del skinning: la malla usa solo `Skeleton3D`+`Skin`; los auxiliares no tienen pistas (`:841-843`). Ya comparte auxiliares por (hueso, shift cuantizado) (`helper_index`, `:739-743`), pero el shift es relativo al hueso principal de CADA vertice, por eso la clave casi no se repite: 286 auxiliares en `eorc`.
- Sobreingenieria para jnwr: la discrepancia maxima es 2,77 mm (media 0,34 mm; `index.json` → `bind_discrepancy`). Para 240 huesos se evita un error de ~1,4 mm en pocos vertices.
- Alternativas, de menor a mayor cambio (recomiendo A+B):
  - A. Umbral: auxiliares solo si la discrepancia del vertice > 0,5 mm; el resto usa bind promediado (error ≤ 0,5 mm, dentro del presupuesto). Para jnwr casi elimina los 208.
  - B. Cuantizar el shift a 0,5 mm (error ≤ 0,43 mm) en vez de 0,05 mm (`SHIFT_STEP`, `:690`): colapsa claves y baja el conteo de auxiliares una o dos ordenes. Presupuesto total debe sumarse (cuantizacion + umbral < 1 mm).
  - C. Elegir como bind el centroide ponderado en vez del hueso principal (menos shifts distintos).
  - D. Skinning propio en shader: descartar ahora (rompe LOD, sombras, `Skeleton3D`/`BoneAttachment3D` y AnimationTree no cambian pero el shader de material si); solo si 023g demuestra que A+B no alcanzan.
- Riesgo de rendimiento (150 cuerpos): 305 huesos * 150 = 45 750 propagaciones de pose + subida de matrices por frame; sin medir. La skin con >256 uniones no se verifico renderizada (el audit corre headless con skinning en CPU): 023b debe confirmar que `eorc` (305) renderiza bien. Medicion obligatoria en 023g con A+B ya aplicados; hasta entonces es hipotesis.

## 3. Cobertura de los 85 clips sin OBJ
- Hoy solo 3+2 clips tienen referencia: el criterio «todos los clips» no esta cumplido (NEEDS WORK, no se puede dar por hecho).
- sacengine ya exporta por linea de comandos: `app.d:455-466` (`export:<file>.obj` con `exportFrame`) y `app.d:495-505` (`export-all-frames:<dir>` para toda la animacion). Recomiendo un modo `--reference` en el audit (script aparte, en scratch, no git): para cada clip correr sacengine con `export-all-frames` y comparar frames {0, mitad, ultimo} con el glb. Es una referencia independiente del exportador (cierra tambien el riesgo de bug en el parser SXSK compartido). Costo: 90 clips * ~3 OBJ.
- Validacion cruzada `--single-bind` vs exacto NO sirve como cobertura: ambos comparten el parseo de poses/ejes; solo prueba la parte de offsets.
- Minimo aceptable para cerrar 023a: los 90 clips en 3 cuadros contra sacengine para eorc y jnwr; o aceptar el subconjunto de 5 y dejar el resto explicitamente a 023b (capturas) con la limitacion escrita en el RFC.

## 4. Licencia y git
- Licencia: PASS. `export_skeletal.py:12-13` declara escritura independiente; las formulas son de formato. No encontre estructuras ni nombres copiados de `saxs.d` mas alla de los del formato (`seam`, `ring_step` son nombres de dominio: nit, renombrar si se quiere distancia).
- Nada de `cache/` trackeable: PASS. `.gitignore:2` ignora `cache/`; `git ls-files cache` vacio.
- `.glb` por LFS: PASS (`git check-attr filter` → `lfs` para `eorc.glb`, via `.gitattributes` de la raiz). `index.json` y `.events.json` van a git normal (39 KB y <1 KB): correcto.
- `.import` no ignorados: PASS (`git check-ignore -v` los devuelve con la regla de negacion `!assets/original/**/*.import`, o sea no ignorados). Nit: `*.import` para otros assets de `assets/original/textures` hereda lo mismo.
- Nota de alcance (no bloquea): se versionan datos derivados del juego original (`.glb` con mallas y animaciones); decision del usuario 2026-10-17 en el RFC, pero queda constancia de que el aviso legal de RULES.md debe cubrirlo.

## Bloqueantes (una correccion)
1. Documentar/automatizar la causa de pesos no normalizados (seccion 1) y enmendar el criterio del RFC.
2. Aplicar A+B (umbral y cuantizacion gruesa) o justificar con medicion por que se conservan 305/240 huesos.
3. Auditar los clips restantes con referencia de sacengine, o escribir en el RFC que quedan para 023b.

## Nits
- `audit_skeletal.gd` no se pudo ejecutar aqui (no se corre Godot); la salida de la tabla es la del developer.
- `audit_skeletal.gd.uid` sin trackear: commitear junto con el script.

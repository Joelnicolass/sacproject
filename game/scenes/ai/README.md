# scenes/ai/

IA de los bandos: cerebros, tareas, percepcion, grupos y comandos. Un cerebro nuevo va en `brains/` y se registra en `ai_roster.gd`.

Agregar uno nuevo: poner el script y la escena aca, componer con nodos hijos y `@export` (nada de herencia profunda), y los datos de tipo en `data/` como `.tres`. Las pruebas de este dominio van en `debug/ai/`.

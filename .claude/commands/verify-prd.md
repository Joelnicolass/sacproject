---
description: "Revisa PRD.md, marca huecos y escribe PRD-REVIEW.md."
---

Eres un product manager experto encargado de revisar un Documento de requisitos de producto (PRD). Tu objetivo es identificar huecos, mejorar la claridad y asegurar que el PRD esté listo para implementación.

Revisá `PRD.md` en el directorio actual y brindá feedback accionable. Si no existe, pedile al usuario su PRD — texto pegado o una ruta de archivo — y guardalo como `PRD.md` antes de continuar.

Llegar aquí con un PRD que ya escribiste es un punto de entrada normal, no un error. No asumas que `/create-prd` se ejecutó primero, y no vuelvas a entrevistar a un usuario que ya escribió el documento.

## AJUSTAR EL CHECKLIST AL TIPO DE PRODUCTO

Primero clasificá el producto: web app · mobile app · library/SDK · CLI · service/API · data pipeline · game.

Aplicá solo las secciones y controles que correspondan a ese tipo. Para una library/SDK, omití infraestructura, escalabilidad, aspectos regulatorios, modelo de negocio, accesibilidad, diseño responsive, gestión de estado y autenticación — en su lugar indagá: superficie de API pública y consistencia, política de semver/deprecación, rangos de peer-dependency, tamaño del bundle, tree-shaking, calidad de tipos, el límite público/interno, y mutación de datos que pertenecen al caller. Cada otro tipo de producto tiene sus equivalentes; definilos antes de aplicar la lista genérica de abajo.

Indicá qué tipo de producto clasificaste y qué controles omitiste. Omitir debe ser visible y auditable, nunca silencioso: un "no se identificaron vectores de inyección SQL" generado en una librería que no tiene SQL fabrica falsa confianza.

## PASO 0: ANCLAR EL PRD EN LA REALIDAD

Antes del análisis de huecos:

- Si el PRD nombra una implementación existente, un prototipo o una fuente "extraída de", LEELA. Compará el comportamiento documentado contra el comportamiento real y reportá cada discrepancia — estos son los hallazgos de mayor valor disponibles, y un checklist no los va a sacar a la luz.
- Si el PRD nombra tecnologías específicas, contrastá sus afirmaciones contra cómo se comportan realmente esas tecnologías: versiones, valores por defecto, breaking changes, footguns.
- Listá cualquier afirmación del PRD que no pudiste verificar, y decilo de forma explícita en lugar de dejarla pasar como verificada.

## PASO 1: ANÁLISIS DE HUECOS

Identificá elementos críticos faltantes en estas áreas:

1. FUNDAMENTOS DEL PRODUCTO
   - Visión del producto y planteo del problema
   - Usuarios objetivo y sus necesidades
   - Métricas de éxito y límites de alcance

2. REQUISITOS TÉCNICOS
   - Restricciones tecnológicas e integraciones
   - Necesidades de seguridad, rendimiento y escalabilidad
   - Requisitos de infraestructura

3. CONSIDERACIONES DE NEGOCIO
   - Restricciones de cronograma y presupuesto
   - Requisitos regulatorios
   - Factores de mercado y modelo de negocio

4. FACTORES DE IMPLEMENTACIÓN
   - Dependencias y requisitos de terceros
   - Recursos del equipo y habilidades necesarias
   - Necesidades de testing y despliegue

## PASO 2: RECOMENDACIONES DE MEJORA

Brindá recomendaciones específicas en estas áreas:

1. ESTRUCTURA Y CLARIDAD
   - Asegurar que estén incluidas todas las secciones esenciales
   - Aclarar requisitos ambiguos
   - Formatear las user stories de forma correcta

2. COMPLETITUD Y VIABILIDAD
   - Completar huecos en las jornadas de usuario
   - Identificar desafíos técnicos
   - Sugerir alternativas para requisitos problemáticos

3. PRIORIZACIÓN E IMPLEMENTACIÓN
   - Aplicar priorización MoSCoW
   - Identificar requisitos del camino crítico
   - Sugerir una secuencia de implementación lógica

## ENTREGABLES

1. RESUMEN DE HALLAZGOS
   - Lista de huecos críticos (impacto High/Medium/Low)
   - Evaluación general de 2-3 oraciones

2. RECOMENDACIONES ESPECÍFICAS
   - Sugerencias concretas de mejora
   - Ejemplos de cómo aclarar requisitos ambiguos

3. PRD MEJORADO
   - Crear una versión mejorada que aborde los problemas encontrados
   - Guardar como "PRD.md" en el directorio actual (sobrescribir el original)
   - Si el proyecto no está bajo control de versiones, decilo primero y ofrecé guardar como "PRD.v2.md" en su lugar — sobrescribir un PRD escrito a mano sin forma de recuperarlo destruye el diff que el usuario necesita para revisar qué cambiaste

4. EVALUACIÓN DE CALIDAD
   - Puntuar el PRD (1-10) en: Completitud, Claridad, Viabilidad y Enfoque en el usuario

5. PRD-REVIEW.md
   - Escribir los entregables 1, 2 y 4 en "PRD-REVIEW.md" junto al PRD mejorado: la lista de huecos, las recomendaciones, los puntajes y por qué se hizo cada cambio
   - Los hallazgos que viven solo en esta conversación desaparecen en cuanto termina. El siguiente lector entonces ve una decisión en PRD.md sin registro de la contradicción que la motivó, y la "simplifica" hasta borrar
   - Los comandos posteriores deben leer este archivo. Cada hallazgo de impacto High debe permanecer trazable hacia FEATURES.md y los RFCs

## AUTOCHEQUEO ANTES DE TERMINAR

- Recontá cada tabla de resumen a partir del contenido real. Nunca arrastres un recuento desde más atrás en tu propia salida.
- Verificá cada referencia cruzada interna — IDs de features, IDs de rules, números de RFC, referencias de sección — apunta a lo que el texto circundante afirma que hace. Una referencia a un ID VÁLIDO pero EQUIVOCADO es el caso peligroso: nada parece malformado, así que los lectores quedan engañados en silencio.
- Confirmá que no hay dos tablas del documento que se contradigan entre sí.
- Indicá que corriste este chequeo y qué encontró.

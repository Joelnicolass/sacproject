---
description: "Genera un plan de tests a partir de FEATURES y los RFCs. Opcional."
---

Eres un ingeniero QA y arquitecto de tests experto encargado de generar un plan de tests completo a partir de las features y los RFCs del proyecto.

Creá una estrategia de testing estructurada que asegure cobertura exhaustiva de toda la funcionalidad implementada. El plan de tests debe ser práctico, priorizado y alineado con la secuencia de implementación de los RFCs.

## Entradas
- FEATURES.md para los requisitos de features
- RFCs (todos o los específicos que se estén testeando)
- RULES.md para los estándares de testing
- Codebase existente (si está disponible)

## CUANDO LOS ARTEFACTOS ENTRAN EN CONFLICTO

Orden de autoridad: PRD.md > FEATURES.md > RULES.md > RFCs > generated plans. Donde la guía genérica de este prompt entre en conflicto con RULES.md, gana RULES.md — se escribió para este proyecto y este prompt no. Nunca resuelvas una contradicción entre dos artefactos en silencio: indicala, decí cuál seguiste y por qué, y marcá el otro para corrección.

## PASO 0: ESTABLECER LA LÍNEA BASE

Antes de planificar cualquier cosa, ejecutá la suite de tests existente y reportá la línea base real: cuántos tests existen, en qué archivos viven, y qué pasa o falla. Pegá la salida real.

A lo largo del plan, distinguí los tests que YA EXISTEN de los tests que ESTÁS PROPONIENDO. Sin esa separación, un plan generado se lee como si describiera la realidad, y su columna de estado es conjetura vestida de hecho.

Si todavía no existe una suite, o no podés ejecutar comandos en este entorno, decilo de forma explícita en lugar de asumir cobertura.

## AJUSTAR EL CHECKLIST AL TIPO DE PRODUCTO

Primero clasificá el producto: web app · mobile app · library/SDK · CLI · service/API · data pipeline · game.

Aplicá solo las secciones y controles que correspondan a ese tipo. Para una library/SDK, omití infraestructura, escalabilidad, aspectos regulatorios, modelo de negocio, accesibilidad, diseño responsive, gestión de estado y autenticación — en su lugar indagá: superficie de API pública y consistencia, política de semver/deprecación, rangos de peer-dependency, tamaño del bundle, tree-shaking, calidad de tipos, el límite público/interno, y mutación de datos que pertenecen al caller. Cada otro tipo de producto tiene sus equivalentes; definilos antes de aplicar la lista genérica de abajo.

Indicá qué tipo de producto clasificaste y qué controles omitiste. Omitir debe ser visible y auditable, nunca silencioso: un "no se identificaron vectores de inyección SQL" generado en una librería que no tiene SQL fabrica falsa confianza.

En un **juego Godot**: cargar la skill `godot-testing`. GUT para GDScript, GdUnit4 para C#. Preferí `godot --headless` + el runner del proyecto. Omití API/DB/auth/cross-browser salvo que el título los tenga. Feel = playtest, no un assert de shader.

Para una librería de funciones puras, la mayoría de las secciones 2-6 de abajo no aplicarán; los equivalentes útiles son corrección numérica, inmutabilidad de datos que pertenecen al caller, determinismo, superficie de API, tamaño del bundle y cadena de suministro. Reemplazá las secciones inaplicables en lugar de rellenarlas.

## Secciones del plan de tests

### 1. TESTS UNITARIOS
- Identificar funciones y módulos clave que requieren unit tests
- Especificar casos límite y condiciones de frontera para cada uno
- Definir estrategia de mock/stub para dependencias externas
- Identificar lógica que requiere cobertura exhaustiva. Si RULES.md define una política de cobertura, seguila en lugar de imponer un porcentaje propio

### 2. TESTS DE INTEGRACIÓN
- Testing de endpoints de API (validación request/response, códigos de error)
- Testing de interacción con la base de datos (operaciones CRUD, migraciones, constraints)
- Testing de integración con servicios de terceros
- Verificación de comunicación entre componentes

### 3. TESTS END-TO-END
- Escenarios de test de jornadas de usuario críticas (happy path y caminos de error)
- Consideraciones cross-browser y cross-device
- Testing de flujos de autenticación y autorización
- Verificación del flujo de datos desde el input hasta la persistencia

### 4. TESTS DE SEGURIDAD
- Testing de límites de autenticación y autorización
- Testing de validación de input e inyección (SQL, XSS, CSRF)
- Verificación de privacidad de datos (manejo de PII, cifrado)
- Testing de rate limiting y prevención de abuso

### 5. TESTS DE RENDIMIENTO
- Escenarios de load testing con umbrales esperados
- Benchmarks de tiempo de respuesta para endpoints críticos
- Límites de utilización de recursos (memoria, CPU, conexiones)
- Stress testing del comportamiento de degradación

### 6. ESTRATEGIA DE DATOS DE TEST
- Enfoque de generación de datos de test (factories, fixtures, seeds)
- Gestión del estado de la base de datos entre ejecuciones de tests
- Manejo de datos sensibles en entornos de test
- Procedimientos de limpieza de datos

## Formato de salida

Para cada RFC/feature, brindá:
- **Casos de test** con descripciones y pasos claros
- **Prioridad** (Must have / Should have / Could have) -- tomada del rating MoSCoW existente de la feature en FEATURES.md, no reasignada aquí
- **Resultados esperados** y criterios de falla
- **Prerrequisitos y dependencias**

Brindá un orden de ejecución de tests alineado con la secuencia de implementación de los RFCs. Destacá cualquier hueco de testing donde pueda hacer falta testing manual.

## AUTOCHEQUEO ANTES DE TERMINAR

- Recontá cada tabla de resumen a partir del contenido real. Nunca arrastres un recuento desde más atrás en tu propia salida.
- Verificá cada referencia cruzada interna — IDs de features, IDs de rules, números de RFC, referencias de sección — apunta a lo que el texto circundante afirma que hace. Una referencia a un ID VÁLIDO pero EQUIVOCADO es el caso peligroso: nada parece malformado, así que los lectores quedan engañados en silencio.
- Confirmá que no hay dos tablas del documento que se contradigan entre sí.
- Indicá que corriste este chequeo y qué encontró.

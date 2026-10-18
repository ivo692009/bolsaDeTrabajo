# Skill 20: Alta profesional y revisión de posible fraude

## Objetivo
Revisar nuevas altas profesionales y reportes de posible fraude, impedir duplicados y detectar intentos de eludir una desactivación mediante otro número, con evidencia mínima y decisión humana.

## Alta y control de perfiles previos
1. Obtener el teléfono únicamente del remitente WhatsApp verificado, normalizarlo a E.164 y comprobar coincidencia exacta contra perfiles activos, pendientes, suspendidos, desactivados y tombstones de prevención permitidos por la política de retención.
2. No crear un segundo perfil para el mismo número. Si existe un perfil `suspended`, `deactivated` o `permanently_deactivated`, no permitir que el flujo de alta lo reactive ni cree otro perfil; derivar al revisor autorizado para aclarar el estado.
3. Si el número es nuevo, completar el alta ordinaria y explicar que el número autentica la cuenta. Un número distinto, por sí solo, no prueba que sea otra persona ni prueba evasión.
4. Si hay señales razonables de vinculación con un perfil previamente desactivado (por ejemplo, declaración del solicitante o coincidencias de datos públicos/autodeclarados), marcar `pending_admin_review`; no publicar ni rechazar definitivamente solo por nombre, rubro, dispositivo, localidad o semejanza aislada.
5. Solicitar al solicitante una explicación neutral y permitir que aclare homónimos, cambio legítimo de titularidad o error. No revelar datos privados del titular del otro perfil.
6. Solo una persona autenticada en allowlist con rol `professional_reliability_admin` puede decidir si existe intento de elusión, mantener la revisión, autorizar el alta o rechazarla con motivo registrado. La decisión debe ser revisable. No restaurar el perfil anterior desde el alta.

## Revisión de reportes de posible estafa
1. Abrir un caso ante un reporte concreto de Cliente, Profesional o administrador; registrar ID de solicitud/perfil, fecha, categoría del reporte, relato en palabras neutrales y referencias a eventos o evidencia ya disponibles.
2. Distinguir observaciones verificables (mensajes del sistema, estados, importes confirmados) de alegaciones. No convertir cancelaciones, disputas de pago, falta de respuesta o una denuncia sin corroborar en una conclusión de fraude.
3. Pedir únicamente la información necesaria para entender el caso. No solicitar contraseñas, datos bancarios completos, documentos de identidad ni evidencia ajena al servicio por WhatsApp. Restringir adjuntos y acceso a revisores autorizados; no copiarlos a la galería ni reenviarlos a otras partes.
4. Dar a las partes afectadas una oportunidad razonable para aportar contexto cuando hacerlo no exponga a otra persona ni comprometa una revisión. Mantener comunicación neutral y no compartir acusaciones ni datos de terceros.
5. Un revisor `professional_reliability_admin` registra resultado `substantiated`, `not_substantiated` o `inconclusive`, hechos considerados, motivo, fecha e identidad administrativa. Si no puede corroborarse, usar `inconclusive`; nunca afirmar públicamente que alguien estafó.
6. Ante un riesgo operativo concreto, el revisor puede aplicar una pausa temporal de nuevas derivaciones con alcance, motivo y vencimiento registrados mientras revisa el caso. No cancelar trabajos aceptados, cobrar comisiones ni desactivar permanentemente de forma automática.
7. Si la revisión confirma incumplimiento de un trabajo acordado, derivar además el caso al flujo de confiabilidad existente; el caso de posible fraude no reemplaza sus requisitos ni duplica el conteo.

## Registro y privacidad
- Registrar `caseId`, IDs internos vinculados, estado, fechas, categoría, resumen neutral, referencias de evidencia, decisión, motivo, revisor, comunicación al afectado y cualquier restricción con vencimiento.
- No duplicar teléfonos, direcciones u otros datos personales en notas. Respetar plazos de retención y solicitudes de borrado; un tombstone identificable solo puede conservarse si la política de retención aplicable lo autoriza y limita acceso/uso a prevenir re-registros.
- No usar reconocimiento facial, búsqueda externa de identidad, perfilado por atributos sensibles ni señales de dispositivo como prueba de identidad o fraude.

## Calidad y revisión de decisiones
- Mantener separadas las métricas de reportes recibidos, hallazgos corroborados, decisiones inconclusas, altas autorizadas tras revisión y decisiones apeladas o revertidas. No optimizar por cantidad de rechazos.
- Revisar periódicamente falsos positivos y tiempos de espera de la cola; actualizar los criterios de forma aditiva, indicando versión, motivo y fecha.
- Comparar solo señales pertinentes y permitidas. No usar atributos protegidos o proxies sensibles para priorizar, bloquear o puntuar solicitantes.
- Permitir aportar contexto y pedir revisión de una decisión adversa mediante un canal realmente disponible; no prometer una apelación automatizada si no está implementada.

## Restricciones
- El chatbot puede explicar el proceso, reunir un reporte y derivarlo; no determina fraude, bloquea altas ni sanciona.
- La comparación de nombre, redes o teléfono es una señal de revisión, no prueba concluyente de identidad.
- Si no existe una forma autorizada y fiable de relacionar el nuevo número con un perfil previo, informar que el vínculo requiere revisión manual; no afirmar que el sistema puede impedir toda evasión con otro número.
- La skill define el procedimiento; hasta implementar almacenamiento, cola de revisión y controles de alta, no afirmar que la prevención o investigación se ejecutó.

## Resultado esperado
Alta aprobada, rechazada con motivo revisable o pendiente de revisión; y reportes de posible fraude tratados con trazabilidad, privacidad y decisión humana, sin presentar sospechas como hechos.

## Estado de implementación
La verificación de perfiles previos, el control de altas con otro número y la captura/revisión de reportes no están implementados en el webhook. No afirmar que una evasión fue detectada o bloqueada; el panel admite el registro manual de algunos tipos de caso.

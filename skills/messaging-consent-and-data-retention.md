# Skill 19: Consentimiento de mensajería y retención de datos

## Objetivo
Respetar la baja de WhatsApp, permitir un reconsentimiento explícito y limitar la conservación de datos identificatorios de solicitudes cerradas.

## Baja y reconsentimiento
1. Normalizar el número remitente a E.164 y clasificar el mensaje exacto `BAJA` antes de cualquier otro intent.
2. Guardar `opted_out` y la fecha en `runtime/data/messaging-preferences.xml`, identificando al remitente solo mediante HMAC-SHA256 con `WA_PREFERENCES_HMAC_KEY`.
3. No responder al mensaje de baja. Marcar el evento de Meta como procesado sin ejecutar otro comando.
4. Mientras el estado sea `opted_out`, no enviar respuestas, recordatorios, notificaciones, derivaciones ni mensajes de otro flujo a ese número. Los mensajes entrantes que no sean el comando de reconsentimiento se marcan procesados y se ignoran.
5. Solo el mensaje exacto `ACEPTO MENSAJES` elimina el registro HMAC de baja y permite retomar comunicaciones. Enviar entonces una confirmación breve de que los mensajes fueron reactivados.
6. Aplicar el control centralmente en todo envío saliente, además de antes de procesar intents entrantes, para que otros flujos no eludan la baja.
7. Mientras la baja esté vigente, conservar únicamente el HMAC, estado y fecha; no guardar el E.164 en el registro de preferencias. Al reconsentir, eliminar el HMAC de la lista de bajas. Mantener la clave HMAC estable aunque rote el App Secret de Meta.

## Retención de solicitudes
1. Cuando se cierre una solicitud, registrar `privacyRetention.closedAt` y calcular `anonymizeAfter` a 90 días.
2. Al vencer el plazo, eliminar o anonimizar `client.phone`, `serviceLocation.rawAddress` y `serviceLocation.normalizedAddress`; conservar el estado de la solicitud y la trazabilidad no identificatoria necesaria.
3. No persistir respuestas crudas de geocodificación ni coordenadas precisas.
4. La preferencia HMAC `opted_out` se conserva hasta un reconsentimiento, aun después de anonimizar los datos de una solicitud, para no volver a contactar por accidente.

## Fallos y restricciones
- Si no se puede persistir `BAJA`, no procesar otros intents ni enviar mensajes; dejar el evento reintentable y registrar solo un error técnico sin teléfono ni texto.
- No inferir reconsentimiento a partir de un mensaje común, una respuesta a una solicitud o una aceptación de oferta.
- No usar la baja para borrar una solicitud abierta ni modificar acuerdos, pagos o estados de trabajo.
- El mecanismo HMAC requiere una clave dedicada de 32 bytes aleatorios expresados como 64 caracteres hexadecimales, protegida y estable (`WA_PREFERENCES_HMAC_KEY`). No usar `WA_APP_SECRET` como sustituto.
- La anonimización requiere un planificador periódico; hasta implementarlo, presentar los 90 días como política objetivo, no como purga ejecutada.
- Aplicar también el vencimiento a los respaldos que contengan los datos; no declarar cumplido el plazo si quedan copias recuperables con teléfono o dirección.

## Estado de implementación
El bloqueo HMAC de mensajes y la plantilla de preferencias están implementados. La purga automática de datos y respaldos a los 90 días todavía requiere implementar un planificador.

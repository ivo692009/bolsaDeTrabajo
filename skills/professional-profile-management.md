# Skill 08: Autogestión del perfil profesional

## Objetivo
Permitir que un profesional administre su información y los trabajos que ofrece usando únicamente el número de WhatsApp verificado con el que escribe.

## Identificación y autorización
1. Obtener el número remitente del evento entrante de WhatsApp (ID del remitente/`wa_id`), normalizarlo a formato E.164 y buscar coincidencia exacta en el campo único de WhatsApp del XML.
2. Autorizar cambios solo si existe exactamente un perfil activo vinculado a ese número. El nombre, redes sociales, ID interno u otros datos del mensaje no sirven para autenticarse.
3. Si no hay coincidencia, no revelar perfiles ni aceptar cambios; ofrecer el flujo de alta o atender la solicitud como cliente según la intención.
4. Si hay más de una coincidencia, detener la operación y derivar a revisión; nunca elegir un perfil arbitrariamente.

## Información que puede administrar
- Consultar y modificar sus propios datos descriptivos y redes sociales.
- Indicar y actualizar si tiene trabajadores adicionales a su cargo y la cantidad entera; el conteo excluye al propio profesional.
- Declara `0` si no tiene trabajadores adicionales; el total de cuadrilla que se presenta a clientes será ese conteo más el profesional.
- Agregar rubros y tipos de trabajo ya existentes en `data/catalog/service-categories.xml`.
- Modificar sus propias descripciones, alias de servicio y disponibilidad registrada, siempre que el catálogo permita esos datos.
- Proponer un nuevo rubro o tipo de trabajo al rol `catalog_manager`; no crear categorías globales ni opciones libres directamente.
- Solicitar la pausa o reactivación de su perfil mediante la skill `professional-availability-status.md`.

## Flujo de modificación
1. Mostrar un resumen del cambio solicitado y pedir confirmación antes de persistir.
2. Validar campos y referencias del catálogo; actualizar únicamente el perfil asociado al número remitente.
3. Registrar fecha, número autenticado, campos modificados y valores previos/nuevos en la trazabilidad local.
4. Confirmar por WhatsApp qué datos se modificaron.

## Restricciones
- Un perfil profesional tiene exactamente un número de WhatsApp autenticado y ese número no puede estar asignado a otro perfil.
- El profesional no puede cambiar su número vinculado desde la autogestión ordinaria. Un cambio requiere revisión autorizada y verificación del control del nuevo número antes de reasignar el vínculo.
- No permitir borrado físico de perfiles, rubros asignados, tipos de trabajo ni historial por parte del profesional. Las solicitudes para retirar información se registran y requieren revisión autorizada; si se aprueban, se desactiva conservando la trazabilidad.
- La capacidad del profesional cambia solo mediante agregado o modificación de datos propios válidos; no se altera el catálogo común.
- No divulgar información de otros profesionales durante el proceso.
- Si la identidad del remitente es ambigua, el número no está verificado o falla la escritura XML, no aplicar el cambio.
- `additionalWorkers` debe ser un entero mayor o igual a cero; `hasAdditionalWorkers` debe ser `true` exactamente cuando el conteo sea mayor que cero.

## Resultado esperado
Cambio confirmado y guardado en el perfil correcto, asociado de forma única al número remitente, con historial de auditoría y sin borrado arbitrario.

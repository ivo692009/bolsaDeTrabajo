# Skill 18: Solicitud de borrado de datos del profesional

## Objetivo
Permitir que un profesional solicite la eliminación de sus datos y requerir decisión manual de un administrador autenticado mediante allowlist.

## Solicitud del profesional
1. Identificar al solicitante exclusivamente por el número remitente verificado de WhatsApp y una coincidencia única con su perfil.
2. Confirmar que la persona solicita borrar sus datos y explicar que la solicitud queda pendiente de revisión manual.
3. Crear un código de solicitud y registrar estado, fecha y referencia al perfil; no copiar el teléfono al registro de borrado.
4. Cambiar inmediatamente el perfil a `deletion_requested` y `availabilityStatus=inactive` para ocultarlo de búsquedas y evitar nuevas ofertas. No cancelar ni alterar trabajos existentes.
5. Notificar al administrador por canal autorizado o dejar la solicitud visible en la cola local de revisiones.

## Revisión manual
1. El revisor debe estar habilitado con el rol `commission_admin` en `runtime/data/admin-whatsapp-numbers.xml`.
2. Antes de aprobar, revisar solicitudes abiertas, disputas, comisiones pendientes y obligaciones de conservación. No borrar información necesaria para resolverlas.
3. El administrador aprueba o rechaza manualmente y registra su ID de allowlist, fecha y motivo, sin copiar su teléfono al historial.
4. Si rechaza, restaurar el estado de disponibilidad anterior y el estado del perfil, y dejar el motivo asociado a la solicitud.
5. Si aprueba, anonimizar el perfil: eliminar nombre, teléfono, redes sociales, rubros, zonas, horarios, cuadrilla y referencias de galería; mantener solo un tombstone técnico no identificable y la constancia mínima de la decisión.
6. El borrado de archivos multimedia asociados se realiza localmente y se registra el resultado. No borrar comprobantes o datos financieros sujetos a revisión/retención antes de resolver esas obligaciones.

## Restricciones
- Nunca aceptar ni ejecutar borrado por una solicitud de otro número o por un comando de administrador sin allowlist/rol válido.
- La petición no elimina datos por sí sola; solo la aprobación manual autoriza anonimización.
- No borrar solicitudes, comisiones o registros obligatorios mediante una acción global; bloquear la aprobación si existen asuntos abiertos.
- No confirmar que el borrado está completo hasta que perfil y archivos autorizados hayan sido tratados.

## Resultado esperado
Solicitud trazable en estado `pending_admin_review`, `rejected` o `approved_anonymized`, revisada por un administrador autenticado y sin exponer el número del solicitante en la cola.

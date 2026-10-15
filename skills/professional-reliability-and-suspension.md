# Skill 18: Revisión de cumplimiento y suspensión profesional

## Objetivo
Registrar de forma auditable los trabajos acordados que no se completaron, determinar si el incumplimiento es atribuible al Profesional y aplicar suspensiones proporcionales sin generar comisiones no confirmadas.

## Requisitos para abrir un caso elegible
- La solicitud debe identificar a un Cliente y un Profesional.
- Ambas partes deben haber confirmado el alcance, el subtotal de mano de obra y la duración del trabajo. La aceptación de una oferta por sí sola no constituye un acuerdo de trabajo para esta política.
- Una cancelación, una falta de respuesta o un reporte unilateral solo abre una revisión; no prueba por sí mismo la responsabilidad del Profesional ni suma un caso.
- Cada solicitud puede producir como máximo un caso computable.

## Flujo de revisión
1. Registrar en la solicitud el reporte, la fecha, el estado del acuerdo y las confirmaciones existentes; conservar los valores acordados y el historial.
2. Derivar el caso a una persona autenticada con rol `professional_reliability_admin` en la allowlist administrativa.
3. Registrar una decisión explícita: `attributable_to_professional`, `not_attributable_to_professional` o `inconclusive`, junto con motivo, revisor y fecha.
4. Solo `attributable_to_professional` cuenta como caso de incumplimiento. Una decisión inconclusa no se cuenta ni se convierte automáticamente en suspensión.
5. Mantener la revisión de confiabilidad separada del cierre de comisión: si Cliente y Profesional no confirman explícitamente que el trabajo se completó, no se cobra comisión, incluso si la revisión atribuye el incumplimiento al Profesional.

## Regla de suspensión
1. Contar casos confirmados, atribuibles al Profesional y aún no asociados a una sanción dentro de la ventana móvil de los últimos 60 días.
2. Al llegar a tres casos elegibles, crear una única suspensión de 60 días. Asociar esos casos a la suspensión para que no vuelvan a dispararla mientras continúan dentro de la ventana.
3. Incrementar `reliabilityHistory.totalSuspensions` una sola vez por suspensión. El historial de suspensiones es acumulativo y no se reinicia al reactivar la cuenta.
4. En la primera y segunda suspensión, establecer el estado de perfil `suspended`; en la tercera suspensión acumulada, establecer `deactivated` con vencimiento a 60 días.
5. Mientras esté `suspended`, `deactivated` o `permanently_deactivated`, excluir el perfil de búsquedas y ofertas nuevas. No cancelar automáticamente trabajos ya aceptados.
6. Antes de cumplir los 60 días de una suspensión o de la desactivación temporal por tercera suspensión, solo un administrador autorizado puede reactivar el perfil mediante una decisión explícita y registrada. Si no existe esa decisión, reactivar automáticamente al cumplirse los 60 días.
7. Después de reactivarse tras la tercera suspensión, contar nuevos casos atribuibles no asociados a una sanción dentro de una ventana móvil de 60 días. Si alcanza tres, establecer `permanently_deactivated`: no hay reactivación automática ni por vencimiento; solo una decisión administrativa explícita puede restablecer el perfil.

## Registro mínimo
- En cada solicitud, `nonCompletionCase`: estado, fecha de acuerdo, reporte, decisión, atribución, motivo, revisor, fecha de revisión e ID de suspensión asociada.
- En el perfil, `reliabilityHistory`: contador acumulado y eventos de suspensión/desactivación con tipo, estado, inicio, vencimiento, causa, revisor y decisión de reactivación.
- Guardar las transiciones de estado de forma idempotente y persistirlas antes de confirmar una acción por WhatsApp.
- No incluir números de WhatsApp en los motivos ni duplicar datos personales en el historial sancionatorio; usar los IDs internos de solicitud y perfil.

## Restricciones
- El Bot no determina responsabilidad ni aplica sanciones a partir de lenguaje natural, una acusación unilateral o falta de respuesta.
- El Profesional no puede borrar ni modificar casos o sanciones desde su autogestión.
- Un administrador no puede alterar un acuerdo de trabajo ni marcarlo como completado para habilitar una comisión.
- La pausa voluntaria (`availabilityStatus=inactive`) es independiente de los estados disciplinarios `suspended`, `deactivated` y `permanently_deactivated`.
- Cualquier operación de reactivación debe respetar el estado de baja de datos si existe una solicitud de borrado pendiente.

## Estado de implementación
La política y los campos de plantilla están especificados. El webhook todavía no implementa creación de solicitudes y acuerdos, revisión administrativa de estos casos, contador de sanciones ni vencimiento/reactivación automática. No presentar estas sanciones como activas hasta implementar los flujos y el planificador.

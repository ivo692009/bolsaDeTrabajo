# Skill 15: Acuerdo y seguimiento de duración del trabajo

## Objetivo
Registrar el plazo que acuerdan Cliente y Profesional, medir el tiempo real de trabajo y consultar a ambas partes al llegar la fecha prevista de finalización.

## Flujo de acuerdo
1. Después de aceptar la oferta, registrar cada tarea y su duración estimada en minutos de mano de obra/ejecución.
2. Mostrar a Cliente y Profesional el mismo desglose de tareas y duración total propuesta.
3. Guardar `confirmedByClientAt` y `confirmedByProfessionalAt` solo cuando ambos confirmen exactamente la misma duración.
4. Si una parte cambia la duración, reiniciar ambas confirmaciones; no usar estimados contradictorios como plazo acordado.

## Inicio y trazabilidad
1. Cuando empieza el trabajo, el Profesional informa el inicio por WhatsApp; el Cliente confirma ese inicio.
2. Solo al contar con ambas confirmaciones se fija `startedAt`; calcular `expectedCompletionAt = startedAt + agreedDurationMinutes`.
3. Registrar cambios de alcance, pausas, reinicios y modificaciones del plazo como eventos con actor y fecha; conservar el plazo anterior.
4. Un cambio de duración durante la ejecución requiere confirmación de ambas partes y recalcula la hora prevista desde el inicio original o desde el reinicio acordado, según quede registrado.

## Confirmación de finalización
1. Al llegar `expectedCompletionAt`, enviar por WhatsApp a Cliente y Profesional una consulta neutral: si el trabajo se completó correctamente, sigue en curso o se canceló.
2. No marcar el trabajo como completado a partir del reloj ni de la respuesta de una sola parte.
3. Si ambos confirman que terminó correctamente, registrar `completedAt`, calcular el tiempo transcurrido desde `startedAt` y continuar con reseña y comisión.
4. Si sigue en curso, pedir a ambas partes un nuevo plazo y confirmarlo antes de actualizar la previsión.
5. Si se cancela, aplicar la regla de cancelación y no cobrar comisión.
6. Si hay desacuerdo o silencio, reintentar según la política de seguimiento vigente y escalar/cerrar sin comisión conforme a esa regla.

## Restricciones
- Duración en minutos como entero positivo; la fecha prevista se deriva del inicio confirmado y de la zona horaria configurada.
- El estimado no garantiza que el trabajo termine a tiempo y nunca constituye una reserva ni una confirmación de finalización.
- No sobrescribir acuerdos ni horarios anteriores; conservar eventos de auditoría.
- No pedir ni mostrar información de contacto adicional para confirmar el plazo.

## Resultado esperado
Plazo común confirmado, hora real de inicio trazable, fecha estimada de término calculada y confirmación de finalización solicitada a ambas partes en el momento previsto.

## Estado de implementación
El modelo y el flujo están especificados. El servicio actual aún no incluye un planificador de mensajes; la programación efectiva de consultas requiere implementar ese componente antes de producción.

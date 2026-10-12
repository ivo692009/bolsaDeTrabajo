# Skill 11: Revisión administrativa de comisiones (`commission_admin`)

## Objetivo
Permitir que una persona administradora revise manualmente el comprobante privado de una comisión y registre si el profesional cumplió el pago.

## Acceso
- Solo el rol `commission_admin` accede a la evidencia en `evidence/commission-payments/<request-id>/`.
- Validar rol, sesión y solicitud antes de mostrar un archivo.
- No compartir capturas con clientes, profesionales distintos al remitente ni galería pública.

## Flujo de revisión
1. Abrir la solicitud y comprobar que exista una única comisión a cargo del profesional, que el trabajo esté confirmado como `completed` por ambas partes y que la solicitud no esté cancelada o disputada.
2. Comparar la captura con el importe esperado de comisión en ARS enteros, fecha, destinatario y referencia visibles.
3. Comprobar duplicados contra los comprobantes ya registrados para esa solicitud u otras solicitudes.
4. Elegir un resultado: `payment_accepted`, `payment_rejected` o `inconclusive`.
5. Guardar resultado, motivo, método `manual_visual_review`, identidad del revisor, fecha y referencia al comprobante.
6. Si se acepta, marcar `paymentStatus=paid` y `paidByAdminReview=true`, y guardar `acceptedByAdminAt`, `reviewedBy` y `reviewedAt`. Esto registra que Administración considera cumplido el compromiso tras inspección manual; mantener `bankDepositVerified=false` porque no hay conciliación bancaria automática.
7. Si se rechaza o queda inconcluso, mantener la misma comisión pendiente y notificar al profesional por WhatsApp para que aclare o reenvíe la evidencia. Nunca crear un segundo cargo.

## Restricciones
- No editar el importe acordado ni la comisión desde esta skill.
- No aceptar pruebas de un importe diferente al esperado sin registrar y resolver la discrepancia.
- No marcar `paymentStatus=paid` para una captura ilegible, incompleta, reutilizada o vinculada a otra solicitud.
- Al informar el estado, decir “pago aceptado por revisión administrativa” y no “depósito verificado por el banco”.
- No borrar el archivo ni la decisión anterior; correcciones generan nuevos eventos de auditoría.

## Resultado esperado
Una decisión administrativa trazable sobre la misma obligación de comisión; evidencia retenida localmente y estado bancario diferenciado del resultado visual.

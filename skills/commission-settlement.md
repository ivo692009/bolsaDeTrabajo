# Skill 07: Liquidación de comisión y comprobante

## Objetivo
Liquidar una sola comisión por trabajo completado y conservar de forma privada la evidencia de transferencia enviada por el profesional.

## Flujo
1. Esperar que Cliente y Profesional confirmen que el trabajo se completó. Si ambos confirman cancelación, cerrar sin comisión. Si discrepan, solicitar confirmación nuevamente una vez y luego escalar a revisión sin cobrar.
2. Leer la suma de importes de mano de obra por servicio, confirmada por ambas partes. Excluir materiales, trámites e importes adicionales.
3. Calcular una única comisión: 5% del subtotal de mano de obra, en pesos argentinos, redondeada hacia abajo al peso entero. Ejemplo: ARS 12.345 x 0.05 = ARS 617,25; la comisión es ARS 617.
4. Comunicar al Profesional únicamente el importe de la comisión adeudada y pedir un comprobante de transferencia por ese importe; no pedir un comprobante del precio total del trabajo.
5. Recibir la imagen por la API oficial de WhatsApp, almacenarla fuera de la galería pública bajo `evidence/commission-payments/<request-id>/` y guardar su ruta relativa y metadatos en el XML de solicitudes.
6. Mantener la evidencia como `proof_submitted` / `pending_admin_review` hasta la revisión del rol `commission_admin`.
7. `commission_admin` compara importe, fecha, destino y referencia visibles con la comisión esperada; registra `visually_reviewed` o `rejected`, quién revisó, cuándo y notas.
8. Si Administración acepta la captura, marcar `paymentStatus=paid` y `paidByAdminReview=true`, conservando `bankDepositVerified=false`; esto representa cumplimiento aceptado manualmente, no conciliación bancaria automática. Reenvíos actualizan la evidencia de esa misma comisión.

## Roles y permisos
- El Cliente confirma la finalización correcta del trabajo.
- El Profesional confirma el precio acordado y envía el comprobante de su comisión.
- El Bot calcula, notifica y registra estados; no puede declarar por sí mismo un comprobante verificado.
- La persona revisora autorizada accede a la evidencia privada y registra la decisión de verificación.

## Restricciones
- La comisión es única por solicitud completada, la paga el Profesional y equivale al 5% de la suma confirmada de mano de obra.
- Usar ARS y redondear hacia abajo al peso entero. Cancelaciones confirmadas por ambas partes no generan comisión.
- Solicitar evidencia solo por el importe de la comisión esperada. No pedir al Profesional una captura del pago total del Cliente.
- La revisión administrativa puede aceptar el compromiso de pago; no afirmar que el depósito se verificó automáticamente con el banco.
- Guardar evidencia con acceso restringido; no incluirla en la galería de trabajos, respuestas a clientes ni enlaces públicos. No duplicar ni borrar evidencia sin dejar trazabilidad.
- Una prueba rechazada permite solicitar una nueva evidencia para la misma comisión, no cobrar otra comisión.

## Estados

`pending_completion` -> `due` -> `proof_submitted` -> `pending_admin_review` -> `paid` (aceptado por Administración; sin verificación bancaria automática)

La revisión puede llevar a `rejected` o `inconclusive`; una cancelación acordada lleva a `waived`; el silencio tras dos reintentos lleva a `closed_unconfirmed` sin comisión y un desacuerdo lleva a `on_hold` hasta resolución. Los estados previos que no aplican se omiten.

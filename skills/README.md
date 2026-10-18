# Skills del proyecto

Cada archivo describe una capacidad funcional, sus entradas, acciones y restricciones:

1. `whatsapp-messaging.md`: mensajería con WhatsApp Business Platform.
2. `availability-assistant.md`: consultas de información y disponibilidad.
3. `professional-catalog.md`: gestión del catálogo local en XML.
4. `gallery-references.md`: almacenamiento y envío de referencias visuales.
5. `service-matching.md`: intermediación y conexión tras aceptación.
6. `follow-up-reviews-commission.md`: seguimiento y reseñas.
7. `commission-settlement.md`: comisión única y comprobante privado.
8. `professional-profile-management.md`: autogestión del perfil autenticada por WhatsApp.
9. `intent-role-routing.md`: selección del flujo según intención y rol contextual.
10. `professional-availability-status.md`: pausa y reactivación del perfil profesional.
11. `commission-admin-review.md`: revisión administrativa y registro del pago.
12. `address-locality-validation.md`: geocodificación interna y validación de zona.
13. `admin-access-control.md`: autenticación administrativa mediante allowlist.
14. `media-intake-validation.md`: validación y almacenamiento de imágenes recibidas.
15. `work-duration-tracking.md`: duración acordada, inicio y finalización del trabajo.
16. `professional-data-deletion.md`: solicitud de borrado y aprobación administrativa.
17. `general-service-chatbot.md`: preguntas conversacionales con contexto editable y límites explícitos.
18. `professional-reliability-and-suspension.md`: revisión de incumplimientos acordados, patrones reiterados de cancelación, suspensiones y desactivación de cuentas.
19. `messaging-consent-and-data-retention.md`: baja/reconsentimiento por WhatsApp y anonimización de solicitudes cerradas.
20. `professional-onboarding-and-fraud-review.md`: control de altas frente a perfiles previamente desactivados y revisión humana de reportes de posible fraude.
21. `professional-prohibited-services-review.md`: evaluación incremental de tareas ilegales o dañinas antes de publicar perfiles profesionales.
22. `professional-activity-dictionary-lookup.md`: consulta selectiva de definiciones por oficio para orientar tareas con menos contexto.
23. `professional-activity-dictionary-maintenance.md`: ampliación acumulativa del diccionario, sin borrar definiciones previas.
24. `professional-registration-activity-enrichment.md`: compara las tareas declaradas al alta y amplía definiciones faltantes con fuentes web verificables.
24. `professional-registration-activity-enrichment.md`: compara las tareas declaradas al alta y amplía definiciones faltantes con fuentes web verificables.

Los XML runtime de perfiles, solicitudes y allowlist se inicializan desde plantillas de `../data/templates/` y se guardan en `../runtime/data/`, excluidos de Git. El perfil usa `../data/templates/professional-profile.template.xml`; los rubros, `../data/catalog/service-categories.xml`; las zonas, `../data/policies/location-policy.xml` y `../data/templates/service-area.template.xml`. La fuente de verdad es [la especificación funcional](../docs/business/system-specification.md).

La evidencia de transferencias se almacena en `../storage/evidence/commission-payments/`, separada de la galería de referencias.

El webhook inicial de WhatsApp está implementado en `../src/whatsapp/whatsapp-bot.ps1`; la configuración Meta y sus límites están en [la guía de operación](../docs/operations/whatsapp-bot.md).

Las plantillas genéricas de `templates/` siguen disponibles para agregar capacidades futuras. Los parámetros comerciales, legales y de integración deben confirmarse antes de producción.

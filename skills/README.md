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

Los XML runtime de perfiles, solicitudes y allowlist se inicializan desde plantillas de `../data/templates/` y no se versionan. El perfil usa `../data/templates/professional-profile.template.xml`; los rubros, `../data/service-categories.xml`; las zonas, `../data/location-policy.xml` y `../data/templates/service-area.template.xml`. La fuente de verdad es `../business-rules/system-specification.md`.

La evidencia de transferencias se almacena en `../evidence/commission-payments/`, separada de la galería de referencias.

El webhook inicial de WhatsApp está implementado en `../scripts/whatsapp-bot.ps1`; la configuración Meta y sus límites están en `../scripts/README.md`.

Las plantillas genéricas de `templates/` siguen disponibles para agregar capacidades futuras. Los parámetros comerciales, legales y de integración deben confirmarse antes de producción.

# Skills y reglas de negocio para intermediación de servicios

Esta carpeta contiene una base inicial para una plataforma que conecta clientes con profesionales y gestiona la comunicación por WhatsApp.

## Estructura

- `.gitignore`: excluye secretos y datos runtime privados.
- `skills/`
  - `whatsapp-messaging.md`
  - `availability-assistant.md`
  - `professional-catalog.md`
  - `gallery-references.md`
  - `service-matching.md`
  - `follow-up-reviews-commission.md`
  - `commission-settlement.md`
  - `professional-profile-management.md`
  - `intent-role-routing.md`
  - `professional-availability-status.md`
  - `commission-admin-review.md`
  - `address-locality-validation.md`
  - `admin-access-control.md`
  - `media-intake-validation.md`
  - `templates/`
    - `skill-template.yaml`
    - `skill-template.md`
- `gallery/`
  - `README.md`
- `data/`
  - `templates/professionals.template.xml`
  - `templates/requests.template.xml`
  - `templates/admin-whatsapp-numbers.template.xml`
  - `professionals.xml` (runtime local, no versionado)
  - `service-categories.xml`
  - `requests.xml` (runtime local, no versionado)
  - `templates/service-category.template.xml`
  - `templates/service-area.template.xml`
  - `templates/professional-profile.template.xml`
  - `templates/webhook-events.template.xml`
  - `webhook-events/2026.xml`
  - `location-policy.xml`
  - `admin-whatsapp-numbers.xml` (runtime local, no versionado)
- `evidence/`
  - `commission-payments/README.md`
- `scripts/`
  - `whatsapp-bot.ps1`
  - `whatsapp-bot.env.example`
  - `README.md`
- `business-rules/`
  - `business-rules.yaml`
  - `system-specification.md`

## Fuente de verdad

`business-rules/system-specification.md` es la fuente de verdad funcional del proyecto. `business-rules/business-rules.yaml` y los XML de `data/` deben mantenerse alineados con esa especificación.

## Cómo usarlo

1. Consulta la fuente de verdad y las skills de `skills/` para sus procesos.
2. Usa los XML de `data/` como ejemplos locales de profesionales, rubros y solicitudes; sustituye los valores de muestra antes de usar datos reales.
3. Completa parámetros pendientes en `business-rules/business-rules.yaml`, como límite geográfico oficial, límites de medios, plazo inicial de seguimiento y vencimiento de ofertas. La comisión es única: 5% de mano de obra a cargo del profesional, en ARS enteros.
4. Sigue `scripts/README.md` para configurar y ejecutar el webhook de WhatsApp.
5. Para nuevas capacidades, parte de `skills/templates/` y conserva identificadores y criterios verificables.

## Objetivo

El webhook de WhatsApp tiene una implementación inicial en PowerShell. No se crean solicitudes nuevas hasta configurar el polígono oficial de Rawson/Playa Unión; Google Maps Geocoding API solo valida internamente direcciones.

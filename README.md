# Plataforma de intermediación de servicios

Proyecto inicial para conectar por WhatsApp a clientes con profesionales de Rawson y Playa Unión, Chubut. El MVP usa un webhook en PowerShell, reglas deterministas y archivos XML locales. El chatbot general con OpenAI es opcional.

## Estructura del repositorio

| Carpeta | Contenido |
| --- | --- |
| `src/whatsapp/` | Implementación del webhook de WhatsApp. |
| `config/business/` | Reglas estructuradas y contexto editable del chatbot. |
| `config/whatsapp-bot.env.example` | Nombres de variables de entorno sin secretos. |
| `data/catalog/` | Catálogo estático de rubros y trabajos. |
| `data/policies/` | Política de zonas y límites geográficos. |
| `data/templates/` | Plantillas XML para configuración y registros runtime. |
| `runtime/` | Perfiles, solicitudes, eventos, conversaciones y respaldos locales; excluido de Git. |
| `storage/gallery/` | Imágenes autorizadas de trabajos, separadas por perfil. |
| `storage/evidence/commission-payments/` | Comprobantes privados de comisión. |
| `docs/business/` | Especificación funcional, fuente de verdad del proyecto. |
| `docs/operations/` | Configuración y operación del webhook. |
| `skills/` | Procedimientos funcionales y sus plantillas. |

La configuración privada permanece en `.env` en la raíz, excluido de Git. No agregues secretos ni datos reales a plantillas o archivos versionados.

## Fuente de verdad y reglas

[La especificación funcional](docs/business/system-specification.md) define el comportamiento esperado. [Las reglas estructuradas](config/business/business-rules.yaml), [el contexto editable del chatbot](config/business/chatbot-context.md), los catálogos y las plantillas deben mantenerse alineados con ella. Las skills de `skills/` describen procedimientos y restricciones por capacidad.

## Puesta en marcha

1. Revisa la especificación y las skills relevantes antes de cambiar flujos.
2. Completa los parámetros pendientes en `config/business/business-rules.yaml`, como el límite geográfico oficial y los límites de medios. El seguimiento posservicio se programa para `expectedCompletionAt` cuando ambas partes confirmaron inicio y duración.
3. Configura Meta y ejecuta el webhook siguiendo [la guía de operación](docs/operations/whatsapp-bot.md).
4. Configura `WA_PREFERENCES_HMAC_KEY` en `.env` con una clave aleatoria de 32 bytes codificada como 64 caracteres hexadecimales; es necesaria para conservar bajas `BAJA` de forma seudonimizada y debe mantenerse estable. Para habilitar respuestas conversacionales, configura `OPENAI_API_KEY`; `OPENAI_MODEL` es opcional. Ajusta el alcance aprobado en `config/business/chatbot-context.md`.
5. Usa únicamente datos ficticios en muestras versionadas. Los datos locales runtime se crean desde `data/templates/` y no se suben al repositorio.

## Estado del MVP

El webhook permite buscar perfiles del catálogo y ejecutar algunas acciones autenticadas. Todavía no crea solicitudes nuevas ni valida direcciones: falta configurar el polígono oficial de Rawson/Playa Unión. El chatbot general contesta solo dentro del contexto del proyecto y no ejecuta acciones de negocio.

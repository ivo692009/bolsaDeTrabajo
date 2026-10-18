# Plataforma de intermediación de servicios

Proyecto inicial para conectar por WhatsApp a clientes con profesionales de Rawson y Playa Unión, Chubut. El MVP usa un webhook en PowerShell, reglas deterministas y archivos XML locales. El chatbot general con OpenAI es opcional.

## Estructura del repositorio

| Carpeta | Contenido |
| --- | --- |
| `src/whatsapp/` | Implementación del webhook de WhatsApp. |
| `admin-panel/` | Panel HTML/JavaScript local para revisiones manuales. |
| `config/business/` | Reglas estructuradas y contexto editable del chatbot. |
| `config/whatsapp-bot.env.example` | Nombres de variables de entorno sin secretos. |
| `data/catalog/` | Catálogo estático de rubros y trabajos. |
| `data/dictionaries/` | Definiciones compactas y ampliables de actividades por oficio. |
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
4. Para revisiones administrativas locales, configura `runtime/data/admin-whatsapp-numbers.xml` con los roles autorizados y ejecuta `npm start` desde la raíz; consulta la guía del [panel administrativo](admin-panel/README.md). No requiere instalar dependencias. Mantén detenido el webhook mientras el panel actualiza los mismos XML.
5. Configura `WA_PREFERENCES_HMAC_KEY` en `.env` con una clave aleatoria de 32 bytes codificada como 64 caracteres hexadecimales; es necesaria para conservar bajas `BAJA` de forma seudonimizada y debe mantenerse estable. Para habilitar respuestas conversacionales, configura `OPENAI_API_KEY`; `OPENAI_MODEL` es opcional. Ajusta el alcance aprobado en `config/business/chatbot-context.md`.
6. Usa únicamente datos ficticios en muestras versionadas. Los datos locales runtime se crean desde `data/templates/` y no se suben al repositorio.

## Comandos de desarrollo

Node.js 18 o posterior permite ejecutar los comandos del panel. No se requieren paquetes npm externos ni `npm install`.

```sh
npm start       # Inicia el panel administrativo local
npm test        # Ejecuta pruebas de integración del panel
npm run check   # Valida la sintaxis JavaScript y ejecuta las pruebas
```

Las pruebas de integración están en `tests/admin-panel.integration.test.js`; utilizan datos y runtime temporales, separados de los registros locales.

## Estado del MVP

El webhook permite buscar perfiles del catálogo y ejecutar algunas acciones autenticadas. Todavía no crea solicitudes nuevas ni valida direcciones: falta configurar el polígono oficial de Rawson/Playa Unión. El chatbot general contesta solo dentro del contexto del proyecto y no ejecuta acciones de negocio.

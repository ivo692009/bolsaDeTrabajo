# Datos versionados

- `catalog/` contiene rubros, tipos de trabajo y sus alias.
- `policies/` contiene las zonas y política de ubicación.
- `templates/` define la forma de los XML locales que el webhook crea o actualiza bajo `../runtime/`.

El catálogo y las políticas son configuración versionada; los registros reales no se guardan aquí. La fuente funcional es `../docs/business/system-specification.md`.

# Datos locales de ejecución

Esta carpeta contiene datos runtime que pueden incluir información personal, identificadores de Meta, historial de mensajes, preferencias seudonimizadas y respaldos. El contenido está excluido de Git. Los XML de profesionales, solicitudes, allowlist y preferencias de mensajería se inicializan desde `../data/templates/` cuando faltan.

No copies aquí secretos versionables ni uses estos archivos para guardar credenciales. Restringe el acceso a la cuenta del proceso y aplica una política de retención y respaldo antes de operar con datos reales. `data/messaging-preferences.xml` contiene HMACs basados en `WA_PREFERENCES_HMAC_KEY`; protege la clave por separado y mantenla estable para preservar las bajas.

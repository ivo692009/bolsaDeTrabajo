# Configuración

- `business/` contiene las reglas estructuradas y el contexto editable del chatbot. La especificación principal está en `../docs/business/system-specification.md` y prevalece sobre el contexto del chatbot.
- `whatsapp-bot.env.example` enumera las variables de entorno; los valores secretos se guardan solo en `.env` en la raíz o en el entorno protegido del proceso.

No pongas secretos, teléfonos reales ni datos runtime en esta carpeta.

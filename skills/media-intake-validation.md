# Skill 14: Recepción y validación de archivos multimedia

## Objetivo
Guardar fotos de trabajos y comprobantes de transferencia de forma segura, evitando archivos inválidos, duplicados o exposición accidental.

## Flujo
1. Aceptar solo tipos de medios configurados para el caso: fotos de portafolio o imágenes de comprobante.
2. Verificar tamaño máximo, formato permitido, MIME declarado y tipo real del contenido; rechazar archivos que no cumplan límites.
3. Descargar desde Meta con URL temporal por HTTPS, validar expiración y comprobar que el archivo recibido no esté vacío ni truncado.
4. Generar un nombre interno aleatorio; nunca usar el nombre entregado por el remitente como ruta.
5. Para portafolio, guardar en galería local y relacionar con el perfil solo después de validar consentimiento.
6. Para comprobantes, guardar exclusivamente bajo `storage/evidence/commission-payments/<request-id>/`, con permisos privados; no copiar a galería.
7. Registrar tamaño, tipo detectado, remitente, fecha, hash criptográfico, categoría y estado de validación en XML. No guardar tokens ni URLs temporales.
8. Evitar duplicados por hash dentro del mismo flujo. Si la descarga falla, informar que no se recibió y pedir reenvío; no registrar éxito.

## Restricciones
- Mantener límites de tamaño y formatos como configuración explícita alineada con Meta y la capacidad del servidor.
- Si los límites o tipos permitidos no están configurados, no aceptar el archivo para uso operativo; solicitar configuración administrativa.
- No ejecutar ni servir archivos subidos como contenido activo.
- No confiar únicamente en extensión o MIME declarado.
- No registrar el contenido de imágenes en logs; restringir acceso según tipo y rol.
- Si el tipo real no puede validarse, rechazar o mantener el archivo en cuarentena privada hasta revisión.

## Resultado esperado
Archivo validado y guardado en su ubicación privada o pública correspondiente, con referencia trazable; si falla cualquier verificación, no se usa ni se confirma su recepción.

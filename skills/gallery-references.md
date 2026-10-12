# Skill 04: Galería y referencias visuales

## Objetivo
Vincular fotos de trabajos con el profesional correspondiente y compartir referencias solicitadas por el cliente.

## Acciones
- Registrar archivos de imagen en almacenamiento local con identificadores estables.
- Relacionar cada archivo con el ID del profesional en el catálogo, evitando guardar rutas rotas.
- Buscar referencias pertinentes por profesional o categoría.
- Enviar las imágenes locales como adjuntos en la conversación de WhatsApp mediante la API oficial de Meta cuando el cliente las solicite.

## Entradas
- ID del profesional, categoría o referencia solicitada.
- Metadatos del archivo y consentimiento asociado.

## Restricciones
- No guardar imágenes dentro del XML; almacenar rutas relativas o IDs de archivo.
- Verificar autorización para almacenar y compartir cada foto, incluyendo permisos de las personas identificables.
- No compartir imágenes que revelen datos privados, ubicación sensible o información ajena al trabajo.
- Validar que el archivo exista y sea accesible antes de ofrecerlo.
- No reemplazar una imagen adjunta por enlaces a almacenamiento o sitios externos.
- No afirmar que una foto corresponde a un profesional si la relación no está verificada.

## Resultado esperado
Referencias pertinentes y autorizadas listas para compartir, o una explicación breve si no hay material disponible.

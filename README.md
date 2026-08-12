# UMA SETRAM — Registro diario de trabajos

Aplicación institucional Android para registrar y supervisar los trabajos diarios del personal TIC, Mecánica, Electromecánica, Restauración y Maestranza.

## Componentes

- `uma_android/`: aplicación móvil desarrollada con Flutter.
- `google-apps-script/Code.gs`: servicio web que conecta la aplicación con Google Sheets.

## Funciones principales

- Usuarios operativos, supervisores, responsables, jefes y superadministrador.
- Contraseña inicial temporal y cambio obligatorio.
- Registro de múltiples trabajos diarios en buses o patios.
- Número de OT para buses, materiales, horarios en formato de 24 horas y porcentaje de avance.
- Continuación de trabajos pendientes y bloqueo de trabajos finalizados.
- Catálogos administrables de buses y patios.
- Estadísticas y dashboard por personal, área y patio.
- Hojas mensuales automáticas en Google Sheets.

## Configuración

1. Crear una hoja de Google Sheets y ajustar `BOOK_ID` en `google-apps-script/Code.gs`.
2. Publicar Apps Script como aplicación web y configurar su URL en `uma_android/lib/main.dart`.
3. Ejecutar `flutter pub get` dentro de `uma_android`.
4. Para una compilación release, crear una clave privada Android y un archivo `uma_android/android/key.properties` local. Estos archivos están excluidos del repositorio por seguridad.

## Seguridad

No se incluyen claves privadas de firma, contraseñas personales, sesiones ni archivos APK. La contraseña inicial es temporal y la aplicación obliga a cambiarla en el primer ingreso.

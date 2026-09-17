# Hammerspoon · Panel de texto y Deck

Atajos para trabajar con texto, organizar ventanas y abrir grupos de páginas en perfiles de Safari. El proyecto está escrito en Lua y se carga desde `~/.hammerspoon/init.lua`.

Hay dos interfaces independientes:

- **Panel de texto:** lista con búsqueda, implementada con `hs.chooser`.
- **Deck:** grilla de botones con búsqueda y categorías, implementada con `hs.webview` y HTML/CSS.

## 1. Requisitos

1. Tener Hammerspoon instalado y ejecutándose, con este proyecto en `~/.hammerspoon`.
2. Tener habilitado su permiso de **Accesibilidad** en los ajustes de macOS para controlar ventanas y enviar atajos.
3. Tener Karabiner configurado para que mantener **Caps Lock** active **Hyper**:

   ```lua
   { 'ctrl', 'alt', 'cmd', 'shift' }
   ```

   La configuración de Karabiner es externa a este repositorio.

4. Para las acciones de IA, ejecutar el servidor de LM Studio y cargar el modelo configurado en `config.lua`.
5. Para los botones de Safari, crear previamente los perfiles que se usarán.

Las acciones de ventanas y Safari no necesitan LM Studio.

## 2. Atajos actuales

Mantén Caps Lock, pulsa la letra y suelta ambas teclas antes de seguir interactuando.

| Atajo | Resultado |
| --- | --- |
| Hyper + T | Panel de texto en modo reemplazar selección |
| Hyper + C | Panel de texto en modo copiar resultado |
| Hyper + E | Traducir al inglés y reemplazar directamente |
| Hyper + F | Corregir en el mismo idioma y reemplazar directamente |
| Hyper + D | Mostrar u ocultar el Deck |
| Hyper + X | Mostrar u ocultar el Deck Canvas |
| Esc dentro del Deck | Cerrar el Deck |

Los atajos globales se configuran en `init.lua`.

## 3. Usar el Deck

1. Pulsa **Hyper + D** o haz clic en **▦ Deck** en la barra de menús de macOS.
2. Busca una acción por su nombre o selecciona **Texto e IA**, **Ventanas** o **Web**.
3. Pulsa el botón correspondiente. También puedes pulsar Enter desde el buscador para ejecutar el primer resultado.

El Deck permanece visible por encima de las ventanas normales al ejecutar acciones,
incluso cuando estas devuelven el foco a otra aplicación. Para ocultarlo usa **Esc**,
la **×** del panel, el botón de cierre de la ventana, **Hyper + D** o **▦ Deck**.
Mientras está visible, Esc se reserva para ocultar el Deck; al ocultarlo se libera.
La posición del botón en la barra de menús la administra macOS.

El selector **Texto: reemplazar selección / Texto: copiar resultado** solo afecta a las acciones de texto.

Los botones de ventanas actúan sobre la ventana que estaba activa antes de abrir el Deck. Los de Web no necesitan una ventana de origen.

La grilla ajusta sus filas al número de resultados y al tamaño disponible, sin scroll vertical. No tiene paginación: si se agregan muchos botones, conviene filtrar por categoría o búsqueda; el espacio visible sigue siendo limitado.

## 4. Trabajar con texto de otra aplicación

Ejemplo: traducir un borrador en Discord, Notas o Gmail.

1. Selecciona el texto en la aplicación de origen.
2. Abre el Deck con **Hyper + D**.
3. Selecciona el modo de resultado.
4. Pulsa **Traducir a ingles**, **Corregir mismo idioma** u otra acción.
5. Espera la respuesta de LM Studio.

El Deck recuerda la ventana de origen, permanece visible y le devuelve el foco. Después, la acción copia con ⌘C, procesa el texto y copia o pega el resultado.

- **Reemplazar selección:** úsalo en campos editables, como un borrador de correo o una nota.
- **Copiar resultado:** úsalo también para texto de lectura, como un mensaje recibido o una página web. Luego puedes pegarlo manualmente donde quieras.

### Limitaciones actuales

- Mantén la ventana original activa y conserva la selección mientras se procesa el texto. El pegado todavía no vuelve a verificar la ventana de destino después de la respuesta de LM Studio.
- Ejecuta una acción de texto por vez: comparten el portapapeles y aún no hay bloqueo durante toda la petición.
- La copia comprueba que haya texto en el portapapeles, pero no que ⌘C lo haya actualizado. Si no hay selección, podría procesar texto anterior.
- La restauración del portapapeles conserva texto; no es una copia completa de imágenes u otros formatos.
- El contexto de estilo se deduce del nombre de la aplicación activa. No identifica por sí solo Gmail u otros sitios dentro de un navegador.

### Configurar LM Studio

En `personal.lua`, la sección `ai` define servidor y modelo. `config.lua` combina esos valores con los tiempos predeterminados. Ejemplo:

```lua
lmStudioUrl = 'http://localhost:1234/v1/chat/completions',
model = 'tu-modelo-cargado',
```

El nombre debe coincidir con el modelo disponible en tu servidor. Si cambias la dirección por un servidor remoto, el texto seleccionado se enviará a ese servidor.

## 5. Crear un botón web: Safari, Chrome o Brave

Edita **`~/.config/hammerspoon/personal.lua`**, sección `webShortcuts`. `modules/deck/web_shortcuts.lua` solo carga esa sección. Cada entrada de la lista crea un botón en **Web**.

### Ejemplo completo con dos botones

Este ejemplo muestra el valor de la sección `webShortcuts` (no reemplaces todo `personal.lua` con él). Puedes adaptar las URLs; los perfiles indicados deben existir en Safari.

```lua
webShortcuts = {
  {
    id = 'web.hex',
    title = 'Hex · Safari',
    badge = 'HEX',
    profile = 'HEX',
    urls = {
      'https://app.my-hex.com',
    },
  },
  {
    id = 'web.arz_docs',
    title = 'Documentación',
    badge = 'DOC',
    profile = 'ARZ',
    urls = {
      'https://www.hammerspoon.org',
      'https://www.lua.org',
    },
  },
}
```

| Campo | Qué escribir |
| --- | --- |
| `id` | Identificador único del botón. No repetirlo en otras acciones. |
| `title` | Nombre visible en la botonera. |
| `badge` | Etiqueta corta visible, por ejemplo `HEX` o `DOC`. Es opcional; por defecto se usa `WEB`. |
| `browser` | `safari`, `chrome` o `brave`. Si se omite, se usa Safari. |
| `profile` | Opcional, solo Safari: nombre exacto del perfil. |
| `profileDirectory` | Opcional, solo Chrome/Brave: carpeta interna del perfil, como `Default` o `Profile 2`. |
| `urls` | Lista de una o más direcciones completas con `https://` o `http://`, sin espacios. |

### Pasos para agregar otro botón

1. Copia una entrada completa `{ ... },` dentro de `webShortcuts = { ... }` en el archivo personal.
2. Cambia `id` por uno que no esté usado.
3. Cambia nombre, etiqueta y perfil.
4. Escribe las URLs entre comillas, una por línea y separadas por comas.
5. Guarda el archivo y recarga Hammerspoon como se explica en la sección 9.
6. Abre **Hyper + D → Web** y prueba el botón.

No agregues un segundo `return` al archivo. Las comas separan tanto las URLs como las entradas de botones.

### Comportamiento de Safari con perfil explícito

- Cada ejecución crea una **ventana nueva** del perfil elegido.
- La primera URL se abre en la pestaña inicial; las siguientes, en pestañas nuevas de esa misma ventana.
- Se respeta el orden de la lista. No se espera a que cada página termine de cargar.
- Safari puede mostrar además las pestañas fijadas propias del perfil.
- Se usa la sesión que ya tenga ese perfil; el proyecto no guarda credenciales ni inicia sesión automáticamente.
- La función impide iniciar otro grupo mientras sigue abriendo uno.
- Mantén Safari activo durante la secuencia. Si cambia la ventana durante la apertura de pestañas, se detiene; las pestañas ya abiertas permanecen.
- Si no logra abrir el perfil, muestra una notificación tras el tiempo de espera.

La implementación usa el menú de Safari. La ruta verificada en este Mac es **File → New Window → New HEX Window**. El código incluye una ruta alternativa en español, aún no verificada en una instalación con ese idioma. Si cambian los nombres del menú, habrá que ajustar `modules/deck/browsers/safari.lua`.

### Chrome y Brave: elegir el perfil

Los nombres visibles del selector de perfiles (por ejemplo, “Juan (KingKong)”) no son necesariamente los nombres de sus carpetas. No deduzcas la carpeta por el orden del menú.

1. Abre una ventana con el perfil que quieres usar.
2. En Chrome, visita `chrome://version`. En Brave, visita `brave://version`.
3. Busca **Profile Path / Ruta del perfil**.
4. Copia únicamente el último componente: por ejemplo `Profile 2` o `Default`.
5. Úsalo como `profileDirectory` en el botón correspondiente.

Ejemplos para agregar dentro de `webShortcuts` en el archivo personal:

```lua
{
  id = 'web.chrome_work',
  title = 'Trabajo · Chrome',
  badge = 'CHR',
  browser = 'chrome',
  profileDirectory = 'Profile 2', -- Ejemplo: sustituir por tu carpeta real.
  urls = {
    'https://example.com',
    'https://www.lua.org',
  },
},
{
  id = 'web.brave',
  title = 'Lecturas · Brave',
  badge = 'BRV',
  browser = 'brave',
  urls = {
    'https://www.hammerspoon.org',
    'https://www.lua.org',
  },
},
```

Chrome y Brave se ejecutan con `--new-window` y, cuando se indica, `--profile-directory`. Las URLs se pasan como argumentos separados, sin usar una shell. Se solicita una ventana nueva con las páginas en pestañas; no se espera a que terminen de cargar. Las preferencias de inicio o restauración pueden añadir contenido adicional.

Para perfiles explícitos, se comprueba que exista la carpeta en la ubicación estándar de macOS. No se crea un perfil nuevo si el nombre es incorrecto. Instalaciones Beta, Canary o directorios de usuario personalizados no están cubiertos por esta implementación.

### Si no se indica un perfil

Omite `profile` y `profileDirectory`. No uses una cadena vacía.

- **Chrome/Brave:** se omite el argumento de perfil; el navegador decide cuál usar según su estado y configuración. Puede ser el último utilizado o mostrar su selector. No equivale a forzar la carpeta `Default`.
- **Safari:** se abren las URLs mediante el mecanismo normal de macOS. Safari decide el perfil y si reutiliza ventanas, según sus preferencias y las asignaciones por sitio. En este modo no se garantiza una ventana nueva con todas las páginas juntas.
- Para obtener un perfil concreto de forma determinista, indícalo explícitamente. Si quieres la carpeta `Default` de Chrome/Brave, usa `profileDirectory = 'Default'`.

### Función común para los tres navegadores

```lua
local ok, err = require('modules.deck.browser').open({
  browser = 'chrome',
  -- profileDirectory = 'Profile 2', -- Opcional.
  urls = { 'https://example.com', 'https://www.lua.org' },
})
if not ok then
  hs.notify.new({ title = 'Deck · Web', informativeText = err }):send()
end
```

El resultado indica si se aceptó el lanzamiento, no si las páginas ya cargaron. Los errores de ejecución posteriores se notifican sin mostrar URLs ni credenciales.

## 6. Usar Safari desde otra acción Lua (perfil explícito)

No es obligatorio crear un botón para reutilizar la función:

```lua
local browser = require('modules.deck.browser')

local ok, errorMessage = browser.open({
  browser = 'safari',
  profile = 'HEX',
  urls = {
    'https://app.my-hex.com',
    'https://www.hammerspoon.org',
  },
})

if not ok then
  hs.notify.new({
    title = 'Safari',
    informativeText = errorMessage,
  }):send()
end
```

`ok = true` significa que aceptó la solicitud, no que las páginas ya cargaron. La ejecución continúa mediante temporizadores y los errores posteriores se notifican en pantalla.

## 7. Agregar otro tipo de acción al Deck

Para una acción personalizada, agrega una llamada a `add(...)` en **`modules/deck/actions.lua`**, antes del `return M` final.

Ejemplo: abrir Notas, usando una categoría existente:

```lua
add({
  id = 'app.notes',
  title = 'Abrir Notas',
  badge = 'NOT',
  subtitle = 'Abrir la aplicación Notas',
  keywords = 'notas notes aplicación',
  category = 'Ventanas',
  requiresOrigin = false,
  run = function()
    hs.application.launchOrFocusByBundleID('com.apple.Notes')
  end,
})
```

- Usa `requiresOrigin = false` para acciones que no necesitan la ventana anterior, como abrir una aplicación.
- Si omites ese campo, el Deck exige una ventana de origen, la enfoca y llama a `run(window, mode)`. Puedes usar `window` para moverla o cambiar su tamaño.
- Para añadir un filtro de categoría nuevo, también debes agregar su botón en el `<nav>` de `modules/deck/panel.html`, con el mismo nombre en `data-category`. Las acciones aparecen en **Todas** aunque no tengan filtro propio.
- Para una secuencia de varios pasos, crea un módulo independiente y llámalo desde `run`. Espera las condiciones necesarias con temporizadores o callbacks; evita esperas que bloqueen Hammerspoon.

## 8. Agregar una acción de texto

Las acciones de texto se definen en **`modules/ai_text/actions.lua`**. Agrega una entrada a la tabla `actions`:

```lua
{
  id = 'friendly',
  title = 'Tono cercano',
  badge = 'AMIGO',
  keywords = 'amable cercano friendly',
  subtitle = 'Reescribir con un tono amable y natural',
  prompt = 'Rewrite the text in a friendly, natural tone. Keep the original language.',
},
```

Después de recargar, aparecerá tanto en el panel original como en el Deck. El color del panel original se puede personalizar en `modules/ai_text/style.lua`.

**Conserva las dos primeras acciones en su posición:** los atajos directos Hyper + E y Hyper + F actualmente las seleccionan por posición en la lista.

## 9. Guardar, recargar y comprobar

1. Guarda los archivos editados.
2. En el menú de Hammerspoon de la barra superior, selecciona **Reload Config**. También puedes ejecutar `hs.reload()` en su consola.
3. Si aparece un error, abre la consola de Hammerspoon y revisa el archivo y la línea indicados.
4. Abre el Deck y comprueba nombre, categoría y comportamiento del botón.

Para Safari, confirma visualmente el perfil y las pestañas. Para texto, prueba primero con una frase de prueba en un campo editable.

Si tienes `luac` instalado, puedes comprobar la sintaxis sin ejecutar las acciones:

```sh
cd ~/.hammerspoon
luac -p init.lua modules/deck/*.lua modules/deck/browsers/*.lua modules/ai_text/*.lua
```

Abrir `panel.html` directamente en un navegador no sustituye al Deck: Hammerspoon inyecta el catálogo y proporciona la comunicación con Lua.

## 10. Datos sensibles

**No guardar contraseñas, tokens, claves API ni URLs firmadas en el repositorio**, incluidos ejemplos, comentarios y este README.

- Las configuraciones actuales contienen nombres de perfiles y URLs sin credenciales.
- Para futuras integraciones, guardar secretos en el llavero de macOS o en un archivo privado fuera de `~/.hammerspoon`, con permisos restringidos.
- El archivo personal ya se carga desde fuera del repositorio; no está cifrado. No almacenes credenciales allí. La integración con el llavero aún no está implementada.
- No pasar secretos al HTML del Deck ni mostrarlos en logs o notificaciones.
- `.gitignore` excluye `.env`, `personal.lua`, `*.local.lua`, secretos y temporales. Ignorar un archivo no elimina versiones ya guardadas en Git.

## 11. Dónde está cada cosa

```text
init.lua                       Atajos y carga de módulos
config.lua                     Configuración de LM Studio y portapapeles
modules/
  ai_text/
    actions.lua                Catálogo y prompts de texto
    app_context.lua            Instrucciones según la aplicación activa
    chooser.lua                Panel original con búsqueda
    clipboard.lua              Copiar, pegar y restaurar texto
    init.lua                   Ejecución de acciones y atajos de texto
    lm_studio.lua              Peticiones al modelo
    style.lua                  Estilo del panel original
  deck/
    actions.lua                Catálogo de botones y funciones
    init.lua                   Ventana del Deck y comunicación con Lua
    panel.html                 Interfaz visual, búsqueda y categorías
    browser.lua                Interfaz pública común y selección del adaptador
    web_validation.lua         Validación de solicitudes, perfiles y URLs
    browsers/
      registry.lua             Datos y capacidades de cada navegador
      safari.lua               Implementación específica de Safari
      chromium.lua             Implementación compartida de Chrome y Brave
      process.lua              Lanzamiento de procesos y gestión de errores
    web_shortcuts.lua          Configuración de botones web
```

## 12. Problemas frecuentes

| Problema | Qué revisar |
| --- | --- |
| El botón nuevo no aparece | Guarda, recarga y comprueba que la entrada esté dentro de la lista correcta. |
| Hyper no responde | Revisa Karabiner, los cuatro modificadores de `init.lua` y que Hammerspoon esté ejecutándose. |
| Safari no encuentra el perfil | Comprueba mayúsculas, nombre exacto y el comando disponible en su menú. |
| Solo se abrieron algunas pestañas | La secuencia puede haberse detenido al cambiar la ventana activa. Volver a ejecutarla crea otra ventana completa. |
| Una acción de texto falla | Revisa servidor/modelo de LM Studio, selección de texto y permisos de Accesibilidad. |
| Aparece una web pidiendo iniciar sesión | Inicia sesión en el perfil elegido; cada perfil mantiene su propia sesión. |
| El HTML abierto en el navegador no funciona | Abre el Deck desde Hammerspoon con Hyper + D. |

## 13. Mantener esta guía actualizada

Cuando agreguemos una función o cambiemos su configuración, actualizar este README en el mismo cambio con:

1. El archivo que se debe editar.
2. Un ejemplo que se pueda copiar y adaptar.
3. Cómo recargar y verificar el resultado.
4. Sus requisitos y limitaciones.

### Validación realizada hasta ahora

- Deck: apariencia, búsqueda y filtros comprobados en Hammerspoon; diseño sin scroll comprobado con 12 botones antes de añadir Safari.
- Safari: apertura del botón original de una URL en el perfil HEX comprobada en este Mac.
- Función reutilizable de Safari: sintaxis y pruebas simuladas con una y tres URLs, validación de entradas, orden y bloqueo de ejecuciones simultáneas. La versión de varias URLs todavía requiere una prueba completa en Safari real.

### Referencias

- [Hammerspoon](https://www.hammerspoon.org)
- [API de Hammerspoon](https://www.hammerspoon.org/docs/)
- [Documentación de Lua](https://www.lua.org/docs.html)

- Chrome/Brave: lanzamiento y perfiles cubiertos por pruebas simuladas; pendiente de validación en los navegadores reales.
- [Directorios de perfiles de Chromium](https://chromium.googlesource.com/chromium/src/+/HEAD/docs/user_data_dir.md)
- [Argumentos de línea de comandos de Brave](https://support.brave.com/hc/en-us/articles/360044860011-How-Do-I-Use-Command-Line-Flags-in-Brave)

## 14. Arquitectura y extensión de navegadores

El punto de entrada para nuevas acciones es siempre:

```lua
require('modules.deck.browser').open({
  browser = 'chrome',
  urls = { 'https://example.com' },
})
```

El recorrido de una solicitud es:

1. `browser.lua` recibe la configuración.
2. `web_validation.lua` valida navegador, campos de perfil y URLs, y copia la lista para evitar cambios durante la ejecución.
3. `browsers/registry.lua` indica qué adaptador corresponde.
4. El adaptador ejecuta la operación: Safari usa sus menús para perfiles explícitos; Chromium comparte la implementación de Chrome y Brave.
5. `browsers/process.lua` centraliza los procesos, mantiene referencias mientras se ejecutan y notifica errores sin imprimir sus argumentos.

### Agregar otro navegador basado en Chromium

Agrega una entrada en `modules/deck/browsers/registry.lua` con:

- Una clave única que luego se usará en `browser`.
- `label`: nombre legible.
- `adapter = 'modules.deck.browsers.chromium'`.
- `bundle`: identificador real de la aplicación en macOS.
- `executable`: nombre real del ejecutable dentro de `Contents/MacOS`.
- `data`: ubicación relativa a `~/Library/Application Support`.
- `profileField = 'profileDirectory'`.

Verifica esos valores para la aplicación instalada. No es necesario modificar `browser.lua`, los botones ni copiar `chromium.lua`.

### Agregar una tecnología diferente

Crea un adaptador con `open(request, spec)` y regístralo. `request` contiene la lista de URLs validada y el perfil opcional; `spec` contiene los datos del navegador. La función devuelve `true` si acepta la ejecución o `false, mensaje` si no puede iniciarla. Los fallos posteriores deben notificarse sin exponer datos sensibles. Los campos de perfil admitidos actualmente son `profile` y `profileDirectory`; una capacidad nueva requiere ampliar explícitamente la validación y sus pruebas.

La interfaz pública valida antes de producir efectos. Los adaptadores son módulos internos. Mantén la lógica de cada tecnología dentro de su adaptador y las diferencias de instalación en el registro. Los accesos se definen en `personal.lua`; `web_shortcuts.lua` carga la sección `webShortcuts`.

### Interfaz pública

Todas las acciones usan `modules.deck.browser.open()`. El adaptador de Safari está en `modules/deck/browsers/safari.lua`; no hay un módulo intermediario ni accesos específicos como `openHex()`.

### Pruebas automatizadas

Desde la raíz del proyecto, con Lua instalado:

```sh
lua tests/browser_test.lua
lua tests/safari_test.lua
```

Las pruebas simulan Hammerspoon: no abren navegadores ni acceden a cuentas. Cubren selección de adaptadores, perfiles opcionales y explícitos, listas de una y tres URLs, orden, entradas inválidas, carpetas inexistentes, errores al iniciar procesos, exclusión de ejecuciones simultáneas de Safari, interfaz pública y extensión del registro sin cambiar el enrutador. No sustituyen una prueba real de los menús de Safari o los argumentos de cada navegador instalado.

## 15. Comparar con una botonera en hs.canvas

**Hyper + X** abre el Deck nativo de Canvas, definido en
`modules/deck/canvas_demo.lua` (se conserva el nombre del archivo por compatibilidad).
Usa el mismo catálogo `modules/deck/actions.lua` y el mismo ejecutor
`modules/deck/executor.lua` que el panel HTML. Agregar una acción al catálogo o a la
configuración personal correspondiente la incorpora a ambas interfaces.

Incluye texto e IA, ventanas, webs, tareas y luces Hue. **Los botones ejecutan
acciones reales**, incluidas las confirmaciones existentes para scripts y snapshots.
La franja **Texto: reemplazar selección / copiar resultado** cambia el modo de texto.
Selecciona primero el texto en la otra aplicación y después abre Canvas. Las acciones
que necesitan una ventana actúan sobre la que estaba activa al abrirlo; cambiar de
página o de modo conserva esa ventana. Mantén el foco en ella mientras se procesa IA.

Se abre debajo de la barra de menús, centrado horizontalmente, con ancho automático
y hasta dos filas. Las flechas **‹ / ›** cambian de página sin ejecutar acciones.
La última página conserva el tamaño y los extremos deshabilitan la flecha correspondiente.
Al volver a abrir comienza en la página 1. Por defecto hay hasta cinco columnas
(diez botones por página); puedes usar `canvasDeck = { maxColumns = 5 }` en
`personal.lua`. La pantalla puede reducir esa cantidad si no hay espacio.

Permanece abierto al ejecutar acciones y se oculta con **×**, **Esc** o **Hyper + X**.
Los colores distinguen categorías; al pasar el mouse aparece el nombre de la acción
en el pie. Las etiquetas largas pueden quedar recortadas en botones compactos.
El panel HTML conserva búsqueda y filtros; Canvas se maneja con el mouse y no ofrece
la misma accesibilidad ni navegación por teclado del HTML.

Pruebas sin ejecutar acciones externas:

```sh
lua tests/canvas_layout_test.lua
lua tests/canvas_actions_test.lua
lua tests/deck_test.lua
```

## 16. Configuración personal fuera de Git

La fuente de configuración por instalación es **`~/.config/hammerspoon/personal.lua`**. El cargador es `modules/config/personal.lua`. Es código Lua de confianza y se ejecuta al iniciar Hammerspoon. No copies archivos personales de desconocidos sin revisarlos.

Para una instalación nueva:

```sh
mkdir -p ~/.config/hammerspoon
chmod 700 ~/.config/hammerspoon
# Solo si personal.lua todavía no existe; no sobrescribas tu configuración.
cp -n ~/.hammerspoon/config.example.lua ~/.config/hammerspoon/personal.lua
chmod 600 ~/.config/hammerspoon/personal.lua
```

Edita `ai`, `webShortcuts`, `snapshots` y `scripts` en ese archivo. No guardes allí contraseñas ni claves AWS. Si falta el archivo o tiene un error Lua, se usan valores por defecto y no se cargan tus botones personales. Sin modelo configurado, configura LM Studio antes de usar IA. Guarda y selecciona **Reload Config** después de cambiarlo.

## 17. Scripts y snapshots RDS

Los scripts compartibles están en `scripts/`; los exclusivos tuyos pueden estar en `~/.config/hammerspoon/scripts/`. El ejecutor común `modules/tasks/runner.lua` usa `/bin/bash`, argumentos separados y procesos asíncronos. No evalúa comandos concatenados ni carga tu `.zshrc`.

### Crear un botón de snapshot

Agrega a `snapshots` en el archivo personal:

```lua
snapshots = {
  {
    id = 'rds.trabajo',
    title = 'Snapshot trabajo',
    profile = 'work',
    region = 'us-east-1',
    instance = 'example-db',
  },
},
```

Configura también `awsBinary` con la ruta absoluta de AWS CLI (`command -v aws`). Los perfiles y la sesión se administran con AWS CLI; no se copian claves al proyecto. Si usas SSO y expiró tu sesión, ejecuta `aws sso login --profile work` en una terminal.

1. Abre **Hyper + D → Tareas** y pulsa el snapshot deseado.
2. Se consulta STS y RDS en modo lectura para comprobar cuenta, motor y estado.
3. Confirma cuenta, perfil, región, instancia y nombre antes de crear.
4. Se vuelve a comprobar la cuenta y el estado antes de solicitar el snapshot.
5. Una notificación indica que fue solicitado. Otra informa cuando está disponible, o si no se pudo confirmar.

Nombre: **`{instancia}-yyyymmdd-hhmm-manual`**, con fecha y hora local del Mac al mostrar la confirmación. No se agrega un sufijo aleatorio: si repites en el mismo minuto puede haber colisión. Un error de creación no dispara reintentos; revisa AWS antes de volver a ejecutar.

Se crean snapshots manuales de **instancias RDS PostgreSQL**, no backups lógicos ni snapshots de clusters Aurora. Se requieren permisos de consulta de instancia/snapshot, creación de snapshot y acceso a STS. Los snapshots pueden generar cargos y no se eliminan automáticamente.

El waiter de AWS es finito. Si termina sin éxito, el snapshot puede seguir creándose: comprueba RDS y no interpretes ese resultado como que AWS canceló la operación. El script verifica instancia y estado `available` después del waiter. No valida una restauración del snapshot.

El proceso permanece en segundo plano mientras Hammerspoon siga ejecutándose. No recargues ni cierres Hammerspoon durante una tarea: se perdería su seguimiento local, aunque AWS podría seguir creando el snapshot. Las ejecuciones repetidas del mismo ID se bloquean durante la tarea; no existe coordinación con otras terminales ni Macs. No dupliques IDs o botones para un mismo destino si quieres evitar operaciones simultáneas.

El Deck muestra el último estado de la tarea en la descripción al volver a abrirlo; las notificaciones informan los cambios. No hay una barra de porcentaje en vivo ni un historial persistente. Canvas ejecuta las mismas tareas y muestra sus notificaciones.

### Otro script personal

```lua
scripts = {
  {
    id = 'script.personal',
    title = 'Mi tarea',
    script = '/Users/tu-usuario/.config/hammerspoon/scripts/mi-tarea.sh',
    args = { 'argumento-1', 'argumento-2' },
    confirm = true,
  },
},
```

Usa rutas absolutas (no `~`) y argumentos de texto. Los scripts deben terminar con código 0 para indicar éxito y distinto de 0 para un error. La salida de scripts genéricos no se imprime ni persiste automáticamente; no escribas secretos en ella. Usa rutas absolutas a herramientas dentro de tus scripts. La confirmación genérica muestra la ruta del script; el flujo RDS tiene su confirmación específica con el destino.

### Verificación sin crear recursos

```sh
python3 tests/snapshot_test.py
lua tests/runner_test.lua
lua tests/browser_test.lua
lua tests/safari_test.lua
bash -n scripts/rds-snapshot.sh
```

Las pruebas de snapshot usan un AWS CLI falso y cubren consulta sin escrituras, cuenta distinta, creación, espera fallida y verificación final. No crean snapshots reales.

Referencias: [crear snapshot](https://docs.aws.amazon.com/cli/latest/reference/rds/create-db-snapshot.html) y [esperar disponibilidad](https://docs.aws.amazon.com/cli/latest/reference/rds/wait/db-snapshot-available.html).

### Avisos de finalización de tareas

Los resultados finales (éxito o error) se envían con `withdrawAfter = 0`, para que Hammerspoon no los retire automáticamente del Centro de Notificaciones. Además se muestra un aviso superpuesto durante diez segundos. Los avisos de progreso siguen siendo temporales. Los banners y su sonido dependen de los permisos de macOS y del modo Concentración; no se cambian esos ajustes automáticamente.

El estado de la tarea puede consultarse al volver a abrir el Deck. Los avisos se centralizan en `modules/tasks/notifications.lua`. No crean ni repiten operaciones en AWS.

## 18. Luces Philips Hue

El Deck (`Hyper + D`) incluye la categoría **Luces**. Cada botón puede alternar
el encendido (`toggle`), encender (`on`) o apagar (`off`) una luz. Consulta su
estado antes de actuar y avisa si no está accesible. Estos mismos botones también aparecen en Canvas (`Hyper + X`).

### Configuración personal

Agrega esta sección a `~/.config/hammerspoon/personal.lua` (fuera del repo):

```lua
hue = {
  bridge = '192.168.1.100', -- IP local de tu Bridge
  lights = {
    { id='hue.desk', title='Escritorio', lightId='1', action='toggle' },
    { id='hue.desk.off', title='Apagar escritorio', lightId='1', action='off' },
  },
},
```

`lightId` es el identificador de la API local v1, no el nombre visible de la luz.
Cada botón necesita un `id` único. La IP y los identificadores reales no deben
copiarse al ejemplo compartido. Conviene reservar la IP del Bridge en el router.

### Vinculación y clave

El Bridge debe estar en una red accesible desde el Mac. Presiona una vez su botón
circular central y solicita inmediatamente un usuario a `POST /api`, enviando
`{"devicetype":"hammerspoon#deck"}`. Si responde `link button not pressed`,
vuelve a presionarlo y repite. Sigue la [guía oficial](https://developers.meethue.com/develop/get-started-2/).

Guarda el campo `success.username` como contraseña genérica en **Acceso a Llaveros**:

- Nombre del ítem/servicio: `hammerspoon.hue`.
- Cuenta: la IP exacta del Bridge configurada arriba.
- Contraseña: la clave generada por el Bridge.

No pegues la clave en archivos Lua, comandos del historial ni documentación.
El módulo la obtiene con `/usr/bin/security` en segundo plano; macOS puede pedir
permiso para leerla. No se incluye en los datos enviados al panel ni en los avisos.

Esta implementación usa la API local **v1 mediante HTTP**, compatible con la
vinculación existente: el tráfico entre Mac y Bridge no está cifrado. Úsala solo
en una red local de confianza; no expongas el Bridge a Internet. No implementa
API v2, escenas ni control remoto.

### Uso y diagnóstico

Recarga Hammerspoon cuando no haya tareas en curso, abre `Hyper + D` y elige
**Luces**. El botón confirma la respuesta del Bridge con un aviso de cuatro
segundos. Si una luz figura inaccesible, comprueba su alimentación y que pueda
controlarse desde la app Hue. Si hay un error del Bridge, revisa la vinculación.
Tras un tiempo de espera, comprueba el estado real antes de volver a pulsar.

Las pulsaciones simultáneas sobre una misma luz quedan bloqueadas hasta finalizar.
El estado se consulta en cada pulsación; otros controles pueden cambiarlo entre
la consulta y la orden. No hay reintentos automáticos.

Código compartido: `modules/hue/init.lua`. Prueba sin modificar luces reales:

```sh
lua tests/hue_test.lua
```

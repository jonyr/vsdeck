# VSDeck · Stream Deck de Elgato

Plugin para el Stream Deck físico con acciones de texto, presencia de Discord,
snapshots RDS y consulta de artefactos de CodePipeline. Hammerspoon ejecuta las
acciones y muestra confirmaciones, progreso y resultados en el centro de tareas.

## Alcance e inicio

Se retiraron el deck virtual HTML/Canvas, su inicializador, menú y atajos Hyper,
el selector de texto y las integraciones exclusivas de navegador, ventanas, Hue
y soundboard. Las ventanas del centro de tareas **sí se conservan**: utilizan
`hs.webview` y son necesarias para los botones físicos. También se conserva el
menú **VS Tasks**, que permite volver a abrir el centro tras iniciar una tarea.

`init.lua` solo comprueba errores de configuración y habilita `hs.ipc`.
Hammerspoon debe seguir abierto: el plugin carga sus módulos cuando se necesitan.
No se debe eliminar ese inicio mínimo mientras el plugin use el puente local.

Tras actualizar, espera a que terminen las tareas y usa **Reload Config** en
Hammerspoon. Esto elimina de memoria el deck anterior y reinicia el historial
efímero del centro. No hace falta reconfigurar los botones de Elgato.

## Configuración y dependencias

Requiere Hammerspoon con Accesibilidad; LM Studio para las acciones de texto;
AWS CLI y un perfil autenticado para AWS; Discord para presencia. Los datos
personales permanecen en `~/.config/hammerspoon/personal.lua`, fuera del repositorio.
Usa [config.example.lua](config.example.lua) como referencia sin sobrescribir tu
archivo existente. Las antiguas opciones del deck virtual ya no se utilizan.
Los parámetros de cada botón se guardan desde la aplicación Stream Deck.

## Componentes conservados

- `streamdeck/com.vsdeck.jonyr.sdPlugin/`: acciones y paneles de configuración.
- `modules/streamdeck/` y `modules/ai_text/`: selección, LLM y reemplazo de texto.
- `modules/discord/presence.lua`: presencia y mensaje de Discord.
- `modules/tasks/`: RDS, pipelines, ejecución, centro de tareas y monitor de origen.
- `scripts/rds-snapshot.sh`: verificación y creación de snapshots.
- `modules/config/`, `modules/i18n/`, `modules/notifications/`: servicios compartidos.

## Idioma y notificaciones

Los textos de interfaz se encuentran en `modules/i18n/locales/es.lua` y
`modules/i18n/locales/en.lua`. Incluyen acciones de texto, estados y confirmaciones de tareas. Los prompts de IA, IDs
internos, nombres de perfiles y títulos personalizados no se traducen. La salida
de scripts y herramientas externas conserva su idioma original.

Agrega o combina estas opciones en la tabla que devuelve tu
`~/.config/hammerspoon/personal.lua`, sin reemplazar el resto de tu configuración:

```lua
language = 'es', -- 'es' o 'en'; también admite es-AR/en-US.
notifications = {
  backend = 'notify', -- 'notify', 'alert' o 'both'.
  finalBackend = 'both', -- Finales de tareas; omitir para heredar backend.
  title = 'VSDeck',
  levels = {
    info = { enabled = true },
    success = { enabled = true },
    warning = { backend = 'alert', duration = 6 },
    error = { backend = 'both', duration = 10 },
  },
  -- style = { textSize = 18 }, -- Estilo de hs.alert.
},
```

Recarga Hammerspoon con **Reload Config** después de cambiar estas opciones.
El idioma predeterminado es español. Sin configuración, los avisos usan
notificaciones nativas y los resultados finales de tareas usan ambos canales.

La prioridad del canal es: configuración del nivel → `finalBackend` para finales
de tareas → `backend` → valor predeterminado. `duration` controla los segundos de
`hs.alert`; macOS controla la presentación de los banners nativos. `withdrawAfter`
controla la retirada de las notificaciones nativas (por defecto 5 segundos para
avisos y 0, persistente, para finales de tareas). `duration`, `withdrawAfter` y
`style` pueden configurarse globalmente o por nivel. Los títulos de tareas
personalizadas se mantienen para identificar cada operación.

Usa `levels.info.enabled = false` para silenciar información sin silenciar errores,
o `notifications.enabled = false` para desactivar todos los avisos. Las
confirmaciones de operaciones siguen siendo diálogos interactivos y no se silencian.

### Agregar mensajes

Usa una clave semántica estable y la frase completa en ambos catálogos:

```lua
["ai_text.error"] = "LM Studio devolvió un error ({status}).",
```

Desde el código:

```lua
local notifications = require('modules.notifications')
notifications.error('ai_text.error', { status = status })

local t = require('modules.i18n').t
local title = t('actions.translate_en.title')
```

`info`, `success`, `warning` y `error` resuelven traducciones y parámetros.
`notifications.text(level, message, options)` está disponible para mensajes ya
resueltos y diagnósticos externos. No agregues llamadas directas a `hs.notify` o
`hs.alert` fuera del módulo central. Las tareas pueden indicar
`{ title = job.title, final = true }` como opciones.

Los parámetros con nombre se sustituyen literalmente, incluso si contienen `%`.
Los plurales usan `{ one = "…", other = "…" }` y el parámetro numérico `count`;
español e inglés usan `one` solamente para 1. Si falta una traducción, se usa
español; si falta también allí, se muestra la clave y se registra el problema en
la consola de Hammerspoon. Agregar otro idioma requiere un catálogo, registrarlo
en `modules/i18n/init.lua` y adaptar las reglas de pluralización si corresponde.

Pruebas sin operaciones externas:

```sh
lua tests/i18n_test.lua
lua tests/notification_routing_test.lua
lua tests/notifications_test.lua
node tests/task_ui_test.mjs
```


## Desarrollo: convenciones y controles de calidad

`AGENTS.md` contiene instrucciones para los agentes y remite a `CONVENTIONS.md`
para las reglas de Lua, documentación y validación. Cada cambio requiere revisar
este README y actualizar las secciones afectadas en la misma entrega; si sigue
vigente, se deja constancia de la revisión sin agregar contenido innecesario.
StyLua aplica el formato
compartido; Luacheck detecta globales accidentales, variables sin usar y otros
problemas estáticos. Los comentarios públicos siguen el estilo LDoc y explican
contratos, efectos asíncronos y responsabilidades.

Instala las herramientas de desarrollo (Node.js y Python 3 también deben estar
disponibles para las pruebas del panel y de snapshots):

```sh
brew install lua stylua luacheck
make help
```

| Comando | Función |
| --- | --- |
| `make format` | Formatea Lua y comprueba que StyLua conserve su AST |
| `make format-check` | Verifica formato sin modificar archivos |
| `make lint` | Ejecuta Luacheck |
| `make test-unit` | Ejecuta las pruebas Lua con dobles de Hammerspoon |
| `make test-panel` | Verifica el centro de tareas HTML |
| `make test-snapshots` | Ejecuta las pruebas del script con AWS simulado |
| `make test` | Ejecuta todas las pruebas offline |
| `make check` | Verifica formato, lint y todas las pruebas |

El flujo habitual después de editar es `make format && make check`.
Las herramientas se pueden seleccionar sin editar el Makefile, por ejemplo
`make check LUA=lua5.4`. No se formatea la configuración personal externa.

GitHub Actions ejecutará `make check` en pushes y pull requests al publicar el
workflow `.github/workflows/lua-quality.yml`. Para impedir merges con fallos,
configura **Lua quality** como check obligatorio en las reglas de la rama.
Las instrucciones del agente y la verificación automática se complementan;
`AGENTS.md` por sí solo no impone una restricción técnica de Git.

## Stream Deck: snapshots manuales de AWS RDS

### Consultar artefactos de CodePipeline

Desde la versión 0.8 del plugin, arrastra **VSDeck → AWS Pipeline · Artefactos**
(**AWS Pipeline Artifacts** en inglés) a una tecla. Configura **Perfil AWS** y
**Pipeline**; opcionalmente indica **Región** y un nombre de tarea. La región vacía
usa `us-east-1`.
Pulsa **Guardar cambios** y espera la confirmación. No se guardan credenciales.

El botón muestra la consulta en el mismo **Centro de automatizaciones**:
**En curso** mientras consulta, **Historial** con el detalle abierto al terminar,
y **Atención** si falla. Consulta la ejecución más reciente al pulsar y fija su
identificador antes de obtener las revisiones; no mezcla artefactos de distintas
ejecuciones. Muestra el estado observado, el identificador de ejecución y todos
los elementos de `artifactRevisions`, con nombre, `revisionId`, `revisionSummary`
y `revisionUrl` completos. Los enlaces HTTPS se abren únicamente al pulsarlos.
Los campos no informados se muestran como «—». Un pipeline sin ejecuciones o sin
revisiones disponibles tiene un mensaje específico.

Esto consulta revisiones de artefactos de origen que devuelve CodePipeline;
no enumera archivos de artefactos de Build ni identifica qué versión está
actualmente desplegada en producción. No inicia pipelines, aprueba ni despliega.
Se necesitan permisos `codepipeline:ListPipelineExecutions` y
`codepipeline:GetPipelineExecution`. El icono pasa de azul a amarillo durante la
consulta y vuelve a azul al terminar; un fallo se representa en rojo con alerta.
Cerrar el centro no cancela la consulta. El resultado queda en el historial de
la sesión; vuelve a pulsar para actualizarlo. El tiempo máximo por llamada es
60 segundos. La consulta usa el `awsBinary` configurado para los backups.

Después de instalar esta actualización, recarga Hammerspoon cuando no haya
tareas activas y cierra/reabre Stream Deck para que registre la nueva acción.
Las pruebas automatizadas usan respuestas simuladas y no acceden a AWS.

### Títulos de todas las acciones de Stream Deck

Todas las acciones VSDeck admiten el campo nativo **Title / Título** de Stream
Deck, incluidas Translate, Correct, Structure, Email, Discord Lunch, Discord Presence y las acciones
AWS. El título es opcional y su formato se ajusta desde Stream Deck. Los cambios
de estado y de icono no lo borran. Las nuevas acciones deben mantener este soporte;
las pruebas verifican esta regla para todas las acciones del manifiesto.
Después de actualizar el plugin, cierra y vuelve a abrir Stream Deck.

### Título y color de los botones AWS

Desde la versión 0.8.1, cada botón **AWS Pipeline Artifacts** o **AWS RDS Snapshot**
permite editar su título visible en el campo nativo **Title / Título** de Stream
Deck. Puedes dejarlo vacío para mostrar solo el icono. Ese título es independiente
del **Nombre de tarea** que se muestra en el centro de notificaciones.

En el panel de la acción, **Fondo** acepta `#RRGGBB`, por ejemplo
`#7C3AED`. Pulsa **Guardar cambios**: el color se persiste por botón, incluso si
varias teclas apuntan al mismo destino. Vacío recupera el azul `#2563EB`.
Desde la versión 0.8.2, **Icono** permite elegir el color del
dibujo en reposo, independientemente del fondo: `#FFFFFF` lo mantiene blanco.
Desde la versión 0.8.3, omitir el color del icono usa blanco `#FFFFFF`; omitir
la región usa `us-east-1` tanto en CodePipeline como en RDS. El panel muestra
estos valores predeterminados y los aplica también al guardar campos vacíos.
Este campo también se guarda por botón con **Guardar cambios**.
Se mantienen el amarillo de actividad y el rojo de error. Desde la versión
0.8.4, tanto RDS como CodePipeline vuelven a los colores elegidos al completar
la operación; un backup exitoso ya no deja el icono verde fijo. El resultado
permanece disponible en el centro de notificaciones.
El formato y color del texto se ajustan desde las opciones nativas del título.
Tras actualizar, cierra y vuelve a abrir Stream Deck para registrar el título.
No hace falta recargar Hammerspoon para estos cambios visuales.

### Acción de backup real

Desde la versión 0.7 del plugin VSDeck, **AWS RDS Snapshot** permite configurar
una tecla desde la aplicación Stream Deck. Arrastra la acción a una tecla y
completa **Task name / Nombre de tarea**, **AWS profile / Perfil AWS**,
**Region / Región** e **RDS instance / Instancia RDS**. Pulsa **Save changes /
Guardar cambios** y espera la confirmación de guardado. Cada tecla conserva su
propio destino. Usa el identificador de la instancia, no su endpoint ni ARN.
El nombre de tarea vacío toma el identificador de la instancia.

El perfil de AWS CLI debe existir y estar autenticado en esta Mac. La acción no
guarda credenciales en Stream Deck ni modifica la configuración privada. Usa
`awsBinary` de la configuración local (por defecto `/opt/homebrew/bin/aws`).
Hammerspoon debe estar abierto, con la configuración de este repositorio e IPC
habilitado, como para las acciones de texto.

Al pulsar la tecla, Hammerspoon reutiliza `modules/tasks/snapshots.lua` y
`scripts/rds-snapshot.sh`: verifica cuenta y destino, muestra la confirmación
en la nueva UI y solo después de pulsar **Crear snapshot** solicita el backup. El nombre se genera como
`instancia-YYYYMMDD-HHMM-manual`. El script vuelve a verificar la cuenta antes de
crear y espera a que AWS confirme disponibilidad. Soporta instancias RDS
PostgreSQL convencionales; no Aurora, AWS Backup ni backups de otros servicios.

El icono muestra los colores configurados al estar listo y al confirmar
disponibilidad, amarillo durante la operación y rojo ante error. Una tecla sin parámetros válidos
también aparece roja. La nueva UI muestra la verificación inicial, la confirmación
con cuenta, perfil, región, instancia y nombre, la solicitud y la espera de
disponibilidad. No muestra porcentajes estimados. **Atención** reúne confirmaciones
y errores, **En curso** las operaciones activas y **Historial** los resultados.
Los avisos finales usan la nueva UI a través de `modules.notifications`, respetan
la desactivación global o por nivel y recurren al aviso nativo si falla su ventana.

Las ventanas no tienen barra de título: **Esc** o el enlace discreto **Cerrar**
cierran la ventana activa. Cerrar la confirmación cancela antes de crear;
cerrar el centro no cancela un backup iniciado. Las confirmaciones de distintos
destinos se encolan y cada una solo se acepta una vez. Un error al abrir la
confirmación impide la creación. Puedes reabrir el centro desde **VS Tasks →
Abrir centro**, disponible después de la primera solicitud, o con
`require('modules.tasks.ui').open()` desde la consola de Hammerspoon.

Se captura el monitor de la aplicación de origen al iniciar, con cursor y monitor principal
como alternativas. Se reutiliza para la confirmación y el resultado; si se
desconecta, se usa el principal. Los avisos finales no toman el foco.
El historial conserva hasta 100 entradas recientes en memoria (las tareas activas
no se descartan), sin guardar credenciales ni datos del backup.

La misma combinación de perfil, región e instancia no inicia dos tareas
simultáneas, aunque se pulse desde otra tecla. Perfiles diferentes que apuntan a la misma cuenta no se consideran el
mismo destino. No hay reintentos automáticos de creación. Si falla la conexión
con Hammerspoon, el plugin consulta el estado antes de permitir otro intento.
Si AWS no confirma el resultado, revisa RDS antes de repetir: el snapshot podría
seguir creándose. Cambiar de página no cancela la tarea; cerrar o recargar
Hammerspoon interrumpe su seguimiento. El estado se mantiene en memoria, no es
un historial persistente. Esta acción no está habilitada en Multi Actions.

Tras actualizar el plugin, cierra Stream Deck desde **Quit Stream Deck** y vuelve
a abrirlo. Si Hammerspoon ya tenía cargado el módulo de snapshots anterior,
recarga su configuración cuando no haya tareas activas. Los destinos se configuran en los campos de Elgato.

Si la instancia está en `backing-up` u otro estado no admitido, el aviso muestra
el identificador y el estado observado. Espera a que esté disponible antes de
reintentar. El ejecutor conserva la salida de error recibida durante el proceso,
incluida la parte final, para que los avisos no pierdan la causa del fallo.

## Stream Deck Neo: traducción y corrección con indicador de actividad

El plugin local **VSDeck** ofrece cuatro acciones que reemplazan la selección en la
aplicación de origen:

- **Translate:** traduce al idioma de destino configurado (inglés por defecto), con el icono de traducción.
- **Correct:** corrige gramática, ortografía, claridad y
  fluidez con los cambios necesarios, conservando el idioma, voz y tono. Usa
  el icono de lápiz con ✓ de Tabler. Reutiliza `fix_same_language` de VSDeck.

- **Structure:** organiza la selección con un título breve, párrafos y viñetas cuando
  hay listas. Conserva el idioma y los datos, sin inventar información. En **Formato de salida** permite elegir **Plano** (predeterminado) o **Markdown**,
  guardado por tecla con **Guardar cambios**. Plano usa saltos de línea y viñetas;
  Markdown usa `#`, `##` y listas con `-`. Se pega como texto y el editor decide
  cómo representar Markdown; no se aplican estilos nativos de Notas.
  Tiene icono de documento con lista, Title opcional y Background/Icon configurables.

- **Email:** usa la selección como contexto para redactar asunto y cuerpo en el
  **Idioma de destino** elegido (inglés por defecto). Reemplaza la selección con
  el borrador en texto plano; no envía correos ni abre el cliente de correo.
  Conserva los datos proporcionados y no inventa destinatarios, firmas o compromisos.
  Incluye icono de sobre, Title nativo, Background/Icon y guardado por tecla.

Son acciones distintas de **System → Hotkey**: el botón de atajo existente
sigue funcionando, pero no recibe este indicador.

- Cada tecla permite un **Title / Título** opcional desde Stream Deck; vacío muestra solo el icono.
- En reposo usa Background e Icon configurables por tecla (por defecto #2563EB y #FFFFFF); el dibujo se conserva en todos los estados.
- Durante la captura, traducción y preparación del pegado muestra amarillo.
- Al enviar ⌘V vuelve al mismo icono con los colores configurados. No verifica que el editor
  haya aceptado el pegado; utiliza las mismas comprobaciones de foco de VSDeck.
- Si falta una selección, falla LM Studio, cambia el foco o no se puede comunicar
  con Hammerspoon, muestra el mismo icono con fondo rojo brevemente y vuelve
  a los colores configurados, sin superponer un triángulo de advertencia.
- Tras dos minutos cancela la entrega y descarta respuestas tardías. Esto no
  interrumpe necesariamente la generación que continúa dentro de LM Studio.
- Traducción, corrección, estructura y email comparten un bloqueo: ignora las pulsaciones de otros
  botones mientras una acción está activa. Solo cambia de color la tecla que inició la operación, aunque haya varias
  configuradas con la misma acción. Las demás conservan sus colores. El bloqueo
  evita ejecuciones simultáneas sobre el portapapeles.

### Instalar la prueba local

Requiere Hammerspoon en `/Applications/Hammerspoon.app`, su permiso de
Accesibilidad, LM Studio funcionando y Stream Deck 6.6 o posterior en macOS 13
o posterior. Para preparar el plugin hacen falta Node.js y npm; Stream Deck usa
su propio Node.js 20 para ejecutarlo. La integración fue preparada en Stream Deck
7.5.1. La configuración personal y los prompts existentes se reutilizan.

Desde la carpeta del repositorio:

```sh
npm ci --prefix streamdeck/com.vsdeck.jonyr.sdPlugin --ignore-scripts
npx @elgato/cli validate streamdeck/com.vsdeck.jonyr.sdPlugin
npx @elgato/cli link streamdeck/com.vsdeck.jonyr.sdPlugin
```

Cierra Stream Deck con **Stream Deck → Quit Stream Deck** y vuelve a abrirlo
para que detecte el plugin enlazado. El comando `streamdeck restart` requiere
modo desarrollador y no sustituye este paso en una instalación normal.

Recarga Hammerspoon con **Reload Config** cuando no haya otras tareas activas.
`init.lua` habilita `hs.ipc`, el canal local de comandos de Hammerspoon. El plugin
lo usa para iniciar una acción de texto y consultar su estado cada medio segundo
mientras está activa; no abre un servidor HTTP ni recibe el texto seleccionado.
El cliente cierra explícitamente la entrada del proceso `hs` y usa su modo
silencioso para recibir únicamente la respuesta, evitando falsos errores por
espera de entrada o mensajes de consola.
`hs.ipc` permite ejecutar Lua desde procesos locales del mismo usuario, por lo que
no debe confundirse con una API restringida únicamente a traducciones.

En Stream Deck, busca **Translate**, **Correct**, **Structure** o **Email**, bajo la categoría **VSDeck**, y arrastra cada acción a una tecla vacía. Puedes conservar el botón Hotkey anterior para comparar. Selecciona
una frase de prueba en un campo editable de Notas y pulsa la nueva tecla física:
observa amarillo, reemplazo del texto y retorno al color original. Mantén la
ventana activa durante la operación. Prueba también sin selección para observar
el indicador de error. Si aparece error de conexión, comprueba que Hammerspoon
esté ejecutándose y que hayas recargado esta versión de la configuración.

Para retirar la prueba, elimina la tecla del perfil y ejecuta
`npx @elgato/cli unlink com.vsdeck.jonyr`. Puedes retirar la línea
`require('hs.ipc')` de `init.lua` si ninguna otra integración la necesita y luego
recargar Hammerspoon. No se modifica la configuración privada al instalar.

### Desarrollo y verificación

El plugin vive en [streamdeck/com.vsdeck.jonyr.sdPlugin](streamdeck/com.vsdeck.jonyr.sdPlugin),
y el puente en [modules/streamdeck/init.lua](modules/streamdeck/init.lua).
Los estados y mensajes dinámicos vienen de `modules.i18n`; `es.json` traduce los
metadatos que muestra la aplicación de Elgato. `make check` incluye pruebas
simuladas de captura, respuesta, pegado, error, timeout, cambios de página y
pulsaciones duplicadas. `make test-streamdeck` ejecuta solo las pruebas del
controlador del plugin. Estas pruebas no controlan aplicaciones reales.

Los recursos usan prefijos por acción: `images/translate-{idle,busy,error}.svg`
y `images/correct-{idle,busy,error}.svg`. Comparten un lienzo de 144 × 144,
fondos azul `#2563eb`, amarillo `#d49a00` y rojo `#dc2626`, y trazos blancos
redondeados de 5 px. Desde la versión 0.12 el namespace es `com.vsdeck.jonyr`. La carpeta del paquete
es `streamdeck/com.vsdeck.jonyr.sdPlugin`; `.sdPlugin` es el sufijo de Elgato.
Al migrar desde `com.vsdeck.translation`, hay que actualizar los UUID del plugin
y las acciones de los perfiles, incluidos los pasos de Multi Action Switch, con
Stream Deck cerrado y respaldo previo. No basta con renombrar la carpeta.
Los títulos, colores y parámetros de las teclas se conservan en la migración.
El icono de corrección deriva de [Pencil Check de Tabler](https://github.com/tabler/tabler-icons/blob/main/icons/outline/pencil-check.svg),
con su [licencia MIT incluida](streamdeck/com.vsdeck.jonyr.sdPlugin/LICENSE-tabler.txt).

Para diagnosticar un botón rojo, `require('modules.streamdeck').status()` incluye
`reason`, una clave como `ai_text.capture_failed`, `ai_text.error` o
`ai_text.result_copy_only`. Conserva únicamente el motivo del último intento,
sin guardar el texto seleccionado ni la respuesta del modelo. Un estado `done`
indica que se envió el pegado, no que el editor confirmó el reemplazo.

Los botones del Neo utilizan el módulo central `modules.notifications` de VSDeck.
Cada operación aparece en el nuevo centro de tareas, sin guardar el texto de origen
ni la respuesta. Al terminar el pegado o fallar muestra un aviso del centro,
respetando los niveles habilitados de notificaciones. El aviso no toma el foco.
El historial es efímero y se reinicia al recargar Hammerspoon.
En el panel de cada tecla, configura **Background**, **Icon** y, para Translate,
**Idioma de destino**, y pulsa **Guardar cambios**. El idioma se envía a la LLM
como parte de la instrucción; Correct conserva el idioma original.
No se modifica la configuración personal. Si Hammerspoon está cerrado o su conexión local
no responde, el plugin solo puede mostrar rojo: no puede entregar un aviso a
través de un servicio que no está disponible.

### Discord · Almuerzo: Disponible / Away

El plugin VSDeck también ofrece **Discord Lunch / Discord · Almuerzo**. Arrastra
esta acción a una tecla vacía; es un único botón que alterna según la presencia
observada en Discord, no una Multi Action Switch de Elgato.

- **Verde:** Discord está Online / Disponible. Al pulsar, guarda el emoji y el mensaje configurados, selecciona su duración y cambia a
  **Idle / Away**. Los valores iniciales son emoji `:cut_of_meat:` (🥩),
  mensaje **🥬 Almorzando** y **1 hora**.
- **Naranja:** Discord está Idle / Away. Al pulsar, borra el mensaje personalizado
  y cambia a Online. Esto también borra un mensaje cambiado manualmente.
- **Amarillo:** operación en curso; ignora pulsaciones adicionales.
- **Rojo temporal:** no se confirmó la operación; el sistema de notificaciones de
  VSDeck indica el paso que falló. Puede haber cambios parciales en Discord.
- **Rojo oscuro:** Do Not Disturb. **Gris oscuro:** Invisible.
- **Gris:** estado no confirmado, Discord cerrado o puente inaccesible. No representa Disponible.

El mensaje y la presencia tienen duraciones independientes. **Duración de presencia**
selecciona el temporizador nativo de Discord (por defecto 1 hora); **Siempre**
mantiene Away hasta que lo cambies. Con **No borrar** el mensaje permanece hasta borrarlo. Cada cinco segundos, mientras la tecla está visible, consulta la
presencia expuesta por la aplicación local. Los cambios hechos desde otro cliente
se reflejan cuando Discord de escritorio los muestra. La lectura no abre menús;
si la interfaz no expone un valor reconocible muestra gris.

Requiere Discord de escritorio estable con sesión iniciada y **su interfaz en
inglés**, como la instalación donde se verificó. El botón activa Discord y usa
sus controles de Accesibilidad, sin tokens de usuario ni APIs privadas. Mantén
Discord al frente durante el cambio. Una actualización de Discord puede exigir
ajustar los nombres de los controles. Se verifica presencia y mensaje antes de
confirmar, selecciona la duración nativa y cierra la tarjeta y los menús de perfil.
Discord queda abierto; no se restaura otra aplicación. No se reintenta automáticamente una operación fallida. No requiere
LM Studio ni el plugin Discord de Elgato. Los botones físicos de texto y
almuerzo rechazan operaciones que se solapen.

Implementación: [modules/discord/presence.lua](modules/discord/presence.lua) y
[presence-controller.mjs](streamdeck/com.vsdeck.jonyr.sdPlugin/presence-controller.mjs).
Los iconos, con título nativo opcional, usan el prefijo `discord-lunch-`, el mismo lienzo y trazos
blancos que las otras acciones, y un dibujo de cubiertos. Las pruebas offline
cubren ambos sentidos, duración, cambios externos, pérdida de foco, errores,
pulsaciones duplicadas y falta de permisos; no modifican Discord real.

Selecciona el botón **Discord Lunch** en Stream Deck para editar su panel:

- **Emoji del estado:** campo de texto libre; escribe el nombre sin dos puntos,
  por ejemplo `cut_of_meat`, `coffee` o `leafy_green`. También acepta `:coffee:`. Vacío significa
  sin emoji. Usa el nombre, no el símbolo Unicode; la búsqueda de Discord no
  reconoce el símbolo pegado directamente. El emoji debe estar disponible en tu
  selector de Discord; un nombre inexistente produce un aviso sin confirmar éxito.
- **Mensaje:** hasta 128 caracteres, con emojis y comillas permitidos; sin saltos
  de línea. Este campo es independiente del emoji del estado.
- **Borrar después de:** 30 minutos, 1 hora, 4 horas, 24 horas o No borrar.

Pulsa **Guardar cambios / Save changes**. El panel muestra **Guardado / Saved**
solo cuando Stream Deck devuelve los mismos valores persistidos. Si falla la
confirmación, conserva la edición y permite volver a guardar. Los valores se
guardan por tecla y se aplican en la siguiente pulsación. No se modifica tu estado al editar el panel. La presencia
es única para toda la cuenta de Discord, aunque uses varios botones con mensajes
distintos. La segunda pulsación borra el estado actual y vuelve a Disponible.

La verificación del texto se hace sobre una lectura nueva y posterior a la
escritura: Discord puede aceptar el cambio antes de actualizar Accesibilidad.
Los errores incluyen la etapa y el puente expone `phase` para diagnóstico, sin
incluir el mensaje configurado. El inspector usa los textos de `modules.i18n`
exportados a `presence-locales.json`. Las pruebas incluyen lecturas retrasadas,
las cinco duraciones, emoji separado, guardado por tecla y escape de texto en el
puente local. El panel implementa el [Property Inspector oficial de Elgato](https://docs.elgato.com/streamdeck/sdk/references/websocket/ui/).

### Presencia configurable de Discord

Arrastra **VSDeck → Discord Presence** a una tecla vacía. Elige **Online**, **Idle**,
**Do Not Disturb** o **Invisible**, y pulsa **Guardar cambios**. Al pulsar esa tecla
aplica la presencia elegida; no alterna ni modifica tu mensaje o emoji actuales.
Puedes asignar varias teclas con destinos distintos. El icono de persona, sin
texto, refleja la presencia observada de la cuenta (compartida por todas las teclas).
Los archivos usan el prefijo `discord-presence-` y el mismo estilo que las demás acciones.

Para Idle, Do Not Disturb e Invisible, las duraciones nativas son **15 minutos**,
**1 hora**, **8 horas**, **24 horas**, **3 días** y **Siempre / Forever**.
**Online** se aplica directamente y deshabilita el selector de duración.
El botón de almuerzo también permite elegir esta duración, independientemente de
**Borrar después de**, que afecta solamente al mensaje.

El cierre usa el control de perfil de Discord y, cuando la tarjeta oculta ese
control, Escape dirigido a la aplicación en primer plano después de comprobar el
foco. El envío de Escape dirigido al proceso no cierra de forma fiable sus menús. La comprobación reconoce los nombres con sufijo
`Until …` después de establecer una duración. Las pruebas offline cubren los
cuatro destinos, las seis duraciones, conservación del mensaje, cierre de menús,
lecturas retrasadas, confirmación del guardado y actualizaciones de iconos solo
cuando cambia el estado. El inspector utiliza su UUID de registro para guardar y
leer ajustes; el identificador de la tecla se conserva para los eventos del plugin.

### Discord Presence dentro de Multi Action Switch

Desde VSDeck 0.6, **Discord Presence** se puede arrastrar a una **Multi Action**
o a cualquiera de los dos lados de una **Multi Action Switch**. Después de
actualizar el plugin, cierra Stream Deck desde su menú **Quit Stream Deck** y
vuelve a abrirlo para refrescar la lista de acciones.

1. Abre la Multi Action Switch y selecciona la pestaña **1**.
2. Arrastra **VSDeck → Discord Presence**, elige **Do Not Disturb** y la duración,
   y pulsa **Save changes**.
3. En la pestaña **2**, añade otra instancia de **Discord Presence**, selecciona
   **Online** y pulsa **Save changes**.

Cada paso conserva sus propios ajustes y establece un destino explícito. No
borra ni cambia el mensaje o emoji de Discord. **Discord Lunch**, traducción y
corrección siguen disponibles únicamente como botones individuales.

**Coloca Discord Presence al final de cada secuencia.** Stream Deck no espera a
que termine la automatización de Hammerspoon antes de ejecutar el siguiente paso.
No cambies de aplicación ni vuelvas a pulsar hasta que termine el cambio; una
segunda solicitud durante la operación se ignora para evitar cambios superpuestos.

El icono del switch lo configura Stream Deck: puedes elegir rojo para el lado de
No molestar y verde para Online. Representa el lado del switch, **no una lectura
confirmada de Discord**. Los pasos internos no sobrescriben su icono ni título.
Un botón independiente de Discord Presence sigue mostrando la presencia real,
y los fallos de automatización siguen usando las notificaciones de VSDeck.

Los avisos del centro de tareas usan esquinas rectas y aprovechan toda la ventana,
sin un contenedor interior con scroll. El cierre es una **×** arriba a la derecha, con etiqueta accesible y ayuda «Cerrar».
**Abrir centro** es un botón secundario al pie; en los errores muestra **Ver detalle**. Los textos muy largos se limitan a dos
líneas en el aviso; el detalle completo sigue disponible en el centro.

En la pestaña **Historial**, **Borrar historial** elimina los registros terminados,
cancelados y con error de esta sesión. Conserva tareas en curso y confirmaciones
pendientes; no borra snapshots, ejecuciones AWS ni modifica el resultado de las
acciones. El botón se deshabilita cuando no hay registros para borrar.

## Licencia

[MIT](LICENSE).

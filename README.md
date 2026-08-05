# High-Performance PHP 8.2 Runtime for PocketMine-MP / Genisys

Este runtime de **PHP 8.2 (CLI)** ha sido diseñado, auditado y optimizado específicamente para ejecutar servidores dedicados de Minecraft Bedrock Edition (**PocketMine-MP**, **Genisys** y sus derivados) con la máxima eficiencia, menor latencia (Tick Time), mayor estabilidad de TPS y consumo optimizado de CPU y memoria RAM.

---

## 🛠️ ¿Qué contiene este Runtime?

El runtime está configurado exclusivamente para ejecución por **Línea de Comandos (CLI)** de procesos de larga duración (daemons 24/7). Se han eliminado/desactivado todas las sobrecargas relacionadas con servidores web (Apache, Nginx, PHP-FPM, CGI, cookies, sesiones HTTP, subida de archivos multipart).

### Componentes Clave:
* **PHP 8.2 Engine (Zend Engine 4)** optimizado para procesamiento multihilo y orientación a objetos intensiva.
* **OPcache activado en CLI (`opcache.enable_cli=1`)**: Caching de bytecode en memoria compartida para eliminar el parsing de código en cada tick.
* **Tracing JIT (Just-In-Time Compiler)**: Compilación en código máquina nativo de bucles pesados de renderizado de chunks, matemáticas de vectores, física de bloques y compresión de paquetes RakNet.
* **Modulo Extensions Auditado**: Módulos web innecesarios deshabilitados (`gd`, `soap`, `pgsql`, `imap`, `ldap`, etc.) y extensiones críticas compiladas y habilitadas (`sockets`, `pmmpthread`, `yaml`, `curl`, `openssl`, `gmp`, `sqlite3`, `zlib`).

---

## 📄 Diferencias entre `php.ini-production` y `php.ini-development`

| Directiva INI | `php.ini-production` | `php.ini-development` | Impacto / Razón |
| :--- | :--- | :--- | :--- |
| **Objetivo** | Máximo rendimiento en servidores públicos 24/7 | Desarrollo de plugins y debugging rápido | Estabilidad vs Facilidad de desarrollo |
| **`opcache.validate_timestamps`** | `0` (Desactivado) | `1` (Activado) | En producción elimina llamadas a disco `stat()`. En dev recarga código editado al instante. |
| **`opcache.revalidate_freq`** | `0` (Sin efecto) | `0` (Revalidación instantánea) | Permite actualizar archivos PHP sin reiniciar el servidor en desarrollo. |
| **`display_errors`** | `Off` | `On` | Muestra errores directamente en la consola durante el desarrollo. |
| **`error_reporting`** | `E_ALL & ~E_DEPRECATED & ~E_STRICT & ~E_NOTICE` | `E_ALL` | Muestra hasta los avisos más mínimos en dev; en prod filtra ruido innecesario. |
| **`zend.assertions`** | `-1` (Zero overhead) | `1` (Ejecutar afirmaciones) | En produccion no genera opcodes de `assert()`. En dev valida invariantes de código. |
| **`zend.exception_ignore_args`**| `On` | `Off` | Ahorra memoria en producción eliminando argumentos de los stack traces de excepciones. |
| **`phar.readonly`** | `On` | `Off` | En dev permite empaquetar o modificar archivos `.phar` en caliente. |
| **`opcache.memory_consumption`**| `256M` | `128M` | Mayor espacio en prod para múltiples plugins y liberías pesadas. |
| **`opcache.jit_buffer_size`** | `128M` | `64M` | Asignación de buffer compilado nativo. |

---

## 🎯 Cuándo usar cada archivo

### Usar `php.ini-production` cuando:
* Despliegues un servidor público o privado en producción.
* Busques el máximo **TPS (20.0)** sostenido con muchos jugadores conectados.
* El servidor se mantenga encendido durante días o semanas sin reiniciar.
* **Nota:** Asume que cada vez que agregues, elimines o edites un plugin o archivo PHP, **reiniciarás el servidor**.

### Usar `php.ini-development` cuando:
* Estés programando o testeando plugins localmente.
* Requieras ver errores detallados, avisos de depreciación y stack traces completos.
* Modifiques código PHP constantemente y no quieras reiniciar el proceso de PocketMine en cada cambio de linea.

---

## 💡 Guía de Optimización Directiva por Directiva

A continuación se detalla cómo ajustar los parámetros según la escala de tu servidor:

### 1. OPcache
* **`opcache.enable_cli`**
  * *Qué hace:* Habilita el caché de bytecode en el entorno CLI.
  * *Configuración:* **MANDATORIO `1`**. Por defecto en PHP CLI es `0`. Si está en `0`, OPcache estará apagado.
  * *Impacto:* Reducción drástica de CPU y latencia.
* **`opcache.validate_timestamps`**
  * *Qué hace:* Comprueba si el archivo PHP cambió en el disco comparando la fecha de modificación (`stat()`).
  * *Producción:* `0`. Elimina llamadas de E/S de disco durante la ejecución de los ticks.
  * *Desarrollo:* `1`.
  * *Impacto CPU:* Muy alto ahorro en `0`.
* **`opcache.memory_consumption`**
  * *Qué hace:* Memoria RAM (MB) reservada para guardar el bytecode de scripts PHP.
  * *Cuándo aumentar:* Si usas más de 100 plugins o librerías masivas y notas que `wasted_memory` sube.
  * *Valores recomendados:* `128M` (servidores pequeños), `256M` (estándar/grande), `512M` (redes masivas con 300+ plugins).
* **`opcache.interned_strings_buffer`**
  * *Qué hace:* Memoria (MB) para almacenar cadenas de texto repetidas (nombres de clases, métodos, identificadores de bloques/ítems).
  * *Cuándo aumentar:* PocketMine maneja millones de llamadas con nombres de bloques y eventos. Si el buffer se llena, PHP recurre a la memoria individual por hilo.
  * *Valores recomendados:* `32M` a `64M`.
* **`opcache.max_accelerated_files`**
  * *Qué hace:* Número máximo de claves en la tabla Hash de OPcache.
  * *Valores recomendados:* `10000` (PocketMine base), `30000` (Servidores con muchos plugins/Phars).

### 2. JIT (Just-In-Time Compiler)
* **`opcache.jit`**
  * *Qué hace:* Compila bytecode de Zend a código de máquina x86_64/ARM64.
  * *Valor recomendado:* `tracing` (equivalente numérico `1254`). El modo Tracing identifica los bucles más ejecutados ("hot loops") como la generación de chunks, tiqueo de entidades y compresión RakNet.
  * *Impacto:* **-15% a -30% uso de CPU** en tareas matemáticas/numéricas.
* **`opcache.jit_buffer_size`**
  * *Qué hace:* Memoria asignada para el código ejecutable nativo generado por JIT.
  * *Valores recomendados:* `64M` (servidores pequeños), `128M` (servidores de alta carga).

### 3. Memoria y Sistema
* **`memory_limit`**
  * *Qué hace:* Límite máximo de RAM que puede consumir el proceso PHP.
  * *Recomendación PocketMine:* `-1` (Sin límite) o un valor alto como `2G` / `4G`.
  * *Impacto:* Evita que el servidor colapse con un error fatal de memoria durante la generación de mundos pesados o picos de jugadores.
* **`realpath_cache_size` y `realpath_cache_ttl`**
  * *Qué hace:* Almacena las rutas absolutas de los archivos resueltos por el sistema de archivos.
  * *Valores recomendados:* `realpath_cache_size = 8M`, `realpath_cache_ttl = 3600` (en producción).

---

## 📊 Guía para la Realización de Benchmarks Correctos

Para medir de forma científica el impacto de cualquier cambio de configuración en PocketMine, sigue estos pasos:

### Metrics a Evaluar
1. **TPS (Ticks Per Second):** Debe mantenerse constante en **20.0**.
2. **Tick Time (Ms):** El tiempo que toma procesar un tick. Debe ser **< 50ms** (un tick time de 10-15ms indica excelente margen de CPU).
3. **Uso de RAM Sostenido:** Medir el consumo tras 1 hora, 12 horas y 24 horas de ejecución continua (detectar fuga de memoria en plugins).
4. **Tiempo de Arranque (Startup Time):** Tiempo en segundos desde el comando de inicio hasta que el servidor escucha en el puerto UDP.
5. **Generación de Chunks (Chunks/sec):** Velocidad de carga de mapa volando en modo espectador con múltiples bots.

### Metodología Recomendada
* **Entorno Aislado:** Ejecuta los benchmarks en el mismo servidor/hardware sin otros procesos compitiendo por CPU.
* **Herramientas de Monitoreo:**
  * Usa el comando `/timings` nativo de PocketMine para analizar la duración de los eventos y ticks del servidor.
  * Utiliza herramientas de sistema como `htop`, `perf top` o `pidstat -p <PID> 1` para registrar uso de CPU por núcleo y fallos de página.
  * Utiliza `valgrind --tool=massif` o comandos de uso de memoria de PHP en hilos para evaluar fugas.
* **Prueba de Carga con Bots:** Utiliza herramientas de estrés como `RakLib Stress Tool` o bots automatizados para simular 50-100 jugadores moviéndose y rompiendo bloques simultáneamente.

---

## ❓ Preguntas Frecuentes (FAQ)

### ¿Por qué desactivar `validate_timestamps`?
En producción, cuando `validate_timestamps = 0`, PHP almacena el código compilado en memoria y **nunca más vuelve a consultar el disco rígido/SSD** para comprobar si el archivo fue modificado. En un ciclo de 20 ticks por segundo con decenas de plugins ejecutándose, esto ahorra millones de llamadas al sistema (`stat()`), reduciendo la latencia de I/O a cero.

### ¿Vale la pena activar JIT en PocketMine?
**Sí, absolutamente.** A diferencia de las aplicaciones web PHP tradicionales (que son I/O bound debido a bases de datos y red), PocketMine realiza un procesamiento intensivo de CPU en el hilo principal (matemáticas de vectores, físicas, tick loop, NBT encoding). JIT Tracing compila esos bucles a instrucciones de CPU puras, logrando un rendimiento sustancialmente mayor.

### ¿Por qué aumentar `interned_strings_buffer` a 64M?
PocketMine y la red Bedrock utilizan cadenas repetitivas constantemente (e.g., `"minecraft:dirt"`, `"PocketMine-MP"`, nombres de eventos, keys de arreglos vectoriales). Si el buffer predeterminado de 8MB se llena, PHP tiene que asignar e internar cadenas individualmente por subproceso/hilo, aumentando la fragmentación y el uso de CPU. Con 64MB aseguramos que todas las cadenas de todos los plugins queden perfectamente en memoria compartida.

### ¿Cuánta memoria necesita OPcache?
Para PocketMine con el núcleo limpio y 10-20 plugins pequeños, `128M` es suficiente. Para servidores en producción con 50+ plugins, mundos personalizados y librerías extensas, se recomiendan **`256M`**.

### ¿Cuándo conviene aumentar `max_accelerated_files`?
Si la suma total de archivos `.php` dentro del core de PocketMine, la carpeta `vendor` y todos tus plugins descomprimidos supera los 10,000 archivos, debes subir este valor a `30000` o `65535` (siempre usando números primos cercanos o valores estándar soportados por la tabla Hash de OPcache).

### ¿Qué hacer si tengo más de 300 plugins?
1. Configura `opcache.memory_consumption = 512`.
2. Configura `opcache.interned_strings_buffer = 128`.
3. Configura `opcache.max_accelerated_files = 65535`.
4. Asegúrate de ejecutar plugins empacados en formato `.phar` optimizado y que `opcache.validate_timestamps = 0` esté en vigor.

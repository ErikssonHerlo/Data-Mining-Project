# Análisis de condiciones de vivienda y migración internacional en Guatemala (Censo 2018)
Por: Eriksson José Hernández López  
Email: erikssonhernandez25@gmail.com

Este repositorio contiene un flujo de trabajo completo en R para analizar las condiciones de vivienda, servicios básicos y migración internacional en Guatemala, utilizando los microdatos del Censo de Población y Vivienda 2018 (INE).

El proyecto implementa:

- Limpieza y unificación de bases (PERSONA, HOGAR, VIVIENDA, MIGRACION).
- Construcción de un índice preliminar de calidad de vivienda.
- Resumen de información de migración a nivel de hogar.
- Minería de datos:
  - Reglas de asociación con Apriori.
  - Patrones frecuentes tipo FP-Growth (usando Eclat).
  - Clustering de hogares con k-means.

Todos los datos originales, así como los resultados pesados, se mantienen fuera del control de versiones por motivos de tamaño y confidencialidad.

---

## 1. Requisitos previos

### 1.1 Software

- R versión 4.2 o superior (recomendado 4.3+).

Opcionalmente:

- RStudio como entorno de desarrollo (no es obligatorio, pero facilita la ejecución de los scripts).

### 1.2 Paquetes de R

Instalar los siguientes paquetes antes de ejecutar los scripts:

```r
install.packages(c(
  "data.table",
  "arules",
  "ggplot2"   # utilizado de forma opcional para algunas visualizaciones
))
````

Los scripts utilizan principalmente:

* `data.table` para manejo eficiente de datos.
* `arules` para reglas de asociación (Apriori) y patrones frecuentes (Eclat).
* `ggplot2` para visualizaciones básicas en el análisis de clusters (k-means).

---

## 2. Estructura del repositorio

La estructura propuesta es la siguiente:

```text
project/
│
├── data/
│   ├── raw/            # Datos originales descargados del INE (Censo 2018)
│   ├── clean/          # Datos limpios intermedios (generados por 01_limpieza.R)
│   └── output/         # Bases unificadas y salidas intermedias (02_unificacion.R)
│
├── reports/
│   ├── apriori/        # Resultados de reglas de asociación (03_apriori.R)
│   ├── fpgrowth/       # Resultados de patrones frecuentes (04_fpgrowth.R)
│   └── clustering/     # Resultados de k-means (05_clustering.R)
│
├── scripts/
│   ├── 01_limpieza.R
│   ├── 02_unificacion.R
│   ├── 03_apriori.R
│   ├── 04_fpgrowth.R
│   └── 05_clustering.R
│
└── README.md
```

Las carpetas `data/` y `reports/` están ignoradas en el control de versiones (`.gitignore`), por lo que deben crearse localmente.

---

## 3. Descarga y preparación de los datos

### 3.1 Descarga de los microdatos

1. Ingresar al sitio oficial del Censo 2018:

   * [https://censo2018.ine.gob.gt/descarga](https://censo2018.ine.gob.gt/descarga)

2. Descargar los microdatos correspondientes a:

   * Personas (PERSONA)
   * Hogares (HOGAR)
   * Viviendas (VIVIENDA)
   * Migración (MIGRACION)
   * Diccionario de datos (en PDF o Excel, según lo proporcione el INE)

   Los nombres exactos pueden variar, pero este repositorio asume archivos del tipo:

   * `PERSONA_BDP.csv`
   * `HOGAR_BDP.csv`
   * `VIVIENDA_BDP.csv`
   * `MIGRACION_BDP.csv`
   * Diccionario de datos (por ejemplo, `Diccionario_Censo2018.*`)

### 3.2 Organización de archivos

1. Crear la carpeta `data/raw/` en la raíz del proyecto (si no existe).
2. Descomprimir los archivos descargados del INE dentro de `data/raw/`.
3. Al finalizar, la carpeta `data/raw/` debe contener al menos:

   ```text
   data/raw/
     ├── PERSONA_BDP.csv
     ├── HOGAR_BDP.csv
     ├── VIVIENDA_BDP.csv
     ├── MIGRACION_BDP.csv
     └── Diccionario_Censo2018.*   # nombre referencial
   ```

Es importante que `data/raw/` contenga únicamente los archivos de datos originales y el diccionario correspondiente, sin modificaciones adicionales.

---

## 4. Flujo de trabajo y ejecución de scripts

Los scripts están pensados para ejecutarse en orden, ya sea desde RStudio, desde la consola de R o usando `Rscript`. A continuación se describe el flujo de trabajo completo.

### 4.1 Fase 1 – Limpieza de datos (`01_limpieza.R`)

**Objetivo:** cargar y limpiar los cuatro archivos de microdatos del INE, generando versiones estandarizadas y coherentes a nivel de tipos de datos y codificaciones.

**Entrada:**

* `data/raw/PERSONA_BDP.csv`
* `data/raw/HOGAR_BDP.csv`
* `data/raw/VIVIENDA_BDP.csv`
* `data/raw/MIGRACION_BDP.csv`

**Pasos principales:**

* Carga de cada archivo con `data.table::fread()`.
* Conversión de columnas a tipos adecuados (`integer`, `numeric`, `factor`, `character`) según el diccionario.
* Recodificación de valores especiales (por ejemplo, 9, 99, 999) a `NA` donde corresponda.
* Homologación de nombres de columnas entre las distintas bases.
* Mensajes informativos en consola indicando:

  * número de registros y columnas,
  * cantidad de valores faltantes,
  * columnas corregidas.

**Salida:**

Se guardan versiones limpias en formato `.rds` dentro de `data/clean/`, por ejemplo:

* `data/clean/persona_clean.rds`
* `data/clean/hogar_clean.rds`
* `data/clean/vivienda_clean.rds`
* `data/clean/migracion_clean.rds`

### 4.2 Fase 2 – Unificación de bases (`02_unificacion.R`)

**Objetivo:** integrar la información de vivienda, hogar, personas y migración en bases unificadas que permitan análisis posteriores.

**Entrada:**

* Archivos `.rds` generados en `data/clean/` durante la Fase 1.

**Pasos principales:**

* Definición de llaves de unión:

  * Llave de vivienda (ejemplo):

    * `DEPARTAMENTO`, `MUNICIPIO`, `COD_MUNICIPIO`, `AREA`/`ZONA`, `NUM_VIVIENDA`
  * Llave de hogar:

    * `DEPARTAMENTO`, `MUNICIPIO`, `COD_MUNICIPIO`, `AREA`/`ZONA`, `NUM_VIVIENDA`, `NUM_HOGAR`
* Unión de HOGAR y VIVIENDA para formar `hogar_vivienda`.
* Construcción de un índice preliminar de calidad de vivienda combinando:

  * material de paredes, techo y piso,
  * acceso a agua mejorada,
  * saneamiento mejorado,
  * electricidad.
* Resumen de la información de migración a nivel de hogar:

  * número total de emigrantes,
  * número de emigrantes hombres y mujeres,
  * edad promedio de emigrantes.
* Unión de la información de migración con `hogar_vivienda` para producir `hogar_vivienda_migracion`.
* Unión final de `hogar_vivienda_migracion` con PERSONA para generar `base_persona_maestra`.

Durante la ejecución, el script imprime en consola:

* llaves utilizadas,
* número de registros antes y después de cada unión,
* resumen del índice de calidad de vivienda,
* estadísticas básicas de migración (cantidad de hogares con emigrantes, edad promedio, etc.).

**Salida:**

En `data/output/` se generan archivos como:

* `hogar_vivienda.rds`
* `hogar_vivienda_migracion.rds`
* `base_persona_maestra.rds`
* y versiones en `.csv` para inspección rápida:

  * `hogar_vivienda_migracion.csv`
  * `base_persona_maestra.csv`

### 4.3 Fase 3 – Reglas de asociación (Apriori) (`03_apriori.R`)

**Objetivo:** identificar patrones de coocurrencia entre características de vivienda, servicios básicos y migración mediante el algoritmo Apriori.

**Entrada:**

* `data/output/hogar_vivienda_migracion.rds`

**Pasos principales:**

* Selección de variables categóricas relevantes:

  * materiales de construcción (pared, techo, piso),
  * acceso a agua, saneamiento, electricidad,
  * índice de calidad de vivienda (categorizado),
  * número de cuartos,
  * área (urbana/rural),
  * número de emigrantes (categorizado).
* Transformación de variables numéricas en categorías (por ejemplo, calidad muy baja, baja, media, alta).
* Conversión a objeto `transactions` del paquete `arules`.
* Ejecución de Apriori con parámetros de soporte y confianza definidos en el script.
* Filtrado de reglas con `lift > 1`.
* Exportación de reglas resultantes.

**Salida:**

En `reports/apriori/` se generan archivos como:

* `reglas_apriori_lift1.csv`
* `reglas_apriori_lift1.rds`

### 4.4 Fase 4 – Patrones frecuentes FP-Growth / Eclat (`04_fpgrowth.R`)

**Objetivo:** complementar el análisis con minería de patrones frecuentes utilizando el algoritmo Eclat (FP-like).

**Entrada:**

* `data/output/hogar_vivienda_migracion.rds` (o la misma derivación de variables categóricas utilizada en Apriori).

**Pasos principales:**

* Selección de variables categóricas de vivienda y servicios.
* Conversión a formato `transactions`.
* Ejecución de Eclat con:

  * soporte mínimo configurable,
  * longitud máxima de los itemsets.
* Inducción de reglas a partir de itemsets frecuentes mediante `ruleInduction`.
* Filtrado de reglas con confianza mínima y `lift > 1`.
* Exportación de itemsets y reglas resultantes.

**Salida:**

En `reports/fpgrowth/` se generan archivos como:

* `itemsets_frecuentes_fp_growth.csv`
* `reglas_fp_growth_lift_gt_1.csv`
* `reglas_fp_growth.rds`

### 4.5 Fase 5 – Clustering de hogares (k-means) (`05_clustering.R`)

**Objetivo:** agrupar hogares en clusters relativamente homogéneos de acuerdo con su calidad de vivienda, tamaño del hogar y migración.

**Entrada:**

* `data/output/hogar_vivienda_migracion.rds`
* `data/output/base_persona_maestra.rds`

**Pasos principales:**

* Cálculo del número de personas por hogar a partir de `base_persona_maestra`.
* Unión del conteo de personas con `hogar_vivienda_migracion`.
* Selección de variables numéricas para clustering, por ejemplo:

  * índice de calidad de vivienda,
  * número de personas,
  * número de emigrantes,
  * edad promedio de emigrantes (si está disponible).
* Filtrado de hogares con datos completos en estas variables.
* Escalamiento de las variables (media 0, varianza 1).
* Ejecución de k-means con un número de clusters `k` definido en el script (por ejemplo `k = 4`).
* Asignación de etiquetas de cluster a cada hogar.
* Cálculo de un resumen descriptivo por cluster (medias de cada variable de interés).

**Salida:**

En `reports/clustering/` se generan archivos como:

* `resumen_clusters_k4.csv`
* `hogar_vivienda_migracion_clusters_k4.csv`
* `modelo_kmeans_k4.rds`

---

## 5. Ejecución rápida del pipeline

Si se desea ejecutar el pipeline completo desde la consola de R o un script de automatización, se puede seguir el siguiente orden:

```r
source("scripts/01_limpieza.R")
source("scripts/02_unificacion.R")
source("scripts/03_apriori.R")
source("scripts/04_fpgrowth.R")
source("scripts/05_clustering.R")
```

Cada script imprime información detallada en la consola sobre:

* qué archivo está cargando,
* cuántos registros procesa,
* qué transformaciones aplica,
* qué salidas genera y en qué carpeta.

---

## 6. Interpretación y reporte final

Los resultados generados en las carpetas `reports/apriori/`, `reports/fpgrowth/` y `reports/clustering/` sirven como insumo para elaborar un reporte final en PDF, que puede incluir:

* descripción del dataset y del proceso de limpieza/unificación,
* análisis de las reglas de asociación más relevantes (al menos cuatro patrones interesantes),
* descripción de los patrones frecuentes obtenidos con Eclat,
* análisis de los clusters de hogares encontrados con k-means,
* propuestas de intervención basadas en evidencia para mejorar las condiciones de vivienda y servicios en Guatemala.

Este README se concentra en la estructura técnica y la reproducibilidad del repositorio. La interpretación sustantiva y las propuestas de política pública deben desarrollarse en un documento aparte (artículo, informe técnico o tesis) utilizando como base los resultados generados por los scripts.

---

## 7. Créditos y uso de datos

* Los datos utilizados en este proyecto provienen del **Instituto Nacional de Estadística (INE) de Guatemala**, específicamente de los microdatos del **Censo de Población y Vivienda 2018**.
* El uso de la información debe respetar los términos, condiciones y licencias definidos por el INE y la normativa nacional sobre protección de datos.
* Este repositorio se limita a proveer código para el procesamiento y análisis de los datos; no distribuye los microdatos ni reproduce información sensible.
* Cualquier duda o consulta sobre el código puede dirigirse al autor del repositorio.
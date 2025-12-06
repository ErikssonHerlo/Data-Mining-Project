# Análisis de condiciones de vivienda y migración internacional en Guatemala (Censo 2018)

Autor: **Eriksson José Hernández López**  
Email: **erikssonhernandez25@gmail.com**

Este repositorio contiene un flujo de trabajo completo para analizar las condiciones de vivienda, servicios básicos y migración internacional en Guatemala utilizando los microdatos del **Censo de Población y Vivienda 2018** del **INE**.

El proyecto está dividido en dos grandes partes:

1. **Parte 1 – Minería de datos en R**  
   - Limpieza y unificación de bases (PERSONA, HOGAR, VIVIENDA, MIGRACION).
   - Construcción de un índice preliminar de calidad de vivienda.
   - Resumen de información de migración a nivel de hogar.
   - Minería de datos:
     - Reglas de asociación con Apriori.
     - Patrones frecuentes tipo FP-Growth (usando Eclat).
     - Clustering de hogares con k-means.

2. **Parte 2 – Modelos predictivos (R + Python)**  
   - Preparación de un dataset de modelado a nivel de hogar.
   - Árboles de decisión (4 targets distintos) en R.
   - Random Forest (3 targets distintos) en R.
   - Redes neuronales (3 modelos) en Python (TensorFlow/Keras).
   - Generación de reportes y figuras para el informe final y las propuestas de intervención.

Los datos originales, así como los resultados, **no se versionan en Git** por tamaño y confidencialidad.  
Para facilitar la revisión, se incluye un archivo **`reports.zip`** con ejemplos de salidas ya generadas (gráficas y tablas clave).

---

## 1. Requisitos previos

### 1.1 Software

- **R** versión 4.2 o superior (recomendado 4.3+).
- **Python** 3.10+ (recomendado).
- Opcional: **RStudio** para trabajar con R de forma más cómoda.
- Opcional: un editor para Python (VS Code, PyCharm, etc.).

### 1.2 Paquetes de R

Instalar los siguientes paquetes en R:

```r
install.packages(c(
  "rpart.plot",
))
````

Principales usos:

* `data.table`: manejo eficiente de datos.
* `arules`: reglas de asociación (Apriori) y patrones frecuentes (Eclat).
* `ggplot2`: visualizaciones (especialmente k-means).
* `rpart` y `rpart.plot`: árboles de decisión.
* `randomForest`: bosques aleatorios.
* `caret`: matrices de confusión y métricas de desempeño.

### 1.3 Paquetes de Python y entorno virtual

Se recomienda crear un **entorno virtual** para aislar las dependencias de Python.

#### 1.3.1 Creación de entorno virtual

En la raíz del proyecto:

```bash
python -m venv .venv
```

Activar el entorno:

* En Linux / macOS:

  ```bash
  source .venv/bin/activate
  ```

* En Windows (PowerShell o CMD):

  ```bash
  .venv\Scripts\activate
  ```

Para salir del entorno:

```bash
deactivate
```

#### 1.3.2 Instalación de paquetes de Python

Dentro del entorno virtual activado, instalar:

```bash
pip install pandas numpy scikit-learn tensorflow matplotlib
```

Principales usos:

* `pandas`, `numpy`: manipulación de datos.
* `scikit-learn`: partición train/test, normalización, codificación.
* `tensorflow` / `keras`: construcción y entrenamiento de redes neuronales.
* `matplotlib`: gráficas de entrenamiento/validación.

---

## 2. Descarga y preparación de los datos

### 2.1 Descarga de microdatos del Censo 2018

1. Ingresar al sitio oficial del Censo 2018:

   [https://censo2018.ine.gob.gt/descarga](https://censo2018.ine.gob.gt/descarga)

2. Descargar los microdatos correspondientes a:

   * Personas (PERSONA)
   * Hogares (HOGAR)
   * Viviendas (VIVIENDA)
   * Migración (MIGRACION)
   * Diccionario de datos (en Excel o PDF)

Los nombres exactos pueden variar, pero este repositorio asume archivos del tipo:

* `PERSONA_BDP.csv`
* `HOGAR_BDP.csv`
* `VIVIENDA_BDP.csv`
* `MIGRACION_BDP.csv`
* Archivos de diccionario (`Diccionario_Base_*.xlsx`)

### 2.2 Organización de archivos

1. Crear la carpeta `data/raw/` en la raíz del proyecto, si no existe.
2. Descomprimir o copiar los archivos descargados dentro de `data/raw/`.
3. Al finalizar, la carpeta `data/raw/` debe verse similar a:

```text
data/raw/
  ├── PERSONA_BDP.csv
  ├── HOGAR_BDP.csv
  ├── VIVIENDA_BDP.csv
  ├── MIGRACION_BDP.csv
  ├── Diccionario de datos/
  │   ├── Diccionario_Base_EMIGRACION.xlsx
  │   ├── Diccionario_Base_HOGAR.xlsx
  │   ├── Diccionario_Base_PERSONA.xlsx
  │   └── Diccionario_Base_VIVIENDA.xlsx
  └── z_Verificacion Integridad de Bases SHA256.txt
```

La carpeta `data/raw/` debe contener únicamente los datos originales y el diccionario.

---

## 3. Estructura del repositorio

Estructura general del proyecto:

```text
.
├── data
│   ├── raw/               # Datos originales (NO versionados)
│   ├── clean/             # Datos limpios intermedios (RDS, generados)
│   └── output/            # Bases unificadas y datasets listos para modelar
│
├── reports
│   ├── apriori/           # Resultados de Apriori
│   ├── fpgrowth/          # Resultados de FP-Growth (Eclat)
│   ├── clustering/        # Resultados de k-means
│   ├── arboles/           # Árboles de decisión (imágenes y métricas)
│   ├── random_forest/     # Random Forest (curvas OOB, importancia, métricas)
│   └── redes_neuronales/  # Resultados y figuras de redes neuronales
│
├── scripts
│   ├── 01_limpieza.R
│   ├── 02_unificacion.R
│   ├── 03_apriori.R
│   ├── 04_fp_growth.R
│   ├── 05_kmeans.R
│   ├── 06_preparacion_modelado.R
│   ├── 07_arboles_decision.R
│   ├── 08_random_forest.R
│   └── 09_redes_neuronales.py
│
├── reports.zip            # Ejemplos de salidas ya generadas (solo referencia)
├── .gitignore
└── README.md
```

Las carpetas `data/` y `reports/` se excluyen del control de versiones mediante `.gitignore` porque contienen archivos muy pesados. Para facilitar la revisión, se incluye **`reports.zip`** con ejemplos de resultados.

---

## 4. Parte 1 – Minería de datos en R (Fases 1 a 5)

### 4.1 Fase 1 – Limpieza de datos (`01_limpieza.R`)

**Objetivo:** cargar y limpiar los microdatos originales del INE.

**Entrada:**

* `data/raw/PERSONA_BDP.csv`
* `data/raw/HOGAR_BDP.csv`
* `data/raw/VIVIENDA_BDP.csv`
* `data/raw/MIGRACION_BDP.csv`

**Salida (ejemplo):**

* `data/clean/persona_clean.rds`
* `data/clean/hogar_clean.rds`
* `data/clean/vivienda_clean.rds`
* `data/clean/migracion_clean.rds`

El script informa en consola el número de registros, columnas, valores faltantes y transformaciones aplicadas.

### 4.2 Fase 2 – Unificación de bases (`02_unificacion.R`)

**Objetivo:** integrar información de viviendas, hogares, personas y migración.

**Entrada:**

* RDS limpios en `data/clean/`.

**Procesos clave:**

* Definición de llaves a nivel de vivienda y hogar.
* Unión de HOGAR + VIVIENDA → `hogar_vivienda`.
* Construcción de un **índice preliminar de calidad de vivienda** combinando materiales y acceso a servicios.
* Resumen de migración a nivel de hogar (número de emigrantes, edad promedio).
* Unión de migración con `hogar_vivienda` → `hogar_vivienda_migracion`.
* Unión final con PERSONA → `base_persona_maestra`.

**Salida:**

* `data/output/hogar_vivienda.rds`
* `data/output/hogar_vivienda_migracion.rds`
* `data/output/base_persona_maestra.rds`
* Versiones `.csv` para inspección.

### 4.3 Fase 3 – Reglas de asociación (Apriori) (`03_apriori.R`)

**Objetivo:** obtener reglas de asociación entre características de vivienda y migración.

**Entrada:**

* `data/output/hogar_vivienda_migracion.rds`

**Salida principal:**

* `reports/apriori/reglas_apriori_lift_mayor_1.csv`
* `reports/apriori/reglas_apriori_lift_mayor_1.rds`
* Gráficas de soporte/confianza (por ejemplo, `hist_confianza_reglas.png`, `scatter_soporte_confianza_lift.png`).

### 4.4 Fase 4 – FP-Growth / Eclat (`04_fp_growth.R`)

**Objetivo:** extraer patrones frecuentes tipo FP-Growth usando Eclat.

**Entrada:**

* `data/output/hogar_vivienda_migracion.rds`

**Salida principal:**

* `reports/fpgrowth/itemsets_frecuentes_fp_growth.csv`
* `reports/fpgrowth/reglas_fp_growth_lift_gt_1.csv`
* `reports/fpgrowth/reglas_fp_growth.rds`
* Gráficas de soporte de itemsets y soporte/confianza de reglas.

### 4.5 Fase 5 – Clustering k-means (`05_kmeans.R`)

**Objetivo:** identificar grupos de hogares con patrones similares.

**Entrada:**

* `data/output/hogar_vivienda_migracion.rds`
* `data/output/base_persona_maestra.rds`

**Salida principal:**

* `reports/clustering/resumen_clusters_k4.csv`
* `reports/clustering/hogar_vivienda_migracion_clusters_k4.csv`
* `reports/clustering/modelo_kmeans_k4.rds`
* `reports/clustering/scatter_clusters_k4.png`

---

## 5. Parte 2 – Modelos predictivos

### 5.1 Fase 6 – Preparación del dataset de modelado (`06_preparacion_modelado.R`)

**Objetivo:** construir un dataset a nivel de hogar listo para modelos supervisados (árboles, random forest, redes neuronales).

**Procesos clave:**

* Cálculo de `n_personas` por hogar y unión con `hogar_vivienda_migracion`.
* Uso de variables derivadas de fases anteriores, como:

  * `indice_calidad_vivienda`
  * `n_emigrantes`
  * `edad_promedio_emigrantes`
  * `cluster_k4` (resultado del k-means)
  * indicadores binarios de servicios (`agua_mejorada`, `saneamiento_mejorado`, `electricidad`).
* Creación de variables objetivo categóricas:

  * `indice_calidad_vivienda_cat`
  * `n_emigrantes_cat`

**Salida:**

* `data/output/modeling_dataset.csv`
* `data/output/modeling_dataset_sample.csv` (muestra reducida para pruebas más rápidas).

### 5.2 Fase 7 – Árboles de decisión (4 targets) (`07_arboles_decision.R`)

**Objetivo:** entrenar cuatro modelos de árbol de decisión para distintos objetivos:

1. Target: `indice_calidad_vivienda_cat`
   Predictoras: materiales, servicios, área, cluster k-means.

2. Target: `n_emigrantes_cat`
   Predictoras: área, índice de calidad, tamaño del hogar, clúster.

3. Target: `agua_mejorada`
   Predictoras: área, materiales, región/departamento, clúster.

4. Target: `cluster_k4`
   Predictoras: tamaño del hogar, índice de vivienda, servicios básicos.

Cada modelo:

* Divide datos en train/test.
* Ajusta un árbol con `rpart`.
* Genera:

  * Gráfico del árbol (`*.png`).
  * Matriz de confusión (`*.csv`).
  * Métricas básicas de desempeño.
  * Importancia de variables (`*.csv`).
  * Predicciones por escenarios (guardadas en CSV).

**Salida:**

* Directorio `reports/arboles/` con:

  * `modeloX_arbol.png`
  * `modeloX_matriz_confusion.csv`
  * `modeloX_importancia_variables.csv`
  * `modeloX_predicciones_escenarios.csv`

### 5.3 Fase 8 – Random Forest (3 targets) (`08_random_forest.R`)

**Objetivo:** entrenar tres modelos de Random Forest sobre objetivos relacionados, pero con configuraciones y combinaciones de variables diferentes a los árboles.

Ejemplos de modelos:

1. RF 1 – Target: `cluster_k4`
   Predictoras: materiales, servicios, tamaño del hogar, migración.

2. RF 2 – Target: `indice_calidad_vivienda_cat`
   Predictoras: servicios básicos, materiales, área, departamento.

3. RF 3 – Target: `n_emigrantes_cat`
   Predictoras: calidad de vivienda, tamaño del hogar, servicios, área.

Cada modelo:

* Calcula error out-of-bag (OOB) y lo grafica.
* Exporta importancia de variables.
* Evalúa en test con matriz de confusión.
* Genera predicciones para escenarios específicos.

**Salida:**

* Directorio `reports/random_forest/` con:

  * Curvas de error OOB (`*.png`).
  * Importancia de variables (`*_importance.csv`).
  * Matrices de confusión (`*_matriz_confusion.csv`).
  * Predicciones por escenarios (`*_predicciones_escenarios.csv`).

### 5.4 Fase 9 – Redes neuronales en Python (3 modelos) (`09_redes_neuronales.py`)

**Objetivo:** construir tres redes neuronales que repliquen los targets de los árboles de decisión para comparar desempeño y capacidad de modelar relaciones complejas.

Targets:

1. NN1 – `indice_calidad_vivienda_cat`
2. NN2 – `n_emigrantes_cat`
3. NN3 – `agua_mejorada`

Cada modelo realiza:

* División train/test.
* Normalización de variables numéricas.
* One-hot encoding de variables categóricas (usando `ColumnTransformer`).
* Definición de una arquitectura clara en Keras (capas densas, dropout).
* Entrenamiento con validación (`validation_split`).
* Gráficas de entrenamiento vs validación:

  * Accuracy.
  * Loss.
* Evaluación en test (accuracy).
* Predicciones para escenarios concretos.
* Guardado del modelo en formato Keras (`*.keras`).

**Ejecución:**

Dentro del entorno virtual:

```bash
python scripts/09_redes_neuronales.py
```

**Salida:**

* Directorio `reports/redes_neuronales/` con:

  * `nnX_accuracy.png`, `nnX_loss.png`
  * `nnX_predicciones_escenarios.csv`
  * `nnX_model.keras`

En el documento de resultados se compara:

* Accuracy de las redes neuronales frente a sus árboles de decisión correspondientes.
* Comportamiento de las curvas de entrenamiento/validación (posibles indicios de sobreajuste o buen ajuste).
* Interpretación de los escenarios simulados.

---

## 6. Ejecución rápida del pipeline

Orden recomendado:

En R:

```r
# Parte 1
source("scripts/01_limpieza.R")
source("scripts/02_unificacion.R")
source("scripts/03_apriori.R")
source("scripts/04_fp_growth.R")
source("scripts/05_kmeans.R")

# Parte 2
source("scripts/06_preparacion_modelado.R")
source("scripts/07_arboles_decision.R")
source("scripts/08_random_forest.R")
```

En Python (con entorno virtual activado):

```bash
python scripts/09_redes_neuronales.py
```

El orden garantiza que cada fase encuentre los archivos generados en la fase anterior.

---

## 7. Sobre la carpeta `reports/` y el archivo `reports.zip`

* La carpeta `reports/` se **excluye del control de versiones** en `.gitignore` debido al tamaño y a la naturaleza derivada de los archivos (gráficas, CSV masivos, modelos entrenados).
* Para facilitar la visualización de resultados sin necesidad de ejecutar todos los scripts, se incluye en el repositorio un archivo **`reports.zip`** que contiene una versión de referencia de los reportes generados.
* Si se desea inspeccionar rápidamente los resultados:

  1. Descomprimir `reports.zip` en la raíz del proyecto.
  2. Navegar por `reports/` y revisar las figuras y tablas.
* Si se desea regenerar todos los resultados desde cero, se recomienda:

  * Vaciar o eliminar `reports/`.
  * Ejecutar nuevamente los scripts en el orden indicado.

---

## 8. Créditos y uso de datos

* Los datos utilizados provienen del **Instituto Nacional de Estadística (INE) de Guatemala**, específicamente de los microdatos del **Censo de Población y Vivienda 2018**.
* El uso de la información debe respetar los términos, condiciones y licencias definidas por el INE y la normativa nacional sobre protección de datos.
* Este repositorio únicamente proporciona código para el procesamiento y análisis de los datos; **no** distribuye microdatos ni información sensible.
* Para consultas sobre el código o la estructura del proyecto, se puede contactar al autor en **[erikssonhernandez25@gmail.com](mailto:erikssonhernandez25@gmail.com)**.

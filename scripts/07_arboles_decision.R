# ===============================================================
# Fase 7 — Modelos de Árboles de Decisión (4 targets)
# ---------------------------------------------------------------
# Este script:
#   1. Carga el dataset de modelado a nivel de hogar.
#   2. Ajusta 4 modelos de árboles de decisión con distintos targets:
#
#      Modelo 1
#        Target: indice_calidad_vivienda_cat
#        Predictoras: PCV2, PCV3, PCV5, agua_mejorada,
#                     saneamiento_mejorado, electricidad, AREA, cluster_k4
#
#      Modelo 2
#        Target: n_emigrantes_cat
#        Predictoras: AREA, indice_calidad_vivienda_cat,
#                     n_personas, cluster_k4
#
#      Modelo 3
#        Target: agua_mejorada
#        Predictoras: AREA, PCV2, PCV3, PCV5, DEPARTAMENTO, cluster_k4
#
#      Modelo 4
#        Target: cluster_k4
#        Predictoras: n_personas, indice_calidad_vivienda_cat,
#                     agua_mejorada, saneamiento_mejorado, electricidad
#
#   3. Para cada modelo:
#        - Realiza partición train/test (70/30).
#        - Ajusta un árbol de decisión con rpart.
#        - Exporta gráfico del árbol.
#        - Exporta matriz de confusión.
#        - Exporta importancia de variables.
#        - Ejecuta predicciones de varios escenarios y las muestra en consola.
#
# Resultados:
#   - Directorio: reports/decision_trees/
#       * arbol_modeloX_*.png
#       * matriz_confusion_modeloX_*.csv
#       * importancia_variables_modeloX_*.csv
#       * modelo_arbol_X_*.rds
# ===============================================================

suppressPackageStartupMessages({
  library(data.table)
  library(rpart)
})

# Carga opcional de rpart.plot para gráficos más legibles
has_rpart_plot <- requireNamespace("rpart.plot", quietly = TRUE)

cat("==============================================================\n")
cat(" FASE 7 — MODELOS DE ÁRBOLES DE DECISIÓN\n")
cat("==============================================================\n\n")

if (!has_rpart_plot) {
  cat("Nota: el paquete 'rpart.plot' no está instalado.\n")
  cat("Se utilizarán gráficos base de rpart para los árboles.\n\n")
} else {
  cat("Paquete 'rpart.plot' disponible. Se utilizarán gráficos mejorados.\n\n")
}

# ---------------------------------------------------------------
# 1. Definición de rutas
# ---------------------------------------------------------------
dir_output   <- file.path("data", "output")
dir_reports  <- file.path("reports", "decision_trees")

cat("--- Definiendo rutas de entrada y salida ---\n")

if (!dir.exists(dir_output)) {
  stop("No se encontró el directorio 'data/output'. ",
       "Ejecutar previamente las fases 1 a 6.")
}

if (!dir.exists(dir_reports)) {
  dir.create(dir_reports, recursive = TRUE)
  cat("Directorio 'reports/decision_trees' creado.\n")
} else {
  cat("Directorio 'reports/decision_trees' encontrado.\n")
}

# ---------------------------------------------------------------
# 2. Carga del dataset de modelado
# ---------------------------------------------------------------
cat("\n--- Cargando dataset de modelado ---\n")

ruta_modeling_rds <- file.path(dir_output, "modeling_dataset.rds")

if (!file.exists(ruta_modeling_rds)) {
  stop("No se encontró 'modeling_dataset.rds' en data/output/. ",
       "Ejecutar primero 06_preparacion_modelado.R.")
}

modeling_dataset <- as.data.table(readRDS(ruta_modeling_rds))

cat("Dataset de modelado cargado correctamente.\n")
cat("Registros:", nrow(modeling_dataset), "\n")
cat("Columnas :", ncol(modeling_dataset), "\n\n")

# ---------------------------------------------------------------
# 3. Función auxiliar genérica para entrenar y reportar un árbol
# ---------------------------------------------------------------
entrenar_y_reportar_arbol <- function(
  data,
  target,
  predictors,
  nombre_modelo,
  prefijo_archivo,
  dir_reports,
  escenarios = NULL,
  seed_offset = 0L
) {
  cat("--------------------------------------------------------------\n")
  cat(" Modelo:", nombre_modelo, "\n")
  cat(" Target:", target, "\n")
  cat(" Predictoras:", paste(predictors, collapse = ", "), "\n")
  cat("--------------------------------------------------------------\n")

  # Verificación de columnas
  columnas_necesarias <- c(target, predictors)
  columnas_faltantes  <- setdiff(columnas_necesarias, names(data))

  if (length(columnas_faltantes) > 0) {
    stop("Las siguientes columnas requeridas no se encuentran en el dataset de modelado:\n  ",
         paste(columnas_faltantes, collapse = ", "), "\n",
         "Revisar la fase de preparación del dataset.")
  }

  # Subconjunto de datos
  dt <- copy(data[, ..columnas_necesarias])

  # Conversión explícita de target a factor
  # (si ya es factor, esta conversión lo preserva)
  dt[, (target) := as.factor(get(target))]

  # Eliminación de filas con NA en target o predictoras
  dt <- na.omit(dt)

  cat("Registros disponibles tras eliminar NA:", nrow(dt), "\n")

  if (nrow(dt) < 1000) {
    cat("Advertencia: el número de registros es relativamente bajo para este modelo.\n")
  }

  # Muestreo opcional para evitar tiempos excesivos
  n_max <- 150000L
  if (nrow(dt) > n_max) {
    set.seed(1234 + seed_offset)
    idx_sample <- sample(seq_len(nrow(dt)), n_max)
    dt <- dt[idx_sample]
    cat("Se realizó muestreo aleatorio a", n_max, "registros para agilizar el entrenamiento.\n")
  }

  # Partición train/test 70/30
  set.seed(2024 + seed_offset)
  n <- nrow(dt)
  idx_train <- sample(seq_len(n), size = floor(0.7 * n))
  train_dt  <- dt[idx_train]
  test_dt   <- dt[-idx_train]

  cat("Registros en entrenamiento:", nrow(train_dt), "\n")
  cat("Registros en prueba       :", nrow(test_dt), "\n")

  # Fórmula del modelo
  formula_str <- paste(target, "~", paste(predictors, collapse = " + "))
  formula_obj <- as.formula(formula_str)

  # Entrenamiento del árbol de decisión
  cat("\n--- Entrenando árbol de decisión ---\n")
  modelo_arbol <- rpart(
    formula_obj,
    data   = train_dt,
    method = "class",
    control = rpart.control(
      cp        = 0.001,
      minbucket = 50
    )
  )

  cat("Árbol entrenado.\n")

  # Predicción sobre el conjunto de prueba
  cat("\n--- Evaluando desempeño en el conjunto de prueba ---\n")
  pred_test <- predict(modelo_arbol, newdata = test_dt, type = "class")

  cm <- table(
    Real      = test_dt[[target]],
    Predicho  = pred_test
  )

  cat("Matriz de confusión:\n")
  print(cm)

  accuracy <- sum(diag(cm)) / sum(cm)
  cat("\nExactitud global (accuracy):", round(accuracy * 100, 2), "%\n")

  # Importancia de variables
  cat("\n--- Importancia de variables ---\n")
  importancia <- modelo_arbol$variable.importance

  if (is.null(importancia)) {
    cat("El modelo no reporta importancia de variables.\n")
    importancia_dt <- data.table(
      variable   = predictors,
      importancia = NA_real_
    )
  } else {
    importancia_dt <- data.table(
      variable   = names(importancia),
      importancia = as.numeric(importancia)
    )[order(-importancia)]
    print(importancia_dt)
  }

  # -----------------------------------------------------------
  # Exportación de resultados
  # -----------------------------------------------------------
  cat("\n--- Exportando resultados del modelo ---\n")

  # Matriz de confusión a CSV
  cm_dt <- as.data.table(cm)
  data.table::setnames(cm_dt, c("Real", "Predicho", "Frecuencia"))

  ruta_cm <- file.path(
    dir_reports,
    paste0("matriz_confusion_", prefijo_archivo, ".csv")
  )
  fwrite(cm_dt, ruta_cm)

  # Importancia de variables a CSV
  ruta_imp <- file.path(
    dir_reports,
    paste0("importancia_variables_", prefijo_archivo, ".csv")
  )
  fwrite(importancia_dt, ruta_imp)

  # Guardar modelo a RDS
  ruta_modelo <- file.path(
    dir_reports,
    paste0("modelo_arbol_", prefijo_archivo, ".rds")
  )
  saveRDS(modelo_arbol, ruta_modelo)

  cat("Archivos exportados:\n")
  cat(" -", ruta_cm, "\n")
  cat(" -", ruta_imp, "\n")
  cat(" -", ruta_modelo, "\n")

  # -----------------------------------------------------------
  # Gráfico del árbol
  # -----------------------------------------------------------
  cat("\n--- Generando gráfico del árbol de decisión ---\n")

  ruta_png <- file.path(
    dir_reports,
    paste0("arbol_", prefijo_archivo, ".png")
  )

  png(ruta_png, width = 1200, height = 800)
  if (has_rpart_plot) {
    rpart.plot::rpart.plot(
      modelo_arbol,
      main = paste("Árbol de decisión -", nombre_modelo),
      type = 2,
      extra = 106,
      under = TRUE,
      tweak = 1.1
    )
  } else {
    plot(modelo_arbol, uniform = TRUE, main = paste("Árbol -", nombre_modelo))
    text(modelo_arbol, use.n = TRUE, cex = 0.7)
  }
  dev.off()

  cat("Gráfico del árbol guardado en:\n")
  cat(" -", ruta_png, "\n")

  # -----------------------------------------------------------
  # Predicciones de escenarios
  # -----------------------------------------------------------
  if (!is.null(escenarios) && length(escenarios) > 0) {
    cat("\n--- Predicciones de escenarios para", nombre_modelo, "---\n")

    for (i in seq_along(escenarios)) {
      esc <- escenarios[[i]]
      nombre_esc <- esc$nombre
      valores    <- esc$valores

      # Construcción de newdata con todas las columnas predictoras
      new_obs <- as.list(rep(NA, length(predictors)))
      names(new_obs) <- predictors

      # Asignar los valores definidos en el escenario
      for (nm in names(valores)) {
        if (nm %in% predictors) {
          new_obs[[nm]] <- valores[[nm]]
        }
      }

      new_df <- as.data.frame(new_obs, stringsAsFactors = FALSE)

      # Intentar preservar tipos según train_dt
      for (p in predictors) {
        if (is.factor(train_dt[[p]])) {
          # Si es factor en entrenamiento, convertir usando los mismos niveles
          new_df[[p]] <- factor(
            new_df[[p]],
            levels = levels(train_dt[[p]])
          )
        } else {
          # Caso numérico o lógico
          new_df[[p]] <- as.numeric(new_df[[p]])
        }
      }

      pred_esc <- predict(modelo_arbol, newdata = new_df, type = "prob")
      clase_esc <- predict(modelo_arbol, newdata = new_df, type = "class")

      cat("\nEscenario", i, ":", nombre_esc, "\n")
      cat("Valores de entrada:\n")
      print(new_df)
      cat("Predicción de clase:", as.character(clase_esc), "\n")
      cat("Distribución de probabilidades:\n")
      print(pred_esc)
    }
  } else {
    cat("\nNo se definieron escenarios para este modelo.\n")
  }

  cat("\nFin del modelo:", nombre_modelo, "\n\n")

  # Retornar el objeto modelo por si se quiere usar en memoria
  invisible(modelo_arbol)
}

# ===============================================================
# 4. Definición de modelos y ejecución
# ===============================================================

# ---------------------------------------------------------------
# Modelo 1
# Target: indice_calidad_vivienda_cat
# Predictoras: materiales, servicios básicos, área, clúster.
# ---------------------------------------------------------------
modelo1_target      <- "indice_calidad_vivienda_cat"
modelo1_predictoras <- c(
  "PCV2", "PCV3", "PCV5",                  # materiales de pared, techo y piso
  "agua_mejorada", "saneamiento_mejorado", # servicios básicos
  "electricidad",
  "AREA",                                  # urbano/rural
  "cluster_k4"                             # clúster k-means
)

escenarios_modelo1 <- list(
  list(
    nombre  = "Vivienda rural con materiales precarios y sin servicios básicos",
    valores = list(
      PCV2               = 7L,
      PCV3               = 7L,
      PCV5               = 6L,
      agua_mejorada      = 0L,
      saneamiento_mejorado = 0L,
      electricidad       = 0L,
      AREA               = 2L,  # por ejemplo: 1 = urbano, 2 = rural
      cluster_k4         = 1L
    )
  ),
  list(
    nombre  = "Vivienda urbana con materiales sólidos y todos los servicios",
    valores = list(
      PCV2               = 1L,
      PCV3               = 3L,
      PCV5               = 2L,
      agua_mejorada      = 1L,
      saneamiento_mejorado = 1L,
      electricidad       = 1L,
      AREA               = 1L,
      cluster_k4         = 3L
    )
  ),
  list(
    nombre  = "Vivienda urbana intermedia con algunos servicios",
    valores = list(
      PCV2               = 2L,
      PCV3               = 4L,
      PCV5               = 3L,
      agua_mejorada      = 1L,
      saneamiento_mejorado = 0L,
      electricidad       = 1L,
      AREA               = 1L,
      cluster_k4         = 2L
    )
  )
)

modelo_arbol_1 <- entrenar_y_reportar_arbol(
  data          = modeling_dataset,
  target        = modelo1_target,
  predictors    = modelo1_predictoras,
  nombre_modelo = "Modelo 1 — Índice de calidad de vivienda (categorías)",
  prefijo_archivo = "modelo1_indice_calidad_vivienda_cat",
  dir_reports   = dir_reports,
  escenarios    = escenarios_modelo1,
  seed_offset   = 1L
)

# ---------------------------------------------------------------
# Modelo 2
# Target: n_emigrantes_cat
# Predictoras: área, índice de calidad, tamaño del hogar, clúster.
# ---------------------------------------------------------------
modelo2_target      <- "n_emigrantes_cat"
modelo2_predictoras <- c(
  "AREA",
  "indice_calidad_vivienda_cat",
  "n_personas",
  "cluster_k4"
)

escenarios_modelo2 <- list(
  list(
    nombre  = "Hogar rural grande con baja calidad de vivienda",
    valores = list(
      AREA                     = 2L,
      indice_calidad_vivienda_cat = "muy_baja",
      n_personas               = 8L,
      cluster_k4               = 2L
    )
  ),
  list(
    nombre  = "Hogar urbano pequeño con buena calidad de vivienda",
    valores = list(
      AREA                     = 1L,
      indice_calidad_vivienda_cat = "alta",
      n_personas               = 3L,
      cluster_k4               = 3L
    )
  ),
  list(
    nombre  = "Hogar urbano mediano con calidad media",
    valores = list(
      AREA                     = 1L,
      indice_calidad_vivienda_cat = "media",
      n_personas               = 5L,
      cluster_k4               = 4L
    )
  )
)

modelo_arbol_2 <- entrenar_y_reportar_arbol(
  data          = modeling_dataset,
  target        = modelo2_target,
  predictors    = modelo2_predictoras,
  nombre_modelo = "Modelo 2 — Número de emigrantes (categorías)",
  prefijo_archivo = "modelo2_n_emigrantes_cat",
  dir_reports   = dir_reports,
  escenarios    = escenarios_modelo2,
  seed_offset   = 2L
)

# ---------------------------------------------------------------
# Modelo 3
# Target: agua_mejorada
# Predictoras: área, materiales, departamento (región aproximada), clúster.
# ---------------------------------------------------------------
# Para este modelo se transforma agua_mejorada a factor (0/1 -> categorías)
# directamente sobre una copia del dataset de modelado.
modeling_dataset_m3 <- copy(modeling_dataset)
if ("agua_mejorada" %in% names(modeling_dataset_m3)) {
  modeling_dataset_m3[, agua_mejorada := factor(
    agua_mejorada,
    levels = c(0, 1),
    labels = c("sin_agua_mejorada", "con_agua_mejorada")
  )]
}

modelo3_target      <- "agua_mejorada"
modelo3_predictoras <- c(
  "AREA",
  "PCV2",
  "PCV3",
  "PCV5",
  "DEPARTAMENTO",
  "cluster_k4"
)

escenarios_modelo3 <- list(
  list(
    nombre  = "Hogar rural en departamento de código 5, materiales precarios",
    valores = list(
      AREA         = 2L,
      PCV2         = 7L,
      PCV3         = 7L,
      PCV5         = 6L,
      DEPARTAMENTO = 5L,
      cluster_k4   = 1L
    )
  ),
  list(
    nombre  = "Hogar urbano en departamento de código 1, materiales sólidos",
    valores = list(
      AREA         = 1L,
      PCV2         = 1L,
      PCV3         = 3L,
      PCV5         = 2L,
      DEPARTAMENTO = 1L,
      cluster_k4   = 3L
    )
  ),
  list(
    nombre  = "Hogar urbano en departamento de código 10, materiales intermedios",
    valores = list(
      AREA         = 1L,
      PCV2         = 3L,
      PCV3         = 4L,
      PCV5         = 3L,
      DEPARTAMENTO = 10L,
      cluster_k4   = 4L
    )
  )
)

modelo_arbol_3 <- entrenar_y_reportar_arbol(
  data          = modeling_dataset_m3,
  target        = modelo3_target,
  predictors    = modelo3_predictoras,
  nombre_modelo = "Modelo 3 — Acceso a agua mejorada",
  prefijo_archivo = "modelo3_agua_mejorada",
  dir_reports   = dir_reports,
  escenarios    = escenarios_modelo3,
  seed_offset   = 3L
)

# ---------------------------------------------------------------
# Modelo 4
# Target: cluster_k4
# Predictoras: tamaño del hogar, índice de vivienda, servicios básicos.
# ---------------------------------------------------------------
# Para este modelo se convierte cluster_k4 a factor (clases de clúster).
modeling_dataset_m4 <- copy(modeling_dataset)
if ("cluster_k4" %in% names(modeling_dataset_m4)) {
  modeling_dataset_m4[, cluster_k4 := as.factor(cluster_k4)]
}

modelo4_target      <- "cluster_k4"
modelo4_predictoras <- c(
  "n_personas",
  "indice_calidad_vivienda_cat",
  "agua_mejorada",
  "saneamiento_mejorado",
  "electricidad"
)

escenarios_modelo4 <- list(
  list(
    nombre  = "Hogar grande con baja calidad y pocos servicios",
    valores = list(
      n_personas               = 8L,
      indice_calidad_vivienda_cat = "baja",
      agua_mejorada            = 0L,
      saneamiento_mejorado     = 0L,
      electricidad             = 0L
    )
  ),
  list(
    nombre  = "Hogar pequeño con alta calidad y todos los servicios",
    valores = list(
      n_personas               = 3L,
      indice_calidad_vivienda_cat = "alta",
      agua_mejorada            = 1L,
      saneamiento_mejorado     = 1L,
      electricidad             = 1L
    )
  ),
  list(
    nombre  = "Hogar mediano con calidad media y servicios parciales",
    valores = list(
      n_personas               = 5L,
      indice_calidad_vivienda_cat = "media",
      agua_mejorada            = 1L,
      saneamiento_mejorado     = 0L,
      electricidad             = 1L
    )
  )
)

modelo_arbol_4 <- entrenar_y_reportar_arbol(
  data          = modeling_dataset_m4,
  target        = modelo4_target,
  predictors    = modelo4_predictoras,
  nombre_modelo = "Modelo 4 — Predicción de clúster k-means",
  prefijo_archivo = "modelo4_cluster_k4",
  dir_reports   = dir_reports,
  escenarios    = escenarios_modelo4,
  seed_offset   = 4L
)

cat("==============================================================\n")
cat(" FASE 7 COMPLETADA — ÁRBOLES DE DECISIÓN GENERADOS\n")
cat("==============================================================\n\n")

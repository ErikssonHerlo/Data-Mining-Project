# ===============================================================
<<<<<<< HEAD
# Fase 8 — Modelos Random Forest
=======
# Fase 8 — Modelos Random Forest (Proyecto Parte 2)
>>>>>>> 75590ad (Feat: add Random Forest modeling script for multiple targets)
# ---------------------------------------------------------------
# Este script:
#   1. Carga el dataset de modelado preparado en la Fase 6.
#   2. Entrena 3 modelos Random Forest con distintos targets:
#        - RF1: cluster_k4
#        - RF2: indice_calidad_vivienda_cat
#        - RF3: n_emigrantes_cat
#   3. Cada modelo genera:
#        - Curva de error out-of-bag (OOB).
#        - Importancia de variables (tabla y gráfica).
#        - Matriz de confusión en conjunto de prueba.
#        - Predicciones de escenarios específicos.
#   4. Exporta resultados a reports/random_forest/.
# ===============================================================

suppressPackageStartupMessages({
    library(data.table)
    library(randomForest)
})

# Carga opcional de ggplot2 para algunas gráficas
has_ggplot2 <- requireNamespace("ggplot2", quietly = TRUE)

cat("==============================================================\n")
cat(" FASE 8 — MODELOS RANDOM FOREST (PROYECTO PARTE 2)\n")
cat("==============================================================\n\n")

if (!has_ggplot2) {
    cat("Nota: el paquete 'ggplot2' no está instalado.\n")
    cat("Los modelos Random Forest se ejecutarán normalmente,\n")
    cat("pero se usarán principalmente gráficos base de R.\n\n")
} else {
    cat("Paquete 'ggplot2' disponible. Se habilitan algunas visualizaciones adicionales.\n\n")
}

# ---------------------------------------------------------------
# 1. Rutas y verificación de archivos
# ---------------------------------------------------------------
cat("--- Definiendo rutas de entrada y salida ---\n")

dir_output <- file.path("data", "output")
dir_reports <- file.path("reports", "random_forest")

if (!dir.exists(dir_reports)) {
    dir.create(dir_reports, recursive = TRUE)
    cat("Directorio 'reports/random_forest' creado.\n")
} else {
    cat("Directorio 'reports/random_forest' encontrado.\n")
}

ruta_sample <- file.path(dir_output, "modeling_dataset_sample.rds")
ruta_full <- file.path(dir_output, "modeling_dataset.rds")

if (file.exists(ruta_sample)) {
    ruta_model <- ruta_sample
    cat("Se utilizará el dataset muestreado para modelado:\n")
    cat(" -", ruta_sample, "\n")
} else if (file.exists(ruta_full)) {
    ruta_model <- ruta_full
    cat("Advertencia: no se encontró 'modeling_dataset_sample.rds'.\n")
    cat("Se utilizará el dataset completo para modelado:\n")
    cat(" -", ruta_full, "\n")
    cat("Esto puede incrementar significativamente el tiempo de cómputo.\n")
} else {
    stop(
        "No se encontraron ni 'modeling_dataset_sample.rds' ni 'modeling_dataset.rds' en data/output/.\n",
        "Ejecutar primero 06_preparacion_modelado.R."
    )
}

cat("\n--- Cargando dataset de modelado ---\n")
dt_model <- readRDS(ruta_model)
dt_model <- as.data.table(dt_model)

cat("Registros en dataset de modelado:", nrow(dt_model), "\n")
cat("Columnas en dataset de modelado :", ncol(dt_model), "\n\n")

# ---------------------------------------------------------------
# 2. Funciones auxiliares genéricas
# ---------------------------------------------------------------

# 2.1. Función para entrenar un Random Forest clasificador
entrenar_random_forest <- function(
  data,
  target,
  predictors,
  model_id,
  dir_reports
) {
    cat("------------------------------------------------------------\n")
    cat(" Entrenando modelo Random Forest:", model_id, "\n")
    cat("------------------------------------------------------------\n")

    # Verificación de columnas disponibles
    cols_necesarias <- c(target, predictors)
    cols_existentes <- intersect(cols_necesarias, names(data))
    faltantes <- setdiff(cols_necesarias, cols_existentes)

    if (length(faltantes) > 0) {
        stop(
            "Las siguientes columnas requeridas no se encuentran en el dataset de modelado para ",
            model_id, ":\n  - ",
            paste(faltantes, collapse = ", "),
            "\nRevisar 06_preparacion_modelado.R y nombres de variables."
        )
    }

    dt_sub <- data[, ..cols_existentes]

    # Asegurar que la variable objetivo sea factor
    if (!is.factor(dt_sub[[target]])) {
        dt_sub[[target]] <- as.factor(dt_sub[[target]])
    }

    # Eliminación de filas con NA en target o predictores
    completos <- complete.cases(dt_sub)
    n_total <- nrow(dt_sub)
    n_usados <- sum(completos)

    cat("Observaciones totales para", model_id, ":", n_total, "\n")
    cat("Observaciones completas (sin NA):", n_usados, "\n")

    if (n_usados < 1000) {
        cat("Advertencia: menos de 1000 observaciones completas para este modelo.\n")
    }

    dt_sub <- dt_sub[completos]

    # Split entrenamiento / prueba (70 / 30)
    set.seed(1234 + as.integer(substr(gsub("[^0-9]", "", model_id), 1, 3)))

    n <- nrow(dt_sub)
    idx_train <- sample(seq_len(n), size = floor(0.7 * n))

    dt_train <- dt_sub[idx_train]
    dt_test <- dt_sub[-idx_train]

    cat("Tamaño de conjunto de entrenamiento:", nrow(dt_train), "\n")
    cat("Tamaño de conjunto de prueba      :", nrow(dt_test), "\n")

    # Construcción de la fórmula
    formula_rf <- as.formula(
        paste(target, "~", paste(predictors, collapse = " + "))
    )

    cat("\nFórmula utilizada:\n  ", deparse(formula_rf), "\n")

    # Entrenamiento del modelo Random Forest
    n_predictors <- length(predictors)
    mtry_default <- floor(sqrt(n_predictors))

    cat("\n--- Entrenando Random Forest ---\n")
    cat("Número de árboles (ntree): 300\n")
    cat("Número de predictores por split (mtry):", mtry_default, "\n")

    modelo_rf <- randomForest(
        formula_rf,
        data = dt_train,
        ntree = 300,
        mtry = mtry_default,
        importance = TRUE,
        na.action = na.omit
    )

    cat("Entrenamiento completado.\n")
    cat(
        "Error OOB final (estimación de error general):",
        round(tail(modelo_rf$err.rate[, "OOB"], 1), 4), "\n\n"
    )

    # -----------------------------------------------------------
    # 2.2. Curva de error OOB
    # -----------------------------------------------------------
    cat("--- Generando gráfica de error OOB ---\n")

    ruta_oob <- file.path(dir_reports, paste0(model_id, "_oob_error.png"))

    png(ruta_oob, width = 900, height = 600)
    plot(
        modelo_rf,
        main = paste0("Curva de error OOB - ", model_id)
    )
    dev.off()

    cat("Gráfica de error OOB guardada en:\n  -", ruta_oob, "\n\n")

    # -----------------------------------------------------------
    # 2.3. Evaluación en conjunto de prueba (matriz de confusión)
    # -----------------------------------------------------------
    cat("--- Evaluación en conjunto de prueba ---\n")

    pred_test <- predict(modelo_rf, newdata = dt_test, type = "response")

    matriz_conf <- table(
        Real       = dt_test[[target]],
        Predicho   = pred_test
    )

    cat("Matriz de confusión (conjunto de prueba):\n")
    print(matriz_conf)

    accuracy <- sum(diag(matriz_conf)) / sum(matriz_conf)
    cat("Exactitud (accuracy) en prueba:", round(accuracy, 4), "\n\n")

    # Exportar matriz de confusión
    ruta_conf <- file.path(dir_reports, paste0(model_id, "_matriz_confusion.csv"))
    fwrite(
        as.data.table(matriz_conf),
        ruta_conf
    )
    cat("Matriz de confusión exportada a:\n  -", ruta_conf, "\n\n")

    # -----------------------------------------------------------
    # 2.4. Importancia de variables
    # -----------------------------------------------------------
    cat("--- Importancia de variables ---\n")

    imp <- randomForest::importance(modelo_rf)
    imp_dt <- as.data.table(imp, keep.rownames = "variable")

    setorder(imp_dt, -MeanDecreaseGini)

    cat("Variables más importantes según MeanDecreaseGini:\n")
    print(head(imp_dt, 10))

    ruta_imp <- file.path(dir_reports, paste0(model_id, "_variable_importance.csv"))
    fwrite(imp_dt, ruta_imp)

    cat("Importancia de variables exportada a:\n  -", ruta_imp, "\n")

    # Gráfica de importancia (varImpPlot)
    ruta_imp_plot <- file.path(dir_reports, paste0(model_id, "_variable_importance.png"))

    png(ruta_imp_plot, width = 900, height = 600)
    varImpPlot(
        modelo_rf,
        main = paste0("Importancia de variables - ", model_id)
    )
    dev.off()

    cat("Gráfica de importancia de variables guardada en:\n  -", ruta_imp_plot, "\n\n")

    # -----------------------------------------------------------
    # 2.5. Retornar estructura con todo lo necesario
    # -----------------------------------------------------------
    list(
        modelo = modelo_rf,
        train = dt_train,
        test = dt_test,
        target = target,
        predictors = predictors
    )
}

# 2.6. Función para construir data.frame de escenarios respetando tipos
construir_escenarios <- function(train_data, predictors, lista_escenarios) {
    # lista_escenarios: named list, cada elemento es una lista con valores por predictor
    escenarios <- names(lista_escenarios)

    df_list <- lapply(escenarios, function(nombre) {
        vals <- lista_escenarios[[nombre]]
        fila <- vector("list", length(predictors))
        names(fila) <- predictors

        for (var in predictors) {
            base_col <- train_data[[var]]
            valor <- vals[[var]]

            if (is.factor(base_col)) {
                fila[[var]] <- factor(
                    valor,
                    levels = levels(base_col)
                )
            } else if (is.integer(base_col)) {
                fila[[var]] <- as.integer(valor)
            } else if (is.numeric(base_col)) {
                fila[[var]] <- as.numeric(valor)
            } else {
                fila[[var]] <- as.character(valor)
            }
        }

        as.data.table(fila)[, escenario := nombre]
    })

    resultado <- rbindlist(df_list, fill = TRUE)
    # Reordenar columnas: escenario primero
    setcolorder(resultado, c("escenario", predictors))
    resultado
}

# 2.7. Función para generar predicciones por escenarios y exportarlas
generar_predicciones_escenarios <- function(
  modelo_rf,
  train_data,
  predictors,
  lista_escenarios,
  model_id,
  dir_reports
) {
    cat("--- Predicciones por escenarios para", model_id, "---\n")

    df_esc <- construir_escenarios(train_data, predictors, lista_escenarios)

    # Predicción por clase (respuesta) y por probabilidad
    pred_resp <- predict(modelo_rf, newdata = df_esc, type = "response")
    pred_prob <- predict(modelo_rf, newdata = df_esc, type = "prob")

    df_res <- cbind(
        df_esc,
        clase_predicha = pred_resp,
        as.data.table(pred_prob)
    )

    cat("Predicciones por escenario:\n")
    print(df_res)

    ruta_esc <- file.path(dir_reports, paste0(model_id, "_predicciones_escenarios.csv"))
    fwrite(df_res, ruta_esc)

    cat("Predicciones de escenarios exportadas a:\n  -", ruta_esc, "\n\n")
}

# ---------------------------------------------------------------
# 3. MODELO RF 1 — Predicción del cluster_k4
# ---------------------------------------------------------------
cat("==============================================================\n")
cat(" MODELO RF 1 — Target: cluster_k4\n")
cat("==============================================================\n\n")

target_rf1 <- "cluster_k4"

pred_rf1 <- c(
    "PCV2", "PCV3", "PCV5", # materiales de pared, techo, piso
    "agua_mejorada", "saneamiento_mejorado", "electricidad", # servicios básicos
    "n_personas", "n_emigrantes" # tamaño del hogar y migración
)

modelo_rf1 <- entrenar_random_forest(
    data = dt_model,
    target = target_rf1,
    predictors = pred_rf1,
    model_id = "rf1_cluster_k4",
    dir_reports = dir_reports
)

# Escenarios para RF1:
# Se plantean distintos hogares con combinaciones de materiales y servicios.
lista_escenarios_rf1 <- list(
    esc_1_hogar_rural_precario = list(
        PCV2 = levels(modelo_rf1$train$PCV2)[1], # peor material disponible
        PCV3 = levels(modelo_rf1$train$PCV3)[1],
        PCV5 = levels(modelo_rf1$train$PCV5)[1],
        agua_mejorada = 0,
        saneamiento_mejorado = 0,
        electricidad = 0,
        n_personas = 7,
        n_emigrantes = 1
    ),
    esc_2_hogar_urbano_mejores_materiales = list(
        PCV2 = levels(modelo_rf1$train$PCV2)[min(3, length(levels(modelo_rf1$train$PCV2)))],
        PCV3 = levels(modelo_rf1$train$PCV3)[min(3, length(levels(modelo_rf1$train$PCV3)))],
        PCV5 = levels(modelo_rf1$train$PCV5)[min(3, length(levels(modelo_rf1$train$PCV5)))],
        agua_mejorada = 1,
        saneamiento_mejorado = 1,
        electricidad = 1,
        n_personas = 4,
        n_emigrantes = 0
    ),
    esc_3_hogar_grande_con_migracion = list(
        PCV2 = levels(modelo_rf1$train$PCV2)[2],
        PCV3 = levels(modelo_rf1$train$PCV3)[2],
        PCV5 = levels(modelo_rf1$train$PCV5)[2],
        agua_mejorada = 1,
        saneamiento_mejorado = 0,
        electricidad = 1,
        n_personas = 8,
        n_emigrantes = 2
    )
)

generar_predicciones_escenarios(
    modelo_rf = modelo_rf1$modelo,
    train_data = modelo_rf1$train,
    predictors = pred_rf1,
    lista_escenarios = lista_escenarios_rf1,
    model_id = "rf1_cluster_k4",
    dir_reports = dir_reports
)

# ---------------------------------------------------------------
# 4. MODELO RF 2 — Target: indice_calidad_vivienda_cat
# ---------------------------------------------------------------
cat("==============================================================\n")
cat(" MODELO RF 2 — Target: indice_calidad_vivienda_cat\n")
cat("==============================================================\n\n")

target_rf2 <- "indice_calidad_vivienda_cat"

pred_rf2 <- c(
    "agua_mejorada", "saneamiento_mejorado", "electricidad", # servicios básicos
    "PCV2", "PCV3", "PCV5", # materiales
    "AREA", "DEPARTAMENTO" # ubicación
)

modelo_rf2 <- entrenar_random_forest(
    data = dt_model,
    target = target_rf2,
    predictors = pred_rf2,
    model_id = "rf2_indice_calidad_vivienda_cat",
    dir_reports = dir_reports
)

# Escenarios para RF2:
lista_escenarios_rf2 <- list(
    esc_1_vivienda_rural_sin_servicios = list(
        agua_mejorada = 0,
        saneamiento_mejorado = 0,
        electricidad = 0,
        PCV2 = levels(modelo_rf2$train$PCV2)[1],
        PCV3 = levels(modelo_rf2$train$PCV3)[1],
        PCV5 = levels(modelo_rf2$train$PCV5)[1],
        AREA = levels(modelo_rf2$train$AREA)[1], # asumiendo primer nivel como rural
        DEPARTAMENTO = levels(modelo_rf2$train$DEPARTAMENTO)[1]
    ),
    esc_2_vivienda_urbana_con_servicios = list(
        agua_mejorada = 1,
        saneamiento_mejorado = 1,
        electricidad = 1,
        PCV2 = levels(modelo_rf2$train$PCV2)[min(3, length(levels(modelo_rf2$train$PCV2)))],
        PCV3 = levels(modelo_rf2$train$PCV3)[min(3, length(levels(modelo_rf2$train$PCV3)))],
        PCV5 = levels(modelo_rf2$train$PCV5)[min(3, length(levels(modelo_rf2$train$PCV5)))],
        AREA = levels(modelo_rf2$train$AREA)[min(2, length(levels(modelo_rf2$train$AREA)))],
        DEPARTAMENTO = levels(modelo_rf2$train$DEPARTAMENTO)[min(3, length(levels(modelo_rf2$train$DEPARTAMENTO)))]
    ),
    esc_3_vivienda_intermedia = list(
        agua_mejorada = 1,
        saneamiento_mejorado = 0,
        electricidad = 1,
        PCV2 = levels(modelo_rf2$train$PCV2)[2],
        PCV3 = levels(modelo_rf2$train$PCV3)[2],
        PCV5 = levels(modelo_rf2$train$PCV5)[2],
        AREA = levels(modelo_rf2$train$AREA)[1],
        DEPARTAMENTO = levels(modelo_rf2$train$DEPARTAMENTO)[5]
    )
)

generar_predicciones_escenarios(
    modelo_rf = modelo_rf2$modelo,
    train_data = modelo_rf2$train,
    predictors = pred_rf2,
    lista_escenarios = lista_escenarios_rf2,
    model_id = "rf2_indice_calidad_vivienda_cat",
    dir_reports = dir_reports
)

# ---------------------------------------------------------------
# 5. MODELO RF 3 — Target: n_emigrantes_cat
# ---------------------------------------------------------------
cat("==============================================================\n")
cat(" MODELO RF 3 — Target: n_emigrantes_cat\n")
cat("==============================================================\n\n")

target_rf3 <- "n_emigrantes_cat"

pred_rf3 <- c(
    "indice_calidad_vivienda_cat", # calidad de vivienda
    "n_personas", # tamaño del hogar
    "agua_mejorada", "saneamiento_mejorado", "electricidad", # servicios
    "AREA" # área geográfica
)

modelo_rf3 <- entrenar_random_forest(
    data = dt_model,
    target = target_rf3,
    predictors = pred_rf3,
    model_id = "rf3_n_emigrantes_cat",
    dir_reports = dir_reports
)

# Escenarios para RF3:
lista_escenarios_rf3 <- list(
    esc_1_hogar_pequeno_buena_vivienda = list(
        indice_calidad_vivienda_cat = levels(modelo_rf3$train$indice_calidad_vivienda_cat)[4], # alta
        n_personas = 3,
        agua_mejorada = 1,
        saneamiento_mejorado = 1,
        electricidad = 1,
        AREA = levels(modelo_rf3$train$AREA)[min(2, length(levels(modelo_rf3$train$AREA)))]
    ),
    esc_2_hogar_grande_baja_calidad = list(
        indice_calidad_vivienda_cat = levels(modelo_rf3$train$indice_calidad_vivienda_cat)[1], # muy_baja
        n_personas = 8,
        agua_mejorada = 0,
        saneamiento_mejorado = 0,
        electricidad = 0,
        AREA = levels(modelo_rf3$train$AREA)[1]
    ),
    esc_3_hogar_mediano_calidad_media = list(
        indice_calidad_vivienda_cat = levels(modelo_rf3$train$indice_calidad_vivienda_cat)[3], # media
        n_personas = 5,
        agua_mejorada = 1,
        saneamiento_mejorado = 0,
        electricidad = 1,
        AREA = levels(modelo_rf3$train$AREA)[1]
    )
)

generar_predicciones_escenarios(
    modelo_rf = modelo_rf3$modelo,
    train_data = modelo_rf3$train,
    predictors = pred_rf3,
    lista_escenarios = lista_escenarios_rf3,
    model_id = "rf3_n_emigrantes_cat",
    dir_reports = dir_reports
)

# ---------------------------------------------------------------
# 6. Guardado de modelos Random Forest
# ---------------------------------------------------------------
cat("==============================================================\n")
cat(" GUARDANDO MODELOS RANDOM FOREST\n")
cat("==============================================================\n\n")

saveRDS(
    modelo_rf1$modelo,
    file.path(dir_reports, "rf1_cluster_k4_model.rds")
)
saveRDS(
    modelo_rf2$modelo,
    file.path(dir_reports, "rf2_indice_calidad_vivienda_cat_model.rds")
)
saveRDS(
    modelo_rf3$modelo,
    file.path(dir_reports, "rf3_n_emigrantes_cat_model.rds")
)

cat("Modelos guardados en 'reports/random_forest/'.\n")
cat(" - rf1_cluster_k4_model.rds\n")
cat(" - rf2_indice_calidad_vivienda_cat_model.rds\n")
cat(" - rf3_n_emigrantes_cat_model.rds\n\n")

cat("==============================================================\n")
cat(" FASE 8 COMPLETADA — MODELOS RANDOM FOREST LISTOS\n")
cat("==============================================================\n\n")

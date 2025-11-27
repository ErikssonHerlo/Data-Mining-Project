# ===============================================================
# Fase 4 — Patrones frecuentes (FP-Growth vía Eclat)
# ---------------------------------------------------------------
# Este script:
#   1. Carga la base unificada a nivel de hogar.
#   2. Selecciona variables categóricas de vivienda y servicios.
#   3. Convierte la base a transacciones (arules).
#   4. Ejecuta Eclat para extraer itemsets frecuentes.
#   5. Induce reglas de asociación a partir de esos itemsets.
#   6. Exporta itemsets y reglas a /reports/fpgrowth/.
#   7. Genera visualizaciones básicas (si ggplot2 está disponible).
# ===============================================================

suppressPackageStartupMessages({
  library(data.table)
  library(arules)
})

# Carga opcional de ggplot2 para visualizaciones
has_ggplot2 <- requireNamespace("ggplot2", quietly = TRUE)

cat("==============================================================\n")
cat(" FASE 4 - PATRONES FRECUENTES (FP-GROWTH / ECLAT)\n")
cat("==============================================================\n\n")

if (!has_ggplot2) {
  cat("Nota: el paquete 'ggplot2' no está instalado.\n")
  cat("Los patrones y reglas se generarán y exportarán normalmente,\n")
  cat("pero se omitirán las gráficas descriptivas.\n\n")
} else {
  cat("Paquete 'ggplot2' disponible. Se habilitan visualizaciones básicas.\n\n")
}

# ---------------------------------------------------------------
# 1. Definición de rutas
# ---------------------------------------------------------------
dir_output  <- file.path("data", "output")
dir_reports <- file.path("reports", "fpgrowth")

if (!dir.exists(dir_reports)) {
  dir.create(dir_reports, recursive = TRUE)
  cat("Directorio 'reports/fpgrowth' creado.\n")
} else {
  cat("Directorio 'reports/fpgrowth' encontrado.\n")
}

# ---------------------------------------------------------------
# 2. Carga de la base unificada a nivel de hogar
# ---------------------------------------------------------------
cat("\n--- Cargando base hogar_vivienda_migracion ---\n")

ruta_hogar_viv_mig <- file.path(dir_output, "hogar_vivienda_migracion.rds")

if (!file.exists(ruta_hogar_viv_mig)) {
  stop("No se encontró 'hogar_vivienda_migracion.rds' en data/output/. ",
       "Ejecutar primero 02_unificacion.R.")
}

hogar_viv_mig <- readRDS(ruta_hogar_viv_mig)
hogar_viv_mig <- as.data.table(hogar_viv_mig)

cat("Base hogar_vivienda_migracion cargada.\n")
cat("Registros:", nrow(hogar_viv_mig), "\n")
cat("Columnas :", ncol(hogar_viv_mig), "\n")

# ---------------------------------------------------------------
# 3. Selección de variables categóricas para patrones frecuentes
# ---------------------------------------------------------------
cat("\n--- Seleccionando variables categóricas para el análisis ---\n")

vars_candidatas <- c(
  "PCV2",  # material de pared
  "PCV3",  # material de techo
  "PCV5",  # material de piso
  "PCH4",  # acceso a agua
  "PCH5",  # tipo de saneamiento
  "PCH8",  # electricidad
  "AREA"   # área urbana/rural (si está disponible)
)

vars_existentes <- intersect(vars_candidatas, names(hogar_viv_mig))

if (length(vars_existentes) == 0) {
  stop("Ninguna de las variables candidatas existe en hogar_vivienda_migracion. ",
       "Revisar nombres de columnas en el diccionario y adaptar 'vars_candidatas'.")
}

cat("Variables seleccionadas para construir transacciones:\n")
for (v in vars_existentes) cat(" -", v, "\n")

# ---------------------------------------------------------------
# 4. Preparación de datos para transacciones
# ---------------------------------------------------------------
cat("\n--- Preparando datos para construir transacciones ---\n")

sub_hogar <- hogar_viv_mig[, ..vars_existentes]

# Convertir a factor para que arules genere ítems del tipo "VAR=valor"
for (v in vars_existentes) {
  sub_hogar[[v]] <- as.factor(sub_hogar[[v]])
}

# Filtrar hogares con al menos un dato no NA
completos <- rowSums(!is.na(sub_hogar)) > 0
n_total   <- nrow(sub_hogar)
n_usados  <- sum(completos)

cat("Hogares totales en la base           :", n_total, "\n")
cat("Hogares con al menos un dato válido :", n_usados, "\n")

sub_hogar_filtrado <- sub_hogar[completos, ]

# Conversión a objeto 'transactions'
cat("\n--- Convirtiendo a objeto 'transactions' (arules) ---\n")
trans_hogar <- as(sub_hogar_filtrado, "transactions")

cat("Número de transacciones:", length(trans_hogar), "\n")
cat("Número de ítems        :", length(itemLabels(trans_hogar)), "\n")

cat("\nResumen del tamaño de las transacciones (número de ítems por hogar):\n")
print(summary(size(trans_hogar)))

# ---------------------------------------------------------------
# 5. Minería de patrones frecuentes con Eclat
# ---------------------------------------------------------------
cat("\n--- Ejecutando Eclat para obtener itemsets frecuentes ---\n")

min_support  <- 0.01   # 1% de los hogares
max_longitud <- 4      # hasta 4 ítems por patrón

cat("Parámetros de Eclat:\n")
cat(" - Soporte mínimo (supp)   :", min_support, "\n")
cat(" - Longitud máxima (maxlen):", max_longitud, "\n")

itemsets_freq <- eclat(
  trans_hogar,
  parameter = list(supp = min_support, maxlen = max_longitud)
)

cat("\nItemsets frecuentes encontrados:", length(itemsets_freq), "\n")

if (length(itemsets_freq) == 0) {
  cat("No se encontraron itemsets con el soporte mínimo especificado.\n")
  cat("Se recomienda reducir el soporte mínimo y volver a ejecutar.\n")
} else {
  cat("Resumen de soporte de los itemsets frecuentes:\n")
  print(summary(quality(itemsets_freq)$support))
}

# ---------------------------------------------------------------
# 6. Generación de reglas desde los itemsets frecuentes
# ---------------------------------------------------------------
cat("\n--- Derivando reglas de asociación desde los itemsets ---\n")

if (length(itemsets_freq) > 0) {
  min_confidence <- 0.6  # 60% de confianza mínima

  cat("Confianza mínima utilizada para la generación de reglas:",
      min_confidence, "\n")

  reglas_fp <- ruleInduction(
    itemsets_freq,
    confidence   = min_confidence,
    transactions = trans_hogar
  )

  cat("Número de reglas generadas (antes de filtrar por lift):",
      length(reglas_fp), "\n")

  # Filtrar reglas con lift > 1 (asociaciones positivas)
  reglas_fp <- reglas_fp[quality(reglas_fp)$lift > 1]

  cat("Número de reglas con lift > 1:", length(reglas_fp), "\n")

  if (length(reglas_fp) > 0) {
    reglas_fp <- sort(reglas_fp, by = "lift", decreasing = TRUE)

    cat("\nPrimeras 10 reglas (ordenadas por lift):\n")
    inspect(head(reglas_fp, 10))

    # -----------------------------------------------------------
    # 7. Exportación de resultados
    # -----------------------------------------------------------
    cat("\n--- Exportando resultados de FP-Growth/Eclat ---\n")

    # Itemsets frecuentes
    df_itemsets <- as(itemsets_freq, "data.frame")
    data.table::fwrite(
      df_itemsets,
      file.path(dir_reports, "itemsets_frecuentes_fp_growth.csv")
    )

    # Reglas
    df_reglas <- as(reglas_fp, "data.frame")
    data.table::fwrite(
      df_reglas,
      file.path(dir_reports, "reglas_fp_growth_lift_gt_1.csv")
    )

    # Objeto RDS de reglas
    saveRDS(
      reglas_fp,
      file.path(dir_reports, "reglas_fp_growth.rds")
    )

    cat("Itemsets frecuentes exportados a:\n")
    cat(" - reports/fpgrowth/itemsets_frecuentes_fp_growth.csv\n")
    cat("Reglas exportadas a:\n")
    cat(" - reports/fpgrowth/reglas_fp_growth_lift_gt_1.csv\n")
    cat("Objeto RDS de reglas:\n")
    cat(" - reports/fpgrowth/reglas_fp_growth.rds\n")

    # -----------------------------------------------------------
    # 8. Visualizaciones básicas con ggplot2 (opcional)
    # -----------------------------------------------------------
    if (has_ggplot2) {
      cat("\n--- Generando visualizaciones descriptivas (ggplot2) ---\n")

      # Histograma de soporte de itemsets
      p_items_supp <- ggplot2::ggplot(
        df_itemsets,
        ggplot2::aes(x = support)
      ) +
        ggplot2::geom_histogram(bins = 30) +
        ggplot2::labs(
          title = "Distribución del soporte de los itemsets frecuentes",
          x     = "Soporte",
          y     = "Frecuencia"
        )

      ggplot2::ggsave(
        filename = file.path(dir_reports, "hist_soporte_itemsets.png"),
        plot     = p_items_supp,
        width    = 8,
        height   = 5
      )

      # Histograma de soporte de reglas
      p_reg_supp <- ggplot2::ggplot(
        df_reglas,
        ggplot2::aes(x = support)
      ) +
        ggplot2::geom_histogram(bins = 30) +
        ggplot2::labs(
          title = "Distribución del soporte de las reglas (FP-Growth/Eclat)",
          x     = "Soporte",
          y     = "Frecuencia"
        )

      ggplot2::ggsave(
        filename = file.path(dir_reports, "hist_soporte_reglas_fp.png"),
        plot     = p_reg_supp,
        width    = 8,
        height   = 5
      )

      # Scatter soporte vs confianza coloreado por lift
      p_scatter <- ggplot2::ggplot(
        df_reglas,
        ggplot2::aes(x = support, y = confidence, color = lift)
      ) +
        ggplot2::geom_point(alpha = 0.7) +
        ggplot2::labs(
          title = "Soporte vs Confianza de las reglas (FP-Growth/Eclat)",
          x     = "Soporte",
          y     = "Confianza",
          color = "Lift"
        )

      ggplot2::ggsave(
        filename = file.path(dir_reports, "scatter_soporte_confianza_lift_fp.png"),
        plot     = p_scatter,
        width    = 8,
        height   = 5
      )

      cat("Gráficas generadas en 'reports/fpgrowth/':\n")
      cat(" - hist_soporte_itemsets.png\n")
      cat(" - hist_soporte_reglas_fp.png\n")
      cat(" - scatter_soporte_confianza_lift_fp.png\n")
    } else {
      cat("\nVisualizaciones omitidas: ggplot2 no está disponible.\n")
    }
  } else {
    cat("No se obtuvieron reglas con lift > 1.\n")
  }
}

cat("\n==============================================================\n")
cat(" FASE 4 COMPLETADA - PATRONES FRECUENTES (FP-GROWTH/ECLAT)\n")
cat("==============================================================\n\n")

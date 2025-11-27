# ===============================================================
# Fase 3 — Reglas de Asociación (Apriori)
# ---------------------------------------------------------------
# Este script:
#   1. Carga la base unificada a nivel de hogar.
#   2. Selecciona variables categóricas relevantes.
#   3. Convierte la base a formato transaccional (arules).
#   4. Ejecuta Apriori con parámetros definidos.
#   5. Exporta reglas filtradas (lift > 1) a CSV y RDS.
#   6. Genera, si es posible, gráficas descriptivas usando ggplot2.
#   7. Muestra un conjunto de reglas en consola.
# ===============================================================

cat("\n==============================================================\n")
cat(" INICIO DE FASE 3 — Reglas de Asociación (Apriori)\n")
cat("==============================================================\n\n")

# ---------------------------------------------------------------
# 1. Librerías
# ---------------------------------------------------------------
suppressPackageStartupMessages({
  library(data.table)
  library(arules)
})

# Carga opcional de ggplot2 para visualizaciones
has_ggplot2 <- requireNamespace("ggplot2", quietly = TRUE)

if (!has_ggplot2) {
  cat("Nota: el paquete 'ggplot2' no está instalado.\n")
  cat("Las reglas se generarán y exportarán normalmente,\n")
  cat("pero se omitirá la generación de gráficos.\n\n")
} else {
  cat("Paquete 'ggplot2' disponible. Se habilitan visualizaciones básicas.\n\n")
}

# ---------------------------------------------------------------
# 2. Rutas
# ---------------------------------------------------------------
dir_output  <- "data/output"
dir_reports <- "reports/apriori"

if (!dir.exists(dir_reports)) {
  dir.create(dir_reports, recursive = TRUE)
  cat("Directorio 'reports/apriori' creado.\n")
} else {
  cat("Directorio 'reports/apriori' encontrado.\n")
}

# ---------------------------------------------------------------
# 3. Cargar base a nivel hogar
# ---------------------------------------------------------------
cat("\n--- Cargando hogar_vivienda_migracion.rds ---\n")
hogar <- readRDS(file.path(dir_output, "hogar_vivienda_migracion.rds"))
cat("Registros cargados en hogar_vivienda_migracion:", nrow(hogar), "\n")

# ---------------------------------------------------------------
# 4. Selección de variables relevantes
# ---------------------------------------------------------------
cat("\n--- Seleccionando variables relevantes para Apriori ---\n")

vars <- c(
  "PCV2", "PCV3", "PCV5",                 # Materiales de paredes, techo, piso
  "agua_mejorada", "saneamiento_mejorado", "electricidad",
  "indice_calidad_vivienda",             # Índice preliminar calculado en 02_unificacion.R
  "PCH2", "PCH3", "PCH15",                # Características del hogar (tamaño, etc.)
  "AREA",                                 # Área urbana/rural
  "n_emigrantes"                          # Número de emigrantes en el hogar
)

vars <- intersect(vars, names(hogar))

cat("Variables seleccionadas:\n  ", paste(vars, collapse = ", "), "\n")

dt <- hogar[, ..vars]

# ---------------------------------------------------------------
# 5. Transformación de variables numéricas a categorías (bins)
# ---------------------------------------------------------------
cat("\n--- Transformando variables numéricas a categorías ---\n")

# Índice de calidad de vivienda → categorías cualitativas
if ("indice_calidad_vivienda" %in% names(dt)) {
  dt[, calidad_cat := cut(
    indice_calidad_vivienda,
    breaks = c(-Inf, 2, 4, 5, Inf),
    labels = c("muy_baja", "baja", "media", "alta"),
    right = TRUE
  )]
}

# Número de cuartos → categorías
if ("PCH15" %in% names(dt)) {
  dt[, cuartos_cat := cut(
    PCH15,
    breaks = c(-Inf, 2, 4, Inf),
    labels = c("1_2_cuartos", "3_4_cuartos", "5plus"),
    right = TRUE
  )]
}

# Número de emigrantes → categorías
if ("n_emigrantes" %in% names(dt)) {
  dt[, emigrantes_cat := fifelse(
    n_emigrantes == 0, "0_emigrantes",
    fifelse(n_emigrantes == 1, "1_emigrante", "2plus_emigrantes")
  )]
}

# Eliminar columnas numéricas originales después de crear las categorías
cols_num <- intersect(
  c("indice_calidad_vivienda", "PCH15", "n_emigrantes"),
  names(dt)
)
if (length(cols_num) > 0) {
  dt[, (cols_num) := NULL]
}

# Convertir todo a factor
dt <- dt[, lapply(.SD, as.factor)]

cat("Transformación de variables completada. Todas las columnas están en formato categórico.\n")

# ---------------------------------------------------------------
# 6. Convertir a transacciones (arules)
# ---------------------------------------------------------------
cat("\n--- Convirtiendo dataset a formato transaccional ---\n")

trans <- as(dt, "transactions")
cat("Transacciones creadas.\n")
cat("Número de transacciones:", length(trans), "\n")
cat("Número total de ítems:", length(itemLabels(trans)), "\n")

# ---------------------------------------------------------------
# 7. Ejecutar Apriori
# ---------------------------------------------------------------
cat("\n--- Ejecutando algoritmo Apriori ---\n")

reglas <- apriori(
  trans,
  parameter = list(
    supp   = 0.02,  # Soporte mínimo
    conf   = 0.5,   # Confianza mínima
    minlen = 2      # Longitud mínima de la regla
  )
)

cat("Total de reglas generadas:", length(reglas), "\n")

# Filtro por lift > 1 (reglas con asociación positiva)
reglas_interes <- reglas[quality(reglas)$lift > 1]
cat("Reglas con lift > 1:", length(reglas_interes), "\n")

# ---------------------------------------------------------------
# 8. Exportar resultados a CSV y RDS
# ---------------------------------------------------------------
cat("\n--- Exportando reglas a 'reports/apriori/' ---\n")

if (length(reglas_interes) > 0) {
  df_reglas <- as(reglas_interes, "data.frame")

  # Exportar tabla de reglas
  data.table::fwrite(
    df_reglas,
    file.path(dir_reports, "reglas_apriori_lift_mayor_1.csv")
  )

  saveRDS(
    reglas_interes,
    file.path(dir_reports, "reglas_apriori_lift_mayor_1.rds")
  )

  cat("Archivo CSV generado: reports/apriori/reglas_apriori_lift_mayor_1.csv\n")
  cat("Objeto RDS generado: reports/apriori/reglas_apriori_lift_mayor_1.rds\n")
} else {
  cat("No se encontraron reglas con lift > 1. No se generaron archivos CSV/RDS.\n")
}

# ---------------------------------------------------------------
# 9. Visualizaciones básicas con ggplot2 (opcional)
# ---------------------------------------------------------------
if (has_ggplot2 && exists("df_reglas") && nrow(df_reglas) > 0) {
  cat("\n--- Generando visualizaciones descriptivas de las reglas ---\n")

  # Histograma de soporte
  p_supp <- ggplot2::ggplot(df_reglas, ggplot2::aes(x = support)) +
    ggplot2::geom_histogram(bins = 30) +
    ggplot2::labs(
      title = "Distribución del soporte de las reglas",
      x = "Soporte",
      y = "Frecuencia"
    )

  ggplot2::ggsave(
    filename = file.path(dir_reports, "hist_soporte_reglas.png"),
    plot     = p_supp,
    width    = 8,
    height   = 5
  )

  # Histograma de confianza
  p_conf <- ggplot2::ggplot(df_reglas, ggplot2::aes(x = confidence)) +
    ggplot2::geom_histogram(bins = 30) +
    ggplot2::labs(
      title = "Distribución de la confianza de las reglas",
      x = "Confianza",
      y = "Frecuencia"
    )

  ggplot2::ggsave(
    filename = file.path(dir_reports, "hist_confianza_reglas.png"),
    plot     = p_conf,
    width    = 8,
    height   = 5
  )

  # Diagrama de dispersión soporte vs confianza coloreado por lift
  p_scatter <- ggplot2::ggplot(
    df_reglas,
    ggplot2::aes(x = support, y = confidence, color = lift)
  ) +
    ggplot2::geom_point(alpha = 0.7) +
    ggplot2::labs(
      title = "Soporte vs Confianza de las reglas",
      x = "Soporte",
      y = "Confianza",
      color = "Lift"
    )

  ggplot2::ggsave(
    filename = file.path(dir_reports, "scatter_soporte_confianza_lift.png"),
    plot     = p_scatter,
    width    = 8,
    height   = 5
  )

  cat("Gráficas generadas en 'reports/apriori/':\n")
  cat(" - hist_soporte_reglas.png\n")
  cat(" - hist_confianza_reglas.png\n")
  cat(" - scatter_soporte_confianza_lift.png\n")
} else {
  cat("\n--- Visualizaciones omitidas: no hay reglas o ggplot2 no está disponible ---\n")
}

# ---------------------------------------------------------------
# 10. Mostrar reglas principales en consola
# ---------------------------------------------------------------
cat("\n--- Ejemplo de reglas encontradas (primeras 10) ---\n")

if (length(reglas_interes) > 0) {
  inspect(head(reglas_interes, 10))
} else {
  cat("No hay reglas con lift > 1 para mostrar.\n")
}

cat("\n==============================================================\n")
cat(" FASE 3 COMPLETADA — Reglas Apriori generadas.\n")
cat("==============================================================\n\n")

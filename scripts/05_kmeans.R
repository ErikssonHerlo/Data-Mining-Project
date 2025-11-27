# ===============================================================
# Fase 5 — Análisis de clusters de hogares con k-means
# ---------------------------------------------------------------
# Este script:
#   1. Carga las bases hogar_vivienda_migracion y base_persona_maestra.
#   2. Calcula el número de personas por hogar.
#   3. Une esta información a la base de hogares.
#   4. Selecciona variables numéricas clave para clustering.
#   5. Escala las variables y ejecuta k-means (k = 4).
#   6. Genera un resumen descriptivo por cluster.
#   7. Exporta tablas y el modelo a /reports/clustering/.
# ===============================================================

suppressPackageStartupMessages({
  library(data.table)
})

# Carga opcional de ggplot2 para visualizaciones
has_ggplot2 <- requireNamespace("ggplot2", quietly = TRUE)

cat("==============================================================\n")
cat(" FASE 5 - CLUSTERING DE HOGARES (K-MEANS)\n")
cat("==============================================================\n\n")

if (!has_ggplot2) {
  cat("Nota: el paquete 'ggplot2' no está instalado.\n")
  cat("El clustering se ejecutará normalmente, pero se omitirán gráficas.\n\n")
} else {
  cat("Paquete 'ggplot2' disponible. Se habilitan visualizaciones básicas.\n\n")
}

# ---------------------------------------------------------------
# 1. Definición de rutas
# ---------------------------------------------------------------
dir_output  <- file.path("data", "output")
dir_reports <- file.path("reports", "clustering")

if (!dir.exists(dir_reports)) {
  dir.create(dir_reports, recursive = TRUE)
  cat("Directorio 'reports/clustering' creado.\n")
} else {
  cat("Directorio 'reports/clustering' encontrado.\n")
}

# ---------------------------------------------------------------
# 2. Carga de bases necesarias
# ---------------------------------------------------------------
cat("\n--- Cargando bases de salida unificada ---\n")

ruta_hogar_viv_mig    <- file.path(dir_output, "hogar_vivienda_migracion.rds")
ruta_persona_maestra  <- file.path(dir_output, "base_persona_maestra.rds")

if (!file.exists(ruta_hogar_viv_mig)) {
  stop("No se encontró 'hogar_vivienda_migracion.rds' en data/output/. ",
       "Ejecutar primero 02_unificacion.R.")
}

if (!file.exists(ruta_persona_maestra)) {
  stop("No se encontró 'base_persona_maestra.rds' en data/output/. ",
       "Ejecutar primero 02_unificacion.R.")
}

hogar_viv_mig   <- as.data.table(readRDS(ruta_hogar_viv_mig))
persona_maestra <- as.data.table(readRDS(ruta_persona_maestra))

cat("Base hogar_vivienda_migracion cargada. Registros:", nrow(hogar_viv_mig), "\n")
cat("Base base_persona_maestra cargada. Registros   :", nrow(persona_maestra), "\n")

# ---------------------------------------------------------------
# 3. Construcción del conteo de personas por hogar
# ---------------------------------------------------------------
cat("\n--- Calculando número de personas por hogar ---\n")

llave_hogar <- c(
  "DEPARTAMENTO", "MUNICIPIO", "COD_MUNICIPIO",
  "AREA", "NUM_VIVIENDA", "NUM_HOGAR"
)

llave_hogar <- intersect(llave_hogar, names(persona_maestra))

if (length(llave_hogar) == 0) {
  stop("No se encontraron columnas para construir la llave de hogar en base_persona_maestra. ",
       "Revisar nombres de columnas y adaptar 'llave_hogar'.")
}

cat("Llave utilizada para agrupar personas por hogar:\n")
for (v in llave_hogar) cat(" -", v, "\n")

personas_por_hogar <- persona_maestra[, .(
  n_personas = .N
), by = llave_hogar]

cat("Tabla personas_por_hogar construida. Registros:", nrow(personas_por_hogar), "\n")

# ---------------------------------------------------------------
# 4. Unión con hogar_vivienda_migracion
# ---------------------------------------------------------------
cat("\n--- Uniendo personas_por_hogar con hogar_vivienda_migracion ---\n")

llave_hogar_hvm <- intersect(llave_hogar, names(hogar_viv_mig))

if (!all(llave_hogar %in% names(personas_por_hogar))) {
  stop("La llave definida no está completamente presente en personas_por_hogar.")
}
if (!all(llave_hogar_hvm %in% names(hogar_viv_mig))) {
  stop("La llave definida no está completamente presente en hogar_vivienda_migracion.")
}

setkeyv(personas_por_hogar, llave_hogar)
setkeyv(hogar_viv_mig,       llave_hogar_hvm)

hogar_cluster <- hogar_viv_mig[personas_por_hogar]

cat("Registros en hogar_vivienda_migracion:", nrow(hogar_viv_mig), "\n")
cat("Registros en hogar_cluster (unión)   :", nrow(hogar_cluster), "\n")

# ---------------------------------------------------------------
# 5. Selección de variables numéricas para clustering
# ---------------------------------------------------------------
cat("\n--- Seleccionando variables numéricas para k-means ---\n")

# Importante: usar el nombre correcto del índice creado en 02_unificacion.R
vars_cluster_candidatas <- c(
  "indice_calidad_vivienda",   # Índice preliminar de calidad de vivienda
  "n_personas",                # Número de personas en el hogar
  "n_emigrantes",              # Número de emigrantes asociados al hogar
  "edad_promedio_emigrantes"   # Edad promedio de emigrantes
)

vars_cluster <- intersect(vars_cluster_candidatas, names(hogar_cluster))

if (length(vars_cluster) < 2) {
  stop("Se requieren al menos 2 variables numéricas para clustering. ",
       "Variables encontradas: ", paste(vars_cluster, collapse = ", "))
}

cat("Variables seleccionadas para clustering:\n")
for (v in vars_cluster) cat(" -", v, "\n")

# ---------------------------------------------------------------
# 6. Filtrado de hogares con datos completos
# ---------------------------------------------------------------
cat("\n--- Filtrando hogares con datos completos en variables de clustering ---\n")

completos <- complete.cases(hogar_cluster[, ..vars_cluster])

n_total     <- nrow(hogar_cluster)
n_completos <- sum(completos)

cat("Hogares totales:", n_total, "\n")
cat("Hogares con datos completos en todas las variables de clustering:",
    n_completos, "\n")

if (n_completos < 1000) {
  cat("Advertencia: el número de hogares con datos completos es relativamente bajo.\n")
}

datos_cluster <- hogar_cluster[completos, ..vars_cluster]

# ---------------------------------------------------------------
# 7. Escalamiento de variables
# ---------------------------------------------------------------
cat("\n--- Escalando variables para k-means (media 0, varianza 1) ---\n")

datos_cluster_scaled <- scale(datos_cluster)

cat("Dimensión de la matriz escalada:",
    paste(dim(datos_cluster_scaled), collapse = " x "), "\n")

# ---------------------------------------------------------------
# 8. Ejecución de k-means
# ---------------------------------------------------------------
cat("\n--- Ejecutando k-means ---\n")

set.seed(12345)  # Para reproducibilidad

k_clusters <- 4  # Número de clusters (ajustable)

cat("Número de clusters (k) seleccionado:", k_clusters, "\n")

modelo_kmeans <- kmeans(
  x        = datos_cluster_scaled,
  centers  = k_clusters,
  nstart   = 25,
  iter.max = 100
)

cat("\nResultados básicos de k-means:\n")
cat("Iteraciones realizadas:",
    modelo_kmeans$iter, "\n")
cat("Suma total de cuadrados dentro de los clusters (tot.withinss):",
    modelo_kmeans$tot.withinss, "\n")

cat("\nTamaño de cada cluster (número de hogares):\n")
print(modelo_kmeans$size)

# ---------------------------------------------------------------
# 9. Incorporación de etiquetas de cluster a la tabla de hogares
# ---------------------------------------------------------------
cat("\n--- Asignando etiquetas de cluster a los hogares ---\n")

hogar_cluster[, cluster_k4 := NA_integer_]
hogar_cluster[completos, cluster_k4 := modelo_kmeans$cluster]

cat("Hogares con cluster asignado:",
    sum(!is.na(hogar_cluster$cluster_k4)), "\n")

# ---------------------------------------------------------------
# 10. Resumen descriptivo por cluster
# ---------------------------------------------------------------
cat("\n--- Resumen descriptivo por cluster ---\n")

resumen_clusters <- hogar_cluster[!is.na(cluster_k4), .(
  n_hogares                = .N,
  media_indice_calidad_viv = mean(indice_calidad_vivienda, na.rm = TRUE),
  media_n_personas         = mean(n_personas, na.rm = TRUE),
  media_n_emigrantes       = mean(n_emigrantes, na.rm = TRUE),
  media_edad_prom_emigr    = mean(edad_prom_emigrantes, na.rm = TRUE)
), by = cluster_k4][order(cluster_k4)]

print(resumen_clusters)

cat("\nNota:\n")
cat("- Los clusters con índice de calidad de vivienda más bajo y mayor número de personas\n")
cat("  pueden asociarse a condiciones de mayor hacinamiento y vulnerabilidad.\n")
cat("- Por su parte, los clusters con mayor presencia de emigrantes pueden estar vinculados a hogares\n")
cat("  que utilizan la migración como estrategia frente a condiciones económicas adversas.\n\n")

# ---------------------------------------------------------------
# 11. Visualizaciones básicas (opcional)
# ---------------------------------------------------------------
if (has_ggplot2) {
  cat("--- Generando visualizaciones básicas de los clusters ---\n")

  # Proyección simple usando las dos primeras variables para un scatter
  var_x <- vars_cluster[1]
  var_y <- vars_cluster[min(2, length(vars_cluster))]

  df_plot <- data.table(
    x        = datos_cluster[[var_x]],
    y        = datos_cluster[[var_y]],
    cluster  = factor(modelo_kmeans$cluster)
  )

  p_clusters <- ggplot2::ggplot(
    df_plot,
    ggplot2::aes(x = x, y = y, color = cluster)
  ) +
    ggplot2::geom_point(alpha = 0.5) +
    ggplot2::labs(
      title = paste0("Clusters de hogares (k = ", k_clusters, ")"),
      x     = var_x,
      y     = var_y,
      color = "Cluster"
    )

  ggplot2::ggsave(
    filename = file.path(dir_reports, "scatter_clusters_k4.png"),
    plot     = p_clusters,
    width    = 8,
    height   = 5
  )

  cat("Gráfica generada en:\n")
  cat(" - reports/clustering/scatter_clusters_k4.png\n")
} else {
  cat("--- Visualizaciones omitidas: ggplot2 no está disponible ---\n")
}

# ---------------------------------------------------------------
# 12. Exportación de resultados
# ---------------------------------------------------------------
cat("\n--- Exportando resultados de clustering ---\n")

data.table::fwrite(
  resumen_clusters,
  file.path(dir_reports, "resumen_clusters_k4.csv")
)

data.table::fwrite(
  hogar_cluster,
  file.path(dir_reports, "hogar_vivienda_migracion_clusters_k4.csv")
)

saveRDS(
  modelo_kmeans,
  file.path(dir_reports, "modelo_kmeans_k4.rds")
)

cat("Archivos generados:\n")
cat(" - reports/clustering/resumen_clusters_k4.csv\n")
cat(" - reports/clustering/hogar_vivienda_migracion_clusters_k4.csv\n")
cat(" - reports/clustering/modelo_kmeans_k4.rds\n")

cat("\n==============================================================\n")
cat(" FASE 5 COMPLETADA - CLUSTERING DE HOGARES (K-MEANS)\n")
cat("==============================================================\n\n")

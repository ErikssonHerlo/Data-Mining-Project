# ===============================================================
# FASE 6 — Preparación del Dataset para Modelos Predictivos
# ---------------------------------------------------------------
# Este script:
#   1. Carga las bases unificadas de hogar y persona.
#   2. Integra el cluster_k4 proveniente de la FASE 5 (k-means).
#   3. Genera variables objetivo (targets) basadas en hallazgos previos:
#        - indice_calidad_vivienda_cat
#        - n_emigrantes_cat
#        - agua_mejorada (0/1)
#        - cluster_k4
#   4. Crea y codifica variables predictoras relevantes.
#   5. Unifica, limpia y exporta:
#        - data/output/modeling_dataset.rds
#        - data/output/modeling_dataset.csv
# ===============================================================

cat("\n==============================================================\n")
cat(" FASE 6 — PREPARACIÓN DEL DATASET DE MODELADO\n")
cat("==============================================================\n\n")

suppressPackageStartupMessages({
  library(data.table)
  library(forcats)
})

# ---------------------------------------------------------------
# 1. Definición de rutas
# ---------------------------------------------------------------
cat("--- Definiendo rutas de entrada y salida ---\n")

dir_output    <- "data/output"
dir_clustering <- file.path("reports", "clustering")

ruta_hogar   <- file.path(dir_output, "hogar_vivienda_migracion.rds")
ruta_persona <- file.path(dir_output, "base_persona_maestra.rds")

if (!file.exists(ruta_hogar))   stop("No se encontró hogar_vivienda_migracion.rds en data/output/")
if (!file.exists(ruta_persona)) stop("No se encontró base_persona_maestra.rds en data/output/")

cat("Rutas verificadas correctamente.\n")

# ---------------------------------------------------------------
# 2. Cargar bases
# ---------------------------------------------------------------
cat("\n--- Cargando bases unificadas ---\n")

hogar   <- as.data.table(readRDS(ruta_hogar))
persona <- as.data.table(readRDS(ruta_persona))

cat("Registros cargados:\n")
cat(" - Hogar/Vivienda/Migración:", nrow(hogar), "\n")
cat(" - Persona Maestra:          ", nrow(persona), "\n")

# ---------------------------------------------------------------
# 3. Construcción de número de personas por hogar
# ---------------------------------------------------------------
cat("\n--- Calculando número de personas por hogar ---\n")

llave_hogar <- intersect(
  c("DEPARTAMENTO","MUNICIPIO","COD_MUNICIPIO",
    "AREA","NUM_VIVIENDA","NUM_HOGAR"),
  names(persona)
)

if (length(llave_hogar) == 0) {
  stop("No se pudo construir la llave de hogar en base_persona_maestra. ",
       "Revisar nombres de columnas.")
}

personas_por_hogar <- persona[, .(
  n_personas = .N
), by = llave_hogar]

cat("Tabla personas_por_hogar creada.\n")
cat("Registros:", nrow(personas_por_hogar), "\n")

# ---------------------------------------------------------------
# 4. Unir conteo de personas al dataset de hogar
# ---------------------------------------------------------------
cat("\n--- Uniendo número de personas al dataset de hogar ---\n")

setkeyv(hogar,           llave_hogar)
setkeyv(personas_por_hogar, llave_hogar)

hogar_full <- hogar[personas_por_hogar]

cat("Unión completada. Registros en hogar_full:", nrow(hogar_full), "\n")

# ---------------------------------------------------------------
# 5. Integrar cluster_k4 desde resultados de clustering
# ---------------------------------------------------------------
cat("\n--- Verificando disponibilidad de 'cluster_k4' ---\n")

if (!"cluster_k4" %in% names(hogar_full)) {
  cat("La columna 'cluster_k4' no está presente en hogar_vivienda_migracion.rds.\n")
  cat("Se intentará cargar desde 'reports/clustering/hogar_vivienda_migracion_clusters_k4.csv'.\n")

  ruta_cluster_csv <- file.path(dir_clustering, "hogar_vivienda_migracion_clusters_k4.csv")

  if (!file.exists(ruta_cluster_csv)) {
    stop(
      "No se encontró 'cluster_k4' ni en la base de hogar ni en el CSV de clustering.\n",
      "Verificar que se haya ejecutado correctamente 05_kmeans.R y que exista:\n",
      ruta_cluster_csv
    )
  }

  cat("Cargando CSV de clustering con etiquetas de cluster_k4...\n")
  cluster_dt <- fread(ruta_cluster_csv)

  # Verificar que existan las columnas de llave y cluster_k4
  cols_necesarias <- c(llave_hogar, "cluster_k4")
  faltantes <- setdiff(cols_necesarias, names(cluster_dt))
  if (length(faltantes) > 0) {
    stop("El archivo de clustering no contiene las columnas necesarias: ",
         paste(faltantes, collapse = ", "))
  }

  # Nos quedamos solo con llave + cluster_k4
  cluster_dt <- cluster_dt[, ..cols_necesarias]

  cat("Registros en tabla de clustering:", nrow(cluster_dt), "\n")

  # Unir cluster_k4 a hogar_full
  cat("Uniendo 'cluster_k4' a hogar_full mediante la llave de hogar...\n")
  setkeyv(cluster_dt, llave_hogar)
  setkeyv(hogar_full, llave_hogar)

  # Usamos merge para mantener todas las filas de hogar_full
  hogar_full <- merge(
    x     = hogar_full,
    y     = cluster_dt,
    by    = llave_hogar,
    all.x = TRUE,
    sort  = FALSE
  )

  cat("Unión completada. Registros en hogar_full:", nrow(hogar_full), "\n")
} else {
  cat("'cluster_k4' ya está presente en hogar_vivienda_migracion.rds.\n")
}

# Verificación final
if (!"cluster_k4" %in% names(hogar_full)) {
  stop("Después de la integración, 'cluster_k4' sigue sin estar disponible. Revisar FASE 5.")
}

cat("La variable 'cluster_k4' está disponible para el modelado.\n")

# ---------------------------------------------------------------
# 6. Crear variables objetivo (targets)
# ---------------------------------------------------------------
cat("\n--- Creando variables objetivo para los modelos ---\n")

## 6.1 Calidad de vivienda categórica
hogar_full[, indice_calidad_vivienda_cat :=
             cut(indice_calidad_vivienda,
                 breaks = c(-Inf, 2, 4, 5, Inf),
                 labels = c("muy_baja", "baja", "media", "alta"))]

## 6.2 Migración categórica
hogar_full[, n_emigrantes_cat :=
             fifelse(n_emigrantes == 0, "0",
             fifelse(n_emigrantes == 1, "1", "2plus"))]

## 6.3 Acceso a agua mejorada (0/1)
if ("agua_mejorada" %in% names(hogar_full)) {
  hogar_full[, agua_mejorada := factor(agua_mejorada, levels = c(0,1))]
}

## 6.4 Cluster de K-means
hogar_full[, cluster_k4 := factor(cluster_k4)]

cat("Variables objetivo creadas correctamente.\n")

# ---------------------------------------------------------------
# 7. Crear variables predictoras
# ---------------------------------------------------------------
cat("\n--- Generando variables predictoras ---\n")

# Materiales de vivienda
for (v in c("PCV2","PCV3","PCV5")) {
  if (v %in% names(hogar_full)) hogar_full[[v]] <- as.factor(hogar_full[[v]])
}

# Servicios básicos
for (v in c("agua_mejorada","saneamiento_mejorado","electricidad")) {
  if (v %in% names(hogar_full)) hogar_full[[v]] <- as.factor(hogar_full[[v]])
}

# Área urbana/rural
if ("AREA" %in% names(hogar_full)) hogar_full[, AREA := as.factor(AREA)]

# Departamento
if ("DEPARTAMENTO" %in% names(hogar_full)) hogar_full[, DEPARTAMENTO := as.factor(DEPARTAMENTO)]

cat("Variables predictoras creadas.\n")

# ---------------------------------------------------------------
# 8. Selección final de variables para modelado
# ---------------------------------------------------------------
cat("\n--- Seleccionando variables finales para modelado ---\n")

vars_target <- c(
  "indice_calidad_vivienda_cat",
  "n_emigrantes_cat",
  "agua_mejorada",
  "cluster_k4"
)

vars_pred <- c(
  "PCV2","PCV3","PCV5",
  "agua_mejorada","saneamiento_mejorado","electricidad",
  "AREA","DEPARTAMENTO",
  "n_personas","n_emigrantes","edad_prom_emigrantes",
  "indice_calidad_vivienda"
)

vars_final <- intersect(c(vars_target, vars_pred), names(hogar_full))

modeling_dataset <- hogar_full[, ..vars_final]

cat("Variables finales incluidas:", length(vars_final), "\n")

# ---------------------------------------------------------------
# 9. Limpieza final (eliminar NAs)
# ---------------------------------------------------------------
cat("\n--- Eliminando registros con NA en variables clave ---\n")

antes   <- nrow(modeling_dataset)
modeling_dataset <- na.omit(modeling_dataset)
despues <- nrow(modeling_dataset)

cat("Registros antes :", antes, "\n")
cat("Registros después:", despues, "\n")
cat("Registros eliminados:", antes - despues, "\n")

# ---------------------------------------------------------------
# 10. Guardado de dataset final
# ---------------------------------------------------------------
cat("\n--- Guardando modeling_dataset ---\n")

saveRDS(
  modeling_dataset,
  file.path(dir_output, "modeling_dataset.rds")
)

fwrite(
  modeling_dataset,
  file.path(dir_output, "modeling_dataset.csv")
)

cat("Dataset final guardado correctamente en data/output/.\n")

cat("\n==============================================================\n")
cat(" FASE 6 COMPLETADA — Dataset listo para Árboles, RF y Redes\n")
cat("==============================================================\n\n")

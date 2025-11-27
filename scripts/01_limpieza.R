# ===============================================================
# Fase 1 - Carga y limpieza de las bases del Censo 2018
# ---------------------------------------------------------------
# Este script realiza:
#   1. Carga eficiente de los cuatro archivos del Censo.
#   2. Conversión de tipos de datos según diccionario.
#   3. Reemplazo de códigos especiales por NA.
#   4. Limpieza y preparación de variables relevantes.
#   5. Exportación de las bases limpias en formato RDS.
# ===============================================================

# ---------------------------------------------------------------
# 1. Carga de librerías necesarias
# ---------------------------------------------------------------
library(data.table)
library(stringr)

cat("\n==============================================================\n")
cat(" INICIO DEL PROCESO DE LIMPIEZA - CENSO 2018\n")
cat("==============================================================\n\n")

# ---------------------------------------------------------------
# 2. Definir rutas
# ---------------------------------------------------------------
dir_data  <- "data/raw"
dir_clean <- file.path("data", "clean")

if (!dir.exists(dir_clean)) {
  dir.create(dir_clean, recursive = TRUE)
  cat("Directorio 'data/clean' creado correctamente.\n")
} else {
  cat("Directorio 'data/clean' encontrado.\n")
}

# ---------------------------------------------------------------
# 3. Funciones auxiliares
# ---------------------------------------------------------------
# Reemplaza códigos utilizados en diccionario como 'No declarado'
recode_na <- function(x, na_values) {
  x[x %in% na_values] <- NA
  return(x)
}

# Códigos geográficos con finalización '99' indican ausencia de dato
recode_geo_na <- function(x) {
  x[ x %% 100 == 99 ] <- NA
  return(x)
}

cat("\nFunciones auxiliares cargadas.\n")

# ---------------------------------------------------------------
# 4. Carga de los archivos principales
# ---------------------------------------------------------------
cat("\n--- Cargando archivos CSV del Censo ---\n")

persona   <- fread(file.path(dir_data, "PERSONA_BDP.csv"))
cat("PERSONA_BDP.csv cargado. Cantidad de Registros:", nrow(persona), "\n")

hogar     <- fread(file.path(dir_data, "HOGAR_BDP.csv"))
cat("HOGAR_BDP.csv cargado. Cantidad de Registros:", nrow(hogar), "\n")

vivienda  <- fread(file.path(dir_data, "VIVIENDA_BDP.csv"))
cat("VIVIENDA_BDP.csv cargado. Cantidad de Registros:", nrow(vivienda), "\n")

migracion <- fread(file.path(dir_data, "MIGRACION_BDP.csv"))
cat("MIGRACION_BDP.csv cargado. Cantidad de Registros:", nrow(migracion), "\n")

cat("\nArchivos cargados correctamente.\n")

# ---------------------------------------------------------------
# 5. Limpieza de la base VIVIENDA
# ---------------------------------------------------------------
cat("\n--- Procesando VIVIENDA_BDP.csv ---\n")

cols_viv <- c("PCV1","PCV2","PCV3","PCV4","PCV5")
cols_viv <- intersect(cols_viv, names(vivienda))

vivienda[, (cols_viv) := lapply(.SD, as.integer), .SDcols = cols_viv]
cat("Variables principales de vivienda convertidas a numéricas.\n")

vivienda[, PCV2 := recode_na(PCV2, c(99))]
vivienda[, PCV3 := recode_na(PCV3, c(9))]
cat("Códigos 'No declarado' en PCV2 y PCV3 reemplazados por NA.\n")

# ---------------------------------------------------------------
# 6. Limpieza de la base HOGAR
# ---------------------------------------------------------------
cat("\n--- Procesando HOGAR_BDP.csv ---\n")

cols_hogar <- grep("^PCH", names(hogar), value = TRUE)
cols_hogar <- intersect(cols_hogar, names(hogar))
hogar[, (cols_hogar) := lapply(.SD, as.integer), .SDcols = cols_hogar]

cat("Variables PCH convertidas a tipo numérico.\n")

hogar[, PCH2 := recode_na(PCH2, c(9))]
hogar[, PCH3 := recode_na(PCH3, c(9))]
hogar[, PCH15 := recode_na(PCH15, c(9))]
cat("Códigos 'No declarado' en PCH2, PCH3 y PCH15 reemplazados por NA.\n")

# ---------------------------------------------------------------
# 7. Limpieza de la base PERSONA
# ---------------------------------------------------------------
cat("\n--- Procesando PERSONA_BDP.csv ---\n")

cols_persona <- c("PCP5","PCP7","PCP12","PCP17_A","ANEDUCA","PCP22")
cols_persona <- intersect(cols_persona, names(persona))

persona[, (cols_persona) := lapply(.SD, as.integer), .SDcols = cols_persona]
cat("Variables principales de persona convertidas a numéricas.\n")

persona[, PCP9    := recode_na(PCP9, c(9))]
persona[, PCP21   := recode_na(PCP21, c(99))]
persona[, ANEDUCA := recode_na(ANEDUCA, c(99))]
cat("Códigos 'No declarado' en variables clave reemplazados por NA.\n")

geo_vars <- c("LUGNACGEO","RESCINGEO","ESTUDIAGEO","TRABAJAGEO","VIVEHABGEO")
geo_vars <- intersect(geo_vars, names(persona))
persona[, (geo_vars) := lapply(.SD, recode_geo_na), .SDcols = geo_vars]

cat("Variables geográficas corregidas con NA para códigos finalizados en 99.\n")

# ---------------------------------------------------------------
# 8. Limpieza de la base MIGRACION
# ---------------------------------------------------------------
cat("\n--- Procesando MIGRACION_BDP.csv ---\n")

cols_mig <- c("PEI3","PEI4","PEI5")
cols_mig <- intersect(cols_mig, names(migracion))
migracion[, (cols_mig) := lapply(.SD, as.integer), .SDcols = cols_mig]
cat("Variables PEI convertidas a tipo numérico.\n")

migracion[, PEI4 := recode_na(PEI4, c(999))]
migracion[, PEI5 := recode_na(PEI5, c(9999))]
cat("Códigos 'No declarado' en variables de migración reemplazados por NA.\n")

# ---------------------------------------------------------------
# 9. Guardado de resultados
# ---------------------------------------------------------------

cat("\n--- Guardando bases limpias ---\n\n")

cat("Guardando persona_clean.rds...\n")
saveRDS(persona,   file.path(dir_clean, "persona_clean.rds"))

cat("Guardando hogar_clean.rds...\n")
saveRDS(hogar,     file.path(dir_clean, "hogar_clean.rds"))

cat("Guardando vivienda_clean.rds...\n")
saveRDS(vivienda,  file.path(dir_clean, "vivienda_clean.rds"))

cat("Guardando migracion_clean.rds...\n")
saveRDS(migracion, file.path(dir_clean, "migracion_clean.rds"))

cat("Bases limpias guardadas en 'data/clean/'.\n")

cat("\n==============================================================\n")
cat(" PROCESO DE LIMPIEZA COMPLETADO EXITOSAMENTE\n")
cat("==============================================================\n\n")

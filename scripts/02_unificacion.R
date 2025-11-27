# ===============================================================
# Fase 2 - Unión de bases y construcción de índice de calidad
# ---------------------------------------------------------------
# Este script realiza:
#   1. Carga de las bases limpias PERSONA, HOGAR, VIVIENDA y MIGRACION.
#   2. Definición de la llave de unión a nivel de vivienda y hogar.
#   3. Unión de HOGAR + VIVIENDA.
#   4. Construcción de un índice preliminar de calidad de vivienda.
#   5. Agregación de la base de MIGRACION a nivel de hogar.
#   6. Unión del resumen de migración con la base hogar–vivienda.
#   7. Unión final con PERSONA para obtener una base maestra.
#   8. Exportación de las bases resultantes en formato RDS y CSV.
# ===============================================================

# ---------------------------------------------------------------
# 1. Carga de librerías necesarias
# ---------------------------------------------------------------
library(data.table)

cat("\n==============================================================\n")
cat("       INICIO DEL PROCESO DE UNIFICACIÓN - CENSO 2018\n")
cat("==============================================================\n\n")

# ---------------------------------------------------------------
# 2. Definir rutas de trabajo
# ---------------------------------------------------------------
dir_data <- "data"
dir_clean <- file.path(dir_data, "clean")
dir_output <- file.path(dir_data, "output")

if (!dir.exists(dir_output)) {
    dir.create(dir_output, recursive = TRUE)
    cat("Directorio 'data/output' creado correctamente.\n")
} else {
    cat("Directorio 'data/output' encontrado.\n")
}

# ---------------------------------------------------------------
# 3. Carga de bases limpias
# ---------------------------------------------------------------
cat("\n--- Cargando bases limpias desde 'data/clean/' ---\n")

persona <- readRDS(file.path(dir_clean, "persona_clean.rds"))
cat("Base PERSONA cargada. Registros:", nrow(persona), "\n")

hogar <- readRDS(file.path(dir_clean, "hogar_clean.rds"))
cat("Base HOGAR cargada. Registros:", nrow(hogar), "\n")

vivienda <- readRDS(file.path(dir_clean, "vivienda_clean.rds"))
cat("Base VIVIENDA cargada. Registros:", nrow(vivienda), "\n")

migracion <- readRDS(file.path(dir_clean, "migracion_clean.rds"))
cat("Base MIGRACION cargada. Registros:", nrow(migracion), "\n")

cat("\nBases limpias cargadas correctamente.\n")

# ---------------------------------------------------------------
# 4. Definición de llaves de unión
# ---------------------------------------------------------------
cat("\n--- Definiendo llaves de unión a nivel de vivienda y hogar ---\n")

# Llave de vivienda (común a HOGAR y VIVIENDA)
key_vivienda <- c(
    "DEPARTAMENTO", "MUNICIPIO", "COD_MUNICIPIO",
    "ZONA", "AREA", "NUM_VIVIENDA"
)

# Llave de hogar (común a PERSONA, HOGAR y MIGRACION)
key_hogar <- c(key_vivienda, "NUM_HOGAR")

cat("Llave a nivel de vivienda: ", paste(key_vivienda, collapse = " + "), "\n")
cat("Llave a nivel de hogar:    ", paste(key_hogar, collapse = " + "), "\n")

# ---------------------------------------------------------------
# 5. Unión de HOGAR + VIVIENDA
# ---------------------------------------------------------------
cat("\n--- Uniendo bases HOGAR y VIVIENDA ---\n")

setDT(hogar)
setDT(vivienda)

# Unión a nivel de vivienda (una vivienda puede tener uno o más hogares)
hogar_vivienda <- merge(
    x = hogar,
    y = vivienda,
    by = key_vivienda,
    all.x = TRUE,
    suffixes = c("_hogar", "_vivienda")
)

cat("Base hogar_vivienda creada.\n")
cat("Registros en HOGAR:         ", nrow(hogar), "\n")
cat("Registros en VIVIENDA:      ", nrow(vivienda), "\n")
cat("Registros en hogar_vivienda:", nrow(hogar_vivienda), "\n")

# ---------------------------------------------------------------
# 6. Construcción de índice preliminar de calidad de vivienda
# ---------------------------------------------------------------
cat("\n--- Construyendo índice preliminar de calidad de vivienda ---\n")

# Verificar que las variables necesarias existan antes de construir el índice
vars_necesarias <- c("PCV2", "PCV3", "PCV5", "PCH4", "PCH5", "PCH8")
vars_presentes <- intersect(vars_necesarias, names(hogar_vivienda))

if (length(vars_presentes) < length(vars_necesarias)) {
    cat("Advertencia: No se encontraron todas las variables necesarias para el índice.\n")
    cat(
        "Variables faltantes:",
        paste(setdiff(vars_necesarias, vars_presentes), collapse = ", "),
        "\n"
    )
    cat("El índice se construirá únicamente con las variables disponibles.\n\n")
}

# Crear componentes binarios de calidad (1 = cumple criterio, 0 = no cumple)
if ("PCV2" %in% names(hogar_vivienda)) {
    hogar_vivienda[, buen_material_pared :=
        fifelse(
            PCV2 %in% c(1L, 2L, 3L), 1L,
            fifelse(is.na(PCV2), NA_integer_, 0L)
        )]
}

if ("PCV3" %in% names(hogar_vivienda)) {
    hogar_vivienda[, buen_material_techo :=
        fifelse(
            PCV3 %in% c(1L, 2L, 3L, 4L), 1L,
            fifelse(is.na(PCV3), NA_integer_, 0L)
        )]
}

if ("PCV5" %in% names(hogar_vivienda)) {
    hogar_vivienda[, buen_material_piso :=
        fifelse(
            PCV5 %in% c(1L, 2L, 3L, 4L, 5L, 6L), 1L,
            fifelse(is.na(PCV5), NA_integer_, 0L)
        )]
}

if ("PCH4" %in% names(hogar_vivienda)) {
    hogar_vivienda[, agua_mejorada :=
        fifelse(
            PCH4 %in% c(1L, 2L, 3L, 4L), 1L,
            fifelse(is.na(PCH4), NA_integer_, 0L)
        )]
}

if ("PCH5" %in% names(hogar_vivienda)) {
    hogar_vivienda[, saneamiento_mejorado :=
        fifelse(
            PCH5 %in% c(1L, 2L, 3L), 1L,
            fifelse(is.na(PCH5), NA_integer_, 0L)
        )]
}

if ("PCH8" %in% names(hogar_vivienda)) {
    hogar_vivienda[, electricidad :=
        fifelse(
            PCH8 == 1L, 1L,
            fifelse(is.na(PCH8), NA_integer_, 0L)
        )]
}

# Calcular el índice de calidad sumando los componentes disponibles
componentes_indice <- intersect(
    c(
        "buen_material_pared",
        "buen_material_techo",
        "buen_material_piso",
        "agua_mejorada",
        "saneamiento_mejorado",
        "electricidad"
    ),
    names(hogar_vivienda)
)

if (length(componentes_indice) > 0 && nrow(hogar_vivienda) > 0) {
    # Calcular el índice como suma de componentes (tratando NA como 0 en esta fase)
    hogar_vivienda[, indice_calidad_vivienda :=
        rowSums(.SD, na.rm = TRUE),
    .SDcols = componentes_indice
    ]

    # Calcular cuántos componentes no-NA existen por registro
    hogar_vivienda[, n_componentes_no_na :=
        rowSums(!is.na(.SD)),
    .SDcols = componentes_indice
    ]

    # Si un hogar no tiene información en ninguno de los componentes, el índice se pone en NA
    hogar_vivienda[n_componentes_no_na == 0, indice_calidad_vivienda := NA_real_]

    # Eliminar la columna auxiliar
    hogar_vivienda[, n_componentes_no_na := NULL]

    cat("Índice de calidad de vivienda calculado.\n")
    cat("Resumen del índice (valores más altos indican mejores condiciones):\n")
    print(summary(hogar_vivienda$indice_calidad_vivienda))
} else {
    cat("No fue posible calcular el índice de calidad de vivienda.\n")
    cat("Motivo posible: no hay componentes disponibles o la tabla está vacía.\n")
}
# ---------------------------------------------------------------
# 7. Resumen de información de MIGRACION a nivel de hogar
# ---------------------------------------------------------------
cat("\n--- Resumiendo información de MIGRACION a nivel de hogar ---\n")

if (!exists("migracion") || nrow(migracion) == 0L) {
    cat("La tabla MIGRACION está vacía o no existe en el entorno. Se omite el resumen de migración.\n")

    migracion_resumen <- NULL
} else {
    # Verificación básica de columnas clave antes de agrupar
    claves_migracion <- c(
        "DEPARTAMENTO", "MUNICIPIO", "COD_MUNICIPIO",
        "ZONA", "AREA", "NUM_VIVIENDA", "NUM_HOGAR"
    )

    faltan_claves_mig <- setdiff(claves_migracion, names(migracion))

    if (length(faltan_claves_mig) > 0L) {
        cat("Advertencia: Faltan columnas clave en MIGRACION para hacer el resumen por hogar.\n")
        cat(
            "Columnas faltantes en MIGRACION:",
            paste(faltan_claves_mig, collapse = ", "), "\n"
        )
        cat("No se generará migracion_resumen.\n")

        migracion_resumen <- NULL
    } else {
        # Asegurar tipos numéricos adecuados en PEI3, PEI4, PEI5
        cols_mig_num <- intersect(c("PEI3", "PEI4", "PEI5"), names(migracion))
        migracion[, (cols_mig_num) := lapply(.SD, as.numeric), .SDcols = cols_mig_num]

        # Resumen por hogar
        migracion_resumen <- migracion[
            ,
            {
                # Conteos básicos
                n_emigrantes <- .N
                n_emigrantes_hombres <- sum(PEI3 == 1, na.rm = TRUE)
                n_emigrantes_mujeres <- sum(PEI3 == 2, na.rm = TRUE)

                # Año del último emigrante (manejo seguro de NA)
                max_anio <- suppressWarnings(max(PEI5, na.rm = TRUE))
                if (!is.finite(max_anio)) {
                    anio_ultimo_emigrante <- NA_integer_
                } else {
                    anio_ultimo_emigrante <- as.integer(round(max_anio))
                }

                # Edad promedio de emigrantes (manejo seguro de NA)
                prom_edad <- suppressWarnings(mean(PEI4, na.rm = TRUE))
                if (is.nan(prom_edad)) {
                    edad_prom_emigrantes <- NA_real_
                } else {
                    edad_prom_emigrantes <- as.numeric(prom_edad)
                }

                list(
                    n_emigrantes          = n_emigrantes,
                    n_emigrantes_hombres  = n_emigrantes_hombres,
                    n_emigrantes_mujeres  = n_emigrantes_mujeres,
                    anio_ultimo_emigrante = anio_ultimo_emigrante, # siempre integer/NA
                    edad_prom_emigrantes  = edad_prom_emigrantes # siempre numeric/NA
                )
            },
            by = c(
                "DEPARTAMENTO", "MUNICIPIO", "COD_MUNICIPIO",
                "ZONA", "AREA", "NUM_VIVIENDA", "NUM_HOGAR"
            )
        ]

        cat("Resumen de migración generado con éxito.\n")
        cat(
            "Número de hogares con al menos un emigrante registrado:",
            nrow(migracion_resumen), "\n"
        )

        if ("n_emigrantes" %in% names(migracion_resumen)) {
            cat("Resumen de n_emigrantes por hogar:\n")
            print(summary(migracion_resumen$n_emigrantes))
        }

        if ("edad_prom_emigrantes" %in% names(migracion_resumen)) {
            cat("Resumen de edad promedio de emigrantes (solo hogares con datos válidos):\n")
            print(summary(migracion_resumen$edad_prom_emigrantes))
        }
    }
}


# ---------------------------------------------------------------
# 8. Unión de hogar_vivienda con resumen de migración
# ---------------------------------------------------------------
cat("\n--- Uniendo hogar_vivienda con resumen de migración ---\n")

if (!is.null(migracion_resumen)) {
    setDT(hogar_vivienda)
    hogar_vivienda_mig <- merge(
        x      = hogar_vivienda, # nolint: indentation_linter.
        y      = migracion_resumen,
        by     = key_hogar,
        all.x  = TRUE
    )

    cat("Base hogar_vivienda_mig creada.\n")
    cat("Registros en hogar_vivienda:      ", nrow(hogar_vivienda), "\n")
    cat("Registros en hogar_vivienda_mig:  ", nrow(hogar_vivienda_mig), "\n")
} else {
    hogar_vivienda_mig <- copy(hogar_vivienda)
    cat("Se reutiliza hogar_vivienda como base final a nivel hogar.\n")
}

# ---------------------------------------------------------------
# 9. Unión final: PERSONA + HOGAR_VIVIENDA + MIGRACIÓN + CALIDAD
# ---------------------------------------------------------------
cat("\n--- Uniendo base PERSONA con información de HOGAR y VIVIENDA ---\n")

if (!exists("persona") || nrow(persona) == 0L) {
    stop("La tabla PERSONA no está cargada o está vacía. No se puede continuar con la unificación.")
}

if (!exists("hogar_vivienda_mig") || nrow(hogar_vivienda_mig) == 0L) {
    stop("La tabla hogar_vivienda_mig no está disponible o está vacía. Revisar pasos anteriores.")
}

# Llave teórica de hogar (se puede haber declarado antes; se vuelve a declarar aquí por claridad)
key_hogar <- c(
    "DEPARTAMENTO", "MUNICIPIO", "COD_MUNICIPIO",
    "ZONA", "AREA", "NUM_VIVIENDA", "NUM_HOGAR"
)

# Columnas realmente disponibles en cada tabla
cols_persona <- names(persona)
cols_hogar_viv <- names(hogar_vivienda_mig)

# Llave efectiva: solo columnas que existen en AMBAS tablas
key_common <- intersect(key_hogar, intersect(cols_persona, cols_hogar_viv))

if (length(key_common) == 0L) {
    stop("No hay columnas en común entre PERSONA y hogar_vivienda_mig para realizar la unión. Revisar estructuras de las bases.")
}

# Reporte de la llave utilizada y de las columnas que se descartaron
cat("Llave teórica de unión a nivel de hogar:\n")
cat("  ", paste(key_hogar, collapse = ", "), "\n")

cat("Llave efectiva utilizada para la unión (común en ambas tablas):\n")
cat("  ", paste(key_common, collapse = ", "), "\n")

cols_descartadas <- setdiff(key_hogar, key_common)
if (length(cols_descartadas) > 0L) {
    cat("Advertencia: Las siguientes columnas de la llave teórica no se usarán en la unión porque no están presentes en ambas tablas:\n")
    for (col in cols_descartadas) {
        origen <- c()
        if (!(col %in% cols_persona)) origen <- c(origen, "PERSONA")
        if (!(col %in% cols_hogar_viv)) origen <- c(origen, "HOGAR_VIVIENDA_MIG")
        cat("  -", col, "no se encuentra en:", paste(origen, collapse = " y "), "\n")
    }
}

# Definición de claves en data.table para acelerar el merge
setkeyv(persona, key_common)
setkeyv(hogar_vivienda_mig, key_common)

# Unión final (left join: todas las personas, info de hogar/vivienda/migración/calidad cuando exista)
base_maestra <- merge(
    x = persona,
    y = hogar_vivienda_mig,
    by = key_common,
    all.x = TRUE,
    suffixes = c("_PER", "_HOGVIV")
)

cat("Unión PERSONA + HOGAR_VIVIENDA_MIG completada.\n")
cat("Registros en PERSONA:             ", nrow(persona), "\n")
cat("Registros en hogar_vivienda_mig:  ", nrow(hogar_vivienda_mig), "\n")
cat("Registros en base_maestra (final):", nrow(base_maestra), "\n")

# Pequeña verificación de proporción de personas que no encuentran hogar
if ("NUM_HOGAR" %in% names(persona) && "NUM_HOGAR" %in% names(base_maestra)) {
    sin_match <- sum(is.na(base_maestra$NUM_HOGAR))
    prop_sin_match <- round(100 * sin_match / nrow(base_maestra), 2)
    cat(
        "Personas sin información de hogar/vivienda asociada (NUM_HOGAR NA en resultado):",
        sin_match, "(", prop_sin_match, "% )\n"
    )
}
# Renombrar la variable de salida al contexto de persona
base_persona_maestra <- base_maestra

# ---------------------------------------------------------------
# 10. Guardado de resultados
# ---------------------------------------------------------------
cat("\n--- Guardando bases unificadas ---\n")

if (!dir.exists(dir_output)) {
    dir.create(dir_output, recursive = TRUE)
    cat("Directorio '", dir_output, "' creado.\n", sep = "")
}

# Guardado a nivel hogar / vivienda
cat("Guardando hogar_vivienda.rds...\n")
saveRDS(
    hogar_vivienda,
    file.path(dir_output, "hogar_vivienda.rds")
)

cat("Guardando hogar_vivienda_migracion.rds...\n")
saveRDS(
    hogar_vivienda_mig,
    file.path(dir_output, "hogar_vivienda_migracion.rds")
)

# Guardado a nivel persona
cat("Guardando base_persona_maestra.rds...\n")
saveRDS(
    base_persona_maestra,
    file.path(dir_output, "base_persona_maestra.rds")
)

# Exportación a CSV (para inspección rápida o uso en otras herramientas)
cat("Exportando hogar_vivienda_migracion.csv...\n")
fwrite(
    hogar_vivienda_mig,
    file.path(dir_output, "hogar_vivienda_migracion.csv")
)

cat("Exportando base_persona_maestra.csv...\n")
fwrite(
    base_persona_maestra,
    file.path(dir_output, "base_persona_maestra.csv")
)

cat("Exportando hogar_vivienda.csv...\n")
fwrite(
    hogar_vivienda,
    file.path(dir_output, "hogar_vivienda.csv")
)

cat("Bases unificadas guardadas en '", dir_output, "'.\n", sep = "")

cat("\n==============================================================\n")
cat(" PROCESO DE UNIFICACIÓN COMPLETADO EXITOSAMENTE\n")
cat("==============================================================\n\n")

# ===============================================================
# Fase 9 — Redes Neuronales
# ---------------------------------------------------------------
# Este script:
#   1. Carga el dataset de modelado preparado en la Fase 6.
#   2. Entrena 3 redes neuronales con targets equivalentes a los
#      árboles de decisión:
#       - NN1: indice_calidad_vivienda_cat
#       - NN2: n_emigrantes_cat
#       - NN3: agua_mejorada
#   3. Para cada modelo:
#       - Realiza train/test split.
#       - Aplica normalización (numéricas) y one-hot encoding
#         (categóricas).
#       - Define una arquitectura clara en Keras/TensorFlow.
#       - Entrena con validación y grafica las curvas.
#       - Evalúa en test y produce accuracy.
#       - Genera predicciones de escenarios concretos.
#   4. Exporta resultados a reports/redes_neuronales/.
# ===============================================================

import os
import pathlib

import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler, OneHotEncoder
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline

import matplotlib.pyplot as plt

import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers

# ---------------------------------------------------------------
# 0. Configuración básica y rutas
# ---------------------------------------------------------------
print("==============================================================")
print(" FASE 9 — REDES NEURONALES (PROYECTO PARTE 2)")
print("==============================================================\n")

BASE_DIR = pathlib.Path(".")
DIR_OUTPUT = BASE_DIR / "data" / "output"
DIR_REPORTS = BASE_DIR / "reports" / "redes_neuronales"

DIR_REPORTS.mkdir(parents=True, exist_ok=True)
print(f"Directorio de reportes: {DIR_REPORTS}\n")

# ---------------------------------------------------------------
# 1. Carga del dataset de modelado
# ---------------------------------------------------------------
print("--- Cargando dataset de modelado ---")

ruta_sample_csv = DIR_OUTPUT / "modeling_dataset_sample.csv"
ruta_full_csv = DIR_OUTPUT / "modeling_dataset.csv"

if ruta_sample_csv.exists():
    ruta_model_csv = ruta_sample_csv
    print(f"Se utilizará el dataset muestreado: {ruta_model_csv}")
elif ruta_full_csv.exists():
    ruta_model_csv = ruta_full_csv
    print("Advertencia: no se encontró 'modeling_dataset_sample.csv'.")
    print(f"Se utilizará el dataset completo: {ruta_model_csv}")
else:
    raise FileNotFoundError(
        "No se encontraron ni 'modeling_dataset_sample.csv' "
        "ni 'modeling_dataset.csv' en data/output/. "
        "Ejecutar primero 06_preparacion_modelado.R."
    )

df = pd.read_csv(ruta_model_csv)
print(f"Registros en dataset de modelado: {df.shape[0]}")
print(f"Columnas en dataset de modelado : {df.shape[1]}\n")

# ---------------------------------------------------------------
# 2. Funciones auxiliares
# ---------------------------------------------------------------


def construir_preprocesador(numeric_features, categorical_features):
    """
    Construye un ColumnTransformer que:
    - Estandariza las variables numéricas.
    - Aplica one-hot encoding a las categóricas.
    """
    numeric_transformer = Pipeline(
        steps=[
            ("scaler", StandardScaler())
        ]
    )

    categorical_transformer = Pipeline(
        steps=[
            ("onehot", OneHotEncoder(handle_unknown="ignore"))
        ]
    )

    preprocessor = ColumnTransformer(
        transformers=[
            ("num", numeric_transformer, numeric_features),
            ("cat", categorical_transformer, categorical_features),
        ]
    )
    return preprocessor


def construir_modelo_clasificacion(input_dim, n_classes, model_name):
    """
    Construye una red neuronal de clasificación en Keras.
    - Si n_classes == 2: salida sigmoide (binary).
    - Si n_classes  > 2: salida softmax (multi-clase).
    """
    model = keras.Sequential(name=model_name)
    model.add(layers.Input(shape=(input_dim,), name="input_layer"))

    # Capa oculta 1
    model.add(layers.Dense(32, activation="relu", name="dense_1"))
    model.add(layers.Dropout(0.2, name="dropout_1"))

    # Capa oculta 2
    model.add(layers.Dense(16, activation="relu", name="dense_2"))

    if n_classes == 2:
        model.add(layers.Dense(1, activation="sigmoid", name="output"))
        model.compile(
            optimizer="adam",
            loss="binary_crossentropy",
            metrics=["accuracy"]
        )
    else:
        model.add(layers.Dense(n_classes, activation="softmax", name="output"))
        model.compile(
            optimizer="adam",
            loss="sparse_categorical_crossentropy",
            metrics=["accuracy"]
        )

    return model


def entrenar_modelo_nn(
    df,
    target_col,
    predictors,
    numeric_features,
    categorical_features,
    model_id,
    dir_reports,
    epochs=50,
    batch_size=256,
):
    """
    Entrena una red neuronal para un target específico.

    Pasos:
    - Limpieza de filas con NA.
    - Train/test split.
    - Preprocesamiento (escala + one-hot).
    - Entrenamiento de la NN.
    - Evaluación en test.
    - Gráficas de entrenamiento.
    - Retorno de modelo, preprocesador y otros elementos.
    """
    print("------------------------------------------------------------")
    print(f" Entrenando modelo de red neuronal: {model_id}")
    print("------------------------------------------------------------")

    # Verificar columnas disponibles
    cols_necesarias = [target_col] + predictors
    faltantes = [c for c in cols_necesarias if c not in df.columns]
    if faltantes:
        raise ValueError(
            f"Las siguientes columnas requeridas no existen en el dataset: "
            f"{', '.join(faltantes)}"
        )

    # Subconjunto
    data_sub = df[cols_necesarias].copy()

    # Eliminar filas con NA en target o predictores
    data_sub = data_sub.dropna(subset=cols_necesarias)
    print(f"Observaciones completas para {model_id}: {data_sub.shape[0]}")

    # Codificar target como categoría (para multi-clase) o binaria
    # Se guardan las categorías originales para interpretaciones.
    y_cat = data_sub[target_col].astype("category")
    class_mapping = dict(enumerate(y_cat.cat.categories))
    y = y_cat.cat.codes.values

    X = data_sub[predictors].copy()

    # Train/test split
    X_train, X_test, y_train, y_test = train_test_split(
        X,
        y,
        test_size=0.3,
        random_state=1234,
        stratify=y,
    )

    print(f"Tamaño entrenamiento: {X_train.shape[0]}")
    print(f"Tamaño prueba       : {X_test.shape[0]}")

    # Preprocesador
    preprocessor = construir_preprocesador(
        numeric_features, categorical_features)

    # Ajustar preprocesador con train
    X_train_proc = preprocessor.fit_transform(X_train)
    X_test_proc = preprocessor.transform(X_test)

    input_dim = X_train_proc.shape[1]
    n_classes = len(np.unique(y_train))

    print(
        f"Dimensión de entrada (features tras preprocesamiento): {input_dim}")
    print(f"Número de clases en el target: {n_classes}")

    # Construcción del modelo
    model = construir_modelo_clasificacion(
        input_dim=input_dim,
        n_classes=n_classes,
        model_name=model_id
    )

    print("\nResumen de la arquitectura de la red:")
    model.summary(print_fn=lambda x: print("  " + x))

    # Entrenamiento
    print("\n--- Entrenando la red neuronal ---")
    history = model.fit(
        X_train_proc,
        y_train,
        validation_split=0.2,
        epochs=epochs,
        batch_size=batch_size,
        verbose=1,
    )

    # Evaluación en test
    print("\n--- Evaluación en conjunto de prueba ---")
    test_loss, test_acc = model.evaluate(X_test_proc, y_test, verbose=0)
    print(f"Loss en prueba    : {test_loss:.4f}")
    print(f"Accuracy en prueba: {test_acc:.4f}")
    print("Nota: comparar este accuracy con el del árbol de decisión correspondiente.\n")

    # Gráficas de entrenamiento vs validación
    print("--- Generando gráficas de entrenamiento ---")
    # Accuracy
    plt.figure(figsize=(8, 5))
    plt.plot(history.history["accuracy"], label="Entrenamiento")
    plt.plot(history.history["val_accuracy"], label="Validación")
    plt.xlabel("Época")
    plt.ylabel("Accuracy")
    plt.title(f"Accuracy entrenamiento/validación - {model_id}")
    plt.legend()
    plt.grid(True)
    ruta_acc = DIR_REPORTS / f"{model_id}_accuracy.png"
    plt.savefig(ruta_acc, dpi=150, bbox_inches="tight")
    plt.close()

    # Loss
    plt.figure(figsize=(8, 5))
    plt.plot(history.history["loss"], label="Entrenamiento")
    plt.plot(history.history["val_loss"], label="Validación")
    plt.xlabel("Época")
    plt.ylabel("Loss")
    plt.title(f"Loss entrenamiento/validación - {model_id}")
    plt.legend()
    plt.grid(True)
    ruta_loss = DIR_REPORTS / f"{model_id}_loss.png"
    plt.savefig(ruta_loss, dpi=150, bbox_inches="tight")
    plt.close()

    print("Gráficas guardadas en:")
    print(f" - {ruta_acc}")
    print(f" - {ruta_loss}\n")

    # Guardar modelo
    ruta_model = DIR_REPORTS / f"{model_id}_model.keras"
    model.save(ruta_model)
    print(f"Modelo guardado en: {ruta_model}\n")

    return {
        "model": model,
        "preprocessor": preprocessor,
        "X_train": X_train,
        "X_test": X_test,
        "y_train": y_train,
        "y_test": y_test,
        "class_mapping": class_mapping,
        "test_accuracy": test_acc,
    }


def construir_df_escenarios(predictors, escenarios_dict):
    """
    Construye un DataFrame con filas que representan los diferentes
    escenarios, cada uno con valores para las columnas de 'predictors'.
    escenarios_dict:
        {
          "escenario_1": {var1: val1, var2: val2, ...},
          ...
        }
    """
    rows = []
    for nombre_esc, valores in escenarios_dict.items():
        fila = {p: valores.get(p, np.nan) for p in predictors}
        fila["escenario"] = nombre_esc
        rows.append(fila)
    df_esc = pd.DataFrame(rows)
    cols = ["escenario"] + predictors
    return df_esc[cols]


def predecir_escenarios(
    info_modelo,
    predictors,
    escenarios_dict,
    model_id,
    dir_reports
):
    """
    Aplica el modelo de red neuronal a los escenarios especificados.
    Exporta un CSV con las predicciones (clase y probabilidades).
    """
    print(f"--- Predicciones por escenarios para {model_id} ---")
    df_esc = construir_df_escenarios(predictors, escenarios_dict)

    # Separar columna escenario
    escenario_col = df_esc["escenario"].copy()
    X_esc = df_esc.drop(columns=["escenario"])

    # Transformar con el preprocesador ajustado
    X_esc_proc = info_modelo["preprocessor"].transform(X_esc)

    # Predicciones
    model = info_modelo["model"]
    class_mapping = info_modelo["class_mapping"]

    y_proba = model.predict(X_esc_proc)
    if y_proba.shape[1] == 1:
        # Caso binario: una sola probabilidad (clase positiva)
        y_pred_class = (y_proba[:, 0] >= 0.5).astype(int)
        # Reconstruir etiquetas originales
        inv_map = {v: k for k, v in class_mapping.items()}
        # Asegurar que 0/1 correspondan a las posiciones correctas
        # y_pred_label = [class_mapping.get(c, c) for c in y_pred_class]
        y_pred_label = [
            class_mapping.get(c, str(c)) for c in y_pred_class
        ]

        df_out = df_esc.copy()
        df_out["clase_predicha_cod"] = y_pred_class
        df_out["clase_predicha"] = y_pred_label
        df_out["prob_clase_positiva"] = y_proba[:, 0]
    else:
        # Multi-clase
        y_pred_class = np.argmax(y_proba, axis=1)
        y_pred_label = [class_mapping.get(c, str(c)) for c in y_pred_class]

        df_out = df_esc.copy()
        df_out["clase_predicha_cod"] = y_pred_class
        df_out["clase_predicha"] = y_pred_label

        # Añadir columnas de probabilidad por clase
        for idx, cat in class_mapping.items():
            col_name = f"prob_{cat}"
            df_out[col_name] = y_proba[:, idx]

    print("Resultados de predicción por escenario:")
    print(df_out)

    ruta_csv = dir_reports / f"{model_id}_predicciones_escenarios.csv"
    df_out.to_csv(ruta_csv, index=False)
    print(f"Predicciones de escenarios exportadas a: {ruta_csv}\n")


# ===============================================================
# 3. MODELO NN1 — Target: indice_calidad_vivienda_cat
# ===============================================================
print("==============================================================")
print(" MODELO NN1 — Target: indice_calidad_vivienda_cat")
print("==============================================================\n")

target_nn1 = "indice_calidad_vivienda_cat"

predictors_nn1 = [
    "PCV2", "PCV3", "PCV5",           # materiales
    "agua_mejorada", "saneamiento_mejorado", "electricidad",  # servicios
    "AREA", "cluster_k4"              # ubicación y clúster
]

numeric_nn1 = ["agua_mejorada", "saneamiento_mejorado", "electricidad"]
categorical_nn1 = ["PCV2", "PCV3", "PCV5", "AREA", "cluster_k4"]

info_nn1 = entrenar_modelo_nn(
    df=df,
    target_col=target_nn1,
    predictors=predictors_nn1,
    numeric_features=numeric_nn1,
    categorical_features=categorical_nn1,
    model_id="nn1_indice_calidad_vivienda_cat",
    dir_reports=DIR_REPORTS,
    epochs=50,
    batch_size=256,
)

# Escenarios NN1 (vivienda de baja, media y alta calidad esperada)
escenarios_nn1 = {
    "esc_1_materiales_muy_precarios_sin_servicios": {
        "PCV2": df["PCV2"].dropna().astype("category").cat.categories[0],
        "PCV3": df["PCV3"].dropna().astype("category").cat.categories[0],
        "PCV5": df["PCV5"].dropna().astype("category").cat.categories[0],
        "agua_mejorada": 0,
        "saneamiento_mejorado": 0,
        "electricidad": 0,
        "AREA": df["AREA"].dropna().astype("category").cat.categories[0],
        "cluster_k4": 1,
    },
    "esc_2_materiales_intermedios_con_algunos_servicios": {
        "PCV2": df["PCV2"].dropna().astype("category").cat.categories[min(1, len(df["PCV2"].dropna().astype("category").cat.categories)-1)],
        "PCV3": df["PCV3"].dropna().astype("category").cat.categories[min(1, len(df["PCV3"].dropna().astype("category").cat.categories)-1)],
        "PCV5": df["PCV5"].dropna().astype("category").cat.categories[min(1, len(df["PCV5"].dropna().astype("category").cat.categories)-1)],
        "agua_mejorada": 1,
        "saneamiento_mejorado": 0,
        "electricidad": 1,
        "AREA": df["AREA"].dropna().astype("category").cat.categories[0],
        "cluster_k4": 2,
    },
    "esc_3_materiales_buenos_con_todos_los_servicios": {
        "PCV2": df["PCV2"].dropna().astype("category").cat.categories[-1],
        "PCV3": df["PCV3"].dropna().astype("category").cat.categories[-1],
        "PCV5": df["PCV5"].dropna().astype("category").cat.categories[-1],
        "agua_mejorada": 1,
        "saneamiento_mejorado": 1,
        "electricidad": 1,
        "AREA": df["AREA"].dropna().astype("category").cat.categories[-1],
        "cluster_k4": 3,
    },
}

predecir_escenarios(
    info_modelo=info_nn1,
    predictors=predictors_nn1,
    escenarios_dict=escenarios_nn1,
    model_id="nn1_indice_calidad_vivienda_cat",
    dir_reports=DIR_REPORTS,
)

# ===============================================================
# 4. MODELO NN2 — Target: n_emigrantes_cat
# ===============================================================
print("==============================================================")
print(" MODELO NN2 — Target: n_emigrantes_cat")
print("==============================================================\n")

target_nn2 = "n_emigrantes_cat"

predictors_nn2 = [
    "AREA",                      # área urbana/rural
    "indice_calidad_vivienda",   # índice numérico de calidad
    "n_personas",                # tamaño del hogar
    "cluster_k4",                # clúster k-means
]

numeric_nn2 = ["indice_calidad_vivienda", "n_personas"]
categorical_nn2 = ["AREA", "cluster_k4"]

info_nn2 = entrenar_modelo_nn(
    df=df,
    target_col=target_nn2,
    predictors=predictors_nn2,
    numeric_features=numeric_nn2,
    categorical_features=categorical_nn2,
    model_id="nn2_n_emigrantes_cat",
    dir_reports=DIR_REPORTS,
    epochs=50,
    batch_size=256,
)

# Escenarios NN2 (hogares con distinto tamaño y calidad)
escenarios_nn2 = {
    "esc_1_hogar_pequeno_alta_calidad": {
        "AREA": df["AREA"].dropna().astype("category").cat.categories[-1],
        "indice_calidad_vivienda": df["indice_calidad_vivienda"].max(),
        "n_personas": 3,
        "cluster_k4": 1,
    },
    "esc_2_hogar_grande_baja_calidad": {
        "AREA": df["AREA"].dropna().astype("category").cat.categories[0],
        "indice_calidad_vivienda": df["indice_calidad_vivienda"].min(),
        "n_personas": 8,
        "cluster_k4": 2,
    },
    "esc_3_hogar_mediano_calidad_media": {
        "AREA": df["AREA"].dropna().astype("category").cat.categories[0],
        "indice_calidad_vivienda": df["indice_calidad_vivienda"].median(),
        "n_personas": 5,
        "cluster_k4": 3,
    },
}

predecir_escenarios(
    info_modelo=info_nn2,
    predictors=predictors_nn2,
    escenarios_dict=escenarios_nn2,
    model_id="nn2_n_emigrantes_cat",
    dir_reports=DIR_REPORTS,
)

# ===============================================================
# 5. MODELO NN3 — Target: agua_mejorada (binario)
# ===============================================================
print("==============================================================")
print(" MODELO NN3 — Target: agua_mejorada")
print("==============================================================\n")

target_nn3 = "agua_mejorada"

predictors_nn3 = [
    "PCV2", "PCV3", "PCV5",     # materiales
    "DEPARTAMENTO", "AREA",     # ubicación
    "cluster_k4",               # clúster
    "n_personas",               # tamaño del hogar
    "indice_calidad_vivienda",  # índice numérico
]

numeric_nn3 = ["n_personas", "indice_calidad_vivienda"]
categorical_nn3 = ["PCV2", "PCV3", "PCV5",
                   "DEPARTAMENTO", "AREA", "cluster_k4"]

info_nn3 = entrenar_modelo_nn(
    df=df,
    target_col=target_nn3,
    predictors=predictors_nn3,
    numeric_features=numeric_nn3,
    categorical_features=categorical_nn3,
    model_id="nn3_agua_mejorada",
    dir_reports=DIR_REPORTS,
    epochs=50,
    batch_size=256,
)

# Escenarios NN3 (acceso a agua esperado vs no esperado)
escenarios_nn3 = {
    "esc_1_vivienda_rural_precaria": {
        "PCV2": df["PCV2"].dropna().astype("category").cat.categories[0],
        "PCV3": df["PCV3"].dropna().astype("category").cat.categories[0],
        "PCV5": df["PCV5"].dropna().astype("category").cat.categories[0],
        "DEPARTAMENTO": df["DEPARTAMENTO"].dropna().astype("category").cat.categories[0],
        "AREA": df["AREA"].dropna().astype("category").cat.categories[0],
        "cluster_k4": 1,
        "n_personas": 7,
        "indice_calidad_vivienda": df["indice_calidad_vivienda"].min(),
    },
    "esc_2_vivienda_urbana_mejor_calidad": {
        "PCV2": df["PCV2"].dropna().astype("category").cat.categories[-1],
        "PCV3": df["PCV3"].dropna().astype("category").cat.categories[-1],
        "PCV5": df["PCV5"].dropna().astype("category").cat.categories[-1],
        "DEPARTAMENTO": df["DEPARTAMENTO"].dropna().astype("category").cat.categories[-1],
        "AREA": df["AREA"].dropna().astype("category").cat.categories[-1],
        "cluster_k4": 3,
        "n_personas": 4,
        "indice_calidad_vivienda": df["indice_calidad_vivienda"].quantile(0.75),
    },
    "esc_3_vivienda_intermedia": {
        "PCV2": df["PCV2"].dropna().astype("category").cat.categories[1],
        "PCV3": df["PCV3"].dropna().astype("category").cat.categories[1],
        "PCV5": df["PCV5"].dropna().astype("category").cat.categories[1],
        "DEPARTAMENTO": df["DEPARTAMENTO"].dropna().astype("category").cat.categories[5],
        "AREA": df["AREA"].dropna().astype("category").cat.categories[0],
        "cluster_k4": 2,
        "n_personas": 5,
        "indice_calidad_vivienda": df["indice_calidad_vivienda"].median(),
    },
}

predecir_escenarios(
    info_modelo=info_nn3,
    predictors=predictors_nn3,
    escenarios_dict=escenarios_nn3,
    model_id="nn3_agua_mejorada",
    dir_reports=DIR_REPORTS,
)

print("==============================================================")
print(" FASE 9 COMPLETADA — MODELOS DE REDES NEURONALES LISTOS")
print("==============================================================\n")

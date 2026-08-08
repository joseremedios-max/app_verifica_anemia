import xgboost as xgb
import numpy as np
import onnxmltools
from onnxconverter_common.data_types import FloatTensorType

# ==========================================
# PARTE 1: Treinamento do Modelo (Exemplo)
# ==========================================
# Aqui simulamos dados com 3 colunas: [Saída_do_ViT, Idade, Sexo]
X_treino = np.random.rand(100, 3) 
# Target: Nível de Hemoglobina Real
y_treino = np.random.rand(100) * 15.0 

# Treinamos um Regressor (pois hemoglobina é um número contínuo, não uma categoria)
modelo_xgb = xgb.XGBRegressor(objective='reg:squarederror', n_estimators=100)
modelo_xgb.fit(X_treino, y_treino)

print("Modelo XGBoost treinado com sucesso!")

# ==========================================
# PARTE 2: Conversão para ONNX
# ==========================================
# CRÍTICO: Precisamos avisar ao ONNX qual é o formato da entrada que o Flutter vai mandar.
# O nome 'features_entrada' deve ser exatamente o mesmo que usamos no arquivo Dart!
# Shape [None, 3] significa: Aceita qualquer quantidade de exames por vez (None), com 3 variáveis (ViT, Idade, Sexo).
tipo_entrada = [('features_entrada', FloatTensorType([None, 3]))]

# Faz a tradução do modelo XGBoost para ONNX
modelo_onnx = onnxmltools.convert_xgboost(modelo_xgb, initial_types=tipo_entrada)

# ==========================================
# PARTE 3: Salvando o Arquivo Físico
# ==========================================
nome_arquivo = "xgboost_tabular_final.onnx"

with open(nome_arquivo, "wb") as arquivo:
    arquivo.write(modelo_onnx.SerializeToString())

print(f"Sucesso! Arquivo '{nome_arquivo}' gerado e pronto para o Flutter.")
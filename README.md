## 📱 Como Executar o Projeto
# 🩸 Verifica Anemia (Edge-AI)

Este é um aplicativo de triagem médica experimental desenvolvido em **Flutter**. Ele utiliza **Visão Computacional e Inteligência Artificial (Edge-AI)** rodando diretamente no celular (offline) para estimar os níveis de hemoglobina do paciente através de uma foto da conjuntiva palpebral.

O projeto foi construído com foco em **Offline-First**, permitindo o diagnóstico em áreas remotas, mas conta com sincronização inteligente na nuvem (FastAPI) para envio de dados e telemetria (GPS e Bateria) quando há conexão disponível.

## 🚀 Principais Funcionalidades

*   **Diagnóstico Offline (Edge-AI):** Processamento do modelo Vision Transformer (ViT) via `onnxruntime` direto no hardware do dispositivo, sem depender de internet.
*   **Validação de Qualidade de Imagem:** Algoritmo de segurança que analisa a contagem de pixels avermelhados, impedindo a geração de laudos a partir de fotos incorretas ou sem iluminação adequada.
*   **Guia de Enquadramento:** Interface de câmera customizada com máscara de recorte oval para auxiliar o usuário na captura perfeita da pálpebra.
*   **Classificação OMS:** Cálculo automático do status de anemia (Normal, Leve, Moderada, Grave) cruzando a hemoglobina estimada com a idade e o sexo do paciente, seguindo as diretrizes da Organização Mundial da Saúde.
*   **Banco de Dados Local:** Salvamento do histórico de exames no próprio aparelho utilizando `shared_preferences`.
*   **Sincronização Nuvem & Telemetria:** Coleta de dados do GPS e nível de bateria do celular, enviando o payload completo via HTTP POST para um servidor FastAPI no momento do diagnóstico.

## 🛠️ Tecnologias Utilizadas

*   **Linguagem & Framework:** Dart & Flutter
*   **IA & Visão Computacional:** ONNX Runtime (`onnxruntime`), Processamento de Imagem (`image`)
*   **Integração Nativa:** Controle de Câmera (`camera`), Permissões (`permission_handler`)
*   **Telemetria:** GPS (`geolocator`), Monitoramento de Hardware (`battery_plus`)
*   **Comunicação & Armazenamento:** HTTP/REST (`http`), Armazenamento Chave-Valor (`shared_preferences`)



```bash
git clone [https://github.com/SEU_USUARIO/app_verifica_anemia.git](https://github.com/SEU_USUARIO/app_verifica_anemia.git)

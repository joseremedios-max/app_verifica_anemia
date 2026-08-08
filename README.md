# 🔬🩺 Verifica Anemia (Edge-AI)

Este é um aplicativo de triagem médica experimental desenvolvido em **Flutter**. Ele utiliza **Visão Computacional e Inteligência Artificial (Edge-AI)** rodando diretamente no celular (offline) para estimar os níveis de hemoglobina do paciente através de uma foto da conjuntiva palpebral.

O projeto foi construído com foco em **Offline-First**, permitindo o diagnóstico em áreas remotas, mas conta com sincronização inteligente na nuvem (FastAPI) para envio de dados e telemetria (GPS e Bateria) quando há conexão disponível.

##  🧩 Principais Funcionalidades

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

*   
* Visão Geral do Projeto: Sangue Virtual AI
O Sangue Virtual AI é um ecossistema biomédico inovador projetado para democratizar o diagnóstico prévio de anemia. O projeto utiliza inteligência artificial de ponta embarcada em dispositivos móveis (Edge Computing) para estimar os níveis de hemoglobina de forma 100% não invasiva, utilizando apenas a câmera de um smartphone para analisar a palidez da conjuntiva palpebral (a parte interna da pálpebra inferior) e dados demográficos básicos do paciente.

Objetivo Principal
Substituir a triagem inicial com agulhas e reagentes químicos por um aplicativo rápido, de baixo custo, que funciona totalmente offline (ideal para regiões remotas e postos de saúde básicos), preservando rigorosamente a privacidade do paciente (adequação total à LGPD/HIPAA).

Arquitetura Tecnológica
O sistema é dividido em duas frentes principais: o Dispositivo Médico (App Flutter) e o Servidor de Monitoramento (FastAPI).

1. O Motor de Inteligência Artificial no Celular (Edge Computing)
O aplicativo não depende de internet para realizar o diagnóstico. Ele utiliza uma arquitetura Multimodal com Fusão Tardia (Late Fusion), combinando visão computacional avançada com regressão de dados tabulares:

Modelo de Visão (ViT - Vision Transformer): Processa a fotografia da conjuntiva calibrada (com correções de cor e brilho) e extrai os padrões visuais (um Feature Vector).

Modelo Tabular (XGBoost/Random Forest): Recebe o vetor de características visuais do ViT e o combina com dados demográficos do paciente (Idade e Sexo).

Motor ONNX: Ambos os modelos rodam nativamente no Flutter através do onnxruntime, garantindo inferência em milissegundos sem esgotar a bateria do dispositivo.

2. O Backend de Monitoramento Ativo e Aprendizado Federado
Em vez de enviar fotos sensíveis para a nuvem, o aplicativo envia apenas metadados e métricas de erro para o servidor, pavimentando o caminho para o Aprendizado Federado (FedAvg):

Tecnologia: API de alta performance construída em FastAPI (Python).

Banco de Dados: Utiliza SQLite com SQLAlchemy (ORM), o que garante a integridade dos dados, previne corrupção por acessos simultâneos e facilita uma futura migração para bancos robustos em nuvem (como PostgreSQL).

Monitoramento (Model Drift): O servidor armazena o id do dispositivo, o erro absoluto, os níveis de hemoglobina predita vs. real e o nível da bateria, permitindo avaliar cientificamente se o modelo precisa ser retreinado sem comprometer os dados dos pacientes.

 Fluxo de Funcionamento (Jornada do Exame)
Captura: O profissional de saúde abre o app, insere a idade e o sexo do paciente, e tira uma foto focada no olho (conjuntiva).

Processamento Local: A foto é transformada em um tensor matemático e processada pelo ViT e, logo após, pelo XGBoost, tudo dentro do celular.

Resultado Clínico: A tela exibe o nível estimado de hemoglobina (ex: 12.5 g/dL) de forma instantânea.

Sincronização Federada: Em momento oportuno, o celular envia o resultado daquela predição e o erro calculado (caso comparado com um exame de sangue real) para a API no servidor FastAPI.

Diferenciais Competitivos
Privacidade por Design: Como a imagem nunca sai do celular, não há tráfego de dados sensíveis ou biométricos.

Alta Precisão Multimodal: A combinação de redes neurais Transformer (ViT) com modelos de árvore de decisão (XGBoost) resolve a limitação que os sistemas mais antigos enfrentavam ao usar apenas CNNs (Redes Convolucionais).

Escalabilidade e Segurança: O uso de SQLAlchemy no backend prepara o projeto para suportar milhares de clínicas conectadas simultaneamente


git clone [https://github.com/SEU_USUARIO/app_verifica_anemia.git](https://github.com/SEU_USUARIO/app_verifica_anemia.git)

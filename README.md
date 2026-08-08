# 📱 Anemia AI: Triagem Não-Invasiva via Edge-AI + Ensaio Clínico

Este é um aplicativo de triagem médica experimental desenvolvido em Flutter, projetado para democratizar o diagnóstico prévio de anemia. O projeto utiliza Inteligência Artificial embarcada em dispositivos móveis (Edge Computing) para estimar os níveis de hemoglobina de forma não invasiva, utilizando a câmera do smartphone para analisar a palidez da conjuntiva palpebral. 
O sistema substitui a triagem inicial com agulhas por um aplicativo rápido e de baixo custo, rodando totalmente offline e preservando rigorosamente a privacidade do paciente (Privacy by Design). 

# 🧩 Principais Funcionalidades e Modos de Operação

O aplicativo é dividido em fluxos operacionais que atendem tanto a rotina clínica quanto a pesquisa científica:
	Modo Triagem (Uso Clínico Padrão): Processamento do modelo Vision Transformer (ViT) via onnxruntime direto no hardware do dispositivo, estimando a hemoglobina em milissegundos. 
	Barreira Anatômica Preditiva (ML Kit): Algoritmo avançado que rastreia as coordenadas faciais (Landmarks) em tempo real, exigindo que a mucosa ocular esteja perfeitamente alinhada a uma máscara oval para liberar a captura da foto. 
	Classificação OMS: Cálculo automático do status de anemia (Normal, Leve, Moderada, Grave) cruzando o resultado matemático com a idade e o sexo biológico do paciente. 
	Modo Pesquisador (Ensaio Clínico): Interface exclusiva para a coleta cega e pareada de dados (Foto + Resultado Hb de Laboratório), permitindo a gravação de identificadores anônimos para alimentar futuras calibrações clínicas. 
	Sincronização Nuvem e Telemetria: Envio de payload seguro via HTTP POST contendo o id do dispositivo, bateria celular e coordenadas GPS (geolocator) para um servidor FastAPI. 
# 🔒 Segurança e Privacidade (Privacy by Design)

A adequação total a diretrizes de proteção de dados é garantida por quatro camadas técnicas implementadas diretamente no aplicativo:
	Ofuscação Biométrica (Crop Destrutivo): A imagem capturada passa por um recorte central (mantendo apenas 60% da largura e 30% da altura), eliminando todo o rosto do paciente e enviando apenas a conjuntiva. 
	Anonimização Estática (Hash SHA-256): Todos os identificadores humanos (código do paciente e pesquisador) são criptografados de forma irreversível utilizando um salt fixo de segurança. 
	Criptografia Assimétrica em Trânsito: A imagem anonimizada é convertida para Base64 e envelopada usando uma chave pública RSA, garantindo que apenas o servidor central consiga decodificá-la. 
	Purga Agressiva (RAM Purge): Imediatamente após a inferência matemática do tensor local, a matriz flutuante é ativamente sobrescrita com zeros para impedir extrações forenses dos dados biométricos da memória RAM. 
# 🧠 Arquitetura Tecnológica e Pipeline de IA

O aplicativo não depende de internet para realizar o diagnóstico primário, executando o seguinte fluxo interno: 
	Captura Guiada: O paciente é orientado a puxar a pálpebra inferior e alinhar a mucosa na elipse preditiva da tela. 
	Pré-processamento Matemático: A imagem passa pelo algoritmo Gray World para correção automática de balanço de branco e é redimensionada para 224×224 pixels. Em seguida, sofre normalização estatística utilizando as médias e desvios padrão estabelecidos (Padrão ImageNet). 
	Inferência do Modelo de Visão: O tensor planar multidimensional processa os padrões visuais através de um modelo otimizado Vision Transformer (vit_hemoglobina_mobile_final.onnx). 
	Reescalonamento e Resultado: A saída bruta da rede neural é reescalonada matematicamente utilizando uma fórmula de calibração que retorna a concentração final de hemoglobina em g/dL. 
	Aprendizado Federado: Opcionalmente, o sistema pode sincronizar os resultados preditos em comparação a exames laboratoriais reais para atualizar o modelo global sem violar dados sensíveis do paciente. 
# 🛠️ Stack Tecnológica

Categoria	Tecnologias Empregadas
Linguagem & Interface	Dart, Flutter, Tema Material 3 
IA & Visão Computacional	ONNX Runtime (onnxruntime), ML Kit Face Detection (google_mlkit_face_detection), Image Manipulation (image) 
Criptografia & Segurança	RSA (pointycastle, encrypt), SHA-256 (crypto) 
Hardware & Telemetria	Controle de Câmeras (camera), GPS (geolocator), Monitoramento (battery_plus) 
Armazenamento	Histórico Local (shared_preferences), REST API (http) 

# 📦 Como Instalar
Bash
git clone https://github.com/joseremedios-max/app_verifica_anemia.git
cd app_verifica_anemia
flutter pub get
flutter run

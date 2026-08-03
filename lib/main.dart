import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:battery_plus/battery_plus.dart';
import 'package:geolocator/geolocator.dart';


late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  OrtEnv.instance.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Diagnóstico de Anemia',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.redAccent,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const UserDataScreen(),
    );
  }
}

// =========================================================================
// TELA 1: Perfil do Paciente (Com acesso ao Histórico)
// =========================================================================
class UserDataScreen extends StatefulWidget {
  const UserDataScreen({super.key});

  @override
  State<UserDataScreen> createState() => _UserDataScreenState();
}

class _UserDataScreenState extends State<UserDataScreen> {
  final _formKey = GlobalKey<FormState>();
  String _selectedSex = 'Feminino';
  final TextEditingController _ageController = TextEditingController();

  void _goToTutorial() {
    if (_formKey.currentState!.validate()) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TutorialScreen(
            age: int.parse(_ageController.text),
            sex: _selectedSex,
          ),
        ),
      );
    }
  }

  void _goToHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HistoryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Perfil do Paciente"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            tooltip: "Histórico",
            onPressed: _goToHistory,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.health_and_safety, size: 80, color: Colors.redAccent),
              const SizedBox(height: 24),
              const Text(
                "Dados do Paciente",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                "Os valores de referência da hemoglobina variam conforme a idade e o sexo (Critérios OMS).",
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Idade (em anos)",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.cake),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return "Informe a idade";
                  int? parsedAge = int.tryParse(value);
                  if (parsedAge == null || parsedAge < 0 || parsedAge > 120) {
                    return "Digite uma idade válida";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedSex,
                decoration: InputDecoration(
                  labelText: "Sexo Biológico",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.person),
                ),
                items: ['Feminino', 'Masculino'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() => _selectedSex = newValue!);
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _goToTutorial,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Continuar para Instruções", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _goToHistory,
                child: const Text(
                  "Ver Histórico de Exames",
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// NOVA TELA: Histórico de Medições
// =========================================================================
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> savedData = prefs.getStringList('exam_history') ?? [];
    
    setState(() {
      _history = savedData.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
      _isLoading = false;
    });
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('exam_history');
    setState(() {
      _history.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Histórico"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: "Limpar Histórico",
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Limpar Histórico"),
                    content: const Text("Tem certeza que deseja apagar todos os registros?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancelar", style: TextStyle(color: Colors.white)),
                      ),
                      TextButton(
                        onPressed: () {
                          _clearHistory();
                          Navigator.pop(context);
                        },
                        child: const Text("Apagar", style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ),
                );
              },
            )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
          : _history.isEmpty
              ? const Center(
                  child: Text(
                    "Nenhum exame realizado ainda.",
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final item = _history[index];
                    final date = DateTime.parse(item['date']);
                    final formattedDate = "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} às ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
                    final Color statusColor = Color(item['color']);

                    return Card(
                      color: Colors.grey[900],
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        leading: CircleAvatar(
                          backgroundColor: statusColor.withValues(alpha: 0.2),
                          child: Text(
                            item['hb'].toStringAsFixed(1),
                            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          item['status'],
                          style: TextStyle(fontWeight: FontWeight.bold, color: statusColor),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            "Idade: ${item['age']} anos • ${item['sex']}\n$formattedDate",
                            style: const TextStyle(color: Colors.white70, height: 1.4),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// =========================================================================
// TELA 2: Carrossel de Tutorial de Captura
// =========================================================================
class TutorialScreen extends StatefulWidget {
  final int age;
  final String sex;

  const TutorialScreen({super.key, required this.age, required this.sex});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _tutorialSteps = [
    {
      "icon": Icons.wb_sunny,
      "color": Colors.orangeAccent,
      "title": "1. Iluminação Adequada",
      "description": "Fique em um ambiente bem iluminado. Evite sombras fortes sobre o rosto. Se necessário, ative o flash na tela da câmera."
    },
    {
      "icon": Icons.touch_app,
      "color": Colors.redAccent,
      "title": "2. Puxe a Pálpebra Inferior",
      "description": "Com o dedo indicador, puxe suavemente a pálpebra inferior para baixo até expor totalmente a mucosa vermelha/rosada."
    },
    {
      "icon": Icons.center_focus_strong,
      "color": Colors.lightBlueAccent,
      "title": "3. Enquadre na Máscara Oval",
      "description": "Posicione a mucosa interna exatamente dentro do formato oval centralizado na tela. Mantenha a mão firme antes de fotografar."
    }
  ];

  void _startCamera() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => AnemiaDiagnosticScreen(
          age: widget.age,
          sex: widget.sex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Instruções de Uso"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _startCamera,
            child: const Text("Pular", style: TextStyle(color: Colors.white70, fontSize: 16)),
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemCount: _tutorialSteps.length,
                itemBuilder: (context, index) {
                  final step = _tutorialSteps[index];
                  return Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: (step["color"] as Color).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(color: step["color"], width: 2),
                          ),
                          child: Icon(step["icon"], size: 80, color: step["color"]),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          step["title"],
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          step["description"],
                          style: const TextStyle(fontSize: 15, color: Colors.white70, height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _tutorialSteps.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 8,
                  width: _currentPage == index ? 24 : 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index ? Colors.redAccent : Colors.grey[700],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_currentPage < _tutorialSteps.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      _startCamera();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _currentPage == _tutorialSteps.length - 1 ? "Entendi, Abrir Câmera" : "Próximo Passo",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// TELA DA CÂMERA (COM VALIDADOR DE IMAGEM, IA E SYNC CLOUD)
// =========================================================================
class AnemiaDiagnosticScreen extends StatefulWidget {
  final int age;
  final String sex;

  const AnemiaDiagnosticScreen({super.key, required this.age, required this.sex});

  @override
  State<AnemiaDiagnosticScreen> createState() => _AnemiaDiagnosticScreenState();
}

class _AnemiaDiagnosticScreenState extends State<AnemiaDiagnosticScreen> {
  // === VARIÁVEIS DE ESTADO E CONTROLADORES ===
  CameraController? _cameraController;
  OrtSession? _ortSession;
  
  bool _isProcessing = false;
  bool _isModelLoaded = false;
  bool _isFlashOn = false;
  int _selectedCameraIndex = 0; 
  
  // Constantes para desnormalização do modelo ViT
  static const double _targetMean = 12.5; 
  static const double _targetStd = 2.1;

  // === INICIALIZAÇÃO DA TELA ===
  @override
  void initState() {
    super.initState();
    _initializeCamera(_selectedCameraIndex);
    _loadModel();
  }

  // === CARREGAMENTO DO MODELO ONNX ===
  // Lê o modelo treinado da pasta assets e o aloca na memória (OrtSession)
  Future<void> _loadModel() async {
    try {
      final sessionOptions = OrtSessionOptions();
      const assetPath = 'assets/vit_hemoglobina_mobile_final.onnx';
      final modelData = await rootBundle.load(assetPath);
      
      _ortSession = OrtSession.fromBuffer(
        modelData.buffer.asUint8List(),
        sessionOptions,
      );
      setState(() => _isModelLoaded = true);
    } catch (e) {
      debugPrint("Erro ao carregar modelo: $e");
    }
  }

  // === INICIALIZAÇÃO DA CÂMERA ===
  // Configura a resolução e liga o sensor óptico escolhido (Frontal ou Traseiro)
  Future<void> _initializeCamera(int cameraIndex) async {
    if (cameras.isEmpty) return;
    _cameraController = CameraController(
      cameras[cameraIndex], 
      ResolutionPreset.high,
      enableAudio: false,
    );
    try {
      await _cameraController!.initialize();
      await _cameraController!.setFlashMode(FlashMode.off);
      _isFlashOn = false;
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Erro ao inicializar câmera: $e");
    }
  }

  // === ALTERNAR CÂMERA (FRONTAL/TRASEIRA) ===
  void _switchCamera() {
    if (cameras.length < 2) return; 
    _selectedCameraIndex = _selectedCameraIndex == 0 ? 1 : 0;
    _initializeCamera(_selectedCameraIndex);
  }

  // === CONTROLE DO FLASH DA CÂMERA ===
  void _toggleFlash() async {
    if (_cameraController == null) return;
    try {
      if (_isFlashOn) {
        await _cameraController!.setFlashMode(FlashMode.off);
      } else {
        await _cameraController!.setFlashMode(FlashMode.torch);
      }
      setState(() => _isFlashOn = !_isFlashOn);
    } catch (e) {
      debugPrint("Erro no flash: $e");
    }
  }

  // === VALIDADOR DE QUALIDADE DA IMAGEM (TRAVA DE SEGURANÇA) ===
  // Garante que a foto possui a coloração avermelhada da conjuntiva palpebral
  bool _validateImageQuality(img.Image image) {
    int validPixels = 0;
    
    int startX = (image.width * 0.2).toInt();
    int endX = (image.width * 0.8).toInt();
    int startY = (image.height * 0.3).toInt(); 
    int endY = (image.height * 0.7).toInt();
    
    int area = (endX - startX) * (endY - startY);

    for (int y = startY; y < endY; y++) {
      for (int x = startX; x < endX; x++) {
        final pixel = image.getPixel(x, y);
        int r = pixel.r.toInt();
        int g = pixel.g.toInt();
        int b = pixel.b.toInt();

        // Procura tons onde o Vermelho prevalece (característica da conjuntiva)
        if (r > 80 && r > (g * 1.1) && r > (b * 1.1)) {
          validPixels++;
        }
      }
    }

    double ratio = validPixels / area;
    return ratio >= 0.05; // 5% da área central precisa ser avermelhada/rosada
  }

  // === DIÁLOGO DE IMAGEM INVÁLIDA ===
  // Alerta o usuário caso a foto não passe na trava de segurança
  void _showInvalidImageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
            SizedBox(width: 8),
            Text("Imagem Inválida", style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          "Não identificamos a coloração avermelhada típica da conjuntiva palpebral.\n\n"
          "Verifique se:\n\n"
          "1. Você puxou bem a pálpebra inferior.\n"
          "2. A área interna vermelha está dentro do círculo.\n"
          "3. O ambiente possui boa iluminação.",
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Tentar Novamente", style: TextStyle(color: Colors.redAccent, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  // === SALVAR RESULTADO NO HISTÓRICO LOCAL (OFFLINE) ===
  // Salva o diagnóstico no SharedPreferences do celular
  Future<void> _saveResultToHistory(double hb, Map<String, dynamic> status) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList('exam_history') ?? [];

    final record = {
      'date': DateTime.now().toIso8601String(),
      'hb': hb,
      'age': widget.age,
      'sex': widget.sex,
      'status': status['text'],
      'color': (status['color'] as Color).toARGB32(),
    };

    history.insert(0, jsonEncode(record)); // Adiciona no topo da lista
    await prefs.setStringList('exam_history', history);
  }

  // === SINCRONIZAÇÃO COM A NUVEM (API FASTAPI) ===
  // Envia os dados coletados (com GPS e Bateria) para o servidor remoto
  Future<void> _syncWithCloud(double hbValue) async {
    // Substitua pelo IP da sua máquina local ou URL do servidor de produção
    const String apiUrl = "http://192.168.1.15:8000/api/v1/sincronizar_exame";

    try {
      final Battery battery = Battery();
      final int batteryLevel = await battery.batteryLevel;

      Position position = await Geolocator.getCurrentPosition(
          // ignore: deprecated_member_use
          desiredAccuracy: LocationAccuracy.high);
      String coords = "${position.latitude}, ${position.longitude}";

      final Map<String, dynamic> payload = {
        "id_paciente": "PAC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}",
        "hemoglobina": hbValue,
        "data_hora": DateTime.now().toUtc().toIso8601String(),
        "coordenadas_gps": coords,
        "bateria_celular": batteryLevel
      };

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        debugPrint("✅ Sincronização Nuvem: SUCESSO! -> ${response.body}");
      } else {
        debugPrint("❌ Sincronização Nuvem: FALHA! -> Code: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("⚠️ Erro de rede (Modo Offline mantido): $e");
    }
  }

  // === PROCESSAMENTO DA IMAGEM E INFERÊNCIA DA IA ===
  // Pipeline principal: Tira foto -> Formata -> Passa no Modelo -> Salva -> Sincroniza -> Mostra Resultado
  Future<void> _processImageAndPredict() async {
    if (_isProcessing || !_isModelLoaded || _ortSession == null || _cameraController == null) return;

    setState(() => _isProcessing = true);

    if (_isFlashOn) {
      await _cameraController!.setFlashMode(FlashMode.off);
      setState(() => _isFlashOn = false);
    }

    try {
      // 1. Captura a imagem
      final XFile photo = await _cameraController!.takePicture();
      final Uint8List imageBytes = await photo.readAsBytes();
      
      img.Image? decodedImage = img.decodeImage(imageBytes);
      if (decodedImage == null) throw Exception("Falha ao decodificar imagem.");
      
      // 2. Redimensiona para o tamanho exigido pelo ViT (224x224)
      img.Image resizedImage = img.copyResize(decodedImage, width: 224, height: 224);

      // 3. Validação de Segurança
      if (!_validateImageQuality(resizedImage)) {
        setState(() => _isProcessing = false);
        _showInvalidImageDialog();
        return; 
      }

      // 4. Conversão e Normalização (Formato Tensor Float32)
      var inputFloatArray = Float32List(1 * 3 * 224 * 224);
      int pixelCount = 224 * 224;
      const mean = [0.485, 0.456, 0.406];
      const std = [0.229, 0.224, 0.225];

      for (int y = 0; y < 224; y++) {
        for (int x = 0; x < 224; x++) {
          var pixel = resizedImage.getPixel(x, y);
          int index = y * 224 + x;

          double r = ((pixel.r / 255.0) - mean[0]) / std[0];
          double g = ((pixel.g / 255.0) - mean[1]) / std[1];
          double b = ((pixel.b / 255.0) - mean[2]) / std[2];

          inputFloatArray[index] = r;                  
          inputFloatArray[pixelCount + index] = g;      
          inputFloatArray[2 * pixelCount + index] = b;  
        }
      }

      // 5. Execução da Inferência (ONNX)
      final inputOrt = OrtValueTensor.createTensorWithDataList(inputFloatArray, [1, 3, 224, 224]);
      final runOptions = OrtRunOptions();
      final outputs = _ortSession!.run(runOptions, {'imagem_recortada': inputOrt});

      final outputValue = outputs[0]?.value as List<List<double>>;
      double rawOutput = outputValue[0][0];

      // 6. Desnormalização e Restrição do Valor de Hemoglobina
      double hemoglobina = (rawOutput * _targetStd) + _targetMean;
      hemoglobina = hemoglobina.clamp(0.0, 25.0);

      inputOrt.release();
      runOptions.release();

      // 7. Gerar Status, Salvar e Sincronizar
      final status = _calculateOMSStatus(hemoglobina, widget.age, widget.sex);
      await _saveResultToHistory(hemoglobina, status);
      await _syncWithCloud(hemoglobina); // NOVO: Chama a sincronização após salvar localmente

      // 8. Exibir Interface de Resultado
      _showResultBottomSheet(hemoglobina, status);

    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e")));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // === CÁLCULO DO STATUS DE ANEMIA (CRITÉRIOS OMS) ===
  // Avalia o nível de hemoglobina cruzando com Idade e Sexo
  Map<String, dynamic> _calculateOMSStatus(double hb, int age, String sex) {
    double thresholdNormal;

    if (age < 5) {
      thresholdNormal = 11.0;
    } else if (age < 12) {
      thresholdNormal = 11.5;
    } else if (age < 15) {
      thresholdNormal = 12.0;
    } else {
      thresholdNormal = (sex == 'Masculino') ? 13.0 : 12.0;
    }

    if (hb >= thresholdNormal) {
      return {
        "color": Colors.greenAccent, 
        "text": "Nível Normal",
        "description": "A hemoglobina está dentro da faixa esperada para a faixa etária e sexo."
      };
    } else if (hb >= (thresholdNormal - 1.0)) {
      return {
        "color": Colors.yellowAccent, 
        "text": "Anemia Leve",
        "description": "Ligeiramente abaixo do ideal. Recomenda-se orientação nutricional e médica."
      };
    } else if (hb >= 8.0) {
      return {
        "color": Colors.orangeAccent, 
        "text": "Anemia Moderada",
        "description": "Valor significativamente reduzido. É recomendada a realização de um hemograma."
      };
    } else {
      return {
        "color": Colors.redAccent, 
        "text": "Alerta: Anemia Grave",
        "description": "Nível muito baixo de hemoglobina. Procure atendimento médico com urgência."
      };
    }
  }

  // === EXIBIR RESULTADO NA TELA (BOTTOM SHEET) ===
  // Mostra o card deslizando de baixo para cima com o laudo final
  void _showResultBottomSheet(double hbValue, Map<String, dynamic> status) {
    final Color statusColor = status["color"];
    final String statusText = status["text"];
    final String statusDesc = status["description"];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Paciente: ${widget.age} anos (${widget.sex})", 
                style: const TextStyle(color: Colors.grey, fontSize: 14)
              ),
              const SizedBox(height: 12),
              
              Text(
                "${hbValue.toStringAsFixed(1)} g/dL", 
                style: TextStyle(fontSize: 56, fontWeight: FontWeight.bold, color: statusColor)
              ),
              
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  border: Border.all(color: statusColor, width: 1.5),
                  borderRadius: BorderRadius.circular(20)
                ),
                child: Text(
                  statusText,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
              
              Text(
                statusDesc,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
              
              const SizedBox(height: 20),
              const Divider(color: Colors.white24),
              const SizedBox(height: 12),
              
              const Text(
                "Aviso: Este teste de visão computacional é experimental e serve apenas como triagem preliminar. Não substitui o exame de sangue de laboratório.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.white54, height: 1.4),
              ),
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Fecha o BottomSheet
                    Navigator.pop(context); // Fecha a tela da Câmera
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Concluir e Voltar ao Início", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        );
      }
    );
  }

  // === LIBERAÇÃO DE RECURSOS (DISPOSE) ===
  @override
  void dispose() {
    _cameraController?.dispose();
    _ortSession?.release();
    super.dispose();
  }

  // === CONSTRUÇÃO DA INTERFACE (BUILD) ===
  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized || !_isModelLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.redAccent)));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: CameraPreview(_cameraController!),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: EyeMaskPainter(),
            ),
          ),
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                children: [
                  Text(
                    "Alinhamento da Pálpebra",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Puxe a pálpebra inferior totalmente para baixo.\nEnquadre a parte vermelha interna dentro da linha oval.",
                    style: TextStyle(fontSize: 13, color: Colors.white, height: 1.3),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 170,
            right: 20,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: "flash_btn",
                  mini: true,
                  backgroundColor: _isFlashOn ? Colors.yellow : Colors.grey[800],
                  onPressed: _toggleFlash,
                  child: Icon(Icons.flash_on, color: _isFlashOn ? Colors.black : Colors.white),
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  heroTag: "switch_btn",
                  mini: true,
                  backgroundColor: Colors.grey[800],
                  onPressed: _switchCamera,
                  child: const Icon(Icons.flip_camera_android, color: Colors.white),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.only(bottom: 40),
              child: _isProcessing 
                ? const CircularProgressIndicator(color: Colors.redAccent)
                : GestureDetector(
                    onTap: _processImageAndPredict,
                    child: Container(
                      height: 80,
                      width: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        color: Colors.redAccent.withValues(alpha: 0.9),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 10,
                            spreadRadius: 2,
                          )
                        ]
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 36),
                    ),
                  ),
            ),
          ),
          Positioned(
            top: 50,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            )
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// DESENHO DA MÁSCARA DE ENQUADRAMENTO (UI)
// =========================================================================
class EyeMaskPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = Colors.black.withValues(alpha: 0.75);
    
    final width = size.width * 0.8;
    final height = width * 0.45;
    final centerOffset = Offset(size.width / 2, (size.height / 2) + 20);
    
    final rect = Rect.fromCenter(
      center: centerOffset,
      width: width,
      height: height,
    );
    
    final backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutPath = Path()..addOval(rect);
    
    final finalPath = Path.combine(PathOperation.difference, backgroundPath, cutoutPath);
    canvas.drawPath(finalPath, backgroundPaint);

    final borderPaint = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    canvas.drawOval(rect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
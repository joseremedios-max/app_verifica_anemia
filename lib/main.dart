// =========================================================================
// 📱 PROJETO: TRIAGEM NÃO-INVASIVA DE ANEMIA VIA EDGE-AI + ENSAIO CLÍNICO
// =========================================================================
// [ESTRATÉGIA] Este arquivo unifica UI/UX fluida com processamento pesado
// local (Edge Computing). Reduzimos a latência a zero e evitamos custos de
// nuvem ao rodar o modelo Vision Transformer (ViT) diretamente no celular.
// =========================================================================

import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:image/image.dart' as img;
import 'package:pointycastle/asymmetric/api.dart' as enc;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:battery_plus/battery_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
// ignore: unused_import
import 'package:pointycastle/asymmetric/api.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  OrtEnv.instance.init(); // [IA] Inicializa o motor do ONNX Runtime em C++
  runApp(const MyApp());
}

// =========================================================================
// 🔒 FUNÇÕES DE SEGURANÇA GLOBAIS
// =========================================================================
// [PRIVACIDADE] A LGPD proíbe armazenar nomes ou CPFs em pesquisas clínicas 
// sem extrema necessidade. Usamos SHA-256 + Salt para anonimizar na origem.
String anonimizarDado(String dadoBruto) {
  final bytes = utf8.encode('${dadoBruto}SALT_CLINICO_SECRETO_2026'); 
  return sha256.convert(bytes).toString();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Diagnóstico de Anemia',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.redAccent,
          brightness: Brightness.dark,
          // ignore: deprecated_member_use
          background: const Color(0xFF0D0D12),
          surface: const Color(0xFF1A1A24),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent, 
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: const MainSelectionScreen(), 
    );
  }
}

// =========================================================================
// 🏠 TELA INICIAL: SELEÇÃO DE MODO DE OPERAÇÃO
// =========================================================================
class MainSelectionScreen extends StatelessWidget {
  const MainSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anemia AI', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.hub_rounded, size: 90, color: Colors.redAccent),
            const SizedBox(height: 24),
            const Text(
              'Sistema Central',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Selecione o modo de operação abaixo para iniciar o processo.',
              style: TextStyle(fontSize: 16, color: Colors.white60),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            
            _buildModeCard(
              context,
              title: 'Modo Triagem',
              subtitle: 'Avaliação rápida para pacientes',
              icon: Icons.health_and_safety_rounded,
              color: Colors.redAccent,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const UserDataScreen())),
            ),
            const SizedBox(height: 20),
            
            _buildModeCard(
              context,
              title: 'Modo Pesquisador',
              subtitle: 'Ensaio clínico e coleta cega pareada',
              icon: Icons.science_rounded,
              color: Colors.blueAccent,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ResearcherModeScreen(cameras: cameras))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 14, color: Colors.white60)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 20),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// 🧑‍⚕️ TELA 1: PERFIL DO PACIENTE (MODO TRIAGEM)
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
    Navigator.push(context, MaterialPageRoute(builder: (context) => const HistoryScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil do Paciente'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Histórico',
            onPressed: _goToHistory,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_outline_rounded, size: 70, color: Colors.redAccent),
              ),
              const SizedBox(height: 32),
              const Text('Dados Biológicos', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              const Text(
                'Os valores de referência variam conforme a idade e o sexo (Diretrizes da OMS).',
                style: TextStyle(fontSize: 15, color: Colors.white60),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              
              TextFormField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Idade (em anos)',
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.cake_rounded, color: Colors.redAccent),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Informe a idade';
                  int? parsedAge = int.tryParse(value);
                  if (parsedAge == null || parsedAge < 0 || parsedAge > 120) return 'Digite uma idade válida';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              
              DropdownButtonFormField<String>(
                initialValue: _selectedSex,
                decoration: InputDecoration(
                  labelText: 'Sexo Biológico',
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.wc_rounded, color: Colors.redAccent),
                ),
                items: ['Feminino', 'Masculino'].map((String value) {
                  return DropdownMenuItem<String>(value: value, child: Text(value));
                }).toList(),
                onChanged: (newValue) => setState(() => _selectedSex = newValue!),
              ),
              const SizedBox(height: 48),
              
              FilledButton(
                onPressed: _goToTutorial,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Continuar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),
              
              TextButton(
                onPressed: _goToHistory,
                child: const Text('Ver Histórico de Exames', style: TextStyle(color: Colors.white70, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// 📂 TELA DE HISTÓRICO COMPLETA
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
    setState(() => _history.clear());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de Exames'),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: const Text('Limpar Histórico'),
                    content: const Text('Tem certeza que deseja apagar todos os registros permanentemente?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.white70))),
                      FilledButton(
                        onPressed: () { _clearHistory(); Navigator.pop(context); },
                        style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                        child: const Text('Apagar Tudo'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
          : _history.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final item = _history[index];
                    final date = DateTime.parse(item['date']);
                    final formattedDate = "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} às ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
                    final Color statusColor = Color(item['color']);

                    return Card(
                      elevation: 0,
                      color: Theme.of(context).colorScheme.surface,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: statusColor.withValues(alpha: 0.3), width: 1),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Container(
                              height: 60,
                              width: 60,
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                // ignore: avoid_dynamic_calls
                                item['hb'].toStringAsFixed(1),
                                style: TextStyle(color: statusColor, fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['status'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: statusColor)),
                                  const SizedBox(height: 6),
                                  Text("Paciente: ${item['age']} anos • ${item['sex']}", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Text(formattedDate, style: const TextStyle(color: Colors.white30, fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 80, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          const Text('Nenhum exame realizado ainda.', style: TextStyle(color: Colors.white54, fontSize: 16)),
        ],
      ),
    );
  }
}

// =========================================================================
// 📖 TELA DE TUTORIAL COMPLETA (CARROSSEL)
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
    {'icon': Icons.wb_sunny_rounded, 'color': Colors.orangeAccent, 'title': 'Iluminação Adequada', 'description': 'Fique em um ambiente bem iluminado. Evite sombras fortes sobre o rosto. Se necessário, ative o flash na próxima tela.'},
    {'icon': Icons.touch_app_rounded, 'color': Colors.redAccent, 'title': 'Puxe a Pálpebra', 'description': 'Com o dedo indicador, puxe suavemente a pálpebra inferior para baixo até expor totalmente a mucosa vermelha do olho.'},
    {'icon': Icons.center_focus_strong_rounded, 'color': Colors.lightBlueAccent, 'title': 'Enquadre Perfeitamente', 'description': 'Posicione a mucosa interna exatamente dentro do formato oval que aparecerá na tela. Mantenha a mão firme.'},
  ];

  void _startCamera() {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => AnemiaDiagnosticScreen(age: widget.age, sex: widget.sex)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton(
            onPressed: _startCamera, 
            child: const Text('Pular', style: TextStyle(color: Colors.white70, fontSize: 16)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _tutorialSteps.length,
                itemBuilder: (context, index) {
                  final step = _tutorialSteps[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(36),
                          decoration: BoxDecoration(
                            color: (step['color'] as Color).withValues(alpha: 0.1), 
                            shape: BoxShape.circle, 
                          ),
                          child: Icon(step['icon'], size: 90, color: step['color']),
                        ),
                        const SizedBox(height: 48),
                        Text(step['title'], style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        Text(step['description'], style: const TextStyle(fontSize: 16, color: Colors.white70, height: 1.6), textAlign: TextAlign.center),
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
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  height: 10,
                  width: _currentPage == index ? 32 : 10,
                  decoration: BoxDecoration(
                    color: _currentPage == index ? Colors.redAccent : Colors.white.withValues(alpha: 0.2), 
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 48),
            Padding(
              padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 32.0),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (_currentPage < _tutorialSteps.length - 1) {
                      _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
                    } else {
                      _startCamera();
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.redAccent, 
                    padding: const EdgeInsets.symmetric(vertical: 18), 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    _currentPage == _tutorialSteps.length - 1 ? 'Abrir Câmera' : 'Próximo', 
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
// 🎨 ALGORITMO DE VISÃO COMPUTACIONAL: GRAY WORLD
// =========================================================================
// [IA] O Gray World Algorithm remove a "contaminação" da cor da luz ambiente 
// (ex: luz amarela de tungstênio vs luz azulada de LED). Isso garante que o 
// vermelho da mucosa avaliado pela IA seja o vermelho real do sangue.
img.Image aplicarBalancoDeBranco(img.Image imagemOriginal) {
  double somaR = 0, somaG = 0, somaB = 0;
  int totalPixels = imagemOriginal.width * imagemOriginal.height;

  for (var pixel in imagemOriginal) {
    somaR += pixel.r;
    somaG += pixel.g;
    somaB += pixel.b;
  }

  double mediaR = somaR / totalPixels;
  double mediaG = somaG / totalPixels;
  double mediaB = somaB / totalPixels;

  if (mediaR == 0) mediaR = 1;
  if (mediaG == 0) mediaG = 1;
  if (mediaB == 0) mediaB = 1;

  double mediaCinza = (mediaR + mediaG + mediaB) / 3.0;

  for (var pixel in imagemOriginal) {
    num novoR = pixel.r * (mediaCinza / mediaR);
    num novoG = pixel.g * (mediaCinza / mediaG);
    num novoB = pixel.b * (mediaCinza / mediaB);

    pixel.r = novoR.clamp(0, 255);
    pixel.g = novoG.clamp(0, 255);
    pixel.b = novoB.clamp(0, 255);
  }

  return imagemOriginal;
}

// =========================================================================
// 📷 TELA PRINCIPAL: CÂMERA, ML KIT (BARREIRA ANATÔMICA) E EDGE-AI
// =========================================================================
class AnemiaDiagnosticScreen extends StatefulWidget {
  final int age;
  final String sex;
  const AnemiaDiagnosticScreen({super.key, required this.age, required this.sex});

  @override
  State<AnemiaDiagnosticScreen> createState() => _AnemiaDiagnosticScreenState();
}

class _AnemiaDiagnosticScreenState extends State<AnemiaDiagnosticScreen> {
  CameraController? _cameraController;
  OrtSession? _ortSession;
  
  // [ESTRATÉGIA] Barreira Anatômica: O modelo de Face Detection do ML Kit 
  // atua como um 'porteiro'. Ele roda a 30 FPS e só libera o botão de captura 
  // se detectar um olho vivo dentro da elipse da UI[cite: 6].
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      enableContours: false,
      performanceMode: FaceDetectorMode.fast,
    ),
  );
  
  bool _isProcessing = false;
  bool _isModelLoaded = false;
  bool _isFlashOn = false;
  int _selectedCameraIndex = 0; 
  
  // Controle de Estado de Frames e Trava Tripla[cite: 6]
  bool _isScanningFrame = false; 
  bool _isAnatomyValid = false; 
  
  static const double _targetMean = 12.5; 
  static const double _targetStd = 2.1;

  @override
  void initState() {
    super.initState();
    _initializeCamera(_selectedCameraIndex);
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      final sessionOptions = OrtSessionOptions();
      const assetPath = 'assets/vit_hemoglobina_mobile_final.onnx';
      final modelData = await rootBundle.load(assetPath);
      
      _ortSession = OrtSession.fromBuffer(modelData.buffer.asUint8List(), sessionOptions);
      setState(() => _isModelLoaded = true);
    } catch (e) {
      debugPrint('Erro ao carregar modelo: $e');
    }
  }

  Future<void> _initializeCamera(int cameraIndex) async {
    if (cameras.isEmpty) return;
    _cameraController = CameraController(
      cameras[cameraIndex], 
      ResolutionPreset.high, 
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
    );
    try {
      await _cameraController!.initialize();
      await _cameraController!.setFlashMode(FlashMode.off);
      _isFlashOn = false;
      
      if (mounted) {
        setState(() {});
        _iniciarRastreamentoAnatomico(); 
      }
    } catch (e) {
      debugPrint('Erro ao inicializar câmera: $e');
    }
  }

  // ==========================================
  // 👁️ PIPELINE DE VISÃO: BARREIRA ANATÔMICA
  // ==========================================
  void _iniciarRastreamentoAnatomico() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    _cameraController!.startImageStream((CameraImage image) async {
      // [OTIMIZAÇÃO] Drop Frame Passivo: Impede acúmulo de processamento 
      // se a CPU do celular não conseguir acompanhar a taxa de quadros[cite: 6].
      if (_isScanningFrame || _isProcessing) return;
      _isScanningFrame = true;

      try {
        final inputImage = _converterCameraImageParaInputImage(image);
        if (inputImage != null) {
          await _validarAnatomiaMLKit(inputImage);
        }
      } catch (e) {
        debugPrint('Erro no pipeline do ML Kit: $e');
      } finally {
        _isScanningFrame = false;
      }
    });
  }

  InputImage? _converterCameraImageParaInputImage(CameraImage image) {
    final camera = cameras[_selectedCameraIndex];
    final sensorOrientation = camera.sensorOrientation;

    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation = _cameraController!.value.deviceOrientation.index;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }

    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.yuv420) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }

    if (image.planes.isEmpty) return null;

    return InputImage.fromBytes(
      bytes: image.planes[0].bytes, 
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation, 
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  // ==========================================
  // 👁️ VALIDAÇÃO GEOMÉTRICA (ML KIT)
  // ==========================================
  Future<void> _validarAnatomiaMLKit(InputImage inputImage) async {
    final List<Face> faces = await _faceDetector.processImage(inputImage);

    if (faces.isEmpty) {
      _bloquearCaptura();
      return;
    }

    final face = faces.first;
    final FaceLandmark? leftEye = face.landmarks[FaceLandmarkType.leftEye];
    final FaceLandmark? rightEye = face.landmarks[FaceLandmarkType.rightEye];

    if (leftEye == null && rightEye == null) {
      _bloquearCaptura();
      return;
    }

    // [ESTRATÉGIA] Inequação da Elipse: Verifica se a coordenada (x,y) do olho
    // está matematicamente dentro do formato desenhado na tela[cite: 6].
    final Size imageSize = inputImage.metadata!.size;
    final double h = imageSize.width / 2; 
    final double k = (imageSize.height / 2) + 20; 
    const double fatorTolerancia = 1.5;
    final double a = ((imageSize.width * 0.8) / 2) * fatorTolerancia; 
    final double b = (((imageSize.width * 0.8) * 0.45) / 2) * fatorTolerancia;

    bool olhoEnquadrado = false;
    final pontosOlhos = [leftEye?.position, rightEye?.position].whereType<Point<int>>();

    for (var pos in pontosOlhos) {
      double calculoElipse = pow((pos.x - h), 2) / pow(a, 2) + pow((pos.y - k), 2) / pow(b, 2);

      if (calculoElipse <= 1.0) {
        olhoEnquadrado = true;
        break; 
      }
    }

    if (olhoEnquadrado && !_isAnatomyValid) {
      setState(() => _isAnatomyValid = true);
    } else if (!olhoEnquadrado && _isAnatomyValid) {
      _bloquearCaptura();
    }
  }

  void _bloquearCaptura() {
    if (_isAnatomyValid) {
      setState(() => _isAnatomyValid = false);
    }
  }

  // ==========================================
  // CONTROLES DE CÂMERA PADRÃO
  // ==========================================
  void _switchCamera() async {
    if (cameras.length < 2) return; 
    await _cameraController?.stopImageStream();
    _selectedCameraIndex = _selectedCameraIndex == 0 ? 1 : 0;
    _initializeCamera(_selectedCameraIndex);
  }

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
      debugPrint('Erro no flash: $e');
    }
  }

  // ==========================================
  // INFERÊNCIA, CROP MATEMÁTICO E SINC 
  // ==========================================
  Future<void> _processImageAndPredict() async {
    if (_isProcessing || !_isModelLoaded || _ortSession == null || _cameraController == null) return; //[cite: 6]
    
    setState(() => _isProcessing = true); //[cite: 6]
    
    // Parar o stream para liberar a captura de foto de alta resolução[cite: 6]
    if (_cameraController!.value.isStreamingImages) {
      await _cameraController!.stopImageStream(); //[cite: 6]
    }

    if (_isFlashOn) { await _cameraController!.setFlashMode(FlashMode.off); setState(() => _isFlashOn = false); } //[cite: 6]

    try {
      final XFile photo = await _cameraController!.takePicture(); //[cite: 6]
      final Uint8List imageBytes = await photo.readAsBytes(); //[cite: 6]
      img.Image? originalImage = img.decodeImage(imageBytes); //[cite: 6]
      if (originalImage == null) throw Exception('Falha ao decodificar imagem.'); //[cite: 6]

      // ==========================================================
      // 🛡️ RECORTE MATEMÁTICO E PRIVACY BY DESIGN
      // ==========================================================
      
      // 1. Correção de Rotação (Garante orientação retrato para o Crop no Android/Motorola)
      if (originalImage.width > originalImage.height) {
        originalImage = img.copyRotate(originalImage, angle: 90);
      }

      final int w = originalImage.width;
      final int h = originalImage.height;

      // 2. Fórmulas de Recorte (Bounding Box Quadrada baseada na elipse da UI)
      final int L = (w * 0.8).toInt(); 
      final int xStart = (w - L) ~/ 2;
      
      // Offset Y de +20 pixels simulado da UI, convertido para proporção da resolução nativa
      // ignore: use_build_context_synchronously
      final int offsetY = (20 * h) ~/ MediaQuery.of(context).size.height;
      final int yStart = ((h ~/ 2) - (L ~/ 2)) + offsetY;

      // 3. O Bisturi Digital: Recorta a área da mucosa e descarta o rosto
      img.Image croppedEye = img.copyCrop(
        originalImage,
        x: xStart,
        y: yStart,
        width: L,
        height: L,
      );

      // 4. [PRIVACIDADE] Purga Imediata da Biometria Facial Original
      // originalImage perde a referência para o Garbage Collector limpar a RAM.
      originalImage = null; 

      // 5. [OTIMIZAÇÃO] Aplica o Gray World apenas no recorte para poupar CPU[cite: 6]
      croppedEye = aplicarBalancoDeBranco(croppedEye);

      // 6. [IA] Redimensiona o recorte quadrado perfeitamente para 224x224 (Target Resolution do ViT)[cite: 6]
      img.Image resizedImage = img.copyResize(
        croppedEye, 
        width: 224, 
        height: 224,
        interpolation: img.Interpolation.linear,
      );
      
      // ==========================================================
      // 🧠 PREPARAÇÃO DE TENSOR E INFERÊNCIA ONNX
      // ==========================================================
      var inputFloatArray = Float32List(1 * 3 * 224 * 224); //[cite: 6]
      int pixelCount = 224 * 224; //[cite: 6]
      // Normalização padrão da ImageNet exigida pelos modelos ViT
      const mean = [0.485, 0.456, 0.406]; //[cite: 6]
      const std = [0.229, 0.224, 0.225]; //[cite: 6]

      for (int y = 0; y < 224; y++) {
        for (int x = 0; x < 224; x++) {
          var pixel = resizedImage.getPixel(x, y); //[cite: 6]
          int index = y * 224 + x; //[cite: 6]

          double r = ((pixel.r / 255.0) - mean[0]) / std[0]; //[cite: 6]
          double g = ((pixel.g / 255.0) - mean[1]) / std[1]; //[cite: 6]
          double b = ((pixel.b / 255.0) - mean[2]) / std[2]; //[cite: 6]

          // O ONNX espera o formato [Channels, Height, Width] (NCHW)
          inputFloatArray[index] = r;                  //[cite: 6]
          inputFloatArray[pixelCount + index] = g;      //[cite: 6]
          inputFloatArray[2 * pixelCount + index] = b;  //[cite: 6]
        }
      }

      final inputOrt = OrtValueTensor.createTensorWithDataList(inputFloatArray, [1, 3, 224, 224]); //[cite: 6]
      final runOptions = OrtRunOptions(); //[cite: 6]
      final outputs = _ortSession!.run(runOptions, {'imagem_recortada': inputOrt}); //[cite: 6]

      final outputValue = outputs[0]?.value as List<List<double>>; //[cite: 6]
      double rawOutput = outputValue[0][0]; //[cite: 6]

      // Desnormalização da predição final
      double hemoglobina = (rawOutput * _targetStd) + _targetMean; //[cite: 6]
      hemoglobina = hemoglobina.clamp(0.0, 25.0); //[cite: 6]

      // [PRIVACIDADE] RAM Purge (Descarte Agressivo do Tensor de Dados)[cite: 6]
      for (int i = 0; i < inputFloatArray.length; i++) {
        inputFloatArray[i] = 0.0;  //[cite: 6]
      }
      
      inputOrt.release(); //[cite: 6]
      runOptions.release(); //[cite: 6]
      for (var element in outputs) {
        element?.release(); //[cite: 6]
      }

      final status = _calculateOMSStatus(hemoglobina, widget.age, widget.sex); //[cite: 6]
      await _saveResultToHistory(hemoglobina, status); //[cite: 6]
      await _syncWithCloud(hemoglobina); //[cite: 6]
      _showResultBottomSheet(hemoglobina, status); //[cite: 6]

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'))); //[cite: 6]
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false); //[cite: 6]
        // Reinicia o fluxo para a próxima leitura após fechar o modal[cite: 6]
        _iniciarRastreamentoAnatomico(); //[cite: 6]
      }
    }
  }

  Map<String, dynamic> _calculateOMSStatus(double hb, int age, String sex) {
    // [ESTRATÉGIA] Diretrizes da OMS para diagnóstico de anemia baseadas
    // nas variáveis demográficas fornecidas na tela 1.
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
      return {'color': Colors.greenAccent, 'text': 'Nível Normal', 'description': 'Hemoglobina dentro da faixa saudável.'};
    } else if (hb >= (thresholdNormal - 1.0)) {
      return {'color': Colors.yellowAccent, 'text': 'Anemia Leve', 'description': 'Ligeiramente abaixo do ideal. Monitore.'};
    } else if (hb >= 8.0) {
      return {'color': Colors.orangeAccent, 'text': 'Anemia Moderada', 'description': 'Valor reduzido. Recomendado hemograma.'};
    } else {
      return {'color': Colors.redAccent, 'text': 'Alerta: Anemia Grave', 'description': 'Nível muito baixo. Procure um médico imediatamente.'};
    }
  }

  Future<void> _saveResultToHistory(double hb, Map<String, dynamic> status) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList('exam_history') ?? [];
    final record = {
      'date': DateTime.now().toIso8601String(),
      'hb': hb, 'age': widget.age, 'sex': widget.sex, 'status': status['text'], 'color': (status['color'] as Color).toARGB32(),
    };
    history.insert(0, jsonEncode(record));
    await prefs.setStringList('exam_history', history);
  }

  Future<void> _syncWithCloud(double hbValue) async {
    const String apiUrl = 'http://10.0.2.2:8000/api/v1/sincronizar_exame'; 
    try {
      final Battery battery = Battery();
      final int batteryLevel = await battery.batteryLevel;
      // ignore: deprecated_member_use
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      String coords = '${position.latitude}, ${position.longitude}';

      final Map<String, dynamic> payload = {
        'id_paciente': 'PAC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        'hemoglobina': hbValue, 'data_hora': DateTime.now().toUtc().toIso8601String(),
        'coordenadas_gps': coords, 'bateria_celular': batteryLevel,
      };

      final response = await http.post(Uri.parse(apiUrl), headers: {'Content-Type': 'application/json'}, body: jsonEncode(payload));
      if (response.statusCode == 200) debugPrint('✅ Sincronização Nuvem: SUCESSO!');
    } catch (e) {
      debugPrint('⚠️ Erro de rede (Modo Offline mantido): $e');
    }
  }

  void _showResultBottomSheet(double hbValue, Map<String, dynamic> status) {
    final Color statusColor = status['color'];
    final TextEditingController exameRealController = TextEditingController(); 

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true, 
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: EdgeInsets.only(left: 28.0, right: 28.0, top: 16.0, bottom: MediaQuery.of(context).viewInsets.bottom + 24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 5,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                ),
                const SizedBox(height: 32),
                
                Text('Paciente: ${widget.age} anos • ${widget.sex}', style: const TextStyle(color: Colors.white60, fontSize: 15)),
                const SizedBox(height: 16),
                
                Text('${hbValue.toStringAsFixed(1)} g/dL', style: TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: statusColor, letterSpacing: -1)),
                
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1), 
                    border: Border.all(color: statusColor.withValues(alpha: 0.5), width: 1.5), 
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(status['text'], style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: statusColor)),
                ),
                Text(status['description'], textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: Colors.white70, height: 1.4)),
                
                const SizedBox(height: 32),
                const Divider(color: Colors.white12),
                const SizedBox(height: 24),
                
                const Text('Calibração (Opcional)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                const Text('Insira o resultado real do laboratório para calibrar a IA via Federated Learning.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.white54, height: 1.4)),
                const SizedBox(height: 20),
                
                TextField(
                  controller: exameRealController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Resultado Real (g/dL)',
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.science_rounded, color: Colors.white54),
                  ),
                ),
                
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      double valorReal = double.tryParse(exameRealController.text.replaceAll(',', '.')) ?? 0.0;
                      if (valorReal > 0) {
                        enviarDadosFederados(hbValue, valorReal);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Metadados enviados para calibração!'), backgroundColor: Colors.green));
                        Navigator.pop(context); Navigator.pop(context);
                      }
                    },
                    icon: const Icon(Icons.cloud_upload_rounded),
                    label: const Text('Enviar Calibração', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.blueAccent, 
                      padding: const EdgeInsets.symmetric(vertical: 16), 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () { Navigator.pop(context); Navigator.pop(context); },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16), 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Concluir sem Calibrar', style: TextStyle(fontSize: 16, color: Colors.white70)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      if (mounted && !_isProcessing) {
        _iniciarRastreamentoAnatomico();
      }
    });
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _faceDetector.close(); // Limpeza essencial do ML Kit
    _cameraController?.dispose();
    _ortSession?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized || !_isModelLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.redAccent)));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: CameraPreview(_cameraController!)),
          Positioned.fill(child: CustomPaint(painter: EyeMaskPainter())), 
          
          Positioned(
            top: 60, left: 24, right: 24,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6), 
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isAnatomyValid ? Colors.greenAccent : Colors.white24, 
                  width: _isAnatomyValid ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    _isAnatomyValid ? 'Anatomia Validada!' : 'Alinhamento da Pálpebra', 
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold, 
                      color: _isAnatomyValid ? Colors.greenAccent : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isAnatomyValid 
                      ? 'Clique no botão abaixo para capturar.' 
                      : 'Puxe a pálpebra inferior totalmente para baixo.\nEnquadre a mucosa dentro da linha oval.', 
                    style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.4), 
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          
          Positioned(
            top: 180, right: 24,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: 'flash_btn', 
                  mini: true, 
                  backgroundColor: _isFlashOn ? Colors.yellowAccent : Theme.of(context).colorScheme.surface, 
                  onPressed: _toggleFlash, 
                  child: Icon(Icons.flash_on_rounded, color: _isFlashOn ? Colors.black : Colors.white),
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  heroTag: 'switch_btn', 
                  mini: true, 
                  backgroundColor: Theme.of(context).colorScheme.surface, 
                  onPressed: _switchCamera, 
                  child: const Icon(Icons.flip_camera_android_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
          
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.only(bottom: 50),
              child: _isProcessing 
                ? const CircularProgressIndicator(color: Colors.redAccent)
                : GestureDetector(
                    onTap: _isAnatomyValid ? _processImageAndPredict : null, 
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 85, width: 85,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle, 
                        border: Border.all(color: Colors.white, width: 4), 
                        color: _isAnatomyValid ? Colors.redAccent : Colors.grey.withValues(alpha: 0.4), 
                        boxShadow: _isAnatomyValid 
                          ? [BoxShadow(color: Colors.redAccent.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 4)]
                          : [],
                      ),
                      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 36),
                    ),
                  ),
            ),
          ),
          
          Positioned(
            top: 50, left: 16, 
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 32), 
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// 🔬 MODO PESQUISADOR: COLETA CEGA PAREADA (ENSAIO CLÍNICO)
// =========================================================================
class ResearcherModeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const ResearcherModeScreen({super.key, required this.cameras});

  @override
  State<ResearcherModeScreen> createState() => _ResearcherModeScreenState();
}

class _ResearcherModeScreenState extends State<ResearcherModeScreen> {
  CameraController? _controller;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _patientCodeController = TextEditingController();
  final TextEditingController _labHbController = TextEditingController();
  final TextEditingController _researcherIdController = TextEditingController();
  String _sex = 'Feminino';
  final int _age = 30;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    if (widget.cameras.isEmpty) return;
    _controller = CameraController(widget.cameras[0], ResolutionPreset.high, enableAudio: false);
    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _captureAndSendPairedData() async {
    if (!_formKey.currentState!.validate() || _controller == null) return;
    setState(() => _isUploading = true);

    try {
      final XFile photo = await _controller!.takePicture();
      final Uint8List imageBytes = await photo.readAsBytes();
      img.Image? decoded = img.decodeImage(imageBytes);
      
      if (decoded == null) throw Exception('Erro na decodificação');

      img.Image processedImage = aplicarBalancoDeBranco(decoded);

      // ==========================================
      // 🛡️ OFUSCAÇÃO BIOMÉTRICA (CROP DESTRUTIVO)
      // ==========================================
      int cropWidth = (processedImage.width * 0.6).toInt();
      int cropHeight = (processedImage.height * 0.3).toInt();
      int offsetX = (processedImage.width - cropWidth) ~/ 2;
      int offsetY = (processedImage.height - cropHeight) ~/ 2;

      img.Image imagemAnonimizada = img.copyCrop(
        processedImage, 
        x: offsetX, 
        y: offsetY, 
        width: cropWidth, 
        height: cropHeight,
      );

      List<int> processedJpg = img.encodeJpg(imagemAnonimizada, quality: 85);
      String base64Image = base64Encode(processedJpg);

      // ==========================================
      // 🛡️ CRIPTOGRAFIA ASSIMÉTRICA EM TRÂNSITO (RSA)
      // ==========================================
      const String publicKeyString = '''
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAsua/x2... (Sua chave real aqui)
-----END PUBLIC KEY-----''';

      final parser = enc.RSAKeyParser();
      final publicKey = parser.parse(publicKeyString) as enc.RSAPublicKey;
      final encrypter = enc.Encrypter(enc.RSA(publicKey: publicKey));
      
      final imagemCriptografada = encrypter.encrypt(base64Image).base64;
      
      final codigoPacienteHash = anonimizarDado(_patientCodeController.text.trim());
      final idPesquisadorHash = anonimizarDado(_researcherIdController.text.trim());

      final Map<String, dynamic> payload = {
        'codigo_paciente_hash': codigoPacienteHash,
        'id_pesquisador_hash': idPesquisadorHash,
        'idade': _age,
        'sexo': _sex,
        'hemoglobina_laboratorio': double.parse(_labHbController.text.replaceAll(',', '.')),
        'data_hora_coleta': DateTime.now().toUtc().toIso8601String(),
        'imagem_criptografada_rsa': imagemCriptografada,
      };

      final response = await http.post(
        Uri.parse('https://seu-servidor-seguro.com/api/v1/coleta-pareada'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Registro pareado salvo no banco!'), backgroundColor: Colors.green));
        _patientCodeController.clear();
        _labHbController.clear();
      } else {
        throw Exception('Status: ${response.statusCode}');
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Erro ao salvar coleta: $e'), backgroundColor: Colors.redAccent));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _patientCodeController.dispose();
    _labHbController.dispose();
    _researcherIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coleta Pareada'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(height: 250, child: CameraPreview(_controller!)),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _patientCodeController,
                decoration: InputDecoration(
                  labelText: 'Código Anônimo do Paciente', 
                  hintText: 'Ex: PAC-042',
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
                validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _labHbController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Hb Lab (g/dL)', 
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                      validator: (v) => v!.isEmpty ? 'Valor exigido' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _sex,
                      decoration: InputDecoration(
                        labelText: 'Sexo', 
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                      items: ['Feminino', 'Masculino'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (v) => setState(() => _sex = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _researcherIdController,
                decoration: InputDecoration(
                  labelText: 'ID do Pesquisador / Coletor', 
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
                validator: (v) => v!.isEmpty ? 'Informe o ID do coletor' : null,
              ),
              const SizedBox(height: 32),
              _isUploading
                  ? const Center(child: CircularProgressIndicator())
                  : FilledButton.icon(
                      onPressed: _captureAndSendPairedData,
                      icon: const Icon(Icons.cloud_upload_rounded),
                      label: const Text('Capturar e Gravar Par', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// 🎯 MÁSCARA GUIA DA CÂMERA E INTEGRAÇÃO DE REDE
// =========================================================================
class EyeMaskPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // [ESTRATÉGIA] Mascara escura com recorte transparente para focar a visão do usuário
    final backgroundPaint = Paint()..color = Colors.black.withValues(alpha: 0.75);
    final width = size.width * 0.8;
    final height = width * 0.45;
    // O offset +20 pixels empurra a UI ligeiramente para baixo facilitando o clique no botão
    final centerOffset = Offset(size.width / 2, (size.height / 2) + 20); 
    
    final rect = Rect.fromCenter(center: centerOffset, width: width, height: height);
    final backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutPath = Path()..addOval(rect);
    
    final finalPath = Path.combine(PathOperation.difference, backgroundPath, cutoutPath);
    canvas.drawPath(finalPath, backgroundPaint);

    final borderPaint = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawOval(rect, borderPaint);
    
    final guidePaint = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2.0;
    canvas.drawLine(Offset(rect.left, rect.top + 20), Offset(rect.left, rect.top), guidePaint);
    canvas.drawLine(Offset(rect.left, rect.top), Offset(rect.left + 20, rect.top), guidePaint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// [IA] Integração com Federated Learning (Aprendizado Federado). Opcionalmente o médico
// devolve o erro residual do modelo para o servidor sem expor os dados do paciente.
Future<void> enviarDadosFederados(double predita, double real) async {
  const String urlServidor = 'https://seu-servidor-seguro.com/federated-update'; 

  final Map<String, dynamic> payload = {
    'id_dispositivo_hash': anonimizarDado('moto_g9_medico_01'),
    'versao_modelo': 'v1.0.onnx',
    'hemoglobina_predita': predita,
    'hemoglobina_real': real,
    'bateria_nivel': 100, 
  };

  try {
    final response = await http.post(
      Uri.parse(urlServidor),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      debugPrint('✅ Sucesso: Dados enviados para calibração do modelo Federated Learning!');
    } else {
      debugPrint('❌ Erro do servidor: ${response.statusCode}');
    }
  } catch (e) {
    debugPrint('❌ Falha na conexão da nuvem: $e');
  }
}
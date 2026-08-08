import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class DetectorConjuntiva extends StatefulWidget {
  final List<CameraDescription> cameras;
  
  // Callback para enviar o frame aprovado de volta para a TelaExame (e para o ONNX)
  final Function(CameraImage imagemAprovada) onFrameAprovado;

  const DetectorConjuntiva({
    super.key, 
    required this.cameras,
    required this.onFrameAprovado,
  });

  @override
  State<DetectorConjuntiva> createState() => _DetectorConjuntivaState();
}

class _DetectorConjuntivaState extends State<DetectorConjuntiva> {
  CameraController? _controladorCamera;
  late FaceDetector _detectorFacial;
  
  // BARREIRA 2: Gerenciamento de Estado de Frames (Drop Frames)
  bool _estaProcessandoQuadro = false;
  String _statusValidacao = 'Iniciando câmera...';

  @override
  void initState() {
    super.initState();
    _inicializarDependencias();
  }

  Future<void> _inicializarDependencias() async {
    // 1. Configura o ML Kit para detecção precisa e classificação (olhos abertos)
    final options = FaceDetectorOptions(
      enableLandmarks: true,
      enableClassification: true, 
      performanceMode: FaceDetectorMode.accurate,
    );
    _detectorFacial = FaceDetector(options: options);

    // 2. Busca a câmera frontal
    final cameraFrontal = widget.cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.front,
      orElse: () => widget.cameras.first,
    );

    // 3. Inicializa o controlador
    _controladorCamera = CameraController(
      cameraFrontal,
      ResolutionPreset.medium, // Medium (aprox. 480p ou 720p) é ideal para IA
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid 
          ? ImageFormatGroup.yuv420 
          : ImageFormatGroup.bgra8888,
    );

    try {
      await _controladorCamera!.initialize();
      if (!mounted) return;

      // 4. Inicia o Stream de Vídeo
      _controladorCamera!.startImageStream(_processarQuadro);
      _atualizarStatus('Alinhe seu rosto na câmera');
    } catch (e) {
      _atualizarStatus('Erro ao iniciar câmera: $e');
    }
  }

  // Função central disparada a cada novo frame
  Future<void> _processarQuadro(CameraImage imagem) async {
    // BARREIRA 2 (Drop Frames): Evita enfileirar processamento se a CPU estiver ocupada
    if (_estaProcessandoQuadro) return;
    _estaProcessandoQuadro = true;

    try {
      // Converte o frame bruto do Flutter para o formato do Google ML Kit
      final inputImage = _converterCameraImageParaInputImage(imagem);
      if (inputImage == null) return;

      // BARREIRA 1 (Data Quality): Tenta detectar rostos
      final rostos = await _detectorFacial.processImage(inputImage);

      if (rostos.isEmpty) {
        _atualizarStatus('Nenhum rosto detectado');
        return;
      }

      final rosto = rostos.first;

      // Exige que o rosto esteja razoavelmente reto (evita fotos de perfil)
      if (rosto.headEulerAngleY != null && rosto.headEulerAngleY!.abs() > 10) {
        _atualizarStatus('Olhe diretamente para a frente');
        return;
      }

      // Valida se os olhos estão visíveis e abertos
      if (rosto.leftEyeOpenProbability != null && rosto.leftEyeOpenProbability! < 0.8) {
        _atualizarStatus('Mantenha os olhos bem abertos');
        return;
      }

      _atualizarStatus('Condições ideais! Capturando...');
      
      // DELEGAÇÃO: Envia o frame bruto de volta para quem chamou este widget 
      // para que a conversão matemática e a chamada ao ONNX sejam feitas lá.
      widget.onFrameAprovado(imagem);
      
    } catch (e) {
      debugPrint('Erro na análise facial: $e');
    } finally {
      // Libera o bloqueio para permitir a análise do próximo frame
      _estaProcessandoQuadro = false;
    }
  }

  /// Converte CameraImage para InputImage (Padrão necessário para o ML Kit)
  InputImage? _converterCameraImageParaInputImage(CameraImage image) {
    final camera = widget.cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.front,
      orElse: () => widget.cameras.first,
    );
    
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null || (Platform.isAndroid && format != InputImageFormat.yuv_420_888) || (Platform.isIOS && format != InputImageFormat.bgra8888)) {
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

  void _atualizarStatus(String status) {
    if (_statusValidacao != status && mounted) {
      setState(() {
        _statusValidacao = status;
      });
    }
  }

  @override
  void dispose() {
    _controladorCamera?.stopImageStream();
    _controladorCamera?.dispose();
    _detectorFacial.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controladorCamera == null || !_controladorCamera!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
    }

    return Column(
      children: [
        // Preview da Câmera com proporção correta
        Expanded(
          child: Container(
            color: Colors.black,
            alignment: Alignment.center,
            child: AspectRatio(
              aspectRatio: 1 / _controladorCamera!.value.aspectRatio,
              child: CameraPreview(_controladorCamera!),
            ),
          ),
        ),
        
        // Barra Inferior de Status / Feedback em Tempo Real
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: const BoxDecoration(
            color: Colors.black,
            border: Border(top: BorderSide(color: Colors.redAccent, width: 3)),
          ),
          child: Text(
            _statusValidacao,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white, 
              fontSize: 18, 
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
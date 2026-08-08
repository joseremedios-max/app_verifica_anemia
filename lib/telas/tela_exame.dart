import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:app_anemia/servicos/motor_diagnostico.dart';
import 'package:app_anemia/servicos/processador_imagem.dart'; 
import 'package:app_anemia/visao/detector_conjuntiva.dart'; 


class TelaExame extends StatefulWidget {
  final List<CameraDescription> cameras;
  final double idade;
  final double sexo;

  const TelaExame({
    super.key,
    required this.cameras,
    required this.idade,
    required this.sexo,
  });

  @override
  State<TelaExame> createState() => _TelaExameState();
}

class _TelaExameState extends State<TelaExame> {
  // Instancia a inteligência artificial[cite: 5]
  final MotorDiagnosticoAnemia _motorIA = MotorDiagnosticoAnemia();
  String _resultadoTexto = 'Aguardando exame...';
  bool _estaProcessando = false;
  bool _mostrarCamera = true; 

  @override
  void initState() {
    super.initState();
    // Carrega os modelos ONNX assim que a tela abrir[cite: 5]
    _inicializarInteligenciaArtificial();
  }

  // Função auxiliar para capturar possíveis erros no carregamento[cite: 5]
  Future<void> _inicializarInteligenciaArtificial() async {
    try {
      await _motorIA.inicializarModelos();
    } catch (e) {
      setState(() {
        _resultadoTexto = 'Erro ao carregar modelos: $e';
        _mostrarCamera = false;
      });
    }
  }

  @override
  void dispose() {
    // CRÍTICO: Libera a memória RAM ocupada pelo ONNX em C++[cite: 5]
    _motorIA.fecharMotor();
    super.dispose();
  }

  // O ciclo completo ocorre aqui quando a barreira facial do ML Kit é vencida
  Future<void> _iniciarPipelineDiagnostico(CameraImage imagemAprovada) async {
    // Evita múltiplos processamentos se um já estiver rolando
    if (_estaProcessando) return;

    setState(() {
      _estaProcessando = true;
      _mostrarCamera = false; // Esconde a câmera para mostrar a tela de load
      _resultadoTexto = 'Traduzindo formato da imagem (YUV -> Tensor)...';
    });

    try {
      // 1. A Costura Matemática (Roda no Isolate, a UI não congela)
      final tensorImagem = await ProcessadorImagem.converterParaTensorIA(imagemAprovada);

      setState(() {
        _resultadoTexto = 'Analisando redes neurais (ViT + XGBoost)...';
      });

      // 2. Inferência Edge-AI com os dados reais
      double hemoglobina = await _motorIA.estimarHemoglobina(
        tensorImagem: tensorImagem,
        idade: widget.idade, 
        sexo: widget.sexo,   
      );

      setState(() {
        _resultadoTexto = 'Hemoglobina: ${hemoglobina.toStringAsFixed(2)} g/dL';
      });

    } catch (e) {
      setState(() {
        _resultadoTexto = 'Falha no diagnóstico: $e';
        _mostrarCamera = true; // Volta para tentar de novo em caso de erro
      });
    } finally {
      setState(() {
        _estaProcessando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exame Virtual', style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: true,
      ),
      // Alterna dinamicamente entre a visão da câmera e o card de resultado
      body: _mostrarCamera
          ? DetectorConjuntiva(
              cameras: widget.cameras,
              onFrameAprovado: _iniciarPipelineDiagnostico, 
            )
          : _construirTelaDeResultado(),
    );
  }

  // Componente extraído para manter o build principal limpo
  Widget _construirTelaDeResultado() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Ícone Principal de Destaque[cite: 5]
            if (_estaProcessando)
              const Center(
                child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 4),
              )
            else
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bloodtype_rounded, 
                  size: 80, 
                  color: Colors.redAccent,
                ),
              ),
            const SizedBox(height: 32),
            
            // Card de Resultado[cite: 5]
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3), width: 1.5),
              ),
              child: Column(
                children: [
                  const Text(
                    'Status do Diagnóstico',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _resultadoTexto,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            
            // Botão para Refazer o Exame
            if (!_estaProcessando)
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _mostrarCamera = true; 
                    _resultadoTexto = 'Aguardando exame...';
                  });
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text(
                  'Repetir Exame',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
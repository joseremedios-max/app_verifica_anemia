import 'package:flutter/foundation.dart'; // Necessário para o debugPrint
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';

/// Classe responsável por gerenciar o motor de inferência local (Edge-AI)
/// Utiliza a fusão de um Vision Transformer (ViT) com um modelo tabular (XGBoost).
class MotorDiagnosticoAnemia {
  OrtSession? _sessaoViT;
  OrtSession? _sessaoXGBoost;

  /// Inicializa o motor do ONNX e carrega os dois modelos na memória RAM
  Future<void> inicializarModelos() async {
    try {
      // Inicializa o ambiente do ONNX Runtime no celular[cite: 3]
      OrtEnv.instance.init();

      // Carrega os modelos da pasta assets[cite: 3]
      final vitBytes = await rootBundle.load('assets/models/vit_model.onnx');
      final xgbBytes = await rootBundle.load('assets/models/xgboost_model.onnx');

      // Cria as opções de sessão exigidas pelo pacote[cite: 3]
      final sessionOptions = OrtSessionOptions();

      // Passamos os bytes e as opções de sessão para instanciar os modelos[cite: 3]
      _sessaoViT = OrtSession.fromBuffer(vitBytes.buffer.asUint8List(), sessionOptions);
      _sessaoXGBoost = OrtSession.fromBuffer(xgbBytes.buffer.asUint8List(), sessionOptions);
      
      // Libera a memória das opções de sessão após usá-las[cite: 3]
      sessionOptions.release();

      debugPrint('✅ Modelos ViT e XGBoost carregados com sucesso no ONNX Runtime!');
    } catch (e) {
      debugPrint('❌ Erro ao inicializar modelos ONNX: $e');
      rethrow; // Repassa o erro para a UI tratar
    }
  }

  /// Realiza a inferência multimodal (Imagem + Dados Demográficos)
  Future<double> estimarHemoglobina({
    required List<List<List<List<double>>>> tensorImagem, // Formato [1, 3, 224, 224][cite: 3]
    required double idade, //[cite: 3]
    required double sexo,  // Ex: 0.0 para feminino, 1.0 para masculino[cite: 3]
  }) async {
    
    if (_sessaoViT == null || _sessaoXGBoost == null) {
      throw Exception('Os modelos não foram inicializados. Chame inicializarModelos() primeiro.');
    }

    OrtValueTensor? inputViT;
    OrtValueTensor? inputXGBoost;
    final runOptions = OrtRunOptions(); //[cite: 3]
    
    List<OrtValue?> saidasViT = [];
    List<OrtValue?> saidasXGBoost = [];

    try {
      // ==========================================
      // PASSO 1: Inferência do Vision Transformer
      // ==========================================
      inputViT = OrtValueTensor.createTensorWithDataList(tensorImagem); //[cite: 3]
      final inputsViT = {'input_imagem': inputViT}; //[cite: 3]
      
      saidasViT = _sessaoViT!.run(runOptions, inputsViT); //[cite: 3]
      
      // Extrai o Feature Vector (predição parcial do ViT)[cite: 3]
      final vitOutputValue = saidasViT[0]?.value as List<List<double>>?;
      if (vitOutputValue == null || vitOutputValue.isEmpty) {
        throw Exception('Falha ao extrair features do ViT.');
      }
      final vitFeature = vitOutputValue[0][0]; //[cite: 3]

      // ==========================================
      // PASSO 2: Fusão dos Dados (Multimodal)
      // ==========================================
      // Concatena a extração visual do ViT com os dados demográficos[cite: 3]
      List<double> vetorCombinado = [vitFeature, idade, sexo]; //[cite: 3]
      inputXGBoost = OrtValueTensor.createTensorWithDataList([vetorCombinado]); //[cite: 3]

      // ==========================================
      // PASSO 3: Inferência do XGBoost (Resultado Final)
      // ==========================================
      final inputsXGBoost = {'features_entrada': inputXGBoost}; //[cite: 3]
      saidasXGBoost = _sessaoXGBoost!.run(runOptions, inputsXGBoost); //[cite: 3]
      
      // Extrai o valor final da hemoglobina estimada[cite: 3]
      final xgbOutputValue = saidasXGBoost[0]?.value as List<List<double>>?;
      if (xgbOutputValue == null || xgbOutputValue.isEmpty) {
        throw Exception('Falha ao gerar o resultado final no XGBoost.');
      }
      
      final hemoglobinaEstimada = xgbOutputValue[0][0]; //[cite: 3]

      return hemoglobinaEstimada;

    } catch (e) {
      debugPrint('❌ Erro durante a inferência: $e');
      rethrow;
    } finally {
      // ==========================================
      // CLEANUP: Prevenção rigorosa de Memory Leak
      // ==========================================
      inputViT?.release(); //[cite: 3]
      inputXGBoost?.release(); //[cite: 3]
      runOptions.release(); //[cite: 3]
      
      for (var out in saidasViT) { 
        out?.release(); //[cite: 3]
      }
      for (var out in saidasXGBoost) { 
        out?.release(); //[cite: 3]
      }
    }
  }

  /// Limpa as sessões quando o app for fechado para evitar memory leak no C++[cite: 3]
  void fecharMotor() {
    try {
      _sessaoViT?.release(); //[cite: 3]
      _sessaoXGBoost?.release(); //[cite: 3]
      OrtEnv.instance.release(); //[cite: 3]
      debugPrint('Motor ONNX encerrado e memória liberada.');
    } catch (e) {
      debugPrint('Erro ao liberar motor ONNX: $e');
    }
  }
}
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ProcessadorImagem {
  /// Executa a conversão matemática pesada em uma Thread separada (Isolate)
  /// para evitar que a UI congele durante o processamento.
  static Future<List<List<List<List<double>>>>> converterParaTensorIA(CameraImage imagemCamera) async {
    // ignore: unnecessary_await_in_return
    return await compute(_processamentoPesado, imagemCamera);
  }

  /// Função executada no Isolate. 
  /// ATENÇÃO: Nenhuma variável de estado do Flutter pode ser acessada aqui.
  static List<List<List<List<double>>>> _processamentoPesado(CameraImage imagemCamera) {
    img.Image? imagemOriginal;

    // 1. Extração de Pixels baseada na Plataforma
    if (Platform.isAndroid && imagemCamera.format.group == ImageFormatGroup.yuv420) {
      imagemOriginal = _converterYUV420ParaImage(imagemCamera);
    } else if (Platform.isIOS && imagemCamera.format.group == ImageFormatGroup.bgra8888) {
      imagemOriginal = _converterBGRAParaImage(imagemCamera);
    }

    if (imagemOriginal == null) {
      throw Exception('Formato de imagem não suportado pela matemática do tensor.');
    }

    // 2. Redimensionamento e Corte (Crop) para 224x224
    // O ViT exige um quadrado perfeito de 224x224 pixels.
    final imagemRedimensionada = img.copyResizeCropSquare(imagemOriginal, size: 224);

    // 3. Construção do Tensor NCHW [1, 3, 224, 224]
    // N = Batch (1), C = Channels (3: R,G,B), H = Height (224), W = Width (224)
    List<List<double>> canalR = List.generate(224, (_) => List.filled(224, 0.0));
    List<List<double>> canalG = List.generate(224, (_) => List.filled(224, 0.0));
    List<List<double>> canalB = List.generate(224, (_) => List.filled(224, 0.0));

    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        final pixel = imagemRedimensionada.getPixel(x, y);
        
        // Normalização (0 a 1) - Dividindo os valores RGB por 255.0
        canalR[y][x] = pixel.r / 255.0;
        canalG[y][x] = pixel.g / 255.0;
        canalB[y][x] = pixel.b / 255.0;
      }
    }

    return [
      [canalR, canalG, canalB],
    ];
  }

  /// Converte o formato YUV_420_888 (Android) para o objeto img.Image RGB
  static img.Image _converterYUV420ParaImage(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final uvRowStride = image.planes[1].bytesPerRow;
    final uvPixelStride = image.planes[1].bytesPerPixel ?? 1;
    
    final imgOriginal = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      int pY = y * image.planes[0].bytesPerRow;
      int pUV = (y >> 1) * uvRowStride;

      for (int x = 0; x < width; x++) {
        int yp = image.planes[0].bytes[pY];
        int up = image.planes[1].bytes[pUV];
        int vp = image.planes[2].bytes[pUV];

        // Conversão matemática YUV para RGB
        int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
        int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91).round().clamp(0, 255);
        int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);

        imgOriginal.setPixelRgb(x, y, r, g, b);
        
        pY++;
        if ((x % 2) != 0) {
          pUV += uvPixelStride;
        }
      }
    }
    return imgOriginal;
  }

  /// Converte BGRA8888 (iOS) para o objeto img.Image RGB
  static img.Image _converterBGRAParaImage(CameraImage image) {
    return img.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: image.planes[0].bytes.buffer,
      order: img.ChannelOrder.bgra,
    );
  }
}
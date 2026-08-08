import 'package:app_anemia/telas/tela_exame.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';


class TelaDadosPaciente extends StatefulWidget {
  final List<CameraDescription> cameras;

  const TelaDadosPaciente({super.key, required this.cameras});

  @override
  State<TelaDadosPaciente> createState() => _TelaDadosPacienteState();
}

class _TelaDadosPacienteState extends State<TelaDadosPaciente> {
  final _formKey = GlobalKey<FormState>();
  double? _idade;
  double? _sexo; // 0.0 para feminino, 1.0 para masculino

  Future<void> _iniciarExame() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    // Solicita permissão da câmera no nível do Sistema Operacional
    var status = await Permission.camera.request();
    
    if (status.isGranted) {
      if (!mounted) return;
      // Navega para a tela da câmera passando os dados reais
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TelaExame(
            cameras: widget.cameras,
            idade: _idade!,
            sexo: _sexo!,
          ),
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A permissão da câmera é obrigatória para o exame.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dados do Paciente'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.person_search_rounded, size: 80, color: Colors.redAccent),
              const SizedBox(height: 32),
              
              // Input de Idade
              TextFormField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Idade (anos)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  prefixIcon: const Icon(Icons.cake_rounded),
                ),
                validator: (valor) {
                  if (valor == null || valor.isEmpty) return 'Informe a idade';
                  if (double.tryParse(valor) == null) return 'Digite um número válido';
                  return null;
                },
                onSaved: (valor) => _idade = double.parse(valor!),
              ),
              const SizedBox(height: 16),
              
              // Input de Sexo
              DropdownButtonFormField<double>(
                decoration: InputDecoration(
                  labelText: 'Sexo Biológico',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  prefixIcon: const Icon(Icons.medical_information_rounded),
                ),
                items: const [
                  DropdownMenuItem(value: 0.0, child: Text('Feminino')),
                  DropdownMenuItem(value: 1.0, child: Text('Masculino')),
                ],
                validator: (valor) => valor == null ? 'Selecione o sexo' : null,
                onChanged: (valor) {},
                onSaved: (valor) => _sexo = valor,
              ),
              const SizedBox(height: 48),
              
              FilledButton.icon(
                onPressed: _iniciarExame,
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('Continuar para a Câmera', style: TextStyle(fontSize: 18)),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
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
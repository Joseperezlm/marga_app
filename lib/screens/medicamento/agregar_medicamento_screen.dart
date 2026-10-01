import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AgregarMedicamentoScreen extends StatefulWidget {
  final int familiarId;
  const AgregarMedicamentoScreen({Key? key, required this.familiarId}) : super(key: key);

  @override
  _AgregarMedicamentoScreenState createState() => _AgregarMedicamentoScreenState();
}

class _AgregarMedicamentoScreenState extends State<AgregarMedicamentoScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreMedController = TextEditingController();
  final TextEditingController _dosisController = TextEditingController();
  
  int? _adultoMayorSeleccionadoId;
  List<dynamic> _listaAdultosVinculados = [];
  bool _isLoadingAdultos = true;
  bool _isSaving = false;

  TimeOfDay _horaSeleccionada = const TimeOfDay(hour: 8, minute: 0);
  int _recurrenciaHoras = 8;

  // REEMPLAZA CON TU IP LOCAL DE XAMPP
  final String _baseUri = "http://172.22.16.1/derek_solutions_api/";

  @override
  void initState() {
    super.initState();
    _cargarAdultosVinculados();
  }

  // Carga los abuelitos vinculados activos desde la base de datos
  Future<void> _cargarAdultosVinculados() async {
    setState(() { _isLoadingAdultos = true; });
    print("=== CARGANDO ABUELITOS VINCULADOS ===");
    print("Enviando familiar_id: ${widget.familiarId}");

    try {
      final response = await http.get(
        Uri.parse("${_baseUri}obtener_vinculados.php?familiar_id=${widget.familiarId}"),
      );

      print("Respuesta de obtener_vinculados.php: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _listaAdultosVinculados = data['adultos'];
            _isLoadingAdultos = false;
          });
          return;
        }
      }
    } catch (e) {
      print("Error al cargar vinculados: $e");
    }
    
    setState(() { _isLoadingAdultos = false; });
  }

  Future<void> _seleccionarHora(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _horaSeleccionada,
    );
    if (picked != null) {
      setState(() { _horaSeleccionada = picked; });
    }
  }

  Future<void> _guardarMedicamento() async {
    if (!_formKey.currentState!.validate()) return;
    if (_adultoMayorSeleccionadoId == null) {
      _showSnackbar("Por favor, selecciona a un Adulto Mayor", Colors.orange);
      return;
    }

    setState(() { _isSaving = true; });

    final String horaFormateada = "${_horaSeleccionada.hour.toString().padLeft(2, '0')}:${_horaSeleccionada.minute.toString().padLeft(2, '0')}:00";

    try {
      final Map<String, dynamic> bodyData = {
        "adulto_mayor_id": _adultoMayorSeleccionadoId,
        "nombre": _nombreMedController.text.trim(),
        "dosis": _dosisController.text.trim(),
        "horario": horaFormateada,
        "recurrencia_horas": _recurrenciaHoras,
      };

      print("Enviando medicamento a guardar_medicamento.php: ${jsonEncode(bodyData)}");

      final response = await http.post(
        Uri.parse("${_baseUri}guardar_medicamento.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(bodyData),
      );

      print("Respuesta de guardar_medicamento.php: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _showSnackbar("¡Medicamento asignado correctamente!", Colors.green);
          Navigator.pop(context, true); 
        } else {
          _showSnackbar(data['message'] ?? "Error al guardar", Colors.redAccent);
        }
      }
    } catch (e) {
      _showSnackbar("Error de red al intentar guardar", Colors.redAccent);
    } finally {
      setState(() { _isSaving = false; });
    }
  }

  void _showSnackbar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Programar Medicamento"), 
        backgroundColor: Colors.blue[700], 
        foregroundColor: Colors.white,
        actions: [
          // Botón para refrescar la lista de abuelitos si se acaba de crear uno nuevo
          IconButton(
            icon: const Icon(Icons.refresh, size: 28),
            onPressed: _cargarAdultosVinculados,
            tooltip: "Actualizar lista de abuelitos",
          )
        ],
      ),
      body: _isLoadingAdultos
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- SELECTOR DE ADULTO MAYOR ---
                    DropdownButtonFormField<int>(
                      value: _adultoMayorSeleccionadoId,
                      decoration: const InputDecoration(
                        labelText: "Asignar al Adulto Mayor",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_search_outlined),
                      ),
                      hint: const Text("Selecciona un abuelito enlazado"),
                      items: _listaAdultosVinculados.map<DropdownMenuItem<int>>((dynamic adulto) {
                        return DropdownMenuItem<int>(
                          value: int.parse(adulto['id'].toString()),
                          child: Text(adulto['nombre'].toString()),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() { _adultoMayorSeleccionadoId = val; });
                      },
                      validator: (value) => value == null ? "Este campo es requerido" : null,
                    ),
                    const SizedBox(height: 20),

                    // --- CAMPOS TRADICIONALES ---
                    TextFormField(
                      controller: _nombreMedController,
                      decoration: const InputDecoration(labelText: "Nombre del Medicamento", border: OutlineInputBorder(), prefixIcon: Icon(Icons.medication)),
                      validator: (v) => v!.isEmpty ? "Ingresa el nombre del medicamento" : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _dosisController,
                      decoration: const InputDecoration(labelText: "Dosis (Ej: 1 tableta, 5ml)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.shutter_speed)),
                      validator: (v) => v!.isEmpty ? "Ingresa la dosis requerida" : null,
                    ),
                    const SizedBox(height: 20),
                    
                    ListTile(
                      title: Text("Hora de toma: ${_horaSeleccionada.format(context)}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                      trailing: const Icon(Icons.access_time, color: Colors.blue),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey[400]!)),
                      onTap: () => _seleccionarHora(context),
                    ),
                    const SizedBox(height: 20),

                    DropdownButtonFormField<int>(
                      value: _recurrenciaHoras,
                      decoration: const InputDecoration(labelText: "Frecuencia de repetición", border: OutlineInputBorder(), prefixIcon: Icon(Icons.repeat)),
                      items: [4, 6, 8, 12, 24].map((int value) {
                        return DropdownMenuItem<int>(value: value, child: Text("Cada $value horas"));
                      }).toList(),
                      onChanged: (val) => setState(() { _recurrenciaHoras = val!; }),
                    ),
                    const SizedBox(height: 35),

                    ElevatedButton(
                      onPressed: _isSaving ? null : _guardarMedicamento,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16), 
                        backgroundColor: Colors.green[700], 
                        foregroundColor: Colors.white, 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                      child: _isSaving 
                          ? const CircularProgressIndicator(color: Colors.white) 
                          : const Text("Guardar y Sincronizar", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
            ),
    );
  }
}
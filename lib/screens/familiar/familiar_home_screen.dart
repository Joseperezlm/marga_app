import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart'; // Control de sesión local
import 'package:marga_app/screens/medicamento/agregar_medicamento_screen.dart';
import 'package:marga_app/screens/codigo/generar_codigo_screen.dart';

class FamiliarHomeScreen extends StatefulWidget {
  final int familiarId;
  final String nombreFamiliar;

  const FamiliarHomeScreen({
    Key? key,
    required this.familiarId,
    required this.nombreFamiliar,
  }) : super(key: key);

  @override
  _FamiliarHomeScreenState createState() => _FamiliarHomeScreenState();
}

class _FamiliarHomeScreenState extends State<FamiliarHomeScreen> {
  bool _isLoading = true;
  List<dynamic> _medicamentosAsignados = [];

  // REEMPLAZA CON TU IP LOCAL DE XAMPP
  final String _baseUri = "http://192.168.1.155/derek_solutions_api/";

  @override
  void initState() {
    super.initState();
    _obtenerMedicamentosGlobales();
  }

  // Obtiene los medicamentos de TODOS los adultos mayores vinculados a este familiar
  Future<void> _obtenerMedicamentosGlobales() async {
    setState(() { _isLoading = true; });
    try {
      final response = await http.get(
        Uri.parse("${_baseUri}obtener_medicamentos_adulto.php?familiar_id=${widget.familiarId}"),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _medicamentosAsignados = data['medicamentos'];
          });
        }
      }
    } catch (e) {
      print("Error de red al obtener medicamentos: $e");
      // Tarjetas de prueba locales por si el servidor no responde
      setState(() {
        _medicamentosAsignados = [
          {"nombre": "Paracetamol", "dosis": "1 tableta de 500mg", "horario": "08:00 AM", "paciente": "Abuelo Luis"},
          {"nombre": "Metformina", "dosis": "Media tableta", "horario": "02:00 PM", "paciente": "Abuela María"},
        ];
      });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  // Borra la persistencia de datos localmente y redirige a la pantalla inicial/login
  Future<void> _cerrarSesionFamiliar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // Limpia la sesión completa del dispositivo
    } catch (e) {
      print("Error al limpiar datos locales de sesión: $e");
    }

    if (mounted) {
      // Limpia todo el historial de navegación para evitar regresos accidentales
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text("Hola, ${widget.nombreFamiliar}"),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar Medicamentos',
            onPressed: _obtenerMedicamentosGlobales,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar Sesión',
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Text("Cerrar Sesión"),
                    content: const Text("¿Estás seguro de que deseas salir del perfil familiar?"),
                    actions: [
                      TextButton(
                        child: const Text("Cancelar"),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      TextButton(
                        child: const Text("Salir", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.of(context).pop(); // Cierra el Modal emergente
                          _cerrarSesionFamiliar();    // Ejecuta la limpieza
                        },
                      ),
                    ],
                  );
                },
              );
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- BLOQUE 1: ACCIONES RÁPIDAS ---
            Text(
              "Acciones de Gestión",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue[900]),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                // Botón 1: Agregar Medicamento
                Expanded(
                  child: _buildMenuButton(
                    context,
                    icon: Icons.medical_services_outlined,
                    label: "Agregar\nMedicamento",
                    color: Colors.green,
                    onTap: () async {
                      final bool? resultado = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => AgregarMedicamentoScreen(familiarId: widget.familiarId)),
                      );
                      // Si se guardó un medicamento con éxito, actualizamos la lista global
                      if (resultado == true) {
                        _obtenerMedicamentosGlobales();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Botón 2: Vincular Paciente de la Tercera Edad CORREGIDO
                Expanded(
                  child: _buildMenuButton(
                    context,
                    icon: Icons.qr_code_scanner_outlined,
                    label: "Vincular\nAdulto Mayor",
                    color: Colors.blue,
                    onTap: () async {
                      // Hacemos la llamada asíncrona esperando la señal del "Terminar y Salir"
                      final bool? seAgregoNuevo = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => GenerarCodigoScreen(familiarId: widget.familiarId)),
                      );
                      
                      // Si el código retornó true, refresca las listas del servidor de inmediato
                      if (seAgregoNuevo == true) {
                        print("Nuevo Adulto Mayor registrado detectado en el Home. Actualizando caché...");
                        _obtenerMedicamentosGlobales();
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),

            // --- BLOQUE 2: LISTADO ---
            Text(
              "Medicamentos Asignados Actuales",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue[900]),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _medicamentosAsignados.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          itemCount: _medicamentosAsignados.length,
                          itemBuilder: (context, index) {
                            final med = _medicamentosAsignados[index];
                            return _buildMedicamentoCard(med);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context, {required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicamentoCard(Map<String, dynamic> med) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Colors.blue[50],
          child: Icon(Icons.vaccines_outlined, color: Colors.blue[700]),
        ),
        title: Text(med['nombre'] ?? "Sin nombre", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Dosis: ${med['dosis'] ?? 'N/A'}"),
            if (med['paciente'] != null)
              Text("Para: ${med['paciente']}", style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13)),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: Colors.blue[900], borderRadius: BorderRadius.circular(8)),
          child: Text(med['horario'] ?? "00:00", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_late_outlined, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 10),
          Text("No hay medicamentos asignados aún.", style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }
}
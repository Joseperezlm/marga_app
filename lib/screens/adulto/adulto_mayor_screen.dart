import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AdultoMayorScreen extends StatefulWidget {
  const AdultoMayorScreen({Key? key}) : super(key: key);

  @override
  _AdultoMayorScreenState createState() => _AdultoMayorScreenState();
}

class _AdultoMayorScreenState extends State<AdultoMayorScreen> {
  final TextEditingController _codigoController = TextEditingController();
  
  bool _estaVinculado = false;
  int? _adultoMayorId;
  String _nombreAdulto = "";
  
  bool _isLoading = false;
  List<dynamic> _misMedicamentos = [];

  // IP de tu servidor local XAMPP
  final String _baseUri = "http://172.22.16.1/derek_solutions_api/";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verificarSesionLocal();
    });
  }

  // Comprueba si el dispositivo ya se encuentra vinculado en el almacenamiento local
  Future<void> _verificarSesionLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final int? idGuardado = prefs.getInt('adulto_mayor_id');
      final String? nombreGuardado = prefs.getString('adulto_mayor_nombre');

      print("=== PERSISTENCIA LOCAL ===");
      print("ID Guardado: $idGuardado");
      print("Nombre Guardado: $nombreGuardado");

      if (idGuardado != null && nombreGuardado != null) {
        setState(() {
          _adultoMayorId = idGuardado;
          _nombreAdulto = nombreGuardado;
          _estaVinculado = true;
        });
        _obtenerMisMedicamentos(); 
      }
    } catch (e) {
      print("Aviso: SharedPreferences no inicializado aún: $e");
    }
  }

  // Guarda las llaves de sesión localmente en formato persistente
  Future<void> _guardarSesionLocal(int id, String nombre) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('adulto_mayor_id', id);
      await prefs.setString('adulto_mayor_nombre', nombre);
      print("Datos guardados con éxito en SharedPreferences: ID $id");
    } catch (e) {
      print("Error al escribir en disco local: $e");
    }
  }

  // Envía el código de 6 dígitos introducido por el Adulto Mayor a la API PHP
 Future<void> _vincularDispositivo() async {
  if (_codigoController.text.trim().length != 6) {
    _msg("El código debe tener 6 dígitos", Colors.orange);
    return;
  }

  setState(() {
    _isLoading = true;
  });

  try {
    final url = Uri.parse("${_baseUri}vincular_codigo.php");

    print("====================================");
    print("URL: $url");
    print("CODIGO: ${_codigoController.text.trim()}");

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "codigo_vinculacion": _codigoController.text.trim(),
      }),
    );

    print("STATUS CODE: ${response.statusCode}");
    print("BODY COMPLETO:");
    print(response.body);
    print("====================================");

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 &&
        data['success'] == true) {

      final int idObtenido =
          int.parse(data['adulto_mayor_id'].toString());

      final String nombreObtenido =
          data['nombre'].toString();

      await _guardarSesionLocal(
        idObtenido,
        nombreObtenido,
      );

      setState(() {
        _adultoMayorId = idObtenido;
        _nombreAdulto = nombreObtenido;
        _estaVinculado = true;
        _isLoading = false;
      });

      _msg(
        "¡Enlace Exitoso!",
        Colors.green,
      );

      await Future.delayed(
        const Duration(milliseconds: 300),
      );

      _obtenerMisMedicamentos();

    } else {

      setState(() {
        _isLoading = false;
      });

      _msg(
        data['message'] ??
            "Código inválido",
        Colors.red,
      );
    }

  } catch (e, stackTrace) {

    print("ERROR DETECTADO:");
    print(e);
    print(stackTrace);

    setState(() {
      _isLoading = false;
    });

    _msg(
      "Error de conexión al servidor",
      Colors.red,
    );
  }
}

  // Obtiene los medicamentos correspondientes asignados por el Familiar
  Future<void> _obtenerMisMedicamentos() async {
    if (_adultoMayorId == null) return;
    
    setState(() { _isLoading = true; });
    
    final String urlFinal = "${_baseUri}obtener_medicamentos_adulto.php?adulto_mayor_id=$_adultoMayorId";
    print("Iniciando HTTP GET a URL: $urlFinal");

    try {
      final response = await http.get(Uri.parse(urlFinal));
      print("Código HTTP obtenido: ${response.statusCode}");
      print("Contenido JSON de medicamentos: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() { 
            _misMedicamentos = data['medicamentos']; 
          });
        }
      }
    } catch (e) {
      print("Error obteniendo la lista médica: $e");
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  // Limpia el almacenamiento local para reiniciar la aplicación (Pruebas de desarrollo)
  Future<void> _cerrarSesion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      print("Sesión local destruida por completo.");
    } catch (e) {
      print("Error al limpiar preferencias: $e");
    }
    setState(() {
      _estaVinculado = false;
      _adultoMayorId = null;
      _misMedicamentos = [];
      _codigoController.clear();
    });
  }

  void _msg(String texto, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto, style: const TextStyle(fontSize: 16)), 
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        title: Text(_estaVinculado ? "Mis Medicamentos" : "Configuración Inicial"),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: _estaVinculado ? [
          IconButton(icon: const Icon(Icons.sync, size: 28), onPressed: _obtenerMisMedicamentos),
          IconButton(icon: const Icon(Icons.logout), onPressed: _cerrarSesion)
        ] : null,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(24.0),
            child: _estaVinculado ? _buildListaMedicamentos() : _buildFormularioCodigo(),
          ),
    );
  }

  Widget _buildFormularioCodigo() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.lock_person_outlined, size: 80, color: Colors.blue),
        const SizedBox(height: 20),
        const Text(
          "¡Bienvenido a tu Recordatorio!", 
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87), 
          textAlign: TextAlign.center
        ),
        const SizedBox(height: 10),
        const Text(
          "Ingresa el código de 6 números que generó tu familiar en su aplicación para enlazar tu teléfono.", 
          style: TextStyle(fontSize: 16, color: Colors.black54), 
          textAlign: TextAlign.center
        ),
        const SizedBox(height: 30),
        TextField(
          controller: _codigoController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 6),
          decoration: const InputDecoration(
            counterText: "", 
            hintText: "000000", 
            border: OutlineInputBorder(), 
            fillColor: Colors.white, 
            filled: true
          ),
        ),
        const SizedBox(height: 25),
        ElevatedButton(
          onPressed: _isLoading ? null : _vincularDispositivo,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16), 
            backgroundColor: Colors.blue[800], 
            foregroundColor: Colors.white, 
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
          ),
          child: const Text("Conectar con mi Familiar", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildListaMedicamentos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Hola, $_nombreAdulto 👋", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue[900])),
        const Text("Estas son tus tomas programadas para hoy:", style: TextStyle(fontSize: 16, color: Colors.black54)),
        const SizedBox(height: 20),
        Expanded(
          child: _misMedicamentos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 70, color: Colors.green[400]),
                      const SizedBox(height: 12),
                      const Text(
                        "¡Todo listo! No tienes medicamentos pendientes.", 
                        style: TextStyle(fontSize: 18, color: Colors.black54), 
                        textAlign: TextAlign.center
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _misMedicamentos.length,
                  itemBuilder: (context, index) {
                    final med = _misMedicamentos[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 28, 
                              backgroundColor: Colors.blue[100], 
                              child: Icon(Icons.alarm, size: 32, color: Colors.blue[800])
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(med['nombre'] ?? "Sin nombre", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text("Dosis: ${med['dosis'] ?? 'N/A'}", style: const TextStyle(fontSize: 16, color: Colors.black54)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(color: Colors.blue[800], borderRadius: BorderRadius.circular(12)),
                              child: Text(
                                med['horario'] ?? "00:00", 
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
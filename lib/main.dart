import 'package:contavida/firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Contabilidad Personal',
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.black87,
      ),
      home: AuthenticationWrapper(),
    );
  }
}

class AuthenticationWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          User? user = snapshot.data;
          if (user == null) {
            return LoginScreen();
          } else {
            return HomeScreen();
          }
        }
        return Center(child: CircularProgressIndicator());
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Error al iniciar sesión')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Iniciar Sesión')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Correo Electrónico',
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Contraseña',
              ),
              obscureText: true,
            ),
            SizedBox(height: 20),
            _isLoading
                ? Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _login,
                    child: Text('Iniciar Sesión'),
                  ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RegisterScreen()),
                );
              },
              child: Text('¿No tienes cuenta? Regístrate aquí'),
            ),
          ],
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  Future<void> _register() async {
    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
      });

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Registro')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Nombre'),
            ),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _register,
              child: Text('Registrar'),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int? sueldo;
  List<Map<String, dynamic>> gastos = [];
  int gananciaExtra = 0;

  final TextEditingController sueldoController = TextEditingController();
  final TextEditingController gastoController = TextEditingController();
  final TextEditingController nombreGastoController = TextEditingController();
  final TextEditingController gananciaExtraController = TextEditingController();

  void agregarGasto() {
    setState(() {
      int gasto = int.tryParse(gastoController.text) ?? 0;
      String nombreGasto = nombreGastoController.text.trim();
      int sueldoRestante = calcularSueldoRestante();

      if (nombreGasto.isNotEmpty && gasto > 0 && gasto <= sueldoRestante) {
        gastos.add({'nombre': nombreGasto, 'monto': gasto});
        gastoController.clear();
        nombreGastoController.clear();
      } else {
        _mostrarMensajeError(
            'El gasto debe tener un nombre, ser positivo y no superar el sueldo restante.');
      }
    });
  }

  int calcularGastosTotales() {
    return gastos.fold<int>(0, (sum, item) => sum + (item['monto'] as int));
  }

  int calcularSueldoRestante() {
    return (sueldo ?? 0) + gananciaExtra - calcularGastosTotales();
  }

  void ingresarSueldo() {
    int? nuevoSueldo = int.tryParse(sueldoController.text);
    if (nuevoSueldo != null && nuevoSueldo > 0) {
      setState(() {
        sueldo = nuevoSueldo;
      });
      sueldoController.clear();
    } else {
      _mostrarMensajeError('El sueldo debe ser un número entero positivo.');
    }
  }

  void agregarGananciaExtra() {
    setState(() {
      int ganancia = int.tryParse(gananciaExtraController.text) ?? 0;
      if (ganancia > 0) {
        gananciaExtra += ganancia;
        gananciaExtraController.clear();
      } else {
        _mostrarMensajeError('La ganancia extra debe ser un número positivo.');
      }
    });
  }

  void reiniciarDatos() {
    setState(() {
      sueldo = null;
      gastos.clear();
      gananciaExtra = 0;
      sueldoController.clear();
      gastoController.clear();
      nombreGastoController.clear();
      gananciaExtraController.clear();
    });
  }

  void _mostrarMensajeError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Contabilidad Personal'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Contabilidad Personal',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            _buildInputSection('Ingrese su sueldo', sueldoController,
                ingresarSueldo, 'Ejemplo: 3000', 'Establecer Sueldo'),
            _buildInputSection('Ingrese un nombre para el gasto',
                nombreGastoController, null, 'Ejemplo: Comida', null),
            _buildInputSection('Ingrese un gasto', gastoController,
                agregarGasto, 'Ejemplo: 150', 'Agregar Gasto'),
            _buildInputSection(
                'Agregar Ganancia Extra',
                gananciaExtraController,
                agregarGananciaExtra,
                'Ejemplo: 500',
                'Agregar Ganancia Extra'),
            SizedBox(height: 20),
            Text('Gastos Totales: \$${calcularGastosTotales()}',
                style: _resultTextStyle),
            SizedBox(height: 10),
            Text('Sueldo Restante: \$${calcularSueldoRestante()}',
                style: _resultTextStyle),
            SizedBox(height: 20),
            Text('Gastos:', style: _sectionTitleTextStyle),
            Expanded(child: _buildGastosList()),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: reiniciarDatos,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 15),
                backgroundColor: Colors.redAccent,
              ),
              child: Text('Reiniciar Datos'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputSection(String title, TextEditingController controller,
      VoidCallback? onPressed, String hint, String? buttonText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: _sectionTitleTextStyle),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey),
            filled: true,
            fillColor: Colors.white,
          ),
          keyboardType: TextInputType.number,
        ),
        SizedBox(height: 10),
        if (onPressed != null && buttonText != null)
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 15),
              backgroundColor: Colors.greenAccent,
            ),
            child: Text(buttonText),
          ),
        SizedBox(height: 20),
      ],
    );
  }

  Widget _buildGastosList() {
    return ListView.builder(
      itemCount: gastos.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text('${gastos[index]['nombre']}: \$${gastos[index]['monto']}',
              style: TextStyle(color: Colors.white)),
          leading: Icon(Icons.money_off, color: Colors.red),
        );
      },
    );
  }

  TextStyle get _resultTextStyle => TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      );

  TextStyle get _sectionTitleTextStyle => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.amber,
      );
}

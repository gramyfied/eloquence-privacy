import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as provider;
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../app/routes.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/repositories/auth_repository.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = true; // Par défaut en mode inscription
  String? _errorMessage;

  // Méthode de gestion de l'authentification
  Future<void> _handleAuth() async {
    // Validation des entrées
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Veuillez remplir tous les champs';
      });
      return;
    }

    // Vérification de la validité de l'email
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(_emailController.text.trim())) {
      setState(() {
        _errorMessage = 'Veuillez entrer une adresse email valide';
      });
      return;
    }

    // Vérification de la confirmation du mot de passe en mode inscription
    if (_isSignUp && _passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Les mots de passe ne correspondent pas';
      });
      return;
    }

    // Vérification de la longueur minimale du mot de passe
    if (_passwordController.text.length < 6) {
      setState(() {
        _errorMessage = 'Le mot de passe doit contenir au moins 6 caractères';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authRepository = provider.Provider.of<AuthRepository>(context, listen: false);
      User user;

      if (_isSignUp) {
        // Inscription
        user = await authRepository.signUpWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text,
        );
        // Afficher un message de succès
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inscription réussie ! Bienvenue.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Connexion
        user = await authRepository.signInWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text,
        );
        // Afficher un message de succès
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connexion réussie ! Bon retour.'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Naviguer vers l'écran d'accueil en utilisant go_router
      context.go(AppRoutes.home, extra: user);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFF1C0A40), // Couleur de fond unie
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              width: MediaQuery.of(context).size.width > 500 
                  ? 500 
                  : MediaQuery.of(context).size.width * 0.9,
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white.withOpacity(0.05),
                border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo et titre
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.mic, 
                          size: 50, 
                          color: AppTheme.primaryColor
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'ÉLOQUENCE',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Coaching vocal intelligent',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Message d'erreur
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white.withOpacity(0.05),
                      border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: TextFormField(
                      controller: _emailController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        labelStyle: TextStyle(color: Colors.white70),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(12),
                        prefixIcon: Icon(Icons.email_outlined, color: Colors.white60),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white.withOpacity(0.05),
                      border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: TextFormField(
                      controller: _passwordController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Mot de passe',
                        labelStyle: TextStyle(color: Colors.white70),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(12),
                        prefixIcon: Icon(Icons.lock_outline, color: Colors.white60),
                      ),
                      obscureText: true,
                      onFieldSubmitted: (_) => _handleAuth(),
                    ),
                  ),
                  
                  // Champ de confirmation de mot de passe (uniquement pour l'inscription)
                  if (_isSignUp) 
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white.withOpacity(0.05),
                        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: TextFormField(
                        controller: _confirmPasswordController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Confirmer le mot de passe',
                          labelStyle: TextStyle(color: Colors.white70),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(12),
                          prefixIcon: Icon(Icons.lock_outline, color: Colors.white60),
                        ),
                        obscureText: true,
                        onFieldSubmitted: (_) => _handleAuth(),
                      ),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleAuth,
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.all(AppTheme.primaryColor),
                        textStyle: WidgetStateProperty.all(
                          const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        shape: WidgetStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              _isSignUp ? 'S\'inscrire' : 'Se connecter',
                              style: const TextStyle(color: Colors.white),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isSignUp = !_isSignUp;
                        _errorMessage = null;
                      });
                    },
                    child: Text(
                      _isSignUp ? 'Déjà inscrit ? Se connecter' : 'Pas encore de compte ? S\'inscrire',
                      style: const TextStyle(color: AppTheme.primaryColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../core/app_theme.dart';
import '../services/auth_service.dart';
import '../services/auto_logout_service.dart';
import 'dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _hide = true;

  Future<void> _login() async {
    if (_username.text.trim().isEmpty || _password.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Username and password required')));
      return;
    }
    setState(() => _loading = true);
    try {
      await AuthService.instance.login(_username.text.trim(), _password.text);
      AutoLogoutService.instance.start();
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardPage()));
    } on ActiveDeviceLoginException catch (e) {
      if (!mounted) return;
      final yes = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Already logged in'),
          content: Text(e.message),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Logout Previous')),
          ],
        ),
      );
      if (yes == true) {
        await AuthService.instance.login(_username.text.trim(), _password.text, forceLogoutPrevious: true);
        AutoLogoutService.instance.start();
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardPage()));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.primaryDark, AppColors.primary, AppColors.secondary]),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(.18), blurRadius: 30, offset: const Offset(0, 16))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 86,
                          height: 86,
                          decoration: BoxDecoration(color: AppColors.primary.withOpacity(.12), borderRadius: BorderRadius.circular(26)),
                          child: const Icon(Icons.business_center_rounded, color: AppColors.primary, size: 46),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Center(child: Text(AppConfig.appName, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.text))),
                      const Center(child: Text('Mobile Sales, Collection, Attendance & GPS', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600))),
                      const SizedBox(height: 26),
                      TextField(controller: _username, decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person_rounded))),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _password,
                        obscureText: _hide,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_rounded),
                          suffixIcon: IconButton(icon: Icon(_hide ? Icons.visibility_rounded : Icons.visibility_off_rounded), onPressed: () => setState(() => _hide = !_hide)),
                        ),
                        onSubmitted: (_) => _login(),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _loading ? null : _login,
                          icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.login_rounded),
                          label: Text(_loading ? 'Signing in...' : 'Login to ERP'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('After login, attendance will be created once per day and GPS tracking can be synchronized.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

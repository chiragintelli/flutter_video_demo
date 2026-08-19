import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Note: You need to run 'flutterfire configure' to generate firebase_options.dart
  // For now, initializing without options (might fail if not configured for platform)
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Video Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  String _verificationId = "";
  int? _resendToken;
  bool _isOtpSent = false;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;

  void _sendOtp() async {
    if (_phoneController.text.isEmpty) return;
    setState(() => _isSendingOtp = true);
    
    String fullNumber = "+91${_phoneController.text.trim()}";
    
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: fullNumber,
        timeout: const Duration(seconds: 15), // Reduced timeout
        forceResendingToken: _resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await FirebaseAuth.instance.signInWithCredential(credential);
          if (mounted) setState(() => _isSendingOtp = false);
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            setState(() => _isSendingOtp = false);
            String errorMsg = e.message ?? "Verification failed";
            if (e.code == 'invalid-phone-number') errorMsg = "Invalid phone number format";
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg)));
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _resendToken = resendToken;
              _isOtpSent = true;
              _isSendingOtp = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("OTP Sent Successfully")),
            );
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (mounted) {
            _verificationId = verificationId;
            setState(() => _isSendingOtp = false);
          }
        },
      );
    } catch (e) {
      if (mounted) setState(() => _isSendingOtp = false);
    }
  }

  void _verifyOtp() async {
    if (_otpController.text.isEmpty) return;
    setState(() => _isVerifyingOtp = true);
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: _otpController.text,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      if (mounted) {
        setState(() => _isVerifyingOtp = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid OTP. Please try again.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const FlutterLogo(size: 100),
            const SizedBox(height: 40),
            if (!_isOtpSent) ...[
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: "Enter Mobile number",
                  border: OutlineInputBorder(),
                  prefixText: "+91 ",
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSendingOtp ? null : _sendOtp,
                  child: _isSendingOtp 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                    : const Text("Next"),
                ),
              ),
            ] else ...[
              TextField(
                controller: _otpController,
                decoration: const InputDecoration(
                  labelText: "Enter OTP",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isSendingOtp ? null : _sendOtp,
                  child: _isSendingOtp 
                    ? const SizedBox(height: 15, width: 15, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text("Did not get otp, resend?"),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isVerifyingOtp ? null : _verifyOtp,
                  child: _isVerifyingOtp 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                    : const Text("Get started"),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _isOtpSent = false),
                child: const Text("Back"),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Home"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: const Center(
        child: Text("Welcome! Video features coming soon."),
      ),
    );
  }
}

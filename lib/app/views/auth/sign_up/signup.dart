import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_app_latest/components/custom_button.dart';
import 'package:share_app_latest/components/input_text_field.dart';
import 'package:share_app_latest/routes/app_navigator.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  bool _agreeTerms = false;
  bool _obscurePassword = true;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xff6D7AFE), Color(0xff2BC8FD)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Create Account",
                    style: GoogleFonts.openSans(
                      fontSize: 35,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  Text(
                    "Start sharing your data securely",
                    style: GoogleFonts.roboto(
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 20),
                  SinUpForm(),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget SinUpForm() {
    return Form(
      key: _formKey,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            /// Name
            CustomTextField(
              controller: _usernameCtrl,
              keyboardtype: TextInputType.emailAddress,
              hintname: "Username",
              icon: "assets/icons/username.png",
              validatetext: "username",
            ),

            const SizedBox(height: 16),

            /// EMAIL
            CustomTextField(
              controller: _emailCtrl,
              keyboardtype: TextInputType.emailAddress,
              hintname: "Email",
              icon: "assets/icons/message.png",
              validatetext: "email",
            ),

            const SizedBox(height: 16),

            /// PASSWORD WITH EYE ICON
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscurePassword,
              decoration: inputDecoration(
                hint: "Password",
                icon: "assets/icons/password.png",
                suffix: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.length < 6) {
                  return "Password must be 6+ chars";
                }
                return null;
              },
            ),
            SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Checkbox(
                      value: _agreeTerms,
                      activeColor: Colors.white,
                      checkColor: const Color(0xff6D7AFE),
                      side: const BorderSide(color: Colors.white),
                      onChanged: (value) {
                        setState(() {
                          _agreeTerms = value!;
                        });
                      },
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _agreeTerms = !_agreeTerms;
                        });
                      },
                      child: Text(
                        "Remember Me",
                        style: GoogleFonts.roboto(
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Image.asset(
                      "assets/icons/forgot.png",
                      height: 22,
                      width: 22,
                    ),
                    SizedBox(width: 8),
                    Text(
                      "Forgot Password",
                      style: GoogleFonts.roboto(color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 80),

            Custombutton(
              textColor: Colors.blue,
              colors: [Colors.white],
              text: "Register",
              ontap: () {
                if (_formKey.currentState!.validate()) {
                  // LOGIN LOGIC
                  // Navigate to main app screen after successful signup
                  // For now, let's navigate to the pairing page
                  // Get.offAllNamed('/pairing');
                  AppNavigator.toLogin();
                }
              },
            ),
            SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Already have an account?",
                  style: GoogleFonts.roboto(color: Colors.white, fontSize: 16),
                ),
                SizedBox(width: 5),
                GestureDetector(
                  onTap: () {
                    AppNavigator.toLogin();
                  },
                  child: Text(
                    "login",
                    style: GoogleFonts.roboto(
                      color: Colors.purple,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// COMMON INPUT DECORATION
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_app_latest/components/custom_button.dart';
import 'package:share_app_latest/components/input_text_field.dart';
import 'package:share_app_latest/routes/app_navigator.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        "assets/icons/profile.png",
                        height: 200,
                        width: 200,
                      ),
                      const SizedBox(height: 20),
                      loginForm(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget loginForm() {
    return Form(
      key: _formKey,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
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
            const SizedBox(height: 100),

            Custombutton(
              textColor: Colors.blue,
              colors: [Colors.white],
              text: "Login",
              ontap: () {
                if (_formKey.currentState!.validate()) {
                  // LOGIN LOGIC
                  AppNavigator.toHome();
                }
              },
            ),
            SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Dont have Account?",
                  style: GoogleFonts.roboto(color: Colors.white, fontSize: 16),
                ),
                SizedBox(width: 5),
                GestureDetector(
                  onTap: () {
                    AppNavigator.toSignup();
                  },
                  child: Text(
                    "SignUp",
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

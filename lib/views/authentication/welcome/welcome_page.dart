import 'package:flutter/material.dart';
import 'package:riendzo/theme/theme.dart';
import '../signIn/sign_in.dart';
import '../signup/sign_up.dart';
import '../widgets/background.dart';
import '../widgets/welcome_button.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Background(
      child: Column(
        children: [
          Flexible(
            flex: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
              ),
              child: Center(
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Welcome to riendzo! \n \n',
                        style: TextStyle(
                          fontSize: 45.0,
                          fontWeight: FontWeight.w600,
                          color: lightColorScheme.secondary,
                        ),
                      ),
                      TextSpan(
                        text:
                            'What are you waiting for?  \n login now and have your own travel agent anywhere you are at any time of the day!',
                        style: TextStyle(
                          fontSize: 20.0,
                          color: lightColorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Flexible(
            flex: 1,
            child: Align(
              alignment: Alignment.bottomRight,
              child: Row(
                children: [
                  Expanded(
                    child: WelcomeButton(
                      buttonText: 'Sign in',
                      onTap: const SignInPage(),
                      color: Colors.transparent,
                      textColor: lightColorScheme.primary,
                    ),
                  ),
                  Expanded(
                    child: WelcomeButton(
                      buttonText: 'Sign up',
                      onTap: const SignUpPage(),
                      color: lightColorScheme.primary,
                      textColor: lightColorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

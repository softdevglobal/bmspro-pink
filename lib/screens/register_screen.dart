import 'package:flutter/material.dart';
import '../routes.dart';
import '../widgets/primary_gradient_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _role = 'Staff';
  bool _obscure = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    final Color accent = Theme.of(context).colorScheme.secondary;
    const Color background = Color(0xFFFFF5FA);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 24),
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Logo and title
                          TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOut,
                            tween: Tween(begin: 0, end: 1),
                            builder: (context, value, child) {
                              return Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, (1 - value) * 20),
                                  child: child,
                                ),
                              );
                            },
                            child: Column(
                              children: [
                                const SizedBox(height: 12),
                                Container(
                                  width: 84,
                                  height: 84,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    gradient: LinearGradient(
                                      colors: [primary, accent],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: primary.withOpacity(0.15),
                                        blurRadius: 30,
                                        offset: const Offset(0, 12),
                                      )
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.brush,
                                        color: Colors.white, size: 32),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Create Account',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF1A1A1A),
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  width: 48,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(99),
                                    gradient: LinearGradient(
                                      colors: [primary, accent],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Card
                          TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOut,
                            tween: Tween(begin: 0, end: 1),
                            builder: (context, value, child) {
                              return Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, (1 - value) * 40),
                                  child: child,
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: primary.withOpacity(0.08),
                                    blurRadius: 40,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Header helper
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: const [
                                      Text(
                                        'Join BMS Pro Pink',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1A1A1A),
                                        ),
                                      ),
                                      SizedBox(height: 6),
                                      Text(
                                        'Create your account to get started',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Color(0xFF9E9E9E),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 16),

                                  // Toggle Staff/Admin
                                  _RoleSegmented(
                                    value: _role,
                                    primary: primary,
                                    accent: accent,
                                    onChanged: (v) => setState(() => _role = v),
                                  ),

                                  const SizedBox(height: 16),

                                  _FocusGlow(
                                    glowColor: primary.withOpacity(0.10),
                                    child: TextField(
                                      controller: _nameController,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      decoration: const InputDecoration(
                                        labelText: 'Full Name',
                                        hintText: 'Enter your name',
                                        prefixIcon: Icon(Icons.person_outline,
                                            color: Color(0xFF9E9E9E)),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  _FocusGlow(
                                    glowColor: primary.withOpacity(0.10),
                                    child: TextField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: const InputDecoration(
                                        labelText: 'Email Address',
                                        hintText: 'Enter your email',
                                        prefixIcon: Icon(Icons.email_outlined,
                                            color: Color(0xFF9E9E9E)),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  _FocusGlow(
                                    glowColor: primary.withOpacity(0.10),
                                    child: TextField(
                                      controller: _passwordController,
                                      obscureText: _obscure,
                                      decoration: InputDecoration(
                                        labelText: 'Password',
                                        hintText: 'Create a password',
                                        prefixIcon: const Icon(
                                            Icons.lock_outline,
                                            color: Color(0xFF9E9E9E)),
                                        suffixIcon: IconButton(
                                          onPressed: () => setState(
                                              () => _obscure = !_obscure),
                                          icon: Icon(_obscure
                                              ? Icons.visibility
                                              : Icons.visibility_off),
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  PrimaryGradientButton(
                                    label: 'Create Account',
                                    onTap: () {
                                      Navigator.pushReplacementNamed(
                                          context, AppRoutes.login);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          Center(
                            child: TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const _GoLogin()),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor:
                                    Theme.of(context).colorScheme.primary,
                              ),
                              child:
                                  const Text('Already have an account? Login'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GoLogin extends StatelessWidget {
  const _GoLogin();
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    });
    return const SizedBox.shrink();
  }
}

class _RoleSegmented extends StatelessWidget {
  final String value;
  final Color primary;
  final Color accent;
  final ValueChanged<String> onChanged;
  const _RoleSegmented({
    required this.value,
    required this.primary,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool left = value == 'Staff';
    const Color background = Color(0xFFFFF5FA);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SizedBox(
        height: 48,
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              alignment: value == 'Staff'
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                heightFactor: 1,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: left
                        ? const BorderRadius.only(
                            topLeft: Radius.circular(14),
                            bottomLeft: Radius.circular(14),
                          )
                        : const BorderRadius.only(
                            topRight: Radius.circular(14),
                            bottomRight: Radius.circular(14),
                          ),
                    gradient: LinearGradient(colors: [primary, accent]),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withOpacity(0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged('Staff'),
                    child: Center(
                      child: Text(
                        'Staff',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: value == 'Staff'
                              ? Colors.white
                              : const Color(0xFF9E9E9E),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged('Admin'),
                    child: Center(
                      child: Text(
                        'Admin',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: value == 'Admin'
                              ? Colors.white
                              : const Color(0xFF9E9E9E),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _FocusGlow extends StatefulWidget {
  final Widget child;
  final Color glowColor;
  const _FocusGlow({required this.child, required this.glowColor});

  @override
  State<_FocusGlow> createState() => _FocusGlowState();
}

class _FocusGlowState extends State<_FocusGlow> {
  bool _focused = false;
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: widget.glowColor,
                  blurRadius: 16,
                  spreadRadius: 0,
                  offset: const Offset(0, 0),
                )
              ]
            : null,
      ),
      child: Focus(
        onFocusChange: (v) => setState(() => _focused = v),
        child: widget.child,
      ),
    );
  }
}

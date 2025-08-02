import 'package:flutter/material.dart';

import 'package:hnde_web/screens/components/sidebar/login_form.dart';

class DashboardAppBarUserInfo extends StatelessWidget {
  final bool loggedIn;
  final String? name;
  final String? position;
  final String? branch;
  final VoidCallback? onLogout;
  const DashboardAppBarUserInfo({
    super.key,
    required this.loggedIn,
    this.name,
    this.position,
    this.branch,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    Widget _buildUserInfo() {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(name ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(position ?? '', style: const TextStyle(fontSize: 13)),
                  Text(branch ?? '',
                      style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
              ),
              const SizedBox(width: 16),
              IconButton(onPressed: (){}, icon: const Icon(Icons.account_circle, color: Colors.white, size: 32)),
            ],
          ),
          const SizedBox(height: 8),
          if (onLogout != null)
            TextButton(onPressed: onLogout, child: const Text('로그아웃', style: TextStyle(color: Color.fromARGB(255, 186, 186, 186)))),
        ],
      );
    }

    return Row(
      children: [
        // Image.asset(kLogoVertical, width: 48, height: 48),
        const SizedBox(width: 16),
        Expanded(
          child: loggedIn
              ? _buildUserInfo()
              : const LoginForm(),
        ),
      ],
    );
  }
}

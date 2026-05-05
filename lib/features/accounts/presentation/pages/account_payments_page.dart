import 'package:flutter/material.dart';

import '../../../consumptions/presentation/pages/consumption_payments_page.dart';
import '../../../users/domain/app_user.dart';

class AccountPaymentsPage extends StatelessWidget {
  const AccountPaymentsPage({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    return ConsumptionPaymentsPage(currentUser: currentUser);
  }
}

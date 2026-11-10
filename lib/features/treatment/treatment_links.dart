import 'package:flutter/material.dart';

import 'data/treatment_data.dart';
import 'screens/treatment_detail_screen.dart';

/// Opens one procedure's page from the Treatment tab, e.g. from a scan result,
/// rather than the list of every treatment. Back returns to where it was opened.
/// Does nothing for an id the Treatment tab doesn't have.
Future<void> openTreatment(
  BuildContext context,
  String id, {
  VoidCallback? onFindClinic,
}) async {
  final treatment = TreatmentData.byId(id);
  if (treatment == null) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: RouteSettings(name: '/treatment/$id'),
      builder: (_) => TreatmentDetailScreen(
        treatment: treatment,
        onFindClinic: onFindClinic,
      ),
    ),
  );
}

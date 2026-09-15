import 'dart:convert';

import 'role_aliases.dart';
import 'screen_catalog.dart';
import 'evaluate_access.dart';

Map<String, Object?> dumpGate(CapabilityGate gate) {
  final out = <String, Object?>{};
  if (gate.permissions.isNotEmpty) {
    final permissions = [...gate.permissions]..sort();
    out['permissions'] = permissions;
  }
  if (gate.roles.isNotEmpty) {
    out['roles'] = [...gate.roles];
  }
  if (gate.requireAll) out['requireAll'] = true;
  if (gate.exactRoles) out['exactRoles'] = true;
  return out;
}

Map<String, Object?> dumpAppCatalog() {
  final aliasKeys = kGlobalRoleAliases.keys.toList()..sort();
  final aliases = <String, List<String>>{
    for (final key in aliasKeys) key: [...kGlobalRoleAliases[key]!],
  };
  final screens = [...kAppScreenCatalog]
    ..sort((a, b) => a.id.compareTo(b.id));
  return {
    'version': 1,
    'aliases': aliases,
    'screens': [
      for (final screen in screens)
        {
          'id': screen.id,
          'surfaces': [...screen.surfaces]..sort(),
          'viewAny': dumpGate(screen.viewAny),
          'capabilities': ([...screen.capabilities]
                ..sort((a, b) => a.id.compareTo(b.id)))
              .map(
                (capability) => {
                  'id': capability.id,
                  'kind': capability.kind,
                  'gate': dumpGate(capability.gate),
                },
              )
              .toList(),
        },
    ],
  };
}

String dumpAppCatalogJson() => '${const JsonEncoder.withIndent('  ').convert(dumpAppCatalog())}\n';

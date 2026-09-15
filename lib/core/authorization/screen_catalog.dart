import 'access_subject.dart';
import 'evaluate_access.dart';

class ScreenCapability {
  final String id;
  final String kind;
  final CapabilityGate gate;

  const ScreenCapability({
    required this.id,
    required this.kind,
    required this.gate,
  });
}

class ScreenDefinition {
  final String id;
  final List<String> surfaces;
  final CapabilityGate viewAny;
  final List<ScreenCapability> capabilities;

  const ScreenDefinition({
    required this.id,
    required this.surfaces,
    required this.viewAny,
    this.capabilities = const [],
  });
}

CapabilityGate _p(List<String> permissions) =>
    CapabilityGate(permissions: permissions);

ScreenCapability _cap(String id, String permission, {String kind = 'button'}) =>
    ScreenCapability(id: id, kind: kind, gate: _p([permission]));

ScreenDefinition _view(
  String id, {
  required List<String> surfaces,
  List<String> permissions = const [],
  List<String> roles = const [],
  List<ScreenCapability> capabilities = const [],
}) {
  return ScreenDefinition(
    id: id,
    surfaces: surfaces,
    viewAny: CapabilityGate(permissions: permissions, roles: roles),
    capabilities: capabilities,
  );
}

const List<String> _adminApp = ['admin', 'app'];
const List<String> _appOnly = ['app'];

/// App-surface screens. Dual-surface entries copy the TS family file.
final List<ScreenDefinition> kAppScreenCatalog = [
  _view(
    'activities',
    surfaces: _adminApp,
    permissions: ['activities:read'],
    capabilities: [
      _cap('create', 'activities:create'),
      _cap('update', 'activities:update'),
    ],
  ),
  _view(
    'annual-folders-rankings',
    surfaces: _adminApp,
    permissions: ['rankings:read'],
  ),
  _view('app-classes', surfaces: _appOnly, permissions: ['classes:read']),
  _view('app-club', surfaces: _appOnly, permissions: ['clubs:update']),
  _view(
    'app-grouped-class',
    surfaces: _appOnly,
    permissions: ['classes:submit_progress'],
  ),
  _view(
    'app-materials',
    surfaces: _appOnly,
    permissions: ['materiales:create'],
  ),
  _view('app-members', surfaces: _appOnly, permissions: ['users:read_detail']),
  _view('app-units', surfaces: _appOnly, permissions: ['units:update']),
  _view(
    'campamentos-list-local',
    surfaces: _adminApp,
    permissions: ['camporees:read'],
    capabilities: [
      _cap('create', 'camporees:create'),
      _cap('delete', 'camporees:delete'),
      _cap('events.create', 'camporee_events:create'),
      _cap('events.delete', 'camporee_events:delete'),
      _cap('events.update', 'camporee_events:update'),
      _cap(
        'orders.configure_offering',
        'camporee-orders:offering-configure',
        kind: 'section',
      ),
      _cap('scoring.read', 'camporee_events:read', kind: 'section'),
      _cap('supplies.configure', 'camporee-supplies:configure'),
      _cap('supplies.deliver', 'camporee-supplies:deliver'),
      _cap('supplies.review_pay', 'camporee-supplies:review-pay'),
      _cap('update', 'camporees:update'),
      _cap('venues.create', 'camporee_events:create'),
      _cap('venues.delete', 'camporee_events:delete'),
      _cap('venues.update', 'camporee_events:update'),
    ],
  ),
  _view(
    'club-inventory',
    surfaces: _adminApp,
    permissions: ['inventory:read'],
    capabilities: [
      _cap('create', 'inventory:create'),
      _cap('delete', 'inventory:delete'),
      _cap('update', 'inventory:update'),
    ],
  ),
  _view(
    'clubs-evidence-folders-list',
    surfaces: _adminApp,
    permissions: ['evidence_folders:read'],
  ),
  _view(
    'coordinator-hub',
    surfaces: _appOnly,
    roles: ['admin', 'coordinator'],
  ),
  _view(
    'finances',
    surfaces: _adminApp,
    permissions: ['finances:read'],
    capabilities: [
      _cap('create', 'finances:create'),
      _cap('delete', 'finances:delete'),
      _cap('update', 'finances:update'),
    ],
  ),
  _view(
    'insurance-by-section',
    surfaces: _adminApp,
    permissions: ['insurance:read'],
    capabilities: [
      _cap('create', 'insurance:create'),
      _cap('delete', 'insurance:update'),
      _cap('update', 'insurance:update'),
    ],
  ),
  _view(
    'reports-list',
    surfaces: _adminApp,
    permissions: ['reports:read'],
  ),
  _view(
    'resources-list',
    surfaces: _adminApp,
    permissions: ['resources:read'],
    capabilities: [
      _cap('create', 'resources:create'),
      _cap('delete', 'resources:delete'),
      _cap('update', 'resources:update'),
    ],
  ),
];

final Map<String, ScreenDefinition> _byId = {
  for (final screen in kAppScreenCatalog) screen.id: screen,
};

ScreenDefinition? getScreen(String screenId) => _byId[screenId];

bool canViewScreen(AccessSubject subject, String screenId) {
  final screen = getScreen(screenId);
  if (screen == null) return false;
  return evaluateAccess(subject, screen.viewAny);
}

bool canCapability(
  AccessSubject subject,
  String screenId,
  String capabilityId,
) {
  final screen = getScreen(screenId);
  if (screen == null) return false;
  for (final capability in screen.capabilities) {
    if (capability.id == capabilityId) {
      return evaluateAccess(subject, capability.gate);
    }
  }
  return false;
}

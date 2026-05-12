# Integration Tests

This directory contains Flutter integration tests that exercise the full widget and
provider graph in a near-production context, using `IntegrationTestWidgetsFlutterBinding`.

## What is covered

- `persona_nav_context_switch_test.dart` — S-15 acceptance scenario:
  boots as director (Miembros shell), then simulates a context switch to
  coordinator; verifies that `personaNavSlotsProvider` rebuilds and the nav
  bar swaps from director slots to coordinator slots (Hub first, branchIndex 0–4).

## How to run

**Headless (flutter-tester VM, no device required):**

```bash
flutter test --device-id flutter-tester integration_test/persona_nav_context_switch_test.dart
```

**Full integration suite:**

```bash
flutter test --device-id flutter-tester integration_test/
```

**On a real device or simulator (full drive mode):**

```bash
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/persona_nav_context_switch_test.dart
```

## Headless execution note

Flutter 3.x treats any file under `integration_test/` as a device test when
`flutter test` is invoked without `--device-id`. Passing `--device-id flutter-tester`
explicitly selects the VM-based host runner and does not require a connected device.

The tests in this directory do not invoke platform channels, so `flutter-tester`
is sufficient. A physical device or simulator is only needed for future tests that
add native interactions (camera, biometrics, etc.).

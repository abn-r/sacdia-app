# Integration Tests

This directory contains Flutter integration tests that exercise the full widget and
provider graph in a near-production context, using `IntegrationTestWidgetsFlutterBinding`.

## How to run

**Headless (flutter-tester VM, no device required):**

```bash
flutter test --device-id flutter-tester integration_test/
```

**On a real device or simulator (full drive mode):**

```bash
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/<your_test>.dart
```

## Headless execution note

Flutter 3.x treats any file under `integration_test/` as a device test when
`flutter test` is invoked without `--device-id`. Passing `--device-id flutter-tester`
explicitly selects the VM-based host runner and does not require a connected device.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/activities/presentation/providers/activities_providers.dart';
import '../../features/members/presentation/providers/members_providers.dart';
import '../../providers/catalogs_provider.dart';
import 'realtime_ref.dart';

/// Callback signature for provider invalidation handlers.
///
/// Receives [ref] (to read/invalidate providers) and [sectionId] (the
/// section that triggered the FCM INVALIDATE event).
///
/// Uses [RealtimeRef] — a thin adapter that unifies [Ref] (from Riverpod
/// providers) and [WidgetRef] (from ConsumerWidgets).
typedef InvalidationCallback = void Function(RealtimeRef ref, int sectionId);

/// Registry that maps FCM resource names to their invalidation callbacks.
///
/// Design contract:
/// - Handlers are registered at app startup (or lazily on first use).
/// - The [invalidate] method is the single entry point called by
///   [RealtimeInvalidationHandler] for every incoming INVALIDATE message.
/// - Unknown resources are logged and silently ignored.
///
/// Bridging section_id → provider key:
///   The FCM payload carries [section_id] because the backend event originates
///   from a specific section. Our [clubActivitiesProvider] is keyed by
///   [ClubActivitiesParams{clubId, clubTypeId?}] — NOT by sectionId.
///   We resolve the mapping via [clubContextProvider]: if the active user's
///   context matches the incoming sectionId we invalidate; otherwise we skip
///   (the user does not hold that section in their current view).
///
///   The [clubTypeId] used when building the family key is null because
///   [ActivitiesListView] always constructs params with clubTypeId from its
///   widget property, which defaults to null from the home navigation path
///   (filtering by activity type is applied locally, see activities_providers.dart).
class RealtimeResourceRegistry {
  RealtimeResourceRegistry._();

  static final Map<String, InvalidationCallback> _handlers = {
    'activities': _invalidateActivities,
    'members': _invalidateMembers,
  };

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Dispatches an invalidation event for [resource] scoped to [sectionId].
  ///
  /// Returns normally for unknown resources (a warning is logged instead of
  /// throwing so a bad FCM payload never crashes the app).
  static void invalidate(RealtimeRef ref, String resource, int sectionId) {
    final handler = _handlers[resource];
    if (handler == null) {
      debugPrint('[RealtimeRegistry] Unknown resource: "$resource" — skipping');
      return;
    }
    handler(ref, sectionId);
  }

  /// Registers (or replaces) a handler for [resource].
  ///
  /// Prefer calling this at app startup so the registry is fully configured
  /// before any FCM messages arrive.
  static void register(String resource, InvalidationCallback handler) {
    _handlers[resource] = handler;
  }

  /// Fires EVERY registered resource handler for [sectionId] plus app-wide
  /// catalog providers.
  ///
  /// Used by the Settings → "Forzar sincronización" control to manually
  /// replay what a broadcast FCM invalidation would do. Unlike [invalidate]
  /// (which targets one resource), this walks the entire registry so newly
  /// registered resources are picked up automatically.
  ///
  /// Catalogs are invalidated unconditionally — they are global (not
  /// section-scoped), so bypassing the per-handler section guard is correct.
  /// Individual resource handlers keep their own section guards, so passing
  /// the user's active sectionId is required for them to fire.
  static void invalidateAll(RealtimeRef ref, int sectionId) {
    // Resource handlers (activities, members, …). Each handler applies its
    // own section guard — we just dispatch to every registered name.
    for (final entry in _handlers.entries) {
      try {
        entry.value(ref, sectionId);
      } catch (e, st) {
        debugPrint(
          '[RealtimeRegistry] invalidateAll: handler "${entry.key}" threw '
          '$e\n$st',
        );
      }
    }

    // Global catalogs — no section scoping, always safe to invalidate.
    try {
      ref.invalidate(clubTypesProvider);
      ref.invalidate(activityTypesProvider);
      ref.invalidate(districtsProvider);
      ref.invalidate(churchesProvider);
      ref.invalidate(ecclesiasticalYearsProvider);
      ref.invalidate(currentEcclesiasticalYearProvider);
    } catch (e, st) {
      debugPrint(
        '[RealtimeRegistry] invalidateAll: catalog invalidation threw $e\n$st',
      );
    }

    debugPrint(
      '[RealtimeRegistry] invalidateAll: dispatched to '
      '${_handlers.length} handlers + catalogs (section=$sectionId)',
    );
  }

  // ── Built-in handlers ───────────────────────────────────────────────────────

  /// Invalidates [clubActivitiesProvider] for the active club when the
  /// incoming [sectionId] matches the user's current club context.
  ///
  /// The bridge: FCM sends section_id. We read [clubContextProvider] to get
  /// the active [ClubContext], which exposes both [clubId] and [sectionId].
  /// If [sectionId] matches, we invalidate the activities family entry that
  /// was created with [ClubActivitiesParams(clubId: ctx.clubId, clubTypeId: null)].
  ///
  /// Why clubTypeId: null?
  ///   [ActivitiesListView] always constructs params with clubTypeId from its
  ///   widget property, which defaults to null from the home navigation stack.
  ///   Filtering by activity type is done locally, so the cached provider entry
  ///   uses null as the clubTypeId — matching what we invalidate here.
  static void _invalidateActivities(RealtimeRef ref, int sectionId) {
    final ctxAsync = ref.read(clubContextProvider);

    // Use .valueOrNull — safe even when the provider is in loading/error state.
    final ctx = ctxAsync.valueOrNull;

    if (ctx == null) {
      debugPrint(
        '[RealtimeRegistry] activities: no active club context, skipping',
      );
      return;
    }

    if (ctx.sectionId != sectionId) {
      debugPrint(
        '[RealtimeRegistry] activities: section $sectionId does not match '
        'active section ${ctx.sectionId} — skipping invalidation',
      );
      return;
    }

    final params = ClubActivitiesParams(
      clubId: ctx.clubId,
      clubTypeId: null,
    );
    ref.invalidate(clubActivitiesProvider(params));

    debugPrint(
      '[RealtimeRegistry] activities: invalidated clubActivitiesProvider '
      'for clubId=${ctx.clubId} (section=$sectionId)',
    );
  }

  /// Invalidates [membersNotifierProvider] for the active club when the
  /// incoming [sectionId] matches the user's current club context.
  ///
  /// The bridge: FCM sends section_id. We read [clubContextProvider] to get
  /// the active [ClubContext], which exposes both [clubId] and [sectionId].
  /// If [sectionId] matches, we invalidate [membersNotifierProvider] — it has
  /// no family key because it resolves its own context via [clubContextProvider]
  /// inside its build method.
  static void _invalidateMembers(RealtimeRef ref, int sectionId) {
    final ctxAsync = ref.read(clubContextProvider);

    // Use .valueOrNull — safe even when the provider is in loading/error state.
    final ctx = ctxAsync.valueOrNull;

    if (ctx == null) {
      debugPrint(
        '[RealtimeRegistry] members: no active club context, skipping',
      );
      return;
    }

    if (ctx.sectionId != sectionId) {
      debugPrint(
        '[RealtimeRegistry] members: section $sectionId does not match '
        'active section ${ctx.sectionId} — skipping invalidation',
      );
      return;
    }

    ref.invalidate(membersNotifierProvider);

    debugPrint(
      '[RealtimeRegistry] members: invalidated membersNotifierProvider '
      'for clubId=${ctx.clubId} (section=$sectionId)',
    );
  }
}

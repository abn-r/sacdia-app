import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/personal_info_providers.dart';
import '../widgets/contact_card.dart';
import 'add_edit_contact_view.dart';
import 'package:sacdia_app/core/animations/page_transitions.dart';

/// Vista para gestionar contactos de emergencia
class EmergencyContactsView extends ConsumerWidget {
  const EmergencyContactsView({super.key});

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    int contactId,
    String contactName,
  ) async {
    final confirmed = await SacDialog.show(
      context,
      title: 'post_registration.emergency_contacts.delete_dialog_title'.tr(),
      content: 'post_registration.emergency_contacts.delete_dialog_content'
          .tr(namedArgs: {'name': contactName}),
      confirmLabel: 'common.delete'.tr(),
      confirmIsDestructive: true,
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref
            .read(emergencyContactsProvider.notifier)
            .deleteContact(contactId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'post_registration.emergency_contacts.delete_success'.tr()),
              backgroundColor: AppColors.secondary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'post_registration.emergency_contacts.error_deleting'
                    .tr(namedArgs: {'error': e.toString()}),
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _navigateToAddEdit(BuildContext context,
      {dynamic contact}) async {
    final result = await Navigator.of(context).push<bool>(
      SacSharedAxisRoute(
        builder: (context) => AddEditContactView(contact: contact),
      ),
    );

    if (result == true && context.mounted) {
      // Opcionalmente cerrar esta vista también si estamos en un bottom sheet
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(emergencyContactsProvider);
    final canAddMore = contactsAsync.maybeWhen(
      data: (contacts) => contacts.isNotEmpty && contacts.length < 5,
      orElse: () => false,
    );

    return Scaffold(
      appBar: SacTopBar(
        title: 'post_registration.emergency_contacts.title'.tr(),
        actions: [
          IconButton(
            icon: HugeIcon(icon: HugeIcons.strokeRoundedRefresh, size: 24),
            onPressed: () {
              ref.read(emergencyContactsProvider.notifier).refresh();
            },
            tooltip:
                'post_registration.emergency_contacts.refresh_tooltip'.tr(),
          ),
          if (canAddMore)
            IconButton(
              tooltip: 'post_registration.emergency_contacts.add_button'.tr(),
              onPressed: () => _navigateToAddEdit(context),
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedAdd01,
                size: 22,
                color: AppColors.primary,
              ),
            ),
        ],
      ),
      body: contactsAsync.when(
        loading: () => const Center(child: SacLoading()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HugeIcon(
                  icon: HugeIcons.strokeRoundedAlert02,
                  size: 48,
                  color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                'post_registration.emergency_contacts.error_loading'
                    .tr(namedArgs: {'error': error.toString()}),
              ),
              const SizedBox(height: 16),
              SacButton(
                text: 'common.retry'.tr(),
                icon: HugeIcons.strokeRoundedRefresh,
                onPressed: () {
                  ref.read(emergencyContactsProvider.notifier).refresh();
                },
              ),
            ],
          ),
        ),
        data: (contacts) {
          if (contacts.isEmpty) {
            return SacEmptyState(
              icon: HugeIcons.strokeRoundedContactBook,
              title: 'post_registration.emergency_contacts.empty_title'.tr(),
              body: 'post_registration.emergency_contacts.empty_subtitle'.tr(),
              actionLabel:
                  'post_registration.emergency_contacts.add_button'.tr(),
              onAction: () => _navigateToAddEdit(context),
            );
          }

          return Column(
            children: [
              // Información sobre límite
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: contacts.length >= 5
                    ? AppColors.accentLight
                    : AppColors.primaryLight,
                child: Row(
                  children: [
                    HugeIcon(
                      icon: contacts.length >= 5
                          ? HugeIcons.strokeRoundedAlertCircle
                          : HugeIcons.strokeRoundedInformationCircle,
                      color: contacts.length >= 5
                          ? AppColors.accentDark
                          : AppColors.primaryDark,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        contacts.length >= 5
                            ? 'post_registration.emergency_contacts.limit_reached'
                                .tr()
                            : 'post_registration.emergency_contacts.limit_progress'
                                .tr(namedArgs: {
                                'current': contacts.length.toString()
                              }),
                        style: TextStyle(
                          fontSize: 14,
                          color: contacts.length >= 5
                              ? AppColors.accentDark
                              : AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Lista de contactos
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    return ContactCard(
                      contact: contact,
                      onEdit: () =>
                          _navigateToAddEdit(context, contact: contact),
                      onDelete: () => _showDeleteConfirmation(
                        context,
                        ref,
                        contact.id!,
                        contact.name,
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

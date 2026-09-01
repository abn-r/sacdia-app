import '../entities/camporee_supply_plan.dart';

class CamporeeSupplySlotBucket {
  final CamporeeSupplySlot slot;
  final List<CamporeeSupplyLineInput> lines;

  const CamporeeSupplySlotBucket({
    required this.slot,
    required this.lines,
  });
}

class CamporeeSupplyDayBucket {
  final String date;
  final int dayNumber;
  final List<CamporeeSupplySlotBucket> slots;

  const CamporeeSupplyDayBucket({
    required this.date,
    required this.dayNumber,
    required this.slots,
  });

  bool get isEmpty => slots.every((bucket) => bucket.lines.isEmpty);
}

List<CamporeeSupplyDayBucket> groupCamporeeSupplyLines({
  required List<String> dates,
  required List<CamporeeSupplySlot> slots,
  required List<CamporeeSupplyLineInput> lines,
}) {
  final sortedSlots = [...slots]..sort((a, b) {
      final order = a.sortOrder.compareTo(b.sortOrder);
      if (order != 0) return order;
      return a.deliverTime.compareTo(b.deliverTime);
    });

  return [
    for (var index = 0; index < dates.length; index++)
      CamporeeSupplyDayBucket(
        date: dates[index],
        dayNumber: index + 1,
        slots: [
          for (final slot in sortedSlots)
            CamporeeSupplySlotBucket(
              slot: slot,
              lines: [
                for (final line in lines)
                  if (line.date == dates[index] && line.slotId == slot.slotId)
                    line,
              ],
            ),
        ].where((bucket) => bucket.lines.isNotEmpty).toList(),
      ),
  ];
}

int estimateCamporeeSupplyTotal({
  required List<CamporeeSupplyLineInput> lines,
  required List<CamporeeSupplyProduct> products,
}) {
  final byId = {for (final product in products) product.productId: product};
  var total = 0;
  for (final line in lines) {
    final product = byId[line.productId];
    if (product == null) continue;
    total += (line.qty * product.unitCostCentavos).round();
  }
  return total;
}

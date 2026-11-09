import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/image_service.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/utilities/format_helper.dart';
import '../../models/activity_models.dart';
import '../../repositories/repos.dart';
import '../../widgets/common_widgets.dart';
import 'crud_framework.dart';

class WishlistPage extends StatelessWidget {
  const WishlistPage({super.key});

  static const occasions = ['Birthday', 'Anniversary', 'Christmas', "Valentine's Day", 'Just Because', 'Other'];

  @override
  Widget build(BuildContext context) {
    return CrudListPage<GiftItem>(
      title: 'Gift Wishlist',
      icon: Icons.card_giftcard_rounded,
      singular: 'gift',
      repo: Repos.gifts,
      orderBy: 'is_purchased ASC, created_at DESC',
      emptyMessage: 'Save gift ideas so you never forget what they love.',
      onDeleted: (g) => ImageService().delete(g.photoPath),
      fieldsBuilder: (_) => const [
        FieldSpec('photo', 'Photo', FieldType.image),
        FieldSpec('title', 'Gift idea', FieldType.text, required: true),
        FieldSpec('description', 'Description', FieldType.multiline),
        FieldSpec('price', 'Estimated price', FieldType.number),
        FieldSpec('occasion', 'Occasion', FieldType.dropdown, options: occasions),
        FieldSpec('purchased', 'Already purchased', FieldType.toggle),
      ],
      toValues: (_, g) => {
        'photo': g?.photoPath,
        'title': g?.title ?? '',
        'description': g?.description ?? '',
        'price': g?.estimatedPrice ?? 0.0,
        'occasion': g?.occasion ?? occasions.last,
        'purchased': g?.isPurchased ?? false,
      },
      fromValues: (_, v, e, cid) => GiftItem(
        id: e?.id,
        coupleId: cid,
        title: vStr(v, 'title'),
        description: vStr(v, 'description'),
        estimatedPrice: vNum(v, 'price'),
        photoPath: v['photo'] as String?,
        occasion: vStr(v, 'occasion'),
        isPurchased: vBool(v, 'purchased'),
      ),
      filtersBuilder: (_) => {
        'To buy': (g) => !g.isPurchased,
        'Purchased': (g) => g.isPurchased,
        for (final o in occasions) o: (g) => g.occasion == o,
      },
      header: (ctx, all) {
        final symbol = ctx.watch<ThemeController>().currency;
        final open = all.where((g) => !g.isPurchased);
        return StatRow([
          (Icons.card_giftcard_rounded, 'To buy', '${open.length}'),
          (Icons.shopping_bag_rounded, 'Purchased', '${all.where((g) => g.isPurchased).length}'),
          (Icons.sell_rounded, 'Still to spend', FormatHelper.money(open.fold(0.0, (s, g) => s + g.estimatedPrice), symbol)),
        ]);
      },
      itemBuilder: (ctx, g, api) {
        final cs = Theme.of(ctx).colorScheme;
        final symbol = ctx.watch<ThemeController>().currency;
        final file = g.photoPath == null ? null : File(g.photoPath!);
        final has = file != null && file.existsSync();
        return AppCard(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: has
                  ? Image.file(file, width: 64, height: 64, fit: BoxFit.cover)
                  : Container(
                      width: 64,
                      height: 64,
                      color: cs.primaryContainer,
                      child: Icon(Icons.card_giftcard_rounded, color: cs.primary)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(g.title,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        decoration: g.isPurchased ? TextDecoration.lineThrough : null)),
                Text(
                    [if (g.occasion != null) g.occasion!, if (g.estimatedPrice > 0) FormatHelper.money(g.estimatedPrice, symbol)]
                        .join(' • '),
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                if (g.description != null) Text(g.description!, maxLines: 2, overflow: TextOverflow.ellipsis),
              ]),
            ),
            Column(children: [
              Checkbox(value: g.isPurchased, onChanged: (_) => api.save(g.toggled())),
              crudMenu(g, api),
            ]),
          ]),
        );
      },
    );
  }
}

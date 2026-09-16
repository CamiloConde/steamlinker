import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../theme/colors.dart';
import '../theme/radii.dart';

class NotificationTile extends StatelessWidget {
  final NotificationModel notif;
  final VoidCallback onChanged;
  final VoidCallback? onOpen;
  final Future<void> Function(bool leida)? onToggleRead;
  final Future<void> Function(bool? interes)? onInteres;

  const NotificationTile({
    super.key,
    required this.notif,
    required this.onChanged,
    this.onOpen,
    this.onToggleRead,
    this.onInteres,
  });

  bool get _isEmoji =>
      notif.avatar.length <= 2 &&
      notif.avatar.contains(RegExp(r'[^\x00-\x7F]'));

  void _showMenu(BuildContext ctx) {
    final RenderBox button = ctx.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(ctx).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
            button.size.bottomRight(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: ctx,
      position: position,
      color: SteamColors.bgPanel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SteamRadii.sm),
        side: const BorderSide(color: SteamColors.border),
      ),
      items: [
        _buildMenuItem(
            'interested', Icons.thumb_up_outlined, SteamColors.green,
            notif.interested == true
                ? 'Quitar "Me interesa"'
                : 'Me interesa'),
        _buildMenuItem(
            'not_interested', Icons.thumb_down_outlined, SteamColors.red,
            notif.interested == false
                ? 'Quitar "No me interesa"'
                : 'No me interesa'),
        _buildMenuItem(
            'toggle_read', Icons.done_all_rounded, SteamColors.blue,
            notif.isRead ? 'Marcar no leída' : 'Marcar leída'),
      ],
    ).then((val) async {
      if (val == null) return;
      switch (val) {
        case 'interested':
          final nuevo = notif.interested == true ? null : true;
          if (onInteres != null) {
            await onInteres!(nuevo);
          } else {
            notif.interested = nuevo;
          }
          break;
        case 'not_interested':
          final nuevo = notif.interested == false ? null : false;
          if (onInteres != null) {
            await onInteres!(nuevo);
          } else {
            notif.interested = nuevo;
          }
          break;
        case 'toggle_read':
          final nuevo = !notif.isRead;
          if (onToggleRead != null) {
            await onToggleRead!(nuevo);
          } else {
            notif.isRead = nuevo;
          }
          break;
      }
      onChanged();
    });
  }

  PopupMenuItem<String> _buildMenuItem(
      String val, IconData icon, Color color, String label) {
    return PopupMenuItem(
      value: val,
      child: Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(color: SteamColors.light, fontSize: 13)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      color: notif.isRead
          ? Colors.transparent
          : SteamColors.blue.withOpacity(0.05),
      child: InkWell(
        onTap: () async {
          if (!notif.isRead) {
            if (onToggleRead != null) {
              await onToggleRead!(true);
            } else {
              notif.isRead = true;
            }
          }
          onOpen?.call();
          onChanged();
        },
        splashColor: SteamColors.blue.withOpacity(0.07),
        highlightColor: SteamColors.blue.withOpacity(0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child:
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Stack(clipBehavior: Clip.none, children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(SteamRadii.sm),
                  gradient: LinearGradient(
                    colors: [
                      notif.typeColor.withOpacity(0.25),
                      notif.typeColor.withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: notif.typeColor
                        .withOpacity(notif.isRead ? 0.2 : 0.6),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: _isEmoji
                      ? Text(notif.avatar,
                          style: const TextStyle(fontSize: 20))
                      : Text(
                          notif.avatar,
                          style: TextStyle(
                            color: notif.typeColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
              Positioned(
                bottom: -4,
                right: -4,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: notif.typeColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: SteamColors.bgDeep, width: 1.5),
                  ),
                  child: Icon(notif.typeIcon,
                      size: 9, color: Colors.white),
                ),
              ),
            ]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: notif.typeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(SteamRadii.sm),
                      ),
                      child: Text(
                        notif.typeLabel,
                        style: TextStyle(
                          color: notif.typeColor,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(notif.time,
                        style: const TextStyle(
                            color: SteamColors.muted, fontSize: 10.5)),
                    if (!notif.isRead) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: SteamColors.blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 5),
                  Text(
                    notif.title,
                    style: TextStyle(
                      color: notif.isRead
                          ? SteamColors.light
                          : Colors.white,
                      fontSize: 13.5,
                      fontWeight: notif.isRead
                          ? FontWeight.w600
                          : FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notif.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: SteamColors.textSec,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  if (notif.interested != null) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(
                        notif.interested!
                            ? Icons.thumb_up_rounded
                            : Icons.thumb_down_rounded,
                        size: 12,
                        color: notif.interested!
                            ? SteamColors.green
                            : SteamColors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        notif.interested!
                            ? 'Marcada como interesante'
                            : 'No te interesa',
                        style: TextStyle(
                          color: notif.interested!
                              ? SteamColors.green
                              : SteamColors.red,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 4),
            Builder(
              builder: (btnCtx) => GestureDetector(
                onTap: () => _showMenu(btnCtx),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.more_vert_rounded,
                      color: SteamColors.muted, size: 18),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

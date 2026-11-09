import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../widgets/common_widgets.dart';
import 'lock_controller.dart';
import 'pin_pad.dart';

enum _Stage { verifyOld, enterNew, confirmNew }

/// Create a PIN, or change an existing one when [changing] is true.
class PinSetupPage extends StatefulWidget {
  const PinSetupPage({super.key, this.changing = false});
  final bool changing;

  @override
  State<PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends State<PinSetupPage> {
  late _Stage _stage = widget.changing ? _Stage.verifyOld : _Stage.enterNew;
  String? _old, _first, _notice;

  Future<String?> _handle(String pin) async {
    final lock = context.read<LockController>();
    switch (_stage) {
      case _Stage.verifyOld:
        final err = await lock.verifyOnly(pin);
        if (err != null) return err;
        setState(() {
          _old = pin;
          _stage = _Stage.enterNew;
          _notice = null;
        });
        return null;
      case _Stage.enterNew:
        if (RegExp(r'^(\d)\1+$').hasMatch(pin)) return 'Choose a PIN that is not all the same digit';
        setState(() {
          _first = pin;
          _stage = _Stage.confirmNew;
          _notice = null;
        });
        return null;
      case _Stage.confirmNew:
        if (pin != _first) {
          setState(() {
            _first = null;
            _stage = _Stage.enterNew;
            _notice = 'The PINs did not match. Start again.';
          });
          return null;
        }
        final nav = Navigator.of(context);
        String? err;
        if (widget.changing) {
          err = await lock.changePin(_old!, pin);
        } else {
          await lock.setupPin(pin);
        }
        if (err != null) return err;
        if (!mounted) return null;
        nav.pop(true);
        showAppSnack(context, widget.changing ? 'PIN changed' : 'PIN created. Your vault is ready 🔒');
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final (title, sub) = switch (_stage) {
      _Stage.verifyOld => ('Enter your current PIN', null),
      _Stage.enterNew => (widget.changing ? 'Enter a new PIN' : 'Create a 6-digit PIN', _notice ?? 'You will use it to open the vault and lock the app.'),
      _Stage.confirmNew => ('Confirm your PIN', 'Enter the same PIN again.'),
    };
    return Scaffold(
      appBar: AppBar(title: Text(widget.changing ? 'Change PIN' : 'Create PIN')),
      body: SafeArea(
        child: Center(child: PinPad(key: ValueKey(_stage), title: title, subtitle: sub, onCompleted: _handle)),
      ),
    );
  }
}

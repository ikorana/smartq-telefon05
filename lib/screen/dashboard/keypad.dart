import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_numpad/simple_numpad.dart';

class KeypadWidget extends StatefulWidget {
  final String message;
  final String password;

  const KeypadWidget({
    super.key,
    required this.message,
    required this.password,
  });

  /// Keypad dialogunu açar ve sonucu Future<bool> olarak döndürür.
  static Future<bool> show({required String message, required String password}) async {
    final result = await Get.dialog<bool>(
      KeypadWidget(message: message, password: password),
      barrierDismissible: true,
    );
    return result ?? false;
  }

  @override
  State<KeypadWidget> createState() => _KeypadWidgetState();
}

class _KeypadWidgetState extends State<KeypadWidget> {
  String _input = "";

  void _onPressed(String value) {
    setState(() {
      if (value == 'clear') {
        _input = "";
      } else if (value == 'backspace') {
        if (_input.isNotEmpty) {
          _input = _input.substring(0, _input.length - 1);
        }
      } else {
        // Sadece şifre uzunluğu kadar girişe izin ver
        if (_input.length < widget.password.length) {
          _input += value;
        }
      }
    });

    // Şifreyi kontrol et
    if (_input.length == widget.password.length) {
      if (_input == widget.password) {
        // Başarılı: Kısa bir gecikme ile true dönerek kapat
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) Get.back(result: true);
        });
      } else {
        // Hatalı giriş: Kullanıcıya yanlış olduğunu göstermek için kısa bir bekleme sonrası temizle
        // Ve isteğe bağlı olarak false dönerek kapat
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) {
            setState(() {
              _input = "";
            });
            // İstek "false döndürecek" dediği için burada kapatıp false da dönebiliriz.
            Get.back(result: false);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 25),
              // Şifre görsel gösterimi (Noktalar)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.password.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index < _input.length ? Colors.blueAccent : Colors.grey.shade300,
                      border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 35),
              SimpleNumpad(
                buttonWidth: 70,
                buttonHeight: 70,
                gridSpacing: 15,
                buttonBorderRadius: 35,
                buttonBorderSide: BorderSide(
                  color: Colors.grey.shade300,
                  width: 1,
                ),
                useBackspace: true,
                optionText: 'clear',
                onPressed: _onPressed,
              ),
              const SizedBox(height: 25),
              TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text(
                  "İPTAL",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

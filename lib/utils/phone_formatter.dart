import 'package:flutter/services.dart';

class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    
    final digitsOnly = text.replaceAll(RegExp(r'[^\d]'), '');
    
    final limitedDigits = digitsOnly.length > 11 
        ? digitsOnly.substring(0, 11) 
        : digitsOnly;
    
    if (limitedDigits.isEmpty) {
      return newValue;
    }
    
    String formatted = '';
    
    if (limitedDigits.length >= 1) {
      formatted = limitedDigits[0];
    }
    
    if (limitedDigits.length > 1) {
      formatted += ' (${limitedDigits.substring(1, limitedDigits.length > 4 ? 4 : limitedDigits.length)}';
    }
    
    if (limitedDigits.length > 4) {
      formatted += ') ${limitedDigits.substring(4, limitedDigits.length > 7 ? 7 : limitedDigits.length)}';
    }
    
    if (limitedDigits.length > 7) {
      formatted += ' ${limitedDigits.substring(7, limitedDigits.length > 9 ? 9 : limitedDigits.length)}';
    }
    
    if (limitedDigits.length > 9) {
      formatted += '-${limitedDigits.substring(9)}';
    }
    
    if (limitedDigits.length > 1 && limitedDigits.length <= 4 && !formatted.contains(')')) {
      formatted += ')';
    }
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
  
  static String unformat(String formattedPhone) {
    return formattedPhone.replaceAll(RegExp(r'[^\d]'), '');
  }
}


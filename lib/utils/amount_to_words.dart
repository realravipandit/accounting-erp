class AmountToWords {
  static String convert(int number) {
    if (number == 0) return 'Zero';

    final units = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven',
      'Eight', 'Nine', 'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen',
      'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
    final tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty',
      'Seventy', 'Eighty', 'Ninety'];

    String convertInner(int n) {
      if (n < 20) return units[n];
      if (n < 100) return '${tens[n ~/ 10]}${n % 10 > 0 ? " ${units[n % 10]}" : ""}';
      if (n < 1000) return '${units[n ~/ 100]} Hundred${n % 100 > 0 ? " ${convertInner(n % 100)}" : ""}';
      if (n < 100000) return '${convertInner(n ~/ 1000)} Thousand${n % 1000 > 0 ? " ${convertInner(n % 1000)}" : ""}';
      if (n < 10000000) return '${convertInner(n ~/ 100000)} Lakh${n % 100000 > 0 ? " ${convertInner(n % 100000)}" : ""}';
      return '${convertInner(n ~/ 10000000)} Crore${n % 10000000 > 0 ? " ${convertInner(n % 10000000)}" : ""}';
    }

    return convertInner(number);
  }
}
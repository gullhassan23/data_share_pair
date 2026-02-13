import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryColor = Color(0xFF4669f5);
  static const Color secondryColor = Color(0xFFfa4646);
  static const Color backGroudColor = Color(0xFF101010);
  static const Color backGroundColorWithOpacityh =
      Color.fromARGB(255, 70, 69, 69); //#A3A3A3



  static const Color primaryGreenColor = Color(0xFF3DD8A8);
  static const Color primaryGreen2Color = Color(0xFF1D906D);
  static const Color seconderyGreenColor = Color(0xFFA3A3A3);

  static const Color textTodayColor = Color(0xFF606060);
  static const Color btnBackgroundColor = Color(0xFF3DD8A8);
  static const Color verticalTwoTextColor = Color(0xFF1D906D);
  static const Color dividerLineColor = Color(0xFFA3A3A3); //#C2C2C2 #8F8F8F

  static const Color isLikedColor = Color.fromARGB(255, 161, 243, 163);
  static const Color disLikedColor = Color.fromARGB(255, 249, 192, 187);
  static const Color btnRedColor = Color.fromARGB(255, 208, 63, 31);
  static const Color btnSkyColor = Color.fromARGB(255, 45, 148, 212);

  static const Color lightGreenColor = Color(0xffDAF2E5);
  static const Color darkGreen1Color = Color(0xff4BB17B);
  static const Color darkGreen2Color = Color(0xff0F7D43);

  // Define a linear gradient with light green colors
  static const LinearGradient lightGreenLinearGradient = LinearGradient(
    colors: greenButtonGradients,
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient crossBtnLinearGradient = LinearGradient(
    colors: [Color(0xffC2C2C2), Color(0xff8F8F8F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomLeft,
  );

  static const Color buttonPrimaryColor = Color(0xFF4669f5);
  static const Color buttonSecondryColor = Color(0xFFfa4646);
  static const Color iconColor = Color(0xFF4669f5);
  static const Color textColor = Color(0xFF001e7d);
  static const Color successColor = Colors.green;
  static const Color successMessageColor = Color(0xFFed9702);
  static const Color alertMessageColor = Color(0xFFfff3cd);
  static const Color ratingColor = Color(0xFFf7c00a);
  static const Color drawerHeaderColor = Color.fromARGB(255, 19, 141, 241);
  static const Color graphAreaCoveredColor = Color(0xFFe2f2e7);
  static const Color filterSectionHeaderText = Color(0xFF6E8076);

  static const Color whiteColor = Colors.white;
  static const Color blackColor = Colors.black;
  static const Color alertColor = Color(0xFFfa4646);
  static const Color greyColor = Colors.grey;
  static const Color greyLightColor = Color(0xFFE1E1E1);
  static const Color lightGreyColor = Color.fromARGB(255, 218, 216, 216);
  static const Color dividerColor = Color.fromRGBO(207, 209, 210, 1);
  static const Color dividerInfoColor = Color.fromARGB(255, 3, 2, 2);
  static const Color greyButton = Color(0xFF434749);
  static const Color greyTextField1 = Color(0xFFD0D0D0);
  static const Color text2 = Color(0xFF303733);
  static const Color checkMark = Color(0xFF4BB17B);
  static const Color checkBorder = Color(0xFF606060);
  static const Color checkBackground = whiteColor;

  static const List<Color> greenButtonGradients = [
    AppColors.primaryGreenColor,
    AppColors.primaryGreen2Color,
  ];
  static const List<Color> dashboardGreenGradients = [
    AppColors.primaryGreen2Color,
    AppColors.primaryGreenColor,
  ];

  static const List<Color> tealButtonGradients = [
    Color(0xFF3DC1D8), // completed colors
    Color(0xFF1D7F90),
  ];

  static const List<Color> purpleButtonGradients = [
    Color(0xFFB13DD8), //archived colors
    Color(0xFF731D90),
  ];

  static const List<Color> greyButtonGradients = [
    Color(0xFFB1B1B1), // Default fallback colors
    Color(0xFF7D7D7D)
  ];

  // Dashboard pie chart colors
  static const Color inProgressColor = Colors.blue;
  static const Color completedColor = Colors.green;
  static const Color overDueColor = Colors.red;
  static const Color upcompingColor = Colors.amber;
  static const Color archivedColor = Colors.purple;
}

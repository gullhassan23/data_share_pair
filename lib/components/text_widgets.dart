import 'package:flutter/material.dart';
import 'package:share_app_latest/utils/color.dart';

const String _fontFamily = 'Oxanium';

TextStyle _baseTextStyle({
  required double fontSize,
  required FontWeight fontWeight,
  required Color color,
  double? letterSpacing,
}) {
  return TextStyle(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    fontFamily: _fontFamily,
    letterSpacing: letterSpacing,
  );
}

/* ===================== HEADINGS ===================== */

Widget h1(String text,
    {Color color = AppColors.blackColor,
    TextAlign align = TextAlign.start,
    int? maxLines}) {
  return Text(
    text,
    textAlign: align,
    maxLines: maxLines,
    style: _baseTextStyle(
      fontSize: 32,
      fontWeight: FontWeight.bold,
      color: color,
    ),
  );
}

Widget h2(String text,
    {Color color = AppColors.blackColor,
    TextAlign align = TextAlign.start,
    int? maxLines}) {
  return Text(
    text,
    textAlign: align,
    maxLines: maxLines,
    style: _baseTextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      color: color,
    ),
  );
}

Widget h3(String text,
    {Color color = AppColors.blackColor,
    TextAlign align = TextAlign.start,
    int? maxLines}) {
  return Text(
    text,
    textAlign: align,
    maxLines: maxLines,
    style: _baseTextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w500,
      color: color,
    ),
  );
}

Widget h4(String text,
    {Color color = AppColors.blackColor,
    TextAlign align = TextAlign.start,
    int? maxLines}) {
  return Text(
    text,
    textAlign: align,
    maxLines: maxLines,
    style: _baseTextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w500,
      color: color,
    ),
  );
}

Widget h5(String text,
    {Color color = AppColors.blackColor,
    TextAlign align = TextAlign.start,
    int? maxLines}) {
  return Text(
    text,
    textAlign: align,
    maxLines: maxLines,
    style: _baseTextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w500,
      color: color,
    ),
  );
}

Widget h6(String text,
    {Color color = AppColors.blackColor,
    TextAlign align = TextAlign.start,
    int? maxLines}) {
  return Text(
    text,
    textAlign: align,
    maxLines: maxLines,
    style: _baseTextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: color,
    ),
  );
}

/* ===================== SUBTITLES ===================== */

Widget subtitle1(String text,
    {Color color = AppColors.blackColor,
    TextAlign align = TextAlign.start}) {
  return Text(
    text,
    textAlign: align,
    style: _baseTextStyle(
      fontSize: 16,
      fontWeight: FontWeight.normal,
      color: color,
    ),
  );
}

Widget subtitle2(String text,
    {Color color = AppColors.blackColor,
    TextAlign align = TextAlign.start}) {
  return Text(
    text,
    textAlign: align,
    style: _baseTextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: color,
    ),
  );
}

/* ===================== BODY ===================== */

Widget body1(String text,
    {Color color = AppColors.blackColor,
    TextAlign align = TextAlign.start,
    int? maxLines}) {
  return Text(
    text,
    textAlign: align,
    maxLines: maxLines,
    style: _baseTextStyle(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: color,
    ),
  );
}

Widget body2(String text,
    {Color color = AppColors.blackColor,
    TextAlign align = TextAlign.start}) {
  return Text(
    text,
    textAlign: align,
    style: _baseTextStyle(
      fontSize: 12,
      fontWeight: FontWeight.normal,
      color: color,
    ),
  );
}

/* ===================== CAPTION ===================== */

Widget caption(String text,
    {Color color = AppColors.greyColor,
    TextAlign align = TextAlign.start}) {
  return Text(
    text,
    textAlign: align,
    style: _baseTextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w300,
      color: color,
    ),
  );
}

/* ===================== BUTTON ===================== */

Widget buttonText(String text,
    {Color color = AppColors.whiteColor}) {
  return Text(
    text,
    textAlign: TextAlign.center,
    style: _baseTextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: color,
      letterSpacing: 1.1,
    ),
  );
}

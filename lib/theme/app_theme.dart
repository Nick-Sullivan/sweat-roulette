import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_palette.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// The app's one and only theme.
///
/// Dark-only by design: the whole visual language — value-separated layers, a
/// champagne reward colour that has to *glow* — only works on a dark canvas,
/// and a second theme would always be the weaker one.
abstract final class SweatTheme {
  /// Hand-written rather than [ColorScheme.fromSeed]. Seeding would push these
  /// exact browns through Material's tonal-palette generator and hand back
  /// something adjacent but not ours.
  static const colorScheme = ColorScheme(
    brightness: Brightness.dark,

    primary: SweatPalette.cognac,
    onPrimary: SweatPalette.inkOnBrand,
    primaryContainer: SweatPalette.cognacDeep,
    onPrimaryContainer: SweatPalette.cognacLight,

    // Champagne is Material's "secondary", but the app should treat it as the
    // reward colour and use it sparingly — see [SweatColors.champagne].
    secondary: SweatPalette.champagne,
    onSecondary: SweatPalette.inkOnBrand,
    secondaryContainer: SweatPalette.surfaceAlt,
    onSecondaryContainer: SweatPalette.inkHigh,

    tertiary: SweatPalette.outlineStrong,
    onTertiary: SweatPalette.inkOnBrand,
    tertiaryContainer: SweatPalette.surfaceHigh,
    onTertiaryContainer: SweatPalette.inkHigh,

    error: SweatPalette.errorInk,
    onError: SweatPalette.inkOnBrand,
    errorContainer: SweatPalette.errorFill,
    onErrorContainer: SweatPalette.errorInkOnFill,

    surface: SweatPalette.surface,
    onSurface: SweatPalette.inkHigh,
    onSurfaceVariant: SweatPalette.inkLow,

    surfaceContainerLowest: SweatPalette.sink,
    surfaceContainerLow: SweatPalette.surfaceLow,
    surfaceContainer: SweatPalette.surface,
    surfaceContainerHigh: SweatPalette.surfaceHigh,
    surfaceContainerHighest: SweatPalette.surfaceAlt,

    outline: SweatPalette.outline,
    outlineVariant: SweatPalette.surfaceAlt,

    inverseSurface: SweatPalette.inkHigh,
    onInverseSurface: SweatPalette.canvas,
    inversePrimary: SweatPalette.cognacDeep,

    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
  );

  static final dark = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    textTheme: SweatTypography.textTheme,
    scaffoldBackgroundColor: SweatPalette.canvas,
    canvasColor: SweatPalette.canvas,
    splashFactory: InkRipple.splashFactory,
    extensions: const [SweatColors.dark, SweatTextStyles.dark],

    appBarTheme: const AppBarTheme(
      backgroundColor: SweatPalette.canvas,
      foregroundColor: SweatPalette.inkHigh,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      // The wordmark treatment, dialled back a little for the bar. Bebas has no
      // lowercase, so the title renders as caps whatever string is passed.
      titleTextStyle: TextStyle(
        fontFamily: 'BebasNeue',
        fontSize: 24,
        fontWeight: FontWeight.w400,
        letterSpacing: 3.4,
        color: SweatPalette.inkHigh,
      ),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: SweatPalette.canvas,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    ),

    // Flat by design: layers separate by value, so no elevation overlays and no
    // shadows anywhere. A card is a surface step plus a hairline.
    cardTheme: CardThemeData(
      color: SweatPalette.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SweatRadius.card),
        side: const BorderSide(color: SweatPalette.outline),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, SweatSize.button),
        padding: const EdgeInsets.symmetric(horizontal: SweatSpace.xl),
        shape: const StadiumBorder(),
        textStyle: SweatTypography.textTheme.labelLarge,
        backgroundColor: SweatPalette.cognac,
        foregroundColor: SweatPalette.inkOnBrand,
        disabledBackgroundColor: SweatPalette.surfaceAlt,
        disabledForegroundColor: SweatPalette.inkLow,
      ),
    ),

    // Cognac border rather than a grey one: it clears 3:1 against the canvas
    // and keeps the outlined variant on-brand.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, SweatSize.button),
        padding: const EdgeInsets.symmetric(horizontal: SweatSpace.xl),
        shape: const StadiumBorder(),
        textStyle: SweatTypography.textTheme.labelLarge,
        foregroundColor: SweatPalette.cognac,
        side: const BorderSide(color: SweatPalette.cognac, width: 1.5),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, SweatSize.minTarget),
        padding: const EdgeInsets.symmetric(horizontal: SweatSpace.lg),
        shape: const StadiumBorder(),
        textStyle: SweatTypography.textTheme.labelLarge,
        foregroundColor: SweatPalette.champagne,
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: SweatPalette.surfaceAlt,
      selectedColor: SweatPalette.cognacDeep,
      side: const BorderSide(color: SweatPalette.outline),
      labelStyle: SweatTypography.textTheme.labelMedium?.copyWith(
        color: SweatPalette.inkHigh,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: SweatSpace.md,
        vertical: SweatSpace.md,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SweatRadius.chip),
      ),
    ),

    // The app's first text input lands on the Exercises screen's search field.
    // Defined here rather than at that call site so Config's inputs match it
    // without anyone having to remember to make them.
    //
    // `surfaceAlt` is the token DESIGN.md names for "chip, input, inactive
    // track". The resting border is the decorative hairline; focus steps it up
    // to `outlineStrong`, which is the token for a border that carries meaning
    // and the one that clears 3:1.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: SweatPalette.surfaceAlt,
      hintStyle: SweatTypography.textTheme.bodyLarge?.copyWith(
        color: SweatPalette.inkLow,
      ),
      prefixIconColor: SweatPalette.inkLow,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: SweatSpace.lg,
        vertical: SweatSpace.md,
      ),
      // A stadium, so the field reads as a set with the action pill sitting
      // directly beneath it.
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(SweatRadius.pill)),
        borderSide: BorderSide(color: SweatPalette.outline),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(SweatRadius.pill)),
        borderSide: BorderSide(color: SweatPalette.outline),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(SweatRadius.pill)),
        borderSide: BorderSide(color: SweatPalette.outlineStrong, width: 1.5),
      ),
    ),

    listTileTheme: const ListTileThemeData(
      minVerticalPadding: SweatSpace.md,
      iconColor: SweatPalette.inkLow,
      textColor: SweatPalette.inkHigh,
    ),

    dividerTheme: const DividerThemeData(
      color: SweatPalette.outline,
      thickness: 1,
      space: 1,
    ),

    iconTheme: const IconThemeData(color: SweatPalette.inkHigh, size: 24),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: SweatPalette.surfaceAlt,
      contentTextStyle: SweatTypography.textTheme.bodyMedium?.copyWith(
        color: SweatPalette.inkHigh,
      ),
      actionTextColor: SweatPalette.champagne,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SweatRadius.chip),
      ),
    ),
  );
}

/// Ergonomic access to the two theme extensions, so call sites read
/// `context.sweatColors.champagne` instead of a `Theme.of` incantation.
extension SweatThemeContext on BuildContext {
  SweatColors get sweatColors => Theme.of(this).extension<SweatColors>()!;
  SweatTextStyles get sweatText => Theme.of(this).extension<SweatTextStyles>()!;
}

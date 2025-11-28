import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class AppLocalizations {
  final Locale locale;
  late Map<String, dynamic> _localizedStrings;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('es', 'ES'),
    Locale('en', 'US'),
    Locale('it', 'IT'),
    Locale('de', 'DE'),
  ];

  Future<bool> load() async {
    String jsonString;
    try {
      jsonString = await rootBundle.loadString('lib/l10n/${locale.languageCode}.json');
    } catch (e) {
      // Si no existe el archivo, usar español como fallback
      jsonString = await rootBundle.loadString('lib/l10n/es.json');
    }
    _localizedStrings = json.decode(jsonString);
    return true;
  }

  String translate(String key) {
    final keys = key.split('.');
    dynamic value = _localizedStrings;
    for (String k in keys) {
      if (value is Map && value.containsKey(k)) {
        value = value[k];
      } else {
        return key; // Retornar la clave si no se encuentra
      }
    }
    return value.toString();
  }

  // Getters para textos comunes
  String get appName => translate('app.name');
  String get welcomeTitle => translate('welcome.title');
  String get welcomeSubtitle => translate('welcome.subtitle');
  String get navHome => translate('nav.home');
  String get navCompany => translate('nav.company');
  String get navService => translate('nav.service');
  String get navRates => translate('nav.rates');
  String get navDestination => translate('nav.destination');
  String get navContacts => translate('nav.contacts');
  String get originLabel => translate('form.origin');
  String get destinationLabel => translate('form.destination');
  String get pickupDate => translate('form.pickupDate');
  String get pickupTime => translate('form.pickupTime');
  String get passengers => translate('form.passengers');
  String get passenger => translate('form.passenger');
  String get seePrices => translate('form.seePrices');
  String get requestRide => translate('form.requestRide');
  String get register => translate('auth.register');
  String get login => translate('auth.login');
  String get logout => translate('auth.logout');
  String get myProfile => translate('auth.myProfile');
  String get featuresTitle => translate('features.title');
  String get featurePayment => translate('features.payment');
  String get featureSafety => translate('features.safety');
  String get featureAvailability => translate('features.availability');
  String get featureSupport => translate('features.support');
  String get vehicleEconomy => translate('vehicles.economy');
  String get vehicleSedan => translate('vehicles.sedan');
  String get vehicleSUV => translate('vehicles.suv');
  String get vehicleVan => translate('vehicles.van');
  String get vehicleLuxury => translate('vehicles.luxury');
  String get vehicleSpacious => translate('vehicles.spacious');
  String get vehicleComfortable => translate('vehicles.comfortable');
  String get vehiclePremium => translate('vehicles.premium');
  String get vehicleLuggage => translate('vehicles.luggage');
  String get pickupLocation => translate('form.pickupLocation');
  String get dropoffLocation => translate('form.dropoffLocation');
  String get distance => translate('form.distance');
  String get estimatedPrice => translate('form.estimatedPrice');
  String get accountRequired => translate('auth.accountRequired');
  String get quickBooking => translate('features.quickBooking');
  String get vehicleEconomyDesc => translate('vehicles.economyDesc');
  String get vehicleSedanDesc => translate('vehicles.sedanDesc');
  String get vehicleSUVDesc => translate('vehicles.suvDesc');
  String get vehicleVanDesc => translate('vehicles.vanDesc');
  String get vehicleLuxuryDesc => translate('vehicles.luxuryDesc');
  String get cancel => translate('form.cancel');
  String get select => translate('form.select');
  String get verifiedDrivers => translate('form.verifiedDrivers');
  String get originPlaceholder => translate('form.originPlaceholder');
  String get destinationPlaceholder => translate('form.destinationPlaceholder');
  String get timePlaceholder => translate('form.timePlaceholder');
  String get createAccount => translate('form.createAccount');
  String get accountRequiredMessage => translate('form.accountRequiredMessage');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['es', 'en', 'it', 'de'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    AppLocalizations localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

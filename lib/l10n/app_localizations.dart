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
      // Si no existe el archivo, intentar usar español como fallback
      try {
        jsonString = await rootBundle.loadString('lib/l10n/es.json');
      } catch (e2) {
        // Si tampoco existe español, usar un mapa vacío para evitar que la app se bloquee
        // Esto permite que la app funcione aunque los archivos de localización no estén disponibles
        _localizedStrings = <String, dynamic>{};
        return true;
      }
    }
    try {
      _localizedStrings = json.decode(jsonString);
    } catch (e) {
      // Si hay un error al decodificar JSON, usar un mapa vacío
      _localizedStrings = <String, dynamic>{};
    }
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
  String get vehicleBusiness => translate('vehicles.business');
  String get vehicleMinivan7pax => translate('vehicles.minivan7pax');
  String get vehicleMinivanLuxury6pax => translate('vehicles.minivanLuxury6pax');
  String get vehicleMinibus8pax => translate('vehicles.minibus8pax');
  String get vehicleBus16pax => translate('vehicles.bus16pax');
  String get vehicleBus19pax => translate('vehicles.bus19pax');
  String get vehicleBus50pax => translate('vehicles.bus50pax');
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
  String get loginOrCreateAccount => translate('form.loginOrCreateAccount');
  String get accountRequiredMessage => translate('form.accountRequiredMessage');

  // Services
  String get servicesIntro => translate('services.intro');
  String get servicesPrivateTransferTitle => translate('services.privateTransfer.title');
  String get servicesPrivateTransferDescription =>
      translate('services.privateTransfer.description');
  String get servicesSimpleBookingTitle => translate('services.simpleBooking.title');
  String get servicesSimpleBookingDescription => translate('services.simpleBooking.description');
  String get servicesCustomerSatisfactionTitle => translate('services.customerSatisfaction.title');
  String get servicesCustomerSatisfactionDescription =>
      translate('services.customerSatisfaction.description');
  String get servicesWaitingTimeTitle => translate('services.waitingTime.title');
  String get servicesWaitingTimeDescription => translate('services.waitingTime.description');
  String get servicesMeetGreetTitle => translate('services.meetGreet.title');
  String get servicesMeetGreetDescription => translate('services.meetGreet.description');
  String get servicesSpecialServicesTitle => translate('services.specialServices.title');
  String get servicesSpecialServicesDescription =>
      translate('services.specialServices.description');

  // Company
  String get companyTitle => translate('company.title');
  String get companyDescription => translate('company.description');
  String get companyPunctualityTitle => translate('company.punctuality.title');
  String get companyPunctualityDescription => translate('company.punctuality.description');
  String get companyProfessionalDriversTitle => translate('company.professionalDrivers.title');
  String get companyProfessionalDriversDescription =>
      translate('company.professionalDrivers.description');
  String get companySecurityTitle => translate('company.security.title');
  String get companySecurityDescription => translate('company.security.description');
  String get companyReliableCompanyTitle => translate('company.reliableCompany.title');
  String get companyReliableCompanyDescription => translate('company.reliableCompany.description');

  // About
  String get aboutTitle => translate('about.title');
  String get aboutParagraph1 => translate('about.paragraph1');
  String get aboutParagraph2 => translate('about.paragraph2');
  String get aboutLongExperience => translate('about.features.longExperience');
  String get aboutTopDrivers => translate('about.features.topDrivers');
  String get aboutFirstClassServices => translate('about.features.firstClassServices');
  String get aboutAlwaysOnTime => translate('about.features.alwaysOnTime');
  String get aboutAllAirportTransfers => translate('about.features.allAirportTransfers');

  // Common
  String get profileComingSoon => translate('common.profileComingSoon');
  String get logoutError => translate('common.logoutError');
  String get imageNotAvailable => translate('common.imageNotAvailable');
  String get accept => translate('common.accept');

  // Features
  String get featuresSubtitle => translate('features.subtitle');
  String get featuresFeature1Title => translate('features.feature1.title');
  String get featuresFeature1Description => translate('features.feature1.description');
  String get featuresFeature2Title => translate('features.feature2.title');
  String get featuresFeature2Description => translate('features.feature2.description');
  String get featuresFeature3Title => translate('features.feature3.title');
  String get featuresFeature3Description => translate('features.feature3.description');

  // Destinations
  String get destinationsSubtitle => translate('destinations.subtitle');
  String get destinationsBookButton => translate('destinations.bookButton');
  String get destinationsRanking => translate('destinations.ranking');
  String get destinationsRomeAirport => translate('destinations.rome.airport');
  String get destinationsRomeCenter => translate('destinations.rome.center');
  String get destinationsMilanAirport => translate('destinations.milan.airport');
  String get destinationsMilanCenter => translate('destinations.milan.center');
  String get destinationsFlorenceAirport => translate('destinations.florence.airport');
  String get destinationsFlorenceCenter => translate('destinations.florence.center');
  String get destinationsBolognaAirport => translate('destinations.bologna.airport');
  String get destinationsBolognaCenter => translate('destinations.bologna.center');
  String get destinationsPisaAirport => translate('destinations.pisa.airport');
  String get destinationsPisaCenter => translate('destinations.pisa.center');

  // TimePicker
  String get timePickerSelectTime => translate('timePicker.selectTime');
  String get timePickerHour => translate('timePicker.hour');
  String get timePickerMinute => translate('timePicker.minute');
  String timePickerEditLabel(String label) =>
      translate('timePicker.editLabel').replaceAll('{label}', label);

  // Contacts
  String get contactsTitle => translate('contacts.title');
  String get contactsSubtitle => translate('contacts.subtitle');
  String get contactsPhone => translate('contacts.phone');
  String get contactsEmail => translate('contacts.email');
  String get contactsWebsite => translate('contacts.website');
  String get contactsLocation => translate('contacts.location');

  // Footer
  String get footerDescription1 => translate('footer.description1');
  String get footerDescription2 => translate('footer.description2');
  String footerCopyright(int year) =>
      translate('footer.copyright').replaceAll('{year}', year.toString());

  // Request Ride
  String get requestRideRequestNewRide => translate('requestRide.requestNewRide');
  String get requestRideTripDate => translate('requestRide.tripDate');
  String get requestRideTripTime => translate('requestRide.tripTime');
  String get requestRideTripCost => translate('requestRide.tripCost');
  String get requestRideRequestRide => translate('requestRide.requestRide');
  String get requestRideSelectDate => translate('requestRide.selectDate');
  String get requestRideSelectTime => translate('requestRide.selectTime');
  String get requestRideFullName => translate('requestRide.fullName');
  String get requestRideEmailAddress => translate('requestRide.emailAddress');
  String get requestRideContactNumber => translate('requestRide.contactNumber');
  String get requestRideInvalidFormat => translate('requestRide.invalidFormat');
  String get requestRideInvalidFormatWithExample =>
      translate('requestRide.invalidFormatWithExample');
  String get requestRideSignOut => translate('requestRide.signOut');
  String get requestRideUnknownError => translate('requestRide.unknownError');

  // Common
  String get commonGettingLocation => translate('common.gettingLocation');
  String get commonVehicle => translate('common.vehicle');
  String get commonJourneyFare => translate('common.journeyFare');
  String get commonPriceMustBeGreaterThanZero => translate('common.priceMustBeGreaterThanZero');
  String get commonInvalidDateTimeFormat => translate('common.invalidDateTimeFormat');
  String get commonAddressNotFound => translate('common.addressNotFound');
  String commonAddressNotFoundWithAddress(String address) =>
      '${translate('common.addressNotFound')}: $address';
  String commonErrorSearchingAddress(String error) =>
      '${translate('common.errorSearchingAddress')}: $error';
  String get commonUnderstood => translate('common.understood');
  String get commonUser => translate('common.user');
  String get commonSelectFromMap => translate('common.selectFromMap');
  String get commonWriteOrSelectAddress => translate('common.writeOrSelectAddress');
  String get commonSelectOption => translate('common.selectOption');
  String get commonPleaseCompleteAllFields => translate('common.pleaseCompleteAllFields');
  String get commonThisFieldIsRequired => translate('common.thisFieldIsRequired');
  String get commonEnterValidEmail => translate('common.enterValidEmail');
  String get commonVerifiedDrivers => translate('common.verifiedDrivers');
  List<String> get commonWeekDays => List<String>.from(translate('common.weekDays') as List);
  List<String> get commonMonths => List<String>.from(translate('common.months') as List);

  // Form
  String get formOrigin => translate('form.origin');
  String get formDestination => translate('form.destination');
  String get formOriginRequired => translate('form.originRequired');
  String get formDestinationRequired => translate('form.destinationRequired');
  String get formPassenger => translate('form.passenger');
  String get formPassengers => translate('form.passengers');
  String get formHandLuggage => translate('form.handLuggage');
  String get formCheckInLuggage => translate('form.checkInLuggage');
  String get formChildSeats => translate('form.childSeats');
  String get formDistance => translate('form.distance');
  String get formDistanceKm => translate('form.distanceKm');
  String get formPriority => translate('form.priority');
  String get formAdditionalNotes => translate('form.additionalNotes');
  String get formCompleteDetails => translate('form.completeDetails');
  String get formTimeFormatHint => translate('form.timeFormatHint');
  String get formVehicleType => translate('form.vehicleType');

  // Payment
  String get paymentTripSummary => translate('payment.tripSummary');
  String get paymentProcessingError => translate('payment.processingError');
  String get paymentUnknownError => translate('payment.unknownError');
  String get paymentInvalidDate => translate('payment.invalidDate');
  String get paymentPayWithPayPal => translate('payment.payWithPayPal');
  String get paymentEnterCardData => translate('payment.enterCardData');
  String get paymentCard => translate('payment.card');
  String get paymentApple => translate('payment.apple');
  String get paymentGoogle => translate('payment.google');
  String get paymentDeposit => translate('payment.deposit');
  String get paymentPay => translate('payment.pay');
  String get paymentBeneficiary => translate('payment.beneficiary');
  String get paymentBank => translate('payment.bank');
  String get paymentAddress => translate('payment.address');
  String get paymentCardNumberRequired => translate('payment.cardNumberRequired');
  String get paymentInvalidCardNumber => translate('payment.invalidCardNumber');
  String get paymentOnlyNumbersAllowed => translate('payment.onlyNumbersAllowed');
  String get paymentExpiryDateRequired => translate('payment.expiryDateRequired');
  String get paymentCvvRequired => translate('payment.cvvRequired');
  String get paymentCvvInvalid => translate('payment.cvvInvalid');
  String get paymentExpiryFormat => translate('payment.expiryFormat');

  // Summary
  String get summaryOrigin => translate('summary.origin');
  String get summaryDestination => translate('summary.destination');
  String get summaryDistance => translate('summary.distance');
  String get summaryPassengers => translate('summary.passengers');
  String get summaryChildSeats => translate('summary.childSeats');
  String get summaryHandLuggage => translate('summary.handLuggage');
  String get summaryCheckInLuggage => translate('summary.checkInLuggage');
  String get summaryPassengerName => translate('summary.passengerName');
  String get summaryContactNumber => translate('summary.contactNumber');
  String get summaryDateTime => translate('summary.dateTime');
  String get summaryPaymentMethod => translate('summary.paymentMethod');

  // Receipt
  String get receiptNumber => translate('receipt.receiptNumber');
  String get receiptDate => translate('receipt.receiptDate');
  String get receiptTripDetails => translate('receipt.receiptTripDetails');
  String get receiptClientInfo => translate('receipt.receiptClientInfo');
  String get receiptPaymentSummary => translate('receipt.receiptPaymentSummary');
  String get receiptName => translate('receipt.receiptName');
  String get receiptEmail => translate('receipt.receiptEmail');
  String get receiptPhone => translate('receipt.receiptPhone');
  String get receiptSubtotal => translate('receipt.receiptSubtotal');
  String get receiptTotal => translate('receipt.receiptTotal');
  String get receiptStatus => translate('receipt.receiptStatus');
  String get receiptPaid => translate('receipt.receiptPaid');
  String get receiptScheduledDateTime => translate('receipt.receiptScheduledDateTime');
  String get receiptThankYou => translate('receipt.receiptThankYou');
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

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
  String get navTours => translate('nav.tours');
  String get navWeddings => translate('nav.weddings');
  String get navTerms => translate('nav.terms');
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
  String get downloadPdf => translate('auth.downloadPdf');
  String get featuresTitle => translate('features.title');
  String get featurePayment => translate('features.payment');
  String get featureSafety => translate('features.safety');
  String get featureAvailability => translate('features.availability');
  String get featureSupport => translate('features.support');
  String get vehicleSedan => translate('vehicles.sedan');
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
  String get vehicleSedanDesc => translate('vehicles.sedanDesc');
  String get vehicleBusinessDesc => translate('vehicles.businessDesc');
  String get vehicleMinivan7paxDesc => translate('vehicles.minivan7paxDesc');
  String get vehicleMinivanLuxury6paxDesc => translate('vehicles.minivanLuxury6paxDesc');
  String get vehicleMinibus8paxDesc => translate('vehicles.minibus8paxDesc');
  String get vehicleBus16paxDesc => translate('vehicles.bus16paxDesc');
  String get vehicleBus19paxDesc => translate('vehicles.bus19paxDesc');
  String get vehicleBus50paxDesc => translate('vehicles.bus50paxDesc');
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
  String get destinationsBergamoAirport => translate('destinations.bergamo.airport');
  String get destinationsBergamoCenter => translate('destinations.bergamo.center');
  String get destinationsCataniaAirport => translate('destinations.catania.airport');
  String get destinationsCataniaCenter => translate('destinations.catania.center');
  String get destinationsLinateAirport => translate('destinations.linate.airport');
  String get destinationsLinateCenter => translate('destinations.linate.center');
  String get destinationsPalermoAirport => translate('destinations.palermo.airport');
  String get destinationsPalermoCenter => translate('destinations.palermo.center');
  String get destinationsTorinoAirport => translate('destinations.torino.airport');
  String get destinationsTorinoCenter => translate('destinations.torino.center');

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
  String get requestRideCompleteDetails => translate('requestRide.completeDetails');

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
  String get commonAllRightsReserved => translate('common.allRightsReserved');
  List<String> get commonWeekDays => List<String>.from(translate('common.weekDays') as List);
  List<String> get commonMonths => List<String>.from(translate('common.months') as List);

  // Form
  String get formOrigin => translate('form.origin');
  String get formDestination => translate('form.destination');
  String get formOriginRequired => translate('form.originRequired');
  String get formDestinationRequired => translate('form.destinationRequired');
  String get formFlightNumber => translate('form.flightNumber');
  String get formFlightNumberHint => translate('form.flightNumberHint');
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
  String get paymentEnterCardDetails => translate('payment.enterCardDetails');
  String get paymentScanWithMobile => translate('payment.scanWithMobile');
  String get paymentLinkOpenedInNewWindow => translate('payment.linkOpenedInNewWindow');
  String get paymentConfirmPayment => translate('payment.confirmPayment');
  String get paymentProcessPayment => translate('payment.processPayment');

  // Summary
  String get summaryOrigin => translate('summary.origin');
  String get summaryDestination => translate('summary.destination');
  String get summaryFlightNumber => translate('summary.flightNumber');
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
  String get receiptTime => translate('receipt.receiptTime');
  String get receiptPaymentProcessed => translate('receipt.receiptPaymentProcessed');
  String get receiptCopiedToClipboard => translate('receipt.receiptCopiedToClipboard');
  String get receiptHopeToServeYouAgain => translate('receipt.receiptHopeToServeYouAgain');

  // WhatsApp messages
  String get whatsappMessageWelcome => translate('whatsapp.messageWelcome');
  String get whatsappMessageRideHelp => translate('whatsapp.messageRideHelp');
  String get whatsappMessagePaymentHelp => translate('whatsapp.messagePaymentHelp');
  String get whatsappMessageReceiptHelp => translate('whatsapp.messageReceiptHelp');
  String get whatsappLabelOrigin => translate('whatsapp.labelOrigin');
  String get whatsappLabelDestination => translate('whatsapp.labelDestination');
  String get whatsappLabelReceiptNumber => translate('whatsapp.labelReceiptNumber');
  String get whatsappLabelDate => translate('whatsapp.labelDate');
  String get whatsappLabelAmount => translate('whatsapp.labelAmount');

  // Tours
  String get toursTitle => translate('tours.title');
  String get toursSubtitle => translate('tours.subtitle');
  String get toursOurTours => translate('tours.ourTours');
  String get toursOurToursDesc => translate('tours.ourToursDesc');
  String get toursCityTitle => translate('tours.cityTitle');
  String get toursCityDesc => translate('tours.cityDesc');
  String get toursHistoricalTitle => translate('tours.historicalTitle');
  String get toursHistoricalDesc => translate('tours.historicalDesc');
  String get toursGastronomicTitle => translate('tours.gastronomicTitle');
  String get toursGastronomicDesc => translate('tours.gastronomicDesc');
  String get toursCoastalTitle => translate('tours.coastalTitle');
  String get toursCoastalDesc => translate('tours.coastalDesc');
  String get toursNatureTitle => translate('tours.natureTitle');
  String get toursNatureDesc => translate('tours.natureDesc');
  String get toursWineTitle => translate('tours.wineTitle');
  String get toursWineDesc => translate('tours.wineDesc');
  String get toursDuration => translate('tours.duration');
  String get toursWhyChooseUs => translate('tours.whyChooseUs');
  String get toursFeature1Title => translate('tours.feature1Title');
  String get toursFeature1Desc => translate('tours.feature1Desc');
  String get toursFeature2Title => translate('tours.feature2Title');
  String get toursFeature2Desc => translate('tours.feature2Desc');
  String get toursFeature3Title => translate('tours.feature3Title');
  String get toursFeature3Desc => translate('tours.feature3Desc');

  // Weddings
  String get weddingsTitle => translate('weddings.title');
  String get weddingsSubtitle => translate('weddings.subtitle');
  String get weddingsOurServices => translate('weddings.ourServices');
  String get weddingsServiceTransportTitle => translate('weddings.serviceTransportTitle');
  String get weddingsServiceTransportDesc => translate('weddings.serviceTransportDesc');
  String get weddingsServiceGuestsTitle => translate('weddings.serviceGuestsTitle');
  String get weddingsServiceGuestsDesc => translate('weddings.serviceGuestsDesc');
  String get weddingsServiceReceptionTitle => translate('weddings.serviceReceptionTitle');
  String get weddingsServiceReceptionDesc => translate('weddings.serviceReceptionDesc');
  String get weddingsServiceHotelTitle => translate('weddings.serviceHotelTitle');
  String get weddingsServiceHotelDesc => translate('weddings.serviceHotelDesc');
  String get weddingsPackages => translate('weddings.packages');
  String get weddingsPackagesDesc => translate('weddings.packagesDesc');
  String get weddingsContactUs => translate('weddings.contactUs');

  // Terms
  String get termsTitle => translate('terms.title');
  String get termsLastUpdate => translate('terms.lastUpdate');
  String get termsIntro => translate('terms.intro');
  
  // Sección 1: PREMESAS
  String get termsSection1Title => translate('terms.section1Title');
  String get termsSection1_1 => translate('terms.section1_1');
  String get termsSection1_2 => translate('terms.section1_2');
  String get termsSection1_3 => translate('terms.section1_3');
  String get termsSection1_3a => translate('terms.section1_3a');
  String get termsSection1_3b => translate('terms.section1_3b');
  
  // Sección 2: RESERVAS
  String get termsSection2Title => translate('terms.section2Title');
  String get termsSection2_1 => translate('terms.section2_1');
  String get termsSection2_2 => translate('terms.section2_2');
  String get termsSection2_2b => translate('terms.section2_2b');
  String get termsSection2_2c => translate('terms.section2_2c');
  String get termsSection2_2d => translate('terms.section2_2d');
  String get termsSection2_3 => translate('terms.section2_3');
  String get termsSection2_3b => translate('terms.section2_3b');
  String get termsSection2_4 => translate('terms.section2_4');
  String get termsSection2_5 => translate('terms.section2_5');
  String get termsSection2_6 => translate('terms.section2_6');
  
  // Sección 3: RECESO Y PENALIDADES
  String get termsSection3Title => translate('terms.section3Title');
  String get termsSection3_1 => translate('terms.section3_1');
  
  // Sección 4: LEY APLICABLE
  String get termsSection4Title => translate('terms.section4Title');
  String get termsSection4_1 => translate('terms.section4_1');
  
  // Sección 5: EQUIPAJE
  String get termsSection5Title => translate('terms.section5Title');
  String get termsSection5_1 => translate('terms.section5_1');
  String get termsSection5_1b => translate('terms.section5_1b');
  String get termsSection5_2 => translate('terms.section5_2');
  
  // Sección 6: RETRASOS
  String get termsSection6Title => translate('terms.section6Title');
  String get termsSection6_1 => translate('terms.section6_1');
  String get termsSection6_2 => translate('terms.section6_2');
  String get termsSection6_2b => translate('terms.section6_2b');
  String get termsSection6_3 => translate('terms.section6_3');
  String get termsSection6_3b => translate('terms.section6_3b');
  
  // Sección 7: MODALIDADES DEL TRANSPORTE
  String get termsSection7Title => translate('terms.section7Title');
  String get termsSection7_1 => translate('terms.section7_1');
  String get termsSection7_2 => translate('terms.section7_2');
  String get termsSection7_3 => translate('terms.section7_3');
  String get termsSection7_4 => translate('terms.section7_4');
  String get termsSection7_5 => translate('terms.section7_5');
  
  // Sección 8: CANCELACIONES
  String get termsSection8Title => translate('terms.section8Title');
  String get termsSection8_1 => translate('terms.section8_1');
  String get termsSection8_1b => translate('terms.section8_1b');
  String get termsSection8_1c => translate('terms.section8_1c');
  String get termsSection8_2 => translate('terms.section8_2');
  String get termsSection8_3 => translate('terms.section8_3');
  
  // Sección 9: IDIOMA
  String get termsSection9Title => translate('terms.section9Title');
  String get termsSection9_1 => translate('terms.section9_1');
  
  // Sección 10: PRIVACIDAD
  String get termsSection10Title => translate('terms.section10Title');
  String get termsSection10_1 => translate('terms.section10_1');
  String get termsSection10_2 => translate('terms.section10_2');
  String get termsSection10_3 => translate('terms.section10_3');
  
  // Aprobación específica de cláusulas
  String get termsSpecificApprovalTitle => translate('terms.specificApprovalTitle');
  String get termsSpecificApproval => translate('terms.specificApproval');
  String get termsClause1 => translate('terms.clause1');
  String get termsClause2 => translate('terms.clause2');
  String get termsClause3 => translate('terms.clause3');
  String get termsClause4 => translate('terms.clause4');
  String get termsClause5 => translate('terms.clause5');
  String get termsClause6 => translate('terms.clause6');
  String get termsClause7 => translate('terms.clause7');
  String get termsContactEmail => translate('terms.contactEmail');
  
  String get termsQuestions => translate('terms.questions');
  String get termsContactUs => translate('terms.contactUs');

  // Privacy Policy
  String get privacyTitle => translate('privacy.title');
  String get privacyLastUpdate => translate('privacy.lastUpdate');
  String get privacyPolicyTitle => translate('privacy.policyTitle');
  String get privacyIntro => translate('privacy.intro');
  String get privacyDefinitionsTitle => translate('privacy.definitionsTitle');
  String get privacyDefWe => translate('privacy.defWe');
  String get privacyDefYou => translate('privacy.defYou');
  String get privacyDefGDPR => translate('privacy.defGDPR');
  String get privacyDefPECR => translate('privacy.defPECR');
  String get privacyDefCookies => translate('privacy.defCookies');
  String get privacyGDPRTitle => translate('privacy.gdprTitle');
  String get privacyGDPRContent => translate('privacy.gdprContent');
  String get privacyRightsTitle => translate('privacy.rightsTitle');
  String get privacyRightsIntro => translate('privacy.rightsIntro');
  String get privacyRight1 => translate('privacy.right1');
  String get privacyRight2 => translate('privacy.right2');
  String get privacyRight3 => translate('privacy.right3');
  String get privacyRight4 => translate('privacy.right4');
  String get privacyRight5 => translate('privacy.right5');
  String get privacyRight6 => translate('privacy.right6');
  String get privacyRight7 => translate('privacy.right7');
  String get privacyRight8 => translate('privacy.right8');
  String get privacyCookiesTitle => translate('privacy.cookiesTitle');
  String get privacyCookiesContent => translate('privacy.cookiesContent');
  String get privacySecurityTitle => translate('privacy.securityTitle');
  String get privacySecurityContent => translate('privacy.securityContent');
  String get privacyEmailTitle => translate('privacy.emailTitle');
  String get privacyEmailContent => translate('privacy.emailContent');
  String get privacyQuestions => translate('privacy.questions');
  String get privacyContactUs => translate('privacy.contactUs');
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

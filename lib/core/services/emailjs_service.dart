// lib/core/services/emailjs_service.dart
// EmailJS service for sending emails from web browser
// Sign up at https://www.emailjs.com/ to get your credentials

export 'emailjs_service_stub.dart'
    if (dart.library.html) 'emailjs_service_web.dart';
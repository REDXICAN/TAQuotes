// lib/core/utils/error_messages.dart

/// Centralized error messages for consistent user experience
class ErrorMessages {
  // Authentication errors
  static const String authEmailNotVerified =
      'Please verify your email before logging in. Check your inbox for a verification link.';
  static const String authInvalidCredentials =
      'Invalid email or password. Please try again.';
  static const String authUserNotFound =
      'No account found with this email. Please sign up first.';
  static const String authWeakPassword =
      'Password must be at least 6 characters long.';
  static const String authEmailAlreadyInUse =
      'An account already exists with this email.';
  static const String authNetworkError =
      'Network error. Please check your internet connection and try again.';
  static const String authGenericError =
      'Authentication failed. Please try again later.';
  static const String authSessionExpired =
      'Your session has expired. Please log in again.';

  // Database errors
  static const String dbSaveError =
      'Failed to save data. Please try again.';
  static const String dbLoadError =
      'Failed to load data. Please check your connection and try again.';
  static const String dbUpdateError =
      'Failed to update. Please try again.';
  static const String dbDeleteError =
      'Failed to delete. Please try again.';
  static const String dbPermissionError =
      'You don\'t have permission to perform this action.';
  static const String dbOfflineError =
      'This action requires an internet connection.';
  static const String dbSyncError =
      'Failed to sync data. Changes will be synced when connection is restored.';

  // Validation errors
  static const String validationEmptyField =
      'This field cannot be empty.';
  static const String validationInvalidEmail =
      'Please enter a valid email address.';
  static const String validationInvalidPhone =
      'Please enter a valid phone number.';
  static const String validationInvalidPrice =
      'Please enter a valid price.';
  static const String validationInvalidQuantity =
      'Please enter a valid quantity (minimum 1).';
  static const String validationPriceTooHigh =
      'Price exceeds maximum allowed value.';
  static const String validationQuantityTooHigh =
      'Quantity exceeds maximum allowed value.';

  // Cart errors
  static const String cartAddError =
      'Failed to add item to cart. Please try again.';
  static const String cartUpdateError =
      'Failed to update cart. Please try again.';
  static const String cartRemoveError =
      'Failed to remove item from cart. Please try again.';
  static const String cartEmptyError =
      'Your cart is empty. Add items to continue.';
  static const String cartClientRequired =
      'Please select a client before creating a quote.';
  static const String cartInsufficientStock =
      'Insufficient stock for this quantity.';

  // Quote errors
  static const String quoteCreateError =
      'Failed to create quote. Please try again.';
  static const String quoteUpdateError =
      'Failed to update quote. Please try again.';
  static const String quoteDeleteError =
      'Failed to delete quote. Please try again.';
  static const String quoteSendError =
      'Failed to send quote email. Please try again.';
  static const String quoteExportError =
      'Failed to export quote. Please try again.';
  static const String quoteNotFound =
      'Quote not found. It may have been deleted.';

  // Client errors
  static const String clientCreateError =
      'Failed to create client. Please try again.';
  static const String clientUpdateError =
      'Failed to update client. Please try again.';
  static const String clientDeleteError =
      'Failed to delete client. Please try again.';
  static const String clientNotFound =
      'Client not found. It may have been deleted.';
  static const String clientDuplicateEmail =
      'A client with this email already exists.';

  // Product errors
  static const String productNotFound =
      'Product not found. It may have been removed.';
  static const String productLoadError =
      'Failed to load products. Please try again.';
  static const String productImageError =
      'Failed to load product image.';

  // File errors
  static const String fileTooLarge =
      'File size exceeds the maximum limit (25MB).';
  static const String fileInvalidType =
      'Invalid file type. Please select a valid file.';
  static const String fileUploadError =
      'Failed to upload file. Please try again.';
  static const String fileDownloadError =
      'Failed to download file. Please try again.';

  // Email errors
  static const String emailSendError =
      'Failed to send email. Please check your internet connection and try again.';
  static const String emailInvalidRecipient =
      'Invalid recipient email address.';
  static const String emailAttachmentError =
      'Failed to attach file to email.';
  static const String emailConfigError =
      'Email service is not configured. Please contact support.';

  // Network errors
  static const String networkOffline =
      'No internet connection. Please check your connection and try again.';
  static const String networkTimeout =
      'Request timed out. Please try again.';
  static const String networkServerError =
      'Server error. Please try again later.';

  // Permission errors
  static const String permissionDenied =
      'Permission denied. You don\'t have access to this feature.';
  static const String permissionAdminOnly =
      'This feature is only available to administrators.';

  // Success messages
  static const String successSaved =
      'Changes saved successfully!';
  static const String successDeleted =
      'Deleted successfully!';
  static const String successUpdated =
      'Updated successfully!';
  static const String successEmailSent =
      'Email sent successfully!';
  static const String successQuoteCreated =
      'Quote created successfully!';
  static const String successClientAdded =
      'Client added successfully!';
  static const String successCartUpdated =
      'Cart updated successfully!';
  static const String successExported =
      'Exported successfully!';

  // Get user-friendly error message from exception
  static String getUserFriendlyError(dynamic error) {
    if (error == null) {
      return 'An unexpected error occurred.';
    }

    final errorString = error.toString().toLowerCase();

    // Authentication errors - use generic messages to prevent information leakage
    if (errorString.contains('email') && errorString.contains('verified')) {
      return authEmailNotVerified;
    }
    if (errorString.contains('user-not-found') || errorString.contains('wrong-password') || errorString.contains('invalid-credential')) {
      // Use generic message to prevent user enumeration attacks
      return authInvalidCredentials;
    }
    if (errorString.contains('email-already-in-use')) {
      return authEmailAlreadyInUse;
    }
    if (errorString.contains('weak-password')) {
      return authWeakPassword;
    }
    if (errorString.contains('session') || errorString.contains('expired')) {
      return authSessionExpired;
    }

    // Network errors
    if (errorString.contains('network') || errorString.contains('connection')) {
      return networkOffline;
    }
    if (errorString.contains('timeout')) {
      return networkTimeout;
    }
    if (errorString.contains('server')) {
      return networkServerError;
    }

    // Permission errors
    if (errorString.contains('permission') || errorString.contains('denied')) {
      return permissionDenied;
    }

    // Database errors - don't expose internal details
    if (errorString.contains('database') || errorString.contains('firestore') || errorString.contains('firebase')) {
      if (errorString.contains('permission')) {
        return dbPermissionError;
      }
      if (errorString.contains('offline')) {
        return dbOfflineError;
      }
      return dbSaveError;
    }

    // File errors
    if (errorString.contains('file')) {
      if (errorString.contains('size')) {
        return fileTooLarge;
      }
      if (errorString.contains('type')) {
        return fileInvalidType;
      }
      return fileUploadError;
    }

    // Email errors
    if (errorString.contains('email')) {
      if (errorString.contains('invalid')) {
        return emailInvalidRecipient;
      }
      if (errorString.contains('attachment')) {
        return emailAttachmentError;
      }
      return emailSendError;
    }

    // Default generic error message - don't expose internal details
    return 'An unexpected error occurred. Please try again later.';
  }

  // Extract clean error message from exception - removed to prevent information leakage
  // All error messages now use predefined generic messages for security
}
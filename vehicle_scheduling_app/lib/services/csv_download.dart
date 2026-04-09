// Conditional import: uses web implementation on web, stub elsewhere
export 'csv_download_stub.dart'
    if (dart.library.html) 'csv_download_web.dart';

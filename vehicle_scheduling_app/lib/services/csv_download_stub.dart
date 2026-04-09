// Stub implementation for non-web platforms
void downloadCsvFile(String csvContent, String filename) {
  // No-op on non-web platforms
  throw UnsupportedError('CSV download is only supported on web');
}

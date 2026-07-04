// Stub for non-web platforms — download not supported
void downloadBytes(List<int> bytes, String fileName) {
  throw UnsupportedError('File download only supported on web');
}

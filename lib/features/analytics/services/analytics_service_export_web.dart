// Web implementation — uses dart:html to trigger browser download
import 'dart:html' as html;
import 'dart:typed_data';

void downloadBytes(List<int> bytes, String fileName) {
  // 1. Convert the standard list to a binary Uint8List
  final uint8List = Uint8List.fromList(bytes);

  // 2. Determine the correct MIME type based on your requested format
  String mimeType = fileName.endsWith('.pdf') 
      ? 'application/pdf' 
      : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  // 3. Create the Blob using the binary data and MIME type
  final blob = html.Blob([uint8List], mimeType);
  final urlBlob = html.Url.createObjectUrlFromBlob(blob);
  
  // 4. Trigger the browser download
  html.AnchorElement(href: urlBlob)
    ..setAttribute('download', fileName)
    ..click();
    
  // 5. Clean up the object URL to prevent memory leaks
  html.Url.revokeObjectUrl(urlBlob);
}
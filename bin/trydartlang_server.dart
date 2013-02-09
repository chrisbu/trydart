import "dart:io";
import '../lib/shortcode.dart';
import '../lib/staticfilehandler.dart';
import '../lib/shortcodehandler.dart';

void main() {
  var server = new HttpServer();
  
  server.defaultRequestHandler = notFoundHandler;
  
  var staticFileHandler = new StaticFileHandler();
  server.addRequestHandler(
      staticFileHandler.matcher, 
      staticFileHandler.handler);
  
  var shortcodeHandler = new ShortcodeHandler();
  server.addRequestHandler(
      shortcodeHandler.matcher, 
      shortcodeHandler.handler);
  
  server.onError = (err) => print(err);
  
  server.listen("0.0.0.0", 8080);
  print("listening...");
}

void notFoundHandler(HttpRequest req, HttpResponse res) {
  print("404: ${req.method}: ${req.path}");
  res.statusCode = HttpStatus.NOT_FOUND;
  res.outputStream.writeString("""
<html><head><title>404 not found</title></head>
<body>
<pre>${req.method}: ${req.path}</pre><br/>
The page you requested was not found<br/>
</body></html>""");
  res.outputStream.close();
}





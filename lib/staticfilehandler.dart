library staticfilehandler;

import 'dart:io';
import 'dart:collection';
import 'shortcode.dart';
import 'package:logging/logging.dart';

class StaticFileHandler {
  static final Map<String,String> MIME_TYPES = {
    ".css": "text/css",
    ".html": "text/html",
    ".dart": "application/dart",
    ".js": "application/javascript",
    ".maps": "text/plain",
    ".deps": "text/plain",
    ".swf" : "application/x-shockwave-flash"
  };
  
  final pathCache = new SplayTreeMap<String,String>();
  final contentCache = new SplayTreeMap<String,String>();
  
  final Logger logger;
  
  StaticFileHandler(this.logger);
  
  /**
   * Only matches GET requests.
   * 
   * Either matches a static file by extension or matches a valid 
   * shortcode handler - ie, a shortcode that has already been created
   * and exists.
   */
  bool match(HttpRequest req) {
    var result = false;
    
    if (req.method == "GET") {
     var path = req.uri.path.toLowerCase();
     if (path.length == 0 ||
         path == "/" ||
         path.contains(".css") ||
         path.contains(".html") ||
         path.contains(".dart") ||
         path.contains(".js") ||
         path.contains(".maps") ||
         path.contains(".deps") ||
         path.contains(".png") ||
         path.contains(".swf")) {
       
       logger.fine("StaticFileHandler matched file request: GET:${path}");
       result = true; // standard file request
     }
     else if (isValidShortcode(req.uri.path)) {
       // this matches a request for a shortcode, like /AbCde1 (7 chars inc /)
       // which gets translated into a request for /index.html
       // the client (running code in the loaded index.html) then makes a
       // second request for GET: /run/AbCde1 which actually runs and
       // loads the content + results.
       logger.fine("StaticFileHandler matched valid shortcode request: GET${path}");
       
       result = true;
     }
    }
    return result; // single exit point
  }      
    
  void handle(HttpRequest req) {
    var path = req.uri.path;
    if (logger.isLoggable(Level.FINE)) {
      logger.fine("Handling request for ${path}");
      logger.fine("Is valid shortcode? ${isValidShortcode(path)}");
    }
    
    try {
      var requestedPath = _determineRequestedPath(path); 
      var filename = new Path(requestedPath).toNativePath().toLowerCase();
      logger.info("Loading file: $filename");
      
      _addContentTypesByExtension(filename,req.response);
  
      var file = new File(filename);
      logger.fine("created file");     
      var fileStream = file.readAsBytes().asStream();
      logger.fine("got file stream");
      fileStream.pipe(req.response);
      logger.fine("piped to response");
      
      //req.response.close();
      logger.fine("closed response");
//      file.readAsBytes().asStream().pipe(req.response)
//        ..catchError((error) {
//          req.response.statusCode = HttpStatus.INTERNAL_SERVER_ERROR;
//          req.response.addString(error.toString());
//          logger.severe("1. Error handling static file: GET: $path\n$error");
//          req.response.close();
//        });
//      req.response.close();
    }
    catch (ex) {
      req.response.statusCode = HttpStatus.INTERNAL_SERVER_ERROR;
      req.response.addString(ex.toString());
      logger.severe("2. Error handling static file: GET: $path\n$ex");
      req.response.close();
    }
    
  }
  
  /**
   * Adds the CONTENT_TYPE headers to the response based upon
   * the requested file's extension
   */
  void _addContentTypesByExtension(String filename, HttpResponse response) {
    MIME_TYPES.forEach((ext, type) {
      if (filename.endsWith(ext)) {
        response.headers.add(HttpHeaders.CONTENT_TYPE, type);
      }
    });
  }
  
  /**
   * Calculates the actual requested path from the input path,
   * reading the path from the cache, or adding to the cache as required 
   */
  String _determineRequestedPath(String path) {
    String result = pathCache[path];
    
    if (result == null) {
      logger.fine("Path cache miss for $path");
      
      if (path.startsWith("/ace/") ||
          path.startsWith("/web/") || 
          path.startsWith("/js/") ||
          path.startsWith("/out/") ||
          path.startsWith("/css") ||
          path.startsWith("/packages")) {
        result = path; // explicitly, because these URLs might also be valid shortcodes.
      }
      else if (path.length == 0 || path == "/" || isValidShortcode(path)) {
        result = "/index.html";
      }
      else {
        result = path;
      }
      
      // fix up path to locate the correct subfolder (/lib /web)
      if (result.startsWith("/lib")) {
        // HACK to allow for relative imports in dart files
        result = result.substring(1); 
      }
      else {
        result = "web${result}";  
      }
      
      pathCache[path] = result;
      print(pathCache);
    }
    else {
      logger.fine("Path cache hit for $path");
    }
    
    return result;
  }
}


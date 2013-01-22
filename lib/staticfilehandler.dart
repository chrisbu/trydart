library staticfilehandler;

import 'dart:io';
import 'shortcode.dart';

class StaticFileHandler {
  static Map<String,String> mimetypes = {
    ".css": "text/css",
    ".html": "text/html",
    ".dart": "application/dart",
    ".js": "application/javascript",
    ".maps": "text/plain",
    ".deps": "text/plain",
    ".swf" : "application/x-shockwave-flash"
  };
  
  bool matcher(req) {
    bool result = false;
    
    if (req.method == "GET") {
     var path = req.path.toLowerCase();
     if (path.length == 0 ||
         path == "/" ||
         path.contains(".css") ||
         path.contains(".html") ||
         path.contains(".dart") ||
         path.contains(".js") ||
         path.contains(".maps") ||
         path.contains(".deps") ||
         path.contains(".swf")) {
       
       result = true; // standard file request
     }
     else if (isValidShortcode(req.path)) {
       // this matches a request for a shortcode, like /AbCde1 (7 chars inc /)
       // which gets translated into a request for /index.html
       // the client (running code in the loaded index.html) then makes a
       // second request for GET: /run/AbCde1 which actually runs and
       // loads the content + results.
       
       result = true;
     }
    }
    return result; // single exit point
  }      
    
  void handler(req,HttpResponse res) {
    
    var requestedpath; 
    if (req.path.length == 0 || req.path == "/" || isValidShortcode(req.path)) {
      requestedpath = "/index.html";
    }
    else
    {
      requestedpath = req.path;
    }
    
    var root;
    
    if (requestedpath.startsWith("/lib")) {
      // HACK to allow for relative imports in dart files
      root = new Path("${requestedpath.substring(1)}"); 
    }
    else {
      root = new Path("web${requestedpath}");  
    }
    
    
    print("Loading: ${root.toNativePath()}");
    var filename = root.toNativePath().toLowerCase();
    var file = new File(filename);
    mimetypes.forEach((ext, type) {
      if (filename.endsWith(ext)) {
        res.headers.add(HttpHeaders.CONTENT_TYPE, type);
      }
    });

    file.openInputStream().pipe(res.outputStream);
    
  }
}


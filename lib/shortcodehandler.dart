library shortcodehandler.dart;

import 'dart:io';
import 'dart:async';
import 'shortcode.dart';
import 'dart:json';
import 'dart:crypto';
import 'package:logging/logging.dart';

class ShortcodeHandlerConfig {
  final ROOT_FOLDER;
  final FILE_URI_PREFIX;
  final DRIVE_PREFIX;
  
  ShortcodeHandlerConfig(
      this.ROOT_FOLDER,
      this.FILE_URI_PREFIX,
      this.DRIVE_PREFIX);
}

class ShortcodeHandler {
  // TODO: Write a generic properties handler!!!
  /* properties for my local machine */
//  static const ROOT_FOLDER = "/work/tmp/";
//  static const FILE_URI_PREFIX = "file:///c:$ROOT_FOLDER";
//  static const DRIVE_PREFIX = "c:";

/* Properties for deployment */
//  static const ROOT_FOLDER = "/data/darts/";
//  static const DRIVE_PREFIX = "";
//  static const FILE_URI_PREFIX = "file://$ROOT_FOLDER";
//  
  static const OBFUSCATED_FILE_URI_PREFIX = "";
  static const SHORTCODE_TAG = "%shortcode%";
  String get WORK_FOLDER => "${config.ROOT_FOLDER}%shortcode%/";
  static const RUN_URL_PATH = "/run/";
  static const LOAD_URL_PATH = "/load/";
  static const DEFAULT_FILE = "app.dart";
  
  final ShortcodeHandlerConfig config;
  final Logger logger;
  
  ShortcodeHandler(this.config, this.logger);
  
  bool match(HttpRequest req) {
    bool result = false;
    var path = req.uri.path.toLowerCase();
    var method = req.method;
    
    
    if  (method == "GET" || method == "PUT") {
      // starts with one of the valid paths, and is a valid shortcode?
      if (path.startsWith(RUN_URL_PATH)) {
        result = isValidShortcode(path.substring(RUN_URL_PATH.length-1, path.length));
      }
      else if (path.startsWith(LOAD_URL_PATH)) {
        result = isValidShortcode(path.substring(LOAD_URL_PATH.length-1, path.length));
      }
    }
    
    if (result) {
      logger.fine("ShortcodeHandler matched file request: $method:$path");
    }
    
    return result;
  }
  
  /**
   * Load (or save first...) 
   * the file, analyze it, run it, return the file and the results.
   */
  void handle(HttpRequest req) {
    var shortcode = req.uri.path.substring(5, req.uri.path.length);
    if (req.method == "PUT") {
      logger.info("SAVE shortcode: $shortcode");
      _saveContent(req,shortcode);
    }
    else if (req.uri.path.startsWith(LOAD_URL_PATH)){
      logger.info("LOAD shortcode: $shortcode");
      _loadContent(req,shortcode);
    }
    else {
      // assume simple GET and run
      logger.info("RUN shortcode: $shortcode");
      runShortcode(shortcode, req.response);
    }
  }
  
  void _loadContent(HttpRequest req, String shortcode) {
    var path = new Path("${config.DRIVE_PREFIX}${WORK_FOLDER.replaceAll(SHORTCODE_TAG,shortcode)}${DEFAULT_FILE}");
    var nativePath = path.toNativePath();
    var file = new File(nativePath);
    
    var map = new Map();
    map["file"] = "// The Shortcode you requested does not exist";
    map["result"] = "Press RUN to execute your code...";
    map["shortcode"] = shortcode.replaceAll("/", "");
    req.response.headers.add(HttpHeaders.CONTENT_TYPE, "application/json");
    
    file.exists().then((exists) {
      if (exists) {
        file.readAsString().then((String content) {
          map["file"] = content;
          map["result"] = "Press RUN to execute your code...";
          map["shortcode"] = shortcode.replaceAll("/", "");
          req.response.write(stringify(map));
          req.response.close();
        }).catchError((error) {
          req.response.write(stringify(map));
          logger.severe("4. Error handling content file: GET: $path\n$error");
          req.response.close();
        });
      }
      else {
        req.response.write(stringify(map));
        req.response.close();
      }
    }).catchError((error) {
      req.response.write(stringify(map));
      logger.severe("5. Error handling content file: GET: $path\n$error");
      req.response.close();
    });
  }
  
  void _saveContent(HttpRequest req, String shortcode) {
    req.transform(new StringDecoder()).listen((String content) {
      content = content.replaceAll("new File", "// new File <--Disabled-->");
      content = content.replaceAll("extends File", "// extends File  <--Disabled-->");
      content = content.replaceAll("new HttpServer", "// new HttpServer  <--Disabled-->");
      content = content.replaceAll("extends HttpServer", "// extends HttpServer  <--Disabled-->");
      content = content.replaceAll("new Directory", "// new Directory  <--Disabled-->");
      content = content.replaceAll("extends Directory", "// extends Directory  <--Disabled-->");
      content = content.replaceAll("new Socket", "// new Socket <--Disabled-->");
      content = content.replaceAll("extends Socket", "// extends Socket <--Disabled-->");
      content = content.replaceAll("Process.start", "// Process.start <--Disabled-->");
      content = content.replaceAll("Process.run", "// Process.run <--Disabled-->");
      content = content.replaceAll("extends Process", "// extends Socket <--Disabled-->");
      content = content.replaceAll("dart:io", "// dart:io <--Disabled-->");
      shortcode = generateShortcode(content); // TODO: Error handling (may already exist).
      
      var dir = new Directory(WORK_FOLDER.replaceAll(SHORTCODE_TAG,shortcode));
      dir.create().then((directory) { // doc says... if the directory already exists then nothing is done.
        var path = new Path("${dir.path}$DEFAULT_FILE");
        var nativePath = path.toNativePath();
        var file = new File(path.toNativePath());
        
        var fileSink = file.openWrite();
        fileSink.write(content);
        fileSink.close();
        fileSink.done.then((file) {
          runShortcode(shortcode, req.response);
        },
        onError: (error) => logger.severe("Error saving file: $nativePath\n$error"));              
      });
      
    },
    onError: (error) => logger.severe("Error: $error"));
  }
  
  void runShortcode(String shortcode, HttpResponse res) {
    var path = new Path("${config.DRIVE_PREFIX}${WORK_FOLDER.replaceAll(SHORTCODE_TAG,shortcode)}${DEFAULT_FILE}");
    var file = new File(path.toNativePath());
    
    final String dartvm = new Options().executable;
    
    var vm_running = (Process p) {
      StringBuffer output = new StringBuffer();
      
      Stream stdoutStream = p.stdout;
      Stream stderrStream = p.stderr;
      
      stdoutStream
          .transform(new StringDecoder())
          .listen((String data) => output.write(data), 
          onError: (error) => logger.severe("error writing stdout to the output: $error"));
      
      stderrStream
          .transform(new StringDecoder())
          .listen((String data) {
            data = data.replaceAll("${config.FILE_URI_PREFIX}${config.ROOT_FOLDER}${shortcode}/", OBFUSCATED_FILE_URI_PREFIX);
            data = data.replaceAll("${DEFAULT_FILE}':", "${DEFAULT_FILE}':\n");
            output.write(data);
          }, 
          onError: (error) {
            logger.severe("error writing stderr to the output: $error");  
          });
      
      
      p.exitCode.then((e) {
        var map = new Map();
        
        var sb = new StringBuffer();
        
        file.openRead()
            .transform(new StringDecoder())
            .listen((String content) {
              sb.write(content);
            }, 
            onDone: () {
              map["file"] = sb.toString();
              map["result"] = output.toString();
              map["shortcode"] = shortcode;
              
              res.headers.add(HttpHeaders.CONTENT_TYPE, "application/json");
              res.write(stringify(map));
              res.close();
            },
            onError: (error) {
              logger.severe("error adding header running shortcode: $error");
              try {
                res.close();
              }
              catch (ex) {
                logger.severe("error closing response: $ex");
              }
            });
      }).catchError((error) {
        logger.severe("error catching exit code: $error");
      });
      
      var t = new Timer(new Duration(seconds:5), () {
        output.write("Note: Script took longer than 5 seconds... Killed.");
        p.kill(ProcessSignal.SIGKILL); 
      });
    };
  
    var vm_error = (ex) {
      logger.severe('Failed to start VM: ${ex.message}\n');
      res.statusCode = HttpStatus.INTERNAL_SERVER_ERROR;
      res.write(ex.toString());
      res.close();
      return true;
    };

    Process.start(dartvm, ["${path.toNativePath()}"])
      .then((p) => vm_running(p), onError: vm_error)
      .catchError(vm_error);
  }
  
  
}


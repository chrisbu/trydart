library shortcodehandler.dart;

import 'dart:io';
import 'dart:async';
import 'shortcode.dart';
import 'dart:json';
import 'dart:crypto';

class ShortcodeHandler {
  // TODO: Write a generic properties handler!!!
  /* properties for my local machine */
  static const ROOT_FOLDER = "/work/tmp/";
  static const FILE_URI_PREFIX = "file:///c:$ROOT_FOLDER";
  static const DRIVE_PREFIX = "c:";

/* Properties for deployment */
//  static const ROOT_FOLDER = "/data/darts/";
//  static const DRIVE_PREFIX = "";
//  static const FILE_URI_PREFIX = "file://$ROOT_FOLDER";
  
  static const OBFUSCATED_FILE_URI_PREFIX = "";
  static const SHORTCODE_TAG = "%shortcode%";
  static const WORK_FOLDER = "${ROOT_FOLDER}%shortcode%/";
  static const RUN_URL_PATH = "/run/";
  static const LOAD_URL_PATH = "/load/";
  static const DEFAULT_FILE = "app.dart";
  
  bool matcher(req) {
    bool result = false;
    var reqpath = req.path.toLowerCase();
    if  (req.method == "GET" || req.method == "PUT") {
      // starts with one of the valid paths, and is a valid shortcode?
      if (reqpath.startsWith(RUN_URL_PATH)) {
        result = isValidShortcode(req.path.substring(RUN_URL_PATH.length-1, req.path.length));
      }
      else if (reqpath.startsWith(LOAD_URL_PATH)) {
        result = isValidShortcode(req.path.substring(LOAD_URL_PATH.length-1, req.path.length));
      }
    }
    
    return result;
  }
  
  /**
   * Load (or save first...) 
   * the file, analyze it, run it, return the file and the results.
   */
  void handler(HttpRequest req,res) {
    var shortcode = req.path.substring(5, req.path.length);
    if (req.method == "PUT") {
      
      req.inputStream.onData = () {
        var data = req.inputStream.read();
        var content = new String.fromCharCodes(data);
        content = content.replaceAll("new File", "new File<--Disabled-->");
        content = content.replaceAll("extends File", "extends File<--Disabled-->");
        content = content.replaceAll("new HttpServer", "new HttpServer<--Disabled-->");
        content = content.replaceAll("extends HttpServer", "extends HttpServer<--Disabled-->");
        content = content.replaceAll("new Directory", "new Directory<--Disabled-->");
        content = content.replaceAll("extends Directory", "extends Directory<--Disabled-->");
        content = content.replaceAll("new Socket", "new Socket<--Disabled-->");
        content = content.replaceAll("extends Socket", "extends Socket<--Disabled-->");
        content = content.replaceAll("Process.start", "Process.start<--Disabled-->");
        content = content.replaceAll("Process.run", "Process.run<--Disabled-->");
        content = content.replaceAll("extends Process", "extends Socket<--Disabled-->");
        
        shortcode = generateShortcode(content); // TODO: Error handling (may already exist).
        
        var dir = new Directory(WORK_FOLDER.replaceAll(SHORTCODE_TAG,shortcode));
        dir.create().then((directory) { // doc says... if the directory already exists then nothing is done.
          var path = new Path("${dir.path}$DEFAULT_FILE");
          var file = new File(path.toNativePath());
          
          var fileStream = file.openOutputStream(FileMode.WRITE);
          // when finished writing the file, run the shortcode.
          fileStream.onNoPendingWrites = () => runShortcode(shortcode, res);
          fileStream.onError = (e) => print(e); // TODO: Tighten this up a bit.
          

          
          
          // write the content, flush and close.
          fileStream.writeString(content);
          fileStream.flush(); // probably not needed.
          fileStream.close(); 
        });
      };
            
    }
    else if (req.path.startsWith(LOAD_URL_PATH)){
      var path = new Path("$DRIVE_PREFIX${WORK_FOLDER.replaceAll(SHORTCODE_TAG,shortcode)}${DEFAULT_FILE}");
      var file = new File(path.toNativePath());
      
      var map = new Map();
      file.readAsString().then((String content) {
        map["file"] = content;
        map["result"] = "Press RUN to execute your code...";
        map["shortcode"] = shortcode.replaceAll("/", "");
        
        res.headers.add(HttpHeaders.CONTENT_TYPE, "application/json");
        res.outputStream.writeString(stringify(map));
        res.outputStream.close();
      });
      
    }
    else {
      // assume simple GET and run 
      runShortcode(shortcode, res);
    }
  }
  
  void runShortcode(String shortcode, HttpResponse res) {
    var path = new Path("$DRIVE_PREFIX${WORK_FOLDER.replaceAll(SHORTCODE_TAG,shortcode)}${DEFAULT_FILE}");
    var file = new File(path.toNativePath());
    
    final String dartvm = new Options().executable;
    
    var vm_running = (Process p) {
      StringBuffer output = new StringBuffer();
      
      var stdoutStream = p.stdout;
      var stderrStream = p.stderr;
      
      
      stdoutStream.onData = () {
        var s = new String.fromCharCodes(stdoutStream.read());
        output.add("${s}");
      };
      
      stderrStream.onData = () {
        var s = new String.fromCharCodes(stderrStream.read());
        s = s.replaceAll("${FILE_URI_PREFIX}${shortcode}/", OBFUSCATED_FILE_URI_PREFIX);
        s = s.replaceAll("${DEFAULT_FILE}':", "${DEFAULT_FILE}':\n");
        output.add("${s}");
      };
      
      p.onExit = (e) {
        var map = new Map();
        
        file.readAsString().then((String content) {
          map["file"] = content;
          map["result"] = output.toString();
          map["shortcode"] = shortcode;
          
          res.headers.add(HttpHeaders.CONTENT_TYPE, "application/json");
          res.outputStream.writeString(stringify(map));
          res.outputStream.close();  
        });
        
      };
      
      var t = new Timer(5000, (tmr) {
        output.add("Note: Script took longer than 5 seconds... Killed.");
        p.kill(ProcessSignal.SIGKILL); 
      });
    };

    Process.start(dartvm, ["${path.toNativePath()}"])
      ..then((p) => vm_running(p))
      ..catchError(vm_error);
   
  }
  
  bool vm_error(e) {
    stderr.writeString('Failed to start VM: ${e.message}\n');
    return true;
  }
}


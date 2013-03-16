import "dart:io";
import '../lib/shortcode.dart';
import '../lib/staticfilehandler.dart';
import '../lib/shortcodehandler.dart';
import 'package:dart_config/default_server.dart';
import 'package:logging/logging.dart';

Logger logger = new Logger("try");

void main() {
  hierarchicalLoggingEnabled = true;
  addLoggingHandler(logger, loggerStdOutHandler);
  
  loadConfig().then((config) {
    setupLogging(logger, config["loglevel"]);
    
    logger.info("Starting web server");
    startWebServer(config);
  },
  onError: (error) => print("Error loading config: ${error}"));
}

/**
 * Start the web server listening
 */
void startWebServer(Map config) {
  var host = config["host"];
  var port = config["port"];

  var sfConfig = new ShortcodeHandlerConfig(
      config["rootFolder"],
      config["drivePrefix"],
      config["fileUriPrefix"]);
  
  var handlers = [new StaticFileHandler(logger),
                  new ShortcodeHandler(sfConfig, logger)];
  
  HttpServer.bind(host, port).then((server) {
    logger.info("Listening on $host:$port");
    server.listen((request) {
      print("request");
      handleRequests(request, handlers, notFound);
    },
    onError: (error) => logger.warning("server.listen: ${error}"));         
  }, 
  onError: (error) {
    logger.severe("bind: $host:$port\n${error}");
  });
}

/**
 * Iterates the handlers to see which one can handle the request.
 * If no request matches, then use the notFoundHandler
 */
void handleRequests(HttpRequest request, handlers, notFoundHandler) {
  logRequest(request);
  
  try {
    bool handlerFound = false;
    
    for (var handler in handlers) { // todo, cache handler lookup by request     
      if (handler.match(request)) {
        logger.fine("Hanfler match: ${handler}");
        handlerFound = true;
        handler.handle(request);
        break;
      }
    }
    
    if (!handlerFound) {
      notFoundHandler(request);
    }    
  }
  catch (ex) {
    logger.severe("handleRequests: ${ex}");
  }
}
  
/**
 * Default handler for handling 404
 */
void notFound(HttpRequest req) {
  HttpResponse res = req.response;
  var method = req.method;
  var path = req.uri.path;
  
  logger.info("404: $method: $path");
  
  res.statusCode = HttpStatus.NOT_FOUND;
  res.addString("""
<html><head><title>404 not found</title></head>
<body>
<pre>$method: $path</pre><br/>
The page you requested was not found<br/>
</body></html>""");
  res.close();
}

/**
 * log to stdout with print
 */
void loggerStdOutHandler(LogRecord logRecord) {  
  if (logRecord.exception != null) {
    print("${logRecord.time}\t${logRecord.level}: ${logRecord.message}\n${logRecord.exceptionText}");
  }
  else {
    print("${logRecord.time}\t${logRecord.level}: ${logRecord.message}");  
  }
}

/**
 * Converts the string logLevel into a [Level]
 */
void setupLogging(Logger logger, String logLevel) {
  switch (logLevel.toUpperCase()) {
    case "FINE": logger.level = Level.FINE; break;
    case "CONFIG": logger.level = Level.CONFIG; break;
    case "INFO": logger.level = Level.INFO; break;
    case "WARNING": logger.level = Level.WARNING; break;
    case "SEVERE": logger.level = Level.SEVERE; break;
    case "OFF": logger.level = Level.OFF; break;
    default: logger.level = Level.ALL;
  }
}

/**
 * Add the log handler function to the logger, handles the onError
 */
void addLoggingHandler(Logger logger, LoggerHandler loggerFunction) {
  logger.onRecord.listen(loggerFunction, 
      onError: (error) => print("Fatal: Error in logger.onRecord: ${error}"));
}

/**
 * Log an [HttpRequest] outputting the [method] and [path]
 */
void logRequest(HttpRequest request) {
  try {
    var method = request.method;
    var path = request.uri.path;
    
    logger.info("$method: $path");
  }
  catch (ex) {
    logger.severe("logRequest: ${ex}");
  }
}
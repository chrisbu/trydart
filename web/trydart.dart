import 'dart:html';
import 'dart:json';
import 'package:js/js.dart' as js;
import 'package:query_string/query_string.dart';

import '../lib/shortcode.dart';

final defaultCode = r"""final messages = ["Great","Cool","Awesome"];

void main() {
  messages.forEach((msg) => print("Dart is $msg"));
}""";

void main() {
  query("#run").onClick.listen(onRunButtonClick);
  query("#editor").onKeyPress.listen((e) => query("#shortcode").children.clear());
  //createTextAreaWithLines("editor");
  init();
  window.onPopState.listen((PopStateEvent e) {
    //print("state: ${e.state}");
    if (e.state != null) {
      window.location.replace("${e.state}");
    }
  });
}

var shortcode = "";

init() {
  print("init");
  // get the file part of the path
  print(window.location.search);
  
  if (window.location.search != null && window.location.search.length > 0) {
    var queryParams = QueryString.parse(window.location.search);
    shortcode = queryParams["sc"];
  }
  
  if (shortcode == null || shortcode.length == 0) {
    shortcode = pathToShortcode(window.location.pathname);
  }
  
  
  print("shortcode: $shortcode");
  if (isValidShortcode(shortcode) && !isDefaultShortcode(shortcode)) {
    print("loading shortcode");
    HttpRequest.getString("/load/$shortcode").then(shortcodeDataLoaded);
  } 
  else {
    js.scoped(() {
      var editor = js.context.editor;
      editor.setValue(defaultCode);
      editor.clearSelection();
    });
  }
}

updateShortcode(_shortcode) {
  shortcode = _shortcode;
  
  var url = "http://${window.location.hostname}:${window.location.port}";
  var embedUrl = url;
  bool isEmbed = false;
  embedUrl = "$url/embed.html?sc=$shortcode";
  
  if (window.location.pathname.toLowerCase().contains("embed.html")) {
    
    isEmbed = true;
  }
  
  if (!url.contains(shortcode)) {
    if (!url.endsWith("/"))  url = "$url/$shortcode";
    else url = "$url$shortcode";
  }
  
  var plus1 = r"""<!-- Place this tag where you want the +1 button to render. -->
<div class="g-plusone" data-annotation="inline" data-width="300"></div>""";
  
  query("#shortcode").children.clear();
  var span = new Element.tag("span");
  if (!isEmbed) {
    span.children.add(new Element.html("<span><a href='$url'>Share Shortcode</a></span>"));
    var clippy1 = getClippy(url,"#FFFFFF");
    span.children.add(clippy1);
    span.children.add(new Element.html("<br>"));
    span.children.add(new Element.html("<span><a href='$embedUrl'>Embed </a></span>"));
    var clippy2 = getClippy(embedUrl,"#FFFFFF");
    span.children.add(clippy2);
  }
  else {
    span.children.add(new Element.html("<span>View this code at <a href='$url' target='_blank'>trydart.dartwatch.com</a></span>"));    
  }
  query("#shortcode").children.add(span);
  
  // only update the url of the window if it's not embeded.
  if (!isEmbed) {
    window.history.pushState(url, url, url);
  }
}

void shortcodeDataLoaded(String responseText) {
  ButtonElement runButton = query("#run");
  runButton.disabled = false;
  runButton.text = "Run";

  var map = parse(responseText);
  js.scoped(() {
    var editor = js.context.editor;
    editor.setValue(map["file"]);
    editor.clearSelection();
  });
  
  query("#results").innerHtml = map["result"];
  updateShortcode(map["shortcode"]);
}

void onRunButtonClick(e) {
  ButtonElement runButton = query("#run");
  runButton.disabled = true;
  runButton.text = "running...";
  var req = new HttpRequest();
  print(shortcode);
  req.open("PUT", "/run/$shortcode", true, null, null);
  req.onProgress.listen((e) => shortcodeDataLoaded(req.responseText));

  // get the text from the editor
  js.scoped(() {
    var editor = js.context.editor;
    req.send(editor.getValue());
  });
  
}



Element getClippy(text, bgcolor) {
  var clippy = new Element.html("""
 <object classid="clsid:d27cdb6e-ae6d-11cf-96b8-444553540000"
            width="110"
            height="14"
            id="clippy" >
    <param name="movie" value="/clippy.swf"/>
    <param name="allowScriptAccess" value="always" />
    <param name="quality" value="high" />
    <param name="scale" value="noscale" />
    <param NAME="FlashVars" value="text=${text}">
    <param name="bgcolor" value="${bgcolor}">
    <embed src="/clippy.swf"
           width="110"
           height="14"
           name="clippy"
           quality="high"
           allowScriptAccess="always"
           type="application/x-shockwave-flash"
           pluginspage="http://www.macromedia.com/go/getflashplayer"
           FlashVars="text=${text}"
           bgcolor="${bgcolor}"
    />
    </object>
""");
  
  return clippy;
}
import 'dart:html';
import 'dart:json';
import 'package:js/js.dart' as js;

import '../lib/shortcode.dart';
import '../lib/codearea.dart';

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
  shortcode = pathToShortcode(window.location.pathname);
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
  print(url);
  if (!url.contains(shortcode)) {
    if (!url.endsWith("/"))  url = "$url/$shortcode";
    else url = "$url$shortcode";
  }
  
  var plus1 = r"""<!-- Place this tag where you want the +1 button to render. -->
<div class="g-plusone" data-annotation="inline" data-width="300"></div>""";
  
  query("#shortcode").children.clear();
  var span = new Element.html("<span><h4>4. Share your code with others</h4><a href='$url'>$url</a>&nbsp;</span>");
  
  query("#shortcode").children.add(span);
  
  var clippy = getClippy(url,"#FFFFFF");
  query("#shortcode").children.add(clippy);
  
  window.history.pushState(url, url, url);
}

void shortcodeDataLoaded(String responseText) {
  ButtonElement runButton = query("#run");
  runButton.disabled = false;
  runButton.text = "Go Dart!";

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
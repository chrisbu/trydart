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
  query("#run").on.click.add(onRunButtonClick);
  query("#editor").on.keyPress.add((e) => query("#shortcode").children.clear());
  //createTextAreaWithLines("editor");
  init();
  window.on.popState.add((PopStateEvent e) {
    print("state: ${e.state}");
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
  
  if (isValidShortcode(shortcode) && !isDefaultShortcode(shortcode)) {
    new HttpRequest.get("/load/$shortcode", loadShortcodeData);
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
  var span = new Element.html("<span><h4>4. Share your code with others</h4><a href='$url'>$url</a></span>");
  
  query("#shortcode").children.add(span);
  var clippy = getClippy(url,"#C8C8C8");
  query("#shortcode").children.add(clippy);
  
  window.history.pushState(url, url, url);
}

void loadShortcodeData(HttpRequest req) {
  query("#run").disabled = false;
  var map = parse(req.responseText);
  query("#run").text = "Run";
  
  js.scoped(() {
    var editor = js.context.editor;
    editor.setValue(map["file"]);
    editor.clearSelection();
  });
  
  query("#results").innerHtml = map["result"];
  updateShortcode(map["shortcode"]);
}

void onRunButtonClick(e) {
  query("#run").disabled = true;
  query("#run").text = "running...";
  var req = new HttpRequest();
  req.open("PUT", "/run/$shortcode", true, null, null);
  req.on.progress.add((e) => loadShortcodeData(req));
  
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
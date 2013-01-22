import 'dart:html';
import 'dart:json';

import '../lib/shortcode.dart';
import '../lib/codearea.dart';

void main() {
  query("#run").on.click.add(onRunButtonClick);
  query("#editor").on.keyPress.add((e) => query("#shortcode").children.clear());
  createTextAreaWithLines("editor");
  init();
  
}

var shortcode = "";

init() {
  print("init");
  // get the file part of the path
  shortcode = pathToShortcode(window.location.pathname);
  
  if (isValidShortcode(shortcode) && !isDefaultShortcode(shortcode)) {
    new HttpRequest.get("/load/$shortcode", loadShortcodeData);
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
  
  query("#shortcode").children.clear();
  var span = new Element.html("<span>4. Share your code with others<br><a href='$url'>$url</a><br></span>");
  query("#shortcode").children.add(span);
  var clippy = getClippy(url,"#C8C8C8");
  query("#shortcode").children.add(clippy);
}

void loadShortcodeData(HttpRequest req) {
  query("#run").disabled = false;
  var map = parse(req.responseText);
  query("#run").text = "Run";
  
  query("#editor").innerHtml = map["file"];
  query("#results").innerHtml = map["result"];
  updateShortcode(map["shortcode"]);
}

void onRunButtonClick(e) {
  query("#run").disabled = true;
  query("#run").text = "running...";
  var req = new HttpRequest();
  req.open("PUT", "/run/$shortcode", true, null, null);
  req.on.progress.add((e) => loadShortcodeData(req));
  req.send(query("#editor").value);
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
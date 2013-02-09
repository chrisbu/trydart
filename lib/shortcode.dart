library shortcode;

import 'dart:crypto';

final _shortcodeRegex = new RegExp("[a-zA-Z0-9]");

const DEFAULT_SHORTCODE = "xxxxxxxxxxxxxxxxxxxx"; // 20 chars long
const String _SC_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
const int _SC_LENGTH = 20;


/** Return a valid shortcode.
 *  No effort is made to validate uniqueness - this is the responsibility
 *  of the calling app.
 */ 
String generateShortcode(String content) {
  final sha1 = new SHA1();
  sha1.add(content.charCodes);
  List digest = sha1.close();
  
  final sb = new StringBuffer();
  digest.forEach( (i) {
    var charpos = i % _SC_CHARS.length; // mod
    sb.add(_SC_CHARS.substring(charpos, charpos+1)); // select the relevant char
  });
  
  final shortcode = sb.toString();
  return shortcode;
}



/** returns true if the entered [shortcode] such as
 * /AbCdE1 
 * begins with a /, and is the correct length of characters,
 * and contains a-zA-Z0-9 only 
 */ 
bool isValidShortcode(String shortcode) {
  bool result = false;
  
  if (shortcode.length == _SC_LENGTH + 1 && shortcode.startsWith("/")) {
    result = shortcode.contains(_shortcodeRegex,1); // ignore the leading /
  }
  else if (shortcode.length == _SC_LENGTH) {
    result = shortcode.contains(_shortcodeRegex);
  }
  
  return result; // single function exit point
}


/** Convert the supplied [pathname] to a
 *  shortcode.  [pathname] will usually be [window.location.pathname] 
 */
String pathToShortcode(String pathname) {
  // eg: http://foo.com:8080/bar.html <- not a shortcode
  // or  http://foo.com:8080/AbCdE1 <- valid shortcode
  var path = pathname.substring(
                pathname.lastIndexOf("/") + 1,
                pathname.length);
  
  // if it's not a valid shortcode (eg, "index.html" or "/")
  if (!isValidShortcode(path)) {
    path = DEFAULT_SHORTCODE;
  }
  
  return path;  
}

bool isDefaultShortcode(String shortcode) {
  if (shortcode.length > _SC_LENGTH) {
    shortcode = pathToShortcode(shortcode);
  }
  return shortcode == DEFAULT_SHORTCODE;
}
library codearea;

import 'dart:html';

final _lineObjOffsetTop = 5;

void createTextAreaWithLines(id)
{
  // ported from a sample here: http://www.dhtmlgoodies.com/forum/viewtopic.php?t=506
  
  var el = new Element.tag("div"); 
  
  var ta = query("#$id");
  ta.parentNode.insertBefore(el,ta);
  el.children.addLast(ta);
  el.classes.add('textAreaWithLines');
  el.style.width = "${(ta.offsetWidth + 30)}px";
  ta.style.position = 'absolute';
  ta.style.left = '30px';
  el.style.height = "${(ta.offsetHeight + 2)}px";
  el.style.overflow='hidden';
  el.style.position = 'relative';
  el.style.width = "${(ta.offsetWidth + 30)}px";
  
  var lineObj = new Element.tag("div"); 
  lineObj.style.position = 'absolute';
  lineObj.style.top = "${_lineObjOffsetTop}px";
  lineObj.style.left = '0px';
  lineObj.style.width = '27px';
  el.insertBefore(lineObj,ta);
  lineObj.style.textAlign = 'right';
  lineObj.classes.add('lineObj');
  var string = "";
  for(var no=1;no<2000;no++){
    if(string.length>0)string = "${string}<br>";
    string = "${string}${no}";
  }
  
  ta.on.keyDown.add((e) => positionLineObj(lineObj,ta));
  ta.on.mouseDown.add((e) => positionLineObj(lineObj,ta));
  ta.on.scroll.add((e) => positionLineObj(lineObj,ta));
  ta.on.blur.add((e) => positionLineObj(lineObj,ta));
  ta.on.focus.add((e) => positionLineObj(lineObj,ta));
  ta.on.mouseOver.add((e) => positionLineObj(lineObj,ta));
  
  lineObj.innerHtml = string;  
}

void positionLineObj(obj,ta)
{
  obj.style.top = "${(ta.scrollTop * -1 + _lineObjOffsetTop)}px";     
}


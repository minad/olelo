function CodeHighlightOn(elem, id) {
  var target = document.getElementById(id);
  if (null != target) {
    elem.cacheClassElem = elem.className;
    elem.cacheClassTarget = target.className;
    target.className = "code-highlighted";
    elem.className   = "code-highlighted";
  }
}

function CodeHighlightOff(elem, id) {
  var target = document.getElementById(id);
  if (elem.cacheClassElem)
    elem.className = elem.cacheClassElem;
  if (elem.cacheClassTarget)
    target.className = elem.cacheClassTarget;
}

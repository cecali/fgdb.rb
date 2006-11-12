// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults

function playwith_fees(o) {
  var params = Form.serialize(o.form);
  new Ajax.Request('/donations/update_fee?' + params,
    {asynchronous:true, evalScripts:true});
}

function playwith_amounts(o) {
  var params = Form.serialize(o.form);
  new Ajax.Request('/sale_txns/update_sale_txn_amounts?' + params,
    {asynchronous:true, evalScripts:true});
}

// Called as:
// confirmReplaceElementValue(elem_id, new_elem_value, confirm_message)
function confirmReplaceElementValue(id, val, msg){
  var truth_value = confirm(msg)
  if (truth_value){
    // alert("updating element:" + id + " with value:" + val)
    $(id).value = val
  }
  return truth_value
}

// Called as:
// calculateOffsetLeft(_inputField)
// was ob
function calculateOffsetLeft(r){
  return Ya(r,"offsetLeft")
}

// Called as:
// calculateOffsetTop(_inputField)
// Was Qb...
function calculateOffsetTop(r){
  return Ya(r,"offsetTop")
}

function Ya(r,attr){
  var kb=0;
  while(r){
    kb+=r[attr]; 
    r=r.offsetParent
  }
  return kb
}

function setRelativelyAbsolute(elem_id, relative_to_id) {
  rel = $(relative_to_id);
  elem = $(elem_id);
  elem.style.left=calculateOffsetLeft(rel)+"px";
  elem.style.top=calculateOffsetTop(rel)+rel.offsetHeight-1+"px";
}

function alertEvent( element, value,  event) {
  // alert('event element: ' + Event.element(event));
  // alert('event id: ' + Event.element(event).id);
}

var ActivityResponder = {  
    onCreate: function(request) {  
        $('global-indicator-small').show();  
    },  
    onComplete: function(request) {  
        $('global-indicator-small').hide();  
    }  
}

Ajax.Responders.register(ActivityResponder);

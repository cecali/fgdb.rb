// redesign

new_line_item_all_instances = [];
function add_all_line_items() {
  for (var i = 0; i < new_line_item_all_instances.length; i++) {
    new_line_item_all_instances[i].on_add_all();
  };
}

// the backends are mixins, then there's a common middle class which
// includes the default backend, and each frontend subclasses the common
// middle class and can include a mixin if it wants to

// mixins for functions common between frontends can be created and
// included the same way.

var OneATimeLineItemBackend = {

};

// *backend*
// var AllAtOnceLineItemBackend = {
//
// };

// includes the default backend, it will be overriden if one is
// passed. but this makes it optional to pass since most use the default.

var LineItem = Class.create(OneATimeLineItemBackend, {
  /*
  edit_hook: function(id) {

  },
*/
  edit_hook: false,
  copyable: false,
  linelist: null,
  add_on_save: false,

  on_add_all: function() {
    if(this.add_on_save) {
      this.add_from_form_hook();
    }
  },

  update_hook: function() {
    return;
  },

  add: function (args) {
    args = this.add_hook(args);
    this.add_line_item(args);
  },

  edit: function (line_id) {
    this.edit_hook(line_id);
    this.editing_id = this.getValueBySelector($(line_id), ".id"); // TODO: need to display the editing to user somehow, and allow them to clear it. (with an x next to the editing boxes)
    Element.remove(line_id);
    this.update_hook();
  },

  copy: function (line_id) {
    this.edit_hook(line_id);
    this.update_hook();
  },

  make_hidden: function (name, display_value, value){
    var line_id = this.counter;
    var prefix = this.prefix;
    hidden = document.createElement("input");
    hidden.name = prefix + '[-' + line_id + '][' + name + ']';
    hidden.value = value;
    hidden.type = 'hidden';
    td = document.createElement("td");
    td.className = name;
    td.appendChild(hidden);
    td.appendChild(document.createTextNode(display_value));
    return td;
  },

  initialize: function() {
    new_line_item_all_instances.push(this);
    this.counter = 0;
    this.editing_id = undefined;
  },

  remove: function(line_id){
    Element.remove(line_id);
    this.update_hook();
  },

  add_line_item: function (args){
    var id = this.prefix + '_' + this.counter + '_line';
    tr = document.createElement("tr");
    tr.className = "line";
    tr.id = id;
    this.make_hidden_hook(args, tr);
    td = document.createElement("td");
    a = document.createElement("a");
    var self = this;
    a.onclick = function () {
      self.edit(id);
    };
    if(this.edit_hook) {
      a.appendChild(document.createTextNode('e'));
      a.className = 'disable_link';
      td.appendChild(a);
    }
    a = document.createElement("a");
    a.onclick = function () {
      self.copy(id);
    };
    if(this.copyable) {
      td.appendChild(document.createTextNode(' '));
      a.appendChild(document.createTextNode('c'));
      a.className = 'disable_link';
      td.appendChild(a);
    }
    td.appendChild(document.createTextNode(' '));
    a = document.createElement("a");
    a.onclick = function () {
      self.remove(id);
    };
    a.appendChild(document.createTextNode('x'));
    a.className = 'disable_link';
    td.appendChild(a);
    if(!args['uneditable']) {
      tr.appendChild(td);
    }
    if(!defined(args['id'])) {
      args['id'] = this.editing_id;
    }
    tr.appendChild(this.make_hidden("id", "", args['id']));
    $(this.prefix + '_lines').lastChild.insertBefore(tr, $(this.prefix + '_form'));
    this.counter++;
    this.update_hook();
    this.editing_id = undefined;
  },

  add_hook: function(args) {
    return args;
  },

  add_many: function(many) {
    var self = this;
    many.each(function(x) {
      self.add(x);
    });
    return;
  },

  handle_event: function(event) {
    if(this.is_tab(event)) {
      if(event.target.onchange) {
        event.target.onchange();
      }
      if(this.is_last(event)) {
        return this.add_from_form_hook();
      }
    }
  },

  is_tab: function(event) {
    return (event.keyCode==9 && !event.shiftKey);
  },

  is_last: function(event) {
    var names = this.linelist;

    var last = null;
    for(var i in names) {
      if(this.is_enabled_visable_there_field_thing(names[i])) {
        last = names[i];
      }
    }

    return last == event.target.id;
  },

  getValueBySelector: function (thing, selector) {
    return thing.getElementsBySelector(selector).first().firstChild.value;
  },

  is_enabled_visable_there_field_thing: function(name) {
    var el = $(name);
    if(!el) {
      return false;
    }
    if(el == null) {
      return false;
    }
    if(el.disabled) {
      return false;
    }
    if(!el.visible) {
      return false;
    }
    return true;
  },
});

// *backend*
// var LineItemFrontendExample = Class.create(LineItem, AllAtOnceLineItemBackend, {
//
// });
//
// ALWAYS: classes, then mixins, then hash of methods


function eexists(eid) {
  return ($(eid) != null);
}

var ContactMethodFrontend = Class.create(LineItem, {
  prefix: 'contact_methods',
  linelist: ['contact_method_value'],
  add_on_save: true,

  edit_hook: function(id) {
    thing = $(id);
    $('is_usable').checked = eval(getValueBySelector(thing, ".ok"));
    $('contact_method_type_id').value = getValueBySelector(thing, ".contact_method_type_id");
    $('contact_method_value').value = getValueBySelector(thing, ".description");
    $('contact_method_type_id').focus();
  },

  add_from_form_hook: function() {
    if($('contact_method_value').value == '' || $('contact_method_type_id').selectedIndex == 0) {
      return true;
    }

    args = new Object();
    args['contact_method_type_id'] = $('contact_method_type_id').value;
    args['contact_method_usable'] = $('is_usable').checked;
    args['contact_method_value'] = $('contact_method_value').value;

    this.add(args);
    $('contact_method_type_id').selectedIndex = 0; //should be default, but it's yucky
    $('contact_method_value').value = $('contact_method_value').defaultValue;
    $('is_usable').checked = false;
    $('contact_method_type_id').focus();
    return false;
  },

  make_hidden_hook: function (args, tr) {
    var contact_method_value = args['contact_method_value'];
    var contact_method_type_id = args['contact_method_type_id'];
    var contact_method_usable = args['contact_method_usable'];
    tr.appendChild(this.make_hidden("contact_method_type_id", contact_method_types[contact_method_type_id], contact_method_type_id));
    usable_node = this.make_hidden("ok", contact_method_usable, contact_method_usable);
    usable_node.className = "ok";
    tr.appendChild(usable_node);
    description_node = this.make_hidden("value", contact_method_value, contact_method_value);
    description_node.className = "description";
    tr.appendChild(description_node);
  },
});

  function three_to_one(hour, min, ampm) {
        if(hour != "12" && ampm == "PM") {
          hour = "" + (parseInt(hour) + 12);
             } else if(hour == "12" && ampm == "AM") {
                  hour = "0";
                 }
        return hour + ":" + min;
      }

  function one_to_three(one) {
        arr = one.split(":");
        hour = arr[0];
        min = arr[1];
        ampm = "AM";
        if(hour >= 12) {
              if(hour != 12) {
                    hour -= 12;
                  }
              ampm = "PM";
            } else if (hour == 0) {
                  hour = 12;
                }
        hour = "" + hour;
        return [hour, min, ampm];
      }

function three_to_form(a) {
    if(a[0].length == 1) {
      a[0] = "0" + a[0];
    }
    if(a[2] == "AM") {
      a[2] = "-1";
    }
    if(a[2] == "PM") {
      a[2] = "-2";
    }
  return a;
}

function three_to_display(arr) {
  return arr[0] + ":" + arr[1] + " " + arr[2];
}

function form_ampm(ampm) {
    if(ampm == "-1") {
      ampm = "AM";
    } else if (ampm == "-2") {
      ampm = "PM";
    }
  return ampm;
}

function trigger_contact_field(el) {
  // TODO
}

var LineItemComponent = Class.create({
  getValueBySelector: function (thing, selector) {
    return thing.getElementsBySelector(selector).first().firstChild.value;
  },

  make_hidden: function (name, display_value, value){
    var prefix = this.prefix;
    var line_id = this._internal_line_id;
    hidden = document.createElement("input");
    hidden.name = prefix + '[-' + line_id + '][' + name + ']';
    hidden.value = value;
    hidden.type = 'hidden';
    td = document.createElement("td");
    td.className = name;
    td.appendChild(hidden);
    td.appendChild(document.createTextNode(display_value));
    return td;
  },

  initialize: function(prefix) {
    this.prefix = prefix;
  },

  // hooks
  linelist: [],

  add_from_form_reject: function() {
    return false;
  },

  set_args_from_form: function(args) {
    alert('broken');
  },

  edit_hook: function(thing) {
    alert('broken');
  },

  make_hidden_hook: function (args, tr) {
    alert('broken');
  },

  clear_widget: function() {
    alert('broken');
  }
});

var ComponentLineItem = Class.create(LineItem, {
  checkfor: [],
  prefix: null,

  initialize: function($super) {
    $super();
    this.rebuild_component_lists();
  },

  rebuild_component_lists: function() {
    this.componentlist = []; // instances of components
    for(var i = 0; i < this.checkfor.length; i++) {
      var cc = this.checkfor[i];
      var a = cc.prototype.linelist;
      if(eexists(a[0])) {
        var c = this.checkfor[i];
        var x = new c(this.prefix);
        this.componentlist[this.componentlist.length] = x;
      }
    }
    this.linelist = [];
    for(var i = 0; i < this.componentlist.length; i++) {
      var c = this.componentlist[i];
      var l = c.linelist;
      for(var x = 0; x < l.length; x++) {
        this.linelist[this.linelist.length] = l[x];
      }
    }
  },

  edit_hook: function(id) {
    var thing = $(id);
    for(var i = 0; i < this.componentlist.length; i++) {
      var c = this.componentlist[i];
      c.edit_hook(thing);
    }
    this.focus_first();
  },

  make_hidden_hook: function (args, tr) {
    for(var i = 0; i < this.componentlist.length; i++) {
      var c = this.componentlist[i];
      c._internal_line_id = this.counter;
      c.make_hidden_hook(args, tr);
    }
  },

  add_from_form_hook: function() {
    for(var i = 0; i < this.componentlist.length; i++) {
      var c = this.componentlist[i];
      if(c.add_from_form_reject()) {
        return true;
      }
    }
    args = new Object();
    for(var i = 0; i < this.componentlist.length; i++) {
      var c = this.componentlist[i];
      c.set_args_from_form(args);
    }
    this.add(args);
    this.clear_all_widgets();
    this.focus_first();
    return false; // all good
  },

  focus_first: function() {
    $(this.linelist[0]).focus();
  },

  clear_all_widgets: function() { // we can add a button that clears the line if its useful. would presumably clear editing_id too, if set. and we should indicate that its set. anyways..
    for(var i = 0; i < this.componentlist.length; i++) {
      var c = this.componentlist[i];
      c.clear_widget();
    }
  }
});

var VolunteerShiftFrontend = Class.create(LineItem, {
  prefix: 'volunteer_shifts',
  linelist: ['volunteer_task_type_id', 'contact_contact_id', 'class_credit', 'program_id', 'description', 'roster_id', 'slot_number', 'slot_count', 'date_start_hour', 'date_start_minute', 'date_start_ampm', 'date_end_hour', 'date_end_minute', 'date_end_ampm'],

  edit_hook: function(id) {
    var thing = $(id);
    $('volunteer_task_type_id').value = this.getValueBySelector(thing, ".volunteer_task_type_id");
    if(eexists('slot_number')) {
      $('slot_number').value = this.getValueBySelector(thing, ".slot_number");
    } else {
      $('slot_count').value = this.getValueBySelector(thing, ".slot_count");
    }
    $('roster_id').value = this.getValueBySelector(thing, ".roster_id");
    $('program_id').value = this.getValueBySelector(thing, ".program_id");
    $('description').value = this.getValueBySelector(thing, ".description");
    $('class_credit').checked = eval(this.getValueBySelector(thing, ".class_credit"));
    if(eexists('contact_contact_id')) {
      $('contact_contact_id').value = this.getValueBySelector(thing, ".contact_id");
      trigger_contact_field($('contact_contact_id'));
    }
    var a = three_to_form(one_to_three(this.getValueBySelector(thing, ".my_start_time")));
    $('date_start_hour').value = a[0];
    $('date_start_minute').value = a[1];
    $('date_start_ampm').value = a[2];
    a = three_to_form(one_to_three(this.getValueBySelector(thing, ".my_end_time")));
    $('date_end_hour').value = a[0];
    $('date_end_minute').value = a[1];
    $('date_end_ampm').value = a[2];
    $('volunteer_task_type_id').focus();
  },

  add_from_form_hook: function() {
    if((eexists('slot_number') && $('slot_number').value == '')) {
      return true;
    }

    args = new Object();
    if(eexists('slot_number')) {
      args['slot_number'] = $('slot_number').value;
    } else {
      args['slot_count'] = $('slot_count').value;
    }
    args['class_credit'] = $('class_credit').checked;
    args['roster_id'] = $('roster_id').value;
    args['program_id'] = $('program_id').value;
    args['description'] = $('description').value;
    args['volunteer_task_type_id'] = $('volunteer_task_type_id').value;
    var hour = $('date_start_hour').value;
    var minute = $('date_start_minute').value;
    var ampm = form_ampm($('date_start_ampm').value);
    if(eexists('contact_contact_id')) {
      args['contact_id'] = $('contact_contact_id').value;
    }
    args['my_start_time'] = three_to_one(hour, minute, ampm);
    hour = $('date_end_hour').value;
    minute = $('date_end_minute').value;
    ampm = form_ampm($('date_end_ampm').value);
    args['my_end_time'] = three_to_one(hour, minute, ampm);

    this.add(args);
    $('volunteer_task_type_id').selectedIndex = 0; //should be default, but it's yucky
    $('date_end_hour').selectedIndex = 0;
    $('date_end_minute').selectedIndex = 0;
    $('date_end_ampm').selectedIndex = 0;
    $('date_start_hour').selectedIndex = 0;
    $('date_start_minute').selectedIndex = 0;
    $('date_start_ampm').selectedIndex = 0;
    $('roster_id').selectedIndex = 0;
    $('program_id').selectedIndex = 0;
    if(eexists('contact_contact_id')) {
      $('contact_contact_id').value = '';
      trigger_contact_field($('contact_contact_id'));
    }
    $('description').value = $('description').defaultValue;
    $('class_credit').checked = false;
    if(eexists('slot_number')) {
      $('slot_number').value = $('slot_number').defaultValue;
    } else {
      $('slot_count').value = $('slot_count').defaultValue;
    }
    return false;
  },

  copyable: true,

  make_hidden_hook: function (args, tr) {
    var volunteer_task_type_id = args['volunteer_task_type_id'];
    var start_time = args['my_start_time'];
    var end_time = args['my_end_time'];
    var roster_id = args['roster_id'];
    var program_id = args['program_id'];
    var description = args['description'];
    var class_credit = args['class_credit'];

    tr.appendChild(this.make_hidden("volunteer_task_type_id", volunteer_task_types[volunteer_task_type_id], volunteer_task_type_id));
    if(eexists('contact_contact_id')) {
      var contact_id = args['contact_id'];
      tr.appendChild(this.make_hidden("contact_id", contact_id, contact_id)); // TODO: get their name over ajax
    }
    tr.appendChild(this.make_hidden("class_credit", to_yesno(class_credit), class_credit));
    tr.appendChild(this.make_hidden("program_id", vol_progs[program_id], program_id));
    tr.appendChild(this.make_hidden("description", description, description));
    tr.appendChild(this.make_hidden("roster_id", rosters[roster_id], roster_id));
    if(eexists('slot_number')) {
      var slot_number = args['slot_number'];
      tr.appendChild(this.make_hidden("slot_number", slot_number, slot_number));
    } else {
      var slot_count = args['slot_count'];
      tr.appendChild(this.make_hidden("slot_count", slot_count, slot_count));
    }
    tr.appendChild(this.make_hidden("my_start_time", three_to_display(one_to_three(start_time)), start_time ));
    tr.appendChild(this.make_hidden("my_end_time", three_to_display(one_to_three(end_time)), end_time ));
  },

});
function to_yesno(truefalse) {
  return truefalse ? "yes" : "no";
}

var ResourceComponent = Class.create(LineItemComponent, {
  linelist: ['resource_id'],

  set_args_from_form: function(args) {
    args['resource_id'] = $('resource_id').value;
  },

  make_hidden_hook: function(args, tr) {
    var resource_id = args['resource_id'];
    tr.appendChild(this.make_hidden("resource_id", vol_resources[resource_id], resource_id));
  },

  clear_widget: function(){
    $('resource_id').selectedIndex = 0;
  },

  add_from_form_reject: function() {
    return $('resource_id').selectedIndex == 0;
  },

  edit_hook: function(thing) {
    $('resource_id').value = this.getValueBySelector(thing, ".resource_id");
  }
});

var RosterComponent = Class.create(LineItemComponent, {
  add_from_form_reject: function() {
    return $('roster_id2').selectedIndex == 0;
  },

  linelist: ['roster_id2'],

  edit_hook: function(thing) {
    $('roster_id2').value = this.getValueBySelector(thing, ".roster_id");
  },

  clear_widget: function(){
    $('roster_id2').selectedIndex = 0;
  },

  make_hidden_hook: function(args, tr) {
    var roster_id = args['roster_id'];
    tr.appendChild(this.make_hidden("roster_id", rosters[roster_id], roster_id));
  },

  set_args_from_form: function(args) {
    args['roster_id'] = $('roster_id2').value;
  }

});

var StartTimeComponent = Class.create(LineItemComponent, {
  time_name: 'start',
  linelist: ['date_start_hour2', 'date_start_minute2', 'date_start_ampm2'],

  edit_hook: function(thing) {
    var a = three_to_form(one_to_three(this.getValueBySelector(thing, ".my_start_time")));
    $('date_' + this.time_name + '_hour2').value = a[0];
    $('date_' + this.time_name + '_minute2').value = a[1];
    $('date_' + this.time_name + '_ampm2').value = a[2];
  },

  set_args_from_form: function(args) {
    var hour = $('date_' + this.time_name + '_hour2').value;
    var minute = $('date_' + this.time_name + '_minute2').value;
    var ampm = form_ampm($('date_' + this.time_name + '_ampm2').value);
    args['my_' + this.time_name + '_time'] = three_to_one(hour, minute, ampm);
  },

  clear_widget: function(){
    $('date_' + this.time_name + '_hour2').selectedIndex = 0;
    $('date_' + this.time_name + '_minute2').selectedIndex = 0;
    $('date_' + this.time_name + '_ampm2').selectedIndex = 0;
  },

  make_hidden_hook: function(args, tr) {
    var time = args['my_' + this.time_name + '_time'];
    tr.appendChild(this.make_hidden('my_' + this.time_name + '_time', three_to_display(one_to_three(time)), time ));
  }
});

var EndTimeComponent = Class.create(StartTimeComponent, {
  time_name: 'end',
  linelist: ['date_end_hour2', 'date_end_minute2', 'date_end_ampm2']
});

var VolunteerResourceFrontend = Class.create(ComponentLineItem, {
  prefix: 'resources_volunteer_events',
  copyable: true,
  checkfor: [ResourceComponent, RosterComponent, StartTimeComponent, EndTimeComponent]
});


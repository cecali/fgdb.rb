module ReportsHelper
  # I can describe this file in one word: ugly
  # it needs a little work done on it...
  def get_matches(what_to_match)
    @this_thing.find(what_to_match).to_a
  end
  def load_xml
    require 'xml/libxml'
    @this_thing = XML::Parser.string(@report.lshw_output).parse
    nil
  end
  def remove_tag(s, tag)#needs a new name...replace all 'tag's with the right word
    s.to_s.gsub(/<#{tag}\b[^>]*>(.*?)<\/#{tag}>/, '\1')
    #   s.to_s.match(/<#{tag}\b[^>]*>(.*?)<\/#{tag}>/)[1] #might be better...
  end
  def remove_attribute(s, tag)#needs a new name...replace all 'tag's with the right word
    s.to_s.gsub(/#{tag}="([^"]*)"/, '\1')
    #   s.to_s.match(/<#{tag}\b[^>]*>(.*?)<\/#{tag}>/)[1] #might be better...
  end
  def xpath_if(what_to_look_for)
    get_matches(what_to_look_for)[0]
  end
  def xpath_foreach(xpath_thing)
    for this_thing in get_matches(xpath_thing) 
      old_value=@this_thing
      @this_thing=this_thing
      yield
      @this_thing=old_value #use a better variable name for this too...replace this_thing with something better
    end
  end
  def whats_in_this_thing(what_to_get)
    nodes=get_matches(what_to_get)
    if what_to_get[0]=='@'[0]
      remove_attribute(nodes, what_to_get.gsub(/@/, '')) #we are good with just this
    else
      remove_tag(nodes, what_to_get) #theres a tag around it...remove it please!
    end
  end
  #TODO: make a xpath_numerical or something like that
  def xpath_value_of(what_to_get, put_me_before = nil, put_me_after = nil)
    if xpath_if(what_to_get)
      "#{put_me_before}#{whats_in_this_thing(what_to_get)}#{put_me_after}"
    else
      "Unknown"
    end
  end
end

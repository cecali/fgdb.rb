module ContactsHelper
  include AjaxScaffold::Helper
  
  def num_columns
    scaffold_columns.length + 1 
  end
  
  def scaffold_columns
    Contact.scaffold_columns
  end

  def searchbox_field_id(options)
    "#{options[:scaffold_id]}_field"
  end

  def searchbox_hidden_id(options)
    "#{options[:scaffold_id]}_hidden"
  end

  def searchbox_div_id(options)
    "#{options[:scaffold_id]}_div"
  end

  def searchbox_search_results_div_id(options)
    "#{options[:scaffold_id]}_search_results"
  end

  def searchbox_search_button_id(options)
    "#{options[:scaffold_id]}_search_button"
  end

  def searchbox_select_id(options)
    "#{options[:scaffold_id]}_select"
  end

  def searchbox_display_id(options)
    "#{options[:scaffold_id]}_display"
  end

  def searchbox_search_label(options)
    session[options[:scaffold_id]][:search_label]
  end

  def searchbox_select_label(options)
    session[options[:scaffold_id]][:select_label]
  end

  def searchbox_select_name(options)
    session[options[:scaffold_id]][:select_name]
  end

  def form_insertion_div_id(options)
    "#{options[:scaffold_id]}_form_insertion"
  end

end

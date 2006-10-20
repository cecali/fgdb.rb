module GizmoContextsHelper
  include AjaxScaffold::Helper
  
  def num_columns
    scaffold_columns.length + 1 
  end
  
  def scaffold_columns
    [
      AjaxScaffold::ScaffoldColumn.new(GizmoContext, 
        :name => 'name'),
    ]
  end

end

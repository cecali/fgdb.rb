module TableHelper
  def make_table(a, html_opts = {})
    trs = a.map_with_index{|x, i|
      subtype = "first"
      subtype = "all" if i == 0
      table_make_tr(subtype, x)
    }
    HtmlTag.new("table", ({:width => "98%", :border => 1, :style => "border-collapse: collapse;"}).merge(html_opts), trs)
  end

  def table_make_tr(type, a)
    opts = {}
    if a.first.class == Hash
      opts = a.shift
    end
    childs = a.map_with_index{|x, i|
      subtype = "td"
      subtype = "th" if (type == "first" && i == 0) or type == "all"
      table_make_td(subtype, x)
    }
    HtmlTag.new("tr", opts, childs)
  end

  def table_make_td(type, value)
    HtmlTag.new(type, {}, [], value)
  end
end

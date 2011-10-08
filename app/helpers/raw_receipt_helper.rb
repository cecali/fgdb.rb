# Receipt printer configuration:
# the local machines configures a printer for on the parellel port with make "Raw" and driver "Raw Queue" (might need to enable printing from Internet)
# scribble adds a network IPP printer with address http://MACHINE:631/printers/PRINTER_NAME
# the users installs java and chooses to enable text receipts for their session in fgdb's receipt display and chooses the printer

module RawReceiptHelper
  def receipt_printer_enabled
    # TODO: Default.keys.include?("raw_receipt_printer")
    Default.is_pdx
  end

  def receipt_printer_default
    if ((!session.keys.include?('raw_receipt_printer')) and receipt_printer_enabled)
      session['raw_receipt_printer'] = "zebra" # TODO: Default["raw_receipt_printer"] database someday, see above
    end
    session['raw_receipt_printer']
  end

  def receipt_printer_set_default(val)
    session['raw_receipt_printer'] = val
  end

  def receipt_trailing_newlines
    7
  end

  def generate_raw_receipt(printer = nil)
    printer ||= receipt_printer_default
    lim = limit_by_printer_name(printer)
    text_lines = yield(lim)
    text_lines.map{|line| receipt_printer_format_line(line, lim)}.join("\n") + ("\n"*receipt_trailing_newlines) + printer_cut_character(printer)
  end

  def receipt_printer_html
    if receipt_printer_enabled
      return render(:partial => 'raw_receipt_form')
    end
  end

  def handle_java_print(page, text, opts)
    if opts[:loading]
      page << "loading_indicator_after_print = #{opts[:loading].to_json};";
    end
    if opts[:redirect]
      page << "redirect_after_print = #{opts[:redirect].to_json}"
    end
    if RAILS_ENV == "development"
      page << "alert('Would have printed to text receipt mode (but RAILS_ENV is development):' + #{text.to_json});"
      page << "after_print_hook();"
    else
      page << "print_text(#{res.to_json});"
    end
    if opts[:alert]
      page << "alert(#{opts[:alert].to_json});" if opts[:alert].length > 0
    end
  end

  # TODO: need to make sure handling of line_width and indent is correct always
  def basic_wrap_lines(text, line_width, indent = 0)
    to_add = (" " * indent)
    my_next_limit = (line_width - indent)
    text.split("\n").collect do |line|
      if line.length > line_width
        r = line.sub(/(.{1,#{line_width}})(\s+|$)/, "\\1\n").split("\n")
        firstline = r.shift
        if r.length > 0
          rest = r.join("\n")
          if rest.length > my_next_limit
            rest = rest.gsub(/(.{1,#{my_next_limit}})(\s+|$)/, "#{to_add}\\1\n").strip
          end
          a= [firstline, to_add + rest]
          a.join("\n")
        else
          firstline
        end
      else
        line
      end
    end * "\n"
  end

  def receipt_printer_format_line(line, limit, padding = 2)
    type = line.shift
    limit -= (2 * padding)
    textline = line.join(' ')
    pad =  (' ' * (padding))
    if line.length == 0
      return textline
    elsif type == 'center'
      if textline.length > limit # if too long just format as left text, this should mean things are broken
        return pad + receipt_printer_format_line(['left', textline], limit, 0) + pad
      else
        extra_needed = (limit - textline.length)
        one_off = (extra_needed % 2)
        extra_needed -= one_off
        right = (extra_needed / 2)
        left = right + one_off
        return (' ' * (padding + left))+ (textline)+ (' ' * (padding + right))
      end
    elsif type == 'standard'
      return line[0]
    elsif type == 'left'
      return pad + basic_wrap_lines(textline, limit, 2 + padding)
    elsif type == 'two'
      left_limit = (limit % 2)
      left_limit += ((limit - left_limit) / 2)
      first_col = line[0]
      second_col = line[1]
      while first_col.length < left_limit
        first_col += ' '
      end
      result = first_col + second_col
      return pad + result + pad
    elsif type == 'right'
      # will handle the arry named line
      # line will have up to 5 elements, with up to 8 chars each
      # will add padding to sides, line elements up with right side and pad with spaces to fill out
      mys = ''
      5.times do |x|
        this = line.pop.to_s
        mys = this + mys
        t = ((x + 1) * 8)
#        t -= 1 if x == 0 # evil
        t += 1 if x == 1 # replaced
        while mys.length < t
          mys = ' ' + mys
        end
      end
      return mys
    else
      raise "Unknown type of line: #{type}"
    end
  end

  def printer_cut_character(printer_name)
    printer_characters = {}
    printer_characters[printer_name] || "\x1Bi"
  end

  def limit_by_printer_name(printer_name)
    printer_limits = {}
    printer_limits[printer_name] || 44
  end
end


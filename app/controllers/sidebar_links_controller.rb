class SidebarLinksController < ApplicationController
  layout :with_sidebar

  protected
  def get_required_privileges
    a = super
    a << {:privileges => ['role_admin'], :only => ["crash", "recent_crash"]}
    a
  end


  public
  def recent_crash
    d = File.join(RAILS_ROOT, "tmp", "crash")
    @page = params[:page] || 1
    @page = @page.to_i
    @first = `ls -t #{d} | head -#{30 * @page}`.split("\n")
    @first = @first[((@page - 1) * 30)..(@page * 30)]
    @first ||= []
    @first = @first.map{|x| x.split(".").last}
    @strs = {}
    for file in @first
      f = File.join(RAILS_ROOT, "tmp", "crash", "crash." + file)
      data = JSON.parse(File.read(f))
      @strs[file] = data
    end
  end

  def crash
    f = File.join(RAILS_ROOT, "tmp", "crash", "crash." + params[:id])
    if !File.exist?(f)
      render :text => "oops, that crash id doesn't exist."
      return
    end
    @exception_data = JSON.parse(File.read(f))
  end

  def fgss_moved
    render :layout => false
  end

  def staffsched_moved
    render :layout => false
  end
end

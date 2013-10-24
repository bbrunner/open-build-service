class Webui::MainController < Webui::WebuiController

  include Webui::WebuiHelper
  include StatisticsCalculations

  # permissions.status_message_create
  before_filter :require_admin, only: [:delete_message, :add_news]

  def index
    @news = StatusMessage.alive.limit(4)
    unless @spider_bot
      @latest_updates = get_latest_updated(6)
    end
  rescue ActiveXML::Transport::UnauthorizedError
    @anonymous_forbidden = true
    logger.error 'Could not load all frontpage data, probably due to forbidden anonymous access in the api.'
  end

  # This action does the heavy lifting for the index method and is only invoked by an AJAX request
  def systemstatus
    check_ajax
    if @spider_bot
      @workerstatus = Xmlhash::XMLHash.new
    else
      @workerstatus = WorkerStatus.hidden.to_hash
    end
    @waiting_packages = 0
    @workerstatus.elements('waiting') {|waiting| @waiting_packages += waiting['jobs'].to_i}
    @busy = nil
    require_available_architectures unless @spider_bot
    if @available_architectures
      @available_architectures.each.map {|arch| map_to_workers(arch.name) }.uniq.each do |arch|
        archret = frontend.gethistory('building_' + arch, 168).map {|time,value| [time,value]}
        if archret.length > 0
          if @busy
            @busy = Webui::MonitorController.addarrays(@busy, archret)
          else
            @busy = archret
          end
        end
      end
    end
    render :partial => 'webui/main/systemstatus'
  rescue ActiveXML::Transport::UnauthorizedError 
    @anonymous_forbidden = true
    render :text => '' # AJAX-request means no 'flash' available, don't render anything if we aren't allowed
  end

  def news
    @news = StatusMessage.alive.limit(5)
    raise ActionController::RoutingError.new('expected application/rss') unless request.format == Mime::RSS
    render layout: false
  end

  def latest_updates
    raise ActionController::RoutingError.new('expected application/rss') unless request.format == Mime::RSS
    @latest_updates = get_latest_updated(10)
    render layout: false
  end

  def sitemap
    render :layout => false, :content_type => 'application/xml'
  end

  def require_projects
    @projects = Array.new
    Webui::Collection.find(:id, :what => 'project').each_project do |p|
      @projects << p.value(:name)
    end
  end

  def sitemap_projects
    require_projects
    render :layout => false, :content_type => 'application/xml'
  end
 
  def sitemap_projects_subpage(action, changefreq, priority)
    require_projects
    render :template => 'webui/main/sitemap_projects_subpage', :layout => false, :locals => { :action => action, :changefreq => changefreq, :priority => priority }, :content_type => 'application/xml'
  end

  def sitemap_projects_packages
    sitemap_projects_subpage(:packages, 'monthly', 0.7)
  end

  def sitemap_projects_prjconf
    sitemap_projects_subpage(:prjconf, 'monthly', 0.1)
  end

  def sitemap_packages
    category = params[:category].to_s
    @packages = Array.new
    predicate = ''
    if category =~ %r{home}
      predicate = "starts-with(@project,'#{category}')"
    elsif category == 'opensuse'
      predicate = "starts-with(@project,'openSUSE:')"
    elsif category == 'main'
      predicate = "not(starts-with(@project,'home:')) and not(starts-with(@project,'DISCONTINUED:')) and not(starts-with(@project,'openSUSE:'))"
    end
    Webui::Collection.find(:id, :what => 'package', :predicate => predicate).each_package do |p|
      @packages << [p.value(:project), p.value(:name)]
    end
    render :template => 'webui/main/sitemap_packages', :layout => false, :locals => {:action => params[:listaction]}, :content_type => 'application/xml'
  end

  def add_news_dialog
    render_dialog
  end

  def add_news
    if params[:message].nil? or params[:severity].empty?
      flash[:error] = 'Please provide a message and severity'
      redirect_to(:action => 'index') and return
    end
    #TODO - make use of permissions.status_message_create
    StatusMessage.create!(message: params[:message], severity: params[:severity], user: User.current)
    redirect_to(:action => 'index')
  end

  def delete_message_dialog
    render_dialog
  end

  def delete_message
    required_parameters :message_id
    StatusMessage.find(params[:message_id]).delete
    redirect_to(:action => 'index')
  end

  def require_available_architectures
    super # Call ApplicationController implementation, but catch an additional exception
  rescue ActiveXML::Transport::UnauthorizedError
    @anonymous_forbidden = true
    logger.error 'Could not load all frontpage data, probably due to forbidden anonymous access in the api.'
  end

end
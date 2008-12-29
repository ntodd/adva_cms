class WikiController < BaseController
  before_filter :set_category, :only => [:index]
  before_filter :set_categories, :only => [:edit]
  before_filter :set_tags, :only => [:index]
  before_filter :set_wikipage, :except => [:index, :new, :create]
  before_filter :set_wikipages, :only => [:index]
  before_filter :set_author_params, :only => [:create, :update]
  before_filter :optimistic_lock, :only => [:update]

  authenticates_anonymous_user
  acts_as_commentable

  caches_page_with_references :index, :show, :track => ['@wikipage', '@wikipages', '@category', {'@site' => :tag_counts, '@section' => :tag_counts}]
  cache_sweeper :wikipage_sweeper, :category_sweeper, :tag_sweeper, :only => [:create, :update, :rollback, :destroy]
  guards_permissions :wikipage, :except => [:index, :show, :diff, :comments], :edit => :rollback

  def index
    respond_to do |format|
      format.html { render } # @section.render_options TODO causes specs to fail in Rails 2.2
      format.atom { render :layout => false }
    end
    # TODO @section.render_options.update(:action => 'show')
  end

  def new
    @wikipage = Wikipage.new(:title => t(:'adva.wiki.new_page_title'))
  end

  def show
    set_categories if @wikipage.new_record?
    if !@wikipage.new_record?
      render # @section.render_options TODO causes specs to fail in Rails 2.2
    elsif has_permission? :create, :wikipage
      render :action => :new, :skip_caching => true
    else
      redirect_to_login t(:'adva.wiki.redirect_to_login')
    end
    # options = @wikipage.new_record? ? {:action => :new} : @section.render_options
    # render options
  end

  def diff
    @diff = @wikipage.diff_against_version params[:diff_version]
  end

  def create
    @wikipage = @section.wikipages.build(params[:wikipage])
    if @wikipage.save
      trigger_events @wikipage
      flash[:notice] = t(:'adva.wiki.flash.create.success')
      redirect_to wikipage_path(:section_id => @section, :id => @wikipage.permalink)
    else
      flash[:error] = t(:'adva.wiki.flash.create.failure')
      render :action => :new
    end
  end

  def edit
  end

  def update
    params[:wikipage][:version] ? rollback : update_attributes
  end

  def update_attributes
    if @wikipage.update_attributes(params[:wikipage])
      trigger_event @wikipage, :updated
      flash[:notice] = t(:'adva.wiki.flash.update_attributes.success')
      redirect_to wikipage_path(:section_id => @section, :id => @wikipage.permalink)
    else
      flash.now[:error] = t(:'adva.wiki.flash.update_attributes.failure')
      render :action => :edit
    end
  end

  def rollback
    version = params[:wikipage][:version].to_i
    if @wikipage.version != version and @wikipage.revert_to!(version)
      trigger_event @wikipage, :rolledback
      flash[:notice] = t(:'adva.wiki.flash.rollback.success', :version => params[:version])
      redirect_to wikipage_path(:section_id => @section, :id => @wikipage.permalink)
    else
      flash.now[:error] = t(:'adva.wiki.flash.rollback.failure', :version => params[:version])
      redirect_to wikipage_path(:section_id => @section, :id => @wikipage.permalink)
    end
  end

  def destroy
    if @wikipage.destroy
      trigger_events @wikipage
      flash[:notice] = t(:'adva.wiki.flash.destroy.success')
      redirect_to wiki_path(@section)
    else
      flash.now[:error] = t(:'adva.wiki.flash.destroy.failure')
      render :action => :show
    end
  end

  private

    def set_section; super(Wiki); end

    def set_wikipage
      # TODO do not initialize a new wikipage on :edit and :update actions
      @wikipage = @section.wikipages.find_or_initialize_by_permalink params[:id] || 'home'
      raise t(:'adva.wiki.exception.could_not_find_wikipage_by_permalink', :id => params[:id]) if params[:show] && @wikipage.new_record?
      @wikipage.revert_to(params[:version]) if params[:version]
      @wikipage.author = current_user || User.anonymous if @wikipage.new_record? || 
        params[:action] == 'edit'
    end

    def set_wikipages
      options = { :page => current_page, :tags => @tags }
      source = @category ? @category.contents : @section.wikipages
      @wikipages = source.paginate options
    end

    def set_category
      if params[:category_id]
        @category = @section.categories.find params[:category_id]
        raise ActiveRecord::RecordNotFound unless @category
      end
    end

    def set_categories
      @categories = @section.categories.roots
    end

    def set_tags
      if params[:tags]
        names = params[:tags].split('+')
        @tags = Tag.find(:all, :conditions => ['name IN(?)', names]).map(&:name)
        raise ActiveRecord::RecordNotFound unless @tags.size == names.size
      end
    end

    def set_commentable
      set_wikipage if params[:id]
      @commentable = @wikipage || super
    end

    def set_author_params
      params[:wikipage][:author] = current_user ? current_user : nil if params[:wikipage]
    end

    def optimistic_lock
      return unless params[:wikipage]
      updated_at = params[:wikipage].delete(:updated_at)
      unless updated_at
        # TODO raise something more explicit here
        raise t(:'adva.wiki.exception.missing_timestamp')
      end
      if @wikipage.updated_at && (Time.zone.parse(updated_at) != @wikipage.updated_at)
        flash[:error] = t(:'adva.wiki.flash.optimistic_lock.failure')
        # TODO filter_chain has been halted because of the rendering, so we have
        # to call this manually ... which is stupid. Maybe an around_filter
        # would be the better idea in CacheableFlash?
        write_flash_to_cookie
        render :action => :edit
      end
    end

    def current_role_context
      @wikipage || @section
    end
end

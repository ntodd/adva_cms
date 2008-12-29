require File.dirname(__FILE__) + "/../../test_helper"

# With.aspects << :access_control

class AdminSectionsControllerTest < ActionController::TestCase
  tests Admin::SectionsController

  with_common :is_superuser, :an_empty_section
  
  def default_params
    { :site_id => @site.id }
  end
   
  test "is an Admin::BaseController" do
    Admin::BaseController.should === @controller # FIXME matchy doesn't have a be_kind_of matcher
  end
   
  describe "routing" do
    with_options :path_prefix => '/admin/sites/1/', :site_id => "1" do |r|
      r.it_maps :get,    "sections",        :action => 'index'
      r.it_maps :get,    "sections/1",      :action => 'show',    :id => '1'
      r.it_maps :get,    "sections/new",    :action => 'new'
      r.it_maps :post,   "sections",        :action => 'create'
      r.it_maps :get,    "sections/1/edit", :action => 'edit',    :id => '1'
      r.it_maps :put,    "sections/1",      :action => 'update',  :id => '1'
      r.it_maps :delete, "sections/1",      :action => 'destroy', :id => '1'
    end
  end
  
  describe "GET to :new" do
    action { get :new, default_params }
    
    it_guards_permissions :create, :section
    
    with :access_granted do
      it_assigns :site, :section => :not_nil
      it_renders_template :new
    end
  end
  
  describe "POST to :create" do
    action do 
      Section.with_observers :section_sweeper do
        post :create, default_params.merge(@params)
      end
    end
    
    with :valid_section_params do
      it_guards_permissions :create, :section
      
      with :access_granted do
        it_assigns :site, :section => :not_nil
        it_redirects_to { @controller.admin_section_contents_path(assigns(:section)) }
        it_assigns_flash_cookie :notice => :not_nil
        it_sweeps_page_cache :by_site => :site

        it "associates the new Section to the current site" do
          assigns(:section).site.should == @site
        end
      end
    
      with :invalid_section_params do
        it_assigns :site, :section => :not_nil
        it_renders_template :new
        it_assigns_flash_cookie :error => :not_nil
      end
    end
  end
  
  describe "GET to :edit" do
    action { get :edit, default_params.merge(:id => @section.id) }
    
    it_guards_permissions :update, :section
    
    with :access_granted do
      it_assigns :site, :section
      it_renders_template :edit
    end
  end
  
  describe "PUT to :update" do
    action do
      Section.with_observers :section_sweeper do
        params = default_params.merge(@params).merge(:id => @section.id)
        params[:section][:title] = "#{@section.title} was changed" unless params[:section][:title].blank?
        put :update, params
      end
    end
  
    with :valid_section_params do
      it_guards_permissions :update, :section
    
      with :access_granted do
        it_assigns :section
        it_updates :section
        it_redirects_to { edit_admin_section_path(@site, @section) }
        it_assigns_flash_cookie :notice => :not_nil
        # it_triggers_event :section_updated
        it_sweeps_page_cache :by_section => :section
      end
    end
  
    with :invalid_section_params do
      with :access_granted do
        it_renders_template :edit
        it_assigns_flash_cookie :error => :not_nil
      end
    end
  end
  
  describe "PUT to :update_all" do
    action do 
      params = {:sections => {@section.id => {'parent_id' => @another_section.id}}}
      put :update_all, default_params.merge(params) 
    end
    
    before do
      @another_section = Section.make :site => @site
      @old_path = @section.path
    end
    
    it_guards_permissions :update, :section
    
    with :access_granted do
      it "updates the site's sections with the section params" do
        @section.reload.parent_id.should != @another_section.id
      end
    
      it "updates the section's paths" do
        @section.reload.path.should == "#{@another_section.path}/#{@section.permalink}"
      end
      
      # FIXME expire cache by site
    end
  end
  
  describe "DELETE to :destroy" do
    action do 
      Section.with_observers :section_sweeper do
        delete :destroy, default_params.merge(:id => @section.id)
      end
    end
    
    it_guards_permissions :destroy, :section
    
    with :access_granted do
      it_assigns :site, :section
      it_destroys :section
      # it_triggers_event :section_deleted
      # it_redirects_to { admin_site_path(@site) } # FIXME actually is new_admin_section_path?
      it_sweeps_page_cache :by_site => :site
      it_assigns_flash_cookie :notice => :not_nil
    end
  end
end

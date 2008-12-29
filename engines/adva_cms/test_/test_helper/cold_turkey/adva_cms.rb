module With
  class Group
    def it_triggers_event(type)
      expect do
        record = satisfy{|arg| type.to_s =~ /#{arg.class.name.underscore}/ }
        controller = is_a(ActionController::Base)
        options = is_a(Hash)
        mock.proxy(Event).trigger(type, record, controller, options)
      end
    end
  
    def it_does_not_trigger_any_event
      expect do
        do_not_allow(Event).trigger.with_any_args
      end
    end
    
    def it_guards_permissions(action, type)
      # FIXME would break due to require_authentication kicking in
      # so maybe rely on just #guard_permission instead?
      # expect do
      #   mock(@controller).has_permission?(action, type)
      # end
      return unless With.test?(:access_control)

      with :"superuser_may_#{action}_#{type}" do
        it_denies_access  :with => [:is_anonymous, :is_user, :is_moderator, :is_admin]
        it_grants_access  :with => [:is_superuser]
      end

      with :"admin_may_#{action}_#{type}" do
        it_denies_access  :with => [:is_anonymous, :is_user, :is_moderator]
        it_grants_access  :with => [:is_admin, :is_superuser]
      end

      with :"moderator_may_#{action}_#{type}" do
        it_denies_access :with => [:is_anonymous, :is_user]
        it_grants_access :with => [:is_admin, :is_superuser] 
        # FIXME should grant to :is_moderator, but currently require_authentication requires an :admin role
      end
    end

    def it_grants_access(options = {})
      group = options[:with] ? with(*options[:with]) : self
      group.assertion do
        message = "expected to grant access but %s"
        assert !rendered_insufficient_permissions?, message % 'rendered :insufficient_permissions'
        assert !redirected_to_login?, message % 'redirected to login_path'
      end
    end

    def it_denies_access(options = {})
      group = options[:with] ? with(*options[:with]) : self
      group.assertion do
        message = "expected to render :insufficient_permissions or redirect to login_path but did neither of these."
        assert rendered_insufficient_permissions? || redirected_to_login?, message
      end
    end
    
    def it_sweeps_page_cache(options)
      options = options.dup
      
      expect do
        options.each do |type, record|
          record = instance_variable_get("@#{record}")
          filters = @controller.class.filter_chain
          sweeper = filters.detect { |f| f.method.is_a?(PageCacheTagging::Sweeper) }.method
          
          case type
          when :by_site
            mock.proxy(sweeper).expire_cached_pages_by_site(record)
          when :by_section
            mock.proxy(sweeper).expire_cached_pages_by_section(record)
          when :by_reference
            mock.proxy(sweeper).expire_cached_pages_by_reference(record)
          end
        end
      end
    end
    
    def it_does_not_sweep_page_cache
      expect do
        do_not_allow(@controller).expire_pages.with_any_args
      end
    end
  end
end

class ActionController::TestCase
  def login_as_superuser!
    stub(@controller).current_user.returns(User.make :roles => [Rbac::Role.build(:superuser)])
  end
  
  def rendered_insufficient_permissions?
    !!(@response.rendered_template.to_s =~ /insufficient_permissions/)
  end
  
  def redirected_to_login?
    @response.redirect_url_match?(/#{login_path}/)
  end
end
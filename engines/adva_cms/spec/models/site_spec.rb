require File.dirname(__FILE__) + '/../spec_helper'

describe Site do
  include Matchers::ClassExtensions
  fixtures :sites, :sections

  before :each do
    User.delete_all
    @site = sites(:site_1)
    @home = sections(:home)
    @about = sections(:about)
    @location = sections(:location)
  end

  describe 'class extensions:' do
    it 'acts as themed' do
     Site.should act_as_themed
   end

    it 'acts as commentable' do
      Site.should act_as_commentable
    end

    it 'acts as role context for the admin role' do
      Site.should act_as_role_context(:roles => :admin)
    end

    it "serializes its actual permissions" do
      Site.serialized_attributes.keys.should include('permissions')
    end

    it "serializes the spam options" do
      Site.serialized_attributes.keys.should include('spam_options')
    end

    it "has a comments counter" do
      Site.should have_counter(:comments)
    end
  end

  describe 'associations:' do
    it "has many sections" do
      @site.should have_many(:sections)
    end

    it "has many users" do
      @site.should have_many(:users)
    end

    it "has many memberships" do
      @site.should have_many(:memberships)
    end

    it "has many assets" do
      @site.should have_many(:assets)
    end

    it "has many cached_pages" do
      @site.should have_many(:cached_pages)
    end

    describe 'the sections association' do
      it "returns the left-most section that has no parent as the root section" do
        @site.sections.root.should == @home
      end

      it "#update_paths! updates all paths" do
        sections = [@home, @about, @location]
        sections.each do |section|
          section.path = nil
          section.save!
        end
        @site.sections.update_paths!
        sections.map(&:reload)
        sections.collect(&:path).should == ['home', 'home/about', 'home/about/location']
      end
    end

    describe 'the assets association' do
      it "#recent finds the six most recent assets" do
        @site.assets.should_receive(:find).with :all, :limit => 6
        @site.assets.recent
      end
    end

    it "calls destroy on associated users when destroyed" do
      user = @site.users.create :first_name => 'John', :last_name => 'Doe',
        :email => 'email@foo.bar', :password => 'password'
      user.should_not be_false
      @site.destroy
      lambda{ User.find user.id }.should raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'methods' do
    describe '#replace_host_spaces' do
      it 'removes spaces from start of the line' do
        @site.host = '    t e s t.advabest.de'
        @site.send(:replace_host_spaces).should == 't-e-s-t.advabest.de'
      end

      it 'replaces spaces with -' do
        @site.host = 't e s t.advabest.de'
        @site.send(:replace_host_spaces).should == 't-e-s-t.advabest.de'
      end

      it 'removes spaces from end of the line' do
        @site.host = 't e s t.advabest.de    '
        @site.send(:replace_host_spaces).should == 't-e-s-t.advabest.de'
      end
    end

    it '#permalinkaze_host should return host as a permalink' # do
    #   @site.host = 't e s t.advabest.de'
    #   @site.send(:permalinkaze_host).should == 't-e-s-t.advabest.de'
    # end

    describe "#has_tracking_enabled?" do
      it "has tracking enabled if Google Analytics tracking code is set" do
        @site.stub!(:google_analytics_tracking_code).and_return("UA-123456")
        @site.should have_tracking_enabled
      end

      it "has tracking disabled if Google Analytics tracking code is not set" do
        @site.stub!(:google_analytics_tracking_code).and_return(nil)
        @site.should_not have_tracking_enabled
      end
    end
  end

  describe 'callbacks:' do
    it 'downcases the host before validation' do
      Site.before_validation.should include(:downcase_host)
    end

    it 'permalinkizes host before validation' # do
    #   Site.before_validation.should include(:permalinkaze_host)
    # end

    it 'strips spaces from host before validation' do
      Site.before_validation.should include(:replace_host_spaces)
    end

    it 'flushs the page cache after destroy' do
      Site.before_destroy.should include(:flush_page_cache)
    end
  end

  describe "validations:" do
    it "validates the presence of a host" do
      @site.should validate_presence_of(:host)
    end

    it "validates the presence of a name" do
      @site.should validate_presence_of(:name)
    end

    it "should have title == name when title is blank" do
      site = Factory.create(:site, :name => 'Example', :title => nil)
      site.title.should == 'Example'
    end

    it "should have title when title is present" do
      site = Factory.create(:site, :name => 'Example', :title => 'Title')
      site.title.should == 'Title'
    end
  end

  describe "plugins:" do
    it "should clone Engines.plugins" do
      @site.plugins.first.object_id.should_not == Engines.plugins.first.object_id
    end

    it "should set plugin owner to site" do
      @site.plugins.first.instance_variable_get(:@owner).should == @site
    end

    it "should save a plugin_configs per site" do
      Engines::Plugin::Config.delete_all

      plugin_1 = sites(:site_1).plugins[:test_plugin]
      plugin_2 = sites(:site_2).plugins[:test_plugin]

      plugin_1.string = 'site_1 string'
      plugin_1.save!
      plugin_1.instance_variable_set :@config, nil # force reload

      plugin_2.string = 'site_2 string'
      plugin_2.save!
      plugin_2.instance_variable_set :@config, nil

      plugin_1.string.should == 'site_1 string'
      plugin_2.string.should == 'site_2 string'
    end
  end

  describe "spam_engine:" do
    it "should return the Default spam engine when none configured" do
      engine = Site.new.spam_engine
      engine.should be_kind_of(SpamEngine::FilterChain)
      engine.first.should be_kind_of(SpamEngine::Filter::Default)
    end

    it "should return the Defensio spam engine when spam_options :engine is set to 'defensio'" do
      site = Site.new :spam_options => {:defensio => {:key => 'defensio key', :url => 'defensio url'}}
      engine = Site.new.spam_engine
      engine.should be_kind_of(SpamEngine::FilterChain)
      engine.first.should be_kind_of(SpamEngine::Filter::Default)
    end
  end
end

require File.dirname(__FILE__) + '/../spec_helper'

describe CalendarEvent do
  include Matchers::ClassExtensions

  before :each do
    @calendar = Calendar.create!(:title => 'Concerts')
    @event = @calendar.events.new(:title => 'The Dodos', :start_date => '2008-11-24 21:30',
      :end_date => '2008-11-25 01:30', :user_id => 1, :location_id => 1)
  end

  describe 'class extensions:' do
    it "acts as a taggable" do
      Content.should act_as_taggable
    end
    it 'should sanitize the body_html attribute' do
      CalendarEvent.should filter_attributes(:sanitize => :body_html)
    end

    it 'should not sanitize the body and cached_tag_list attributes' do
      CalendarEvent.should filter_attributes(:except => [:body, :cached_tag_list])
    end

    it 'should set a permalink' do
      @event.permalink.should be_nil
      @event.save!
      @event.permalink.should ==('the-dodos')
    end
  end
  
  describe 'validations' do
    before :each do
      @event.should be_valid
      @event.save!.should be_true
      @event.reload
    end

    it "must have a title" do
      @event.title = nil
      @event.should_not be_valid
      @event.errors.on("title").should be
      @event.errors.count.should be(1)
    end

    it "must have start datetime" do
      @event.start_date = nil
      @event.should_not be_valid
      @event.errors.on("start_date").should be
      @event.errors.count.should be(1)
    end

    it "must have end datetime" do
      @event.end_date = nil
      CalendarEvent.require_end_date = true
      @event.require_end_date?.should == true
      @event.should_not be_valid
      @event.errors.on("end_date").should be
      @event.errors.count.should be(1)
    end

    it "must not require and end date if model says so" do
      CalendarEvent.require_end_date = false
      @event.end_date = nil
      @event.should be_valid      
    end

    it "must have a start date earlier than the end date" do
      @event.end_date = @event.start_date - 1.day
      @event.should_not be_valid
      @event.errors.on("end_date").should be
      @event.errors.count.should be(1)
    end
  end
  
  describe "relations" do
    it "should have many categories" do
      @event.should have_many(:categories)
    end
    it "should have a location" do
      @event.should belong_to(:location)
    end
  end
  
  describe "named scopes" do
    before do
      Time.stub!(:now).and_return Time.utc(2009,11,27, 12,00)
      Date.stub!(:today).and_return Date.civil(2009,11,27)
      @calendar.events.delete_all
      default_attrs = { :user_id => 1, :location_id => 1, :published_at => Time.now - 2.years }
      @cat1 = @calendar.categories.create!(:title => 'cat1')
      @cat2 = @calendar.categories.create!(:title => 'cat2')
      @cat3 = @calendar.categories.create!(:title => 'cat3')
      @elapsed_event = @calendar.events.create!(default_attrs.merge(:title => 'Gameboy Music Club', 
          :start_date => Time.now - 1.day, :end_date => Time.now - 18.hours, :categories => [@cat1, @cat2])).reload
      @elapsed_event2 = @calendar.events.create!(default_attrs.merge(:title => 'Mobile Clubbing', 
          :start_date => Time.now - 5.hours, :end_date => Time.now - 3.hours, :categories => [@cat1, @cat2])).reload
      @upcoming_event = @calendar.events.create!(default_attrs.merge(:title => 'Jellybeat', 
          :start_date => Time.now + 4.hours, :end_date => Time.now + 6.hours, :categories => [@cat2, @cat3])).reload
      @running_event = @calendar.events.create!(default_attrs.merge(:title => 'Vienna Jazz Floor 08', 
          :start_date => Time.now - 1.month, :end_date => Time.now + 9.days, :categories => [@cat1, @cat3])).reload
      @real_old_event = @calendar.events.create!(default_attrs.merge(:title => 'Vienna Jazz Floor 07', 
          :start_date => Time.now - 1.year, :end_date => Time.now - 11.months, :published_at => nil, :categories => [@cat2])).reload
#      @calendar.reload
    end
    it "should have a elapsed scope" do
      @calendar.events.elapsed.should ==[@elapsed_event2, @elapsed_event, @real_old_event]
    end
    it "should have a recently added scope" do
      @calendar.events.recently_added.should ==[@running_event, @upcoming_event]
    end
    it "should have a published scope" do
      @calendar.events.published.should ==[@elapsed_event, @elapsed_event2, @upcoming_event, @running_event]
    end
    it "should have a by_categories scope" do
      @calendar.events.by_categories(@cat1.id).should ==[@elapsed_event, @elapsed_event2, @running_event]
      @calendar.events.by_categories(@cat2.id).should ==[@elapsed_event, @elapsed_event2, @upcoming_event, @real_old_event]
      @calendar.events.by_categories(@cat3.id).should ==[@upcoming_event, @running_event]
      @calendar.events.by_categories(@cat1.id, @cat2.id).should ==[@elapsed_event, @elapsed_event2, @upcoming_event, @running_event, @real_old_event]
    end
    describe ":upcoming" do
      it "from today on" do
        @calendar.events.upcoming.should ==[@running_event, @upcoming_event]
      end
      it "from tomorrow on" do
         @calendar.events.upcoming(Time.now + 1.day).should ==[@running_event]
      end
      it "for tomorrow only" do
        @calendar.events.upcoming(Time.now + 1.day, Time.now + 2.days).should ==[@running_event]
      end
      it "for last year" do
        @calendar.events.upcoming(Time.now - 1.year).should ==[@real_old_event]
      end
    end
  end
  
  describe "named scope :search" do
    before :each do
      default_attributes = {:user_id => 1, :location_id => 1, :start_date => Time.now,
          :end_date => Time.now + 2.hours}
      @event_jazz = @calendar.events.create!(default_attributes.merge(:title => 'A Jazz concert', :body => 'A band with Sax,Trumpet,Base,Drums'))
      @event_rock = @calendar.events.create!(default_attributes.merge(:title => 'Rocking all night', :body => 'A band with Guitar, Base & Drums'))
    end
    it "should have a search scope by title" do
      @calendar.events.search('Jazz', :title).should ==[@event_jazz]
    end
    it "should have a search scope by body" do
      @calendar.events.search('Base', :body).should ==[@event_jazz, @event_rock]
      @calendar.events.search('Guitar', :body).should ==[@event_rock]
    end
  end
  
  describe "all day" do
    it "should" do
      
    end
  end
end

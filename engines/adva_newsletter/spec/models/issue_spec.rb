require File.dirname(__FILE__) + '/../spec_helper'

describe Issue do
  before :each do
    Site.delete_all
    @issue = Factory :issue
    @user = Factory :user
  end

  describe "associations:" do
    it "sholud belong to newsletter" do @issue.should belong_to(:newsletter) end
    it "should have one cronjob as cronable" do @issue.should have_one(:cronjob) end
  end

  describe "validations:" do
    it "should be valid" do
      @issue.should be_valid
    end

    it "should have title" do
      @issue.title = nil
      @issue.should_not be_valid
    end

    it "should have body" do
      @issue.body = nil
      @issue.should_not be_valid
    end
  end
  
  describe "filtering" do
    it "should have filter for body" do
      @issue.body = "<div>html body</div>"
      @issue.body_html = nil
      @issue.filter = nil
      @issue.save
      @issue.body_html.should == "<div>html body</div>"
    end
  end

  describe "methods:" do
    describe "editable?" do
      it "should be editable when state is draft or published" do
        @issue.editable?.should == true
        @issue.state = "hold"
        @issue.editable?.should == true
      end
      
      it "should NOT be editable when new record" do
        @issue = Issue.new
        @issue.editable?.should == false
      end
      
      it "should NOT be editable" do
        @issue.state = "queued"
        @issue.editable?.should == false
        @issue.state = "delivered"
        @issue.editable?.should == false
      end
    end

    describe "destroy" do
      it "should move Issue to DeletedIssue" do
        Issue.find_by_id(@issue.id).should_not == nil
        DeletedIssue.find_by_id(@issue.id).should == nil
        @issue.destroy
        Issue.find_by_id(@issue.id).should == nil
        DeletedIssue.find_by_id(@issue.id).should_not == nil
      end

      it "should decrease issues_count by -1" do
        @newsletter = Newsletter.first
        @newsletter.issues_count.should == 1
        @newsletter.issues.first.destroy
        @newsletter.reload.issues_count.should == 0
      end
    end
    
    describe "state_time" do
      it "should be updated_at when draft state" do
        @issue.state_time.should == @issue.updated_at
      end
      
      it "should be published_at when on hold state" do
        @issue.published_state!
        @issue.state_time.should == @issue.published_at
      end
      
      it "should be queued_at when queued state" do
        @issue.state = "hold"
        @issue.queued_state!
        @issue.state_time.should == @issue.queued_at
      end
      
      it "should be delivered_at when delivered state" do
        @issue.state = "queued"
        @issue.delivered_state!
        @issue.state_time.should == @issue.delivered_at
      end
    end

### Chaneg states
    describe "[change states group]" do
        before :each do
          @issue.state = "test_state"
        end

      describe "draft_state!" do
        it "should change to draft_state" do
          @issue.state = "hold"
          @issue.draft_state!
          @issue.state.should == "draft"
        end
        
        it "should not allow chaneg to draft unless published or draft" do
          @issue.draft_state!.should == nil
          @issue.state.should == "test_state"
        end
      end

      describe "published_state!" do
        it "should change to published state" do
          @issue.state = "draft"
          @issue.published_state!
          @issue.state.should == "hold"
        end
        
        it "should remove cronjob when previous state was queued" do
          @issue.state = "hold"
          @issue.deliver_all
          @issue.state.should == "queued"

          @issue.published_state!
          @issue.cronjob.should == nil
        end
        
        it "should not allow to change state unless state is draft or queued" do
          @issue.published_state!.should == nil
          @issue.state.should == "test_state"
        end
      end
      
      describe "queued_state!" do
        it "should change to queued state" do
          @issue.state = "hold"
          @issue.queued_state!
          @issue.state.should == "queued"
        end
        
        it "should not allow to change state unless state is published" do
          @issue.queued_state!.should == nil
        end
      end
      
      describe "delivered_state!" do
        it "should change to delivered state" do
          @issue.state = "queued"
          @issue.delivered_state!.should == true
          @issue.delivered?.should == true
        end
        
        it "should not allow change state unless state is queued" do
          @issue.delivered_state!.should == nil
          @issue.state.should == "test_state"
        end
      end

      after :each do
        remove_all_test_cronjobs
      end
    end

    describe "draft!" do
      it "should unpublish" do
        @issue.draft_state!
        @issue.draft?.should == true
      end
    end

    describe "draft?" do
      it "should be true by default" do
        @issue.draft?.should == true
      end

      it "should be false when published" do
        @issue.published_state!
        @issue.draft?.should == false
      end
    end

    describe "published?" do
      it "should be false by default" do
        @issue.published?.should == false
      end
      
      it "should be true when published" do
        @issue.published_state!
        @issue.published?.should == true
      end
      
      it "should be true when state is 'hold' or 'published'" do
        @issue.state = 'published'
        @issue.published?.should == true
        @issue.state = 'hold'
        @issue.published?.should == true
      end
    end

    describe "queued?" do
      it "should be false by default" do
        @issue.queued?.should == false
      end

      it "sholud be true when queued" do
        @issue.state = "queued"
        @issue.queued?.should == true
      end
    end
    
    describe "delivered?" do
      it "should be false by default" do
        @issue.delivered?.should == false
      end
      
      it "should be true when delivered" do
        @issue.state = "queued"
        @issue.delivered_state!
        @issue.delivered?.should == true
      end
    end

    describe "draft" do
      it "should be 1 by default" do
        @issue.draft.should == 1
      end
      
      it "should be 0 when published" do
        @issue.stub!(:published?).and_return(true)
        @issue.draft.should == 0
      end
    end
    
    describe "draft=" do
      it "should set state published when given 0" do
        @issue.draft = 0
        @issue.published?.should == true
      end

      it "should set state not published when given 1" do
        @issue.draft = 1
        @issue.published?.should == false
      end
    end
    
    describe "create_emails" do
      it "should change state to delivered" do
        @issue.state = "queued"
        @issue.create_emails
        @issue.delivered?.should == true
      end
    end
    
    describe "email" do
      it "should provide newsletter email" do
        @issue.newsletter.email = "newsletter@example.org"
        @issue.email.should == "newsletter@example.org"
      end

      it "should provide site email when newsletter email is nil" do
        @issue.newsletter.email = nil
        @issue.newsletter.site.email = "site@example.org"
        @issue.email.should == "site@example.org"
      end
    end
    
    describe "#has_tracking_enabled?" do
      it "has tracking enabled if it should be tracked and Google Analytics tracking code, campaign name and source name are set" do
        @issue.stub!(:track?).and_return(true)
        @issue.stub!(:tracking_campaign).and_return("Test campaign")
        @issue.stub!(:tracking_source).and_return("Test source")
        @issue.newsletter.site.stub!(:google_analytics_tracking_code).and_return("GA-123456")

        @issue.should have_tracking_enabled
      end

      it "has tracking disabled if it should not be tracked" do
        @issue.stub!(:track?).and_return(false)
        @issue.stub!(:tracking_campaign).and_return("Test campaign")
        @issue.stub!(:tracking_source).and_return("Test source")
        @issue.newsletter.site.stub!(:google_analytics_tracking_code).and_return("GA-123456")

        @issue.should_not have_tracking_enabled
      end

      it "has tracking disabled if Google Analytics tracking code is missing" do
        @issue.stub!(:track?).and_return(true)
        @issue.stub!(:tracking_campaign).and_return("Test campaign")
        @issue.stub!(:tracking_source).and_return("Test source")
        @issue.newsletter.site.stub!(:google_analytics_tracking_code).and_return(nil)

        @issue.should_not have_tracking_enabled
      end

      it "has tracking disabled if campaign name is missing" do
        @issue.stub!(:track?).and_return(true)
        @issue.stub!(:tracking_campaign).and_return(nil)
        @issue.stub!(:tracking_source).and_return("Test source")
        @issue.newsletter.site.stub!(:google_analytics_tracking_code).and_return("GA-123456")

        @issue.should_not have_tracking_enabled
      end

      it "has tracking disabled if source name is missing" do
        @issue.stub!(:track?).and_return(true)
        @issue.stub!(:tracking_campaign).and_return("Test campaign")
        @issue.stub!(:tracking_source).and_return(nil)
        @issue.newsletter.site.stub!(:google_analytics_tracking_code).and_return("GA-123456")

        @issue.should_not have_tracking_enabled
      end
    end

    describe "#body_html" do
      before(:each) do
        @issue.stub!(:tracking_campaign).and_return("test-campaign")
        @issue.stub!(:tracking_source).and_return("test-source")
        @issue.body = '<a href="http://www.example.com/newest-products.html?order=date">View our newest products</a>'
        @issue.save
      end

      it "tracks URLs if tracking is enabled" do
        @issue.stub!(:has_tracking_enabled?).and_return(true)

        @issue.body_html.should == '<a href="http://www.example.com/newest-products.html?order=date&utm_medium=newsletter&utm_campaign=test-campaign&utm_source=test-source">View our newest products</a>'
      end

      it "does not track URLs if tracking is disabled" do
        @issue.stub!(:has_tracking_enabled?).and_return(false)

        @issue.body_html.should == '<a href="http://www.example.com/newest-products.html?order=date">View our newest products</a>'
      end
    end
  end

  describe "deliver" do
    it "should call deliver_all when no arguments given" do
      @issue.should_receive(:deliver_all)
      @issue.deliver
    end

    it "should call deliver_all with datetime" do
      time = DateTime.now
      @issue.should_receive(:deliver_all).with(time)
      @issue.deliver :later_at => time
    end

    it "should call deliver_to" do
      @issue.should_receive(:deliver_to)
      @issue.deliver :to => @user
    end 

    it "should change state to queued when deliver to all" do
      @issue.published_state!
      @issue.deliver
      @issue.queued?.should == true
    end
    
    it "should not change state to queued when deliver to user" do
      @issue.published_state!
      @issue.deliver :to => @user
      @issue.published?.should == true
    end

    after do
      remove_all_test_cronjobs
    end
  end
  
  describe "deliver_all" do
    it "should create cronjob" do
      @issue.cronjob.should == nil
      @issue.published_state!
      @issue.deliver_all
      @issue.cronjob.class.should == Cronjob
      @issue.cronjob.cronable_id.should == 1
    end
    
    it "should change to queued state" do
      @issue.published_state!
      @issue.deliver_all
      @issue.state.should == "queued"
    end
    
    it "should return nil when state is already queued" do
      @issue.queued_state!
      @issue.deliver_all.should == nil
    end
  end
  
  describe "cancel_delivery" do
    before :each do
      @issue.published_state!
      @issue.deliver
      @return = @issue.cancel_delivery
    end

    it "should return true" do
      @return.should == true
    end

    it "should remove cronjob" do
      @issue.cronjob.should == nil
    end
    
    it "should set published state" do
      @issue.published?.should == true
    end
    
    it "should return false when issue is delivered" do
      @issue.cancel_delivery.should == false
    end

    after do
      remove_all_test_cronjobs
    end
  end
end

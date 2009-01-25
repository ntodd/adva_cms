require File.expand_path(File.dirname(__FILE__) + "/../../test_helper")

class UserTest < ActiveSupport::TestCase
  def setup
    super
    @user = User.find_by_first_name('a user')
    @credentials = { :email => @user.email, :password => 'a password' }
    @valid_user_params = { :email => 'test@example.org', :password => 'test', :first_name => 'name' }
    # @time_now = Time.now
    # Time.zone.stub!(:now).and_return @time_now
  end

  test 'acts as authenticated user' do
    # FIXME implement matcher
    # User.should act_as_authenticated_user
  end
  
  # ASSOCIATIONS

  test "has many sites" do
    @user.should have_many(:sites)
  end

  test "has many memberships" do
    @user.should have_many(:memberships)
  end

  test "has many roles" do
    @user.should have_many(:roles)
  end

  # the roles association

  # stub_scenario :user_having_several_roles

  # test 'roles.by_site returns all superuser, site and section roles for the given user' do
  #   roles = @user.roles.by_site(@site)
  #   roles.map(&:type).should == ['Rbac::Role::Superuser', 'Rbac::Role::Admin', 'Rbac::Role::Moderator']
  # end
  # 
  # test 'roles.by_context returns all roles by_site for the given object' do
  #   roles = @user.roles.by_context(@site)
  #   roles.map(&:type).should == ['Rbac::Role::Superuser', 'Rbac::Role::Admin', 'Rbac::Role::Moderator']
  # end
  # 
  # test 'roles.by_context adds the implicit roles for the given object if it has any' do
  #   @topic.stub!(:implicit_roles).and_return [@comment_author_role]
  #   roles = @user.roles.by_context(@topic)
  #   roles.map(&:type).should == ['Rbac::Role::Superuser', 'Rbac::Role::Admin', 'Rbac::Role::Moderator', 'Rbac::Role::Author']
  # end
  # 
  # VALIDATIONS
  
  test "validates the presence of a first name" do
    @user.should validate_presence_of(:first_name)
  end
  
  test "validates the presence of an email adress" do
    @user.should validate_presence_of(:email)
  end
  
  test "validates the uniqueness of the email" do
    @user.should validate_uniqueness_of(:email)
  end
  
  test "validates the presence of a password if the password is required" do
    # FIXME implement matcher: stub method returning true
    # @user.should validate_presence_of(:password, :if => :password_required?)
  end
  
  test "validates the length of the last name" do
    # FIXME implement matcher
    # @user.should validate_length_of(:last_name, :within => 0..40)
  end
  
  test "creates a user with blank last name" do
    @user.last_name = ''
    @user.save.should be_true
  end
  
  test "validates the length of the first name" do
    # FIXME implement matcher
    # @user.should validate_length_of(:first_name, :within => 1..40)
  end
  
  test "validates the length of the password" do
    # FIXME implement matcher
    # @user.should validate_length_of(:password, :within => 4..40)
  end
  
  # # CLASS METHODS
  #   # before :each do
  #   #   User.stub!(:find_by_email).and_return @user
  #   #   @credentials = {:email => 'email@email.org', :password => 'password'}
  #   # end
  # 
  test 'User.authenticate returns the user if user#authenticate succeeds' do
    User.authenticate(@credentials).should == @user
  end
  
  test 'User.authenticate returns false if user#authenticate fails' do
    @credentials[:email] = 'does_not_exist@email.org'
    User.authenticate(@credentials).should be_false
  end
  
  test 'User.authenticate returns false if no user with the given email exists' do
    @credentials[:password] = 'wrong password'
    User.authenticate(@credentials).should be_false
  end
  
  test 'User.superusers returns all superusers' do
    superuser = User.find_by_first_name('a superuser')
    
    result = User.superusers
    result.should include(superuser)
    result.size.should == 1
  end
  
  # FIXME implement 
  test 'User.admins_and_superusers returns all site admins and superusers' do
    admin = User.find_by_first_name('an admin')
    superuser = User.find_by_first_name('a superuser')
    
    result = User.admins_and_superusers
    result.should include(admin)
    result.should include(superuser)
    result.size.should == 2
  end
    
  # User.create_superuser
  test 'User.create_superuser defaults :first_name to the name part of the email' do
    user = User.create_superuser(:email => 'first.name@example.com')
    user.first_name == 'first.name'
  end
  
  test 'User.create_superuser uses default values for email and password' do
    user = User.create_superuser(:email => nil, :password => nil, :first_name => nil)
    user.email.should == 'admin@example.org'
    user.password.should == 'admin'
  end
  
  test 'User.create_superuser uses params values if given' do
    user = User.create_superuser(@valid_user_params)
    user.email.should == 'test@example.org'
    user.password.should == 'test'
    user.first_name == 'name'
  end
  
  test 'User.create_superuser verifies the user' do
    user = User.create_superuser(@valid_user_params)
    user.verified?.should be_true
  end
  
  test 'User.create_superuser saves the user' do
    user = User.create_superuser(@valid_user_params)
    user.new_record?.should be_false
  end
  
  test 'assigns the password hash' do
    user = User.create_superuser(@valid_user_params)
    user.password_hash.should_not be_blank
    user.password_salt.should_not be_blank
  end

  test 'makes the new user a superuser' do
    user = User.create_superuser(@valid_user_params)
    user.has_role?(:superuser).should be_true
  end

  # User.by_context_and_role
  test "User.by_context_and_role finds all superusers" do
    users = User.by_context_and_role(nil, :superuser)
    users.size.should == 1
  end

  test "User.by_context_and_role finds all admins of a given site" do
    site = Site.find_by_name('site with blog')
    users = User.by_context_and_role(site, :admin)
    users.size.should == 1
  end
  
  # INSTANCE METHODS
  
  test '#attributes= calls update_roles if attributes have a :roles key' do
    mock(@user).update_roles(anything)
    @user.attributes= {:roles => 'roles'}
  end
  
  test '#verify! sets the verified_at timestamp and saves the user' do
    @user.update_attributes :verified_at => nil
    @user.verify!
    @user.reload.verified_at.should_not be_nil
  end
  
  # test '#restore! restores the user record' do
  #   @user.deleted_at = @time_now
  #   @user.should_receive(:update_attributes).with :deleted_at => nil
  #   @user.restore!
  # end

  test '#anonymous? returns true when anonymous is true' do
    User.new(:anonymous => true).anonymous?.should be_true
    User.new.anonymous?.should be_false
  end
  
  # registered?
  test '#registered? returns true when the record is not new' do
    @user.registered?.should be_true
    User.new.registered?.should be_false
  end
  
  test '#to_s returns the name' do # FIXME hu? where's that used?
    @user.to_s.should == @user.name
  end
  
  test "#homepage returns the http://homepage is homepage is set to 'homepage'" do
    @user.homepage ='homepage'
    @user.homepage.should == 'http://homepage'
  end
  
  test "#homepage returns the http://homepage is homepage is set to 'http://homepage'" do
    @user.homepage ='http://homepage'
    @user.homepage.should == 'http://homepage'
  end
  
  test "#homepage returns nil if homepage is not set" do
    @user.homepage.should be_nil
  end
  
  def role_attributes
    { "0" => { "type" => "Rbac::Role::Superuser", "selected" => "1" },
      "1" => { "type" => "Rbac::Role::Admin", "context_id" => Site.first.id, "context_type" => "Site", "selected" => "1" } }
  end

  test 'clears existing roles' do
    mock(@user.roles).clear
    @user.update_roles role_attributes
  end

  test 'creates new roles from the given attributes' do
    @user.roles.should be_empty
    
    @user.update_roles role_attributes
    @user.roles(true).size.should == 2
  end

  test 'ignores parameters that do not have the :selected flag set' do
    @user.roles.should be_empty

    attributes = role_attributes
    attributes['0']['selected'] = '0'
    @user.update_roles attributes
    
    @user.roles(true).size.should == 1
  end
end

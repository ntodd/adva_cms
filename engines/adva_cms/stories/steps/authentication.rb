factories :user

steps_for :authentication do
  Given "the user is logged in" do
    Given "a user"
    @user.verify!
    post "/session", :user => {:email => @user.email, :password => 'password'}
    controller.authenticated?.should be_true
  end

  Given "the user is logged in as $role" do |role|
    User.delete_all
    @user = create_user :name => role, :email => "#{role}@email.org"
    case role.to_sym
    when :admin
      @site ||= Site.find(:first) || create_site
      @site.users << @user
      @user.roles << Rbac::Role.build(role.to_sym, :context => @site)
    else
      @user.roles << Rbac::Role.build(role.to_sym)
    end
    @user.verify!

    post "/session", :user => {:email => @user.email, :password => @user.password}
    controller.authenticated?.should be_true
  end

  Given "a verified user" do
    Given "a user"
    @user.verify!
  end

  Given "an unverified user" do
    Given "a user"
    @user.update_attributes! :verified_at => nil
  end

  When "the user goes to the login page" do
    get login_path
  end

  When "the user goes to the user registration page" do
    get new_user_path
  end

  When "the user fills in the login form with valid credentials" do
    fill_in :email, :with => 'email@email.org'
    fill_in :password, :with => 'password'
  end

  When "the user fills in the login form with invalid credentials" do
    fill_in :email, :with => 'invalid-email@email.org'
    fill_in :password, :with => 'invalid password'
  end

  When "the user fills in the user registration form with valid values" do
    fill_in :"first name", :with => 'first name'
    fill_in :"last name", :with => 'last name'
    fill_in :email, :with => 'email@email.org'
    fill_in :password, :with => 'password'
  end

  When "the user verifies their account" do
    token = @user.assign_token! 'verify'
    AccountController.hidden_actions.delete 'verify'
    AccountController.instance_variable_set(:@action_methods, nil) # WTF ...
    get "/account/verify?token=#{@user.id}%3B#{token}"
    @user = controller.current_user
  end

  Then "the user is verified" do
    @user.should be_verified
  end

  Then "an unverified user exists" do
    @user = User.find(:first)
    @user.verified?.should be_false
  end

  Then "the page has a login form" do
    response.should have_form_posting_to(session_path)
  end

  Then "the page has a user registration form" do
    response.should have_form_posting_to(user_path)
  end

  Then "the system authenticates the user" do
    controller.current_user.should == @user
  end

  Then "the system does not authenticate the user" do
    controller.current_user.should be_nil
  end

  Then "the system authenticates the user as a known anonymous" do
    controller.current_user.should == @anonymous
  end

  Then "the anonymous id is saved to a cookie" do
    cookies['aid'].should == @anonymous.id.to_s
  end

  Then "the system authenticates the user as $role" do |role|
    Then "the system authenticates the user"
    @user.has_role?(role.to_sym).should be_true
  end

  Then "a verification email is sent to the user's email address" do
    ActionMailer::Base.deliveries.first.should_not be_nil
  end

  Then "the user sees the login page" do
    request.request_uri.should =~ /^#{login_path}/
    response.should render_template('session/new')
  end
end

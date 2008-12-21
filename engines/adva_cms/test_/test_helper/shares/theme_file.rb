class Test::Unit::TestCase
  def make_theme_template(theme)
    Theme::File.create theme, valid_theme_template_params
  end

  def valid_theme_template_params
    { :localpath  => 'template.html.erb',
      :data       => 'the template' }
  end

  share :valid_theme_template_params do
    before do
      @params = { :file => valid_theme_template_params }
    end
  end
  
  share :invalid_theme_template_params do
    before do
      @params = { :file => valid_theme_template_params.update(:localpath => 'invalid') }
    end
  end

  share :a_theme_template do
    before do 
      @site = Site.make
      @theme = make_theme(@site)
      @file = make_theme_template(@theme)
    end
  end
end
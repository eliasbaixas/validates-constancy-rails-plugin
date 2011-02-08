# Includes ConstancyValidation in ActiveRecord::Base.

Dir.glob(File.join(File.dirname(__FILE__),
         'validates_constancy',
         '*.rb')) do |filename|
  require filename
end

ActiveRecord::Base.class_eval { include ConstancyValidation }

I18n.load_path << File.dirname(__FILE__) + '/validates_constancy/locale/en.yml'

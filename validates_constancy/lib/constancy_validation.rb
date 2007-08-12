# When this module is included in ActiveRecord::Base, the validation method in
# ConstancyValidation::ClassMethods becomes available to all Active Record
# models.
module ConstancyValidation
  
  ActiveRecord::Errors.default_error_messages[:constancy] = "can't be changed"
  
  class OriginalAttributesCapture #:nodoc:
    
    class << self
      
      def extend(klass)
        unless create_method_after_find_with_original_attributes_capture(klass)
          return false
        end
        
        create_method_after_find_unless_exists klass
        klass.alias_method_chain :after_find, :original_attributes_capture
        
        true
      end
      
    private
      
      def create_method(klass, method_name, &block)
        klass.send :define_method, method_name, &block
      end
      
      def create_method_after_find_unless_exists(klass)
        # ActiveRecord does not define Base#after_find � it gets called
        # dynamically if present. So we need to define a do-nothing method to
        # serve as the head of the method chain.
        unless klass.method_defined?(:after_find)
          create_method(klass, :after_find) { self }
        end
      end
      
      def create_method_after_find_with_original_attributes_capture(klass)
        if klass.method_defined?(:after_find_with_original_attributes_capture)
          return false
        end
        
        create_method(klass, :after_find_with_original_attributes_capture) do
          after_find_without_original_attributes_capture
          
          constant_names = self.class.instance_variable_get(:@constant_attribute_names)
          originals = constant_names.inject({}) do |result, attribute_name|
            result[attribute_name] = read_attribute(attribute_name)
            result
          end
          instance_variable_set :@original_attributes, originals
          
          self
        end
        
        true
      end
      
    end
    
  end
  
  # The following validation is defined in the class scope of the model that
  # you're interested in validating. It offers a declarative way of specifying
  # when the model is valid and when it is not.
  module ClassMethods
    
    # Encapsulates the pattern of wanting to protect one or more model
    # attributes from being changed after the model object is created. Example:
    # 
    #   class Person < ActiveRecord::Base
    #     
    #     # Prevent changes to Person#user_name and Person#member_since.
    #     validates_constancy_of :user_name, :member_since
    #     
    #   end
    # 
    # This check is performed only on update.
    # 
    # Configuration options:
    # 
    # [<tt>:message</tt>] A custom error message (default is: �can�t be changed�)
    # [<tt>:if</tt>] Specifies a method, Proc or string to call to determine if the validation should occur (e.g., <tt>:if => :allow_validation</tt>, or <tt>:if => Proc.new { |user| user.signup_step > 2 }</tt>). The method, Proc or string should return or evaluate to +true+ or +false+.
    # 
    # Warning: With associations, validate the constancy of a foreign key, not
    # the instance variable itself: <tt>validates_constancy_of :invoice_id</tt>
    # instead of <tt>validates_constancy_of :invoice</tt>.
    def validates_constancy_of(*attribute_names)
      options = {:message =>
                 ActiveRecord::Errors.default_error_messages[:constancy]}
      options.merge!(attribute_names.pop) if attribute_names.last.kind_of?(Hash)
      
      (@constant_attribute_names ||= []).concat attribute_names.collect!(&:to_s)
      
      ConstancyValidation::OriginalAttributesCapture.extend self
      
      options.merge! :on => :update
      validates_each(attribute_names, options) do |record, attribute_name, value|
        unless value ==
               record.instance_variable_get(:@original_attributes)[attribute_name]
          record.errors.add attribute_name, options[:message]
        end
      end
      
      self
    end
    
  end
  
  #:nodoc:
  def self.included(other_module)
    other_module.extend ClassMethods
  end
  
end

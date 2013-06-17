actions :add, :delete, :update
default_action :add

attribute :name, :name_attribute => true, :kind_of => String, :required => true
attribute :password, :kind_of => String, :required => true
attribute :database, :kind_of => String, :required => true

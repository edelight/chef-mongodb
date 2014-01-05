require_relative 'instance'

class Chef
  class Resource::MongodbMongodInstance < Resource::MongodbInstance
  end
  class Provider::MongodbMongodInstance < Provider::MongodbInstance
  end
end

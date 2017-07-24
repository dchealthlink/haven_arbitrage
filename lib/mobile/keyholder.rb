require_relative 'constants'
require_relative 'base'

# holds a set of primary keys for a DB input table row
# and is capable of reading them from a chunk of parsed JSON
class KeyHolder < Base

  attr_accessor :finapp_id
  attr_accessor :personid
  attr_accessor :id 
  attr_accessor :type
  attr_accessor :tbd

  def read(entity)
    self.clone.tap do |o|
      KEY_SETTERS.each do |key, fields|
        fields.each do |f|  
          o.instance_variable_set(key, entity.delete(f)) if entity[f]
        end
      end
    end
  end

end
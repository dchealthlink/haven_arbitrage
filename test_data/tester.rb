require 'json'
require 'yaml'

KEY_SETTERS = {
        :'@finapp_id' =>   ["eaid"],
        :'@personid'  =>   ["eapersonid"],
        :'@id'        =>   ["insuranceid", "incomeid", "tax_no", "cross_personid"],
        :'@type'      =>   ["addresstype", "insurancetype", "incometype", "  emailtype" , "numbertype"]
    }


class Base
  def initialize args={}
    args.each do |k, v|
      instance_variable_set("@#{k}", v) unless v.nil?
    end
  end
end

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
          o.instance_variable_set(key, entity[f]) if entity[f]
        end
      end
    end
  end

end

class FieldValue < Base

  attr_accessor :keyholder
  attr_accessor :tablename
  attr_accessor :field
  attr_accessor :value

  def to_pipe_delimited 
  [ @keyholder.finapp_id,
    @tablename,
    @keyholder.personid,
    @keyholder.id,
    @keyholder.type,
    @keyholder.tbd,
    @field,
    @value ].join("|") + "|]"
  end
end

def transform(json, entity_name, keyholder)
  begin 
    is_lowercased = ->(name) { /^[a-z]/ =~ name }
  end

  kh = keyholder.read(json)
  fields, arrays = json.partition {|k, v| is_lowercased.call(k) }

  fieldvalues = fields.map do |k, v|
    FieldValue.new(keyholder: kh, 
                   tablename: entity_name,
                   field: k,
                   value: v
      )
  end

  arrays.each do |k, elems|
    elems.each do |elem|
      fieldvalues += transform elem, k, kh
    end
  end

  fieldvalues
end


fvs = transform(JSON.parse(ARGF.read), "Application", KeyHolder.new)
strs = fvs.map do |fv|
  fv.to_pipe_delimited
end

print strs.join("\n")

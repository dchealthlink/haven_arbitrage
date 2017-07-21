require 'json'
require_relative 'constants'
require_relative 'keyholder'
require_relative 'fieldvalue'


# Transform input JSON of the mobile type to the pipe delimited format 
# for insertion into the HAVEN input DB

class MobileJSONToPipeDelimited

  # determine which fields contain arrays 
  # the convention is that uppercase names mean arrays of subentities
  def is_subentity(name) 
  	/^[A-Z]/ =~ name
  end

  def tablename_for(entity_name)
  	TABLENAMES[entity_name.to_sym].tap do |tablename|
  		raise "Unknown entity #{entity_name}" unless tablename
  	end
  end

  def transform_entity(entity, entity_name, keyholder)
  
    # we inherit the primary keys of our parent entity, and
    # add to them whatever we find in the currently processed entity
    kh = keyholder.read(entity)

    # we map simple fields to FieldValue objects, and recurse into subentity arrays
    arrays, fields = entity.partition {|k, v| is_subentity(k) }
    fieldvalues = fields.map do |k, v|
      FieldValue.new(keyholder: kh, 
                     tablename: tablename_for(entity_name),
                     field: k,
                     value: v)
    end
    arrays.each do |k, elems|
      elems.each do |elem|
        fieldvalues += transform_entity elem, k, kh
      end
    end
  
    fieldvalues
  end
  
  #
  # takes a mobile JSON payload and returns a pair of 
  # finapp_id and pipe-delimited string payload 
  #
  def transform_payload(json)
    payload_in = JSON.parse(json)
    fieldvalues = transform_entity(payload_in,   "Application", KeyHolder.new)
    finapp_id = payload_in["eaid"]
    finapp_out = fieldvalues.map { |fv| fv.  to_pipe_delimited }.join "\n"
    [finapp_id, finapp_out]
  end

 end
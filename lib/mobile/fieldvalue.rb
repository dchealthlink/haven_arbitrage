require_relative 'base'


# represents a single field value from the mobile input JSON
# and knows how to write itself in the pipe-delimited output format
# for insertion into the HAVEN input database
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
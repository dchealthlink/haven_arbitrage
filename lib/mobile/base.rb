
# A handy base class to allow a dynamic constructor format that
# lets us set any of our attibutes
class Base
  def initialize args={}
    args.each do |k, v|
      instance_variable_set("@#{k}", v) unless v.nil?
    end
  end
end
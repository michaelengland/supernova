class Supernova::Condition
  attr_accessor :key, :type
  
  def initialize(key, type)
    self.key = key
    self.type = type
  end
  
  def ==(other)
    self.hash == other.hash
  end
  
  def eql?(other)
    self == other
  end
  
  def hash
    [type, key].hash
  end
  
  def solr_filter_for(value)
    case type
      when :not, :ne
        if value.nil?
          nil_filter
        else
          "!#{key}:#{value}"
        end
      when :gt
        "#{key}:{#{value} TO *}"
      when :gte
        "#{key}:[#{value} TO *]"
      when :lt
        "#{key}:{* TO #{value}}"
      when :lte
        "#{key}:[* TO #{value}]"
      when :nin
        value.is_a?(Range) ? "#{key}:{* TO #{value.first}} OR #{key}:{#{value.last} TO *}" : "!(#{or_key_and_value(value)})"
      when :in, :inside
        or_key_and_value(value)
    end
  end
  
  def nil_filter
    "#{key}:[* TO *]"
  end
  
  def or_key_and_value(values)
    if values.is_a?(Range)
      "#{key}:[#{values.first} TO #{values.last}]"
    elsif values.respond_to?(:ne) && values.respond_to?(:sw)
      "#{key}:#{type == :inside ? "{" : "["}#{values.sw.lat},#{values.sw.lng} TO #{values.ne.lat},#{values.ne.lng}#{type == :inside ? "}" : "]"}"
    elsif values.is_a?(Supernova::Circle)
      "{!geofilt}"
    else
      values.map { |v| v.nil? ? "!#{nil_filter}" : "#{key}:#{v}"}.join(" OR ")
    end
  end
end
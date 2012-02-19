def mkstruct(*args)
  klass = Struct.new(*args)
  klass.class_eval do
    def to_s
      self.class.to_s + "[" + each_pair.collect {|k,v| "#{k}=#{v.inspect}"}.join(",") + "]"
    end
    def inspect
      self.to_s
    end
    def pretty_inspect
      self.to_s
    end
    def pretty_print_inspect
      self.to_s
    end
    def pretty_print(io)
      io.text(self.to_s)
    end
  end
  return klass
end

Delete = mkstruct(:klass, :element_id)
Redact = mkstruct(:klass, :element_id, :version, :mode)
Edit = mkstruct(:obj)

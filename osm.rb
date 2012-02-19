module OSM

  module Taggable
    attr_accessor :tags
    private
    def init_tags(tags)
      @tags = tags
    end
  end

  module Element
    attr_accessor :element_id, :changeset_id, :timestamp, :visible, :version
    private
    def init_attrs(attrs)
      @element_id = attrs[:id]
      @changeset_id = attrs[:changeset]
      @timestamp = attrs[:timestamp]
      @visible = attrs[:visible] || false
      @version = attrs[:version]
    end

    def self.parse_options(options)
      groups = options.group_by {|k, v| k.instance_of? String and v.instance_of? String}
      tags = groups[true].nil? ? Hash.new : Hash[groups[true]]
      attrs = groups[false].nil? ? Hash.new : Hash[groups[false]]
      return tags, attrs
    end

    def compare(o, arg, *args)
      cmp = self.send(arg) <=> o.send(arg)
      if cmp != 0 or args.empty?
        cmp
      else
        compare(o, *args)
      end
    end
  end

  class Node
    include Taggable, Element, Comparable

    attr_accessor :position

    def self.[](pos, options = {})
      tags, attrs = Element.parse_options(options)
      Node.new(attrs, pos, tags)
    end

    def <=>(o)
      compare(o, :position, :tags, :element_id, :changeset_id, :timestamp, :visible, :version)
    end

    def to_s
      self.class.to_s + "[" + 
        @position.inspect + "," + 
        [:element_id, :changeset_id, :timestamp, :visible, :version].collect {|attr| "#{attr.inspect}=>#{self.send(attr)}"}.join(",") + "," + 
        @tags.to_a.collect {|k,v| "#{k.inspect}=>#{v.inspect}"}.join(",") + "]"
    end

    private
    def initialize(attrs, pos, tags)
      @position = pos
      init_attrs(attrs)
      init_tags(tags)
    end
  end
end

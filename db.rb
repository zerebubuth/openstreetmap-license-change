require './osm'

class DB
  # metaclass trick to define instance methods below in the
  # constructor.
  def metaclass; class << self; self; end; end

  #attr_reader :changesets, :nodes, :ways, :relations
  attr_accessor :edit_whitelist, :edit_blacklist

  def initialize(options = {})
    # define a set of accessors for changesets, nodes, ways and 
    # relations dynamically. this is a kinda stupid way to do
    # it, just saving a bit of typing.
    [:changesets, :nodes, :ways, :relations].each do |opt|
      non_plural_name = opt[0..-2]
      instance_name = "@#{opt}"
      hash = options.has_key?(opt) ? options[opt] : Hash.new

      self.instance_variable_set(instance_name, hash)
      metaclass.send(:define_method, non_plural_name) do |elt_id|
        self.instance_variable_get(instance_name)[elt_id]
      end
      metaclass.send(:define_method, 'each_' + non_plural_name) do |&block|
        self.instance_variable_get(instance_name).keys.each &block
      end
      metaclass.send(:define_method, 'current_' + non_plural_name) do |elt_id|
        self.instance_variable_get(instance_name)[elt_id].last
      end
    end

    @exclusions = Hash.new

    @edit_whitelist = Array.new
    @edit_blacklist = Array.new
  end

  def exclude(klass, ids)
    unless @exclusions.has_key? klass
      @exclusions[klass] = Set.new
    end

    ids.each { |i| @exclusions[klass].add(i) }
  end

  def exclude?(klass, i)
    @exclusions.has_key?(klass) && @exclusions[klass].include?(i)
  end

  def objects_using(klass, elt_id)
    references = Array.new

    # if it's nodes, add the ways too
    if klass == OSM::Node
      @ways.each do |k, v|
        # only use the current version...
        way = v.last

        references << way if way.nodes.include? elt_id
      end
    end

    # for all element types, try relations
    @relations.each do |k, v|
      rel = v.last

      references << rel if rel.members.any? {|m| m.type == klass && m.ref == elt_id}
    end

    return references
  end
end

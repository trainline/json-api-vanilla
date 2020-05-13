# Copyright © Trainline Limited, 2016. All rights reserved. See LICENSE.txt in the project root for license information.
require "json"

module JSON::Api; end
module JSON::Api::Vanilla
  class InvalidRootStructure < StandardError; end

  # Convert a String JSON API payload to vanilla Ruby objects.
  #
  # Example:
  #   >> json = IO.read("articles.json")  # From http://jsonapi.org
  #   >> doc = JSON::Api::Vanilla.parse(json)
  #   >> doc.data[0].comments[1].author.last_name
  #   => "Gebhardt"
  #
  # @param json [String] the JSON API payload.
  # @return [JSON::Api::Vanilla::Document] a wrapper for the objects.
  def self.parse(json)
    hash = JSON.parse(json)
    build(hash)
  end

  # Convert a ruby hash JSON API representation to vanilla Ruby objects.
  # Similar to .parse but takes hash as a parameter.
  #
  # Example:
  #   >> hash = { errors: [{ source: { pointer: "" }, detail:  "Missing `data` Member at document's top level." }]}
  #   >> doc = JSON::Api::Vanilla.build(hash)
  #   >> doc.errors.first["detail"]
  #   => "Missing `data` Member at document's top level."
  #
  # @param hash [Hash] parsed JSON API payload.
  # @return [JSON::Api::Vanilla::Document] a wrapper for the objects.
  def self.build(hash)
    naive_validate(hash)
    # Object storage.
    container = Module.new
    superclass = Class.new

    data_hash = hash['data']
    data_hash_array = if data_hash.is_a?(Array)
      data_hash
    else
      [data_hash].compact
    end
    obj_hashes = (hash['included'] || []) + data_hash_array
    errors = hash['errors']

    # Create all the objects.
    # Store them in the `objects` hash from [type, id] to the object.
    objects = {}
    links = {}  # Object links.
    rel_links = {}  # Relationship links.
    meta = {}  # Meta information.
    # Map from objects to map from keys to values, for use when two keys are
    # converted to the same ruby method identifier.
    original_keys = {}

    obj_hashes.each do |o_hash|
      klass = prepare_class(o_hash, superclass, container)
      obj = prepare_object(o_hash, klass, original_keys)

      if o_hash['links']
        links[obj] = o_hash['links']
      end

      objects[[obj.type, obj.id]] = obj
    end

    # Now that all objects have been created, we can link everything together.
    obj_hashes.each do |o_hash|
      obj = objects[[o_hash['type'], o_hash['id']]]
      if o_hash['relationships']
        o_hash['relationships'].each do |key, value|
          naive_validate_relationship_object(value)

          if value['data']
            data = value['data']
            if data.is_a?(Array)
              # One-to-many relationship.
              ref = data.map do |ref_hash|
                _ref = objects[[ref_hash['type'], ref_hash['id']]]

                if _ref.nil?
                  klass = prepare_class(ref_hash, superclass, container)
                  _ref = prepare_object(ref_hash, klass)
                end

                _ref
              end
            else
              ref = objects[[data['type'], data['id']]]

              if ref.nil?
                klass = prepare_class(data, superclass, container)
                ref = prepare_object(data, klass)
              end
            end
          end

          ref = ref || Object.new
          set_key(obj, key, ref, original_keys)

          rel_links[ref] = value['links']
          meta[ref] = value['meta']
        end
      end
    end

    # Create the main object.
    data = if data_hash.is_a?(Array)
      data_hash.map do |o_hash|
        objects[[o_hash['type'], o_hash['id']]]
      end
    elsif data_hash
      objects[[data_hash['type'], data_hash['id']]]
    end
    links[data] = hash['links']
    meta[data] = hash['meta']
    Document.new(data, links: links, rel_links: rel_links, meta: meta,
                 objects: objects, keys: original_keys, errors: errors,
                 container: container, superclass: superclass)
  end

  def self.prepare_class(hash, superclass, container)
    name = ruby_class_name(hash['type']).to_sym
    if container.constants.include?(name)
      klass = container.const_get(name)
    else
      klass = generate_object(name, superclass, container)
    end
    add_accessor(klass, 'id')
    add_accessor(klass, 'type')
    attr_keys = hash['attributes'] ? hash['attributes'].keys : []
    rel_keys = hash['relationships'] ? hash['relationships'].keys : []
    (attr_keys + rel_keys).each do |key|
      add_accessor(klass, key)
    end
    klass
  end

  def self.prepare_object(hash, klass, original_keys = {})
    (klass.new).tap do |obj|
      obj.type = hash['type']
      obj.id = hash['id']
      if hash['attributes']
        hash['attributes'].each do |key, value|
          set_key(obj, key, value, original_keys)
        end
      end
    end
  end

  def self.generate_object(ruby_name, superclass, container)
    klass = Class.new(superclass)
    container.const_set(ruby_name, klass)
    klass
  end

  def self.add_accessor(klass, name)
    ruby_name = ruby_ident_name(name)
    if !klass.method_defined?(ruby_name)
      klass.send(:attr_accessor, ruby_name)
    end
  end

  # Set a value to an object's key through its setter.
  # original_keys is a map from objects to a map from String keys to their
  # values.
  def self.set_key(obj, key, value, original_keys)
    ruby_key = ruby_ident_name(key)
    obj.send("#{ruby_key}=", value)
    original_keys[obj] ||= {}
    original_keys[obj][key] = value
  end

  # Convert a name String to a String that is a valid Ruby class name.
  def self.ruby_class_name(name)
    name.scan(/[a-zA-Z_][a-zA-Z_0-9]+/).map(&:capitalize).join
  end

  # Convert a name String to a String that is a valid snake-case Ruby
  # identifier.
  def self.ruby_ident_name(name)
    name.gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2')
       .gsub(/([a-z\d])([A-Z])/,'\1_\2')
       .tr("-", "_")
       .downcase
  end

  # Naïvely validate the top level document structure
  # @param hash [Hash] json:api document as a hash
  # @raise [InvalidRootStructure] raised if the document doesn't have
  # data, errors nor meta objects at its root.
  def self.naive_validate(hash)
    root_keys = %i(data errors meta)
    present_structures = root_keys & hash.keys.map(&:to_sym)
    if present_structures.empty?
      raise InvalidRootStructure.new("JSON:API document must contain at least one of these objects: #{root_keys.join(', ')}")
    end
  end

  # Naïvely validate a relationship object.
  # @param hash [Hash] json:api document as a hash
  # @raise [InvalidRootStructure] raised if the document doesn't have data, errors nor meta objects
  # at its root.
  def self.naive_validate_relationship_object(hash)
    root_keys = %i(data meta links)
    present_structures = root_keys & hash.keys.map(&:to_sym)
    if present_structures.empty?
      raise InvalidRootStructure.new("JSON:API relationship must contain at least one of these objects: #{root_keys.join(', ')}")
    end
  end

  class Document
    # @return [Object, Array<Object>] the content of the JSON API data.
    attr_reader :data
    # @return [Hash] a map from objects (obtained from .data) to their links,
    #   as a Hash.
    attr_reader :links
    # @return [Hash] a map from objects' relationships (obtained from .data)
    #   to the links defined in that relationship, as a Hash.
    attr_reader :rel_links
    # @return [Hash] a map from objects to their meta information (a Hash).
    attr_reader :meta
    # @return [Array] a list of errors, if any, otherwise nil.
    attr_reader :errors
    # @return [Hash] a map from objects to a Hash from their original field
    #   names (non-snake_case'd) to the corresponding object.
    attr_reader :keys
    attr_reader :container
    attr_reader :superclass
    def initialize(data, links: {}, rel_links: {}, meta: {},
                   keys: {}, objects: {}, errors: [],
                   container: Module.new, superclass: Class.new)
      @data = data
      @links = links
      @rel_links = rel_links
      @meta = meta
      @keys = keys
      @objects = objects
      @errors = errors
      @container = container
      @superclass = superclass
    end

    # Get a JSON API object.
    #
    # @param type [String] the type of the object we want returned.
    # @param id [String] its id.
    # @return [Object] the object with that type and id.
    def find(type, id)
      @objects[[type, id]]
    end

    # Get all JSON API objects of a given type.
    #
    # @param type [String] the type of the objects we want returned.
    # @return [Array<Object>] the list of objects with that type.
    def find_all(type)
      @objects.values.select { |obj| obj.type == type }
    end
  end
end

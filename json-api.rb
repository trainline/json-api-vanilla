# Copyright © Trainline.com Limited. All rights reserved. See LICENSE.txt in the project root for license information.
require "json"

module JsonApi
  def self.parse(json)
    hash = JSON.parse(json)

    # Object storage.
    container = Module.new
    superclass = Class.new

    data_hash = Array(hash['data'])
    obj_hashes = (hash['included'] || []) + data_hash

    # Create all the objects.
    # Store them in the `objects` hash from [type, id] to the object.
    objects = {}
    links = {}  # Object links.
    rel_links = {}  # Relationship links.
    # Map from objects to map from keys to values, for use when two keys are
    # converted to the same ruby method identifier.
    original_keys = {}

    obj_hashes.each do |o_hash|
      klass = self.prepare_class(o_hash, superclass, container)
      obj = klass.new
      obj.type = o_hash['type']
      obj.id = o_hash['id']
      if o_hash['attributes'] != nil
        o_hash['attributes'].each do |key, value|
          self.set_key(obj, key, value, original_keys)
        end
      end
      if o_hash['links'] != nil
        links[obj] = o_hash['links']
      end
      objects[[obj.type, obj.id]] = obj
    end

    # Now that all objects have been created, we can link everything together.
    obj_hashes.each do |o_hash|
      klass = container.const_get(self.ruby_class(o_hash['type']).to_sym)
      obj = objects[[o_hash['type'], o_hash['id']]]
      if o_hash['relationships'] != nil
        o_hash['relationships'].each do |key, value|
          if value['data'] != nil
            data = value['data']
            if data.is_a?(Array)
              # One-to-many relationship.
              ref = data.map do |ref_hash|
                objects[[ref_hash['type'], ref_hash['id']]]
              end
            else
              ref = objects[[data['type'], data['id']]]
            end
          end

          ref = ref || Object.new
          self.set_key(obj, key, ref, original_keys)

          if value['links'] != nil
            rel_links[ref] = value['links']
          end
        end
      end
    end

    # Create the main object.
    data = data_hash.map do |o_hash|
      objects[[o_hash['type'], o_hash['id']]]
    end
    links[data] = hash['links']
    Document.new(data, links: links, rel_links: rel_links,
                 objects: objects, keys: original_keys,
                 container: container, superclass: superclass)
  end

  def self.prepare_class(hash, superclass, container)
    name = self.ruby_class(hash['type']).to_sym
    if container.const_defined?(name)
      klass = container.const_get(name)
    else
      klass = self.generate_object(name, superclass, container)
    end
    self.add_method(klass, 'id')
    self.add_method(klass, 'type')
    attr_keys = (hash['attributes'] != nil) ? hash['attributes'].keys : []
    rel_keys = (hash['relationships'] != nil) ? hash['relationships'].keys : []
    (attr_keys + rel_keys).each do |key|
      self.add_method(klass, key)
    end
    klass
  end

  def self.generate_object(ruby_name, superclass, container)
    klass = Class.new(superclass)
    container.const_set(ruby_name, klass)
    klass
  end

  def self.add_method(klass, name)
    ruby_name = self.ruby_ident(name)
    if !klass.method_defined?(ruby_name)
      klass.send(:attr_accessor, ruby_name)
    end
  end

  # Set a value to an object's key through its setter.
  # original_keys is a map from objects to a map from String keys to their
  # values.
  def self.set_key(obj, key, value, original_keys)
    ruby_key = self.ruby_ident(key)
    obj.send("#{ruby_key}=", value)
    original_keys[obj] ||= {}
    original_keys[obj][key] = value
  end

  def self.ruby_class(key)
    key.scan(/[a-zA-Z_][a-zA-Z_0-9]+/).map(&:capitalize).join
  end

  def self.ruby_ident(key)
    s = self.ruby_class(key)
    # We convert the slice to string in case it is nil
    # (eg, the key has only one character).
    s[0].downcase + s.slice(1..-1).to_s
  end

  class Document
    attr_reader :data, :links, :rel_links, :keys, :container, :superclass
    def initialize(data, links: {}, rel_links: {}, keys: {}, objects: {},
                   container: Module.new, superclass: Class.new)
      @data = data
      @links = links
      @rel_links = rel_links
      @keys = keys
      @objects = objects
      @container = container
      @superclass = superclass
    end

    def find(type, id)
      @objects[[type, id]]
    end
  end
end

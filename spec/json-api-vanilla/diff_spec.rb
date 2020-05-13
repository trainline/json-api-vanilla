# Copyright © Trainline Limited, 2016. All rights reserved. See LICENSE.txt in the project root for license information.
require 'spec_helper'

describe JSON::Api::Vanilla do
  let(:doc) { JSON::Api::Vanilla.parse(IO.read("#{__dir__}/example.json")) }

  it "should cross arrays and fields of objects" do
    expect(doc.data[0].comments[1].author.last_name).to eql("Gebhardt")
  end

  it "should read relationship links" do
    expect(doc.rel_links[doc.data[0].comments]['related']).to eql("http://example.com/articles/1/comments")
  end

  it "should read object links" do
    expect(doc.links[doc.data[0].author]['self']).to eql("http://example.com/people/9")
  end

  it "should read links at the root" do
    expect(doc.links[doc.data]['self']).to eql("http://example.com/articles")
  end

  it "should read objects that are only in relationships of included" do
    expect(doc.data.first.comments.first.post.id).to eql("42")
  end

  it "should read objects that are only in relationships of included when it is an array" do
    expect(doc.data.first.comments.first.tags[0].id).to eql("42")
  end

  it "should find objects by type and id" do
    expect(doc.find('comments', '5').body).to eql("First!")
  end

  it "should find all objects given a type" do
    expect(doc.find_all('comments').size).to eql(2)
  end

  it "should give access to data through the original key" do
    expect(doc.keys[doc.find('people', '9')]['first-name']).to eql("Dan")
  end

  it "should give access to meta information" do
    expect(doc.meta[doc.data]['from']).to eql("http://jsonapi.org")
  end

  it "should support reference cycles" do
    json = <<-JSON
    {
      "data": {
        "type": "cycle",
        "id": "1",
        "relationships": { "cycle": { "data": { "type": "cycle", "id": "2" } } }
      },
      "included": [{
        "type": "cycle",
        "id": "2",
        "attributes": { "body": "content" },
        "relationships": { "cycle": { "data": { "type": "cycle", "id": "2" } } }
      }]
    }
    JSON
    doc = JSON::Api::Vanilla.parse(json)
    expect(doc.data.cycle.cycle.cycle.body).to eql("content")
  end

  it "should support errors when present" do
    json = <<-JSON
    {
      "errors": [{
        "status": "400",
        "detail": "JSON parse error - Expecting property name at line 1 column 2 (char 1)."
      }]
    }
    JSON
    doc = JSON::Api::Vanilla.parse(json)
    expect(doc.errors.size).to eql(1)
    expect(doc.errors.first["status"]).to eql("400")
    expect(doc.errors.first["detail"]).to eql("JSON parse error - Expecting property name at line 1 column 2 (char 1).")
  end

  it "should return nil for errors when there are no errors" do
    expect(doc.errors).to be_nil
  end

  it "should raise an error if the document does not contain required root elements" do
    json = <<-JSON
    {
      "jsonapi": { "version": "1" }
    }
    JSON
    expect do
      JSON::Api::Vanilla.parse(json)
    end.to raise_error(JSON::Api::Vanilla::InvalidRootStructure)
  end

  it "should raise an error if the document contains an unrecognized element" do
    json = <<-JSON
    {
      "type": "object",
      "id": "123",
      "attributes": {},
      "foo": "bar"
    }
    JSON
    expect do
      JSON::Api::Vanilla.parse(json)
    end.to raise_error(JSON::Api::Vanilla::InvalidRootStructure)
  end

  it "should raise an error if the document has a malformed link" do
    json = <<-JSON
    {
      "data": {
        "type": "cycle",
        "id": "1",
        "relationships": { "cycle": { "type": "cycle", "id": "2" } }
      }
    }
    JSON
    expect do
      JSON::Api::Vanilla.parse(json)
    end.to raise_error(JSON::Api::Vanilla::InvalidRootStructure)
  end

  it "should not raise any errors if the document contains root elements as symbols" do
    expect do
      JSON::Api::Vanilla.naive_validate(data: { id: 1, type: 'mvp' })
    end.to_not raise_error
  end

  it "should not raise any errors if the document contains an empty array for data" do
    expect do
      JSON::Api::Vanilla.naive_validate(data: [])
    end.to_not raise_error
  end

  describe '.prepare_class' do
    let(:container) {Module.new}
    let(:superclass) {Class.new}
    let(:hash) {{'type' => 'test-classes'}}
    subject {described_class.prepare_class(hash, superclass, container)}

    context 'when same name class in global scope' do
      class TestClasses
      end

      it 'should create dynamic class in container' do
        subject
        expect(container.constants).to include(:TestClasses)
      end
    end
  end

  describe '.prepare_object' do
    let(:data) do
      {
        'type' => 'example',
        'id' => '1',
        'attributes' => {
          'name' => 'example name'
        }
      }
    end
    let(:klass) { described_class.prepare_class(data, Class.new, Module.new) }
    subject { described_class.prepare_object(data, klass) }

    it 'creates an object with the attributes mapped' do
      expect(subject.type).to eql(data['type'])
      expect(subject.id).to eql(data['id'])
      expect(subject.name).to eql(data['attributes']['name'])
    end
  end
end

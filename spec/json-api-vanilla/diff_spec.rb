# Copyright © Trainline.com Limited. All rights reserved. See LICENSE.txt in the project root for license information.
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
end

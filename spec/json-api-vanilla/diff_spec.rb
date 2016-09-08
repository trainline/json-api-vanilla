# Copyright © Trainline.com Limited. All rights reserved. See LICENSE.txt in the project root for license information.
require 'spec_helper'

doc = JSON::Api::Vanilla.parse(IO.read("#{__dir__}/example.json"))

describe JSON::Api::Vanilla do
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
end

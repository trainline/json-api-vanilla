# JSON API *VANILLA*

Deserialize JSON API formats into *vanilla* Ruby objects.
The simplest JSON API library at all altitudes above Earth centre.

```ruby
# gem install json-api-vanilla
require "json-api-vanilla"
json = IO.read("articles.json")  # From http://jsonapi.org
doc = JSON::Api::Vanilla.parse(json)
doc.data[0].comments[1].author.last_name  # "Gebhardt"
```

Compare with [jsonapi](https://github.com/beauby/jsonapi):

```ruby
# gem install jsonapi --pre
require "jsonapi"
json = IO.read("articles.json")
doc = JSONAPI.parse(json)
comment_ref = doc.data[0].relationships.comments.data[1]
comment = doc.included.select do |obj|
  obj.type == comment_ref.type && obj.id == comment_ref.id
end[0]
author_ref = comment.relationships.author.data
author = doc.included.select do |obj|
  obj.type == author_ref.type && obj.id == author_ref.id
end[0]
author.attributes['last-name']
```

# Documentation

`JSON::Api::Vanilla.parse(json_string)` returns a document with the following
fields:

- `data` is an object corresponding to the JSON API's data object.
- `errors` is an array containing [errors](http://jsonapi.org/format/#error-objects). Each error is a Hash.
- `links` is a Hash from objects (obtained from `data`) to their links, as a
  Hash.
- `rel_links` is a Hash from objects' relationships (obtained from `data`) to
  the links defined in that relationship, as a Hash.
- `meta` is a Hash from objects to their meta information (a Hash).
- `find('type', 'id')` returns the object with that type and that id.
- `findAll('type')` returns an Array of all objects with that type.
- `keys` is a Hash from objects to a Hash from their original field names
  (non-snake\_case'd) to the corresponding object.

# License

Copyright © Trainline.com Limited. All rights reserved. See LICENSE.txt in the project root for license information.

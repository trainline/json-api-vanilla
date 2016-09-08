# Copyright © Trainline.com Limited. All rights reserved. See LICENSE.txt in the project root for license information.
require "./json-api.rb"

doc = JsonApi.parse(IO.read("./example.json"))
p doc.data[0].comments[1].author.lastName == "Gebhardt"
p doc.relLinks[doc.data[0].comments]['related'] == "http://example.com/articles/1/comments"
p doc.links[doc.data[0].author]['self'] == "http://example.com/people/9"
p doc.links[doc.data]['self'] == "http://example.com/articles"

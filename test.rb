# Copyright © Trainline.com Limited. All rights reserved. See LICENSE.txt in the project root for license information.
require "./json-api.rb"

doc = JsonApi.parse(IO.read("./example.json"))
p doc.data[0].comments[1].author.lastName == "Gebhardt"
p doc.links[doc.data[0].author]['related'] == "http://example.com/articles/1/author"

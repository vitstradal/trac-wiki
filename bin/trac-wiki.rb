#!/usr/bin/env ruby

require 'trac-wiki'

options = {}
wiki = ARGF.read;
print TracWiki.render(wiki, options)


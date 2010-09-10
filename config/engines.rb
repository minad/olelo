# Filter engine configuration engines.rb

################################################################################
#
# Register some simple regular expression filters which are used later
#
# Usage:
#   regexp :filter_name, /regex1/, 'replacement1', /regex2/, 'replacement2'
#
################################################################################

regexp :remove_comments, /<!--.*?-->/m,         ''
regexp :tag_shortcuts,   /\$\$(.*?)\$\$/m,      '<math display="inline">\1</math>',
                         /\\\((.*?)\\\)/m,      '<math display="inline">\1</math>',
                         /\\\[(.*?)\\\]/m,      '<math display="block">\1</math>',
                         /<<(.*?)(\|(.*?))?>>/, '<include page="\1" \3/>'
regexp :creole_nowiki,   /\{\{\{.*?\}\}\}/m,    '<notags>\0</notags>'
regexp :textile_nowiki,  /<pre>.*?<\/pre>/m,    '<notags>\0</notags>'

################################################################################
#
# Define filter output engines which process pages by sending them
# through multiple filters. DSL methods can be chained.
# Available filters are listed on the /system page.
#
# Example DSL usage:
#
# engine :engine_name do          # Create engine with name "engine_name"
#  is_cacheable                   # Engine supports caching (renders static content)
#  needs_layout                   # Engine needs a html layout around the generated content
#  has_priority 1                 # Engine has priority 1, lower priorities are preferred
#  accepts 'text/x-creole'        # Accepted mime types. This is a regular expression
#  mime    'text/html'            # Generated mime type. Only interesting for engines which don't need a layout.
#  filter do                      # Define filter chain
#    remove_comments              # First filter removes html comments <!--...-->. This filter is defined above.
#    tag_shortcuts                # Replace tag shortcuts with tags (e.g $$...$$ -> <math>...</math>, <<page>> -> <include page="page"/>)
#    creole_nowiki                # Replace creole nowiki tags with <notags> to disable tag interpretation (next filter)
#    tag do                       # Interpret wiki tags. Wiki tags are an extension to default wiki text
#      creole!                    # Transform creole to html
#      rubypants                  # Execute rubypants (e.g. replace ... with &hellip;)
#    end
#    toc                          # Auto-generate table of contents
#    link_classifier              # Classify links: Insert classes present for present pages, absent for absent pages, internal, external
#  end
# end
#
# tag filter options:
#   tag(:enable => 'html:*') Enable only html tags
#   tag(:disable => %w(html:* scripting:include)) Disable html tags and scripting:include
#   tag(:disable => 'html:*') Disable only html tags
#
################################################################################

interwiki_map = YAML.load_file(File.join(Config.config_path, 'interwiki.yml'))

################################################################################
# Creole engines configuration
################################################################################

engine :page do
  is_cacheable.needs_layout.has_priority(1)
  accepts 'text/x-creole'
  filter do
    editsection do
      remove_comments.tag_shortcuts
      creole_nowiki.tag { creole!.rubypants }
    end
    toc.interwiki(:map => interwiki_map).link_classifier
  end
end

engine :s5 do
  is_cacheable
  accepts 'text/x-creole'
  mime 'application/xhtml+xml; charset=utf-8'
  filter do
    remove_comments.tag_shortcuts
    creole_nowiki.tag { creole!.rubypants }
    toc.interwiki(:map => interwiki_map).link_classifier
    html_wrapper!.s5!
  end
end

engine :latex do
  is_cacheable
  accepts 'text/x-creole'
  mime 'text/plain; charset=utf-8'
  filter do
    remove_comments.tag_shortcuts
    creole_nowiki.tag { creole!.rubypants }
    toc.interwiki(:map => interwiki_map)
    html_wrapper!.xslt!(:stylesheet => 'xhtml2latex.xsl')
  end
end

################################################################################
# Textile engines configuration
################################################################################

engine :page do
  is_cacheable.needs_layout.has_priority(1)
  accepts 'text/x-textile'
  filter do
    remove_comments.tag_shortcuts
    textile_nowiki.tag { textile!.rubypants }
    toc.interwiki(:map => interwiki_map).link_classifier
  end
end

engine :s5 do
  is_cacheable
  accepts 'text/x-textile'
  mime 'application/xhtml+xml; charset=utf-8'
  filter do
    remove_comments.tag_shortcuts
    textile_nowiki.tag { textile!.rubypants }
    toc.interwiki(:map => interwiki_map).link_classifier
    html_wrapper!.s5!
  end
end

engine :latex do
  is_cacheable
  accepts 'text/x-textile'
  mime 'text/plain; charset=utf-8'
  filter do
    remove_comments.tag_shortcuts
    textile_nowiki.tag { textile!.rubypants }
    toc.interwiki(:map => interwiki_map)
    html_wrapper!.xslt!(:stylesheet => 'xhtml2latex.xsl')
  end
end

################################################################################
# Markdown engines configuration
################################################################################

engine :page do
  is_cacheable.needs_layout.has_priority(1)
  accepts 'text/x-markdown'
  filter do
    remove_comments.tag_shortcuts
    markdown_nowiki.tag { markdown! }
    toc.interwiki(:map => interwiki_map).link_classifier
  end
end

engine :s5 do
  is_cacheable
  accepts 'text/x-markdown'
  mime 'application/xhtml+xml; charset=utf-8'
  filter do
    remove_comments.tag_shortcuts
    markdown_nowiki.tag { markdown! }
    toc.interwiki(:map => interwiki_map).link_classifier
    html_wrapper!.s5!
  end
end

engine :latex do
  is_cacheable
  accepts 'text/x-markdown'
  mime 'text/plain; charset=utf-8'
  filter do
    remove_comments.tag_shortcuts
    markdown_nowiki.tag { markdown! }
    toc.interwiki(:map => interwiki_map)
    html_wrapper!.xslt!(:stylesheet => 'xhtml2latex.xsl')
  end
end

################################################################################
# Kramdown engines configuration
################################################################################

engine :page do
  is_cacheable.needs_layout.has_priority(2)
  accepts 'text/x-markdown'
  filter do
    remove_comments.tag_shortcuts
    markdown_nowiki.tag { kramdown! }
    toc.interwiki(:map => interwiki_map).link_classifier
  end
end

engine :s5 do
  is_cacheable
  accepts 'text/x-markdown'
  mime 'application/xhtml+xml; charset=utf-8'
  filter do
    remove_comments.tag_shortcuts
    markdown_nowiki.tag { kramdown! }
    toc.interwiki(:map => interwiki_map).link_classifier
    html_wrapper!.s5!
  end
end

engine :latex do
  is_cacheable
  accepts 'text/x-markdown'
  mime 'text/plain; charset=utf-8'
  filter do
    remove_comments.tag_shortcuts
    markdown_nowiki.tag { kramdown!(:latex => true) }
  end
end

################################################################################
# Maruku engines configuration
################################################################################

engine :page do
  is_cacheable.needs_layout.has_priority(3)
  accepts 'text/x-markdown'
  filter do
    remove_comments.tag_shortcuts
    markdown_nowiki.tag { maruku! }
    toc.interwiki(:map => interwiki_map).link_classifier
  end
end

engine :s5 do
  is_cacheable
  accepts 'text/x-markdown'
  mime 'application/xhtml+xml; charset=utf-8'
  filter do
    remove_comments.tag_shortcuts
    markdown_nowiki.tag { maruku! }
    toc.interwiki(:map => interwiki_map).link_classifier
    html_wrapper!.s5!
  end
end

engine :latex do
  is_cacheable
  accepts 'text/x-markdown'
  mime 'text/plain; charset=utf-8'
  filter do
    remove_comments.tag_shortcuts
    markdown_nowiki.tag { maruku! }
    toc.interwiki(:map => interwiki_map)
    html_wrapper!.xslt!(:stylesheet => 'xhtml2latex.xsl')
  end
end

################################################################################
# Mediawiki engines configuration
################################################################################

engine :page do
  is_cacheable.needs_layout.has_priority(1)
  accepts 'text/x-mediawiki'
  filter do
    remove_comments.tag_shortcuts
    tag { mediawiki!.rubypants }
    toc
  end
end

engine :s5 do
  is_cacheable
  accepts 'text/x-mediawiki'
  mime 'application/xhtml+xml; charset=utf-8'
  filter do
    remove_comments.tag_shortcuts
    tag { mediawiki!.rubypants }
    toc.html_wrapper!.s5!
  end
end

engine :latex do
  is_cacheable
  accepts 'text/x-mediawiki'
  mime 'text/plain; charset=utf-8'
  filter do
    remove_comments.tag_shortcuts
    tag { mediawiki!.rubypants }
    toc.html_wrapper!.xslt!(:stylesheet => 'xhtml2latex.xsl')
  end
end

################################################################################
# Orgmode engines configuration
################################################################################

#engine :page_rb do
engine :page do
  is_cacheable.needs_layout.has_priority(1)
  accepts 'text/x-orgmode'
  filter do
    remove_comments.tag_shortcuts
    tag { orgmode!.rubypants }
    toc.interwiki(:map => interwiki_map).link_classifier
  end
end

#engine :s5_rb do
engine :s5 do
  is_cacheable
  accepts 'text/x-orgmode'
  mime 'application/xhtml+xml; charset=utf-8'
  filter do
    remove_comments.tag_shortcuts
    tag { orgmode!.rubypants }
    toc.interwiki(:map => interwiki_map).link_classifier
    html_wrapper!.s5!
  end
end

#engine :latex_rb do
engine :latex do
  is_cacheable
  accepts 'text/x-orgmode'
  mime 'text/plain; charset=utf-8'
  filter do
    remove_comments.tag_shortcuts
    tag { orgmode!.rubypants }
    toc.interwiki(:map => interwiki_map)
    html_wrapper!.xslt!(:stylesheet => 'xhtml2latex.xsl')
  end
end

################################################################################
# Orgmode_emacs engines configuration
################################################################################
# Options
##########
# :export (string)
#   - sets export type, possible values: html, latex, pdf
# :infojs (bool)
#   - if set to false: sets #+INFOJS_OPT: view:showall ltoc:nil\n
# :include (string)
#   - by default #+INCLUDE filename is replaced to be relative to repository root if you have a non-bare repository
#   - if set to 'wiki': (this doesn't work atm, because the tag filter is turned off for now as the html_tags filter causes problems)
#       replaces #+INCLUDE lines to <include page="filename"/>
#       in this case you can include non-org pages as well, but it only works in html, in latex & pdf not
#
# Security
###########
# - source block options are filtered with s/[^\s\w:.-]//g (both #+begin_src options and src_foo[options]{...})
# - #+INCLUDE lines are filtered as described above

engine :page_emacs do
#engine :page do
#  is_cacheable.adds_title.needs_layout.has_priority(0)
  is_cacheable.needs_layout.adds_title.has_priority(1)
  accepts 'text/x-orgmode'
  filter do
    orgmode_emacs!(:export => 'html')
  end
end

engine :info_emacs do
#engine :info do
  is_cacheable.needs_layout.adds_title
  accepts 'text/x-orgmode'
  filter do
    orgmode_emacs!(:export => 'html', :infojs => true)
  end
end

engine :s5_emacs do
#engine :s5 do
  is_cacheable
  accepts 'text/x-orgmode'
  mime 'application/xhtml+xml; charset=utf-8'
  filter do
    orgmode_emacs!(:export => 'html')
    html_wrapper!.s5!
  end
end

engine :icalendar_emacs do
#engine :icalendar do
  is_cacheable
  accepts 'text/x-orgmode'
  mime 'text/calendar; charset=utf-8'
  download_ext 'ics'
  filter do
    orgmode_emacs!(:export => 'icalendar')
  end
end

engine :latex_emacs do
#engine :latex do
  is_cacheable
  accepts 'text/x-orgmode'
  mime 'application/x-latex; charset=utf-8'
  download_ext 'tex'
  filter do
    orgmode_emacs!(:export => 'latex')
  end
end

engine :pdf_emacs do
#engine :pdf do
  is_cacheable
  accepts 'text/x-orgmode'
  mime 'application/pdf; charset=utf-8'
  download_ext 'pdf'
  filter do
    orgmode_emacs!(:export => 'pdf')
  end
end

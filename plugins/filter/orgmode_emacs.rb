description  'Emacs org-mode filter (using emacs/emacsclient)'
dependencies 'engine/filter', 'utils/assets'
export_scripts 'orgmode_emacs/*.css', 'orgmode_emacs/*.js'

class Olelo::OrgMode
  def OrgMode.tempname
    "#{Time.now.to_i}-#{rand(0x100000000).to_s(36)}"
  end

  # filter content
  # TODO: check for other keywords that need to be filtered
  def OrgMode.filter_content(s, options)
    s = filter_src(s)
    if (options[:include] == 'wiki')
      #+INCLUDE: replace it with wiki include tag
      s.gsub(/^\s*#\+INCLUDE:?\s+(?:"(.+?)"|(\S+))(.*)$/i, '#+HTML: <include page="\1\2" \3/>')
    else
      #+INCLUDE: make file path relative to repository path
      # (this works only with non-bare repos, in case of bare repos the whole line is removed)
      repo = Config.repository[Config.repository.type]
      begin; path = repo.bare ? repo.path_non_bare : repo.path; rescue; end
      s.gsub(/^(\s*\#\+INCLUDE:?)\s+(?:"(.+?)"|(\S+))(.*)$/i) {|s|
        if path && File.directory?(path)
          file = File.join(path, File.expand_path("/#{$2}#{$3}"))
          file = File.join(file, 'content') if File.directory?(file)
          "#{$1} \"#{file}\"#{$4}"
        else; ''; end}
    end
  end

  # prevent absolute paths & command execution in code blocks
  # e.g. #+begin_src ditaa :file /tmp/foo; rm -rf /
  def OrgMode.filter_src(s)
    s.gsub(/(?: ^([ \t]*\#\+BEGIN_SRC)(.*)$ |
                ^((?:.*[ \f\t\r\v]|)src_\w+\[)(.*)(\]\{.*\}.*)$ )/ix) {|s|
      a = "#{$1}#{$3}"; m = "#{$2}#{$4}"; z = "#{$5}"
      "#+OLELO_FILTER_SRC: "+a+m+z+"\n" + a + m.gsub(/[^\s\w:.-]/, '') + z
    }
  end

  def OrgMode.unfilter_src(s)
    s.gsub(/^#\+OLELO_FILTER_SRC: (.*?)\n(.*?)$/mi, '\1')
  end

  def OrgMode.escape(s)
    s.gsub(/\\/,'\\\\').
      gsub(/"/,'\"')
  end

  def OrgMode.emacs(eval, ec_eval)
    load = "(load-file \"#{Config.config_path}/orgmode-init.el\")"
    if (Config.orgmode_emacs.use_emacsclient)
      cmd = Config.orgmode_emacs.emacsclient_cmd
      cmd += ['-e', "(progn #{load} #{eval} #{ec_eval})"]
    else
      cmd = Config.orgmode_emacs.emacs_cmd
      cmd += ['--batch', '--eval', "(progn #{load} #{eval})"]
    end
    Plugin.current.logger.info(cmd.join(' '))
    system *cmd
  end
end

Filter.create :orgmode_emacs do |context, content|
  begin
    uri = uri_saved = "/org/#{context.page.path}/"
    basename = OrgMode::tempname
    exts = ['org'] # list of generated extensions to clean up
    eval = ''      # lisp code to be executed in emacs

    if !context.params[:page_modified]
      dir = File.join(Config.tmp_path, 'org', context.page.path)
      # remove preview dirs, TODO: remove only old ones, maybe with cron+find?
      FileUtils.rm_rf(Dir.glob(File.join(Config.tmp_path, 'org-preview', "#{context.page.path}-*")))
    else
      page_path = "#{context.page.path}-#{OrgMode::tempname}"
      dir = File.join(Config.tmp_path, 'org-preview', page_path)
      uri = "/org-preview/#{page_path}/"
      # infojs does not work properly in preview mode
      eval += '(setq org-export-html-use-infojs nil)'
    end

    FileUtils.mkdir_p(dir)
    basepath = File.join(dir, basename)
    basepath_esc = OrgMode::escape(basepath)
    file = File.new(basepath+'.org', 'w')

    content = OrgMode::filter_content(content, @options)

    # default title, can be overridden in document
    opts = "#+TITLE: #{context.page.title}\n"
    if context.page.attributes['toc']
      opts += "#+OPTIONS: toc:t\n"
    end

    case @options[:export]
    when 'html'
      ext = 'html'
      eval += '(org-export-as-html-batch)'
      if !@options[:infojs]
        # if not in info view, apply showall view, overrides setting in document
        opts += "#+INFOJS_OPT: view:showall ltoc:nil\n"
      end
    when 'latex'
      ext = 'tex'
      eval += '(org-export-as-latex-batch)'
    when 'pdf'
      ext = 'pdf'
      exts += ['tex']
      eval += '(org-export-as-pdf org-export-headline-levels)'
    when 'docbook'
      ext = 'xml'
      eval += '(org-export-as-docbook-batch)'
    when 'docbook-pdf'
      ext = 'pdf'
      exts += ['xml', 'fo']
      eval += '(org-export-as-docbook-pdf)'
    when 'freemind'
      ext = 'mm'
      eval += '(org-export-as-freemind)'
    when 'icalendar'
      ext = 'ics'
      eval += '(org-export-icalendar-this-file)'
    when 'taskjuggler'
      ext = 'tjp'
      eval += '(org-export-as-taskjuggler)'
    when 'utf8'
      ext = 'txt'
      eval += '(org-export-as-utf8)'
    when 'xoxo'
      ext = 'html'
      eval += '(org-export-as-xoxo)'
    end

    file.write(opts + content)
    file.close

    ec_eval = ''
    exts.push(ext)
    exts.each {|e| ec_eval += "(kill-buffer (get-file-buffer \"#{basepath_esc}.#{e}\"))"}
    OrgMode::emacs("(find-file \"#{basepath_esc}.org\") #{eval}", ec_eval)

    raise "Error during export" unless File.exist?("#{basepath}.#{ext}")
    result = File.read("#{basepath}.#{ext}")

    case @options[:export]
    when 'html'
      # set appropriate image paths (different in preview & saved view)
      result.gsub!(/(<img.*?src=")(.*?)"/i) { |s|
        $1 + (File.exist?(File.join(Config.tmp_path, uri, $2)) ? uri : uri_saved) +
        $2 + "?#{Time.now.to_i}\""
      }
      result.gsub!(/.*(?:<meta.*?>)+(.*)<\/head>.*?<div id="content">(.*)<\/div>.*/mi, '\2\1')
    end
    result
  ensure
    exts.each{|e| File.unlink("#{basepath}.#{e}") if File.exist?("#{basepath}.#{e}")}
  end
end

class Olelo::Page
  # store sha1 hash of src blocks, so they're re-evaluted only when changed
  # see http://orgmode.org/org.html#cache
  before(:save, 9999) do
    begin
      dir = File.join(Config.tmp_path, 'org', @path)
      filename = OrgMode::tempname+'.org'
      filepath = File.join(dir, filename)
      filepath_esc = OrgMode::escape(filepath)

      FileUtils.mkdir_p(dir)
      file = File.new(filepath, 'w')
      file.write(OrgMode::filter_src(@content))
      file.close

      OrgMode::emacs("(find-file \"#{filepath_esc}\") (org-babel-execute-buffer) (save-buffer)", "(kill-buffer)")
      @content = OrgMode::unfilter_src(File.read(filepath))
    ensure
      File.unlink(filepath) if File.exist?(filepath)
    end
  end
end

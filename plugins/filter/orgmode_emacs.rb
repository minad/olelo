description  'Emacs org-mode filter (using emacs/emacsclient)'
dependencies 'engine/filter'

class Olelo::OrgMode
  def OrgMode.tempname
    "#{Time.now.to_i}-#{rand(0x100000000).to_s(36)}"
  end

  # prevent absolute paths & command execution e.g. #+begin_src ditaa :file /tmp/foo; rm -rf /
  # TODO: check for other keywords that need to be filtered
  def OrgMode.filter_content(content)
    content.gsub(/^(#\+BEGIN_SRC)(.*)$/i) {|s| "#+COMMENT: "+$1+$2+"\n" + $1+$2.gsub(/[^\s\w:.-]/, '')}
  end

  def OrgMode.unfilter_content(content)
    content.gsub(/^#\+COMMENT: (#\+BEGIN_SRC.*?)\n#\+BEGIN_SRC.*?$/mi, '\\1')
  end

  def OrgMode.escape(s)
    s.gsub(/\\/,'\\\\').gsub(/"/,'\"')
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
    exts = ['org']
    eval = ''

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

    content = OrgMode::filter_content(content)

    # default title, can be overridden in document
    opts = "#+TITLE: #{context.page.title}\n"
    if context.page.attributes['toc']
      opts += "#+OPTIONS: toc:t\n"
    end

    case @options[:export]
    when 'html'
      ext = 'html'
      exts += ['html']
      eval += '(org-export-as-html-batch)'
      if !@options[:infojs]
        # if not in info view, apply showall view, overrides setting in document
        opts += "#+INFOJS_OPT: view:showall ltoc:nil\n"
      end
    when 'latex'
      ext = 'tex'
      exts += ['tex']
      eval += '(org-export-as-latex-batch)'
    when 'pdf'
      ext = 'pdf'
      exts += ['tex', 'pdf']
      eval += '(org-export-as-pdf org-export-headline-levels)'
    end

    file.write(opts + content)
    file.close

    ec_eval = ''
    exts.each {|e| ec_eval += "(kill-buffer (get-file-buffer \"#{basepath_esc}.#{e}\"))"}
    OrgMode::emacs("(find-file \"#{basepath_esc}.org\") #{eval}", ec_eval)

    raise "Error during export" unless File.exist?("#{basepath}.#{ext}")
    result = File.read("#{basepath}.#{ext}")

    case @options[:export]
    when 'html'
      result.gsub!(/(<img.*?src=")(.*?)"/i) { |s|
        $1 + (File.exist?(File.join(Config.tmp_path, uri, $2)) ? uri : uri_saved) +
        $2 + "?#{Time.now.to_i}\""
      }
      result.gsub!(/.*((?:<style.*<\/style>.*?)?
                    (?:<link.*?>.*?)?
                    (?:<style.*<\/style>.*?)?
                    (?:<script.*<\/script>)).*?
                    <div\ id="content">(.*)<\/div>.*/mix,
                   '\\1\\2')
    end
    result
  ensure
    exts.each{|e| File.unlink("#{basepath}.#{e}") if File.exist?("#{basepath}.#{e}")}
  end
end

class Olelo::Page
  # cache results in source blocks before save
  before(:save, 9999) do |page|
    begin
      dir = File.join(Config.tmp_path, 'org', page.path)
      filename = OrgMode::tempname+'.org'
      filepath = File.join(dir, filename)
      filepath_esc = OrgMode::escape(filepath)

      FileUtils.mkdir_p(dir)
      file = File.new(filepath, 'w')
      file.write(OrgMode::filter_content(page.content))
      file.close

      OrgMode::emacs("(find-file \"#{filepath_esc}\") (org-babel-execute-buffer) (save-buffer)", "(kill-buffer)")
      page.content = OrgMode::unfilter_content(File.read(filepath))
    ensure
      File.unlink(filepath)
    end
  end
end

description  'Enhanced edit form with preview and diff'
dependencies 'engine/engine'

class Olelo::Application
  hook :layout do |name, doc|
    if name == :edit
      if @preview
        doc.css('#content .tabs').before Nokogiri::HTML::DocumentFragment.parse(%{<div class="preview">#{@preview}</div>})
      elsif @patch
        doc.css('#content .tabs').before Nokogiri::HTML::DocumentFragment.parse(@patch)
      end

      doc.css('#tab-edit button[type=submit]').before(
        Nokogiri::HTML::DocumentFragment.parse(%{<button type="submit" name="action" value="preview" accesskey="p">#{:preview.t}</button>
          <button type="submit" name="action" value="changes" accesskey="c">#{:changes.t}</button>}.unindent))
    end
  end

  def post_preview
    raise 'No content' if !params[:content]
    params[:content].gsub!("\r\n", "\n")

    if page.new? || !params[:pos]
      # Whole page edited, assign new content before engine search
      page.content = params[:content]
      engine = Engine.find(page, :layout => true)
    else
      # We assume that engine stays the same if section is edited
      engine = Engine.find(page, :layout => true)
      page.content = params[:content]
    end
    @preview = engine && engine.output(Context.new(:page => page))
    halt render(:edit)
  end

  def post_changes
    raise 'No content' if !params[:content]
    params[:content].gsub!("\r\n", "\n")

    original = Tempfile.new('original')
    original.write(params[:pos] ? page.content[params[:pos].to_i, params[:len].to_i] : page.content)
    original.close

    new = Tempfile.new('new')
    new.write(params[:content].to_s)
    new.close

    # Read in binary mode and fix encoding afterwards
    patch = IO.popen("diff -u '#{original.path}' '#{new.path}'", 'rb') {|io| io.read }
    patch.force_encoding(Encoding::UTF_8) if patch.respond_to? :force_encoding
    @patch = PatchParser.parse(patch, PatchFormatter.new).html

    halt render(:edit)
  end
end

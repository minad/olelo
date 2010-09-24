description 'Git repository backend'
require     'gitrb'
require 'extensions/string'

raise 'Newest gitrb version 0.2.7 is required. Please upgrade!' if !Gitrb.const_defined?('VERSION') || Gitrb::VERSION != '0.2.7'

class GitRepository < Repository
  def initialize(config)
    logger = Plugin.current.logger
    logger.info "Opening git repository: #{config.path}"
    @shared_git = Gitrb::Repository.new(:path => config.path, :create => true,
                                        :bare => config.bare, :logger => logger)
    @current_transaction = {}
    @git = {}
    @cfg = Config.repository.git
  end

  def content_path(path)
    path = @cfg.index_page if path == ''
    path + (@cfg.content_ext || '.page')
  end

  def attribute_path(path)
    path = @cfg.index_page if path == ''
    path =~ /(.*\/)?(.*)$/
    path = String($1) + @cfg.attribute_pre + $2 if @cfg.attribute_pre
    path + (@cfg.attribute_ext || '')
  end

  def git
    @git[Thread.current.object_id] ||= @shared_git.dup
  end

  def transaction(&block)
    raise 'Transaction already running' if @current_transaction[Thread.current.object_id]
    @current_transaction[Thread.current.object_id] = []
    git.transaction(&block)
  ensure
    @current_transaction.delete(Thread.current.object_id)
  end

  def commit(comment)
    user = User.current
    git.commit(comment, user && Gitrb::User.new(user.name, user.email))
    tree_version = commit_to_version(git.head)
    current_transaction.each {|f| f.call(tree_version) }
  end

  def find_page(path, tree_version, current)
    check_path(path)
    commit = !tree_version.blank? ? git.get_commit(tree_version.to_s) : git.head
    return nil if !commit
    object = commit.tree[path] || commit.tree[content_path(path)]
    return nil if !object
    Page.new(path, commit_to_version(commit), current)
  rescue
    nil
  end

  def find_version(version)
    commit_to_version(git.get_commit(version.to_s))
  rescue
    nil
  end

  def load_history(page, skip, limit)
    git.log(:max_count => limit, :skip => skip,
            :path => [page.path, attribute_path(page.path), content_path(page.path)]).map do |c|
      commit_to_version(c)
    end
  end

  def load_version(page)
    cnt_path = content_path(page.path)
    attr_path = attribute_path(page.path)
    commits = git.log(:max_count => 2, :start => page.tree_version, :path => [page.path, attr_path, cnt_path])

    child = nil
    git.git_rev_list('--reverse', '--remove-empty', "#{commits[0]}..", '--', page.path, attr_path, cnt_path) do |io|
      child = io.eof? ? nil : git.get_commit(git.set_encoding(io.readline).strip)
    end rescue nil # no error because pipe is closed intentionally

    [commits[1] ? commit_to_version(commits[1]) : nil, commit_to_version(commits[0]), child ? commit_to_version(child) : nil]
  end

  def load_children(page)
    object = git.get_commit(page.tree_version.to_s).tree[page.path]
    if object.type == :tree
      object.map do |name, child|
        page_name = name.gsub(/#{Regexp.escape(@cfg.content_ext)}$/, '')
        Page.new(page.path/page_name, page.tree_version, page.current?) if !reserved_name?(page_name, page.path)
      end.compact
    else
      []
    end
  end

  def load_content(page)
    tree = git.get_commit(page.tree_version.to_s).tree
    object = tree[content_path(page.path)]
    if object
      content = object.data
      # Try to force utf-8 encoding and revert to old encoding if this doesn't work
      content.respond_to?(:try_encoding) ? content.try_encoding(Encoding::UTF_8) : content
    else
      ''
    end
  end

  def load_attributes(page)
    object = git.get_commit(page.tree_version.to_s).tree[attribute_path(page.path)]
    object ? YAML.load(object.data) : {}
  end

  def save(page)
    check_path(page.path)

    content = page.content
    content = content.read if content.respond_to? :read
    attributes = page.attributes.empty? ? nil : YAML.dump(page.attributes).sub(/\A\-\-\-\s*\n/s, '')

    cnt_path = content_path(page.path);
    attr_path = attribute_path(page.path);

    if attributes
      git.root[attr_path] = Gitrb::Blob.new(:data => attributes)
    elsif git.root[attr_path]
      git.root.delete(attr_path)
    end
    git.root[content_path(page.path)] = Gitrb::Blob.new(:data => content)

    current_transaction << proc {|tree_version| page.committed(page.path, tree_version) }
  end

  def move(page, destination)
    check_path(destination)
    # what if destination already exists? we should add a check for that too
    #git.root.move(page.path, destination) # would this move the whole subtree if page.path is a tree? do we want that?
    git.root.move(content_path(page.path), content_path(destination)) if git.root[content_path(page.path)]
    git.root.move(attribute_path(page.path), attribute_path(destination)) if git.root[attribute_path(page.path)]
    current_transaction << proc {|tree_version| page.committed(destination, tree_version) }
  end

  def delete(page)
    git.root.delete(page.path)
    git.root.delete(content_path(page.path))
    git.root.delete(attribute_path(page.path))
    current_transaction << proc { page.committed(page.path, nil) }
  end

  def diff(page, from, to)
    diff = git.diff(:from => from && from.to_s, :to => to.to_s,
                    :path => [page.path, content_path(page.path), attribute_path(page.path)], :detect_renames => true)
    Olelo::Diff.new(diff.from && commit_to_version(diff.from), commit_to_version(diff.to), diff.patch)
  end

  def short_version(version)
    version[0..4]
  end

  def cleanup
    @git.delete(Thread.current.object_id)
  end

  def reserved_name?(name, path)
    name.ends_with?(@cfg.content_ext) ||
      (@cfg.attribute_pre != nil && name.starts_with?(@cfg.attribute_pre)) ||
      (@cfg.attribute_ext != nil && name.ends_with?(@cfg.attribute_ext)) ||
      (path == '' && name == @cfg.index_page)
  end

  private

  def check_path(path)
    raise :reserved_path.t if reserved_name?(File.basename(path), path)
  end

  def current_transaction
    @current_transaction[Thread.current.object_id] || raise('No transaction running')
  end

  def commit_to_version(commit)
    Olelo::Version.new(commit.id, Olelo::User.new(commit.author.name, commit.author.email),
                       commit.date, commit.message, commit.parents.map(&:id))
  end
end

Repository.register :git, GitRepository

Application.after(:request) do
  Repository.instance.cleanup if GitRepository === Repository.instance
end

description 'Git repository backend (Using rugged library)'
require 'rugged'
require 'fileutils'

class RuggedRepository < Repository
  CONTENT_EXT  = '.content'
  ATTRIBUTE_EXT = '.attributes'

  class Blob
    def initialize(git, content)
      @git = git
      @content = content
    end

    def type
      :blob
    end

    def filemode
      0100644
    end

    def save
      Rugged::Blob.create(@git, @content)
    end
  end

  class Reference
    attr_reader :filemode, :type

    def initialize(git, entry)
      @git = git
      @oid = entry[:oid]
      @filemode = entry[:filemode]
      @type = entry[:type]
    end

    def save
      @oid
    end

    def lookup
      if type == :tree
        Tree.new(@git, @oid)
      else
        self
      end
    end
  end

  class Tree
    def initialize(git, oid = nil)
      @git = git
      @entries = {}
      @oid = oid
      if oid
        tree = @git.lookup(oid)
        raise 'Not a tree' unless Rugged::Tree === tree
        tree.each {|entry| @entries[entry[:name].force_encoding(Encoding.default_external)] = Reference.new(@git, entry) }
      end
    end

    def empty?
      @entries.empty?
    end

    def type
      :tree
    end

    def filemode
      0040000
    end

    def get(name)
      child = @entries[name]
      Reference === child ? @entries[name] = child.lookup : child
    end

    def [](path)
      return self if path.blank?
      name, path = path.split('/', 2)
      child = get(name)
      if path && child
        raise 'Find child in blob' unless child.type == :tree
        child[path]
      else
        child
      end
    end

    def []=(path, object)
      raise 'Blank path' if path.blank?
      @oid = nil
      name, path = path.split('/', 2)
      child = get(name)
      if path
        child = @entries[name] = Tree.new(@git) unless child
        if child.type == :tree
          child[path] = object
        else
          raise 'Parent not found'
        end
      else
        @entries[name] = object
      end
    end

    def move(path, destination)
      self[destination] = delete(path)
    end

    def delete(path)
      raise 'Blank path' if path.blank?
      @oid = nil
      name, path = path.split('/', 2)
      child = get(name)
      if path
        if child.type == :tree
          child.delete(path)
        else
          raise 'Object not found'
        end
      else
        entry = @entries.delete(name)
        raise 'Object not found' unless entry
        entry
      end
    end

    def save
      return @oid if @oid
      builder = Rugged::Tree::Builder.new
      @entries.each do |name, entry|
        builder << { type: entry.type, filemode: entry.filemode, oid: entry.save, name: name }
      end
      builder.write(@git)
    end
  end

  class Transaction
    attr_reader :tree

    def initialize(git)
      @git = git
      @head = current_head
      @tree = Tree.new(@git, @head && @git.lookup(@head).tree_oid)
    end

    def commit(comment)
      raise 'Concurrent transactions' if @head != current_head

      user = User.current
      author = {email: user.email, name: user.name, time: Time.now }
      Rugged::Commit.create(@git,
                            author: author,
                            message: comment,
                            committer: author,
                            parents: [@head],
                            tree: @tree.save,
                            update_ref: 'HEAD')
    end

    private

    def current_head
      @git.head.target rescue nil
    end
  end

  def initialize(config)
    @git = Rugged::Repository.new(config[:path])
    Olelo.logger.info "Opening git repository: #{config[:path]}"
  rescue Rugged::Error
    Olelo.logger.info "Creating git repository: #{config[:path]}"
    FileUtils.mkpath(config[:path])
    @git = Rugged::Repository.init_at(config[:path], config[:bare])
  end

  def transaction
    raise 'Transaction already running' if Thread.current[:olelo_rugged_tx]
    Thread.current[:olelo_rugged_tx] = Transaction.new(@git)
    yield
  ensure
    Thread.current[:olelo_rugged_tx] = nil
  end

  def set_content(path, content)
    check_path(path)
    expand_tree(path)
    object = work_tree[path]
    if object && object.type == :tree
      if content.blank?
        work_tree.delete(path + CONTENT_EXT)
      else
        work_tree[path + CONTENT_EXT] = Blob.new(@git, content)
      end
      collapse_empty_tree(path)
    else
      work_tree[path] = Blob.new(@git, content)
    end
  end

  def set_attributes(path, attributes)
    check_path(path)
    attributes = attributes.blank? ? nil : YAML.dump(attributes).sub(/\A\-\-\-\s*\n/s, '')
    expand_tree(path)
    if attributes
      work_tree[path + ATTRIBUTE_EXT] = Blob.new(@git, attributes)
    else
      work_tree.delete(path + ATTRIBUTE_EXT) if work_tree[path + ATTRIBUTE_EXT]
    end
  end

  def move(path, destination)
    check_path(destination)
    work_tree.move(path, destination)
    work_tree.move(path + CONTENT_EXT, destination + CONTENT_EXT) if work_tree[path + CONTENT_EXT]
    work_tree.move(path + ATTRIBUTE_EXT, destination + ATTRIBUTE_EXT) if work_tree[path + ATTRIBUTE_EXT]
    collapse_empty_tree(path/'..')
  end

  def delete(path)
    check_path(path)
    work_tree.delete(path)
    work_tree.delete(path + CONTENT_EXT) if work_tree[path + CONTENT_EXT]
    work_tree.delete(path + ATTRIBUTE_EXT) if work_tree[path + ATTRIBUTE_EXT]
    collapse_empty_tree(path/'..')
  end

  def commit(comment)
    current_transaction.commit(comment)
    commit_to_version(@git.last_commit)
  end

  def path_etag(path, version)
    check_path(path)
    commit = @git.lookup(version.to_s)
    raise 'Not a commit' unless Rugged::Commit === commit
    if oid = oid_by_path(commit, path)
      [oid,
       oid_by_path(commit, path + CONTENT_EXT),
       oid_by_path(commit, path + ATTRIBUTE_EXT)].join('-')
    end
  end

  def get_version(version = nil)
    if version
      commit = @git.rev_parse(version.to_s) rescue nil
      commit_to_version(commit)
    else
      commit_to_version(@git.last_commit) rescue nil
    end
  end

  def get_history(path, skip, limit)
    check_path(path)

    commits = []
    walker = Rugged::Walker.new(@git)
    walker.sorting(Rugged::SORT_TOPO)
    walker.push(@git.head.target)
    walker.each do |c|
      if path_changed?(c, path)
        if skip > 0
          skip -= 1
        else
          commits << c
          break if commits.size >= limit
        end
      end
    end
    commits.map {|c| commit_to_version(c) }
  end

  def get_path_version(path, version)
    check_path(path)

    version ||= @git.head.target
    version = version.to_s

    commits = []
    walker = Rugged::Walker.new(@git)
    walker.sorting(Rugged::SORT_TOPO)
    walker.push(version)
    walker.each do |c|
      if path_changed?(c, path)
        commits << c
        break if commits.size == 2
      end
    end

    succ = nil
    if version != @git.head.target
      newer = nil
      walker.reset
      walker.sorting(Rugged::SORT_TOPO)
      walker.push(@git.head.target)
      walker.each do |c|
        if path_changed?(c, path)
          if c == commits[0]
            succ = newer
            break
          end
          newer = c
        end
      end
    end

    [commit_to_version(commits[1]), # previous version
     commit_to_version(commits[0]), # current version
     commit_to_version(succ)] # next version
  end

  def get_children(path, version)
    check_path(path)
    commit = @git.lookup(version.to_s)
    raise 'Not a commit' unless Rugged::Commit === commit
    object = object_by_path(commit, path)
    Rugged::Tree === object ? object.map do |e|
      e[:name].force_encoding(Encoding.default_external)
    end.reject {|name| reserved_name?(name) } : []
  end

  def get_content(path, version)
    check_path(path)
    commit = @git.lookup(version.to_s)
    raise 'Not a commit' unless Rugged::Commit === commit
    object = object_by_path(commit, path)
    object = object_by_path(commit, path + CONTENT_EXT) if Rugged::Tree === object
    Rugged::Blob === object ? object.content.try_encoding(Encoding.default_external) : ''
  end

  def get_attributes(path, version)
    check_path(path)
    commit = @git.lookup(version.to_s)
    raise 'Not a commit' unless Rugged::Commit === commit
    path += ATTRIBUTE_EXT
    object = object_by_path(commit, path)
    object ? YAML.load(object.content) : {}
  end

  def diff(path, from, to)
    check_path(path)
    commit_from = from && @git.rev_parse(from.to_s)
    commit_to = @git.rev_parse(to.to_s)
    raise 'Not a commit' unless (!commit_from || Rugged::Commit === commit_from) && Rugged::Commit === commit_to
    diff = git_diff_tree('--root', '--full-index', '-u', '-M', commit_from ? commit_from.oid : nil, commit_to.oid, '--', path, path + CONTENT_EXT, path + ATTRIBUTE_EXT)
    Diff.new(commit_to_version(commit_from), commit_to_version(commit_to), diff)
  end

  def short_version(version)
    version[0..4]
  end

  def method_missing(name, *args)
    cmd = name.to_s
    if cmd =~ /\Agit_/
      cmd = $'.tr('_', '-')
      args = args.flatten.compact.map(&:to_s)

      out = IO.popen('-', 'rb') do |io|
        if io
          # Read in binary mode (ascii-8bit) and convert afterwards
          block_given? ? yield(io) : io.read.try_encoding(Encoding.default_external)
        else
          # child's stderr goes to stdout
          STDERR.reopen(STDOUT)
          ENV['GIT_DIR'] = @git.path
          exec(self.class.git_path, cmd, *args)
        end
      end

      if $?.exitstatus > 0
        return '' if $?.exitstatus == 1 && out == ''
        raise "git #{cmd} #{args.inspect} #{out}"
      end

      out
    else
      super
    end
  end

  def reserved_name?(name)
    name.ends_with?(ATTRIBUTE_EXT) || name.ends_with?(CONTENT_EXT)
  end

  private

  def self.git_path
    @git_path ||= begin
                    path = `which git`.chomp
                    raise 'git not found' if $?.exitstatus != 0
                    path
                  end
  end

  def check_path(path)
    raise :reserved_path.t if path.split('/').any? {|name| reserved_name?(name) }
  end

  def path_changed?(c, path)
    return true if path.blank?
    ref1, ref2, ref3 = nil, nil, nil
    (c.parents.empty? && (ref1 ||= oid_by_path(c, path))) || c.parents.any? do |parent|
      (ref1 ||= oid_by_path(c, path)) != (oid_by_path(parent, path)) ||
        (ref2 ||= oid_by_path(c, path + ATTRIBUTE_EXT)) != (oid_by_path(parent, path + ATTRIBUTE_EXT)) ||
        (ref3 ||= oid_by_path(c, path + CONTENT_EXT)) != (oid_by_path(parent, path + CONTENT_EXT))
    end
  end

  def oid_by_path(commit, path)
    return commit.tree_oid if path.blank?
    commit.tree.path(path)[:oid]
  rescue Rugged::Error
    nil
  end

  def object_by_path(commit, path)
    return commit.tree if path.blank?
    @git.lookup(commit.tree.path(path)[:oid])
  rescue Rugged::Error
    nil
  end

  def commit_to_version(commit)
    commit && Version.new(commit.oid, User.new(commit.author[:name], commit.author[:email]),
                          Time.at(commit.time), commit.message, commit.parents.map(&:oid), commit.oid == @git.head.target)
  end

  def current_transaction
    Thread.current[:olelo_rugged_tx] || raise('No transaction running')
  end

  def work_tree
    current_transaction.tree
  end

  # Convert blob parents to trees
  # to allow children
  def expand_tree(path)
    names = path.split('/')
    names.pop
    parent = work_tree
    names.each do |name|
      object = parent[name]
      break if !object
      if object.type == :blob
        parent.move(name, name + CONTENT_EXT)
        break
      end
      parent = object
    end
  end

  # If a tree consists only of tree/, tree.content and tree.attributes without
  # children, tree.content can be moved to tree ("collapsing").
  def collapse_empty_tree(path)
    if !path.blank? && work_tree[path].empty? && work_tree[path + CONTENT_EXT]
      work_tree.move(path + CONTENT_EXT, path)
    end
  end
end

Repository.register :git, RuggedRepository
Repository.register :rugged, RuggedRepository

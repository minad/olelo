description 'Git repository backend (Using gitrb library)'
require 'gitrb'

class GitrbRepository < Repository
  CONTENT_EXT   = '.content'
  ATTRIBUTE_EXT = '.attributes'

  def initialize(config)
    Olelo.logger.info "Opening git repository: #{config[:path]}"
    @git = Gitrb::Repository.new(path: config[:path], create: true,
                                 bare: config[:bare], logger: Olelo.logger)
  end

  # @override
  def transaction(&block)
    @git.transaction(&block)
  end

  # @override
  def commit(comment)
    user = User.current
    @git.commit(comment, user && Gitrb::User.new(user.name, user.email))
    commit_to_version(@git.head)
  end

  # @override
  def path_etag(path, version)
    check_path(path)
    if id = get_object(path, version).id rescue nil
      [id,
       (get_object(path + CONTENT_EXT, version).id rescue nil),
       (get_object(path + ATTRIBUTE_EXT, version).id rescue nil)].join('-')
    end
  end

  # @override
  def get_version(version)
    commit_to_version(version ? (get_commit(version) rescue nil) : @git.head)
  end

  # @override
  def get_history(path, skip, limit)
    check_path(path)
    @git.log(max_count:  limit, skip: skip,
             path: [path, path + ATTRIBUTE_EXT, path + CONTENT_EXT]).map do |c|
      commit_to_version(c)
    end
  end

  # @override
  def get_path_version(path, version)
    check_path(path)

    commits = @git.log(max_count:  2, start: version, path: [path, path + ATTRIBUTE_EXT, path + CONTENT_EXT])

    succ = nil
    @git.git_rev_list('--reverse', '--remove-empty', "#{commits[0]}..", '--', path, path + ATTRIBUTE_EXT, path + CONTENT_EXT) do |io|
      succ = io.eof? ? nil : get_commit(@git.set_encoding(io.readline).strip)
    end rescue nil # no error because pipe is closed intentionally

    # Deleted pages have next version (Issue #11)
    succ = nil if succ && !path_exists?(path, succ.id)

    [commit_to_version(commits[1]), # previous version
     commit_to_version(commits[0]), # current version
     commit_to_version(succ)]      # next version
  end

  # @override
  def get_children(path, version)
    check_path(path)
    object = get_object(path, version)
    object && object.type != :tree ? [] : object.names.reject {|name| reserved_name?(name) }
  end

  # @override
  def get_content(path, version)
    check_path(path)
    tree = get_commit(version).tree
    object = tree[path]
    object = tree[path + CONTENT_EXT] if object && object.type == :tree
    if object
      content = object.data
      # Try to force utf-8 encoding and revert to old encoding if this doesn't work
      content.try_encoding(Encoding.default_external)
    else
      ''
    end
  end

  # @override
  def get_attributes(path, version)
    check_path(path)
    object = get_object(path + ATTRIBUTE_EXT, version)
    object && object.type == :blob ? yaml_load(object.data) : {}
  end

  # @override
  def set_content(path, content)
    check_path(path)
    expand_tree(path)
    object = @git.root[path]
    if object && object.type == :tree
      if content.blank?
        @git.root.delete(path + CONTENT_EXT)
      else
        @git.root[path + CONTENT_EXT] = Gitrb::Blob.new(data: content)
      end
      collapse_empty_tree(path)
    else
      @git.root[path] = Gitrb::Blob.new(data: content)
    end
  end

  # @override
  def set_attributes(path, attributes)
    check_path(path)
    attributes = attributes.blank? ? nil : yaml_dump(attributes).sub(/\A\-\-\-\s*\n/s, '')
    expand_tree(path)
    if attributes
      @git.root[path + ATTRIBUTE_EXT] = Gitrb::Blob.new(data: attributes)
    else
      @git.root.delete(path + ATTRIBUTE_EXT)
    end
  end

  # @override
  def move(path, destination)
    check_path(destination)
    @git.root.move(path, destination)
    @git.root.move(path + CONTENT_EXT, destination + CONTENT_EXT) if @git.root[path + CONTENT_EXT]
    @git.root.move(path + ATTRIBUTE_EXT, destination + ATTRIBUTE_EXT) if @git.root[path + ATTRIBUTE_EXT]
    collapse_empty_tree(path/'..')
  end

  # @override
  def delete(path)
    check_path(path)
    @git.root.delete(path)
    @git.root.delete(path + CONTENT_EXT)
    @git.root.delete(path + ATTRIBUTE_EXT)
    collapse_empty_tree(path/'..')
  end

  # @override
  def diff(path, from, to)
    check_path(path)
    diff = @git.diff(from: from && from.to_s, to: to.to_s,
                    path: [path, path + CONTENT_EXT, path + ATTRIBUTE_EXT], detect_renames:  true)
    Diff.new(commit_to_version(diff.from), commit_to_version(diff.to), diff.patch)
  end

  # @override
  def short_version(version)
    version[0..4]
  end

  def reserved_name?(name)
    name.ends_with?(ATTRIBUTE_EXT) || name.ends_with?(CONTENT_EXT)
  end

  def method_missing(name, *args)
    if cmd =~ /\Agit_/
      @git.method_missing(name, *args)
    else
      super
    end
  end

  private

  def get_commit(version)
    @git.get_commit(version.to_s)
  end

  def get_object(path, version)
    @git.get_commit(version.to_s).tree[path]
  end

  def check_path(path)
    raise :reserved_path.t if path.split('/').any? {|name| reserved_name?(name) }
  end

  def commit_to_version(commit)
    commit && Version.new(commit.id, User.new(commit.author.name, commit.author.email),
                          commit.date, commit.message, commit.parents.map(&:id), commit == @git.head)
  end

  # Convert blob parents to trees
  # to allow children
  def expand_tree(path)
    names = path.split('/')
    names.pop
    parent = @git.root
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
    if !path.blank? && @git.root[path].empty? && @git.root[path + CONTENT_EXT]
      @git.root.move(path + CONTENT_EXT, path)
    end
  end
end

Repository.register :gitrb, GitrbRepository

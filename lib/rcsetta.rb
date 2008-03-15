require 'grit/lib/grit'

module RCSetta

  class HGBranch

    attr_accessor :name

    def initialize(n)
      self.name=n
    end

    def inspect
      %Q{#<HGBranch "#{name}>}
    end

  end

  class HGCommit

    attr_reader :id
    attr_reader :parents
    attr_reader :tree
    attr_reader :author
    attr_reader :authored_date
    attr_reader :committer
    attr_reader :committed_date
    attr_reader :message
    attr_reader :short_message
  
    def initialize(repo, node, author, branches, parents, date, summary, msg)
      @repo=repo
      @id=node
      @author=::Grit::Actor.from_string author
      @authored_date = Time.at date.to_i
      @committer=self.author
      @committed_date = self.authored_date
      @short_message = summary
      @message = msg

      @parents=[]
    end

    def diffs
      diff = @repo.run_cmd %W(export -g #{@id})
      if diff =~ /diff --git a/
        diff = diff.sub(/.+?(diff --git a)/m, '\1')
      else
        diff = ''
      end
      ::Grit::Diff.list_from_string(@repo, diff)
    end

  end

  class HGRepo

    attr_accessor :path

    # This is a terrible hack -- I couldn't get nulls working correctly
    FSEP='892af' + '675f7'
    LSEP='7dff7' + 'f5263'

    FIELDS=%w(node author branches parents date desc|firstline desc)

    COMMIT_TEMPL=FIELDS.map{|i| "{#{i}}"}.join(FSEP) + LSEP
    COMMIT_TEMPL_Q=%{"#{COMMIT_TEMPL}"}

    def initialize(path)
      self.path=path
    end

    def inspect
      %Q{#<HGRepo "#{@path}>"}
    end

    def branches
      [HGBranch.new('default')]
    end

    def commit_count(start='default')
      (run_cmd %W(id -n)).to_i
    end

    def commits(start = 'master', max_count = 10, skip = 0)
      start = 'default' if start.to_s == 'master'
      l=run_cmd ['log', '-l', (max_count + skip), '--template', COMMIT_TEMPL_Q]
      l.split(LSEP).last(max_count).map{|i| HGCommit.new(self, *i.split(FSEP))}
    end

    def run_cmd(cmd)
      c = (%W(hg -R #{self.path}) + cmd).join(' ')
      `#{c}`
    end

  end

  SCM_DRIVERS = { '.hg' => HGRepo, '.git' => ::Grit::Repo }

  # Detect a repo type and open it.
  def RCSetta::open(path)
    epath = File.expand_path path

    driver = SCM_DRIVERS.detect{|p, c| File.exist?(File.join(epath, p))}
    if driver
      driver.last.new epath
    else
      raise "Cannot detect repo type from #{path}"
    end
  end

end


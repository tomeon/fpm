require "fpm/namespace"
require "fpm/package"
require "fpm/util"
require "fileutils"
require "find"

class FPM::Package::CPAN < FPM::Package
  # Flags '--foo' will be accessable  as attributes[:npm_foo]
  option "--perl-bin", "PERL_EXECUTABLE",
    "The path to the perl executable you wish to run.", :default => "perl"

  option "--cpanm-bin", "CPANM_EXECUTABLE",
    "The path to the cpanm executable you wish to run.", :default => "cpanm"

  option "--mirror", "CPAN_MIRROR",
    "The CPAN mirror to use instead of the default."

  option "--mirror-only", :flag,
    "Only use the specified mirror for metadata.", :default => false

  option "--package-name-prefix", "NAME_PREFIX",
    "Name to prefix the package name with.", :default => "perl"

  option "--test", :flag,
    "Run the tests before packaging?", :default => true

  option "--perl-lib-path", "PERL_LIB_PATH",
    "Path of target Perl Libraries"

  option "--contained", :flag,
    "Install prerequisites in a temporary environment; otherwise install them in the specified perl's 'installsitelib'", :default => true

  option "--sudo", :flag,
    "Use sudo to install dependencies.  Potentially useful with '--no-cpan-contained'", :default => false

  option "--sandbox-non-core", :flag,
    "Sandbox all non-core modules, even if they're already installed", :default => true

  private
  def input(package)
    #if RUBY_VERSION =~ /^1\.8/
      #raise FPM::Package::InvalidArgument,
        #"Sorry, CPAN support requires ruby 1.9 or higher. You have " \
        #"#{RUBY_VERSION}. If this negatively impacts you, please let " \
        #"me know by filing an issue: " \
        #"https://github.com/jordansissel/fpm/issues"
    #end
    #require "ftw" # for http access
    require "net/http"
    require "json"

    # Test whether we can write to :cpan_perl_bin's library/bin paths.
    if !(attributes[:cpan_contained?] or attributes[:cpan_sudo?])
      cpan_installsitelib = `#{attributes[:cpan_perl_bin]} -MConfig -e 'print $Config{installsitelib}'`.chomp
      cpan_installsitebin = `#{attributes[:cpan_perl_bin]} -MConfig -e 'print $Config{installsitebin}'`.chomp
      if not File.writable?(cpan_installsitelib) or not File.writable?(cpan_installsitebin)
        raise FPM::Util::PermissionError, "Can't write to #{cpan_installsitelib} and/or " \
          "#{cpan_installsitebin}.  Either use '--cpan-contained' or '--cpan-sudo'"
      end
    end

    if (attributes[:cpan_local_module?])
      moduledir = package
    else
      result = search(package)
      tarball = download(result, version)
      moduledir = unpack(tarball)
    end

    # Read package metadata (name, version, etc)
<<<<<<< HEAD
    if File.exists?(File.join(moduledir, "META.json"))
      local_metadata = JSON.parse(File.read(File.join(moduledir, ("META.json"))))
    elsif File.exists?(File.join(moduledir, ("META.yml")))
      require "yaml"
      local_metadata = YAML.load_file(File.join(moduledir, ("META.yml")))
    elsif File.exists?(File.join(moduledir, "MYMETA.json"))
      local_metadata = JSON.parse(File.read(File.join(moduledir, ("MYMETA.json"))))
    elsif File.exists?(File.join(moduledir, ("MYMETA.yml")))
      require "yaml"
      local_metadata = YAML.load_file(File.join(moduledir, ("MYMETA.yml")))
=======
    if File.exist?(File.join(moduledir, "META.json"))
      metadata = JSON.parse(File.read(File.join(moduledir, ("META.json"))))
    elsif File.exist?(File.join(moduledir, ("META.yml")))
      require "yaml"
      metadata = YAML.load_file(File.join(moduledir, ("META.yml")))
    elsif File.exist?(File.join(moduledir, "MYMETA.json"))
      metadata = JSON.parse(File.read(File.join(moduledir, ("MYMETA.json"))))
    elsif File.exist?(File.join(moduledir, ("MYMETA.yml")))
      require "yaml"
      metadata = YAML.load_file(File.join(moduledir, ("MYMETA.yml")))
    else
      raise FPM::InvalidPackageConfiguration,
        "Could not find package metadata. Checked for META.json and META.yml"
>>>>>>> master
    end

    # Merge the MetaCPAN query result and the metadata pulled from the local
    # META file(s).  The local data overwrites the query data for all keys the
    # two hashes have in common.  Merge with an empty hash if there was no
    # local META file.
    metadata = result.merge(local_metadata || {})

    if metadata.empty?
      raise FPM::InvalidPackageConfiguration,
        "Could not find package metadata. Checked for META.json, META.yml, and MetaCPAN API data"
    end

    self.version = metadata["version"]
    self.description = metadata["abstract"]

    self.license = case metadata["license"]
      when Array; metadata["license"].first
      when nil; "unknown"
      else; metadata["license"]
    end

    unless metadata["distribution"].nil?
      logger.info("Setting package name from 'distribution'",
                   :distribution => metadata["distribution"])
      self.name = fix_name(metadata["distribution"])
    else
      logger.info("Setting package name from 'name'",
                   :name => metadata["name"])
      self.name = fix_name(metadata["name"])
    end

    # author is not always set or it may be a string instead of an array
    self.vendor = case metadata["author"]
      when String; metadata["author"]
      when Array; metadata["author"].join(", ")
      else
        raise FPM::InvalidPackageConfiguration, "Unexpected CPAN 'author' field type: #{metadata["author"].class}. This is a bug."
    end if metadata.include?("author")

    self.url = metadata["resources"]["homepage"] rescue "unknown"

    # TODO(sissel): figure out if this perl module compiles anything
    # and set the architecture appropriately.
    self.architecture = "all"

    # Install any build/configure dependencies with cpanm.
    # We'll install to a temporary directory.
    logger.info("Installing any build or configure dependencies")

<<<<<<< HEAD
    cpanm_flags = [moduledir]
    if attributes[:cpan_contained?]
      cpanm_flags += ["-L", build_path("cpan")]
=======
    if attributes[:cpan_sandbox_non_core?]
      cpanm_flags = ["-L", build_path("cpan"), moduledir]
    else
      cpanm_flags = ["-l", build_path("cpan"), moduledir]
>>>>>>> master
    end

    # This flag causes cpanm to ONLY download dependencies, skipping the target
    # module itself.  This is fine, because the target module has already been
    # downloaded, and there's no need to download twice, test twice, etc.
    cpanm_flags += ["--installdeps"]
<<<<<<< HEAD

    cpanm_flags += ["--sudo"] if attributes[:cpan_sudo?]
=======
>>>>>>> master
    cpanm_flags += ["-n"] if !attributes[:cpan_test?]
    cpanm_flags += ["--mirror", "#{attributes[:cpan_mirror]}"] if !attributes[:cpan_mirror].nil?
    cpanm_flags += ["--mirror-only"] if attributes[:cpan_mirror_only?] && !attributes[:cpan_mirror].nil?

    safesystem(attributes[:cpan_cpanm_bin], *cpanm_flags)

    if !attributes[:no_auto_depends?]
      unless metadata["requires"].nil?
        metadata["requires"].each do |dep_name, version|
          # Special case for representing perl core as a version.
          if dep_name == "perl"
            self.dependencies << "#{dep_name} >= #{version}"
            next
          end
          dep = search(dep_name)

          if dep.include?("distribution")
            name = fix_name(dep["distribution"])
          else
            name = fix_name(dep_name)
          end

          if version.to_s == "0"
            # Assume 'Foo = 0' means any version?
            self.dependencies << "#{name}"
          else
            # The 'version' string can be something complex like:
            #   ">= 0, != 1.0, != 1.2"
            if version.is_a?(String)
              version.split(/\s*,\s*/).each do |v|
                if v =~ /\s*[><=]/
                  self.dependencies << "#{name} #{v}"
                else
                  self.dependencies << "#{name} = #{v}"
                end
              end
            else
              self.dependencies << "#{name} >= #{version}"
            end
          end
        end
      end
    end #no_auto_depends

    ::Dir.chdir(moduledir) do
      # TODO(sissel): install build and config dependencies to resolve
      # build/configure requirements.
      # META.yml calls it 'configure_requires' and 'build_requires'
      # META.json calls it prereqs/build and prereqs/configure

      prefix = attributes[:prefix] || "/usr/local"
      # TODO(sissel): Set default INSTALL path?

      # Set up the local::lib environment
      export_local_lib_env(build_path("cpan"))

      # Some modules will prompt for input during the build process, hanging
      # fpm.  These options will override most such occurrences.
      ENV["PERL_MM_USE_DEFAULT"] = "1"
      ENV["AUTOMATED_TESTING"] = "1"

      # Try Makefile.PL, Build.PL
      #
      if File.exist?("Build.PL")
        # Module::Build is in use here; different actions required.
        safesystem(attributes[:cpan_perl_bin], "Build.PL")
        safesystem(attributes[:cpan_perl_bin], "./Build")

        if attributes[:cpan_test?]
          safesystem(attributes[:cpan_perl_bin], "./Build", "test")
        end
        if attributes[:cpan_perl_lib_path]
          perl_lib_path = attributes[:cpan_perl_lib_path]
          safesystem("./Build install --install_path lib=#{perl_lib_path} \
                     --destdir #{staging_path} --prefix #{prefix} --destdir #{staging_path}")
        else
           safesystem("./Build", "install",
                     "--prefix", prefix, "--destdir", staging_path)
        end
      elsif File.exist?("Makefile.PL")
        if attributes[:cpan_perl_lib_path]
          perl_lib_path = attributes[:cpan_perl_lib_path]
          safesystem(attributes[:cpan_perl_bin],
                     "Makefile.PL", "PREFIX=#{prefix}", "LIB=#{perl_lib_path}")
        else
          safesystem(attributes[:cpan_perl_bin],
                     "Makefile.PL", "PREFIX=#{prefix}")
        end
        if attributes[:cpan_test?]
          make = [ "env", "PERL5LIB=#{build_path("cpan/lib/perl5")}", "make" ]
        else
          make = [ "make" ]
        end
        safesystem(*make)
        safesystem(*(make + ["test"])) if attributes[:cpan_test?]
        safesystem(*(make + ["DESTDIR=#{staging_path}", "install"]))


      else
        raise FPM::InvalidPackageConfiguration,
          "I don't know how to build #{name}. No Makefile.PL nor " \
          "Build.PL found"
      end

      # Fix any files likely to cause conflicts that are duplicated
      # across packages.
      # https://github.com/jordansissel/fpm/issues/443
      # https://github.com/jordansissel/fpm/issues/510
      glob_prefix = attributes[:cpan_perl_lib_path] || prefix
      ::Dir.glob(File.join(staging_path, glob_prefix, "**/perllocal.pod")).each do |path|
        logger.debug("Removing useless file.",
                      :path => path.gsub(staging_path, ""))
        File.unlink(path)
      end
    end


    # TODO(sissel): figure out if this perl module compiles anything
    # and set the architecture appropriately.
    self.architecture = "all"

    # Find any shared objects in the staging directory to set architecture as
    # native if found; otherwise keep the 'all' default.
    Find.find(staging_path) do |path|
      if path =~ /\.so$/
        logger.info("Found shared library, setting architecture=native",
                     :path => path)
        self.architecture = "native"
      end
    end
  end

  def export_local_lib_env(local_lib_path)
    # Iterate over the output of local::lib line by line
    `#{attributes[:cpan_perl_bin]} -Mlocal::lib=#{local_lib_path}`.lines.each do |line|
      # local::lib's output is in the form:
      # 'ENV_VAR="some value"; export $ENV_VAR;'
      # This regular expression strips everything from the semicolon in front
      # of 'export' to the end of the line, then splits on the equals sign,
      # limiting the returned array to two elements.
      (k, v) = line.chomp.gsub(/;\s+export.*$/, '').split("=", 2)

      # Skip these, since they wreak havoc when PREFIX # is set.
      next if k == "PERL_MM_OPT" or k == "PERL_MB_OPT"

      # Set the current environment in accordance with local::lib's output.
      # The subshell call to echo is necessary because some environment
      # variables are defined in terms of other such variables; this technique
      # expands the variables-within-variables.
      ENV[k] = `echo #{v}`.chomp
    end
  end

  def unpack(tarball)
    directory = build_path("module")
    ::Dir.mkdir(directory)
    args = [ "-C", directory, "-zxf", tarball,
      "--strip-components", "1" ]
    safesystem("tar", *args)
    return directory
  end

  def download(metadata, cpan_version=nil)
    distribution = metadata["distribution"]
    author = metadata["author"]

    logger.info("Downloading perl module",
                 :distribution => distribution,
                 :version => cpan_version)

    # default to latest versionunless we specify one
    if cpan_version.nil?
      self.version = metadata["version"]
    else
      if metadata["version"] =~ /^v\d/
        self.version = "v#{cpan_version}"
      else
        self.version = cpan_version
      end
    end

    metacpan_release_url = "http://api.metacpan.org/v0/release/#{author}/#{distribution}-#{self.version}"
    begin
      release_response = httpfetch(metacpan_release_url)
    rescue Net::HTTPServerException => e
      logger.error("metacpan release query failed.", :error => e.message,
                    :module => package, :url => metacpan_release_url)
      raise FPM::InvalidPackageConfiguration, "metacpan release query failed"
    end

    data = release_response.body
    release_metadata = JSON.parse(data)
    archive = release_metadata["archive"]

    # should probably be basepathed from the url
    tarball = File.basename(archive)

    url_base = "http://www.cpan.org/"
    url_base = "#{attributes[:cpan_mirror]}" if !attributes[:cpan_mirror].nil?

    #url = "http://www.cpan.org/CPAN/authors/id/#{author[0,1]}/#{author[0,2]}/#{author}/#{tarball}"
    url = "#{url_base}/authors/id/#{author[0,1]}/#{author[0,2]}/#{author}/#{archive}"
    logger.debug("Fetching perl module", :url => url)

    begin
      response = httpfetch(url)
    rescue Net::HTTPServerException => e
      #logger.error("Download failed", :error => response.status_line,
                    #:url => url)
      logger.error("Download failed", :error => e, :url => url)
      raise FPM::InvalidPackageConfiguration, "metacpan query failed"
    end

    File.open(build_path(tarball), "w") do |fd|
      #response.read_body { |c| fd.write(c) }
      fd.write(response.body)
    end
    return build_path(tarball)
  end # def download

  def search(package)
    logger.info("Asking metacpan about a module", :module => package)
    metacpan_url = "http://api.metacpan.org/v0/module/" + package
    begin
      response = httpfetch(metacpan_url)
    rescue Net::HTTPServerException => e
      #logger.error("metacpan query failed.", :error => response.status_line,
                    #:module => package, :url => metacpan_url)
      logger.error("metacpan query failed.", :error => e.message,
                    :module => package, :url => metacpan_url)
      raise FPM::InvalidPackageConfiguration, "metacpan query failed"
    end

    #data = ""
    #response.read_body { |c| p c; data << c }
    data = response.body
    metadata = JSON.parse(data)
    return metadata
  end # def metadata

  def fix_name(name)
    case name
      when "perl"; return "perl"
      else; return [attributes[:cpan_package_name_prefix], name].join("-").gsub("::", "-")
    end
  end # def fix_name

  def httpfetch(url)
    uri = URI.parse(url)
    if ENV['http_proxy']
      proxy = URI.parse(ENV['http_proxy'])
      http = Net::HTTP.Proxy(proxy.host,proxy.port,proxy.user,proxy.password).new(uri.host, uri.port)
    else
      http = Net::HTTP.new(uri.host, uri.port)
    end
    response = http.request(Net::HTTP::Get.new(uri.request_uri))
    case response
      when Net::HTTPSuccess; return response
      when Net::HTTPRedirection; return httpfetch(response["location"])
      else; response.error!
    end
  end

  public(:input)
end # class FPM::Package::NPM

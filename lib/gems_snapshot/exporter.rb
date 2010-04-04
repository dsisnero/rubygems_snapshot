require "rubygems/package"
require "tmpdir"

module GemsSnapshot

  class Exporter

    def export(filename = nil, options = {})
      options = {:format => :tar}.merge(options)
      if options[:format] == :tar
        result = export_to_tar(filename)
      else
        result = export_to_yml(filename)
      end
      result
    end

    def installed_gems
      dep = Gem::Dependency.new(/^/i, Gem::Requirement.default) #get all local gems
      Gem.source_index.search(dep)
    end

    def export_to_yml(filename)
      hash_specs = {}
      installed_gems.each do |spec|
        versions = hash_specs[spec.name.to_s] || []
        versions << spec.version.to_s
        hash_specs[spec.name.to_s] = versions
      end

      gems = []
      hash_specs.each do |spec_name, versions|
        gems << {'name' => spec_name, 'versions' => versions}
      end

      main_hash = {'gems' => gems, 'sources' => Gem.sources}
      #puts main_hash.to_yaml.to_s  #for debug only :P

      File.open(filename, "w") { |file| file.puts(main_hash.to_yaml) }
      filename
    end

    def export_to_tar(filename)
      filename = "snapshot.gems" if filename.nil?

      files = []
      installed_gems.each do |gem|
        files << {:name => "gems/#{gem.full_name}.gem", :path => "#{gem.installation_path}/cache/#{gem.full_name}.gem"}
      end
      files << {:name => "gems.yml", :path => export_to_yml("#{Dir.tmpdir}/gems.yml")}

      create_tar_file(filename, files)
      filename
    end

    # Create a tar file with Gem::Package::TarWriter from Rubygems.
    # +filename+ file destination.
    # +files+ Array of Hash. Each hash have to be +:name+ and +:path+ keys.
    def create_tar_file(filename, files)
      File.open(filename, "w+") do |file|
        Gem::Package::TarWriter.new(file) do |tar_file|

          files.each do |hash|
            filepath = hash[:path]
            filename = hash[:name]

            stat = File.stat(filepath)
            tar_file.add_file_simple(filename, stat.mode, stat.size) do |tar_io|
              File.open(filepath, "rb") do |file_io|
                tar_io.write(file_io.read(4096)) until file_io.eof?
              end
            end
          end

        end
      end
    end

  end

end
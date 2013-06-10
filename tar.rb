require 'rubygems'
require 'rubygems/package'
require 'find'
require 'fileutils'
require 'zlib'

module Util
    module Tar

        ############## Public methods
        # ruby version of 'tar cf tarfile srcs'
        # make a tar file from src source files and directories
        # tarfile: the target tar file to be generate
        # src: source files and directories, no absolute path is permitted.
        def tar(tarfile, *src)
            raise "tar file #{tarfile} shouldn't be a directory" if File.directory? tarfile
            File.open tarfile, 'w' do |otarfile|
                tar0(otarfile, *src)
            end
        end

        # ruby version of 'tar zcf targzfile srcs'
        def targz(targzfile, *src)
            raise "tar.gz file #{targzfile} shouldn't be a directory" if File.directory? targzfile
            Zlib::GzipWriter.open targzfile do |otarfile|
                tar0(otarfile, *src)
            end
        end

        # in ruby Dir.chdir is not thread safe, so a cd-version tar is provided
        # no Dir.chdir is called when tar the src files. all path of 'src' is related
        # to the path 'cdpath'
        def cdtar(cdpath, tarfile, *src)
            raise "tar file #{tarfile} shouldn't be a directory" if File.directory? tarfile
            File.open tarfile, 'w' do |otarfile|
                cdtar0 cdpath, otarfile, *src
            end
        end

        # similar as 'tar -C cdpath -zcf targzfile srcs', the difference is 'srcs' is related
        # to the current working directory, instead of 'cdpath'
        def cdtargz(cdpath, targzfile, *src)
            raise "tar.gz file #{targzfile} shouldn't be a directory" if File.directory? targzfile
            Zlib::GzipWriter.open targzfile do |otarfile|
                cdtar0 cdpath, otarfile, *src
            end
        end

        # ruby version of 'tar -C destdir -xf tarfile'
        def untar(tarfile, destdir)
            raise "invalid tar file #{tarfile}" unless File.file? tarfile
            File.open tarfile, 'r' do |otarfile|
                untar0(otarfile, destdir)
            end
        end

        # ruby version of 'tar -C destdir -zxf targzfile'
        def untargz(targzfile, destdir)
            raise "invalid tar.gz file #{targzfile}" unless File.file? targzfile
            Zlib::GzipReader.open targzfile do |otarfile|
                untar0(otarfile, destdir)
            end
        end

        # ruby version of 'tar tf tarfile'
        def tarls(tarfile)
            raise "invalid tar file #{tarfile}" unless File.file? tarfile
            File.open tarfile, 'r' do |otarfile|
                tarls0 otarfile
            end
        end

        # ruby version of 'tar ztf targzfile'
        def targzls(targzfile)
            raise "invalid tar.gz file #{targzfile}" unless File.file? targzfile
            Zlib::GzipReader.open targzfile do |otarfile|
                tarls0 otarfile
            end
        end


        ######### Private internal methods, do not use these xxx0 version directly

        def tar0(otarfile, *src)
            raise "no file or directory to tar" if !src || src.length == 0
            Gem::Package::TarWriter.new otarfile do |tar|
                Find.find *src do |f|
                    mode = File.stat(f).mode
                    if File.directory? f
                        tar.mkdir f, mode
                    else
                        tar.add_file f, mode do |tio|
                            File.open f, 'r' do |io|
                                tio.write io.read
                            end
                        end
                    end
                end
            end
        end

        def cdtar0(cdpath, otarfile, *src)
            raise "path #{cdpath} should be a directory" unless File.directory? cdpath
            raise "no file or directory to tar" if !src || src.length == 0

            src.each do |p| p.sub! /^/, "#{cdpath}/" end
            Gem::Package::TarWriter.new otarfile do |tar|
                Find.find *src do |f|
                    relative_path = f.sub "#{cdpath}/", ""
                    mode = File.stat(f).mode
                    if File.directory? f
                        tar.mkdir relative_path, mode
                    else
                        tar.add_file relative_path, mode do |tio|
                            File.open f, 'r' do |io|
                                tio.write io.read
                            end
                        end
                    end
                end
            end
        end


        def untar0(otarfile, destdir)
            raise "invalid destination directory #{destdir}" unless File.directory? destdir
            Gem::Package::TarReader.new otarfile do |tar|
                tar.each do |tarentry|
                    path = File.join destdir, tarentry.full_name
                    if tarentry.directory?
                        FileUtils.mkdir_p path
                    else
                        ppath = File.dirname path
                        FileUtils.mkdir_p ppath unless File.directory? ppath
                        File.open path, 'wb' do |ofile|
                            ofile.write tarentry.read
                        end
                    end
                end
            end
        end

        def tarls0(otarfile)
            result = []
            Gem::Package::TarReader.new otarfile do |tar|
                tar.each do |tarentry|
                    result << tarentry.full_name + (tarentry.directory? ? '/' : '')
                end
            end
            result
        end

    end
end

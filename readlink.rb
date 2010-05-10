module Puppet::Parser::Functions
  newfunction(:readlink) do |args|
    self.interp.newfile(args[0])
    filename = args[0]
    if ( File.symlink(filename) )
      return File.readlink(filename);
    end
    raise Puppet::ParseError, "${filename} is not a symbolic link"
  end
end
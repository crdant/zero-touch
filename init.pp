##
# Installs the Drush command-line management shell for Drupal
#
class drush {
  $version = "3.0-alpha1"
  include packages
  include sdi::packages
  
  realize(Package[ "php-pear" ], Package["php5-cli"], Package["php5-common"], Package["php5-mysql"])

  ##
  # Download Drush
  #
  file { "/var/tmp/drush-All-Versions-$version.tar.gz" :
    alias => "drush-download",
    source   => "puppet:///drush/drush-All-Versions-$version.tar.gz",
  }

  exec { "console-table-package":
    command => "pear install Console_Table",
    user => "root",
  }
  
  ##
  # Unpack the drush package
  #
  exec { "tar -xzf /var/tmp/drush-All-Versions-$version.tar.gz -C /opt":
    alias   => "drush-extract",
    creates => "/opt/drush",
    require => [ 
      File["drush-download"], 
      Exec["console-table-package"]
    ],
  }

  file { "/opt/drush/drush":
    alias   => "drush-executable",
    mode    => 755,
    require => Exec["drush-extract"],
  }
  
  ##
  # Create a directory for local commands
  # 
  $share_dir = "/usr/local/share/drush"
  $command_dir = "${share_dir}/commands"
  $etc_dir = "${share_dir}/etc"
  
  file { $share_dir:
    alias   => "drush-share-directory",
    ensure  => "directory",
    mode    => 755,
    owner   => root,
    group   => root,
  }
  
  file { $etc_dir:
    alias   => "drush-etc-directory",
    ensure  => "directory",
    mode    => 755,
    owner   => root,
    group   => root,
  }
  
  # add our own run-test.sh that allows for the xunit output
  file { "run-tests.sh":
    mode    => 755,
    owner   => root,
    group   => root,
    source   => "puppet:///drush/run-tests.sh",
  }
  
  file { $command_dir:
    alias   => "drush-local-command-directory",
    ensure  => "directory",
    mode    => 755,
    owner   => root,
    group   => root,
    require => [
      File["drush-share-directory"], 
    ],
  }
  
  ##
  # Setup the drushrc for the local commands
  #
  file { "/opt/drush/drushrc.php":
    alias   => "drush-drushrc",
    mode    => "755",
    owner   => "root",
    group   => "root",
    require => [ 
      Exec["drush-extract"], 
      File["drush-local-command-directory"], 
    ],
    content  => template("drush/drushrc.php.erb"),
  }
  
  ##
  # Install local commands
  #
  file { "${command_dir}/role.drush.inc":
    alias   => "drush-role-commands",
    mode    => "755",
    owner   => "root",
    group   => "root",
    require => [ 
      File["drush-local-command-directory"], 
    ],
    source   => "puppet:///drush/commands/role.drush.inc",
  }  
  
  file { "${command_dir}/simpletest_xml.drush.inc":
    alias   => "drush-simpletest-commands",
    mode    => "755",
    owner   => "root",
    group   => "root",
    require => [ 
      File["drush-local-command-directory"], 
    ],
    source   => "puppet:///drush/commands/simpletest_xml.drush.inc",
  }
  
  ##
  # Link drush into the standard directory structure
  #
  file { "/usr/local/bin/drush":
    alias   => "drush-link",
    ensure  => "link",
    owner   => "root",
    group   => "root",
    target  => "/opt/drush/drush",
    require => File["drush-executable"],
  }

  ##
  # Download a Drupal module from drupal.org, using the short form of the clear command since it's the
  # same between versions 2 and 3
  #
  define module($module,$url,$root) {
    drush::command { "install module ${module}" : user => 1, commmand => "dl", url => $url, root => $root, $arguments => "${module}" }
  }
  
  ##
  # Enable a Drupal module, using the short form of the clear command since it's the same
  # between versions 2 and 3
  #
  define enable($module,$url,$root) {
    drush::command { "enable module ${module}" : user => 1, commmand => "en", url => $url, root => $root, $arguments => "${module}", require => "install module ${module}" }
  }
  
  ##
  # Disable a Drupal module, using the short form of the clear command since it's the same
  # between versions 2 and 3
  #
  define disable($module,$url,$root) {
    drush::command { "disable module ${module}" : user => 1, commmand => "dis", url => $url, root => $root, $arguments => "${module}" }
  }
   
  ##
  # Disable a Drupal module, this is Drush 3.0 compatible only
  #
  define uninstall($module,$url,$root) {
   drush::command { "uninstall module ${module}" : user => 1, commmand => "pm-uninstall", url => $url, root => $root, $arguments => "${module}" }
  }
    
  ##
  # Clear the Drupal cache, using the short form of the clear command since it's the same
  # between versions 2 and 3
  #
  define cacheclear($url,$root) {
    drush::command { "clear cache" : user => 1, commmand => "cc", url => $url, root => $root }
  }
  
  ##
  # Create a drupal role
  #
  define createrole($role,$url,$root) {
    drush::command { "create role ${role}" : user => 1, commmand => "role-create", url => $url, root => $root, $arguments => "${role}" }
  }
  
  ##
  # Add drupal role to a user
  #
  define userrole($role,$user,$url,$root) {
    drush::command { "create role ${role}" : user => 1, commmand => "role-add-user", url => $url, root => $root, $arguments => "${role} ${user}" }
  }
  
  ##
  # Add drupal permission to a role
  #
  define roleperm($role,$permission,$url,$root) {
    drush::command { "create role ${role}" : user => 1, commmand => "role-add-permission", url => $url, root => $root, $arguments => "${role} ${permission}" }
  }
  
  ##
  # Update the Drupal database
  #
  define updatedb($url,$root) {
    drush::command { "updatedb" : user => 1, commmand => "updatedb", url => $url, root => $root }
  }
  
  ##
  # Export the Drupal database
  #
  define exportdb($url,$root,$file) {
    # TODO: make agnostic to Drush versions, currently only 3.x
    drush::command { "exportdb ${file}" : user => 1, commmand => "sql-dump", url => $url, root => $root, 
      arguments => "--result-file ${file} --ordered-dump" }
  }
  
  ##
  # Load the Drupal database from an export
  # 
  define loaddb($url,$root,$file) {
    # TODO: make agnostic to Drush versions, currently only 3.x
    # can't use the basic define for Drush commands here because I need to use the output of 
    # the call to the command as the command that I execute
    exec { "import db: $file":
	    require => Service["drush-link"],
	    cwd => $root,
	    path => "/bin:/usr/bin:/usr/local/bin",
	    command => "`drush -u $uid -l $url sql-connect` < $file"
  	}
  }
  
  ##
  # run a Drush command as a specified user on the specified site
  #
  define command($uid,$command,$url,$root, $arguments = null) {
  	exec { "Drush command: $command":
	    require => Service["drush-link"],
	    cwd => $root,
	    path => "/bin:/usr/bin:/usr/local/bin",
	    command => "drush -u $uid -l $url ${cmd} ${arguments}"
  	}
  }
}
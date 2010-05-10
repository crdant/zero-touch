##
# Default setup for all servers not mentioned below
#
node default { 
  include base
} 

# Define the environment to use later
$hosting_env = "coop"

########################################################
# Web Server configurations
#

node 'web-config' {
  $firewall_ports = [ "80", "443", ]

  $firewall_source_ports = [ 
    "11211", "11212", "11213", "11214", "11215", "11216", "11217", "11218", "11219", 
  ]
  
  $aide_watch_dirs = [ 
    "/var/www/vhost", 
  ]

  $aide_ignore_dirs = [ 
    "/var/www/vhost/whitehouse_files$", 
    "/var/www/vhost/www.public.tld/files$", 
    "/var/www/vhost/www.public.tld/sites/default/files$", 
    "/var/www/vhost/www.public.tld/sites/www.public.tld/files$", 
    "/var/www/vhost/whitehouse_releases/.*/files$", 
    "/var/www/vhost/whitehouse_releases/.*/sites/default/files$", 
    "/var/www/vhost/whitehouse_releases/.*/sites/www.public.tld/files$", 
  ]
}

##
# Public accessible web servers
#
node 'web1.domain.tld' inherits 'web-config' {
  include apache::drupal
  include drush
  include monitor

  monitor::monitor_web { "web": }

  apache::vhost { "www.public.tld" :
    aliases => [ "web1.domain.tld", "origin.domain.tld", "wh.gov", "public.tld"],
    type    => "public",
  }
  apache::vhost { "m.public.tld" :
    host    => "m.public.tld",
    site    => "www.public.tld",
    aliases => [ "m.wh.gov"],
    type    => "mobile",
  }
  apache::vhost { "www.public.tld-ssl" :
    aliases => [ "web1.domain.tld", "origin.domain.tld", ],
    site    => "www.public.tld",
    ssl     => true,
    type    => "public",
  }
  
}


##
# Dedicated edit web server
#
node 'edit.domain.tld' inherits 'web-config' {
  include drush
  include monitor
  include apache::drupal

  monitor::monitor_web { "web": }
  
  apache::vhost { "edit.public.tld" :
    type => "edit",
    aliases => ["edit.domain.tld",],
  }  
  apache::vhost { "edit.public.tld-ssl" :
    site    => "edit.public.tld",
    aliases => ["edit.domain.tld",],
    ssl     => true,
    type    => "edit",
  }
}

########################################################
# Cache Server configurations
#

node 'cache-config' {
  $firewall_ports = [ 
    "11211", "11212", "11213", "11214", "11215", "11216", "11217", "11218", "11219", 
  ]
}

node 'cache1.domain.tld' inherits 'cache-config' {
  include memcache
  include monitor

  monitor::monitor_cache { "cache": }
}

########################################################
# Search Server configurations
#

node 'search-config' {
  $aide_watch_dirs = [ 
    "/opt/tomcat", 
    "/opt/solr", 
  ]
  $aide_log_dirs = [ 
    "/opt/tomcat/logs", 
  ]
  $aide_ignore_dirs = [ 
    "/opt/solr/www.public.tld/home/data$", 
  ]
}

node 'search-master.domain.tld' inherits 'search-config'{
  $firewall_ports = [ "8080", "8888", ]

  include search
  include search::nginx
  include monitor
  monitor::monitor_search { "search": }

  # Have this replicate from primary
  $solr_type       = "master"
  $solr_master_url = "http://search-replication:8080/solr-whitehouse"
  include search::solr
}


##
# Utility server configurations
#
node 'monitoring.' {
  $firewall_ports = [ "162", "6060", "6061"]
  
  include nagios
  include cacti
  include apache::php
  include selinux::setup

  selinux::module { "mysqld":
    name => "mysqld"
  }
  
  selinux::module { "nagios":
    name => "nagios"
  }
}

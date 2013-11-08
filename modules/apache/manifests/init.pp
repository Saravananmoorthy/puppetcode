class apache (
    $service_name = $apache::params::service_name,
    $default_mods         = true,
    $default_ssl_vhost    = false,
    $default_ssl_cert     = $apache::params::default_ssl_cert,
    $default_ssl_key      = $apache::params::default_ssl_key,
    $default_ssl_chain    = undef,
    $default_ssl_ca       = undef,
    $default_ssl_crl_path = undef,
    $default_ssl_crl      = undef,
    $service_enable       = true,
    $service_ensure       = 'running',
    $purge_configs        = true,
    $purge_vdir           = false,
    $serveradmin          = 'root@localhost',
    $sendfile             = 'On',
    $error_documents      = false,
    $timeout              = '120',
    $httpd_dir            = $apache::params::httpd_dir,
    $confd_dir            = $apache::params::confd_dir,
    $vhost_dir            = $apache::params::vhost_dir,
    $vhost_enable_dir     = $apache::params::vhost_enable_dir,
    $mod_dir              = $apache::params::mod_dir,
    $mod_enable_dir       = $apache::params::mod_enable_dir,
    $conf_template        = $apache::params::conf_template,
    $servername           = $apache::params::servername,
    $manage_user          = true,
    $manage_group         = true,
    $user                 = $apache::params::user,
    $group                = $apache::params::group,
    $keepalive            = $apache::params::keepalive,
    $keepalive_timeout    = $apache::params::keepalive_timeout,
    $logroot              = $apache::params::logroot,
    $ports_file           = $apache::params::ports_file,
    $server_tokens        = 'OS',
    $server_signature     = 'On',
    $package_ensure       = 'installed'
) inherits apache::params {

  package { 'httpd':
      ensure => $package_ensure,
      name   => $apache::params::apache_name,
      notify => Class['Apache::Service'],
  }

  class { 'apache::service':
    service_name   => $service_name,
    service_enable => $service_enable,
    service_ensure => $service_ensure,
  }


  Exec {
    path => '/bin:/sbin:/usr/bin:/usr/sbin',
  }

  exec { "mkdir ${confd_dir}":
    creates => $confd_dir,
    require => Package['httpd'],
  }
  file { $confd_dir:
    ensure  => directory,
    recurse => true,
    purge   => $purge_confd,
    notify  => Class['Apache::Service'],
    require => Package['httpd'],
  }
## Add local conf
#exec { "mkdir ${confd_dir}/local":
#    creates => $confd_dir/local,
#    require => Package['httpd'],
#  }
#  file { $confd_dir/local:
#    ensure  => directory,
#    recurse => true,
#    purge   => $purge_confd,
#    notify  => Class['Apache::Service'],
#    require => Package['httpd'],
#  }

##############


  if ! defined(File[$mod_dir]) {
    exec { "mkdir ${mod_dir}":
      creates => $mod_dir,
      require => Package['httpd'],
    }
    file { $mod_dir:
      ensure  => directory,
      recurse => true,
      purge   => $purge_configs,
      notify  => Class['Apache::Service'],
      require => Package['httpd'],
    }
  }

  if $mod_enable_dir and ! defined(File[$mod_enable_dir]) {
    $mod_load_dir = $mod_enable_dir
    exec { "mkdir ${mod_enable_dir}":
      creates => $mod_enable_dir,
      require => Package['httpd'],
    }
    file { $mod_enable_dir:
      ensure  => directory,
      recurse => true,
      purge   => $purge_configs,
      notify  => Class['Apache::Service'],
      require => Package['httpd'],
    }
  } else {
    $mod_load_dir = $mod_dir
  }

  if ! defined(File[$vhost_dir]) {
    exec { "mkdir ${vhost_dir}":
      creates => $vhost_dir,
      require => Package['httpd'],
    }

    file { $vhost_dir:
      ensure  => directory,
      recurse => true,
      purge   => $purge_configs,
      notify  => Class['Apache::Service'],
      require => Package['httpd'],
    }
  }

  if $vhost_enable_dir and ! defined(File[$vhost_enable_dir]) {
    $vhost_load_dir = $vhost_enable_dir
    exec { "mkdir ${vhost_load_dir}":
      creates => $vhost_load_dir,
      require => Package['httpd'],
    }
    file { $vhost_enable_dir:
      ensure  => directory,
      recurse => true,
      purge   => $purge_configs,
      notify  => Class['Apache::Service'],
      require => Package['httpd'],
    }
  } else {
    $vhost_load_dir = $vhost_dir
  }

# #############
# Does not work. Has dependency on puppetlabs/concat but it does not build...
##################
#  concat { $ports_file:
#    owner   => 'root',
#    group   => $apache::params::root_group,
#    mode    => '0644',
#    notify  => Class['Apache::Service'],
#    require => Package['httpd'],
#  }
   file { $ports_file:
         ensure => file ,
         content => template('apache/ports_header.erb'),
         notify  => Class['Apache::Service'],
         require => Package['httpd'],
       }

#  concat::fragment { 'Apache ports header':
#    target  => $ports_file,
#    content => template('apache/ports_header.erb')
#  }

  if $apache::params::conf_dir and $apache::params::conf_file {
    case $::osfamily {
      'debian': {
        $docroot              = '/var/www'
        $pidfile              = '${APACHE_PID_FILE}'
        $error_log            = 'error.log'
        $error_documents_path = '/usr/share/apache2/error'
        $scriptalias          = '/usr/lib/cgi-bin'
        $access_log_file      = 'access.log'
      }
      'redhat': {
        $docroot              = '/var/www/html'
        $pidfile              = 'run/httpd.pid'
        $error_log            = 'error_log'
        $error_documents_path = '/var/www/error'
        $scriptalias          = '/var/www/cgi-bin'
        $access_log_file      = 'access_log'
      }
      default: {
        fail("Unsupported osfamily ${::osfamily}")
      }
    }
  }

    $apxs_workaround = $::osfamily ? {
      'freebsd' => true,
      default   => false
    }

    # Template uses:
    # - $httpd_dir
    # - $pidfile
    # - $user
    # - $group
    # - $logroot
    # - $error_log
    # - $sendfile
    # - $mod_dir
    # - $ports_file
    # - $confd_dir
    # - $vhost_dir
    # - $error_documents
    # - $error_documents_path
    # - $apxs_workaround
    # - $keepalive
    # - $keepalive_timeout
    file { "${apache::params::conf_dir}/${apache::params::conf_file}":
      ensure  => file,
      content => template($conf_template),
      notify  => Class['Apache::Service'],
      require => Package['httpd'],
    }

    # preserve back-wards compatibility to the times when default_mods was
    # only a boolean value. Now it can be an array (too)
    class { 'apache::default_mods':
        all => $default_mods,
    }

#    if $mpm_module {
#      class { "apache::mod::${mpm_module}": }
#    }



#    include apache::install, apache::service

    notice("Establishing http://$name:80")

    notice("Starting service : $service_name")
}








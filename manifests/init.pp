#
#
#
class profile_synapse (
  Boolean          $manage_repo,
  String           $package_ensure,
  String           $server_name,
  String           $listen_address,
  Integer          $listen_port,
  String           $postgres_host,
  Hash             $additional_config,
  Boolean          $manage_firewall_entry,
  String           $sd_service_name,
  Array[String]    $sd_service_tags,
  String           $postgres_password      = extlib::cache_data('profile_synapse', 'synapse_postgres_password', extlib::random_password(42)), # lint:ignore:140chars
  String           $registration_secret    = extlib::cache_data('profile_synapse', 'synapse_registration_token', extlib::random_password(42)), # lint:ignore:140chars
  String           $macaroon_secret_key    = extlib::cache_data('profile_synapse', 'synapse_macaroon_secret_key', extlib::random_password(42)), # lint:ignore:140chars
  Boolean          $manage_sd_service      = lookup('manage_sd_service', Boolean, first, true),
) {
  $_database_args = {
    'user'     => 'synapse',
    'password' => $postgres_password,
    'database' => 'matrix-synapse',
    'host'     => 'localhost',
    'cp_min'   => 5,
    'cp_max'   => 10,
  }

  class { 'synapse':
    repo_manage         => $manage_repo,
    package_ensure      => $package_ensure,
    server_name         => $server_name,
    listen_address      => $listen_address,
    listen_port         => $listen_port,
    database_name       => 'psycopg2',
    database_args       => $_database_args,
    additional_config   => $additional_config,
    registration_secret => $registration_secret,
    macaroon_secret_key => $macaroon_secret_key,
  }

  if $manage_firewall_entry {
    firewall { "0${listen_port} allow matrix synapse":
      dport  => $listen_port,
      action => 'accept',
    }
  }

  # Additional package required for postgres
  package { 'libpq5':
    ensure => present,
  }

  profile_postgres::database { 'matrix-synapse':
    user     => 'synapse',
    password => $postgres_password,
  }

  if $manage_sd_service {
    consul::service { $sd_service_name:
      checks => [
        {
          http     => "http://${listen_address}:${listen_port}/health",
          interval => '10s'
        }
      ],
      port   => $listen_port,
      tags   => $sd_service_tags,
    }
  }
}

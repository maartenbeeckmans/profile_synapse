#
#
#
class profile_synapse (
  Boolean          $manage_repo,
  String           $package_ensure,
  String           $server_name,
  String           $web_client_location,
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
    web_client_location => $web_client_location,
    listen_address      => '127.0.0.1',
    listen_port         => 8008,
    database_name       => 'psycopg2',
    database_args       => $_database_args,
    additional_config   => $additional_config,
    registration_secret => $registration_secret,
    macaroon_secret_key => $macaroon_secret_key,
  }

  profile_apache::vhost { $server_name:
    listen_address        => $listen_address,
    port                  => 80,
    docroot               => false,
    request_headers       => [ 'set "X-Forwarded-Proto" expr=%{REQUEST_SCHEME}' ],
    allow_encoded_slashes => 'nodecode',
    proxy_preserve_host   => true,
    proxy_pass            => [
      {
        'path'     => '/health',
        'url'      => "http://127.0.0.1:8008/health",
        'keywords' => ['nocanon'],
      },
      {
        'path'     => '/_matrix',
        'url'      => "http://127.0.0.1:8008/_matrix",
        'keywords' => ['nocanon'],
      },
      {
        'path'     => '/_synapse/client',
        'url'      => "http://127.0.0.1:8008/_synapse/client",
        'keywords' => ['nocanon'],
      },
    ],
    manage_firewall_entry => $manage_firewall_entry,
    manage_sd_service     => $manage_sd_service,
    sd_service_name       => $sd_service_name,
    sd_check_uri          => 'health',
    sd_service_tags       => $sd_service_tags,
  }

  # Additional package required for postgres
  package { 'libpq5':
    ensure => present,
  }

  profile_postgres::database { 'matrix-synapse':
    user     => 'synapse',
    password => $postgres_password,
    encoding => 'UTF8',
    locale   => 'C',
  }
}

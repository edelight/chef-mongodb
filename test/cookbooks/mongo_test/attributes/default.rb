require 'openssl'

default['mongodb']['keyfile'] = ::OpenSSL::Random.random_bytes(753).gsub(/\W/, '')

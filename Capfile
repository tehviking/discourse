require 'dotenv'
Dotenv.load

load 'deploy' if respond_to?(:namespace)

Dir['vendor/gems/*/recipes/*.rb','vendor/plugins/*/recipes/*.rb'].each { |plugin| load(plugin) }

load 'config/deploy'
load 'deploy'
load 'deploy/assets'

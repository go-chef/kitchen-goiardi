# -*- encoding: utf-8 -*-
#
# Author:: Brad Beam (<brad.beam@b-rad.info>)
#
# Copyright (C) 2014, Brad Beam
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'kitchen'
require 'kitchen/provisioner/chef_base'

module Kitchen

  module Provisioner

    # Goiardi driver for Kitchen.
    #
    # @author Brad Beam <brad.beam@b-rad.info>
    #class Goiardi < Kitchen::Driver::SSHBase
    class Goiardi < ChefBase

      default_config :goiardi_version, 'v0.5.1'
      default_config :goiardi_port, '4545'
      default_config :goiardi_location, "https://github.com/bradbeam/goiardi/releases/download/"

      def create_sandbox         
        super
        prepare_validation_pem
        prepare_client_rb
      end

      def prepare_command
        data = default_config_rb
        <<-PREPARE
          sh -c '
            if [ ! -f #{config[:root_path]}/goiardi ]; then
              echo -n "Downloading goiardi..."
              wget #{config[:goiardi_location]}/#{config[:goiardi_version]}/goiardi -O #{config[:root_path]}/goiardi -o #{config[:root_path]}/goiardi_download.log
              chmod 755 #{config[:root_path]}/goiardi
              echo "done!"
            fi
            if [ -z "$(ps --no-header -C goiardi )" ]; then
              echo -n "Starting goiardi server... "
              sudo nohup #{config[:root_path]}/goiardi -V -H localhost -P #{config[:goiardi_port]} --conf-root=#{config[:root_path]} > #{config[:root_path]}/goiardi.log 2>&1 &
              echo "done!"
            fi
            echo -n "Uploading cookbooks to goiardi..."
              sudo knife cookbook upload -o #{config[:root_path]}/cookbooks -a -c #{config[:root_path]}/client.rb >> #{config[:root_path]}/goiardi.log 2>&1
            echo "done!"                                                                                                                   
            '
        PREPARE
      end

      def run_command
        args = [
          "--config #{config[:root_path]}/client.rb",
          "--log_level #{config[:log_level]}"
        ]
        if config[:json_attributes]
          args << "--json-attributes #{config[:root_path]}/dna.json"
        end

        ["#{sudo('chef-client')} "].concat(args).join(" ")
      end

      private

      def prepare_validation_pem
        source = File.join(File.dirname(__FILE__),
          %w{.. .. .. support dummy-validation.pem})
        FileUtils.cp(source, File.join(sandbox_path, "validation.pem"))
      end

      def prepare_client_rb
        data = default_config_rb.merge(config[:client_rb])
        data[:chef_server_url] = "http://127.0.0.1:#{config[:goiardi_port]}"
        data[:verify_peer] = :verify_peer
        data[:client_key] = File.join(config[:root_path], "validation.pem")
        File.open(File.join(sandbox_path, "client.rb"), "wb") do |file|
          file.write(format_config_file(data))
        end
      end

    end
  end
end

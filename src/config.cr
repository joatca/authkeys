# This file is part of authkeys, a tool intended to be used as an AuthorizedKeysCommand for sshd
#
# Copyright Fraser McCrossan <fraser@mccrossan.ca> 2021
# 
# ne is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# ne is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with authkeys.  If not, see <http://www.gnu.org/licenses/>.

# this file parses the command line arguments and then the sssd config file and encapsulates all of the
# configuration we need to connect to LDAP

require "option_parser"
require "ini"
require "uri"

module Authkeys

  class Config

    @config : String # configuration file
    @domain : String # which domain in the config file to use
    @uri : String # the full LDAP service URI
    @server : String # server name, extracted from the URI
    @port : Int32 # port number to connect to
    @base : String # search base
    @dn : String # the bind DN
    @pw : String # the bind password
    @attrib : String # which attribute contains ssh keys?
    @filter : String # access filter, that records must match or they won't be found
    @start_tls : Bool # whether to try STARTTLS
    @simple_tls : Bool # whether to try use a plain SSL socket

    getter server, port, base, filter, attrib, start_tls, simple_tls, dn, pw
    
    def initialize
      @config = "/etc/sssd/sssd.conf"
      @domain = "default"
      # blank is a safe initial value for all of these; for @filter maybe there is none and for all the others it's invalid and will trigger a later error
      @filter = @uri = @base = ""
      # initialize just to keep the compiler happy
      @server = ""
      @port = 389
      @attrib = "sshPublicKey"
      @dn = @pw = ""
      @start_tls = false
      @simple_tls = false

      parse_commandline
      parse_config_file
    end

    def parse_commandline
      OptionParser.parse do |parser|
        parser.banner = "Usage: #{PROGRAM_NAME} [options] username...\n"
        parser.on("-cFILE", "--config=FILE", "sssd configuration file (default #{@config}") { |c|
          @config = c
        }
        parser.on("-dFILE", "--domain=DOMAIN", "which domain in the sssd config to use (default #{@domain}") { |d|
          @domain = d
        }
        parser.on("-h", "--help", "Show this help") {
          puts parser
          exit 0
        }
        parser.invalid_option { |o|
          STDERR.puts "#{PROGRAM_NAME}: unknown option #{o}"
          STDERR.puts parser
          exit 1
        }
        parser.missing_option { |m|
          raise "#{PROGRAM_NAME}: option #{m} requires an argument"
        }
      end
    end

    def parse_config_file
      File.open(@config, "r") do |cf|
        data = INI.parse(cf)
        raise "#{@config} doesn't look like an sssd config file" unless data.has_key?("sssd")
        raise "#{@config} doesn't look like a version 2 sssd config file" if data["sssd"]?.try { |h| h["config_file_version"]? } != "2"
        domain_section = "domain/#{@domain}"
        raise "domain #{@domain.inspect} not found in #{@config}" unless data.has_key?(domain_section)
        dom = data[domain_section]
        raise "domain #{@domain} is not an ldap domain" unless dom["id_provider"].to_s == "ldap"
        # extract parts of the config that we need
        @start_tls = dom["ldap_id_use_start_tls"]?.to_s.downcase == "true"
        # cast these all to string so that we get blank if it's nil; that's invalid so will trigger an error later
        @base = dom["ldap_search_base"]?.to_s
        @uri = dom["ldap_uri"]?.to_s
        # similar, but a blank filter is legal
        @filter = dom["ldap_access_filter"]?.to_s
        # we already have a default attribute so only overwrite it if it's in the config file
        @attrib = dom["ldap_user_ssh_public_key"]?.to_s unless dom["ldap_user_ssh_public_key"]?.nil?
        @dn = dom["ldap_default_bind_dn"]?.to_s # the bind DN, blank means don't bother authenticating
        @pw = dom["ldap_default_authtok"]?.to_s # the bind password, ignored unless the bind DN is set
        # that's all the parameters we care about from the config file, now we process them
        uri = URI.parse(@uri)
        case uri.scheme
        when "ldaps"
          @simple_tls = true
          @start_tls = false # for ldaps we ignore the ldap_id_use_start_tls option above
          @port = 636 # force the default port number, we'll confirm it below
        when "ldap"
          @simple_tls = false # already initialized so not really needed
          @port = 389 # force the default port number
        else
          raise "#{@uri.inspect} is not an LDAP URI"
        end
        @port = uri.port.as(Int32) unless uri.port.nil? # maybe override the port number
        @server = uri.host.to_s # again, force nils to blanks, check below
        # for now we'll ignore all the other URI components
        raise "no server name found in URI #{@uri.inspect}" if @server == ""
        # now we should have everything we need to connect and bind; note: ldap_default_bind_dn,
        # ldap_default_authtok_type and ldap_default_authtok are currently unsupported, only anonymous bind is
        # supported
      end
    end

    def need_to_bind?
      @dn != ""
    end
    
  end
  
end

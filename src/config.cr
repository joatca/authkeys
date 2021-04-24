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
require "./autherr"

module Authkeys

  class Config

    @config : String # configuration file
    @domain : String # which domain in the config file to use
    @uri : String # the full LDAP service URI
    @server : String # server name, extracted from the URI
    @port : Int32 # port number to connect to
    @timeout : Int32 # connection timeout
    @base : String # search base
    @dn : String # the bind DN
    @pw : String # the bind password
    @attrib : String # which attribute contains ssh keys?
    @filter : String # access filter, that records must match or they won't be found
    @start_tls : Bool # whether to try STARTTLS
    @simple_tls : Bool # whether to try use a plain SSL socket

    getter server, port, timeout, base, filter, attrib, start_tls, simple_tls, dn, pw
    
    def initialize
      @config = "/etc/sssd/sssd.conf"
      @domain = "default"
      # blank is a safe initial value for all of these; for @filter maybe there is none and for all the others it's invalid and will trigger a later error
      @filter = @uri = @base = ""
      # initialize just to keep the compiler happy
      @server = ""
      @port = 389
      @timeout = 6
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
        parser.on("-cFILE", "--config=FILE", "sssd configuration file (default #{@config})") { |c|
          @config = c
        }
        parser.on("-dFILE", "--domain=DOMAIN", "which domain in the sssd config to use (default #{@domain})") { |d|
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
          raise AuthErr.new("#{PROGRAM_NAME}: option #{m} requires an argument", ErrType::Cmdline)
        }
      end
    end

    def parse_config_file
      begin
        File.open(@config, "r") do |cf|
          data = INI.parse(cf)
          raise AuthErr.new("#{@config} doesn't look like an sssd config file", ErrType::Config) unless data.has_key?("sssd")
          raise AuthErr.new("#{@config} doesn't look like a version 2 sssd config file", ErrType::Config) if data["sssd"]?.try { |h| h["config_file_version"]? } != "2"
          domain_section = "domain/#{@domain}"
          raise AuthErr.new("domain #{@domain.inspect} not found in #{@config}", ErrType::Config) unless data.has_key?(domain_section)
          dom = data[domain_section]
          raise AuthErr.new("domain #{@domain} is not an ldap domain", ErrType::Config) unless dom["id_provider"].to_s == "ldap"
          # extract parts of the config that we need; we use #try to avoid explicit nil checks or depending on
          # nil.to_s == ""
          dom["ldap_id_use_start_tls"]?.try { |t| @start_tls = t.downcase == "true" }
          dom["ldap_search_base"]?.try { |b| @base = b }
          dom["ldap_uri"]?.try { |u| @uri = u }
          dom["ldap_access_filter"]?.try { |f| @filter = f }
          # we already have a default attribute so only overwrite it if it's in the config file
          dom["ldap_user_ssh_public_key"]?.try { |a| @attrib = a }
          # the bind DN, blank means don't bother authenticating
          dom["ldap_default_bind_dn"]?.try { |d| @dn = d }
          # the bind password, ignored unless the bind DN is set
          dom["ldap_default_authtok"]?.try { |p| @pw = p }
          # since this is an int with a default, only process it if the value exists
          begin
            dom["ldap_search_timeout"]?.try { |t| @timeout = t.to_i }
          rescue e : ArgumentError
            raise AuthErr.new("ldap_search_timeout invalid: #{e.message}", ErrType::Config)
          end
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
            raise AuthErr.new("#{@uri.inspect} is not an LDAP URI", ErrType::Config)
          end
          uri.port.try { |p| @port = p }
          @server = uri.host.to_s # again, force nils to blanks, check below
          # for now we'll ignore all the other URI components
          raise AuthErr.new("no server name found in URI #{@uri.inspect}", ErrType::Config) if @server == ""
          # now we should have everything we need to connect and bind; note: ldap_default_bind_dn,
          # ldap_default_authtok_type and ldap_default_authtok are currently unsupported, only anonymous bind is
          # supported
        end
      rescue e : File::NotFoundError | File::AccessDeniedError
        raise AuthErr.new(e.message, ErrType::Config)
      end
    end

    def need_to_bind?
      @dn != ""
    end
    
  end
  
end

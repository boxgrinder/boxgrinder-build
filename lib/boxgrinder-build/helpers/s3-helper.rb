#
# Copyright 2010 Red Hat, Inc.
#
# This is free software; you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation; either version 3 of
# the License, or (at your option) any later version.
#
# This software is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this software; if not, write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
# 02110-1301 USA, or see the FSF site: http://www.fsf.org.

require 'boxgrinder-build/helpers/aws-helper'

module BoxGrinder
  class S3Helper < AWSHelper

    #AWS::S3 object should be instantiated already, as config can be inserted
    #via global AWS.config or via AWS::S3.initialize
    def initialize(ec2, s3, options={})
      raise ArgumentError, "ec2 argument must not be nil" if ec2.nil?
      raise ArgumentError, "s3 argument must not be nil" if s3.nil?
      @ec2 = ec2
      @s3 = s3
      @log = options[:log] || LogHelper.new
    end

    def bucket(options={})
      defaults = {:bucket => nil, :acl => :private, :location_constraint => 'us-east-1', :create_if_missing => false}
      options = parse_opts(options, defaults)

      s3b = @s3.buckets[options[:bucket]]
      return s3b if s3b.exists?
      return @s3.buckets.create(options[:bucket],
                         :acl => options[:acl],
                         :location_constraint => options[:location_constraint]) if options[:create_if_missing]
      nil
    end

    def delete_folder(bucket, path)
      bucket.objects.with_prefix(deslash(path)).map(&:delete)
    end

    def stub_s3obj(bucket, path)
      bucket.objects[path]
    end

    def parse_path(path)
      return '' if path == '/'
      #Remove preceding and trailing slashes
      deslash(path) << '/'
    end

    def self.endpoints
      ENDPOINTS
    end

    private

    #Remove extraneous slashes on paths to ensure they are valid for S3
    def deslash(path)
      "#{path.gsub(/^(\/)*/, '').gsub(/(\/)*$/, '')}"
    end

    ENDPOINTS = {
      'eu-west-1' => {
        :endpoint => 's3-eu-west-1.amazonaws.com',
        :location => 'EU',
        :kernel => {
          :i386 => {:aki => 'aki-4deec439'},
          :x86_64 => {:aki => 'aki-4feec43b'}
        }
      },

      'ap-southeast-1' => {
        :endpoint => 's3-ap-southeast-1.amazonaws.com',
        :location => 'ap-southeast-1',
        :kernel => {
          :i386 => {:aki => 'aki-13d5aa41'},
          :x86_64 => {:aki => 'aki-11d5aa43'}
        }
      },

      'ap-southeast-2' => {
        :endpoint => 's3-ap-southeast-2.amazonaws.com',
        :location => 'ap-southeast-2',
        :kernel => {
          :i386 => {:aki => 'aki-3f990e05'},
          :x86_64 => {:aki => 'aki-3d990e07'}
        }
      },

      'ap-northeast-1' => {
        :endpoint => 's3-ap-northeast-1.amazonaws.com',
        :location => 'ap-northeast-1',
        :kernel => {
          :i386 => {:aki => 'aki-d209a2d3'},
          :x86_64 => {:aki => 'aki-d409a2d5'}
        }
      },

      'us-west-1' => {
        :endpoint => 's3-us-west-1.amazonaws.com',
        :location => 'us-west-1',
        :kernel => {
          :i386 => {:aki => 'aki-99a0f1dc'},
          :x86_64 => {:aki => 'aki-9ba0f1de'}
        }
      },

      'us-west-2' => {
        :endpoint => 's3-us-west-2.amazonaws.com',
        :location => 'us-west-2',
        :kernel => {
          :i386 => {:aki => 'aki-dce26fec'},
          :x86_64 => {:aki => 'aki-98e26fa8'}
        }
      },

      'us-east-1' => {
        :endpoint => 's3.amazonaws.com',
        :location => nil,
        :kernel => {
          :i386 => {:aki => 'aki-407d9529'},
          :x86_64 => {:aki => 'aki-427d952b'}
        }
      },

      'sa-east-1' => {
        :endpoint => 's3-sa-east-1.amazonaws.com',
        :location => 'sa-east-1',
        :kernel => {
          :i386 => {:aki => 'aki-863ce39b'},
          :x86_64 => {:aki => 'aki-d63ce3cb'}
        }
      }
    }

  end
end

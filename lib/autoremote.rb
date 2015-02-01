require 'autoremote/net'
require 'autoremote/version'
require 'autoremote/exceptions'
require 'sqlite3'
require 'active_record'
require 'socket'

## Establish the database connection
ActiveRecord::Base.establish_connection(
    adapter:    'sqlite3',
    database:   ENV['HOME'] + '/.autoremote/devices.db'
)

class Device < ActiveRecord::Base
end

## Create the database table
ActiveRecord::Schema.define do
    break if ActiveRecord::Base.connection.table_exists? 'devices'
    create_table :devices do |table|
        table.column :name, :string
        table.column :key, :string
    end
end

module AutoRemote
    # Add a device
    # @param name [String] The name of the device
    # @param input [String] Can either be the 'goo.gl' url or the personal key of the device
    # @raise [AutoRemote::InvalidKey] if the key or url is invalid
    # @return [Device] the device that was was created
    # @return [nil] if the device already exists
    def AutoRemote::add_device(name, input)
        
        ## Validation if input is a 'goo.gl' url
        if input.match(/^(https?:\/{2})?(goo.gl\/[\S]*)$/i)
            result = AutoRemoteRequest.validate_url(input)
            
            ## Get the key from the resulting url
            begin
                input = CGI.parse(result.request.last_uri.query)['key'][0]
            rescue
                raise self::InvalidKey
            end
            
        ## If not a 'goo.gl' url, check if it is a valid key
        else
            ## Validate key
            result = AutoRemoteRequest.validate_key(input)
            
            ## Check result
            raise self::InvalidKey if result.body != 'OK'
        end
        
        ## Check if the device already exist
        if Device.find_by_name(name)
            return nil
        else
            ## Save the device
            return Device.create(name: name, key: input)
        end
    end
    
    # Remove a specific device
    # @param name [String] The name of the device
    # @return [true] if the device was deleted
    # @return [false] if the device wasn't found
    def AutoRemote::remove_device(name)
        device = Device.find_by_name(name)
        if device
            ## Remove the device
            Device.delete(device.id)
            return true
        else
            return false
        end
    end
    
    # Returns a list with all devices
    # @return [Device::ActiveRecord_Relation]
    def AutoRemote::list_devices
        return Device.order('name').all
    end
    
    # Returns one specific device
    # @return [Device] if the device was found
    # @return [nil] if the device wasn't found
    def AutoRemote::get_device(name)
        return Device.find_by_name(name)
    end
    
    # Sends a message to a device
    # @param device [Device, String] A device object or the name of the device
    # @param message [String] The message to send
    # @raise [ArgumentError] if message isn't a string
    # @return [true] if the message was sent
    # @return [false] if the message wasn't sent
    def AutoRemote::send_message(device, message)
        device = self.validate_device(device)
        
        if !device
            return false
        elsif ! message.is_a?(String)
            raise ArgumentError, 'Message must be a string'
        end
        
        ## Send the message
        result = AutoRemoteRequest.message(device.key, `hostname`.strip, CGI.escape(message))
        
        ## Check result
        if result.body == 'OK'
            return true
        else
            return false
        end
    end
    
    # Register on the device
    # @param device [Device, String] A device object or the name of the device
    # @param remotehost [String] The public hostname or ip-address
    # @raise [ArgumentError] if message isn't a string or less than 5 characters
    # @return [true] if the registration was successful
    # @return [false] if the registration failed
    def AutoRemote::register_on_device(device, remotehost)
        device = self.validate_device(device)
        
        if !device
            return false
        elsif ! remotehost.is_a?(String) || remotehost.length < 5
            raise ArgumentError, 'remotehost must be a string of 5 chars or more'
        end
        
        hostname = `hostname`.strip
        ipAddress = AutoRemote::get_ip_address.ip_address
        
        ## Perform the registration
        result = AutoRemoteRequest.register(device.key, hostname, hostname, remotehost, ipAddress)
        
        ## Check result
        if result.body == 'OK'
            return true
        else
            return false
        end
    end
    
    ## Define alases for some methods
    class << AutoRemote
        # Add
        alias :addDevice :add_device
        alias :saveDevice :add_device
        alias :save_device :add_device
        # Remove
        alias :removeDevice :remove_device
        alias :deleteDevice :remove_device
        alias :delete_device :remove_device
        # List
        alias :listDevices :list_devices
        # Get
        alias :getDevice :get_device
        # Message
        alias :sendMessage :send_message
        alias :sendMsg :send_message
        alias :send_msg :send_message
        # Register
        alias :registerOnDevice :register_on_device
        alias :regOnDevice :register_on_device
        alias :reg_on_device :register_on_device
    end
    
    private
    # Validates device
    # @param input the input to validate
    # @return [Device] if the input is valid
    # @return [nil] if the input is not valid
    def AutoRemote::validate_device(input)
        if input.is_a?(Device)
            return input
        else
            device = Device.find_by_name(input)
            if device.kind_of?(Device)
                return device
            else
                return nil
            end
        end
    end
    
    # Gets the ip address of the system
    # @return [String]
    def AutoRemote::get_ip_address
        return Socket.ip_address_list.detect { |ipInfo| ipInfo.ipv4_private? }
    end
end

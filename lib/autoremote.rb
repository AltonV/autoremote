require 'autoremote/version'
require 'autoremote/exceptions'
require 'sqlite3'
require 'active_record'
require 'net/http'
require 'socket'
require 'httparty'

## Establish the database connection
ActiveRecord::Base.establish_connection(
    :adapter  => 'sqlite3',
    :database => ENV['HOME'] + '/.autoremote/devices.db'
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
    REG_URL = 'http://autoremotejoaomgcd.appspot.com/registerpc?key=%YOUR_KEY%&name=%DISPLAY_NAME%&id=%UNIQUE_ID%&type=linux&publicip=%PUBLIC_HOST%&localip=%IP_ADDRESS%'
    MSG_URL = 'http://autoremotejoaomgcd.appspot.com/sendmessage?key=%YOUR_KEY%&message=%MESSAGE%&sender=%SENDER_ID%'
    VALIDATION_URL = 'http://autoremotejoaomgcd.appspot.com/sendmessage?key=%YOUR_KEY%'
    
    # Add a device
    # @param name [String] The name of the device
    # @param input [String] Can either be the 'goo.gl' url or the personal key of the device
    # @raise [AutoRemote::DeviceAlreadyExist] if the device already exits
    # @raise [AutoRemote::InvalidKey] if the key or url is invalid
    # @return [void]
    def AutoRemote::add_device(name, input)
        
        ## Validation if input is a 'goo.gl' url
        if input.match(/^(https?:\/{2})?(goo.gl\/[\S]*)$/i)
            result = self.url_request(input)
            
            ## Get the key from the resulting url
            begin
                input = CGI.parse(result.request.last_uri.query)['key'][0]
            rescue
                raise self::InvalidKey
            end
            
        ## If not a 'goo.gl' url, check if it is a valid key
        else
            ## Validate key
            result = self.url_request(VALIDATION_URL.sub(/%YOUR_KEY%/, input))
            
            ## Check result
            if result.body != 'OK'
                raise self::InvalidKey
            end
        end
        
        ## Check if the device already exist
        if Device.find_by_name(name) || Device.find_by_key(input)
            raise self::DeviceAlreadyExist
        end
        
        ## Save the device
        Device.create(:name => name, :key => input)
    end
    
    # Remove a specific device
    # @param name [String] The name of the device
    # @raise [AutoRemote::DeviceNotFound] if the device didn't exist
    # @return [void]
    def AutoRemote::remove_device(name)
        if device = Device.find_by_name(name)
            ## Remove the device
            Device.delete(device.id)
        else
            raise self::DeviceNotFound
        end
    end
    
    # Returns a list with all devices
    # @return [Device::ActiveRecord_Relation]
    def AutoRemote::list_devices
        return Device.order('name').all
    end
    
    # Returns one specific device
    # @return [Device]
    def AutoRemote::get_device(name)
        return Device.find_by_name(name)
    end
    
    # Sends a message to a device
    # @param device [Device, String] A device object or the name of the device
    # @param message [String] The message to send
    # @raise [AutoRemote::DeviceNotFound] if the device didn't exits
    # @raise [TypeError] if message isn't a string
    # @return [void]
    def AutoRemote::send_message(device, message)
        if ! device.kind_of?(Device) && ! (device = Device.find_by_name(device))
            raise self::DeviceNotFound
        elsif ! message.kind_of?(String)
            raise TypeError, 'Message must be a string'
        end
        
        hostname = `hostname`.strip
        
        ## Send the message
        result = self.url_request(MSG_URL.sub(/%YOUR_KEY%/, device.key).sub(/%MESSAGE%/, CGI.escape(message)).sub(/%SENDER_ID%/, hostname))
        
        ## Check result
        if result.body != 'OK'
            raise self::InvalidKey
        end
    end
    
    # Register on the device
    # @param device [Device, String] A device object or the name of the device
    # @param remotehost [String] The public hostname or ip-address
    # @raise [AutoRemote::DeviceNotFound] if the device didn't exits
    # @raise [AutoRemote::UnsupportedAction] if running from windows
    # @raise [TypeError] if message isn't a string or less than 5 characters
    # @return [void]
    def AutoRemote::register_on_device(device, remotehost)
        if ! device.kind_of?(Device) && ! (device = Device.find_by_name(device))
            raise self::DeviceNotFound
        elsif ! remotehost.kind_of?(String) || remotehost.length < 5
            raise ArgumentError, 'remotehost must be a string of 5 chars or more'
        end
        
        hostname = `hostname`.strip
        ipAddress = AutoRemote::get_ip_address.ip_address
        
        ## Perform the registration
        result = self.url_request(REG_URL.sub(/%YOUR_KEY%/, device.key).sub(/%DISPLAY_NAME%/, hostname).sub(/%UNIQUE_ID%/, hostname).sub(/%PUBLIC_HOST%/, remotehost).sub(/%IP_ADDRESS%/, ipAddress))
        
        ## Check result
        if result.body != 'OK'
            raise self::AutoRemoteException, 'Something went wrong when registering on the device'
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
    # Gets the ip address of the system
    # @return [String]
    def AutoRemote::get_ip_address
        return Socket.ip_address_list.detect { |ipInfo| ipInfo.ipv4_private? }
    end
    
    # Performs a http request
    # @param url [String]
    def AutoRemote::url_request(url)
        ## Add http:// to the url if not present
        url = 'http://' + url unless url.match(/^https?:\/{2}/i)
        
        return HTTParty.get(url)
    end
end

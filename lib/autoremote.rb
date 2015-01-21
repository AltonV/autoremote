require "autoremote/version"
require "autoremote/exceptions"
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
    REGURL = "http://autoremotejoaomgcd.appspot.com/registerpc?key=%YOUR_KEY%&name=%DISPLAY_NAME%&id=%UNIQUE_ID%&type=linux&publicip=%PUBLIC_HOST%&localip=%IP_ADDRESS%"
    MSGURL = "http://autoremotejoaomgcd.appspot.com/sendmessage?key=%YOUR_KEY%&message=%MESSAGE%&sender=%SENDER_ID%"
    VALIDATIONURL = "http://autoremotejoaomgcd.appspot.com/sendmessage?key=%YOUR_KEY%"
    
    # Add a device
    # @param name [String] The name of the device
    # @param input [String] Can either be the 'goo.gl' url or the personal key of the device
    # @raise [AutoRemote::DeviceAlreadyExist] if the device already exits
    # @raise [AutoRemote::InvalidKey] if the key or url is invalid
    # @return [void]
    def AutoRemote::addDevice( name, input )
        
        ## Validation if input is a 'goo.gl' url
        if input.match( /^(https?:\/{2})?(goo.gl\/[\S]*)$/i )
            result = self.urlRequest( input )
            
            ## Get the key from the resulting url
            begin
                input = CGI.parse( result.request.last_uri.query )['key'][0]
            rescue
                raise self::InvalidKey
            end
            
        ## If not a 'goo.gl' url, check if it is a valid key
        else
            ## Validate key
            result = self.urlRequest( VALIDATIONURL.sub( /%YOUR_KEY%/, input ) )
            
            ## Check result
            if result.body != "OK"
                raise self::InvalidKey
            end
        end
        
        ## Check if the device already exist
        if Device.find_by_name( name ) || Device.find_by_key( input )
            raise self::DeviceAlreadyExist
        end
        
        ## Save the device
        Device.create(:name => name, :key => input)
    end
    
    # Remove a specific device
    # @param name [String] The name of the device
    # @raise [AutoRemote::DeviceNotFound] if the device didn't exist
    # @return [void]
    def AutoRemote::removeDevice( name )
        if device = Device.find_by_name(name)
            
            ## Remove the device
            Device.delete(device.id)
        else
            raise self::DeviceNotFound
        end
    end
    
    # Returns a list with all devices
    # @return [Device::ActiveRecord_Relation]
    def AutoRemote::listDevices
        return Device.order("name").all
    end
    
    # Returns one specific device
    # @return [Device]
    def AutoRemote::getDevice( name )
        return Device.find_by_name( name )
    end
    
    # Sends a message to a device
    # @param device [Device, String] A device object or the name of the device
    # @param message [String] The message to send
    # @raise [AutoRemote::DeviceNotFound] if the device didn't exits
    # @raise [TypeError] if message isn't a string
    # @return [void]
    def AutoRemote::sendMessage( device, message )
        if ! device.kind_of?( Device ) && ! ( device = Device.find_by_name( device ) )
            raise self::DeviceNotFound
        elsif ! message.kind_of?( String )
            raise TypeError, "Message must be a string"
        end
        
        hostname = `hostname`.strip
        
        ## Send the message
        result = self.urlRequest( MSGURL.sub( /%YOUR_KEY%/, device.key ).sub( /%MESSAGE%/, message ).sub( /%SENDER_ID%/, hostname ) )
        
        ## Check result
        if result.body != "OK"
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
    def AutoRemote::registerOnDevice( device, remotehost )
        if ! device.kind_of?( Device ) && ! ( device = Device.find_by_name( device ) )
            raise self::DeviceNotFound
        elsif ! remotehost.kind_of?( String ) || remotehost.length < 5
            raise ArgumentError, "remotehost must be a string of 5 chars or more"
        end
        
        hostname = `hostname`.strip
        ipAddress = AutoRemote::getIpAddress.ip_address
        
        ## Perform the registration
        result = self.urlRequest( REGURL.sub( /%YOUR_KEY%/, device.key ).sub(/%DISPLAY_NAME%/, hostname ).sub(/%UNIQUE_ID%/, hostname ).sub(/%PUBLIC_HOST%/, remotehost ).sub(/%IP_ADDRESS%/, ipAddress ) )
        
        ## Check result
        if result.body != "OK"
            raise self::AutoRemoteException, "Something went wrong when registering on the device"
        end
    end
    
    ## Define alases for some methods
    class << AutoRemote
        alias :saveDevice :addDevice
        alias :deleteDevice :removeDevice
        alias :sendMsg :sendMessage
        alias :regOnDevice :registerOnDevice
    end
    
    private
    # Gets the ip address of the system
    # @return [String]
    def AutoRemote::getIpAddress
        return Socket.ip_address_list.detect{|ipInfo| ipInfo.ipv4_private?}
    end
    
    # Performs a http request
    # @param url [String]
    def AutoRemote::urlRequest( url )
        ## Add http:// to the url if not present
        if ! url.match( /^https?:\/{2}/i )
            url = "http://" + url
        end
        
        return HTTParty.get( url )
    end
end

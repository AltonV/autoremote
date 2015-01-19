require "autoremote/version"
require "autoremote/exceptions"
require 'sqlite3'
require 'active_record'
require 'net/http'
require 'rbconfig'

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
    REGCMD = "curl \"http://autoremotejoaomgcd.appspot.com/registerpc?key=%YOUR_KEY%&name=%DISPLAY_NAME%&id=%UNIQUE_ID%&type=linux&publicip=%PUBLIC_HOST%&localip=$(sudo ifconfig eth0 |grep \"inet addr\" |awk '{print $2}' |awk -F: '{print $2}')\""
    MSGURL = "http://autoremotejoaomgcd.appspot.com/sendmessage?key=%YOUR_KEY%&message=%MESSAGE%&sender=%SENDER_ID%"
    VALIDATIONURL = "http://autoremotejoaomgcd.appspot.com/sendmessage?key=%YOUR_KEY%"
    
    # Add a device
    # @param name [String] The name of the device
    # @param key [String] The personal key of the device
    # @raise [AutoRemote::DeviceAlreadyExist] if the device already exits
    # @return [void]
    def AutoRemote::addDevice( name, key )
        ## Check if the name is taken
        if Device.find_by_name( name ) || Device.find_by_key(key)
            raise self::DeviceAlreadyExist
        end
        
        ## Validate key
        result = self.urlRequest( VALIDATIONURL.sub( /%YOUR_KEY%/, key ) )
        
        ## Check result
        if result.body != "OK"
            raise self::InvalidKey
        end
        
        ## Save the device
        Device.create(:name => name, :key => key)
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
        
        if RbConfig::CONFIG['host_os'] =~ /mswin|msys|mingw|cygwin|bccwin|wince|emc/i
            raise self::UnsupportedAction, "Windows not supported"
        elsif ! device.kind_of?( Device ) && ! ( device = Device.find_by_name( device ) )
            raise self::DeviceNotFound
        elsif ! remotehost.kind_of?( String ) || remotehost.length < 5
            raise ArgumentError, "remotehost must be a string of 5 chars or more"
        end
        
        hostname = `hostname`.strip
        
        ## Perform the registration
        cmd = REGCMD.sub( /%YOUR_KEY%/, device.key ).sub(/%DISPLAY_NAME%/, hostname ).sub(/%UNIQUE_ID%/, hostname ).sub(/%PUBLIC_HOST%/, remotehost )
        result = system(cmd)
        puts
        
        ## Check result
        if ! result
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
    # Performs a http request
    # @param url [String]
    def AutoRemote::urlRequest( url )
        url = URI.parse( url )
        result = Net::HTTP.start(url.host, url.port) {|http|
            http.request( Net::HTTP::Get.new( url.to_s ) )
        }
        return result
    end
end

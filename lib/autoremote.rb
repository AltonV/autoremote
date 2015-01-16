require "autoremote/version"
require "autoremote/exceptions"
require 'sqlite3'
require 'active_record'
require 'net/http'

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
    
    ## Add a device
    def AutoRemote::addDevice( name, key )
        ## Check if the name is taken
        if Device.find_by_name( name ) || Device.find_by_key(key)
            raise self::DeviceAlreadyExist#
        end
        
        ## Validate key
        url = URI.parse( VALIDATIONURL.sub( /%YOUR_KEY%/, key ) )
        result = Net::HTTP.start(url.host, url.port) {|http|
            http.request( Net::HTTP::Get.new( url.to_s ) )
        }
        if result.body != "OK"
            raise self::InvalidKey
        end
        
        ## Save the device
        Device.create(:name => name, :key => key)
        return true
    end
    
    ## Remove a specific device
    def AutoRemote::removeDevice( name )
        if device = Device.find_by_name(name)
            
            ## Remove the device
            return Device.delete(device.id)
        else
            raise self::DeviceNotFound
        end
    end
    
    ## Returns a list with all devices
    def AutoRemote::listDevices
        return Device.order("name").all
    end
    
    ## Returns one specific device
    def AutoRemote::getDevice( name )
        return Device.find_by_name( name )
    end
    
    ## Send a message to a device
    def AutoRemote::sendMessage( device, message )
        if ! device.kind_of?( Device ) && ! ( device = Device.find_by_name( device ) )
            raise self::DeviceNotFound
        elsif ! message.kind_of?( String )
            raise TypeError, "Message must be a string"
        end
        
        hostname = `hostname`.strip
        
        ## Send the message
        url = URI.parse( MSGURL.sub( /%YOUR_KEY%/, device.key ).sub( /%MESSAGE%/, message ).sub( /%SENDER_ID%/, hostname ) )
        result = Net::HTTP.start(url.host, url.port) {|http|
            http.request( Net::HTTP::Get.new( url.to_s ) )
        }
        
        ## Check result
        if result.body != "OK"
            raise self::InvalidKey
        end
        
        return true
    end
    
    ## Register on the device
    def AutoRemote::registerOnDevice( device, remotehost )
        
        if ! device.kind_of?( Device ) && ! ( device = Device.find_by_name( device ) )
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
        
        return true
    end
    
    ## Define alases for some methods
    class << AutoRemote
        alias :saveDevice :addDevice
        alias :deleteDevice :removeDevice
        alias :sendMsg :sendMessage
        alias :regOnDevice :registerOnDevice
    end
end

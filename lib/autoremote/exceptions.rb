module AutoRemote
    class AutoRemoteException < StandardError
    end
    
    class DeviceNotFound < AutoRemoteException
        def message
            "Device doesn't exist"
        end
    end
    
    class DeviceAlreadyExist < AutoRemoteException
        def message
            "Device already exist"
        end
    end
    
    class InvalidKey < AutoRemoteException
        def message
            "The key is invalid"
        end
    end
    
end

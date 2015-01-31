module AutoRemote
    class AutoRemoteException < StandardError
    end

    class InvalidKey < AutoRemoteException
        def message
            "The key is invalid"
        end
    end

end
